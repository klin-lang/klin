# Klin — overall idea

## What it is

Klin is a systems language compiled **to C**, not to machine code.
The compiler emits one readable `.c` file. An ordinary C compiler
(`gcc`, `clang`, `tcc`, `arm-none-eabi-gcc`, a vendor PIC toolchain)
turns that file into a binary.

The name is not accidental: a wedge (klin) is the oldest simple machine —
zero moving parts, zero overhead. The language is a thin layer **wedged**
between the programmer and C. It does not replace C, does not hide it,
and does not pretend it is not there.

## Overarching principle

> **No hidden allocation, no hidden control flow,
> no hidden cost. If something allocates or branches, it must be
> visible in the syntax.**

That sentence settles every design dispute. Practical test for every
proposed feature:

> Compile the same thing twice — once in Klin, once by hand in C — and compare
> `objdump -d`. If the instructions are identical, the feature passes.
> If not, drop it or fix it.

C++ broke this rule three times: copy constructors, exceptions,
operator overloading. Each makes an innocent line do something expensive.
Klin must not repeat that.

A second test, for the frontend: **if a feature does not disappear in C
emission, it probably violates the principle.** `mut` becomes `*`.
`defer` becomes a jump to cleanup. `!T` becomes a tagged struct.
Nothing runs at runtime that the source did not say.

## Who it is for

Klin is a **systems** language. The first program that proved the
pipeline was an LED on STM32 — that is the hard case (no libc, no
runtime, vendor `gcc`). It is not the identity of the language.

The same source model runs:

- on the **host** (`klin run`, ordinary libc, packages)
- on **any MCU that already has a C compiler** — STM32, RP2040 / RP2350,
  ESP32, CH32V, GD32V, and older parts (PIC, 8051) that LLVM will never
  grow a backend for

What you get that C does not:

- structures with methods instead of `module_function()` prefixes
- modules and `pub` instead of `static` and opaque pointers
- no `null`; errors as values (`!T` + `or { }`)
- immutability by default; mutation visible in the signature
- typed register access from SVD, where the chip has an SVD

What you keep from C:

- full control over memory
- zero runtime
- the generated `.c` is ordinary C you can read, debug, and keep

## Why a C backend, not LLVM

1. **Exit hatch.** If Klin stops — the compiler, the project, the
   author — the last successful compile is still a `.c` file a C
   programmer can maintain. That is the product, not an intermediate
   dump. Zig and Rust do not offer this: you need their toolchain
   forever.
2. **Reach.** Works on every target for which a C compiler exists,
   including vendor and archaic toolchains LLVM will not grow.
   That is a real niche Zig and Rust do not cover.
3. **Interop for free.** C headers, C libraries, C tools (`gdb`,
   `objdump`, Valgrind, vendor IDEs) work without a middle layer.
   Klin talks to C through explicit FFI, not by parsing headers.
4. **Implementation simplicity.** The C backend is the easy part.
   The difficulty sits in the frontend — which you would need anyway,
   even targeting LLVM.

## What Klin is NOT (non-goals)

- **Not a superset of C.** It does not parse legal C. Parsing full C
  (preprocessor, `typedef` vs identifier, the "lexer hack") is an order
  of magnitude harder than a clean grammar. Interop is FFI declarations,
  not header ingestion.
- **No GC.** Neither by default nor optionally at the start.
- **No borrow checker.** That is a research problem, not a matter of
  enthusiasm. Solo + Polonius = a project that never reaches 1.0.
- **No runtime.** No goroutines, no scheduler in the language.
- **No exceptions.** Hidden control flow.

## Neighbors

Klin is not "better than Zig" and does not claim to be. It makes a
**different bet**: the artifact is C you can take away.

| | Backend | If the compiler dies | Hidden cost | Typical reach |
|---|---|---|---|---|
| **C** | you write it | you already have C | none (and no structure) | everywhere |
| **C++** | native | — | ctors, exceptions, overload | everywhere |
| **Rust** | LLVM | you need `rustc` | `Drop`, panic paths | Cortex well; not PIC / 8051 |
| **Zig / Odin** | LLVM | you need their toolchain | mostly explicit | growing LLVM targets |
| **Nelua** | C | you keep the `.c` | mostly honest | any C compiler |
| **V** | C | you keep the `.c` | autofree (still WIP) | any C compiler |
| **Klin** | one readable `.c` | you keep the `.c` | forbidden by rule | any C compiler |

### What to take

| Source | Take |
|---|---|
| **V** | `mut` (immutability by default), `pub`, no `null`, `!T` + `or {}` |
| **Nelua** | preprocessor instead of generics in the core, `cimport` / `cexport` / `codename`, ZII |
| **Go** | `defer`, methods on structs without inheritance, `fmt` / `test` / modules |
| **Zig / Odin** | allocator as an explicit argument, not global magic |

### What Klin does differently from the closest sibling

**Nelua** is the nearest working compiler (Lua → C). Klin takes its
honesty about cost and its C-shaped FFI, then changes three things:

- **`mut` is in the signature.** Nelua `function Vec2:translate` gives
  `self: *Vec2` implicitly; the call site cannot tell. Klin
  `fn (mut v: Vec2)` is visible at both ends and disappears in emission.
- **The C is the exit hatch, on purpose.** Not "we compile to C because
  it was easy" — if this repo goes cold, the `.c` is the continuation.
- **Embedded registers are a first-class path** (SVD → fluent MMIO →
  `static inline`), not an afterthought. Host is still first-class;
  STM32 was only the first board that proved freestanding.

**Zig / Odin** do systems programming with more language and a modern
backend. Use them when you want that toolchain. Use Klin when the
constraint is "must be C at the end" — vendor `gcc`, an existing C
codebase, or a project that must outlive its compiler.

### What to deliberately NOT take

**Autofree from V.** V's flagship promise — the compiler inserts
`free()` at compile time, without GC and without a borrow checker. After
years it is still WIP, the docs discourage using it, and it can be
**slower than GC** (string cloning O(n) to avoid dangling pointers).
That is empirical proof that automatic memory management without GC
and without a type system tracking lifetimes is a research problem.

**Conclusion:** declare the memory model you can actually implement,
not the one that sounds best in the README.

## Decisions, architecture, how to write Klin

- Decisions (memory, errors, generics): [01-decisions.md](01-decisions.md)
- Compiler rules: [02-architecture.md](02-architecture.md)
- Short tutorial: [guide.md](guide.md)
- Doc map: [README.md](README.md)
