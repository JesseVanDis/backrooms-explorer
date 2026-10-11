# Non-canon tracking template

Copy this file to `scenes/<level>/docs/NON_CANON.md` (or, for a level that has no scene folder
yet, `docs/ai/levels/planned/<level>_non_canon.md`) and fill it in. Delete every `<...>`
placeholder and every instruction line in italics.

Rules while filling it in:

- This file is a **companion list**, not a replacement for inline tagging. A claim must still be
  tagged `[interpretation]` where it is actually written (`SPEC.md`, `DESIGN.md`, `SCRIPT.md`,
  the related `docs/ai/systems/*.md`); this file just gathers every one of those tags for the
  level into a single place that is easy to scan.
- **Scope: world/lore decisions only.** Log facts about the Backrooms world itself that the wiki
  leaves undescribed (an NPC, an entity behaviour, what happens to the player, dialogue, set
  dressing). Do **not** log purely gameplay-engine or UI mechanics - menus, buttons, on-screen
  prompts, save/restart plumbing, HUD elements - those are needed by the game regardless of what
  the wiki says, so there is no lore gap for them to fill. Tag those `[interpretation]` inline
  where relevant, just do not add a row here for them.
- **Whenever the wiki does not describe a world/lore fact and a new decision has to be made up
  to fill that gap, add a row here in the same change** that introduces the decision - do not let
  this file fall behind the docs it indexes. See
  [CONVENTIONS.md](../CONVENTIONS.md#8-tracking-non-canon-additions).
- One row per distinct decision, not per sentence. If five lines all describe facets of the same
  invented feature, that is one row with a longer "Why it exists" cell.
- "Documented in" links to every file where the claim appears, inline, with the `[interpretation]`
  tag - not just where it was first decided.

---

<!-- ======================= COPY FROM HERE ======================= -->

# Non-canon additions: <Level name>

> **Wiki:** <https://backrooms-wiki.wikidot.com/level-X>
> This is the single list of every <Level name> design decision that is **not** sourced from the
> wiki page above.

| Addition                     | Why it exists (the gap it fills)                              | Documented in |
|-------------------------------|----------------------------------------------------------------|---------------|
| <short name of the addition>  | <what the wiki does not say, and why this game needed a decision anyway> | <file(s)> |
