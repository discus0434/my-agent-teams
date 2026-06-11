#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/team_common.sh"
source "$SCRIPT_DIR/team_config.sh"

usage() {
  echo "usage: team_integrate.sh <task_id> <agent_id>" >&2
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

ensure_team_dirs

task_file="$TEAM_QUEUE_DIR/tasks/$task_id.md"
claim_file="$TEAM_STATE_DIR/claims/$task_id.claim"
state_file="$(team_task_state_file "$task_id")"
report_file="$TEAM_QUEUE_DIR/reports/${task_id}_${agent_id}.md"

[[ -f "$task_file" ]] || die "task file not found: $task_file"
[[ -f "$claim_file" ]] || die "task is not claimed: $task_id"
[[ -f "$state_file" ]] || die "task state not found: $state_file"
[[ -f "$report_file" ]] || die "report file not found: $report_file"

claimed_by="$(<"$claim_file")"
[[ "$claimed_by" == "$agent_id" ]] || die "task $task_id is claimed by $claimed_by, not $agent_id"

owner="$(team_task_state_field "$task_id" owner)"
status="$(team_task_state_field "$task_id" status)"
worktree="$(team_task_state_field "$task_id" worktree)"
branch="$(team_task_state_field "$task_id" branch)"
base_commit="$(team_task_state_field "$task_id" base_commit)"
head_commit="$(team_task_state_field "$task_id" head_commit)"
previous_merge_commit="$(team_task_state_field "$task_id" merge_commit)"
review_file="$(team_task_state_field "$task_id" review)"
review_decision="$(team_task_state_field "$task_id" review_decision)"

[[ "$owner" == "$agent_id" ]] || die "task $task_id is owned by $owner, not $agent_id"
[[ -n "$worktree" ]] || die "task $task_id state is missing worktree"
[[ -n "$branch" ]] || die "task $task_id state is missing branch"
[[ -n "$base_commit" ]] || die "task $task_id state is missing base_commit"
[[ -n "$head_commit" ]] || die "task $task_id state is missing head_commit"
[[ -n "$review_file" ]] || die "task $task_id state is missing review"
[[ -f "$review_file" ]] || die "review file not found: $review_file"

report_status="$(team_report_field "$report_file" Status)"
[[ "$report_status" == "done" ]] || die "report Status must be done before integration: $report_status"

parsed_review_decision="$(team_review_decision "$review_file")"
[[ "$parsed_review_decision" == "OK" ]] || die "review Decision must be OK before integration: $parsed_review_decision"
[[ "$review_decision" == "OK" ]] || die "task state review_decision must be OK before integration: $review_decision"

abs_worktree="$(abs_path "$worktree")"
[[ -d "$abs_worktree" ]] || die "worker worktree not found: $abs_worktree"
worker_branch="$(git -C "$abs_worktree" branch --show-current)"
[[ "$worker_branch" == "$branch" ]] || die "worker worktree is on $worker_branch, expected $branch"

if ! team_git_is_clean "$abs_worktree"; then
  team_git_dirty_summary "$abs_worktree" >&2
  die "worker worktree must be clean before integration: $abs_worktree"
fi

actual_head="$(git -C "$abs_worktree" rev-parse HEAD)"
[[ "$actual_head" == "$head_commit" ]] || die "worker HEAD changed after report: state=$head_commit actual=$actual_head"

if ! git -C "$TEAM_ROOT" show-ref --verify --quiet "refs/heads/$branch"; then
  die "task branch not found: $branch"
fi

if ! team_git_is_clean "$TEAM_ROOT"; then
  team_git_dirty_summary "$TEAM_ROOT" >&2
  die "lead worktree must be clean before integration: $TEAM_ROOT"
fi

integration_file="$TEAM_QUEUE_DIR/integrations/${task_id}_${agent_id}.md"
merge_log="$TEAM_QUEUE_DIR/integrations/${task_id}_${agent_id}_merge.log"
post_change_log="$TEAM_QUEUE_DIR/integrations/${task_id}_${agent_id}_post-change.log"
smoke_log="$TEAM_QUEUE_DIR/integrations/${task_id}_${agent_id}_smoke.log"
lead_base_commit="$(git -C "$TEAM_ROOT" rev-parse HEAD)"

if git -C "$TEAM_ROOT" merge-base --is-ancestor "$branch" HEAD; then
  [[ -n "$previous_merge_commit" ]] || die "task branch is already merged, but task state is missing merge_commit"
  merge_commit="$previous_merge_commit"
  {
    printf 'Already integrated: %s\n' "$branch"
    printf 'Recorded merge commit: %s\n' "$merge_commit"
    printf 'Rerunning integration checks from lead HEAD: %s\n' "$lead_base_commit"
  } > "$merge_log"
else
  git -C "$TEAM_ROOT" merge --no-ff "$branch" -m "Integrate $task_id from $agent_id" > "$merge_log" 2>&1
  merge_commit="$(git -C "$TEAM_ROOT" rev-parse HEAD)"
fi

post_change_status=0
smoke_status=0

make -C "$TEAM_ROOT" post-change > "$post_change_log" 2>&1 || post_change_status=$?
if [[ "$post_change_status" -eq 0 ]]; then
  make -C "$TEAM_ROOT" smoke > "$smoke_log" 2>&1 || smoke_status=$?
else
  printf '%s\n' "skipped because make post-change failed" > "$smoke_log"
  smoke_status=125
fi

if [[ "$post_change_status" -eq 0 && "$smoke_status" -eq 0 ]]; then
  integration_status="integrated"
else
  integration_status="integration-failed"
fi

cat > "$integration_file" <<REPORT
# Integration: $task_id by $agent_id

Status: $integration_status
Branch: $branch
Lead base commit: $lead_base_commit
Task base commit: $base_commit
Task head commit: $head_commit
Merge commit: $merge_commit
Report: $report_file
Review: $review_file
Merge log: $merge_log

## Checks

- Command: make post-change
- Status: $post_change_status
- Log: $post_change_log

- Command: make smoke
- Status: $smoke_status
- Log: $smoke_log
REPORT

team_update_markdown_field "$report_file" "Integration" "$integration_file"
team_write_task_state \
  "$task_id" \
  "$agent_id" \
  "$integration_status" \
  "$worktree" \
  "$branch" \
  "$base_commit" \
  "$head_commit" \
  "$merge_commit" \
  "$report_file" \
  "$review_file" \
  "$integration_file" \
  "$review_decision"

if [[ "$integration_status" != "integrated" ]]; then
  die "integration checks failed. See $integration_file"
fi

echo "$integration_file"
