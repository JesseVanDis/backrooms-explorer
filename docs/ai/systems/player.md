# System: Player

> **Status:** partial
> **Code:** `assets/scripts/player.gd`, `player_hands.gd`, `player_wield.gd`
> **Scene:** `assets/models/player.tscn`

## 1. Responsibility

What the Player system owns:

- First person movement of a `CharacterBody3D` (`class_name Player`): walking, jumping, gravity, optional fall-speed cap.
- Mouse look, mouse capture/release, and clamping pitch/yaw according to the active wieldable's look-freedom limits.
- Head bob, horizontal bob and "movement lowering" of the camera.
- Footstep / jump / landing sound playback through `_Hands/_cam/Camera/RaytracedAudioPlayer3D_Foot`, including timing (interval) and random pitch.
- Voice playback through `_Hands/_cam/Camera/RaytracedAudioPlayer3D_Voice` as a queue of `AudioStream`s, plus derivation of the matching `.srt` path.
- Pushing `RigidBody3D` bodies it slides into (`PUSH_FORCE` impulse).
- Delegating wieldable equip/dequip animation state to `PlayerWield` (`assets/scripts/player_wield.gd`).
- Hand mesh opacity fade, via `PlayerHands` (`assets/scripts/player_hands.gd`), which copies an animated helper node's Y position into the hand shader's `opacity` parameter.
- Auto-adding a `SoundController` node if the current scene does not already contain one.

What it explicitly does NOT own:

- Footstep sound *content*: the level decides, by calling `apply_footsteps()`, `apply_footstep_start_sound()` and `apply_jump_sounds()`. The player only ships defaults (`FOOTSTEP_SOUNDS`, `FOOTSTEP_START_SOUND`, `JUMP_SOUNDS`, `LANDING_SOUNDS`).
- Voice *content* and when it plays: the level pushes `AudioStream` sequences into the queue.
- Which wieldable is active and what `wield_target` is: the level sets those (see `scenes/frontroom_0/frontroom_0.gd`, `scenes/lvl_0/lvl_0.gd`).
- Subtitle rendering: handed off to `IngameUI` -> `PlayerSubtitles`.
- Level geometry, streaming, transitions, fog.
- Health, inventory, interaction/use of objects - none of that exists in the player code.

## 2. Public API

### `@export` variables

| name | type | default | meaning |
|---|---|---|---|
| `max_speed` | `float` | `3.0` | Maximum horizontal movement speed (m/s). Also used as the deceleration step in `move_toward` when there is no input. |
| `max_fall_speed` | `float` | `0.0` | Downward velocity clamp while airborne. Only applied when `> 0.0`; `0.0` means "no clamp". |
| `initial_velocity` | `Vector3` | `Vector3.ZERO` | Velocity applied in `_ready()`. |
| `initial_yaw` | `float` | `0.0` | Body yaw in degrees, applied in `_ready()` as `rotation.y`. |
| `initial_pitch` | `float` | `0.0` | Camera pitch in degrees, applied in `_ready()` as camera `rotation.x`. |

### Public properties other scripts set / read

| name | type | default | meaning |
|---|---|---|---|
| `control_enabled` | `bool` | `true` | When `false`, input is ignored: horizontal velocity decays to 0, gravity still applies, `move_and_slide()` still runs, and all wield/bob/footstep updates are skipped. Mouse look is also suppressed. |
| `active_wieldable` | `String` | `""` (via `PlayerWield`) | Proxy property: getter/setter forwards to `_wield.active_wieldable`. Setting it to a different name makes `PlayerWield` dequip the old one and equip the new one. Must be a name previously registered with `add_wieldable()`. |
| `wield_target` | `Node3D` | `null` | The object the player is "working on". Used by `_handle_hands_aim()` (only when `active_wieldable == "wield_push"`) to yaw the hands toward the target, and by `_current_speed()` to apply `max_movement_speed_to_target`. |
| `forward_2d` | `Vector2` (get only) | - | `UtilsMath.xz_normal(-transform.basis.z)`. |
| `moving_direction_2d` | `Vector2` (get only) | - | `UtilsMath.xz_normal(global_position - _old_global_pos)`, i.e. direction actually moved last physics frame. |

