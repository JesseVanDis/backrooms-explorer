# System: Save and checkpoint

> **Status:** stub (planned - no code exists yet)
> **Code:** none yet - see section 3 for where it should live

## 1. Responsibility

This is the project's **first persistent save system**. It does not exist today - `docs/ai/STATUS.md`
section 3 lists "Save games" under "Does not exist at all", and `ARCHITECTURE.md` section 8 lists
"save games" as planned-not-built. This spec exists so it is designed once, consistently, before
any of the Level 0 features that need it are implemented.

Two Level 0 features depend on this system and must not each invent their own persistence:

- The **Manila room** must stop spawning forever, across game restarts, once the player has
  visited it once (see [./npc_bot.md](./npc_bot.md)).
- **Red Rooms** are gated behind that same "has the player ever visited a Manila room" flag, and
  both the **Holes Game Over screen** and the **Red Room restart prompt** need a **checkpoint** to
  restart the player at (see [./ui_subtitles.md](./ui_subtitles.md) section 6).

`[interpretation]` tag applies to this whole document: none of this is implemented, so every
concrete choice below is a design decision for this game, not a description of existing code.

## 2. What must be stored

| Field                     | Type     | Written when                                      | Read when                               |
|---------------------------|----------|----------------------------------------------------|------------------------------------------|
| `manila_room_visited`     | `bool`   | The player enters a Manila room for the first time  | `MapGenerator` decides whether to ever place a Manila room again, and whether Red Rooms are allowed to generate |
| `checkpoint_position`     | `Vector3`| The player discovers a new POI (currently: a Manila room) | Restart-from-checkpoint, from either the Game Over screen or the Red Room prompt |
| `checkpoint_level_path`   | `String` | Same time as `checkpoint_position`                  | Restart-from-checkpoint, so it can load the right level if the checkpoint is not in `lvl_0` |

Checkpoint granularity is **last discovered POI**, not "start of the level" - this was an explicit
decision over the simpler alternative. Until the player has discovered any POI, the checkpoint
falls back to the level's normal entry point (`entry_tube.tscn` for `lvl_0`) `[interpretation]`.

## 3. Where this should live, per `ARCHITECTURE.md`

`ARCHITECTURE.md` section 2 is explicit: **no autoload singletons**. This system must therefore be
a plain `class_name` (for example `class_name SaveSystem`, extending nothing or `RefCounted`,
following the same shape as `LevelTransition`) that a level instantiates itself and calls, not a
global. A sketch of the shape to follow (mirroring `LevelTransition`'s `_init(tree)` pattern):

```gdscript
class_name SaveSystem

const SAVE_FILE_PATH: String = "user://save.json"

func load_save() -> void: ...          # reads SAVE_FILE_PATH, push_error()s if it exists but cannot be opened
func is_manila_room_visited() -> bool: ...
func mark_manila_room_visited() -> void: ...   # also saves immediately
func set_checkpoint(level_path: String, position: Vector3) -> void: ...   # also saves immediately
func get_checkpoint() -> Dictionary: ...       # {"level_path": String, "position": Vector3}
```

Format: a small on-disk JSON file via `FileAccess` (`user://save.json`), read once at game start
and written immediately whenever `manila_room_visited` or the checkpoint changes - there is no
reason to batch writes for data this small. A missing or unreadable save file must **not** be an
error the player sees: default to `manila_room_visited = false` and no checkpoint, the same way
`PlayerSubtitles._parse_srt` treats a missing `.srt` as empty rather than failing (see
[./ui_subtitles.md](./ui_subtitles.md) section 3) - but per the project's null-check rule, a file
that exists and fails to open must still `push_error(...)`.

## 4. How the two consumers use it

- **`MapGenerator` / `Lvl_0`** (see [./map_generation.md](./map_generation.md)): before placing a
  Manila room POI, check `is_manila_room_visited()`; if `true`, never place one again. Before
  allowing a Red Room to be selected during biome generation, check the same flag; if `false`, Red
  Rooms must not generate at all.
- **The Manila room's `Trigger`** (`OnEnter`, see [./interaction.md](./interaction.md)) calls
  `mark_manila_room_visited()` and `set_checkpoint(current_level_path, manila_room_global_position)`
  the moment the player first enters it.
- **The Holes Game Over screen and the Red Room restart prompt**
  (see [./ui_subtitles.md](./ui_subtitles.md) section 6) both call `get_checkpoint()` and then
  either teleport the player there (if the checkpoint level is already loaded) or go through
  `LevelTransition.switch_to_level(checkpoint_level_path)` (see
  [./level_flow.md](./level_flow.md)) followed by positioning the player once loaded.

## 5. Open questions

- Exact save file format (`JSON` via `FileAccess` vs. Godot's `ConfigFile`/`ResourceSaver`) -
  `[interpretation]`, JSON is suggested here only because it is the simplest to hand-inspect while
  debugging. **decision:** TBD at implementation time.
- Whether future POIs beyond the Manila room should also update `checkpoint_position`, or whether
  the Manila room stays the only checkpoint source for the foreseeable future. **decision:** TBD -
  default to "yes, any future POI with a `Trigger` can call `set_checkpoint`" so the system does
  not need to change shape later.
- Whether `checkpoint_level_path` can ever differ from the level the player died in once more than
  `lvl_0` exists. **decision:** TBD, out of scope while only `lvl_0` exists.

## 6. Related

- [../ARCHITECTURE.md](../ARCHITECTURE.md) section 2 - no autoload singletons rule this system must follow
- [./ui_subtitles.md](./ui_subtitles.md) section 6 - the two UI screens that call into this system
- [./npc_bot.md](./npc_bot.md) - the Manila room bot whose visit sets `manila_room_visited`
- [./level_flow.md](./level_flow.md) - `LevelTransition`, used if a checkpoint restart needs a level swap
- [lvl_0 DESIGN.md](../../../scenes/lvl_0/docs/DESIGN.md) - the feature list this system unblocks
