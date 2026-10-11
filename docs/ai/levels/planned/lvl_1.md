# Spec: Level 1 - Habitable Zone

> ⚠ **UNVERIFIED DRAFT.** Written from memory of the wiki, not from the wiki page itself, and
> not from any code. Before implementing anything here, open the wiki page, correct this file,
> and remove this banner. Claims marked `[interpretation]` are invented for this game.

> **Wiki:** <https://backrooms-wiki.wikidot.com/level-1>
> **Scene:** `scenes/lvl_1/` - does not exist yet
> **Entry script:** -
> **State:** not-started
> **Accuracy estimate:** 0%

## 1. One paragraph pitch

After squeezing through a glitched wall in the endless yellow lobby, the carpet gives way to wet
concrete. The rooms are suddenly huge: warehouse halls, catwalks, parked machinery, water
dripping from somewhere above. It is the first place that feels built by someone - and the first
place where something else is walking around.

## 2. Canon summary

| Property            | Value                                                                  |
|---------------------|------------------------------------------------------------------------|
| Survival difficulty | Class 2 - unsafe, entities present                                      |
| Environment         | Large concrete warehouse rooms, corridors, catwalks, puddles, crates    |
| Lighting            | Fluorescent strips, dimmer and patchier than Level 0; dark corners      |
| Sound               | Dripping water, distant machinery hum, footsteps that are not yours     |
| Entities            | Hounds, Smilers, Facelings (verify the exact list on the wiki)          |
| Resources           | Almond water occasionally found in crates / abandoned supplies          |
| M.E.G. presence     | Occasional small outposts                                               |

## 3. Entrances

| From    | How                                            | Implemented |
|---------|------------------------------------------------|-------------|
| `lvl_0` | Glitched wall segment                          | no          |

## 4. Exits

| To      | How                                                        | Chance / condition | Implemented |
|---------|------------------------------------------------------------|--------------------|-------------|
| `lvl_2` | A descending stairwell or a hole in the floor into the pipes | TBD               | no          |

## 5. Hazards and rules

- First level where the player can be **killed**. Entities must exist before this level is
  playable - see the gap list in section 6.
- Darkness is a real hazard here `[interpretation]`: areas with no working light should be
  navigable but genuinely disorienting.
- Standing water should change footstep sound and be audible to entities `[interpretation]`.

## 6. Player capabilities required

| Capability             | System spec                                              | Exists |
|------------------------|----------------------------------------------------------|--------|
| Walking / running      | [player](../../systems/player.md)                         | yes    |
| Health and death       | -                                                         | **no** |
| Entities and AI        | -                                                         | **no** |
| Inventory              | -                                                         | **no** |
| Light source / torch   | -                                                         | **no** |
| Level transition       | [level_flow](../../systems/level_flow.md)                 | yes    |

**This level is blocked** until health, death and at least one entity exist. Roadmap places
entities in V0.0.5 and the inventory in V0.0.4, while `lvl 1` sits in V0.0.1 - that ordering
needs a decision.

## 7. Technical approach

TBD. Probably a hybrid: handcrafted hall modules stitched together procedurally, rather than the
tile-level generation used by Level 0, because the spaces are much larger and more varied.
Reusing `MapGenerator` directly is unlikely to fit - per the PRY rule, copy and adapt rather
than generalise.

## 8. Assets needed

| Asset                      | Type    | Status  |
|----------------------------|---------|---------|
| Concrete wall / floor / ceiling modules | model   | missing |
| Catwalk and railing        | model   | missing |
| Crates, pallets, machinery | model   | missing |
| Wet concrete material      | shader  | missing |
| Puddle / water plane       | shader  | missing |

## 9. Audio

| Kind       | File | Status  |
|------------|------|---------|
| Ambience: machinery hum | - | missing |
| Ambience: dripping water | - | missing |
| Footsteps: concrete, wet concrete | - | missing |
| Voice lines | - | not written, needs a `SCRIPT.md` |

## 10. Acceptance criteria

- [ ] The player can arrive here from `lvl_0`.
- [ ] The player can leave towards `lvl_2`.
- [ ] At least one entity can find, chase and kill the player.
- [ ] Concrete and wet-concrete footsteps are distinct.
- [ ] `tools/static_check.sh` passes.

## 11. Open questions

- Does this level need entities to ship, or can a first pass be empty and atmospheric only?
  **decision:** TBD.
- Generated or handcrafted? **decision:** TBD.
- Roadmap ordering conflict described in section 6. **decision:** TBD.

## 12. Related documents

- [Level index](../README.md)
- [Level spec template](../../templates/LEVEL_SPEC_TEMPLATE.md)
- [Level 0 spec](../../../../scenes/lvl_0/docs/SPEC.md)
