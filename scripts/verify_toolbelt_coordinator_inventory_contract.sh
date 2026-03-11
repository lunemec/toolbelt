#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVAL_NOTE='> Archival note: This spec package records the pre-extraction in-repo coordinator model.'

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local context="$3"

  [[ "${haystack}" == *"${needle}"* ]] || fail "${context}: missing '${needle}'"
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local context="$3"

  [[ "${haystack}" != *"${needle}"* ]] || fail "${context}: unexpectedly found '${needle}'"
}

check_absent_path() {
  local rel_path="$1"

  [[ ! -e "${REPO_ROOT}/${rel_path}" ]] || fail "expected '${rel_path}' to be absent from toolbelt"

  if git -C "${REPO_ROOT}" ls-files --error-unmatch "${rel_path}" >/dev/null 2>&1; then
    fail "expected '${rel_path}' to be removed from git tracking"
  fi
}

assert_allowed_reference_path() {
  local rel_path="$1"

  case "${rel_path}" in
    AGENTS.md|CHANGELOG.md|README.md|container/codex-entrypoint.sh|container/codex-init-workspace.sh|scripts/verify_toolbelt_coordinator_boundary_contract.sh|scripts/verify_toolbelt_coordinator_inventory_contract.sh|specs/orchestrator-requirements-clarification/*)
      return 0
      ;;
  esac

  fail "unexpected live coordinator reference in '${rel_path}'"
}

check_archival_specs() {
  local spec_file
  while IFS= read -r spec_file; do
    local rel_path="${spec_file#${REPO_ROOT}/}"
    local header
    header="$(sed -n '1,3p' "${spec_file}")"
    assert_contains "${header}" "${ARCHIVAL_NOTE}" "${rel_path} archival banner"
    assert_contains "${header}" '/workspace/coordinator' "${rel_path} archival destination"
  done < <(find "${REPO_ROOT}/specs/orchestrator-requirements-clarification" -type f | sort)
}

check_reference_allowlist() {
  local ref_paths=()
  local rel_path
  while IFS= read -r rel_path; do
    [[ -n "${rel_path}" ]] || continue
    ref_paths+=("${rel_path}")
    assert_allowed_reference_path "${rel_path}"
  done < <(
    git -C "${REPO_ROOT}" grep -l -I \
      -e 'coordination/' \
      -e '/workspace/coordinator' \
      -e 'standalone coordinator' \
      -e 'coordinator assets' \
      -- .
  )

  [[ "${#ref_paths[@]}" -gt 0 ]] || fail "expected at least one retained coordinator reference"
}

check_absent_path "coordination"
check_absent_path "scripts/taskctl.sh"
check_absent_path "scripts/agent_worker.sh"
check_absent_path "scripts/agents_ctl.sh"
check_absent_path "scripts/coordination_repair.sh"
check_absent_path "scripts/verify_agent_worker_lock_contract.sh"
check_absent_path "scripts/verify_agent_worker_reasoning_contract.sh"
check_absent_path "scripts/verify_benchmark_contract.sh"
check_absent_path "scripts/verify_clarification_workflow_contract.sh"
check_absent_path "scripts/verify_coordination_repair_contract.sh"
check_absent_path "scripts/verify_coordinator_instructions_contract.sh"
check_absent_path "scripts/verify_orchestrator_clarification_suite.sh"
check_absent_path "scripts/verify_task_done_contract.sh"
check_absent_path "scripts/verify_task_local_prompt_contract.sh"
check_absent_path "scripts/verify_task_template_lock_metadata_contract.sh"
check_absent_path "scripts/verify_taskctl_lock_contract.sh"
check_absent_path "scripts/verify_top_level_prompt_contract.sh"

GITIGNORE_TEXT="$(cat "${REPO_ROOT}/.gitignore")"
assert_not_contains "${GITIGNORE_TEXT}" 'coordination/runtime/logs/' ".gitignore coordinator log ignore"
assert_not_contains "${GITIGNORE_TEXT}" 'coordination/runtime/pids/' ".gitignore coordinator pid ignore"

check_archival_specs
check_reference_allowlist

printf 'PASS: toolbelt coordinator inventory contract\n'
