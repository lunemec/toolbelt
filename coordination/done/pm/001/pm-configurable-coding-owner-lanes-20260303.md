---
id: pm-configurable-coding-owner-lanes-20260303
title: Orchestrate configurable coding-owner lane policy for write-target auto-inclusion
owner_agent: pm
creator_agent: pm
parent_task_id: none
status: done
priority: 1
depends_on: []
intended_write_targets: []
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-03T08:55:14+0000
updated_at: 2026-03-03T12:54:44+0000
acceptance_criteria:
  - Coding-owner lane set is configurable without editing script code.
  - Write-target auto-inclusion and assign-pruning behavior remains deterministic under configured lane set.
  - Independent review confirms no regression for existing default behavior.
---

## Prompt
Orchestrate hardening to replace hard-coded coding-owner lanes with a configurable policy source.

## Context
Current behavior is correct but hard-codes coding-owner lanes as `fe|be|db` in taskctl helpers.
User requested continuation to make this configurable.

Configuration decision captured:
- Primary source: environment variable.
- Optional source: CLI override for one-off runs.
- Precedence: CLI override > ENV var > built-in default (`fe,be,db`).
Task-local sidecar overrides embedded execution sections when present: `coordination/task_prompts/<TASK_ID>/{prompt,context,deliverables,validation}/*.md`.

## Deliverables
1. Implementation task for configurable coding-owner lane source and policy wiring.
2. Validation updates covering default + configured behavior.
3. Independent review sign-off.
4. Parent synthesis and closure recommendation.

## Validation
Orchestration gates:
1. Software task includes Red/Green/Blue evidence.
2. Verifier coverage includes default compatibility and configured-lane scenario.
3. Review confirms deterministic lock policy behavior remains intact.

## Result
Execution summary:

Configuration policy implemented:
1. Primary source: `TASK_CODING_OWNER_LANES` environment variable.
2. Optional override: `--coding-owner-lanes <agents>` on `taskctl` commands.
3. Precedence: CLI override > ENV > default `fe,be,db`.

Delegation outcomes:
1. Core implementation:
- `coordination/done/be/001/be-configurable-coding-owner-lanes-20260303.md`
2. Initial audit:
- `coordination/done/review/002/review-configurable-coding-owner-lanes-audit-20260303.md`
- identified low consistency gap: requirement enforcement still hard-coded.
3. Alignment fix:
- `coordination/done/be/001/be-align-write-target-requirement-with-configured-lanes-20260303.md`
4. Final audit sign-off:
- `coordination/done/review/002/review-align-write-target-requirement-audit-20260303.md`
- no findings.

Final behavior achieved:
1. Coding-owner lane set is configurable without editing script code.
2. Write-target requirement enforcement, auto self-target inclusion, and assign-path stale-target pruning all use the same resolved lane set.
3. Deterministic behavior preserved for default and configured lane sets.

Validation evidence (final cycle):
1. `scripts/verify_taskctl_lock_contract.sh` pass
2. `scripts/verify_task_local_prompt_contract.sh` pass
3. `scripts/verify_agent_worker_reasoning_contract.sh` pass

Residual risk:
1. Low operational risk: per-invocation ENV/CLI differences can change enforcement outcomes unless operators standardize configuration in their run context.

## Completion Note
Completed configurable coding-owner lane rollout with aligned requirement enforcement and independent review sign-off.
