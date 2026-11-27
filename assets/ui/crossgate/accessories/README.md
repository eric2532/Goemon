# Numbered Cross Gate accessories

These include ten original icons selected from the 543-choice accessory gallery
and the selected footwear graphics 21817, 21884, 21818 and 21903, plus clothing
graphics 21669 and 21678. PNG filenames retain the gallery
numbers or footwear graphic serial. `provenance.json` records their
original pack, row, serial, palette, dimensions and encoded/pixel/PNG hashes.
Keep these pixels unchanged; names and bonuses are local Goemon rules, not
recovered server item definitions. Descriptive names do not establish original
item names. The game loads only these local PNGs, never the research library.

| Number | Effect |
| --- | --- |
| 22 | Attack range ×2 |
| 23 | Attack range ×3; together with 22 gives ×6 |
| 72 | Counterattack chance +35 percentage points, capped at 100% |
| 78 | Flat +1,000 maximum health after other health multipliers |
| 207 | Two additional 追月 waves per cast; extra waves can share an existing target |
| 217 | Basic attacks become level 1 Fire magic |
| 231 | Each connected 乾坤 hit adds a local explosion that damages other enemies |
| 241 | Basic attacks become level 1 亂射 with three arrows while a bow is equipped |
| 262 | Each Ice effect makes ten contacts by repeating its original animation |
| 263 | Ten additional Wind projectiles per native volley, with their own four damage pulses |
| 21669 | Shadow Vest: every accepted manual Space dodge leaves an anchored shadow that automatically performs one normal counterattack, regardless of Counter Chance |
| 21678 | Evasion Vest: +100 percentage points Dodge (capped at 100%) and +100 physical defense |
| 21817 | Speed Shoes: movement speed ×3 while equipped, multiplying existing movement bonuses |
| 21884 | Backstep Boots: tap Space to dodge backward without a warning; ordinary timed dodges and Shift+Space jumps remain available |
| dash-boots | Dash Boots: left-click a melee target to dash 50% faster with the run animation into normal attack range; ranged weapons keep their firing range |

Dash Boots retain the local save ID `accessory:dash-boots` and now use the
user-selected original graphic **21903**, v3 row 4509, palette 0. `21903.png`
is copied byte-for-byte from the preserved footwear library. The previous
21818 icon is preserved. Speed Shoes (21817) and Backstep Boots (21884) keep
their own icons. The existing `attack_dash` flag enables the shared approach
mover and native run animation; it does not enable free Space dodge.
The full dash uses 48 units/second (50% faster than the previous 32) times current movement bonuses. Without this
item, the existing approach and short final rush remain. There is no added
damage, reach or protection. Reproduce the focused checks with
`tests/forest-shrine/dash_boots_test.gd` through Play Goemon; captures are under
`build/Other Files/Asset Toolkit/Accessories/Dash Boots/`.

Use the existing Equipment → Accessories page and five accessory slots. Each
item can be worn once. Fire and 亂射 replace one another when equipped; save
validation rejects both together. With another weapon, #241 retains normal
attacks. These items are for Cross Gate fighters and their existing native
character copies; they are not exposed as unsupported pet equipment. Gear
remains saved per fighter across appearances. Back discards drafts, and failed
saves retain the last saved loadout. Equipping health does not repeatedly heal.

`scripts/forest/equipment.gd` owns the catalog and bounded five-slot aggregation.
The player caches its bonuses on selection/equipment changes. Shared range,
health and counter owners consume them. Shared skill tickets snapshot the
per-cast effects; current pools, original sprites, contact checks, cover rules,
audio and native lifecycle remain in use. No extra simulation or targeting owner
is introduced.

21669 starts the existing normal shadow counter directly from manual dodge input.
It preserves Space's warning requirement; with Backstep Boots, warning-free
manual steps also leave a shadow. A timed step remembers its original attacker;
a free step uses the existing bounded visible-target query at the shadow's
origin once when dodging. With nobody nearby there is no valid counter target,
just as for a regular counter. No attack click is required. An
already-running counter finishes its swing before the existing pending slot
starts the new automatic counter. Pause, key repeat,
Shift+Space jumps and automatic stat/skill dodges cannot earn this guaranteed
counter. Automatic reactions retain their ordinary Counter Chance. Removing
the vest, changing fighter or dying clears its counters and prepared shadow.
The accessory only bypasses the ordinary Counter Chance roll for manual dodge
input. Damage, reach, timing, attack frames and the pending-counter slot are the
existing regular counter's; hit and automatic-dodge counter behavior is unchanged.
21678 uses the shared chance cap and adds physical defense through the player's
existing damage reduction calculation and Stats panel; food/level defense still
stacks, and magic defense is unchanged. Neither garment changes the body sprites.

Run `tests/forest-shrine/clothing_accessories_test.gd` through Play Goemon for
the Cross Gate roster, real dodge/counter damage, manual/automatic separation,
free backsteps, save/reload, imported pixels, UI and repeated resource reuse.
Evidence belongs under `Accessories/Clothing/` in the Asset Toolkit folder.

Fire uses a separate prepared instance and projectile lease profile, so its
basic casts cannot consume or cancel the hotbar Fire cooldown/projectiles. Both
basic replacements force level-one skill rules without changing learned skill
levels. Ice keeps the original three contact markers per full animation cycle
and stops at the tenth damaging marker. Extra winds share the selected target
set, with independent per-pulse hit dictionaries. The additional 乾坤 explosion
uses the existing pooled presentation and bounded splash helper; its ticket
cannot recursively explode or apply the original damage multipliers again.

Run `tests/forest-shrine/accessory_effects_test.gd` through Play Goemon for the
Cross Gate roster, source/imported pixel checks, real damage, level-one
replacements, save boundaries, UI, simultaneous native ally casts and warmed
resource checks. Evidence is in `build/Other Files/Asset Toolkit/Accessories/`.
