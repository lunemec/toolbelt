---
id: coordinator-role-prompts-final-scrub-20260302
title: Final specialist role baseline scrub via non-target lane
owner_agent: coordinator
creator_agent: pm
parent_task_id: pm-role-prompts-baseline-review-20260302
status: done
priority: 1
depends_on: [pm-role-prompts-baseline-review-20260302]
intended_write_targets: ['coordination/roles/architect.md', 'coordination/roles/be.md', 'coordination/roles/db.md', 'coordination/roles/designer.md', 'coordination/roles/fe.md', 'coordination/roles/pm.md', 'coordination/roles/review.md', 'coordination/in_progress/coordinator/coordinator-role-prompts-final-scrub-20260302.md']
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-02T11:00:37+0000
updated_at: 2026-03-02T11:02:51+0000
acceptance_criteria:
  - Seven specialist role files are scrubbed of volatile generated metadata/task-fit blocks.
  - Durable section structure remains intact and role-specialized.
  - Task result includes scoped verification command evidence.
---

## Prompt
Final commit-ready scrub for specialist role prompts.
You are a non-target lane for this scrub; ensure all seven specialist files end clean.

## Context
Running a worker for a target role can repopulate its own metadata. This pass uses `coordinator` to avoid that for specialist files.

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
- Scrubbed volatile generated metadata/task-fit blocks from:
  - `coordination/roles/db.md`
  - `coordination/roles/pm.md`
- Verified all seven specialist role files now contain durable section headers (`Primary focus`, `Execution rules`, `Delegation rules`, `Definition of done`) with no generated metadata markers.

Validation evidence:
1. `rg -n "fit_signature|fit_source|generated_at|role_profile|Task-fit profile" coordination/roles/{architect,be,db,designer,fe,pm,review}.md || true`
```text
(no output)
```
2. `rg -n "^Primary focus:|^Execution rules:|^Delegation rules:|^Definition of done:" coordination/roles/{architect,be,db,designer,fe,pm,review}.md`
```text
coordination/roles/review.md:3:Primary focus:
coordination/roles/review.md:8:Execution rules:
coordination/roles/review.md:15:Delegation rules:
coordination/roles/review.md:21:Definition of done:
coordination/roles/pm.md:3:Primary focus:
coordination/roles/pm.md:7:Execution rules:
coordination/roles/pm.md:12:Delegation rules:
coordination/roles/pm.md:16:Definition of done:
coordination/roles/designer.md:3:Primary focus:
coordination/roles/designer.md:8:Execution rules:
coordination/roles/designer.md:15:Delegation rules:
coordination/roles/designer.md:21:Definition of done:
coordination/roles/fe.md:3:Primary focus:
coordination/roles/fe.md:8:Execution rules:
coordination/roles/fe.md:15:Delegation rules:
coordination/roles/fe.md:20:Definition of done:
coordination/roles/db.md:3:Primary focus:
coordination/roles/db.md:17:Execution rules:
coordination/roles/db.md:25:Delegation rules:
coordination/roles/db.md:34:Definition of done:
coordination/roles/be.md:3:Primary focus:
coordination/roles/be.md:8:Execution rules:
coordination/roles/be.md:15:Delegation rules:
coordination/roles/be.md:21:Definition of done:
coordination/roles/architect.md:3:Primary focus:
coordination/roles/architect.md:9:Execution rules:
coordination/roles/architect.md:16:Delegation rules:
coordination/roles/architect.md:22:Definition of done:
```
3. `git diff -- coordination/roles/{architect,be,db,designer,fe,pm,review}.md`
```text
diff --git a/coordination/roles/db.md b/coordination/roles/db.md
@@ -1,10 +1,37 @@
-You are the DB specialist agent.
+You are the db specialist agent.
...
diff --git a/coordination/roles/pm.md b/coordination/roles/pm.md
@@ -1,17 +1,5 @@
-<!-- role_profile: auto-generated -->
-<!-- role_agent: pm -->
-<!-- role_tags: product -->
-<!-- fit_signature: ... -->
-<!-- fit_source: general -->
-<!-- generated_at: ... -->
-
 You are the pm specialist agent.

-Task-fit profile:
-- skill: pm
-- inferred_domains: product
-- fit_source: general
```

## Completion Note
Completed by worker; log: coordination/runtime/logs/coordinator/coordinator-role-prompts-final-scrub-20260302-20260302-110050.log
