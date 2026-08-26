# 152 — C-`for` post: `+=` / `-=`

**Status:** ✅ done
**Depends on:** 003, 151

## Description

Allow compound assignment in the C-style `for` post clause:

```
for i := 0; i < n; i += 1 { … }
for i := n; i > 0; i -= 1 { … }
```

Plain `i = i + 1` remains valid. Only `+=` and `-=` in post (not
`*=` / `/=` / …) — the common loop-counter forms.

Semantics match statement-level compound assign (issue 078).
`klin fmt` preserves the operator.

## Completion criteria

- [x] parser accepts `ident ("=" | "+=" | "-=") expr` in post
- [x] checker / emit / fmt
- [x] golden + fmt tests; docs (`guide`, issue entry)
