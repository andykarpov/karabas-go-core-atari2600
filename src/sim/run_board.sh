#!/bin/bash
# Builds the verilator model of a2600_core (the machine + the karabas parts of karabas_minig.prj
# without the board glue) and runs sim_board (see sim_board.cpp). The build goes to build/obj_board.
#   ./run_board.sh ../roms/legendary_spear.bin --frames 6 --ppm build/board
set -e
cd "$(dirname "$0")"
HERE=$PWD
SRC=..
mkdir -p build
PRJ="$(sed -n 's/^verilog work "\(.*\)"/\1/p' $SRC/atari2600.prj) rtl/karabas/a2600_ce.v rtl/karabas/a2600_sram.v
 rtl/karabas/a2600_hid.v rtl/karabas/a2600_fb.v rtl/karabas/a2600_core.v"
BIN=build/obj_board/Va2600_core
if [ ! -x $BIN ] || [ -n "$(cd $SRC && find $PRJ sim/sim_board.cpp sim/run_board.sh -newer sim/$BIN 2>/dev/null)" ]; then
	echo "JOB-STAGE: build"
	(cd $SRC && verilator -O2 -Wno-fatal -Wno-lint -Wno-style -Wno-BLKANDNBLK -Wno-MULTIDRIVEN -Wno-UNOPTFLAT \
		--no-timing --top-module a2600_core -Mdir sim/build/obj_board --cc $PRJ \
		--exe $HERE/sim_board.cpp -o Va2600_core > sim/build/verilator_board.log 2>&1) || { tail -30 build/verilator_board.log; exit 1; }
	make -s -j8 -C build/obj_board -f Va2600_core.mk > build/make_board.log 2>&1 || { tail -30 build/make_board.log; exit 1; }
fi
CART=$(realpath "$1"); shift
ARGS=()
while [ $# -gt 0 ]; do
	if [ "$1" = --ppm ]; then ARGS+=(--ppm "$(realpath -m "$2")"); shift 2; else ARGS+=("$1"); shift; fi
done
echo "JOB-STAGE: sim"
cd $SRC
exec sim/build/obj_board/Va2600_core "$CART" "${ARGS[@]}"
