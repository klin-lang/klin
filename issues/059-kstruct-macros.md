# 059 — Macros / codegen for richer `klinstruct` (`$kstruct`)

**Status:** 💭 under consideration (low priority — non-blocking)
**Depends on:** [026](026-preprocessor.md); [052](052-klinstruct.md); nice to have stronger `$fn` (export via `import`, better diagnostics); not [034](034-generic-types.md)

## Context

MVP [`klinstruct`](https://github.com/klin-lang/klinstruct) = `read_*` /
`write_*` atoms + `Cursor` (native endian; JS: `CStructLE`/`BE`). Frame schemas =
hand-written methods. [`@mrhiden/cstruct`](https://github.com/MrHIDEn/cstruct) has
richer declaration (model → `make`/`read`).

Goal: same ergonomics in Klin via **compile-time expand** (D3), without
runtime DSL and without hidden cost on MCU.

## UX goal

```klin
import "github/klin-lang/klinstruct" kstruct

$kstruct Telemetry {
  seq: u16
  temp_c: i16
}

fn main() {
  let mut buf: [4]u8
  let t = Telemetry{ seq: 10, temp_c: -10 }
  t.pack(buf[:])!
  let back = Telemetry.unpack(buf)!
}
```

Or builtin like SVD ([027](027-svd-ergonomic-api.md)):

```klin
$kstruct_from("protocol/telemetry.kspec")
```

Expand → `struct` + `pack`/`unpack` calling atoms. C emission monomorphic.

## What to write where (path forward)

### A. `klin` repo — language / preprocessor

| Step | Where | What |
|---|---|---|
| A1 | `lib/preprocess.dart` (+ tests) | Macros via path `import "…"` ✅ lite (block/`$mod`); ident imports still expand in-package |
| A2 | `lib/preprocess.dart`, `docs/04-macros.md` | “Field block” argument / list `(name, type)` or variadic |
| A3 | preprocess or builtin like `027` | Iterate fields in expand → `write_*` / `read_*` text |
| A4 | checker / preprocess | Diagnostics mapped to `$kstruct` call site |
| A5 | optional `lib/…` builtin | `$kstruct_from("….kspec")` — model file parser → same expand as A3 |
| A6 | [048](048-import-aliases.md) / [049](049-remote-imports.md) | `import "github/klin-lang/klinstruct" kstruct` |

**Not:** generics in grammar ([034](034-generic-types.md)), runtime reflection.

### B. `klinstruct` repo — library

| Step | Where | What |
|---|---|---|
| B0 | ✅ MVP | `klinstruct/atoms*.kl`, `atoms_host.c`, `Cursor` |
| B1 | `klinstruct/*.kl` or macro in package | After A1–A3: `$kstruct` definition (or docs + examples only if builtin in `klin`) |
| B2 | tests + `fixtures/` | Golden hex vs cstruct for generated `pack`/`unpack` |
| B3 | later | Length-prefix, `sN` (`j*` / JSON was [051](051-json-wrapper.md) — ❌ not doing) |

### C. Shared model artifact (optional, “like SVD” path)

| Step | Where | What |
|---|---|---|
| C1 | e.g. `protocol/*.kspec` / JSON like cstruct `jsonModel` | Single source for Klin (`$kstruct_from`) and TS (`fromCompiled`) |
| C2 | tooling outside MCU | Optional generator / hex compatibility check — not in firmware |

## Implementation order

1. B0 atoms — done in klinstruct  
2. A1 macros from package  
3. A2–A3 `$kstruct { fields }` → expand  
4. B1–B2 examples + golden  
5. A5 `$kstruct_from` (when you want file like SVD)  
6. A6 remote import  
7. B3 richer field types  

## Binary contract

As in [052](052-klinstruct.md): packed, native endian; macro only generates what
is written by hand today.

## Out of scope

- Runtime model parser like TS cstruct  
- Generics in grammar as a prerequisite  
- Bitfields; forcing LE/BE ≠ native  
- Priority relative to core / embedded LED  
