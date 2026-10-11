# System: Map generation

> **Status:** partial
> **Code:** `scenes/lvl_0/map_generator.gd`, `scenes/lvl_0/lvl_0.gd`
> **Tests:** `scenes/lvl_0/tests/`

## 1. Responsibility

- Produce the infinite tile layout of Level 0: floors, ceilings, ceiling lights, walls and arches.
- `MapGenerator` is **pure data**: it fills a `Section` (a `PackedInt64Array` of bitmask "pixels").
  It never touches the scene tree, which is why it can run on a worker thread.
- `Lvl_0` is **pure instantiation**: it turns those pixels into `part_*.tscn` instances and
  `CollisionShape3D`s around the player, and removes them again when the player walks away.
- Both files live in `scenes/lvl_0/`. This is **not** a shared system: `MapGenerator` has
  `class_name MapGenerator` (so it is globally resolvable) but it is written for, and only used
  by, Level 0.
- That is intentional. The project prefers **PRY (Please Repeat Yourself)** over DRY for level
  specific logic (see [CONVENTIONS.md](../CONVENTIONS.md) section 5): a future level that needs
  procedural geometry is expected to copy and adapt this code rather than generalise it, so a
  change for Level 3 can never break Level 0.
- The only genuinely shared dependency is `UtilsMath` (`assets/scripts/utils/math.gd`) for noise.

## 2. Two stage design

```
STAGE 1 - worker thread (map_generator.gd)
------------------------------------------

  Lvl_0._start_chunk_generation(chunk_index)
      |  Thread.new().start(_generate_chunk_thread)
      v
  MapGenerator.generate_map(x0, y0, x0+128, y0+128, margin = 8)
      |
      |  Section(x0-8 .. x1+8, y0-8 .. y1+8)   "expanded"
      |  _run_mapshader(expanded)
      |      pass 0   : biome noise
      |      pass 1.. : per-biome layout + refinement
      |      (double buffered pass_a / pass_b,
      |       loops until every biome returns INVALID)
      |
      |  copy the inner 128x128 back out
      v
  chunks_in_results[chunk_index] = Section        (mutex guarded)
      |
      |  no nodes created, no scene tree access
      v

STAGE 2 - main thread (lvl_0.gd)
--------------------------------

  _process() -> _handle_world_generation()
      |
      v
  _get_or_create_chunk() picks the result up and builds
  Chunk { chunk_index, global_pos, static_body_3d, tiles, section }
      |
      v
  _add_tile() for all 128x128 pixels
      -> placed_tiles[tile_index] = PlacedTile    (data only, still no nodes)
      |
      +-----------------------------+------------------------------+
      v                                                            v
  _handle_tile_graphics()                     _handle_static_collision_shapes()
    radius VIEW_DISTANCE = 60 tiles             radius 2 tiles
    max 50 new tiles per frame                  no per-frame limit
    model.graphic.duplicate()                   model.collisions[i].duplicate()
    -> chunk.tiles                              -> chunk.static_body_3d
```

Why the split:

- Stage 1 is expensive (a dozen-plus full-grid passes over 144 x 144 cells with flood fills) but
  allocates no nodes, so it is safe off the main thread.
- Stage 2 is cheap per tile but must happen on the main thread. Keeping it distance driven is what
  makes an "infinite" level affordable: a chunk holds 16384 tiles of *data*, but at most a disc of
  radius 60 tiles of that is ever *instantiated*, and only radius 2 has collision.
- `_add_tile` runs for the whole chunk at creation time and only fills the `placed_tiles`
  dictionary; node creation is deferred to the radius handlers.

## 3. Coordinate system and constants

All constants of `scenes/lvl_0/lvl_0.gd`:

| Name                   | Value            | Meaning                                                                                 |
|------------------------|------------------|-----------------------------------------------------------------------------------------|
| `TILE_SIZE`            | `1.0` (float)    | World units per tile. One pixel of a `Section` is a 1 x 1 metre cell.                     |
| `CHUNK_SIZE`           | `128` (int)      | Tiles per chunk edge. A chunk is 128 x 128 = 16384 tiles / world units.                   |
| `GENERATION_THRESHOLD` | `CHUNK_SIZE` -> `128.0` | Distance (world units) at which a neighbouring chunk starts generating.            |
| `REMOVAL_THRESHOLD`    | `200.0`          | Distance (world units) past which a chunk is freed entirely.                              |
| `VIEW_DISTANCE`        | `60` (int)       | Radius in tiles for instantiating tile *graphics*.                                        |

Relevant constants of `scenes/lvl_0/map_generator.gd`:

| Name                     | Value              | Meaning                                                      |
|--------------------------|--------------------|---------------------------------------------------------------|
| `CHANCE_BLINKING_LIGHT`  | `0.004`            | Per-light chance that a ceiling light becomes a blinking one.  |
| `BIOME_MASK`             | `0x0000000000FF`   | Bits 0-7 hold the biome id.                                    |
| `WALL_MASK`              | `0x00000000FF00`   | Bits 8-15 - non-zero means "blocks movement" (wall or arch).   |
| `TILE_MASK`              | `0x000000FFFF00`   | Bits 8-23 - the whole tile kind, including `WALL_MASK`.        |
| `FLAG_MASK`              | `0xFFFFFF000000`   | Bits 24+ - the per-tile flags. **Unused** in the current code. |
| `PROP_MASK`              | `0xFF000000000000` | Bits 48-55 - one scattered-clutter value per tile (`PROP_CHAIR` = `0x01...`, `PROP_TRASH_BIN` = `0x02...`). Plain values, not bit flags, because a tile carries at most one prop. See section 4.9. |
| `NUM_PASSES_IN_GEN_BIOMES` | `1`              | How many leading passes belong to biome selection.             |

### World position -> tile -> chunk

The XZ plane is the map plane; the map `y` coordinate is the world `z` coordinate.

Player / world position to tile index (`_handle_tiles_in_radius`):

```gdscript
var player_pos_3d: Vector3 = _player.transform.origin
var player_pos: Vector2 = Vector2(player_pos_3d.x, player_pos_3d.z)
var tile_index_of_player: Vector2i = Vector2i(int(player_pos.x), int(player_pos.y))
```

Tile index back to world position (`_handle_tile_graphics`, `_handle_static_collision_shapes`):

```gdscript
var tile_pos: Vector3 = Vector3(float(placed_tile.tile_index.x) * TILE_SIZE, 0.0,
                                float(placed_tile.tile_index.y) * TILE_SIZE)
```

Tile index to chunk index - **the code has two different formulas**:

