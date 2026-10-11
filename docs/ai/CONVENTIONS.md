# Conventions

`AGENTS.md` holds the **hard rules** (they win on any conflict). This file holds the
**patterns**: how the existing code actually looks, so new code blends in.

---

## 1. Hard rules recap

Copied here only as a reminder. The authority is [../../AGENTS.md](../../AGENTS.md).

- Use `const` wherever possible (split functions if that is what it takes).
- Type hint **everything**, including `bool` and `float`.
- Add or update a reasoning comment directly above every function you add or change.
- Never modify third party assets or `addons/`.
- Ask permission before changing an existing `.md` file.
- No abbreviations in names. The only allowed one is `dt`.
- Never touch nodes **inside** imported (Blender) objects; only nodes Godot itself created.
- Every `null` check must be accompanied by a `push_error(...)`.
- Avoid `preload()` for `.gd` scripts (`preload()` of `.tscn` is fine and is used in `lvl_0.gd`).
- Do not "fix" code unrelated to your task.
- Verify with `tools/static_check.sh [optional/file.gd]`.

---

## 2. The `[AI-DOC]` header

Every first-party `.gd` file starts with this block. It is a GDScript `##` doc comment, so
Godot also shows it in the in-editor class reference.

```gdscript
## [AI-DOC] <one sentence, present tense, what this script is responsible for>
## spec: <repo relative path to the owning spec document>
## status: <implemented|partial|stub>
## notes: <optional, one line: a trap, a dependency, a missing piece>

extends Node3D
class_name Example
```

| Field    | Rules                                                                              |
|----------|------------------------------------------------------------------------------------|
| purpose  | One sentence. Say what it *owns*, not how it works.                                  |
| spec     | A system spec (`docs/ai/systems/*.md`) for shared code, or the level's own doc for level code. |
| status   | `implemented` = feature complete for its current scope. `partial` = works but the spec lists unfinished items. `stub` = placeholder. |
| notes    | Omit the line entirely when there is nothing worth saying.                           |

**Keep it honest.** A wrong header is worse than no header. If you change what a script does,
change its header in the same edit.

---

## 3. Naming

| Thing                   | Convention                  | Example                              |
|-------------------------|-----------------------------|--------------------------------------|
| Script file             | `snake_case.gd`             | `player_wield.gd`                     |
| Class                   | `PascalCase`                | `class_name PlayerWield`              |
| Level class             | `Lvl_<n>` / scene name      | `class_name Lvl_0`                    |
| Function / variable     | `snake_case`, spelled out   | `opening_side_detection_distance`     |
| Constant                | `SCREAMING_SNAKE_CASE`      | `const TILE_SIZE: float = 1.0`        |
| Private member          | leading `_`                 | `var _player: Player`                 |
| Scene folder            | `lvl_<n>` / `frontroom_<n>` / `menu_<name>` / `test_<n>` | `scenes/lvl_0`    |
| Level part scene        | `part_<size>_<what>.tscn`   | `part_1x1_ceiling_light.tscn`         |
| Transition scene        | `transition_<from>_<to>.tscn` | `transition_frontrooms_lvl_0.tscn`  |
| Voice file              | `voice_<event>.flac`        | `voice_landing.flac`                  |
| Utility class           | `Utils<Area>`               | `UtilsMath`, `UtilsNode`, `UtilsScreen` |

### The `_` node prefix

A node name starting with `_` means **GDScript references it by name/path**.
Renaming or re-parenting it silently breaks `$`-paths. Applies to Godot nodes *and* to nodes
authored in Blender. Examples in use: `_viewport_container`, `_viewport`, `_Hands`, `_cam`,
`_hands`, `_setting_opacity`, `_Screen`, `_UI`, `_subtitles`, `_node_map`.

---

## 4. Code patterns in use

### Changed functions explain why

Whenever a function is added or changed, place a comment directly above it explaining why the
function exists or why the change is necessary. Keep the comment focused on reasoning and context;
do not merely translate the function name or implementation into prose. Update an existing comment
when its reasoning is no longer accurate.

```gdscript
# Keeps prop placement stable when a chunk is regenerated from overlapping world coordinates.
func _get_prop_chair_angle(tile_index: Vector2i) -> float:
	return PROP_CHAIR_ROTATIONS[hash(tile_index) % PROP_CHAIR_ROTATIONS.size()]
```

### Null checks always report

```gdscript
_player = UtilsNode.find_player(get_tree())
if _player == null:
	push_error("Player not found in scene tree")
	return
```

### Find nodes through `UtilsNode`, not absolute paths

```gdscript
var player: Player = UtilsNode.find_player(get_tree())
var camera: Camera3D = UtilsNode.find_camera_recursive(some_node)
```

### Tuning numbers are constants, scoped as tightly as possible

```gdscript
func _update_player_speed() -> void:
	const DETECTION_DISTANCE: float = 1.0
```

A `const` inside the function that uses it is preferred over a file-level one when only that
function needs it.

### `@onready` for owned nodes

```gdscript
@onready var _node_map: Node3D = $_viewport_container/_viewport/Map
```

### `dt` is the only abbreviation

```gdscript
func _physics_process(dt: float) -> void:
```

Use `_dt` when the parameter is unused, to keep the static check quiet.

