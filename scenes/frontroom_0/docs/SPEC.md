# Spec: Frontrooms 0 - Home

> **Wiki:** not a Backrooms level. This is "the Frontrooms", the ordinary world the player
> no-clips out of. See <https://backrooms-wiki.wikidot.com/frontrooms>
> **Scene:** `scenes/frontroom_0/frontroom_0.tscn`
> **Entry script:** `scenes/frontroom_0/frontroom_0.gd`
> **State:** in-progress
> **Accuracy estimate:** n/a - this level is original content, not canon

## 1. One paragraph pitch

The player comes home from work to a half-unpacked house and starts shoving moving boxes out of
the hallway, calling for Jen, who never answers. One box falls straight through the floor. Then
so does the player.

## 2. Purpose in the game

This is the **tutorial and the hook**. It has to do three jobs before the player ever sees the
Backrooms:

| Job                                   | How                                                        |
|---------------------------------------|-------------------------------------------------------------|
| Teach movement                        | A normal, safe house the player walks through freely         |
| Teach the only interaction verb       | Walking into a moving box pushes it (`wield_push`)           |
| Establish normality, then break it    | Warm lit house + unanswered calls -> a box no-clips away     |

Everything here exists to make Level 0 land. Do not add mechanics that Level 0 does not use.

## 3. Entrances

| From       | How                                   | Implemented |
|------------|---------------------------------------|-------------|
| Game start | `menu_intro.tscn` fades out over the scene | yes      |

`_ready()` disables player control, instantiates `menu_intro.tscn` as a child of the tree root,
then fades it out over 2 seconds and re-enables control.

> `INTRO_WAIT_TIME` is currently `0.0`, so the intro is effectively skipped. Raise it when the
> intro screen actually has content.

## 4. Exits

| To      | How                                           | Condition                           | Implemented |
|---------|-----------------------------------------------|-------------------------------------|-------------|
| `lvl_0` | The player no-clips through the floor and falls | `player.global_position.y < -15.0` | yes        |

`lvl_0` is preloaded during `_ready()`, so the swap should be seamless by the time the player
falls. The fall itself is dressed with `transition_frontrooms_lvl_0.tscn` and
`frontroom_0_tunnel_to_lvl_0.gdshader`.

## 5. Hazards and rules

There is no way to die, no enemy and no fail state. The only scripted rules are:

- Player within `1.0` m of one of the four `MovingBox*` bodies -> `active_wieldable` becomes
  `"wield_push"` and `wield_target` becomes that box. Outside that range both are cleared.
- Player below `y = -5.0` -> fog starts rolling in.
- Player below `y = -10.0` -> fog is at full density (`0.1`) and fully affects the sky.
- Player below `y = -15.0` -> transition to `lvl_0` starts.

These thresholds are the constants `Y_START`, `Y_END`, `FOG_DENSITY_END`, `SKY_AFFECT_END` and
`OPEN_LVL_0_TRIGGER_Y` in `frontroom_0.gd`.

## 6. Player capabilities required

