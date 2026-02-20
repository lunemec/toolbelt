#!/usr/bin/env bash
set -euo pipefail

ROOT="${TASK_ROOT_DIR:-coordination}"
TEMPLATE="$ROOT/templates/TASK_TEMPLATE.md"
DEFAULT_OWNER_AGENT="${TASK_DEFAULT_OWNER:-pm}"
DEFAULT_CREATOR_AGENT="${TASK_DEFAULT_CREATOR:-pm}"
DEFAULT_PRIORITY="${TASK_DEFAULT_PRIORITY:-50}"
LOCK_ROOT="$ROOT/locks/files"
DEFAULT_LOCK_STALE_TTL_SECONDS="${TASK_LOCK_STALE_TTL_SECONDS:-3600}"
LOCK_REAPER_AGENTS_RAW="${TASK_LOCK_REAPER_AGENTS:-pm coordinator}"

abs_path() {
  local path="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath -m "$path"
  else
    readlink -f "$path"
  fi
}

require_container_workspace() {
  [[ -f /.dockerenv ]] || {
    echo "taskctl must run inside Docker (.dockerenv not found)" >&2
    exit 1
  }

  local cwd
  cwd="$(pwd -P)"
  [[ "$cwd" == "/workspace" || "$cwd" == /workspace/* ]] || {
    echo "taskctl must run from /workspace (current: $cwd)" >&2
    exit 1
  }

  local root_abs
  root_abs="$(abs_path "$ROOT")"
  [[ "$root_abs" == "/workspace" || "$root_abs" == /workspace/* ]] || {
    echo "TASK_ROOT_DIR must resolve under /workspace (current: $root_abs)" >&2
    exit 1
  }
}

require_container_workspace

now() {
  date '+%Y-%m-%dT%H:%M:%S%z'
}

usage() {
  cat <<USAGE
Usage:
  $0 create <TASK_ID> <TITLE> [--to <owner_agent>] [--from <creator_agent>] [--priority <N>] [--parent <TASK_ID>] [--write-target <path>]...
  $0 delegate <from_agent> <to_agent> <TASK_ID> <TITLE> [--priority <N>] [--parent <TASK_ID>] [--write-target <path>]...
  $0 assign <TASK_ID> <agent>
  $0 claim <agent>
  $0 done <agent> <TASK_ID> [NOTE]
  $0 block <agent> <TASK_ID> <REASON>
  $0 lock-acquire <TASK_ID> <owner_agent> <target>
  $0 lock-heartbeat <TASK_ID> <owner_agent> <target>
  $0 lock-release <TASK_ID> <owner_agent> <target>
  $0 lock-release-task <TASK_ID> <owner_agent>
  $0 lock-status <target>
  $0 lock-clean-stale [--ttl <seconds>] [--actor <agent>]
  $0 ensure-agent <agent> [--task <TASK_ID|TASK_FILE>] [--force]
  $0 list [agent]

Notes:
  - Lower priority number means higher urgency (0 is highest).
  - Blocked tasks are moved out of active queues and a blocker report task is queued for creator_agent.
  - Agents are dynamic skill names (examples: pm, designer, architect, fe, be, db, review).
  - Coding-owner tasks (fe/be/db) must declare at least one --write-target path.
  - lock-clean-stale requires orchestrator actor identity via --actor or TASK_ACTOR_AGENT.
  - Default stale-lock reaper lanes are "pm coordinator" (override with TASK_LOCK_REAPER_AGENTS).
  - ensure-agent creates role prompts when missing and refreshes when role prompt is unfit for the current task context.
USAGE
}

is_integer() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

require_task_id() {
  local task_id="$1"
  [[ "$task_id" =~ ^[A-Za-z0-9._-]+$ ]] || {
    echo "invalid task id: $task_id" >&2
    exit 1
  }
}

require_agent() {
  local agent="$1"
  [[ "$agent" == "system" || "$agent" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || {
    echo "invalid agent: $agent" >&2
    exit 1
  }
}

normalize_priority() {
  local priority="$1"
  is_integer "$priority" || {
    echo "priority must be an integer: $priority" >&2
    exit 1
  }
  (( priority >= 0 && priority <= 999 )) || {
    echo "priority out of range 0..999: $priority" >&2
    exit 1
  }
  printf '%d' "$priority"
}

pad_priority() {
  local priority
  priority="$(normalize_priority "$1")"
  printf '%03d' "$priority"
}

set_field() {
  local file="$1"
  local key="$2"
  local value="$3"

  if grep -qE "^${key}:" "$file"; then
    sed -i "s|^${key}:.*|${key}: ${value}|" "$file"
  else
    sed -i "1 a ${key}: ${value}" "$file"
  fi
}

field_value() {
  local file="$1"
  local key="$2"
  sed -n "s/^${key}: //p" "$file" | head -n1
}

append_unique_word() {
  local current="${1:-}"
  local candidate="$2"

  if [[ " $current " == *" $candidate "* ]]; then
    printf '%s' "$current"
  else
    if [[ -n "$current" ]]; then
      printf '%s %s' "$current" "$candidate"
    else
      printf '%s' "$candidate"
    fi
  fi
}

text_matches() {
  local text="$1"
  local pattern="$2"
  printf '%s' "$text" | grep -qiE "$pattern"
}

resolve_task_file() {
  local ref="$1"

  if [[ -f "$ref" ]]; then
    printf '%s' "$ref"
    return 0
  fi

  if [[ -f "$ROOT/$ref" ]]; then
    printf '%s' "$ROOT/$ref"
    return 0
  fi

  if [[ "$ref" =~ ^[A-Za-z0-9._-]+$ ]]; then
    local found
    found="$(find "$ROOT" -type f -name "${ref}.md" \
      ! -path "$ROOT/examples/*" \
      ! -path "$ROOT/templates/*" \
      ! -path "$ROOT/roles/*" | head -n1)"

    if [[ -n "$found" ]]; then
      printf '%s' "$found"
      return 0
    fi
  fi

  return 1
}

compute_file_hash() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  else
    cksum "$file" | awk '{print $1}'
  fi
}

compute_fit_signature() {
  local agent="$1"
  local task_file="${2:-}"
  local tags_csv="$3"

  local source_hash="none"
  if [[ -n "$task_file" && -f "$task_file" ]]; then
    source_hash="$(compute_file_hash "$task_file")"
  fi

  local payload="${agent}|${tags_csv}|${source_hash}"
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$payload" | sha256sum | awk '{print $1}'
  else
    printf '%s' "$payload" | cksum | awk '{print $1}'
  fi
}

require_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "missing required command: $cmd" >&2
    exit 1
  }
}

normalize_ttl_seconds() {
  local ttl="$1"
  is_integer "$ttl" || {
    echo "ttl must be an integer (seconds): $ttl" >&2
    exit 1
  }
  (( ttl > 0 )) || {
    echo "ttl must be > 0 seconds: $ttl" >&2
    exit 1
  }
  printf '%d' "$ttl"
}

normalize_agent_list() {
  local raw="$1"
  raw="${raw//,/ }"
  printf '%s' "$raw" | tr -s '[:space:]' ' ' | sed -E 's/^ //; s/ $//'
}

agent_in_space_list() {
  local needle="$1"
  local haystack="$2"
  local item
  for item in $haystack; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

require_lock_reap_actor_allowed() {
  local actor_agent="$1"
  local allowed_agents="$2"

  [[ -n "$actor_agent" ]] || {
    echo "lock-clean-stale requires actor identity (--actor <agent> or TASK_ACTOR_AGENT)" >&2
    return 1
  }

  require_agent "$actor_agent"

  [[ -n "$allowed_agents" ]] || {
    echo "lock-clean-stale has no allowed reaper lanes configured (TASK_LOCK_REAPER_AGENTS)" >&2
    return 1
  }

  if ! agent_in_space_list "$actor_agent" "$allowed_agents"; then
    echo "lock-clean-stale denied: actor_agent=$actor_agent allowed_reaper_agents=\"$allowed_agents\"" >&2
    return 2
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

compute_text_hash() {
  local value="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$value" | sha256sum | awk '{print $1}'
  else
    printf '%s' "$value" | cksum | awk '{print $1}'
  fi
}

lock_path_for_canonical_target() {
  local canonical_target="$1"
  local target_hash
  target_hash="$(compute_text_hash "$canonical_target")"
  printf '%s/%s.lock' "$LOCK_ROOT" "$target_hash"
}

lock_path_for_target() {
  local target="$1"
  local canonical_target
  canonical_target="$(canonicalize_target_path "$target")"
  lock_path_for_canonical_target "$canonical_target"
}

ensure_lock_root() {
  mkdir -p "$LOCK_ROOT"
}

write_lock_payload_file() {
  local out_file="$1"
  local task_id="$2"
  local owner_agent="$3"
  local canonical_target="$4"
  local acquired_at="$5"
  local heartbeat_at="$6"

  require_command jq
  jq -cn \
    --arg task_id "$task_id" \
    --arg owner_agent "$owner_agent" \
    --arg canonical_target "$canonical_target" \
    --arg acquired_at "$acquired_at" \
    --arg heartbeat_at "$heartbeat_at" \
    '{
      task_id: $task_id,
      owner_agent: $owner_agent,
      canonical_target: $canonical_target,
      acquired_at: $acquired_at,
      heartbeat_at: $heartbeat_at
    }' >"$out_file"
}

create_lock_payload_file_atomic() {
  local lock_file="$1"
  local task_id="$2"
  local owner_agent="$3"
  local canonical_target="$4"
  local acquired_at="$5"
  local heartbeat_at="$6"

  ensure_lock_root
  local tmp_file
  tmp_file="$(mktemp "$LOCK_ROOT/.lock-create.XXXXXX")"
  write_lock_payload_file "$tmp_file" "$task_id" "$owner_agent" "$canonical_target" "$acquired_at" "$heartbeat_at"

  if ln "$tmp_file" "$lock_file" 2>/dev/null; then
    rm -f "$tmp_file"
    return 0
  fi

  rm -f "$tmp_file"
  return 1
}

read_lock_payload() {
  local lock_file="$1"
  [[ -f "$lock_file" ]] || return 1
  cat "$lock_file"
}

remove_lock_payload() {
  local lock_file="$1"
  rm -f "$lock_file"
}

lock_payload_field() {
  local lock_file="$1"
  local field="$2"
  require_command jq
  jq -r --arg field "$field" '.[$field] // ""' "$lock_file"
}

lock_owner_matches() {
  local lock_file="$1"
  local task_id="$2"
  local owner_agent="$3"
  [[ -f "$lock_file" ]] || return 1

  local existing_task_id existing_owner
  existing_task_id="$(lock_payload_field "$lock_file" "task_id" 2>/dev/null || true)"
  existing_owner="$(lock_payload_field "$lock_file" "owner_agent" 2>/dev/null || true)"
  [[ "$existing_task_id" == "$task_id" && "$existing_owner" == "$owner_agent" ]]
}

lock_acquire() {
  local task_id="$1"
  local owner_agent="$2"
  local target="$3"

  require_task_id "$task_id"
  require_agent "$owner_agent"

  local canonical_target lock_file timestamp
  canonical_target="$(canonicalize_target_path "$target")"
  lock_file="$(lock_path_for_canonical_target "$canonical_target")"
  timestamp="$(now)"

  ensure_lock_root

  if [[ -f "$lock_file" ]]; then
    if lock_owner_matches "$lock_file" "$task_id" "$owner_agent"; then
      local acquired_at
      acquired_at="$(lock_payload_field "$lock_file" "acquired_at" 2>/dev/null || true)"
      acquired_at="${acquired_at:-$timestamp}"
      write_lock_payload_file "$lock_file" "$task_id" "$owner_agent" "$canonical_target" "$acquired_at" "$timestamp"
      echo "lock already held: target=$canonical_target task_id=$task_id owner_agent=$owner_agent"
      return 0
    fi

    local holder_task holder_owner
    holder_task="$(lock_payload_field "$lock_file" "task_id" 2>/dev/null || true)"
    holder_owner="$(lock_payload_field "$lock_file" "owner_agent" 2>/dev/null || true)"
    echo "lock conflict: target=$canonical_target holder_task_id=${holder_task:-unknown} holder_owner_agent=${holder_owner:-unknown}" >&2
    return 2
  fi

  if create_lock_payload_file_atomic "$lock_file" "$task_id" "$owner_agent" "$canonical_target" "$timestamp" "$timestamp"; then
    echo "lock acquired: target=$canonical_target task_id=$task_id owner_agent=$owner_agent"
    return 0
  fi

  if [[ -f "$lock_file" ]] && lock_owner_matches "$lock_file" "$task_id" "$owner_agent"; then
    echo "lock already held: target=$canonical_target task_id=$task_id owner_agent=$owner_agent"
    return 0
  fi

  local holder_task holder_owner
  holder_task="$(lock_payload_field "$lock_file" "task_id" 2>/dev/null || true)"
  holder_owner="$(lock_payload_field "$lock_file" "owner_agent" 2>/dev/null || true)"
  echo "lock conflict: target=$canonical_target holder_task_id=${holder_task:-unknown} holder_owner_agent=${holder_owner:-unknown}" >&2
  return 2
}

lock_heartbeat() {
  local task_id="$1"
  local owner_agent="$2"
  local target="$3"

  require_task_id "$task_id"
  require_agent "$owner_agent"

  local canonical_target lock_file
  canonical_target="$(canonicalize_target_path "$target")"
  lock_file="$(lock_path_for_canonical_target "$canonical_target")"

  [[ -f "$lock_file" ]] || {
    echo "lock not found for heartbeat: target=$canonical_target" >&2
    return 1
  }

  if ! lock_owner_matches "$lock_file" "$task_id" "$owner_agent"; then
    local holder_task holder_owner
    holder_task="$(lock_payload_field "$lock_file" "task_id" 2>/dev/null || true)"
    holder_owner="$(lock_payload_field "$lock_file" "owner_agent" 2>/dev/null || true)"
    echo "lock heartbeat denied: target=$canonical_target holder_task_id=${holder_task:-unknown} holder_owner_agent=${holder_owner:-unknown}" >&2
    return 2
  fi

  local acquired_at
  acquired_at="$(lock_payload_field "$lock_file" "acquired_at" 2>/dev/null || true)"
  acquired_at="${acquired_at:-$(now)}"
  write_lock_payload_file "$lock_file" "$task_id" "$owner_agent" "$canonical_target" "$acquired_at" "$(now)"
  echo "lock heartbeat updated: target=$canonical_target task_id=$task_id owner_agent=$owner_agent"
}

lock_release() {
  local task_id="$1"
  local owner_agent="$2"
  local target="$3"

  require_task_id "$task_id"
  require_agent "$owner_agent"

  local canonical_target lock_file
  canonical_target="$(canonicalize_target_path "$target")"
  lock_file="$(lock_path_for_canonical_target "$canonical_target")"

  if [[ ! -f "$lock_file" ]]; then
    echo "lock already clear: target=$canonical_target"
    return 0
  fi

  if ! lock_owner_matches "$lock_file" "$task_id" "$owner_agent"; then
    local holder_task holder_owner
    holder_task="$(lock_payload_field "$lock_file" "task_id" 2>/dev/null || true)"
    holder_owner="$(lock_payload_field "$lock_file" "owner_agent" 2>/dev/null || true)"
    echo "lock release denied: target=$canonical_target holder_task_id=${holder_task:-unknown} holder_owner_agent=${holder_owner:-unknown}" >&2
    return 2
  fi

  remove_lock_payload "$lock_file"
  echo "lock released: target=$canonical_target task_id=$task_id owner_agent=$owner_agent"
}

lock_release_task() {
  local task_id="$1"
  local owner_agent="$2"

  require_task_id "$task_id"
  require_agent "$owner_agent"

  ensure_lock_root

  local released=0
  local lock_file
  shopt -s nullglob
  for lock_file in "$LOCK_ROOT"/*.lock; do
    if lock_owner_matches "$lock_file" "$task_id" "$owner_agent"; then
      remove_lock_payload "$lock_file"
      released=$((released + 1))
    fi
  done
  shopt -u nullglob

  echo "lock-release-task: task_id=$task_id owner_agent=$owner_agent released=$released"
}

timestamp_to_epoch() {
  local timestamp="$1"
  date -d "$timestamp" '+%s'
}

lock_is_stale() {
  local lock_file="$1"
  local ttl_seconds="$2"
  local now_epoch="$3"

  local heartbeat_at acquired_at reference_ts
  heartbeat_at="$(lock_payload_field "$lock_file" "heartbeat_at" 2>/dev/null || true)"
  acquired_at="$(lock_payload_field "$lock_file" "acquired_at" 2>/dev/null || true)"
  reference_ts="${heartbeat_at:-$acquired_at}"

  [[ -n "$reference_ts" ]] || return 0

  local reference_epoch
  reference_epoch="$(timestamp_to_epoch "$reference_ts" 2>/dev/null || true)"
  [[ -n "$reference_epoch" ]] || return 0

  local age
  age=$((now_epoch - reference_epoch))
  (( age > ttl_seconds ))
}

write_lock_reap_audit_report() {
  local actor_agent="$1"
  local lock_file="$2"
  local ttl_seconds="$3"
  local now_epoch="$4"

  local task_id owner_agent canonical_target acquired_at heartbeat_at
  task_id="$(lock_payload_field "$lock_file" "task_id" 2>/dev/null || true)"
  owner_agent="$(lock_payload_field "$lock_file" "owner_agent" 2>/dev/null || true)"
  canonical_target="$(lock_payload_field "$lock_file" "canonical_target" 2>/dev/null || true)"
  acquired_at="$(lock_payload_field "$lock_file" "acquired_at" 2>/dev/null || true)"
  heartbeat_at="$(lock_payload_field "$lock_file" "heartbeat_at" 2>/dev/null || true)"

  local reference_ts reference_epoch age_seconds
  reference_ts="${heartbeat_at:-$acquired_at}"
  age_seconds=""
  if [[ -n "$reference_ts" ]]; then
    reference_epoch="$(timestamp_to_epoch "$reference_ts" 2>/dev/null || true)"
    if [[ -n "$reference_epoch" ]]; then
      age_seconds=$((now_epoch - reference_epoch))
    fi
  fi

  local report_dir report_file
  report_dir="$ROOT/reports/$actor_agent"
  mkdir -p "$report_dir"
  report_file="$report_dir/LOCK-REAP-$(date +%Y%m%d%H%M%S%N).md"

  cat >"$report_file" <<EOF
# Lock Reap Audit

- action: lock-clean-stale
- actor_agent: $actor_agent
- reaped_at: $(now)
- ttl_seconds: $ttl_seconds
- lock_file: $lock_file
- canonical_target: ${canonical_target:-unknown}
- task_id: ${task_id:-unknown}
- owner_agent: ${owner_agent:-unknown}
- acquired_at: ${acquired_at:-unknown}
- heartbeat_at: ${heartbeat_at:-unknown}
- stale_age_seconds: ${age_seconds:-unknown}
EOF

  printf '%s' "$report_file"
}

lock_status() {
  local target="$1"
  local canonical_target lock_file
  canonical_target="$(canonicalize_target_path "$target")"
  lock_file="$(lock_path_for_canonical_target "$canonical_target")"

  echo "canonical_target: $canonical_target"
  echo "lock_file: $lock_file"

  if [[ ! -f "$lock_file" ]]; then
    echo "status: unlocked"
    return 0
  fi

  echo "status: locked"
  read_lock_payload "$lock_file"
}

lock_clean_stale() {
  local ttl_seconds="$1"
  local actor_agent="${2:-${TASK_ACTOR_AGENT:-}}"
  ttl_seconds="$(normalize_ttl_seconds "$ttl_seconds")"

  local allowed_reaper_agents
  allowed_reaper_agents="$(normalize_agent_list "$LOCK_REAPER_AGENTS_RAW")"
  require_lock_reap_actor_allowed "$actor_agent" "$allowed_reaper_agents" || return $?

  ensure_lock_root
  local now_epoch
  now_epoch="$(date '+%s')"

  local scanned=0
  local removed=0
  local kept=0

  local lock_file
  shopt -s nullglob
  for lock_file in "$LOCK_ROOT"/*.lock; do
    scanned=$((scanned + 1))
    if lock_is_stale "$lock_file" "$ttl_seconds" "$now_epoch"; then
      local canonical_target report_file
      canonical_target="$(lock_payload_field "$lock_file" "canonical_target" 2>/dev/null || true)"
      report_file="$(write_lock_reap_audit_report "$actor_agent" "$lock_file" "$ttl_seconds" "$now_epoch")"
      remove_lock_payload "$lock_file"
      removed=$((removed + 1))
      echo "reaped lock: file=$lock_file canonical_target=${canonical_target:-unknown} actor_agent=$actor_agent audit_report=$report_file"
    else
      kept=$((kept + 1))
    fi
  done
  shopt -u nullglob

  echo "lock-clean-stale summary: actor_agent=$actor_agent scanned=$scanned removed=$removed kept=$kept ttl_seconds=$ttl_seconds"
}

extract_frontmatter_to_file() {
  local source_file="$1"
  local out_file="$2"
  awk '
    BEGIN { section = 0 }
    /^---$/ { section++; next }
    section == 1 { print }
    section >= 2 { exit }
  ' "$source_file" >"$out_file"
}

task_intended_write_target_count() {
  local task_file="$1"
  require_command yq

  local frontmatter_file
  frontmatter_file="$(mktemp)"
  extract_frontmatter_to_file "$task_file" "$frontmatter_file"

  if [[ ! -s "$frontmatter_file" ]]; then
    rm -f "$frontmatter_file"
    echo "unable to extract task frontmatter: $task_file" >&2
    return 1
  fi

  if ! yq -e '.intended_write_targets | type == "array"' "$frontmatter_file" >/dev/null 2>&1; then
    rm -f "$frontmatter_file"
    echo "task missing intended_write_targets array: $task_file" >&2
    return 1
  fi

  local count
  count="$(yq -r '.intended_write_targets | length' "$frontmatter_file")"
  rm -f "$frontmatter_file"
  printf '%s' "$count"
}

agent_requires_write_targets() {
  local agent="$1"
  case "$agent" in
    fe|frontend|front-end|be|backend|back-end|db|database|data-store)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

validate_write_target_requirement() {
  local owner_agent="$1"
  shift
  local -a targets=("$@")

  if ! agent_requires_write_targets "$owner_agent"; then
    return 0
  fi

  (( ${#targets[@]} > 0 )) || {
    echo "coding tasks for owner_agent=$owner_agent require non-empty intended_write_targets (pass --write-target <path>)" >&2
    return 1
  }
}

validate_task_write_target_policy() {
  local task_file="$1"
  local owner_agent="$2"

  if ! agent_requires_write_targets "$owner_agent"; then
    return 0
  fi

  local count
  count="$(task_intended_write_target_count "$task_file")" || return 1
  (( count > 0 )) || {
    echo "coding tasks for owner_agent=$owner_agent require non-empty intended_write_targets: $task_file" >&2
    return 1
  }
}

canonicalize_write_targets() {
  local -a targets=("$@")
  local -a normalized=()
  local target canonical_target existing

  for target in "${targets[@]}"; do
    [[ -n "$target" ]] || continue
    canonical_target="$(canonicalize_target_path "$target")"
    local seen=0
    for existing in "${normalized[@]}"; do
      if [[ "$existing" == "$canonical_target" ]]; then
        seen=1
        break
      fi
    done
    if [[ "$seen" -eq 0 ]]; then
      normalized+=("$canonical_target")
    fi
  done

  printf '%s\n' "${normalized[@]}"
}

yaml_quote_single() {
  local value="$1"
  value="${value//\'/\'\'}"
  printf "'%s'" "$value"
}

yaml_inline_list() {
  local -a values=("$@")
  if (( ${#values[@]} == 0 )); then
    printf '[]'
    return 0
  fi

  local index
  local rendered="["
  for index in "${!values[@]}"; do
    if (( index > 0 )); then
      rendered+=", "
    fi
    rendered+="$(yaml_quote_single "${values[$index]}")"
  done
  rendered+="]"
  printf '%s' "$rendered"
}

role_current_signature() {
  local role_file="$1"
  sed -n 's/^<!-- fit_signature: \(.*\) -->$/\1/p' "$role_file" | head -n1
}

role_is_auto_managed() {
  local role_file="$1"
  grep -Fxq "<!-- role_profile: auto-generated -->" "$role_file"
}

role_has_required_sections() {
  local role_file="$1"
  local section

  for section in "Task-fit profile:" "Primary focus:" "Execution rules:" "Delegation rules:"; do
    if ! grep -Fxq "$section" "$role_file"; then
      return 1
    fi
  done

  return 0
}

role_mentions_tags() {
  local role_file="$1"
  local tags="$2"
  local tag

  for tag in $tags; do
    [[ "$tag" == "general" ]] && continue
    if ! grep -qi "$tag" "$role_file"; then
      return 1
    fi
  done

  return 0
}

role_unfit_for_task() {
  local role_file="$1"
  local expected_signature="$2"
  local tags="$3"

  [[ -f "$role_file" ]] || return 0
  role_has_required_sections "$role_file" || return 0

  if [[ -n "$expected_signature" ]]; then
    local current_signature
    current_signature="$(role_current_signature "$role_file")"

    if [[ -n "$current_signature" ]]; then
      [[ "$current_signature" == "$expected_signature" ]] || return 0
      return 1
    fi

    role_mentions_tags "$role_file" "$tags" || return 0
  fi

  return 1
}

infer_skill_tags() {
  local agent="$1"
  local task_file="${2:-}"

  local corpus="$agent"
  if [[ -n "$task_file" && -f "$task_file" ]]; then
    corpus="$corpus $(cat "$task_file")"
  fi
  corpus="$(printf '%s' "$corpus" | tr '[:upper:]' '[:lower:]')"

  local tags=""

  case "$agent" in
    pm|product|coordinator) tags="$(append_unique_word "$tags" "product")" ;;
    designer|design|ux|ui) tags="$(append_unique_word "$tags" "design")" ;;
    architect|architecture) tags="$(append_unique_word "$tags" "architecture")" ;;
    fe|frontend|front-end) tags="$(append_unique_word "$tags" "frontend")" ;;
    be|backend|back-end) tags="$(append_unique_word "$tags" "backend")" ;;
    db|database|data-store) tags="$(append_unique_word "$tags" "database")" ;;
    review|qa|tester|testing) tags="$(append_unique_word "$tags" "qa")" ;;
  esac

  if text_matches "$corpus" '(product|roadmap|scope|requirement|backlog|acceptance criteria|priorit)'; then
    tags="$(append_unique_word "$tags" "product")"
  fi
  if text_matches "$corpus" '(design|ux|ui|wireframe|prototype|figma|layout|copy)'; then
    tags="$(append_unique_word "$tags" "design")"
  fi
  if text_matches "$corpus" '(architect|architecture|system design|interface|contract|boundary|sequence)'; then
    tags="$(append_unique_word "$tags" "architecture")"
  fi
  if text_matches "$corpus" '(frontend|front-end|react|vue|svelte|angular|css|html|browser|component|client)'; then
    tags="$(append_unique_word "$tags" "frontend")"
  fi
  if text_matches "$corpus" '(backend|back-end|api|endpoint|server|service|handler|controller|grpc|rest)'; then
    tags="$(append_unique_word "$tags" "backend")"
  fi
  if text_matches "$corpus" '(database|db|sql|schema|migration|index|query|postgres|mysql|redis)'; then
    tags="$(append_unique_word "$tags" "database")"
  fi
  if text_matches "$corpus" '(qa|test|testing|e2e|integration|regression|review|verification|validate)'; then
    tags="$(append_unique_word "$tags" "qa")"
  fi
  if text_matches "$corpus" '(security|auth|authentication|authorization|permission|token|owasp|encrypt|vuln)'; then
    tags="$(append_unique_word "$tags" "security")"
  fi
  if text_matches "$corpus" '(deploy|deployment|infra|infrastructure|ci|cd|docker|kubernetes|helm|terraform|observability)'; then
    tags="$(append_unique_word "$tags" "infra")"
  fi
  if text_matches "$corpus" '(analytics|metric|tracking|event|etl|warehouse|model|reporting|dataset|pipeline)'; then
    tags="$(append_unique_word "$tags" "data")"
  fi

  if [[ -z "$tags" ]]; then
    tags="general"
  fi

  printf '%s\n' $tags
}

render_primary_focus_lines() {
  local tags="$1"
  local tag

  for tag in $tags; do
    case "$tag" in
      product)
        cat <<'EOF'
- Translate goals into explicit scope, constraints, and acceptance criteria.
- Prioritize work sequencing to reduce dependency churn.
EOF
        ;;
      design)
        cat <<'EOF'
- Define interaction flows, edge states, and accessible behavior.
- Produce implementation-ready guidance for FE work.
EOF
        ;;
      architecture)
        cat <<'EOF'
- Define system boundaries, contracts, and dependency order.
- Reduce cross-team ambiguity before implementation starts.
EOF
        ;;
      frontend)
        cat <<'EOF'
- Implement user-facing behavior with reliable state handling and API integration.
- Preserve usability and consistency across desktop/mobile surfaces.
EOF
        ;;
      backend)
        cat <<'EOF'
- Implement service logic, contracts, validation, and error handling.
- Keep API behavior deterministic and observable.
EOF
        ;;
      database)
        cat <<'EOF'
- Own schema/migration safety, constraints, and data integrity.
- Keep migrations reversible or clearly risk-documented.
EOF
        ;;
      qa)
        cat <<'EOF'
- Identify regressions, missing tests, and acceptance gaps.
- Report findings with reproducible evidence.
EOF
        ;;
      security)
        cat <<'EOF'
- Enforce authentication/authorization and secure data handling expectations.
- Surface abuse paths and sensitive-risk gaps early.
EOF
        ;;
      infra)
        cat <<'EOF'
- Ensure deployment/runtime readiness, observability, and operational safety.
- Keep rollout and rollback paths explicit.
EOF
        ;;
      data)
        cat <<'EOF'
- Ensure events/metrics/data contracts are explicit and trustworthy.
- Protect data quality for downstream analytics/reporting.
EOF
        ;;
      *)
        cat <<'EOF'
- Deliver the requested outcome for your skill area with minimal scope expansion.
EOF
        ;;
    esac
  done
}

render_verification_lines() {
  local tags="$1"
  local tag

  for tag in $tags; do
    case "$tag" in
      frontend)
        echo "- Run frontend lint/build/test commands relevant to touched files."
        ;;
      backend)
        echo "- Run backend unit/integration checks covering contract and error paths."
        ;;
      database)
        echo "- Validate migration/apply paths and schema compatibility assumptions."
        ;;
      qa)
        echo "- Verify reported findings against acceptance criteria and changed code paths."
        ;;
      infra)
        echo "- Validate deploy/runtime checks and any required operational smoke tests."
        ;;
      security)
        echo "- Verify auth/permission behavior and sensitive-path handling."
        ;;
      data)
        echo "- Validate event/data outputs and expected schema fields."
        ;;
      *)
        ;;
    esac
  done
}

render_delegation_lines() {
  local tags="$1"
  local tag

  for tag in $tags; do
    case "$tag" in
      product)
        echo "- Delegate implementation to specialist skills (designer/architect/fe/be/db/review) when deeper execution is needed."
        ;;
      design)
        echo "- Delegate build work to FE and escalate contract gaps to PM/architect."
        ;;
      architecture)
        echo "- Delegate build tasks to FE/BE/DB with explicit interfaces and dependency ordering."
        ;;
      frontend)
        echo "- Delegate backend/data-contract blockers to BE/DB or creator agent."
        ;;
      backend)
        echo "- Delegate schema concerns to DB and UI-impact follow-ups to FE when needed."
        ;;
      database)
        echo "- Delegate consumer contract alignment to BE/architect if usage assumptions are unclear."
        ;;
      qa)
        echo "- Delegate fixes to owning implementation agents with precise reproduction notes."
        ;;
      security)
        echo "- Delegate remediations to impacted FE/BE/infra owners with clear risk notes."
        ;;
      infra)
        echo "- Delegate service-specific code changes to owning FE/BE/DB agents."
        ;;
      data)
        echo "- Delegate instrumentation/contract fixes to FE/BE/DB owners as appropriate."
        ;;
      *)
        ;;
    esac
  done

  echo "- If blocked by ambiguity or missing dependency, stop and report blocker to creator agent."
}

coordinator_handover_path() {
  printf '%s/reports/coordinator/HANDOVER.md' "$ROOT"
}

ensure_coordinator_handover() {
  local agent="$1"
  [[ "$agent" == "coordinator" ]] || return 0

  local handover_file
  handover_file="$(coordinator_handover_path)"
  [[ -f "$handover_file" ]] && return 0

  cat >"$handover_file" <<EOF
# Coordinator Handover

Last updated: $(now)

## Current Objective
- User objective:
- Parent task:

## Active Plan
- Current phase:
- In-progress tasks:

## Delegation Status
- Waiting on:
- Recently completed:

## Decisions and Constraints
- Key decisions:
- Constraints:

## Risks and Blockers
- Active blockers:
- Mitigations:

## Next Actions
1. Capture the next coordinator action before ending the session.

## Resume Checklist
1. Read this handover first.
2. Check current queues with \`scripts/taskctl.sh list coordinator\`.
3. Resume from \`## Next Actions\`.
4. Update this file after meaningful plan/delegation changes and before completing or blocking a task.
EOF
}

generate_role_prompt() {
  local agent="$1"
  local role_file="$2"
  local task_file="${3:-}"
  local tags="$4"
  local tags_csv="$5"
  local fit_signature="$6"

  local fit_source="general"
  if [[ -n "$task_file" ]]; then
    fit_source="$task_file"
  fi

  cat >"$role_file" <<EOF
<!-- role_profile: auto-generated -->
<!-- role_agent: $agent -->
<!-- role_tags: $tags_csv -->
<!-- fit_signature: $fit_signature -->
<!-- fit_source: $fit_source -->
<!-- generated_at: $(now) -->

You are the $agent specialist agent.

Task-fit profile:
- skill: $agent
- inferred_domains: $tags_csv
- fit_source: $fit_source

Primary focus:
EOF

  render_primary_focus_lines "$tags" >>"$role_file"

  cat >>"$role_file" <<EOF

Execution rules:
- Keep scope limited to the active task and its acceptance criteria.
- Record implementation outcomes and exact verification commands in the task's \`## Result\` section.
- If blocked by dependency or ambiguity, stop immediately and report via \`scripts/taskctl.sh block $agent <TASK_ID> "reason"\`.
EOF

  if [[ "$agent" == "coordinator" ]]; then
    local handover_file
    handover_file="$(coordinator_handover_path)"
    cat >>"$role_file" <<EOF
- Handover continuity: maintain \`$handover_file\` as the persistent coordinator state file.
- At startup, read \`$handover_file\` first and resume work from its \`## Next Actions\`.
- Update \`$handover_file\` after meaningful plan or delegation changes.
- Update \`$handover_file\` before completing (\`scripts/taskctl.sh done coordinator <TASK_ID>\`) or before blocking (\`scripts/taskctl.sh block coordinator <TASK_ID> "reason"\`) a task.
EOF
  fi

  render_verification_lines "$tags" >>"$role_file"

  cat >>"$role_file" <<'EOF'

Delegation rules:
EOF

  render_delegation_lines "$tags" >>"$role_file"

  cat >>"$role_file" <<'EOF'

Definition of done:
- Deliverables in the task are complete and acceptance criteria are met.
- Verification evidence is captured in the task result.
- Any required follow-up tasks are explicitly delegated with owner, priority, and parent linkage.
EOF
}

ensure_agent_scaffold() {
  local agent="$1"
  local task_ref="${2:-}"
  local force_refresh="${3:-0}"

  require_agent "$agent"
  [[ "$agent" == "system" ]] && return 0

  mkdir -p \
    "$ROOT/inbox/$agent" \
    "$ROOT/in_progress/$agent" \
    "$ROOT/done/$agent" \
    "$ROOT/blocked/$agent" \
    "$ROOT/reports/$agent" \
    "$ROOT/runtime/logs/$agent" \
    "$ROOT/runtime/pids" \
    "$ROOT/roles"

  ensure_coordinator_handover "$agent"

  local role_file="$ROOT/roles/$agent.md"

  local task_file=""
  if [[ -n "$task_ref" ]]; then
    if ! task_file="$(resolve_task_file "$task_ref")"; then
      echo "unable to resolve task reference: $task_ref" >&2
      return 1
    fi
  fi

  local tags
  tags="$(infer_skill_tags "$agent" "$task_file" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
  [[ -n "$tags" ]] || tags="general"

  local tags_csv
  tags_csv="${tags// /,}"

  local fit_signature
  fit_signature="$(compute_fit_signature "$agent" "$task_file" "$tags_csv")"

  local needs_refresh=0
  if [[ ! -f "$role_file" ]]; then
    needs_refresh=1
  elif [[ "$force_refresh" -eq 1 ]]; then
    needs_refresh=1
  elif role_unfit_for_task "$role_file" "$fit_signature" "$tags"; then
    needs_refresh=1
  fi

  if [[ "$needs_refresh" -eq 1 ]]; then
    if [[ -f "$role_file" ]] && ! role_is_auto_managed "$role_file"; then
      local backup_dir="$ROOT/runtime/role_backups/$agent"
      mkdir -p "$backup_dir"
      cp "$role_file" "$backup_dir/$(basename "$role_file").$(date +%Y%m%d%H%M%S).bak"
    fi

    generate_role_prompt "$agent" "$role_file" "$task_file" "$tags" "$tags_csv" "$fit_signature"
  fi
}

find_existing_task() {
  local task_id="$1"
  find "$ROOT" -type f -name "${task_id}.md" \
    ! -path "$ROOT/examples/*" \
    ! -path "$ROOT/templates/*" \
    ! -path "$ROOT/roles/*" | head -n1
}

create_task() {
  local task_id="$1"
  local title="$2"
  local owner="$3"
  local creator="$4"
  local priority="$5"
  local parent_task_id="${6:-}"
  shift 6
  local -a requested_targets=("$@")
  local -a write_targets=()

  require_task_id "$task_id"
  require_agent "$owner"
  require_agent "$creator"
  priority="$(normalize_priority "$priority")"

  if (( ${#requested_targets[@]} > 0 )); then
    while IFS= read -r target; do
      [[ -n "$target" ]] || continue
      write_targets+=("$target")
    done < <(canonicalize_write_targets "${requested_targets[@]}")
  fi

  validate_write_target_requirement "$owner" "${write_targets[@]}"

  [[ -f "$TEMPLATE" ]] || { echo "missing template: $TEMPLATE" >&2; exit 1; }

  local existing
  existing="$(find_existing_task "$task_id")"
  [[ -z "$existing" ]] || { echo "task already exists: $existing" >&2; exit 1; }

  ensure_agent_scaffold "$owner"
  ensure_agent_scaffold "$creator"

  local out_dir="$ROOT/inbox/$owner/$(pad_priority "$priority")"
  local out="$out_dir/${task_id}.md"
  mkdir -p "$out_dir"

  cp "$TEMPLATE" "$out"
  set_field "$out" "id" "$task_id"
  set_field "$out" "title" "$title"
  set_field "$out" "owner_agent" "$owner"
  set_field "$out" "creator_agent" "$creator"
  set_field "$out" "status" "inbox"
  set_field "$out" "priority" "$priority"
  set_field "$out" "created_at" "$(now)"
  set_field "$out" "updated_at" "$(now)"

  if [[ -n "$parent_task_id" ]]; then
    require_task_id "$parent_task_id"
    set_field "$out" "parent_task_id" "$parent_task_id"
    set_field "$out" "depends_on" "[$parent_task_id]"
  else
    set_field "$out" "parent_task_id" "none"
    set_field "$out" "depends_on" "[]"
  fi

  if (( ${#write_targets[@]} > 0 )); then
    set_field "$out" "intended_write_targets" "$(yaml_inline_list "${write_targets[@]}")"
  fi

  validate_task_write_target_policy "$out" "$owner"

  ensure_agent_scaffold "$owner" "$out"

  echo "created $out"
}

assign_task() {
  local task_id="$1"
  local target_agent="$2"
  require_task_id "$task_id"
  require_agent "$target_agent"

  ensure_agent_scaffold "$target_agent"

  local src
  src="$(find "$ROOT/inbox" -type f -name "${task_id}.md" | head -n1)"
  [[ -n "$src" ]] || { echo "task not found in inbox queues: $task_id" >&2; exit 1; }
  validate_task_write_target_policy "$src" "$target_agent"

  local priority
  priority="$(field_value "$src" "priority")"
  priority="${priority:-$DEFAULT_PRIORITY}"
  priority="$(normalize_priority "$priority")"

  local dst_dir="$ROOT/inbox/$target_agent/$(pad_priority "$priority")"
  local dst="$dst_dir/${task_id}.md"
  mkdir -p "$dst_dir"

  mv "$src" "$dst"
  set_field "$dst" "owner_agent" "$target_agent"
  set_field "$dst" "status" "inbox"
  set_field "$dst" "updated_at" "$(now)"

  ensure_agent_scaffold "$target_agent" "$dst"

  echo "assigned $task_id -> $target_agent"
}

claim_task() {
  local agent="$1"
  require_agent "$agent"
  [[ "$agent" != "system" ]] || { echo "system cannot claim tasks" >&2; exit 1; }

  ensure_agent_scaffold "$agent"

  local next=""
  local invalid_count=0
  local candidate

  while IFS= read -r candidate; do
    local owner_agent
    owner_agent="$(field_value "$candidate" "owner_agent")"
    owner_agent="${owner_agent:-$agent}"
    if validate_task_write_target_policy "$candidate" "$owner_agent"; then
      next="$candidate"
      break
    fi
    invalid_count=$((invalid_count + 1))
    echo "skipping unclaimable task for $agent: $candidate" >&2
  done < <(find "$ROOT/inbox/$agent" -type f -name '*.md' | sort)

  if [[ -z "$next" ]]; then
    if [[ "$invalid_count" -gt 0 ]]; then
      echo "no claimable tasks in inbox/$agent (fix intended_write_targets metadata)"
    else
      echo "no tasks in inbox/$agent"
    fi
    exit 0
  fi

  local base
  base="$(basename "$next")"
  local dst="$ROOT/in_progress/$agent/$base"

  mv "$next" "$dst"
  set_field "$dst" "status" "in_progress"
  set_field "$dst" "updated_at" "$(now)"

  ensure_agent_scaffold "$agent" "$dst"

  echo "claimed $base"
}

create_blocker_report() {
  local blocker_agent="$1"
  local blocked_task_file="$2"
  local blocked_task_id="$3"
  local reason="$4"

  local creator
  creator="$(field_value "$blocked_task_file" "creator_agent")"
  creator="${creator:-}"

  if [[ -z "$creator" || "$creator" == "none" || "$creator" == "system" ]]; then
    return 0
  fi

  local report_id="BLK-${blocked_task_id}-$(date +%Y%m%d%H%M%S%N)"
  local report_title="Blocker from ${blocker_agent}: ${blocked_task_id}"

  create_task "$report_id" "$report_title" "$creator" "system" 0 "$blocked_task_id"

  local report_file
  report_file="$(find "$ROOT/inbox/$creator" -type f -name "${report_id}.md" | head -n1)"
  [[ -n "$report_file" ]] || return 0

  cat >>"$report_file" <<REPORT_NOTE_EOF

## Blocker Details
- blocked_task: $blocked_task_id
- blocked_by: $blocker_agent
- creator_to_notify: $creator
- blocked_task_file: $blocked_task_file
- reason: $reason

## Requested Action
Resolve ambiguity/dependency, then create follow-up task(s) for the appropriate skill agent.
REPORT_NOTE_EOF
}

transition_task() {
  local action="$1"
  local agent="$2"
  local task_id="$3"
  local note="${4:-}"

  require_agent "$agent"
  require_task_id "$task_id"

  local src="$ROOT/in_progress/$agent/${task_id}.md"
  [[ -f "$src" ]] || { echo "task not in progress for $agent: $src" >&2; exit 1; }

  local priority
  priority="$(field_value "$src" "priority")"
  priority="${priority:-$DEFAULT_PRIORITY}"
  priority="$(normalize_priority "$priority")"
  local pdir
  pdir="$(pad_priority "$priority")"

  local dst_state status
  if [[ "$action" == "done" ]]; then
    dst_state="done"
    status="done"
  else
    dst_state="blocked"
    status="blocked"
  fi

  local dst_dir="$ROOT/$dst_state/$agent/$pdir"
  local dst="$dst_dir/${task_id}.md"
  mkdir -p "$dst_dir"

  mv "$src" "$dst"
  set_field "$dst" "status" "$status"
  set_field "$dst" "updated_at" "$(now)"

  if [[ -n "$note" ]]; then
    if [[ "$action" == "done" ]]; then
      printf "\n## Completion Note\n%s\n" "$note" >>"$dst"
    else
      printf "\n## Blocked Reason\n%s\n" "$note" >>"$dst"
    fi
  fi

  if [[ "$action" == "block" ]]; then
    create_blocker_report "$agent" "$dst" "$task_id" "$note"
  fi

  echo "$action $task_id for $agent"
}

list_tasks() {
  local agent="${1:-}"
  if [[ -n "$agent" ]]; then
    find "$ROOT" -type f -name '*.md' \
      \( -path "$ROOT/inbox/$agent/*" -o -path "$ROOT/in_progress/$agent/*" -o -path "$ROOT/done/$agent/*" -o -path "$ROOT/blocked/$agent/*" -o -path "$ROOT/reports/$agent/*" \) | sort
  else
    find "$ROOT" -type f -name '*.md' \
      \( -path "$ROOT/inbox/*" -o -path "$ROOT/in_progress/*" -o -path "$ROOT/done/*" -o -path "$ROOT/blocked/*" -o -path "$ROOT/reports/*" \) | sort
  fi
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    create)
      [[ $# -ge 3 ]] || { usage; exit 1; }
      local task_id="$2"
      local title="$3"
      local owner="$DEFAULT_OWNER_AGENT"
      local creator="$DEFAULT_CREATOR_AGENT"
      local priority="$DEFAULT_PRIORITY"
      local parent=""
      local -a write_targets=()
      shift 3

      while [[ $# -gt 0 ]]; do
        case "$1" in
          --to)
            owner="$2"
            shift 2
            ;;
          --from)
            creator="$2"
            shift 2
            ;;
          --priority)
            priority="$2"
            shift 2
            ;;
          --parent)
            parent="$2"
            shift 2
            ;;
          --write-target)
            write_targets+=("$2")
            shift 2
            ;;
          *)
            echo "unknown arg: $1" >&2
            usage
            exit 1
            ;;
        esac
      done

      create_task "$task_id" "$title" "$owner" "$creator" "$priority" "$parent" "${write_targets[@]}"
      ;;
    delegate)
      [[ $# -ge 5 ]] || { usage; exit 1; }
      local from_agent="$2"
      local to_agent="$3"
      local task_id="$4"
      local title="$5"
      local priority="$DEFAULT_PRIORITY"
      local parent=""
      local -a write_targets=()
      shift 5

      while [[ $# -gt 0 ]]; do
        case "$1" in
          --priority)
            priority="$2"
            shift 2
            ;;
          --parent)
            parent="$2"
            shift 2
            ;;
          --write-target)
            write_targets+=("$2")
            shift 2
            ;;
          *)
            echo "unknown arg: $1" >&2
            usage
            exit 1
            ;;
        esac
      done

      create_task "$task_id" "$title" "$to_agent" "$from_agent" "$priority" "$parent" "${write_targets[@]}"
      ;;
    assign)
      [[ $# -eq 3 ]] || { usage; exit 1; }
      assign_task "$2" "$3"
      ;;
    claim)
      [[ $# -eq 2 ]] || { usage; exit 1; }
      claim_task "$2"
      ;;
    done)
      [[ $# -ge 3 ]] || { usage; exit 1; }
      local note="${4:-}"
      transition_task done "$2" "$3" "$note"
      ;;
    block)
      [[ $# -ge 4 ]] || { usage; exit 1; }
      shift
      local agent="$1"
      local task_id="$2"
      shift 2
      local reason="$*"
      transition_task block "$agent" "$task_id" "$reason"
      ;;
    lock-acquire)
      [[ $# -eq 4 ]] || { usage; exit 1; }
      lock_acquire "$2" "$3" "$4"
      ;;
    lock-heartbeat)
      [[ $# -eq 4 ]] || { usage; exit 1; }
      lock_heartbeat "$2" "$3" "$4"
      ;;
    lock-release)
      [[ $# -eq 4 ]] || { usage; exit 1; }
      lock_release "$2" "$3" "$4"
      ;;
    lock-release-task)
      [[ $# -eq 3 ]] || { usage; exit 1; }
      lock_release_task "$2" "$3"
      ;;
    lock-status)
      [[ $# -eq 2 ]] || { usage; exit 1; }
      lock_status "$2"
      ;;
    lock-clean-stale)
      local ttl_seconds="$DEFAULT_LOCK_STALE_TTL_SECONDS"
      local actor_agent="${TASK_ACTOR_AGENT:-}"
      shift

      while [[ $# -gt 0 ]]; do
        case "$1" in
          --ttl)
            ttl_seconds="$2"
            shift 2
            ;;
          --actor)
            actor_agent="$2"
            shift 2
            ;;
          *)
            echo "unknown arg: $1" >&2
            usage
            exit 1
            ;;
        esac
      done

      lock_clean_stale "$ttl_seconds" "$actor_agent"
      ;;
    ensure-agent)
      [[ $# -ge 2 ]] || { usage; exit 1; }
      local agent="$2"
      local task_ref=""
      local force_refresh=0
      shift 2

      while [[ $# -gt 0 ]]; do
        case "$1" in
          --task)
            task_ref="$2"
            shift 2
            ;;
          --force)
            force_refresh=1
            shift
            ;;
          *)
            echo "unknown arg: $1" >&2
            usage
            exit 1
            ;;
        esac
      done

      ensure_agent_scaffold "$agent" "$task_ref" "$force_refresh"
      if [[ -n "$task_ref" ]]; then
        echo "ensured agent scaffold: $agent (task-fit refresh checked)"
      else
        echo "ensured agent scaffold: $agent"
      fi
      ;;
    list)
      if [[ $# -eq 2 ]]; then
        list_tasks "$2"
      elif [[ $# -eq 1 ]]; then
        list_tasks
      else
        usage
        exit 1
      fi
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
