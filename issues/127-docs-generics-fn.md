# 127 — Map: generics are `$fn`, not `[T]` in the compiler

**Status:** ✅ done
**Depends on:** [116](116-docs-reorg.md), [026](026-preprocessor.md),
[034](034-generic-types.md)

## Problem

`04-macros.md` opened with “Generics are **not** in the language
grammar.” Readers (and agents) parsed that as “Klin has no generics.”
D3 is the opposite: `$fn` **is** the generic. It expands to ordinary
`fn` / `struct` before parse. The checker never sees `T`.
[034](034-generic-types.md) is optional `fn id[T]` sugar later — not a
hole.

## Done

- [x] [docs/04-macros.md](../docs/04-macros.md) — title + pipeline + why
- [x] [docs/README.md](../docs/README.md) — map row + sentence
- [x] [docs/guide.md](../docs/guide.md) — What next
- [x] [docs/01-decisions.md](../docs/01-decisions.md) D3
- [x] [docs/00-idea.md](../docs/00-idea.md) — “what you get” + Nelua take
- [x] [docs/16-slice.md](../docs/16-slice.md) / [14-allocator.md](../docs/14-allocator.md)
- [x] [034](034-generic-types.md) / [026](026-preprocessor.md) point at the page
- [x] [examples/README.md](../examples/README.md), [stdlib/README.md](../stdlib/README.md)

## Out of scope

- Implementing `[T]` in the compiler (034 stays 💭)
- Changing `$fn` expand or stdlib names
- Landing README feature dump
