# System: Utils

> **Status:** implemented
> **Code:** `assets/scripts/utils/*.gd`

## 1. Responsibility

`assets/scripts/utils/` holds small, **stateless static helper libraries**. Each file declares one
`class_name` named `Utils<Area>` (`UtilsMath`, `UtilsNode`, `UtilsScreen`), extends `Node`, and
exposes only `static func`s. They are called as `UtilsMath.xz_normal(...)` - they are never
instantiated and never added to the scene tree.

Rules for this folder:

- **No game state here.** No member variables holding level, player or session data.
  (`NodePool` is the one exception: it is an instance-based object pool that lives in the same
  folder, see section 4.)
- Helpers must be usable from any level and from headless scripts.
- Same hard rules as the rest of the project: full type hints, `const` where possible,
  `push_error(...)` on every null check.

The folder currently contains `math.gd`, `node.gd`, `node_pool.gd`, `screen.gd` and
`static_analysis.gd` (the last one is a headless `SceneTree` tool script, documented in
[./tooling.md](./tooling.md), not a helper library).

## 2. UtilsMath

`assets/scripts/utils/math.gd`, `class_name UtilsMath`.

| Exact signature | What it does | Typical use |
|---|---|---|
| `static func fraction(x: float) -> float` | `x - floorf(x)`, the fractional part | building blocks for the hash/noise functions |
| `static func smooth_step(x: float) -> float` | `x * x * (3.0 - 2.0 * x)`, the classic smoothstep curve (does **not** clamp its input) | easing an already normalised 0..1 factor; interpolation weight inside the noise functions |
| `static func pseudo_random(x: float, h1: float = 12.9989, h2: float = 43758.54) -> float` | `fraction(sin(x * h1) * h2)` - 1D hash, returns 0..1 | deterministic "random" value for an integer coordinate |
| `static func pseudo_random_2d(x: float, y: float, h1x: float = 12.9989, h1y: float = 13.1536, h2: float = 43758.54) -> float` | 2D version of the same sine hash | deterministic value per tile/chunk coordinate |
| `static func value_noise(x: float, h1: float = 12.9989, h2: float = 43758.54) -> float` | 1D value noise: smooth-step blend between the hashes of the two neighbouring integer cells | smooth 1D variation along an axis |
| `static func value_noise_2d(x: float, y: float, h1x: float = 12.9989, h1y: float = 13.1536, h2: float = 43758.54) -> float` | 2D value noise: bilinear blend of the four corner hashes, smooth-stepped in both axes | smooth 2D field |
| `static func fractal_noise(x: float, h1: float = 12.9989, h2: float = 43758.54, iterations: int = 8) -> float` | sums `iterations` octaves of `value_noise` at doubling frequency and halving amplitude, result multiplied by `0.5`. Reference: <https://www.desmos.com/calculator/i5x9mkslt3> | 1D multi-scale variation |
| `static func fractal_noise_2d(x: float, y: float, h1x: float = 12.9989, h1y: float = 13.1536, h2: float = 43758.54, iterations: int = 8) -> float` | 8 octaves of `value_noise_2d`, normalised by the amplitude sum | **drives the lvl_0 biome selection** |
| `static func xz_distance(pos1: Vector3, pos2: Vector3) -> float` | distance between two points ignoring Y | "is the player near this box" checks on the floor plane |
| `static func xz_normal(normal: Vector3) -> Vector2` | `Vector2(normal.x, normal.z).normalized()` | flattening a facing/movement direction to the floor plane (`player.gd` uses it for look and move direction) |

Private helpers (do not call from outside): `_smooth_fraction`, `_cell_hash`, `_cell_hash_2d`.

**Determinism.** All of the noise functions are pure functions of their arguments and the hash
constants - no RNG object, no seed state, no time dependency. The same coordinate always yields the
same value, in the editor, in a build and in a headless test. That is what makes the lvl_0 map
reproducible: `scenes/lvl_0/map_generator.gd` calls
`UtilsMath.fractal_noise_2d(ctx.x_flt * noise_upscale, ctx.y_flt * noise_upscale)` to pick biomes,
so a chunk looks identical however often it is regenerated. See
[./map_generation.md](./map_generation.md).

## 3. UtilsNode

