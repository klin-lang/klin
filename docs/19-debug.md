# Debugging Klin (`#line`, gdb / lldb)

Klin emits readable C with `#line` directives so the host debugger can map
stops and stack frames back to `.kl` sources
([architecture Z2](02-architecture.md#z2-line-in-emission)). There is **no**
Klin VM and **no** debugger inside `klin lsp`.

Issue: [088](../issues/088-dap-debug.md).

## LSP ≠ debug

| Protocol | Role | Klin today |
|---|---|---|
| **LSP** ([086](../issues/086-lsp.md)) | Edit: diagnostics, format, hover, … | `klin lsp` |
| **gdb / lldb / OpenOCD** | Run, step, breakpoints | Emitted C + `#line`; host `cc -g` via `klin run -g` or manual `cc` |
| **DAP** | IDE debug adapter API | Not shipped (optional later; still wraps gdb) |

Editors may already attach **Native Debug** / gdb to a binary built with `-g`.
Wire that to the binary, not through the language server.

## Host recipe

### `klin run -g` (debug symbols)

`-g` / `--debug` forwards host `cc -g` when Klin compiles (no Klin VM, no
hidden runtime):

```sh
dart run bin/klin.dart run -g examples/hello.kl
# binary: out/hello  (then: gdb ./out/hello)
```

### Optimization (`-O` / `--opt`)

Host `cc -O…` is opt-in (default = whatever the C compiler uses without `-O`):

```sh
dart run bin/klin.dart run -O2 examples/hello.kl
dart run bin/klin.dart run --opt s examples/hello.kl   # → -Os
dart run bin/klin.dart run -g -O0 examples/hello.kl    # debug + no opt
```

Allowed levels: `0` `1` `2` `3` `s` `z` (forms `O2`, `-Os`, … also OK).

`--emit-c` alone still skips `cc`; use the manual recipe below if you only want
the `.c` file.

### Manual `emit-c` + `cc -g`

```sh
dart run bin/klin.dart --emit-c examples/hello.kl
# → out/hello.c

gcc -g -O0 out/hello.c -o out/hello
gdb ./out/hello
# or: lldb ./out/hello
```

Breakpoints and stepping should land on `.kl` lines when the toolchain honors
`#line` (typical with gcc/clang). Inspect generated C only if you need to see
the emission itself.

Flags: [06-cli.md](06-cli.md). Issue: [088](../issues/088-dap-debug.md).

## MCU / embedded

Same idea: Klin → `.c` → your cross `cc` with `-g` → OpenOCD / probe →
`arm-none-eabi-gdb` (or vendor tools). Point the debugger at the ELF and the
`.kl` tree; `#line` is what maps PC back to Klin. Board / linker details stay
in the embedded / board issues — this doc only states the debug mapping.

## IDE notes

- **VS Code / Cursor:** use a C/Native Debug launch config against the `-g`
  binary; TextMate highlight is separate ([093](../issues/093-syntax-highlight.md)).
- **IntelliJ:** thin plugin for edit via LSP4IJ
  ([087](../issues/087-intellij-plugin.md)); debug configs should attach gdb /
  Native Debug to the binary, not `klin lsp`.

## Non-goals (reminders)

- No Klin interpreter for stepping
- No DWARF emitter in the Klin frontend (the C compiler owns that)
- No DAP inside `klin lsp`
