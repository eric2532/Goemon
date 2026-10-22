# Enlarged Tidefall town and colored Edo V05

Local integration on `feat/original-enemies-town-cap`, base `32c02225e8ec9924d770de53c3df6237cb426cc2`. No push or merge.

The main Tidefall area now has **48 buildings**, up from 24. Every town building is **4× its previous linear scale**: the 8×6m source footprint becomes 32×24m (24×32m after the layout yaw), with 16× floor area. Larger lots and streets keep the original routes, spawn, courts and outposts open. Other regions are unchanged. Existing original building assets are reused.

Three houses use the new original Blender open-house kit, with a real timber floor, three solid walls, split front facade, a 12m clear doorway, tables, benches, a counter, and lanterns. The same simple interior kit serves all three. Walk straight in or out; no loading transition or interaction key is required. The other 45 houses are closed and have solid collision.

| Interior | Center (x,z) | Door center (x,z) | Direction |
| --- | --- | --- | --- |
| Tea House | -40,35 | -28,35 | East |
| Travelers' Hall | -116,14 | -104,14 | East |
| Merchant House | 62,18 | 50,18 | West |

Only these three lots and their 6m transition margins are leveled to avoid foundations blocking entry. Old foliage/rock dressing is cleared inside building footprints. Closed buildings use solid hulls and roof collision; interiors use the exported mesh collision, without a filled interior hull. Three static lights have shadows disabled.

The native source is `assets/blender/town/open_teahouse.blend`; its export has 718 triangles, two meshes and six surfaces. `tools/build_open_teahouse.py` uses the existing original town authoring/export pipeline and refuses to overwrite an existing source.

## Validation

**165 checks passed** in final validation: town 48, colored V05 rig/material/animation 26, combined gameplay 7, original Edo fallback 7, firecaster 49, direct attacks 28. The town suite physically walks the player into and out of each interior twice, follows actual enemies through each door, and checks 36 nearby enemy spawn samples. Floors, walls, closed houses, all roofs, original and outer routes, court approaches, all nine outposts, terrain outside entrance lots, RNG, cap 200, and camera clearance are covered. Existing Storm Court center is not a valid enemy ground cell; its approach 4.4m away remains reachable. No crowd stress test was run on the Mac.

```sh
Godot --headless --path . --script res://tests/tidefall-town-expanded/checks.gd
Godot --path . --script res://tests/tidefall-town-expanded/review.gd
```

The earlier 24-building comparison checks are historical; the expanded suite above covers the requested changed layout and interiors. Native screenshots and placement inventory are saved beside this report.

- [Town overview](overview.png)
- [Normal spawn camera](spawn.png)
- [Open doorway](doorway.png)
- [Lit interior](interior-wide.png)
- [Colored Edo face in native rendering](edo-face.png)

Edo uses the untouched V05 geometry and rig from `9299c3532e5a6f6d341defb0ea0f92277a975e16`, the established V01 crimson/black/skin/trim palette, and stationary relaxed idle. Original model fallback remains `-- --edo-original`. See [Edo integration details](../edo-v05-integration/README.md).
