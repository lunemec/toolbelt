---
id: be-reasoning-isolation-tests-20260302
title: Implement reasoning isolation verification tests
owner_agent: be
creator_agent: pm
parent_task_id: pm-reasoning-default-isolation-20260302
status: done
priority: 3
depends_on: [pm-reasoning-default-isolation-20260302, architect-reasoning-isolation-strategy-20260302]
intended_write_targets: ['scripts/verify_agent_worker_reasoning_contract.sh', 'scripts/verify_orchestrator_clarification_suite.sh', 'CHANGELOG.md']
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-02T09:58:31+0000
updated_at: 2026-03-02T10:02:49+0000
acceptance_criteria:
  - Adds an automated reasoning-isolation contract test proving planner-vs-default reasoning selection with no leakage from prior `coordinator` execution.
  - Integrates the new test into `scripts/verify_orchestrator_clarification_suite.sh`.
  - Updates `CHANGELOG.md` with the new verification coverage.
  - Provides explicit red/green/blue evidence in `## Result` with failing then passing command outputs.
---

## Prompt
Implement automated verification for reasoning-isolation behavior in worker orchestration scripts.
You must follow Red -> Green -> Blue workflow and record evidence.

## Context
User needs proof that a non-planner agent (default reasoning) does not reuse `xhigh` chosen for `coordinator`.
Target behavior from `scripts/agent_worker.sh`:
- `coordinator` should resolve to planner effort (`xhigh` by default)
- non-planner agents should resolve to default effort (`none` by default)
- effort resolution should be per-agent invocation, not sticky/shared across invocations.
Use architect task output as strategy input before coding.

## Deliverables
1. New script: `scripts/verify_agent_worker_reasoning_contract.sh`
2. Suite wiring update: `scripts/verify_orchestrator_clarification_suite.sh`
3. Changelog note: `CHANGELOG.md`
4. `## Result` evidence containing:
- Red: failing check before implementation
- Green: minimal implementation passing targeted checks
- Blue: broader relevant verification still green

## Validation
Required success gates:
1. `scripts/verify_agent_worker_reasoning_contract.sh` exits 0 and demonstrates:
- planner agent run (use `coordinator`) logs planner effort
- non-planner run after planner (use `fe`) logs default effort
- assertions fail if either expectation is violated
2. `scripts/verify_orchestrator_clarification_suite.sh` exits 0 with new check included.
3. Red/Green/Blue evidence is explicit and command-based in task result.
4. No edits outside declared `intended_write_targets`.

## Result
Agent fills this before moving the task to `done` or `blocked`.

## Completion Note
Completed by worker; log: coordination/runtime/logs/be/be-reasoning-isolation-tests-20260302-20260302-100220.log
