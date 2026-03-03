---
id: be-fix-reasoning-verifier-sideeffects-20260302
title: Remove verifier repo side-effects and clean helper artifacts
owner_agent: be
creator_agent: pm
parent_task_id: pm-reasoning-default-isolation-20260302
status: done
priority: 2
depends_on: [pm-reasoning-default-isolation-20260302]
intended_write_targets: ['scripts/verify_agent_worker_reasoning_contract.sh', 'scripts/codex', 'scripts/taskctl_stub.sh', 'CHANGELOG.md']
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-02T10:11:30+0000
updated_at: 2026-03-02T10:11:54+0000
acceptance_criteria:
  - Verifier no longer leaves repo helper artifacts after execution.
  - Existing reasoning-isolation assertions remain intact.
  - Verifier and suite commands continue to pass.
  - Existing accidental helper files are removed from repo working tree.
---

## Prompt
Fix verifier side-effects and clean accidental helper artifacts from repository root scripts directory.

## Context
Current verifier creates a temp scripts path that is linked to repo `scripts/`, then writes stub helpers into it.
This leaves `scripts/codex` and `scripts/taskctl_stub.sh` in the working tree after runs.
Functionality currently passes; this task removes side-effects without weakening verification logic.

## Deliverables
1. Update `scripts/verify_agent_worker_reasoning_contract.sh` so helper files are created only in isolated temp paths (not repo `scripts/`).
2. Remove accidental artifact files:
- `scripts/codex`
- `scripts/taskctl_stub.sh`
3. Keep verifier semantics unchanged for reasoning isolation checks.
4. Update changelog if behavior/expectation changed materially.

## Validation
Required checks:
1. `scripts/verify_agent_worker_reasoning_contract.sh`
2. `scripts/verify_orchestrator_clarification_suite.sh`
3. Post-run check confirms artifact files are absent:
- `test ! -e scripts/codex`
- `test ! -e scripts/taskctl_stub.sh`

## Result
Agent fills this before moving the task to `done` or `blocked`.

## Completion Note
Completed by worker; log: coordination/runtime/logs/be/be-fix-reasoning-verifier-sideeffects-20260302-20260302-101151.log
