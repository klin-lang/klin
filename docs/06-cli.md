# Klin CLI

Entry: `dart run bin/klin.dart <subcommand|file.kl> …`

## Meta

| Flag | Meaning |
|---|---|
| `--version` / `-v` | Print `klin <version>` (from `lib/version.dart` / `pubspec.yaml`) |
| `--help` / `-h` | Usage on stdout, exit 0 |
| *(no arguments)* | Same as `--help` |

## Subcommands

| Command | Meaning |
|---|---|
| `run <file.kl>` | Preprocess → parse → check → emit C → host `cc` → run |
| *(bare path)* | Alias for `run` — `klin examples/hello.kl` |
| `fmt [-w] <file.kl>` | Canonical printer (4 spaces, K&R). Without `-w` → stdout; with `-w` → write |
| `lsp` | Language Server over **stdio** (diagnostics, format, hover, definition, completion, rename, semantic tokens, cross-file; [086](../issues/086-lsp.md)) |
| `test [path…]` | Finds `*_test.kl`, runs `test_*` (like `go test`) |
| `init <board> [dir]` | Copy MCU board scaffold (`main.kl`, Makefile, `klin.mod`; Arm/RP: `board/{startup.s,linker.ld,…}`; ESP: ESP-IDF `main/` + `sdkconfig.defaults`; VW553: `board/{startup.S,linker.ld}`). Known: `nucleo-f411`, `pico`, `pico2`, `waveshare-rp2350-lcd-096`, `waveshare-esp32-s3-pico`, `gd32vw553h-eval`. Default `[dir]` = `./<board>`. Host `klin init` (no ld) is out of scope — [075](../issues/075-board-pack-init-host.md) |
| `get [path[@ref]…]` | Fetch remote package, device SVD (`.svd`), or board `.ioc` into cache; writes `klin.mod` (`require` / `device` / `board`) + `klin.lock` ([049](../issues/049-remote-imports.md), [053](../issues/053-device-board-assets.md), [074](../issues/074-board-ioc-klin-mod.md), [065](../issues/065-project-lockfile.md)). Never overwrites project-local `board/*.ioc` |
| `update [path[@ref]…]` | Force re-fetch (no args = all `require`/`device`/`board` from `klin.mod`); refreshes lock (cache only for `.ioc`) |
| `outdated [path…]` | Report: pin from mod vs latest tag/ref on host ([066](../issues/066-klin-upgrade-outdated.md); **network**) |
| `upgrade [path…]` | Bump outdated → latest + fetch ([066](../issues/066-klin-upgrade-outdated.md); **network**) |

`run` / `test` **do not** open network for remotes — cache only.
`get` with existing `klin.lock` prefers commit SHA (reproducible).
`update` ≠ `upgrade`: update keeps pin from mod; upgrade looks for a newer tag.

### `klin init` (MCU scaffold)

One-time copy from bundled `templates/<board>/` (not a network fetch). After
scaffold: `cd <dir> && klin get && make` (Arm/RP: `arm-none-eabi-gcc`; ESP:
`make emit` then `idf.py` with `IDF_PATH`; VW553: `riscv64-unknown-elf-gcc`).
Does **not** overwrite a non-empty
destination. Discovery (like stdlib): repo `templates/`, `$KLIN_TEMPLATES`, or
`templates/` / `share/klin/templates` next to the install.
Walkthrough (Pico, Nucleo, ESP, VW553 — not STM32-only):
[embedded.md](embedded.md). Design: [075](../issues/075-board-pack-init-host.md).

## Language Server (`klin lsp`)

Starts an LSP server on stdin/stdout (no args). Editors wire it as:

```json
"klin": {
  "command": ["klin", "lsp"]
}
```

Dev without install: `dart run bin/klin.dart lsp`.

MVP: full-document sync, publish diagnostics (check errors collected per
function; parse recovers at decl/stmt boundaries —
[092](../issues/092-lsp-parse-recovery.md)), formatting, hover / definition /
completion / rename / semantic tokens
([094](../issues/094-lsp-semantic-tokens.md)). Cross-file goto uses
`loadProject` with an overlay of open LSP buffers. After `$fn` / `$device`
expand (including SVD fluent rewrite),
[`SourceMap`](../lib/source_map.dart) remaps positions
([091](../issues/091-lsp-svd-sourcemaps.md)). Library files do not require
`main`. Syntax highlight for `.kl` is a separate TextMate pack —
[`editors/vscode/`](../editors/vscode/) ([093](../issues/093-syntax-highlight.md));
editors may stack TextMate with LSP semantic tokens. IntelliJ thin plugin:
[`editors/intellij/`](../editors/intellij/)
([087](../issues/087-intellij-plugin.md)).
Details: [086](../issues/086-lsp.md).

**Debug is not LSP.** For gdb / lldb on `.kl` via `#line`, see
[19-debug.md](19-debug.md) ([088](../issues/088-dap-debug.md)).

## Flags before / with `run`

| Flag | Meaning |
|---|---|
| `--emit-c` | Write generated `.c` (default `out/`), no compile / run |
| `--emit-h` | Write C header with `@[cexport]` prototypes (`out/<base>.h`) |
| `--emit-pp` | Write preprocessor output (`.pp.kl`), no further stages |
| `--cc <gcc\|clang\|tcc>` | Host C compiler (default `gcc`) |
| `-g` / `--debug` | Pass host `cc -g` (debug symbols; no Klin runtime) — [19-debug.md](19-debug.md) |
| `-O0`…`-O3` / `-Os` / `-Oz` / `--opt LEVEL` | Pass host `cc -O…` (optimization; LEVEL = `0`…`3`/`s`/`z`, also `O2` / `-O2`) |
| `-I <dir>` / `-Idir` | Search Klin sources (`import` → `name.kl`) in `dir` |
| `-l <name>` / `-lname` | Link `-lname` (like cc; C FFI) |
| `-L <dir>` / `-Ldir` | Search C libs in `dir` |

Klin paths (`lib/`, `-I`, `$KLIN_PATH`): [11-klin-libraries.md](11-klin-libraries.md).
Modules (`module` / `import` / `pub`): [12-modules.md](12-modules.md).
fmt details: [05-fmt.md](05-fmt.md). Macros / SVD: [04-macros.md](04-macros.md).
FFI (import `@[cimport]`/`@[link]` and export `@[cexport]`): [09-ffi-c.md](09-ffi-c.md).
ASM units / `asm("…")`: [10-asm.md](10-asm.md).
