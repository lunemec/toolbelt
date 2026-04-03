#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"

cleanup() {
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

write_fake_security() {
  local path="$1"

  cat >"${path}" <<'EOF'
#!/usr/bin/env bash
# Fake macOS security command -- always fails (no Keychain).
exit 1
EOF
}

run_toolbelt_case() {
  local scenario="$1"
  shift

  local scenario_root="${TMP_ROOT}/${scenario}"
  local fakebin="${scenario_root}/bin"
  local workdir="${scenario_root}/cwd"
  local home_dir="${scenario_root}/home"
  local stdout_path="${scenario_root}/stdout.log"
  local stderr_path="${scenario_root}/stderr.log"

  mkdir -p "${fakebin}" "${workdir}" "${home_dir}"

  write_fake_docker "${fakebin}/docker"
  chmod +x "${fakebin}/docker"

  write_fake_security "${fakebin}/security"
  chmod +x "${fakebin}/security"

  set +e
  (
    cd "${workdir}"
    export PATH="${fakebin}:${PATH}"
    export HOME="${home_dir}"
    export FAKE_DOCKER_LOG="${scenario_root}/docker.log"
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

trap cleanup EXIT

# --- Test 1: RO secret mount is present ---
mkdir -p "${TMP_ROOT}/ro-mount/home/.claude"
run_toolbelt_case ro-mount claude
[[ "${CASE_STATUS}" -eq 0 ]] || fail "ro-mount should succeed"
assert_contains "${CASE_DOCKER_LOG}" "/run/secrets/claude-config:ro" "RO secret mount"

# --- Test 2: No RW claude mount ---
assert_not_contains "${CASE_DOCKER_LOG}" "${HOME}/.claude " "no RW .claude mount (trailing space)"
# Ensure no mount to /.claude without :ro
if printf '%s\n' "${CASE_DOCKER_LOG}" | grep -qE '\.claude[^-]' | grep -v ':ro'; then
  # Double-check: any /.claude mount must have :ro
  while IFS= read -r line; do
    if [[ "${line}" == *"/.claude"* && "${line}" != *":ro"* && "${line}" != *"claude-config"* && "${line}" != *"claude-config.json"* && "${line}" != *"claude-credentials"* ]]; then
      fail "no-RW-mount: found RW claude mount: ${line}"
    fi
  done <<<"${CASE_DOCKER_LOG}"
fi

# --- Test 3: Env override with missing dir ---
run_toolbelt_case env-override-missing claude
[[ "${CASE_STATUS}" -eq 0 ]] || fail "missing claude dir should still succeed (no hard failure)"
# When ~/.claude/ does not exist, there should be no claude-config mount
assert_not_contains "${CASE_DOCKER_LOG}" "/run/secrets/claude-config" "missing dir skips claude mount"

# --- Test 4: TOOLBELT_CLAUDE_DIR_SRC override ---
mkdir -p "${TMP_ROOT}/env-override-custom/home"
custom_claude="${TMP_ROOT}/env-override-custom/claude-alt"
mkdir -p "${custom_claude}"
(
  cd "${TMP_ROOT}/env-override-custom"
  export TOOLBELT_CLAUDE_DIR_SRC="${custom_claude}"
  scenario_root="${TMP_ROOT}/env-override-custom"
  fakebin="${scenario_root}/bin"
  workdir="${scenario_root}/cwd"
  home_dir="${scenario_root}/home"
  mkdir -p "${fakebin}" "${workdir}"

  write_fake_docker "${fakebin}/docker"
  chmod +x "${fakebin}/docker"
  write_fake_security "${fakebin}/security"
  chmod +x "${fakebin}/security"

  export PATH="${fakebin}:${PATH}"
  export HOME="${home_dir}"
  export FAKE_DOCKER_LOG="${scenario_root}/docker.log"
  bash "${REPO_ROOT}/scripts/toolbelt.sh" claude >"${scenario_root}/stdout.log" 2>"${scenario_root}/stderr.log" || true
)
CASE_DOCKER_LOG="$(cat "${TMP_ROOT}/env-override-custom/docker.log" 2>/dev/null || echo "")"
assert_contains "${CASE_DOCKER_LOG}" "$(canonical_path "${custom_claude}"):/run/secrets/claude-config:ro" "TOOLBELT_CLAUDE_DIR_SRC override mount"

# --- Test 5: ANTHROPIC_API_KEY set skips keychain extraction ---
mkdir -p "${TMP_ROOT}/apikey-skip/home/.claude"
(
  scenario_root="${TMP_ROOT}/apikey-skip"
  fakebin="${scenario_root}/bin"
  workdir="${scenario_root}/cwd"
  home_dir="${scenario_root}/home"
  mkdir -p "${fakebin}" "${workdir}"

  # Fake security that would fail loudly if called
  cat >"${fakebin}/security" <<'SECEOF'
#!/usr/bin/env bash
echo "ERROR: security should not be called when ANTHROPIC_API_KEY is set" >&2
printf 'security-was-called\n' >>"${FAKE_DOCKER_LOG:?}.security"
exit 1
SECEOF
  chmod +x "${fakebin}/security"

  write_fake_docker "${fakebin}/docker"
  chmod +x "${fakebin}/docker"

  export PATH="${fakebin}:${PATH}"
  export HOME="${home_dir}"
  export FAKE_DOCKER_LOG="${scenario_root}/docker.log"
  export ANTHROPIC_API_KEY="sk-test-key"
  bash "${REPO_ROOT}/scripts/toolbelt.sh" claude >"${scenario_root}/stdout.log" 2>"${scenario_root}/stderr.log" || true
)
# Verify security was never called
if [[ -f "${TMP_ROOT}/apikey-skip/docker.log.security" ]]; then
  fail "ANTHROPIC_API_KEY: security command was called despite API key being set"
fi
# Verify ANTHROPIC_API_KEY is passed through
CASE_DOCKER_LOG="$(cat "${TMP_ROOT}/apikey-skip/docker.log" 2>/dev/null || echo "")"
assert_contains "${CASE_DOCKER_LOG}" "ANTHROPIC_API_KEY=sk-test-key" "ANTHROPIC_API_KEY passthrough"

printf 'verify_toolbelt_claude_contract: ok\n'
