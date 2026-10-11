# Architecture

How the game is wired together at runtime. For *what* is built see [STATUS.md](STATUS.md),
for *how to write* code see [CONVENTIONS.md](CONVENTIONS.md).

---

## 1. Engine facts

| Item            | Value                                                      |
|-----------------|------------------------------------------------------------|
| Engine          | Godot 4.7, `Forward Plus` renderer                          |
| Language        | GDScript only                                               |
| Physics         | Jolt Physics (3D)                                           |
| Max FPS         | 60 (`run/max_fps`)                                          |
| Autoloads       | **none** - there is no global singleton in this project     |
| Addons          | `addons/raytraced_audio` (third party, do not modify)       |
| Main scene      | `uid://ctkngyu5rcixj` = `scenes/lvl_0/lvl_0.tscn`           |

> **Gotcha:** the main scene currently points at **lvl_0**, not at the frontrooms.
> This is a development shortcut. The intended first-run flow starts at
> `scenes/frontroom_0/frontroom_0.tscn`. Change `run/main_scene` in `project.godot`
> if you need to test the full flow.

### Input actions

Defined in `project.godot`, all with deadzone `0.2`:

| Action      | Key | Used by                          |
|-------------|-----|----------------------------------|
| `forward`   | W   | `player.gd`                      |
| `backward`  | S   | `player.gd`                      |
| `left`      | A   | `player.gd`                      |
| `right`     | D   | `player.gd`                      |
| `ui_accept` | -   | `player.gd` - **jump**           |
| `ui_cancel` | -   | `player.gd`                      |

> Jumping is bound to the built-in `ui_accept` action, not to a dedicated `jump` action.
> There is no `jump` entry in `project.godot`, so jumping cannot be rebound independently of
> the UI accept key. Add a real action before relying on it.

### Audio buses

`raytraced_audio` expects two buses, configured in `project.godot`:

- `RaytracedReverb` - driven by `SoundController`, must have an `AudioEffectReverb` at index 0.
- `RaytracedAmbient`

---

## 2. There is no global game state

Deliberate. The project follows **PRY (Please Repeat Yourself)** for level specific logic
(see `TECHNICAL.md`): a bug in level 7 must never be able to break level 0.

Consequences you must respect:

- No autoload singletons. Shared behaviour is a `class_name` that a level **instantiates itself**
  (e.g. `LevelTransition.new(get_tree())`).
- Shared code in `assets/scripts/` must be **level agnostic**. If a feature only makes sense for
  one level, it belongs in `scenes/<level>/`.
- Cross-cutting lookups go through `UtilsNode` (e.g. `UtilsNode.find_player(tree)`), not through
  hardcoded absolute node paths.

---

## 3. Scene anatomy of a level

Every playable level follows the same shape:

```
<Level>                       (Node, script: <level>.gd  -- the level entry point)
└── _viewport_container       (SubViewportContainer)
    └── _viewport             (SubViewport)
        ├── Player            (CharacterBody3D, assets/models/player.tscn)
        ├── WorldEnvironment
        ├── SoundController   (optional; player.gd adds one if missing)
        ├── <level geometry>  (static model, or a Map node filled at runtime)
        └── <Trigger / Door / RigidBody nodes>
    └── menu_ui               (CanvasLayer, scenes/menu_ui/menu_ui.tscn)
```

The `_viewport_container` / `_viewport` wrapper exists so the 3D world can be post-processed, while UI stays crisp outside of it.

The `_` prefix means **"Godot code depends on this node name"** - renaming or moving it breaks
`$`-paths in GDScript. This also applies to nodes authored in Blender (see `TECHNICAL.md`).

---

## 4. Boot and level flow

```
project.godot run/main_scene
        │
        ▼
scenes/frontroom_0/frontroom_0.tscn        (intended entry; see Gotcha above)
        │  _ready()
        │    ├── UtilsNode.find_player() ....... grab the Player
        │    ├── player.control_enabled = false  freeze the player
        │    ├── LevelTransition.new(tree)
        │    ├── preload_level("res://scenes/lvl_0/lvl_0.tscn")
        │    └── _show_intro() ................. menu_intro.tscn over the top, then fade out
        │
        │  _physics_process()
        │    ├── _update_player_speed() ........ proximity to a MovingBox -> wieldable "wield_push"
        │    ├── _update_environment_effects() . player.y drives fog_density / fog_sky_affect
        │    ├── _handle_level_transition() .... player.y < -15.0 -> switch_to_level(lvl_0)
        │    └── _level_transition.update() .... drives the async state machine
        │
        ▼
scenes/lvl_0/lvl_0.tscn
```

