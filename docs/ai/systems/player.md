# System: Player

> **Status:** partial
> **Code:** `assets/scripts/player.gd`, `assets/scripts/player_behaviour.gd`, `assets/scripts/position_to_shader_param.gd`
> **Scene:** `assets/models/player.tscn`

## 1. Responsibility

What the Player system owns:

- First person movement of a `CharacterBody3D` (`class_name Player`): walking, jumping, gravity, optional fall-speed cap.
- Mouse look, mouse capture/release, and clamping pitch/yaw according to active AnimationTree behaviour look-freedom limits.
- Head bob, horizontal bob and "movement lowering" of the camera.
- Footstep / jump / landing sound playback through `RaytracedAudioPlayer3D_Foot` under `character_main`'s attached camera, including timing (interval) and random pitch.
- Voice playback through `RaytracedAudioPlayer3D_Voice` under `character_main`'s attached camera as a queue of `AudioStream`s, plus derivation of the matching `.srt` path.
- Pushing `RigidBody3D` bodies it slides into (`PUSH_FORCE` impulse).
- Applying active behaviours' look and movement restrictions plus camera offsets through `PlayerBehaviour` (`assets/scripts/player_behaviour.gd`), while the player scene's `AnimationTree` continues to drive the animations.
- Hand mesh opacity fade, via `PositionToShaderParam` (`assets/scripts/position_to_shader_param.gd`), which copies the animated hand-opacity bone's local Y position into the hand shader's `opacity` parameter.
- Auto-adding a `SoundController` node if the current scene does not already contain one.

What it explicitly does NOT own:

- Footstep sound *content*: the level decides, by calling `apply_footsteps()`, `apply_footstep_start_sound()` and `apply_jump_sounds()`. The player only ships defaults (`FOOTSTEP_SOUNDS`, `FOOTSTEP_START_SOUND`, `JUMP_SOUNDS`, `LANDING_SOUNDS`).
- Voice *content* and when it plays: the level pushes `AudioStream` sequences into the queue.
- Which level-specific behaviour to activate: a level registers and activates named behaviours through `add_behaviour()` and `activate_behaviour()`. The player independently activates its built-in `freefall` blend after sustained airtime.
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
| `initial_pitch` | `float` | `0.0` | Camera pitch in degrees, applied in `_ready()` to `_cam_pitch_pivot.rotation.x` through the active behaviour's vertical look limit. |

### Public properties other scripts set / read

| name | type | default | meaning |
|---|---|---|---|
| `control_enabled` | `bool` | `true` | When `false`, input is ignored: horizontal velocity decays to 0, gravity still applies, `move_and_slide()` still runs, and head-bob/footstep updates are skipped. Mouse look is also suppressed. |
| `behaviour_target` | `Node3D` | `null` | Optional target used by `_handle_hands_aim()` and `_current_speed()` when an active behaviour supplies `player_max_movement_speed_to_target`. |
| `forward_2d` | `Vector2` (get only) | - | `UtilsMath.xz_normal(-transform.basis.z)`. |
| `moving_direction_2d` | `Vector2` (get only) | - | `UtilsMath.xz_normal(global_position - _old_global_pos)`, i.e. direction actually moved last physics frame. |

### Public functions

| signature | what it does |
|---|---|
| `add_behaviour(unique_name: String, p_animation_tree_parameter: StringName = "", p_additional_settings: Dictionary = {}) -> void` | Registers an AnimationTree-driven behaviour and its optional player restrictions. See section 7. |
| `activate_behaviour(unique_name: String) -> void` | Starts a blend behaviour or fires a one-shot request and applies its restrictions immediately. |
| `deactivate_behaviour(unique_name: String) -> void` | Ramps down a blend behaviour or aborts a one-shot request. |
| `replace_voice(sequence: Array[AudioStream]) -> void` | Stops the current voice line and subtitles, replaces the remaining queue with a copy of `sequence`, and starts playing immediately. |
| `push_back_voice(sequence: Array[AudioStream]) -> void` | Appends `sequence` to the end of the remaining queue. Starts playback if nothing is currently playing and the queue was empty. |
| `push_front_voice(sequence: Array[AudioStream]) -> void` | If nothing is playing, behaves like `replace_voice()`. Otherwise inserts `sequence` in front of the remaining queue, so it plays after the current line finishes (it does not cut the current line). |
| `get_subtitle_path(path_to_voice_ogg: String) -> String` | Derives the subtitle file path from a voice resource path. See section 8. |
| `apply_footsteps(sounds: Array[AudioStream]) -> void` | Replaces the random footstep sound pool. |
| `apply_footstep_start_sound(sound: AudioStream) -> void` | Replaces the sound played on the first step after standing still. If `null`, a normal footstep is played instead. |
| `apply_jump_sounds(sounds: Array[AudioStream]) -> void` | Replaces the random jump sound pool. Note: there is no corresponding `apply_landing_sounds()`; `_landing_sounds` can only be changed by editing the code. |

