---
id: architect-task-local-prompt-contract-20260302
title: Define strict task-local prompt architecture contract
owner_agent: architect
creator_agent: pm
parent_task_id: pm-task-local-prompt-architecture-20260302
status: done
priority: 1
depends_on: [pm-task-local-prompt-architecture-20260302]
intended_write_targets: []
lock_scope: file
lock_policy: block_on_conflict
created_at: 2026-03-02T16:04:46+0000
updated_at: 2026-03-02T16:07:59+0000
acceptance_criteria:
  - Contract defines canonical sidecar path layout keyed by TASK_ID and required files/sections.
  - Contract specifies worker prompt assembly order using sectioned task-local inputs only (no role merge).
  - Contract defines deterministic fallback for legacy tasks without sidecars.
  - Contract includes dependency notes and migration-safe rollout order for implementation/review lanes.
---

## Prompt
Define the implementation contract for strict task-local prompt architecture before coding begins.

## Context
User decisions already confirmed:
1. Strict task-local prompt model (no shared role-file prompt merge).
2. Sectioned worker input hierarchy for clarity.
3. Multi-file task prompts are allowed.
4. Sidecars should use fixed path by task ID.
5. Legacy tasks without sidecars must still run.
6. `taskctl create/delegate` must auto-generate sidecar prompt files.
7. After architecture rollout, `coordination_repair.sh` will be updated to safe overwrite baseline assets only.

Need a concise, implementation-ready contract for BE lane execution.

## Deliverables
1. In `## Result`, provide canonical sidecar directory/file naming under `coordination/` by `<TASK_ID>`.
2. Provide explicit worker prompt assembly sequence with section priorities (Prompt, Context, Deliverables, Validation) and exclusions.
3. Provide fallback rules when sidecars are absent and embedded sections are incomplete.
4. Provide migration/compatibility rules for existing tasks across inbox/in_progress/done/blocked.
5. Provide acceptance checklist BE/review can validate.

## Validation
1. Confirm proposed pathing does not require moving sidecars during task state transitions.
2. Confirm contract can be validated with deterministic script tests (list target commands).
3. Confirm no dependency on mutable `coordination/roles/*.md` at worker runtime.

## Result
### Strict Task-Local Prompt Contract (v1)

1. Canonical sidecar path/layout (fixed by `TASK_ID`, state-independent):
   - Root: `coordination/task_prompts/<TASK_ID>/`
   - Required section directories:
     - `prompt/`
     - `context/`
     - `deliverables/`
     - `validation/`
   - Required bootstrap files (created by `taskctl create` and `taskctl delegate`):
     - `coordination/task_prompts/<TASK_ID>/prompt/000.md`
     - `coordination/task_prompts/<TASK_ID>/context/000.md`
     - `coordination/task_prompts/<TASK_ID>/deliverables/000.md`
     - `coordination/task_prompts/<TASK_ID>/validation/000.md`
   - Multi-file extension rule: additional `*.md` fragments are allowed in each section directory and are concatenated in lexicographic filename order.
   - `TASK_ID` uniqueness remains globally enforced by existing `taskctl` duplicate checks; no state/path suffix is allowed in sidecar location.

2. Worker prompt assembly contract (strict task-local, no role merge):
   - Runtime prompt inputs must be sourced only from:
     - Task file path/reference metadata.
     - Task-local sidecar section files under `coordination/task_prompts/<TASK_ID>/...`.
     - Legacy embedded sections in the task markdown (`## Prompt`, `## Context`, `## Deliverables`, `## Validation`) only when fallback is required.
   - Final assembly order is fixed:
     1. `Prompt`
     2. `Context`
     3. `Deliverables`
     4. `Validation`
   - Section population precedence is fixed per section:
     1. Sidecar section fragments (`*.md`, sorted lexicographically).
     2. Embedded section from task markdown with matching heading.
     3. Deterministic sentinel line: `MISSING SECTION: <SectionName>`.
   - Explicit exclusions:
     - Do not merge/include `coordination/roles/*.md` in runtime worker prompt.
     - Do not include task sections outside the four canonical execution sections (`Result`, `Completion Note`, `Blocked Reason`, `Blocker Details`, etc. are excluded).
     - Ignore non-markdown files and hidden files in sidecar section directories.