`assets/scripts/utils/node.gd`, `class_name UtilsNode`.

| Exact signature | What it does |
|---|---|
| `static func find_mesh_recursive(root_node: Node) -> MeshInstance3D` | depth-first search, returns the first `MeshInstance3D` at or under `root_node`, else `null` |
| `static func find_animation_player_recursive(root_node: Node) -> AnimationPlayer` | same, for the first `AnimationPlayer` |
| `static func find_camera_recursive(root_node: Node) -> Camera3D` | same, for the first `Camera3D` |
| `static func find_hands_recursive(root_node: Node) -> PlayerHands` | same, for the first `PlayerHands` |
| `static func find_player(tree: SceneTree) -> Player` | finds the player in the whole tree, see lookup order below |

`find_player` lookup order:

1. `tree.get_first_node_in_group("player")` - the group `player`.
2. Fallback by class: `tree.get_nodes_in_group("player")` and return the first entry cast to
   `Player`, if the array is not empty.
   - unclear: as written, step 2 queries the same group as step 1, so it can only ever add a result
     when step 1 returned a node that is not a `Player`. The comment calls it "search by class",
     but the code searches the group again.
3. Last resort deep search: `tree.get_root().find_children("*", "CharacterBody3D", true, false)`
   and return the first node that `is Player`.
4. Otherwise `null`.

**Rule: use these helpers instead of hardcoded absolute node paths.** Levels wrap their world in a
`SubViewport`, so absolute paths like `/root/lvl_0/_viewport_container/_viewport/Player` break as
soon as a scene is re-parented or loaded through `LevelTransition`. `frontroom_0.gd` shows the
intended pattern:

```gdscript
_player = UtilsNode.find_player(get_tree())
if _player == null:
	push_error("Player not found in scene tree")
```

Relative `$Child` / `@onready` paths inside a scene's own subtree are fine; it is the cross-scene
absolute paths that the helpers replace.

## 4. NodePool

`assets/scripts/utils/node_pool.gd`, `class_name NodePool`. Unlike the other files this is an
**instance** object (`NodePool.new()`), holding `var pools: Dictionary = {}` mapping a reference
node name to an inner `Pool` object.

Public API on `NodePool`:

| Exact signature | What it does |
|---|---|
| `func get_auto_create(reference_node: Node3D) -> Node3D` | looks up (or creates) the `Pool` for `reference_node` and returns a recycled or freshly duplicated copy |
| `func archive(created_node: Node3D) -> void` | splits `created_node.name` on `"_<>_"`, finds the matching pool by the prefix and returns the node to that pool's archive. Does nothing if no such pool exists |

Inner `Pool` API: `func get_auto_create() -> Node3D`, `func archive(created_node: Node3D) -> void`,
`func _create() -> Node3D`, `func _init(node_reference: Node3D) -> void`.

Recycling model:

- Every pool keeps an **off-tree** `archive_node: Node3D` created with `Node3D.new()`. It is never
  added to the scene tree, so archived copies exist but are not processed or rendered.
- `_create()` duplicates the reference node and names the copy
  `"<reference name>" + "_<>_" + str(counter)`. The `_<>_` separator is what `archive()` later uses
  to find the owning pool from a node name alone.
- `get_auto_create()` pops `archive_node.get_child(0)` via `remove_child` if the archive is not
  empty; the returned node is parentless and the caller must add it to the tree. If the archive is
  empty it prints `"created for: <counter>"` and duplicates a new one.
- `archive()` calls `created_node.reparent(archive_node)`, which moves the node out of the scene
  tree while keeping it alive.

**Pre-allocation and its memory cost.** `Pool._init` pre-allocates by duplicating the reference node
**20000** times (`for i in range(0, 20000)`) and adding every copy to the archive, printing
`Pre allocating '<name>'...` before and `... Done` after:

```gdscript
for i in range(0, 20000):
	var node: Node3D = _create()
	archive_node.add_child(node)
```

> **Warning:** this happens the first time a given reference node is passed to `get_auto_create`,
> synchronously, on the calling thread. 20000 duplicated `Node3D` subtrees **per distinct reference
> node** is a large, immediate memory and stall cost, and it is paid even if only a handful of
> copies are ever used. There is no way to configure the count - it is a literal in the loop.

