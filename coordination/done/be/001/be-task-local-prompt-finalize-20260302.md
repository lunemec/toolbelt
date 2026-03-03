---
id: be-task-local-prompt-finalize-20260302
title: Finalize strict task-local runtime/taskctl implementation with evidence
owner_agent: be
creator_agent: pm
parent_task_id: pm-task-local-prompt-architecture-20260302
status: done
priority: 1
depends_on: [pm-task-local-prompt-architecture-20260302]
intended_write_targets: ['scripts/agent_worker.sh', 'scripts/taskctl.sh', 'coordination/templates/TASK_TEMPLATE.md', 'scripts/verify_agent_worker_reasoning_contract.sh', 'scripts/verify_task_local_prompt_contract.sh', 'coordination/README.md', 'coordination/COORDINATOR_INSTRUCTIONS.md', 'coordination/in_progress/be/be-task-local-prompt-finalize-20260302.md']
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-02T16:15:25+0000
updated_at: 2026-03-02T16:22:53+0000
acceptance_criteria:
  - "Declared target files include concrete strict task-local runtime and taskctl sidecar implementation changes."
  - "Worker runtime prompt excludes coordination role merge and follows ordered section assembly with deterministic fallback."
  - "taskctl create/delegate generates coordination/task_prompts/<TASK_ID> bootstrap section files."
  - "Task file Result section contains explicit Red/Green/Blue evidence with command outcomes."
  - "If any required evidence or behavior is missing, task is blocked instead of marked done."
---

## Prompt
Finalize strict task-local runtime/taskctl implementation and record complete evidence directly in this task file.

## Context
Previous attempts were marked done without sufficient implementation/evidence.
This task includes its own in-progress task file in write targets so Result updates are now permitted.

Use contract source:
`coordination/done/architect/001/architect-task-local-prompt-contract-20260302.md`

Do only declared write targets.

## Deliverables
1. Implement strict task-local prompt runtime behavior in `scripts/agent_worker.sh`.
2. Implement sidecar bootstrap generation in `scripts/taskctl.sh`.
3. Update template/docs/tests in declared targets to match actual behavior.
4. Write `## Result` with:
- Red: failing baseline evidence before fix.
- Green: minimal fix and targeted passing checks.
- Blue: cleanup and broader checks passing.
- concise changed-file list and key behavior assertions.

## Validation
Required commands:
1. `scripts/verify_task_local_prompt_contract.sh`
2. `scripts/verify_agent_worker_reasoning_contract.sh`
3. `scripts/verify_taskctl_lock_contract.sh`
4. `scripts/verify_task_template_lock_metadata_contract.sh`
5. `git diff -- scripts/agent_worker.sh scripts/taskctl.sh coordination/templates/TASK_TEMPLATE.md scripts/verify_agent_worker_reasoning_contract.sh scripts/verify_task_local_prompt_contract.sh coordination/README.md coordination/COORDINATOR_INSTRUCTIONS.md`

## Result
### Red (baseline before fix)
- `test -x scripts/verify_task_local_prompt_contract.sh; echo "verify_task_local_prompt_contract.sh exit=$?"`
  - Outcome: `verify_task_local_prompt_contract.sh exit=1` (contract verifier missing).
- `rg -n "cat \"\\$role_file\"|missing role file" scripts/agent_worker.sh`
  - Outcome: `270:  [[ -f "$role_file" ]] || { echo "missing role file: $role_file" >&2; exit 1; }` (runtime role merge dependency present).
- Baseline sidecar bootstrap check:
  - Command: `TASK_ROOT_DIR=/workspace/.tmp-red-taskctl/coordination scripts/taskctl.sh create RED-TASK-LOCAL "red baseline" --to pm --from pm --priority 5` (temp root with copied template), then `test -f /workspace/.tmp-red-taskctl/coordination/task_prompts/RED-TASK-LOCAL/prompt/000.md`
  - Outcome: `sidecar bootstrap missing as expected (RED)` (no task-local prompt sidecar creation).

### Green (minimal fix + targeted verification)
- `scripts/verify_task_local_prompt_contract.sh`
  - Outcome: `task-local prompt contract verified`.
- `scripts/verify_agent_worker_reasoning_contract.sh`
  - Outcome: `agent worker reasoning contract verified`.
- `if rg -n "cat \"\\$role_file\"|missing role file" scripts/agent_worker.sh; then ...; else echo "no runtime role merge references (GREEN)"; fi`
  - Outcome: `no runtime role merge references (GREEN)`.
- Sidecar bootstrap verification after fix (temp root):
  - Command: `TASK_ROOT_DIR=/workspace/.tmp-green-taskctl/coordination scripts/taskctl.sh create GREEN-TASK-LOCAL "green sidecar" --to pm --from pm --priority 5` + file existence checks for all four `000.md` files.
  - Outcome: `sidecar bootstrap files present (GREEN)`.

### Blue (cleanup + broader required checks)
- `scripts/verify_task_local_prompt_contract.sh`
  - Outcome: `task-local prompt contract verified`.
- `scripts/verify_agent_worker_reasoning_contract.sh`
  - Outcome: `agent worker reasoning contract verified`.
- `scripts/verify_taskctl_lock_contract.sh`
  - Outcome: `taskctl lock contract checks passed: scripts/taskctl.sh`.
- `scripts/verify_task_template_lock_metadata_contract.sh`
  - Outcome: `task template lock metadata contract checks passed: coordination/templates/TASK_TEMPLATE.md`.
- `git diff -- scripts/agent_worker.sh scripts/taskctl.sh coordination/templates/TASK_TEMPLATE.md scripts/verify_agent_worker_reasoning_contract.sh scripts/verify_task_local_prompt_contract.sh coordination/README.md coordination/COORDINATOR_INSTRUCTIONS.md`
  - Outcome: diff contains only intended strict task-local runtime/taskctl/docs/test changes for declared targets.

### Changed Files
- `scripts/agent_worker.sh`
- `scripts/taskctl.sh`
- `coordination/templates/TASK_TEMPLATE.md`
- `scripts/verify_agent_worker_reasoning_contract.sh`
- `scripts/verify_task_local_prompt_contract.sh` (new)
- `coordination/README.md`
- `coordination/COORDINATOR_INSTRUCTIONS.md`
- `coordination/in_progress/be/be-task-local-prompt-finalize-20260302.md`

### Key Behavior Assertions
- Worker runtime prompt assembly is strict task-local only, ordered as `Prompt -> Context -> Deliverables -> Validation`.
- Per-section precedence is deterministic: sidecar fragments (`*.md`, lexicographic, non-hidden) -> embedded section -> `MISSING SECTION: <SectionName>`.
- Runtime no longer merges `coordination/roles/*.md` into worker prompts.
- `taskctl create`/`taskctl delegate` now bootstrap `coordination/task_prompts/<TASK_ID>/{prompt,context,deliverables,validation}/000.md`.
- Required verification commands pass with explicit command evidence above.

## Completion Note
Completed by worker; log: coordination/runtime/logs/be/be-task-local-prompt-finalize-20260302-20260302-161607.log
