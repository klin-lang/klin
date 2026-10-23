# What is the language

The `.kl` contract. For agents and humans who are about to add
grammar. Not a tutorial ([guide.md](guide.md)) and not a roadmap
([issues/sorted.md](../issues/sorted.md)).

**If it is not on this page, it is a library, a tool, or not Klin.**
Do not open a PR that adds syntax because an issue is 💭 or because
another language has the feature.

## The test

> No hidden allocation, no hidden control flow, no hidden cost.
> If it does not disappear in C emission, it probably does not belong.

Klin vs the same thing written by hand in C — `objdump -d` should
match. Details: [00-idea.md](00-idea.md), [01-decisions.md](01-decisions.md).

## In the language

These compile. They are not “missing.”

| Surface | Notes |
|---|---|
| Integers / `float` / `bool` / `str` | `int` → `i32`, `float` → `f64`. An integer literal coerced to a declared integer type must fit that type (`const X: u8 = 300` is an error; hex, `'A'`, and a negative value too). `cast` still truncates. Unary `-` / `~` on a literal take that type (`let x: i64 = -1`, `const M: u32 = ~0`); the range check is on the result. Integer constant expressions (`+ - * / % << >> & | ^`, other integer `const`s) fold in a `const`, an `[N]T` length, and any other expected integer type (`let x: u8 = 1 + 2`; `let x: u8 = 200 + 100` is out of range). A variable stays runtime |
| `b"..."` | `[]u8` — bytes of the text and `.len` (an embedded `\0` counts); same escapes as `"..."`; no interpolation ([syntax.md](syntax.md)) |
| `[N]T`, `[]T`, `*T` / `*mut T` | slices are `{ptr, len}`; no hidden cap grow. `N` is an integer constant expression (a literal, an integer `const`, `[N * 2]T`, `[1 + 2]T`). An array literal takes the element type from the expected array (`let a: [2]u8 = [1, 2]`, also a struct field and a parameter) and range-checks each element; an element constant expression folds in that type (`let a: [1]u8 = [1 + 2]`). Without a type it is `[N]i32`. An empty literal `[]` is `[0]T` when the expected array has length 0 (`let a: [0]u8 = []`, an argument, a field); without that array type it is an error. A function may return `[N]T`: C gets a struct with one array field, no allocation (D13). A literal in `return` takes the element type from the declaration. A zero-length array cannot be returned. `&` of a place reached through `*mut` is `*mut`. `&s[i]` is `*mut T` when the slice place is mutable (`let mut`, or `&xs[:][i]` on a `let mut` array) and `*T` through an immutable place. Assigning `s[i]` through an immutable slice (a binding or a parameter) is an error; `let mut s` can write |
| `struct`, `enum`, `fn`, methods, `Type.fn` | a mutating method accepts any mutable place, including one reached through `*mut` ([syntax.md](syntax.md)) |
| `const Name: Type = …` | module-level immutable; integer, `bool`, or `b"..."`; an integer initializer is a constant expression (other `const`s, `+ - * / % << >> & | ^`, unary `-` / `~`) and a valid `[N]T` length; no mutable globals ([syntax.md](syntax.md)) |
| `let` / `let mut` / `:=` | immutability by default |
| `if` / `while` / `for` / `return` / `break` / `continue` | [guide.md](guide.md) |
| `match` / `pick` | no fallthrough; `pick` → C `?:` |
| `defer` | jump to cleanup |
| `!T`, `or { }`, `!`, `error(n)` | D2 — value (`match` arm or `fn` return); not `Result[T,E]` |
| `$fn` … `$name(args)` | **this is the generic** ([04-macros.md](04-macros.md)) |
| `module` / `import` / `pub` | [12-modules.md](12-modules.md) |
| `fn(T…): Ret` | function pointer; **no capture** |
| `async fn` / `.await` | desugar over an **explicit** executor |
| `asm("…")` | → `asm volatile("…");` — not an assembler |
| `@[cimport]` / `@[cexport]` / `@[link]` / `@[isr]` / `codename` | FFI and vectors; no `c("…")` |
| `&&` `\|\|` / bitwise | `or` stays error-handling |
| `"$x"` / `${expr}` | interpolation → print sinks **or** `fmt.write(buf[:], …)` ([156](../issues/156-fmt-write.md)) |
| destructuring, enum as `[N]T` index | [syntax.md](syntax.md) |
| ZII | no constructors / destructors |

## Libraries — not the language

A package is not a keyword. Do not fold these into the compiler.

| Thing | Where |
|---|---|
| Event loop | [`eventloop`](https://github.com/klin-lang/eventloop) — `async` / `.await` are sugar over it |
| FreeRTOS | C kernel + [`klin_freertos`](https://github.com/klin-lang/klin_freertos) |
| Pins / PWM / UART | `machine_*` / board packs (`klin init`) |
| Host helpers | `stdlib/` (`io`, `mem`, `time`, `str`, `math`, `slice`) |
| JSON / SQLite / HTTP | `@[cimport]` a C library if you need one |

## Not missing — do not propose

These look like holes. They are decisions.

| Proposal | Reality |
|---|---|
| `[T]`, `Vec[T]`, `fn id[T]`, `Result[T,E]` | Generics **are** `$fn`. `!T` exists. [034](../issues/034-generic-types.md) is optional sugar later, not a gap. |
| `map[K]V` / hash map | ❌ struck — grow on insert is a hidden resize ([060](../issues/060-map-kv.md)). Use `table[Enum.x]` or owned bsearch. |
| Closures that capture | Not now (D7). Hidden alloc of the environment. Use `fn` pointer + explicit context. |
| Mutable globals / module-level `let` | `const` is immutable (D11). A local stays `let`. |
| JSON / SQLite | ❌ not doing ([125](../issues/125-drop-host-json-sqlite.md)) |
| Exceptions, GC, borrow checker, autofree | Rejected (D1 / D2 / idea) |
| `c("…")`, parse C headers | FFI declarations only ([09-ffi-c.md](09-ffi-c.md)) |
| `? :` | `pick` ([18-pick.md](18-pick.md)) |
| Parser generator | Hand-written recursive descent ([02-architecture.md](02-architecture.md)) |

`issues/` being 💭 does not mean “please implement.” It often means
**not now** or **struck**.

## 1.0

1.0 freezes this contract, not “finish `sorted.md`.” A 💭 issue is
not a license to invent `[T]` or `map`.
