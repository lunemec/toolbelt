---
id: pm-role-prompts-baseline-review-20260302
title: Orchestrate baseline role prompt curation from generated diffs
owner_agent: pm
creator_agent: pm
parent_task_id: none
status: done
priority: 2
depends_on: []
intended_write_targets: []
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-02T10:30:55+0000
updated_at: 2026-03-02T16:04:07+0000
acceptance_criteria:
  - Clear keep/drop recommendations for role prompt diff content are produced.
  - Recommendations separate task-specific generated metadata from durable baseline guidance.
  - Independent review confirms recommendations are coherent for long-term use.
---

## Prompt
Orchestrate curation of role prompt diffs into long-term baseline guidance recommendations (no implementation commit yet).

## Context
User asked whether new role prompt additions should be included long-term.
Current diffs mix:
1. task-specific auto-generated metadata and fit annotations (likely not baseline)
2. potentially useful evergreen guardrails (execution/delegation/definition of done)
Need recommendation set first, then explicit user decision before editing/staging role files.

## Deliverables
1. `architect` recommendation task with keep/drop rationale per prompt section type.
2. `review` validation task checking recommendation quality and long-term maintainability.
3. Parent synthesis with actionable baseline adoption plan.

## Validation
Quality gates:
1. Recommendations explicitly classify additions into:
- keep as baseline
- adapt/trim
- drop
2. Recommendations avoid task-linked metadata (`fit_source`, timestamps, signatures) in baseline.
3. Review lane provides independent sign-off or findings.

## Result
Recommendation synthesis (architect + review validated):
1. `Drop` from baseline role files:
- all generated metadata headers (`role_profile`, `fit_signature`, `fit_source`, `generated_at`)
- task-fit profile blocks and task-linked inferred domain/source sections
2. `Keep` in baseline role files:
- concise role identity
- core execution invariants (scope discipline, verification evidence, blocker protocol)
- standardized definition-of-done block
3. `Adapt/trim` before baseline commit:
- primary focus bullets to strictly role-owned outcomes
- delegation rules to minimal role-relevant dependency edges
- role-specific validation bullets only when ownership-aligned

Decision-ready guidance for user:
1. Do not commit current role diffs as-is.
2. If adopting long-term improvements, apply a curated baseline rewrite that keeps stable guardrails and removes generated/task-fit content.
3. Optional low-risk follow-up: add regression guard to reject volatile keys in committed `coordination/roles/*.md`.

## Completion Note
Superseded on 2026-03-02 by task-local prompt architecture program requested by user; prior role-prompt scrub track closed.
