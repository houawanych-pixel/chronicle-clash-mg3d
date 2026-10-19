#!/bin/bash
set -e
cd /home/claude/art/castle2
python3 route3.py 2>&1 | grep -v Warn | tail -4
python3 castle3.py 2>&1 | grep -v Warn | tail -1
/opt/bpyenv/bin/python bl_build.py 2>&1 | grep -E "TRIS" || true
G=/home/claude/chronicle-clash-mg3d
cp out/game_skycitadel_lite.glb $G/assets/ruin3/skycitadel.glb
cp out/game_skycitadel_col.glb $G/assets/ruin3/skycitadel_col.glb
cp out/route3.json $G/assets/ruin3/route3.json
cd $G
timeout 300 xvfb-run -a godot --headless --path . --import >/dev/null 2>&1 || true
timeout 1500 xvfb-run -a godot --audio-driver Dummy --rendering-driver opengl3 --path . -- --autotest --quit-after-test --ruin-only --shots=/tmp/claude-0/sp/shots $@ 2>&1 | grep -iE "PASS|FAIL|STUCK|SCRIPT ERROR|Parse Error|RESULT|JUMP|ROUTE STEP|^STEP" | head -60
