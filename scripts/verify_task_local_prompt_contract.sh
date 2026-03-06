#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
WORKDIR="$(mktemp -d "$WORKSPACE_ROOT/.verify-task-local-prompt.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! rg -q --fixed-strings "$pattern" "$file"; then
    echo "$message" >&2
    exit 1
  fi
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if rg -q --fixed-strings "$pattern" "$file"; then
    echo "$message" >&2
    exit 1
  fi
}

heading_line() {
  local file="$1"
  local heading="$2"
  rg -n "^## ${heading}\$" "$file" | head -n1 | cut -d: -f1
}

run_worker_once_capture_prompt() {
  local case_root="$1"
  local prompt_capture="$2"
  (
    cd "$case_root"
    AGENT_ROOT_DIR="$case_root/coordination" \
    AGENT_TASKCTL="$case_root/bin/taskctl_stub.sh" \
    PROMPT_CAPTURE="$prompt_capture" \
    AGENT_EXEC_CMD='cat > "$PROMPT_CAPTURE"' \
    "$WORKSPACE_ROOT/scripts/agent_worker.sh" be --once >/dev/null
  )
}

setup_taskctl_stub() {
  local case_root="$1"
  mkdir -p "$case_root/bin"

  cat >"$case_root/bin/taskctl_stub.sh" <<'EOF_TASKCTL'
#!/usr/bin/env bash
set -euo pipefail
cmd="${1:-}"
case "$cmd" in
  claim|done|verify-done|block|lock-acquire|lock-heartbeat|lock-release-task)
    exit 0
    ;;
  *)
    printf 'unsupported taskctl stub call: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF_TASKCTL
  chmod +x "$case_root/bin/taskctl_stub.sh"
}

CASE_A="$WORKDIR/case-a"
mkdir -p "$CASE_A/coordination/in_progress/be"
setup_taskctl_stub "$CASE_A"

cat >"$CASE_A/coordination/in_progress/be/case-a-task.md" <<'TASK'
---
id: case-a-task
owner_agent: be
creator_agent: pm
status: in_progress
priority: 1
intended_write_targets: ['scripts/case-a.txt']
---

## Prompt
EMBEDDED-PROMPT

## Context
EMBEDDED-CONTEXT

## Validation
EMBEDDED-VALIDATION

## Result
pending
TASK

mkdir -p "$CASE_A/coordination/task_prompts/case-a-task/prompt"
mkdir -p "$CASE_A/coordination/task_prompts/case-a-task/context"
mkdir -p "$CASE_A/coordination/task_prompts/case-a-task/deliverables"
mkdir -p "$CASE_A/coordination/task_prompts/case-a-task/validation"
mkdir -p "$CASE_A/coordination/roles"

cat >"$CASE_A/coordination/task_prompts/case-a-task/prompt/000.md" <<'EOF_PROMPT_000'
SIDECAR-PROMPT-000
EOF_PROMPT_000

cat >"$CASE_A/coordination/task_prompts/case-a-task/prompt/010.md" <<'EOF_PROMPT_010'
SIDECAR-PROMPT-010
EOF_PROMPT_010

cat >"$CASE_A/coordination/task_prompts/case-a-task/prompt/.hidden.md" <<'EOF_PROMPT_HIDDEN'
HIDDEN-SHOULD-BE-IGNORED
EOF_PROMPT_HIDDEN

cat >"$CASE_A/coordination/task_prompts/case-a-task/context/000.md" <<'EOF_CONTEXT_000'
   
EOF_CONTEXT_000

cat >"$CASE_A/coordination/task_prompts/case-a-task/context/notes.txt" <<'EOF_CONTEXT_NOTES'
TEXT-NOTES-SHOULD-BE-IGNORED
EOF_CONTEXT_NOTES

cat >"$CASE_A/coordination/task_prompts/case-a-task/deliverables/000.md" <<'EOF_DELIVERABLES_000'
   
EOF_DELIVERABLES_000

cat >"$CASE_A/coordination/task_prompts/case-a-task/validation/000.md" <<'EOF_VALIDATION_000'
SIDECAR-VALIDATION
EOF_VALIDATION_000

cat >"$CASE_A/coordination/roles/be.md" <<'EOF_ROLE'
ROLE-POISON-SHOULD-NOT-APPEAR
EOF_ROLE

