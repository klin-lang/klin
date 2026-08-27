# Klin

> **Experimental 0.1.4** — real programs compile (host and several MCU
> families). The public packaging surface is still settling. Expect
> breaking changes before 1.0.

Klin is a systems language **wedged** between you and C. The compiler
checks Klin source and emits **one readable `.c` file**. `gcc`, `clang`,
`tcc`, or a vendor toolchain (`arm-none-eabi-gcc`, …) finish the build.

It does not replace C and does not hide it. If this project stops, the
last compile is still C you can keep shipping.

```klin
struct Vec2 {
    x: i32
    y: i32
}

fn (v: Vec2) len_sq(): i32 {
    return v.x * v.x + v.y * v.y
}

fn (mut v: Vec2) translate(dx: i32, dy: i32) {
    v.x = v.x + dx
    v.y = v.y + dy
}
```

`mut` is in the signature. In the `.c` it is only `*`.

## Why it exists

> **No hidden allocation, no hidden control flow, no hidden cost.**

If a line allocates or branches, the syntax shows it. The check is
practical: Klin vs the same thing written by hand in C — `objdump -d`
should match. C++ broke that with copy constructors, exceptions, and
operator overloading. Klin refuses to.

The C backend is the product, not a temporary IR:

| | Klin | C | Zig / Rust | Nelua |
|---|---|---|---|---|
| Artifact | one readable `.c` | you write C | LLVM / their toolchain | also C |
| If the compiler dies | **keep the `.c`** | you already have C | you need `zig` / `rustc` | keep the `.c` |
| Hidden cost | forbidden | none (and no structure) | `Drop`, panic, … | mostly honest |
| Reach | **any C compiler** | any | LLVM backends | any C compiler |
| Mutation | visible (`mut`) | n/a | `const` / borrow | implicit `self` pointer |

Klin is not “better Zig”. Zig and Rust are stronger languages with
modern backends. Klin’s bet is different: **must be C at the end** —
vendor `gcc`, an existing C tree, a chip LLVM will never see, or a
codebase that has to outlive its compiler.

Closest sibling: [Nelua](https://nelua.io) (Lua → C). Klin takes the
honest C-shaped FFI and adds `mut` in the signature, Go-like
`fmt` / `test` / modules, and SVD registers as a first-class path.

Founding notes: [docs/00-idea.md](docs/00-idea.md),
[docs/01-decisions.md](docs/01-decisions.md).
What is in the language: [docs/language.md](docs/language.md)
(`$fn` is the generic — not `[T]`).
Doc map: [docs/README.md](docs/README.md).

## Who it is for

**Systems code** — host tools and firmware — wherever a C compiler
already exists.

- **Host:** `klin run`, libc, packages (`klin get`)
- **MCU:** STM32, RP2040 / RP2350, ESP32, CH32V, GD32V, STM8, megaAVR,
  ATxmega, PIC16, … plus anything with a vendor `cc` (including parts
  LLVM will not target)

STM32 was the **first** freestanding demo (an LED, no libc). It is not
the only target. Walkthrough: [docs/embedded.md](docs/embedded.md)
(`klin init pico` / Nucleo / WeAct F411 / ESP / VW553). AVR / Arduino FAQ:
[docs/arduino.md](docs/arduino.md). Board trees:
[`templates/`](templates/), [`examples/stm32/`](examples/stm32/).
Typed registers from SVD: [docs/device.md](docs/device.md).

You get methods, modules, `!T` errors, immutability by default, and
typed MMIO from SVD — with no runtime and no GC.

## Quick start

**Homebrew** (prebuilt, no Dart; macOS / Linux):

```sh
brew install klin-lang/klin/klin
klin --version
klin run examples/hello.kl          # from a clone
```

**Linux tarball** (prebuilt, no Dart; **no apt / snap**):

```sh
curl -fsSL https://raw.githubusercontent.com/klin-lang/klin/main/scripts/install-linux.sh | bash
klin --version
```

Details (manual extract, Scoop, WinGet, CLT): [docs/17-homebrew.md](docs/17-homebrew.md).

**Windows** (Scoop or WinGet, prebuilt, no Dart):

```powershell
scoop bucket add klin https://github.com/klin-lang/scoop-klin
scoop install klin
# or, once published to microsoft/winget-pkgs:
# winget install klin-lang.klin
klin --version
```

**From source** (Dart SDK `^3.5` + a host C compiler):

```sh
git clone https://github.com/klin-lang/klin.git
cd klin
dart pub get
dart run bin/klin.dart run examples/hello.kl
```

```sh
klin --emit-c examples/vec2.kl      # just the .c
klin fmt -w examples/hello.kl
klin test examples/
```

CLI: [docs/06-cli.md](docs/06-cli.md). Debug (`#line`, `-g`):
[docs/19-debug.md](docs/19-debug.md).

## From hello to a board

Why Klin: [docs/00-idea.md](docs/00-idea.md). How, without opening
`issues/`:

1. [docs/guide.md](docs/guide.md) — write Klin (`hello` → `if` / `defer` → C)
2. [docs/device.md](docs/device.md) — typed register from SVD
3. [docs/embedded.md](docs/embedded.md) — `klin init` → `get` → `make`

Then [`examples/`](examples/README.md) and [`stdlib/`](stdlib/README.md).
This README is not a tutorial. Map: [docs/README.md](docs/README.md).

## Toolchain (short)

| Command | Role |
|---|---|
| `klin run <file.kl>` | Emit C, host `cc`, execute |
| `klin --emit-c` | Write `out/*.c` only |
| `klin fmt` / `klin test` | Format / run `*_test.kl` |
| `klin get` / `outdated` / `upgrade` | Remote packages (`klin.mod` / `klin.lock`) |
| `--emit-h` / `--emit-pp` | C header from `@[cexport]` / macro expand |

C FFI both ways: [docs/09-ffi-c.md](docs/09-ffi-c.md).
ASM units and `asm("…")`: [docs/10-asm.md](docs/10-asm.md).
Libraries: [docs/11-klin-libraries.md](docs/11-klin-libraries.md).

## License

The compiler and stdlib are **[MIT](LICENSE)**.

Code generated by the Klin compiler and standard library fragments
compiled into your program are not subject to any additional
restrictions — your program is yours.
See [docs/03-name-license.md](docs/03-name-license.md).

## Roadmap and contributing

Work order (what compiles): [`issues/sorted.md`](issues/sorted.md).
Compiler tests: `dart test`. Agent rules: [`CLAUDE.md`](CLAUDE.md).
