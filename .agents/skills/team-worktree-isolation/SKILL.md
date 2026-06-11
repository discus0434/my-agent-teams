---
name: team-worktree-isolation
description: Use only when starting, inspecting, debugging, or repairing repo-external worker worktrees, parking branches, task branches, or branch/worktree state mismatches.
---

# team-worktree-isolation

## Standard

- worker worktree は repo 外に置く。
- default: `../customizable-agent-teams-worktrees/<agent_id>`
- repo 内 `worktrees/` は使わない。
- parking branch: `agent/<agent_id>`
- task branch: `task/<agent_id>/<task_id>`

## Check

```bash
git rev-parse --git-dir
git rev-parse --git-common-dir
git rev-parse --show-superproject-working-tree 2>/dev/null
```

- `git rev-parse` の値で linked worktree と submodule を区別する。
- config の `worktree` path が repo 外を向いている。
- 対象 path が空でない非-worktree なら fail fast。

## Start

```bash
make team-start
```

worktree 作成後は標準 smoke / test を確認する。失敗している場合は pre-existing failure として report に残す。

通常の task claim ではこの skill を読まない。`make claim` の検査に従う。
