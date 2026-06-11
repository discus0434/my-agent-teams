---
name: team-review
description: Use only when a verifier result is ambiguous, disputed, or says ASK_LEAD, and a worker or lead must decide whether to fix, accept risk, split scope, or change the task contract.
---

# team-review

## Inputs

- `.agents/queue/tasks/<task_id>.md`
- `.agents/queue/reports/<task_id>_<agent_id>.md`
- `.agents/queue/reviews/<task_id>_<agent_id>_review.md`
- `.agents/docs/MEMORY.md`

## Worker Handling

- 明確な `OK` / `FIX` は AGENTS.md の flow に従う。
- scope、contract、ownership、user-visible behavior に関わる判断だけここで扱う。
- 判断に迷う Minor / Info は、直す理由または直さない理由を report に書く。

## Lead Handling

- worker の相談に対して、fix / accept risk / split task を決める。
- 統合判断は `make integrate` と `.agents/docs/TEAM_PROTOCOL.md` の Integration gate で行う。
- review result だけで統合せず、worker report、state、verification evidence も見る。

## Decision

- `needs-fix`
- `needs-lead-decision`
- `ready-to-integrate`
- `split-task`
