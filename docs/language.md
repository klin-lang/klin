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
| Integers / `float` / `bool` / `str` | `int` → `i32`, `float` → `f64`. An integer literal coerced to a declared integer type must fit that type (`const X: u8 = 300` is an error; hex, `'A'`, and a negative value too). `cast` still truncates. Unary `-` / `~` on a literal take that type (`let x: i64 = -1`, `const M: u32 = ~0`); the range check is on the result. Integer constant expressions (`+ - * / % << >> & | ^`, other integer `const`s) fold in a `const`, an `[N]T` length, and any other expected integer type (`let x: u8 = 1 + 2`; `let x: u8 = 200 + 100` is out of range). A variable stays runtime. `puts` takes one `str`; `printf`'s format must be `str` (`puts(b"hi")` is an error — `b"..."` is `[]u8`, not `const char*`). Later `printf` arguments with no type fold as `i32` (`printf("%d\n", 1 + 2)`). `str` is `const char*`. `s.len` is `strlen` as `i32` (each use walks the bytes), `s[i]` is a read-only `u8`, and `cstr_u8(s)` is a read-only `[]u8` (D22). No subslice and no write |
| `b"..."` | `[]u8` — bytes of the text and `.len` (an embedded `\0` counts); same escapes as `"..."`; no interpolation. The bytes are read-only. A `let mut` binding may hold them and can be reseated; `s[i] = …` while it points at those bytes is an error (copy into `[N]u8` to modify), including a subslice (`b"ab"[0:1]`, `[0:]`, `[:1]`). An immutable module `let kw: []u8 = b"..."` follows the same rule. A module `let mut` of those bytes is storage and a write may crash (D11). A `[]u8` parameter, a return, and a struct field are not tracked ([syntax.md](syntax.md)) |
| `[N]T`, `[]T`, `*T` / `*mut T` | slices are `{ptr, len}` for a primitive, struct, enum, `str`, pointer, slice, function, or array (not an array of structs, not `!T`); no hidden cap grow. `xs[:]` on `[N]Token` is `[]Token`. `N` is an integer constant expression (a literal, an integer `const`, `[N * 2]T`, `[1 + 2]T`). An array literal takes the element type from the expected array (`let a: [2]u8 = [1, 2]`, also a struct field and a parameter) and range-checks each element; an element constant expression folds in that type (`let a: [1]u8 = [1 + 2]`). Without a type it is `[N]i32`. An empty literal `[]` is `[0]T` when the expected array has length 0 (`let a: [0]u8 = []`, an argument, a field); without that array type it is an error. A function may return `[N]T`: C gets a struct with one array field, no allocation (D13). A literal in `return` takes the element type from the declaration. A zero-length array cannot be returned, and `pick` / `match` cannot produce one. Destructuring a call, `pick`, or `match` of `[N]T` evaluates that value once (`let [x, y] = pair()`). `&` of a place reached through `*mut` is `*mut`. `&s[i]` is `*mut T` when the slice place is mutable (`let mut`, or `&xs[:][i]` on a `let mut` array) and `*T` through an immutable place. Assigning `s[i]` through an immutable slice (a binding or a parameter) is an error; `let mut s` can write. `xs[a:b]`, `xs[a:]`, and `xs[:b]` are a subslice (no runtime bounds check, same as an index); mutability follows the source place (D15). `(*p)[:]`, `(*p)[a:b]`, `(*p)[a:]`, and `(*p)[:b]` on `*mut [N]T` or `*[N]T` are `[]T` (D19); `(*p)[i]` indexes that array. `*mut` is a mutable place and `*` is immutable. `let mut s = (*p)[:]` can write. No runtime bounds check on a runtime index. A constant integer index of `[N]T` that is negative or `>= N` is a compile-time error (D23). A subslice of read-only bytes is a header that can be reseated; the bytes still cannot be written (D10) |
| `struct`, `enum`, `fn`, methods, `Type.fn` | a mutating method accepts any mutable place, including one reached through `*mut`. A by-value struct cycle (`A` holds `B` holds `A`) is an error (infinite size; store one behind a pointer). An array that needs the same struct complete (`kids: *mut [N]Node`) is a different error. Duplicate enum variant names are an error, and so are two variants with the same numeric value, written or implied (D25). ([syntax.md](syntax.md)) |
| `const Name: Type = …` | module-level compile-time value; integer, `bool`, or `b"..."`; an integer initializer is a constant expression (other `const`s, `+ - * / % << >> & | ^`, unary `-` / `~`) and a valid `[N]T` length ([syntax.md](syntax.md)) |
| `let` / `let mut` at module scope | storage with an address. `let` is not assignable (`&` is `*T`); `let mut` is (`&` is `*mut T`). `pub let mut` may be assigned from another module. Initializer is a constant expression, or omitted (zero). Not an `[N]T` length. No implicit synchronization ([syntax.md](syntax.md), D11) |
| `let` / `let mut` / `:=` | immutability by default; `:=` is local only. `let _ = expr` (and `let { a: _, b: _ }`) evaluates and discards; `_` may be repeated in one scope and is not a variable |
| `if` / `while` / `for` / `return` / `break` / `continue` | [guide.md](guide.md) |
| `match` / `pick` | no fallthrough; `pick` → C `?:`. Untyped arms adopt the expected type (`let x: u8 = match k { 0 { 1 + 2 } else { 4 } }`) and are range-checked; with no type they are `i32`. Two unguarded arms that match the same constant values are an error (D24); a `when` guard and overlapping but different patterns stay |
| `defer` | jump to cleanup |
| `!T`, `or { }`, `!`, `error(n)` | D2 — value (`match` arm or `fn` return); not `Result[T,E]`. `f()!` is also a statement: it propagates and discards the success value. The enclosing function must return `!T`. An `or` block may end with a value or diverge (`return`, `break`, `continue`) (D21) |
| `$fn` … `$name(args)` | **this is the generic** ([04-macros.md](04-macros.md)). A plain free function in the body is renamed per expansion (D20) |
| `module` / `import` / `pub` | [12-modules.md](12-modules.md) |
| `fn(T…): Ret` | function pointer; **no capture** |
| `async fn` / `.await` | desugar over an **explicit** executor. The body can index a `[N]T` or `[]T`. An array literal or an array parameter is copied element by element (a C array cannot be assigned) |
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
