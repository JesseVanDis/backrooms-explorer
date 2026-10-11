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
| Isolation Effect    | No two wanderers can ever find, see, or signal one another in Level 0 - shouting, notes and marking paths all fail; the one exception is the Manila room |
| Entities            | Unconfirmed - no entity has been directly reported, but wanderers describe dark figures stalking the corridors and a feeling of being watched (scopophobia) |
| Resources           | None; no almond water on this level                                   |
| M.E.G. presence     | None in canon - the Manila room only contains written notes/guides, no living person. This game adds a single briefing NPC (nicknamed "the MEG Supplier") who appears there `[interpretation: a deliberate addition replacing the wiki's static notes with a voiced briefing; not a wiki fact]` |

Wiki facts already recorded in [DESIGN.md](DESIGN.md): roughly 50,000 people go missing on Earth
each year, around 20,000 of them end up here; 60-70% of those who die in the Backrooms die on
Level 0.

These facts were re-verified this pass directly against the live wiki
(`backrooms-wiki.wikidot.com/level-0`, `/red-rooms`, `/manila-room`) via search results surfacing
that page's own text, since the `fetch_url` tool itself still fails on every URL including
unrelated ones (not a site-specific issue - see section 11). Level 0's wiki page has since been
revised and retitled "Threshold"; this spec follows that current revision, not the older archived
version.

## 3. Entrances

| From                 | How                                                               | Implemented |
|----------------------|-------------------------------------------------------------------|-------------|
| `scenes/frontroom_0` | No-clipping through the floor; the fall is continued in `entry_tube.tscn` | yes   |
| Direct boot          | `project.godot` `run/main_scene` currently points straight here (dev shortcut) | yes |

The player spawns at roughly `y = 15` and falls; `entry_tube.tscn` covers the drop so the player
cannot see the unfinished chunk boundary while landing.

## 4. Exits

| To           | How                                                      | Chance / condition                                       | Implemented |
|--------------|-----------------------------------------------------------|-----------------------------------------------------------|-------------|
| `lvl_1`      | A flickering wall segment the player can walk through (wiki: "a flickering wall to throw yourself through") | Rare; must be findable within a reasonable play session    | **no** |
| Game Over    | A Hole (floor pit, canon grid-pattern hazard, see section 5) | Common within Hole clusters; walking into one drops the player | **no** |

Canon says finding an exit can take days. That is not playable, so the discovery rate must be
compressed. **Open question, see section 11.** There is currently **no way to leave Level 0** -
it is a dead end.

Holes are canon (the wiki's "Hole Variation": pitch-black floor pits, appearing in grid-pattern
clusters "like the pillars"); what is **not** canon is the outcome of falling in - the wiki only
says no one has reported surviving it. This game interprets that as **not** a second route to
`lvl_1` - falling through a Hole triggers the project's first **Game Over screen** (full overlay,
clickable "Restart from checkpoint" button) instead of a level transition `[interpretation]`. See
[DESIGN.md](DESIGN.md) and
[Save system](../../../docs/ai/systems/save_system.md) for the checkpoint this restarts to, and
[UI & subtitles](../../../docs/ai/systems/ui_subtitles.md) section 6 for the screen itself.

Red Rooms are a related, but separate, dead end: they are reached by turning a corner in Level 0
"completely at random" per the wiki, with warning signs beforehand (see section 5). Once fully
entered, a Red Room has **no walkable exit at all** - the only way out is the `P`-to-restart prompt
described in section 5, not a level transition. This game additionally gates Red Rooms behind a
Manila room visit `[interpretation: the wiki does not describe any such gate - entry is purely
random]`.

## 5. Hazards and rules

Level 0 is deliberately almost harmless for most of the level. The pressure is mostly
psychological, with two deliberate exceptions below.

- No entities, no damage, no hunger, no sanity meter outside of the two exceptions below. Do not
  add any more without updating this spec.
