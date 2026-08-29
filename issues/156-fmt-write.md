# 156 — `fmt.write`: interpolation into a caller buffer

**Status:** ✅  
**Depends on:** [016](016-string-interpolation.md), [012](012-stdlib-io.md), [007](007-pointers-arrays-slices.md)

## Verdict

Print-only interpolation ([016](016-string-interpolation.md)) is not enough for
LCD / UART / CDC payloads. Add **`fmt.write(buf[:], "… $x")`** — same `$` /
`${…}` slots as print sinks, but the sink is a caller-owned `[]u8`.

No hidden heap. Emission is `snprintf` into `buf` (libc / newlib-nano).

## API

```klin
import fmt

fn main() {
    let mut buf: [64]u8
    let n = fmt.write(buf[:], "x: $x")
    // n = bytes written (no trailing NUL in the count), or -1 on error/truncation
    printf("%s\n", &buf[0])
}
```

| Piece | Rule |
|---|---|
| First arg | `[]u8` (mutable buffer) |
| Second arg | interpolated string **or** plain `str` |
| Return | `i32` — length excluding NUL, or `-1` |
| Formats | Same as 016 (`%d`, `0.00`, `hex`, `sN`, …) |
| Newline | Never appended (unlike `puts` / `io.println`) |

Plain `str`:

```klin
let n = fmt.write(buf[:], "hello")
```

## Not in this step

- `let s = "x: $x"` / returning `str` without a buffer ([077](077-string-template.md) / explicit `Allocator`)
- `fmt.string(…)` alias
- Changing print sinks

## Links

- Docs: [07-interpolation.md](../docs/07-interpolation.md), [stdlib/README.md](../stdlib/README.md)
- Stdlib: [`stdlib/fmt.kl`](../stdlib/fmt.kl)
- Tests: `test/fmt_write.kl`, golden pipeline
- Demo: `examples/fmt_write.kl`