No signals. `player.gd` neither declares nor emits any signal; it only *connects* to `_audio_player_voice.finished`.

`PositionToShaderParam` (`assets/scripts/position_to_shader_param.gd`) is configured through inspector fields on the `Node3D` whose position should drive the parameter; see section 3.

## 3. Expected scene tree

Relevant player nodes, including the Godot-created hand-opacity attachment:

```
Player (CharacterBody3D, player.gd, assets/models/player.tscn)
└── character_main                                (instance of character_main.tscn)
    └── _body_armature/Skeleton3D
        ├── shape_perspective_hands                (hand mesh using hand_skin.tres)
        └── _bone_attachement_hand_opacity        (BoneAttachment3D, PositionToShaderParam)
            └── _hand_opacity_node
```

The attachment follows the imported `_setting_hands_opacity` bone. Its animation changes local Y from `0.0` to `1.0`; `PositionToShaderParam` writes that value, clamped to `0.0..1.0`, to `hand_skin.tres`'s `opacity` uniform. Do not edit the imported skeleton or animation tracks to change this connection.

The `Camera3D` is a child of `_cam_pitch_pivot`, which is under the camera `BoneAttachment3D`. `_handle_camera_limits()` applies vertical look to the pivot, making the camera orbit it while leaving the camera's local rotation unchanged. Pitch is limited to 90° up and 80° down; a behaviour's vertical look-freedom setting may impose a tighter symmetric limit but cannot widen these absolute bounds. Behaviour camera offsets move the camera itself, converting the requested displacement from player-root axes into the camera parent's current basis; the pitch pivot stays in place and the camera's local head-bob offset remains separate. The same path initializes and clamps `initial_pitch` before the first physics frame.

### `PositionToShaderParam` configuration

Attach `PositionToShaderParam` to the `Node3D` whose position should drive a shader uniform, then configure:

- Exactly one target: `target_mesh` selects a mesh and surface (the active `ShaderMaterial` is duplicated and assigned to that mesh only); `target_material` directly selects a shared material resource.
- `shader_parameter_name` names the uniform. `position_component` chooses a `Vector3` value or the `X`, `Y`, or `Z` scalar component, and `position_space` chooses local or global position.
- `clamp_scalar_output` and `scalar_clamp_range` optionally clamp float output. The component validates the declared uniform type and disables itself after reporting an invalid configuration.

The hands use `target_material = hand_skin.tres`, `shader_parameter_name = opacity`, `position_component = Y`, local position, and a `0.0..1.0` clamp.

Nodes resolved by type instead of by path (renaming them is safe):

- the `Camera3D` is additionally looked up with `UtilsNode.find_camera_recursive(self)`;
- the `AnimationTree` used by behaviours is looked up with `UtilsNode.find_animation_tree_recursive()`;
- the `IngameUI` is looked up by walking up the tree with `_find_ingame_ui()`.

`player.tscn` itself also contains a hidden `MeshInstance3D` (capsule) and a `CollisionShape3D` (capsule, radius 0.3, height 1.5); `collision_layer` and `collision_mask` are both `9`.

## 4. Input

| action | where | effect |
|---|---|---|
| `left`, `right`, `forward`, `backward` | `Input.get_vector("left", "right", "forward", "backward")` in `_physics_process()` | Horizontal movement direction. |
| `ui_accept` | `Input.is_action_just_pressed("ui_accept")` in `_physics_process()` | Jump, only when `is_on_floor()`. |
| `ui_cancel` | `_unhandled_input()` | Releases the mouse (`MOUSE_MODE_VISIBLE`). |
| any `InputEventMouseButton` | `_unhandled_input()` | Captures the mouse (`MOUSE_MODE_CAPTURED`). |
| `InputEventMouseMotion` | `_unhandled_input()` | Yaw on the body and clamp pitch to a maximum of 90° up and 80° down, further narrowed by the active behaviour's vertical look limit, before rotating `_cam_pitch_pivot`, while the mouse is captured and `control_enabled` is `true`; the child camera's local rotation is unchanged. Camera-limit passes also synchronize the pivot after a limit change. |

