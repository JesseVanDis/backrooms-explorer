# System: Tooling

> **Status:** implemented
> **Code:** `tools/parse.sh`, `tools/static_check.sh`, `assets/scripts/utils/static_analysis.gd`

## 1. Static checking

`tools/static_check.sh` is the project's only correctness gate. It `cd`s to the repository root
itself, so it can be run from anywhere.

Whole project (every `.gd` file found by `find . -name "*.gd"`):

```bash
tools/static_check.sh
```

Single file (the argument must end in `.gd` and exist, otherwise it prints
`Error: Argument '<x>' is not a valid .gd file.` and exits `1`):

```bash
tools/static_check.sh assets/scripts/player.gd
```

For each file it prints `checking file: '<path>'` and runs:

```bash
godot --headless --path . --check-only --script "<file>"
```

**What it temporarily does to `project.godot`.** Before checking anything, the script rewrites the
`[debug]` section so that every enabled warning becomes an **error**:

1. Copies `project.godot` to a temp file and installs a `trap cleanup EXIT` that moves the copy back
   - so `project.godot` is restored even if the run is interrupted. (If the process is killed hard,
   the trap does not run and `project.godot` may be left in the escalated state; `git diff` will
   show it.)
2. Collects warning settings from two sources: the current `[debug]` section of `project.godot`
   (via `sed`) and the output of
   `godot --headless --path . --script res://assets/scripts/utils/static_analysis.gd`.
   That script is a headless `SceneTree` that walks `ProjectSettings.get_property_list()`, keeps
   every property starting with `debug/gdscript/warnings/`, prints `"<name without debug/>=<value>"`
   and then `quit()`s - i.e. it reports the engine defaults as well as the overrides.
