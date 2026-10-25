# Pull private Mixamo-derived clips.json into six_stage\assets\anim\ for local/PC builds.
# Needs read access to houawanych-pixel/hovagi-anim-private (gh auth or git credentials).
$ErrorActionPreference = "Stop"
$Here = Split-Path -Parent $PSScriptRoot
$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("hovagi-anim-" + [guid]::NewGuid())
try {
  git clone --depth 1 -q https://github.com/houawanych-pixel/hovagi-anim-private.git "$Tmp"
  if ($LASTEXITCODE -ne 0) { throw "git clone failed" }
  $Dest = Join-Path $Here "assets\anim"
  New-Item -ItemType Directory -Force -Path $Dest | Out-Null
  Copy-Item (Join-Path $Tmp "assets\anim\clips.json") (Join-Path $Dest "clips.json") -Force
  Write-Host "Copied clips.json -> $Dest\clips.json"
} finally { Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue }
