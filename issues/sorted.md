# Klin — work order

Steps are defined by **what compiles**, not by which
components exist.

## Main queue (foundation) — ✅

| # | Task | Status | Depends on |
|---|---|---|---|
| [000](000-fundamental-decisions.md) | Three fundamental decisions | ✅ | — |
| [001](001-empty-pass.md) | **Empty pass: hello world** | ✅ | 000 |
| [002](002-symbol-table-checker.md) | Symbol table and type checker | ✅ | 001 |
| [003](003-control-flow.md) | Control flow | ✅ | 002 |
| [004](004-functions.md) | Functions | ✅ | 003 |
| [005](005-structs-methods.md) | Structs and methods | ✅ | 004 |
| [006](006-modules.md) | Modules | ✅ | 005 |
| [007](007-pointers-arrays-slices.md) | Pointers, arrays, slices | ✅ | 006 |
| [008](008-defer.md) | `defer` | ✅ | 007 |
| [009](009-errors.md) | Errors as values | ✅ | 008 |
| [010](010-bare-metal.md) | **Bare metal: LED on STM32** | ✅ | 009 |
| [011](011-svd.md) | SVD generator (`svd2klin`) | ✅ | 010 |

After **010** the language does what it was built for. After **011** there is a
register generator from SVD. Further work is growth (backlog below), not
building the core from scratch.

---

## Backlog — done

| # | Task | Status | Depends on |
|---|---|---|---|
| [012](012-stdlib-io.md) | Optional I/O module (`io.print` / `println`) | ✅ | 006 |
| [014](014-match.md) | `match` (default break, `1,2,3` / `4..=10`, stmt+expr) | ✅ | 003 |
| [084](084-match-when-rel.md) | `match`: `when` guards + relational patterns (`>`, `>=`, …) + `_ when` | ✅ | 014 |
| [085](085-pick.md) | `pick cond { a } { b }` — expression ternary → C `?:` | ✅ | 003 |
| [016](016-string-interpolation.md) | Interpolated strings | ✅ | 012 |
| [017](017-collection-methods.md) | Collection methods (`slice` + `slice_alloc`; +i64/f64 types, +ops) | ✅ | 007, 057 |
| [019](019-default-int-types.md) | Default types (`int` / `float` → `i32` / `f64`) | ✅ | 002 |
| [020](020-klin-libraries.md) | Klin libraries (`lib/` / `-I` / `KLIN_PATH`) | ✅ | 006 |
| [021](021-c-libraries.md) | C libraries (FFI / link) | ✅ | 006, 010 |
| [022](022-asm-libraries.md) | ASM units (`.s` via `@[link]`) | ✅ | 021 |
| [024](024-rtos.md) | RTOS as C API client (`klin_freertos` ✅; Zephyr/RT-Thread ⏸) | ✅ | 010, 021 |
| [023](023-examples.md) | `examples/` catalog (+ `stm32/`) | ✅ | 001+ |
| [025](025-english-project.md) | English project (PL design/roadmap exception superseded by 082) | ✅ | — |
| [082](082-english-issues-docs.md) | English `docs/` + `issues/` (`note/` → `docs/`, EN slugs) | ✅ | 025 |
| [026](026-preprocessor.md) | Preprocessor (`$fn`…, D3) | ✅ | 010+ |
| [027](027-svd-ergonomic-api.md) | Ergonomic SVD API (`$peripherals_from_svd`) | ✅ | 011, 026 |
| [032](032-klin-run.md) | CLI: `klin run <file.kl>` | ✅ | 001 |
| [033](033-gofmt-style.md) | Go-style formatting (`klin fmt`) | ✅ | 005+ |
| [035](035-klin-test.md) | `klin test` (like `go test`, Klin code) | ✅ | 032 |
| [036](036-docs-catchup.md) | Docs catch-up (CLI / stdlib / features ✅) | ✅ | 026–035 |
| [037](037-datetime-format.md) | Date/time formatting (`stdlib/time`) | ✅ | 016 |
| [038](038-time-api.md) | `time` API ergonomics (`until` / `abs` / `as_s`) | ✅ | 037 |
| [039](039-time-calendar.md) | Calendar `add_days` / months / years | ✅ | 037 |
| [045](045-cexport.md) | Klin → C export (`@[cexport]`) | ✅ | 021 |
| [046](046-emit-h.md) | `--emit-h` (C header from `@[cexport]`) | ✅ | 045 |
| [047](047-directory-modules.md) | Directory = one module (like Go/V) | ✅ | 006, 020 |
| [055](055-short-decl.md) | `:=` shorthand (= `let mut`) | ✅ | 002 |
| [057](057-allocator.md) | `Allocator` (explicit allocator, D1) — `stdlib/mem` | ✅ | 007, 008 |

