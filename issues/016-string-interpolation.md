# 016 — Interpolated strings

**Status:** ✅ done (print sinks); buffer sink → [156](156-fmt-write.md)  
**Depends on:** 012 (`str` / `io`)

## Decisions

- Dart/V syntax in plain `"…"`: `$name`, `${expr}`, `${expr:format}`
- Format: **printf** (`%d`, `%.2f`) + mask sugar (`0.00` → `%.Nf`, `0.###` →
  trim helper), `sN` → `%.Ns`, `hex` / `sci`
- Emission: `printf` for print sinks (zero hidden allocation); `0.###` → stack
  buffer + `klin_fmt_trim_frac`
- **Print sinks:** `puts` / `printf` / `io.print` / `io.println`
- **Buffer sink:** `fmt.write(buf[:], "…")` → `snprintf` ([156](156-fmt-write.md))
- No `let s = "a $b"` without an explicit buffer / allocator
- No `n3` / locale; dates → [037](037-datetime-format.md)

Runtime mustache substitution (pattern-as-data, `{0}` / `{key}`) → separately
[077](077-string-template.md).

Details: [docs/07-interpolation.md](../docs/07-interpolation.md).
Golden: `test/interp.kl`, `test/fmt_write.kl`. Demo: `examples/interp.kl`,
`examples/fmt_write.kl`.