- The player can become permanently lost - that is the intended failure state.
- Walking on wet carpet must sound different from walking on dry carpet (planned, 0%).
- **Blackout zones** remove the ceiling lights entirely, so the player loses all orientation.
  Per the wiki: rough wall textures, an intense silence (the buzzing stops), and recessed floor
  sections that fill with ankle-deep fluid; the advised survival tactic is to sprint towards the
  first glimmer of light or follow any buzzing sound back out. A hand-feel wall shader is the
  planned navigation aid `[interpretation: not a wiki mechanic]` (planned, 0%). See [DESIGN.md](DESIGN.md).
- **Holes** are a canon grid-pattern floor hazard (pitch-black pits, light barely penetrates a few
  feet, cluster in a grid like the Pillars biome, some clusters large/dense enough to make falling
  an "enormous risk"). This game interprets falling in as an instant, unavoidable death (full Game
  Over screen) - the one true "you lose" state in the level `[interpretation: the wiki only says no
  survivors have been reported]`, planned, 0%. See section 4.
- **Red Rooms** are near-impossible to escape per the wiki. Proximity gives a **gradual warning**,
  not an instant transition: carpet becomes thicker, stickier and coarser, the colour hue shifts
  towards red, and sections of wallpaper visibly **peel to reveal crimson underneath** - the player
  should be able to turn back during this transition. Once fully entered, it is an infinite looping
  corridor with no true exit; the only way out is a `P`-to-restart prompt, not walking. This game
  additionally gates first appearance behind a Manila room visit `[interpretation: the wiki says
  entry is simply random]`. Planned, 0%. See [DESIGN.md](DESIGN.md) and
  [npc_bot.md](../../../docs/ai/systems/npc_bot.md).
- The **Manila room** is canonically an 8x8m safe room with written notes/guides and no living
  person; this game adds a one-off briefing NPC on top of that `[interpretation]` and permanently
  stops spawning it once visited once, saved to disk. Planned, 0%.

## 6. Player capabilities required

| Capability                  | System spec                                                | Exists |
|-----------------------------|------------------------------------------------------------|--------|
| Walking / running / gravity | [player](../../../docs/ai/systems/player.md)                | yes    |
| Footstep sounds per surface | [player](../../../docs/ai/systems/player.md)                | partial - one set only |
| Inner voice + subtitles     | [ui_subtitles](../../../docs/ai/systems/ui_subtitles.md)    | yes    |
| Reverberant shouting        | [audio](../../../docs/ai/systems/audio.md)                  | partial |
| Leaving to another level    | [level_flow](../../../docs/ai/systems/level_flow.md)        | yes, unused here |
| Interacting with an NPC/bot | [npc_bot](../../../docs/ai/systems/npc_bot.md) (new)         | **no** |
| Save / checkpoint / restart | [save_system](../../../docs/ai/systems/save_system.md) (new) | **no** |
| Game Over screen + restart prompt | [ui_subtitles](../../../docs/ai/systems/ui_subtitles.md) section 6 (new) | **no** |

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
| Hole biome pass (pitch-black pit mesh/shader, grid-pattern like Pillars) | model/shader | missing |
| Manila room props (8x8m room, manila wallpaper, wooden floor, octagonal table + 2 chairs) | model | missing |
| `part_manila_room.tscn` + MEG Supplier mesh | model | missing |
| MEG Supplier dissolve/clip shader       | shader   | missing |
| `wallpaper_dark_touch.gdshader` (hand-feel) | shader | missing |
| `carpet_wet_shallow.gdshader`           | shader   | missing |
| `wallpaper_peel_red.gdshader` (gradual Red Room approach: peeling wallpaper, carpet/colour shift) | shader | missing |
| Scattered prop pool (chair, trash bin)  | model    | missing |
| Holes Game Over overlay + button        | UI       | missing |
| Red Room restart text prompt            | UI       | missing |

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

Planned, not yet recorded:

| Kind       | File                                      | Status |
|------------|-------------------------------------------|--------|
| One shot   | wet/splash footstep set (Blackout zones)  | missing |
| Ambience   | shallow water loop (Blackout zones)       | missing |
| Ambience   | relaxing piano loop (Manila room, per wiki - isolation hum fades as it starts) | missing |
| Voice      | MEG Supplier's Manila room briefing lines | missing |
| Voice      | Red Room entry line ("oh... the Red rooms he warned about... SHIT!") | missing |

