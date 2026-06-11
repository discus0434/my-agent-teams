#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_BASE="$(mktemp -d)"
TMP_ROOT="$TMP_BASE/repo"
TMP_CONFIG_FILE="$TMP_ROOT/config/agent-team.yaml"
trap 'rm -rf "$TMP_BASE"' EXIT

mkdir -p "$TMP_ROOT"
cp -R "$ROOT/scripts" "$TMP_ROOT/scripts"
cp -R "$ROOT/config" "$TMP_ROOT/config"
cp -R "$ROOT/docs" "$TMP_ROOT/docs"
cp "$ROOT/.gitignore" "$TMP_ROOT/.gitignore"
cp "$ROOT/AGENTS.md" "$TMP_ROOT/AGENTS.md"
cp -P "$ROOT/CLAUDE.md" "$TMP_ROOT/CLAUDE.md"

mkdir -p \
  "$TMP_ROOT/queue/tasks" \
  "$TMP_ROOT/queue/inbox" \
  "$TMP_ROOT/queue/reports" \
  "$TMP_ROOT/queue/reviews" \
  "$TMP_ROOT/queue/integrations" \
  "$TMP_ROOT/queue/memory_proposals" \
  "$TMP_ROOT/queue/state"
cp "$ROOT/queue/tasks/TEMPLATE.md" "$TMP_ROOT/queue/tasks/TEMPLATE.md"

cat > "$TMP_ROOT/Makefile" <<'MAKE'
.PHONY: post-change smoke

