# String interpolation

Syntax like Dart/V in plain `"…"` (no `$"` prefix).

## Slots

| Form | Meaning |
|---|---|
| `$name` | simple name |
| `${expr}` | expression; default format from type |
| `${expr:%d}` | native `printf` specifier |
| `${x:0.00}` | mask → `%.2f` |
| `${x:0.###}` | optional places → `klin_fmt_trim_frac` + `%s` |
| `${s:s8}` | truncate → `%.8s` |
| `${n:hex}` / `${f:sci}` | aliases for `%x` / `%e` |
| `\$` | literal `$` |

## Sinks

| Sink | Effect |
|---|---|
| `puts` / `printf` / `io.print` / `io.println` | print (016) |
| `fmt.write(buf[:], "…")` | write into caller `[]u8` ([156](../issues/156-fmt-write.md)) |

`fmt.write` returns bytes written excluding the trailing NUL, or `-1` on
empty buffer / truncation / error. Same format slots as print. Needs libc
`snprintf` (newlib-nano is fine on embedded).

```klin
import fmt

fn main() {
    let mut buf: [64]u8
    let x = 7
    let n = fmt.write(buf[:], "x: $x")
    printf("%s\n", &buf[0])
}
```

**Not yet:** `let s = "a $b"` (would hide allocation). Heap form → later /
[077](../issues/077-string-template.md).

Alignment / padding: explicit printf (`%8s`, `%-8s`, `%08x`). Dates → [issue 037](../issues/037-datetime-format.md).

Examples: [`examples/interp.kl`](../examples/interp.kl),
[`examples/fmt_write.kl`](../examples/fmt_write.kl).
