#!/bin/bash
# Converts the 2600 part of the k7800 RTL (SystemVerilog) to Verilog-2001 for XST with sv2v
# (/opt/sv2v/sv2v): one file per module in rtl/sv2v/. rtl/sv2v/ is generated and in git: change the
# sources (with a "karabas:" comment), then run this.
# State (Ф0 start): TIA, mos6502 and M6532 (+ cache_ram.v) only. cart2600 / banks2600 / detect2600
# and the machine top atari2600_top come in Ф0 (docs/PLAN.md): cart2600 needs the enum fixes for XST
# and the ARM / DPC+ / CDF parts cut out.
set -e
cd "$(dirname "$0")/../rtl"
SV2V=${SV2V:-/opt/sv2v/sv2v}
SRC="k7800/6502/mos6502_pkg.sv k7800/6502/mos6502_alu.sv k7800/6502/mos6502_decode.sv k7800/6502/mos6502_dp.sv
 k7800/6502/mos6502_ctl.sv k7800/6502/mos6502.sv k7800/TIA.sv k7800/RIOT/M6532.sv"
TOPS="--top=TIA --top=mos6502 --top=M6532"
rm -rf sv2v && mkdir sv2v
$SV2V $TOPS $SRC -w sv2v 2>&1 | grep -v -E '^\s*$|Warning: Number literal|^ *[0-9]* \||^\s*\|' || true
ls sv2v | wc -l
# k7800_parts.prj: the converted parts alone (make k7800-parts-xst); cache_ram.v is plain Verilog
{ echo 'verilog work "rtl/k7800/cache_ram.v"'; for f in sv2v/*.v; do echo "verilog work \"rtl/$f\""; done; } > ../k7800_parts.prj