| Function                        | Formula                                                     |
|---------------------------------|-------------------------------------------------------------|
| `_get_pixel_at(x, y)`           | `Vector2i(int(floorf(float(x) / CHUNK_SIZE)), int(floorf(float(y) / CHUNK_SIZE)))` |
| `_get_chunk_index(tile_index)`  | `Vector2i(int(roundf(float(tile_index.x) / float(CHUNK_SIZE))), int(roundf(float(tile_index.y) / float(CHUNK_SIZE))))` |
| `_handle_world_generation()`    | `int(floorf(player_pos.x / float(CHUNK_SIZE)))` (and `.y`)   |

unclear: `_get_chunk_index` uses `roundf` while everything else uses `floorf`. For tile 100 that
gives chunk 1 (`round(0.78)`) instead of chunk 0, so `_handle_tiles_in_radius` can look up the
wrong chunk for tiles in the outer half of a chunk. Observed as written in the source; not
verified at runtime, and not "fixed" here because this document only describes the code.

Chunk index to the world position of its centre (`_get_center_chunk_pos`):

```gdscript
Vector2((float(chunk_index.x * CHUNK_SIZE)) + CHUNK_SIZE / 2.0,
        (float(chunk_index.y * CHUNK_SIZE)) + CHUNK_SIZE / 2.0)
```

A chunk's tile range is therefore `x in [chunk_index.x * 128, chunk_index.x * 128 + 128)`.

Inside a `Section`, a global tile maps to the flat array as
`data[(global_x - x) + (global_y - y) * w]` (`Section.get_pixel`).

### Pixel layout

A pixel is a 64 bit int: `biome | tile | flags`. `PreviousPass.with_tile()` keeps the biome bits
and swaps the tile bits; `with_biome()` does the opposite; both `push_error` when given the wrong
kind of value.

| Enum member                   | Value             | Meaning                                       |
|-------------------------------|-------------------|-----------------------------------------------|
| `NONE`                        | `0x000000000000`  | Empty pixel (also the zero-filled border).     |
| `BIOME_MESS`                  | `0x000000000001`  | Biome: chaotic organic maze.                   |
| `BIOME_ROOMS`                 | `0x000000000002`  | Biome: regular 7 x 7 room grid.                |
| `BIOME_ARCHES`                | `0x000000000003`  | Biome: 7 x 7 grid built from arches.           |
| `BIOME_PILLARS`               | `0x000000000004`  | Biome: open hall with 2 x 2 pillars.           |
| `TILE_WALL`                   | `0x000000000100`  | Solid wall tile (inside `WALL_MASK`).          |
| `TILE_ARCH`                   | `0x000000000200`  | Arch tile (inside `WALL_MASK`).                |
| `TILE_EMPTY`                  | `0x000000010000`  | Walkable floor.                                |
| `TILE_CEILING_LIGHT`          | `0x000000020000`  | Walkable floor + ceiling light.                |
| `TILE_CEILING_LIGHT_BLINKING` | `0x000000030000`  | Walkable floor + blinking ceiling light.       |
| `FLAG_WALL_SKIRT_F*_*`        | `0x000001000000` .. `0x000080000000` | 8 skirting-board flags, one per wall face. |
| `FLAG_WALL_LINE_F*_*`         | `0x000100000000` .. `0x008000000000` | 8 wall-line flags, one per wall face.      |
| `FLAG_WALL_LOBE_N/S/E/W`      | `0x010000000000` .. `0x080000000000` | This wall connects to the wall in that direction. |
| `FLAG_WALL_TOP_GAP`           | `0x100000000000`  | Wall is lowered by 1.0 so you can see over it. |
| `FLAG_ARCH_ROT_TO_E`          | `0x000001000000`  | Arch is rotated +PI/2 (east/west run).         |
| `FLAG_ARCH_MIRROR`            | `0x000002000000`  | Arch is rotated +PI (the mirrored half).       |
| `INVALID`                     | `0x7FFFFFFFFFFFFFFF` | "this pass produced nothing here".          |

Note the arch flags deliberately reuse the same bits as the first two wall skirt flags; which
meaning applies depends on the tile kind.

### Wall face naming

```
             FW_N | FE_N
 FN_W   FN_W/FW_N | FE_N/FN_E   FN_E
 ------------------+-------------------
 FS_W   FS_W/FW_S | FE_S/FS_E   FS_E
             FW_S | FE_S
```

`WallFace.FN_E` reads as "**F**acing **N**orth, on the **E**astern lobe". The eight members are
`FN_E = 0x01`, `FS_E = 0x02`, `FN_W = 0x04`, `FS_W = 0x08`, `FE_N = 0x10`, `FW_N = 0x20`,
`FE_S = 0x40`, `FW_S = 0x80`, collected in `all_wall_faces`.

## 4. MapGenerator algorithm

### 4.1 The pass driver

`generate_map(x0, y0, x1, y1, margin = 8)`:

1. Allocate the result `Section(x0, y0, x1, y1)`.
2. If `margin > 0`, allocate `Section(x0 - margin, y0 - margin, x1 + margin, y1 + margin)`,
   run the generator on that, then copy the inner rectangle into the result. The margin exists
   because the passes skip the outermost ring (see below) and because neighbourhood lookups clamp
   at the section edge.
3. If `margin == 0`, run directly on the result.

`_run_mapshader(section)`:

- Two buffers `pass_a` / `pass_b` (`PackedInt64Array`) are ping-ponged; `section.data` is pointed
  at whichever one was last written.
- Pass 0 reads `pass_a` (zero-filled) and writes `pass_b`.
- It then loops `pass_index = 1, 2, 3, ...` while `_run_pass` returns `true`.

`_run_pass(x0, y0, x1, y1, target, pass_index, previous_pass_array) -> bool`:

- Iterates `y in [y0+1, y1-1)` and `x in [x0+1, x1-1)` - **the 1 tile border of a section is never
  written**.
- For each cell: fill `Context` (`x`, `y`, `lx`, `ly`, `w`, `h`, `x_flt`, `y_flt`), call
  `PreviousPass.update(context)`, then `_gen(pass_index, context)`.
- If `_gen` returns `INVALID` the previous value is copied through; otherwise the new pixel is
  written and the pass is marked "did something".
- Returns `true` if at least one pixel was written, i.e. generation stops on the first pass where
  **every** cell returned `INVALID`. Since biomes have different pass counts (13, 12, 12, 11), the
  loop runs until the longest biome present in the section is exhausted.
- It prints `"Running pass: <n>"` to stdout on every pass.

`_gen(pass_index, ctx)`:

```gdscript
if pass_index < NUM_PASSES_IN_GEN_BIOMES:      # NUM_PASSES_IN_GEN_BIOMES == 1
    retval = _gen_biomes(pass_index, ctx)
else:
    var biome_pass_index: int = pass_index - NUM_PASSES_IN_GEN_BIOMES
    match pp.biome_c: ... _gen_biome_mess / _rooms / _arches / _pillars
```

Finally, a spawn guard runs for every pass:

