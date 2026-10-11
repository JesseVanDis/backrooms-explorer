# System: Level flow

> **Status:** partial
> **Code:** `assets/scripts/level_transition.gd`, `assets/scripts/utils/screen.gd`, `scenes/menu_intro/`, `scenes/menu_loading/`

## 1. Responsibility

Getting the player from one level scene into another without a visible hitch:

- **Preloading** a level scene on a background thread (`ResourceLoader.load_threaded_*`) while the
  current level keeps running.
- Giving the incoming level a chance to **initialize asynchronously** (lvl_0 generates its first
  chunks here) before it is shown.
- Covering the swap with a **fade screen** (`UtilsScreen`), which lives under the tree root so it
  survives the destruction of the old scene.
- Performing the actual **scene swap**: free the old `current_scene`, add the new one to the root
  and make it `current_scene`.

What it is explicitly **not** responsible for: a main menu, pause, settings, save games, or any
persistent state between levels. None of that exists yet (section 8).

Who drives it: a level script owns a `LevelTransition` instance and calls `update()` every frame.
Today the only owner is `scenes/frontroom_0/frontroom_0.gd`.

## 2. LevelTransition API

`assets/scripts/level_transition.gd`, `class_name LevelTransition`. It extends nothing (plain
`RefCounted` by default) - it is **not** a node and is not in the tree.

| Exact signature | Meaning | Return value |
|---|---|---|
| `func _init(tree: SceneTree) -> void` | stores the `SceneTree` it will operate on; `push_error("SceneTree is null")` if `tree` is `null` (it still assigns it) | - |
| `func preload_level(scene_path: String) -> void` | queues `scene_path` in `_levels_to_preload` if it is not already loaded and not already queued. Cheap, non-blocking | nothing |
| `func switch_to_level(scene_path: String) -> bool` | requests a transition: queues the path, kicks the preload, starts the fade-in screen, sets `_next_level_path` | `true` if the request was accepted. `false` if already transitioning to that same path, if `scene_path` is `""` (with `push_error`), or if a transition to a *different* level is already running (with `push_error`) |
| `func update() -> void` | must be called every frame (it is `await`ed because it awaits the scene swap). Advances the preloading state machine and performs the transition once the target level is loaded and the fade-in has finished | nothing |
| `func _preload_level(scene_path: String) -> int` | internal, one preload request | `0` = not started (empty path, or another preload/transition in progress), `1` = already preloaded, `2` = preload started |
| `func _check_and_preload() -> void` | internal; pops the head of `_levels_to_preload` if `_preload_level` returned non-zero | nothing |
| `func _perform_transition(target_level: Node) -> void` | internal, the actual scene swap, see section 5 | nothing |

Typical frame from `frontroom_0.gd`:

```gdscript
func _physics_process(_dt: float) -> void:
	_handle_level_transition()
	await _level_transition.update()
```

## 3. The loading state machine

Two independent integers. There are no enums; the raw ints below are exactly as implemented.

`_loading_state` - the preloader:

| Value | Meaning | Transitions to |
|---|---|---|
| `0` | idle, nothing being preloaded | `1`, set by `_preload_level` when a path is accepted |
| `1` | start request: calls `ResourceLoader.load_threaded_request(_path_to_preload_now)`. On a non-`OK` error it `push_error`s and returns, staying in `1` (so it retries next frame) | `2` |
| `2` | poll: `ResourceLoader.load_threaded_get_status(...)`. On `THREAD_LOAD_LOADED` it takes the `PackedScene`, `instantiate()`s it into `_loading_level`, and then either calls `initialize_async()` on it (-> `3`) or skips straight to `4`. On `THREAD_LOAD_FAILED` and `THREAD_LOAD_INVALID_RESOURCE` it `push_error`s and falls back to `1`. A `null` `PackedScene` or a `null` instance `push_error`s and returns, staying in `2` | `3`, `4`, or back to `1` |
| `3` | waiting for async init: each frame calls `initialized()` on the level if that method exists and treats a `bool` result as "is it done". If the method is missing, or returns a non-bool, it counts as done | `4` |
| `4` | finish: stores `_loaded_levels[_path_to_preload_now] = _loading_level`, prints `level '<path>' loaded`, clears `_path_to_preload_now` | `0` |

`_transition_state` - the swap:

| Value | Meaning |
|---|---|
| `0` | no transition in progress. This is also the value restored after `_perform_transition` returns |
| `1` | transition requested by `switch_to_level`: fade screen started, `_next_level_path` set, waiting for the target level to appear in `_loaded_levels` **and** for `_fade_in_complete` to become `true` |
| `2` | swap in progress; set immediately before `await _perform_transition(next_level)` and reset to `0` afterwards |

