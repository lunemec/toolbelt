#!/usr/bin/env bash
set -euo pipefail

GWS_REAL_BIN="${GWS_REAL_BIN:-/usr/local/bin/gws-real}"
GWS_SCOPE_GUARD_TMPDIR=""

cleanup_gws_scope_guard() {
  if [[ -n "${GWS_SCOPE_GUARD_TMPDIR}" && -d "${GWS_SCOPE_GUARD_TMPDIR}" ]]; then
    rm -rf "${GWS_SCOPE_GUARD_TMPDIR}"
  fi
}

warn() {
  printf 'warning: %s\n' "$*" >&2
}

python3_available() {
  command -v python3 >/dev/null 2>&1
}

ensure_gws_scope_guard_tmpdir() {
  if [[ -z "${GWS_SCOPE_GUARD_TMPDIR}" || ! -d "${GWS_SCOPE_GUARD_TMPDIR}" ]]; then
    GWS_SCOPE_GUARD_TMPDIR="$(mktemp -d)"
  fi
}

gws_scope_preflight_target() {
  if [[ $# -lt 3 ]]; then
    return 1
  fi

  case "$1" in
    auth|help|schema|version)
      return 1
      ;;
  esac

  printf '%s\n' "$1.$2.$3"
}

read_json_string_field() {
  local json_path="$1"
  local field_name="$2"

  python3 - "$json_path" "$field_name" <<'PY'
import json
import sys

with open(sys.argv[1], 'r', encoding='utf-8') as handle:
    data = json.load(handle)

value = data.get(sys.argv[2], "")
if isinstance(value, str):
    print(value)
PY
}

read_json_scope_field() {
  local json_path="$1"
  local field_name="$2"

  python3 - "$json_path" "$field_name" <<'PY'
import json
import sys

with open(sys.argv[1], 'r', encoding='utf-8') as handle:
    data = json.load(handle)

value = data.get(sys.argv[2], "")
if isinstance(value, str):
    for item in value.split():
        if item:
            print(item)
elif isinstance(value, list):
    for item in value:
        if isinstance(item, str) and item:
            print(item)
PY
}

extract_schema_scopes_from_json() {
  python3 - "$1" <<'PY'
import json
import sys

try:
    data = json.loads(sys.argv[1])
except json.JSONDecodeError:
    sys.exit(1)

scopes = data.get("scopes")
if not isinstance(scopes, list):
    sys.exit(1)

for item in scopes:
    if isinstance(item, str) and item:
        print(item)
PY
}

extract_tokeninfo_scopes() {
  python3 - "$1" <<'PY'
import json
import sys

try:
    data = json.loads(sys.argv[1])
except json.JSONDecodeError:
    sys.exit(1)

scope_field = data.get("scope", "")
if not isinstance(scope_field, str) or not scope_field.strip():
    sys.exit(1)

for item in scope_field.split():
    if item:
        print(item)
PY
}

extract_access_token() {
  python3 - "$1" <<'PY'
import json
import sys

try:
    data = json.loads(sys.argv[1])
except json.JSONDecodeError:
    sys.exit(1)

token = data.get("access_token", "")
if not isinstance(token, str) or not token:
    sys.exit(1)

print(token)
PY
}

extract_granted_scopes_from_file() {
  local credentials_path="$1"
  local access_token=""
  local client_id=""
  local client_secret=""
  local refresh_token=""
  local token_response=""
  local token_uri=""
  local tokeninfo_response=""
  local tokeninfo_url="${CODEX_GWS_TOKENINFO_URL:-https://oauth2.googleapis.com/tokeninfo}"
  local field_name
  local -a scope_lines=()

  for field_name in granted_scopes scopes scope; do
    if mapfile -t scope_lines < <(read_json_scope_field "${credentials_path}" "${field_name}"); then
      if [[ ${#scope_lines[@]} -gt 0 ]]; then
        printf '%s\n' "${scope_lines[@]}"
        return 0
      fi
    fi
  done

  access_token="$(read_json_string_field "${credentials_path}" "access_token")" || return 1
  if [[ -z "${access_token}" ]]; then
    refresh_token="$(read_json_string_field "${credentials_path}" "refresh_token")" || return 1
    client_id="$(read_json_string_field "${credentials_path}" "client_id")" || return 1
    client_secret="$(read_json_string_field "${credentials_path}" "client_secret")" || return 1
    token_uri="$(read_json_string_field "${credentials_path}" "token_uri")" || return 1
    if [[ -z "${token_uri}" ]]; then
      token_uri="https://oauth2.googleapis.com/token"
    fi

    if [[ -z "${refresh_token}" || -z "${client_id}" || -z "${client_secret}" ]]; then
      return 1
    fi

    token_response="$(curl -fsS --max-time 15 \
      --request POST \
      --data-urlencode "client_id=${client_id}" \
      --data-urlencode "client_secret=${client_secret}" \
      --data-urlencode "refresh_token=${refresh_token}" \
      --data-urlencode "grant_type=refresh_token" \
      "${token_uri}")" || return 1

    access_token="$(extract_access_token "${token_response}")" || return 1
  fi

  tokeninfo_response="$(curl -fsS --max-time 15 -G \
    --data-urlencode "access_token=${access_token}" \
    "${tokeninfo_url}")" || return 1

  extract_tokeninfo_scopes "${tokeninfo_response}"
}

resolve_granted_scopes() {
  local credentials_path=""
  local config_dir="${GOOGLE_WORKSPACE_CLI_CONFIG_DIR:-${HOME}/.config/gws}"
  local credentials_file="${config_dir}/credentials.json"
  local exported_credentials_path=""
  local tokeninfo_response=""

  if [[ -n "${GOOGLE_WORKSPACE_CLI_TOKEN:-}" ]]; then
    tokeninfo_response="$(curl -fsS --max-time 15 -G \
      --data-urlencode "access_token=${GOOGLE_WORKSPACE_CLI_TOKEN}" \
      "${CODEX_GWS_TOKENINFO_URL:-https://oauth2.googleapis.com/tokeninfo}")" || return 1
    extract_tokeninfo_scopes "${tokeninfo_response}"
    return 0
  fi

  ensure_gws_scope_guard_tmpdir
  exported_credentials_path="${GWS_SCOPE_GUARD_TMPDIR}/exported-credentials.json"
  if [[ -x "${GWS_REAL_BIN}" ]] \
    && "${GWS_REAL_BIN}" auth export --unmasked >"${exported_credentials_path}" 2>/dev/null \
    && [[ -s "${exported_credentials_path}" ]]; then
    extract_granted_scopes_from_file "${exported_credentials_path}"
    return 0
  fi
  rm -f "${exported_credentials_path}" 2>/dev/null || true

  if [[ -n "${GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE:-}" && -f "${GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE}" ]]; then
    credentials_path="${GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE}"
  elif [[ -f "${credentials_file}" ]]; then
    credentials_path="${credentials_file}"
  else
    return 1
  fi

  extract_granted_scopes_from_file "${credentials_path}"
}

scopes_overlap() {
  local granted_scope required_scope

  for required_scope in "${REQUIRED_GWS_SCOPES[@]}"; do
    for granted_scope in "${GRANTED_GWS_SCOPES[@]}"; do
      if [[ "${granted_scope}" == "${required_scope}" ]]; then
        return 0
      fi
    done
  done

  return 1
}

preflight_gws_scope_requirements() {
  local granted_scopes_output=""
  local required_scopes_output=""
  local schema_json=""
  local schema_ref=""
  local service_name="$1"

  schema_ref="$(gws_scope_preflight_target "$@")" || return 0

  if [[ ! -x "${GWS_REAL_BIN}" ]]; then
    warn "gws real binary not found at ${GWS_REAL_BIN}; skipping scope preflight"
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    warn "curl not found; skipping gws scope preflight for ${schema_ref}"
    return 0
  fi

  if ! python3_available; then
    warn "python3 not found; skipping gws scope preflight for ${schema_ref}"
    return 0
  fi

  schema_json="$("${GWS_REAL_BIN}" schema "${schema_ref}" 2>/dev/null)" || {
    warn "unable to resolve required scopes for ${schema_ref}; continuing without gws scope preflight"
    return 0
  }

  if ! required_scopes_output="$(extract_schema_scopes_from_json "${schema_json}")"; then
    warn "unable to parse required scopes for ${schema_ref}; continuing without gws scope preflight"
    return 0
  fi

  if [[ -n "${required_scopes_output}" ]]; then
    mapfile -t REQUIRED_GWS_SCOPES <<<"${required_scopes_output}"
  else
    REQUIRED_GWS_SCOPES=()
  fi

  if [[ ${#REQUIRED_GWS_SCOPES[@]} -eq 0 ]]; then
    warn "no required scopes reported for ${schema_ref}; continuing without gws scope preflight"
    return 0
  fi

  if ! granted_scopes_output="$(resolve_granted_scopes)"; then
    warn "unable to inspect granted scopes for current gws credentials; continuing without gws scope preflight"
    return 0
  fi

  if [[ -n "${granted_scopes_output}" ]]; then
    mapfile -t GRANTED_GWS_SCOPES <<<"${granted_scopes_output}"
  else
    GRANTED_GWS_SCOPES=()
  fi

  if [[ ${#GRANTED_GWS_SCOPES[@]} -eq 0 ]]; then
    warn "current gws credentials did not report any granted scopes; continuing without gws scope preflight"
    return 0
  fi

  if scopes_overlap; then
    return 0
  fi

  {
    printf 'requested gws command requires one of these OAuth scopes for %s:\n' "${schema_ref}"
    printf '  - %s\n' "${REQUIRED_GWS_SCOPES[@]}"
    printf 'but the current container credentials currently grant:\n'
    printf '  - %s\n' "${GRANTED_GWS_SCOPES[@]}"
    printf "if this container was launched with 'scripts/toolbelt.sh -gws', re-run 'gws auth login -s %s' on the host and restart the container\n" "${service_name}"
  } >&2
  exit 1
}

run_gws_with_failure_hint() {
  local combined_output=""
  local service_name="${1:-workspace}"
  local status=0
  local stderr_path=""
  local stdout_path=""

  if [[ ! -x "${GWS_REAL_BIN}" ]]; then
    echo "gws real binary not found at ${GWS_REAL_BIN}" >&2
    exit 1
  fi

  GWS_SCOPE_GUARD_TMPDIR="$(mktemp -d)"
  stdout_path="${GWS_SCOPE_GUARD_TMPDIR}/stdout"
  stderr_path="${GWS_SCOPE_GUARD_TMPDIR}/stderr"

  set +e
  "${GWS_REAL_BIN}" "$@" >"${stdout_path}" 2>"${stderr_path}"
  status=$?
  set -e

  if [[ -s "${stdout_path}" ]]; then
    cat "${stdout_path}"
  fi
  if [[ -s "${stderr_path}" ]]; then
    cat "${stderr_path}" >&2
  fi

  if [[ "${status}" -ne 0 ]]; then
    combined_output="$(cat "${stdout_path}" "${stderr_path}" 2>/dev/null || true)"
    if [[ "${combined_output}" == *"insufficientPermissions"* ]]; then
      printf "hint: Google accepted the credentials but rejected the scopes. If this container was launched with 'scripts/toolbelt.sh -gws', re-run 'gws auth login -s %s' on the host and restart the container.\n" "${service_name}" >&2
    fi
  fi

  return "${status}"
}

main() {
  trap cleanup_gws_scope_guard EXIT
  preflight_gws_scope_requirements "$@"
  run_gws_with_failure_hint "$@"
}

main "$@"
