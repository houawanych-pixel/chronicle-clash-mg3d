# Runtime verification

Use Godot 4.3. Tests run the actual scene; camera/HUD checks require a rendered display (native X11 or Xvfb), not only `--headless`.

Example on Linux with Xvfb installed:

```sh
xvfb-run -a godot --path . --audio-driver Dummy --script res://tests/controls_test.gd
```

Run suites: `controls`, `movement`, `combat`, `equipment`, `enemies`, `swim`, `arsenal`, `room`, `touch`, `update`, `build05`, each named `tests/<suite>_test.gd`. Each prints PASS/FAIL and a RESULT count and exits nonzero on assertion failure. Native suite totals in this delivery are 258 passing assertions.

Several tests deliberately manipulate positions and advance real physics to isolate collisions and state transitions. They are not a substitute for player usability review. Native runs sometimes produce an exit-time resource diagnostic; those logs are retained rather than filtered.

The enemies suite writes test rank/unlock records to Godot's user-data save. Use an isolated user-data environment when validating a personal play session.

For rendered browser verification:

```sh
godot --headless --path . --export-release Web /absolute/export/index.html
WEB_ROOT=/absolute/export CHROMIUM_BIN=/absolute/chromium node tests/web_test.cjs
```

Install Playwright in the Node environment first. The harness hosts locally with COOP/COEP, runs the actual exported WASM/PCK, sends touch events and saves screenshots. It uses software WebGL; its timing is not a Samsung performance benchmark. Inspect the screenshots, not only exit status. Output path may be set with `WEB_TEST_OUTPUT`.

`assets/verified_features.json` drives the exported checklist. Update it only after the corresponding runtime checks pass. Keep partial implementations marked UNFINISHED and name the missing behavior.
