# Non-canon additions: Level 0

> **Wiki:** <https://backrooms-wiki.wikidot.com/level-0> (retitled "Threshold")
> This is the single list of every Level 0 design decision that is **not** sourced from the wiki
> page above - every `[interpretation]` claim scattered across `SPEC.md`, `DESIGN.md`,
> `SCRIPT.md`, and the related system specs (`npc_bot.md`, `save_system.md`, `ui_subtitles.md`),
> gathered in one place. This is a companion list, not a replacement: claims must still be tagged
> `[interpretation]` inline, where they are actually written.
>
> This list is for **lore/world decisions only**. Purely gameplay-engine or UI mechanics (menus,
> buttons, on-screen prompts, save/restart plumbing) are not logged here - see
> [CONVENTIONS.md](../../../docs/ai/CONVENTIONS.md#8-tracking-non-canon-additions) for why.

**Rule for future contributors:** whenever the wiki does not describe something and a new
world/lore decision has to be made up to fill the gap, tag it `[interpretation]` where it is
written **and** add a row below in the same change. See
[CONVENTIONS.md](../../../docs/ai/CONVENTIONS.md#8-tracking-non-canon-additions).

| Addition                                              | Why it exists (the gap it fills)                                                                                          | Documented in |
|--------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------|---------------|
| Flickering-wall exit discovery-rate compression         | Canon says finding the exit "can take days"; not playable as-is, so the spawn/discovery rate must be artificially sped up. Exact mechanism is still an open question. | [DESIGN.md](DESIGN.md), [SPEC.md](SPEC.md) §4, §11 |
| Holes are unsurvivable, with no second route to `lvl_1` | The wiki only says no one has reported surviving a fall; it does not describe a game mechanic. This game interprets that silence as a guaranteed, instant death rather than an alternate path forward. | [DESIGN.md](DESIGN.md), [SPEC.md](SPEC.md) §4-5 |
| Hand-feel navigation shader in Blackout Zones           | Not a wiki mechanic at all. Invented so the player has a usable tool while a zone's lights are off, rather than being simply unplayable. | [DESIGN.md](DESIGN.md), [SPEC.md](SPEC.md) §5 |
| MEG Supplier NPC in the Manila room                     | The wiki's Manila room has **no living person** in it, only notes and no-clip guides on a table. This game replaces those static notes with a single voiced NPC. | [DESIGN.md](DESIGN.md), [SPEC.md](SPEC.md) §2, [npc_bot.md](../../../docs/ai/systems/npc_bot.md) |
| "MEG Supplier" as the NPC's name                        | Invented nickname for the NPC above; not a wiki term, and not a literal robot despite the nickname. | [DESIGN.md](DESIGN.md), [npc_bot.md](../../../docs/ai/systems/npc_bot.md), [SCRIPT.md](SCRIPT.md), [GLOSSARY.md](../../../docs/ai/GLOSSARY.md) |
| MEG Supplier's briefing mentions a Level 1 M.E.G. base  | `lvl_1` does not exist yet beyond its own unverified draft spec, so any dialogue about it is necessarily speculative. | [DESIGN.md](DESIGN.md), [SCRIPT.md](SCRIPT.md), [npc_bot.md](../../../docs/ai/systems/npc_bot.md) |
| MEG Supplier dissolve/clip-away exit shader             | Visual effect invented for this game's NPC exit ("clips away into the air"); no wiki equivalent. Replaces an earlier, dropped idea of making the *player* invisible at the exit. | [DESIGN.md](DESIGN.md), [npc_bot.md](../../../docs/ai/systems/npc_bot.md) §4 |
| Manila room visit gates Red Room generation             | The wiki says Red Room entry is "completely at random, after turning a corner" - no such gate exists in canon. This game ties first appearance to a Manila room visit instead. | [DESIGN.md](DESIGN.md), [SPEC.md](SPEC.md) §4-5, [npc_bot.md](../../../docs/ai/systems/npc_bot.md) §5 |
| Manila room stops appearing forever after one visit     | Game-only persistence rule. The wiki's Manila room is visited by many different wanderers over time with no such limit. | [DESIGN.md](DESIGN.md), [npc_bot.md](../../../docs/ai/systems/npc_bot.md) §5 |
| Red Room first-entry voice line ("oh... the Red rooms he warned about... SHIT!") | Original dialogue; the wiki has no player character to narrate anything. | [SCRIPT.md](SCRIPT.md) |
| Scattered clutter props (chairs, trash bins)            | Set dressing invented for variety; not mentioned anywhere on the wiki page. | [DESIGN.md](DESIGN.md) |
| MEG Supplier defaults to a static mesh with no idle/speaking animation | Implementation simplification for a first pass, not a wiki fact either way. **decision:** TBD, see open questions. | [npc_bot.md](../../../docs/ai/systems/npc_bot.md) §6 |

## Related documents

- [SPEC.md](SPEC.md), [DESIGN.md](DESIGN.md), [SCRIPT.md](SCRIPT.md) - the docs this file indexes
- [npc_bot.md](../../../docs/ai/systems/npc_bot.md), [save_system.md](../../../docs/ai/systems/save_system.md), [ui_subtitles.md](../../../docs/ai/systems/ui_subtitles.md) - system specs with their own `[interpretation]` claims about Level 0
- [CONVENTIONS.md](../../../docs/ai/CONVENTIONS.md#8-tracking-non-canon-additions) - the rule that keeps this file alive
- [GLOSSARY.md](../../../docs/ai/GLOSSARY.md) - definition of the `[interpretation]` tag itself
