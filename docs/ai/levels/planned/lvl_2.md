# Spec: Level 2 - Pipe Dreams

> ⚠ **UNVERIFIED DRAFT.** Written from memory of the wiki, not from the wiki page itself, and
> not from any code. Before implementing anything here, open the wiki page, correct this file,
> and remove this banner. Claims marked `[interpretation]` are invented for this game.

> **Wiki:** <https://backrooms-wiki.wikidot.com/level-2>
> **Scene:** `scenes/lvl_2/` - does not exist yet
> **Entry script:** -
> **State:** not-started
> **Accuracy estimate:** 0%

## 1. One paragraph pitch

Narrow service tunnels of bare concrete and hot pipes, going on for kilometres with no light of
their own. There is nothing to see, which is the point: the level is about carrying your own
light, hearing things you cannot see, and never stopping.

## 2. Canon summary

| Property            | Value                                                              |
|---------------------|---------------------------------------------------------------------|
| Survival difficulty | Class 2 - unsafe, entities, no light                                 |
| Environment         | Tight maintenance tunnels, pipes along the walls, occasional valves  |
| Lighting            | **None.** The player must bring a light source                       |
| Sound               | Hissing steam, dripping, metallic knocking                           |
| Entities            | Smilers (verify on the wiki)                                         |
| Resources           | None documented                                                      |
| M.E.G. presence     | None                                                                 |
| Temperature         | Hot; pipes can burn on contact `[interpretation]`                    |

## 3. Entrances

| From    | How                               | Implemented |
|---------|-----------------------------------|-------------|
| `lvl_1` | Descending into the service level | no          |

## 4. Exits

| To      | How                                            | Chance / condition | Implemented |
|---------|------------------------------------------------|--------------------|-------------|
| `lvl_3` | Reaching the end of a tunnel run / a stairwell | TBD                | no          |

## 5. Hazards and rules

- **Darkness is the main mechanic.** Without a light source the player should be effectively
  blind, not merely dim. This is the level that justifies building a torch item.
- Smilers only appear in darkness and vanish when lit `[interpretation]`.
- Touching a hot pipe damages the player `[interpretation]`.
- Tunnels are tight: the player must not be able to run freely everywhere `[interpretation]`.

## 6. Player capabilities required

| Capability           | System spec                                | Exists |
|----------------------|--------------------------------------------|--------|
| Walking / running    | [player](../../systems/player.md)           | yes    |
| Carryable light source | -                                         | **no** |
| Health and damage    | -                                          | **no** |
| Entities and AI      | -                                          | **no** |
| Crouching            | -                                          | **no** |
| Inventory            | -                                          | **no** |

**Blocked** until a light source and a health system exist. Roadmap puts the headlight in
V0.0.8 but `lvl 2` in V0.0.4 - that ordering needs a decision.

## 7. Technical approach

TBD. A tunnel graph rather than a tile grid `[interpretation]`: generate a network of corridor
segments and junctions, then instantiate straight / corner / T / cross pieces along it.
Occlusion is cheap here, which should make it much lighter than Level 0.

## 8. Assets needed

| Asset                                   | Type   | Status  |
|-----------------------------------------|--------|---------|
| Tunnel segments: straight, corner, T, cross | model | missing |
| Pipe runs, valves, brackets             | model  | missing |
| Ladder / stairwell                      | model  | missing |
| Carryable light source                  | model + script | missing |

## 9. Audio

| Kind                         | File | Status  |
|------------------------------|------|---------|
| Ambience: steam hiss          | -    | missing |
| Ambience: metallic knocking   | -    | missing |
| Footsteps: bare concrete, echoing | - | missing |
| Voice lines                   | -    | not written, needs a `SCRIPT.md` |

Heavy reverb is essential here - see [audio](../../systems/audio.md) and the `RaytracedReverb`
bus.

## 10. Acceptance criteria

- [ ] The player can arrive here from `lvl_1`.
- [ ] The player can leave towards `lvl_3`.
- [ ] Without a light source the player cannot navigate; with one, they can.
- [ ] Tunnel audio is noticeably more reverberant than Level 0.
- [ ] `tools/static_check.sh` passes.

## 11. Open questions

- How dark is "dark" before it stops being fun? **decision:** TBD, needs playtesting.
- Is the light source an item in an inventory, or always carried? **decision:** TBD.
- Roadmap ordering conflict described in section 6. **decision:** TBD.

## 12. Related documents

- [Level index](../README.md)
- [Level spec template](../../templates/LEVEL_SPEC_TEMPLATE.md)
- [Audio system](../../systems/audio.md)