3. Keeps only the lines ending in `=1` or `=2`, de-duplicates them with `sort -u`, and rewrites
   every `=1` to `=2` (`1` = warn, `2` = error in Godot's warning levels). Settings at `0`
   (disabled) are dropped.
4. Splices that block back into the `[debug]` section with `awk` and writes the result over
   `project.godot` for the duration of the run.

Effect: **any warning that is enabled at all becomes a hard error during the check**, so a clean run
means warning-free as well as error-free.

> **Hard rule (AGENTS.md):** `tools/static_check.sh` must pass before a change is considered done.
> Run it on the files you touched at minimum.
>
> Note the single-file branch `exit 0`s right after the `godot` call, so the shell exit status of
> the script does not reflect the check result - read the printed output.

## 2. Enabled GDScript warnings

From the `[debug]` section of `project.godot`. Values: `0` = ignore, `1` = warn, `2` = error.
`static_check.sh` promotes every `1` to `2` while it runs.

| Setting | Value | What it means in practice |
|---|---|---|
| `gdscript/warnings/untyped_declaration` | `1` | Every `var`, parameter and return must carry a type. **This is why the project rule "use type hinting even for basic variables like booleans and floats" is not optional** - `var is_done = false` fails the check, `var is_done: bool = false` passes. Inferred `:=` counts as typed |
| `gdscript/warnings/unsafe_property_access` | `1` | Reading/writing a property on a `Variant` or loosely typed value. Forces typed locals before touching members, e.g. `var body: RigidBody3D = ...` instead of poking at an untyped `Node` |
| `gdscript/warnings/unsafe_method_access` | `1` | Calling a method on a value whose type the compiler cannot verify. This is why dynamic probing is done with `has_method(...)` plus `call(...)` (see `level_transition.gd`) rather than a direct call |
| `gdscript/warnings/unsafe_cast` | `1` | A cast the compiler cannot prove safe; prefer `is` checks before `as` |
| `gdscript/warnings/unsafe_call_argument` | `1` | Passing an argument whose type cannot be verified against the parameter type |
| `gdscript/warnings/missing_await` | `1` | Calling a coroutine without `await`. This is why `await _level_transition.update()` is written with `await` even though the call looks synchronous |
| `gdscript/warnings/int_as_enum_without_cast` | `0` | **Disabled** - raw ints may be assigned to enum-typed values |
| `gdscript/warnings/int_as_enum_without_match` | `0` | **Disabled** - an int need not match a known enum value |
| `gdscript/warnings/inference_on_variant` | `1` | `:=` inferring from something `Variant`-typed, which silently produces a `Variant` |
| `gdscript/warnings/native_method_override` | `1` | Shadowing an engine method by accident |
| `gdscript/warnings/get_node_default_without_onready` | `1` | `$Node` in a member initialiser without `@onready`, which would run before the node exists |
| `gdscript/warnings/onready_with_export` | `1` | `@onready` combined with `@export` - the export value would be overwritten |
| `gdscript/warnings/property_used_as_function` | `2` | Already an error: calling a property as if it were a method |
| `gdscript/warnings/constant_used_as_function` | `2` | Already an error: calling a constant |
| `gdscript/warnings/function_used_as_property` | `2` | Already an error: referencing a function without calling it where a value is expected |

- unclear: these are only the keys present in `project.godot`. `static_analysis.gd` additionally
  reports every other `debug/gdscript/warnings/*` setting at its engine default, and those defaults
  are promoted to errors too if they are `1`. Run `tools/static_check.sh` and inspect the
  `[debug]` section mid-run (or the script output) to see the full effective list.

## 3. Asset parsing

`tools/parse.sh` prepares source assets for Godot import. (`tools/` carries a `.gdignore`, so the
engine ignores the folder.)

Run all default tasks (currently: check ffmpeg, then convert every `voice` folder):

```bash
tools/parse.sh
```

Help:

```bash
tools/parse.sh --help
```

FLAC to OGG conversion:

```bash
tools/parse.sh --flac_to_ogg_for_import                 # scan mode
tools/parse.sh --flac_to_ogg_for_import [IN] [OUT]      # explicit folders
```

- With **no** `IN`/`OUT`, it runs `find . -type d -name "voice"` and processes every `voice` folder
  it finds. For each one it creates `<voice>/gen/`, drops a `README.txt` in it if absent
  ("This folder contains files converted via tools/parse.sh. Do not edit the .ogg files. instead
  please change the .flac files, and run the parse.sh"), and converts every `*.flac` at depth 1 into
  `<voice>/gen/<name>.ogg`.
- With `IN` and `OUT` given, it converts `IN/*.flac` (depth 1) into `OUT/*.ogg`, creating `OUT` and
  a shorter `README.txt` if needed. A non-existent `IN` prints an error and exits `1`.
- Any other first argument prints the help and exits `1`.

**mtime cache.** `TRACKING_FILE="$(dirname "$0")/.parse_sh_latest_changes.txt"`, i.e.
`tools/.parse_sh_latest_changes.txt`. It stores one `"<path>:<epoch mtime>"` line per converted
`.flac` (`stat -c %Y`). A file is reconverted only when the cache is missing, has no entry for it,
or the current mtime is greater than the recorded one; otherwise the script prints
`Skipping <file> (unchanged)`. Delete the cache file to force a full reconvert.

**ffmpeg dependency.** `check_ffmpeg` runs before any conversion and exits `1` with
`Error: ffmpeg is not found on the machine. Please install it to continue.` if `ffmpeg` is not on
`PATH`. The actual command is:

```bash
ffmpeg -i "$flac_file" -y -acodec libvorbis "$output_file"
```

so the local ffmpeg build must have `libvorbis`. Output is suppressed; a failure prints
`Error: Failed to convert <file>` and the cache entry is **not** updated, so the next run retries.

> **Project rule (AGENTS.md):** when changing the parsing tools, **only** invoke `tools/parse.sh` to
> verify the changes. Do not write a separate verification script for it.

Related: the `.srt` subtitle files stay in the `voice/` folder and are *not* touched by `parse.sh` -
see [./ui_subtitles.md](./ui_subtitles.md).

## 4. Building

Copied from [AGENTS.md](../../../AGENTS.md).

Linux:

```bash
mkdir -p ./build/debug/linux 2>/dev/null
godot --path . --export-debug "Linux" ./build/debug/linux/backgrooms-explorer.x86_64
```

Windows (the `New-Item` line is PowerShell):

```bash
New-Item -ItemType Directory -Force ./build/debug/windows
godot --path . --export-release "Windows Desktop" ./build/debug/windows/backgrooms-explorer.exe
```

Output layout:

```
build/
  debug/
    linux/backgrooms-explorer.x86_64
    windows/backgrooms-explorer.exe
```

`build/` is build output and is not committed (see the folder map in
[../README.md](../README.md), section 6).

- unclear: there is no `export_presets.cfg` in the repository, so the preset names `"Linux"` and
  `"Windows Desktop"` must be configured locally in the Godot editor before these commands work.
  Also note the filename typo `backgrooms-explorer` and that the Windows command uses
  `--export-release` while the path says `build/debug/` - both are reproduced here exactly as they
  appear in AGENTS.md.

## 5. Running headless tests

The pattern comes from `scenes/lvl_0/tests/test_map_gen.sh`, which wraps a single call:

```bash
godot --headless --path . -s scenes/lvl_0/tests/test_map_gen.gd
```

On success it opens the produced image with `xdg-open scenes/lvl_0/tests/result.png`, otherwise it
prints `Godot failed`. After the first run it optionally watches the source: if `inotifywait`
(package `inotify-tools`) is available it loops on
`inotifywait -e modify scenes/lvl_0/map_generator.gd` and re-runs the test on every change; if not,
it prints a hint to install it. The watcher is a convenience only - the single `godot --headless`
line above is the test.

**SceneTree scripts.** `-s` (`--script`) runs a script that `extends SceneTree` with no main scene
and no window. The whole test lives in `_init()`, and the script must call `quit(<exit code>)`
itself. `scenes/lvl_0/tests/test_map_gen.gd` does exactly that: it `load()`s
`res://scenes/lvl_0/map_generator.gd`, instantiates it, calls `generate_map_image(256, 256)`, saves
`res://scenes/lvl_0/tests/result.png`, and `quit(0)` (or `quit(1)` when the script fails to load).
Note the assertion is visual - a human looks at `result.png`; nothing fails the run on a bad map.

To add a new headless test:

1. Create `scenes/<scene>/tests/test_<thing>.gd` with the `[AI-DOC]` header
   (`## spec:` pointing at the system or level spec it covers) and `extends SceneTree`.
2. Do the work in `func _init() -> void:`; `load()` the script under test rather than `preload()`
   (project rule), `push_error(...)` on every failure, and end with `quit(0)` / `quit(1)`.
3. Write any artefact next to the script, e.g. `res://scenes/<scene>/tests/result.png`.
4. Add `scenes/<scene>/tests/test_<thing>.sh` calling
   `godot --headless --path . -s scenes/<scene>/tests/test_<thing>.gd`, following the
   `run_test` shape of `test_map_gen.sh`.
5. Run `tools/static_check.sh scenes/<scene>/tests/test_<thing>.gd` before you call it done.

## 6. Known gaps

- **No CI.** No workflow files; nothing runs `static_check.sh`, `parse.sh` or a build automatically
  on push or pull request.
- **No automated test runner.** Tests are individual shell scripts that must be invoked by hand and
  are discovered only by knowing where to look (`scenes/<scene>/tests/`). There is no aggregate
  "run everything" entry point and no pass/fail summary.
- **No unit test framework.** No GUT, no gdUnit, no assertions - `test_map_gen.gd` verifies nothing
  programmatically, it just produces an image for a human to inspect. None of `UtilsMath`,
  `UtilsNode`, `PlayerSubtitles` or `LevelTransition` has a test.
- **No formatter.** No gdformat / gdlint configuration; style is kept by convention only
  (see [../CONVENTIONS.md](../CONVENTIONS.md)).
- `static_check.sh` edits `project.godot` in place and relies on an `EXIT` trap to restore it.
- The single-file branch of `static_check.sh` always exits `0`, so it cannot be used as a CI gate
  as written.
- No export presets are committed, so the build commands are not reproducible on a fresh clone
  (section 4).

## 7. Related

- [../CONVENTIONS.md](../CONVENTIONS.md) - the coding rules the warning configuration enforces
- [./audio.md](./audio.md) - the voice pipeline that `parse.sh` feeds
- [./map_generation.md](./map_generation.md) - what `test_map_gen.gd` exercises