```gdscript
if (ctx.x * ctx.x) < 100 && (ctx.y * ctx.y) < 100 && retval != Pixel.INVALID && pp.wall_c:
    retval = pp.with_tile(Pixel.TILE_EMPTY)
```

so the square `|x| < 10, |y| < 10` around the origin is kept free of walls.

`_test(pass_index, ctx)` is a hand-built debug layout; the call to it at the top of `_gen` is
commented out.

### 4.2 Pass 0 - biome selection

`_gen_biomes`, with `noise_upscale = 0.01`:

```gdscript
var noise := UtilsMath.fractal_noise_2d(ctx.x_flt * 0.01, ctx.y_flt * 0.01)
```

`UtilsMath.fractal_noise_2d` is 8 octaves of smooth-stepped value noise, amplitude halving and
frequency doubling, normalised by the amplitude sum - so roughly 0..1 centred near 0.5.

| Noise range     | Biome           |
|-----------------|-----------------|
| `< 0.4`         | `BIOME_ROOMS`   |
| `< 0.44`        | `BIOME_ARCHES`  |
| `< 0.6`         | `BIOME_MESS`    |
| `< 0.62`        | `BIOME_ARCHES`  |
| otherwise       | `BIOME_PILLARS` |

The two narrow `ARCHES` bands act as a transition ring between rooms/mess and mess/pillars. An
older grid-based (40 tile cells) selection is present but commented out.

### 4.3 `BIOME_MESS` - `_gen_biome_mess`, biome passes 0..12

| Pass    | Rule                                                                                                            |
|---------|-----------------------------------------------------------------------------------------------------------------|
| 0       | `ctx.random() > 0.9` -> `TILE_WALL` (about 10% seed walls). Else `_ceiling_light(ctx, 0.7, 5, 2)` -> `TILE_CEILING_LIGHT`. Else `TILE_EMPTY`. |
| 1       | `tile_c == TILE_CEILING_LIGHT && ctx.random() < 0.004` -> `TILE_CEILING_LIGHT_BLINKING`.                         |
| 2       | Non-wall cell with at least one wall among N/S/E/W and `ctx.random() > 0.75` -> `TILE_WALL` (grow blobs).        |
| 3       | `_is_isolated_wall_dot` -> `TILE_EMPTY` (delete single-cell walls).                                              |
| 4,5,6,7,8,9,10 | `ctx.random() > 0.1` and `_extend_walls` -> `TILE_WALL`. Seven identical passes = up to 7 cells of growth per wall end. |
| 11      | Same extend rule, plus isolated-dot removal again.                                                               |
| 12      | `_handle_walltypes(ctx, _connect_lobes(ctx, pp.pixel_c))` - lobes, lines, skirts.                                |
| 13      | Not handled -> `INVALID` -> this biome is finished.                                                              |

`_ceiling_light(ctx, 0.7, 5, 2)`: one light per 5 x 5 cell at local offset (2, 2), with a 70%
chance of being nudged one tile in a random direction.

### 4.4 `BIOME_ROOMS` - `_gen_biome_rooms`, biome passes 0..11

`const grid_cell_size = 7`, `noise_upscale = 0.4`.

| Pass    | Rule                                                                                                              |
|---------|---------------------------------------------------------------------------------------------------------------------|
| 0       | Grid: `grid_local_x == 0` or `grid_local_y == 0` -> `TILE_WALL`, else `TILE_EMPTY`. Produces 7 x 7 rooms with 1 tile walls. |
| 1       | Doorways: on a wall, `fractal_noise_2d(x * 0.4, y * 0.4) > 0.55` -> `TILE_EMPTY`.                                    |
| 2       | `# coridors` - `pp.no_change()`, placeholder, does nothing.                                                           |
| 3       | `_is_open_corner` -> `TILE_WALL` (close L-shaped gaps left by pass 1).                                                |
| 4       | `pp.wall_c && _is_wall_length_lesser_then(pp, ctx, 4)` -> `TILE_EMPTY` (delete wall fragments shorter than 4).        |
| 5       | On non-wall cells, `_ceiling_light(ctx, 0.1, 4, 2)` -> `TILE_CEILING_LIGHT` (one per 4 x 4, 10% misplacement).        |
| 6       | Blinking light, chance `0.004`.                                                                                       |
| 7       | Top gaps: a wall dead end, `ctx.random() > 0.70`, `_find_distance_to_deadend(pp, ctx, 5) >= 0`, `_find_distance_to_junction(pp, ctx, 5) >= 0` and their sum `<= 3` -> `TILE_WALL \| FLAG_WALL_TOP_GAP`. |
| 8, 9, 10 | Spread `FLAG_WALL_TOP_GAP` from any N/S/E/W neighbour onto non-junction walls - three passes, so a gap spreads at most 3 tiles. |
| 11      | `_handle_walltypes(ctx, _connect_lobes(ctx, pp.pixel_c))`.                                                            |
| 12      | Not handled -> `INVALID`.                                                                                             |

Net effect: a regular office-like grid of 6 x 6 open rooms, punched through with doorways, with
short stubs removed and some dead-end walls lowered so you can see over them.

### 4.5 `BIOME_ARCHES` - `_gen_biome_arches`, biome passes 0..11

`const grid_cell_size = 7`, `noise_upscale = 0.4`. Same skeleton as rooms, but the grid is made of
`TILE_ARCH` instead of `TILE_WALL`.

| Pass    | Rule                                                                                                           |
|---------|------------------------------------------------------------------------------------------------------------------|
| 0       | Grid: `grid_local_x == 0` or `grid_local_y == 0` -> `TILE_ARCH`, else `TILE_EMPTY`.                               |
| 1       | Openings: on an arch, `fractal_noise_2d(x * 0.4, y * 0.4) > 0.55` -> `TILE_EMPTY`.                                |
| 2       | `# coridors` - `pp.no_change()`, placeholder.                                                                     |
| 3       | `_is_wall_length_lesser_then(pp, ctx, 4)` -> `TILE_EMPTY` (diagonals counted).                                    |
| 4       | `_ceiling_light(ctx, 0.1, 4, 2)` on non-wall cells.                                                               |
| 5       | Blinking light, chance `0.004`.                                                                                   |
| 6       | `_is_corner` -> `TILE_EMPTY`: arches cannot turn a corner, so corners are cut out.                                |
| 7       | `_is_wall_length_lesser_then(pp, ctx, 5, 0, 0, false)` -> `TILE_EMPTY` (orthogonal only, threshold 5).            |
| 8       | `_is_open_corner` -> `TILE_WALL`; additionally, if the N and S neighbours are both arches, or the two horizontal neighbours are both arches, -> `TILE_ARCH` (fill one-tile holes in an arch run). |
| 9       | Alignment: on an arch, set `FLAG_ARCH_ROT_TO_E` when a horizontal neighbour is an arch; set `FLAG_ARCH_MIRROR` when a vertical neighbour is an arch and `(y & 1) == 1`, or a horizontal neighbour is an arch and `(x & 1) == 1`. This pairs tiles up so each 2 tile span forms one complete arch. |
| 10      | Fix mis-aligned: for each of the four (rotation, mirror) combinations, if the arch half it should pair with is not an arch, degrade this tile to `TILE_WALL` (when that side is a wall) or `TILE_EMPTY`. |
| 11      | `_handle_walltypes(ctx, _connect_lobes(ctx, pp.pixel_c))`.                                                        |
| 12      | Not handled -> `INVALID`.                                                                                         |

