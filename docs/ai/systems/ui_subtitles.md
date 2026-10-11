# System: UI and subtitles

> **Status:** partial
> **Code:** `assets/scripts/player_subtitles.gd`, `scenes/menu_ui/menu_ui.gd`

## 1. Responsibility

Everything drawn on top of the 3D world while playing. Today that is exactly one thing: the
**subtitle line** for the main character's voice-over.

- `IngameUI` (`scenes/menu_ui/menu_ui.gd`) is the UI layer. It is a `CanvasLayer` scene instanced
  inside a level, finds the `SubViewport` it is rendered into, and forwards subtitle calls.
- `PlayerSubtitles` (`assets/scripts/player_subtitles.gd`) is the `Label` that parses an `.srt` file
  and shows the line matching the current playback position of the voice `AudioStreamPlayer3D`.
- `player.gd` drives both: it finds the `IngameUI`, hands it the voice audio player, derives the
  `.srt` path from the audio stream's `resource_path` and calls `play_subtitles` /
  `stop_subtitles` as the voice queue advances.

Not in scope here: the voice queue itself and audio routing - see [./audio.md](./audio.md) and
[./player.md](./player.md). Loading / intro / transition overlays are a different system, see
[./level_flow.md](./level_flow.md).

Call chain:

```
player.gd  _play_next_voice()
   -> _ingame_ui.play_subtitles(get_subtitle_path(stream.resource_path))
      -> PlayerSubtitles.play_subtitles(srt_path)
         -> _parse_srt(...) + set_process(true)
            -> _process() reads _audio_player.get_playback_position() each frame
```

## 2. IngameUI (menu_ui.gd)

`scenes/menu_ui/menu_ui.tscn`, script `scenes/menu_ui/menu_ui.gd`, `class_name IngameUI`,
`extends CanvasLayer`.

Scene structure:

| Node | Type | Script | Notes |
|---|---|---|---|
| `_UI` | `CanvasLayer` | `menu_ui.gd` (`IngameUI`) | the root node of `menu_ui.tscn` |
| `_UI/_subtitles` | `Label` | `player_subtitles.gd` (`PlayerSubtitles`) | anchored to the bottom of the screen (`anchor_top = 0.891`, `anchor_right = 1.0`, `anchor_bottom = 1.0`), horizontally and vertically centred, `LabelSettings` with `font_size = 20`, `outline_size = 6`, `outline_color = Color(0, 0, 0, 0.5058824)` |

That is the whole scene - no HUD, no crosshair, no menu nodes.

Public API:

| Exact signature | What it does |
|---|---|
| `func setup(audio_player: AudioStreamPlayer3D) -> void` | forwards to `PlayerSubtitles.setup`, binding the label to the voice player. Called once from `player.gd::_ready()` as `_ingame_ui.setup(_audio_player_voice)` |
| `func play_subtitles(srt_path: String) -> void` | forwards to `PlayerSubtitles.play_subtitles` |
| `func stop_subtitles() -> void` | forwards to `PlayerSubtitles.stop_subtitles` |

Internals:

- `func _get_subtitles() -> PlayerSubtitles` lazily caches `$_subtitles`, so the three public
  functions work even if they are called before `_ready()`.
- `func _find_viewport() -> SubViewport` walks up the parents from `self`, and at each level
  searches the subtree for a `Viewport`, returning the first `SubViewport` found; `push_error`s
  `"Viewport not found!"` and returns `null` otherwise. `_ready()` stores it in `_viewport` and
  `push_error`s `"Failed to find viewport."` when it is `null`.
- unclear: `_viewport` is found and stored but never read anywhere. The only use is a commented out
  line `# _3d_display.texture = _viewport.get_texture()`, which suggests it was meant for rendering
  the viewport onto an in-world surface. `_process()` is an empty `pass`.

`player.gd` locates the UI with its own `_find_ingame_ui()` walk (same shape as `_find_viewport`),
not via a group or an exported reference.

## 3. PlayerSubtitles

`assets/scripts/player_subtitles.gd`, `class_name PlayerSubtitles`, **`extends Label`**. It *is* the
subtitle label - its own `text` property is the rendered subtitle.

| Exact signature | What it does |
|---|---|
| `func setup(audio_player: AudioStreamPlayer3D) -> void` | stores the voice player in `_audio_player`; `push_error("_audio_player is null")` when it is `null` |
| `func play_subtitles(srt_path: String) -> void` | parses `srt_path` into `_subtitles`, resets `_current_subtitle_index` to `0`, clears `text`, and enables `_process` only if at least one cue was parsed |
| `func stop_subtitles() -> void` | clears `_subtitles`, resets the index, clears `text`, `set_process(false)` |

State: `_subtitles: Array[Dictionary]` (each entry `{"start": float, "end": float, "text": String}`),
`_current_subtitle_index: int`, `_audio_player: AudioStreamPlayer3D`. `_ready()` calls
`set_process(false)` so nothing runs until a file is played.

Syncing against the audio player, in `_process(_delta: float)`:

1. If `_audio_player` is `null`, or `not _audio_player.playing`, or `_subtitles` is empty: clear
   `text`, `set_process(false)` and return. So the label self-disables as soon as the voice line
   ends - no explicit stop is required (`player.gd` still calls `stop_subtitles()` on the
   `finished` signal).
2. `var current_time: float = _audio_player.get_playback_position()` - the position **within the
   currently playing stream**, in seconds. Subtitle times are therefore relative to the start of
   each individual voice file, not to any global timeline.