3. Deterministic fallback behavior (legacy and partial sidecars):
   - If `coordination/task_prompts/<TASK_ID>/` is absent: run in legacy mode using embedded task sections only.
   - If sidecar exists but one or more section directories/files are absent/empty: fallback per missing section to embedded markdown section.
   - If both sidecar and embedded section content are missing: emit `MISSING SECTION: <SectionName>` for that section and continue execution.
   - If sidecar directory exists but cannot be read (permission/IO error), worker fails deterministically and blocks task with explicit reason.

4. Migration and compatibility rules across queue states:
   - Sidecar path is queue-state agnostic and must never move during task transitions:
     - `inbox -> in_progress -> done|blocked` moves only the task markdown file.
     - Sidecar remains at `coordination/task_prompts/<TASK_ID>/` for task lifetime.
   - Existing tasks in any state (`inbox`, `in_progress`, `done`, `blocked`) without sidecars remain executable via fallback.
   - No mandatory backfill migration is required for legacy tasks to preserve compatibility and avoid state churn.
   - New tasks created/delegated after rollout always get sidecars auto-generated.

5. Dependency notes and rollout order (migration-safe):
   1. BE lane: implement sidecar read/assembly helpers in worker with strict exclusion of role-file merge.
   2. BE lane: update `taskctl create/delegate` to auto-generate required sidecar directories/files.
   3. BE lane: add deterministic contract tests for section precedence/fallback and state transitions.
   4. Review lane: validate no runtime dependency on `coordination/roles/*.md`, validate legacy fallback, and validate unchanged task lifecycle semantics.
   5. Post-architecture follow-up lane: update `coordination_repair.sh` safe-overwrite baseline assets only (active queues/runtime untouched).

### Acceptance Checklist (BE + Review)
- [ ] Creating/delegating a new task generates `coordination/task_prompts/<TASK_ID>/` with all four required section bootstrap files.
- [ ] Worker prompt assembly uses only task-local section sources; no role-file merge at runtime.
- [ ] Assembly order is exactly `Prompt -> Context -> Deliverables -> Validation`.
- [ ] Sidecar-missing legacy tasks still execute via embedded sections.
- [ ] Partial sidecars fallback per section deterministically.
- [ ] `done`/`blocked` transitions do not move sidecar directories.
- [ ] Runtime behavior and errors are deterministic and test-covered.

### Deterministic Validation Commands (target contract tests)
1. `scripts/taskctl.sh create TASK-LP-CONTRACT-001 "contract smoke" --to architect --from pm --priority 50`
2. `test -f coordination/task_prompts/TASK-LP-CONTRACT-001/prompt/000.md && test -f coordination/task_prompts/TASK-LP-CONTRACT-001/context/000.md && test -f coordination/task_prompts/TASK-LP-CONTRACT-001/deliverables/000.md && test -f coordination/task_prompts/TASK-LP-CONTRACT-001/validation/000.md`
3. `scripts/taskctl.sh claim architect && test -f coordination/in_progress/architect/TASK-LP-CONTRACT-001.md && test -d coordination/task_prompts/TASK-LP-CONTRACT-001`
4. `scripts/taskctl.sh done architect TASK-LP-CONTRACT-001 "contract transition check" && test -f coordination/done/architect/050/TASK-LP-CONTRACT-001.md && test -d coordination/task_prompts/TASK-LP-CONTRACT-001`
5. `rg -n "coordination/roles/\\$AGENT\\.md|cat \\\"\\$role_file\\\"" scripts/agent_worker.sh` (must show no runtime prompt merge usage after BE implementation)

### Verification Commands Executed For This Contract Task
- `rg -n "task_prompts/<TASK_ID>|Prompt -> Context -> Deliverables -> Validation|MISSING SECTION|queue-state agnostic|no runtime dependency" coordination/in_progress/architect/architect-task-local-prompt-contract-20260302.md -S`
- `sed -n '1438,1478p' scripts/taskctl.sh`
- `sed -n '256,316p' scripts/agent_worker.sh`

## Completion Note
Defined strict task-local prompt contract with sidecar layout, assembly/fallback rules, rollout order, and acceptance checklist.