Other fields: `_path_to_preload_now` (the single path currently being threaded-loaded, `""` when
idle), `_levels_to_preload: Array[String]` (FIFO queue), `_loaded_levels: Dictionary`
(path -> instantiated `Node`), `_loading_level` (the instance being prepared), `_loading_screen`
(the `_Screen` node returned by `UtilsScreen.fade_in_screen`), `_fade_in_complete: bool`.

Note that `_preload_level` refuses to start while `_transition_state > 0`, so only one level is
ever being loaded at a time, and nothing new starts once a transition has been requested.

## 4. The async level contract

A level scene may optionally implement two methods. `LevelTransition` probes for them with
`has_method(...)`, so **both are optional** and there is no interface/base class to inherit.

```gdscript
# in your level's root script
func initialize_async() -> void:
	# called once, right after the scene is instantiated, before it is in the tree.
	# kick off (or do) the expensive setup here.
	initialized()

func initialized() -> bool:
	# polled every frame while _loading_state == 3.
	# return true when the level is ready to be shown.
	return _everything_is_ready
```

Rules as implemented:

- `initialize_async()` is called only if it exists; otherwise the level is considered ready
  immediately (`_loading_state` jumps to `4`).
- `initialized()` is only polled if `initialize_async()` existed. If `initialize_async()` exists but
  `initialized()` does not, the level is considered ready on the next frame.
- The return value of `initialized()` is read as `Variant` and only honoured when
  `typeof(result) == TYPE_BOOL`; anything else counts as "ready".
- The node is **not in the scene tree** while these run, so `get_tree()`, `_ready`, `_process` and
  `@onready` members are not available yet.

Which level implements them: **`scenes/lvl_0/lvl_0.gd`** - the only one. Its
`initialize_async()` simply calls `initialized()`, and `initialized()` creates/returns the four
starting chunks `(0,0)`, `(-1,-1)`, `(-1,0)`, `(0,-1)` and returns whether all four exist.

- unclear: because `initialize_async()` is not itself asynchronous and `initialized()` does the work
  on each poll, the "async" part is really "retry chunk creation each frame until all four exist".
  `lvl_0.gd::_ready()` repeats the same four-chunk loop with `OS.delay_msec(50)`, so the work is
  done twice when the level is reached through a transition.

## 5. Scene swap mechanics

`_perform_transition(target_level: Node)`, in order:

1. `var old_scene: Node = _tree.current_scene` - `push_error("current_scene is null")` and return if
   it is `null`.
2. `old_scene.queue_free()`.
3. `await old_scene.tree_exited` - the swap genuinely waits for the old level to leave the tree, so
   the two levels never coexist. This is why `update()` is `await`ed by the caller.
4. `push_error("_next_level is null during transition")` and return if `target_level` is `null`.
5. `_tree.root.add_child(target_level)`.
6. `_tree.current_scene = target_level`.
7. `_loaded_levels.clear()`.

Why the loading screen survives: `UtilsScreen.fade_in_screen` adds the `_Screen` node to
`_tree.root`, **not** to the current scene. Freeing `current_scene` therefore does not touch it, and
the black overlay stays up across the whole swap. The code says so explicitly:

```gdscript
# Note: _loading_screen is already a child of root, so it stays when current_scene is freed
_tree.root.add_child(target_level)
```

`_loaded_levels.clear()` drops every preloaded instance reference after the swap - including any
other level that was preloaded but not used. Note that `LevelTransition` keeps `_loading_screen`
non-null after the transition, so a second `switch_to_level` on the same instance reuses the
existing screen and sets `_fade_in_complete = true` straight away.

- unclear: nothing in `level_transition.gd` ever calls `UtilsScreen.fade_out_screen`, so the overlay
  is not removed by this system. The new level has to fade it out itself (as `frontroom_0.gd` does
  for its own intro overlay with `UtilsScreen.fade_out`). In practice lvl_0 does not do this.

## 6. Loading and intro screens

All three screen scenes share the exact same shape required by `UtilsScreen`
(see [./utils.md](./utils.md), section 5):

| Scene | Root node | Children | Used by |
|---|---|---|---|
| `scenes/menu_intro/menu_intro.tscn` | `_Screen` (`Node2D`) | `CanvasLayer` -> `ColorRect` (full-rect, opaque black, `mouse_filter = 1`) + `Label` "BACKROOMS EXPLORER", font size 40, centred, offset upwards (`offset_top = -147`) | `frontroom_0.gd` via `MENU_INTRO_PATH`, faded out over 2.0 s at startup |
| `scenes/menu_loading/menu_loading.tscn` | `_Screen` (`Node2D`) | `CanvasLayer` -> `ColorRect` (full-rect, opaque black) + `Label` "BACKROOMS EXPLORER", font size 40, centred (`offset_top = -73`) | nothing - no `.gd` or `.tscn` references it |
| `scenes/frontroom_0/transition_frontrooms_lvl_0.tscn` | `_Screen` (`Node2D`) | `CanvasLayer` -> `ColorRect` only (full-rect, opaque black), no label | `level_transition.gd`, as the fade screen for every transition |

