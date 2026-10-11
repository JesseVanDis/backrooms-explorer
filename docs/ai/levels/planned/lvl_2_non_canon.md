# Non-canon additions: Level 2 - Pipe Dreams

> **Wiki:** <https://backrooms-wiki.wikidot.com/level-2>
> This is the single list of every Level 2 design decision that is **not** sourced from the wiki
> page above. Per [lvl_2.md](lvl_2.md)'s banner, that whole spec is still an **unverified draft**
> written from memory, not from the live wiki page - so this list, too, should be re-checked
> against the actual page before any of it is implemented.

**Rule for future contributors:** whenever the wiki does not describe something and a new
gameplay decision has to be made up to fill the gap, tag it `[interpretation]` where it is
written **and** add a row below in the same change. See
[CONVENTIONS.md](../../CONVENTIONS.md#8-tracking-non-canon-additions). When this level gets a
`scenes/lvl_2/` folder, move this file to `scenes/lvl_2/docs/NON_CANON.md` alongside the rest of
its spec, per [levels/README.md](../README.md).

| Addition                                       | Why it exists (the gap it fills)                                                              | Documented in |
|---------------------------------------------------|---------------------------------------------------------------------------------------------------|---------------|
| Hot pipes burn the player on contact               | Invented hazard; "hot" is recorded in the canon summary but the burn-on-touch rule is a guess. | [lvl_2.md](lvl_2.md) §5 |
| Smilers only appear in darkness and vanish when lit | Invented entity-behaviour rule; not verified against the wiki. | [lvl_2.md](lvl_2.md) §5 |
| Tunnels are deliberately too tight to run everywhere | Invented pacing/level-design rule, not a documented wiki fact. | [lvl_2.md](lvl_2.md) §5 |
| Tunnel-graph generation (corridor network, not a tile grid) | Pure implementation guess; not a wiki fact. | [lvl_2.md](lvl_2.md) §7 |
| Exact entity list (Smilers only)                   | Marked "verify on the wiki" in the draft - not yet checked against the live page. | [lvl_2.md](lvl_2.md) §2 |
| Exit to `lvl_3` via "reaching the end of a tunnel run / a stairwell" | Condition is `TBD`; no wiki-sourced mechanism recorded yet. | [lvl_2.md](lvl_2.md) §4 |

## Related documents

- [lvl_2.md](lvl_2.md) - the draft spec this file indexes
- [Level index](../README.md)
- [CONVENTIONS.md](../../CONVENTIONS.md#8-tracking-non-canon-additions)
