---
id: be-coordination-repair-finalize-20260302
title: Finalize coordination_repair safe overwrite behavior with evidence
owner_agent: be
creator_agent: pm
parent_task_id: pm-task-local-prompt-architecture-20260302
status: done
priority: 2
depends_on: [pm-task-local-prompt-architecture-20260302]
intended_write_targets: ['scripts/coordination_repair.sh', 'container/codex-init-workspace.sh', 'scripts/verify_coordination_repair_contract.sh', 'coordination/README.md', 'coordination/COORDINATOR_INSTRUCTIONS.md', 'coordination/in_progress/be/be-coordination-repair-finalize-20260302.md']
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-02T16:15:25+0000
updated_at: 2026-03-02T16:25:15+0000
acceptance_criteria:
  - "Safe baseline refresh semantics are correct and dynamic lanes remain preserved."
  - "scripts/coordination_repair.sh duplicate --force bug is fixed in quiet path."
  - "Verification script and required commands pass with outcomes recorded in Result."
  - "If any required evidence or behavior is missing, task is blocked instead of marked done."
---

## Prompt
Finalize coordination repair safe-overwrite implementation and capture full evidence in this task file.

## Context
This task includes its own in-progress task file in write targets to permit Result updates.
Current code still shows a duplicate `--force` argument in `scripts/coordination_repair.sh` quiet path and needs correction.

Do only declared write targets.

## Deliverables
1. Correct and finalize safe-overwrite logic in `scripts/coordination_repair.sh` and `container/codex-init-workspace.sh` as needed.
2. Ensure `scripts/verify_coordination_repair_contract.sh` remains valid and executable.
3. Ensure docs in declared targets match final behavior.
4. Write `## Result` with:
- Red: failing/unsafe pre-fix evidence.
- Green: targeted fix and passing checks.
- Blue: cleanup plus broader checks passing.
- concise changed-file summary and preserved-lane proof.

## Validation
Required commands:
1. `scripts/verify_coordination_repair_contract.sh`
2. `scripts/verify_top_level_prompt_contract.sh`
3. `scripts/verify_coordinator_instructions_contract.sh`
4. `scripts/verify_task_local_prompt_contract.sh`
5. `git diff -- scripts/coordination_repair.sh container/codex-init-workspace.sh scripts/verify_coordination_repair_contract.sh coordination/README.md coordination/COORDINATOR_INSTRUCTIONS.md`

## Result
### Red (pre-fix failing/unsafe evidence)
- Pre-fix `scripts/coordination_repair.sh` quiet path included a duplicate force flag:
  - `codex-init-workspace --workspace "$WORKSPACE_ROOT" --force --force --quiet`
- Initial required validation failed before fixture fix:
  - `scripts/verify_coordination_repair_contract.sh: line 22: .../coordination/prompts/TOP_LEVEL_AGENT_PROMPT.md: No such file or directory`

### Green (targeted fix + required checks passing)
- Fixed `scripts/coordination_repair.sh` baseline seed call:
  - quiet path now: `codex-init-workspace --workspace "$WORKSPACE_ROOT" --force --quiet`
  - non-quiet path now: `codex-init-workspace --workspace "$WORKSPACE_ROOT" --force`
- Fixed `scripts/verify_coordination_repair_contract.sh` fixture setup by creating `$WS/coordination/prompts` before writing the prompt seed file.
- Required validations executed and passing:
  1. `scripts/verify_coordination_repair_contract.sh` -> `PASS: coordination repair contract verified`
  2. `scripts/verify_top_level_prompt_contract.sh` -> `top-level prompt contract checks passed: coordination/prompts/TOP_LEVEL_AGENT_PROMPT.md`
  3. `scripts/verify_coordinator_instructions_contract.sh` -> `coordinator instructions contract checks passed: coordination/COORDINATOR_INSTRUCTIONS.md`
  4. `scripts/verify_task_local_prompt_contract.sh` -> `task-local prompt contract verified`
  5. `git diff -- scripts/coordination_repair.sh container/codex-init-workspace.sh scripts/verify_coordination_repair_contract.sh coordination/README.md coordination/COORDINATOR_INSTRUCTIONS.md` reviewed for scoped evidence.

### Blue (cleanup + broader checks)
- `scripts/verify_coordination_repair_contract.sh` remains executable (`-rwxr-xr-x`).
- Preserved-lane proof: passing coordination repair contract asserts no overwrite of dynamic/task state:
  - `coordination/inbox/**`
  - `coordination/in_progress/**`
  - `coordination/done/**`
  - `coordination/blocked/**`
  - `coordination/reports/**`
  - `coordination/runtime/**`
  - `coordination/task_prompts/**`
- Concise changed-file summary:
  - `scripts/coordination_repair.sh`: removed duplicate `--force` invocation and finalized single-force safe-refresh call path.
  - `scripts/verify_coordination_repair_contract.sh`: corrected test fixture directory creation for prompt seed file.
  - No additional edits were needed in `container/codex-init-workspace.sh`, `coordination/README.md`, or `coordination/COORDINATOR_INSTRUCTIONS.md` for this finalize step; existing scoped changes remain consistent with safe-overwrite behavior.

## Completion Note
Completed by worker; log: coordination/runtime/logs/be/be-coordination-repair-finalize-20260302-20260302-162325.log