### Public functions

| signature | what it does |
|---|---|
| `add_wieldable(unique_name: String, p_rewind_for_dequip: bool = true, p_clear_wield_when_finish: bool = false, p_additional_args: Dictionary = {}) -> void` | Registers a wieldable under `unique_name` with `PlayerWield`. See section 7. |
| `replace_voice(sequence: Array[AudioStream]) -> void` | Stops the current voice line and subtitles, replaces the remaining queue with a copy of `sequence`, and starts playing immediately. |
| `push_back_voice(sequence: Array[AudioStream]) -> void` | Appends `sequence` to the end of the remaining queue. Starts playback if nothing is currently playing and the queue was empty. |
| `push_front_voice(sequence: Array[AudioStream]) -> void` | If nothing is playing, behaves like `replace_voice()`. Otherwise inserts `sequence` in front of the remaining queue, so it plays after the current line finishes (it does not cut the current line). |
| `get_subtitle_path(path_to_voice_ogg: String) -> String` | Derives the subtitle file path from a voice resource path. See section 8. |
| `apply_footsteps(sounds: Array[AudioStream]) -> void` | Replaces the random footstep sound pool. |
| `apply_footstep_start_sound(sound: AudioStream) -> void` | Replaces the sound played on the first step after standing still. If `null`, a normal footstep is played instead. |
| `apply_jump_sounds(sounds: Array[AudioStream]) -> void` | Replaces the random jump sound pool. Note: there is no corresponding `apply_landing_sounds()`; `_landing_sounds` can only be changed by editing the code. |

No signals. `player.gd` neither declares nor emits any signal; it only *connects* to `_audio_player_voice.finished`.

`PlayerHands` (`player_hands.gd`) has no public API beyond being attached to the hands scene root; it only runs `_ready()` and `_process()`.

## 3. Expected scene tree

Node paths `player.gd` depends on via `$` / `find_child`:

```
Player (CharacterBody3D, player.gd, assets/models/player.tscn)
└── _Hands                                        (instance of assets/models/hands.tscn, PlayerHands)
    ├── _cam
    │   └── Camera                                (Camera3D)
    │       ├── RaytracedAudioPlayer3D_Voice      ($_Hands/_cam/Camera/RaytracedAudioPlayer3D_Voice)
    │       └── RaytracedAudioPlayer3D_Foot       ($_Hands/_cam/Camera/RaytracedAudioPlayer3D_Foot)
    ├── _hands                                    ($_Hands/_hands, yawed by _handle_hands_aim())
    │   └── ... armature/Skeleton3D/Hand_3D       (found by PlayerHands via find_child("Hand_3D"))
    └── _setting_opacity                          (found by PlayerHands via find_child, animated helper)
```

Names starting with `_` (`_Hands`, `_cam`, `_hands`, `_setting_opacity`, `_ignore_groundreference`) are referenced from code and must not be renamed.

Nodes resolved by type instead of by path (renaming them is safe):

- the `Camera3D` is additionally looked up with `UtilsNode.find_camera_recursive(self)`;
- the `AnimationPlayer` used by wieldables is looked up with `UtilsNode.find_animation_player_recursive()`;
- the `IngameUI` is looked up by walking up the tree with `_find_ingame_ui()`.

`player.tscn` itself also contains a hidden `MeshInstance3D` (capsule) and a `CollisionShape3D` (capsule, radius 0.3, height 1.5); `collision_layer` and `collision_mask` are both `9`.

## 4. Input

| action | where | effect |
|---|---|---|
| `left`, `right`, `forward`, `backward` | `Input.get_vector("left", "right", "forward", "backward")` in `_physics_process()` | Horizontal movement direction. |
| `ui_accept` | `Input.is_action_just_pressed("ui_accept")` in `_physics_process()` | Jump, only when `is_on_floor()`. |
| `ui_cancel` | `_unhandled_input()` | Releases the mouse (`MOUSE_MODE_VISIBLE`). |
| any `InputEventMouseButton` | `_unhandled_input()` | Captures the mouse (`MOUSE_MODE_CAPTURED`). |
| `InputEventMouseMotion` | `_unhandled_input()` | Yaw on the body, pitch on the camera, while the mouse is captured and `control_enabled` is `true`. |