PROMPT_A="$CASE_A/prompt-capture-a.txt"
run_worker_once_capture_prompt "$CASE_A" "$PROMPT_A"

assert_contains "$PROMPT_A" "## Prompt" "missing Prompt heading in assembled worker prompt"
assert_contains "$PROMPT_A" "## Context" "missing Context heading in assembled worker prompt"
assert_contains "$PROMPT_A" "## Deliverables" "missing Deliverables heading in assembled worker prompt"
assert_contains "$PROMPT_A" "## Validation" "missing Validation heading in assembled worker prompt"

prompt_line="$(heading_line "$PROMPT_A" "Prompt")"
context_line="$(heading_line "$PROMPT_A" "Context")"
deliverables_line="$(heading_line "$PROMPT_A" "Deliverables")"
validation_line="$(heading_line "$PROMPT_A" "Validation")"
(( prompt_line < context_line && context_line < deliverables_line && deliverables_line < validation_line )) || {
  echo "worker section order mismatch (expected Prompt -> Context -> Deliverables -> Validation)" >&2
  exit 1
}

sidecar_prompt_000_line="$(rg -n "SIDECAR-PROMPT-000" "$PROMPT_A" | head -n1 | cut -d: -f1)"
sidecar_prompt_010_line="$(rg -n "SIDECAR-PROMPT-010" "$PROMPT_A" | head -n1 | cut -d: -f1)"
(( sidecar_prompt_000_line < sidecar_prompt_010_line )) || {
  echo "sidecar prompt fragments were not concatenated in lexicographic order" >&2
  exit 1
}

assert_contains "$PROMPT_A" "SIDECAR-PROMPT-000" "sidecar prompt fragment 000 missing"
assert_contains "$PROMPT_A" "SIDECAR-PROMPT-010" "sidecar prompt fragment 010 missing"
assert_not_contains "$PROMPT_A" "EMBEDDED-PROMPT" "embedded prompt should not win when sidecar prompt section is populated"

assert_contains "$PROMPT_A" "EMBEDDED-CONTEXT" "embedded context fallback missing for empty sidecar context section"
assert_contains "$PROMPT_A" "MISSING SECTION: Deliverables" "missing deterministic sentinel for absent/empty Deliverables content"
assert_contains "$PROMPT_A" "SIDECAR-VALIDATION" "sidecar validation content missing"
assert_not_contains "$PROMPT_A" "EMBEDDED-VALIDATION" "embedded validation should not win when sidecar validation section is populated"

assert_not_contains "$PROMPT_A" "ROLE-POISON-SHOULD-NOT-APPEAR" "role file content leaked into worker runtime prompt"
assert_not_contains "$PROMPT_A" "HIDDEN-SHOULD-BE-IGNORED" "hidden sidecar markdown files should be ignored"
assert_not_contains "$PROMPT_A" "TEXT-NOTES-SHOULD-BE-IGNORED" "non-markdown sidecar files should be ignored"

CASE_B="$WORKDIR/case-b"
mkdir -p "$CASE_B/coordination/in_progress/be"
setup_taskctl_stub "$CASE_B"

cat >"$CASE_B/coordination/in_progress/be/case-b-task.md" <<'TASK'
---
id: case-b-task
owner_agent: be
creator_agent: pm
status: in_progress
priority: 1
intended_write_targets: ['scripts/case-b.txt']
---

## Prompt
LEGACY-PROMPT

## Context
LEGACY-CONTEXT

## Deliverables
LEGACY-DELIVERABLES

## Validation
LEGACY-VALIDATION

## Result
pending
TASK

PROMPT_B="$CASE_B/prompt-capture-b.txt"
run_worker_once_capture_prompt "$CASE_B" "$PROMPT_B"

assert_contains "$PROMPT_B" "LEGACY-PROMPT" "legacy fallback failed for Prompt section when sidecar is absent"
assert_contains "$PROMPT_B" "LEGACY-CONTEXT" "legacy fallback failed for Context section when sidecar is absent"
assert_contains "$PROMPT_B" "LEGACY-DELIVERABLES" "legacy fallback failed for Deliverables section when sidecar is absent"
assert_contains "$PROMPT_B" "LEGACY-VALIDATION" "legacy fallback failed for Validation section when sidecar is absent"
assert_not_contains "$PROMPT_B" "MISSING SECTION:" "legacy fallback should not emit sentinel when embedded sections exist"

echo "task-local prompt contract verified"
