---
id: BLK-architect-role-prompts-final-clean-pass-20260302-20260302105812274690447
title: Blocker from architect: architect-role-prompts-final-clean-pass-20260302
owner_agent: pm
creator_agent: system
parent_task_id: architect-role-prompts-final-clean-pass-20260302
status: done
priority: 0
depends_on: [architect-role-prompts-final-clean-pass-20260302]
intended_write_targets: []
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-02T10:58:12+0000
updated_at: 2026-03-02T10:58:49+0000
acceptance_criteria:
  - Criterion 1
  - Criterion 2
---

## Prompt
Write the exact instructions for the target skill agent.

## Context
Business or technical background and constraints.

## Deliverables
List concrete files/outputs expected.

## Validation
List exact commands/tests that must pass.

## Result
Agent fills this before moving the task to `done` or `blocked`.

## Blocker Details
- blocked_task: architect-role-prompts-final-clean-pass-20260302
- blocked_by: architect
- creator_to_notify: pm
- blocked_task_file: coordination/blocked/architect/001/architect-role-prompts-final-clean-pass-20260302.md
- reason: worker stalled during codex execution; rerouting to simpler implementation lane

## Requested Action
Resolve ambiguity/dependency, then create follow-up task(s) for the appropriate skill agent.

## Completion Note
Resolved by delegating be-role-prompts-commit-ready-finalize-20260302 and architect-role-prompts-final-clean-pass-20260302 follow-up
