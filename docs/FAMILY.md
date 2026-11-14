# Living Village: families and growing children

Branch `feature/living-village-family`. Not merged, not deployed: the brief asks for a review first.

The existing village is unchanged in how it plays. Village Square and Mill Lane keep the same cast, routines, navigation, chat and save. Frogtown has this module switched off. Families are added on top: couples, home visits, births, children who grow up over about 60 real days, and parents who leave work to look after them.

## What is built and what is only proposed

| Part | Status |
|---|---|
| Family, NPC, relationship and pregnancy records, keyed by stable ids | Built and tested |
| Consent (both adults must agree), kinship and age checks | Built and tested |
| Private home visit: walk home, door shuts, privacy fade, muffled sound on a low-pass bus, then routines resume | Built and tested. The sound clip is missing (see assets) |
| Pregnancy with configurable chance and duration, one baby per pregnancy, birth at the due time | Built and tested |
| Aging from real timestamps, including offline catch-up, with no duplicate transitions | Built and tested |
| Children walking the village nav mesh at every stage, with stage-specific poses | Built and tested. The bodies are placeholders |
| Parent needs (feeding, bedtime, park walk, carrying a newborn, teaching, family meal) that interrupt work and then resume it | Built and tested |
| Child day plans (play, lessons, apprenticeship, meals, naps); children never get work or combat jobs | Built and tested |
| Echo Vision: bounded family context, compact memories, AI can only propose a memory, per-minute call budget | Built and tested (game side; the JS change is checked by loading it, not with a live brain) |
| Server-authoritative persistence: reference server, file store, two-client and restart safety | Built and tested locally. **Not deployed anywhere, and the game does not connect to it yet** |
| Two-game-client sync | Tested with two headless game processes against the local server. Not yet tested in browsers on the live site |
| Zoo visits, outings, friendships between children, adoption for couples who can't carry | Proposed only (`family_activities.FUTURE_KINDS`) |
| Death causes and NPC replacement | Records support death (admin only on the server). Nothing in the game kills villagers. Replacement is proposed only |

Multiplayer is **not** live. The game still plays from the local save. The server and its two-client tests show how it will work, but the live site has no family server yet.

## Files

New:
- `scripts/cc/family/family_config.gd`, `data/cc/family/family_config.tres`: every number (stage days, heights, chances, cooldowns, limits, budgets)
- `scripts/cc/family/family_profile.gd`: record shapes and the FNV hash shared with the server
- `scripts/cc/family/family_service.gd`: the rules, built around events (validation, idempotent apply, `sync()` for births and aging)
- `scripts/cc/family/child_growth.gd`: life stages from real timestamps
- `scripts/cc/family/pregnancy_service.gd`: conception dice and pregnancy records
- `scripts/cc/family/family_activities.gd`: child day plans and parent needs
- `scripts/cc/family/family_context.gd`: Echo Vision context, proposal checks, AI budget
- `scripts/cc/family/family_save.gd`: local save, migration, seeding from the cast
- `scripts/cc/family/child_anim.gd`: animation states, the asset manifest, the newborn bundle
- `scripts/cc/family/child_villager.gd`: children as villagers (extends `Villager.gd`)
- `scripts/cc/family/village_family.gd`: glue to the village (bodies, needs, home visits, sim levels, chat)
- `scripts/cc/family/family_net.gd`: game client for the server (not switched on)
- `scripts/cc/family/tests/family_tests.gd`, `scenes/systems/cc_family_test.tscn`: unit tests, plus seed export, parity and net-client modes
- `scripts/cc/family/tests/family_village_tests.gd`: tests in the real village
- `data/cc/family/names.json`: original given names and traits
- `server/family/`: `server.js`, `rules.js` (a port of the rules), `store.js`, `config.json`, `seed_state.json`, and tests (`test/*.test.js`, `test/scenario.json`). `server/.gdignore` keeps the server folder out of Godot.

Changed (additions only; old behaviour is kept when the family module returns nothing):
- `scripts/citadel/Village.gd`: creates the family module, plus hooks in `activity_for`, `lines_for`, `enter`, `spawn_villagers`, `save_now` and `progress`
- `scripts/citadel/Villager.gd`: `family:*` and `visit` activities, `stays_inside_for()`, `inside_at` (they come out of the door they went in), and the carry pose with the baby bundle
- `scripts/citadel/VillageChat.gd`: adds the family context, skips infants for TALK, and passes `propose` events to the family rules
- `scripts/citadel/VillageSave.gd`: `clear()` also clears the companion family file
- `scripts/citadel/Frogtown.gd`: `family_enabled()` returns false
- `scripts/citadel/AutoTest.gd`: adds the `--family-only` and `--village-only` flags
- `web/village_chat.js`: family lines in the prompt, the `[remember: ...]` proposal tag, and the AI call budget
- `export_presets.cfg`: includes `data/cc/family/names.json` in web builds

