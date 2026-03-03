---
id: review-auto-include-taskfile-targets-audit-20260302
title: Audit auto-inclusion hardening for coding-owner task files
owner_agent: review
creator_agent: pm
parent_task_id: pm-auto-include-taskfile-write-targets-20260302
status: done
priority: 2
depends_on: [pm-auto-include-taskfile-write-targets-20260302]
intended_write_targets: []
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-03T08:11:45+0000
updated_at: 2026-03-03T08:18:49+0000
acceptance_criteria:
  - Review confirms coding-owner tasks can update their task Result without manual task-file write-target configuration.
  - Review confirms non-coding owners are unaffected.
  - Review provides severity-ranked findings with file references, or explicit no-findings statement.
---

## Prompt
Audit the coding-owner task-file auto-inclusion hardening for correctness and regression risk.

## Context
Audit target:
1. `be-auto-include-taskfile-targets-20260302`

Required scope decision already confirmed:
- auto-inclusion applies to `fe`, `be`, `db` only.

## Deliverables
1. Severity-ordered findings with file references.
2. Gate verdicts:
- coding-owner behavior fixed
- non-coding-owner behavior preserved
- lock/write-target policy remains deterministic
3. Residual risk summary if no blockers.

## Validation
Run and summarize:
1. `scripts/verify_taskctl_lock_contract.sh`
2. `scripts/verify_task_local_prompt_contract.sh`
3. `scripts/verify_agent_worker_reasoning_contract.sh`

Inspect BE task Result for concrete Red/Green/Blue evidence and verify claims against diff.

## Result
### Findings (severity-ordered)
1. **Medium** - `assign` path can break coding-owner self-task-file guarantee after reassignment.
   - Evidence: auto self-target is added only during task creation (`owner_auto_includes_taskfile_target` + `task_in_progress_write_target` in `create_task`), but reassignment only mutates `owner_agent` and does not recalculate `intended_write_targets`.
   - File refs:
     - `scripts/taskctl.sh:1304` (auto-add self target on create)
     - `scripts/taskctl.sh:1361` (assign flow entry)
     - `scripts/taskctl.sh:1384` (owner updated without target rewrite)
   - Repro command:
     - `tmp=$(mktemp -d /workspace/.review-audit.XXXXXX); cp -R coordination/templates "$tmp"; TASK_ROOT_DIR="$tmp" scripts/taskctl.sh create review-assign-case "assign case" --to fe --from pm --priority 50 --write-target scripts/taskctl.sh >/dev/null; TASK_ROOT_DIR="$tmp" scripts/taskctl.sh assign review-assign-case be >/dev/null; TASK_ROOT_DIR="$tmp" scripts/taskctl.sh claim be >/dev/null; awk 'BEGIN{s=0}/^---$/{s++;next}s==1{print}s>=2{exit}' "$tmp/in_progress/be/review-assign-case.md"; rm -rf "$tmp"`
     - Observed frontmatter: `owner_agent: be` with `intended_write_targets` containing `.review-audit.../in_progress/fe/review-assign-case.md` (stale owner lane path).

### Gate verdicts
- `coding-owner behavior fixed`: **Pass with caveat** (verified for create/delegate/claim flow; assign path caveat above).
- `non-coding-owner behavior preserved`: **Pass** (PM task creation with no targets remains valid in contract test).
- `lock/write-target policy remains deterministic`: **Pass** (canonicalization + de-duplication and exact-set assertions pass).

### Validation run
1. `scripts/verify_taskctl_lock_contract.sh` -> `taskctl lock contract checks passed: scripts/taskctl.sh`
2. `scripts/verify_task_local_prompt_contract.sh` -> `task-local prompt contract verified`
3. `scripts/verify_agent_worker_reasoning_contract.sh` -> `agent worker reasoning contract verified`

### BE Result evidence cross-check (Red/Green/Blue)
- **Red claim** (coding owners still require explicit `--write-target`) matches `validate_write_target_requirement` behavior and contract test negative case.
- **Green claim** (auto-inclusion for coding owners in create/delegate/claim) matches `scripts/taskctl.sh` create-path logic and verifier assertions.
- **Blue claim** (declared files changed and diff reviewed) is consistent with observed diffs in:
  - `scripts/taskctl.sh`
  - `scripts/verify_taskctl_lock_contract.sh`
  - `coordination/README.md`
  - `coordination/COORDINATOR_INSTRUCTIONS.md`

### Residual risk
- If tasks are reassigned between coding-owner lanes using `taskctl assign`, the auto-included self-task-file target can remain bound to the old owner lane, potentially conflicting with the intent that coding owners can always update their own in-progress task file under write-target policy.

## Completion Note
Audit complete: medium assign-path caveat documented; required validations passed.
