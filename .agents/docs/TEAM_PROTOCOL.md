# Team Protocol

## Artifacts

- `.agents/queue/tasks/<task_id>.md`: task body.
- `.agents/queue/inbox/<agent_id>.jsonl`: agent messages.
- `.agents/queue/reports/<task_id>_<agent_id>.md`: worker report.
- `.agents/queue/reviews/<task_id>_<agent_id>_review.md`: verifier result.
- `.agents/queue/integrations/<task_id>_<agent_id>.md`: lead integration result.
- `.agents/queue/state/tasks/<task_id>.json`: lifecycle state.
- `.agents/queue/state/processed/<agent_id>/<message_id>`: processed inbox marker.

All queue paths are canonical under `TEAM_ROOT`. Worker worktrees may contain an empty or stale `.agents/queue/` skeleton; use helper scripts or absolute paths from messages for shared state.

tmux carries only short nudges:

```text
inbox <agent_id>
```

On receipt, the agent runs:

```bash
make inbox AGENT=<agent_id>
```

If the prompt is visible in a pane but has not submitted, run:

```bash
make team-submit AGENT=<agent_id>
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
- direct lightweight requests that do not require claim or integration

## Identity

`make team-start` passes identity through environment variables and tmux pane metadata.

```bash
make team-identity
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

Lead may work directly when the change is small, single-owner, and not worth a task/report/review cycle.

Direct work gate:

```bash
make post-change
make smoke
```

Run task-specific checks before `make post-change` when they exist.

## Task Dispatch

Create a task from `.agents/queue/tasks/TEMPLATE.md`.

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

For direct lightweight requests without a task file, send `TYPE=note`, `TYPE=retro`, or another explicit type with `TASK=-`. The receiver follows the inbox body and does not claim, commit, review, or integrate unless the body says to create a task.
After writing the requested artifact, the receiver marks the message processed with `make inbox AGENT=<agent_id> MARK=<message_id>`.

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
# Edit .agents/queue/reports/<task_id>_<agent_id>.md with concrete verification evidence.
make review TASK=<task_id> AGENT=<agent_id>
```

The report must include summary, changed files, task-specific verification, `make post-change`, and `make smoke` evidence before review.

Review handling:

- `Decision: OK`: `make report TASK=<task_id> AGENT=<agent_id> STATUS=done`.
- `Decision: FIX`: fix, rerun checks, commit, report `needs-review`, and review again.
- `Decision: ASK_LEAD`: write the question in the report and notify lead.

After review, recheck inbox and mark the verifier notification when the review artifact has already been handled.

Review refuses dirty worker worktrees. The review target is the committed diff from task base commit to worker head. The review prompt embeds the task, report, git status, and committed diff; verifier agents should decide from that evidence.

`team.review.cli` supports:

- `claude`: runs `claude --print`.
- `codex`: runs `codex exec` and writes the final response to the review artifact.

`team.review.timeout_seconds` is required. A timed-out review fails instead of leaving the task in an invisible running state.

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
.agents/queue/integrations/<task_id>_<agent_id>.md
```

If merge or checks fail, the task remains unintegrated. Lead fixes the root state or sends a follow-up task to the worker.

## Memory

Workers submit memory proposals. Lead edits `.agents/docs/MEMORY.md`.

Memory proposal path:

```text
.agents/queue/memory_proposals/<task_id>_<agent_id>_<short-slug>.md
```

Lead reviews proposals and edits `.agents/docs/MEMORY.md` only when the lesson is durable, sourced, non-secret, and not a duplicate.
