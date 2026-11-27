# Chest axes

These are unchanged original Cross Gate inventory sprites from the preserved
`Cross Gate Weapon Catalog/original-pngs/axes/` under the Asset Toolkit.
`provenance.json` records source keys, graphic serials and original PNG/RGBA
hashes. AX codes are catalog selections, not recovered official item names.

| Code | Item level | Added ATK | Added critical chance | Normal attack effect |
| --- | ---: | ---: | ---: | --- |
| AX018 | 3 | 150 | 30 percentage points | — |
| AX013 | 4 | 300 | 30 percentage points | — |
| AX024 | 8 | 500 | — | A connected normal hit adds one level 4 乾坤 strike |

Every axe, including the generic axe and character-native axe stances, subtracts
10 Accuracy. This is a shared weapon-family penalty, so it applies once and does
not grow with duplicate upgrades. ATK/critical bonuses apply only to the active
weapon; critical chance caps at 100%. Levels are informational, with no level
requirement. Inventory sprites do not replace axes baked into character frames.

All chest colors draw equally from the six existing swords and these three axes
in one nine-item shuffle bag. Duplicate axes reuse the existing permanent upgrade
rule: each rank adds 10% of original ATK, rounded after computing the total.
Axe ownership/ranks reuse the historical `chest_swords`/`sword_upgrades` save keys
so existing discoveries, equipment and saves remain compatible. A failed save
rolls back ownership/ranks and leaves the same chest reward ready for retry.

AX024 snapshots level 4 乾坤 with the shared skill rules and existing native impact
presentation. Each connected normal contact adds one extra physical hit to the
same living enemy. It spends no mana, starts no cast controller, changes no
learned skill level, and cannot trigger itself. The extra strike has its own
physical hit check. Guard replies, Guard Break, misses and cancelled windups do
not trigger it. Native copies inherit the same equipment and effect.

Accuracy starts at zero. One allocated stat point adds one Accuracy and offsets
one percentage point of enemy dodge. Physical miss chance is
`clamp(enemy Dodge − attacker Accuracy, 0, 100)`; higher Accuracy cannot defeat
range, cover, guard or invulnerability. The new general enemy Dodge defaults to
5% and is editable per supported enemy family in Enemy Balance. Each native
target draws percentage marbles without replacement and reshuffles after 100
checks. Magic and damage-free status applications bypass this general physical
check. Existing reactive boss/pet defenses retain their own rules; Accuracy also
reduces the existing reactive dodge roll. Towers retain their prior hit contract.

Owners: `equipment.gd`, `exploration_loot.gd`, `player.gd`, `attack_chain.gd`,
`crossgate_combat.gd`, `spell_loadout.gd`, and the shared native army contact owner.
Focused verification through the desktop launcher:

```sh
"/Users/eric/Desktop/Play Goemon.command" --headless --script res://tests/forest-shrine/axes_accuracy_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/axes_accuracy_test.gd
"/Users/eric/Desktop/Play Goemon.command" --headless --script res://tests/forest-shrine/mirror_movement_test.gd
```

Logs, captures and native checks belong in
`build/Other Files/Asset Toolkit/Axes and Accuracy/`.

## Temporary startup access — 2026-11-23

Play Goemon now supplies `--all-weapons` for ordinary play sessions. Equipment
shows every compatible default weapon and all nine collectible swords/axes
immediately. The flag bypasses collection locks without writing fake discoveries
or upgrade ranks. Equipping still uses the regular saved loadout. Chest rewards
and duplicate upgrades continue to use actual saved ownership. Script tests keep
normal collection locks unless they explicitly supply the flag. Remove the flag
from `tools/launch_goemon.command` when this testing period ends.
