# Architecture and engineering rules

Compiler pipeline and day-one rules. Not an introduction — start with
[00-idea.md](00-idea.md) and [guide.md](guide.md).

## Pipeline

```
file.kl
  → lexer        (text → tokens, each with position)
  → parser       (tokens → AST, recursive descent)
  → checker      (symbol table, types, name resolution)
  → codegen      (AST → one .c file)
  → gcc/clang/tcc (.c → binary)
```

## Implementation language: Dart

Not because it is the best tool for writing compilers
(that is OCaml or Rust), but because it is the best **for me
for this project**. The project will die not on technical difficulty, but on
friction — when after a week away you have to remember
the syntax. Plus: configured IntelliJ, familiarity with the debugger,
`dart compile exe` gives a standalone binary.

Sealed classes + pattern matching from Dart 3 are exactly what
the AST needs:

```dart
sealed class Expr {}
final class IntLit extends Expr { final int value; IntLit(this.value); }
final class Binary extends Expr {
  final Expr left, right; final String op;
  Binary(this.left, this.op, this.right);
}
```

The compiler will force handling every variant in every `switch` —
that replaces half the tests.

Rewriting the frontend in OCaml/Rust is a decision for after step 5,
not now.

## Directory layout

```
bin/klin.dart      # CLI: argv → read → lex → parse → check → emit → cc → run
lib/token.dart
lib/lexer.dart
lib/ast.dart
lib/parser.dart
lib/checker.dart
lib/emit_c.dart
test/             # golden tests: .kl files + expected output
out/              # ALL generated output, ignored by git
docs/             # design + user docs (map: docs/README.md)
issues/           # roadmap (what compiles) — not a user manual
```

Split into files from day one, even though initially everything
would fit in one — in a month `parser.dart` will be 1500 lines
and you will not want to split it retroactively.

---

## Rules, from day one

### Z1. Golden tests

`test/` directory: a `.kl` file + expected program output. A script
compiles everything and compares. **Without this, after three weeks
nothing will change out of fear.**

Error tests matter more than success tests.

### Z2. `#line` in emission

From day one. Without it gdb shows generated C, not Klin
source. Adding it later = rewriting codegen.

Consequence: **the lexer must carry position (line, column) in every
token from the very start.** If it does, everything else works.
If not — you have to bolt it onto every structure separately.

### Z3. The frontend catches every error

If gcc screams at generated code, that is **my** bug, not
the user's. C is supposed to be just an assembler. The user should never
see a message about code they did not write.

### Z4. Hand-written recursive-descent parser

No parser generators. For a language whose syntax I design myself,
a hand-written parser is faster to write and gives incomparably better
error messages.

### Z5. Declaration order

In Klin order in a file does not matter. In C it does. Codegen must
topologically sort types and emit forward declarations.

### Z6. tcc during iteration

`tcc` starts in milliseconds. gcc/clang only for release
and measurements. Flag `--cc`.

---

## Sections in generated C

After Nelua — four sections, otherwise order breaks:

1. **directives** — `#include`, `#define`
2. **declarations** — types, function prototypes, variables
3. **definitions** — function bodies
4. **inside functions** — local code

---

## Bare metal (from step 10)

- `-ffreestanding`, no libc: no `printf`, `malloc`, `string`
- no GC — for us that is the default anyway, not a flag
- ASM startup stays raw `.s` alongside — vector table, reset
  handler, copying `.data`, zeroing `.bss`. **Do not wrap it.**
- linker script on the user side
- `-Os`, `-ffunction-sections -fdata-sections`, `--gc-sections`
  — otherwise dead code from SVD will blow up the binary

**Do not parse CMSIS headers.** They are built from macros and bitfields
that no simple parser can chew. Signatures written by hand
as FFI declarations.
