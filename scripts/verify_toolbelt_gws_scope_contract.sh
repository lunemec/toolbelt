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

write_fake_gws() {
  local path="$1"

  cat >"${path}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "auth" && "${2:-}" == "export" && "${3:-}" == "--unmasked" ]]; then
  cat <<'JSON'
{"refresh_token":"fake-refresh-token","client_id":"fake-client-id","client_secret":"fake-client-secret","token_uri":"https://oauth2.googleapis.com/token"}
JSON
  exit 0
fi

if [[ "${1:-}" == "schema" && "${2:-}" == "drive.files.list" ]]; then
  if [[ "${FAKE_GWS_SCHEMA_MODE:-ok}" == "fail" ]]; then
    exit 1
  fi
  cat <<'JSON'
{"scopes":["https://www.googleapis.com/auth/drive","https://www.googleapis.com/auth/drive.readonly"]}
JSON
  exit 0
fi

printf 'unexpected gws invocation: %s\n' "$*" >&2
exit 1
EOF
}

write_fake_curl() {
  local path="$1"

  cat >"${path}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"${FAKE_CURL_LOG:?}"

if [[ "$*" == *"grant_type=refresh_token"* ]]; then
  printf '%s\n' '{"access_token":"fake-access-token"}'
  exit 0
fi

if [[ "$*" == *"tokeninfo"* ]]; then
  printf '{"scope":"%s"}\n' "${FAKE_TOKENINFO_SCOPES:-}"
  exit 0
fi

printf 'unexpected curl invocation: %s\n' "$*" >&2
exit 1
EOF
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
  local token_scopes="$2"
  local schema_mode="$3"
  shift 3

  local scenario_root="${TMP_ROOT}/${scenario}"
  local fakebin="${scenario_root}/bin"
  local home_dir="${scenario_root}/home"
  local mount_dir="${scenario_root}/mount"
  local stderr_path="${scenario_root}/stderr.log"
  local stdout_path="${scenario_root}/stdout.log"

  mkdir -p "${fakebin}" "${home_dir}/.config/gws" "${mount_dir}"

  write_fake_gws "${fakebin}/gws"
  write_fake_curl "${fakebin}/curl"
  write_fake_docker "${fakebin}/docker"
  chmod +x "${fakebin}/gws" "${fakebin}/curl" "${fakebin}/docker"

  set +e
  PATH="${fakebin}:${PATH}" \
  HOME="${home_dir}" \
  FAKE_CURL_LOG="${scenario_root}/curl.log" \
  FAKE_DOCKER_LOG="${scenario_root}/docker.log" \
  FAKE_GWS_SCHEMA_MODE="${schema_mode}" \
  FAKE_TOKENINFO_SCOPES="${token_scopes}" \
  bash "${REPO_ROOT}/scripts/toolbelt.sh" -gws "${mount_dir}" -- "$@" \
    >"${stdout_path}" 2>"${stderr_path}"
  CASE_STATUS=$?
  set -e

  CASE_STDERR="$(cat "${stderr_path}")"
  CASE_STDOUT="$(cat "${stdout_path}")"
  if [[ -f "${scenario_root}/curl.log" ]]; then
    CASE_CURL_LOG="$(cat "${scenario_root}/curl.log")"
  else
    CASE_CURL_LOG=""
  fi
  if [[ -f "${scenario_root}/docker.log" ]]; then
    CASE_DOCKER_LOG="$(cat "${scenario_root}/docker.log")"
  else
    CASE_DOCKER_LOG=""
  fi
}

trap cleanup EXIT

run_toolbelt_case matching-scope "https://www.googleapis.com/auth/drive.readonly" ok \
  gws drive files list --params '{"pageSize":10}'
[[ "${CASE_STATUS}" -eq 0 ]] || fail "matching-scope should succeed"
assert_contains "${CASE_DOCKER_LOG}" "run" "matching-scope docker launch"
assert_contains "${CASE_CURL_LOG}" "tokeninfo" "matching-scope tokeninfo lookup"
assert_not_contains "${CASE_STDERR}" "requires one of these OAuth scopes" "matching-scope stderr"

run_toolbelt_case missing-scope "https://www.googleapis.com/auth/gmail.readonly" ok \
  gws drive files list --params '{"pageSize":10}'
[[ "${CASE_STATUS}" -ne 0 ]] || fail "missing-scope should fail"
assert_contains "${CASE_STDERR}" "requires one of these OAuth scopes for drive.files.list" "missing-scope stderr"
assert_contains "${CASE_STDERR}" "gws auth login -s drive" "missing-scope remediation"
assert_not_contains "${CASE_DOCKER_LOG}" "run" "missing-scope docker launch"

run_toolbelt_case shell-wrapper "https://www.googleapis.com/auth/gmail.readonly" ok \
  bash -lc "gws drive files list --params '{\"pageSize\":10}'"
[[ "${CASE_STATUS}" -eq 0 ]] || fail "shell-wrapper should succeed"
assert_contains "${CASE_DOCKER_LOG}" "run" "shell-wrapper docker launch"
assert_not_contains "${CASE_CURL_LOG}" "tokeninfo" "shell-wrapper preflight"

run_toolbelt_case schema-failure "https://www.googleapis.com/auth/gmail.readonly" fail \
  gws drive files list --params '{"pageSize":10}'
[[ "${CASE_STATUS}" -eq 0 ]] || fail "schema-failure should continue"
assert_contains "${CASE_STDERR}" "unable to resolve required scopes for drive.files.list" "schema-failure warning"
assert_contains "${CASE_DOCKER_LOG}" "run" "schema-failure docker launch"

printf 'verify_toolbelt_gws_scope_contract: ok\n'
