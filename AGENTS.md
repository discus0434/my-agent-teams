# Agent Team Rules

## Identify

```bash
./scripts/team_identity.sh
```

Primary identity:

- `TEAM_AGENT_ID`
- `TEAM_AGENT_ROLE`
- `TEAM_AGENT_CLI`
- `TEAM_AGENT_MODEL`
- `TEAM_AGENT_WORKTREE`
- `TEAM_SESSION`

Read before task work:

1. `docs/TEAM_PROTOCOL.md`
2. `docs/MEMORY.md`
3. `queue/tasks/<task_id>.md`

## Roles

### lead

- Do small, single-agent changes directly.
- Create task files for delegated work.
- Dispatch tasks with `make team-send`.
- Decide worker questions after review.
- Integrate only `done` reports with `OK` reviews.
- Edit `docs/MEMORY.md` after reviewing memory proposals.

Direct work is allowed when ownership is clear, the change is small, and lead can run the relevant task-specific checks plus:

```bash
make post-change
make smoke
```

Use workers when isolation, parallelism, review follow-up, or separate ownership is useful.

### worker

- Read inbox and task file.
- Claim the task before changing files.
- Work only on the task branch checked out by `make claim`.
- Respect `Allowed paths` and `Do not modify`.
- Run task-specific verification, `make post-change`, and `make smoke`.
- Commit the finished task branch before review.
- Run noninteractive review and handle the result.
- Report blockers, questions, verification gaps, and memory proposals.
- Do not edit `docs/MEMORY.md`.

### verifier

- Runs only through `scripts/team_review.sh`.
- Reviews task, report, committed diff, and verification evidence.
- Returns `Decision: OK`, `Decision: FIX`, or `Decision: ASK_LEAD`.
- Does not edit files or own a worktree.

## Worker Flow

```bash
make claim TASK=<task_id> AGENT=<agent_id>
```

`make claim` checks `Owner`, `Branch`, clean worker worktree, claim state, and checks out:

```text
task/<agent_id>/<task_id>
```

After implementation:

```bash
make post-change
make smoke
git add <changed-files>
git commit -m "<task_id>: <summary>"
make report TASK=<task_id> AGENT=<agent_id> STATUS=needs-review
make review TASK=<task_id> AGENT=<agent_id>
```

Handle review:

- `OK`: update the report to `done`.
- `FIX`: fix, rerun checks, commit, report `needs-review`, and review again.
- `ASK_LEAD`: write the question in the report and notify lead.

Finish:

```bash
make report TASK=<task_id> AGENT=<agent_id> STATUS=done
./scripts/team_inbox.sh <agent_id> --mark <message_id>
```

## Lead Integration

Check status:

```bash
make team-status
```

Integrate only tasks shown as `ready-to-integrate`:

```bash
make integrate TASK=<task_id> AGENT=<agent_id>
```

Integration requires:

- report `Status: done`
- review `Decision: OK`
- clean worker worktree
- clean lead worktree
- unchanged worker head since report

`make integrate` performs a `--no-ff` merge, runs `make post-change` and `make smoke`, and writes `queue/integrations/<task_id>_<agent_id>.md`.

## Memory

- Lead is the only editor of `docs/MEMORY.md`.
- Workers write durable lessons to `queue/memory_proposals/`.
- Store only lessons that will change future agent behavior.
