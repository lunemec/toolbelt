---
id: pm-task-local-prompt-architecture-20260302
title: Orchestrate strict task-local prompt architecture rollout
owner_agent: pm
creator_agent: pm
parent_task_id: none
status: done
priority: 1
depends_on: []
intended_write_targets: []
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-02T16:04:10+0000
updated_at: 2026-03-02T16:28:35+0000
acceptance_criteria:
  - Worker prompt assembly is strict task-local with sectioned hierarchy and no shared role-file merge.
  - New task creation/delegation auto-generates task-local prompt sidecars in a fixed path by task ID.
  - Legacy tasks without sidecars remain executable via deterministic fallback to embedded task sections.
  - coordination_repair refreshes only baseline scripts and baseline coordination prompts/roles/templates/examples/docs; active task/runtime lanes are not overwritten.
  - Verification evidence includes red/green/blue implementation logs and independent review sign-off.
---

## Prompt
Run end-to-end orchestration for strict task-local prompt architecture and post-architecture coordination repair hardening.

## Context
User confirmed scope pivot from role-prompt cleanup to architecture change:
1) Workers must use strict task-local prompt source with sectioned hierarchy.
2) Shared role files must not be merged into worker execution prompts.
3) Multi-file task prompt artifacts are allowed and should be stored in fixed paths by TASK_ID.
4) Legacy tasks without sidecars must remain supported.
5) taskctl create/delegate should auto-generate sidecar prompt files.
6) After architecture rollout, adjust coordination_repair to overwrite only safe baseline assets and never active task lanes.

Hard constraints:
- Orchestrator does not directly implement non-coordination project code.
- Coding tasks must follow Red/Green/Blue and capture evidence.
- Final closeout requires independent review evidence.

## Deliverables
1. Architecture contract task outcome (task-local prompt file layout + fallback + section extraction rules).
2. Implementation task outcome for worker/taskctl/template/test updates.
3. Follow-up implementation task outcome for coordination_repair safe-overwrite behavior.
4. Independent review task outcome with regression/risk findings or sign-off.
5. Parent synthesis capturing gates passed, residual risks, and closure recommendation.

## Validation
Orchestration gates:
1. Child tasks include concrete validation commands and pass/fail checkpoints.
2. Software child tasks include explicit Red/Green/Blue evidence in `## Result`.
3. Review lane confirms no regression in task lifecycle and worker execution behavior.
4. Parent result summarizes what changed, which commands passed, and any remaining follow-ups.

## Result
Plan finalized on 2026-03-02 (post-clarification confirmation):

Milestones and rollout order:
1. Architecture contract milestone (`architect-task-local-prompt-contract-20260302`) - completed.
2. Runtime + taskctl implementation milestone (`be-task-local-prompt-runtime-and-taskctl-20260302`) - pending.
3. Safe repair overwrite milestone (`be-coordination-repair-safe-baseline-overwrite-20260302`) - pending, after milestone 2.
4. Independent audit milestone (`review-task-local-prompt-and-repair-audit-20260302`) - pending, after milestone 2+3.

Dependency notes:
- M2 uses architect contract output as normative specification.
- M3 depends on M2 because repair safeguards must preserve new `coordination/task_prompts/<TASK_ID>/` artifacts.
- M4 runs after M2+M3 for end-to-end sign-off.

Assumptions:
- Fixed sidecar root: `coordination/task_prompts/<TASK_ID>/`.
- New tasks auto-generate sidecars; legacy tasks may lack sidecars and must still execute.
- No explicit backfill migration required for historical tasks.

Open critical assumptions:
- None remaining after clarification confirmation.

Primary risks and mitigations:
1. Risk: prompt assembly regression breaks worker behavior.
   Mitigation: contract test script + existing worker contract checks required in M2.
2. Risk: repair overwrite clobbers active task state.
   Mitigation: explicit path allowlist + dedicated repair contract test in M3.
3. Risk: hidden dependency on role-file runtime guidance.
   Mitigation: review lane grep/assertions + runtime test coverage in M4.

Execution outcome summary:
1. Architecture contract delivered:
- `coordination/done/architect/001/architect-task-local-prompt-contract-20260302.md`
2. Final implementation tasks completed with Red/Green/Blue evidence:
- `coordination/done/be/001/be-task-local-prompt-finalize-20260302.md`
- `coordination/done/be/002/be-coordination-repair-finalize-20260302.md`
3. Final independent audit completed with no blocking findings:
- `coordination/done/review/003/review-task-local-prompt-final-audit-20260302.md`

Completed validation gates (from BE + review evidence):
1. `scripts/verify_task_local_prompt_contract.sh` pass
2. `scripts/verify_agent_worker_reasoning_contract.sh` pass
3. `scripts/verify_taskctl_lock_contract.sh` pass
4. `scripts/verify_task_template_lock_metadata_contract.sh` pass
5. `scripts/verify_coordination_repair_contract.sh` pass
6. `scripts/verify_top_level_prompt_contract.sh` pass
7. `scripts/verify_coordinator_instructions_contract.sh` pass

Notable process issue discovered and mitigated during execution:
1. Coding tasks initially omitted their in-progress task file from `intended_write_targets`, preventing workers from updating `## Result`.
2. Mitigation used in final cycle: include each BE task's in-progress task file path in declared write targets.
3. Follow-up improvement candidate: automate this write-target inclusion in task creation for coding owners.

Residual risk:
1. Evidence remains narrative command outcomes in task files rather than persisted raw artifacts.
2. Review marked this as low severity and suggested transcript/artifact capture hardening.

## Completion Note
Completed strict task-local prompt architecture rollout and safe coordination repair hardening with independent review sign-off and no blocking findings.
