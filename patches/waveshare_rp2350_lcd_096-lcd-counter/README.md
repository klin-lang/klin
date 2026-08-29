# Patch seed: waveshare_rp2350_lcd_096 — lcd_counter + PICOTOOL.md

Upstream: [`klin-lang/waveshare_rp2350_lcd_096`](https://github.com/klin-lang/waveshare_rp2350_lcd_096)
(`@v0.13.0` base). **Open pack PR:**
[#14](https://github.com/klin-lang/waveshare_rp2350_lcd_096/pull/14).

This folder is a Klin-side mirror of that PR.

## Contents

| Path (in upstream) | What |
|---|---|
| `PICOTOOL.md` | UF2 / `picotool` flash guide (BOOT = bootloader only) |
| `examples/lcd_counter/` | White LCD, black `x:` ++ once per second |
| `README.md` | Checklist + link to `PICOTOOL.md` (in the `.patch`) |

Also: [`../waveshare_rp2350_lcd_096-lcd-counter.patch`](../waveshare_rp2350_lcd_096-lcd-counter.patch).

## Apply (if needed offline)

```sh
cd /path/to/waveshare_rp2350_lcd_096
git checkout main && git pull
git apply /path/to/klin/patches/waveshare_rp2350_lcd_096-lcd-counter.patch
```

Prefer merging [PR #14](https://github.com/klin-lang/waveshare_rp2350_lcd_096/pull/14).

## Run

```sh
cd examples/lcd_counter
make deps KLIN=/path/to/klin/bin/klin.dart
make emit KLIN=/path/to/klin/bin/klin.dart
make elf
# flash: see PICOTOOL.md
```

Klin issue: [095](../../issues/095-board-waveshare-rp2350-lcd-096.md).