unclear: in passes 8, 9 and 10 the locals are named `e` and `w` but read offsets `(-1, 0)` and
`(+1, 0)` respectively, i.e. the two names are swapped relative to the rest of the file. The logic
is symmetric in those spots so the output looks unaffected, but the naming is misleading.

### 4.6 `BIOME_PILLARS` - `_gen_biome_pillars`, biome passes 0..10

`const grid_cell_size = 3`.

| Pass    | Rule                                                                                                      |
|---------|-------------------------------------------------------------------------------------------------------------|
| 0       | `_ceiling_light(ctx, 1.0, 3, 1)` -> `TILE_CEILING_LIGHT`, else `TILE_EMPTY`. One light per 3 x 3 cell, always jittered (`misplacement_chance = 1.0`). |
| 1       | Blinking light, chance `0.004`.                                                                              |
| 2       | 2 x 2 pillar: `grid_local_x` in `{1, 2}` and `grid_local_y` in `{1, 2}` -> `TILE_WALL`. Other cells fall out of the `match` with no `return`, so they yield `INVALID` and keep their previous value. |
| 3,4,5,6,7,8 | `pp.no_change()` - six empty passes. Placeholders that keep the biome alive for the same number of passes as its neighbours. |
| 9       | `pp.wall_c && _is_wall_length_lesser_then(pp, ctx, 4)` -> `TILE_EMPTY`.                                      |
| 10      | `_connect_lobes(ctx, pp.pixel_c)` only - **no** `_handle_walltypes`, so pillars never get line or skirt flags. |
| 11      | Not handled -> `INVALID`.                                                                                     |

### 4.7 Refinement helpers

| Helper                                                     | What it does                                                                                                   |
|------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------|
| `_ceiling_light(ctx, misplacement_chance, interval_range, offset)` | True on the one cell per `interval_range` x `interval_range` block at local `offset`, optionally nudged 1 tile by a per-block hash. |
| `_extend_walls(ctx)`                                        | Grows a straight wall end by one tile; refuses if any diagonal neighbour is a wall.                               |
| `_retract_walls(ctx)`                                       | Inverse of the above. **Defined but never called.**                                                               |
| `_is_isolated_wall_dot(ctx)` / `..._at_offset`              | Wall with no orthogonal wall neighbour.                                                                           |
| `_is_open_corner(ctx)`                                      | Non-wall cell that would close an L shape.                                                                        |
| `_is_corner(ctx)`                                           | Wall with both a vertical and a horizontal neighbour.                                                             |
| `_is_wall_deadend(ctx)`                                     | Wall with exactly one orthogonal wall neighbour.                                                                  |
| `_is_junction(ctx)` / `..._at_offset`                       | Wall with (N or S) **and** (W or E).                                                                              |
| `_get_wall_length(pp, ctx, limit = 10, ...)`                | Flood fill counting connected wall cells, optionally including diagonals, capped at `limit`.                      |
| `_is_wall_length_lesser_then` / `_is_wall_length_greater_then` | Thresholded wrappers. `_greater_then` is **never called**.                                                      |
| `_find_distance_to_deadend(pp, ctx, limit = 10, ...)`       | Iterative search, returns the shortest distance to a dead end or `-1`.                                            |
| `_find_distance_to_junction(pp, ctx, limit = 10, ...)`      | Recursive search, returns the longest distance to a junction or `-1`.                                             |
| `_connect_lobes(ctx, pixel)`                                | On `TILE_WALL`, sets `FLAG_WALL_LOBE_N/S/E/W` for each wall neighbour. Drives mesh removal in `lvl_0.gd`.         |
| `_get_connected_walls_at_offset(..., limit = 50)`           | Iterative walk over a connected *face* run, returns the visited `(dx, dy, face)` triples.                         |
| `_get_wall_face_hash(ctx, face, limit = 50)`                | Stable hash of a whole connected face run, memoised in `ctx.pass_cache` for every cell of the run.                |
| `_get_wall_section_hash(ctx, limit = 50)`                   | Hash of a straight wall run's endpoints. **Only used in commented-out debug code.**                               |
| `_handle_walltypes(ctx, pixel)`                             | For each of the 8 faces of a `TILE_WALL`, take `_get_wall_face_hash`; `random_with_seed(hash([face_hash, "line"])) > 0.7` adds the line flag, `... "skirt"] ) > 0.7` adds the skirt flag. The hash makes the decision identical along the whole run, so a line or skirt never stops halfway down a wall. |

### 4.8 Randomness

There is **no global seed**. `Context.random()` builds a fresh `RandomNumberGenerator` seeded with
`hash(Vector2i(x, y))`; `Context.random_with_seed(v)` seeds with `hash(v)`. Everything is therefore
a deterministic function of the global tile coordinate, which is what makes chunks seamless and the
generator reproducible across runs. The flip side is that the world is always the same world.

### 4.9 Prop pass

Runs as the **last pass of every biome chain** (`_gen_biome_mess` pass 13, `_gen_biome_rooms` 12,
`_gen_biome_arches` 12, `_gen_biome_pillars` 11), each of which just calls the shared
`_gen_props(ctx)`. Because it is the final case of the chain, every wall/arch it looks at is already
settled, and it reads the previous pass through `ctx.get_at_offset`, which clamps at the section
edge - the same way the structural passes rely on the generation margin for their neighbourhood
checks. **Keep it the last case** when adding passes to a biome: `PreviousPass.with_tile` rebuilds a
pixel from biome + tile only, so a later structural pass would wipe the prop value again.

Placement is grid based, not scan-order based: the generator divides the plane into
`PROP_CHAIR_GRID_SIZE` / `PROP_TRASH_BIN_GRID_SIZE` (both `6`) tile cells, and for each cell derives,
purely from that cell's own global coordinates (via `hash()`, no mutable RNG state):

- whether the cell rolls a prop at all (`PROP_CHAIR_CHANCE` / `PROP_TRASH_BIN_CHANCE`, both `0.2`);
- one candidate tile inside the cell;
- a priority score used to resolve conflicts between nearby cells.

