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

numeric_gid_for_path() {
  local path="$1"

  if stat -c '%g' "${path}" >/dev/null 2>&1; then
    stat -c '%g' "${path}"
    return 0
  fi

  if stat -f '%g' "${path}" >/dev/null 2>&1; then
    stat -f '%g' "${path}"
    return 0
  fi

  return 1
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
  local home_dir="${scenario_root}/home"
  local stdout_path="${scenario_root}/stdout.log"
  local stderr_path="${scenario_root}/stderr.log"

  mkdir -p "${fakebin}" "${workdir}" "${home_dir}"

  write_fake_docker "${fakebin}/docker"
  chmod +x "${fakebin}/docker"

  set +e
  (
    cd "${workdir}"
    export PATH="${fakebin}:${PATH}"
    export HOME="${home_dir}"
    export FAKE_DOCKER_LOG="${scenario_root}/docker.log"
    bash "${REPO_ROOT}/scripts/toolbelt.sh" codex -docker "$@" >"${stdout_path}" 2>"${stderr_path}"
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

[[ -S /var/run/docker.sock ]] || fail "host docker socket is required for -docker contract verification"
EXPECTED_SOCKET_GID="$(numeric_gid_for_path /var/run/docker.sock)" || fail "could not read host docker socket gid"

run_toolbelt_case docker-enabled
[[ "${CASE_STATUS}" -eq 0 ]] || fail "docker-enabled should succeed"
assert_contains "${CASE_DOCKER_LOG}" "-e TOOLBELT_HOST_UID=$(id -u)" "host uid propagation"
assert_contains "${CASE_DOCKER_LOG}" "-e TOOLBELT_HOST_GID=$(id -g)" "host gid propagation"
assert_contains "${CASE_DOCKER_LOG}" "-e TOOLBELT_DOCKER_SOCK_GID=${EXPECTED_SOCKET_GID}" "docker socket gid propagation"
assert_contains "${CASE_DOCKER_LOG}" "-v /var/run/docker.sock:/var/run/docker.sock" "docker socket mount"
assert_contains "${CASE_DOCKER_LOG}" "-v ${TMP_ROOT}/docker-enabled/cwd:${TMP_ROOT}/docker-enabled/cwd" "workspace mount"

printf 'verify_toolbelt_docker_contract: ok\n'
