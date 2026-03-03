---
id: be-coordination-repair-remediation-20260302
title: Remediate coordination_repair safe overwrite behavior and evidence
owner_agent: be
creator_agent: pm
parent_task_id: pm-task-local-prompt-architecture-20260302
status: done
priority: 2
depends_on: [pm-task-local-prompt-architecture-20260302]
intended_write_targets: ['scripts/coordination_repair.sh', 'container/codex-init-workspace.sh', 'scripts/verify_coordination_repair_contract.sh', 'coordination/README.md', 'coordination/COORDINATOR_INSTRUCTIONS.md']
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-02T16:13:18+0000
updated_at: 2026-03-02T16:14:36+0000
acceptance_criteria:
  - "coordination_repair invokes safe baseline refresh behavior that cannot overwrite queue/runtime/task_prompt lanes."
  - "Any bugs from prior attempt are fixed (including duplicate --force argument if present)."
  - "scripts/verify_coordination_repair_contract.sh passes and result includes Red/Green/Blue evidence."
  - "If behavior or evidence is incomplete, task is blocked instead of marked done."
---

## Prompt
Remediate safe-overwrite repair implementation and produce complete verification evidence.

## Context
Prior task `be-coordination-repair-safe-baseline-overwrite-20260302` introduced partial changes but did not provide required result evidence.

Focus on deterministic, safe baseline refresh semantics:
1. Refresh baseline-managed scripts and baseline coordination docs/prompts/roles/templates/examples.
2. Preserve dynamic lanes: inbox/in_progress/done/blocked/reports/runtime/task_prompts.

Scope is limited to declared write targets.

## Deliverables
1. Finalize/fix `scripts/coordination_repair.sh` and `container/codex-init-workspace.sh` safe-refresh behavior.
2. Ensure `scripts/verify_coordination_repair_contract.sh` is valid, executable, and passes.
3. Update docs in declared targets to accurately reflect final behavior.
4. Fill `## Result` with Red/Green/Blue evidence:
- Red: failing/unsafe pre-fix behavior.
- Green: minimal fix plus targeted passing checks.
- Blue: cleanup and broader checks passing.
- Include concise changed-file summary and explicit preserved-lane proof points.

## Validation
Required commands:
1. `scripts/verify_coordination_repair_contract.sh`
2. `scripts/verify_top_level_prompt_contract.sh`
3. `scripts/verify_coordinator_instructions_contract.sh`
4. `scripts/verify_task_local_prompt_contract.sh`

Also include:
1. `git diff -- scripts/coordination_repair.sh container/codex-init-workspace.sh scripts/verify_coordination_repair_contract.sh coordination/README.md coordination/COORDINATOR_INSTRUCTIONS.md`

## Result
Agent fills this before moving the task to `done` or `blocked`.

## Completion Note
Completed by worker; log: coordination/runtime/logs/be/be-coordination-repair-remediation-20260302-20260302-161423.log
