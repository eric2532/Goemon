# Goemon terrain math

A small dependency-free Godot 4.6 GDExtension for sampled terrain corridors and wall contacts. It preserves the sampled GDScript math: float32 Vector2/Vector3 operations, double triangle interpolation and tolerances, covered terrain, eight disk offsets, trees, map bounds, five road offsets, and original wall contact checks. It does not handle custom rampart pieces; the caller must use the GDScript fallback for those.

The extension exposes `GoemonTerrainMath : RefCounted`:

- `configure_field(width, spacing, heights: PackedFloat32Array, covered: PackedByteArray)`
- `set_domain(origin, minimum: Vector2, maximum: Vector2, rect_bounds: bool)`
- `set_obstacles(trees: PackedVector2Array, roads: PackedVector2Array, walls: PackedVector3Array)`
- `sample(from: Vector3, to: Vector3, radius, spacing, horizontal: bool, on_road: bool) -> PackedVector3Array`
- `walls_clear(points: PackedVector3Array, radius) -> bool`
- `probe(points: PackedVector3Array, radii: PackedFloat64Array) -> PackedFloat64Array`

`probe` returns interleaved full precision ground heights and point-clearance flags.
Corpse presentation uses one batch per rendered frame, with the same disk, tree,
building and exclusive map-edge checks as GDScript. Authored ramparts and custom
terrain retain their original sampler. Unequal arrays return an empty result;
invalid points/radii return a NaN height and a false clearance flag.

Trees are world-space X/Z centers. Roads are integer grid cells represented by Vector2. Walls are alternating first/last Vector3 corners with first.y at the foundation height. `sample` excludes the starting point, includes the destination, returns at least one point for a valid zero-length path, and returns an empty array for an unsupported corridor. Walls remain a separate live check.

The default domain retains the original `+240` coordinate offset and inclusive `[-243,237]` clearance limits. `set_domain` supports scaled Blood Gulch fields without translating query points. With `rect_bounds=true`, clearance matches `Rect2.grow(-radius).has_point`, including float32 rounding and the exclusive upper edge. Exact Kai and Blood Gulch scripts can use the native sampler; custom terrain subclasses or authored rampart pieces retain GDScript sampling.

## Build

On macOS with the Xcode Command Line Tools installed, run `./build.sh`. The script compiles an ad-hoc signed universal arm64/x86_64 dylib at `bin/libgoemon_terrain_math.macos.universal.dylib`, with `-O3 -ffp-contract=off -fno-fast-math`. The extension uses the C ABI header dumped by Godot 4.6.1; it needs neither godot-cpp nor a third-party download. Standard float32 Godot builds on 64-bit macOS are supported. The library selectors require Godot’s `single` feature, so double-precision builds use the script fallback. See the [Godot GDExtension feature selector documentation](https://docs.godotengine.org/en/stable/engine_details/engine_api/gdextension/gdextension_file.html).

Godot discovers `terrain_math.gdextension` on editor import. Before import, the caller can explicitly run `GDExtensionManager.load_extension("res://native/terrain_math/terrain_math.gdextension")` and then `ClassDB.instantiate("GoemonTerrainMath")`. Keep the GDScript fallback when the class is unavailable or the platform is not macOS.

## Headless smoke checks

Player and borrowed-skill candidate queries use
`GoemonCrowdRuntime.ordered_enemy_candidates(bounds, actors, source, extras)`.
It joins pending simulation, queries the existing native spatial grid, rejects
freed/queued owned proxies and projects candidates into the caller's current
source order. It retains no scene objects or cached query/order state. Exact
contacts, cover, hit history and damage remain in the existing combat owner.
Unknown/custom populations keep the script's conservative source-list path.
`army_candidate_marshalling_test.gd` checks this transfer, and
`army_rigid_sweep_test.gd` compares the rigid-proxy fast path against the original
prepared contact solver, including exact hit times and points.

From the project root:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://native/terrain_math/smoke.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://native/terrain_math/numeric_smoke.gd
```

The first verifies method registration, zero-length/flat samples, trees, roads, and wall decisions. The second compares every Vector3 component for 1,000 seeded sampled paths on a triangulated field against the GDScript arithmetic, using horizontal and full 3D sampling. These are math checks, not graphics or gameplay performance benchmarks.
