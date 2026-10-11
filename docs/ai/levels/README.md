# Level index

Every scene in the game, its state, and where its documentation lives.
This table is the **single list of levels** - add a row here the moment you create a scene folder.

Legend for **State**: `not-started` | `blocked` | `in-progress` | `playable` | `complete`.

---

## Implemented scenes

| Scene                 | Name                | State       | Docs                                                     |
|-----------------------|---------------------|-------------|-----------------------------------------------------------|
| `scenes/frontroom_0`  | Frontrooms 0 - Home | in-progress | [SPEC](../../../scenes/frontroom_0/docs/SPEC.md) · [SCRIPT](../../../scenes/frontroom_0/docs/SCRIPT.md) |
| `scenes/lvl_0`        | Level 0 - The Lobby | in-progress | [SPEC](../../../scenes/lvl_0/docs/SPEC.md) · [DESIGN](../../../scenes/lvl_0/docs/DESIGN.md) · [TECHNICAL](../../../scenes/lvl_0/docs/TECHNICAL.md) · [SCRIPT](../../../scenes/lvl_0/docs/SCRIPT.md) |

## Support scenes

| Scene                  | Purpose                                   | State       | Docs                                     |
|------------------------|-------------------------------------------|-------------|-------------------------------------------|
| `scenes/menu_intro`    | Black screen shown over the first level    | stub        | [level_flow](../systems/level_flow.md)    |
| `scenes/menu_loading`  | Loading screen during level transitions    | stub        | [level_flow](../systems/level_flow.md)    |
| `scenes/menu_ui`       | In-game UI layer, currently subtitles only | in-progress | [ui_subtitles](../systems/ui_subtitles.md) |
| `scenes/test_0`        | Sandbox for raytraced audio                | sandbox     | none                                      |

## Planned levels

Specs below are **written from the wiki, not from code**. Nothing here exists yet. They are
starting points to argue with, not commitments.

| Level   | Name                   | State       | Spec                                 |
|---------|------------------------|-------------|---------------------------------------|
| `lvl_1` | Habitable Zone         | not-started | [planned/lvl_1.md](planned/lvl_1.md)  |
| `lvl_2` | Pipe Dreams            | not-started | [planned/lvl_2.md](planned/lvl_2.md)  |
| `lvl_3` | Electrical Station     | not-started | [planned/lvl_3.md](planned/lvl_3.md)  |

Further levels from the roadmap in [README.md](../../../README.md) have no spec yet. When you
start one, copy [the template](../templates/LEVEL_SPEC_TEMPLATE.md) and add a row above.

---

## Level graph

How the player can move between levels. Solid = implemented, dashed = planned.

```
  [ frontroom_0 ]
         |  no-clip through the floor (y < -15)   IMPLEMENTED
         v
  [ lvl_0 ]
         :  glitched wall, rare                   PLANNED
         v
  [ lvl_1 ]
       :     :
       :     :..... pipes / vents                 PLANNED
       v
  [ lvl_2 ]        [ lvl_3 ]
```

**Today the graph has exactly one working edge.** `lvl_0` is a dead end: there is no code path
out of it. Anything that claims otherwise is wrong.

---

## Rules for this folder

- `docs/ai/levels/planned/` holds specs for levels that have **no scene folder yet**.
- The moment a level gets a `scenes/lvl_<n>/` folder, **move** its spec to
  `scenes/lvl_<n>/docs/SPEC.md` and replace the row above with a link to the new location.
  A spec must never exist in two places.
- Never copy wiki prose verbatim into a spec. Summarise, and link the source.
