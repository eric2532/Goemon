# Explore-mode food and sword chests

Twelve unchanged RGBA sprites from the preserved Blue CG original pack. Source
rows, dimensions and pixel/PNG hashes are in `provenance.json`. Rebuild with:

```
python3 tools/recover_crossgate_explore_loot.py '../Magic Power'
```

Regular/black/white closed chests use original rows 15614/15616/15618 (graphic
serials 27893/27895/27897). Food uses bread 14982, roast chicken 15054, bento
15012, hot pot 15076, stew 15011, noodles 15014, fruit salad 14986 and
dumplings 15022. 親子丼 reuses rice-bowl row 15013. Imported alpha edges and
source pixels are preserved. No recoloring or new artwork.

These are local Goemon rules, not recovered Blue CG drop/healing rules:

| Food | Effect |
| --- | --- |
| Bread | Restore 25% maximum HP |
| Roast chicken | Restore 50% maximum HP |
| Bento | Restore 100% maximum HP |
| Hot pot | +30% damage for 10 gameplay minutes |
| Hearty stew | +30% maximum HP for 10 gameplay minutes |
| Noodles | +20% attack speed for 10 gameplay minutes |
| Fruit salad | +20% movement speed for 10 gameplay minutes |
| Dumplings | +20 defense points for 10 gameplay minutes |
| 親子丼 | +5% of starting skill size and hit radius per serving, for the rest of the run |

Explore-mode native enemy deaths and arena slime deaths have a 20% food chance,
equally choosing the nine foods. They never drop chests. Arena slime return queues
and wave counts retain their existing owner. Within 7.5 world metres (roughly a
normal arena slime's reach), food slides toward the player at 24 m/s and eats
automatically on reaching the existing 2.4 m pickup distance. The pull checks
3D distance and clear cover each update, stopping outside range or behind walls.
All food is consumed at full HP too; healing never raises HP above its maximum.
A healing pickup at full HP shows the food name and “HP full”. Healing is capped and
cannot revive. Different temporary bonuses coexist, and repeated servings stack additively:
two hot pots give +60% damage, three give +90%; two noodles give +40% attack
speed. Each serving refreshes that food's shared timer to 600 seconds. There
is no stack cap. Every new stew stack adds 30% of unbuffed maximum HP and grants
that added health. Expiry clears all stacks of that food and safely clamps HP
to the restored maximum. Healing-only food retains its immediate HP effect.
Movement food scales walking, sprinting and the existing prepared flight speed;
it does not change attack-driven lunges, dodges, jump height or controls.
Defense food adds to the existing level/allocated armor points before applying
`100 / (100 + total defense)`, so stacks reduce real incoming damage without
reaching immunity. The Stats panel includes food defense and its live reduction.

Active bonuses appear as the original food icons directly under character HP.
A single serving has a plain icon; repeats show ×2, ×3 and higher counts.
Six effect icons wrap into three columns under HP. Tooltips identify the food,
total bonus and remaining time. The same grid follows
Master Chief's visor health, with pet commands and skill buttons placed below it.
親子丼 has no timer: twenty servings give 2× starting visual dimensions and hit
radius, with unchanged damage, projectile count and explosion count. Run progression
owns its stacks, preserving them across fighter changes, death/respawn and real
walking transitions. Title/new run resets them. Existing Skill Balance size/area
edits remain the starting values; new casts snapshot food growth, including charge
shine and in-flight projectiles. There is no stack cap. Its tooltip says “Rest of
run”. It also appears in bonus chests; the regular healing chest is unchanged.

Timers freeze during pause, travel and death, and run through ordinary attacks,
spells and ladders. Bonuses survive area travel and fighter changes, but reset
on title/new run. Player stats keep the existing combat, animation and projectile
owners; food does not change native enemy/ally profiles or saved balance values.

Chest rewards now use the six original sword selections documented in
`swords/README.md`. Every chest awards one sword instead of food; levels are
item labels with no equip requirement. Acquired swords persist in Equipment.
A shuffled six-sword bag draws without replacement, then refills.

At area entry, up to twelve chests outside or three inside are placed on
reachable, clear navigation cells, at least twelve world metres apart. A fixed
area/run seed gives the same positions across entry points. Regular chests are
90%; black and white are 5% each. Walk within 4 metres and press F to open an
optional chest. All three colors draw from the same six-sword bag. Rewards
are saved before consuming the chest; failed saves keep the same reward ready
for retry. Opened location keys
persist for the run so revisiting an area cannot refill them. 熊弟 dialogue takes
F priority; pet orders elsewhere retain their owner. All three chest sprites render
at 0.06375 world units per source pixel, anchored
to the ground. Chest interaction key hints are hidden.

Dropped food expires after 120 unpaused seconds; scattered chests remain until
opened or leaving the area. Sixty-four shared slots bound active ground loot;
a full pool skips new food drops. Area changes clear ground drops. Twelve prepared
MultiMesh batches share immutable art/materials. Proximity uses only the bounded
loot slots, never an army scan, and bulk pickups coalesce HUD/audio feedback.
No per-kill loading or runtime material creation. No inventory, keys or MP effects.

Rules/presentation: `scripts/forest/exploration_loot.gd`. Temporary player stat
multipliers/timers: `scripts/player.gd`. Regression and rendered evidence:
`tests/forest-shrine/exploration_loot_test.gd`, run through Play Goemon with
`--script res://tests/forest-shrine/exploration_loot_test.gd` (optionally
`--headless`). Reports/captures: `build/Other Files/Explore Loot/`.

`tests/forest-shrine/food_magnet_test.gd` checks attraction, actual walking,
frame-rate consistency, cover, pause, expiry and all 64 pooled slots. Its
desktop captures and logs are under `build/Other Files/Food Magnet/`.
