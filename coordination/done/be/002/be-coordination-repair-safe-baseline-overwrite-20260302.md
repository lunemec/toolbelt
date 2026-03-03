---
id: be-coordination-repair-safe-baseline-overwrite-20260302
title: Update coordination_repair to safe baseline overwrite only
owner_agent: be
creator_agent: pm
parent_task_id: pm-task-local-prompt-architecture-20260302
status: done
priority: 2
depends_on: [pm-task-local-prompt-architecture-20260302]
intended_write_targets: ['scripts/coordination_repair.sh', 'container/codex-init-workspace.sh', 'scripts/verify_coordination_repair_contract.sh', 'coordination/README.md', 'coordination/COORDINATOR_INSTRUCTIONS.md']
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-02T16:08:44+0000
updated_at: 2026-03-02T16:12:16+0000
acceptance_criteria:
  - "coordination_repair.sh refreshes baseline-managed assets only (scripts plus coordination baseline docs/prompts/roles/templates/examples)."
  - "Repair flow does not overwrite active/dynamic task lanes (inbox, in_progress, done, blocked, reports, runtime) or task-local prompt sidecars."
  - "Behavior is deterministic and test-covered by a dedicated verification script."
  - "Task result includes Red/Green/Blue evidence and command outcomes."
---

## Prompt
Implement safe baseline overwrite behavior in coordination repair flow after task-local architecture rollout.

## Context
This task depends on the architecture rollout in:
`coordination/inbox/be/001/be-task-local-prompt-runtime-and-taskctl-20260302.md`

User requirement:
- Safe to overwrite baseline scripts and baseline coordination prompt/role assets from Docker image.
- Must not overwrite current tasks/history/runtime artifacts.

Keep scope to declared write targets only.

## Deliverables
1. Update `scripts/coordination_repair.sh` overwrite/refresh logic to target only safe baseline-managed paths.
2. Update `container/codex-init-workspace.sh` only if required for a clean, deterministic repair flow; otherwise keep unchanged and explain.
3. Add deterministic verification script `scripts/verify_coordination_repair_contract.sh`.
4. Update docs in declared targets to state exactly what is refreshed vs preserved.
5. Fill `## Result` with Red/Green/Blue evidence:
- Red: failing behavior reproduction that shows unsafe overwrite risk.
- Green: minimal fix and targeted passing checks.
- Blue: cleanup + broader relevant checks still green.

## Validation
Required commands (record concise outcomes in `## Result`):
1. `scripts/verify_coordination_repair_contract.sh`
2. `scripts/verify_top_level_prompt_contract.sh`
3. `scripts/verify_coordinator_instructions_contract.sh`
4. Re-run: `scripts/verify_task_local_prompt_contract.sh`

Required assertions:
1. Baseline refresh updates targeted baseline-managed files.
2. Existing task markdown files in queue lanes are preserved.
3. Existing `coordination/task_prompts/<TASK_ID>/` content is preserved.

## Result
Agent fills this before moving the task to `done` or `blocked`.

## Completion Note
Completed by worker; log: coordination/runtime/logs/be/be-coordination-repair-safe-baseline-overwrite-20260302-20260302-161104.log
