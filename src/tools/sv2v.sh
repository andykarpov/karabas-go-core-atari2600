#!/bin/bash
# Converts the 2600 part of the k7800 RTL (SystemVerilog) and our cart2600_kg to Verilog-2001 for XST
# with sv2v (/opt/sv2v/sv2v): one file per module in rtl/sv2v/. rtl/sv2v/ is generated and in git:
# change the sources (with a "karabas:" comment), then run this.
# Tops: the parts atari2600_top (rtl/karabas, plain Verilog) instantiates. bram.v / cache_ram.v
# go through too (spram, cache_ram_dp), so the prj lists only rtl/sv2v/ + the karabas files.
set -e
cd "$(dirname "$0")/../rtl"
SV2V=${SV2V:-/opt/sv2v/sv2v}
SRC="k7800/detect2600.sv k7800/6502/mos6502_pkg.sv k7800/6502/mos6502_alu.sv k7800/6502/mos6502_decode.sv
 k7800/6502/mos6502_dp.sv k7800/6502/mos6502_ctl.sv k7800/6502/mos6502.sv k7800/6502/sally.sv
 k7800/TIA.sv k7800/RIOT/M6532.sv k7800/banks2600.sv k7800/mapper_fa2.sv karabas/cart2600_kg.sv
 k7800/paddles.sv k7800/bram.v k7800/cache_ram.v"
TOPS="--top=sally --top=TIA --top=M6532 --top=detect2600 --top=cart2600_kg --top=paddle_timer"
rm -rf sv2v && mkdir sv2v
$SV2V $TOPS $SRC -w sv2v 2>&1 | grep -v -E '^\s*$|Warning: Number literal|^ *[0-9]* \||^\s*\|' || true
ls sv2v | wc -l
# k7800_parts.prj: the converted parts alone (make k7800-parts-xst)
{ for f in sv2v/*.v; do echo "verilog work \"rtl/$f\""; done; } > ../k7800_parts.prj
# atari2600.prj: the whole machine (make atari2600-xst)
{ cat ../k7800_parts.prj; echo 'verilog work "rtl/karabas/atari2600_top.v"'; } > ../atari2600.prj
