# Build06 handoff to reviewer / deploy bot

Repository: **houawanych-pixel/chronicle-clash-mg3d only**.
Branch: **build06 only**. Do not touch main or castle-rpg-testbed during review.
Base: `2e7ba6325596375e596c44198dfa9877d23cf49b`.

Fetch main history before importing the cumulative bundle. In a clean checkout of this repository:

```sh
git fetch origin main
git bundle verify /path/to/MG_Build06_Final.bundle
git fetch /path/to/MG_Build06_Final.bundle build06:refs/remotes/review/build06
```

If local build06 does not exist, create it from `refs/remotes/review/build06`. If it already exists, switch to it and merge that ref using `--ff-only`; investigate any divergence without force-pushing. Verify the resulting commit and push **build06** to origin. The full source ZIP can also be imported directly into Godot 4.3 without Git.

All checkpoint bundles A through E are on Drive. The final bundle supersedes them and includes all their commits. Native and browser logs, the explicit unfinished feature list and reproducible test instructions are inside the project. Start with README.md and docs/BUILD06.md.

Do not report a live deployment from this handoff: none was performed. After independent review, the deploy agent can use the existing main-branch Pages workflow. Verify export success and actual game rendering at the public URL before calling deployment complete.
