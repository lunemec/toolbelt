---
id: architect-reasoning-isolation-strategy-20260302
title: Define reasoning isolation verification strategy
owner_agent: architect
creator_agent: pm
parent_task_id: pm-reasoning-default-isolation-20260302
status: done
priority: 2
depends_on: [pm-reasoning-default-isolation-20260302]
intended_write_targets: []
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-02T09:58:31+0000
updated_at: 2026-03-02T10:01:41+0000
acceptance_criteria:
  - Defines an implementation-ready strategy for proving per-agent reasoning selection isolation.
  - Identifies at least one deterministic verification path that does not depend on live model behavior.
  - Specifies concrete pass/fail checks and command sequence for implementation and review lanes.
---

## Prompt
Produce the verification strategy for reasoning-isolation testing in `scripts/agent_worker.sh` and hand off implementation-ready guidance to `be`.

## Context
User requirement: verify and test that non-planner agents keep default reasoning effort and do not inherit `xhigh` from a prior `coordinator` run.
Current behavior in `scripts/agent_worker.sh`:
- planner allowlist default: `pm coordinator architect`
- planner effort default: `xhigh`
- default effort for other agents: `none`
- worker logs chosen effort at task start.
No dedicated automated contract test currently verifies cross-agent isolation.

## Deliverables
1. A concise test strategy in `## Result` with:
- primary test approach
- edge cases and negative checks
- specific target files the `be` lane should modify
2. Clear dependency and ordering notes for `be` then `review`.
3. Risk notes (false positives/false negatives) and mitigations.

## Validation
Quality gates:
1. Strategy must include explicit pass/fail assertions for both `coordinator` and one non-planner agent (for example `fe`).
2. Strategy must include deterministic command-level verification using existing local scripts.
3. Strategy must include expected evidence format for `be` red/green/blue reporting.

## Result
### Primary test approach (deterministic, no live model dependency)
- Add `scripts/verify_agent_worker_reasoning_contract.sh` as a contract/smoke verifier that stubs `codex` via a temporary `PATH` shim and captures argv; do not set `AGENT_EXEC_CMD` so `run_default_exec_cmd` is exercised.
- In the verifier, create an isolated temp coordination root (`mktemp -d /workspace/.agent-worker-reasoning-smoke.XXXXXX`), copy `coordination/templates/TASK_TEMPLATE.md`, and create two tasks:
- coordinator task (`--to coordinator`)
- non-planner task (`--to fe --write-target docs/reasoning-smoke.txt`) to satisfy coding-task write-target validation.
- Run workers sequentially against the same temp root:
- `scripts/agent_worker.sh coordinator --once`
- `scripts/agent_worker.sh fe --once`
- Assert from captured codex args and worker logs that reasoning selection is per-invocation and non-sticky.

### Explicit pass/fail assertions
- Pass only if all checks hold:
- coordinator codex invocation includes `model_reasoning_effort="xhigh"`.
- subsequent `fe` codex invocation includes `model_reasoning_effort="none"`.
- `fe` codex invocation does not include `model_reasoning_effort="xhigh"`.
- coordinator worker start log contains `reasoning_effort=xhigh`.
- `fe` worker start log contains `reasoning_effort=none`.
- both tasks land in `done/<agent>/...` with no unexpected blocked transition.
- Fail immediately on missing/inverted assertions or if invocation order/count is not exactly coordinator then `fe`.

### Edge cases and negative checks
- Mandatory isolation sequence: run `coordinator` first, then `fe` in the same root to detect cross-run leakage.
- Mandatory negative assertion: fail if `fe` receives `xhigh` anywhere in captured codex args.
- Config normalization edge check: run one additional `fe` pass with `AGENT_DEFAULT_REASONING_EFFORT=null` and assert resolved effort remains `none`.

### Target files for `be`
- `scripts/verify_agent_worker_reasoning_contract.sh` (new)
- `scripts/verify_orchestrator_clarification_suite.sh` (add new `run_check`)
- `CHANGELOG.md` (note reasoning-isolation contract coverage)

### Dependency and ordering (be -> review)
1. `be` implements verifier script, suite wiring, and changelog update; records red/green/blue evidence.
2. `review` executes after `be` completion; reruns verifier and suite independently; validates assertion quality and evidence completeness.

### Command sequence and evidence format
- `be` Red (pre-implementation): `bash scripts/verify_agent_worker_reasoning_contract.sh`
- Expected: non-zero (missing file or non-executable). Record exit code and key failing line.
- `be` Green (post-implementation): `bash scripts/verify_agent_worker_reasoning_contract.sh`
- Expected: exit 0 and explicit pass marker (for example `agent worker reasoning contract checks passed`).
- `be` Blue (regression sweep): `bash scripts/verify_orchestrator_clarification_suite.sh`
- Expected: exit 0 and output includes reasoning contract check execution.
- `review` validation commands:
- `bash scripts/verify_agent_worker_reasoning_contract.sh`
- `bash scripts/verify_orchestrator_clarification_suite.sh`
- `review` also verifies `be` transcript includes red/green/blue with exact exits.
- Required evidence format in `## Result` (both `be` and `review`): `Command`, `Exit`, `Observed key lines`, `Verdict`.

### Risks and mitigations
- False positive risk: log-only assertions can miss regressions in codex CLI flag wiring.
- Mitigation: assert stub-captured codex argv contains exact `model_reasoning_effort=...` arguments.
- False negative risk: ambient `AGENT_*` environment overrides can skew expected behavior.
- Mitigation: verifier sets explicit reasoning env values and runs in isolated temp root.
- Flake risk: stale coordination/runtime state contaminates results.
- Mitigation: `mktemp` root, deterministic per-run task IDs, and trap-based cleanup.

### Verification commands run by architect
- `sed -n '1,320p' scripts/agent_worker.sh`
- `sed -n '1,280p' scripts/verify_agent_worker_lock_contract.sh`
- `sed -n '1,300p' scripts/verify_orchestrator_clarification_suite.sh`

## Completion Note
Completed strategy and handoff guidance in ## Result
