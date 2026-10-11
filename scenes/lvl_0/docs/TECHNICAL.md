# Technical

 - The level is procedualy generated, by the help of the script `generate_level.gd` It generates a bitmap with white and black pixels. 
   - The black pixels are walls, the bright ( not white per-se ) pixels are empty space.
   - Each pixel ( any color ) will have flooring. for now the only pick is `part_1x1_floor`.
   - Each pixel ( any color ) will have a ceiling. for now the only pick is `part_1x1_ceiling`.
   - Each black pixel bordering a white pixel means a wall. The wall to use is `part_1x1_wall`. It consists of only 1 face pointing to the positive Y, located at exacly [0,0,0]
   - ect... 

(This page is stale about the generator's script/part names - see
[map_generation.md](../../../docs/ai/systems/map_generation.md) for the authoritative, up to date
description of `map_generator.gd`/`part_wall_x.tscn`.)

## Scattered clutter (chairs, trash bins)

 - A reserved byte on the 64-bit `MapGenerator.Pixel` (`PROP_MASK`) marks a `TILE_EMPTY` floor
   tile as carrying a `PROP_CHAIR` or `PROP_TRASH_BIN`, set by `MapGenerator._gen_props`, the last
   pass of every biome chain, after all walls/arches are final.
 - `Lvl_0._add_tile()` checks these bits via `_place_prop()` and instantiates
   `part_prop_chair.tscn` / `part_prop_trash_bin.tscn` - both plain `MeshInstance3D` +
   `CollisionShape3D` scenes with no `RigidBody3D`, so they are static and not pushable.
 - See [map_generation.md](../../../docs/ai/systems/map_generation.md) sections 3, 4.9 and 5 for
   the full pixel contract, eligibility rules, and orientation convention.
 

