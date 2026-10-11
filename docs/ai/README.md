# AI Documentation Index

**This is the entry point for any AI agent (or human) that needs to understand this project.**
Read this file first, then jump to the specific document you need.

---

## 1. What is this project

A 3D first person **exploration** game about the Backrooms, built in **Godot 4.7** with **GDScript**.
Not primarily a horror game: the goal is to recreate the scale, mystery and documented lore of the
[Backrooms Wiki](https://backrooms-wiki.wikidot.com) as faithfully as possible.

| Question                        | Document                                       |
|---------------------------------|------------------------------------------------|
| Why does this game exist?       | [../../README.md](../../README.md)             |
| What is planned, and when?      | [../../README.md#roadmap](../../README.md)     |
| What actually works *today*?    | [STATUS.md](STATUS.md)                         |
| How is the code wired together? | [ARCHITECTURE.md](ARCHITECTURE.md)             |
| How do I write code here?       | [../../AGENTS.md](../../AGENTS.md) (hard rules) + [CONVENTIONS.md](CONVENTIONS.md) (patterns) |
| What does term X mean?          | [GLOSSARY.md](GLOSSARY.md)                     |

---

## 2. The documentation model

Documentation lives on **three levels**. Each level answers a different question, and each has
exactly one owner so the same fact is never written down twice.

```
┌─ repo root ───────────────────────────────────────────────────────────────┐
│ README.md      vision, design pillars, roadmap          (product / WHY)   │
│ TECHNICAL.md   stack, folder layout, voice pipeline     (project / HOW)   │
│ AGENTS.md      hard rules for AI + contributors         (process)         │
│ CREDITS.md     third party attribution                                    │
└───────────────────────────────────────────────────────────────────────────┘
          │
┌─ docs/ai/ ────────────────────────────────────────────────────────────────┐
│ README.md      <- you are here, the index                                 │
│ ARCHITECTURE.md runtime structure, boot flow, data flow                   │
│ CONVENTIONS.md  naming, node prefixes, the [AI-DOC] header spec           │
│ STATUS.md       what is implemented / partial / stub, per system          │
│ GLOSSARY.md     lore + engine vocabulary                                  │
│ systems/*.md    one spec per cross-level system (player, audio, ...)      │
│ levels/         level index + specs for levels that do not exist yet      │
│ templates/      copy-paste templates for new levels and new scripts       │
└───────────────────────────────────────────────────────────────────────────┘
          │
┌─ scenes/<scene>/docs/ ────────────────────────────────────────────────────┐
│ SPEC.md        the contract: what this level IS, machine readable         │
│ DESIGN.md      MoSCoW feature list with progress, wiki interpretation     │
│ TECHNICAL.md   how this level is built, scene tree, generation rules      │
│ SCRIPT.md      narration / dialogue / subtitle text                       │
│ NON_CANON.md   every design decision not sourced from the wiki, in one place │
└───────────────────────────────────────────────────────────────────────────┘
```

Fourth level: **every `.gd` file starts with an `[AI-DOC]` header** pointing at its spec.
See [CONVENTIONS.md](CONVENTIONS.md#ai-doc-header) for the exact format.

---

## 3. Systems

Cross-level code lives in `assets/scripts/`. One spec per system:

| System                                           | Code                                                                 |
|--------------------------------------------------|----------------------------------------------------------------------|
| [Player](systems/player.md)                       | `assets/scripts/player.gd`, `player_hands.gd`, `player_wield.gd`      |
| [Audio](systems/audio.md)                         | `assets/scripts/sound_controller.gd`, `physics_sounds.gd`             |
| [Interaction](systems/interaction.md)             | `assets/scripts/trigger.gd`, `door.gd`                                |
| [Level flow](systems/level_flow.md)               | `assets/scripts/level_transition.gd`, `utils/screen.gd`, `scenes/menu_*` |
| [Map generation](systems/map_generation.md)       | `scenes/lvl_0/map_generator.gd`, `lvl_0.gd`                           |
| [UI & subtitles](systems/ui_subtitles.md)         | `assets/scripts/player_subtitles.gd`, `scenes/menu_ui/menu_ui.gd`     |
| [Utils](systems/utils.md)                         | `assets/scripts/utils/*.gd`                                           |
| [Tooling](systems/tooling.md)                     | `tools/parse.sh`, `tools/static_check.sh`                             |
| [Save and checkpoint](systems/save_system.md)     | none yet - planned, see the spec                                      |
| [NPC bot](systems/npc_bot.md)                     | none yet - planned, see the spec                                      |

## 4. Levels

See the [level index](levels/README.md) for every level, its state, and where its spec lives.

| Scene                        | Spec                                                                  | State       |
|------------------------------|-----------------------------------------------------------------------|-------------|
| `scenes/frontroom_0`         | [SPEC.md](../../scenes/frontroom_0/docs/SPEC.md)                      | partial     |
| `scenes/lvl_0`               | [SPEC.md](../../scenes/lvl_0/docs/SPEC.md)                            | partial     |
| `scenes/menu_intro`          | [level_flow.md](systems/level_flow.md)                                | stub        |
| `scenes/menu_loading`        | [level_flow.md](systems/level_flow.md)                                | stub        |
| `scenes/menu_ui`             | [ui_subtitles.md](systems/ui_subtitles.md)                            | partial     |
| `scenes/test_0`              | sandbox, no spec                                                      | sandbox     |
| `lvl_1` .. `lvl_3`           | [levels/planned/](levels/planned/)                                    | not started |

---

## 5. Working agreement for AI agents

1. **Read before writing.** Open the spec of the system or level you are about to touch.
   If there is no spec, read the `[AI-DOC]` header of the script.
2. **Obey [AGENTS.md](../../AGENTS.md).** Those rules win over anything written here.
3. **Keep docs in sync with the change you make, in the same change.**
   - Changed behaviour of a system -> update `docs/ai/systems/<system>.md`.
   - Changed a level -> update `scenes/<level>/docs/TECHNICAL.md` and the progress column in `DESIGN.md`.
   - Finished or started a feature -> update [STATUS.md](STATUS.md).
   - Added a script -> add an `[AI-DOC]` header.
4. **Never invent lore.** Every gameplay claim must be traceable to the Backrooms Wiki page
   linked in the level's `DESIGN.md`, or be explicitly marked as `[interpretation]`.
5. **Log every `[interpretation]` in that level's `NON_CANON.md`, in the same change.** See
   [CONVENTIONS.md](CONVENTIONS.md#8-tracking-non-canon-additions).
6. **Verify with `tools/static_check.sh`** before declaring a code change done.
7. **Ask before editing an existing `.md` file** (hard rule in AGENTS.md). Creating new docs
   under `docs/ai/` as part of documenting your own change is expected and does not need asking.

---

## 6. Where things physically are

```
addons/            third party Godot plugins              -- DO NOT MODIFY
assets/models/     shared .tscn models (player, hands, box)
assets/scripts/    shared gameplay code, see "Systems" above
assets/scripts/utils/  stateless static helper libraries
docs/ai/           this documentation set
docs/readme/       images used by README.md
materials/         shared materials
scenes/<name>/     one folder per scene; levels are prefixed lvl_ (or frontroom_)
scenes/<name>/docs/    per level documentation
scenes/<name>/voice/   lossless voice recordings (.flac) + gen/ (.ogg, imported)
scenes/<name>/tests/   headless test scripts for that scene
tools/             shell tooling (asset parsing, static analysis)
build/             build output, not committed
```
