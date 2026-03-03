---
id: be-configurable-coding-owner-lanes-20260303
title: Implement configurable coding-owner lane policy (ENV primary + CLI override)
owner_agent: be
creator_agent: pm
parent_task_id: pm-configurable-coding-owner-lanes-20260303
status: done
priority: 1
depends_on: [pm-configurable-coding-owner-lanes-20260303]
intended_write_targets: ['scripts/taskctl.sh', 'scripts/verify_taskctl_lock_contract.sh', 'coordination/README.md', 'coordination/COORDINATOR_INSTRUCTIONS.md', 'coordination/in_progress/be/be-configurable-coding-owner-lanes-20260303.md']
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-03T12:41:06+0000
updated_at: 2026-03-03T12:46:11+0000
acceptance_criteria:
  - "Coding-owner lane set is configurable via ENV primary source and optional CLI override."
  - "Effective precedence is CLI override > ENV > default fe,be,db."
  - "Default behavior remains backward-compatible when no override/config is provided."
  - "Write-target auto-inclusion and assign-pruning remain deterministic under configured lane set."
  - "Result section includes explicit Red/Green/Blue evidence with command outcomes."
---

## Prompt
Implement configurable coding-owner lane policy for taskctl using ENV primary source plus optional CLI override.

## Context
Scope confirmed by user:
1. Primary configuration source: environment variable.
2. Optional one-off override: CLI argument.
3. Precedence: CLI > ENV > default (`fe,be,db`).

Maintain existing lock policy guarantees and existing default behavior.

## Deliverables
1. Update `scripts/taskctl.sh` with configurable coding-owner lane resolution (ENV + optional CLI override).
2. Update `scripts/verify_taskctl_lock_contract.sh` to cover:
- default lane behavior
- ENV-configured lane behavior
- CLI-overrides-ENV behavior
3. Update docs in declared targets with concise configuration usage.
4. Populate `## Result` with Red/Green/Blue evidence and changed-file summary.

## Validation
Required commands:
1. `scripts/verify_taskctl_lock_contract.sh`
2. `scripts/verify_task_local_prompt_contract.sh`
3. `scripts/verify_agent_worker_reasoning_contract.sh`
4. `git diff -- scripts/taskctl.sh scripts/verify_taskctl_lock_contract.sh coordination/README.md coordination/COORDINATOR_INSTRUCTIONS.md`

## Result
Red
- Risk addressed: coding-owner lane behavior was hard-coded (`fe,be,db`) so policy could not be configured by environment or one-off CLI invocation.
- Risk addressed: lock-contract verification did not assert ENV-configured lane behavior or CLI-overrides-ENV precedence.

Green
- Implemented configurable coding-owner lane resolution in `scripts/taskctl.sh` with precedence:
  1. CLI `--coding-owner-lanes <agents>`
  2. `TASK_CODING_OWNER_LANES`
  3. default `fe,be,db`
- Wired resolved lanes into coding-owner auto self-target inclusion and coding-owner self-target pruning on `assign`.
- Added CLI override parsing for affected commands: `create`, `delegate`, `assign`, `claim`.
- Extended `scripts/verify_taskctl_lock_contract.sh` coverage for:
  - default lane behavior
  - ENV-configured lane behavior
  - CLI-overrides-ENV behavior
- Updated concise usage docs in:
  - `coordination/README.md`
  - `coordination/COORDINATOR_INSTRUCTIONS.md`

Blue
- Required validation command outcomes:
  - `scripts/verify_taskctl_lock_contract.sh` -> `taskctl lock contract checks passed: scripts/taskctl.sh`
  - `scripts/verify_task_local_prompt_contract.sh` -> `task-local prompt contract verified`
  - `scripts/verify_agent_worker_reasoning_contract.sh` -> `agent worker reasoning contract verified`
  - `git diff -- scripts/taskctl.sh scripts/verify_taskctl_lock_contract.sh coordination/README.md coordination/COORDINATOR_INSTRUCTIONS.md` -> diff shows configurable coding-owner lanes in `taskctl`, new precedence assertions in lock-contract verification, and matching coordination doc updates.
- Changed-file summary:
  - `scripts/taskctl.sh`: configurable coding-owner lane resolver (ENV + CLI override), usage/docs, and option parsing for lane override.
  - `scripts/verify_taskctl_lock_contract.sh`: added ENV lane tests and CLI-overrides-ENV precedence test coverage.
  - `coordination/README.md`: documented lane configuration/precedence and resolved-lane behavior.
  - `coordination/COORDINATOR_INSTRUCTIONS.md`: documented delegation-time lane configuration/precedence and resolved-lane behavior.

## Completion Note
Completed by worker; log: coordination/runtime/logs/be/be-configurable-coding-owner-lanes-20260303-20260303-124127.log
