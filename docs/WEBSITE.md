# chronicleclashgame.com

The domain is served by this repo through GitHub Pages (`.github/workflows/deploy.yml`, every push to `main`).

| Path | What |
|---|---|
| `/` | Homepage: `site/index.html`, `site/site.css`, `site/site.js` |
| `/play/` | The Godot game (Gameplay Test: Sky Citadel, Forest Escape) |
| `/play/?village` | Same game, opened on the Village Simulation |

Old links such as `/?village` forward to `/play/?village`.

## Editing
- Text lives in `site/index.html`. The two beta cards are written once in the `<template id="tests-tpl">` block; the Beta section and the dialog both use it.
- Images are in `site/img/` as WebP at two widths (`name-400.webp`, `name-534.webp` …). Swap a file with the same name to change art.
- Original full-size artwork is kept in `art/originals/` (not deployed). The site art is cut from the owner's four concept screens in `art/originals/mockups/` (hero, world, meet Lance & Elyza, choose your test), with all text rebuilt as real HTML.
- Fonts are self-hosted in `site/fonts/` (Cinzel, Source Sans 3; OFL licences included).
- `site/.gdignore` and `art/.gdignore` keep Godot from importing the website files into the game.

## Canon used on the site
From the Canon Register and the approved character cards: Lance (Key NPC, elf) is mute, so the site gives him no lines; Elyza (Key NPC, princess) is spelled E-L-Y-Z-A; a dormant Guardian awakens through her at the Grand Festival in Elindor. The Shadow Realm is labelled as a world concept not in the beta. Beta screenshots use placeholder models and are labelled as such.

## Test
Playwright scripts used for the release check: layout at 1440, 390 and 360 px, no sideways scroll or clipped text, dialog (keyboard, Esc, close, tap outside), scroll reveals forwards and backwards, reduced motion, images, console errors, and both launches reaching the game.
