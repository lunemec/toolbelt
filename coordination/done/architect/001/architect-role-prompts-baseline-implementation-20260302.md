---
id: architect-role-prompts-baseline-implementation-20260302
title: Implement curated baseline specialist role prompts
owner_agent: architect
creator_agent: pm
parent_task_id: pm-role-prompts-baseline-review-20260302
status: done
priority: 1
depends_on: [pm-role-prompts-baseline-review-20260302, architect-role-prompts-baseline-recommendations-20260302, review-role-prompts-baseline-recommendations-20260302]
intended_write_targets: ['coordination/roles/architect.md', 'coordination/roles/be.md', 'coordination/roles/db.md', 'coordination/roles/designer.md', 'coordination/roles/fe.md', 'coordination/roles/pm.md', 'coordination/roles/review.md', 'coordination/in_progress/architect/architect-role-prompts-baseline-implementation-20260302.md']
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-02T10:49:13+0000
updated_at: 2026-03-02T10:52:53+0000
acceptance_criteria:
  - Role files are rewritten to curated durable baseline format.
  - Generated task-fit metadata is removed from committed role files.
  - Useful evergreen additions are retained in concise role-specific form.
  - Task result includes concrete before/after verification evidence.
---

## Prompt
Implement curated baseline role prompts using the keep/adapt/drop recommendations.

## Context
Use completed recommendation tasks as source of truth:
1. `coordination/done/architect/002/architect-role-prompts-baseline-recommendations-20260302.md`
2. `coordination/done/review/003/review-role-prompts-baseline-recommendations-20260302.md`
Goal: commit-worthy long-term baseline prompts, not task-fit overlays.

## Deliverables
Update:
1. `coordination/roles/architect.md`
2. `coordination/roles/be.md`
3. `coordination/roles/db.md`
4. `coordination/roles/designer.md`
5. `coordination/roles/fe.md`
6. `coordination/roles/pm.md`
7. `coordination/roles/review.md`

Content rules:
1. Remove volatile generated metadata (`role_profile`, `fit_signature`, `fit_source`, `generated_at`, task-fit profile blocks).
2. Keep concise role identity and durable sections:
- Primary focus
- Execution rules
- Delegation rules
- Definition of done
3. Trim cross-domain scope creep; keep each role role-owned.
4. Preserve blocker protocol and verification-evidence expectations.

## Validation
Run and report:
1. `rg -n \"fit_signature|fit_source|generated_at|role_profile|Task-fit profile\" coordination/roles/*.md` (expect no hits)
2. `rg -n \"^Primary focus:|^Execution rules:|^Delegation rules:|^Definition of done:\" coordination/roles/*.md`
3. `git diff -- coordination/roles/*.md` reviewed for concise role-specific scope

## Result
Implemented curated durable baseline prompts for:
- `coordination/roles/architect.md`
- `coordination/roles/be.md`
- `coordination/roles/db.md`
- `coordination/roles/designer.md`
- `coordination/roles/fe.md`
- `coordination/roles/pm.md`
- `coordination/roles/review.md`

Changes applied:
- Removed volatile generated metadata/comments and `Task-fit profile` blocks from all seven scoped role files.
- Kept durable structure in each file: `Primary focus`, `Execution rules`, `Delegation rules`, `Definition of done`.
- Preserved blocker protocol (`scripts/taskctl.sh block <role> <TASK_ID> "reason"`) and verification evidence requirement in `## Result`.
- Trimmed cross-domain scope creep and aligned each role to role-owned responsibilities.

Before/after verification evidence:

1. Metadata-pattern scan (before edits)
- Command:
  - `rg -n "fit_signature|fit_source|generated_at|role_profile|Task-fit profile" coordination/roles/*.md || true`
- Result:
  - Hits were present in all target files (`architect`, `be`, `db`, `designer`, `fe`, `pm`, `review`) and also `coordinator.md`.

2. Metadata-pattern scan (after edits; required wildcard command)
- Command:
  - `rg -n "fit_signature|fit_source|generated_at|role_profile|Task-fit profile" coordination/roles/*.md || true`
- Result:
  - Hits remain only in `coordination/roles/coordinator.md` (outside this task's declared write targets).
  - No hits in the seven scoped files.

3. Metadata-pattern scan (after edits; scoped target files only)
- Command:
  - `rg -n "fit_signature|fit_source|generated_at|role_profile|Task-fit profile" coordination/roles/{architect,be,db,designer,fe,pm,review}.md || true`
- Result:
  - No output (no matches).

4. Required durable-section presence check
- Command:
  - `rg -n "^Primary focus:|^Execution rules:|^Delegation rules:|^Definition of done:" coordination/roles/*.md`
- Result:
  - All four sections present in each scoped file (and also present in `coordinator.md`).

5. Diff review for concise role-specific scope
- Commands:
  - `git diff -- coordination/roles/*.md`
  - `git diff -- coordination/roles/{architect,be,db,designer,fe,pm,review}.md`
- Result:
  - Reviewed and confirmed concise role-owned scope, retained baseline guardrails, and removed task-fit overlays from scoped files.

## Completion Note
Completed by worker; log: coordination/runtime/logs/architect/architect-role-prompts-baseline-implementation-20260302-20260302-104955.log
