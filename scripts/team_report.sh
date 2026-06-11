#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/team_common.sh"
source "$SCRIPT_DIR/team_config.sh"

usage() {
  echo "usage: team_report.sh <task_id> <agent_id> <done|blocked|needs-review>" >&2
}

[[ $# -eq 3 ]] || { usage; exit 2; }

task_id="$1"
agent_id="$2"
status="$3"

case "$status" in
  done|blocked|needs-review) ;;
  *) die "invalid status: $status" ;;
esac

if ! team_config_agent_record "$agent_id" >/dev/null; then
  die "unknown agent: $agent_id"
fi

ensure_team_dirs
report_file="$TEAM_QUEUE_DIR/reports/${task_id}_${agent_id}.md"
state_file="$(team_task_state_file "$task_id")"
[[ -f "$state_file" ]] || die "task is not claimed: $task_id"

owner="$(team_task_state_field "$task_id" owner)"
current_status="$(team_task_state_field "$task_id" status)"
worktree="$(team_task_state_field "$task_id" worktree)"
branch="$(team_task_state_field "$task_id" branch)"
base_commit="$(team_task_state_field "$task_id" base_commit)"
merge_commit="$(team_task_state_field "$task_id" merge_commit)"
review_file="$(team_task_state_field "$task_id" review)"
integration_file="$(team_task_state_field "$task_id" integration)"
review_decision="$(team_task_state_field "$task_id" review_decision)"

[[ "$owner" == "$agent_id" ]] || die "task $task_id is owned by $owner, not $agent_id"
[[ "$current_status" != "integrated" ]] || die "task $task_id is already integrated"
[[ -n "$worktree" ]] || die "task $task_id state is missing worktree"
[[ -n "$branch" ]] || die "task $task_id state is missing branch"
[[ -n "$base_commit" ]] || die "task $task_id state is missing base_commit"

abs_worktree="$(abs_path "$worktree")"
[[ -d "$abs_worktree" ]] || die "worker worktree not found: $abs_worktree"
current_branch="$(git -C "$abs_worktree" branch --show-current)"
[[ "$current_branch" == "$branch" ]] || die "worker worktree is on $current_branch, expected $branch"

head_commit="$(git -C "$abs_worktree" rev-parse HEAD)"

if [[ "$status" == "done" && "$review_decision" != "OK" ]]; then
  die "report Status done requires review Decision OK"
fi

if [[ ! -f "$report_file" ]]; then
  cat > "$report_file" <<REPORT
# Report: $task_id by $agent_id

Status: $status
Branch: $branch
Base commit: $base_commit
Head commit: $head_commit
Review: ${review_file:-none}
Integration: ${integration_file:-none}

## Summary

- 未記入

## Files changed

- 未記入

## Verification

- Command:
- Result:
- Evidence:

## Post-change

- Command: make post-change
- Result:
- Evidence:

## Smoke

- Command: make smoke
- Result:
- Evidence:

## Review

- Command: make review TASK=$task_id AGENT=$agent_id
- Result:
- Evidence:

## Integration

- Command: make integrate TASK=$task_id AGENT=$agent_id
- Result:
- Evidence:

## Blockers

- 未記入

## Questions for lead

- 未記入

## Memory proposals

- 未記入
REPORT
else
  team_update_markdown_field "$report_file" "Status" "$status"
  team_update_markdown_field "$report_file" "Branch" "$branch"
  team_update_markdown_field "$report_file" "Base commit" "$base_commit"
  team_update_markdown_field "$report_file" "Head commit" "$head_commit"
  team_update_markdown_field "$report_file" "Review" "${review_file:-none}"
  team_update_markdown_field "$report_file" "Integration" "${integration_file:-none}"
fi

team_write_task_state \
  "$task_id" \
  "$agent_id" \
  "$status" \
  "$worktree" \
  "$branch" \
  "$base_commit" \
  "$head_commit" \
  "$merge_commit" \
  "$report_file" \
  "$review_file" \
  "$integration_file" \
  "$review_decision"

echo "$report_file"
