#!/bin/bash
# The bankswitching test ROMs of gamebub-2600 (Mark Schlosser, MIT; another port of the 2600 mode of
# k7800): sim/testroms of github.com/Wenwald/gamebub-2600 at a fixed commit, fetched into
# build/gamebub (not in the repo), assembled with dasm by this script (the variants of its Makefile)
# into build/gb/, then run on the model. A test shows green ($C6, palette index 63) on its first 64
# visible lines when every check passed, red ($46, 23) otherwise (multicarts: the game's colour).
#   ./run_gamebub.sh            all of them
#   ./run_gamebub.sh e0 f8sc    some (names without bs_)
# AR, JANE, the paddle / switch / tone / save state tests and the ARM schemes are not run here.
set -e
cd "$(dirname "$0")"
COMMIT=438cd0823d8ec051c23e415216da69da0f7be610
SRC=build/gamebub
OUT=build/gb
mkdir -p $SRC $OUT
if [ ! -f $SRC/.commit ] || [ "$(cat $SRC/.commit)" != $COMMIT ]; then
	for f in testlib.h bs_fx.asm bs_mc.asm bs_e0.asm bs_3f.asm bs_f0.asm bs_2k.asm bs_cv.asm bs_e7.asm \
		bs_3e.asm bs_fe.asm bs_wd.asm bs_fc.asm bs_p2.asm; do
		gh api "repos/Wenwald/gamebub-2600/contents/sim/testroms/$f?ref=$COMMIT" --jq .content | base64 -d > $SRC/$f
	done
	echo $COMMIT > $SRC/.commit
fi

# name: source and dasm defines (decimal), as the gamebub Makefile
declare -A V=(
	[e0]="bs_e0" [3f]="bs_3f" [f0]="bs_f0" [2k]="bs_2k" [cv]="bs_cv" [e7]="bs_e7" [3e]="bs_3e"
	[fe]="bs_fe" [wd]="bs_wd" [fc]="bs_fc" [p2]="bs_p2"
	[4ksc]="bs_fx -DBANKS=1 -DHOT=65528 -DRAM=128 -DSC4K=1"
	[f8]="bs_fx -DBANKS=2 -DHOT=65528"
	[f6]="bs_fx -DBANKS=4 -DHOT=65526"
	[f4]="bs_fx -DBANKS=8 -DHOT=65524"
	[f8sc]="bs_fx -DBANKS=2 -DHOT=65528 -DRAM=128"
	[f6sc]="bs_fx -DBANKS=4 -DHOT=65526 -DRAM=128"
	[f4sc]="bs_fx -DBANKS=8 -DHOT=65524 -DRAM=128"
	[fa]="bs_fx -DBANKS=3 -DHOT=65528 -DRAM=256"
	[fa2]="bs_fx -DBANKS=7 -DHOT=65525 -DRAM=256"
	[ef]="bs_fx -DBANKS=16 -DHOT=65504"
	[efsc]="bs_fx -DBANKS=16 -DHOT=65504 -DRAM=128"
	[df]="bs_fx -DBANKS=32 -DHOT=65472 -DTAIL=1"
	[dfsc]="bs_fx -DBANKS=32 -DHOT=65472 -DTAIL=1 -DRAM=128"
	[bf]="bs_fx -DBANKS=64 -DHOT=65408 -DTAIL=1"
	[bfsc]="bs_fx -DBANKS=64 -DHOT=65408 -DTAIL=1 -DRAM=128"
	[sb128]="bs_fx -DBANKS=32 -DHOT=2048"
	[sb256]="bs_fx -DBANKS=64 -DHOT=2048"
	[ua]="bs_fx -DBANKS=2 -DHOT=544 -DSTRIDE=32"
	[0840]="bs_fx -DBANKS=2 -DHOT=2048 -DSTRIDE=64"
	[cty]="bs_fx -DBANKS=8 -DFIRST=1 -DHOT=65525 -DRAM=64"
	[mc2k]="bs_mc -DGAMES=8 -DGSIZE=2048"
	[mc4k]="bs_mc -DGAMES=8 -DGSIZE=4096"
	[mc8k]="bs_mc -DGAMES=8 -DGSIZE=8192"
	[32in1]="bs_mc -DGAMES=32 -DGSIZE=2048"
)
# tests the autodetect cannot tell from the image (as Stella, by name / database only): the mapper
# forced as in the OSD (BANK* numbers of detect2600). Multicarts: two resets -> game 2, whose
# colour hue is 2 ($2A, index 15); the first game after a load is game 0.
declare -A OPT=(
	[fe]="--mapper 3" [cty]="--mapper 22"
	[mc2k]="--mapper 29 --frames 8 --reset-at 2 --reset-at 4"
	[mc4k]="--mapper 30 --frames 8 --reset-at 2 --reset-at 4"
	[mc8k]="--mapper 31 --frames 8 --reset-at 2 --reset-at 4"
	[32in1]="--mapper 14 --frames 8 --reset-at 2 --reset-at 4"
)
declare -A EXP=([mc2k]=15 [mc4k]=15 [mc8k]=15 [32in1]=15)
NAMES=("$@")
[ ${#NAMES[@]} -eq 0 ] && NAMES=(2k cv 4ksc f8 f6 f4 f8sc f6sc f4sc fa fa2 e0 3f 3e fe e7 f0 ua wd ef efsc \
	sb128 sb256 0840 fc df dfsc bf bfsc p2 cty mc2k mc4k mc8k 32in1)
pass=0; fail=()
for n in "${NAMES[@]}"; do
	set -- ${V[$n]}
	[ -n "$1" ] || { echo "unknown test $n"; exit 2; }
	src=$1; shift
	(cd $SRC && dasm $src.asm -f3 -v0 "$@" -o../gb/bs_$n.a26 -l../gb/bs_$n.lst > ../gb/bs_$n.log 2>&1) \
		|| { echo "== $n: dasm failed"; cat $OUT/bs_$n.log; fail+=($n); continue; }
	r=$(./run_sim.sh $OUT/bs_$n.a26 --frames 4 ${OPT[$n]} --sample-line 70 --expect-colour ${EXP[$n]:-63} | grep -v JOB-STAGE)
	if echo "$r" | grep -q '^PASS'; then
		pass=$((pass + 1)); echo "== $n: PASS ($(echo "$r" | sed -n 's/.*\(mapper [0-9]* (detected [0-9]*)\).*/\1/p'))"
	else
		fail+=($n); echo "== $n: FAIL"; echo "$r" | sed 's/^/   /'
	fi
done
echo "passed $pass, failed ${#fail[@]}: ${fail[*]}"
[ ${#fail[@]} -eq 0 ]
