# Fire Siege — Arrow Tower v1

Actual editable Blender geometry inspired by the approved Japanese-style tower concept. This package contains a level-1 arrow tower, discrete construction stages, a reversible build preview, a recoil/arrow launch preview, a standalone arrow projectile, and an optional wall-top mounting collar. It does not contain game code or an engine-integrated scene.

## Open the model

- Open `firesiege_arrow_tower_v1.blend` in Blender 4.3.2 or newer
- The default scene is `02_BUILD_RECOIL_REVERSE_PREVIEW`, initially at completed frame 72
- In the Scene selector, `STAGE_00_EMPTY_BASE`, `STAGE_10_FRAME`, `STAGE_20_ASSEMBLING`, and `STAGE_30_COMPLETE` each contain an independent, editable construction-state collection
- `TOWER_CANONICAL_PARTS` holds the animated asset. `OPTIONAL_WALL_MOUNT` is hidden by default; enable it only for wall placement
- `PREVIEW_ONLY` holds the floor, lights, and camera; these are excluded from GLBs

Meshes remain individually editable. Bevel and weighted-normal modifiers remain live in the blend and are evaluated in glTF exports. Materials are native Principled BSDF colors; there are no external textures or texture dependencies.

## Exports

| File | Purpose | Mesh nodes |
|---|---|---:|
| `exports/tower_stage_empty.glb` | Site's empty foundation/base | 15 |
| `exports/tower_stage_frame.glb` | Timber frame | 51 |
| `exports/tower_stage_assembling.glb` | Rails, launcher, roof frame | 105 |
| `exports/tower_stage_complete.glb` | Finished arrow tower | 170 |
| `exports/tower_wall_mount.glb` | Detachable wall-top collar | 10 |
| `exports/arrow_projectile.glb` | Reusable arrow, pivot at tip | 5 |
| `exports/tower_build_recoil_reverse.glb` | Animated 170-part tower | 170 |

Exported meshes retain names, `stable_id`, and `stage_min` metadata. Stable IDs are `firesiege.tower.<part_name>`. Use the supplied JSON manifest for the complete list. These objects are intentionally separated for construction; an engine can merge static meshes after completion if needed. Full tower is approximately 20,052 evaluated triangles. No LOD, collider, navigation obstacle, damage hitbox, or occlusion mesh is supplied.

## Dimensions and axes

- One Blender unit is one meter
- Blender: +Z up, front/fire direction -Y; ground-center root at `(0,0,0)`
- glTF: +Y up, front/fire direction +Z after Blender's standard export conversion
- Core foundation: 2.8 m wide × 2.75 m deep, within a nominal 2.8 m square site
- Full bounds including roof and loaded arrow: 3.550 × 3.425 × 3.785 m
- Blender bounds: min `(-1.775,-1.720,0)`; max `(1.775,1.705,3.785)`
- Godot importer: do not apply another Z-up conversion. If a gameplay parent uses -Z as forward, rotate its imported visual child by 180° about Y. The axis and muzzle coordinates were verified by isolated Godot 4.6.3 import; this is not game integration

Keep the root at the site origin. On ground, the included stone feet touch Z=0. On a wall, remove/hide the four `stone_foot_*` parts, place tower root at the wall-top center, and attach `tower_wall_mount.glb` at the same origin. The collar reaches down 0.62 m below wall top. It is designed around a 0.6–1.0 m wall thickness and may be scaled laterally to the actual wall. No wall geometry is bundled.

## Nodes and sockets

- `TOWER_ROOT`: ground-center asset parent
- `LAUNCHER_YAW`: aiming/upgrade parent; pivot Blender `(0,-0.05,0.59)`
- `LAUNCHER_RECOIL`: recoil transform parent
- `ARROW_PROJECTILE`: loaded/preview arrow parent; each arrow mesh remains separate
- `SOCKET_ARROW_MUZZLE`: Blender world `(0,-1.73,1.86)`; glTF `(0,1.86,1.73)` before root rotation
- `SOCKET_BUILD_FX`: Blender `(0,0,3.90)`; attach independently supplied construction UI/effects

The launcher pivot parents all launcher geometry, the recoil group, the arrow, and the muzzle socket. The 3D arrow is visual-only; spawn/ownership, damage, collision and lifetime belong to gameplay implementation.

### Standalone arrow

`exports/arrow_projectile.glb` and the native Blender scene `03_ARROW_PROJECTILE` contain `ARROW_PROJECTILE_ROOT`, `SOCKET_ARROW_TIP`, and five meshes: head, shaft, and three fletchings. The runtime arrow GLB contains only its one scene, seven nodes and five mesh definitions; unused tower data has been removed and its tip/shape reverified in Godot. Both root and tip are at `(0,0,0)`. The origin is the leading tip, not the center. Blender front is -Y; glTF/Godot front is +Z. Godot bounds are X ±0.12, Y ±0.077942, Z -2.28..0 m. Thus the bolt is 2.28 m long and extends behind its tip. This is a deliberately readable tower bolt, not a character-scale arrow.

Spawn a new standalone arrow under a world/projectile container and copy the muzzle socket global transform. Use the socket global +Z basis as travel direction after any visual-root or launcher yaw rotation. Do not leave the flying arrow parented to the launcher: future aiming would bend its flight path. Hide the tower’s embedded `ARROW_PROJECTILE` after launch and show it at the chosen reload time; that embedded group belongs to the demonstration/reload visual. Actual trajectory, speed and collision response are unresolved gameplay decisions.