Jumping is implemented (`velocity.y = JUMP_VELOCITY` plus a jump sound), but there is **no `jump` action registered in `project.godot`** - only `forward`, `backward`, `left` and `right` are defined there. Jump is therefore bound to Godot's built-in `ui_accept` (space/enter) rather than to a dedicated game action.

## 5. Tuning constants

Declared at the top of `player.gd`. Note that only `JUMP_VELOCITY` (and the sound arrays) are actual `const`; the others are `var` even though they are used as constants.

| constant | value | effect |
|---|---|---|
| `JUMP_VELOCITY` | `3.5` | Upward velocity set on jump. |
| `PUSH_FORCE` | `0.5` | Magnitude of the central impulse applied to any `RigidBody3D` the player slides into, along `-collision.get_normal()`. |
| `HANDS_APPEAR_DURATION` | `0.1` | unclear: declared but never read anywhere in `player.gd`, `player_hands.gd` or `player_wield.gd`. Presumably intended as the hand fade-in time, which is currently driven by the `_setting_opacity` animation instead. |
| `FOOTSTEP_INTERVAL` | `SpeedScale.new(0.8, 0.36)` | Seconds between footsteps: `0.8` s at speed 1, `0.36` s at speed 3. Also sets the head-bob frequency. |
| `BOB_VERTICAL_AMPLITUDE` | `SpeedScale.new(0.02, 0.08)` | Vertical camera bob amplitude in metres: `0.02` at speed 1, `0.08` at speed 3. |
| `BOB_HORIZONTAL_AMPLITUDE` | `SpeedScale.new(0.005, 0.02)` | Horizontal camera sway amplitude in metres: `0.005` at speed 1, `0.02` at speed 3. |
| `MOVEMENT_LOWERING` | `SpeedScale.new(0.02, 0.15)` | How far the camera is lowered while moving: `0.02` m at speed 1, `0.15` m at speed 3 (applied negatively). |

`SpeedScale` is a small inner helper class holding two values, `at_speed_1` and `at_speed_3`. `at(speed)` linearly interpolates between them using `(speed - 1.0) / (3.0 - 1.0)` as the factor, i.e. it maps the current movement speed from the 1..3 m/s range onto the two given values. The factor is not clamped, so speeds below 1 or above 3 extrapolate.

Other hard-coded values worth knowing: camera position lerp uses `delta * 15.0`; hands yaw lerp uses `dt * 30.0`; mouse sensitivity is `0.01`, dropping to `0.0005` while a wieldable limits looking; camera-limit adjustment speed is `10.0 + seconds_since_equiping_start * 40.0`; footsteps play at `volume_db = -20.0` with `pitch_scale` randomised `0.9..1.3` (jump `0.9..1.0`, landing `0.8..1.1`).

## 6. Movement model