post-change:
	@bash -n scripts/*.sh
	@git diff --check -- .

smoke:
	@echo "temp smoke ok"
MAKE

perl -0pi -e 's#\.\./my-agent-teams-worktrees/#../worktrees/#g' "$TMP_CONFIG_FILE"
perl -0pi -e 's/(  review:\n    cli: )claude/${1}codex/; s/(  review:\n    cli: codex\n    model: )claude-opus-4-8/${1}gpt-5.5/' "$TMP_CONFIG_FILE"
mkdir -p "$TMP_BASE/bin"

git -C "$TMP_ROOT" init -q
git -C "$TMP_ROOT" config user.email "agent-team-smoke@example.local"
git -C "$TMP_ROOT" config user.name "Agent Team Smoke"
git -C "$TMP_ROOT" add .
git -C "$TMP_ROOT" commit -qm "Initial template"

cat > "$TMP_BASE/bin/codex" <<'SH'
#!/usr/bin/env bash
if [[ "$1" != "exec" ]]; then
  printf 'unexpected codex command: %s\n' "$*" >&2
  exit 2
fi

output=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-last-message|-o)
      [[ $# -ge 2 ]] || exit 2
      output="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

[[ -n "$output" ]] || { echo "missing --output-last-message" >&2; exit 2; }
{
  printf '%s\n\n' 'Decision: OK'
  printf '%s\n\n' '## Findings'
  printf '%s\n\n' '## Verification Gaps'
  printf '%s\n\n' '## Notes'
  printf '%s\n' 'stub review'
} > "$output"
printf '%s\n' "codex exec stub"
SH
chmod +x "$TMP_BASE/bin/codex"

cat > "$TMP_BASE/bin/tmux" <<'SH'
#!/usr/bin/env bash
case "$1" in
  has-session)
    exit 1
    ;;
  new-session|new-window)
    printf '%s\n' "$*" >> "$TEAM_FAKE_TMUX_LOG"
    exit 0
    ;;
  display-message)
    if [[ "$*" == *"#{pane_id}"* ]]; then
      printf '%%fake-pane\n'
    fi
    exit 0
    ;;
  set-option|send-keys|kill-session)
    exit 0
    ;;
  *)
    printf 'unexpected tmux command: %s\n' "$*" >&2
    exit 2
    ;;
esac
SH
chmod +x "$TMP_BASE/bin/tmux"

TEAM_ROOT="$TMP_ROOT" TEAM_CONFIG_FILE="$TMP_CONFIG_FILE" "$TMP_ROOT/scripts/team_config.sh" session >/dev/null
TEAM_ROOT="$TMP_ROOT" TEAM_CONFIG_FILE="$TMP_CONFIG_FILE" "$TMP_ROOT/scripts/team_config.sh" agent worker-1 >/dev/null
TEAM_ROOT="$TMP_ROOT" TEAM_CONFIG_FILE="$TMP_CONFIG_FILE" "$TMP_ROOT/scripts/team_config.sh" review-field model >/dev/null

identity="$(
  TEAM_ROOT="$TMP_ROOT" \
  TEAM_CONFIG_FILE="$TMP_CONFIG_FILE" \
  TEAM_AGENT_ID=worker-1 \
  TEAM_AGENT_ROLE=worker \
  TEAM_AGENT_CLI=codex \
  TEAM_AGENT_MODEL=gpt-5.5 \
  TEAM_AGENT_WORKTREE=../worktrees/worker-1 \
  TEAM_SESSION=agent-team \
  "$TMP_ROOT/scripts/team_identity.sh"
)"
case "$identity" in
  *"agent_id=worker-1"*) ;;
  *) echo "identity missing agent_id" >&2; exit 1 ;;
esac
case "$identity" in
  *"role=worker"*) ;;
  *) echo "identity missing role" >&2; exit 1 ;;
esac

export TEAM_FAKE_TMUX_LOG="$TMP_BASE/tmux.log"
PATH="$TMP_BASE/bin:$PATH" TEAM_ROOT="$TMP_ROOT" TEAM_CONFIG_FILE="$TMP_CONFIG_FILE" TEAM_BOOT_NUDGE=0 "$TMP_ROOT/scripts/team_start.sh" --restart >/dev/null
case "$(<"$TEAM_FAKE_TMUX_LOG")" in
  *"TEAM_AGENT_ID=lead"*"TEAM_AGENT_ROLE=lead"*"TEAM_AGENT_MODEL="*) ;;
  *) echo "lead launch env was not passed" >&2; exit 1 ;;
esac
case "$(<"$TEAM_FAKE_TMUX_LOG")" in
  *"TEAM_AGENT_ID=worker-1"*"TEAM_AGENT_ROLE=worker"*"TEAM_AGENT_MODEL="*) ;;
  *) echo "worker launch env was not passed" >&2; exit 1 ;;
esac
if TEAM_ROOT="$TMP_ROOT" TEAM_CONFIG_FILE="$TMP_CONFIG_FILE" "$TMP_ROOT/scripts/team_config.sh" agent verifier >/dev/null 2>&1; then
  echo "verifier must not be a tmux agent" >&2
  exit 1
fi

worker_1="$TMP_BASE/worktrees/worker-1"
[[ -d "$worker_1/.git" || -f "$worker_1/.git" ]]
[[ "$(git -C "$worker_1" branch --show-current)" == "agent/worker-1" ]]

printf '%s\n' "root update" > "$TMP_ROOT/root-update.txt"
git -C "$TMP_ROOT" add root-update.txt
git -C "$TMP_ROOT" commit -qm "Root update"
PATH="$TMP_BASE/bin:$PATH" TEAM_ROOT="$TMP_ROOT" TEAM_CONFIG_FILE="$TMP_CONFIG_FILE" TEAM_BOOT_NUDGE=0 "$TMP_ROOT/scripts/team_start.sh" --restart >/dev/null
[[ "$(git -C "$worker_1" rev-parse HEAD)" == "$(git -C "$TMP_ROOT" rev-parse HEAD)" ]]
[[ -f "$worker_1/root-update.txt" ]]

cp "$TMP_ROOT/queue/tasks/TEMPLATE.md" "$TMP_ROOT/queue/tasks/T-001.md"
perl -0pi -e 's/T-XXX/T-001/g' "$TMP_ROOT/queue/tasks/T-001.md"

cp "$TMP_ROOT/queue/tasks/TEMPLATE.md" "$TMP_ROOT/queue/tasks/T-BAD.md"
perl -0pi -e 's/T-XXX/T-BAD/g; s#Branch: task/worker-1/T-BAD#Branch: task/worker-1/wrong#' "$TMP_ROOT/queue/tasks/T-BAD.md"
if TEAM_ROOT="$TMP_ROOT" TEAM_CONFIG_FILE="$TMP_CONFIG_FILE" "$TMP_ROOT/scripts/team_claim.sh" T-BAD worker-1 >/dev/null 2>&1; then
  echo "branch mismatch claim unexpectedly succeeded" >&2
  exit 1
fi

message_id="$(TEAM_ROOT="$TMP_ROOT" TEAM_CONFIG_FILE="$TMP_CONFIG_FILE" TEAM_DISABLE_NUDGE=1 "$TMP_ROOT/scripts/team_send.sh" worker-1 task_assigned T-001)"
[[ -n "$message_id" ]]

pending="$(TEAM_ROOT="$TMP_ROOT" TEAM_CONFIG_FILE="$TMP_CONFIG_FILE" "$TMP_ROOT/scripts/team_inbox.sh" worker-1)"
case "$pending" in
  *"$message_id"*) ;;
  *) echo "message was not visible in inbox" >&2; exit 1 ;;
esac

TEAM_ROOT="$TMP_ROOT" TEAM_CONFIG_FILE="$TMP_CONFIG_FILE" "$TMP_ROOT/scripts/team_inbox.sh" worker-1 --mark "$message_id" >/dev/null
pending_after_mark="$(TEAM_ROOT="$TMP_ROOT" TEAM_CONFIG_FILE="$TMP_CONFIG_FILE" "$TMP_ROOT/scripts/team_inbox.sh" worker-1)"
[[ -z "$pending_after_mark" ]]

TEAM_ROOT="$TMP_ROOT" TEAM_CONFIG_FILE="$TMP_CONFIG_FILE" "$TMP_ROOT/scripts/team_claim.sh" T-001 worker-1 >/dev/null
[[ "$(git -C "$worker_1" branch --show-current)" == "task/worker-1/T-001" ]]
if TEAM_ROOT="$TMP_ROOT" TEAM_CONFIG_FILE="$TMP_CONFIG_FILE" "$TMP_ROOT/scripts/team_claim.sh" T-001 worker-2 >/dev/null 2>&1; then
  echo "second claim unexpectedly succeeded" >&2
  exit 1
fi

printf '%s\n' "worker change" > "$worker_1/integration-smoke.txt"
report_file="$(TEAM_ROOT="$TMP_ROOT" TEAM_CONFIG_FILE="$TMP_CONFIG_FILE" "$TMP_ROOT/scripts/team_report.sh" T-001 worker-1 needs-review)"
[[ -f "$report_file" ]]
if PATH="$TMP_BASE/bin:$PATH" TEAM_ROOT="$TMP_ROOT" TEAM_CONFIG_FILE="$TMP_CONFIG_FILE" TEAM_DISABLE_NUDGE=1 "$TMP_ROOT/scripts/team_review.sh" T-001 worker-1 >/dev/null 2>&1; then
  echo "dirty worktree review unexpectedly succeeded" >&2
  exit 1
fi

git -C "$worker_1" add integration-smoke.txt
git -C "$worker_1" commit -qm "Implement T-001"
report_file="$(TEAM_ROOT="$TMP_ROOT" TEAM_CONFIG_FILE="$TMP_CONFIG_FILE" "$TMP_ROOT/scripts/team_report.sh" T-001 worker-1 needs-review)"
grep -q '^Branch: task/worker-1/T-001$' "$report_file"
grep -q '^Head commit: ' "$report_file"

review_file="$(PATH="$TMP_BASE/bin:$PATH" TEAM_ROOT="$TMP_ROOT" TEAM_CONFIG_FILE="$TMP_CONFIG_FILE" TEAM_DISABLE_NUDGE=1 "$TMP_ROOT/scripts/team_review.sh" T-001 worker-1)"
[[ -f "$review_file" ]]
case "$review_file" in
  "$TMP_ROOT/queue/reviews/T-001_worker-1_review.md") ;;
  *) echo "unexpected review path: $review_file" >&2; exit 1 ;;
esac

review_message="$(TEAM_ROOT="$TMP_ROOT" TEAM_CONFIG_FILE="$TMP_CONFIG_FILE" "$TMP_ROOT/scripts/team_inbox.sh" worker-1)"
case "$review_message" in
  *"\"type\":\"review\""*) ;;
  *) echo "review message was not returned to worker" >&2; exit 1 ;;
esac

report_file="$(TEAM_ROOT="$TMP_ROOT" TEAM_CONFIG_FILE="$TMP_CONFIG_FILE" "$TMP_ROOT/scripts/team_report.sh" T-001 worker-1 done)"
status_output="$(TEAM_ROOT="$TMP_ROOT" TEAM_CONFIG_FILE="$TMP_CONFIG_FILE" "$TMP_ROOT/scripts/team_status.sh")"
case "$status_output" in
  *"T-001 owner=worker-1 phase=ready-to-integrate"*) ;;
  *) echo "status did not show ready-to-integrate" >&2; exit 1 ;;
esac

integration_file="$(PATH="$TMP_BASE/bin:$PATH" TEAM_ROOT="$TMP_ROOT" TEAM_CONFIG_FILE="$TMP_CONFIG_FILE" "$TMP_ROOT/scripts/team_integrate.sh" T-001 worker-1)"
[[ -f "$integration_file" ]]
grep -q '^Status: integrated$' "$integration_file"
[[ -f "$TMP_ROOT/integration-smoke.txt" ]]

integrated_status="$(TEAM_ROOT="$TMP_ROOT" TEAM_CONFIG_FILE="$TMP_CONFIG_FILE" "$TMP_ROOT/scripts/team_status.sh")"
case "$integrated_status" in
  *"T-001 owner=worker-1 phase=integrated"*) ;;
  *) echo "status did not show integrated" >&2; exit 1 ;;
esac

echo "smoke ok"