Jumping is implemented (`velocity.y = JUMP_VELOCITY` plus a jump sound), but there is **no `jump` action registered in `project.godot`** - only `forward`, `backward`, `left` and `right` are defined there. Jump is therefore bound to Godot's built-in `ui_accept` (space/enter) rather than to a dedicated game action.

## 5. Tuning constants

Declared at the top of `player.gd`. Note that only `JUMP_VELOCITY` (and the sound arrays) are actual `const`; the others are `var` even though they are used as constants.

| constant | value | effect |
|---|---|---|
| `JUMP_VELOCITY` | `3.5` | Upward velocity set on jump. |
| `FREEFALL_ACTIVATION_DELAY` | `0.5` s | Continuous time off the floor before the built-in freefall animation activates. |
| `PUSH_FORCE` | `0.5` | Magnitude of the central impulse applied to any `RigidBody3D` the player slides into, along `-collision.get_normal()`. |
| `HANDS_APPEAR_DURATION` | `0.1` | Declared but never read; hand opacity is driven by the `_setting_hands_opacity` animation track through `PositionToShaderParam`. |
| `FOOTSTEP_INTERVAL` | `SpeedScale.new(0.8, 0.36)` | Seconds between footsteps: `0.8` s at speed 1, `0.36` s at speed 3. Also sets the head-bob frequency. |
| `BOB_VERTICAL_AMPLITUDE` | `SpeedScale.new(0.02, 0.08)` | Vertical camera bob amplitude in metres: `0.02` at speed 1, `0.08` at speed 3. |
| `BOB_HORIZONTAL_AMPLITUDE` | `SpeedScale.new(0.005, 0.02)` | Horizontal camera sway amplitude in metres: `0.005` at speed 1, `0.02` at speed 3. |
| `MOVEMENT_LOWERING` | `SpeedScale.new(0.02, 0.15)` | How far the camera is lowered while moving: `0.02` m at speed 1, `0.15` m at speed 3 (applied negatively). |

`SpeedScale` is a small inner helper class holding two values, `at_speed_1` and `at_speed_3`. `at(speed)` linearly interpolates between them using `(speed - 1.0) / (3.0 - 1.0)` as the factor, i.e. it maps the current movement speed from the 1..3 m/s range onto the two given values. The factor is not clamped, so speeds below 1 or above 3 extrapolate.

Other hard-coded values worth knowing: camera position lerp uses `delta * 15.0`; hands yaw lerp uses `dt * 30.0`; mouse sensitivity is `0.01`, dropping to `0.0005` while a behaviour limits looking; camera-limit changes are applied immediately; footsteps play at `volume_db = -20.0` with `pitch_scale` randomised `0.9..1.3` (jump `0.9..1.0`, landing `0.8..1.1`).

## 6. Movement model

- Horizontal speed comes from `_current_speed()`: base `max_speed` (default `3.0`), multiplied by the active behaviour's `player_movement_multiplier` and capped by its `player_max_movement_speed`.
- When `behaviour_target` is set and the active behaviour's `player_max_movement_speed_to_target < max_speed`, the cap is interpolated between `player_max_movement_speed_to_target` and `max_speed` based on how far the movement direction deviates from the direction to the target (`factor = (distance_between_directions * 0.5)^2`, clamped to 1). Moving straight at the target is the slowest.
- With no input, `velocity.x/z` decay with `move_toward(..., 0, max_speed)` - i.e. one `max_speed` step per physics frame, which is effectively an instant stop.
- Gravity: `velocity += get_gravity() * delta` whenever not on the floor (also while `control_enabled == false`).
- Freefall animation: post-movement floor checks accumulate `real_delta`; the `freefall` blend activates only after more than `0.5` seconds continuously off the floor. Every landing resets the timer and deactivates the blend. This tracking also runs while controls are disabled; debug freecam suspends it along with player physics.
- `max_fall_speed`: if `> 0.0`, `velocity.y` is clamped to `>= -max_fall_speed`. Default `0.0` means unlimited fall speed.
- Jump: `velocity.y = JUMP_VELOCITY` (3.5) plus a random jump sound; a landing sound plays on the frame the player goes from airborne to on-floor.
- Head bob runs only when `is_on_floor()` and `velocity.length() > 0.1`. `_bob_phase` advances by `delta * (PI / FOOTSTEP_INTERVAL.at(speed))` and wraps at `2*PI`; vertical offset is `BOB_VERTICAL_AMPLITUDE.at(speed) * abs(sin(phase))`, horizontal offset is `BOB_HORIZONTAL_AMPLITUDE.at(speed) * sin(phase)`.
- Movement lowering adds `-MOVEMENT_LOWERING.at(speed)` to the camera Y while moving. Head-bob and movement-lowering offsets ease separate camera-local X/Y offsets with `lerp(..., delta * 15.0)`; behaviour camera offsets move the camera itself in player-root XYZ axes at their configured shared speed, without translating the pitch pivot.
- Footstep interval scales with speed via `FOOTSTEP_INTERVAL.at(speed)`. The first step after standing still plays `_footstep_start_sound` and resets both the timer and the bob phase; afterwards a random footstep plays every interval and the bob phase is snapped to the nearest multiple of `PI`.
- Collision push: after `move_and_slide()`, every slide collision against a `RigidBody3D` gets `apply_central_impulse(-collision.get_normal() * PUSH_FORCE)`.

