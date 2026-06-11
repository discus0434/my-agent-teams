#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/team_common.sh"
source "$SCRIPT_DIR/team_config.sh"

session="$(team_config_session)"
[[ -n "$session" ]] || die "team.session is missing in $TEAM_CONFIG_FILE"

if tmux has-session -t "$session" 2>/dev/null; then
  tmux kill-session -t "$session"
  echo "stopped tmux session: $session"
else
  echo "tmux session is not running: $session"
fi

