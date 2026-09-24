# Deploy bot handoff — publish branch only

Target repository: `houawanych-pixel/chronicle-clash-mg3d`.
Target branch: `build05`. Do not change `main`, deploy Pages, or touch `castle-rpg-testbed`.

Preferred exact-commit transfer: download `Chronicle_Clash_MG3D_Build05.bundle` from Drive as a binary file. This is an incremental Git bundle based on upstream main at `ea6cc3e`; the receiving repository needs that base commit.

In a clean clone of the MG repo:

```sh
git fetch origin main
git bundle verify /path/to/Chronicle_Clash_MG3D_Build05.bundle
git bundle list-heads /path/to/Chronicle_Clash_MG3D_Build05.bundle
git fetch /path/to/Chronicle_Clash_MG3D_Build05.bundle build05:build05
git switch build05
git status --short
git push -u origin build05
```

If build05 already exists or main has moved, stop and inspect the difference. Do not force-push or silently overwrite another agent's changes. The bundle is based on the merged-grid web fix and must retain it.

Fallback: extract `Chronicle_Clash_MG3D_Build05_Source.zip`, create build05 from the matching MG base, apply the full project tree, inspect the diff, commit, and push build05 only. The bundle is preferable because it preserves the exact reviewed commit.

Report the successful remote branch URL and commit SHA. A Drive upload or local commit is not proof of a GitHub push. Existing Pages workflow runs on main only and has not been changed. Claude should clone build05, independently test, and approve before the separate deploy agent merges it.

Evidence: `BUILD05.md`, native/browser logs, screenshots, and reproducible tests. Builder's results: 112 native assertions and 14 browser checks passed; initial 160 mesh objects; actual 3D scene visually inspected in desktop and phone-sized Chromium. Physical Samsung testing and Android export remain unverified.
