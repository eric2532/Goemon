# Task 2 — Approved Forest enemy crowd

Implemented, uncommitted. Other-mode `scripts/enemy_crowd.gd` and its shader are unchanged.

Files:

- `scripts/forest/forest_enemy_crowd.gd`
- `assets/materials/forest_enemy_crowd.gdshader`
- `tests/forest-shrine/enemy_visual_test.gd`
- `tests/forest-shrine/enemy_visual_tour.gd`

Four shared ArrayMeshes/MultiMeshes retain all 42 original material surfaces, all seven painted texture surfaces, source UVs, smooth normals, original albedo colors, roughness/metallicity/emission and approved world heights (4.62/4.455/23.10/5.115 m). Original GLBs remain unchanged. A model is imported only during one-time shared mesh setup; actors retain hidden empty HeroModel crowd proxies, without imported per-actor mesh trees. Roles owns asset paths, dimensions, speeds and gait strides.

`ForestEnemyCrowd.part_pose(group,data)` is the common transform source for rendering and fitted combat. Rigid named pieces encode their group in UV2, and each species has one small floating-point pose texture containing seven affine transforms per actor. Rendering and contact therefore do not reproduce independent animation formulas. Giant feet use alternating stance and swing; stance offsets cancel world root travel exactly at .75 m/s with a 3 m, four-second gait cycle. Body rocking is restrained. The right fist reaches the authoritative local strike point at completed windup and first recovery frame. Its reference visible surface is `(10.637,6.0,-4.20)`, chosen to keep the fist clear of terrain at a 3 m high building contact. Only the short connecting arm stretches; painted fists retain rigid geometry. Archer arms draw the bow locally, independent of its distant target. Lantern uses its authored single-legged gait.

Frozen pose snapshots, including motion and attack progress, remain unchanged; pause skips updates. Cached poses continue updating while actors are hidden, so revealing an already frozen actor preserves the last physical pose. Fog hides actors and shared instances, keeps legacy models hidden, and marks distance_asleep. Death collapses the shared instance over the existing .65 s actor cleanup period; clear() removes instances and cached poses, and vanished actors have their cache entries pruned.

Verification:

- RED: renderer absent; the initial visual test reported the missing dedicated renderer.
- GREEN: `godot --headless --path . --script tests/forest-shrine/enemy_visual_test.gd` → **160 checks, zero failures**, final run 2026-10-14.
- Off-origin camera regression RED→GREEN: per-species custom AABB now unions visible instance transforms with animation-expanded source bounds, preventing a giant at z70 from being culled by a box around origin0. `godot --path . --script tests/forest-shrine/enemy_contact_test.gd -- --contact-fast --visual` → **17 checks, zero failures**, native process exited0; `visuals/giant_off_origin_contact.png` visibly shows lower body/fists/feet in the actual main game camera.
- Additional RED→GREEN cases: Archer's arm cannot reach its distant ranged target; stopped giant settles its feet; giant strike stays above terrain; reveal during freeze retains the last simulated pose.
- CPU/texture contact consistency, full dimensions, painted materials/UVs, bounded batching for 80 actors, legacy proxy scale immunity, pause/freeze, exact planted stance, exact strike contact, fog, wave cleanup and death presentation all have focused checks.
- `godot --path . --script tests/forest-shrine/enemy_visual_tour.gd` → native Metal Forward+ process exited 0, no shader/script errors. Front/side/back, heavy walking, windup/contact and Archer bow draw were saved and visually inspected.
- Native Apple M3 stress: 200 actors including 50 giants, four shared MultiMeshes, **129 draw calls including material surfaces/shadow cascades**, renderer CPU update mean **4.061 ms**, maximum **5.225 ms** over 60 updates. This measures the isolated renderer, not whole-game frame time.

Native visual artifacts live under this workspace's `visuals/`:

- `small_front.png`, `small_side.png`, `small_back.png`
- `giant_front.png`, `giant_side.png`, `giant_back.png`
- `giant_walk_left.png`, `giant_walk_right.png`
- `giant_windup.png`, `giant_contact.png`
- `archer_bow_draw.png`, `giant_off_origin_contact.png`
- `daruma_walk.gif`: 24 deterministic native frames with 3 m root travel, played as a four-second .75 m/s stride; original frames `walk_00.png`…`walk_23.png`.

Implementation assumptions / rulings:

- Texture transforms replace the proposed COLOR-encoded pivots because the same exact affine transforms must serve fitted collisions and target contact. UV2 still stores rigid group membership. This avoids per-actor shader materials and per-actor scene trees.
- Godot's headless dummy renderer does not reliably return updated GPU MultiMesh/ImageTexture contents. Headless tests assert the actual cached poses and uploaded Image plus pure transform helpers; native screenshots separately validate shader/GPU output.
- Source models have no skinning, normal-map textures or alpha-cutout facial materials; shader conversion retains their authored material properties. Imported rock facets are authored geometry, while painted shell/skull surfaces retain smooth normals.
- The standalone tour uses deterministic role data. Root's integration/native tour remains responsible for actual game navigation, arrow presentation, five-wave completion and export.
