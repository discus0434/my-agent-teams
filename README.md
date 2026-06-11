# my-agent-teams

tmux、file mailbox、repo 外 worktree を使う agent team template です。

Lead は小さい変更を直接行い、大きい変更を task に切って worker に渡します。worker は task branch で実装、検証、review 対応、report 更新まで行い、lead が最後に merge します。

## Install

### macOS (Homebrew)

<details><summary>コマンド</summary>

```bash
brew install gh ripgrep fd bat jq yq git-delta direnv tmux pnpm node python
brew install --cask codex
npm install -g @anthropic-ai/claude-code
```

</details>

### Linux (Debian/Ubuntu)

<details><summary>コマンド</summary>

```bash
npm install -g @openai/codex @anthropic-ai/claude-code
wget -qO- https://get.pnpm.io/install.sh | sh -

# GitHub CLI (official apt repository)
type -p wget >/dev/null || (sudo apt update && sudo apt install -y wget)
sudo mkdir -p -m 755 /etc/apt/keyrings
out=$(mktemp) && wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg
cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
sudo mkdir -p -m 755 /etc/apt/sources.list.d
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt-get install -y gh ripgrep fd-find bat jq direnv tmux python3 nodejs npm
command -v fd >/dev/null || sudo ln -s /usr/bin/fdfind /usr/local/bin/fd
command -v bat >/dev/null || sudo ln -s /usr/bin/batcat /usr/local/bin/bat
```

</details>

### direnv

```bash
direnv allow
```

shell hook が未設定の場合は、利用している shell の rc file に追加します。

```bash
eval "$(direnv hook zsh)"
```

## Bootstrap

Lead agent で `team-bootstrap` skill を使い、構築対象と stack を決めます。

- stack に応じた package manager / formatter / linter / test runner / build command
- Python example: `uv` / `ruff` / `pytest`
- TypeScript example: `pnpm` / `biome` / `vitest`
- checks: `make post-change`
- runtime smoke: `make smoke`

bootstrap 完了後は `.codex/skills/team-bootstrap/` を削除します。

初期化後、worker worktree を作る前に commit します。

```bash
make post-change
make smoke
git add .
git commit -m "Bootstrap project"
```

## Start

```bash
make team-start
tmux attach -t agent-team
```

worker worktree は `../my-agent-teams-worktrees/<agent_id>` に作られます。repo 内 `worktrees/` は使いません。

## Dispatch

```bash
cp queue/tasks/TEMPLATE.md queue/tasks/T-001.md
${EDITOR:-vi} queue/tasks/T-001.md
make team-send TO=worker-1 TYPE=task_assigned TASK=T-001
make team-status
```

Task branch は必ず次の形にします。

```text
task/<agent_id>/<task_id>
```

Example:

```text
Owner: worker-1
Branch: task/worker-1/T-001
```

## Worker Flow

```bash
make claim TASK=T-001 AGENT=worker-1
make post-change
make smoke
git add <changed-files>
git commit -m "T-001: implement task"
make report TASK=T-001 AGENT=worker-1 STATUS=needs-review
make review TASK=T-001 AGENT=worker-1
```

Review decision:

- `OK`: `make report TASK=T-001 AGENT=worker-1 STATUS=done`
- `FIX`: fix, rerun checks, commit, report `needs-review`, review again
- `ASK_LEAD`: write the question in the report and notify lead

## Integrate

Lead checks tasks ready to merge:

```bash
make team-status
```

Tasks with `phase=ready-to-integrate` can be merged:

```bash
make integrate TASK=T-001 AGENT=worker-1
```

Integration performs a `--no-ff` merge, runs `make post-change` and `make smoke`, and writes:

```text
queue/integrations/T-001_worker-1.md
```

## Stop

```bash
make team-stop
```

## Shared Entrypoints

All CLI agents share the same rules and skills.

- `CLAUDE.md` -> `AGENTS.md`
- `.claude/skills` -> `../.codex/skills`
- `.agents/skills` -> `../.codex/skills`

## Layout

- `AGENTS.md`: common agent rules
- `.codex/skills/`: agent skills
- `config/agent-team.yaml`: roles, commands, models, worktrees
- `docs/TEAM_PROTOCOL.md`: mailbox, branch, review, integration protocol
- `docs/MEMORY.md`: shared memory and update rules
- `queue/tasks/`: task files
- `queue/inbox/`: JSONL inboxes
- `queue/reports/`: worker reports
- `queue/reviews/`: verifier reviews
- `queue/integrations/`: lead integration logs
- `scripts/`: lifecycle commands
- `Makefile`: common command entrypoints
