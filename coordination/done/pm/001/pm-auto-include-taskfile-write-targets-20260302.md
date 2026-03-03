---
id: pm-auto-include-taskfile-write-targets-20260302
title: Orchestrate auto-inclusion of in-progress task file in coding task write targets
owner_agent: pm
creator_agent: pm
parent_task_id: none
status: done
priority: 1
depends_on: []
intended_write_targets: []
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-02T16:33:49+0000
updated_at: 2026-03-03T08:31:33+0000
acceptance_criteria:
  - Coding-owner tasks can always update their own in-progress task file `## Result` without manual write-target bookkeeping.
  - Lock policy remains deterministic and does not weaken target-scope safety for non-task files.
  - Independent review validates no regression in claim/done/block lifecycle and write-target enforcement.
---

## Prompt
Orchestrate a targeted hardening change so coding tasks automatically include their in-progress task file in write-target metadata.

## Context
During prior rollout, BE tasks could not update required `## Result` evidence unless the task file path was manually added to `intended_write_targets`.
User approved continuation to harden this behavior.

Open clarification assumption:
- Whether auto-inclusion applies only to coding-owner tasks (`fe`, `be`, `db`) or to all task owners.
Task-local sidecar overrides embedded execution sections when present: `coordination/task_prompts/<TASK_ID>/{prompt,context,deliverables,validation}/*.md`.

## Deliverables
1. Scoped implementation task(s) for `taskctl` metadata behavior hardening.
2. Validation coverage updates to assert this behavior.
3. Independent review confirmation.
4. Parent synthesis and closure decision.

## Validation
Orchestration gates:
1. Child software task includes Red/Green/Blue evidence.
2. Contract tests validate auto-inclusion behavior and no policy regression.
3. Review lane signs off or reports severity-ranked findings.

## Result
Execution summary:

Confirmed scope decision:
1. Auto-inclusion applies only to coding-owner tasks: `fe`, `be`, `db`.

Delegation and outcomes:
1. Initial implementation:
- `coordination/done/be/001/be-auto-include-taskfile-targets-20260302.md`
2. Initial audit surfaced assign-path gap:
- `coordination/done/review/002/review-auto-include-taskfile-targets-audit-20260302.md`
- finding: stale self-target after `coding -> non-coding -> coding` reassignment.
3. First fix cycle:
- `coordination/done/be/001/be-fix-assign-self-target-refresh-20260303.md`
4. Second audit surfaced residual multi-hop stale-target accumulation:
- `coordination/done/review/002/review-fix-assign-self-target-refresh-audit-20260303.md`
5. Final fix cycle:
- `coordination/done/be/001/be-fix-multihop-self-target-prune-20260303.md`
6. Final audit sign-off (no findings):
- `coordination/done/review/002/review-fix-multihop-self-target-prune-audit-20260303.md`

Final behavior achieved:
1. `taskctl create`/`delegate` for coding owners still require explicit `--write-target` and auto-append current task self-target in `in_progress/<owner>/<TASK_ID>.md`.
2. `taskctl assign` to a coding owner prunes historical coding-owner self-targets and keeps exactly the new owner-lane self-target.
3. Non-coding assignment behavior remains unchanged.

Validation evidence (final cycle):
1. `scripts/verify_taskctl_lock_contract.sh` pass
2. `scripts/verify_task_local_prompt_contract.sh` pass
3. `scripts/verify_agent_worker_reasoning_contract.sh` pass

Residual risk:
1. Low: coding-owner set is explicitly `fe|be|db`; introducing new coding-owner lanes requires helper/test updates.

## Completion Note
Completed coding-owner auto-inclusion hardening with multi-hop assign regression closure and independent review sign-off.