`menu_intro.tscn` and `menu_loading.tscn` are **currently near-identical placeholders**: same root
name, same node structure, same black `ColorRect`, same 40 pt "BACKROOMS EXPLORER" label. The only
differences are the label's vertical offset and that the intro sets `mouse_filter = 1` on both
`ColorRect` and `Label`. Neither has a script, an animation, a progress bar or a spinner.

**Known gap - the hardcoded transition scene.** `switch_to_level` hardcodes the screen path inside
the shared system:

```gdscript
_loading_screen = UtilsScreen.fade_in_screen(_tree, "res://scenes/frontroom_0/transition_frontrooms_lvl_0.tscn", func() -> void: _fade_in_complete = true)
```

So every transition between any two levels uses a scene that lives inside `scenes/frontroom_0/`,
and `scenes/menu_loading/` is dead content. The path should be a parameter (or at least a `const`
pointing at `scenes/menu_loading/menu_loading.tscn`).

## 7. How to add a transition between two levels

Following exactly what `scenes/frontroom_0/frontroom_0.gd` does:

1. **Declare the target path as a const** in the source level's script:

   ```gdscript
   const LVL_0_PATH: String = "res://scenes/lvl_0/lvl_0.tscn"
   ```

2. **Create the `LevelTransition` and start preloading in `_ready()`**, long before the player can
   reach the trigger:

   ```gdscript
   var _level_transition: LevelTransition

   func _ready() -> void:
       _level_transition = LevelTransition.new(get_tree())
       _level_transition.preload_level(LVL_0_PATH)
   ```

3. **Pump `update()` every frame** and `await` it (the project enables the `missing_await` warning,
   so leaving the `await` off is an error):

   ```gdscript
   func _physics_process(_dt: float) -> void:
       _handle_level_transition()
       await _level_transition.update()
   ```

4. **Define the trigger** and call `switch_to_level`. It is safe to call repeatedly - a second call
   with the same path while transitioning returns `false` without side effects:

   ```gdscript
   const OPEN_LVL_0_TRIGGER_Y: float = -15.0

   func _handle_level_transition() -> void:
       if _player == null:
           return
       if _player.global_position.y < OPEN_LVL_0_TRIGGER_Y:
           _level_transition.switch_to_level(LVL_0_PATH)
   ```

   Get `_player` with `UtilsNode.find_player(get_tree())`, not an absolute path.

5. **If the target level needs heavy setup**, give its root script `initialize_async()` and
   `initialized() -> bool` (section 4). Otherwise skip this.

6. **Optionally sell the transition** by driving effects up to the trigger - `frontroom_0.gd` ramps
   `WorldEnvironment.environment.fog_density` from `0.0` to `0.1` and `fog_sky_affect` from `0.0` to
   `1.0` between y `-5.0` and y `-10.0`, so the screen is already dark when the fade starts at
   y `-15.0`.

7. **Fade the overlay back out** in the new level once it is ready, with
   `UtilsScreen.fade_out(node, duration, node.queue_free)` or `UtilsScreen.fade_out_screen(tree)`.
   Nothing does this automatically today (section 5).

## 8. Known gaps

- **Hardcoded transition scene path.** `"res://scenes/frontroom_0/transition_frontrooms_lvl_0.tscn"`
  is a string literal inside `level_transition.gd`; a shared system depends on a level folder.
- **`scenes/menu_loading/menu_loading.tscn` is unused.** Nothing references it.
- **No main menu.** The game boots straight into a level; there is no title screen, no "new game",
  no pause and no quit flow. `menu_intro.tscn` is only a fading title overlay.
- **No save/load.** `_loaded_levels.clear()` after each swap and no persistence layer anywhere; the
  player state is not carried between levels.
- **Placeholder menus.** `menu_intro` and `menu_loading` are a black rect plus a label, scriptless
  and near-identical; there is no progress indication even though
  `ResourceLoader.load_threaded_get_status` already fills a `progress` array (it is read into a
  local `progress: Array[float]` and then ignored).
- **No error recovery if a level fails to load.** `THREAD_LOAD_FAILED` and
  `THREAD_LOAD_INVALID_RESOURCE` only `push_error` and reset `_loading_state` to `1`, which retries
  the same failing path forever. Meanwhile `_transition_state` stays at `1` and the black screen
  stays up, so a bad path is an unrecoverable soft lock with no user-visible message.
- **No fade-out owner.** The overlay is faded in by the system but must be faded out by the level.
- **Single consumer.** Only `frontroom_0 -> lvl_0` is wired up, so the system is effectively tested
  on one path only.

## 9. Related

- [../ARCHITECTURE.md](../ARCHITECTURE.md) - boot flow and where levels sit at runtime
- [./utils.md](./utils.md) - `UtilsScreen` fade helpers and the `_Screen` node contract
- [./ui_subtitles.md](./ui_subtitles.md) - the in-game UI layer that lives inside a level
