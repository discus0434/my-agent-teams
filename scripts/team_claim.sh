#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/team_common.sh"
source "$SCRIPT_DIR/team_config.sh"

usage() {
  echo "usage: team_claim.sh <task_id> <agent_id>" >&2
}

[[ $# -eq 2 ]] || { usage; exit 2; }

task_id="$1"
agent_id="$2"

[[ "$task_id" != */* ]] || die "task_id must not contain '/': $task_id"
[[ "$agent_id" != */* ]] || die "agent_id must not contain '/': $agent_id"

if ! team_config_agent_record "$agent_id" >/dev/null; then
  die "unknown agent: $agent_id"
fi

agent_role="$(team_config_agent_field "$agent_id" role)"
[[ "$agent_role" == "worker" ]] || die "$agent_id is not a worker agent"

worker_worktree="$(team_config_agent_field "$agent_id" worktree)"
[[ -n "$worker_worktree" ]] || die "$agent_id worktree is missing"
abs_worktree="$(abs_path "$worker_worktree")"
[[ -d "$abs_worktree" ]] || die "worker worktree not found: $abs_worktree"
git -C "$abs_worktree" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "worker worktree is not a git worktree: $abs_worktree"

task_file="$TEAM_QUEUE_DIR/tasks/$task_id.md"
[[ -f "$task_file" ]] || die "task file not found: $task_file"

task_owner="$(team_task_markdown_field "$task_file" Owner)" || die "task Owner is missing: $task_file"
task_branch="$(team_task_markdown_field "$task_file" Branch)" || die "task Branch is missing: $task_file"
expected_branch="$(team_task_branch "$task_id" "$agent_id")"

[[ "$task_owner" == "$agent_id" ]] || die "task Owner mismatch: expected $agent_id, got $task_owner"
[[ "$task_branch" == "$expected_branch" ]] || die "task Branch mismatch: expected $expected_branch, got $task_branch"

if ! git -C "$TEAM_ROOT" rev-parse --verify HEAD >/dev/null 2>&1; then
  die "git HEAD does not exist yet. Commit the template before claiming tasks."
fi

if ! team_git_is_clean "$abs_worktree"; then
  team_git_dirty_summary "$abs_worktree" >&2
  die "worker worktree must be clean before claiming $task_id: $abs_worktree"
fi

ensure_team_dirs
claim_file="$TEAM_STATE_DIR/claims/$task_id.claim"
base_commit="$(git -C "$TEAM_ROOT" rev-parse HEAD)"

acquire_team_lock "claim-$task_id"
if [[ -f "$claim_file" ]]; then
  existing="$(<"$claim_file")"
  if [[ "$existing" != "$agent_id" ]]; then
    release_team_lock
    die "task $task_id is already claimed by $existing"
  fi
  existing_branch="$(team_task_state_field "$task_id" branch)"
  [[ "$existing_branch" == "$expected_branch" ]] || {
    release_team_lock
    die "task $task_id state branch mismatch: expected $expected_branch, got $existing_branch"
  }
  git -C "$abs_worktree" checkout "$expected_branch" >/dev/null
  release_team_lock
  echo "claimed $task_id by $agent_id on $expected_branch"
  exit 0
fi

if git -C "$TEAM_ROOT" show-ref --verify --quiet "refs/heads/$expected_branch"; then
  release_team_lock
  die "task branch already exists without claim: $expected_branch"
fi

git -C "$abs_worktree" checkout -b "$expected_branch" "$base_commit" >/dev/null

printf '%s\n' "$agent_id" > "$claim_file"
team_write_task_state \
  "$task_id" \
  "$agent_id" \
  "claimed" \
  "$worker_worktree" \
  "$expected_branch" \
  "$base_commit" \
  "" \
  "" \
  "" \
  "" \
  "" \
  ""
release_team_lock

echo "claimed $task_id by $agent_id on $expected_branch"
