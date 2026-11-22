# Cave monster progression

The user requested Cross Gate-inspired cave levels on 2026-11-12, with bear
and sea caves in the level-20 category, and explicitly chose to retain the
original stronger boss levels. Aiming displays **name and level only**.

## Source evidence and chosen levels

The preserved CGMSV reference is in the sibling Magic Power project:
`research/cgmsv-20261031/source/gmsv/data/enemy.txt`, from
`linv2/Crossgate_Docker` commit `dd8690ed3df11e4eb5a038a54079a8f40d8e93b3`.
The existing importer validates ID/base/min/max level columns. This is a pinned
server reference, **not a verified dump of every official or BlueCG revision**.
Selected rows, line numbers and the original file's SHA-256 are recorded in
`build/Other Files/Cave Progression/source-levels.json`. Source archives are read-only.

| Encounter | Source evidence | Goemon level |
|---|---|---|
| Habaru passage slimes | Adapted progression, not an asserted source level | 12 then 16 |
| 熊弟 and nine 穴熊 | Records 9022/9023: 25/20; [cave guide](https://guide.bluecg.net/blue-cg/453468) agrees | 25 / 20 |
| Venoa cave bears | Historical wild range 15–18; user requested the level-20 category | 18 / 20 / 22 across floors |
| Venoa Great Bear | Existing Goemon encounter; no matched original boss record established | 25 |
| Sokia sea-cave lizards | Historical range 18–20 in the [cave guide](https://cg.skyey.tw/errand/maae03.htm) | 20 |
| 熊哥 | Records 9067/9068: 40; cave guide agrees | 40 |
| Venoa sea-cave lizards | Adapted later-route progression; historical sea-cave tables give 18–20 | 26 |
| Modified Zombie | Record 9021: 35; [encounter guide](https://cg.skyey.tw/errand/maad03.htm) agrees | 35 |
| Zombie/corpse/hellhound | Zombie escort guide gives 23–24; other exact levels are adapted | 24 / 23 / 20 in the lab; 20 / 20 / 18 in the entrance resource |
| Pirate captain, sea bats and pirates | Records 9062–9066: 20 / 15 / 15 | 20 / 15 / 15 |
| Ruby, Bloody Blades and ghosts | Matching [Black Prayer fight](https://guide.bluecg.net/blue-cg/452857): 50 / 30 / 30 | 50 / 30 / 30 |
| Black Prayer maze Ghosts and Bloody Blades | Pinned dungeon configuration 301 / encounter 15001: 20–23 | 20–23 on all six generated floors |
| Parukes ghost, soldiers, final form and rebels | Records 25021–25025: 80 / 70 / 90 / 60; [encounter guide](https://guide.bluecg.net/blue-cg/453130) agrees | 80 / 70 / 90 / 60 |

Do not use Ruby's level-68 arena or level-70 Ice Prison records for this
Black Prayer encounter. Species appearance alone does not identify an encounter.
The routes remain open; these levels do not introduce entry restrictions or
automatically scale to the player's level.

## Real-time balance

`scripts/forest/cave_progression.gd` owns the small prepared table. Each row is
name, level, HP per level, and boss flag. Ordinary units use 300–500 HP per
level according to species, and `30 + 3 × (level − 1)` base contact damage.
Bosses use 1,200 HP and 8 damage per level. This preserves 熊弟's 30,000 HP /
200 damage while making 熊哥 48,000 / 320, Ruby 60,000 / 400 and final Parukes
108,000 / 720. Level-20 bears retain 10,000 HP and now deal 87 base damage.
Native attack-specific multipliers, such as the bears' double-edge contact,
continue to apply. HP, damage and XP are Goemon balancing choices, not claimed
original turn-based formulas.

Ordinary kills grant one XP per monster level, consistent with outdoor monsters.
Bosses grant five XP per level. The native death event credits the main character
and the pet that lands the killing blow, including in two-stage encounters and
against recurring rebels.

Apply this data once before native arrival import. Preserve the current
controllers, navigation, footprints, attack timing, skills, dialogue triggers,
spawn counts and slain-slot persistence. Deeper floor spawns get higher stats;
crossing a doorway does not upgrade a surviving unit in place. Player pets and
arena slime waves do not use this table.

## Verification

```sh
"/Users/eric/Desktop/Play Goemon.command" --headless --script res://tests/forest-shrine/cave_progression_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/cave_progression_test.gd
```

The focused fixture checks actual native HP and repeated contacts across cave
families, scaling in both Parukes phases and replacement rebels, once-only XP,
name/level-only targeting, and reuse of the same HUD. Rendered captures go to
`build/Other Files/Cave Progression/`; consult the final logs for actual results.
Existing scripted lethal hits now use each target's maximum HP; wound/skill
threshold fixtures use HP fractions so balance changes cannot silently stop
them from reaching their intended phase. No app export is needed.
