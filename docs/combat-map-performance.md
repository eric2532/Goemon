# Expanded-map combat performance

The four-sided fortress exposed two CPU costs that grew with the map and enemy population. Each continuous terrain height query scanned all 20 raised segments, even for distant walls. Separately, every ready tower calculated a fitted contact point for every enemy, including those far beyond 48m.

Terrain configuration now builds a 12m spatial index of candidate segments. Height queries retain the same interpolation, overlap maximum and .001m edge tolerance; the index only excludes distant segments. Exact per-tick enemy bounds are shared across towers. A conservative distance lower bound rejects impossible candidates before the original fitted hit-point/range/visibility ranking runs. Bounds are discarded each workforce tick, preserving live movement, recoil, frozen poses and deaths.

In the same native Metal painterly scene on this machine, 96 advancing enemies improved from 27.076ms median / 29.010ms p95 to 16.665ms median / 16.949ms p95 (about 37 to 60 FPS). Simulation fell from 19.930ms to 5.995ms; draw count stayed 5626. These are controlled local results, not a guarantee for every combat scene or machine. Cold portal guidance fell from approximately 21ms to 6ms in the model probe.

Reproduce scene measurements with:

```sh
godot --path . --always-on-top --script tests/forest-shrine/combat_map_profile.gd -- --painterly-preview --out=/tmp/combat-map-profile.json
```

`rampart_sampling_test.gd` compares the continuous surface against an exhaustive reference, including negative coordinates, edges, overlaps and reconfiguration, and checks local sampling scaling. `tower_target_broadphase_test.gd` compares exact target choices in 270 combinations of range, facing and pose, plus the cost of one versus eight idle towers. The measurements above used the sixteen-gate layout. The current map has one gate per side (four total) and eight portals; both CPU optimizations remain active, with combat stats, characters and rendering quality preserved.

Before/after profiles and app backups are recorded under `build/Other Files/combat-lag-20261018/` in the main checkout.
