#!/usr/bin/env bash
set -euo pipefail

TASKCTL="${1:-scripts/taskctl.sh}"
TEMPLATE_FILE="${2:-coordination/templates/TASK_TEMPLATE.md}"

if [[ ! -x "$TASKCTL" ]]; then
  echo "taskctl script not executable: $TASKCTL" >&2
  exit 1
fi

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "task template file not found: $TEMPLATE_FILE" >&2
  exit 1
fi

for cmd in jq yq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "missing required command: $cmd" >&2
    exit 1
  fi
done

extract_frontmatter() {
  local source_file="$1"
  local out_file="$2"

  awk '
    BEGIN { section = 0 }
    /^---$/ { section++; next }
    section == 1 { print }
    section >= 2 { exit }
  ' "$source_file" >"$out_file"
}

assert_yaml_expr() {
  local yaml_file="$1"
  local expr="$2"
  local description="$3"

  if ! yq -e "$expr" "$yaml_file" >/dev/null; then
    echo "yaml assertion failed: $description" >&2
    echo "expression: $expr" >&2
    exit 1
  fi
}

require_contains() {
  local haystack="$1"
  local needle="$2"
  local description="$3"

  if ! printf '%s' "$haystack" | grep -Fq -- "$needle"; then
    echo "missing expected output: $description" >&2
    echo "expected snippet: $needle" >&2
    exit 1
  fi
}

smoke_root="$(mktemp -d /workspace/.taskctl-lock-smoke.XXXXXX)"
tmp_frontmatter="$(mktemp)"
trap 'rm -rf "$smoke_root"; rm -f "$tmp_frontmatter"' EXIT

mkdir -p "$smoke_root/templates"
cp "$TEMPLATE_FILE" "$smoke_root/templates/TASK_TEMPLATE.md"

run_taskctl() {
  TASK_ROOT_DIR="$smoke_root" "$TASKCTL" "$@"
}

run_taskctl_as() {
  local actor_agent="$1"
  shift
  TASK_ROOT_DIR="$smoke_root" TASK_ACTOR_AGENT="$actor_agent" "$TASKCTL" "$@"
}

invalid_task_id="taskctl-lock-invalid-$(date +%s)-$$"
set +e
invalid_output="$(run_taskctl create "$invalid_task_id" "Missing write targets for FE" --to fe --from pm --priority 50 2>&1)"
invalid_rc=$?
set -e

if [[ "$invalid_rc" -eq 0 ]]; then
  echo "expected create validation failure for coding task without write targets" >&2
  exit 1
fi
require_contains "$invalid_output" "require non-empty intended_write_targets" "coding task write-target validation"

valid_task_id="taskctl-lock-valid-$(date +%s)-$$"
run_taskctl create "$valid_task_id" "Lock metadata create smoke" --to fe --from pm --priority 50 --write-target scripts/taskctl.sh >/dev/null

created_task="$smoke_root/inbox/fe/050/${valid_task_id}.md"
if [[ ! -f "$created_task" ]]; then
  echo "expected created task file not found: $created_task" >&2
  exit 1
fi

extract_frontmatter "$created_task" "$tmp_frontmatter"
assert_yaml_expr "$tmp_frontmatter" '.intended_write_targets | type == "array" and length == 1' "created coding task includes one write target"
assert_yaml_expr "$tmp_frontmatter" '.intended_write_targets[0] == "scripts/taskctl.sh"' "write target path canonicalized and persisted"

run_taskctl lock-acquire "$valid_task_id" fe scripts/taskctl.sh >/dev/null
status_output="$(run_taskctl lock-status scripts/taskctl.sh)"
require_contains "$status_output" "status: locked" "lock-status locked state"
status_payload="$(printf '%s\n' "$status_output" | awk 'capture {print} /^status: locked$/ {capture=1; next}')"
if [[ -z "$status_payload" ]]; then
  echo "lock-status did not return a JSON payload for locked state" >&2
  exit 1
