---
id: review-task-local-prompt-and-repair-audit-20260302
title: Audit task-local prompt rollout and coordination repair safety
owner_agent: review
creator_agent: pm
parent_task_id: pm-task-local-prompt-architecture-20260302
status: done
priority: 3
depends_on: [pm-task-local-prompt-architecture-20260302]
intended_write_targets: []
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-02T16:08:48+0000
updated_at: 2026-03-02T16:12:23+0000
acceptance_criteria:
  - Independent review confirms strict task-local prompt behavior and fallback semantics match approved contract.
  - Independent review confirms coordination repair overwrite scope is safe and does not touch task/runtime lanes.
  - Findings are severity-ranked with file references; if none, review explicitly states no findings and residual risk.
---

## Prompt
Perform independent regression/risk audit of the completed BE rollout tasks and provide sign-off or findings.

## Context
Audit targets:
1. `be-task-local-prompt-runtime-and-taskctl-20260302`
2. `be-coordination-repair-safe-baseline-overwrite-20260302`
3. Contract baseline:
   `coordination/done/architect/001/architect-task-local-prompt-contract-20260302.md`

Focus on behavior correctness, compatibility risk, and workflow safety.

## Deliverables
1. Severity-ordered findings list with file/line references for issues.
2. Explicit pass/fail statement for each contract gate:
- strict task-local prompt assembly
- legacy fallback behavior
- sidecar bootstrap generation
- safe coordination repair overwrite scope
3. Residual risks/follow-ups if no blocking findings.

## Validation
Run and summarize:
1. `scripts/verify_task_local_prompt_contract.sh`
2. `scripts/verify_agent_worker_reasoning_contract.sh`
3. `scripts/verify_coordination_repair_contract.sh`
4. `scripts/verify_taskctl_lock_contract.sh`

Also inspect implementation diffs and confirm no hidden dependency on runtime role-file prompt merge.

## Result
Agent fills this before moving the task to `done` or `blocked`.

## Completion Note
Completed by worker; log: coordination/runtime/logs/review/review-task-local-prompt-and-repair-audit-20260302-20260302-161221.log
