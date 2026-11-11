#!/bin/bash
# Builds the verilator model of atari2600_top (the files of atari2600.prj) and runs sim_a2600 with
# the given arguments (see sim_a2600.cpp). The build goes to src/sim/build.
#   ./run_sim.sh build/bars.a26 --frames 5 --ppm build/bars
# DEBUG=1: a build with the internal signals public (build/obj_dbg), for the --trace-* options.
set -e
cd "$(dirname "$0")"
HERE=$PWD
SRC=..
mkdir -p build
PRJ=$(sed -n 's/^verilog work "\(.*\)"/\1/p' $SRC/atari2600.prj)
OBJ=obj; DBG=
if [ -n "$DEBUG" ]; then OBJ=obj_dbg; DBG="--public-flat-rw -CFLAGS -DSIM_DEBUG"; fi
BIN=build/$OBJ/Vatari2600_top
if [ ! -x $BIN ] || [ -n "$(cd $SRC && find $PRJ sim/sim_a2600.cpp sim/run_sim.sh -newer sim/$BIN 2>/dev/null)" ]; then
	echo "JOB-STAGE: build"
	(cd $SRC && verilator -O2 -Wno-fatal -Wno-lint -Wno-style -Wno-BLKANDNBLK -Wno-MULTIDRIVEN -Wno-UNOPTFLAT \
		--no-timing --top-module atari2600_top $DBG -Mdir sim/build/$OBJ --cc $PRJ \
		--exe $HERE/sim_a2600.cpp -o Vatari2600_top > sim/build/verilator.log 2>&1) || { tail -30 build/verilator.log; exit 1; }
	make -s -j8 -C build/$OBJ -f Vatari2600_top.mk > build/make.log 2>&1 || { tail -30 build/make.log; exit 1; }
fi
# the cartridge and --ppm paths are relative to the caller's dir; run from src/ for $readmem
CART=$(realpath "$1"); shift
ARGS=()
while [ $# -gt 0 ]; do
	if [ "$1" = --ppm ]; then ARGS+=(--ppm "$(realpath -m "$2")"); shift 2; else ARGS+=("$1"); shift; fi
done
echo "JOB-STAGE: sim"
cd $SRC
exec sim/build/$OBJ/Vatari2600_top "$CART" "${ARGS[@]}"
