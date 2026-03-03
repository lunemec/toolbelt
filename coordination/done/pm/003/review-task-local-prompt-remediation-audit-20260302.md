---
id: review-task-local-prompt-remediation-audit-20260302
title: Re-audit remediation rollout for strict task-local prompts and repair safety
owner_agent: pm
creator_agent: pm
parent_task_id: pm-task-local-prompt-architecture-20260302
status: done
priority: 3
depends_on: [pm-task-local-prompt-architecture-20260302]
intended_write_targets: []
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-02T16:13:21+0000
updated_at: 2026-03-02T16:28:17+0000
acceptance_criteria:
  - Remediation implementation is audited with severity-ranked findings and file references.
  - Review confirms required Red/Green/Blue evidence exists in both BE remediation tasks.
  - Review confirms strict task-local runtime behavior and safe repair overwrite scope via command evidence.
---

## Prompt
Run independent re-audit on remediation tasks and accept only evidence-backed completion.

## Context
Audit these remediation tasks:
1. `be-task-local-prompt-runtime-remediation-20260302`
2. `be-coordination-repair-remediation-20260302`

Prior cycle issue: tasks were marked done without populated result evidence.
This audit must explicitly validate evidence quality and behavior.

## Deliverables
1. Severity-ordered findings with file references for any regressions/gaps.
2. Explicit gate verdicts (pass/fail) for:
- strict task-local worker prompt assembly
- sidecar bootstrap generation on create/delegate
- legacy fallback behavior
- safe overwrite preservation of dynamic lanes
- presence and quality of Red/Green/Blue evidence in BE task result sections
3. If no findings, explicit no-findings statement plus residual risk note.

## Validation
Run and summarize:
1. `scripts/verify_task_local_prompt_contract.sh`
2. `scripts/verify_agent_worker_reasoning_contract.sh`
3. `scripts/verify_coordination_repair_contract.sh`
4. `scripts/verify_taskctl_lock_contract.sh`

Also inspect BE remediation task files directly and confirm `## Result` includes concrete failing->passing evidence and command outcomes.

## Result
Agent fills this before moving the task to `done` or `blocked`.

## Completion Note
Superseded by final completed audit task review-task-local-prompt-final-audit-20260302.
