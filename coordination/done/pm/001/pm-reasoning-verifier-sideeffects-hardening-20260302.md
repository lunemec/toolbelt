---
id: pm-reasoning-verifier-sideeffects-hardening-20260302
title: Orchestrate reasoning verifier side-effect hardening
owner_agent: pm
creator_agent: pm
parent_task_id: none
status: done
priority: 1
depends_on: []
intended_write_targets: []
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-02T10:15:59+0000
updated_at: 2026-03-02T10:19:38+0000
acceptance_criteria:
  - Reasoning verifier no longer creates persistent helper artifacts in repository `scripts/`.
  - `scripts/verify_agent_worker_reasoning_contract.sh` passes.
  - `scripts/verify_orchestrator_clarification_suite.sh` passes.
  - Independent review confirms artifact absence and no regression to reasoning assertions.
---

## Prompt
Orchestrate side-effect hardening for reasoning verifier while preserving existing pass behavior and assertion semantics.

## Context
Current residual risk after core delivery:
1. `scripts/codex` and `scripts/taskctl_stub.sh` remain in repository after verifier runs.
2. Prior cleanup task did not complete due lock metadata preventing agent from writing its required `## Result` section.
This parent task closes that hardening gap end-to-end with verifiable evidence.

## Deliverables
1. Delegated `be` fix with corrected write-target metadata (including in-progress task file).
2. Delegated independent `review` verification of side-effect absence plus regression checks.
3. Parent aggregation with sign-off evidence and residual risk statement.

## Validation
Required command evidence:
1. `scripts/verify_agent_worker_reasoning_contract.sh`
2. `scripts/verify_orchestrator_clarification_suite.sh`
3. `test ! -e scripts/codex`
4. `test ! -e scripts/taskctl_stub.sh`

Dependencies:
1. `be` executes first.
2. `review` executes after `be` completion.

## Result
Delivered:
1. Final `be` hardening task completed:
- `be-reasoning-verifier-sideeffects-final-20260302`
- updated `scripts/verify_agent_worker_reasoning_contract.sh` to isolate helper executables in temp-only `$WORKDIR/bin` and avoid repo `scripts/` writes.
- removed repository helper artifacts `scripts/codex` and `scripts/taskctl_stub.sh`.
2. Final independent `review` audit completed:
- `review-reasoning-verifier-sideeffects-final-20260302`
- no findings, PASS verdict.

Verification outcomes:
1. `scripts/verify_agent_worker_reasoning_contract.sh` -> exit 0 (`agent worker reasoning contract verified`).
2. `scripts/verify_orchestrator_clarification_suite.sh` -> exit 0 (`orchestrator clarification suite checks passed`).
3. `test ! -e scripts/codex` -> exit 0 (absent).
4. `test ! -e scripts/taskctl_stub.sh` -> exit 0 (absent).

Closure assessment:
1. Residual side-effect risk is resolved.
2. Core reasoning isolation verification remains intact.
3. Parent acceptance criteria met.

## Completion Note
Reasoning verifier side-effect hardening complete with independent PASS audit
