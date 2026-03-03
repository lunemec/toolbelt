---
id: review-fix-assign-self-target-refresh-audit-20260303
title: Audit assign-path self-target refresh fix
owner_agent: review
creator_agent: pm
parent_task_id: pm-auto-include-taskfile-write-targets-20260302
status: done
priority: 2
depends_on: [pm-auto-include-taskfile-write-targets-20260302]
intended_write_targets: []
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-03T08:19:18+0000
updated_at: 2026-03-03T08:24:17+0000
acceptance_criteria:
  - Review confirms assign-path stale self-target issue is resolved for coding owners.
  - Review confirms non-coding owner assignment behavior is unaffected.
  - Review provides severity-ranked findings or explicit no-findings statement.
---

## Prompt
Audit the assign-path self-target refresh fix and confirm regression closure.

## Context
Audit target:
1. `be-fix-assign-self-target-refresh-20260303`

Focus on prior medium finding:
- stale `in_progress/<old_owner>/<TASK_ID>.md` self-target after `taskctl assign`.

## Deliverables
1. Severity-ordered findings with file references.
2. Gate verdicts:
- assign-path refresh fixed for coding owners
- no stale self-target remains after assign
- non-coding behavior unchanged
3. Residual risk summary.

## Validation
Run and summarize:
1. `scripts/verify_taskctl_lock_contract.sh`
2. `scripts/verify_task_local_prompt_contract.sh`
3. `scripts/verify_agent_worker_reasoning_contract.sh`

Cross-check BE Result evidence against actual diffs/behavior.

## Result
### Findings (Severity-Ordered)
1. Medium - Multi-hop reassignment can still leave a stale coding-owner self-target in `intended_write_targets`.
- Evidence:
  - `refresh_assign_self_taskfile_target` only removes the immediate `previous_owner` self-target before appending the new owner target, so older coding-owner targets can survive (`scripts/taskctl.sh:783`, `scripts/taskctl.sh:795`, `scripts/taskctl.sh:802`, `scripts/taskctl.sh:808`).
  - Current regression coverage validates direct `fe -> be` and `be -> pm`, but not `coding -> non-coding -> coding` (`scripts/verify_taskctl_lock_contract.sh:179`, `scripts/verify_taskctl_lock_contract.sh:200`, `scripts/verify_taskctl_lock_contract.sh:218`).
  - Reproduction:
    - `TASK_ROOT_DIR="$tmp" scripts/taskctl.sh create review-assign-hop ... --to be --write-target scripts/taskctl.sh`
    - `TASK_ROOT_DIR="$tmp" scripts/taskctl.sh assign review-assign-hop pm`
    - `TASK_ROOT_DIR="$tmp" scripts/taskctl.sh assign review-assign-hop fe`
    - Observed `intended_write_targets`: `["scripts/taskctl.sh",".../in_progress/be/review-assign-hop.md",".../in_progress/fe/review-assign-hop.md"]` (stale `be` lane retained).

### Gate Verdicts
- assign-path refresh fixed for coding owners: **Pass** (direct `fe -> be` reassignment refreshes self-target to `in_progress/be/<TASK_ID>.md`).
- no stale self-target remains after assign: **Fail** (`be -> pm -> fe` leaves stale `in_progress/be/<TASK_ID>.md` target).
- non-coding behavior unchanged: **Pass** (`be -> pm` preserves write-target metadata, including prior `be` self-target).

### Validation Summary
1. `scripts/verify_taskctl_lock_contract.sh` - pass
2. `scripts/verify_task_local_prompt_contract.sh` - pass
3. `scripts/verify_agent_worker_reasoning_contract.sh` - pass
4. Manual direct check (`fe -> be -> claim be`) - no stale old-owner target observed.
5. Manual multi-hop check (`be -> pm -> fe`) - stale prior coding-owner target observed.

### BE Result Cross-Check
- Confirmed: direct assign-path refresh behavior and verifier additions match the implemented diff.
- Not fully confirmed: BE claim that no stale owner-lane self-target remains after assignment for coding owners is too broad; multi-hop reassignment still retains stale coding-owner target(s).

### Residual Risk
- Tasks that move from coding-owner to non-coding and later back to coding-owner can accumulate stale historical coding-owner self-targets, expanding write-target scope and creating avoidable lock-policy friction.
