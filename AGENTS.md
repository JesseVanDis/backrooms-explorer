# AI Guidelines for RCCar Project
This document provides context and instructions for AI agents working on the `backrooms-explorer` project.

## Project Overview
It is a 3D first person exploration game, based on the backrooms wiki. Please see the README.md for more details.

## Technical Stack
- **Engine**: Godot
- **Language**: GDScript

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
- do **NOT** change any third party assets / libraries.
- Always ask for permission when you change something in any .md file.

