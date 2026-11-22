# Black Prayer source evidence

`dungeonconf-row.tsv` is the exact UTF-8 decoded 黑色的祈祷 row from
[`linv2/Crossgate_Docker`, commit dd8690ed3df11e4eb5a038a54079a8f40d8e93b3](https://github.com/linv2/Crossgate_Docker/blob/dd8690ed3df11e4eb5a038a54079a8f40d8e93b3/gmsv/data/dungeonconf.txt).
The original repository stores the table in GB18030. Preserve the row as evidence;
change the runtime reconstruction rather than editing the source reference.

It specifies six maze floors, dimensions 40–80, 10–20 rooms, floor graphic 9555,
up/down stairs 17974/17975, props 15011–15020, encounter table 15001 and levels
20–23. The fixed endpoints are map 16507 (14,14) and map 16508 (39,5).

The existing pinned encounter tables in `build/Other Files/Asset Toolkit/Map
Encounters/Source/` map 15001 to groups 15006/15004/15005; those groups use Ghost
101121 and Bloody Blade 101600. The [historic Black Prayer report](https://games.sina.com.cn/z/cross/diaocha/heiseqidao.shtml)
reports a slightly different wild level range (19–21), variable maze depth and
the level-50 Ruby with five level-30 Blades and four level-30 Ghosts. The runtime
uses the pinned six-floor server configuration and its 20–23 maze levels.

The sibling Magic Power resource library contains original fixed maps
`BlueCrossgate/map/0/16507.dat` and `16508.dat`, plus matching transient maze
snapshots, including `BlueCrossgate/map/1/3/80.dat` (66×62, floor 9555, wall
13792–13827, both 17974/17975 stairs). Cache filenames change; do not assume an
online player's numbered `.dat` filename identifies the same dungeon locally.
See the prepared material provenance and `docs/black-prayer-recovery.md`.


`spell-effect-factory.json` pins seven original effect-creation cases against
client memory snapshot `8babbe4ad20e4e1e2a6992ecf086d47ef3527426879699f83fa2cebb1a476afe`.
The six ward branches call skill-level lookup with protocol 55–60, independently
confirming their physical/magic Reflect/Absorb/Null resources. Kind 6 selects
rank-five Confusion 110163. Run
`python3 tests/forest-shrine/test_ruby_effect_factory.py` to re-execute the archived
bytes through the existing sibling research fixture. Allocation, geometry, video
and audio calls are inert; the existing EAX tier-initializer repair is explicitly
retained. The proof does not establish live turn scheduling or exact world-space
anchors. Original resource pixels and sound flags are compared by
`tools/recover_ruby_spells.py --check`.


`holy-shield-factory.json` separately traces Special Guard: status/result 0x400
queries skill protocol 8 and selects 110098. The control cases select ordinary
guard 110000 for bit 0x4 and ordinary hit 110133 for no guard. The same archived
branch chooses impact sound 131 or 132. `test_ruby_holy_source.py` replays both
sound endpoints across all three flags; actor fields and host submissions remain
inert. This branch does not execute the older effect-factory tier detour.
