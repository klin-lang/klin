# 079 — Associated (static) functions on types (`Type.func`)

**Status:** ✅ done (enum + struct, current module)
**Depends on:** 005 (methods with receiver), 072 (enums)
**User page:** [docs/syntax.md](../docs/syntax.md)

## Goal

Functions “on a type" without instance receiver — declared with type qualification,
called as `Type.func(args)`. Constructors / parsers / factories:
opposite of instance method (`fn (c: Color) name(): str` ↔
`fn Color.from_name(s: str): !Color`). Disappear in emission (plain C function
`Type_func(...)`, no hidden receiver) — zero hidden cost.

## Syntax

```klin
fn Color.from_name(s: str): !Color { … }   // declaration (mirror of call)
let c = Color.from_name("red") or { Color.Blue }

fn Point.new(x, y: i32): Point { return Point{ x: x, y: y } }
let p = Point.new(3, 4)
```

- Declaration: `fn Type.name(params): Ret { … }` — first identifier after `fn`
  with a dot is the type under which the function lives in the namespace. No receiver.
- Call: `Type.name(args)` — checker recognizes `Type` as type name
  (not variable), and routes to associated function.
- Works for **enums and structs**. Separate namespace from instance
  methods and enum constants (`Color.Red` without `()` is still a constant).

## How others do it

- Rust: `impl T { fn from_str(…) -> T }` → `T::from_str(…)`.
- Zig: type as namespace — `T.fromName(…)` (closest to this approach).
- Swift/Kotlin/Java/C#: `static` / `companion` / failable `init?`.
- Go/C: no feature — free function convention (`NewT` / `t_from_name`).

Klin: Zig/Rust‑like variant with emission to plain C function.

## Out of scope (deliberately)

- Auto-generated `values()` / `valueOf` / `to_string` (requires string arrays /
  reflection → hidden cost). Write explicitly (`from_name` + `strcmp`).
- `mod.Type.func` (cross-module) — current module for now.
- Associated `@[cimport]`/`@[cexport]`, using `Type.func` as function pointer.
- Name overloading (Klin has no overloading).

## Done

- Parser: `fn Type.name(...)` (`FuncDecl.associatedType`).
- Checker: registration in `_assocFuncs` under `Type.func`; recognition of
  `Type.func(...)` call (receiver = type name, not variable); arity/types; mangling.
- Emission: header without receiver, call without receiver argument,
  mangling `Type_func` (consistent with methods).
- Fmt: prints `fn Type.func(...)`.

Example: `examples/associated_fn.kl`. Golden: `test/assoc_fn.kl`.
