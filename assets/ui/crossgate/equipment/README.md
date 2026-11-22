# Cross Gate equipment hub artwork

## Current equipped appearance preview — 2026-11-17

The larger main-character preview renders the selected model's standing frame
in one transparent menu viewport. It shares prepared body/cosmetic textures and
materials with gameplay and reuses `cosmetic_layers.gd` for the same head anchors,
facing, depth and animation. Equipping, removing or changing skin refreshes it
immediately. All standing cosmetic frames contribute to a stable camera fit;
large outfits can zoom out to stay visible. Five layer nodes are reused. No
player pose, combat controller, targeting owner or source pixels are changed.
Pet selection keeps its independent portrait. The top owner row and skin gallery
continue to use their original selection images. Available weapons are left
aligned at x=48, y=296, directly above the Weapons label.

Equipment saves immediately through the validated atomic save/apply path.
Back/Q retain equipped choices, failures restore the last saved appearance,
and Return/Enter Map are navigation actions. Older draft/layout descriptions
below are historical recovery notes.

Run `equipment_cosmetic_preview_test.gd` through Play Goemon for rendered bounds,
equip/remove/rollback, animation, layer reuse, current Cross Gate body frames,
skin changes, pet selection and reopening. Evidence belongs under
`build/Other Files/Asset Toolkit/Equipment Hub/Cosmetic Preview/`.

Locked weapon slots use `lock.svg`, a small slate and muted ivory symbol centered
inside the recovered cell. Keep this shared texture instead of OS emoji so its
size, baseline and colors remain consistent across machines and menu scales.

Double-click an equipped weapon, accessory, cosmetic or skill in the left rows
to Unequip it. Single clicks select; double-clicks in the collection still equip.
This uses the existing Unequip action and remains a draft until Enter Map.

## Skills inventory — 2026-11-15

The fourth tab and bottom Skills row use the same inventory selection, Equip,
Unequip, hover description and draft-on-entry behavior as the other categories.
Characters display their existing six key positions; the sixth retains its
native fixed skill except for Maze/Saizo, matching the existing Loadout picker.
Pets display their three existing attack slots and reject duplicate skill
families. Unequip restores a character's original/default skill or clears a pet
slot. Existing native skill icons and spell artwork are reused.

Character edits use `spell_loadouts` per selected appearance; pet edits use
`forest_pet_skills` by stable pet key. Enter Map saves these records atomically
with gear, cosmetics and appearance drafts. Back discards drafts and failed
saves retain previous records. The existing skill controllers, numbered hotbar,
skill levels and native pet caster owner apply the saved choices; the unused
skill-item stat catalog is kept separate. Pet-picker edits synchronize with
untouched drafts so either screen cannot silently overwrite the other's work.

Run `equipment_skills_test.gd` through Play Goemon for all nine Cross Gate
fighters, native-slot restrictions, draft/save/reload, failed-save preservation,
pet skills and key-triggered casting. Captures are in the Equipment Hub/Skills
folder under Asset Toolkit evidence.

The three PNGs are unchanged recovered Blue Cross Gate artwork. Sources and
SHA-256 hashes are in `provenance.json`; original archives and Magic Power
research remain read-only. The board is serial 244307 / `joy:322`, not the
mislabelled 0x552ed0 window (which displays a numeric-entry dialog).

The original eight-position board and crystal icon remain preserved as
references. The hub repeats the first native inventory cell from the 300×259
item window into ten generic equipped slots (two rows of five) and an 8×5
selection area. Character Gear and Skill Items have separate ten-slot loadouts
and filter selection by category. Character Gear offers the selected outfit's
verified weapons; Skill Items remains empty. Full-body portraits reuse
`rogue_roster_picker.gd`'s selection framing. The recovered ivory/slate frame
surrounds the enlarged panes. PNGs are not repainted or stretched into a fixed
grid. `equipment_hub.gd` owns layout; `preparation_skin.gd` owns shared styling.

The allowed-weapon icons beneath the character's feet and selectable items come from
`assets/characters/crossgate/weapons/catalog.json`. Weapons are Sword, Axe,
Spear, Bow, Staff, Fist and the existing Maze/Saizo Kunai. One weapon occupies
any one of the ten slots; replacing it removes the previous weapon. Special
Kaz is Sword only. Fixed/effect outfits retain their verified weapons. Pets
retain native attacks and cannot equip character weapons. These are recovered
animation capabilities, not server job/class restrictions or new stat items.
The centered row replaces the textual allowed list and uses the existing weapon
icons with hover names and accessibility labels. It follows the selected wearer
on Character Gear, hiding on other tabs and for pets without weapon equipment.

Fist uses compact artwork with cloth bandages wrapping the knuckles, hand and
wrist. Its transparent margins keep it smaller in the normal icon area. It uses
the same presentation as the other weapons in the allowed row, collection,
equipped slot and preview; there is no separate badge or frame around the fist.

Enter Map applies the matching whole-body source sprites, native cues and
existing combat owner. No explicit gear uses the existing native weapon;
Unequip returns to it. Select a weapon from the Weapons collection to equip it.
A saved choice unavailable on another outfit remains
saved and grey in its slot while that outfit uses its native weapon. Returning
to a compatible outfit restores the choice. The save boundary rejects unknown
or impossible character/weapon pairs and weapons on pets.

Cosmetics retains the ten-cell loadout and forty-cell collection grids. Its
six current choices are regular blue, Red, Gold, Jade, Violet and Rainbow chrome.
The chosen Qi finish appears in loadout cell 1; the other cells remain empty
for future cosmetics. They reuse the existing Qi orb artwork and a shared canvas tint shader.
These are local Goemon appearance choices, not recovered server item rules.
Color consumes no gear slot and changes neither damage, count, skill level,
targeting, cooldown nor weapon models. Old `crystal` and numbered-slot color
saves migrate into cosmetics; existing choices, including explicit regular
blue, win over legacy data. Combat keeps its existing pooled effects.

Rainbow chrome adds slow rainbow reflections and silver highlights to the
flying orb. The menu and projectile share
`assets/characters/crossgate/qigong/chrome.gdshaderinc`; original orb PNGs,
charge and contact artwork remain preserved. Its finish is snapshotted on the
existing cast ticket and reset on each pooled projectile launch. The menu
prepares one chrome material during setup; combat uses an instance parameter
on the existing shared material, without per-shot material creation.

All three pages save by fighter identity across skins or stable pet source key.
The hub keeps drafts until Enter Map and saves all three records together.
Back discards drafts; the companion picker saves its selection separately.
New runs, travel, recall and death preserve these saved choices. Existing run
skill-level reset rules remain. Unknown items, wrong categories, invalid slots
and owners are rejected. Saves preserve unreadable files and write a temporary
file before replacement.

No client archive, research file or sibling project is loaded by the game.
Use Play Goemon for `weapon_equipment_test.gd`, `equipment_hub_test.gd`, `arena_menu_test.gd`,
`preparation_menu_hotkeys_test.gd` and existing pet/loadout regressions.
Evidence stays under `build/Other Files/Asset Toolkit/Equipment Hub/`.
