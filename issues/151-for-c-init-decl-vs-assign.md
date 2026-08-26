# 151 — C-`for` init: `:=` declares, `=` assigns

**Status:** ✅ done
**Depends on:** 003, 055

## Description

Align C-style `for` init with the rest of the language (and with V):

- `for x := k; …` — declare a **new** mutable loop variable
- `for x = k; …` — **assign** to an existing mutable `x` in scope
- empty init (`for ; …`) unchanged

If `x` is already visible, `for x := …` is a checker error (no shadowing).
Use `=` to assign, or choose another name.

`klin fmt` preserves which operator was written (`:=` vs `=`).

## Breaking

Older docs/examples treated `for i = 0` as introducing a new `i`.
That form is now assignment-only; write `for i := 0` to declare.

## Completion criteria

- [x] parser records `:=` vs `=` on `ForCStmt`
- [x] checker: declare + conflict / assign to existing mut
- [x] emit: `for (T i = …)` vs `for (i = …)`
- [x] fmt preserves operator; goldens + negative tests
- [x] docs (`guide`, `14-short-decl`) + entry in `sorted.md`
