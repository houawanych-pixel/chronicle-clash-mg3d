#!/bin/bash
set -e
cd /home/claude/art/castle2
python3 castle3.py
/opt/bpyenv/bin/python bl_build.py 2>&1 | grep -E "TRIS|Error|failed" || true
cp out/CC_castle_skycitadel_vis.glb /tmp/claude-0/sp/gp/castle.glb
cd /tmp/claude-0/sp/gp
timeout 300 xvfb-run -a godot --headless --path . --import >/dev/null 2>&1 || true
timeout 300 xvfb-run -a godot --audio-driver Dummy --rendering-driver opengl3 --path . -s ortho.gd -- /tmp/claude-0/sp/gp/shots res://castle.glb raw 2>&1 | grep -i "script error" || true
python3 overlay.py ${1:-ov}
