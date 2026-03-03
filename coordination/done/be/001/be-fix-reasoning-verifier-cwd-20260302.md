---
id: be-fix-reasoning-verifier-cwd-20260302
title: Correct reasoning verifier cwd handling so checks pass
owner_agent: be
creator_agent: pm
parent_task_id: pm-reasoning-default-isolation-20260302
status: done
priority: 1
depends_on: [pm-reasoning-default-isolation-20260302]
intended_write_targets: ['scripts/verify_agent_worker_reasoning_contract.sh', 'scripts/verify_orchestrator_clarification_suite.sh', 'CHANGELOG.md']
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-02T10:08:54+0000
updated_at: 2026-03-02T10:10:15+0000
acceptance_criteria:
  - scripts/verify_agent_worker_reasoning_contract.sh exits 0.
  - scripts/verify_orchestrator_clarification_suite.sh exits 0 including reasoning contract step.
  - Verifier still checks coordinator xhigh and non-planner none with explicit no-leak assertion.
  - Changelog stays accurate for reasoning verification behavior.
---

## Prompt
Implement the specific cwd/root fix in the reasoning verifier so it is compatible with `scripts/agent_worker.sh` workspace guard.
This task is blocked on a concrete bug; apply a minimal deterministic correction.

## Context
Confirmed high-severity regression from review:
- `scripts/verify_agent_worker_reasoning_contract.sh` currently creates `WORKDIR="$(mktemp -d)"` under `/tmp` and invokes worker from that cwd.
- `scripts/agent_worker.sh` enforces cwd under `/workspace`, so verifier fails immediately.
Need explicit correction to verifier harness, not a documentation-only update.

## Deliverables
1. Update `scripts/verify_agent_worker_reasoning_contract.sh` so worker invocations satisfy `/workspace` cwd guard.
2. Preserve and validate reasoning assertions:
- coordinator invocation includes `model_reasoning_effort=\"xhigh\"`
- non-planner invocation includes `model_reasoning_effort=\"none\"`
- non-planner invocation must not include `xhigh`
3. If needed, adjust suite/changelog in declared targets.
4. Provide red/green/blue evidence in task output.

## Validation
Required pass gates:
1. `scripts/verify_agent_worker_reasoning_contract.sh`
2. `scripts/verify_orchestrator_clarification_suite.sh`
3. Include command outputs that explicitly show pass status for both commands.

## Result
Agent fills this before moving the task to `done` or `blocked`.

## Completion Note
Completed by worker; log: coordination/runtime/logs/be/be-fix-reasoning-verifier-cwd-20260302-20260302-100915.log