- unclear: `NodePool` is currently referenced by nothing else in the project; no `.gd` file outside
  `node_pool.gd` mentions it. It reads as prepared-but-unused infrastructure for the chunk
  streaming in `scenes/lvl_0/`.

## 5. UtilsScreen

`assets/scripts/utils/screen.gd`, `class_name UtilsScreen`. Fades whole overlay "screen" scenes
(intro, loading, transition) in and out. Documented in context in
[./level_flow.md](./level_flow.md).

| Exact signature | What it does |
|---|---|
| `static func fade_in(root_node: Node, duration: float, callback: Callable) -> void` | sets `modulate.a = 0.0` on every `CanvasItem` child of `root_node`'s `CanvasLayer`, then tweens every child that has a `modulate` property to alpha `1.0` over `duration`, and finally calls `callback` via `tween.tween_callback` |
| `static func fade_in_screen(tree: SceneTree, screen_scene_path: String, callback: Callable) -> Node` | `load`s and instantiates `screen_scene_path`, adds it to `tree.root`, runs `fade_in` with `const DURATION = 0.3`, and returns the instantiated screen node (or `null` on failure) |
| `static func fade_out(root_node: Node, duration: float, callback: Callable) -> void` | mirror of `fade_in`: tweens every `modulate`-capable child of the `CanvasLayer` to alpha `0.0` over `duration`, then calls `callback` |
| `static func fade_out_screen(tree: SceneTree) -> void` | looks up `tree.root.get_node_or_null("_Screen")` and, if found, runs `fade_out` with `const DURATION = 0.3` and `loading_screen.queue_free` as the callback. Does nothing when the node is absent |

Callback parameters:

- `callback` is a zero-argument `Callable`. It is invoked once, after the tween finishes.
- It is **also** invoked immediately, without any fade, on the error paths: when the `CanvasLayer`
  child is missing in `fade_in` / `fade_out`, and when the scene fails to load or instantiate in
  `fade_in_screen`. So a caller can rely on "the callback always runs", but not on "the screen is
  actually visible when it runs".
- `fade_in` / `fade_out` return early **without** calling the callback when `root_node` itself is
  `null` (a `push_error` is raised).
- `fade_out_screen` supplies the callback itself: `loading_screen.queue_free`.

The special node name: every screen scene's **root node is named `_Screen`**
(`menu_intro.tscn`, `menu_loading.tscn`, `transition_frontrooms_lvl_0.tscn`), and each has exactly
one child named `CanvasLayer`. `fade_out_screen` finds the active screen purely by that name
directly under the tree root (`/root/_Screen`) - it keeps no reference. Consequences:

- A screen scene **must** be named `_Screen` and **must** have a child literally named
  `CanvasLayer`, or the helpers cannot find it.
- Only one such screen can be addressed at a time; `get_node_or_null` returns the first match.

## 6. Known gaps

- `NodePool` is unused by any other script and its 20000-node pre-allocation is hardcoded and
  unbounded - unusable as-is for more than one or two reference nodes.
- `NodePool.get_auto_create` and `Pool._init` print to stdout on every miss / allocation; there is
  no logging level.
- `NodePool.archive` silently does nothing if the node name has no matching pool.
- `UtilsNode.find_player` step 2 does not actually search by class (see section 3); the three
  fallbacks overlap.
- The `find_*_recursive` helpers return the first match in child order, with no way to filter by
  name - ambiguous when a scene holds several meshes or cameras.
- `UtilsScreen` depends on the magic names `_Screen` and `CanvasLayer`, neither of which is
  validated anywhere except at call time.
- `UtilsMath.smooth_step` does not clamp, so inputs outside 0..1 produce values outside 0..1.
- No unit tests cover any of these helpers (see [./tooling.md](./tooling.md)).

## 7. Related

- [../ARCHITECTURE.md](../ARCHITECTURE.md) - where these helpers sit in the runtime structure
- [../CONVENTIONS.md](../CONVENTIONS.md) - naming, `[AI-DOC]` headers, typing rules
- [./map_generation.md](./map_generation.md) - the main consumer of `UtilsMath` noise
- [./level_flow.md](./level_flow.md) - the main consumer of `UtilsScreen`
