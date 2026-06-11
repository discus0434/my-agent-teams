---
name: team-memory
description: Use by a lead agent when .agents/queue/memory_proposals contains proposals that may be integrated into .agents/docs/MEMORY.md.
---

# team-memory

## Inputs

- `.agents/docs/MEMORY.md`
- `.agents/queue/memory_proposals/*.md`
- proposal の source task / report

## Accept

- 次回以降の作業で再利用できる。
- 1 entry 1 lesson。
- source task / report / commit を追える。
- 既存 entry と重複しない。
- 秘密情報、raw log、未検証の推測を含まない。

## Process

```bash
./scripts/team_memory_update.sh list
```

1. proposal を読む。
2. `.agents/docs/MEMORY.md` を検索して重複や supersede 対象を確認する。
3. 採択する内容だけを整形して統合する。
4. 必要なら proposal file に対応済みであることを report に残す。

```bash
./scripts/team_memory_update.sh append <proposal_file>
```
