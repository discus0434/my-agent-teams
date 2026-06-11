---
name: team-bootstrap
description: Use by a lead agent when initializing a new project from this template, before direct implementation or worker dispatch, to decide the product shape and language stack with the user and configure packaging, format, lint, test, and make post-change.
---

# team-bootstrap

## Inspect

- `AGENTS.md`
- `Makefile`
- `docs/TEAM_PROTOCOL.md`
- existing project files: `pyproject.toml`, `package.json`, `pnpm-workspace.yaml`, `src/`, `tests/`

## Ask

Ask only blocking questions.

- 何を構築するか。
- primary language/runtime: Python, TypeScript, both, or another explicit stack。
- deliverable: library, CLI, service, app, package, or script。
- package name, public entrypoints, and first user-visible behavior。
- `make post-change` で必ず検証したい contract。

既存 repo や user request から分かることは質問しない。

## Contract

- `make post-change` は worker が code change 後に実行する 1 command。
- `make post-change` は format、lint、必要な package/build check、test、`git diff --check -- .` を含める。
- 既存の repo-level checks がある場合は `post-change` に残す。
- `make smoke` は runtime smoke または agent-team smoke に使う。language checks だけを `smoke` に置かない。
- 選ばなかった言語や未使用 scaffold は残さない。
- `AGENTS.md` には選んだ stack の command だけを書く。
- 必要な package manager lockfile を作る。
- 必須 tool が無い場合は失敗させる。silent fallback を作らない。

## Python

Use:

- `uv`
- `ruff`
- `pytest`
- `pyproject.toml`
- `src/<package_name>/`
- `tests/`

`pyproject.toml`:

- `[project]` に name, version, description, requires-python。
- test/dev dependency group に `pytest` と `ruff`。
- library/package なら `hatchling` などの build backend を設定する。
- ruff config は `tool.ruff` と `tool.ruff.lint` に置く。

`make post-change` path:

```make
PY_PACKAGE_DIRS := .

post-change: post-change-py
	@git diff --check -- .

post-change-py:
	@set -e; \
	for dir in $(PY_PACKAGE_DIRS); do \
		echo "==> $$dir"; \
		(cd $$dir && uv run ruff format .); \
		(cd $$dir && uv run ruff check . --fix); \
		(cd $$dir && uv run --group test pytest -q); \
	done
```

For a package build contract, add `uv build` to `post-change-py`.

## TypeScript

Use:

- `pnpm`
- `typescript`
- `biome`
- `vitest`
- `package.json`
- `tsconfig.json`
- `src/`
- `tests/`

`package.json` scripts:

- `format`: `biome format --write .`
- `lint`: `biome check .`
- `typecheck`: `tsc --noEmit`
- `test`: `vitest`
- `build`: project-specific package/app build when needed

`make post-change` path:

```make
PNPM ?= pnpm
TS_PACKAGE_DIRS := .

post-change: post-change-ts
	@git diff --check -- .

post-change-ts:
	@set -e; \
	for dir in $(TS_PACKAGE_DIRS); do \
		echo "==> $$dir"; \
		(cd $$dir && $(PNPM) -s format); \
		(cd $$dir && $(PNPM) -s lint); \
		(cd $$dir && $(PNPM) -s typecheck); \
		(cd $$dir && $(PNPM) -s test -- --run); \
	done
```

For a package/app build contract, add `$(PNPM) -s build` to `post-change-ts`.

## Other Stack

- package manager、formatter、linter、test runner、package/build command を明示する。
- `make post-change` に全 check を入れる。
- 必須 command が無い場合は失敗させる。

## Multi-package

- Use explicit package dir variables such as `PY_PACKAGE_DIRS` and `TS_PACKAGE_DIRS`.
- For multiple stacks, define `post-change` once and depend on each selected subtarget.
- If selective execution is worth it, add one explicit changed-file selector script and call it from `post-change-*`.
- Do not autodetect package dirs at runtime.

```make
post-change: post-change-py post-change-ts
	@bash -n scripts/*.sh
	@git diff --check -- .
```

## Finish

- Run `make post-change`.
- Run `make smoke`.
- package/app build が成果物に必要なら、build command が `make post-change` に含まれていることを確認する。
- Update `AGENTS.md` and `README.md` with actual commands only.
- Delete `.codex/skills/team-bootstrap/` after bootstrap is complete.
- Dispatch implementation tasks only after the bootstrap checks pass.