## Save schema (local file `user://village_save_family.json`, server `world.json`)

```
{ "schema": 1, "world_id": "cc_village", "rev": int,
  "npcs":   { npc_id: { npc_id, name, birth_timestamp, life_stage, parent_ids, family_id,
                        personality, appearance_traits, current_job, current_activity, alive,
                        health_state, memory_summary, memories[<=8], stage_log[{stage, at}],
                        sex, can_carry, home_id "<block>/<door>", location, established,
                        age_locked, recruited_by, died_at, last_birth_at } },
  "families": { family_id: { family_id, parent_ids, child_ids, partner_relationships,
                             home_id, family_relationship_history[{at, kind, ids}] } },
  "relationships": { "a|b": { key, a, b, kind, consent{id: true}, since, last_visit_at, established, notes } },
  "pregnancies": { pregnancy_id: { carrier_id, partner_id, family_id, conceived_at, due_at, status, baby_id } },
  "applied": { event_id: rev }, "applied_order": [event_id] }
```

Times are unix seconds. A baby's id comes from its pregnancy (`npc_preg_<event id>`), so it is unique and the same on every machine.

Migration:
- **No family file** (schema 0, every save before this branch): the 12 cast members are registered as established adults with locked ages. Pip is registered as the child he is written as. Only the marriage the text states (Ada and Rolf) becomes a relationship. Pip gets no parents, and Finn's crush on Lia stays a note. Nothing else is invented.
- **Older schema-1 file:** missing fields are filled from defaults, and numbers that JSON turned into floats are made ints again.
- **File from a newer schema:** it is not touched, and family features pause.
- The village save (`user://village_save.json`) keeps its own format.

## Server (reference, not deployed)

Run it with `node server/family/server.js`. Settings come from the `PORT`, `FAMILY_DATA` and `FAMILY_ADMIN_TOKEN` environment variables. It has no dependencies.

Endpoints:
- `GET /v1/state?since=rev`
- `POST /v1/events {events:[{id, type, args}]}`
- `GET /v1/can_visit?a=&b=`
- `GET /health`

How it stays consistent:
- One queue per world, so concurrent requests can't interleave.
- Event ids make every send safe to repeat. A resent accepted event returns `duplicate`. A resent refused event is checked again, because refusals are not recorded.
- Server time replaces client time.
- Births and aging come only from the server clock.
- Clients can't send births. Creating NPCs and recording deaths need the admin token.
- Writes are atomic (temp file, fsync, rename).
- Population and family limits count active pregnancies.
- Body size and batch size are capped.
- No AI key exists on this server. Echo Vision keeps its own proxy.

## Echo Vision

The chat code is not rebuilt. `VillageChat.context()` gains a `family` field: stage, parents, partner, children, activity, place, a one-line world summary, and a memory summary. Every field is cut to a fixed length. The prompt tells toddlers and children to talk their age, and tells everyone never to describe romance.

The brain can only add `[remember: ...]`. The game checks it (`validate_proposal`, which allows memories only) and applies it as a normal event. Anything else it proposes, such as pregnancy, birth, death, aging, a partner, a job or recruitment, is refused. Chat calls are capped per minute (`ai_calls_per_minute`). Newborns, crawling infants and early walkers don't open a chat.

## Simulation levels

| Level | What runs |
|---|---|
| ACTIVE | Bodies in the loaded block: navigation, poses, and needs that interrupt routines. Poses stop beyond 38 m, as for the cast. |
| BACKGROUND | Records in other blocks. `sync()` advances births and aging every `background_tick_seconds`, from timestamps. |
| UNLOADED | The game is closed. On the next load, `sync()` catches up once. |

Bodies are capped at `max_spawned_children` per block. Records are never capped or deleted, and no NPC is killed to save memory. No AI call is made unless the player chats.

## Tests run (all executed on this branch)