## 7. AnimationTree behaviours

`PlayerBehaviour` (`assets/scripts/player_behaviour.gd`) tracks named player behaviours while the existing `AnimationTree` continues to select and blend animations. Each behaviour reports one of `PlayerBehaviour.BehaviourStatus.IDLE`, `ENABLING`, `ACTIVE`, or `DISABLING`; `player.gd` advances blend values during `_physics_process()` and refreshes the active settings before movement and mouse input consume them.

The player registers `freefall` against `parameters/freefall/blend_amount`. It automatically blends in after more than `0.5` seconds off the floor and blends out on landing, independently of the `run` blend; this also works while `control_enabled` is false.

In `character_main.tscn`, the player resolves `_skeleton_modifier_headpitch` separately from `_skeleton_modifier_perspective_hands`. While the registered `push` behaviour is active and `behaviour_target` is set, `_handle_hands_aim()` smoothly turns only the perspective-hands modifier's `extra_rotation_degrees.y` toward the target in player-local space. It eases that yaw back to neutral when the target clears or the push blend finishes, including while controls are disabled; the head-pitch modifier and the hands modifier's X/Z rotations remain unchanged.

`Player.get_behaviour_status(unique_name)` returns the `PlayerBehaviour.BehaviourStatus` enum for a registered behaviour and reports an error for an unknown name. Blend behaviours are `ENABLING` while their target is one and their blend is below one, `ACTIVE` at a blend of one, `DISABLING` while targeted to zero with a nonzero blend, and `IDLE` at zero; reversing a fade changes the status back to `ENABLING`. A pending one-shot request is `ENABLING`, playback is `ACTIVE`, playback after an abort request is `DISABLING` until the AnimationTree stops it, and a cancelled-before-playback or completed request is `IDLE`. The empty-parameter behaviour is always `ACTIVE`. `PlayerBehaviour.is_behaviour_active(unique_name)` remains true for all states other than `IDLE`, including while a behaviour is fading out.

Register and control a behaviour through `Player`:

```gdscript
add_behaviour(unique_name: String, p_animation_tree_parameter: StringName = "", p_additional_settings: Dictionary = {}) -> void
activate_behaviour(unique_name: String) -> void
deactivate_behaviour(unique_name: String) -> void
get_behaviour_status(unique_name: String) -> PlayerBehaviour.BehaviourStatus
```

- An empty animation parameter is an always-active settings entry; `player.gd` registers the empty-name entry with default settings.
- A parameter ending in `/blend_amount` is ramped toward `1.0` on activation and `0.0` on deactivation. General settings apply while the status is non-idle, including while the blend fades out; `player_camera_offset` applies only during `ENABLING` and `ACTIVE`.
- A parameter ending in `/request` is treated as an `AnimationNodeOneShot` request. Activation writes `ONE_SHOT_REQUEST_FIRE`; general settings apply while the request is pending and while the corresponding `/active` parameter is true. Deactivation writes `ONE_SHOT_REQUEST_ABORT`; a playing one-shot is `DISABLING` until playback stops, and its camera offset is omitted immediately.
- Non-idle behaviours' general settings are combined in registration order. Unspecified keys remain intact; when multiple eligible behaviours specify the same setting, the later registered behaviour wins. `player_camera_offset` is eligible only from `ENABLING` and `ACTIVE` behaviours.
- Restriction setting keys are copied exactly as registered and must use the canonical `player_` prefix: `player_max_look_freedom_degrees` (common fallback), `player_max_look_freedom_degrees_h`, `player_max_look_freedom_degrees_v`, `player_movement_multiplier`, `player_max_movement_speed`, and `player_max_movement_speed_to_target`. Look-freedom values are full angles; the player uses half as the positive and negative limit. Defaults are `360.0` degrees and movement multiplier `1.0`; speed caps default to `99999.0`.
- Camera framing keys are `player_camera_offset` (a player-root-relative `Vector3` in metres, default `Vector3.ZERO`) and `player_camera_offset_speed` (metres per second, default `1.0`). These are generic setting defaults; the built-in `run` behaviour supplies its own offset and speed. Each vector component moves independently with the shared speed using `move_toward`, so large frame deltas do not overshoot; when offset settings are released, the last active speed is retained for the return to zero. Camera offsets contribute only during `ENABLING` and `ACTIVE`; when a behaviour enters `DISABLING`, a lower-priority active offset takes over immediately or the camera returns to zero, while its other settings (including offset speed) can remain active through the fade. Offsets also update while controls are disabled and are converted into the camera parent's basis so attachment and pitch rotation do not rotate the requested player-relative displacement. Head-bob and movement-lowering remain separately composed with this displacement, and the pitch pivot stays at its original position.
- `actions_at_millisecond` is accepted in the settings dictionary but is not executed; timed animation actions remain deferred.

