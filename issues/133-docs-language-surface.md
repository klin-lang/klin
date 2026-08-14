# 133 — Page: what is the language

**Status:** ✅ done
**Depends on:** [116](116-docs-reorg.md), [127](127-docs-generics-fn.md),
[125](125-drop-host-json-sqlite.md)

Filed as 131, then 132; renumbered because `main` already has
[131-linux-install](131-linux-install-docs.md) and
[132-match-else-or](132-match-else-or.md).

## Problem

Agents (and readers) treat `issues/` as a shopping list. They come
back with “Klin has no generics,” `fn id[T]`, `map[K]V`, `Result[T,E]`,
or a JSON stdlib. Those are decisions, not holes. `$fn` **is** the
generic ([127](127-docs-generics-fn.md)). Map is struck
([125](125-drop-host-json-sqlite.md)).

There was no one page that says: this is the `.kl` contract; everything
else is a library, a tool, or not Klin.

## Done

- [x] [`docs/language.md`](../docs/language.md) — surface + “do not propose”
- [x] Map, landing, idea, guide What next, `CLAUDE.md` / `AGENTS.md`

## Out of scope

- Implementing 034 / 132 / D7
- A formal language spec
- Dumping `sorted.md` into the page
