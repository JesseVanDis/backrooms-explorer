# System: Audio

> **Status:** partial
> **Code:** `assets/scripts/sound_controller.gd`, `assets/scripts/physics_sounds.gd`
> **Buses:** `RaytracedReverb`, `RaytracedAmbient`

## 1. Responsibility

What this system covers:

- Driving the reverb effect of the `raytraced_audio` addon per level, through `SoundController`.
- Impact ("bonk") and sliding sounds for loose rigid bodies, through `PhysicsSounds`.
- The offline voice pipeline: `.flac` recordings converted to imported `.ogg` by `tools/parse.sh`.
- The naming and folder convention for per-scene voice and ambience audio.

What this system does **not** cover:

- Playback and queueing of player voice lines and footsteps: that lives in `assets/scripts/player.gd`,
  see [./player.md](./player.md).
- Displaying the matching subtitle text: see [./ui_subtitles.md](./ui_subtitles.md).

## 2. Bus layout and the raytraced_audio addon

Relevant `project.godot` entries:

| Section            | Key                       | Value                   |
|--------------------|---------------------------|-------------------------|
| `[audio]`          | `buses/default_bus_layout`| `uid://bbann6iux08g2`   |
| `[editor_plugins]` | `enabled`                 | `PackedStringArray("res://addons/raytraced_audio/plugin.cfg")` |
| `[raytraced_audio]`| `reverb_bus`              | `&"RaytracedReverb"`    |
| `[raytraced_audio]`| `ambient_bus`             | `&"RaytracedAmbient"`   |

Hard requirements:

- The bus named `RaytracedReverb` must exist, and the effect at **index 0** on that bus must be an
  `AudioEffectReverb`. `SoundController` addresses that effect by index only; if the bus is missing,
  the slot is empty, or the effect is a different class, it calls `push_error(...)` and does nothing.
- `addons/` is third party and must **never** be modified. All project-side control over the reverb
  happens through `SoundController`, not by editing the addon.
