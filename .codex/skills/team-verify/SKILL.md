---
name: team-verify
description: Use by any agent immediately before saying work is done, fixed, passing, ready to integrate, or ready to report, to collect fresh verification evidence.
---

# team-verify

完了主張は、直近の検証 evidence の後にだけ行う。

## Gate

1. 主張を証明する command / inspection を特定する。
2. 直近で実行する。
3. exit code と output を読む。
4. acceptance と照合する。
5. 成功、失敗、未実行、未検証範囲を report に書く。

## Not Enough

- lint だけで build 成功を主張する。
- unit test だけで integration contract を満たしたことにする。
- worker の `done` 報告だけで統合可能と判断する。
- 古い結果を現在の evidence として扱う。

## Use Before

- worker report
- lead `integrate` 判断
- lead の完了報告
