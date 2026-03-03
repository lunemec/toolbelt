---
id: db-role-prompts-final-scrub-20260302
title: Final scrub of specialist role prompt metadata for commit
owner_agent: db
creator_agent: pm
parent_task_id: pm-role-prompts-baseline-review-20260302
status: blocked
priority: 1
depends_on: [pm-role-prompts-baseline-review-20260302]
intended_write_targets: ['coordination/roles/architect.md', 'coordination/roles/be.md', 'coordination/roles/db.md', 'coordination/roles/designer.md', 'coordination/roles/fe.md', 'coordination/roles/pm.md', 'coordination/roles/review.md', 'coordination/in_progress/db/db-role-prompts-final-scrub-20260302.md']
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-02T10:59:19+0000
updated_at: 2026-03-02T10:59:35+0000
acceptance_criteria:
  - Seven specialist role files are scrubbed of volatile generated metadata/task-fit blocks.
  - Section structure remains intact and role-specific.
  - Task result includes command evidence for scoped files.
---

## Prompt
Run a final scrub across specialist role prompts to produce commit-ready baseline files.
This is final pass; after completion no further worker actions will run before commit.

## Context
Prior runs can repopulate metadata for whichever worker is executed.
Need one deterministic end-of-cycle cleanup on scoped specialist files.

## Deliverables
Scrub and normalize:
1. `coordination/roles/architect.md`
2. `coordination/roles/be.md`
3. `coordination/roles/db.md`
4. `coordination/roles/designer.md`
5. `coordination/roles/fe.md`
6. `coordination/roles/pm.md`
7. `coordination/roles/review.md`

Do not edit `coordination/roles/coordinator.md`.

## Validation
Run and report:
1. `rg -n \"fit_signature|fit_source|generated_at|role_profile|Task-fit profile\" coordination/roles/{architect,be,db,designer,fe,pm,review}.md || true` (expect no output)
2. `rg -n \"^Primary focus:|^Execution rules:|^Delegation rules:|^Definition of done:\" coordination/roles/{architect,be,db,designer,fe,pm,review}.md`
3. `git diff -- coordination/roles/{architect,be,db,designer,fe,pm,review}.md`

## Result
Agent fills this before moving the task to `done` or `blocked`.

## Blocked Reason
write lock conflict for target=coordination/roles/architect.md; lock conflict: target=coordination/roles/architect.md holder_task_id=architect-role-prompts-final-clean-pass-20260302 holder_owner_agent=architect