A candidate only survives if its tile is exactly `TILE_EMPTY` (that alone means walkable and free),
it is outside `PROP_SPAWN_EXCLUSION_RADIUS` = `12` tiles around the origin, its four neighbours are
in the same biome (so the walls it sees are final), **and** no valid candidate in a neighbouring
cell (3x3 neighbourhood) closer than the grid size has a higher priority score - this keeps minimum
spacing between same-type props deterministic and local, with no dependency on scan order, so two
overlapping sections (or the same section regenerated) always agree pixel for pixel. A rival
candidate in a *different* biome is counted by its dice roll alone (its walls may not be final
yet), which gives both sides the same verdict and keeps the spacing intact at biome borders.
Chairs require `PROP_CHAIR_MIN_OPEN_NEIGHBORS` (`3`) non-wall orthogonal neighbours (open floor, not
a tight corner); trash bins require exactly one orthogonally adjacent `TILE_WALL`.

A tile can only ever carry one prop: `_gen_props` returns the bin first if it wins, otherwise the
chair, and the value is written with `with_prop(pixel, prop)` onto the existing `TILE_EMPTY` pixel
(biome preserved) - see `PROP_MASK` in section 3 and `Lvl_0._place_prop()` in section 5.

## 5. Tile to model mapping

Loaded once in `lvl_0.gd` via `_load_model(preload(...))`, which splits each `part_*.tscn` into a
`Model { id, graphic: Node3D, collisions: Array[CollisionShape3D] }`.

| Pixel / cell kind                     | Scene instantiated                             | Notes                                                                 |
|---------------------------------------|------------------------------------------------|-------------------------------------------------------------------------|
| every tile                            | `part_1x1_floor.tscn`                          | Unconditional, added first in `_add_tile`.                               |
| every tile except the two light tiles | `part_1x1_ceiling.tscn`                        | Skipped for `TILE_CEILING_LIGHT` and `TILE_CEILING_LIGHT_BLINKING`.      |
| `TILE_EMPTY`                          | - (floor + ceiling only)                       | `_add_tile` returns early.                                               |
| `TILE_CEILING_LIGHT`                  | `part_1x1_ceiling_light.tscn`                  | Replaces the plain ceiling.                                              |
| `TILE_CEILING_LIGHT_BLINKING`         | `part_1x1_ceiling_light_blinking.tscn`         | Replaces the plain ceiling.                                              |
| `TILE_WALL`                           | `part_wall_x.tscn`                             | Via `_place_wall(model_wall_x, null, null, tile_index)`, angle always 0. |
| `TILE_ARCH`                           | `part_arch_i.tscn`                             | Via `_place_wall(model_arch_i, null, model_arch_e, tile_index)`.         |
| `part_arch_i_mirror.tscn`             | **never instantiated**                         | The file exists in `scenes/lvl_0/` but no script references it; mirroring is done by rotating `part_arch_i` by PI. |
| `part_arch_e.tscn`                    | loaded as `model_arch_e`, **never placed**     | It is passed into `_place_wall` as `_wall_model_e`, which is unused (the underscore prefix marks it so). |
| `PROP_CHAIR` bit set                  | `part_prop_chair.tscn`                         | Via `_place_prop(pixel, tile_index)`, called from `_add_tile` right after floor/ceiling, before the `TILE_MASK` match - see below. |
| `PROP_TRASH_BIN` bit set              | `part_prop_trash_bin.tscn`                     | Same call site as the chair; static-only, no `RigidBody3D`/`PhysicsSounds`.|

Arch rotation (`_place_wall`), applied with `graphic.rotate_y(angle)`:

| Flags on the pixel                        | `angle`      |
|-------------------------------------------|--------------|
| none                                      | `0`          |
| `FLAG_ARCH_ROT_TO_E`                      | `PI/2`       |
| `FLAG_ARCH_MIRROR`                        | `PI`         |
| `FLAG_ARCH_ROT_TO_E` + `FLAG_ARCH_MIRROR` | `PI/2 + PI`  |

### Wall orientation convention

`part_wall_x.tscn` is a single "cross" model whose sub-meshes are selectively deleted per tile, not
a set of pre-rotated variants. `ModelModefier.remove_meshes_with_postfix` drives this by **child
node name suffix**:

| Node name suffix                                               | Removed unless                                      |
|-----------------------------------------------------------------|------------------------------------------------------|
| `_n`, `_s`, `_e`, `_w`                                            | the matching `FLAG_WALL_LOBE_*` is set                |
| `_skirt_fn_e`, `_skirt_fs_e`, `_skirt_fn_w`, `_skirt_fs_w`, `_skirt_fe_n`, `_skirt_fw_n`, `_skirt_fe_s`, `_skirt_fw_s` | the matching `FLAG_WALL_SKIRT_*` is set |
| `_line_fn_e` ... `_line_fw_s`                                     | the matching `FLAG_WALL_LINE_*` is set                |

and `ModelModefier.yoffset_*` shifts nodes whose name ends in `offs_n`, `offs_s`, `offs_w`,
`offs_e`, `offs_c` by `-1.0` when `FLAG_WALL_TOP_GAP` is set on this tile (all five) or on the
neighbour in that direction (that one only). The same removal test is applied to collision shapes.

`scenes/lvl_0/docs/TECHNICAL.md` does describe an orientation convention, but it is **out of date**:
it talks about a script `generate_level.gd` and a part `part_1x1_wall` with "only 1 face pointing to
the positive Y, located at exactly [0,0,0]". Neither of those names exists in the project any more
(the script is `map_generator.gd`, the part is `part_wall_x.tscn`). Treat the suffix table above as
the authoritative convention.

### Prop orientation convention

`_place_prop()` hands every prop (chair and trash bin alike) to `_instantiate_prop_model()`, which
stores a per-model pose on the tile's `ModelModefier` (which owns everything that changes how the
models of one tile are rendered/collided; it is created for the tile when it has none yet):

| Value | Source |
|-------|--------|
| angle (`ModelModefier.model_angles`) | `_get_prop_angle(tile_index)` - any angle in `[0, TAU)`, so props are not aligned with walls. |
| offset (`ModelModefier.model_offsets`) | `_get_prop_wanted_offset(tile_index)` - a point uniformly distributed in a disc of `PROP_MAX_OFFSET_RADIUS` (`0.8` m) around the tile center. |

Both come from a coordinate hash (`_get_prop_random`, with a salt per value), never from a shared
RNG, so a regenerated chunk puts every prop at the same pose. The offset can leave the prop's own
tile, so `_get_prop_offset()` checks the prop's footprint (`PROP_FOOTPRINT_HALF_EXTENT` = `0.25` m
square) against walls/arches and halves the offset (up to `PROP_OFFSET_SHRINK_STEPS` times, then
zero) until it no longer clips one. A neighbour chunk that is not loaded yet reads as `INVALID`,
which counts as a wall, so the offset may be smaller than wanted right at a chunk border.

