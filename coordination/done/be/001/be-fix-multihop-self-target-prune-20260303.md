---
id: be-fix-multihop-self-target-prune-20260303
title: Fix multi-hop assign stale coding-owner self-target accumulation
owner_agent: be
creator_agent: pm
parent_task_id: pm-auto-include-taskfile-write-targets-20260302
status: done
priority: 1
depends_on: [pm-auto-include-taskfile-write-targets-20260302]
intended_write_targets: ['scripts/taskctl.sh', 'scripts/verify_taskctl_lock_contract.sh', 'coordination/README.md', 'coordination/COORDINATOR_INSTRUCTIONS.md', 'coordination/in_progress/be/be-fix-multihop-self-target-prune-20260303.md']
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-03T08:24:57+0000
updated_at: 2026-03-03T08:28:25+0000
acceptance_criteria:
  - "assign path prunes stale coding-owner self-target entries across multi-hop owner changes."
  - "After assignment to coding owners, exactly one coding-owner self-target remains and matches current owner lane."
  - "Assignment to non-coding owners preserves policy without expanding stale coding-owner target accumulation."
  - "Verifier coverage includes multi-hop regression checks and Result contains Red/Green/Blue evidence."
---

## Prompt
Fix multi-hop reassignment behavior so historical coding-owner self-targets are pruned deterministically.

## Context
Blocking finding from review:
- `be -> pm -> fe` can leave stale `in_progress/be/<TASK_ID>.md` target while adding new `in_progress/fe/<TASK_ID>.md`.

Goal:
- Ensure no accumulation of historical coding-owner self-targets in intended_write_targets.
- Maintain scope to coding-owner behavior (`fe`, `be`, `db`) and preserve non-coding semantics.

## Deliverables
1. Update `scripts/taskctl.sh` assign-path logic to prune stale coding-owner self-targets across multi-hop transitions.
2. Extend `scripts/verify_taskctl_lock_contract.sh` with multi-hop regression assertion (`coding -> non-coding -> coding`).
3. Update docs in declared targets if needed.
4. Populate `## Result` with Red/Green/Blue evidence and changed-file summary.

## Validation
Required commands:
1. `scripts/verify_taskctl_lock_contract.sh`
2. `scripts/verify_task_local_prompt_contract.sh`
3. `scripts/verify_agent_worker_reasoning_contract.sh`
4. `git diff -- scripts/taskctl.sh scripts/verify_taskctl_lock_contract.sh coordination/README.md coordination/COORDINATOR_INSTRUCTIONS.md`

## Result
### Red
- Pre-fix blocking finding (from review context): multi-hop reassignment `be -> pm -> fe` could leave stale `coordination/in_progress/be/<TASK_ID>.md` in `intended_write_targets` while also adding `coordination/in_progress/fe/<TASK_ID>.md`.
- Failure mode: historical coding-owner self-target accumulation across hops.

### Green
- Implemented deterministic pruning in `scripts/taskctl.sh` assign-path refresh logic:
  - When assigning to coding owners (`fe`, `be`, `db`), prune any existing coding-owner self task-file targets for the task ID.
  - Append only the current owner-lane self task-file target.
  - Preserve non-coding assignment behavior (no forced pruning when target owner is non-coding).
- Added regression coverage in `scripts/verify_taskctl_lock_contract.sh`:
  - New `coding -> non-coding -> coding` assertion (`be -> pm -> fe`) verifies final targets include only explicit target(s) plus the current coding owner self target.
- Command: `scripts/verify_taskctl_lock_contract.sh`
  - Exit: `0`
  - Observed key line: `taskctl lock contract checks passed: scripts/taskctl.sh`

### Blue
- Command: `scripts/verify_task_local_prompt_contract.sh`
  - Exit: `0`
  - Observed key line: `task-local prompt contract verified`
- Command: `scripts/verify_agent_worker_reasoning_contract.sh`
  - Exit: `0`
  - Observed key line: `agent worker reasoning contract verified`
- Command: `git diff -- scripts/taskctl.sh scripts/verify_taskctl_lock_contract.sh coordination/README.md coordination/COORDINATOR_INSTRUCTIONS.md`
  - Exit: `0`
  - Observed: scoped diff includes assign-path pruning logic, multi-hop verifier assertions, and doc language update for deterministic coding-owner self-target pruning.

### Changed-file summary
- `scripts/taskctl.sh`
  - Added coding-owner self-target detection/pruning helpers and updated assign refresh path to remove stale coding-owner self-targets before appending current owner target.
- `scripts/verify_taskctl_lock_contract.sh`
  - Added multi-hop regression scenario (`be -> pm -> fe`) and strict final `intended_write_targets` assertions.
- `coordination/README.md`
  - Updated write-target behavior docs to state historical coding-owner self-target pruning on assign-to-coding-owner.
- `coordination/COORDINATOR_INSTRUCTIONS.md`
  - Updated delegation/assign guidance to match deterministic stale coding-owner self-target pruning behavior.

## Completion Note
Completed by worker; log: coordination/runtime/logs/be/be-fix-multihop-self-target-prune-20260303-20260303-082532.log