- Horizontal speed comes from `_current_speed()`: base `max_speed` (default `3.0`), multiplied by the active wieldable's `movement_multiplier` and capped by its `max_movement_speed`.
- When a `wield_target` is set and the wieldable's `max_movement_speed_to_target < max_speed`, the cap is interpolated between `max_movement_speed_to_target` and `max_speed` based on how far the movement direction deviates from the direction to the target (`factor = (distance_between_directions * 0.5)^2`, clamped to 1). Moving straight at the target is the slowest.
- With no input, `velocity.x/z` decay with `move_toward(..., 0, max_speed)` - i.e. one `max_speed` step per physics frame, which is effectively an instant stop.
- Gravity: `velocity += get_gravity() * delta` whenever not on the floor (also while `control_enabled == false`).
- `max_fall_speed`: if `> 0.0`, `velocity.y` is clamped to `>= -max_fall_speed`. Default `0.0` means unlimited fall speed.
- Jump: `velocity.y = JUMP_VELOCITY` (3.5) plus a random jump sound; a landing sound plays on the frame the player goes from airborne to on-floor.
- Head bob runs only when `is_on_floor()` and `velocity.length() > 0.1`. `_bob_phase` advances by `delta * (PI / FOOTSTEP_INTERVAL.at(speed))` and wraps at `2*PI`; vertical offset is `BOB_VERTICAL_AMPLITUDE.at(speed) * abs(sin(phase))`, horizontal offset is `BOB_HORIZONTAL_AMPLITUDE.at(speed) * sin(phase)`.
- Movement lowering adds `-MOVEMENT_LOWERING.at(speed)` to the camera Y while moving. All camera offsets are applied as a `lerp(..., delta * 15.0)` toward `_camera_default_position` plus the offsets, so they ease back when the player stops.
- Footstep interval scales with speed via `FOOTSTEP_INTERVAL.at(speed)`. The first step after standing still plays `_footstep_start_sound` and resets both the timer and the bob phase; afterwards a random footstep plays every interval and the bob phase is snapped to the nearest multiple of `PI`.
- Collision push: after `move_and_slide()`, every slide collision against a `RigidBody3D` gets `apply_central_impulse(-collision.get_normal() * PUSH_FORCE)`.

## 7. Wieldables

`PlayerWield` (`assets/scripts/player_wield.gd`) is created in `player.gd` as `var _wield: PlayerWield = PlayerWield.new(self)` and ticked from `_physics_process()` via `_wield.update(delta)`.

### `WieldState` enum

| value | meaning |
|---|---|
| `NONE` | Idle. If `_wieldable_old != active_wieldable`, it tries to play the old wieldable's `dequip` range; success -> `DEQUIPING`, failure (empty range / no animation) -> `EQUIPING_START`. |
| `DEQUIPING` | Waiting for the dequip animation to stop playing, then -> `EQUIPING_START`. |
| `EQUIPING_START` | Plays the new wieldable's `equip` range; success -> `EQUIPING`, failure -> `NONE`. Records `_wieldable_old = active_wieldable` and resets the action time cursor. |
| `EQUIPING` | While the animation plays, fires any `Action` whose `trigger_time_millis` falls into the interval advanced this frame. When the animation stops: if `clear_wield_when_finish`, `active_wieldable` is reset to `""`; state -> `NONE`. |

`_seconds_since_equiping_start` is reset when entering `EQUIPING_START` and is exposed as `seconds_since_equiping_start`; `player.gd` uses it to speed up the camera-limit adjustment right after equipping.

### `add_wieldable` signature

```gdscript
add_wieldable(unique_name: String, p_rewind_for_dequip: bool = true, p_clear_wield_when_finish: bool = false, p_additional_args: Dictionary = {}) -> void
```

| parameter | meaning |
|---|---|
| `unique_name` | Key in the wieldable dictionary **and** the name of the animation in the player's `AnimationPlayer`. The empty string `""` is the special "nothing wielded" entry: it has empty equip/dequip ranges and `play_animation()` always returns `false`. `player.gd` registers it in `_ready()`. |
| `p_rewind_for_dequip` | If `true` and no explicit `dequip` range is given, the dequip range is the equip range played backwards (`last_frame -> 0`). If `false`, dequip is `(0, 0)`, i.e. no dequip animation. |
| `p_clear_wield_when_finish` | If `true`, `active_wieldable` is set back to `""` once the equip animation finishes (one-shot animation). |
| `p_additional_args` | Dictionary of optional settings, see below. |

`p_additional_args` keys read by `WieldableData`:

| key | default | used by |
|---|---|---|
| `max_look_freedom_degrees_h` | falls back to `max_look_freedom_degrees`, then `360.0` | `player.gd` `_handle_camera_limits()` - yaw limit is half this value |
| `max_look_freedom_degrees_v` | falls back to `max_look_freedom_degrees`, then `360.0` | pitch limit is half this value (default pitch limit is 90 deg) |
| `movement_multiplier` | `1.0` | `_current_speed()` |
| `max_movement_speed` | `99999.0` | `_current_speed()` hard cap |
| `max_movement_speed_to_target` | `99999.0` | `_current_speed()` cap when `wield_target` is set |
| `equip` | `AnimationRange.new(0, last_frame)` | explicit equip frame range |
| `dequip` | derived from `p_rewind_for_dequip` | explicit dequip frame range |
| `actions_at_millisecond` | `[]` | list of `{time_ms: {action_name: value}}` dictionaries |

