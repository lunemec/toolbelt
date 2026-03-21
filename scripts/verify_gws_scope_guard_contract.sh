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

write_fake_gws_real() {
  local path="$1"

  cat >"${path}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "schema" && "${2:-}" == "drive.files.list" ]]; then
  if [[ "${FAKE_GWS_REAL_SCHEMA_MODE:-ok}" == "fail" ]]; then
    exit 1
  fi
  cat <<'JSON'
{"scopes":["https://www.googleapis.com/auth/drive","https://www.googleapis.com/auth/drive.readonly"]}
JSON
  exit 0
fi

if [[ "${1:-}" == "auth" && "${2:-}" == "export" && "${3:-}" == "--unmasked" ]]; then
  cat <<'JSON'
{"refresh_token":"fake-refresh-token","client_id":"fake-client-id","client_secret":"fake-client-secret","token_uri":"https://oauth2.googleapis.com/token"}
JSON
  exit 0
fi

printf '%s\n' "$*" >>"${FAKE_GWS_REAL_LOG:?}"

if [[ "${FAKE_GWS_REAL_MODE:-success}" == "fail-permission" ]]; then
  cat <<'JSON'
{"error":{"code":403,"message":"Request had insufficient authentication scopes.","reason":"insufficientPermissions"}}
JSON
  exit 1
fi

cat <<'JSON'
{"files":[]}
JSON
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

run_guard_case() {
  local scenario="$1"
  local token_scopes="$2"
  local schema_mode="$3"
  local real_mode="$4"
  shift 4

  local scenario_root="${TMP_ROOT}/${scenario}"
  local fakebin="${scenario_root}/bin"
  local stderr_path="${scenario_root}/stderr.log"
  local stdout_path="${scenario_root}/stdout.log"
  local credentials_path="${scenario_root}/credentials.json"

  mkdir -p "${fakebin}"

  write_fake_gws_real "${fakebin}/gws-real"
  write_fake_curl "${fakebin}/curl"
  chmod +x "${fakebin}/gws-real" "${fakebin}/curl"

  cat >"${credentials_path}" <<'JSON'
{"refresh_token":"fake-refresh-token","client_id":"fake-client-id","client_secret":"fake-client-secret","token_uri":"https://oauth2.googleapis.com/token"}
JSON

  set +e
  PATH="${fakebin}:${PATH}" \
  GWS_REAL_BIN="${fakebin}/gws-real" \
  GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE="${credentials_path}" \
  FAKE_CURL_LOG="${scenario_root}/curl.log" \
  FAKE_GWS_REAL_LOG="${scenario_root}/gws-real.log" \
  FAKE_GWS_REAL_SCHEMA_MODE="${schema_mode}" \
  FAKE_GWS_REAL_MODE="${real_mode}" \
  FAKE_TOKENINFO_SCOPES="${token_scopes}" \
  "${REPO_ROOT}/scripts/gws-scope-guard.sh" "$@" \
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
  if [[ -f "${scenario_root}/gws-real.log" ]]; then
    CASE_GWS_REAL_LOG="$(cat "${scenario_root}/gws-real.log")"
  else
    CASE_GWS_REAL_LOG=""
  fi
}

trap cleanup EXIT

run_guard_case matching-scope "https://www.googleapis.com/auth/drive.readonly" ok success \
  drive files list --params '{"pageSize":10}'
[[ "${CASE_STATUS}" -eq 0 ]] || fail "matching-scope should succeed"
assert_contains "${CASE_STDOUT}" '"files":[]' "matching-scope stdout"
assert_contains "${CASE_GWS_REAL_LOG}" 'drive files list' "matching-scope real invocation"
assert_contains "${CASE_CURL_LOG}" 'tokeninfo' "matching-scope tokeninfo lookup"

run_guard_case missing-scope "https://www.googleapis.com/auth/gmail.readonly" ok success \
  drive files list --params '{"pageSize":10}'
[[ "${CASE_STATUS}" -ne 0 ]] || fail "missing-scope should fail"
assert_contains "${CASE_STDERR}" 'requires one of these OAuth scopes for drive.files.list' "missing-scope stderr"
assert_contains "${CASE_STDERR}" "gws auth login -s drive" "missing-scope remediation"
assert_not_contains "${CASE_GWS_REAL_LOG}" 'drive files list' "missing-scope real invocation"

run_guard_case hint-on-403 "https://www.googleapis.com/auth/gmail.readonly" fail fail-permission \
  drive files list --params '{"pageSize":10}'
[[ "${CASE_STATUS}" -ne 0 ]] || fail "hint-on-403 should fail"
assert_contains "${CASE_STDERR}" 'unable to resolve required scopes for drive.files.list' "hint-on-403 warning"
assert_contains "${CASE_STDERR}" 'Google accepted the credentials but rejected the scopes' "hint-on-403 scope hint"
assert_contains "${CASE_STDOUT}" 'insufficientPermissions' "hint-on-403 original output"
assert_contains "${CASE_GWS_REAL_LOG}" 'drive files list' "hint-on-403 real invocation"

printf 'verify_gws_scope_guard_contract: ok\n'
