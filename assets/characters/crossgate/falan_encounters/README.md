# Recovered-map wild creatures

This prepared derivative extends the original five Falan patrol skins to the
29 creatures referenced on the recovered Freyja/Sokia regions and Great Wind
Cave. `../falan_frontier/` remains intact. The first five IDs, original pixels,
proportions and audio/contact clocks are preserved. Other source sprites keep
all eight directions, including their recovered guard poses. World creatures
use the existing native SLIME role, patrol owner,
combat, queries, geometry table, pooled audio and spatial sprite batches.

Species/source keys and relative heights are in
`assets/maps/falan/frontier_species.json`. Encounter rectangles, source hashes
and the pinned CGMSV reference are in `map_encounter_provenance.json` alongside
it. That reference is not verified BlueCG server placement data. Exact posts,
counts and combat stats are Goemon adaptations. Existing five-species balance
remains; added species use the existing 3,000 HP / 30 damage patrol baseline
with the shared area progression. Towns, safe gate approaches and source rooms
without encounter records receive no invented hostile population.

From the project root, rebuild placements with:

```
python3 tools/build_map_encounters.py 'build/Other Files/Asset Toolkit/Map Encounters/Source' '../Magic Power'
python3 tools/recover_habaru_encounter.py '../Magic Power' --frontier
```

The first command needs `encount.txt`, `group.txt`, `enemy.txt` and
`enemybase.txt` from the pinned revision recorded in provenance. It samples
existing recovered surface masks and open floor cells, without editing them.
The runtime rechecks native scenery clearance and keeps bandits 39 m from roads.
All setup uses cached tables; no new species controller or simulation is added.
The native 240-enemy adventure cap remains. Great Wind deaths use run-scoped
slain slots; sea passages reuse the existing undersea slots and original art.

The derivative uses the native 32-value contact row, allowing the cold tree's
14 original sound/contact cues without dropping markers. Other historical cave
assets retain their 28-value prepared rows and existing expansion adapter.
The atlas has 49 indexed 1024×1024 pages, about 49 MiB of raw GPU index pixels
when loaded, plus lookup/palette data. It is shared across regions and loaded
at setup, not during attacks. Future additions should reuse this owner and
prepared source data; do not silently discard source cues to fit a short row.

Run `map_encounters_test.gd -- --east-il-road` through Play Goemon for actual
clear placements, source-region membership, native skins, repeated damage and
cave return persistence. Captures and logs live under
`build/Other Files/Asset Toolkit/Map Encounters/`. Technical checks and rendered
review are separate; these checks do not establish whole-game smoothness.
