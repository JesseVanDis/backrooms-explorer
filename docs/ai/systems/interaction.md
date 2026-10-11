# System: Interaction

> **Status:** implemented
> **Code:** `assets/scripts/trigger.gd`, `assets/scripts/door.gd`

## 1. Responsibility

This system covers the two ways the world currently reacts to the player:

- `Trigger` - an invisible volume that fires **once** when its target enters it, leaves it, or looks at
  a given node from inside it. It then plays a sound or queues player voice lines.
- `Door` - a door mesh that swings open and closed automatically based on the player's distance and on
  which side of the door the player stands.

Both are proximity based and fully automatic. There is no "press a key to use" interaction in the game
today - see [5. Known gaps](#5-known-gaps).

## 2. Trigger

`assets/scripts/trigger.gd`, `extends Area3D`, `class_name Trigger`.

Place it as an `Area3D` with a `CollisionShape3D` child and assign the script.

### @export properties

| @export             | Type                 | Default           | Meaning |
|---------------------|----------------------|-------------------|---------|
| `trigger_object`    | `Node3D`             | `null`            | The body that must enter/leave the area. If empty, the player is used as default (resolved through `get_player()`). |
| `mode`              | `Mode`               | `Mode.None`       | What happens when the trigger fires. See the Mode table. |
| `sounds`            | `Array[AudioStream]` | `[]`              | The sound, or the voice sequence, used by `mode`. |
| `trigger_delay_ms`  | `int`                | `0`               | Delay in milliseconds between the condition being met and the action running. |
| `condition`         | `Condition`          | `Condition.OnEnter` | When the trigger fires. In the `Condition` export group. |
| `condition_arg_node`| `Node3D`             | `null`            | Extra argument for the condition; required by `WhileInside_PlayerLookAtNode`. In the `Condition` export group. |

### Mode

| Value                   | Int | Effect |
|-------------------------|-----|--------|
| `None`                  | 0   | Plays `sounds` on the trigger's own `AudioStreamPlayer3D`. Empty array: does nothing. Exactly one stream: plays it. More than one: `push_error("Non-voice sound sequence not implemented yet.")` - **not implemented**. |
| `PlayerVoice_Replace`   | 1   | `get_player().replace_voice(sounds)` - stops the current line and subtitles and starts this sequence. |
| `PlayerVoice_PushBack`  | 2   | `get_player().push_back_voice(sounds)` - appends to the end of the pending voice queue. |
| `PlayerVoice_PushFront` | 3   | `get_player().push_front_voice(sounds)` - inserts in front of the pending queue (the line already playing is not cut). |

### Condition

| Value                           | Int | Fires when |
|---------------------------------|-----|------------|
| `OnEnter`                       | 0   | The target body is inside the area. |
| `OnLeave`                       | 1   | The target body has been inside at some point *and* is no longer inside. |
| `WhileInside_PlayerLookAtNode`  | 2   | The target body is inside the area **and** the player looks at `condition_arg_node`. The check is a dot product: `forward = -camera.global_basis.z`, `to_node = (condition_arg_node.global_position - camera.global_position).normalized()`, fires when `forward.dot(to_node) > 0.85` (the code comments this as approximately 30 degrees). The camera is found with `UtilsNode.find_camera_recursive(get_player())`. If `condition_arg_node` is `null`, `_ready()` emits a `push_error`. |

Note: the look-at condition always uses the **player's** camera, even when `trigger_object` points at a
different body.

### Firing and delay

- The condition is polled every frame in `_process`. Once it is met, `_has_triggered` is set to `true`
  and the trigger never fires again; there is no reset or `one_shot` toggle.
- The trigger prints `Triggered '<node path>'` when it fires.
- `trigger_delay_ms` is applied **inside** `_trigger()`, after `_has_triggered` was already set:
  `await get_tree().create_timer(trigger_delay_ms / 1000.0).timeout`. So the delay postpones the action,
  not the detection, and leaving the area during the delay does not cancel it. A value of `0` means no
  await at all.
- `_ready()` creates its own `AudioStreamPlayer3D` child at runtime (used by `Mode.None`) and connects
  `body_entered` / `body_exited`.

### Public functions

```gdscript
func get_player() -> Player
```

Lazily resolves and caches the player through `UtilsNode.find_player(get_tree())`. If no player is
found it calls `push_error("Player not found in trigger.gd")` and returns `null`.

## 3. Door

`assets/scripts/door.gd`, `extends MeshInstance3D`, no `class_name`. Assign the script directly to the
door mesh; the script rotates that mesh around its own Y axis.

### Constants

| Constant                        | Value      | Meaning |
|---------------------------------|------------|---------|
| `OPEN_ANGLE`                    | `PI / 2.0` | Swing of the door when open, 90 degrees, relative to its initial Y rotation. |
| `CLOSE_ANGLE`                   | `0.0`      | Closed reference angle. |
| `DOOR_SPEED`                    | `5.0`      | Base factor in the `lerp_angle` towards the target angle. |
| `DETECTION_RANGE`               | `1.5`      | Default `detection_distance` (player on the non-opening side). |
| `OPENING_SIDE_DETECTION_RANGE`  | `2.5`      | Default `opening_side_detection_distance` (player on the side the door swings towards). |

### @export properties

| @export                            | Type          | Default                                       | Meaning |
|------------------------------------|---------------|-----------------------------------------------|---------|
| `open_clockwise`                   | `bool`        | `true`                                        | Direction of the swing. The applied offset is `-OPEN_ANGLE` when true, `+OPEN_ANGLE` when false. It also inverts which side counts as the "opening side". |
| `detection_distance`               | `float`       | `DETECTION_RANGE` (`1.5`)                     | Open radius when the player is *not* on the opening side. |
| `opening_side_detection_distance`  | `float`       | `OPENING_SIDE_DETECTION_RANGE` (`2.5`)        | Open radius when the player *is* on the opening side. |
| `mesh_rotation_degrees`            | `float`       | `0.0`                                         | Correction for a door mesh that is not modelled facing the default direction; used when building the door normal. |
| `sound_open`                       | `AudioStream` | `load("res://assets/sounds/door_open_1.wav")` | Played when the door starts opening. |
| `sound_close`                      | `AudioStream` | `load("res://assets/sounds/door_close_1.wav")`| Played when the door has finished closing. |

### State machine and motion

`DoorState` is an internal enum: `CLOSED`, `OPENING`, `OPEN`, `CLOSING`.

- `_ready()` stores `_initial_rotation_y` from the node's current `rotation.y`, starts in `CLOSED`, and
  creates an `AudioStreamPlayer3D` child **at runtime** (`_audio_player`) - do not add one in the scene.
  It also resolves the player eagerly via `get_player()`.
- Every frame the distance from the door to the player is compared with the detection distance returned
  by `_get_detection_distance(player)`:
  - closer: target angle becomes `_initial_rotation_y + offset`; if the state was `CLOSED` or `CLOSING`
    it becomes `OPENING` and `sound_open` plays immediately.
  - further: target angle becomes `_initial_rotation_y`; if the state was `OPEN` or `OPENING` it becomes
    `CLOSING`. `sound_close` only plays once the door has actually reached the closed angle.
- "Reached" means `abs(angle_difference(rotation.y, _target_angle)) < 0.01`.
- Motion: `rotation.y = lerp_angle(rotation.y, _target_angle, minf(1.0, delta * (_state_time * 8.0) * DOOR_SPEED))`
  where `_state_time` is the time since the last state change, so the door eases in rather than snapping.
- `get_player()` caches `UtilsNode.find_player(get_tree())`; `_process` returns early while it is `null`.
  Note: unlike `trigger.gd`, `door.gd` does **not** `push_error` when the player is missing.

### Which side is the player on

`_get_detection_distance()` works in 2D (XZ plane):

1. `door_normal = Vector2(0, 1).rotated((-_initial_rotation_y) - rad_to_deg(mesh_rotation_degrees))`
2. `dir_to_player_2d = Vector2(delta.x, delta.z).normalized()`
3. `dot = door_normal.dot(dir_to_player_2d)`; `is_on_opening_side = dot > 0.0`
4. if `open_clockwise` the test is inverted: `is_on_opening_side = dot < 0.0`
5. returns `opening_side_detection_distance` when on the opening side, else `detection_distance`

The effect is that the door notices you earlier (2.5 m by default) when you approach from the side it
swings towards, so it is out of the way before you walk into it.

unclear: step 1 mixes units - `_initial_rotation_y` is radians while `rad_to_deg(mesh_rotation_degrees)`
converts a value that is already named "degrees" into degrees-from-radians, and the result is fed to
`Vector2.rotated()`, which expects radians. This looks like a bug, but it is what the code does; it has
no visible effect while `mesh_rotation_degrees` stays at its default `0.0`.

## 4. How to place one in a level

Both examples mirror what `scenes/frontroom_0/frontroom_0.tscn` actually does.

**A. Voice line when the player walks into a room** (`trigger_sfx_start` in `frontroom_0`):

1. Add an `Area3D` named `trigger_sfx_<event>` with a `CollisionShape3D` (a box) covering the spot.
2. Assign `res://assets/scripts/trigger.gd`.
3. Leave `trigger_object` empty so it defaults to the player, leave `condition` on `OnEnter`.
4. Set `mode = PlayerVoice_Replace` (`1`) and put one generated voice stream in `sounds`, for example
   `res://scenes/frontroom_0/voice/gen/voice_home.ogg`.

`trigger_sfx_first_box_encounter` is the same thing with `mode = PlayerVoice_PushBack` (`2`) and two
streams in `sounds` (`voice_first_box_encounter.ogg`, `voice_im_home.ogg`), so the two lines play back to
back after whatever is already queued.

**B. Reacting to an object instead of the player** (`trigger_sfx_boxes_clip` in `frontroom_0`):

1. Add the `Area3D` + `CollisionShape3D` + `trigger.gd` as above, and set `collision_layer` /
   `collision_mask` so the object's physics layer is actually detected (that node uses `5` for both).
2. Set `trigger_object` to the body, e.g. `NodePath("../MovingBox1")`.
3. Set `mode = PlayerVoice_Replace` (`1`) and `sounds` to the reaction line
   (`voice_boxes_gone.ogg`).

Always reference the generated `voice/gen/*.ogg`, never the `.flac` - see [./audio.md](./audio.md).

## 5. Known gaps

- No generic "use"/"interact" input action exists. `project.godot` defines no such action and neither
  script reads input; everything is proximity or look-at driven.
- No pickup, carry or inventory system. Boxes are plain `RigidBody3D` / `PhysicsSounds` objects that can
  only be pushed by walking into them.
- No entity interaction at all: there are no NPCs or entities to interact with.
- `Trigger` fires exactly once per level load and cannot be reset, repeated, or disabled from script.
- `Mode.None` with more than one stream is not implemented and only emits
  `push_error("Non-voice sound sequence not implemented yet.")`.
- `Trigger` exposes no signal; other scripts cannot react to a trigger firing, only the built-in modes run.
- `Door` always opens for the player only, cannot be locked, blocked or opened by any other body, and has
  no `class_name`, so it cannot be type-checked from other scripts.
- `Door` plays `sound_open` the moment it starts opening but `sound_close` only after it is fully closed,
  which is asymmetric.
- No TODO/FIXME comments are present in either file; the only in-code marker is the `push_error` above.

## 6. Related

- [../ARCHITECTURE.md](../ARCHITECTURE.md) - how the systems are wired together at runtime.
- [./player.md](./player.md) - `replace_voice` / `push_back_voice` / `push_front_voice` and the camera used by the look-at condition.
- [./audio.md](./audio.md) - buses, the voice pipeline and the shared sounds in `assets/sounds/`.
