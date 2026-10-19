#!/bin/bash
set -e
cd /home/claude/art/castle2
python3 castle.py
/opt/bpyenv/bin/python bl_build.py 2>&1 | grep -E "TRIS" || true
G=/home/claude/chronicle-clash-mg3d
cp out/game_skycitadel_lite.glb $G/assets/ruin2/skycitadel.glb
cp out/game_skycitadel_col.glb $G/assets/ruin2/skycitadel_col.glb
cp out/route2.json $G/assets/ruin2/route2.json
cd $G
timeout 300 xvfb-run -a godot --headless --path . --import >/dev/null 2>&1 || true
timeout 900 xvfb-run -a godot --audio-driver Dummy --rendering-driver opengl3 --path . -- --autotest --quit-after-test --ruin-only --shots=/tmp/claude-0/sp/shots 2>&1 | grep -iE "PASS|FAIL|STUCK|SCRIPT ERROR|RESULT|JUMP|ROUTE STEP" | head -40