The tile-wide `PlacedTile.angle` is no longer touched by props; the graphics and collision creation
use `_get_model_angle()` / `_get_model_offset()`, which read the `ModelModefier` and fall back to the
tile angle / no offset for every other model. A later `_instantiate_model` call with a null modefier
replaces the tile's modefier, so props must be placed after the floor/ceiling (as `_add_tile` does).

## 6. Streaming and pooling

### Chunk lifecycle

Driven from `_process` -> `_handle_world_generation()`, every frame:

1. **Removal** - for every live chunk, `dist = |_get_center_chunk_pos(chunk_index) - player_pos|`;
   if `(dist - CHUNK_SIZE / 2.0) > REMOVAL_THRESHOLD` (`> 200.0`) the chunk is removed.
   `_remove_chunk` detaches `chunk.tiles` and `chunk.static_body_3d` from `Map`, `queue_free()`s the
   tiles node, calls `queue_free` on the groups `col_<tiles name>` and `col_<static body name>`
   (commented "not tested"), and erases the chunk from `chunks`.
2. **Creation** - for the 3 x 3 block of chunk indices around the player's chunk, any missing chunk
   whose `(dist - CHUNK_SIZE / 2.0) < GENERATION_THRESHOLD` (`< 128.0`) is requested with
   `_get_or_create_chunk(chunk_index, true)`.

`_get_or_create_chunk(chunk_index, async)`:

- Cache hit -> re-parents `static_body_3d` / `tiles` under `Map` if needed and returns the `Chunk`.
- `async == true` -> first call registers the index in `chunks_in_progress` (mutex guarded) and
  starts a `Thread` running `_generate_chunk_thread`; it then returns `null`. Later calls poll
  `chunks_in_results` (mutex guarded) and return `null` until the section is there.
- `async == false` -> generates synchronously on the calling thread (`_generate_chunk`).
- Once a section is available it builds the `Chunk`, adds a fresh `StaticBody3D`
  (`Chunk_static_body_<x>_<y>`) and `Node3D` (`Chunk_<x>_<y>`) under
  `$_viewport_container/_viewport/Map`, and runs `_add_tile` over all 128 x 128 pixels.

`_generate_chunk` calls `generate_map(x0, y0, x0 + 128, y0 + 128, 8)`.

`_add_tile` does **not** create nodes. It calls `_instantiate_model`, which only records a
`PlacedTile { tile_index, angle, models, model_modefier }` in the level-wide `placed_tiles`
dictionary. Note `placed_tiles` is never pruned when a chunk is removed, so it grows for the whole
session.

### Two radii

| Handler                            | Radius                  | Per-frame cap            | What it creates                                               |
|------------------------------------|-------------------------|--------------------------|----------------------------------------------------------------|
| `_handle_tile_graphics()`          | `VIEW_DISTANCE` = `60` tiles | `max_tiles_to_handle = 50` | `model.graphic.duplicate()` -> `chunk.tiles`                 |
| `_handle_static_collision_shapes()`| `2` tiles               | `0` (no cap)             | `collision.duplicate()` -> `chunk.static_body_3d`             |

Both go through `_handle_tiles_in_radius(radius, cache, create_cb, remove_cb, max_tiles_to_handle)`,
which:

- scans the square `[tile - radius, tile + radius)` and keeps tiles where
  `int(roundf(dist)) < radius`;
- sorts the visible tiles by squared distance so instantiation grows outwards from the player;
- removes tiles that left the radius first (`remove_cb`, i.e. `queue_free()` on the duplicated
  nodes), then creates up to `max_tiles_to_handle` new ones;
- keeps per-handler state in a `HandleTilesCache` (`last_tiles_where_needed`, `placed_tiles`).

So geometry is visible out to 60 tiles but only solid within 2 tiles of the player. The 50
tiles/frame budget means a full 60 tile disc (around 11300 tiles) takes a few hundred frames to
fill in after a teleport.

### Pooling

**`NodePool` is not used by the map generation path.** `assets/scripts/utils/node_pool.gd` defines
`class_name NodePool`, but a project-wide search finds no `.gd` or `.tscn` that instantiates it -
`lvl_0.gd` creates its nodes with `Node3D.duplicate()` and destroys them with `queue_free()` on
every radius change.

What `NodePool` would do if wired in:

| Member                                   | Behaviour                                                                 |
|------------------------------------------|---------------------------------------------------------------------------|
| `get_auto_create(reference_node: Node3D) -> Node3D` | Pops a recycled copy from that template's archive, or creates one. |
| `archive(created_node: Node3D) -> void`  | Re-parents the node back into the off-tree archive, keyed by the `"_<>_"` name prefix. |
| `Pool._init(node_reference: Node3D)`     | **Pre-allocates 20000 duplicates** (`for i in range(0, 20000)`) into the archive node. |

Memory implication: 20000 duplicated `Node3D` subtrees **per distinct template**. With the seven
templates `lvl_0.gd` loads that would be 140000 live nodes before a single tile is drawn, which is
why `STATUS.md` issue 6 warns "watch memory when reusing it". Note the `Pool` also never shrinks and
`get_auto_create` prints a line every time it has to create beyond the pre-allocation.

`docs/ai/ARCHITECTURE.md` section 7 and `scenes/lvl_0/docs/SPEC.md` both currently claim nodes are
recycled "via `NodePool`". That is not what the code does today.

## 7. Async level loading contract

`LevelTransition` (`assets/scripts/level_transition.gd`) optionally calls, on the freshly
instantiated level scene:

```gdscript
func initialize_async() -> void   # start heavy work (threads, generation)
func initialized() -> bool        # return true once that work is done
```

`lvl_0.gd` implements both:

```gdscript
func initialize_async() -> void:
	initialized()

func initialized() -> bool:
	var chunk1: Chunk = _get_or_create_chunk(Vector2i(0, 0), true)
	var chunk2: Chunk = _get_or_create_chunk(Vector2i(-1, -1), true)
	var chunk3: Chunk = _get_or_create_chunk(Vector2i(-1, 0), true)
	var chunk4: Chunk = _get_or_create_chunk(Vector2i(0, -1), true)
	return chunk1 && chunk2 && chunk3 && chunk4
```

- `initialize_async()` simply calls `initialized()` once; because `_get_or_create_chunk(.., true)`
  *starts* the worker threads on its first call for an index, that one call is what kicks off
  generation of the four chunks that meet at the world origin.
- `initialized()` is then polled by the transition state machine. Each poll re-enters
  `_get_or_create_chunk`, which picks up any finished section from `chunks_in_results`, builds the
  `Chunk`, and returns it. It returns `true` only when all four chunks exist.
- The level is only shown once that happens, so the player never spawns into empty space.
- At this point `_node_map` is still `null` (it is an `@onready` on
  `$_viewport_container/_viewport/Map`), so `_get_or_create_chunk` skips the `add_child` calls and
  the later cache-hit branch re-parents the nodes under `Map` on the first call after `_ready`.
