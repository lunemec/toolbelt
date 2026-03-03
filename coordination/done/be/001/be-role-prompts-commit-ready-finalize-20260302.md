---
id: be-role-prompts-commit-ready-finalize-20260302
title: Finalize commit-ready curated specialist role prompts
owner_agent: be
creator_agent: pm
parent_task_id: pm-role-prompts-baseline-review-20260302
status: done
priority: 1
depends_on: [pm-role-prompts-baseline-review-20260302]
intended_write_targets: ['coordination/roles/architect.md', 'coordination/roles/be.md', 'coordination/roles/db.md', 'coordination/roles/designer.md', 'coordination/roles/fe.md', 'coordination/roles/pm.md', 'coordination/roles/review.md', 'coordination/in_progress/be/be-role-prompts-commit-ready-finalize-20260302.md']
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-02T10:53:54+0000
updated_at: 2026-03-02T10:54:16+0000
acceptance_criteria:
  - Seven scoped specialist role files are in curated baseline form and commit-ready.
  - No volatile task-fit metadata remains in scoped files.
  - Section structure is present and role-specialized (no broad cross-domain drift).
  - Task result includes exact verification command evidence.
---

## Prompt
Produce commit-ready curated baseline specialist role prompts from current working state.

## Context
Prior implementation is mostly correct but audit runs by `review` reintroduced metadata in `coordination/roles/review.md` due worker auto-fit behavior.
Need a final deterministic normalization pass by a non-review lane.

## Deliverables
Normalize these files only:
1. `coordination/roles/architect.md`
2. `coordination/roles/be.md`
3. `coordination/roles/db.md`
4. `coordination/roles/designer.md`
5. `coordination/roles/fe.md`
6. `coordination/roles/pm.md`
7. `coordination/roles/review.md`

Rules:
1. Remove generated metadata and task-fit profile blocks from these seven files.
2. Keep durable structure: `Primary focus`, `Execution rules`, `Delegation rules`, `Definition of done`.
3. Keep role scope concise and role-specific.
4. Do not touch `coordination/roles/coordinator.md` in this task.

## Validation
Run and report:
1. `rg -n \"fit_signature|fit_source|generated_at|role_profile|Task-fit profile\" coordination/roles/{architect,be,db,designer,fe,pm,review}.md || true` (expect no output)
2. `rg -n \"^Primary focus:|^Execution rules:|^Delegation rules:|^Definition of done:\" coordination/roles/{architect,be,db,designer,fe,pm,review}.md`
3. `git diff -- coordination/roles/{architect,be,db,designer,fe,pm,review}.md`

## Result
Agent fills this before moving the task to `done` or `blocked`.

## Completion Note
Completed by worker; log: coordination/runtime/logs/be/be-role-prompts-commit-ready-finalize-20260302-20260302-105408.log