- 3D audio sources used by the addon appear in scenes as `RaytracedAudioPlayer3D` nodes (for example
  the player's `RaytracedAudioPlayer3D_Voice` and `RaytracedAudioPlayer3D_Foot`).

## 3. SoundController

`assets/scripts/sound_controller.gd`, `extends Node`, `class_name SoundController`.

- Constant: `RAYTRACED_REVERB_BUS_NAME: StringName = &"RaytracedReverb"` - the only bus this script touches.
- On `_ready()` it applies the exported values to the reverb effect; on `_exit_tree()` it resets the
  effect back to the `DEFAULT_*` constants and disables it, so leaving a level cannot leak its reverb
  into the next one.
- Every exported property has a setter that re-applies all settings immediately, so it is live-editable
  in the editor and at runtime.

| @export                | Type    | Default (constant)                     | Meaning |
|------------------------|---------|----------------------------------------|---------|
| `reverb_enabled`       | `bool`  | `false`                                | Enables/disables effect 0 on the `RaytracedReverb` bus. |
| `room_size`            | `float` | `1.0` (`DEFAULT_ROOM_SIZE`)            | `AudioEffectReverb.room_size`, range 0.0 - 1.0. |
| `damping`              | `float` | `0.5` (`DEFAULT_DAMPING`)              | `AudioEffectReverb.damping`, range 0.0 - 1.0. |
| `spread`               | `float` | `1.0` (`DEFAULT_SPREAD`)               | `AudioEffectReverb.spread`, range 0.0 - 1.0. |
| `high_pass`            | `float` | `1.0` (`DEFAULT_HIGH_PASS`)            | Mapped to `AudioEffectReverb.hipass`, range 0.0 - 1.0. |
| `dry`                  | `float` | `1.0` (`DEFAULT_DRY`)                  | `AudioEffectReverb.dry`, range 0.0 - 1.0. |
| `wet`                  | `float` | `0.5` (`DEFAULT_WET`)                  | `AudioEffectReverb.wet`, range 0.0 - 1.0. |
| `predelay_msec`        | `float` | `150.0` (`DEFAULT_PREDELAY_MSEC`)      | `AudioEffectReverb.predelay_msec`, range 0.0 - 500.0. |
| `predelay_feedback`    | `float` | `0.4` (`DEFAULT_PREDELAY_FEEDBACK`)    | `AudioEffectReverb.predelay_feedback`, range 0.0 - 1.0. |

All exports sit in the `Reverb Options` group.

Auto-provisioning: `player.gd` calls `_ensure_sound_controller()` on startup. It searches the current
scene (falling back to the scene tree root) for an existing node of type `SoundController`; if there is
none, it loads `res://assets/scripts/sound_controller.gd`, creates a plain `Node` named
`SoundController` and adds it as a child of the player. So a level without an explicit controller still
gets one - with the defaults above, which means `reverb_enabled == false`.

## 4. PhysicsSounds

`assets/scripts/physics_sounds.gd`, `extends RigidBody3D`, `class_name PhysicsSounds`.

| @export            | Type             | Default                                            | Meaning |
|--------------------|------------------|----------------------------------------------------|---------|
| `slide_sound`      | `AudioStreamWAV` | `SLIDE_DEFAULT` = `res://assets/sounds/slide_2.wav` | Looping-ish sound faded in while the body slides. |
| `slide_volume_db`  | `float`          | `0.0`                                              | Initial `volume_db` of the slide player. |
| `slide_pitch_scale`| `float`          | `1.0`                                              | `pitch_scale` of the slide player. |
| `bonk_sound`       | `AudioStreamWAV` | `BONK_DEFAULT` = `res://assets/sounds/bonk_1.wav`   | Impact sound played on body contact. |
| `bonk_volume_db`   | `float`          | `0.0`                                              | Initial `volume_db` of the bonk player. |
| `bonk_pitch_scale` | `float`          | `1.0`                                              | Base pitch of the bonk; randomised by `randf_range(0.9, 1.1)` per hit. |

unclear: the two defaults are declared as `const ... : AudioStream = preload(...)` while the exports are
typed `AudioStreamWAV`. That is what the code says; it works because the `.wav` resources import as
`AudioStreamWAV`.

Constants:

| Constant                         | Value | Meaning |
|----------------------------------|-------|---------|
| `SLIDE_SOUND_VELOCITY_THRESHOLD` | `0.3` | Minimum `linear_velocity.length()` before the slide sound fades in. |
| `SLIDE_SOUND_FADE_IN_SPEED`      | `10.0`| Fade-in rate of the slide volume. |
| `SLIDE_SOUND_FADE_OUT_SPEED`     | `10.0`| Fade-out rate of the slide volume. |
| `MIN_IMPULSE_FOR_BONK`           | `0.5` | Declared threshold for the bonk. unclear: it is declared but never read anywhere in the script; `_on_body_entered` does not consult an impulse. |

Behaviour:

- `_ready()` creates two `AudioStreamPlayer3D` children at runtime (slide + bonk), sets
  `contact_monitor = true`, raises `max_contacts_reported` to at least `3`, and connects `body_entered`.
  **Contact monitoring must stay on**, otherwise `body_entered` never fires and there is no bonk.
- A `_startup_timer` of `2.0` seconds suppresses all sound after spawn, so objects settling at level
  load stay quiet.
- The slide volume is lerped towards 1.0 while the body is "laying flat" and moving faster than the
  threshold, otherwise towards 0.0; the player is started/stopped around a `0.001` volume threshold.
- Collisions with the player are ignored: `_on_body_entered` returns early `if body is Player`.
- The bonk is re-triggered only if it is not already playing or its playback position is past `0.1` s.

Public function:

```gdscript
func is_boxshape_laying_float(tollerance_degrees: float) -> bool
```

Returns `true` when any of the body's local axes (X, Y or Z) is within `tollerance_degrees` of world up
(or of straight down), i.e. the box is resting on a flat face. Note the **existing typo** in the name
(`tollerance` / `is_boxshape_laying_float`). It is part of the public API and must **NOT** be renamed as
part of unrelated work - rename it only in a dedicated change that updates every call site.

## 5. Voice pipeline

Voice lines are recorded/generated as `.flac` and converted offline; Godot only ever imports the
generated `.ogg`.

```
scenes/<scene>/voice/voice_<event>.flac        (source, committed)
        |
        |  tools/parse.sh --flac_to_ogg_for_import [IN] [OUT]
        |  (no args -> finds every folder named "voice" and writes to <voice>/gen)
        |  ffmpeg -i <in> -y -acodec libvorbis <out>
        v
scenes/<scene>/voice/gen/voice_<event>.ogg     (generated, committed with its .import)
        |
        v
imported by Godot -> referenced from the .tscn as an AudioStream
```

- The script requires `ffmpeg` on `PATH` and aborts with an error if it is missing.
- Conversion is incremental: modification times are cached in `tools/.parse_sh_latest_changes.txt`
  (lines of `path:mtime`). Unchanged `.flac` files are skipped.
- Each generated folder gets a `README.txt` stating that the `.ogg` files must not be edited by hand -
  edit the `.flac` and re-run `parse.sh`.
- **Rule:** scenes and scripts reference the generated `voice/gen/*.ogg`, never the `.flac`. For example
  `frontroom_0.tscn` references `res://scenes/frontroom_0/voice/gen/voice_im_home.ogg`.
- Subtitles are found from the audio path: `player.gd` maps `.../gen/<name>.ogg` back to
  `.../<name>_sub_en.srt` next to the `.flac`. Keeping the names in sync is therefore mandatory.
- Voice generation settings per voice actor (ElevenLabs model, stability, similarity, starting lines)
  live in the table in [../../../TECHNICAL.md](../../../TECHNICAL.md#voices).

## 6. Naming and folder layout

- Voice files: `voice_<event>.flac`, lower snake case, event-based, for example
  `voice_first_box_encounter.flac`, `voice_boxes_gone.flac`, `voice_anybody_there.flac`.
- Subtitle files: `voice_<event>_sub_en.srt`, next to the `.flac` in `voice/`.
- Per scene layout:

```
scenes/<scene>/voice/           *.flac sources + *_sub_en.srt subtitles
scenes/<scene>/voice/gen/       README.txt + generated *.ogg (+ *.ogg.import)
```

  Present today in `scenes/lvl_0/voice/` (13 lines, e.g. `voice_landing`, `voice_yell_hello`,
  `voice_why_stuck`) and `scenes/frontroom_0/voice/` (e.g. `voice_home`, `voice_im_home`,
  `voice_more_boxes`, `voice_slip_fall`, `voice_scream_jen`).
  unclear: `scenes/frontroom_0/voice/` also contains a `lossless_to_ogg_for_import.sh`, which looks like
  an older per-scene variant of the `tools/parse.sh` step.

- Shared, non-voice sounds live flat in `assets/sounds/` (`bonk_1.wav`, `slide_1.wav`, `slide_2.wav`,
  `door_open_1.wav`, `door_close_1.wav`, `jump_start_1.wav`, `silence_1s.ogg`, `silence_3s.ogg`, ...).
- Level specific ambience lives next to the level scene. In `scenes/lvl_0/`:

| File                          | Use |
|-------------------------------|-----|
| `bg_outside.mp3`              | Outside/background ambience (also referenced from `frontroom_0.tscn`). |
| `fluorescent-light-buzz.mp3`  | Continuous buzz of the fluorescent lighting. |
| `fluorescent-lamp-flick.wav`  | One-shot flicker of a lamp. |

## 7. Known gaps

- No volume or mixer settings anywhere: no master/music/sfx/voice volume sliders, nothing persisted,
  and `SoundController` only touches the reverb effect - never bus volumes.
- No music system at all.
- No per-surface footstep sets. Footsteps are a single `AudioStreamPlayer3D` on the player; the material
  underfoot is not taken into account.
- `MIN_IMPULSE_FOR_BONK` is declared but unused, so bonks are impulse-independent: any non-player contact
  after the startup timer plays the sound at the same strength.
- `PhysicsSounds` has no `linear_velocity`-based pitch or volume modulation beyond the fade; the slide
  fade is binary (above/below the threshold).
- No ambient zone / reverb zone system. Reverb is one global setting per level, not per room.
- No audio occlusion or distance-based filtering beyond what the `raytraced_audio` addon provides.
- Voice is placeholder AI narration; see [../../../TECHNICAL.md](../../../TECHNICAL.md#voices).
- Only English subtitles exist (`_sub_en.srt`); there is no language selection.

## 8. Related

- [../ARCHITECTURE.md](../ARCHITECTURE.md) - how the systems are wired together at runtime.
- [./player.md](./player.md) - voice queueing (`replace_voice`, `push_back_voice`, `push_front_voice`) and footsteps.
- [./ui_subtitles.md](./ui_subtitles.md) - SRT parsing and subtitle display.
- [./tooling.md](./tooling.md) - `tools/parse.sh` and the other helper scripts.
