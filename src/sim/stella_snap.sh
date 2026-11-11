#!/bin/bash
# A reference frame from Stella (6.7): stella_snap.sh ROM OUTDIR [SECONDS]. Runs Stella under a
# virtual X server (xvfb-run, so nothing opens on the desktop), with its own config in OUTDIR/base
# (the user's ~/.config/stella is not touched), presses the snapshot key F12 after SECONDS
# (default 3), quits. The PNG (320 x 228, the visible area at 1x) lands in OUTDIR.
# The debugger script route (frame N / saveSnap) does not work: saveSnap runs before the frames.
ROM=$(realpath "$1"); OUT=$(realpath -m "$2"); T=${3:-3}
mkdir -p "$OUT/base"
exec xvfb-run -a -s "-screen 0 1280x1024x24" bash -c '
	SDL_AUDIODRIVER=dummy stella -basedir "$2/base" -snapsavedir "$2" -sssingle 1 -ss1x 1 -uimessages 0 \
		-confirmexit 0 -exitlauncher 0 "$1" > "$2/stella.log" 2>&1 &
	P=$!
	sleep "$3"
	W=$(xdotool search --sync --onlyvisible --pid $P 2>/dev/null | head -1)
	xdotool key --window "$W" F12
	sleep 1
	kill $P 2>/dev/null; wait $P 2>/dev/null
	ls "$2"/*.png' _ "$ROM" "$OUT" "$T"
