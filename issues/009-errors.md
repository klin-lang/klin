# 009 — Errors as values

**Status:** ✅ done
**Depends on:** 008

## Scope

```
pub fn load(path: string): !Config {
    let f = os.open(path)!
    defer f.close()
    return parse(f)!
}

let cfg = load("app.toml") or {
    log.warn("brak configu")
    Config.defaults()
}
```

- `!T` as sum type → struct with tag in C
- propagation operator → `if (r.is_err) return r;`
- `or { }` block with access to `err`
- no `null`: `?T` as option

## Completion criteria

- [x] propagation through 3 call levels
- [x] `or` with default value
- [x] compile error on ignoring `!T`
- [x] objdump: overhead = flag check, nothing more
- [x] `error(n)` as a `!T` **value** + `match { } or { }` —
  [132](132-match-else-or.md) ✅
