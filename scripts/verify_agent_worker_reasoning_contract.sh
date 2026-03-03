#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
WORKDIR="$(mktemp -d "$WORKSPACE_ROOT/.verify-agent-worker-reasoning.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

mkdir -p "$WORKDIR/bin"
ln -s "$WORKSPACE_ROOT/scripts" "$WORKDIR/scripts"
mkdir -p "$WORKDIR/coordination"
mkdir -p "$WORKDIR/coordination/in_progress/coordinator" "$WORKDIR/coordination/in_progress/fe"

cat > "$WORKDIR/coordination/in_progress/coordinator/coord-task.md" <<'TASK'
---
id: coord-task
owner_agent: coordinator
creator_agent: pm
status: in_progress
priority: 1
intended_write_targets: ['scripts/dummy-coordinator.txt']
---

## Prompt
noop

## Result
pending
TASK

cat > "$WORKDIR/coordination/in_progress/fe/fe-task.md" <<'TASK'
---
id: fe-task
owner_agent: fe
creator_agent: pm
status: in_progress
priority: 1
intended_write_targets: ['scripts/dummy-fe.txt']
---

## Prompt
noop

## Result
pending
TASK

cat > "$WORKDIR/bin/taskctl_stub.sh" <<'EOF_TASKCTL'
#!/usr/bin/env bash
set -euo pipefail
cmd="${1:-}"
if [[ "$cmd" == "claim" ]]; then
  agent="${2:-}"
  if [[ "$agent" == "coordinator" ]]; then
    printf '%s\n' 'coord-task'
  elif [[ "$agent" == "fe" ]]; then
    printf '%s\n' 'fe-task'
  else
    exit 1
  fi
  exit 0
fi
if [[ "$cmd" == "ensure-agent" ]]; then
  exit 0
fi
if [[ "$cmd" == "lock-acquire" ]]; then
  exit 0
fi
if [[ "$cmd" == "lock-heartbeat" ]]; then
  exit 0
fi
if [[ "$cmd" == "lock-release-task" ]]; then
  exit 0
fi
if [[ "$cmd" == "done" ]]; then
  exit 0
fi
if [[ "$cmd" == "block" ]]; then
  exit 0
fi
printf 'unsupported taskctl stub call: %s\n' "$*" >&2
exit 1
EOF_TASKCTL
chmod +x "$WORKDIR/bin/taskctl_stub.sh"

cat > "$WORKDIR/bin/codex" <<'EOF_CODEX'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${FAKE_CODEX_CAPTURE:?}"
exit 0
EOF_CODEX
chmod +x "$WORKDIR/bin/codex"

export PATH="$WORKDIR/bin:$PATH"
export AGENT_TASKCTL="$WORKDIR/bin/taskctl_stub.sh"
export FAKE_CODEX_CAPTURE="$WORKDIR/codex_calls.log"
: > "$FAKE_CODEX_CAPTURE"

run_worker_once() {
  local agent="$1"
  (
    cd "$WORKDIR"
    AGENT_ROOT_DIR=coordination \
    AGENT_XHIGH_AGENTS="pm coordinator architect" \
    AGENT_PLANNER_REASONING_EFFORT=xhigh \
    AGENT_DEFAULT_REASONING_EFFORT=none \
    "$WORKSPACE_ROOT/scripts/agent_worker.sh" "$agent" --once >/dev/null
  )
}

run_worker_once coordinator
run_worker_once fe

if [[ $(wc -l < "$FAKE_CODEX_CAPTURE") -ne 2 ]]; then
  echo "expected exactly 2 codex executions" >&2
  cat "$FAKE_CODEX_CAPTURE" >&2
  exit 1
fi

coord_line="$(sed -n '1p' "$FAKE_CODEX_CAPTURE")"
fe_line="$(sed -n '2p' "$FAKE_CODEX_CAPTURE")"

[[ "$coord_line" == *'model_reasoning_effort="xhigh"'* ]] || {
  echo "coordinator did not receive planner reasoning effort" >&2
  echo "$coord_line" >&2
  exit 1
}

[[ "$fe_line" == *'model_reasoning_effort="none"'* ]] || {
  echo "fe did not receive default reasoning effort" >&2
  echo "$fe_line" >&2
  exit 1
}

if [[ "$fe_line" == *'model_reasoning_effort="xhigh"'* ]]; then
  echo "reasoning leakage detected: fe invocation used xhigh" >&2
  echo "$fe_line" >&2
  exit 1
fi

echo "agent worker reasoning contract verified"
