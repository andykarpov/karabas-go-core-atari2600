#!/bin/bash
# The Ф1 checks of the machine (seconds each): our test cartridges of roms/mkrom.py on the
# verilator model (run_sim.sh). Exit 1 on the first failure.
#   bars   : CPU + TIA: 262 lines, colour bars (ADC) + playfield; also at div 5 with a jittered CE
#   timer  : RIOT TIM64T / INTIM timing: 261 lines (see mkrom.py); 259 = the wrap-on-write bug
#   f8     : F8 detected by detect2600 (mapper 1), both hotspots each frame, all lines COLUBK $40 (index 20)
set -e
cd "$(dirname "$0")"
mkdir -p build
for k in bars timer f8; do python3 roms/mkrom.py build/$k.a26 $k; done
run() { echo "== $*"; ./run_sim.sh "$@" --quiet | grep -v JOB-STAGE; }
run build/bars.a26 --frames 4 --expect-lines 262
run build/bars.a26 --frames 4 --div 5 --jitter --expect-lines 262
run build/timer.a26 --frames 4 --expect-lines 261
run build/f8.a26 --frames 4 --expect-lines 262 --expect-mapper 1 --expect-colour 20
echo "all checks passed"