fi
if ! printf '%s\n' "$status_payload" | jq -e --arg task_id "$valid_task_id" '.task_id == $task_id and .owner_agent == "fe"' >/dev/null; then
  echo "lock-status payload missing expected holder fields" >&2
  echo "$status_output" >&2
  exit 1
fi

conflict_task_id="taskctl-lock-conflict-$(date +%s)-$$"
set +e
conflict_output="$(run_taskctl lock-acquire "$conflict_task_id" be scripts/taskctl.sh 2>&1)"
conflict_rc=$?
set -e

if [[ "$conflict_rc" -ne 2 ]]; then
  echo "expected lock conflict exit code 2, got: $conflict_rc" >&2
  echo "$conflict_output" >&2
  exit 1
fi
require_contains "$conflict_output" "lock conflict" "lock conflict message"

run_taskctl lock-release "$valid_task_id" fe scripts/taskctl.sh >/dev/null
status_after_release="$(run_taskctl lock-status scripts/taskctl.sh)"
require_contains "$status_after_release" "status: unlocked" "lock-status unlocked after release"

stale_task_id="taskctl-lock-stale-$(date +%s)-$$"
fresh_task_id="taskctl-lock-fresh-$(date +%s)-$$"
run_taskctl lock-acquire "$stale_task_id" fe docs/stale-lock.md >/dev/null
run_taskctl lock-acquire "$fresh_task_id" fe docs/fresh-lock.md >/dev/null

stale_status="$(run_taskctl lock-status docs/stale-lock.md)"
stale_lock_file="$(printf '%s\n' "$stale_status" | sed -n 's/^lock_file: //p' | head -n1)"
if [[ -z "$stale_lock_file" || ! -f "$stale_lock_file" ]]; then
  echo "failed to resolve stale lock file path" >&2
  exit 1
fi

tmp_lock_payload="$(mktemp)"
trap 'rm -rf "$smoke_root"; rm -f "$tmp_frontmatter" "$tmp_lock_payload"' EXIT
jq '.heartbeat_at = "1970-01-01T00:00:00+0000"' "$stale_lock_file" >"$tmp_lock_payload"
mv "$tmp_lock_payload" "$stale_lock_file"

set +e
denied_output="$(run_taskctl_as fe lock-clean-stale --ttl 60 2>&1)"
denied_rc=$?
set -e

if [[ "$denied_rc" -eq 0 ]]; then
  echo "expected non-orchestrator stale-lock reap to fail" >&2
  exit 1
fi
require_contains "$denied_output" "lock-clean-stale denied" "non-orchestrator stale-lock reap denied"

clean_output="$(run_taskctl_as coordinator lock-clean-stale --ttl 60)"
require_contains "$clean_output" "removed=1" "stale lock removed"
require_contains "$clean_output" "actor_agent=coordinator" "stale lock cleanup actor reflected"

audit_report_file="$(printf '%s\n' "$clean_output" | sed -n 's/^reaped lock: .* audit_report=\(.*\)$/\1/p' | head -n1)"
if [[ -z "$audit_report_file" || ! -f "$audit_report_file" ]]; then
  echo "expected audit report for reaped stale lock" >&2
  echo "$clean_output" >&2
  exit 1
fi

audit_content="$(cat "$audit_report_file")"
require_contains "$audit_content" "- action: lock-clean-stale" "audit action marker"
require_contains "$audit_content" "- actor_agent: coordinator" "audit actor marker"
require_contains "$audit_content" "- canonical_target: docs/stale-lock.md" "audit canonical target marker"

stale_after_clean="$(run_taskctl lock-status docs/stale-lock.md)"
fresh_after_clean="$(run_taskctl lock-status docs/fresh-lock.md)"
require_contains "$stale_after_clean" "status: unlocked" "stale lock cleaned"
require_contains "$fresh_after_clean" "status: locked" "fresh lock preserved"

echo "taskctl lock contract checks passed: $TASKCTL"
