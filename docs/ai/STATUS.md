# Status

**What actually exists in the code today.** This is deliberately *not* the roadmap - the roadmap
in [README.md](../../README.md) says what is planned and in which version. This page says what an
AI can rely on right now.

> Last reviewed: 2026-10-11. If you change behaviour, update this page in the same change.

Legend: `done` · `partial` · `stub` · `missing`

---

## 1. Systems

| System                                      | State   | Reality check                                                       |
|---------------------------------------------|---------|----------------------------------------------------------------------|
| [Player movement](systems/player.md)        | done    | Walk, run, gravity, head bob, footsteps                               |
| Jumping                                     | partial | Works via the built-in `ui_accept`; no rebindable `jump` action       |
| [Wieldables](systems/player.md#7-wieldables)| partial | Only `wield_push` is used, only in the frontrooms                     |
| [Voice + subtitles](systems/ui_subtitles.md)| done    | Queue, `.srt` parsing, synced playback                                |
| [Audio reverb](systems/audio.md)            | partial | `SoundController` drives one reverb bus; no mixer, no settings        |
| [Physics sounds](systems/audio.md)          | done    | Slide and impact sounds on rigid bodies                               |
| [Triggers](systems/interaction.md)          | done    | Enter / leave / look-at conditions with delays                        |
| [Doors](systems/interaction.md)             | done    | Proximity opening with side detection                                 |
| [Level transitions](systems/level_flow.md)  | partial | Works, but the transition scene path is hardcoded                     |
| [Map generation](systems/map_generation.md) | partial | Infinite chunks work; most biomes are not implemented                 |
| [Utils](systems/utils.md)                   | done    | Math, node lookup, screen fades. `NodePool` exists but is unused      |
| [Tooling](systems/tooling.md)               | done    | Static check and asset parsing both work                              |

## 2. Scenes

| Scene                | State   | Reality check                                                    |
|----------------------|---------|-------------------------------------------------------------------|
| `frontroom_0`        | partial | Walkable, boxes pushable, voice recorded, fall to `lvl_0` works   |
| `lvl_0`              | partial | Infinite walkable lobby with static chair/trash-bin clutter; **no exit, no biomes, no events** |
| `menu_intro`         | stub    | Black screen + title label                                        |
| `menu_loading`       | stub    | Near-identical copy of `menu_intro`                               |
| `menu_ui`            | partial | Subtitle label only                                               |
| `test_0`             | sandbox | Raytraced audio test bed, not part of the game                    |

## 3. Does not exist at all

Do not assume any of these. They are named in `README.md` but have **zero code**:

| Area            | Missing                                                             |
|-----------------|----------------------------------------------------------------------|
| Progression     | Save games, main menu, pause, settings                               |
| Survival        | Health, damage, death, hunger, inventory, almond water               |
| Entities        | Every entity: Hounds, Smilers, Facelings, Clumps, Jerry, Red Knight  |
| M.E.G.          | Bases, trading, the Explorer Device (phone), the narrator            |
| Multiplayer     | Server mode (`--server`), networking of any kind                     |
| World mechanics | Non-euclidean geometry, swimming, gravity changes, vehicles, filters |
| Levels          | Everything past `lvl_0`                                              |

## 4. Known issues and sharp edges

These are real, verified, and will bite an unsuspecting contributor.

| # | Issue                                                                                                                 | Where                            |
|---|-----------------------------------------------------------------------------------------------------------------------|----------------------------------|
| 1 | `run/main_scene` points at `lvl_0.tscn`, so the game boots mid-story instead of at the frontrooms                     | `project.godot`             |
| 2 | `lvl_0` has no exit - the player can never leave it                                                                   | `scenes/lvl_0/`                  |
| 3 | The transition scene path is hardcoded inside the shared transition code                                              | `assets/scripts/level_transition.gd` |
| 4 | Jumping is bound to the built-in `ui_accept`; there is no rebindable `jump` action                                    | `project.godot`                  |
| 5 | `INTRO_WAIT_TIME` is `0.0`, so the intro screen is skipped                                                            | `scenes/frontroom_0/frontroom_0.gd` |
| 6 | `NodePool` is dead code - nothing uses it, and it pre-allocates 20000 instances per template                          | `assets/scripts/utils/node_pool.gd` |
| 7 | The housemate is "Jen" in the frontrooms script table but "Jen" in the recorded audio                                 | `scenes/frontroom_0/docs/SCRIPT.md` |
| 8 | Two `lvl_0` voice lines have no `.srt`: `voice_anybody_there`, `voice_bad_taste`                                      | `scenes/lvl_0/voice/`            |
| 9 | `voice/lossless_to_ogg_for_import.sh` appears to duplicate what `tools/parse.sh` does                                 | `scenes/frontroom_0/voice/`      |
| 10 | `menu_intro` and `menu_loading` are duplicates of each other                                                          | `scenes/menu_*/`                 |
| 11 | `MIN_IMPULSE_FOR_BONK` is declared but never read, so impact sounds ignore impulse                                    | `assets/scripts/physics_sounds.gd` |
| 12 | `HANDS_APPEAR_DURATION` is declared but never read                                                                    | `assets/scripts/player.gd`       |
| 13 | `part_arch_i_mirror.tscn` and `part_arch_e.tscn` are never placed by the generator                                    | `scenes/lvl_0/`                  |
| 14 | `scenes/lvl_0/docs/TECHNICAL.md` is stale - it names `generate_level.gd` and `part_1x1_wall`, neither of which exists | `scenes/lvl_0/docs/` |
| 15 | `PlacedTile` stores one `angle` for every model on a tile, so a chair/trash-bin prop overwrites the angle its tile's floor/ceiling model renders with (harmless today since those are rotationally symmetric, but blocks a future non-symmetric prop without a rework) | `scenes/lvl_0/lvl_0.gd` |

## 5. Suggested next steps

Ordered by how much they unblock, not by the roadmap.

1. **Give `lvl_0` an exit.** Without it the game has no second act. See
   [lvl_0 SPEC section 4](../../scenes/lvl_0/docs/SPEC.md).
2. **Point `run/main_scene` back at the frontrooms** once `lvl_0` is stable enough to be entered
   normally, so the whole flow is exercised every run.
3. **Finish the `lvl_0` *Must* biomes** listed in
   [DESIGN.md](../../scenes/lvl_0/docs/DESIGN.md) - the level is currently one texture.
4. **Make the transition scene a parameter** instead of a hardcoded path, so a second transition
   is possible at all.
5. **Decide the health/entity ordering** flagged in
   [lvl_1 spec section 6](levels/planned/lvl_1.md) before starting any Class 2 level.

---

## How to update this page

- Change a system's row the moment its capability changes, not "later".
- Add a row to section 4 when you discover a sharp edge; remove it when you fix it.
- Never move a feature from section 3 into section 1 without a spec to back it up.
