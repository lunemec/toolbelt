---
id: pm-reasoning-default-isolation-20260302
title: Orchestrate reasoning default isolation verification
owner_agent: pm
creator_agent: pm
parent_task_id: none
status: done
priority: 1
depends_on: []
intended_write_targets: []
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-02T09:58:03+0000
updated_at: 2026-03-02T10:12:59+0000
acceptance_criteria:
  - Parent plan defines specialist milestones, dependencies, and verification gates for reasoning-isolation coverage.
  - Specialist implementation adds an automated check proving planner-vs-default reasoning selection with no cross-agent leakage.
  - Verification suite includes the new reasoning check and passes in local execution.
  - Independent review confirms evidence quality and that non-planner defaults remain `none` unless explicitly overridden.
---

## Prompt
Orchestrate delivery of automated reasoning-isolation verification for worker agents without directly implementing product code.

## Context
User requested proof that default reasoning for non-planner agents is not contaminated by a prior `coordinator` run using `xhigh`.
Current code sets planner roles (`pm`, `coordinator`, `architect`) to `xhigh` and other agents to default (`none`), but existing tests do not explicitly verify runtime isolation behavior.
Coordination policy requires delegation for implementation and objective evidence for acceptance.

## Deliverables
1. Delegated architect task defining verification strategy and edge conditions.
2. Delegated implementation task adding/wiring reasoning-isolation automated checks with TDD evidence.
3. Delegated review task for independent verification and regression scan.
4. Parent aggregation summary with acceptance decision.

Milestones and dependency order:
1. `architect` strategy task completes first.
2. `be` implementation task executes with strategy context.
3. `review` validation task executes after implementation completes.

## Validation
1. `scripts/verify_agent_worker_reasoning_contract.sh`
2. `scripts/verify_orchestrator_clarification_suite.sh`
3. Any additional targeted commands declared by specialists in task results.

Critical assumptions / open questions:
1. Assumption: reasoning effort can be validated via worker logs that include `reasoning_effort=...` at task start.
2. Assumption: no production code changes are required beyond verification scripts and changelog updates.
3. Open question resolved by user: clarification complete and scope is locked to automated reasoning-isolation verification.

## Result
Delivered:
1. Added automated reasoning-isolation verifier:
- `scripts/verify_agent_worker_reasoning_contract.sh`
- Asserts planner role (`coordinator`) receives `model_reasoning_effort="xhigh"`.
- Asserts non-planner role (`fe`) receives `model_reasoning_effort="none"`.
- Asserts non-planner role does not receive `xhigh` (leak guard).
2. Integrated verifier into suite entrypoint:
- `scripts/verify_orchestrator_clarification_suite.sh` includes `agent worker reasoning contract`.
3. Updated changelog entries describing new reasoning verification coverage.

Specialist evidence summary:
1. `architect-reasoning-isolation-strategy-20260302` completed with implementation strategy and risk notes.
2. `be` implementation tasks completed and introduced verifier + suite integration.
3. Final independent review sign-off task reports both required commands pass and confirms no reasoning-leak regression:
- `review-reasoning-verifier-final-signoff-20260302` -> PASS.

Verification checkpoints:
1. `scripts/verify_agent_worker_reasoning_contract.sh` -> pass (exit 0).
2. `scripts/verify_orchestrator_clarification_suite.sh` -> pass (exit 0).

Residual risk / follow-up:
1. Verification harness currently creates helper files at `scripts/codex` and `scripts/taskctl_stub.sh` during runs due a symlinked temp scripts path pattern.
2. Core user-requested reasoning isolation objective is met and validated, but side-effect cleanup should be handled in a follow-up hardening task.

## Completion Note
Core reasoning-isolation verification delivered; residual side-effect cleanup tracked as follow-up risk
