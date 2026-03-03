---
id: be-task-local-prompt-runtime-and-taskctl-20260302
title: Implement strict task-local prompt runtime and taskctl sidecars
owner_agent: be
creator_agent: pm
parent_task_id: pm-task-local-prompt-architecture-20260302
status: done
priority: 1
depends_on: [pm-task-local-prompt-architecture-20260302]
intended_write_targets: ['scripts/agent_worker.sh', 'scripts/taskctl.sh', 'coordination/templates/TASK_TEMPLATE.md', 'scripts/verify_agent_worker_reasoning_contract.sh', 'scripts/verify_task_local_prompt_contract.sh', 'coordination/README.md', 'coordination/COORDINATOR_INSTRUCTIONS.md']
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-02T16:08:40+0000
updated_at: 2026-03-02T16:11:01+0000
acceptance_criteria:
  - "Worker runtime prompt is sectioned and task-local only in this order: Prompt -> Context -> Deliverables -> Validation."
  - "Worker no longer merges coordination/roles/*.md into runtime prompt input."
  - "taskctl create/delegate auto-generates sidecar prompt bootstrap files at coordination/task_prompts/<TASK_ID>/."
  - "Legacy tasks without sidecars still execute via embedded section fallback; partial sidecars fallback per section."
  - "Deterministic contract tests exist and pass; task result includes Red/Green/Blue evidence."
---

## Prompt
Implement strict task-local prompt architecture per architect contract and provide complete Red/Green/Blue evidence.

## Context
Architecture contract source:
`coordination/done/architect/001/architect-task-local-prompt-contract-20260302.md`

Use the contract as normative behavior for:
1. Sidecar layout under `coordination/task_prompts/<TASK_ID>/` with section dirs `prompt/context/deliverables/validation` and `000.md` bootstrap files.
2. Worker prompt assembly from sectioned task-local sources only, in fixed order.
3. No runtime role-file prompt merge.
4. Legacy fallback to embedded markdown sections when sidecars/section fragments are missing.

Do not widen scope beyond declared write targets.

## Deliverables
1. Update `scripts/agent_worker.sh` to build runtime prompt from sectioned task-local inputs and fallback rules.
2. Update `scripts/taskctl.sh` so `create` and `delegate` auto-generate sidecar directories/files for new tasks.
3. Update `coordination/templates/TASK_TEMPLATE.md` to align with sectioned task-local workflow (without breaking legacy readability).
4. Add/adjust deterministic verification scripts in declared targets, including `scripts/verify_task_local_prompt_contract.sh`.
5. Update coordination docs in declared targets with concise operator guidance.
6. Fill `## Result` with Red/Green/Blue details:
- Red: failing tests/commands proving missing behavior before change.
- Green: minimal implementation and passing targeted tests.
- Blue: cleanup/refactor and broader relevant checks still passing.

## Validation
Minimum required commands (include output summary in `## Result`):
1. `scripts/verify_task_local_prompt_contract.sh`
2. `scripts/verify_agent_worker_reasoning_contract.sh`
3. `scripts/verify_taskctl_lock_contract.sh`
4. `scripts/verify_task_template_lock_metadata_contract.sh`

Behavior checks to explicitly assert:
1. New task sidecar bootstrap files are generated.
2. Worker execution prompt excludes role-file guidance.
3. Legacy task without sidecar still executes via embedded sections.

## Result
Agent fills this before moving the task to `done` or `blocked`.

## Completion Note
Completed by worker; log: coordination/runtime/logs/be/be-task-local-prompt-runtime-and-taskctl-20260302-20260302-161046.log
