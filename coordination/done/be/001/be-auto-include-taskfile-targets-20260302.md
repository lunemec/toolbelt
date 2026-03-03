---
id: be-auto-include-taskfile-targets-20260302
title: Implement auto-inclusion of in-progress task file write target for coding owners
owner_agent: be
creator_agent: pm
parent_task_id: pm-auto-include-taskfile-write-targets-20260302
status: done
priority: 1
depends_on: [pm-auto-include-taskfile-write-targets-20260302]
intended_write_targets: ['scripts/taskctl.sh', 'scripts/verify_taskctl_lock_contract.sh', 'coordination/README.md', 'coordination/COORDINATOR_INSTRUCTIONS.md', 'coordination/in_progress/be/be-auto-include-taskfile-targets-20260302.md']
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-03T08:11:45+0000
updated_at: 2026-03-03T08:16:26+0000
acceptance_criteria:
  - "For owner_agent in fe/be/db, task metadata handling guarantees the task can update its own in-progress task file without manual write-target entry."
  - "Non-coding owner agents preserve current write-target policy behavior."
  - "Verification contract covers create/delegate/claim path and rejects regressions."
  - "Task Result includes explicit Red/Green/Blue evidence with command outcomes."
---

## Prompt
Implement scoped hardening so coding-owner tasks automatically include their own in-progress task file in write-target enforcement behavior.

## Context
Scope confirmed by user:
- Apply auto-inclusion only to coding owner agents: `fe`, `be`, `db`.
- Do not change behavior for non-coding owners.

Reason:
- Coding tasks require write-target enforcement and must always be able to append `## Result` evidence in their task file.

## Deliverables
1. Update `scripts/taskctl.sh` to ensure coding-owner tasks effectively include their in-progress task file path under write-target policy.
2. Update `scripts/verify_taskctl_lock_contract.sh` with deterministic checks for this behavior.
3. Update docs in declared targets with concise policy note.
4. Populate `## Result` with Red/Green/Blue evidence and changed-file summary.

## Validation
Required commands:
1. `scripts/verify_taskctl_lock_contract.sh`
2. `scripts/verify_task_local_prompt_contract.sh`
3. `scripts/verify_agent_worker_reasoning_contract.sh`
4. `git diff -- scripts/taskctl.sh scripts/verify_taskctl_lock_contract.sh coordination/README.md coordination/COORDINATOR_INSTRUCTIONS.md`

## Result
Red:
- Verified coding-owner validation remains enforced (no explicit write target still fails):
  - `TASK_ROOT_DIR="<tmp>" scripts/taskctl.sh create rgb-red-no-target "RGB Red" --to fe --from pm --priority 50`
  - exit `1`, output: `coding tasks for owner_agent=fe require non-empty intended_write_targets (pass --write-target <path>)`

Green:
- Implemented coding-owner-only auto-inclusion of task self path for `fe`/`be`/`db` in `scripts/taskctl.sh` (`owner_auto_includes_taskfile_target`, `task_in_progress_write_target`, and create-path write-target assembly).
- Deterministic metadata evidence:
  - `TASK_ROOT_DIR="<tmp>" scripts/taskctl.sh create rgb-green-target "RGB Green" --to be --from pm --priority 50 --write-target scripts/taskctl.sh`
  - `intended_write_targets` includes both explicit target and self task file target (example): `["scripts/taskctl.sh",".taskctl-rgb.cVRQd9/in_progress/be/rgb-green-target.md"]`.
- Required verification commands:
  - `scripts/verify_taskctl_lock_contract.sh` -> `taskctl lock contract checks passed: scripts/taskctl.sh`
  - `scripts/verify_task_local_prompt_contract.sh` -> `task-local prompt contract verified`
  - `scripts/verify_agent_worker_reasoning_contract.sh` -> `agent worker reasoning contract verified`

Blue:
- Contract/docs/tests updated for policy clarity and regression coverage:
  - `scripts/taskctl.sh`
  - `scripts/verify_taskctl_lock_contract.sh`
  - `coordination/README.md`
  - `coordination/COORDINATOR_INSTRUCTIONS.md`
- Required diff command executed:
  - `git diff -- scripts/taskctl.sh scripts/verify_taskctl_lock_contract.sh coordination/README.md coordination/COORDINATOR_INSTRUCTIONS.md`

## Completion Note
Completed by worker; log: coordination/runtime/logs/be/be-auto-include-taskfile-targets-20260302-20260303-081236.log
