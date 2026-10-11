# System: NPC bot (Manila room)

> **Status:** stub (planned - no code exists yet)
> **Code:** none yet - see section 2 for where it should live

## 1. Responsibility

This is the project's **first NPC system**. Today there are no NPCs or entities to interact
with at all - [./interaction.md](./interaction.md) section 5 states this explicitly ("No entity
interaction at all: there are no NPCs or entities to interact with"), and `STATUS.md` section 3
lists every entity as missing. This spec designs the one NPC Level 0 needs: the M.E.G. briefing
character that appears in the Manila room.

**"MEG Supplier" is a nickname, not a literal robot.** The character is an NPC - a person sent by
M.E.G. - and is only called "the MEG Supplier" in this project's docs and code (file/variable names
like `meg_supplier.gd`) for brevity. Nothing in this document should be read as describing a mechanical
or synthetic character.

**Canon correction:** the wiki's Manila room (re-verified this pass directly against
`backrooms-wiki.wikidot.com/manila-room`) has **no living person in it at all** - it is an 8x8
metre room with notes and no-clip guides left on a table and supply cupboards underneath, visited
by many different wanderers over time (see `scenes/lvl_0/docs/DESIGN.md` for the full physical
description). `[interpretation]`: this game replaces those static notes with a single, one-off NPC
who delivers the same information as a voiced briefing, kept to a single character and a simple
appear/brief/leave sequence so the project's first NPC stays in scope.

## 2. Where this should live

Per [../CONVENTIONS.md](../CONVENTIONS.md) section 5 (PRY), this is new, Level-0-specific
behaviour with no second consumer yet, so it should **not** be forced into a generic "entity"
framework on the first attempt:

- `scenes/lvl_0/meg_supplier.gd` (or `assets/scripts/meg_supplier.gd` only if a second level needs the exact
  same NPC before this is revisited - default to the level-local path).
- A handcrafted `part_manila_room.tscn` POI (static or lightly animated mesh), stitched into the
  generated maze the same way `entry_tube.tscn` is today (see
  [./map_generation.md](./map_generation.md)), not a procedurally tiled biome.
- The NPC reuses the player's existing voice-queue *pattern* (`replace_voice` /
  `push_back_voice`/`push_front_voice`, see [./player.md](./player.md) section 8) but targets its
  **own** `AudioStreamPlayer3D`, since `Player`'s queue is hardcoded to the player's own voice.

## 3. Appear / brief / leave sequence

1. A `Trigger` (`Mode.None` is not enough since this needs custom logic - most likely a `Trigger`
   with `Condition.OnEnter` whose fired callback is read by `meg_supplier.gd`, or `meg_supplier.gd` polls
   player distance itself) fires when the player enters the Manila room and spawns/activates the
   NPC.
2. The NPC plays its briefing lines in order (new `scenes/lvl_0/docs/SCRIPT.md` entries, see that
   file) through its own voice queue, with subtitles exactly like the player's
   (see [./ui_subtitles.md](./ui_subtitles.md)) - reusing `IngameUI`/`PlayerSubtitles` requires the
   subtitle label to be told which `AudioStreamPlayer3D` to follow, so either a second
   `PlayerSubtitles`-like label is added, or `IngameUI.setup()` is extended to accept a second
   audio player. **decision:** TBD, see section 6.
3. Content of the briefing: the risks of Level 0 (per [SPEC.md](../../../scenes/lvl_0/docs/SPEC.md)
   section 5) and a mention of the M.E.G. base in Level 1 `[interpretation, since lvl_1 does not
   exist beyond its draft spec]`, including a warning about Red Rooms - this is what justifies the
   player's own reaction line when they first find one (see
   [lvl_0 DESIGN.md](../../../scenes/lvl_0/docs/DESIGN.md)).
4. Once the voice queue drains, the NPC plays its exit animation: a **dissolve/clip shader**, active
   only inside the Manila room, so it visibly "clips away into the air". This replaces an
   earlier idea of making the *player* invisible at the room's exit - that idea was dropped
   entirely in favour of this NPC-side effect.
5. The moment the player first enters the Manila room (independent of how far the briefing has
   played), `meg_supplier.gd` must call into the save system to persist the visit and set a checkpoint -
   see [./save_system.md](./save_system.md) sections 2 and 4. This is also what permanently removes
   the Manila room from future generation and unlocks Red Rooms.

## 4. The dissolve/clip shader

A new material/shader, used only on the NPC's mesh, only while inside the Manila room:

- Built as its own small shader rather than extended from `wallpaper.gdshader` or
  `carpet.gdshader`, since it dissolves a mesh rather than tinting a surface.
- Driven by a single `uniform float dissolve_amount` (or similar), animated from `0.0` to `1.0`
  over the exit sequence, the same "drive a shader uniform from a script" pattern `player_hands.gd`
  already uses for hand opacity (see [./player.md](./player.md) section 1).
- `[interpretation]` on the exact visual technique (noise-cutout dissolve vs. a simple vertical
  wipe) - pick whichever is cheapest to author first; the requirement from the design discussion is
  only that it reads as the NPC "clipping away", not a specific algorithm.

## 5. Manila room persistence and Red Room gating

- The Manila room can appear **multiple times** across a playthrough, but **once visited, it never
  spawns again** - not just for the current run, but **permanently, saved to disk**
  (see [./save_system.md](./save_system.md)).
- That same persisted flag is what allows Red Rooms to start appearing in generation at all: before
  the player has ever visited a Manila room, Red Rooms must not be selectable by the biome
  generator (see [./map_generation.md](./map_generation.md) and
  [lvl_0 DESIGN.md](../../../scenes/lvl_0/docs/DESIGN.md)).

## 6. Open questions

- Does the NPC need its own `PlayerSubtitles`-equivalent label, or does `IngameUI` grow a second
  slot? **decision:** TBD at implementation time; either is acceptable, but whichever is chosen
  must be documented back into [./ui_subtitles.md](./ui_subtitles.md).
- Exact spawn-distance/frequency tuning for how often a not-yet-visited Manila room appears.
  **decision:** TBD, same open-ended tuning as the glitched-wall exit chance in
  [SPEC.md](../../../scenes/lvl_0/docs/SPEC.md) section 11.
- Whether the NPC needs any animation beyond the dissolve exit (idle motion, a "speaking" cue).
  **decision:** TBD, default to a static humanoid mesh for a first pass `[interpretation]`.

## 7. Related

- [./interaction.md](./interaction.md) - `Trigger`, the only existing building block for "something
  happens when the player enters an area"
- [./player.md](./player.md) section 8 - the voice-queue pattern this NPC's own queue is modelled on
- [./ui_subtitles.md](./ui_subtitles.md) - subtitle display, and the UI layer this NPC's dialogue needs
- [./save_system.md](./save_system.md) - persistence of the visited flag and the checkpoint it sets
- [lvl_0 SCRIPT.md](../../../scenes/lvl_0/docs/SCRIPT.md) - the NPC's briefing lines
- [lvl_0 DESIGN.md](../../../scenes/lvl_0/docs/DESIGN.md) - the feature list this system belongs to