## 10. Acceptance criteria

- [ ] The player enters from the frontrooms and lands without seeing unloaded geometry.
- [ ] The level is walkable in any direction for at least 10 minutes with no visible seam,
      hitch, or missing collision.
- [ ] All biomes listed as *Must* in [DESIGN.md](DESIGN.md) are generated and visually distinct.
- [ ] Carpet footstep sounds differ between wet and dry areas.
- [ ] The inner-voice sequence from [SCRIPT.md](SCRIPT.md) plays in order, with subtitles.
- [ ] A flickering wall exists and leads to `lvl_1`.
- [ ] Blackout zones remove ceiling lights, include a shallow-water layer with distinct wet
      footstep sounds, and the hand-feel wall shader reveals a dithered black-and-white halo
      around the player's touch point.
- [ ] Holes appear in pitch-black, grid-pattern clusters (like the Pillars biome) and drop the
      player straight into a working Game Over screen with a functional "Restart from checkpoint"
      button.
- [ ] The Manila room matches the wiki's physical description (8x8m, manila wallpaper, wooden
      floor, one octagonal table, two chairs, notes/documents); the MEG Supplier NPC plays its full
      briefing with subtitles on top of that and visibly clips away via its dissolve shader on
      exit; once visited it never spawns again, even across a full game restart (persisted to disk).
- [ ] Approaching a Red Room is a gradual transition - thicker/stickier/coarser carpet, a red
      colour shift, and peeling wallpaper revealing crimson underneath - giving the player a chance
      to turn back before it is too late. Red Rooms do not appear at all before the Manila room has
      been visited once; after that they can appear, trigger the "SHIT!" voice line on full entry,
      and have no walkable exit, only the `P`-to-restart prompt.
- [ ] Scattered props (chairs, trash bins) appear at low density and are pushable.
- [ ] `tools/static_check.sh` passes.
- [ ] `scenes/lvl_0/tests/test_map_gen.sh` produces a `result.png` with no obvious artefacts.

## 11. Open questions

- How is the flickering-wall exit made findable in minutes instead of days?
  **decision:** TBD. Candidates: guarantee one within N chunks of the spawn, or increase the
  spawn chance the longer the player has been in the level.
- Should the "layout changes where you do not look" rule apply to chunks the player has already
  walked through, given that chunks are cached? **decision:** TBD.
- `bg_outside.mp3` sits in this level's folder but the level has no outside. Leftover, or
  intended for a biome? **decision:** TBD.
- Besides the Manila room, should any other future POI also update the save system's checkpoint,
  or does the Manila room stay the only checkpoint source for now? **decision:** TBD, default to
  "any future POI may set one" - see [save_system.md](../../../docs/ai/systems/save_system.md)
  section 5.
- How far before a Red Room should the peeling-wallpaper/carpet/colour transition begin, and how
  gradual should it be? **decision:** TBD at implementation time; should be slow enough to read as
  a warning, not a jump-scare.

## 12. Related documents

- [DESIGN.md](DESIGN.md) - MoSCoW feature list and progress
- [TECHNICAL.md](TECHNICAL.md) - how the level is built. **Stale**: it refers to
  `generate_level.gd` and `part_1x1_wall`, neither of which exists any more. Until it is
  rewritten, trust [map_generation](../../../docs/ai/systems/map_generation.md) instead.
- [SCRIPT.md](SCRIPT.md) - narration
- [Map generation system](../../../docs/ai/systems/map_generation.md)
- [UI & subtitles system](../../../docs/ai/systems/ui_subtitles.md) - Holes Game Over screen and Red Room prompt
- [Save/checkpoint system](../../../docs/ai/systems/save_system.md) - persistence this level now needs (new)
- [NPC bot system](../../../docs/ai/systems/npc_bot.md) - the Manila room's MEG Supplier (new)
- [AI documentation index](../../../docs/ai/README.md)
