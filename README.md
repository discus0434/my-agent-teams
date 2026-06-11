# my-agent-teams

Claude Code と Codex を混ぜて、ローカルの tmux 上で lead / worker チームを動かすためのテンプレートです。

このリポジトリを使うと、次の流れをそのまま始められます。

1. lead pane に人間が依頼する。
2. lead が小さい変更は直接行い、大きい変更は task に分ける。
3. worker が repo 外 worktree の task branch で実装する。
4. worker が検証、smoke、review 対応、report 更新まで行う。
5. lead が `make integrate` で root repository に取り込む。

## Quick Start

```bash
direnv allow
make post-change
make smoke
make team-start
tmux attach -t agent-team
```

`lead` pane にプロジェクトの依頼を直接入力してください。

worker worktree は `../my-agent-teams-worktrees/<agent_id>` に作られます。repo 内に worktree は置きません。

## Install

### macOS

```bash
brew install gh ripgrep fd bat jq yq git-delta direnv tmux pnpm node python uv
brew install --cask codex
npm install -g @anthropic-ai/claude-code
```

### Linux

```bash
npm install -g @openai/codex @anthropic-ai/claude-code
wget -qO- https://get.pnpm.io/install.sh | sh -
wget -qO- https://astral.sh/uv/install.sh | sh
```

GitHub CLI:

```bash
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

direnv shell hook:

```bash
eval "$(direnv hook zsh)"
direnv allow
```

## Bootstrap A Project

新しいプロジェクトとして使い始めるときは、lead agent に構築したいものを伝えて `team-bootstrap` skill で初期化します。

bootstrap で決めるもの:

- 何を作るか
- 使用言語と package manager
- formatter / linter / test runner
- build command
- `make post-change`
- `make smoke`

初期化後、worker worktree を作る前に一度 commit します。

```bash
make post-change
make smoke
git add .
git commit -m "Bootstrap project"
```

bootstrap が終わったプロジェクトでは `.codex/skills/team-bootstrap/` を削除します。

## Start A Team

```bash
make team-start
tmux attach -t agent-team
```

lead への依頼は、tmux の `lead` pane にそのまま入力します。

agent 間の通知は短い `inbox <agent_id>` だけです。本文は `queue/inbox/` と `queue/tasks/` にあります。

```bash
make inbox AGENT=worker-1
make inbox AGENT=worker-1 MARK=<message_id>
```

pane に `inbox <agent_id>` が入力されたまま止まっている場合:

```bash
make team-submit AGENT=worker-1
```

## Dispatch A Task

```bash
cp queue/tasks/TEMPLATE.md queue/tasks/T-001.md
${EDITOR:-vi} queue/tasks/T-001.md
make team-send TO=worker-1 TYPE=task_assigned TASK=T-001
make team-status
```

task file では branch を必ずこの形にします。

```text
Owner: worker-1
Branch: task/worker-1/T-001
```

## Worker Commands

```bash
make claim TASK=T-001 AGENT=worker-1
make post-change
make smoke
git add <changed-files>
git commit -m "T-001: implement task"
make report TASK=T-001 AGENT=worker-1 STATUS=needs-review
make review TASK=T-001 AGENT=worker-1
```

review result:

- `OK`: `make report TASK=T-001 AGENT=worker-1 STATUS=done`
- `FIX`: 修正、再検証、追加 commit、再 report、再 review
- `ASK_LEAD`: report に質問を書いて lead に相談

review artifact を読んだ後、review 通知が inbox に残っていれば mark します。

```bash
make inbox AGENT=worker-1
make inbox AGENT=worker-1 MARK=<message_id>
```

## Integrate

lead は `ready-to-integrate` の task だけを取り込みます。

```bash
make team-status
make integrate TASK=T-001 AGENT=worker-1
```

`make integrate` は `--no-ff` merge、`make post-change`、`make smoke` を実行し、結果を `queue/integrations/` に残します。

## Stop

```bash
make team-stop
```

## Important Files

- `AGENTS.md`: 全 agent 共通の作業ルール
- `CLAUDE.md`: `AGENTS.md` への symlink
- `.codex/skills/`: Codex / Claude Code 共通 skill
- `.claude/skills`: `.codex/skills` への symlink
- `config/agent-team.yaml`: role、model、起動 command、worktree 設定
- `docs/TEAM_PROTOCOL.md`: task、report、review、integration の詳細手順
- `docs/MEMORY.md`: 共有 memory と更新ルール
- `queue/tasks/`: task files
- `queue/inbox/`: agent inbox
- `queue/reports/`: worker reports
- `queue/reviews/`: verifier reviews
- `queue/integrations/`: lead integration logs
- `scripts/`: harness commands
- `Makefile`: 操作用 entrypoints
