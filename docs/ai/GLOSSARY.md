# Glossary

Vocabulary used in this repository. Two kinds: **lore** terms from the Backrooms Wiki, and
**project** terms that only mean something here.

---

## Project terms

| Term                  | Meaning                                                                                          |
|-----------------------|---------------------------------------------------------------------------------------------------|
| `[AI-DOC]` header     | The four-line doc comment at the top of every first-party `.gd` file. See [CONVENTIONS.md](CONVENTIONS.md#2-the-ai-doc-header). |
| `[interpretation]`    | Tag marking a gameplay claim that is **not** from the wiki - invented for this game.               |
| Biome                 | A region of `lvl_0` generated with different layout rules (`MESS`, `ROOMS`, `ARCHES`, `PILLARS`, ...). |
| Chunk                 | A square block of map tiles generated and cached as one unit in `lvl_0`.                           |
| Frontrooms            | The ordinary world; here, the house scene `scenes/frontroom_0` the player starts in.               |
| Level                 | A Backrooms level, one scene folder `scenes/lvl_<n>/`.                                             |
| Part                  | A reusable piece of level geometry, `part_*.tscn`, instantiated by the generator.                  |
| PRY                   | "Please Repeat Yourself" - duplicate level-specific logic rather than share it. See [CONVENTIONS.md](CONVENTIONS.md#5-level-specific-vs-shared-code-pry). |
| SPEC / DESIGN / TECHNICAL / SCRIPT | The four per-level documents. Contract / feature list / build notes / narration. |
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
| Clump               | Entity; a mass of fused human remains.                                                    |
| Entity              | Any non-player inhabitant, hostile or not. Numbered on the wiki (Entity 7, Entity 71...). |
| Faceling            | Entity; humanoid with no facial features. Usually passive.                                |
| Firesalt            | Consumable item that produces heat/fire.                                                  |
| Hound               | Entity; aggressive, dog-like, hunts by sound.                                             |
| Jerry (Entity 7)    | Entity that can appear in any level. Can be permanently dismissed with sunflower seeds.   |
| Level 0             | "The Lobby" - the endless yellow mono-room. The first Backrooms level in this game.       |
| M.E.G.              | Major Explorer Group, the main organised human faction. Runs bases and outposts.          |
| M.E.G. Explorer Device | The in-game phone that shows the level description and wiki link. Planned, not built.  |
| No-clip             | Passing through solid geometry into another level. How the player enters the Backrooms.   |
| Red Knight (Entity 71) | Entity that sometimes helps newly arrived travellers.                                  |
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
