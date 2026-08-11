#!/usr/bin/env bash
# Compare Klin main.elf vs hand-written blink_ref.elf (issue 028).
# Requires both ELFs already built (make elf / make ref).
set -euo pipefail
cd "$(dirname "$0")"

KLIN_ELF=${1:-main.elf}
REF_ELF=${2:-blink_ref.elf}
OUT=${3:-overhead.md}

for f in "$KLIN_ELF" "$REF_ELF"; do
  if [[ ! -f "$f" ]]; then
    echo "missing $f — run: make elf FREERTOS_DIR=… && make ref FREERTOS_DIR=…" >&2
    exit 1
  fi
done

OBJDUMP=${OBJDUMP:-arm-none-eabi-objdump}
SIZE=${SIZE:-arm-none-eabi-size}
NM=${NM:-arm-none-eabi-nm}

command -v "$NM" >/dev/null || { echo "missing $NM" >&2; exit 1; }
command -v "$OBJDUMP" >/dev/null || { echo "missing $OBJDUMP" >&2; exit 1; }
command -v "$SIZE" >/dev/null || { echo "missing $SIZE" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

sym_size() {
  local elf=$1 sym=$2 hex
  # nm -S: address size type name
  hex=$("$NM" -S "$elf" | awk -v s="$sym" '$4==s {print $2; exit}')
  if [[ -z "$hex" ]]; then
    echo "symbol not found: $sym in $elf" >&2
    exit 1
  fi
  printf '%d\n' "$((16#$hex))"
}

dump_sym() {
  local elf=$1 sym=$2 dest=$3
  "$OBJDUMP" -d "$elf" | awk -v s="<$sym>:" '
    $0 ~ s {p=1}
    p && /^[0-9a-f]+ </ && $0 !~ s {exit}
    p {print}
  ' >"$dest"
  if [[ ! -s "$dest" ]]; then
    echo "empty disassembly for $sym in $elf" >&2
    exit 1
  fi
  if ! grep -q 'vTaskDelay' "$dest"; then
    echo "$sym in $elf does not call vTaskDelay" >&2
    exit 1
  fi
}

hb_k=$(sym_size "$KLIN_ELF" task_heartbeat)
hb_r=$(sym_size "$REF_ELF" task_heartbeat)
blink_k=$(sym_size "$KLIN_ELF" task_blink)
blink_r=$(sym_size "$REF_ELF" task_blink)
main_k=$(sym_size "$KLIN_ELF" main)
main_r=$(sym_size "$REF_ELF" main)
text_k=$("$SIZE" "$KLIN_ELF" | awk 'NR==2{print $1}')
text_r=$("$SIZE" "$REF_ELF" | awk 'NR==2{print $1}')

dump_sym "$KLIN_ELF" task_heartbeat "$tmp/klin_hb.txt"
dump_sym "$REF_ELF" task_heartbeat "$tmp/ref_hb.txt"

if [[ "$hb_k" -ne "$hb_r" ]]; then
  echo "task_heartbeat size mismatch: Klin=${hb_k} C=${hb_r}" >&2
  exit 1
fi

{
  echo "# FreeRTOS blink — Klin vs C overhead (issue 028)"
  echo
  echo "Same FreeRTOS-Kernel, \`FreeRTOSConfig.h\`, \`CFLAGS\`, linker script."
  echo "Klin: \`main.kl\` → \`main.elf\`. C twin: \`ref/blink_ref.c\` → \`blink_ref.elf\`."
  echo
  echo "Generated: $(date -u +%Y-%m-%dT%H:%MZ)"
  echo
  echo "## \`size\` (whole ELF)"
  echo
  echo '```'
  echo "=== Klin ($KLIN_ELF) ==="
  "$SIZE" "$KLIN_ELF"
  echo
  echo "=== C ref ($REF_ELF) ==="
  "$SIZE" "$REF_ELF"
  echo '```'
  echo
  echo "## App symbol sizes (bytes, \`nm -S\`)"
  echo
  echo "| Symbol | Klin | C ref |"
  echo "|---|---:|---:|"
  echo "| \`task_blink\` | $blink_k | $blink_r |"
  echo "| \`task_heartbeat\` | $hb_k | $hb_r |"
  echo "| \`main\` | $main_k | $main_r |"
  echo
  echo "## \`task_heartbeat\` disassembly (pure RTOS delay loop)"
  echo
  echo "Both should only call \`vTaskDelay\` in the loop — no Klin runtime."
  echo
  echo "### Klin"
  echo
  echo '```'
  cat "$tmp/klin_hb.txt"
  echo '```'
  echo
  echo "### C ref"
  echo
  echo '```'
  cat "$tmp/ref_hb.txt"
  echo '```'
  echo
  echo "## Verdict"
  echo
  echo "- FreeRTOS entry points are direct C calls (\`vTaskDelay\`, \`xTaskCreate\`,"
  echo "  \`vTaskStartScheduler\`) — Klin FFI is thin \`@[cimport]\`, not a scheduler."
  echo "- \`task_heartbeat\` (fair RTOS-only compare): Klin=${hb_k} B, C=${hb_r} B —"
  echo "  **equal** size; both disassemblies contain \`vTaskDelay\` (checked by compare.sh)."
  echo "- \`task_blink\` may differ: Klin uses \`machine_stm32.Pin\` helpers; C ref"
  echo "  inlines PA5 MMIO. That is board HAL shape, not FreeRTOS tax."
  echo "- Whole-ELF \`.text\`: Klin=${text_k}, C=${text_r} (delta from Pin /"
  echo "  thin wrappers; FreeRTOS kernel is shared)."
  echo
  echo "Conclusion: **no hidden FreeRTOS / scheduler overhead** from Klin vs the C twin."
} >"$OUT"

echo "wrote $OUT"
