#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
COORDINATOR_PROMPT_PATH="${TMP_ROOT}/coordinator/coordination/prompts/TOP_LEVEL_AGENT_PROMPT.md"
COORDINATOR_PROMPT_BACKUP=""

cleanup() {
  if [[ -n "${COORDINATOR_PROMPT_BACKUP}" && -f "${COORDINATOR_PROMPT_BACKUP}" ]]; then
    mv "${COORDINATOR_PROMPT_BACKUP}" "${COORDINATOR_PROMPT_PATH}"
  fi
  rm -rf "${TMP_ROOT}"
}

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

canonical_path() {
  local path="$1"

  if [[ -d "${path}" ]]; then
    (
      cd "${path}" >/dev/null 2>&1
      pwd -P
    )
    return 0
  fi

  if command -v realpath >/dev/null 2>&1; then
    if realpath -m / >/dev/null 2>&1; then
      realpath -m "${path}"
    else
      realpath "${path}"
    fi
    return 0
  fi

  printf '%s\n' "${path}"
}

write_fake_docker() {
  local path="$1"

  cat >"${path}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"${FAKE_DOCKER_LOG:?}"

case "${1:-}" in
  info|run)
    exit 0
    ;;
esac

printf 'unexpected docker invocation: %s\n' "$*" >&2
exit 1
EOF
}

run_toolbelt_case() {
  local scenario="$1"
  shift

  local scenario_root="${TMP_ROOT}/${scenario}"
  local fakebin="${scenario_root}/bin"
  local workdir="${scenario_root}/cwd"
  local stdout_path="${scenario_root}/stdout.log"
  local stderr_path="${scenario_root}/stderr.log"

  mkdir -p "${fakebin}" "${workdir}" "${scenario_root}/home"

  write_fake_docker "${fakebin}/docker"
  chmod +x "${fakebin}/docker"

  set +e
  (
    cd "${workdir}"
    PATH="${fakebin}:${PATH}" \
    HOME="${scenario_root}/home" \
    FAKE_DOCKER_LOG="${scenario_root}/docker.log" \
    bash "${REPO_ROOT}/scripts/toolbelt.sh" "$@" >"${stdout_path}" 2>"${stderr_path}"
  )
  CASE_STATUS=$?
  set -e

  CASE_STDOUT="$(cat "${stdout_path}")"
  CASE_STDERR="$(cat "${stderr_path}")"
  if [[ -f "${scenario_root}/docker.log" ]]; then
    CASE_DOCKER_LOG="$(cat "${scenario_root}/docker.log")"
  else
    CASE_DOCKER_LOG=""
  fi
}

write_entrypoint_harness() {
  local path="$1"

  cat >"${path}" <<EOF
#!/usr/bin/env bash
set -euo pipefail

source <(sed \
  -e '/^bootstrap_codex_home\$/,\$d' \
  -e 's|if \[\[ -f /workspace/coordinator/coordination/prompts/TOP_LEVEL_AGENT_PROMPT.md \]\]; then|if [[ -f "\${TEST_COORDINATOR_PROMPT_PATH:?missing TEST_COORDINATOR_PROMPT_PATH}" ]]; then|' \
  "${REPO_ROOT}/container/codex-entrypoint.sh")
show_motd "\$@"
EOF

  chmod +x "${path}"
}

capture_pty_output() {
  local output_path="$1"
  shift

  python3 - "${output_path}" "$@" <<'PY'
import os
import pty
import sys

output_path = sys.argv[1]
cmd = sys.argv[2:]

master_fd, slave_fd = pty.openpty()
pid = os.fork()
if pid == 0:
    os.setsid()
    os.close(master_fd)
    os.dup2(slave_fd, 0)
    os.dup2(slave_fd, 1)
    os.dup2(slave_fd, 2)
    if slave_fd > 2:
        os.close(slave_fd)
    os.execvp(cmd[0], cmd)

os.close(slave_fd)
chunks = []
while True:
    try:
        data = os.read(master_fd, 4096)
    except OSError:
        break
    if not data:
        break
    chunks.append(data)

_, status = os.waitpid(pid, 0)
if hasattr(os, "waitstatus_to_exitcode"):
    rc = os.waitstatus_to_exitcode(status)
else:
    rc = os.WEXITSTATUS(status)

with open(output_path, "wb") as handle:
    handle.write(b"".join(chunks))

sys.exit(rc)
PY
}