### Animation ranges and frame-based actions

- `AnimationRange(p_from_frame_index: float, p_to_frame_index: float, p_speed: float = 1.0)` stores `from`, `to`, `speed` as **frame indices**, converted to seconds by `PlayerWield.frame_index_to_time(anim, index) -> index * anim.step`.
- `last_frame = int(anim.length / anim.step)`.
- `play_animation()` returns `false` when the animation name is `""` or when `from == to`. If `from <= to` it calls `animation_player.play_section(name, from_time, to_time, -1, speed, false)`; otherwise it plays the section reversed with `-speed` and the reverse flag set.
- Actions are time-based, not real keyframe callbacks: every frame in `EQUIPING`, the current animation position is converted to milliseconds and any `Action` with `_old_animation_time_ms < trigger_time_millis <= current_time_ms` fires `_on_animation_action()`. The only implemented action name is `set_animation_speed`, which assigns `animation_player.speed_scale`. Any other action name is printed but ignored.

### Registered wieldables in the project

- `player.gd` `_ready()` registers `""` and `"wield_push"` with `{"max_movement_speed_to_target": 0.15}`.
- `scenes/frontroom_0/frontroom_0.gd` activates `"wield_push"`: when the player is within `1.0` m of one of the four moving boxes it sets `active_wieldable = "wield_push"` and `wield_target = <box>`, otherwise it clears both back to `""` / `null`.
- `scenes/lvl_0/lvl_0.gd` registers `"lvl_0_landing"` (`p_rewind_for_dequip = false`, `p_clear_wield_when_finish = true`) with look-freedom and `movement_multiplier: 0.0`, plus `set_animation_speed` actions at 600 / 1000 / 2000 ms, and activates it the first time the falling player touches the floor.

## 8. Voice and subtitles

The player holds `_remaining_voice_sequence: Array[AudioStream]` and plays it through `_audio_player_voice`. The queue API:

| signature | behaviour |
|---|---|
| `replace_voice(sequence: Array[AudioStream]) -> void` | Stops audio and subtitles, replaces the queue with `sequence.duplicate()`, plays the first entry. |
| `push_back_voice(sequence: Array[AudioStream]) -> void` | Appends to the queue; only starts playback if nothing was playing and the queue was empty. |
| `push_front_voice(sequence: Array[AudioStream]) -> void` | If nothing is playing, equivalent to `replace_voice()`. Otherwise prepends `sequence` before the remaining queue, so it plays after the current line ends. |

All three return early (silently) if `_audio_player_voice` is `null`.

`_play_next_voice()` pops the next stream, `push_error`s and skips it when it is `null`, assigns it to the voice player, plays it, and starts subtitles. When the stream finishes, `_on_voice_finished()` stops subtitles and plays the next entry.

Subtitle path derivation:

```gdscript
get_subtitle_path(path_to_voice_ogg: String) -> String
```

- If the voice file's directory ends with `/gen` (or `\gen`), the result is `<parent of gen dir>/<filename>_sub_en.srt`.
- Otherwise it is `<voice path without extension>_sub_en.srt`.

Handoff: in `_ready()` the player finds the nearest `IngameUI` by walking up the tree (`_find_ingame_ui()`, `push_error("IngameUI not found!")` when absent) and calls `_ingame_ui.setup(_audio_player_voice)`. `IngameUI` (`scenes/menu_ui/menu_ui.gd`) forwards `setup()`, `play_subtitles(srt_path)` and `stop_subtitles()` to `PlayerSubtitles` (`assets/scripts/player_subtitles.gd`), which parses the `.srt` and syncs lines to the voice player's playback position. See [./ui_subtitles.md](./ui_subtitles.md).

## 9. How a level uses it

Derived from `scenes/frontroom_0/frontroom_0.gd` and `scenes/lvl_0/lvl_0.gd`:

