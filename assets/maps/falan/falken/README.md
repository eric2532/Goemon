# 法爾肯 and the sixteen-floor 羅連斯研究塔

Use **Play Goemon**. From 其利村's east gate, cross 轟恩大風穴 and follow
法爾肯之路. The source-backed night entry actors are at Sokia **(579,275)**,
**(514,337)** and **(593,332)**, arriving on3300 at **(20,28)**. The old540,350
guide/entry is removed; that point remains only for compatibility with the
existing reward/return owner. Original roaming/time selection and those legacy
return anchors are not certified. See the Sokia regional ledger for provenance
and the three night-entry/day-refusal movement checks. Beyond the entry, the
existing playable quest route is:

沒落的村莊 → (40,39) 連接時空的房間 → (12,10) 時空石盤 →
勇者里雍 (21,18), receive 解咒之法 → 反抗軍 (35,21) →
帝都地下 (23003), entrance (42,21) → 羅連斯研究塔 1–16樓 →
original top exit (23,45) → 巫師耶卡 (25,27) → 法爾肯 →
liberated palace (23002) → temporal stone (37,11) → Sokia.

The previous capital-to-boss shortcut is removed. Every tower floor has both
return and onward stairs. The rebel warns if the scroll is missing; Yeka checks
it before opening the barrier. Victory opens the original reward room and exit.
Starting a fresh saved adventure clears Falken's per-run kills and quest flag.

## Source and 3D scenery

`tools/recover_falken_route.py` recovers the six fixed original maps 3300, 3301,
23000, 23001, 23002 and 23003. Their unchanged navigation grids, original paint
and remaining scenery anchors are recorded in `data.gd` and `provenance.json`.
312 native graphics supply the scenery. The pinned server configuration and
boss AI/tech rows are in `assets/references/falken/original.json`.

The original dungeon 302 contract specifies **16 floors**, 40–80 tile dimensions,
floor **3256**, wall **15827**, stairs **12000/12002** and level **22–25** monsters.
Runtime identities 30201–30216 stay independent of original cache filenames.
Each floor has seeded rooms and a connected maze. Direction, size, room and
species choices use seeded shuffle bags. Layouts repeat for the same run seed
and vary between seeds. Only one cached layout per floor is retained.

Existing room meshes build native stone floors and solid walls. Existing stone
stair/ramp geometry builds both original stair forms, using opaque stone patches
from the original stair paint rather than its transparent background. Gold
cornice graphics 17360–17369 now use 3D walls; pedestal 16328 reuses the existing
round-piece and source-projected mesh builders for a solid base and four finials.
Fitted boundary walls use native masonry; the old wood skirting is omitted.
Smaller distinctive props and original NPCs retain original-art cards.

The environment detail pass samples the original projected wall luminance into
a 4×24 relief grid, recessed at most 0.12 m inside each unchanged wall footprint.
The depth is fitted; the pixels and mortar pattern come from the source. Equal
neighboring walls omit their hidden faces. All visible faces still share one
static room mesh. Wall tops sample the source's first eight opaque rows, with
one cached material/texture per distinct color. These replace the old generic
brown caps. The sixteen floors and top chamber use a dark cutaway backdrop;
travel to another room or the desert restores that area's backdrop.

Single-sided native masonry/cornice pieces now reflect their intact original
face onto the unseen reverse, replacing the generic beige projection padding.
Empty original blocking graphic 17644 stays invisible. Gold panels use the
matching 92-pixel unshadowed source height instead of counting a cast shadow as
wall height. Original carved columns 17361/17363/17365/17368/17369 in the fixed
capital/reward maps reuse source-projected round shafts, stepped caps and rail
arms, with their original anchors; they no longer become full wall cubes.
Their unseen depth and profiles are fitted, not recovered original 3D models.

The boss chamber has a distinct 3D waterworks treatment in
`scripts/forest/forest_falken_chamber.gd`. The room builder uses the existing
water tile footprint for one recessed teal surface. Shore flags keep the
shader's lighter waterline at the actual banks, and the coping blocks follow
the perimeter. Flush pavers mark the two existing walkable crossings.
The teal water motion is authored in
`scripts/forest/forest_falken_channel.gdshader`.

The same chamber script assembles the pair of bronze-braced iron gates, four
stone plinths and low sluice covers from reusable solid parts. Gate positions
and blocked tiles come from the current map, and the quest still owns access
to the fight. The environment harness captures the chamber, gates and water
under `build/Other Files/Asset Toolkit/Falken Chamber/`.

`scripts/forest/forest_falken_chamber_props.gd` builds the boss chamber's
original stone arches, decorated piers and double-sided channel emblems. Both
arches span the three open corridor cells, with jambs set into the sides.
The outer boundary uses world-projected masonry so long walls have consistent
stone sizes. Solid urns, lighting, cabinets, desks and displays reuse the
project's existing furniture parts. In total, 69 scenery placements share
15 prepared meshes. The chamber still uses the same collision and route data.
Close views are captured under `build/Other Files/Asset Toolkit/Falken Stonework/`.

