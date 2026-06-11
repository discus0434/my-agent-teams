# Team Protocol

## Artifacts

- `queue/tasks/<task_id>.md`: task body.
- `queue/inbox/<agent_id>.jsonl`: agent messages.
- `queue/reports/<task_id>_<agent_id>.md`: worker report.
- `queue/reviews/<task_id>_<agent_id>_review.md`: verifier result.
- `queue/integrations/<task_id>_<agent_id>.md`: lead integration result.
- `queue/state/tasks/<task_id>.json`: lifecycle state.
- `queue/state/processed/<agent_id>/<message_id>`: processed inbox marker.

tmux carries only short nudges:

```text
inbox <agent_id>
```

## Human To Lead

Human users interact with the lead through the lead tmux pane.

Use the lead pane for:

- project requests
- bootstrap conversations
- scope decisions
- integration decisions

Use mailbox plus tmux nudge for:

- lead-to-worker task dispatch
- worker-to-lead questions
- verifier-to-worker review results

## Identity

`team_start.sh` passes identity through environment variables and tmux pane metadata.

```bash
./scripts/team_identity.sh
```

Expected fields:

- `TEAM_AGENT_ID`
- `TEAM_AGENT_ROLE`
- `TEAM_AGENT_CLI`
- `TEAM_AGENT_MODEL`
- `TEAM_AGENT_WORKTREE`
- `TEAM_SESSION`
- `TEAM_ROOT`
- `TEAM_CONFIG_FILE`

## Branches

- Parking branch for each worker worktree: `agent/<agent_id>`.
- Task branch for implementation: `task/<agent_id>/<task_id>`.
- Task branches are created from lead root `HEAD` at claim time.
- A task file `Branch:` must exactly match `task/<agent_id>/<task_id>`.

Git cannot store both `agent/<agent_id>` and `agent/<agent_id>/<task_id>` as branch refs. Keep parking and task branches in separate namespaces.

## Lead Direct Work

Lead may work directly when the change is small, single-owner, and not worth a queue/report/review cycle.

Direct work gate:

```bash
make post-change
make smoke
```

Run task-specific checks before `make post-change` when they exist.

## Task Dispatch

Create a task from `queue/tasks/TEMPLATE.md`.

Required fields:

- `Owner`
- `Branch`
- `Allowed paths`
- `Do not modify`
- `Goal`
- `Acceptance`
- `Verification`
- `Report`

Send:

```bash
make team-send TO=<agent_id> TYPE=task_assigned TASK=<task_id>
make team-status
```

## Worker Lifecycle

Claim:

```bash
make claim TASK=<task_id> AGENT=<agent_id>
```

Claim checks:

- task exists.
- `Owner` equals agent id.
- `Branch` equals `task/<agent_id>/<task_id>`.
- worker worktree exists and is clean.
- task is unclaimed or already claimed by the same agent.

Work:

```bash
make post-change
make smoke
git add <changed-files>
git commit -m "<task_id>: <summary>"
make report TASK=<task_id> AGENT=<agent_id> STATUS=needs-review
# Edit queue/reports/<task_id>_<agent_id>.md with concrete verification evidence.
make review TASK=<task_id> AGENT=<agent_id>
```

The report must include summary, changed files, task-specific verification, `make post-change`, and `make smoke` evidence before review.

Review handling:

- `Decision: OK`: `make report TASK=<task_id> AGENT=<agent_id> STATUS=done`.
- `Decision: FIX`: fix, rerun checks, commit, report `needs-review`, and review again.
- `Decision: ASK_LEAD`: write the question in the report and notify lead.

Review refuses dirty worker worktrees. The review target is the committed diff from task base commit to worker head.

`team.review.cli` supports:

- `claude`: runs `claude --print`.
- `codex`: runs `codex exec` and writes the final response to the review artifact.

## Integration

Lead integrates only tasks shown by `make team-status` as `ready-to-integrate`.

```bash
make integrate TASK=<task_id> AGENT=<agent_id>
```

Integration checks:

- claim owner matches the agent.
- report exists and has `Status: done`.
- review exists and has `Decision: OK`.
- worker branch equals state branch.
- worker worktree is clean.
- worker `HEAD` still equals report/state head commit.
- lead worktree is clean.

Integration performs:

```bash
git merge --no-ff task/<agent_id>/<task_id>
make post-change
make smoke
```

Result is written to:

```text
queue/integrations/<task_id>_<agent_id>.md
```

If merge or checks fail, the task remains unintegrated. Lead fixes the root state or sends a follow-up task to the worker.

## Memory

Workers submit memory proposals. Lead edits `docs/MEMORY.md`.

Memory proposal path:

```text
queue/memory_proposals/<task_id>_<agent_id>_<short-slug>.md
```

Lead reviews proposals and edits `docs/MEMORY.md` only when the lesson is durable, sourced, non-secret, and not a duplicate.
