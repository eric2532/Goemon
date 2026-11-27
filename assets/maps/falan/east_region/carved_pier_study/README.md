# Private carved-pier surface study

`inferred-masonry-albedo-v1.png` is a built-in image_gen material draft for unseen pier faces, not recovered Cross Gate art. The prompt and byte provenance are adjacent. It was prepared as a private candidate; `publication.json` records the later bounded canonical acceptance for appearance1230051 only. Preserve the generated original; any revision gets a sibling filename.

Original1230051front pixels, footprint, map placements, collision/navigation and quest behavior remain source-owned. Use an independent material at a fixed measured pitch for hidden surfaces, never stretch the complete front drawing around the model. This bitmap alone does not prove seamlessness, material scale, depth, silhouette or gameplay-camera quality.

The authoritative procedural source is `scripts/forest/forest_east_carved_pier_study.gd`; it may reuse the existing closed moulding/profile pieces. The attached-rock trials are rejected and archived under `build/Other Files/Asset Toolkit/East Gate Region/Mouse Room Piers/`. No shared stone shader changes are needed. Future whole-family publication requires the full source census and actual room/camera/native checks.

Appearance1230051 now uses dispatch group24 for178 original placements in ten fixed maps. Canonical review passes44 checks with all six33608 instances and both reachable camera views; the independent native-axis image is diagnostic only. The other four carved variants and surrounding room art remain unfinished. Original paint is retained at its native resolution.

Prepare the lossless inferred CPU Image with `Play Goemon.command --headless --script res://tools/prepare_east_carved_pier_masonry.gd`; add `-- --check` to verify it. The original atlas CPU page uses `tools/prepare_sokia_server_cpu_pages.gd` with pages=east/atlas-13.png and output=east/carved-cpu-pages. Runtime loads prepared resources at first appearance setup, shares one mesh/material, and never reads a raw PNG for relief. The shared stone shader is unchanged.
