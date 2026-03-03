---
id: be-fix-assign-self-target-refresh-20260303
title: Fix taskctl assign to refresh coding-owner self task-file write target
owner_agent: be
creator_agent: pm
parent_task_id: pm-auto-include-taskfile-write-targets-20260302
status: done
priority: 1
depends_on: [pm-auto-include-taskfile-write-targets-20260302]
intended_write_targets: ['scripts/taskctl.sh', 'scripts/verify_taskctl_lock_contract.sh', 'coordination/README.md', 'coordination/COORDINATOR_INSTRUCTIONS.md', 'coordination/in_progress/be/be-fix-assign-self-target-refresh-20260303.md']
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-03T08:19:18+0000
updated_at: 2026-03-03T08:22:27+0000
acceptance_criteria:
  - "taskctl assign recomputes coding-owner self task-file target for the new owner lane."
  - "No stale owner-lane self-target remains after assignment for coding owners."
  - "Non-coding owner assignment behavior remains unchanged."
  - "Verifier coverage includes assign-path regression checks and task Result contains Red/Green/Blue evidence."
---

## Prompt
Fix the assign-path regression so coding-owner self-task-file target is refreshed when owner changes.

## Context
Blocking finding from independent review:
- `scripts/taskctl.sh assign` updates `owner_agent` but leaves auto-included self-target tied to old owner lane (`in_progress/<old_owner>/<TASK_ID>.md`).

Scope:
- coding-owner owners only (`fe`, `be`, `db`) should have self-target rewritten to new owner lane path during assign.
- keep behavior stable for non-coding owners.

## Deliverables
1. Update `scripts/taskctl.sh` assign logic to refresh self-target for coding owners.
2. Extend `scripts/verify_taskctl_lock_contract.sh` with deterministic assign-path regression test.
3. Update docs in declared targets if needed for clarity.
4. Populate `## Result` with Red/Green/Blue evidence and changed-file summary.

## Validation
Required commands:
1. `scripts/verify_taskctl_lock_contract.sh`
2. `scripts/verify_task_local_prompt_contract.sh`
3. `scripts/verify_agent_worker_reasoning_contract.sh`
4. `git diff -- scripts/taskctl.sh scripts/verify_taskctl_lock_contract.sh coordination/README.md coordination/COORDINATOR_INSTRUCTIONS.md`

## Result
### Red
- Reproduced regression contract in `scripts/verify_taskctl_lock_contract.sh`:
  - Coding-owner reassignment test (`fe` -> `be`) now asserts `intended_write_targets` moves self-target from `in_progress/fe/<TASK_ID>.md` to `in_progress/be/<TASK_ID>.md`.
  - Non-coding reassignment test (`be` -> `pm`) asserts write-target metadata remains unchanged.

### Green
- Updated `scripts/taskctl.sh` assign flow to refresh self-target metadata for coding owners only:
  - Added `task_intended_write_targets` helper to read current `intended_write_targets`.
  - Added `refresh_assign_self_taskfile_target` and invoked it from `assign_task` after owner update.
  - Behavior: when assigned to `fe|be|db`, stale previous-owner self target is removed and new owner self target is appended/deduped; non-coding owners are unchanged.

### Blue
- Clarified operator docs:
  - `coordination/README.md` now states that `taskctl assign` refreshes coding-owner auto self-target lanes.
  - `coordination/COORDINATOR_INSTRUCTIONS.md` includes the same reassignment rule for orchestrators.

### Verification
1. `scripts/verify_taskctl_lock_contract.sh` (pass)
2. `scripts/verify_task_local_prompt_contract.sh` (pass)
3. `scripts/verify_agent_worker_reasoning_contract.sh` (pass)
4. `git diff -- scripts/taskctl.sh scripts/verify_taskctl_lock_contract.sh coordination/README.md coordination/COORDINATOR_INSTRUCTIONS.md` (reviewed)

### Changed Files
- `scripts/taskctl.sh`
- `scripts/verify_taskctl_lock_contract.sh`
- `coordination/README.md`
- `coordination/COORDINATOR_INSTRUCTIONS.md`
- `coordination/in_progress/be/be-fix-assign-self-target-refresh-20260303.md`

## Completion Note
Completed by worker; log: coordination/runtime/logs/be/be-fix-assign-self-target-refresh-20260303-20260303-081957.log