---

## Backlog — under consideration

| # | Task | Status | Depends on |
|---|---|---|---|
| [018](018-generators-yield.md) | ~~Generators / `yield`~~ | ❌ struck | — |
| [028](028-freertos.md) | FreeRTOS (`klin_freertos` ✅ `@v0.4.0`; blink + objdump vs C ✅) | ✅ | 024, 010, 021, 030 |
| [029](029-async-event-loop.md) | Event loop / async·await (lib `@v0.4.0` + `flag_wait` ✅; `$event_loop` ✅; async MVP ✅; IDE → [087](087-intellij-plugin.md)) | 🔨 | 028?, 049? |
| [030](030-isr-decorators.md) | Interrupts via decorators (`@[isr("…")]` MVP ✅) | ✅ | 010 |
| [031](031-hal-libraries.md) | HAL libraries (Cube / LL) | 💭 | 010, 021 |
| [034](034-generic-types.md) | Generics in the grammar — not now (D3/`$fn`; maybe sugar later) | 💭 | 026 |
| [040](040-time-zones.md) | IANA zones + DST | 💭 | 037 |
| [041](041-time-locale-relative.md) | Date locales + relative strings | 💭 | 037 |
| [042](042-time-format-luxon.md) | `yyyy-MM-dd` format dialect in `time` | 💭 | 037 |
| [043](043-rtc.md) | RTC → `Instant` (separate module) | 💭 | 010, 031? |
| [044](044-cpu-cycles.md) | CPU cycles / SysTick → `Duration` | 💭 | 010 |
| [048](048-import-aliases.md) | Import aliases (+ local string) | ✅ | 006, 047 |
| [049](049-remote-imports.md) | Remote imports + `klin.mod` + `klin get` / `update` | ✅ | 048, 020, 047, 063 |
| [063](063-remote-fixture-osa.md) | Remote fixture `klin-lang/osa` (e2e 049) | ✅ | 047 |
| [065](065-project-lockfile.md) | `klin.lock` / checksums (like go.sum) | ✅ | 049 |
| [066](066-klin-upgrade-outdated.md) | `klin upgrade` / outdated (newer deps) | ✅ | 049 |
| [067](067-homebrew.md) | Homebrew: `brew install klin` (formula + tap + v0.1.0) | ✅ | — |
| [050](050-sqlite-wrapper.md) | SQLite wrapper (FFI) | ❌ not doing | 021 |
| [070](070-host-orm-sqlite.md) | ~~ORM-like / typed repo over SQLite~~ | ❌ struck | — |
| [051](051-json-wrapper.md) | JSON wrapper + `$…` paths | ❌ not doing | 021, 026? |
| [052](052-klinstruct.md) | `klinstruct` — pack/unpack like cstruct (low priority) | 💭 | 007, 020/047 |
| [053](053-device-board-assets.md) | `$device` + Go-like SVD fetch (`device` in `klin.mod`) | ✅ (MVP; board → 074) | 027, 049 |
| [054](054-embedded-project-layout.md) | Embedded project look / layout | ✅ | 023, 010 |
| [056](056-destructuring.md) | Destructuring (`{}` / `[]` / multi-assign; no tuples) | ✅ (A+A′+B+C+D; bare `[]=` skipped) | 005, 007? |
| [058](058-source-file-split.md) | Split large compiler source files (tech debt) | 💭 | — |
| [059](059-kstruct-macros.md) | `$kstruct` / `$kstruct_from` macros (richer klinstruct) | 💭 | 026, 052 |
| [060](060-map-kv.md) | ~~KV map (hash map)~~ | ❌ struck (hidden resize) | — |
| [061](061-micropython-machine-api.md) | MicroPython-style `machine` API (PWM, UART, …) | ✅ (+ rp Pio+Dma+UsbCdc `@v0.11.0` / ch32v `@v0.1.0` / gd32v `@v0.2.0`) | 010, 031? |
| [062](062-targets-esp-rp.md) | MCU targets: ESP32 / RP2040 / RP2350 / STM8 / CH32V / GD32V | 🚧 (RP Pio+Dma+UsbCdc ✅ `@v0.11.0`; ESP C3+S3+STM8+CH32V+GD32V Pin…Adc ✅; **P4 Pin…Adc+Rmt+LP GPIO+regi2c+LP UART** ✅ `@v0.15.0`; RMII ✅ `esp_eth@v0.2.0`) | 010 |
| [086](086-machine-ch32v.md) | `machine_ch32v` CH32V003 QingKe Pin…Adc | ✅ `@v0.1.0` | 061, 062 |
| [087](087-machine-gd32v.md) | `machine_gd32v` GD32VF103 Nuclei Pin…Adc | ✅ `@v0.2.0` | 061, 086 |
| [117](117-machine-gd32v-gd32vw553.md) | `machine_gd32v` GD32VW553 Pin…Adc twins (`*_vw553`) | ✅ `@v0.8.0` | 061, 062, 087 |
| [126](126-gd32v-wifi-sdk.md) | `gd32v_wifi` GD32VW553 STA + SoftAP + scan + link + static (GigaDevice SDK, not `machine_*`) | 🔨 STA+SoftAP+scan+link+static `@v0.4.0` | 021, 024, 049, 061, 062, 117 |
| [127](127-board-gd32vw553h-eval.md) | Board pack GD32VW553H-EVAL (pins + `klin init`) | 🔨 `@v0.1.0` ([repo](https://github.com/klin-lang/gd32vw553h_eval)) | 061, 062, 075, 117 |
| [129](129-board-gd32vw553h-start.md) | Board pack GD32VW553 START (UART2 + RGB V4 + `klin init`) | 🔨 `@v0.1.0` ([repo](https://github.com/klin-lang/gd32vw553h_start)) | 061, 062, 075, 117 |
| [130](130-gd32v-ble-sdk.md) | `gd32v_ble` GD32VW553 advertise (GigaDevice AN152, not `machine_*`) | 🔨 advertise `@v0.1.0` | 021, 024, 049, 061, 062, 117, 126 |
| [095](095-board-waveshare-rp2350-lcd-096.md) | Board pack Waveshare RP2350-LCD-0.96 (ST7735S) | ✅ `@v0.13.0` ([repo](https://github.com/klin-lang/waveshare_rp2350_lcd_096)) | 061, 062 |
| [096](096-board-nucleo-f411re.md) | Board pack Nucleo-F411RE (pins + `.ioc` + examples) | ✅ `@v0.1.3` ([repo](https://github.com/klin-lang/nucleo_f411re)) | 061, 074, 075 |
| [098](098-board-adafruit-rp2040-can-feather.md) | Board pack Adafruit RP2040 CAN Feather (MCP25625) | ✅ `@v0.1.0` ([repo](https://github.com/klin-lang/adafruit_rp2040_can_feather)) | 061, 062, 075 |
| [099](099-machine-esp-esp32-s3.md) | `machine_esp` ESP32-S3 Pin…Adc+Rmt (`*_s3`) | ✅ `@v0.5.0`/`@v0.6.0`/`@v0.7.0` ([repo](https://github.com/klin-lang/machine_esp)) | 061, 062 |
| [100](100-board-waveshare-esp32-s3-pico.md) | Board pack Waveshare ESP32-S3-Pico | ✅ `@v0.3.0` ([repo](https://github.com/klin-lang/waveshare_esp32_s3_pico)) | 061, 062, 099 |
| [101](101-esp-wifi-idf.md) | ESP Wi‑Fi thin IDF package (`esp_wifi` STA + SoftAP + scan + link) | ✅ `@v0.4.0` ([repo](https://github.com/klin-lang/esp_wifi)) | 021, 024, 049, 061, 062, 099 |
| [102](102-esp-eth-idf.md) | ESP Ethernet thin IDF package (`esp_eth` W5500 + RMII) | ✅ `@v0.2.0` ([repo](https://github.com/klin-lang/esp_eth)) | 021, 024, 049, 061, 062, 101 |
| [103](103-later-tracks-ble-usb-camera-lcd.md) | Later tracks A–D MVP done (BLE/USB/camera/Pico LCD); leftover tags | ✅ MVP (later tags elsewhere) | 061, 062, 101, 102, 106, 108, 109, 110 |
| [104](104-later-tracks-esp-network.md) | Later tracks: ESP network (Wi‑Fi W1–W3 ✅; N1 dual ✅; sockets ✅; HTTP/TLS ✅; RMII ✅) | 🔨 Wi‑Fi+N1–N3+E1 ✅; ETH E2+ backlog | 101, 102, 062, 111, 112, 113 |
| [105](105-later-tracks-iot.md) | Later tracks: IoT (MQTT / OTA…) | 💭 maybe backlog (sockets+HTTP ✅; ready for MQTT) | 104, 101, 102, 111, 112 |
| [106](106-esp-ble-idf.md) | ESP BLE thin IDF package (`esp_ble` GATT + bond + UUID16/128 + privacy + Mesh OnOff) | ✅ `@v0.10.0` ([repo](https://github.com/klin-lang/esp_ble)) | 021, 024, 049, 061, 062, 101 |
| [107](107-later-tracks-arduino-boards.md) | Later tracks: Arduino boards (Leonardo / Uno R4 / Due / Giga / Portenta) | 💭 backlog (one family at a time) | 061, 062, 075 |
| [108](108-esp-usb-idf.md) | ESP USB OTG thin IDF package (`esp_usb` TinyUSB device CDC) | ✅ `@v0.1.0` ([repo](https://github.com/klin-lang/esp_usb)) | 021, 024, 049, 061, 062 |
| [109](109-esp-camera-idf.md) | ESP camera thin IDF package (`esp_camera` DVP JPEG) | ✅ `@v0.1.0` ([repo](https://github.com/klin-lang/esp_camera)) | 021, 024, 049, 061, 062 |
| [110](110-board-waveshare-pico-lcd-114.md) | Board pack Waveshare Pico-LCD-1.14 (ST7789 shield) | ✅ `@v0.1.0` ([repo](https://github.com/klin-lang/waveshare_pico_lcd_114)) | 061, 062, 075 |
| [111](111-esp-sockets-idf.md) | ESP LwIP sockets thin IDF package (`esp_sockets` TCP/UDP) | ✅ `@v0.1.0` ([repo](https://github.com/klin-lang/esp_sockets)) | 021, 024, 049, 101, 102, 104 |
| [112](112-esp-http-idf.md) | ESP HTTP(+TLS) thin IDF package (`esp_http` GET/POST) | ✅ `@v0.1.0` ([repo](https://github.com/klin-lang/esp_http)) | 021, 024, 049, 101, 102, 104, 111 |
| [113](113-esp-netif-dual-idf.md) | ESP dual Wi‑Fi+ETH glue (`esp_netif_dual` prefer/failover) | ✅ `@v0.1.0` ([repo](https://github.com/klin-lang/esp_netif_dual)) | 021, 024, 049, 101, 102, 104 |
| [114](114-machine-esp-esp32-p4.md) | `machine_esp` ESP32-P4 Pin…Adc+Rmt (`*_p4`) | ✅ `@v0.8.0`/`@v0.9.0`/`@v0.10.0`/`@v0.11.0`/`@v0.12.0`/`@v0.13.0`/`@v0.14.0`/`@v0.15.0` ([repo](https://github.com/klin-lang/machine_esp)) | 061, 062 |
| [064](064-if-cond-struct-literal-parse.md) | `if`/`while` condition ending in a name mistaken for a struct literal | ✅ | — |
| [068](068-shared-type-decl.md) | Shared type annotation (`a, b: i32` like Go; both forms OK) | ✅ | 002, 004, 005 |
| [069](069-eventemitter-signals.md) | Observer / EventEmitter / Signals (library; JS-signals explicitly) | 💭 | 013, 057 |
| [071](071-lambda.md) | Lambdas / `fn (…) => expr` (verdict: not now; after D7) | 💭 | fn-ptr, D7 |
| [072](072-enums.md) | Enums (C23-style, optional base type; methods; explicit conversion; string/kv-enum out of MVP) | ✅ | 002, 005, 014 |
| [073](073-mem-leak-detection.md) | Potential memory-leak detection (Valgrind/ASan, debug allocator, lint) | 💭 | 057, 008 |
| [074](074-board-ioc-klin-mod.md) | `board` in `klin.mod` + narrow CubeMX `.ioc` (pinout) | ✅ MVP | 053 |
| [075](075-board-pack-init-host.md) | Board pack / `klin init` vs host — linker & startup | 🔨 MCU init ✅ (+ ESP S3-Pico; host 💭) | 010, 054, 053 |
| [076](076-release-windows-arm.md) | Release: Windows/ARM targets + publishing + checksums | ✅ | 067 |
| [077](077-string-template.md) | Runtime string substitution / templates (`{0}` positional + `{key}` KV) | 💭 | 007, 057, 016, 060 |
| [078](078-bitwise-ops.md) | Bitwise operators (`\| & ^ ~ << >>`; integers only) | ✅ | 002, 019 |
| [097](097-logical-ops.md) | Logical operators (`&&` / `\|\|`; bool only, short-circuit) | ✅ | 002, 003, 078 |
| [079](079-associated-functions.md) | Associated/static functions on types (`Type.func`; constructors/parsers) | ✅ | 005, 072 |
| [080](080-stdlib-str.md) | `stdlib/str` — `eq`/`len`/… (string compares without `==`) | ✅ | 012, 021 |
| [083](083-stdlib-math.md) | `stdlib/math` — thin libm + typed `min_*`/`max_*`/`clamp_*` | ✅ | 012, 021 |
| [081](081-number-literals.md) | Literals: binary `0b`, float exponent `1e…`, char `'A'`, octal `0o` | ✅ | 002 |
| [086](086-lsp.md) | Language Server (`klin lsp` MVP + cross-file + rename) | ✅ | 002, 033, 026 |
| [087](087-intellij-plugin.md) | IntelliJ plugin for Klin (LSP client + highlight; not full PSI) | ✅ MVP (no Marketplace) | 086, 093 |
| [088](088-dap-debug.md) | Debug: `#line`/gdb docs + CLI `-g` + optional thin DAP | 🔨 docs+`-g` ✅ (DAP 💭) | `#line`, 087? |
| [091](091-lsp-svd-sourcemaps.md) | LSP source maps through SVD fluent (`$device`) | ✅ | 086 |
| [092](092-lsp-parse-recovery.md) | LSP lex/parse multi-error recovery + workspace index | ✅ parse MVP (index 💭) | 086 |
| [093](093-syntax-highlight.md) | TextMate / tree-sitter highlight (not inside `klin lsp`) | ✅ TextMate MVP (tree-sitter 💭) | 086?, 087 |
| [094](094-lsp-semantic-tokens.md) | LSP semantic tokens (AST/checker coloring) | ✅ full MVP (range/delta 💭) | 086 |
| [115](115-english-leftover-pl.md) | Leftover Polish after 025 / 082 (Taskfile, gitignore, diagnostics) | ✅ | 025, 082 |
| [116](116-docs-reorg.md) | Docs map: landing README, idea, short guide (not STM32-only) | ✅ | 036, 082, 023 |
| [117](117-docs-device.md) | User doc for SVD / `$device` / fluent MMIO | ✅ | 116, 011, 027, 053 |
| [118](118-docs-embedded.md) | User doc: `klin init` walkthrough (not STM32-only) | ✅ | 116, 075, 054 |
| [119](119-docs-guide-control.md) | Guide: `if` / `defer` / `import` + precedence table | ✅ | 116, 003, 008, 006 |
| [120](120-docs-syntax.md) | User page: enums / `Type.fn` / destructuring | ✅ | 116, 072, 079, 056 |
| [121](121-docs-async-lib.md) | Map: event loop is a library; `async` / `.await` are language | ✅ | 116, 029 |
| [122](122-docs-hello-to-board.md) | Path: hello → register → small project (no `issues/`) | ✅ | 116, 117, 118, 119 |
| [123](123-docs-rtos-lib.md) | Map: FreeRTOS is C + `klin_freertos`, not the language | ✅ | 116, 024, 028 |
| [124](124-docs-c-asm.md) | Map: C FFI + ASM units / `asm("…")` (not a C/ASM language) | ✅ | 116, 021, 022 |
| [125](125-drop-host-json-sqlite.md) | Drop JSON / SQLite; strike ORM, `yield`, map (hidden resize) | ✅ | 050, 051, 070, 018, 060 |
| [126](126-enum-index.md) | Enum as `[N]T` index (`table[Slot.B]`) | ✅ | 072, 007 |
| [127](127-docs-generics-fn.md) | Map: generics are `$fn`, not `[T]` in the compiler | ✅ | 116, 026, 034 |
| [128](128-fmt-comments.md) | `klin fmt` keeps `//` comments | ✅ | 033 |
| [129](129-enum-match-exhaustive.md) | Exhaustive `match` on enum (checker) | ✅ | 072, 014 |
| [130](130-winget-scoop-windows.md) | Windows package channels: WinGet + Scoop (wrap Release `.zip`) | 💭 | 076, 067 |
| [131](131-linux-install-docs.md) | Linux install docs (tarball) + no apt/snap note | 💭 | 076, 067 |
| [132](132-match-else-or.md) | `match { else { error(n) } } or { }` — `error` as `!T` value | 💭 | 009, 014 |
| [133](133-docs-language-surface.md) | Page: what is the language (agents: not “no generics”) | ✅ | 116, 127, 125 |

---

## Rules (always)

Details in `docs/02-architecture.md`.

1. **Golden tests** — `.kl` + expected output.
2. **`#line` in emission** — every token carries a position.
3. **The frontend catches errors** — gcc must not complain about generated code.
4. **Hand-written recursive-descent parser** — no generators.
5. **Overarching principle** — no hidden allocation / control flow / cost; for a new
   feature, `objdump` Klin vs hand-written C.
6. **Do not expand the scope** of the current step on this list.
