---
id: TASK-0000
title: Replace with task title
owner_agent: pm
creator_agent: pm
parent_task_id: none
status: inbox
priority: 50
depends_on: []
phase: plan
requirement_ids: []
evidence_commands: []
evidence_artifacts: []
intended_write_targets: []
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-02-19T00:00:00+0000
updated_at: 2026-02-19T00:00:00+0000
acceptance_criteria:
  - Criterion 1
  - Criterion 2
---

## Prompt
Write the exact instructions for the target skill agent.

## Context
Business or technical background and constraints.
Task-local sidecar overrides embedded execution sections when present: `coordination/task_prompts/<TASK_ID>/{prompt,context,deliverables,validation}/*.md`.

## Deliverables
List concrete files/outputs expected.

## Validation
List exact commands/tests that must pass.

## Result
Agent fills this before moving the task to `done` or `blocked`.
For `phase: execute|review|closeout`, include:
- `Acceptance Criteria:` with pass/fail status per criterion.
- One or more `Command:` + `Exit:` evidence entries.
