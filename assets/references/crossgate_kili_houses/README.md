# Original Kili house maps

The four local Blue CG cache gaps (3801, 3802, 3803, 3807) are recovered from
[the Cross Gate server archive](https://github.com/awafer/crossgate/tree/6e5794f591ae40838e86d3229e4d930c7ce297b4/gmsv/data/map).
`provenance.json` pins the revision, Git blob identities and SHA-256 hashes.
Only map data was downloaded; no archived programs were run.

Control maps 3220 and 3221 match the local Blue CG client maps in all 400 ground
and 400 object cells each. This supports using the missing server maps, but is
not an independent capture of the four houses from the current Blue CG service.
Do not describe that remaining version uncertainty as verified parity.

LS2MAP has a six-byte magic, big-endian 16-bit map ID, a 32-byte name, big-endian
16-bit width/height, then ground and object planes (big-endian 16-bit entries).
All six maps are 20 by 20. The original door coordinates are cross-checked with
the warp/NPC archive in Magic Power. There are no archived indoor NPC placements
for these four houses; other village NPCs remain unchanged and silent.

`tools/build_freyja_destinations.py` reads these maps directly and regenerates
the room walk masks and links. `tools/build_falan_room_art.py` regenerates legacy
floor/wall metadata. `tools/build_coastal_villages.py` emits complete source
placements, source-palette paint and floors. Run from the project root:

```sh
python3 tools/build_falan_approaches.py '../Magic Power'
python3 tools/build_falan_room_art.py '../Magic Power' assets/maps/falan
python3 tools/build_undersea_details.py '../Magic Power'
python3 -m unittest discover -s tests/asset-toolkit -p 'test_kili_houses.py'
```

The undersea exporter also calls the coastal exporter and refreshes the blue
palette atlas against the changed shared tile indexes.

Use Play Goemon with `--script res://tests/forest-shrine/freyja_villages_habaru_test.gd
-- --coastal-kili` for rendered room/door checks, and `-- --freyja-scale
--gate-exteriors` for all three Falan crossings. Source previews, comparison
evidence and logs belong under `build/Other Files/BlueCG Map Study/Kili Original
Houses/`. Do not rewrite the existing saved venture or export another app.

The 3D furniture masters reuse the shared procedural primitives in
`scripts/forest/forest_coastal_rooms.gd`; original placements and floor plans are
preserved, while depth and hidden faces remain 3D interpretations of 2D art.