```gdscript
extends Node

@onready var _node_box: RigidBody3D = $_viewport_container/_viewport/MovingBox1
var _player: Player = null
var _did_hit_floor: bool = false

func _ready() -> void:
	_player = UtilsNode.find_player(get_tree())
	if _player == null:
		push_error("Player not found in scene tree")
		return

	# Block input until the intro is done.
	_player.control_enabled = false

	# Register a level specific wieldable animation (one-shot, no dequip).
	_player.add_wieldable("lvl_0_landing", false, true, {
							"max_look_freedom_degrees_v": 10.0,
							"max_look_freedom_degrees_h": 0.0,
							"movement_multiplier": 0.0,
							"actions_at_millisecond": [
								{600:  {"set_animation_speed": 0.13}},
								{1000: {"set_animation_speed": 0.3}},
								{2000: {"set_animation_speed": 1.0}}
							]
						})

	_player.control_enabled = true

func _physics_process(_dt: float) -> void:
	if _player == null:
		push_error("Player is null")
		return

	const DETECTION_DISTANCE: float = 1.0
	if _player.global_position.distance_to(_node_box.global_position) < DETECTION_DISTANCE:
		_player.active_wieldable = "wield_push"
		_player.wield_target = _node_box
	else:
		_player.active_wieldable = ""
		_player.wield_target = null

	if !_did_hit_floor && _player.is_on_floor():
		_player.active_wieldable = "lvl_0_landing"
		_did_hit_floor = true
```

Voice is normally not driven from level code directly: `assets/scripts/trigger.gd` calls `get_player().replace_voice(sounds)`, `push_back_voice(sounds)` or `push_front_voice(sounds)` depending on its `Mode` (`PlayerVoice_Replace`, `PlayerVoice_PushBack`, `PlayerVoice_PushFront`).

unclear: `apply_footsteps()`, `apply_footstep_start_sound()` and `apply_jump_sounds()` are not called anywhere in the repository, so every level currently uses the default sound sets.

## 10. Known gaps

- No health, damage or death model of any kind.
- No inventory. `active_wieldable` is a single `String` and is driven entirely by the level, not by the player picking things up.
- No `jump` input action in `project.godot`; jumping is hard-wired to `ui_accept`. Only `forward`, `backward`, `left`, `right` are registered.
- `HANDS_APPEAR_DURATION` is declared but never used.
- Most "constants" (`FOOTSTEP_INTERVAL`, `BOB_*`, `MOVEMENT_LOWERING`, `HANDS_APPEAR_DURATION`, `PUSH_FORCE`) are `var`, not `const`, which contradicts the project convention.
- Dead/commented-out code remains: the `active_voice_sequence` property and `_on_active_voice_sequence_changed()`, `_update_speed_cap(delta)`, and an empty `_process()`.
- `apply_jump_sounds()` exists but there is no `apply_landing_sounds()`, so landing sounds cannot be overridden per level.
- `_play_next_voice()` prints the subtitle path to stdout on every line (`print("Playing subtitle: " + ...)`), and `PlayerWield._on_animation_action()` prints on every action.
- `_ensure_sound_controller()` has a typo in its log message: "Scene foes not contain a sound controller".
- `PlayerWield.update()` indexes `_wieldables[_wieldable_old]` and `_wieldables[active_wieldable]` directly; assigning an unregistered name to `active_wieldable` will fail at runtime rather than produce a readable error.
- `SpeedScale.at()` does not clamp, so speeds outside 1..3 m/s extrapolate the bob/footstep values.
- `_find_ingame_ui()` searches the whole tree every time the player enters a scene; if no `IngameUI` exists, `_ready()` pushes an error and then still dereferences `_ingame_ui`.
- No TODO/FIXME comments are present in `player.gd`, `player_hands.gd` or `player_wield.gd`.

## 11. Related

- [../ARCHITECTURE.md](../ARCHITECTURE.md)
- [../CONVENTIONS.md](../CONVENTIONS.md)
- [./ui_subtitles.md](./ui_subtitles.md)
- [./audio.md](./audio.md)
- [./interaction.md](./interaction.md)
