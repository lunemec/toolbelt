---
id: architect-role-prompts-baseline-recommendations-20260302
title: Recommend baseline keep/drop for role prompt diffs
owner_agent: architect
creator_agent: pm
parent_task_id: pm-role-prompts-baseline-review-20260302
status: done
priority: 2
depends_on: [pm-role-prompts-baseline-review-20260302]
intended_write_targets: []
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-02T10:31:09+0000
updated_at: 2026-03-02T10:32:40+0000
acceptance_criteria:
  - Provides explicit keep/adapt/drop recommendations for role prompt diff categories.
  - Distinguishes durable baseline guidance from ephemeral task-fit metadata.
  - Produces actionable recommendation set for PM/user decision.
---

## Prompt
Analyze current `coordination/roles/*.md` unstaged diffs and propose long-term baseline prompt curation recommendations.

## Context
Role files currently include generated task-fit metadata and broadened guidance blocks from recent worker runs.
Need an architectural recommendation for what should be baseline policy versus generated runtime overlay.

## Deliverables
1. Recommendation matrix in `## Result`:
- keep
- adapt/trim
- drop
2. Rationale per category with examples from current diffs.
3. Suggested baseline prompt template shape for specialist roles.

## Validation
Quality gates:
1. Explicitly marks generated metadata (`fit_signature`, `fit_source`, `generated_at`, etc.) as baseline-ineligible unless strong rationale.
2. Recommends concise role-specific scope (avoid cross-domain bloat).
3. Provides practical next-step editing plan that can be delegated to implementation owner.

## Result
### Recommendation matrix (baseline policy vs runtime overlay)

| Diff category | Recommendation | Rationale | Examples in current unstaged diffs |
| --- | --- | --- | --- |
| Generated metadata header comments (`role_profile`, `fit_signature`, `fit_source`, `generated_at`) | drop from committed baseline; keep only in runtime overlay artifacts | These fields are per-run/per-task volatile and create high-churn commits with low policy value. | Added across `architect.md`, `be.md`, `db.md`, `designer.md`, `fe.md`, `review.md`; `pm.md` changed only by `generated_at` timestamp refresh. |
| `Task-fit profile` block (`inferred_domains`, task-scoped `fit_source`) | drop from committed baseline; runtime overlay only | This is explicitly task-fit state, not durable role policy. | Added in all changed role files; includes task-specific source paths (for example `coordination/in_progress/be/...`). |
| Role identity sentence (`You are the <role> specialist agent.`) | keep | Stable, low-noise identity anchor for prompt behavior. | Present consistently in all role files. |
| Primary focus bullets that are role-specific and durable | keep (trim to concise role scope) | Durable role contract should remain, but limited to role-owned outcomes. | `db.md` focus on migration safety is good durable scope. |
| Cross-domain focus bloat copied across roles | adapt/trim aggressively | Broad mixed-domain bullets reduce role specialization and increase conflicting behavior. | `be.md` includes FE/design/architect/review concerns; `architect.md` now includes review/ops/security-adjacent checks; `review.md` includes PM sequencing/planning bullets. |
| Execution rules enforcing scope, result evidence, blocker protocol | keep as shared baseline core | These are stable workflow invariants and should be consistent across roles. | `Keep scope limited...`, `Record implementation outcomes...`, `scripts/taskctl.sh block ...`. |
| Role-specific validation checks in execution rules | adapt per role | Useful when they map to role ownership; remove unrelated checks. | Keep `be.md` contract/error-path testing; keep `fe.md` lint/build/test; keep `db.md` migration/apply validation. |
| Delegation rules | adapt to minimal dependency edges | Current set contains duplicated generic lines and circular/self-referential guidance. | `be.md` and `architect.md` have overlapping generic delegation bullets; some duplicate across many roles. |
| `Definition of done` block | keep (standardized shared text) | Durable and cross-role consistent; should be centralized or copied verbatim once. | Same 3 bullets repeated across role files. |

### Rationale summary

- Baseline-ineligible (ephemeral): `fit_signature`, `fit_source`, `generated_at`, `inferred_domains`, and task-linked source paths should not be committed in `coordination/roles/*.md`.
- Baseline-eligible (durable): role identity, role-owned focus, core execution invariants, blocker protocol, and definition-of-done criteria.
- Main quality issue in current diffs: specialization erosion from cross-domain prompt expansion (notably `be.md`, `architect.md`, `review.md`), which increases ambiguity and instruction conflict.

### Suggested baseline template shape for specialist roles

```md
You are the <ROLE> specialist agent.

Primary focus:
- <2-4 bullets, role-owned outcomes only>

Execution rules:
- Keep scope limited to the active task and acceptance criteria.
- Record outcomes and exact verification commands in task `## Result`.
- If blocked, run: scripts/taskctl.sh block <ROLE> <TASK_ID> "reason"
- <1-2 role-specific verification bullets>

Delegation rules:
- <2-4 role-specific dependency handoff bullets>

Definition of done:
- Deliverables complete and acceptance criteria met.
- Verification evidence captured in task result.
- Required follow-up tasks delegated with owner/priority/parent.
```

Runtime overlay (not committed to baseline role files):
- Generated metadata (`fit_signature`, `fit_source`, `generated_at`, inferred domains).
- Task-specific context expansion for the active task only.

### Practical next-step editing plan (for PM/coordinator delegation)

1. Owner: `pm` (priority `2`, parent `pm-role-prompts-baseline-review-20260302`)
- Approve baseline policy: committed role files contain durable role contract only; generated task-fit data moves to runtime overlay.
2. Owner: `be` or tooling owner (priority `2`, same parent)
- Update prompt-rendering path so task-fit metadata is injected at runtime and not written back to `coordination/roles/*.md`.
3. Owner: `architect` + role owners (priority `3`, same parent)
- Trim each role file to the baseline template, preserving role-specific scope and removing cross-domain bloat.
4. Owner: `review` (priority `3`, same parent)
- Add regression check that role files do not reintroduce volatile keys (`fit_signature`, `fit_source`, `generated_at`, `Task-fit profile`).

### Verification commands run

- `git status --short`
- `git diff -- coordination/roles/architect.md coordination/roles/be.md coordination/roles/db.md coordination/roles/designer.md coordination/roles/fe.md coordination/roles/pm.md coordination/roles/review.md`
- `sed -n '1,220p' coordination/roles/architect.md`
- `sed -n '1,220p' coordination/roles/be.md`
- `sed -n '1,220p' coordination/roles/db.md`
- `sed -n '1,220p' coordination/roles/designer.md`
- `sed -n '1,220p' coordination/roles/fe.md`
- `sed -n '1,220p' coordination/roles/pm.md`
- `sed -n '1,220p' coordination/roles/review.md`
- `sed -n '1,220p' coordination/roles/coordinator.md`