run_entrypoint_case() {
  local scenario="$1"
  local harness_path="$2"
  local output_path="${TMP_ROOT}/${scenario}.pty.log"

  set +e
  capture_pty_output "${output_path}" env NO_COLOR=1 TEST_COORDINATOR_PROMPT_PATH="${COORDINATOR_PROMPT_PATH}" bash "${harness_path}" bash
  CASE_STATUS=$?
  set -e

  CASE_PTY_OUTPUT="$(python3 - "${output_path}" <<'PY'
import pathlib
import sys

print(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace").replace("\r", ""))
PY
)"
}

restore_coordinator_prompt() {
  if [[ -n "${COORDINATOR_PROMPT_BACKUP}" && -f "${COORDINATOR_PROMPT_BACKUP}" ]]; then
    mv "${COORDINATOR_PROMPT_BACKUP}" "${COORDINATOR_PROMPT_PATH}"
    COORDINATOR_PROMPT_BACKUP=""
  fi
}

hide_coordinator_prompt() {
  [[ -f "${COORDINATOR_PROMPT_PATH}" ]] || fail "expected coordinator prompt at ${COORDINATOR_PROMPT_PATH}"

  COORDINATOR_PROMPT_BACKUP="${TMP_ROOT}/TOP_LEVEL_AGENT_PROMPT.md.backup"
  mv "${COORDINATOR_PROMPT_PATH}" "${COORDINATOR_PROMPT_BACKUP}"
}

run_init_case() {
  local scenario="$1"
  shift

  local scenario_root="${TMP_ROOT}/${scenario}"
  local stdout_path="${scenario_root}/stdout.log"
  local stderr_path="${scenario_root}/stderr.log"

  mkdir -p "${scenario_root}"

  set +e
  bash "${REPO_ROOT}/container/codex-init-workspace.sh" "$@" >"${stdout_path}" 2>"${stderr_path}"
  CASE_STATUS=$?
  set -e

  CASE_STDOUT="$(cat "${stdout_path}")"
  CASE_STDERR="$(cat "${stderr_path}")"
}

trap cleanup EXIT

mkdir -p "$(dirname "${COORDINATOR_PROMPT_PATH}")"
printf '# test coordinator prompt\n' >"${COORDINATOR_PROMPT_PATH}"

README_TEXT="$(cat "${REPO_ROOT}/README.md")"
assert_contains "${README_TEXT}" 'coordinator/orchestration source of truth lives in the standalone `/workspace/coordinator` repository for this phase' "README top-level boundary"
assert_contains "${README_TEXT}" 'hard cutover is complete; `toolbelt` only references the external coordinator checkout' "README steady-state boundary"
assert_contains "${README_TEXT}" 'compatibility redirect and never seeds or repairs coordinator assets' "README codex-init redirect"
assert_contains "${README_TEXT}" 'a host path whose basename is `coordinator` mounts to `/workspace/coordinator`' "README mount contract"
assert_not_contains "${README_TEXT}" 'integration is deferred' "README stale status"
assert_not_contains "${README_TEXT}" 'during this migration' "README stale migration wording"
assert_not_contains "${README_TEXT}" 'intentionally left as a TODO' "README stale TODO wording"

run_toolbelt_case default-mount
[[ "${CASE_STATUS}" -eq 0 ]] || fail "default mount should succeed"
assert_contains "${CASE_DOCKER_LOG}" "-v $(canonical_path "${TMP_ROOT}/default-mount/cwd"):/workspace" "default mount docker args"

mkdir -p "${TMP_ROOT}/mounts/coordinator"
run_toolbelt_case coordinator-mount "${TMP_ROOT}/mounts/coordinator"
[[ "${CASE_STATUS}" -eq 0 ]] || fail "coordinator mount should succeed"
assert_contains "${CASE_DOCKER_LOG}" "-v $(canonical_path "${TMP_ROOT}/mounts/coordinator"):/workspace/coordinator" "coordinator mount docker args"

