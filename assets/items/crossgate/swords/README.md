# Chest swords

These six inventory sprites are unchanged original Cross Gate artwork copied
from `build/Other Files/Asset Toolkit/Cross Gate Weapon Catalog/original-pngs/swords/`.
`provenance.json` records their original graphic keys, serials and hashes.
SW codes identify catalog selections, not recovered official item names.

| Code | Item level | Added ATK | Added dodge chance | Normal attack effect |
| --- | ---: | ---: | ---: | --- |
| SW016 | 3 | 55 | 10 percentage points | — |
| SW020 | 6 | 150 | 20 percentage points | — |
| SW042 | 2 | 45 | 30 percentage points | — |
| SW052 | 6 | 300 | 40 percentage points | — |
| SW082 | 10 | 400 | — | A connected normal hit adds level 7 Fire |
| SW101 | 10 | 300 | — | One click performs two normal swings |

Levels are informational, with no player-level requirement. All three chest
colors award one sword instead of food. Each shuffle bag contains all six
swords equally, draws without replacement and refills after six draws. A save
failure retains the unopened chest and the same selected sword for retry.
Acquisition unlocks that sword in the existing shared Equipment collection.
Each duplicate permanently adds one upgrade rank: +1, +2 and so on. Each rank
adds 10% of the original weapon ATK, rounded to a whole number after calculating
the total. SW052 progresses from +300 ATK to +330, +360 and +390; it does not
compound from the previous upgraded value. Item level, dodge chance, Fire
level and swing count stay unchanged. No upgrade cap is currently imposed.
Ranks belong to the shared collected sword and follow it across fighters.
Earlier discarded duplicates were not recorded and cannot be credited retroactively.
Failed saves roll back both collection and rank, leaving the chest ready to retry.
An active sword's bonus and prepared native copies refresh after a saved upgrade;
inactive carried swords still add no stats. The receipt, Equipment and HUD show
the upgraded name, and Equipment describes its actual upgraded ATK.
Enemy food drops are unchanged.

Only the active weapon adds its ATK and dodge chance. Dodge chance adds
percentage points and caps at 100%. ATK adds to normal physical damage before
the existing damage multiplier. The stat panel and HUD use the selected sword.
Carried inactive swords add no bonuses. Original character and skin sword
animations remain in use; these inventory icons do not replace blades baked
into full-body character frames.

SW082 snapshots the existing level 7 Fire rules and uses the shared projectile
pool, original effect art and audio. Each connected normal contact adds a Fire
effect on the struck enemy, without a casting motion, mana cost or learned-level
change. Fire cannot trigger itself and does not select unrelated targets.
SW101 repeats the complete native swing once; characters whose original swing
contains multiple contacts retain those contacts in both swings. Cancelling
the attack also cancels the pending repeat. Guard replies and Guard Break do
not gain either normal-attack effect.

Runtime owners: `scripts/forest/equipment.gd`,
`scripts/forest/exploration_loot.gd`, `scripts/crossgate_combat.gd` and
`scripts/spells/spell_loadout.gd`. Focused verification:

```sh
"/Users/eric/Desktop/Play Goemon.command" --headless --script res://tests/forest-shrine/chest_swords_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/chest_swords_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/sword_upgrades_test.gd
```

Reports and captures: `build/Other Files/Asset Toolkit/Chest Swords/`.
