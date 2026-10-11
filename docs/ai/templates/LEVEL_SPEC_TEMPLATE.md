# Level spec template

Copy this file to `scenes/<level>/docs/SPEC.md` and fill it in. Delete every `<...>` placeholder
and every instruction line in italics. Keep the section numbering and the field names exactly as
they are - this document is meant to be machine readable, consistency matters more than prose.

Rules while filling it in:

- Every lore claim must come from the linked wiki page. Anything you made up must be tagged
  `[interpretation]` so a later contributor knows it is not canon.
- Anything not decided yet is `TBD`, never a guess.
- `state` values: `not-started` | `blocked` | `in-progress` | `playable` | `complete`.

---

<!-- ======================= COPY FROM HERE ======================= -->

# Spec: <Level name>

> **Wiki:** <https://backrooms-wiki.wikidot.com/level-X>
> **Scene:** `scenes/<folder>/<scene>.tscn`
> **Entry script:** `scenes/<folder>/<script>.gd`
> **State:** <not-started|blocked|in-progress|playable|complete>
> **Accuracy estimate:** <n>%  *(how close the implementation is to the wiki description)*

## 1. One paragraph pitch

*What does the player experience here? Three sentences maximum, written for a human.*

## 2. Canon summary

| Property          | Value                                                     |
|-------------------|-----------------------------------------------------------|
| Survival difficulty | <wiki class, e.g. Class 1>                              |
| Environment       | <endless rooms / caves / water / ...>                      |
| Lighting          | <description>                                              |
| Sound             | <description>                                              |
| Entities          | <list, or None documented>                                 |
| Resources         | <almond water, ...>                                        |
| M.E.G. presence   | <none / outpost / base>                                    |

## 3. Entrances

| From          | How                        | Implemented |
|---------------|----------------------------|-------------|
| <level/scene> | <mechanism>                | <yes/no>    |

## 4. Exits

| To            | How                        | Chance / condition         | Implemented |
|---------------|----------------------------|----------------------------|-------------|
| <level/scene> | <mechanism>                | <description>              | <yes/no>    |

*If the wiki documents no exit, say so, and describe what this game does instead.*

## 5. Hazards and rules

*What can hurt or kill the player, and under what exact condition. One bullet per rule, phrased
so it can be turned directly into code.*

- <condition> -> <effect>

## 6. Player capabilities required

*Which shared systems this level needs. Mark the ones that do not exist yet.*

| Capability             | System spec                               | Exists |
|------------------------|-------------------------------------------|--------|
| Walking / running      | [player](../../../docs/ai/systems/player.md) | yes |
| <swimming>             | <->                                       | no     |

## 7. Technical approach

*One paragraph: handcrafted scene, procedurally generated, or hybrid. Link to
`TECHNICAL.md` in this same folder for the details - do not duplicate them here.*

## 8. Assets needed

| Asset        | Type        | Status            | Source / credit |
|--------------|-------------|-------------------|-----------------|
| <name>       | model/sound/texture | missing/wip/done | <->      |

## 9. Audio

| Kind       | File                                | Status |
|------------|-------------------------------------|--------|
| Ambience   | `scenes/<folder>/<file>`            | <->    |
| Voice line | `scenes/<folder>/voice/gen/<file>`  | <->    |

*Narration text itself belongs in `SCRIPT.md`, not here.*

## 10. Acceptance criteria

*The checklist that decides whether this level is "done". Must be objectively verifiable.*

- [ ] The player can enter the level from <entrance>.
- [ ] The player can leave the level via <exit>.
- [ ] <level specific criterion>
- [ ] `tools/static_check.sh` passes.

## 11. Open questions

- <question> - **decision:** TBD

## 12. Related documents

- [DESIGN.md](DESIGN.md) - feature list and progress
- [TECHNICAL.md](TECHNICAL.md) - how it is built
- [SCRIPT.md](SCRIPT.md) - narration
- [AI documentation index](../../../docs/ai/README.md)
