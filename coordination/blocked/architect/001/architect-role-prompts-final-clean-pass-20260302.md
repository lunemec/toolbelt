---
id: architect-role-prompts-final-clean-pass-20260302
title: Final clean pass for commit-ready specialist role prompts
owner_agent: architect
creator_agent: pm
parent_task_id: pm-role-prompts-baseline-review-20260302
status: blocked
priority: 1
depends_on: [pm-role-prompts-baseline-review-20260302]
intended_write_targets: ['coordination/roles/architect.md', 'coordination/roles/be.md', 'coordination/roles/db.md', 'coordination/roles/designer.md', 'coordination/roles/fe.md', 'coordination/roles/pm.md', 'coordination/roles/review.md', 'coordination/in_progress/architect/architect-role-prompts-final-clean-pass-20260302.md']
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-02T10:54:42+0000
updated_at: 2026-03-02T10:58:12+0000
acceptance_criteria:
  - Seven scoped specialist role files have no generated task-fit metadata headers/blocks.
  - Files retain curated baseline structure and role specialization.
  - Result section contains verification evidence for scoped files.
---

## Prompt
Perform final metadata scrub pass for commit-ready specialist role prompts.
Important: this is the last worker pass before commit; ensure all scoped files end clean.

## Context
Worker runs can repopulate role metadata for the running agent.
Need single-pass cleanup across all scoped specialist role files, then no more worker runs.

## Deliverables
Clean these files:
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
worker stalled during codex execution; rerouting to simpler implementation lane
