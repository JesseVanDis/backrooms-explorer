# AI Guidelines for Backrooms-explorer Project
This document provides context and instructions for AI agents working on the `backrooms-explorer` project.

## Start here
**Before doing anything, read [docs/ai/README.md](docs/ai/README.md).** It is the index of all
project documentation and tells you where everything lives.

The short version:

| You need to know...                  | Read                                                      |
|--------------------------------------|------------------------------------------------------------|
| What actually works today            | [docs/ai/STATUS.md](docs/ai/STATUS.md)                      |
| How the code is wired together       | [docs/ai/ARCHITECTURE.md](docs/ai/ARCHITECTURE.md)          |
| How to write code that fits in       | [docs/ai/CONVENTIONS.md](docs/ai/CONVENTIONS.md)            |
| What a shared system does            | [docs/ai/systems/](docs/ai/systems/)                        |
| What a level is supposed to be       | `scenes/<level>/docs/SPEC.md`, indexed in [docs/ai/levels/README.md](docs/ai/levels/README.md) |
| What a term means                    | [docs/ai/GLOSSARY.md](docs/ai/GLOSSARY.md)                  |

Every `.gd` file also starts with an `[AI-DOC]` header naming the spec that owns it.

## Project Overview
It is a 3D first person exploration game, based on the backrooms wiki. Please see the README.md for more details.

## Technical Stack
- **Engine**: Godot
- **Language**: GDScript

For more please see the [TECHNICAL.md](TECHNICAL.md)

## Building
### Linux
```bash
mkdir -p ./build/debug/linux 2>/dev/null
godot --path . --export-debug "Linux" ./build/debug/linux/backgrooms-explorer.x86_64
```
### Windows
```bash
New-Item -ItemType Directory -Force ./build/debug/windows
godot --path . --export-release "Windows Desktop" ./build/debug/windows/backgrooms-explorer.exe
```

# Rules
- Use `const` as much as possible. ( so make separate functions if needed )
- Use type hinting even for basic variables look booleans and floats.
- do **NOT** change any third party assets / libraries.
- Always ask for permission when you change something in any .md file.
- When changing the parsing tools, only invoke `tools/parse.sh` to verify the changes.
- Do not abbreviate function and variable names, with the exception of: `dt`
- Do not do anything with(in) the nodes of any imported objects. Only operate on nodes that are set by Godot itself.
- *When* checking if something is null, **Always** add a `push_error(...)` in case it is null.  
- Avoid `preload()` gd scripts.
- Do not correct any code that is not related to the current task.
- Use `tools/static_check.sh` to check for warnings and errors.
  - you can supply a path to the .gd file to let it only check that file. otherwise it will check the whole project 
- Keep the documentation true in the same change as the code:
  - new or changed `.gd` file -> update its `[AI-DOC]` header
  - changed behaviour of a shared system -> update `docs/ai/systems/<system>.md`
  - changed a level -> update `scenes/<level>/docs/`
  - started or finished a feature -> update `docs/ai/STATUS.md`
- Never state a gameplay fact that is not on the Backrooms Wiki without tagging it `[interpretation]`.
