# Spec: Level 3 - Electrical Station

> ⚠ **UNVERIFIED DRAFT.** Written from memory of the wiki, not from the wiki page itself, and
> not from any code. Before implementing anything here, open the wiki page, correct this file,
> and remove this banner. Claims marked `[interpretation]` are invented for this game.

> **Wiki:** <https://backrooms-wiki.wikidot.com/level-3>
> **Scene:** `scenes/lvl_3/` - does not exist yet
> **Entry script:** -
> **State:** not-started
> **Accuracy estimate:** 0%

## 1. One paragraph pitch

A sprawling electrical station: transformer halls, cable trays, humming switchgear and corridors
lit by failing fluorescent tubes. Unlike the levels before it, this place is still *running* -
and whatever keeps it running does not want to be looked at too closely.

## 2. Canon summary

| Property            | Value                                                                 |
|---------------------|-----------------------------------------------------------------------|
| Survival difficulty | Class 2 - unsafe, entities present                                     |
| Environment         | Industrial electrical station, transformer rooms, cable corridors      |
| Lighting            | Working but unstable; flickering tubes, pools of darkness              |
| Sound               | Loud mains hum, relay clicks, arcing                                   |
| Entities            | Facelings, Hounds (verify on the wiki)                                 |
| Resources           | Salvageable parts `[interpretation]`                                   |
| M.E.G. presence     | Possible outpost `[interpretation]`                                    |

## 3. Entrances

| From    | How                              | Implemented |
|---------|----------------------------------|-------------|
| `lvl_2` | Tunnel run ending in a stairwell | no          |

## 4. Exits

| To    | How  | Chance / condition | Implemented |
|-------|------|--------------------|-------------|
| TBD   | TBD  | TBD                | no          |

Confirm on the wiki which levels Level 3 connects to before building anything.

## 5. Hazards and rules

- Live electrical hazards: exposed busbars and arcing equipment damage or kill on contact
  `[interpretation]`.
- The mains hum should be loud enough to mask entity footsteps `[interpretation]` - this is the
  level's signature tension mechanic.
- Lights fail in sequence rather than randomly `[interpretation]`, so darkness spreads.

## 6. Player capabilities required

| Capability           | System spec                                | Exists |
|----------------------|--------------------------------------------|--------|
| Walking / running    | [player](../../systems/player.md)           | yes    |
| Health and damage    | -                                          | **no** |
| Entities and AI      | -                                          | **no** |
| Inventory / salvage  | -                                          | **no** |
| Dynamic light control | -                                         | partial - see `part_1x1_ceiling_light.gd` in `lvl_0` for the blinking-light pattern |

## 7. Technical approach

TBD. Likely mostly **handcrafted**, unlike Levels 0 to 2: an electrical station has recognisable
rooms with purpose, and random generation would destroy that. A handful of hand-built halls
connected by generated corridors would keep it affordable `[interpretation]`.

## 8. Assets needed

| Asset                     | Type   | Status  |
|---------------------------|--------|---------|
| Transformer / switchgear  | model  | missing |
| Cable trays and conduits  | model  | missing |
| Industrial doors          | model  | missing (`assets/scripts/door.gd` already exists for the behaviour) |
| Arc / spark effect        | shader / particles | missing |

## 9. Audio

| Kind                       | File | Status  |
|----------------------------|------|---------|
| Ambience: mains hum (loud) | -    | missing |
| One shot: relay click      | -    | missing |
| One shot: electrical arc   | -    | missing |
| Voice lines                | -    | not written, needs a `SCRIPT.md` |

## 10. Acceptance criteria

- [ ] The player can arrive here from `lvl_2`.
- [ ] At least one exit exists and is documented in section 4.
- [ ] Electrical hazards can damage the player and are readable before contact.
- [ ] The mains hum masks footsteps without becoming unpleasant to listen to.
- [ ] `tools/static_check.sh` passes.

## 11. Open questions

- Which levels does Level 3 actually connect to? **decision:** TBD, check the wiki.
- Handcrafted, generated, or hybrid? **decision:** TBD.
- Is salvage a real system or set dressing? **decision:** TBD; the roadmap only mentions
  salvage in the suggestions section of `README.md`.

## 12. Related documents

- [Level index](../README.md)
- [Level spec template](../../templates/LEVEL_SPEC_TEMPLATE.md)
- [Interaction system](../../systems/interaction.md)