The chamber's raised platform and paving are authored in
`scripts/forest/forest_falken_dais.gd` and `forest_falken_paving.gdshader`.
The shallow approaches use the same corner heights and triangle split for the
arena mesh, player collision, spawn placement and native movement. Keep those
in sync if changing the height or footprint. The new paving uses staggered
slate, limestone, bronze lines and a water emblem. Four amber lights mark the
candles, and two cool lights pick out the channels. These lights have no
shadow maps. The next room restores its lighting when you travel.

Use the environment harness to review the approach and inlay captures in
`build/Other Files/Asset Toolkit/Falken Dais/`. Its baseline comparison checks
the pre-existing colliders separately from the new platform collider. The
full route harness also exercises spells, summons and the victory exit with
the raised platform in place.

Both stairs now assemble the existing rounded-block primitive into individual
stone treads, staggered joints and segmented shaft rims. Two prepared meshes
are shared across all sixteen floors; source stone patches use the existing
world-projected paint shader. The original walkable ramps, origins, widths and
visual extents remain intact. A reversed cap winding in the shared rounded-block
helper was corrected; its existing Falan desks and chair seats also keep solid
top faces. Original assets and other cave stair styles remain preserved.

## Monsters and boss spells

The corrected source actors are **101531 法爾肯**, **101110 骷髏戰士** and
**101701 蜥蜴鬥士**. Regenerate them with:

```
python3 tools/recover_habaru_encounter.py '../Magic Power' --falken
python3 tools/recover_falken_spells.py
python3 tools/recover_falken_route.py
```

Each random floor has **84 native monsters** in connected rooms, outside the
stairs. Setup is bounded; repeat ticks do not duplicate them. The boss chamber
uses level-35 escorts and the project's level-50 real-time boss scaling
(60,000 HP). Other recovered maps keep their existing population and combat.

Falken's native spell kit includes **聖盾、攻擊反彈、魔法反彈、吸血魔法、
強力恢復魔法、即死魔法E1 and 召喚**. Shared native ward and recovery code,
indexed sprites, pools, exact damage, targets and lifecycle remain authoritative.
There is no separate boss simulation or targeting loop.

AI 11037 supplies relative weights. A compact per-boss bit bag draws without
replacement, filtering recovery to below half HP, summoning to an empty escort
line and instant death to a present escort line. Instant death has **one success
per ten attempts** in its shuffled bag, from source `SR:10`. Summoning restores
exactly five skeletons or five lizards and draws both families before refilling.
Duplicate callbacks cannot add another group. Life drain uses source 245 damage
and heals only confirmed damage, preserving invulnerability and spell immunity.
The original ward, recovery and level-five drain sheets/audio are reused;
`recover_falken_spells.py --check` verifies their source hashes.
Level-five drain now honors the original `targetAlpha: 128` (128/255) instead
of the generic 70% effect opacity, including the existing reduced-flash option.

## Verification and remaining limits

Run through Play Goemon:

```
--script res://tests/forest-shrine/falken_route_test.gd -- --east-il-road
```

The preceding tower/spell pass passed **1,598 rendered assertions**, including every floor,
all connecting passages, seeded regeneration, monster levels/placement,
nonduplicating populations, actual casts, summoning, victory and return travel.
The shared map-monster regression passed **4,808 assertions**. Native Falken
spell tests passed exact reflection, confirmed drain, recovery, Holy Shield,
conditional AI, ten-attempt death bags and both summon families. Ruby's native
spell regression passed **149 checks**. Source regeneration and shared asset
checks passed; the audit read **319 GLBs without read errors**. Evidence and
final captures are under `build/Other Files/Asset Toolkit/Falken Tower/`.

For the environment pass, use:

```
--script res://tests/forest-shrine/falken_environment_test.gd -- --east-il-road
```

The matched baseline and final environment captures/metrics are under
`build/Other Files/Asset Toolkit/Falken Environment/`. The focused check visits
all sixteen floors, verifies seeded variation/connectivity and 84 monsters each,
compares player collision shapes, native navigation plans and travel links with
the pre-edit baseline, and checks shared geometry, outward faces, stair bounds,
backdrop restoration and repeated simultaneous drain contacts. A baseline is
captured before edits by adding `--environment-before`; absent a baseline file,
the self-contained geometry/population checks still run.

Fresh environment verification passed **524 rendered assertions**. Source
regeneration, spell-source verification and shared asset/source/audio checks
passed. The audit read **319 GLBs with no read errors**; existing category budget
warnings were reviewed without deleting or decimating assets. The saved
adventure hash remains unchanged. The previous full tower/boss checks above
were not rerun for this visual pass.

The tower wall mesh is 146,688–281,088 triangles per loaded floor, one surface;
the top chamber is 114,432. This is increased static geometry, not a measured
speed improvement. No monsters or scenery quality were reduced for validation.

These are closer source-guided reconstructions, not completed 1:1 original 3D.
The original maze generator is unavailable: room geometry, unseen surfaces and
real-time turn cadence remain fitted. Instant death's unique target artwork is
unverified; it uses the original common cast and the victim's death gesture.
Night/神眼 restrictions and the original food confiscation remain bypassed;
no existing player inventory is deleted. Skill-book learning is not implemented.
The original quest references are [蔚藍幻境](https://cg.skyey.tw/errand/mabb03.htm)
and the pinned server data above. No app export, long-session stress test or
rendered frame-time benchmark was performed.
