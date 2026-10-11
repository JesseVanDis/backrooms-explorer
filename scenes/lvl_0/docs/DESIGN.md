# Design
[https://backrooms-wiki.wikidot.com/level-0](https://backrooms-wiki.wikidot.com/level-0)

### Isolation Effect `[canon]`

 - No two wanderers can ever find, see, hear or signal one another while in Level 0 - shouting,
   leaving notes, marking paths, or damaging the walls all fail. This holds for the whole level,
   with exactly **one exception: the Manila room** (see below), where the effect weakens and
   people can meet.
 - `[interpretation]`: the project's existing inner-voice lines already lean into this (the player
   yells for "Jane" and only hears their own echo come back) - no code change is required to honour
   this fact, it is already consistent.

### Exits

 - A flickering wall the player can walk/throw themself through, leading to `lvl_1` (wiki: "Survive
   long enough to find a flickering wall to throw yourself through"). Low chance.
 - Holes (floor pits, a canon grid-pattern hazard - see "Holes" below, not a rare one-off POI):
   falling through one does **not** lead to another level - it is an instant **Game Over**
   `[interpretation: the wiki only says no one has reported surviving a fall]`, see
   "Holes -> Game Over" below.

Since it will take so long to find the flickering wall ( can take days ) there needs to be a way to speed that up.

### Holes `[canon]`

 - A grid-pattern floor hazard, generated the same way the Pillars biome is: pits appear in close
   groups laid out on a grid, which "usually makes them simple to bypass". Some clusters can be
   large or dense enough that falling in becomes "an enormous risk".
 - The pits are pitch black; light does not penetrate more than a few feet into them. It is unknown
   what happens to a wanderer who falls in - none have reported doing so and surviving.
 - Architecturally this means Holes should be designed closer to a fifth `BIOME_*` grid variation
   (like `BIOME_PILLARS`) than to a handcrafted one-off POI like the Manila room - see
   [map_generation.md](../../../docs/ai/systems/map_generation.md) section 10.
 - This game turns "none have survived" into an instant **Game Over** screen on contact
   `[interpretation]` - see "Holes -> Game Over" below.

### Blackout zones (formerly called "Darkrooms" during planning - one feature, one name)

 - Canon name is "Blackout Zone": entire sections of Level 0 devoid of lighting, that constantly
   shift behind the low visibility, making them extremely hard to traverse and easy to get lost in.
 - All ceiling lights are removed for the whole biome; ambient light drops to near-zero while the
   player is inside it, so the player loses all orientation.
 - Per the wiki, survivors report rough wall textures and an intense silence (the fluorescent
   buzzing stops entirely); the advised survival tactic is to sprint towards the first glimmer of
   light, or follow any buzzing sound, until an exit is found.
 - The floor may be recessed and fill with **ankle-deep fluid** `[canon - confirms the "a little
   water, not fully flooded" reading]`, with its own wet/splash footstep sounds and a looping
   shallow-water ambience - new SFX needed, see [SPEC.md](SPEC.md) section 9.
 - **Hand-feel navigation shader `[interpretation: not a wiki mechanic]`.** Because the player
   cannot see, a raycast/shapecast from the hand feeds a wall shader a touch point; the wall
   desaturates to black & white and reveals a dithered (ordered/Bayer) circular region around that
   point, falling off with distance. This is a per-wall-material shader, not a full-screen
   post-process - see [TECHNICAL.md](TECHNICAL.md) once it is implemented.

### Manila room

Canon physical description `[canon]`: an isolated 8x8 metre room with thick walls, named for the
beige "manila" colour of its wallpaper. Wooden floorboards, one octagonal table, two chairs, and a
wooden entrance door in its walls. Notes are left on the table containing information about the
Backrooms and guides to no-clipping (how newcomers learn to escape Level 0); cupboards under the
table hold food, water and more documents brought in by volunteers. As a wanderer approaches, the
Isolation Effect weakens - people already inside see newcomers phase into existence - the
fluorescent humming fades and a relaxing piano loop plays from the room itself. The room is also a
guaranteed, safe route onward for newly no-clipped wanderers into Level 1.

**Important: the wiki's Manila room has no living person in it - only the notes and documents
above.** This project adds a one-off NPC on top of that canon room:

 - A handcrafted, one-off POI (not procedurally tiled), stitched into the generated maze the same
   way `entry_tube.tscn` is today.
 - An NPC sent from M.E.G. appears - a person, nicknamed "the MEG Supplier" in this project's docs and
   code, not a literal robot `[interpretation: this whole character, and the nickname, is this
   game's own invention replacing the wiki's static notes with a voiced briefing]` - and briefs the
   player on Level 0's risks and the Level 1 base `[interpretation, lvl_1 does not exist
   beyond its draft spec]`, including a warning about Red Rooms, then leaves.
 - The NPC visibly "clips away into the air" via a dissolve shader, visible only inside the Manila
   room, when it finishes its briefing and leaves.
 - The room can appear **multiple times** across a playthrough, but once the player has visited it
   **once**, it never appears again - **permanently, saved to disk** (the project's first
   persistent save file). See [NPC bot system](../../../docs/ai/systems/npc_bot.md) and
   [Save system](../../../docs/ai/systems/save_system.md).
 - Visiting the Manila room is also the **gate** that allows Red Rooms to start appearing at all
   (see below) `[interpretation: the wiki says Red Room entry is simply random, with no such gate]`
   - until then, Red Rooms must never be selected by the generator.

### Red rooms

 - Canon `[canon]`: Red Rooms are sections of Level 0 that have disconnected from the whole,
   completely unbreachable once fully entered, "like a closed loop". Even remaining in proximity
   can cause severe claustrophobia and acute paranoia. The wiki's advice is simply to turn back and
   walk away.
 - **Approach is a gradual transition, not an instant snap-in `[canon]`.** As a wanderer nears a Red
   Room, the carpet becomes thick, sticky and very coarse, the overall colour hue shifts towards
   red, and sections of wallpaper visibly **peel away to reveal a crimson colour underneath**. This
   is the player's chance to recognise the danger and turn back before the room is fully entered.
 - Gated `[interpretation: not in the wiki - entry there is "completely at random, after turning a
   corner"]`: in this game, Red Rooms only begin appearing in generation **after** the player has
   visited a Manila room at least once.
 - On first entering a Red Room, the player's inner voice says: *"oh... the Red rooms he warned
   about... SHIT!"* - see [SCRIPT.md](SCRIPT.md).
 - The trap itself: infinite looping corridors, with **no hidden true exit** `[canon: "after one has
   entered the Red Rooms, there is presumably no chance of exit"]` - this is an intentional,
   permanent soft-lock by design, not a bug.
 - Recourse: an on-screen text prompt appears once inside - *"Press P to restart from checkpoint"*.
   This is a key-press prompt, not a menu button, so the player never has to release the mouse.
   Pressing `P` restarts the player at their last checkpoint (see "Holes -> Game Over" below).

### Holes -> Game Over

 - Falling through a Hole triggers the project's **first Game Over screen**: a full overlay with a
   clickable **"Restart from checkpoint"** button (this one does need the mouse released, unlike
   the Red Room's key-only prompt).
 - "Checkpoint" = the **last discovered POI** (today: the Manila room's location), not just the
   start of the level. Both this screen and the Red Room's `P` prompt use the same
   restart-from-checkpoint flow. See [Save system](../../../docs/ai/systems/save_system.md).
 - This - together with the Red Room prompt - is why `docs/ai/systems/ui_subtitles.md` ("No
   menus"/"No HUD") has been corrected: Level 0 now needs two small, deliberately different UI
   elements (click vs. key-press), not a full menu system.

### Scattered clutter `[interpretation: set dressing, not mentioned on the wiki]`

 - Two prop types implemented so far: a chair and a trash bin. Placement is decided by the map
   generator itself, not by `Lvl_0` at render time: the last pass of every biome chain in
   `map_generator.gd` reserves a byte on the 64-bit pixel (`PROP_MASK`) and marks eligible,
   sparsely-spaced `TILE_EMPTY` floor tiles with `PROP_CHAIR` or `PROP_TRASH_BIN` once all walls
   and arches have settled. This keeps placement deterministic and stable across chunk regeneration.
 - Chairs favour open floor tiles and get a coordinate-derived cardinal rotation. Trash bins only
   spawn on tiles with exactly one adjacent wall and are oriented so their open side faces away
   from it.
 - Both props are **static**: plain `MeshInstance3D` + `CollisionShape3D` scenes
   (`part_prop_chair.tscn`, `part_prop_trash_bin.tscn`) with no `RigidBody3D`/`PhysicsSounds` - they
   block the player but cannot be pushed, moved, or interacted with. They reuse the existing
   chunk-streamed graphics/static-collision lifetime, same as floor and wall tiles.
 - See [map_generation.md](../../../docs/ai/systems/map_generation.md) for the pixel contract and
   prop pass.

## MoSCoW

### Must

| Subject                             | progress (%) | Note |
|-------------------------------------|--------------|------|
| **Mechanics**                       | -            |      |
| - Different carpet walking sounds   | 0%           |      |
| - Inner voice                       | 0%           |      |
| - occasional blinking ceiling lights | 0%           |      |
| **Map generation**                  | -            |      |
| - Infinite chunks                   | 80%          |      |
| - Layout changes where you dont look | 0%           |      |
| - Flickering wall - exit to lvl_1 (wiki calls it a "glitched"/flickering wall) | 0%           |      |
| - Sound: Background noise           | 0%           |      |
| **Map**                             | -            |      |
| - Biome: Arches                     | 0%           |      |
| - Biome: Pillars                    | 0%           |      |
| - Biome: Holes                      | 0%           | Canon grid-pattern pit hazard (like Pillars); no level transition - triggers the Game Over screen (see below) |
| - Biome: Blackout zones             | 0%           | Lights off, shallow water + wet SFX, hand-feel wall shader |
| - Biome: Extremely loud buzzing sound | 0%           |      |
| - Biome: Manila room                | 0%           | Canon room (8x8m, notes/documents, no NPC) + this game's NPC briefing; visited-once-ever, saved to disk |
| **Events**                          | -            |      |
| - Sound of scratching behind wall   | 0%           |      |
| **NPC**                             | -            |      |
| - MEG Supplier (Manila room briefing NPC + clip-away exit) | 0% | New system, see [npc_bot.md](../../../docs/ai/systems/npc_bot.md) |
| **Persistence**                     | -            |      |
| - Save / checkpoint system          | 0%           | First persistent save; see [save_system.md](../../../docs/ai/systems/save_system.md) |
| **UI**                              | -            |      |
| - Holes Game Over screen            | 0%           | First real menu in the project; "Restart from checkpoint" button |
| - Red room restart prompt           | 0%           | Key prompt, "Press P to restart from checkpoint" |

### Should 
| Subject                          | progress (%) | Note |
|----------------------------------|--------------|------|
| **Map**                          | -            | -    |
| - Biome: Red rooms               | 0%           | Canon infinite looping corridors, no true exit; gradual peeling-wallpaper/carpet/colour approach; gated behind a Manila room visit `[interpretation]`; `P`-to-restart prompt |
| - Scattered props (chairs, trash bins) | 100%   | Static, map-generator-marked, low density; see "Scattered clutter" above |


### Could 
| Subject                                 | progress (%) | Note |
|-----------------------------------------|--------------|------|
| **Other**                               | -            | -    |
| - Biome: The torment                    | 0%           |      | 
| - Sound: Whispering of voices           | 0%           |      |
| - Embedded subsections (Level 0.x)      | 0%           |      |


### Wont 
| Subject                          | progress (%) |
|----------------------------------|--------------|


## mentions
 - Around 50,000 people on Earth go missing each year. 20,000 of which get here.
 - 60-70% of people die in Level 0 die here.
 - Re-verified this pass directly against the current wiki text itself (via search results
   surfacing `backrooms-wiki.wikidot.com/level-0`, `/red-rooms` and `/manila-room` content, since
   `fetch_url` still fails on every URL, canon or not - not specific to this wiki).
 - Level 0's page was rewritten and retitled "Threshold"; survival difficulty is Class 1,
   "Unconfirmed Entities" - wanderers report dark figures and scopophobia, nothing confirmed.
 - A core, previously undocumented mechanic: the **Isolation Effect** - no two wanderers can ever
   meet in Level 0, except in the Manila room.
 - Red rooms are reached by turning a corner while in Level 0, completely at random, Class 3
   survival difficulty, and are near-impossible to escape; proximity is signalled by thicker/
   stickier/coarser carpet, a red colour shift, and peeling wallpaper revealing crimson underneath.
 - The Manila room is an 8x8m room with manila-coloured wallpaper, wooden floor, one octagonal
   table and two chairs, containing only written notes/guides and supply cupboards - **no living
   person**. `[interpretation]`: this game gives the briefing role to a specific NPC - a person,
   nicknamed "the MEG Supplier" in docs and code, not a literal robot - replacing the wiki's static
   notes with a voiced moment.