#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/team_common.sh"
source "$SCRIPT_DIR/team_config.sh"

lead_id=""
while IFS='|' read -r id role _cli _model _window _worktree _command; do
  [[ -n "$id" ]] || continue
  if [[ "$role" == "lead" ]]; then
    [[ -z "$lead_id" ]] || die "multiple lead agents configured in $TEAM_CONFIG_FILE"
    lead_id="$id"
  fi
done < <(team_config_agents)

[[ -n "$lead_id" ]] || die "no lead agent configured in $TEAM_CONFIG_FILE"

TEAM_BOOT_NUDGE=0 "$SCRIPT_DIR/team_start.sh" --restart --lead-only

state_file="$TEAM_STATE_DIR/agents/$lead_id.env"
[[ -f "$state_file" ]] || die "no pane state for lead agent: $lead_id"

# shellcheck disable=SC1090
source "$state_file"

if [[ -z "${pane:-}" || -z "${session:-}" || -z "${cli:-}" ]]; then
  die "pane state for lead agent is incomplete: $lead_id"
fi

require_command tmux

if ! tmux has-session -t "$session" 2>/dev/null; then
  die "tmux session is not running: $session"
fi

prompt="team-bootstrap を開始してください。role=lead agent_id=$lead_id として AGENTS.md に従い、まだ実装や worker dispatch は行わず、まずこの pane のユーザーに、新しいプロジェクトの初期化に必要な最小限の質問をしてください。確認する項目は、何を作るか、使用言語/runtime、deliverable、最初の user-visible behavior、make smoke で確認する動作です。"

team_tmux_wait_for_ready "$pane" "$cli" 30
team_tmux_send_text "$pane" "$prompt"

echo "started bootstrap in tmux session: $session"
echo "attach with: tmux attach -t $session"