- `_ready()` additionally contains a **blocking** fallback loop that calls the same four
  `_get_or_create_chunk(.., true)` and `OS.delay_msec(50)`s until all four are non-null. If the
  level is loaded without `LevelTransition`, that loop stalls the main thread until generation is
  done.

unclear: the per-chunk `Thread` objects are stored in `chunk_threads` but `wait_to_finish()` is
never called on them, and the dictionary is never cleaned.

## 8. Public API

### `MapGenerator` (`scenes/lvl_0/map_generator.gd`, `extends Node`)

| Signature                                                                      | Purpose                                                                 |
|--------------------------------------------------------------------------------|---------------------------------------------------------------------------|
| `func generate_map(x0: int, y0: int, x1: int, y1: int, margin: int = 8) -> Section` | Generate the tile data for the global rectangle `[x0, x1) x [y0, y1)`. |
| `func generate_map_image(width: int, height: int, margin: int = 8) -> Image`    | Debug render of `generate_map(0, 0, width, height, margin)` at 6 x 6 pixels per tile, including wall lobes, skirt/line marks and arch direction. |
| `func generate_biome_image(width: int, height: int, margin: int) -> Image`      | Debug render at 1 pixel per tile using `TileUtils.to_color`.               |
| `static func is_wall(pixel: Pixel) -> bool`                                     | `pixel & WALL_MASK != 0`.                                                  |
| `static func is_wall_arch(pixel: Pixel) -> bool`                                | `(pixel & TILE_MASK) == TILE_ARCH`.                                        |
| `static func with_flag(pixel: Pixel, flag: Pixel) -> Pixel`                     | Bitwise or.                                                                |
| `static func has_flag(pixel: Pixel, flag: Pixel) -> bool`                       | Bitwise and `!= 0`.                                                        |

Inner classes:

| Signature                                                                | Purpose                                                        |
|--------------------------------------------------------------------------|-------------------------------------------------------------------|
| `MapGenerator.Section._init(x0: int, y0: int, x1: int, y1: int) -> void`  | Allocates `w * h` entries; exposes `x`, `y`, `w`, `h`, `data`.    |
| `MapGenerator.Section.get_pixel(global_x: int, global_y: int) -> Pixel`   | Read by global tile coordinate.                                   |
| `MapGenerator.Section.get_pixel_clamped(global_x: int, global_y: int) -> Pixel` | Same, clamped to the section bounds.                        |
| `MapGenerator.Section.set_pixel(global_x: int, global_y: int, tile_type: Pixel) -> void` | Write by global tile coordinate.                |
| `MapGenerator.TileUtils.get_biome(pixel: Pixel) -> Pixel`                 | `pixel & BIOME_MASK`.                                             |
| `MapGenerator.TileUtils.remove_biome(pixel: Pixel) -> Pixel`              | Strips the biome bits.                                            |
| `MapGenerator.TileUtils.to_color(pixel: Pixel) -> Color`                  | Debug colour for a pixel.                                         |
| `MapGenerator.PreviousPass.with_tile(tile: Pixel) -> Pixel`               | Current biome + the given tile. `push_error` if given a biome.    |
| `MapGenerator.PreviousPass.with_biome(biome: Pixel) -> Pixel`             | Current tile + the given biome. `push_error` if given a tile.     |
| `MapGenerator.PreviousPass.no_change() -> Pixel`                          | Returns `pixel_c` unchanged.                                      |
| `MapGenerator.Context.get_at(pass_data: PackedInt64Array) -> Pixel`       | Current cell of an arbitrary pass buffer.                         |
| `MapGenerator.Context.get_at_offset(pass_data: PackedInt64Array, offset_x: int, offset_y: int) -> Pixel` | Neighbour, clamped to the section.  |
| `MapGenerator.Context.random() -> float`                                  | Deterministic 0..1 from `hash(Vector2i(x, y))`.                   |
| `MapGenerator.Context.random_with_seed(seed_val: Variant) -> float`       | Deterministic 0..1 from `hash(seed_val)`.                         |

Every other function in the file is `_`-prefixed and private.

### `Lvl_0` (`scenes/lvl_0/lvl_0.gd`, `extends Node`)

| Signature                        | Purpose                                                                     |
|----------------------------------|--------------------------------------------------------------------------------|
| `func initialize_async() -> void`| `LevelTransition` hook; starts generation of the four origin chunks.           |
| `func initialized() -> bool`     | `LevelTransition` hook; `true` once those four chunks exist.                   |
| `func _ready() -> void`          | Godot callback: grabs the player, registers the `lvl_0_landing` wieldable, then blocks until the four origin chunks exist. |
| `func _process(_delta: float) -> void` | Godot callback: landing, world generation, tile graphics, collision shapes. |

Public state (no accessors; read directly):

| Member                                      | Type / content                                   |
|---------------------------------------------|---------------------------------------------------|
| `chunks`                                    | `Dictionary` - `Vector2i` chunk index -> `Chunk`   |
| `placed_tiles`                              | `Dictionary` - `Vector2i` tile index -> `PlacedTile` |
| `chunks_in_progress` / `chunks_in_progress_mutex` | pending generations, guarded                 |
| `chunks_in_results` / `chunks_in_results_mutex`   | finished `Section`s, guarded                 |
| `chunk_threads`                             | `Dictionary` - `Vector2i` -> `Thread`              |
| `model_floor`, `model_ceiling`, `model_ceiling_light`, `model_ceiling_light_blinking`, `model_wall_x`, `model_arch_i`, `model_arch_e`, `model_prop_chair`, `model_prop_trash_bin` | `Model` |
| `last_model_id`                             | `int`, incremented by `_load_model`                |

Helper classes: `Lvl_0.Model`, `Lvl_0.Chunk`, `Lvl_0.PlacedTile`, `Lvl_0.ModelModefier`,
`Lvl_0.HandleTilesCache` - all plain data holders with an empty `_init()`.

## 9. Testing

### Run once, headless

From the project root:

```bash
godot --headless --path . -s scenes/lvl_0/tests/test_map_gen.gd
```

`scenes/lvl_0/tests/test_map_gen.gd` `extends SceneTree`, loads `map_generator.gd` by path
(`push_error` + `quit(1)` if that fails), calls `generate_map_image(256, 256)` - so the default
`margin = 8` applies - saves the result and `quit(0)`s. A failed save produces
`push_error("Failed to save maze image: ...")`.

### `result.png`