### Indentation

**Tabs.** Not spaces. Godot default.

---

## 5. Level specific vs shared code (PRY)

> Prefer **PRY** (Please Repeat Yourself) over DRY for level specific logic.
> Breaking level 3 while fixing level 9 is far worse than duplicating 20 lines.

Decision rule:

```
Is this behaviour meaningful in at least two levels,
AND stable enough that a change should affect both?
    yes -> assets/scripts/  (shared, needs a system spec)
    no  -> scenes/<level>/  (duplicate freely)
```

Shared code must never hardcode a level path, a level specific node name, or a level specific
constant. The level passes those in (`apply_footsteps()`, `@export` fields on `Trigger`, ...).

---

## 6. Adding a new level: checklist

1. `mkdir scenes/lvl_<n>` with `docs/`, `voice/`, `tests/` as needed.
2. Copy [templates/LEVEL_SPEC_TEMPLATE.md](templates/LEVEL_SPEC_TEMPLATE.md) to
   `scenes/lvl_<n>/docs/SPEC.md` and fill it in from the wiki page.
3. Add `docs/DESIGN.md` (MoSCoW + progress) and `docs/TECHNICAL.md` (how it is built).
   Add `docs/SCRIPT.md` if there is narration.
4. Copy [templates/NON_CANON_TEMPLATE.md](templates/NON_CANON_TEMPLATE.md) to `docs/NON_CANON.md`
   and fill it in with every `[interpretation]`-tagged claim already in the files above - see
   section 8 below.
5. Create `lvl_<n>.tscn` following the scene anatomy in [ARCHITECTURE.md](ARCHITECTURE.md#3-scene-anatomy-of-a-level).
6. Create `lvl_<n>.gd` with `class_name Lvl_<n>`, an `[AI-DOC]` header, and - if the level needs
   heavy loading - `initialize_async()` / `initialized()`.
7. Wire the exit(s) with `LevelTransition`.
8. Register the level in [levels/README.md](levels/README.md) and [STATUS.md](STATUS.md).
9. Run `tools/static_check.sh`.

## 7. Adding a new shared script: checklist

1. Put it in `assets/scripts/` (or `assets/scripts/utils/` if it is stateless and static).
2. Add the `[AI-DOC]` header pointing at an existing `docs/ai/systems/*.md`, or create a new one.
3. Document its public API in that system spec (exports, public functions, signals, node
   expectations, input actions).
4. Run `tools/static_check.sh assets/scripts/<file>.gd`.

---

## 8. Tracking non-canon additions

Every gameplay claim must be traceable to the Backrooms Wiki page linked in the level's spec, or
be explicitly tagged `[interpretation]` (see [GLOSSARY.md](GLOSSARY.md)). Tagging inline is not
enough on its own - each level also keeps a **`NON_CANON.md`** that gathers every one of those
tags into a single, scannable list, so a later contributor (or a future wiki update) can see at a
glance what in a level is invented versus sourced.

- Location: `scenes/<level>/docs/NON_CANON.md` for a level with a scene folder, or
  `docs/ai/levels/planned/<level>_non_canon.md` for a level that only has a draft spec so far
  (move it to the `scenes/` location the moment a scene folder is created, same rule as the spec
  itself - see section 6 below).
- Template: [templates/NON_CANON_TEMPLATE.md](templates/NON_CANON_TEMPLATE.md).
- **Scope: world/lore decisions only.** `NON_CANON.md` tracks facts about the Backrooms world
  itself that the wiki leaves undescribed (an NPC, an entity behaviour, what happens to the
  player, dialogue, set dressing). It does **not** track purely gameplay-engine or UI mechanics -
  menus, buttons, on-screen prompts, save/restart plumbing, HUD elements - because those are
  needed by the game regardless of what the wiki says, so there is no lore gap for them to fill.
  Still tag those `[interpretation]` inline where relevant, just do not add a `NON_CANON.md` row
  for them.
- **Whenever the wiki does not describe a world/lore fact and a new decision has to be made up
  to fill that gap, do both of these in the same change:**
  1. Tag the claim `[interpretation]` where it is actually written (`SPEC.md`, `DESIGN.md`,
     `SCRIPT.md`, or the relevant `docs/ai/systems/*.md`).
  2. Add a one-row entry to that level's `NON_CANON.md` describing the addition, the gap it
     fills, and where it is documented.
- A level whose spec is "n/a - not canon" by design (no detailed wiki page exists to compare
  against, e.g. `frontroom_0`) still gets a short `NON_CANON.md` saying so, so the absence of a
  wiki is itself a documented, deliberate fact rather than an oversight.

## 9. Definition of done

A change is done when **all** of these hold:

- [ ] `tools/static_check.sh` reports no new warnings or errors.
- [ ] Every new/changed script has an accurate `[AI-DOC]` header.
- [ ] The owning spec (`docs/ai/systems/*.md` or `scenes/<level>/docs/*.md`) matches reality.
- [ ] [STATUS.md](STATUS.md) reflects the new state if a feature started or finished.
- [ ] Progress percentages in the level's `DESIGN.md` were revisited.
- [ ] Any new third party asset is credited in `CREDITS.md` and licensed for commercial use.