`scenes/lvl_0/lvl_0.gd` registers `lvl_0_landing` with `parameters/lvl_0_landing/request`, horizontal and vertical look limits, and `movement_multiplier: 0.0`. It activates the behaviour on the player's first landing, so those restrictions follow the one-shot animation instead of an old equip/dequip state machine.

`scenes/frontroom_0/frontroom_0.gd` activates the built-in `push` blend when the player is less than `1.0` m from a moving box and assigns that box to `behaviour_target`. The target-relative cap reaches `0.15` m/s when moving directly toward the box; leaving range clears the target and deactivates the blend.

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

`scenes/lvl_0/lvl_0.gd` registers `lvl_0_landing` in `_ready()` with AnimationTree parameter `parameters/lvl_0_landing/request` and these settings:

| setting | value |
|---|---:|
| `player_max_look_freedom_degrees_v` | `10.0` |
| `player_max_look_freedom_degrees_h` | `0.0` |
| `player_movement_multiplier` | `0.0` |

The level activates it once, when `_handle_player_landing()` detects the player on the floor. The request starts the existing OneShot node in the player scene; movement and look restrictions remain active through playback and release when the node becomes inactive. The registration also has `actions_at_millisecond` entries, but the player currently does not execute them.

Voice is normally not driven from level code directly: `assets/scripts/trigger.gd` calls `get_player().replace_voice(sounds)`, `push_back_voice(sounds)` or `push_front_voice(sounds)` depending on its `Mode` (`PlayerVoice_Replace`, `PlayerVoice_PushBack`, `PlayerVoice_PushFront`).

unclear: `apply_footsteps()`, `apply_footstep_start_sound()` and `apply_jump_sounds()` are not called anywhere in the repository, so every level currently uses the default sound sets.

## 10. Known gaps

- No health, damage or death model of any kind.
- No inventory or pickup system.
- `actions_at_millisecond` is accepted in behaviour settings but timed animation actions are not implemented.
- No `jump` input action in `project.godot`; jumping is hard-wired to `ui_accept`. Only `forward`, `backward`, `left`, `right` are registered.
- `HANDS_APPEAR_DURATION` is declared but never used.
- Most "constants" (`FOOTSTEP_INTERVAL`, `BOB_*`, `MOVEMENT_LOWERING`, `HANDS_APPEAR_DURATION`, `PUSH_FORCE`) are `var`, not `const`, which contradicts the project convention.
- Dead/commented-out code remains: the `active_voice_sequence` property and `_on_active_voice_sequence_changed()`, `_update_speed_cap(delta)`, and an empty `_process()`.
- `apply_jump_sounds()` exists but there is no `apply_landing_sounds()`, so landing sounds cannot be overridden per level.
- `_play_next_voice()` prints the subtitle path to stdout on every line (`print("Playing subtitle: " + ...)`).
- `_ensure_sound_controller()` has a typo in its log message: "Scene foes not contain a sound controller".
- `SpeedScale.at()` does not clamp, so speeds outside 1..3 m/s extrapolate the bob/footstep values.
- `_find_ingame_ui()` searches the whole tree every time the player enters a scene; if no `IngameUI` exists, `_ready()` pushes an error and then still dereferences `_ingame_ui`.
- `player.gd` and `player_behaviour.gd` still contain unfinished or commented-out code.

## 11. Related

- [../ARCHITECTURE.md](../ARCHITECTURE.md)
- [../CONVENTIONS.md](../CONVENTIONS.md)
- [./ui_subtitles.md](./ui_subtitles.md)
- [./audio.md](./audio.md)
- [./interaction.md](./interaction.md)