mkdir -p "${TMP_ROOT}/collision/a/coordinator" "${TMP_ROOT}/collision/b/coordinator"
run_toolbelt_case collision "${TMP_ROOT}/collision/a/coordinator" "${TMP_ROOT}/collision/b/coordinator"
[[ "${CASE_STATUS}" -ne 0 ]] || fail "basename collision should fail"
assert_contains "${CASE_STDERR}" "mount destination collision at /workspace/coordinator" "collision stderr"
assert_contains "${CASE_STDERR}" "use paths with unique basenames" "collision remediation"
assert_not_contains "${CASE_DOCKER_LOG}" "run" "collision docker launch"

ENTRYPOINT_HARNESS="${TMP_ROOT}/show-motd-harness.sh"
write_entrypoint_harness "${ENTRYPOINT_HARNESS}"

run_entrypoint_case coordinator-present "${ENTRYPOINT_HARNESS}"
[[ "${CASE_STATUS}" -eq 0 ]] || fail "entrypoint present case should succeed"
assert_contains "${CASE_PTY_OUTPUT}" "External coordinator checkout detected at /workspace/coordinator." "entrypoint present message"
assert_contains "${CASE_PTY_OUTPUT}" 'codex "$(cat /workspace/coordinator/coordination/prompts/TOP_LEVEL_AGENT_PROMPT.md)"' "entrypoint prompt command"

hide_coordinator_prompt
run_entrypoint_case coordinator-missing "${ENTRYPOINT_HARNESS}"
restore_coordinator_prompt
[[ "${CASE_STATUS}" -eq 0 ]] || fail "entrypoint missing case should succeed"
assert_contains "${CASE_PTY_OUTPUT}" "No standalone coordinator checkout detected at /workspace/coordinator." "entrypoint missing message"
assert_contains "${CASE_PTY_OUTPUT}" "Toolbelt does not embed coordinator assets; mount or clone the standalone repository there if you need orchestration flows." "entrypoint missing remediation"
assert_not_contains "${CASE_PTY_OUTPUT}" 'codex "$(cat /workspace/coordinator/coordination/prompts/TOP_LEVEL_AGENT_PROMPT.md)"' "entrypoint missing command"

run_init_case init-redirect --workspace /tmp/toolbelt-step5
[[ "${CASE_STATUS}" -eq 1 ]] || fail "codex-init-workspace redirect should exit 1"
assert_contains "${CASE_STDERR}" "codex-init-workspace is a compatibility redirect in toolbelt." "codex-init stderr"
assert_contains "${CASE_STDERR}" "Toolbelt no longer seeds coordinator assets; use the standalone /workspace/coordinator repository." "codex-init repo guidance"
assert_contains "${CASE_STDOUT}" "Requested workspace: /tmp/toolbelt-step5" "codex-init workspace echo"
assert_contains "${CASE_STDOUT}" "Next step: mount or clone coordinator at /workspace/coordinator and run its scripts directly." "codex-init next step"
assert_not_contains "${CASE_STDERR}${CASE_STDOUT}" "TODO" "codex-init stale todo"
assert_not_contains "${CASE_STDERR}${CASE_STDOUT}" "seed /workspace" "codex-init stale seeding"

run_init_case init-quiet --workspace /tmp/toolbelt-step5 --quiet
[[ "${CASE_STATUS}" -eq 1 ]] || fail "codex-init-workspace quiet redirect should exit 1"
assert_contains "${CASE_STDERR}" "codex-init-workspace is a compatibility redirect in toolbelt." "codex-init quiet stderr"
assert_contains "${CASE_STDERR}" "Toolbelt no longer seeds coordinator assets; use the standalone /workspace/coordinator repository." "codex-init quiet repo guidance"
assert_not_contains "${CASE_STDOUT}" "Requested workspace" "codex-init quiet stdout"
assert_not_contains "${CASE_STDOUT}" "Next step:" "codex-init quiet next step"

printf 'verify_toolbelt_coordinator_boundary_contract: ok\n'
