# Glossary

Vocabulary used in this repository. Two kinds: **lore** terms from the Backrooms Wiki, and
**project** terms that only mean something here.

---

## Project terms

| Term                  | Meaning                                                                                          |
|-----------------------|---------------------------------------------------------------------------------------------------|
| `[AI-DOC]` header     | The four-line doc comment at the top of every first-party `.gd` file. See [CONVENTIONS.md](CONVENTIONS.md#2-the-ai-doc-header). |
| `[interpretation]`    | Tag marking a gameplay claim that is **not** from the wiki - invented for this game.               |
| Biome                 | A region of `lvl_0` generated with different layout rules (`MESS`, `ROOMS`, `ARCHES`, `PILLARS`, and the planned `BLACKOUT_ZONES` and `HOLES`). |
| Checkpoint            | The last discovered POI (planned: the Manila room's position); where a restart-from-checkpoint puts the player back. Planned, see [systems/save_system.md](systems/save_system.md). |
| Chunk                 | A square block of map tiles generated and cached as one unit in `lvl_0`.                           |
| Frontrooms            | The ordinary world; here, the house scene `scenes/frontroom_0` the player starts in.               |
| Game Over screen      | Planned full-screen overlay shown after falling through a Hole, with a "Restart from checkpoint" button. See [systems/ui_subtitles.md](systems/ui_subtitles.md). |
| Level                 | A Backrooms level, one scene folder `scenes/lvl_<n>/`.                                             |
| MEG Supplier          | Planned NPC: a person sent by M.E.G. (nicknamed "the MEG Supplier" in docs/code, not a literal robot) who briefs the player in a Manila room, then dissolves away. See [systems/npc_bot.md](systems/npc_bot.md). |
| `NON_CANON.md`        | Per-level document listing every `[interpretation]`-tagged design decision in one place, so it is easy to see what in a level is invented versus wiki-sourced. See [CONVENTIONS.md](CONVENTIONS.md#8-tracking-non-canon-additions). |
| Part                  | A reusable piece of level geometry, `part_*.tscn`, instantiated by the generator.                  |
| POI                   | "Point of interest" - a handcrafted, non-tiled landmark stitched into `lvl_0`'s generated maze, e.g. `entry_tube.tscn` or the planned Manila room. |
| PRY                   | "Please Repeat Yourself" - duplicate level-specific logic rather than share it. See [CONVENTIONS.md](CONVENTIONS.md#5-level-specific-vs-shared-code-pry). |
| SPEC / DESIGN / TECHNICAL / SCRIPT / NON_CANON | The five per-level documents. Contract / feature list / build notes / narration / non-canon log. |
| Tile                  | One cell of the generation grid in `lvl_0`.                                                        |
| Trigger               | An `Area3D` that fires a sound or voice line on enter, leave, or look-at.                          |
| Wieldable             | Something the player holds or uses with their hands; currently only `wield_push`.                  |
| `_` node prefix       | Marks a node whose **name is referenced from GDScript**. Renaming it breaks code.                  |
| Voice line            | A recorded `.flac` in `scenes/<level>/voice/`, converted to `.ogg` in `voice/gen/`.                 |

## Lore terms

Short definitions only, so an AI reading the code knows what a name refers to. The wiki is the
authority; link to the relevant page in the level's `DESIGN.md`.

| Term                | Meaning                                                                                 |
|---------------------|------------------------------------------------------------------------------------------|
| Almond water        | The staple drinkable resource of the Backrooms. Safe, restorative.                        |
| The Backrooms       | An endless set of liminal "levels" reachable by no-clipping out of reality.               |
| Blackout zone       | Level 0 sub-area with no working lights, per the wiki; wiki also describes rough wall textures, intense silence, and recessed floors that fill with ankle-deep fluid. Planned in this game as the `BLACKOUT_ZONES` biome, with the water layer matching the wiki and a hand-feel wall shader `[interpretation: the shader is this game's own invention, not a wiki mechanic]`. |
| Clump               | Entity; a mass of fused human remains.                                                    |
| Entity              | Any non-player inhabitant, hostile or not. Numbered on the wiki (Entity 7, Entity 71...). |
| Faceling            | Entity; humanoid with no facial features. Usually passive.                                |
| Firesalt            | Consumable item that produces heat/fire.                                                  |
| Holes               | Canon Level 0 floor pits, appearing in pitch-black, grid-pattern clusters (like the Pillars biome); the wiki reports no survivors of a fall. In this game they are an instant Game Over, not a path to another level `[interpretation: the wiki does not specify a game mechanic, only that no one has reported surviving]`. |
| Hound               | Entity; aggressive, dog-like, hunts by sound.                                             |
| Isolation Effect    | Canon Level 0 mechanic: no two wanderers can ever find, see, hear or signal one another, with the Manila room as the sole exception. |
| Jerry (Entity 7)    | Entity that can appear in any level. Can be permanently dismissed with sunflower seeds.   |
| Level 0             | "The Lobby" - the endless yellow mono-room. The first Backrooms level in this game.       |
| M.E.G.              | Major Explorer Group, the main organised human faction. Runs bases and outposts.          |
| M.E.G. Explorer Device | The in-game phone that shows the level description and wiki link. Planned, not built.  |
| Manila room         | A canon 8x8m safe room inside Level 0 with manila-coloured wallpaper, a wooden floor, one octagonal table, two chairs, and written notes/no-clip guides - the wiki's version has **no living person** in it. In this game, briefed instead by the MEG Supplier, an NPC person `[interpretation: replaces the wiki's static notes with a voiced briefing]`; see [systems/npc_bot.md](systems/npc_bot.md). |
| No-clip             | Passing through solid geometry into another level. How the player enters the Backrooms.   |
| Red Knight (Entity 71) | Entity that sometimes helps newly arrived travellers.                                  |
| Red rooms           | Rare, crimson-walled pockets reached by turning a corner in Level 0, completely at random per the wiki; near-impossible to escape, signalled beforehand by thicker/stickier/coarser carpet, a red colour shift, and peeling wallpaper revealing crimson underneath. In this game: infinite looping corridors with no true exit, gated behind having visited a Manila room `[interpretation: the wiki describes purely random entry, no such gate]`. |
| Royal rations       | High value food item.                                                                     |
| Skin-Stealer        | Entity that wears human skin to pass as a person.                                         |
| Smiler              | Entity; visible only as a grin in darkness.                                               |
| Survival difficulty | The wiki's per-level danger rating, "Class 0" to "Class 5".                               |

## Godot terms worth pinning down

| Term            | Meaning in this project                                                                  |
|-----------------|--------------------------------------------------------------------------------------------|
| Autoload        | A global singleton. **This project has none** and should keep it that way.                   |
| `class_name`    | Registers a GDScript class globally so it can be used without `preload`.                     |
| `@export`       | Exposes a variable to the Godot inspector; this is how levels configure shared scripts.      |
| `@onready`      | Resolves a node path when the node enters the tree.                                          |
| `SubViewport`   | The `_viewport` that the 3D world renders into, separate from the UI layer.                  |
| `dt`            | Delta time. The only abbreviation allowed in this codebase.                                  |
