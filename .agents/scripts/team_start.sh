#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/team_common.sh"
source "$SCRIPT_DIR/team_config.sh"

restart=0
skip_worktrees=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --restart)
      restart=1
      shift
      ;;
    --skip-worktrees)
      skip_worktrees=1
      shift
      ;;
    -h|--help)
      cat <<'USAGE'
usage: team_start.sh [--restart] [--skip-worktrees]

Starts the tmux session described in .agents/config/agent-team.yaml.
USAGE
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

ensure_agent_worktree() {
  local agent_id="$1"
  local worktree="$2"
  local abs_worktree
  abs_worktree="$(abs_path "$worktree")"
  local branch="agent/$agent_id"

  if [[ "$worktree" == "." ]]; then
    return 0
  fi

  if ! git -C "$TEAM_ROOT" rev-parse --verify HEAD >/dev/null 2>&1; then
    die "git HEAD does not exist yet. Commit the template once before creating agent worktrees, or rerun with --skip-worktrees."
  fi

  if [[ -d "$abs_worktree/.git" || -f "$abs_worktree/.git" ]]; then
    local current_branch
    current_branch="$(git -C "$abs_worktree" branch --show-current)"
    if [[ "$current_branch" == "$branch" ]]; then
      if ! team_git_is_clean "$abs_worktree"; then
        team_git_dirty_summary "$abs_worktree" >&2
        die "parking worktree must be clean before start: $abs_worktree"
      fi
      local root_head worker_head
      root_head="$(git -C "$TEAM_ROOT" rev-parse HEAD)"
      worker_head="$(git -C "$abs_worktree" rev-parse HEAD)"
      if [[ "$worker_head" != "$root_head" ]]; then
        if git -C "$abs_worktree" merge-base --is-ancestor HEAD "$root_head"; then
          git -C "$abs_worktree" merge --ff-only "$root_head" >/dev/null
        else
          die "parking branch $branch cannot fast-forward to lead HEAD"
        fi
      fi
    fi
    return 0
  fi

  if [[ -e "$abs_worktree" ]]; then
    if [[ -n "$(find "$abs_worktree" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
      die "$abs_worktree exists but is not a git worktree"
    fi
  fi

  mkdir -p "$(dirname "$abs_worktree")"

  if git -C "$TEAM_ROOT" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$TEAM_ROOT" worktree add "$abs_worktree" "$branch"
  else
    git -C "$TEAM_ROOT" worktree add -b "$branch" "$abs_worktree" HEAD
  fi
}

write_agent_state() {
  local id="$1"
  local role="$2"
  local cli="$3"
  local model="$4"
  local window="$5"
  local worktree="$6"
  local command="$7"
  local pane="$8"
  local session="$9"
  local state_file="$TEAM_STATE_DIR/agents/$id.env"

  {
    printf 'agent_id=%s\n' "$(shell_quote "$id")"
    printf 'role=%s\n' "$(shell_quote "$role")"
    printf 'cli=%s\n' "$(shell_quote "$cli")"
    printf 'model=%s\n' "$(shell_quote "$model")"
    printf 'window=%s\n' "$(shell_quote "$window")"
    printf 'worktree=%s\n' "$(shell_quote "$worktree")"
    printf 'command=%s\n' "$(shell_quote "$command")"
    printf 'pane=%s\n' "$(shell_quote "$pane")"
    printf 'session=%s\n' "$(shell_quote "$session")"
    printf 'started_at=%s\n' "$(shell_quote "$(team_now_utc)")"
  } > "$state_file"
}

set_pane_metadata() {
  local pane="$1"
  local id="$2"
  local role="$3"
  local model="$4"
  local worktree="$5"

  tmux set-option -p -t "$pane" @agent_id "$id" >/dev/null
  tmux set-option -p -t "$pane" @role "$role" >/dev/null
  tmux set-option -p -t "$pane" @model "$model" >/dev/null
  tmux set-option -p -t "$pane" @worktree "$worktree" >/dev/null
}

send_boot_nudge() {
  local pane="$1"
  local id="$2"
  local role="$3"

  if [[ "${TEAM_BOOT_NUDGE:-1}" == "0" ]]; then
    return 0
  fi

  sleep "${TEAM_BOOT_NUDGE_DELAY:-1}"
  if [[ "$role" == "lead" ]]; then
    tmux send-keys -t "$pane" C-u "AGENTS.md を読み、role=lead agent_id=$id として待機してください。ユーザー指示はこのpaneに直接入力されます。agent間通知は inbox $id です。" C-m
  else
    tmux send-keys -t "$pane" C-u "AGENTS.md を読み、role=$role agent_id=$id として待機してください。通知は inbox $id です。" C-m
  fi
}

agent_launch_command() {
  local id="$1"
  local role="$2"
  local cli="$3"
  local model="$4"
  local worktree="$5"
  local session="$6"
  local command="$7"

  printf 'TEAM_AGENT_ID=%s TEAM_AGENT_ROLE=%s TEAM_AGENT_CLI=%s TEAM_AGENT_MODEL=%s TEAM_AGENT_WORKTREE=%s TEAM_SESSION=%s TEAM_ROOT=%s TEAM_CONFIG_FILE=%s %s' \
    "$(shell_quote "$id")" \
    "$(shell_quote "$role")" \
    "$(shell_quote "$cli")" \
    "$(shell_quote "$model")" \
    "$(shell_quote "$worktree")" \
    "$(shell_quote "$session")" \
    "$(shell_quote "$TEAM_ROOT")" \
    "$(shell_quote "$TEAM_CONFIG_FILE")" \
    "$command"
}

main() {
  require_command tmux
  ensure_team_dirs

  local session
  session="$(team_config_session)"
  [[ -n "$session" ]] || die "team.session is missing in $TEAM_CONFIG_FILE"

  if tmux has-session -t "$session" 2>/dev/null; then
    if [[ "$restart" -eq 1 ]]; then
      tmux kill-session -t "$session"
    else
      die "tmux session already exists: $session. Use --restart to replace it."
    fi
  fi

  rm -f "$TEAM_STATE_DIR/agents/"*.env 2>/dev/null || true

  local first=1
  while IFS='|' read -r id role cli model window worktree command; do
    [[ -n "$id" ]] || continue
    [[ -n "$window" ]] || window="$id"
    [[ -n "$worktree" ]] || worktree="."
    [[ -n "$command" ]] || die "agent $id has no command"

    if [[ "$skip_worktrees" -eq 0 ]]; then
      ensure_agent_worktree "$id" "$worktree"
    fi

    local abs_worktree
    abs_worktree="$(abs_path "$worktree")"
    mkdir -p "$abs_worktree"

    local launch_command
    launch_command="$(agent_launch_command "$id" "$role" "$cli" "$model" "$worktree" "$session" "$command")"

    if [[ "$first" -eq 1 ]]; then
      tmux new-session -d -s "$session" -n "$window" -c "$abs_worktree" "$launch_command"
      first=0
    else
      tmux new-window -d -t "$session:" -n "$window" -c "$abs_worktree" "$launch_command"
    fi

    local pane
    pane="$(tmux display-message -p -t "$session:$window.0" '#{pane_id}')"
    set_pane_metadata "$pane" "$id" "$role" "$model" "$worktree"
    write_agent_state "$id" "$role" "$cli" "$model" "$window" "$worktree" "$command" "$pane" "$session"
    send_boot_nudge "$pane" "$id" "$role"
  done < <(team_config_agents)

  tmux set-option -t "$session" status on >/dev/null
  tmux set-option -t "$session" pane-border-status top >/dev/null
  tmux set-option -t "$session" pane-border-format '#{@agent_id} #{@role} #{@model}' >/dev/null

  echo "started tmux session: $session"
  echo "attach with: tmux attach -t $session"
}

main "$@"
