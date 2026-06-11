---
name: team-brainstorm
description: Use by a lead agent when the user request is ambiguous, broad, creative, or has multiple viable approaches, before deciding whether to work directly or dispatch workers.
---

# team-brainstorm

## Trigger

- 目的、制約、成功条件、責務境界、検証方法がまだ曖昧。
- 実装方針が複数あり、先に選択肢を整理した方がよい。
- すぐ task 化または直接実装すると推測で進めそう。

## Process

1. repo 状態、docs、関連 script / skill を軽く確認する。
2. 目的をユーザー可視の成果とシステム上の状態に分ける。
3. 契約上重要な不明点だけ質問する。
4. 必要なら 2-3 案の trade-off と推奨案を出す。
5. ownership、検証方法、リスク、依存順序を洗い出す。
6. 小さい変更なら lead が直接行う。
7. worker に渡す価値があるなら、仮定を明示して `team-plan` へ進む。

## Output

- 目的
- 成功条件
- 制約
- 想定 task
- lead direct work で足りるか
- ユーザー判断が必要な点
- 先に調査すべき file / command
