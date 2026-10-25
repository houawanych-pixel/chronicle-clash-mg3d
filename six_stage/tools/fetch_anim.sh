#!/usr/bin/env bash
# Pull private Mixamo-derived clips.json into six_stage/assets/anim/ for local/PC builds.
# Needs read access to houawanych-pixel/hovagi-anim-private (gh auth or git credentials).
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
git clone --depth 1 -q https://github.com/houawanych-pixel/hovagi-anim-private.git "$TMP/repo"
mkdir -p "$HERE/assets/anim"
cp "$TMP/repo/assets/anim/clips.json" "$HERE/assets/anim/clips.json"
echo "Copied clips.json -> $HERE/assets/anim/clips.json"