- Written to `res://scenes/lvl_0/tests/result.png`.
- 256 x 256 tiles rendered at 6 x 6 pixels per tile, so **1536 x 1536**, `FORMAT_RGB8`.
- Each tile is first filled with its *biome* colour (`BIOME_* | TILE_EMPTY`), then the tile itself is
  drawn on top:
  - walls as a 2 x 2 pixel core plus a 2 x 2 "lobe" towards each `FLAG_WALL_LOBE_*` neighbour, so
    wall connectivity is visible directly;
  - skirt and line flags as coloured strips along the matching face - red = skirt only,
    blue = line only, magenta = both (`_set_wall_edge_pixel`);
  - arches as a 4 x 4 block with a gradient and a solid edge on the side the arch opens towards,
    chosen from `FLAG_ARCH_ROT_TO_E` / `FLAG_ARCH_MIRROR`;
  - `FLAG_WALL_TOP_GAP` walls in grey `(0.393, 0.393, 0.393)` instead of black;
  - lights in cyan, blinking lights in dark cyan.
- The commented-out `image.resize(...)` line in the test would scale it 3x with nearest neighbour.

### Watch loop

```bash
bash scenes/lvl_0/tests/test_map_gen.sh
```

(there is no shebang line in the file, so run it through `bash` or `sh` explicitly). It:

1. defines `run_test()`, which runs the headless command above and, on success, opens the PNG with
   `xdg-open scenes/lvl_0/tests/result.png`; on failure it prints `"Godot failed"`;
2. runs it once;
3. if `inotifywait` is available (`inotify-tools`), loops forever on
   `inotifywait -e modify scenes/lvl_0/map_generator.gd` and re-runs `run_test` after every
   modification, so saving the generator immediately regenerates and re-opens the preview;
4. if `inotifywait` is missing it prints a hint to install `inotify-tools` and exits.

Note both branches inside the loop end up calling `run_test`: the `status -ne 0` branch is a restart
path for a failed watcher, the normal branch is the "Change found!" path.

There is no automated assertion anywhere - the test is a visual one, you look at `result.png`.

## 10. Known gaps

Cross-checked against `scenes/lvl_0/docs/DESIGN.md`:

- **Biome: Arches - 0% in DESIGN.md.** Code exists (`_gen_biome_arches`, `part_arch_i.tscn`) and the
  biome is selected by the noise, so this is really "implemented but not accepted". The mirrored
  half is still produced by rotating one model, and `part_arch_i_mirror.tscn` is dead weight.
- **Biome: Pillars - 0% in DESIGN.md.** Same: `_gen_biome_pillars` exists but is minimal - a 2 x 2
  block every 3 tiles, six empty placeholder passes, and no wall line/skirt detailing at all.
- **Biome: Holes - not implemented.** No `Pixel` value, no pass, no part scene. Per the wiki, Holes
  are a grid-pattern pit cluster generated "like the pillars" - so per the resolved design in
  `scenes/lvl_0/docs/DESIGN.md` this should become a sixth `BIOME_*` value implemented the same way
  as `BIOME_PILLARS` (a grid of pitch-black pits), not a handcrafted one-off POI like the Manila
  room. It does not lead to another level - walking into one is meant to trigger a Game Over screen
  (see [./ui_subtitles.md](./ui_subtitles.md) section 6 and [./save_system.md](./save_system.md)).
- **Biome: Blackout zones - not implemented.** Lights are the only lighting control and there is no
  "no light" biome. Planned as a fifth `BIOME_*` value alongside `MESS`/`ROOMS`/`ARCHES`/`PILLARS`,
  with a shallow-water tile subset and a hand-feel wall shader - see `DESIGN.md`.
- **Biome: Extremely loud buzzing sound - not implemented.** Nothing in the generator produces audio
  markers.
- **Biome: Manila room - not implemented.** Planned as a handcrafted POI (like `entry_tube.tscn`),
  not a tiled biome, gated by the save system so it stops appearing once visited once - see
  [./npc_bot.md](./npc_bot.md) and [./save_system.md](./save_system.md).
- **Biome: Red rooms (Should) and The torment (Could) - not implemented.** Red rooms are planned to
  only become selectable by the biome generator once the save system reports the Manila room has
  been visited - see `DESIGN.md` and [./save_system.md](./save_system.md).
- **No glitched wall / exit to lvl_1.** `lvl_0.gd` never constructs a `LevelTransition`, and there
  is no `Pixel` value, flag or part for a glitched wall. Level 0 currently has no exit at all.
- **No "layout changes where you don't look".** Generation is a pure function of the tile
  coordinate and a chunk's `Section` is never regenerated, so the layout behind the player is
  frozen. Re-entering a removed chunk reproduces exactly the same geometry.
- **Infinite chunks - 80% in DESIGN.md.** Working, but with rough edges:
  - `_get_chunk_index` uses `roundf` where everything else uses `floorf` (section 3);
  - `placed_tiles` is never pruned when a chunk is removed, so it only grows;
  - `chunk_threads` entries are never `wait_to_finish()`ed or erased;
  - the group-based collision cleanup in `_remove_chunk` is commented "not tested";
  - `_ready()` blocks the main thread with `OS.delay_msec(50)` until the first four chunks exist;
  - the generator prints `"Running pass: <n>"` per pass and several `print`s per chunk, from a
    worker thread, on every chunk.
- **`NodePool` is documented as used, but is not** (section 6). `ARCHITECTURE.md` section 7 and
  `scenes/lvl_0/docs/SPEC.md` need correcting, or the pool needs wiring in.
- **`scenes/lvl_0/docs/TECHNICAL.md` is stale**: it names `generate_level.gd` and `part_1x1_wall`,
  neither of which exists.
- **Dead code in the generator**: `_retract_walls`, `_is_wall_length_greater_then` and
  `_get_wall_section_hash` are never called; `_test()` is a disabled debug layout; the `# coridors`
  passes in the rooms and arches biomes do nothing.
- **Dead code in the level**: `_find_spawn_point()` and `_get_wall_t_px()` are never called, and
  `model_arch_e` is loaded but never placed.
- **No seed control.** The world is a fixed function of the tile coordinate, so every playthrough
  gets the identical Level 0. There is no way to re-roll it.
- **No automated test.** `test_map_gen.gd` asserts nothing; correctness is judged by eye from
  `result.png`.

## 11. Related

- [../ARCHITECTURE.md](../ARCHITECTURE.md) - where this sits in the whole project
- [./utils.md](./utils.md) - `UtilsMath` (noise) and `NodePool`
- [./level_flow.md](./level_flow.md) - `LevelTransition` and the async loading contract
- [../../../scenes/lvl_0/docs/SPEC.md](../../../scenes/lvl_0/docs/SPEC.md) - what Level 0 must be
- [../../../scenes/lvl_0/docs/TECHNICAL.md](../../../scenes/lvl_0/docs/TECHNICAL.md) - Level 0 build notes (stale, see section 5)
- [./npc_bot.md](./npc_bot.md) - the Manila room POI and its gating of Red Rooms
- [./save_system.md](./save_system.md) - the persisted flag that gates the Manila room and Red Rooms