## Animation contract

The animated GLB has ONE merged clip named `Tower_Build_Recoil_Reverse`, containing 313 translation/scale channels. Blender timeline is 24 FPS.

| Frames | Meaning |
|---|---|
| 1–72 | Empty foundation to complete tower |
| 79–91 | Recoil and arrow launch |
| 92–108 | Reload/settle hold |
| 109–180 | Reversed construction demonstration |

The GLB sampler times were explicitly normalized and tested in Godot: the clip begins at time zero and ends at `179/24` seconds. Import animations at **24 FPS**. Godot’s default 30 FPS baking/resampling softens the short construction and recoil endpoints; the verified exact-seek contract uses 24 FPS. For a continuous gameplay build progress `p` in `[0,1]`, seek the first segment at `t = p × 71/24` seconds. A falling `p` reverses the same build appearance; resuming advances from the remaining value. The reverse segment is provided as a preview, not a separate required gameplay state. Parts use tiny positive scale (0.001) when hidden for portable glTF playback; collision must be disabled by gameplay when a part is not constructed.

### Seeking pseudocode (documentation only)

```gdscript
# Import the animated GLB at 24 FPS. This is usage pseudocode, not game code.
const CLIP = "Tower_Build_Recoil_Reverse"
const BUILD_END = 71.0 / 24.0

# Initialize while the visual is hidden, then reveal it after the first seek.
player.play(CLIP)
player.pause()  # Progress owns the pose; do not let the whole preview auto-run.
player.seek(clampf(progress, 0.0, 1.0) * BUILD_END, true)

# Release/decay: lower progress, then seek the same build segment.
# Resume: increase the remaining progress, then seek again.
# Independent reverse-preview mapping (optional):
reverse_time = 108.0 / 24.0 + (1.0 - progress) * BUILD_END

# Spawn visual projectile under an independent world container.
# The actual game must add movement, collision, ownership and lifetime.
world_projectiles.add_child(new_arrow_instance)
new_arrow_instance.global_transform = muzzle.global_transform
flight_direction = muzzle.global_transform.basis.z.normalized()
```

Exact clip segments in seconds: build 0..2.958333; complete/hold until 3.25; recoil starts 3.25; arrow release 3.333333; recoil peak 3.375; arrow reaches preview displacement +5 m at 3.75; reload through 4.041667; reverse construction 4.5..7.458333. For gameplay, slice or drive the recoil locally rather than autoplaying the full build/reverse clip for every shot. Do not derive game fire rate or arrow velocity from this demonstration.

These durations are presentation timings only. Build speed and decay speed remain unresolved. Confirmed level-1 gameplay fires once every 0.5 seconds (2 shots/sec) for 50 damage per arrow; the illustrative animation timing is unchanged. The video shows the same 3D model/timeline rendered with Blender Workbench studio lighting, not generated illustration.

## Gameplay context to preserve

Initial gameplay starts with zero built towers. There are 4 front-wall sites and 8 entrance sites. Hold B builds; release decays progress; resuming continues from remaining progress. Spend 5 gold only on completion. Enemies have 100 HP. Level-1 arrows deal 50 damage and fire once every 0.5 seconds (2 shots/sec). Each built tower also requires time-based gold drain during combat; the drain rate and behavior when the wallet reaches zero remain unresolved. No numeric drain rate is assumed. These values are documentation only; the package does not implement them. Cannon upgrade tier count remains unresolved, and no fixed cannon tier or cannon prototype is included.

## Verification

`verification_report.json` records fresh imports of every supplied GLB into an empty Blender 4.3.2 scene. Checks passed for binary glTF structure, geometry bounds, mesh counts, unique stable IDs, merged animation channels, construction/reversal endpoint visibility, and projectile travel. All seven supplied GLBs, including the standalone arrow, were checked. Front, side, quarter and stage renders were visually inspected. MP4 is H.264/yuv420p at 24 FPS, 720×820, 7.5 seconds. `godot_validation/godot_import_report.json` records isolated Godot 4.6.3 GLTFDocument scene-generation and AnimationPlayer seek tests at 24 FPS. Those tests passed for all seven imports, exact clip offset/duration, five normalized build poses, reciprocal reverse poses, out-of-order decay/resume seeks, recoil distance/direction, projectile movement/reset, axis-converted bounds, muzzle position, and standalone arrow tip origin. Godot retains unique mesh/node names but does not automatically expose arbitrary `stable_id` extras as node metadata; use the manifest mapping by retained name. No actual game project was edited, and no gameplay, Godot rendered appearance, performance or collision behavior was tested.

## Rebuilding

The generation scripts are included for reproducibility, not game code. Run `scripts/build_tower.py` with Blender, then `scripts/finalize_and_preview.py`, `scripts/normalize_gltf_time.py`, `scripts/export_standalone_arrow.py`, and `scripts/verify_tower.py`. The second step ensures current-frame static exports and a single merged glTF animation. The normalization step is idempotent and removes a possible frame-1 time offset in the exporter. The arrow step creates the separate projectile scene and GLB. The isolated Godot checker lives in `godot_validation/check_tower.gd`; run it with a writable HOME/XDG data directory if the system home is read-only. `scripts/render_preview.py` makes animation PNG frames; `scripts/render_workbench_views.py` makes the three studio views. Paths in scripts use the producing workspace and should be changed to your own output folder before reuse.