| Capability             | System spec                                               | Exists |
|------------------------|-----------------------------------------------------------|--------|
| Walking, look around   | [player](../../../docs/ai/systems/player.md)               | yes    |
| Control lock           | `player.control_enabled`                                   | yes    |
| Pushing rigid bodies   | [player](../../../docs/ai/systems/player.md#7-wieldables)  | yes    |
| Impact / slide sounds  | [audio](../../../docs/ai/systems/audio.md)                 | yes    |
| Proximity voice lines  | [interaction](../../../docs/ai/systems/interaction.md)     | yes    |
| Subtitles              | [ui_subtitles](../../../docs/ai/systems/ui_subtitles.md)   | yes    |
| Level transition       | [level_flow](../../../docs/ai/systems/level_flow.md)       | yes    |

## 7. Technical approach

Handcrafted, not generated. The house is a single imported model (`frontrooms_0.gltf` ->
`frontrooms_0_model.tscn`) with a baked lightmap (`frontroom_0.lmbake`) and a custom sky shader
(`frontroom_0_sky.gdshader`) using `frontroom_0.exr`. Boxes are `RigidBody3D` nodes with
`PhysicsSounds`. Narration is driven by `Trigger` nodes placed in the scene.

> Reminder: the house model is an imported object. Per `AGENTS.md`, never touch nodes **inside**
> it - only nodes Godot itself created.

## 8. Assets present

| Asset                                   | Type    | Status |
|-----------------------------------------|---------|--------|
| `frontrooms_0.gltf` / `.bin`            | model   | done   |
| `frontrooms_0_model.tscn`               | scene   | done   |
| `frontroom_0.lmbake`                    | lightmap| baked  |
| `frontroom_0_sky.gdshader` + `.exr`     | shader  | done   |
| `frontroom_0_tunnel_to_lvl_0.gdshader`  | shader  | done   |
| `transition_frontrooms_lvl_0.tscn`      | scene   | done   |
| Bicycle / doorway props heard in script | model   | missing - the opening bicycle sound has no visual |

`garden.blend1` and `grass.blend1` are Blender backup files, not used by the game.

## 9. Audio

| Kind       | File                                            | Status |
|------------|-------------------------------------------------|--------|
| Voice      | `voice/voice_home.flac`                          | recorded + `.srt` |
| Voice      | `voice/voice_im_home.flac`                       | recorded + `.srt` |
| Voice      | `voice/voice_first_box_encounter.flac`           | recorded + `.srt` |
| Voice      | `voice/voice_more_boxes.flac`                    | recorded + `.srt` |
| Voice      | `voice/voice_scream_jen.flac`                    | recorded + `.srt` |
| Voice      | `voice/voice_boxes_gone.flac`                    | recorded + `.srt` |
| Voice      | `voice/voice_slip_fall.flac`                     | recorded + `.srt` |
| Ambience   | wind / outside                                   | missing |

All seven lines have an English `.srt`. Generated `.ogg` files live in `voice/gen/`.

> `voice/lossless_to_ogg_for_import.sh` is a leftover local copy of what `tools/parse.sh`
> now does. Prefer `tools/parse.sh --flac_to_ogg_for_import`.

## 10. Acceptance criteria

- [ ] The player can walk the whole house without getting stuck on geometry.
- [ ] Every box can be pushed, and pushing produces slide and impact sounds.
- [ ] All seven voice lines fire at the right moment, in order, with subtitles.
- [ ] At least one box visibly no-clips through the floor before the player does.
- [ ] The fog and sky ramp is smooth across the full fall, with no popping.
- [ ] The handover to `lvl_0` happens with no visible load hitch.
- [ ] `tools/static_check.sh` passes.

## 11. Open questions

- The partner is called **Jen** in the table at the top of [SCRIPT.md](SCRIPT.md) but **Jen**
  in the draft lines below it and in the recorded file `voice_scream_jen.flac`.
  **decision:** TBD - pick one name and make `SCRIPT.md` and the audio agree.
- `INTRO_WAIT_TIME` is `0.0`. Is the intro screen meant to be shown at all yet?
  **decision:** TBD.
- The script opens with a bicycle being parked, but there is no bicycle asset and no outdoor
  area. Is the opening meant to start indoors? **decision:** TBD.
- The box that falls through the floor is scripted in `SCRIPT.md` but it is unclear whether it
  is implemented; `frontroom_0.gd` contains no such logic. **decision:** TBD.

## 12. Related documents

- [SCRIPT.md](SCRIPT.md) - narration, the source of truth for the dialogue
- [Level 0 spec](../../lvl_0/docs/SPEC.md) - where the player goes next
- [Level flow system](../../../docs/ai/systems/level_flow.md)
- [AI documentation index](../../../docs/ai/README.md)
