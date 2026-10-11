# Spec: Level 0 - The Lobby

> **Wiki:** <https://backrooms-wiki.wikidot.com/level-0>
> **Scene:** `scenes/lvl_0/lvl_0.tscn`
> **Entry script:** `scenes/lvl_0/lvl_0.gd` (`class_name Lvl_0`)
> **State:** in-progress
> **Accuracy estimate:** ~35% - the endless yellow room is there, the biomes, events and exit are not

## 1. One paragraph pitch

The player falls out of the frontrooms and faceplants into damp, salty carpet. Around them is an
endless maze of mono-yellow wallpaper, soaked carpet and buzzing fluorescent lights, with no
horizon and no landmark. There is nothing to fight and nothing to collect - the only thing to do
is walk, listen, and slowly understand that the building does not end.

## 2. Canon summary

| Property            | Value                                                                 |
|---------------------|-----------------------------------------------------------------------|
| Survival difficulty | Class 1 - safe, stable, almost no entities                            |
| Environment         | Endless randomly segmented rooms, mono-yellow wallpaper, damp carpet  |
| Lighting            | Buzzing fluorescent ceiling lights, some flickering, never fully dark |
| Sound               | Constant fluorescent hum; occasional scratching behind walls          |
| Entities            | None documented at this level (rare Hound sightings in canon)         |
| Resources           | None; no almond water on this level                                   |
| M.E.G. presence     | None                                                                  |

Wiki facts already recorded in [DESIGN.md](DESIGN.md): roughly 50,000 people go missing on Earth
each year, around 20,000 of them end up here; 60-70% of those who die in the Backrooms die on
Level 0.

## 3. Entrances

| From                 | How                                                               | Implemented |
|----------------------|-------------------------------------------------------------------|-------------|
| `scenes/frontroom_0` | No-clipping through the floor; the fall is continued in `entry_tube.tscn` | yes   |
| Direct boot          | `project.godot` `run/main_scene` currently points straight here (dev shortcut) | yes |

The player spawns at roughly `y = 15` and falls; `entry_tube.tscn` covers the drop so the player
cannot see the unfinished chunk boundary while landing.

## 4. Exits

| To      | How                                     | Chance / condition                  | Implemented |
|---------|-----------------------------------------|-------------------------------------|-------------|
| `lvl_1` | A "glitched" wall segment the player can walk through | Rare; must be findable within a reasonable play session | **no** |

Canon says finding an exit can take days. That is not playable, so the discovery rate must be
compressed. **Open question, see section 11.** There is currently **no way to leave Level 0** -
it is a dead end.

## 5. Hazards and rules

Level 0 is deliberately almost harmless. The pressure is psychological, not mechanical.

- No entities, no damage, no hunger, no sanity meter. Do not add any without updating this spec.
- The player can become permanently lost - that is the intended failure state.
- Walking on wet carpet must sound different from walking on dry carpet (planned, 0%).
- Blackout biomes remove the ceiling lights, so the player loses all orientation (planned, 0%).

## 6. Player capabilities required

| Capability                  | System spec                                                | Exists |
|-----------------------------|------------------------------------------------------------|--------|
| Walking / running / gravity | [player](../../../docs/ai/systems/player.md)                | yes    |
| Footstep sounds per surface | [player](../../../docs/ai/systems/player.md)                | partial - one set only |
| Inner voice + subtitles     | [ui_subtitles](../../../docs/ai/systems/ui_subtitles.md)    | yes    |
| Reverberant shouting        | [audio](../../../docs/ai/systems/audio.md)                  | partial |
| Leaving to another level    | [level_flow](../../../docs/ai/systems/level_flow.md)        | yes, unused here |

## 7. Technical approach

Fully procedural and effectively infinite. `MapGenerator` produces tile data on a worker thread;
`Lvl_0` instantiates `part_*.tscn` pieces around the player, graphics far out and collision only
nearby, using `duplicate()` and `queue_free()` directly (the `NodePool` utility is **not** used
here). Details in
[TECHNICAL.md](TECHNICAL.md) and [map_generation](../../../docs/ai/systems/map_generation.md) -
do not duplicate them here.

## 8. Assets present

| Asset                                   | Type     | Status |
|-----------------------------------------|----------|--------|
| `part_1x1_floor.tscn`                   | model    | done   |
| `part_1x1_ceiling.tscn`                 | model    | done   |
| `part_1x1_ceiling_light.tscn`           | model    | done   |
| `part_1x1_ceiling_light_blinking.tscn`  | model    | done   |
| `part_wall_x.tscn`                      | model    | done   |
| `part_arch_i.tscn`, `part_arch_i_mirror.tscn`, `part_arch_e.tscn` | model | done |
| `entry_tube.tscn`                       | model    | done   |
| `wallpaper.gdshader` / `wallpaper_pattern.png` | shader | done |
| `carpet.gdshader`, `carpet_fur.gdshader`| shader   | done   |
| `ceiling_tile.gdshader`                 | shader   | done   |
| Pillar biome props                      | model    | missing |
| Manila room props                       | model    | missing |

## 9. Audio

| Kind       | File                                      | Status |
|------------|-------------------------------------------|--------|
| Ambience   | `fluorescent-light-buzz.mp3`              | in scene |
| Ambience   | `bg_outside.mp3`                          | present, use unclear |
| One shot   | `fluorescent-lamp-flick.wav`              | present |
| Voice      | `voice/*.flac` -> `voice/gen/*.ogg` (13 lines) | recorded |
| Subtitles  | `voice/voice_*_sub_en.srt`                | present for most lines |

Two of the 13 voice lines have **no `.srt` yet**: `voice_anybody_there` and `voice_bad_taste`.
Narration text lives in [SCRIPT.md](SCRIPT.md).

## 10. Acceptance criteria

- [ ] The player enters from the frontrooms and lands without seeing unloaded geometry.
- [ ] The level is walkable in any direction for at least 10 minutes with no visible seam,
      hitch, or missing collision.
- [ ] All biomes listed as *Must* in [DESIGN.md](DESIGN.md) are generated and visually distinct.
- [ ] Carpet footstep sounds differ between wet and dry areas.
- [ ] The inner-voice sequence from [SCRIPT.md](SCRIPT.md) plays in order, with subtitles.
- [ ] A glitched wall exists and leads to `lvl_1`.
- [ ] `tools/static_check.sh` passes.
- [ ] `scenes/lvl_0/tests/test_map_gen.sh` produces a `result.png` with no obvious artefacts.

## 11. Open questions

- How is the glitched-wall exit made findable in minutes instead of days?
  **decision:** TBD. Candidates: guarantee one within N chunks of the spawn, or increase the
  spawn chance the longer the player has been in the level.
- Should the "layout changes where you do not look" rule apply to chunks the player has already
  walked through, given that chunks are cached? **decision:** TBD.
- `bg_outside.mp3` sits in this level's folder but the level has no outside. Leftover, or
  intended for a biome? **decision:** TBD.

## 12. Related documents

- [DESIGN.md](DESIGN.md) - MoSCoW feature list and progress
- [TECHNICAL.md](TECHNICAL.md) - how the level is built. **Stale**: it refers to
  `generate_level.gd` and `part_1x1_wall`, neither of which exists any more. Until it is
  rewritten, trust [map_generation](../../../docs/ai/systems/map_generation.md) instead.
- [SCRIPT.md](SCRIPT.md) - narration
- [Map generation system](../../../docs/ai/systems/map_generation.md)
- [AI documentation index](../../../docs/ai/README.md)