### `LevelTransition` state machine

`assets/scripts/level_transition.gd`. Owned and ticked by the level that wants to leave.
Nothing is automatic - **you must call `update()` every physics frame**.

| API                                | Meaning                                                        |
|------------------------------------|----------------------------------------------------------------|
| `_init(tree: SceneTree)`           | Needs the tree; pushes an error when `null`                     |
| `preload_level(path)`              | Queue a level for background loading                            |
| `switch_to_level(path) -> bool`    | Start fade + swap; `false` if already transitioning             |
| `update()`                         | Pump the loader; call from `_physics_process`                   |

Internal `_loading_state`: `1` request threaded load -> `2` poll + instantiate ->
`3` await optional `initialize_async()` / `initialized()` -> `4` store in `_loaded_levels`.

**Level async contract** (opt in, both optional):

```gdscript
func initialize_async() -> void   # start heavy work (threads, generation)
func initialized() -> bool        # return true once that work is done
```

`lvl_0.gd` implements both to generate its first chunks before being shown.

The swap itself: `current_scene.queue_free()` -> `await tree_exited` -> `root.add_child(new)` ->
`tree.current_scene = new`. The loading screen is parented to `root`, so it survives the swap.

---

## 5. Data flow of the player

```
Input actions ──► player.gd ──► velocity / CharacterBody3D
                      │
                      ├──► head bob + camera (UtilsMath noise)
                      ├──► footstep sounds (per level, via apply_footsteps())
                      ├──► PlayerWield ──► wieldable animation (hands)
                      ├──► PlayerHands ──► hand mesh opacity shader param
                      └──► voice queue ──► AudioStreamPlayer3D ──► PlayerSubtitles (.srt)
```

- The **level** decides which footstep sounds and which voice lines play; the player only
  executes them. That keeps `player.gd` level agnostic.
- Voice lines are queued: `replace_voice`, `push_back_voice`, `push_front_voice`.
- Subtitles are `.srt` files parsed at runtime and synced against the audio player position.

See [systems/player.md](systems/player.md).

---

## 6. Audio pipeline

```
.flac (recorded / AI generated, committed)
   │  tools/parse.sh --flac_to_ogg_for_import   (ffmpeg, mtime cached)
   ▼
scenes/<level>/voice/gen/*.ogg   ──► imported by Godot ──► AudioStreamPlayer3D
                                                               │
                                       RaytracedReverb bus ◄── SoundController
```

Only the `gen/` `.ogg` files are referenced by scenes. Never reference a `.flac` directly, as Godot does not support this format.
Voice recording settings (ElevenLabs model, stability, priming lines) live in `TECHNICAL.md`.

See [systems/audio.md](systems/audio.md).

---

## 7. Procedural generation (lvl_0)

```
MapGenerator (threaded)                 Lvl_0 (main thread)
  fractal noise ──► biome mask              │
  biome rules  ──► wall / open bitmap  ──►  chunk cache (128 x 128 tiles)
  refinement   ──► lights, arches            │
                                             ├─ instantiate graphics within the view radius
                                             └─ instantiate collision only close by
                                                    via duplicate() / queue_free()
```

> `NodePool` exists in `assets/scripts/utils/` but is **not used** by the generator - the level
> duplicates and frees nodes directly. See [systems/map_generation.md](systems/map_generation.md).

Generation is pure data (an image-like grid); instantiation is separate and distance driven.
That split is what makes the "infinite" level affordable. See
[systems/map_generation.md](systems/map_generation.md).

---

## 8. Planned, not built yet

These appear in `README.md` but have **no code at all**. Do not assume they exist:

multiplayer / server mode (`--server`), save games, main menu, inventory, health,
the M.E.G. Explorer Device (phone), entities, non-euclidean geometry, swimming,
gravity changes, vehicles, filters, narrator system.
