#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 firmware.elf firmware.bin" >&2
    exit 2
fi
elf_path="$1"
bin_path="$2"

size_tool="${LLVM_SIZE:-llvm-size}"
if ! command -v "$size_tool" >/dev/null 2>&1; then
    size_tool="$(xcrun -f llvm-size)"
fi

sizes="$($size_tool "$elf_path" | awk 'NR == 2 { print $1, $2, $3 }')"
set -- $sizes
text_bytes="$1"
data_bytes="$2"
bss_bytes="$3"
static_bytes=$((data_bytes + bss_bytes))
flash_bytes=$(wc -c < "$bin_path" | tr -d ' ')
printf 'text=%s data=%s bss=%s static_ram=%s\n' "$text_bytes" "$data_bytes" "$bss_bytes" "$static_bytes"
printf 'flash_image=%s B delta_from_reference=%s B (reference 13844 B)\n' "$flash_bytes" "$((flash_bytes - 13844))"
printf 'static_ram_delta_from_reference=%s B (reference 516 B)\n' "$((static_bytes - 516))"
echo 'Provide the same linked firmware ELF and BIN from ch32-mimoc-ui; this repository does not link the board driver.'
