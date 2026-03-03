---
id: be-fix-reasoning-verifier-workspace-20260302
title: Fix reasoning contract verifier to satisfy /workspace guard and pass
owner_agent: be
creator_agent: pm
parent_task_id: pm-reasoning-default-isolation-20260302
status: done
priority: 1
depends_on: [pm-reasoning-default-isolation-20260302]
intended_write_targets: ['scripts/verify_agent_worker_reasoning_contract.sh', 'scripts/verify_orchestrator_clarification_suite.sh', 'CHANGELOG.md']
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-02T10:07:12+0000
updated_at: 2026-03-02T10:07:49+0000
acceptance_criteria:
  - scripts/verify_agent_worker_reasoning_contract.sh exits 0 from /workspace.
  - scripts/verify_orchestrator_clarification_suite.sh exits 0 and includes reasoning contract check.
  - Verification harness still asserts coordinator `xhigh` and non-planner default `none` without leakage.
  - Changelog reflects the corrected verification behavior.
---

## Prompt
Fix the reasoning contract verification harness so it passes with current `agent_worker` workspace guards.
Implement minimal changes within declared write targets and preserve intended coverage.

## Context
Current failure observed by both be/review logs:
- `scripts/verify_agent_worker_reasoning_contract.sh` fails with `agent_worker must run from /workspace (current: /tmp/tmp.*)`.
- Suite script fails transitively because it invokes that verifier.
Root cause is harness execution context mismatch versus `scripts/agent_worker.sh` guard requiring cwd under `/workspace`.

## Deliverables
1. Updated `scripts/verify_agent_worker_reasoning_contract.sh` with workspace-compatible harness execution.
2. Any required suite/changelog adjustments in declared targets.
3. `## Result` must include red/green/blue evidence:
- Red: failing behavior before fix
- Green: targeted verifier passes
- Blue: broader suite passes

## Validation
Required success gates:
1. `scripts/verify_agent_worker_reasoning_contract.sh`
2. `scripts/verify_orchestrator_clarification_suite.sh`
3. Verifier output confirms:
- coordinator receives `model_reasoning_effort=\"xhigh\"`
- non-planner invocation receives `model_reasoning_effort=\"none\"`
- non-planner invocation does not contain `xhigh`

## Result
Agent fills this before moving the task to `done` or `blocked`.

## Completion Note
Completed by worker; log: coordination/runtime/logs/be/be-fix-reasoning-verifier-workspace-20260302-20260302-100740.log