| Suite | Command | Result |
|---|---|---|
| Family unit | `godot --headless res://scenes/systems/cc_family_test.tscn -- --quit-after-test` | **FT 49/49** |
| Family in the real village | `godot --headless res://scenes/citadel.tscn -- --autotest --family-only --quit-after-test` | **26/26** |
| Existing village + Frogtown (regression) | `... --autotest --village-only --quit-after-test` | **52/53**. The one failure ("leaving returns the player to that house's door") also fails on `main` with the same numbers, so it is not from this branch |
| Server: two HTTP clients, races, resends, out-of-order, restart, population, death/recruit | `cd server/family && npm test` | **pass** |
| Server: two headless game processes at once (`family_net.gd`) | same, with `GODOT=...` set | **pass** (3 runs) |
| Game rules = server rules (one scenario through both, plus config match) | same, with `GODOT=...` set | **pass**. A deliberate one-word rule change made it fail, as it should |

How the 18 brief tests map:

| Brief test | Covered by |
|---|---|
| 1 | FV 1 |
| 2 | FV 2 |
| 3 | FV 3 |
| 4 | FV 4 |
| 5 | FT 5, FV 5/16 |
| 6 | FT 6, FV 6 |
| 7 | FT 7 |
| 8 | FT 8 |
| 9 | FT 9 |
| 10 | FT 10, FV 3 |
| 11 | FT 11 |
| 12 | FT 12, FV 12 |
| 13 | FT 13, FV 13 |
| 14 | FT 14, FV 14 |
| 15 | the server two-client and game-client tests |
| 16 | FT 16, FV 5/16, server restart |
| 17 | FT 17, server |
| 18 | FT 18, server |

Not tested: phones, real browsers talking to a deployed server, and the live Echo Vision brain answering with the new context.

## Missing assets

Every item below uses a placeholder today. Nothing points to a file that doesn't exist.

- [ ] Child body models by stage: crawling infant, early walker, toddler, child, adolescent. **Today they are the adult village models shown at a smaller height. That is a stand-in, not a finished child model.**
- [ ] Newborn model, or a swaddled-baby prop. Today it is a two-shape bundle mesh.
- [ ] Animation clips for `newborn_idle`, `newborn_cry`, `parent_carry`, `crawl`, `stand`, `first_steps`, `toddler_walk`, `child_walk`, `child_play`, `teen_walk`, `adult_walk`. Today they are code-made poses (`child_anim.MANIFEST`). Clips would go in the manifest's `clip` field once added.
- [ ] Soft laughter loop for home visits, non-explicit and licensed or original. Set `home_audio_path` once it exists. Today a caption shows instead.
- [ ] Baby cry and child voice barks (optional).
- [ ] A park or play area, a school spot, and a zoo. There are no such places in the village yet. Lessons use the bench area and play uses the plaza.

## Limitations

- The 12 written cast members don't age. Their ages aren't written anywhere, so `age_locked` keeps them as they are. Only village-born people age.
- A couple needs one partner who can carry to have a baby. Same-sex couples can partner and visit but can't have children yet. Adoption is proposed, not built.
- Born adults walk the village as wanderers. Giving them jobs and homes of their own isn't built yet.
- Parents' homes are fixed by the family record. Rolf still sleeps in his own house and comes to Ada's for family needs.
- The home-visit trigger is evening (19:00–21:00), at most once per village day for each couple, and skipped while parents are busy. There is no player-facing UI for it.
- Two copies of the rules exist: GDScript for offline play and JS for the server. The parity test is what keeps them equal.
- On the web the local save lives in browser storage, as the village save already does.
- Unrelated finding: `export_presets.cfg` only exports listed JSON files, and `data/cc/*.json` (items, ingredients, fuel and others used by the survival systems) isn't listed. On the live web build those files are probably missing. This branch doesn't change that.

## Integration steps (to go online later)

1. Deploy `server/family` somewhere with a disk, such as a small VM or a container with a volume. Set `FAMILY_ADMIN_TOKEN`. Keep HTTPS in front of it, and allow the site's origin (CORS headers aren't added yet).
2. Add a `server_url` to `family_config.gd`. In `village_family.gd`, when it is set, create `family_net.gd`. Send player-made events through `net.queue()` instead of `svc.apply()`, then call `net.flush()` and `net.pull()` every `background_tick_seconds` and on load.
3. Keep the local service as the offline fallback and for instant checks (`visit_block()` before walking a couple home).
4. Test two browsers on the live site before calling it multiplayer.

## Reuse in Homelancer

`family_service`, `child_growth`, `pregnancy_service`, `family_activities`, `family_context`, `family_save` and the server know nothing about Chronicle Clash. Text lives in `names.json` and the config. Only `village_family.gd`, `child_villager.gd` and the seed (`seed_events`) touch this village. Homelancer would replace those three with its own station or crew glue and its own names file.

## Originality

All code, names and text here are original to this project. No Sims code, characters, models, voices or animations were used. No third-party code was added: Godot built-ins only, and the server uses only Node's standard library.
