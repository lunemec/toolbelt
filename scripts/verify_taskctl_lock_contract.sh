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

abs_path() {
  local path="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath -m "$path"
  else
    readlink -f "$path"
  fi
}

canonicalize_target_path() {
  local target="$1"
  [[ -n "$target" ]] || {
    echo "target path must not be empty" >&2
    exit 1
  }

  local absolute_target
  if [[ "$target" == /* ]]; then
    absolute_target="$(abs_path "$target")"
  else
    absolute_target="$(abs_path "/workspace/$target")"
  fi

  [[ "$absolute_target" == "/workspace" || "$absolute_target" == /workspace/* ]] || {
    echo "target must resolve under /workspace: $target" >&2
    exit 1
  }

  if [[ "$absolute_target" == "/workspace" ]]; then
    printf '.'
  else
    printf '%s' "${absolute_target#/workspace/}"
  fi
}

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

assert_write_targets_exact() {
  local yaml_file="$1"
  shift
  local -a expected_targets=("$@")
  local expected_json

  if (( ${#expected_targets[@]} == 0 )); then
    expected_json='[]'
  else
    expected_json="$(printf '%s\n' "${expected_targets[@]}" | jq -R . | jq -cs 'sort')"
  fi

  if ! yq -c '.intended_write_targets // []' "$yaml_file" | jq -e --argjson expected "$expected_json" 'type == "array" and (sort == $expected)' >/dev/null; then
    echo "write-target assertion failed for $yaml_file" >&2
    echo "expected(sorted): $expected_json" >&2
    echo "actual:" >&2
    yq -c '.intended_write_targets // []' "$yaml_file" >&2 || true
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

run_taskctl_with_coding_owner_lanes() {
  local coding_owner_lanes="$1"
  shift
  TASK_ROOT_DIR="$smoke_root" TASK_CODING_OWNER_LANES="$coding_owner_lanes" "$TASKCTL" "$@"
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

env_required_task_id="taskctl-lock-env-required-$(date +%s)-$$"
set +e
env_required_output="$(run_taskctl_with_coding_owner_lanes "qa" create "$env_required_task_id" "Env-configured coding-owner lane requires write targets" --to qa --from pm --priority 50 2>&1)"
env_required_rc=$?
set -e

if [[ "$env_required_rc" -eq 0 ]]; then
  echo "expected env-configured coding-owner lane validation failure without write targets" >&2
  exit 1
fi
require_contains "$env_required_output" "require non-empty intended_write_targets" "env coding-owner write-target validation"

env_nonrequired_task_id="taskctl-lock-env-nonrequired-$(date +%s)-$$"
run_taskctl_with_coding_owner_lanes "qa" create "$env_nonrequired_task_id" "Env-configured non-lane owner allows empty write targets" --to be --from pm --priority 51 >/dev/null
env_nonrequired_task="$smoke_root/inbox/be/051/${env_nonrequired_task_id}.md"
if [[ ! -f "$env_nonrequired_task" ]]; then
  echo "expected env non-lane no-target task file not found: $env_nonrequired_task" >&2
  exit 1
fi
extract_frontmatter "$env_nonrequired_task" "$tmp_frontmatter"
assert_write_targets_exact "$tmp_frontmatter"

cli_required_task_id="taskctl-lock-cli-required-$(date +%s)-$$"
set +e
cli_required_output="$(run_taskctl_with_coding_owner_lanes "qa" create "$cli_required_task_id" "CLI coding-owner lanes override env write-target requirement" --to be --from pm --priority 52 --coding-owner-lanes be 2>&1)"
cli_required_rc=$?
set -e

if [[ "$cli_required_rc" -eq 0 ]]; then
  echo "expected CLI coding-owner override validation failure without write targets" >&2
  exit 1
fi
require_contains "$cli_required_output" "require non-empty intended_write_targets" "CLI coding-owner write-target validation"

valid_task_id="taskctl-lock-valid-$(date +%s)-$$"
run_taskctl create "$valid_task_id" "Lock metadata create smoke" --to fe --from pm --priority 50 --write-target scripts/taskctl.sh >/dev/null

created_task="$smoke_root/inbox/fe/050/${valid_task_id}.md"
if [[ ! -f "$created_task" ]]; then
  echo "expected created task file not found: $created_task" >&2
  exit 1
fi

extract_frontmatter "$created_task" "$tmp_frontmatter"
expected_fe_task_target="$(canonicalize_target_path "$smoke_root/in_progress/fe/${valid_task_id}.md")"
assert_write_targets_exact "$tmp_frontmatter" "scripts/taskctl.sh" "$expected_fe_task_target"

noncoding_task_id="taskctl-lock-pm-no-target-$(date +%s)-$$"
run_taskctl create "$noncoding_task_id" "Non-coding task allows empty write targets" --to pm --from pm --priority 50 >/dev/null
noncoding_task="$smoke_root/inbox/pm/050/${noncoding_task_id}.md"
if [[ ! -f "$noncoding_task" ]]; then
  echo "expected non-coding task file not found: $noncoding_task" >&2
  exit 1
fi
extract_frontmatter "$noncoding_task" "$tmp_frontmatter"
assert_write_targets_exact "$tmp_frontmatter"

delegated_task_id="taskctl-lock-delegate-be-$(date +%s)-$$"
run_taskctl delegate pm be "$delegated_task_id" "Delegate coding task with auto self target" --priority 40 --write-target scripts/verify_taskctl_lock_contract.sh >/dev/null
delegated_task="$smoke_root/inbox/be/040/${delegated_task_id}.md"
if [[ ! -f "$delegated_task" ]]; then
  echo "expected delegated task file not found: $delegated_task" >&2
  exit 1
fi
extract_frontmatter "$delegated_task" "$tmp_frontmatter"
expected_be_task_target="$(canonicalize_target_path "$smoke_root/in_progress/be/${delegated_task_id}.md")"
assert_write_targets_exact "$tmp_frontmatter" "scripts/verify_taskctl_lock_contract.sh" "$expected_be_task_target"

env_lane_task_id="taskctl-lock-env-qa-$(date +%s)-$$"
run_taskctl_with_coding_owner_lanes "qa" create "$env_lane_task_id" "Env-configured coding-owner lane adds QA self target" --to qa --from pm --priority 41 --write-target scripts/taskctl.sh >/dev/null
env_lane_task="$smoke_root/inbox/qa/041/${env_lane_task_id}.md"
if [[ ! -f "$env_lane_task" ]]; then
  echo "expected env-configured task file not found: $env_lane_task" >&2
  exit 1
fi
extract_frontmatter "$env_lane_task" "$tmp_frontmatter"
expected_env_qa_target="$(canonicalize_target_path "$smoke_root/in_progress/qa/${env_lane_task_id}.md")"
assert_write_targets_exact "$tmp_frontmatter" "scripts/taskctl.sh" "$expected_env_qa_target"

env_nonlane_task_id="taskctl-lock-env-be-no-self-$(date +%s)-$$"
run_taskctl_with_coding_owner_lanes "qa" create "$env_nonlane_task_id" "Env-configured coding-owner lanes exclude BE self target" --to be --from pm --priority 42 --write-target scripts/taskctl.sh >/dev/null
env_nonlane_task="$smoke_root/inbox/be/042/${env_nonlane_task_id}.md"
if [[ ! -f "$env_nonlane_task" ]]; then
  echo "expected env non-lane task file not found: $env_nonlane_task" >&2
  exit 1
fi
extract_frontmatter "$env_nonlane_task" "$tmp_frontmatter"
assert_write_targets_exact "$tmp_frontmatter" "scripts/taskctl.sh"

env_assign_task_id="taskctl-lock-env-assign-prune-$(date +%s)-$$"
run_taskctl_with_coding_owner_lanes "qa,be" create "$env_assign_task_id" "Env-configured assign prunes stale coding-owner self target" --to qa --from pm --priority 43 --write-target scripts/taskctl.sh >/dev/null
env_assign_src_task="$smoke_root/inbox/qa/043/${env_assign_task_id}.md"
if [[ ! -f "$env_assign_src_task" ]]; then
  echo "expected env assign source task file not found: $env_assign_src_task" >&2
  exit 1
fi
extract_frontmatter "$env_assign_src_task" "$tmp_frontmatter"
expected_env_assign_qa_target="$(canonicalize_target_path "$smoke_root/in_progress/qa/${env_assign_task_id}.md")"
assert_write_targets_exact "$tmp_frontmatter" "scripts/taskctl.sh" "$expected_env_assign_qa_target"

run_taskctl_with_coding_owner_lanes "qa,be" assign "$env_assign_task_id" be >/dev/null
env_assign_dst_task="$smoke_root/inbox/be/043/${env_assign_task_id}.md"
if [[ ! -f "$env_assign_dst_task" ]]; then
  echo "expected env assign destination task file not found: $env_assign_dst_task" >&2
  exit 1
fi
extract_frontmatter "$env_assign_dst_task" "$tmp_frontmatter"
expected_env_assign_be_target="$(canonicalize_target_path "$smoke_root/in_progress/be/${env_assign_task_id}.md")"
assert_write_targets_exact "$tmp_frontmatter" "scripts/taskctl.sh" "$expected_env_assign_be_target"

cli_override_task_id="taskctl-lock-cli-overrides-env-$(date +%s)-$$"
run_taskctl_with_coding_owner_lanes "qa" create "$cli_override_task_id" "CLI coding-owner lanes override env config" --to be --from pm --priority 44 --write-target scripts/taskctl.sh --coding-owner-lanes be >/dev/null
cli_override_task="$smoke_root/inbox/be/044/${cli_override_task_id}.md"
if [[ ! -f "$cli_override_task" ]]; then
  echo "expected CLI-override task file not found: $cli_override_task" >&2
  exit 1
fi
extract_frontmatter "$cli_override_task" "$tmp_frontmatter"
expected_cli_override_be_target="$(canonicalize_target_path "$smoke_root/in_progress/be/${cli_override_task_id}.md")"
assert_write_targets_exact "$tmp_frontmatter" "scripts/taskctl.sh" "$expected_cli_override_be_target"

assign_refresh_task_id="taskctl-lock-assign-refresh"
run_taskctl create "$assign_refresh_task_id" "Assign refreshes coding-owner self target" --to fe --from pm --priority 70 --write-target scripts/taskctl.sh >/dev/null
assign_refresh_src_task="$smoke_root/inbox/fe/070/${assign_refresh_task_id}.md"
if [[ ! -f "$assign_refresh_src_task" ]]; then
  echo "expected assign-source task file not found: $assign_refresh_src_task" >&2
  exit 1
fi
extract_frontmatter "$assign_refresh_src_task" "$tmp_frontmatter"
expected_assign_refresh_fe_target="$(canonicalize_target_path "$smoke_root/in_progress/fe/${assign_refresh_task_id}.md")"
assert_write_targets_exact "$tmp_frontmatter" "scripts/taskctl.sh" "$expected_assign_refresh_fe_target"

run_taskctl assign "$assign_refresh_task_id" be >/dev/null
assign_refresh_dst_task="$smoke_root/inbox/be/070/${assign_refresh_task_id}.md"
if [[ ! -f "$assign_refresh_dst_task" ]]; then
  echo "expected reassigned coding-owner task file not found: $assign_refresh_dst_task" >&2
  exit 1
fi
extract_frontmatter "$assign_refresh_dst_task" "$tmp_frontmatter"
expected_assign_refresh_be_target="$(canonicalize_target_path "$smoke_root/in_progress/be/${assign_refresh_task_id}.md")"
assert_write_targets_exact "$tmp_frontmatter" "scripts/taskctl.sh" "$expected_assign_refresh_be_target"

assign_noncoding_task_id="taskctl-lock-assign-noncoding"
run_taskctl create "$assign_noncoding_task_id" "Assign keeps non-coding target metadata stable" --to be --from pm --priority 71 --write-target scripts/taskctl.sh >/dev/null
assign_noncoding_src_task="$smoke_root/inbox/be/071/${assign_noncoding_task_id}.md"
if [[ ! -f "$assign_noncoding_src_task" ]]; then
  echo "expected non-coding assign-source task file not found: $assign_noncoding_src_task" >&2
  exit 1
fi
extract_frontmatter "$assign_noncoding_src_task" "$tmp_frontmatter"
expected_assign_noncoding_be_target="$(canonicalize_target_path "$smoke_root/in_progress/be/${assign_noncoding_task_id}.md")"
assert_write_targets_exact "$tmp_frontmatter" "scripts/taskctl.sh" "$expected_assign_noncoding_be_target"

run_taskctl assign "$assign_noncoding_task_id" pm >/dev/null
assign_noncoding_dst_task="$smoke_root/inbox/pm/071/${assign_noncoding_task_id}.md"
if [[ ! -f "$assign_noncoding_dst_task" ]]; then
  echo "expected reassigned non-coding task file not found: $assign_noncoding_dst_task" >&2
  exit 1
fi
extract_frontmatter "$assign_noncoding_dst_task" "$tmp_frontmatter"
assert_write_targets_exact "$tmp_frontmatter" "scripts/taskctl.sh" "$expected_assign_noncoding_be_target"

assign_multihop_task_id="taskctl-lock-assign-multihop"
run_taskctl create "$assign_multihop_task_id" "Assign prunes stale coding-owner self targets across multi-hop transitions" --to be --from pm --priority 72 --write-target scripts/taskctl.sh >/dev/null
assign_multihop_src_task="$smoke_root/inbox/be/072/${assign_multihop_task_id}.md"
if [[ ! -f "$assign_multihop_src_task" ]]; then
  echo "expected multi-hop assign-source task file not found: $assign_multihop_src_task" >&2
  exit 1
fi
extract_frontmatter "$assign_multihop_src_task" "$tmp_frontmatter"
expected_assign_multihop_be_target="$(canonicalize_target_path "$smoke_root/in_progress/be/${assign_multihop_task_id}.md")"
assert_write_targets_exact "$tmp_frontmatter" "scripts/taskctl.sh" "$expected_assign_multihop_be_target"

run_taskctl assign "$assign_multihop_task_id" pm >/dev/null
assign_multihop_mid_task="$smoke_root/inbox/pm/072/${assign_multihop_task_id}.md"
if [[ ! -f "$assign_multihop_mid_task" ]]; then
  echo "expected multi-hop mid-hop non-coding task file not found: $assign_multihop_mid_task" >&2
  exit 1
fi
extract_frontmatter "$assign_multihop_mid_task" "$tmp_frontmatter"
assert_write_targets_exact "$tmp_frontmatter" "scripts/taskctl.sh" "$expected_assign_multihop_be_target"

run_taskctl assign "$assign_multihop_task_id" fe >/dev/null
assign_multihop_dst_task="$smoke_root/inbox/fe/072/${assign_multihop_task_id}.md"
if [[ ! -f "$assign_multihop_dst_task" ]]; then
  echo "expected multi-hop reassigned coding-owner task file not found: $assign_multihop_dst_task" >&2
  exit 1
fi
extract_frontmatter "$assign_multihop_dst_task" "$tmp_frontmatter"
expected_assign_multihop_fe_target="$(canonicalize_target_path "$smoke_root/in_progress/fe/${assign_multihop_task_id}.md")"
assert_write_targets_exact "$tmp_frontmatter" "scripts/taskctl.sh" "$expected_assign_multihop_fe_target"

run_taskctl claim be >/dev/null
claimed_task="$smoke_root/in_progress/be/${delegated_task_id}.md"
if [[ ! -f "$claimed_task" ]]; then
  echo "expected claimed delegated task not found in progress: $claimed_task" >&2
  exit 1
fi
extract_frontmatter "$claimed_task" "$tmp_frontmatter"
assert_write_targets_exact "$tmp_frontmatter" "scripts/verify_taskctl_lock_contract.sh" "$expected_be_task_target"

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