3. Linear scan over all cues: the first one with `current_time >= sub.start and current_time <= sub.end`
   wins; its text is assigned and its index stored in `_current_subtitle_index`.
4. If no cue matches, `text` is set to `""` (gaps between cues show nothing).

The timestamp format it parses is standard SRT, `HH:MM:SS,mmm` (two digits, two digits, two digits,
comma, three digits). The regex used is:

```
(\d+)\n(\d{2}:\d{2}:\d{2},\d{3}) --> (\d{2}:\d{2}:\d{2},\d{3})\n([\s\S]*?)(?=\n\d+\n|\Z)
```

- Group 1 is the cue index, groups 2 and 3 the timestamps, group 4 the text (`strip_edges()`d, so
  multi-line cue text is kept but surrounding whitespace is removed).
- `_time_to_float(time_str: String) -> float` replaces `,` with `.`, splits on `:` and returns
  `hours * 3600.0 + minutes * 60.0 + seconds`. It returns `0.0` if the string does not have exactly
  three parts.
- The separator must be exactly ` --> ` and line endings must be `\n`; CRLF files will not match.
- A missing file is **not** an error: `_parse_srt` returns an empty array when
  `FileAccess.file_exists(path)` is false, with the comment "It's possible that the subtitle file
  doesn't exist for every voice line". Only a file that exists but cannot be opened raises
  `push_error("Failed to open subtitle file: " + path)`.

## 4. Authoring subtitles

**Where the files live.** Next to the lossless voice recordings, in the level's `voice/` folder:
`scenes/<level>/voice/`. For level 0 that is `scenes/lvl_0/voice/`. The converted `.ogg` files that
Godot actually imports live one level deeper in `voice/gen/` (produced by `tools/parse.sh`, see
[./tooling.md](./tooling.md)); the `.srt` files stay in the parent `voice/` folder.

**Naming.** `voice_<event>_sub_en.srt`, matching the recording `voice_<event>.flac` /
`gen/voice_<event>.ogg`. Examples that exist today: `voice_landing_sub_en.srt`,
`voice_scream_jen_sub_en.srt`, `voice_why_stuck_sub_en.srt`.

This is enforced by `player.gd::get_subtitle_path(path_to_voice_ogg: String) -> String`: it takes
the played stream's `resource_path`, and if the directory ends in `/gen` (or `\gen`) it returns
`<parent dir>/<filename>_sub_en.srt`; otherwise it returns `<path without extension>_sub_en.srt`.
The `_en` suffix is hardcoded there.

**Format.** Plain SRT, blank line between cues, times as `HH:MM:SS,mmm`, relative to the start of
that one voice file. A real example, `scenes/lvl_0/voice/voice_landing_sub_en.srt`:

```
1
00:00:00,000 --> 00:00:00,900
AAAAAAAHH!!

2
00:00:01,100 --> 00:00:01,530
OOF!

3
00:00:02,000 --> 00:00:03,000
EEEUUGHH....
```

**Source of truth for the words.** `scenes/lvl_0/docs/SCRIPT.md` is the human-authored narration
script: a table of "Happenings" against "Say" lines, with stage directions in backticks, e.g.
`` `[On landing]` OOOFF!! ``. Write or change the line there first, then record the `.flac`, then
author the `.srt` to match the recording's timing. The `.srt` text may be a tidied version of the
scripted line (the script's "OOOFF!!" is "OOF!" in the file), but the script stays the reference for
what the character says and when.

## 5. Known gaps

- **No HUD.** No crosshair, interaction prompt, stamina, inventory or objective display - the only
  UI node in `menu_ui.tscn` is the subtitle `Label`.
- **No menus.** No main menu, no pause menu, no in-game overlay other than the fade screens of
  [./level_flow.md](./level_flow.md).
- **No settings.** Subtitles cannot be turned off, resized or repositioned at runtime; the font
  size (20), outline (6) and anchor are baked into `menu_ui.tscn`. There is no audio/graphics/input
  options screen either.
- **No localisation beyond `_en`.** The `_sub_en` suffix is hardcoded in
  `player.gd::get_subtitle_path`; there is no locale lookup and no fallback chain, and no use of
  Godot's `TranslationServer`.
- **No subtitle styling options.** One `LabelSettings`, no speaker names, no colours per character,
  no rich text (`Label`, not `RichTextLabel`), so SRT markup like `<i>` would be shown verbatim.
- **Lines missing an `.srt`.** Missing files are silently tolerated, so gaps are easy to miss. In
  `scenes/lvl_0/voice/` these two recordings currently have **no** subtitle file:
  `voice_anybody_there.flac` and `voice_bad_taste.flac`. All other `voice_*.flac` files there have a
  matching `voice_*_sub_en.srt`.
- **No coverage for the rest of SCRIPT.md.** `scenes/lvl_0/docs/SCRIPT.md` lists considerably more
  lines (the spitting sequence, "What is this place !", the repeated Jen calls) than there are
  recordings and `.srt` files.
- `IngameUI._viewport` is resolved and then never used (section 2).
- Cue lookup is a linear scan over all cues every frame; fine at this scale, but there is no
  cursor/binary search and `_current_subtitle_index` is written but never used for anything.

## 6. Related

- [../ARCHITECTURE.md](../ARCHITECTURE.md) - where the UI layer sits inside a level's viewport
- [./player.md](./player.md) - the voice queue, `get_subtitle_path`, and who calls the UI
- [./audio.md](./audio.md) - voice recording pipeline and audio playback
