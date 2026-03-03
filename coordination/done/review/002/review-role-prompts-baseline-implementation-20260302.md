---
id: review-role-prompts-baseline-implementation-20260302
title: Audit curated baseline specialist role prompts
owner_agent: review
creator_agent: pm
parent_task_id: pm-role-prompts-baseline-review-20260302
status: done
priority: 2
depends_on: [pm-role-prompts-baseline-review-20260302, architect-role-prompts-baseline-implementation-20260302]
intended_write_targets: []
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-02T10:49:13+0000
updated_at: 2026-03-02T10:53:14+0000
acceptance_criteria:
  - Confirms volatile task-fit metadata has been removed from baseline role files.
  - Confirms retained additions are concise and role-specialized.
  - Provides findings-first verdict with sign-off or blockers.
---

## Prompt
Audit curated baseline role prompt implementation for long-term maintainability.

## Context
Implementation should apply keep/adapt/drop policy from completed recommendation cycle.
This audit verifies both policy compliance and role specialization quality.

## Deliverables
1. Findings-first `## Result` with severity ordering.
2. Confirmation of keep/adapt/drop policy adherence.
3. Explicit sign-off verdict for commit readiness.

## Validation
Run and report:
1. `rg -n \"fit_signature|fit_source|generated_at|role_profile|Task-fit profile\" coordination/roles/*.md` (expect no hits)
2. `rg -n \"^Primary focus:|^Execution rules:|^Delegation rules:|^Definition of done:\" coordination/roles/*.md`
3. `git diff -- coordination/roles/*.md` reviewed for role drift / cross-domain bloat

## Result
Agent fills this before moving the task to `done` or `blocked`.

## Completion Note
Completed by worker; log: coordination/runtime/logs/review/review-role-prompts-baseline-implementation-20260302-20260302-105304.log
