# Forest Shrine tests

## Ranged-hit enemy aggro

Run `"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/ranged_aggro_test.gd`
(add `--headless` for logic only). Actual Water Dragon arrows, knives and curved
boomerangs, plus Maze's native knife volley, hit unaware patrols at 45 meters.
Checks cover player pursuit, movement, prepared projectile reuse and release
when the player becomes untargetable. Desktop captures show each hit and chase.
Evidence belongs under `build/Other Files/Asset Toolkit/Ranged Aggro/`.
Native `crowd/player_approach_test.cpp` also covers 120-meter hits, guarding,
committed counters, non-provoking hits, death, patrol leashes, companion source
attribution, taunt priority and generation-safe reuse at 20/30/60 Hz.

## 水龍 and 螳螂 family passives

Run `"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/pet_family_passives_test.gd`
(add `--headless` for logic only). Checks cover all family variants, stacked
player regen/crit, individual pet-point spending, actual Equipment clicks,
critical caps and tickets, healing through player physics, Bee Mirage,
ordinary native ally isolation, wounds, recall, travel, removal and reset.
Desktop captures cover both passives and the 960×640 upgrade layout. Evidence
belongs under `build/Other Files/Asset Toolkit/Pet Family Passives/`.

## Level-up skill cards

Run `"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/skill_cards_test.gd`.
Add `--headless` for logic only. The fixture covers the 20-marble bag, queued
choices, equipped-only offers, empty and fully capped loadouts, stat points,
and independent pet rewards. Screenshots and logs belong under
`build/Other Files/Asset Toolkit/Skill Cards/`. Tests for the previous team
buff, named recruitment and Qi rank card workflows below describe historical
revisions. Use the new fixture for the current picker.

## Skill input without a queue

Run `"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/skill_no_queue_test.gd` (add `--headless` for logic only). It checks all current Cross Gate fighters with eight shared spells: rapid numbered/action presses, held-key echoes, release cleanup, waiting beyond cooldowns/projectile lifetimes, a fresh ready press and dodge cancellation. Busy/cooldown presses must never produce a later cast. Settings are temporary; logs belong under `build/Other Files/Asset Toolkit/Skill Input/`. Historical queue expectations remain excluded under `reference/skill-timelines/`.

## J automatic melee range

Run `"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/crossgate_auto_melee_range_test.gd` (add `--headless` for logic only). The current Cross Gate roster and supported default-appearance weapons cover waiting outside melee reach, automatic native hits inside reach, manual empty swings, ×1/×2/×6 accessory range, ranged weapon/Fire exceptions, physical J, height, cover, guard and pause. Temporary settings isolate the fixture; logs and desktop captures belong under `build/Other Files/Asset Toolkit/Auto Melee Range/`. This is a focused behavior check, not a full-army performance benchmark.

## Rounded punch gust

Run `"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/crossgate_skin_wind_test.gd -- --fists-only` (add `--headless` for logic only). This covers all 228 supported fist appearances across 15 Cross Gate identities, eight facings and ×1/×2/×6 accessory range. It checks original contacts, native damage/misses, the gust's world direction, fist height and visible front against the real hit boundary throughout its travel, then repeats five simultaneous native copies for each supported identity. Desktop captures cover every fist appearance plus representative ×1/×3/×6 range. Evidence is isolated under `build/Other Files/Asset Toolkit/Cross Gate Melee Wind/Punch Gust/`. The shared wind fixture remains the regression for other weapons. This isolated fist matrix does not establish full-army frame performance; the full alternate-skin matrix is described below.

## Cross Gate melee wind and alternate skins

Run `"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/crossgate_skin_wind_test.gd` (add `--headless` for logic only). This covers all 271 current Cross Gate appearances and 1,402 weapon choices: 1,165 melee setups, eight facings, ×1/×2/×6 accessory range, each original contact, reviewed source cues, visible leading edges against actual reach, gentler cosmetic breadth at ×3/×6 without shrinking below normal, native damage/misses and ranged exclusions. Desktop sequences cover all 923 distinct non-fist source keys. Representative paired/side swords, heavy axe, piercing/chopping polearms, mixed and pouncing staff, spinning sword and special palm/release gestures repeat five simultaneous native copies and render ×1/×3/×6 range. Source silhouettes and original anchors were reviewed in all eight directions, grouping 403 exact shape sequences. Evidence belongs under `build/Other Files/Asset Toolkit/Cross Gate Melee Wind/Alternate Skins/`.

`crossgate_melee_wind_test.gd` runs the smaller 68-default-melee-setup regression, including pause, clear, cosmetic capacity, paired directions and bounded reuse. Both fixtures isolate temporary settings. The approved shapes indicate reach at weapon height without a range ground circle; they do not change hit timing or act as persistent hitbox outlines. Timings are isolated fixture CPU steps, not full-army frame measurements.

## Cross Gate fist reach and timing

Run `"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/crossgate_fist_feel_test.gd` (add `--headless` for logic only). The fixture covers every supported fist appearance, all eight source-facing contact clocks, actual native hits beyond the previous reach, no early damage, full recovery, weapon switches, upgrades and the 3× speed cap. Five simultaneous native character copies repeat ten cycles at previous/current tuning per supported identity. Temporary balance overrides simulate the previous fist multipliers; this is not a historical build benchmark. Desktop runs play each identity's fist animation and capture a native enemy hit. Settings are isolated; evidence goes to `build/Other Files/Asset Toolkit/Cross Gate Fist Feel/`. Use `crossgate_stat_baseline_test.gd` for the shared weapon/balance regression.

## Cross Gate player attack audio

Run `"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/crossgate_player_audio_test.gd -- --visual`.
The matrix discovers the current Cross Gate roster, appearances and compatible
weapons. It checks real hit/miss playback against recovered PCM, source silence,
unchanged swing/contact counts, selected-weapon Studio previews, recordings,
gain, mute, repeated voice/resource reuse and five simultaneous native copies.
The visual pass records recovered bow/sword/staff playback and rendered poses.
First run `python3 tools/prepare_crossgate_player_audio.py '../Magic Power' --check`
to validate all eight source directions. Ordinary asset `check` rejects stale
coverage, source hashes and sample PCM. Evidence goes under
`build/Other Files/Asset Toolkit/Cross Gate Player Audio/`.

## Saizo sword audio

Run `"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/saizo_sword_audio_test.gd -- --visual`.
It checks original swing 105 on one native sword cut across all thirteen Saizo skins,
hit-only impacts, original contact/recovery frames, Maze isolation and saved sound
recording/gain/mute overrides. The visual pass saves attack frames and real SFX
mixer output under `build/Other Files/Asset Toolkit/Saizo Sword Motion/`.

## Q equipment and carried weapons

Run `"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/equipment_shortcut_weapons_test.gd`.
It checks the Cross Gate weapon/skill choices, missing-weapon save rejection,
three-bear inventory/hotbar icon, physical Q, held-key repeats, immediate saves,
pause restoration and preservation of the live wave. Desktop captures include
1280×800 and 960×640 under `build/Other Files/Asset Toolkit/Equipment Shortcut/`.

## Skill key hub

Run `"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/skill_key_hub_test.gd`
(add `--headless` for technical checks). It covers all nine Cross Gate fighters,
hidden key numbers, tooltip/empty-slot mappings, shared frame reuse, icon/status
bounds, two window sizes,
65–125% HUD scaling, Kaz's toggle/cooldown and repeated HUD resource reuse.
Desktop captures go to `build/Other Files/Asset Toolkit/Skill Key Hub/`.

## Equipment and pet picker

`equipment_cosmetic_preview_test.gd` checks the larger equipped character preview,
shared standing artwork/attachments, animated cosmetics, stable camera fit,
equip/removal/save rollback, reused nodes, skin/pet changes and in-game reopening.
Run it through Play Goemon; rendered evidence goes to Equipment Hub/Cosmetic Preview.

`equipment_skills_test.gd` checks the fourth inventory tab and bottom skill row,
all nine fighters' six editable empty-default slots, immediate character/pet assignment and removal,
atomic save rollback, reload, native pet caster preparation and key-triggered Qi.
Desktop captures cover 1280×800 and 960×640 under Equipment Hub/Skills evidence.

`equipment_double_click_test.gd` checks empty skill keys across all nine fighters,
single-click inspection, double-click equipment, ordered full-row replacement and
wrap, per-pet three-slot placement, retained starting weapons, cosmetic finish
replacement, skin activation/auto-close, separate saved loadouts and removal of
an equipped toggle. Full accessory/cosmetic placement uses test-only item fixtures
without adding fake items to the game catalog. Run through Play Goemon for desktop
input and captures; evidence is under `build/Other Files/Asset Toolkit/Equipped Skills Only/`.
The older `crossgate_combo_test.gd` and `shared_crossgate_skills_test.gd` still have
historical fixed shine/contact/audio assertions that fail current level rules;
their failures are recorded separately in that directory's `validation.json`.

`weapon_icon_scaling_test.gd` compares the approved red boxing gloves with the other weapon
icons at 1280×800 and 960×640, including 65–125% HUD scaling. It checks shared
icon bounds, aspect ratio, six-column collection fit, all 48 slots reachable by
scrolling, all four category grids and tabs inside their frames, half-size supported
weapon icons, untinted boxing gloves, larger equipped/skill icons and the selected source texture.
Desktop captures go to `build/Other Files/Asset Toolkit/Equipment Hub/Icon Scaling/`.

Run `weapon_equipment_test.gd` through Play Goemon for the current Cross Gate
appearance/weapon catalog. It covers outfit restrictions (including
Sword-only Kaz), selection drafts, atomic saves/reload, unlocked carried weapons with one active weapon,
native contact damage and arrow release, existing Kunai quotas, all eight
directions, weapon cycling, incompatible-outfit fallback/restoration and warmed
melee resource reuse. Omit `--headless` to capture the equipment grid at two
window sizes and representative native attack poses. Evidence lives under
`build/Other Files/Asset Toolkit/Cross Gate Weapon Inventory/`.

`original_boomerang_test.gd` covers all 237 compatible appearances against the
source inventory, including eight-direction normal/counter frame identity,
source release timing, one hit per flight, return/retirement, original/custom
pool separation, saves, four native copies and actual click/Shift controls.
It also checks the separate Lv1 wooden and 水龍 equipment icons. Run through
Play Goemon for rendered evidence under `Asset Toolkit/Original Boomerang/Implementation/`.
`water_dragon_weapons_test.gd` explicitly selects the separate 水龍 custom item;
its contact checks fix crit/accuracy so random defenses cannot alter expected damage.

`water_boomerang_contact_test.gd` checks the separated blue wave at confirmed
enemy contacts: no caster-side release wave, exact contact position, misses,
ordinary-weapon isolation, counters, four native copies, repeated effect/projectile
reuse and damage with a full cosmetic pool. Run through Play Goemon for release
and contact captures under `Asset Toolkit/Water Boomerang Contact/`.

Run `equipment_hub_test.gd`, `pet_loadout_test.gd`,
`preparation_menu_hotkeys_test.gd` and `arena_menu_test.gd` through Play Goemon
with `-- --crossgate-pet-test`; use `--headless` for technical checks and omit
it for rendered review. The equipment fixture checks the five-position weapon row
(one initially open), five accessory slots and five cosmetic item slots,
collection tabs, 48 cells in six columns and scrolling, concise hover descriptions,
appearance drafts, fighter-specific persisted unlocks and failed-save rollback.
It also covers the separated Main Character / Pets headings, shared full-body
game sprites on the hero button and preview, skin updates, weapon permissions, legacy weapon/crystal
save migration, independent wearer colors, safe saves, rainbow-chrome snapshots,
pool resets and repeated five-pet casts with different finishes. Clicking the
main character model opens the shared skin gallery; skin choices are separate
from the five cosmetic slots. The fixture checks preview, discard and commit,
and equipping/removing cosmetic items in the first slot. Existing Qi placements
retain their saved positions.

`cosmetic_equipment_test.gd` exercises all 400 recovered wardrobe resources in
the actual Cosmetics menu, five simultaneous slots, draft discard, disk reload,
unequip, authored facing gaps, fall fallbacks and the prepared Cross Gate
skin/weapon attachment matrix. It also checks repeated playback reuse and five
native copies through disposal. Run through Play Goemon for roster captures
and an isolated warmed render sample; append `-- --controls` for rendered normal
walk/sprint/jump/attack input. Settings remain isolated. Pixel matching tests are
`python3 -m unittest discover -s tools -p test_prepare_crossgate_cosmetics.py`.
Append `-- --alignment` for all 273 skin bindings, all 400 resources across the
16 Cross Gate characters and compatible facing/action combinations, reviewed
pose landmarks, and normal-input motion captures for every character. The source
audit is `python3 tools/audit_crossgate_cosmetic_alignment.py`; pixel support
coverage and rendered appearance remain separate checks.
Append `-- --all-animations` for every available selected-skin frame/action, the
complete resource/facing/action matrix, and full hurt/death capture in eight
facings with a final corpse hold through the existing combat owner. Pair it with
`python3 tools/audit_crossgate_cosmetic_alignment.py --all-animations` to reject
attachment gaps in any recovered action, including weapon/fist/dagger aliases.
Evidence belongs under `build/Other Files/Asset Toolkit/Sponsor Cosmetics/`;
technical coverage does not approve every item/skin/action visually.

Future rewards call `forest_game.unlock_weapon_slot(Gear.character_key(character))`;
this commits one additional slot, caps at five and preserves the old state on failure.
No progression cost or automatic unlock milestone has been selected yet.
The pet picker fixture checks that only the pet-family dropdown remains, that
pack saves preserve current skill assignments (including changes made after
opening), and seven full-pack picks replace slots 1–5 then wrap. It also retains
native save/lifecycle, wound and rollback checks. Skill assignment is covered by
`equipment_skills_test.gd`; the pet picker no longer edits skills.
The retired build/hire hotkey fixture is preserved under `reference/ui/`.
Evidence is under `build/Other Files/Asset Toolkit/Equipment Hub/`.

## 贊助 sponsor pets — 2026-11-14

`sponsor_pet_combat_test.gd` checks every new native contact/audio contract.
`sponsor_pet_loadout_test.gd` reuses the reward fixture for all nine Cross Gate
pickers, 56 exact category members, five saved source keys, wounds, commands,
recall/resummon and warmed atlas/node/resource reuse. `sponsor_pet_skills_test.gd`
checks shared attacks and five simultaneous new casters, including 雷公,
獨角黑馬, 珊瑚鯨, 雷姆 and 亞古獸. `sponsor_pet_visual_review.gd` renders all 56
in idle, movement and front/back attack poses at current gameplay sizes.
Run separately through `/Users/eric/Desktop/Play Goemon.command --script
res://tests/forest-shrine/NAME.gd`; only the contact fixture is nonvisual.
Evidence belongs under `build/Other Files/Asset Toolkit/Sponsor Pets/`.

## 灰熊厲害 A/S reward pets

Run `bear_reward_pet_combat_test.gd` for actual native contacts/audio across all
126 A/S appearances. `bear_reward_pet_loadout_test.gd` covers all Cross Gate
pickers, saved keys, the five-pet limit, wounds, F/G/H, P toggle, resident
pages and warmed resource counts. `bear_reward_pet_skills_test.gd` reuses the
shared skill/pooling checks with five simultaneous reward species.
`bear_reward_pet_visual_review.gd` captures idle,
movement and front/back contacts using the real sprite shader and body fits.
Use Play Goemon for the visual/loadout/skills fixtures; keep evidence under
`build/Other Files/Asset Toolkit/Bear Challenge Pets/A Rank Recheck/`.

## 諸刃 debuff display — 2026-11-13

`double_edge_debuff_hud_test.gd` verifies actual casts and the below-character
badge: level-dependent defense reduction, remaining time, following, pause,
recast, expiry/death/offscreen hiding, HUD scaling and stable resource counts.
Run through Play Goemon for screenshots; evidence is under
`build/Other Files/Skill Levels/Double Edge Debuff/`.

## Skill level first pass — 2026-11-13

Current level-rule coverage is `skill_levels_rules_test.gd`,
`skill_levels_gameplay_test.gd`, `skill_levels_melee_test.gd` and the focused
`skill_levels_sure_strike_test.gd`. Run desktop verification through
`/Users/eric/Desktop/Play Goemon.command --script res://tests/forest-shrine/NAME.gd`;
add `--headless` only for nonvisual checks. Evidence belongs under
`build/Other Files/Skill Levels/`. Skill Balance now supplies manual run-level
and count-modifier controls for testing. `skill_level_points_test.gd` covers the
real I → Skills six-slot menu: current loadout/weapon mapping across the nine
Cross Gate fighters, shared stat balance, current/next tooltips, native aliases,
cap/empty/undefined/inactive requests, save preservation, travel, fresh-run reset,
small-window rendering and repeated panel cleanup.
`skill_shine_tiers_test.gd` checks the actual four original casting-shine sheets,
all nine Cross Gate casters, native boundaries, elemental/recovery impact
preservation, saved item/food snapshots and repeated effect reuse. Source and
desktop previews are under `build/Other Files/Skill Levels/Original Shine Tiers/`;
original source previews remain in `Shine Tiers/Source/`.
`lancelot_shadows_test.gd` now covers 1/7 shadows, 3/32 arrows, current caster
levels, cast snapshots and repeated native-owned volleys.

`crossgate_native_skill_pattern_test.gd` and its ranged-skill wrappers now assert
the new cast quotas, damage contracts and source contact markers. Older fixed
damage/count/recovery-charge expectations elsewhere document the previous
design; use the level fixtures for the redesigned numeric contracts. Preserve
those older fixtures and their images rather than rewriting their historical
claims as current verification.

`skill_shine_tiers_test.gd` rechecks the recovered four-tier source tables at
levels 1/9/10/18/19/27/28/30 across the current Cross Gate roster. It covers
physical/elemental casting shines, all elemental target variants, Recovery
cast/arrival agreement, source pixel density, snapshots, item/food multipliers
and prepared-pool reuse. The fixed-rank Spirit and specialized single-sheet/EX
impacts remain preserved; their missing rank mappings are not fabricated.
Source rank/hash receipts and rendered comparisons live under
`build/Other Files/Asset Toolkit/All Cross Gate Art Tiers/`. The target captures
isolate source impact art after hiding the casting shine and advance ice,
meteor and recovery to their actual upright/contact/arrival frames.

## Default test scope — Cross Gate only

`shared_meditation_test.gd` checks 明鏡止水 in Equipment → Skills and real numbered
input across the current Cross Gate roster and its supported weapon
routes across all four original meditation tiers. It covers original art/audio
and cast/release timing, source pixel density/origins, tier snapshots, exact missing-health healing, snapshots/modifiers,
the shared ten-second duplicate-slot cooldown, interrupted/rejected casts,
upgrade-point UI, original Shin/Bog entry points and forty warmed repetitions. Run through
Play Goemon for inventory, casting and healing captures under
`build/Other Files/Asset Toolkit/Shared Meditation/Original Tiers/`. The historical
default-hotbar fixtures are preserved.

User direction (2026-11-13): future character/skill verification uses the Cross
Gate roster only. Limit mixed-roster fixtures to those cases when reusing them;
do not run old-character matrices or legacy-only regressions unless explicitly
requested. Keep shared gameplay, native army, pooling, save-data and preservation
checks relevant to Cross Gate. Preserve the existing legacy test references.
Historical all-42-character results do not set the scope of future testing.

## Native skill contacts — 2026-11-13

```sh
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/crossgate_blast_coverage_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/crossgate_native_skill_pattern_test.gd
```

The first fixture compares empowered 乾坤 with each of the nine Cross Gate
fighters' actual basic attacks: contact count, total/split damage, body-centred
confirmed-hit explosions, no cosmetic splash, misses, lethal retirement and
combo opening audio/overrides. The second checks all eight ranged attack skills
on all nine casters, using their native animation/contact markers and split
volley damage. It also checks per-hop combo totals and cancellation. Logs and
side-view captures are in `build/Other Files/Shin Sword Contact/`; the first
fixture's recorded starting shine is in `build/Other Files/Native Sure Strike/`.

Qigong, Moon, element and spirit entrypoints now select their cases from the
shared native-pattern matrix. Previous donor-specific cast-clock fixtures are
preserved as historical references under `reference/skill-timelines/`; their old
single-release timings are superseded, not fresh passing results. Native Shin
skins/weapons, Maze techniques, combo balance, lethal/far retargeting, borrowed
skills, food, sizes, projectile counts and simultaneous allies have focused
companion fixtures. No app export is required.

## Consistent skill sizes and centred impacts — 2026-11-13

```sh
"/Users/eric/Desktop/Play Goemon.command" --headless --script res://tests/forest-shrine/skill_size_consistency_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/skill_size_consistency_test.gd
```

Checks native and borrowed 氣功彈/gold Qi/追月 on the nine Cross Gate receivers, fixed base
sizes (Qi art at 30% of the original base diameter, with unchanged hit coverage),
zero/twenty food servings, body-centred charge, retained palettes and
in-flight snapshots. Real native contacts verify extra coverage, one hit per
victim/projectile, cover exclusion and counter growth. Desktop-only checks read
actual MultiMesh transforms from four off-axis camera views, comparing projected
centres and apparent width for both combo sheets, 乾坤 and 諸刃. Headless's dummy
renderer cannot read those transforms; it does not establish visual correctness.
Captures and logs: `build/Other Files/Skill Size Revision/`. Existing volley tests
also exercise repeated use, native allies, cooldown, ground following and walls.
The primary-retarget fixtures disable splash explicitly, since larger attacks
can otherwise hit several nearby enemies in one contact.

## Venoa bear-cave archive route — 2026-11-12

```sh
python3 tests/forest-shrine/test_venoa_archive.py
"/Users/eric/Desktop/Play Goemon.command" --headless --script res://tests/forest-shrine/freyja_villages_habaru_test.gd -- --venoa-cave
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/freyja_villages_habaru_test.gd -- --venoa-cave
```

The Python checks compare all 24,000 client collision cells and the eight original
inter-floor warps, using the adjacent `Magic Power` archive. The playable check
enters from Falan, crosses both original stair pairs, visits Venoa Village, returns
through the cave and traverses the miners' shortcut in both directions. It checks
the exact runtime masks, original NPC/stair placements, native 32/40/32 bear counts,
Great Bear damage/death persistence and ceilings. The test gives Kaz temporary
health for the boss-contact check so a killing hit cannot invalidate subsequent
walking checks. Captures: `build/Other Files/BlueCG Map Study/Venoa Restoration/`;
logs: `build/Other Files/venoa-restoration-{headless,desktop}.log`.

`venoa_bear_road_test.gd` extends that fixture: `--venoa-cave` checks repeated
native population ticks and added bear slain flags; `--venoa-undersea` checks
both complete original outdoor paths, ambient road clearance and cave returns.
`test_venoa_archive.py` also checks all 2,402 recovered surrounding placements,
193/79 road cells and the stable original bear-slot prefix. Current logs and
preservation/audit results are under `build/Other Files/Asset Toolkit/Venoa Bear Road/`;
road captures are under `build/Other Files/BlueCG Map Study/Venoa Bear Road/`.

Run checks from the source checkout being changed. The desktop game launchers point at the complete painterly source; see [the project README](../../README.md).

These are test entry points, not a record of the current build passing. Read each script's setup and flags before running it. Some older fixtures encode historical maps or balance defaults; assess failures against the behavior being changed.

## Focused checks

Il/Alyut texture wrapping and the connected canal bridge:

```sh
python3 tests/forest-shrine/test_village_building_surfaces.py
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/village_building_wrap_test.gd -- --il-habaru-alyut
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/east_bridge_connected_test.gd -- --east-il-road
```

Both Godot checks accept `--headless` before `--script`. The wrap test measures
UV density and feature aspect after fitting, visits every village doorway and
captures each distinct building from four sides. The bridge test checks that the
same terrain/world/bridge/native monster handles survive walking both directions.
Captures/logs are under `BlueCG Map Study/Building Wrap/` and `Connected East Road/`.
Run `scenery_canopy_chunks_test.gd` through Play Goemon to verify that spatial
tree batches preserve every transform and shared material. Desktop rendering is
required for GPU transform checks; headless verifies counts and material sharing.

Run `connected_villages_test.gd -- --east-il-road` through Play Goemon to check
Il and Alyut as part of their surrounding outdoor maps. It walks all three gates
both ways with identical world/army handles, verifies all source village ground
heights, thirteen buildings and NPC counts, visits eleven interiors and both
Habaru entrances/exits, and captures outward views. It also accepts `--headless`.
Evidence is under `BlueCG Map Study/Connected Villages/`.

Habaru cave wayfinding and native Il/Alyut village dressing:

```sh
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/habaru_wayfinding_test.gd -- --il-habaru-alyut
```

Also accepts `--headless` before `--script`. Checks both cave cutouts and normal
walking camera framing, the twelve trail checkpoints, centre and both-side entry
at both enlarged cave mouths, all eleven village doorway round trips, original
grass/plant reuse, round-house wall orientation and exclusion of authored frontage furniture. Captures
are under `build/Other Files/BlueCG Map Study/Habaru Wayfinding/` and
`build/Other Files/BlueCG Map Study/Village Fidelity/`.

Focused Explore visual-source integration (no walkthroughs or screenshots):

```sh
python3 tools/recover_venoa_walls.py --check
"/Users/eric/Desktop/Play Goemon.command" --headless --script res://tests/forest-shrine/explore_southern_walls_test.gd
```

Checks fourteen weathered wall variants, cache sharing, finite geometry/normals,
local batches, the two-armed corner, all 164 Venoa wall plans and preservation
of their old physical shapes. It also compiles the existing village fixtures
against the shared compound Il guild. Appearance remains for in-game review.

The area continuation adds these focused checks without captures:

```sh
python3 tools/recover_venoa_buildings.py --check
python3 tests/forest-shrine/test_venoa_paint.py
"/Users/eric/Desktop/Play Goemon.command" --headless --script res://tests/forest-shrine/explore_venoa_buildings_test.gd
python3 tools/recover_ghana_fronts.py --check
"/Users/eric/Desktop/Play Goemon.command" --headless --script res://tests/forest-shrine/explore_ghana_fronts_test.gd
```

The Venoa fixture checks six source-specific forms across seven placements and
their seven original physical shapes. Ghana checks eight reused building pieces,
46 source wall pieces and all 52 old physical shapes. Source RGB checks protect
dark interiors while excluding the original checkerboard ground shadow. These
checks do not certify appearance or a full Explore match.


乾坤 / 諸刃 red and blue burst visibility:

```sh
"/Users/eric/Desktop/Play Goemon.command" --headless --script res://tests/forest-shrine/sure_strike_visibility_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/sure_strike_visibility_test.gd
```

Checks camera-edge origins, panning, map visibility, bounded effect capacity,
repeated Shin/Bog numbered casts, charge interruption and resource reuse.
Captures and logs belong in `build/Other Files/Sure Strike Visibility/`.


Shared bear summon / 連擊 and unlocked Cross Gate loadouts:

```sh
godot --headless --path . --script res://tests/forest-shrine/shared_crossgate_skills_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/shared_crossgate_skills_test.gd
```

Checks all 42 playable fighters, Bog/Shin/Shin Special's editable rows, saved
assignments and native-slot restoration, icons, actual input, weapon-only audio,
native bear accumulation, eight distinct combo contacts, streak damage, cooldown
preservation, cancellation and repeated resource reuse. These two shared skills
are player controlled; allied copies retain their existing automatic attack list.
Evidence belongs in `build/Other Files/Shared Cross Gate Skills/`. Bog's native
regression uses clear arena ground and a camera that contains the full effect;
solid cover still blocks effect placements and damage in production.

連擊 and Bee Flurry overkill:

```sh
"/Users/eric/Desktop/Play Goemon.command" --headless --script res://tests/forest-shrine/combo_overkill_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/combo_overkill_test.gd -- --visual
```

The Cross Gate roster checks shared 連擊 and the five-hit Bee Flurry after a
one-hit kill; Kaz, Shin and Bog also check their underlying original combo controllers.
Native enemies die and award rewards immediately. Only an already-running
sequence retains that victim's body and exact contacts, then releases the normal
death animation. Post-death contacts are cosmetic: no repeated damage, rewards,
splash, on-hit effects or ordinary targeting. The fixture covers cancellation,
shared corpse ownership, five simultaneous companion families, return/cooldown,
and deferred cleanup. `--visual` limits the desktop roster to Kaz, Shin, Bog and
Uru; headless defaults to all Cross Gate fighters. Evidence is under
`build/Other Files/Overkill/`. The older `combo_lethal_retarget_test.gd` is historical: its empty native-hotbar
and kill-every-hop assumptions no longer describe current loadout/overkill rules. Native assert suites are `bee_flurry_test.cpp` and
`pet_skills_test.cpp`; they also cover native slot reuse and command cancellation.

Slime-sized 乾坤 / 諸刃 / 連擊, chest-centred shine and 親子丼 growth:

```sh
godot --headless --path . --script res://tests/forest-shrine/skill_food_growth_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/skill_food_growth_test.gd
```

Checks one-slime starting dimensions, shine size/body anchoring, additive permanent
food stacks, cast snapshots, actual extra native contacts at 20 servings, utility
exclusions and repeated resource reuse. Captures use the same prepared animation
frame and a real standard slime for comparison. `shared_crossgate_skills_test.gd`
checks the starting shine's size and chest location on the nine Cross Gate receivers.
`exploration_loot_test.gd` covers actual run-preserving travel and all nine food
IDs; `food_magnet_test.gd` walks into 親子丼 without a pickup key. The HUD fixture
includes all six food icons. Evidence: `build/Other Files/Skill Growth/`.

Slime starting stats and stronger returns:

```sh
godot --headless --path . --script res://tests/forest-shrine/crossgate_slime_test.gd -- --crossgate-pet-test --painterly-preview --test
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/crossgate_slime_test.gd -- --crossgate-pet-test --test
# Add --large to exercise the large arena.
```

Checks 700 starting HP, 20 damage, three compounded 10% returns held until the
next wave boundary with real
native melee, independent simultaneous deaths, stale-hit rejection, all 29
appearances per active entrance, the 30-second schedule, sides opening at
0/60/120/180 seconds, the unchanged 928-unit cap,
blocked return queues, defeat and fresh-run reset. Ordinary-mode regression
uses the excluded historical valley fixture. Logs belong in
`build/Other Files/Slime Rebirth/`; rendered captures use
`build/Other Files/Asset Toolkit/Cross Gate Slimes/Survival/`.

Bog's key-3 cave-bear guards:

```sh
godot --headless --path . --script res://tests/forest-shrine/bog_cave_bears_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/bog_cave_bears_test.gd
```

Checks five-per-press accumulation, 30,000 HP, 3,000 damage, fast native pursuit,
20/30/60 Hz guarding, hound-order/card isolation, deaths, repeated reuse and run
cleanup. It also checks three replacement groups with scattered pursuits and
actual damage on visible slimes, lone-enemy sharing and stable resource counts.
The desktop path adds live repeated casts and rendered captures.
Evidence belongs in `build/Other Files/Asset Toolkit/Cross Gate Bog/Cave Bears/`.

Run-only Qi upgrade paths, with cards disabled for normal play:

```sh
godot --headless --path . --script res://tests/forest-shrine/qi_upgrades_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/qi_upgrades_test.gd
godot --headless --path . --script res://tests/forest-shrine/team_progression_test.gd
```

The fixture first checks that cards default off and XP advances without offers,
then enables cards only in its isolated settings file. It covers real card
buttons, custom-baseline previews, both Qi variants, independent count/radius
paths, rarity caps, native contacts, allied exclusion, switching, new-run reset,
unchanged saved baselines and overlapping 48-orb pool reuse. Captures at 1280×800
and 960×640 and logs belong in `build/Other Files/Qi Upgrades/`. The existing
leveling/catalog fixtures explicitly enable cards for their own checks.

Shared/native skill baselines and projectile/target counts:

```sh
godot --headless --path . --script res://tests/forest-shrine/skill_baselines_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/skill_baselines_test.gd
godot --headless --path . --script res://tests/forest-shrine/skill_balance_test.gd
```

Checks catalog defaults, integer validation, separate saves/reset, UI baseline
labels, cast snapshots, actual native contacts, independent visual/hit-area
settings, 1/8/12/32 Qi orbs, the other Cross Gate counts, native combo/kunai/
arrow limits, overlapping high-count casts and five simultaneous allied owners.
The fixture selects open level ground using real landing and visibility checks
on Wind Meadow. Evidence belongs in `build/Other Files/Skill Baselines/`.
Counts add projectiles/targets; elemental per-target hit pulses retain their
existing source timing. The shared-skill fixture also handles native spells
that are available in the catalog but not currently assigned to a default key.

Per-character 連擊 size and splash baseline:

```sh
godot --headless --path . --script res://tests/forest-shrine/crossgate_combo_balance_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/crossgate_combo_balance_test.gd
```

Checks independent character defaults, validation, editor controls, save/reload,
reset, cast snapshots, actual native contacts with splash disabled or expanded,
effect size, shared-glow restoration and bounded repeated reuse. The graphical
run captures the settings and tuned hit effects at 1280×800. Evidence belongs in
`build/Other Files/Combo Balance/`. Original Kaz and Shin skill fixtures remain
separate regression checks; use the desktop renderer for sprite-transform review.

Automatic Guard/Cannon Towers:

```sh
godot --headless --path . --script res://tests/forest-shrine/automatic_towers_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/human_cannon_tower_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/human_cannon_tower_test.gd -- --large
```

Checks empty-tower volleys, worker reservations, cooldowns, saved volley settings,
team upgrades, visibility/death guards and map restart. The graphical fixture
checks actual native Guard/Cannon hits, unchanged splash/cover and repeated
16-shell presentation with stable node/resource counts. Logs for the worker-free
change are under `build/Other Files/Automatic Towers/`; rendered captures remain
under `build/Other Files/Asset Toolkit/Human Cannon Tower/`.

Editor navigation, entry/discard and palette switching:

```sh
godot --headless --path . --script res://tests/forest-shrine/map_editor_navigation_document_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/map_editor_navigation_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/map_editor_navigation_test.gd -- --large --live
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/map_editor_navigation_test.gd -- --large --entry-only
```

The document fixture compares road/portal local checks with complete validation,
including both map sizes, scenery/gates/edges, limits, atomic commits, saved-picker
validation and canonical asset-cache aliases. The desktop fixture measures actual
pan frames, all 22 palette hotkeys and repeated pinch input. `--live` retains the
normal game process plus a timed editor probe; otherwise it times the editor
callback directly. `--entry-only` checks repeated open/discard, restored run data,
scene reuse and bounded resources. `--layout=/absolute/path.json` reads a specific
map without writing it; `--saved` prefixes that run's output filenames. `--baseline`
labels reference captures and skips new-path timing/reuse assertions; it does not
restore old production code. Capture/log/JSON output belongs under
`build/Other Files/Map Editor Navigation/`. GPU timing may be unavailable; preserve
frame outliers and other desktop load when reporting results.

Building edit responsiveness and shared editor zoom:

```sh
godot --headless --path . --script res://tests/forest-shrine/map_editor_responsiveness_test.gd -- --document-only
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/map_editor_responsiveness_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/map_editor_responsiveness_test.gd -- --large
```

Checks local/full building validation agreement, all five building types and
rotations, incremental/fresh navigation grids and weights, normal worker release,
retained terrain/structures/scenery, local plant clearance and exact restoration,
physical collision, undo/redo/delete, native Play map, bounded repeated edits, wheel/fractional
scroll/pinch/trackpad/+− input and text/UI/modal guards. Desktop runs capture the
building and close view. Reports belong under
`build/Other Files/Map Editor Responsiveness/`; operation timings are not FPS.

Terrain-module placement stalls and local refresh parity:

```sh
godot --headless --path . --script res://tests/forest-shrine/terrain_edit_reuse_test.gd
"/Users/eric/Desktop/Play Goemon.command" --audio-driver Dummy --script res://tests/forest-shrine/terrain_placement_performance_test.gd
"/Users/eric/Desktop/Play Goemon.command" --audio-driver Dummy --script res://tests/forest-shrine/terrain_placement_performance_test.gd -- --large
```

Compares incremental terrain edits with a complete model, including every team's
navigation grid, exact native terrain/obstacles, stacked scenery and distant cliff
cache retention. Live runs time actual placement validation, refresh, deletion and
next rendered frame; check retained base terrain/collision, local foliage,
bounded nodes/materials/resources and discard restoration. Reports belong under
`build/Other Files/Asset Toolkit/Modular Environment/`. `--baseline` labels a
reference and skips new reuse assertions; it does not restore old source. These
are edit latencies, not full-army FPS. Use the palette and modular fixtures for
interactive rotation/height/save/restart and player/native traversal coverage.

Expanded scenery catalog and meadow-style tree variants:

```sh
godot --headless --path . --script res://tests/forest-shrine/map_catalog_test.gd -- --document-only
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/map_catalog_test.gd -- --visual
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/map_catalog_test.gd -- --visual --large
```

Checks all thirteen additions, source mesh roots, batching/material contracts,
meadow canopy/wind, data allowlisting, adjacent rotated module edges, actual grid
hotkeys/placement/selection/resize/rotation, physical/native blockers, save/load,
delete/history, restart, native play and bounded repeated edits. Visual runs
capture all three tree forms and a ground-level active-game view. Asset audits,
protected source hashes, staged lossless passes and captures are under
`build/Other Files/Asset Toolkit/Map Catalog/`. The first failed fixtures are
retained diagnostics: roof hits exposed incorrect selection coordinates, and
an enlarged fence needed its clear rotation before its size change.

Map scenery authoring and editor responsiveness:

```sh
godot --headless --path . --script res://tests/forest-shrine/map_scenery_test.gd -- --document-only
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/map_scenery_test.gd -- --visual --profile
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/map_scenery_test.gd -- --visual --profile --large
```

Checks all nine number keys, keypad selection, page switching and empty slots,
text-focus protection, real placement/selection input, size/rotation, overlap/boundary rejection,
old map compatibility, local/full preview validation agreement, incremental/full
navigation agreement, unchanged scenery chunks, bounded repeated edits, save/load,
Play map, restart, both native teams' blockers and toolbar fit at three sizes.
The fixture uses temporary preferences/maps, avoids stealing keyboard focus and
forces its capture draws so a hidden window does not hang on a draw signal.
`--profile` times the previous full refresh operation on the same layout alongside
new scenery edits; these are edit latencies, not whole-game FPS measurements.
Logs and inspected captures belong under `build/Other Files/Map Scenery/`.

Simultaneous native ally crescent stress test:

```sh
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/crescent_battle_benchmark.gd -- --per-team=240 --allies=120 --duration=120 --scenario=open --map=wind_meadow_large --await-focus --profile-spikes "--out=/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Asset Toolkit/Crescent Battle/Repeat"
```

Maintains 240 enemies, 96 regular allies and 24 full hero allies through the
existing native lifecycle and pooled legendary owner. Three each of Goemon,
Musashi, Ben, Sasuke, Yae, Kojiro, Blademaster and Illidan keep their normal stats,
AI, attacks and approved effects. The inherited benchmark checks frame-time
thresholds, population, event delivery, simulation time and unchanged inputs;
the extra report records simultaneous attacks/crescents and per-second resources.
Keep the window foreground and avoid other profiling/tests during measurement.
The current 24-hero result fails the smoothness thresholds; see the fresh evidence
and remaining limits in [the performance guide](../../docs/goemon-performance-guide.md).
`army_retirement_test.gd` protects bounded queries between death and facade cleanup.

With `--await-focus`, both simulation owners pause during focus loss. Reports keep
active `measurement_seconds`, total `wall_seconds` and `focus_wait_seconds` separate;
acceptance verifies their accounting and rejects any `changed_inputs`. The focused
`army_benchmark_coverage_test.gd` and `benchmark_focus_hold_test.gd` cover these gates.

`goemon_hit_frame_cache_test.gd` and `kojiro_cosmetic_updates_test.gd` compare the
prepared effects with their reference behavior; desktop runs add pixel comparisons.
`shared_sphere_test.gd` checks geometry/material isolation, and
`warcraft_material_updates_test.gd` checks original opacity and texture pages.
`melee_assist_local_test.gd` compares acquisition/order/retention against a full
240-enemy scan. Its standalone native-query shutdown warnings also occur in the
existing `army_candidate_marshalling_test.gd`; they are not counted as clean exits.

Illidan AI form commitment:

```sh
godot --headless --path . --script res://tests/forest-shrine/illidan_ai_form_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/illidan_ai_form_test.gd
```

Checks both manual Meta toggles, both AI toggle inputs during cooldown, five
native recruits making repeated random choices, real bolt damage, bounded pool
reuse, retirement and body reuse. AI transforms once and redirects later form
requests to its existing bolt attack. Evidence belongs under
`build/Other Files/Asset Toolkit/Illidan AI/`. This is a behavior regression,
not a full-army performance benchmark.

Statue-only presets and nearby ally attack audio:

```sh
"/Users/eric/Desktop/Play Goemon.command" --headless --script res://tests/forest-shrine/nearby_ally_audio_test.gd
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/nearby_ally_audio_test.gd
```

Checks both preset building lists, custom-tower preservation, the 15-metre
player/source boundary (including height), global and native ally cues, paired
voices, delayed/held spell ownership and repeated bounded reuse. The desktop
run also captures the actual nearby/distant SFX mix and statue-only opening
under `build/Other Files/Ally Audio/`. It is not a full-army performance test.

Enemy Skullpion statue objectives:

```sh
godot --headless --path . --script res://tests/forest-shrine/enemy_statue_model_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/enemy_castle_damage_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/enemy_castle_damage_test.gd -- --large
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/enemy_castle_placement_test.gd -- --visual
```

The model test proves source hashes, posed triangles and rotated statue bounds.
The castle fixture uses real melee/bullets, repeated hits, independent wall
breaches, destruction, collision removal, victory and restart. Placement covers
the shared statue ghost, new objectives, save/reload and enlarged maps. The
placement site is outside the raised castle's side stairs. Logs and sculpture
captures belong in `build/Other Files/Asset Toolkit/Skullpion Statue/`; battle
captures use `Asset Toolkit/Wind Meadow/Castle Breaches/` beneath Other Files.
These short fixtures do not establish full-army or long-session performance.

Musashi recovered sword techniques and one-press skills:

```sh
godot --headless --path . --script res://tests/forest-shrine/musashi_techniques_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/musashi_techniques_test.gd
```

Uses the current Wind Meadow terrain and native enemy contacts. Checks X Slash,
Tenderize and Desperado body phases, default keys 1–3, reassigned slots, miss and
interruption behavior, repeated use, and five allies executing mixed combos.
Captures and logs belong under `build/Other Files/Asset Toolkit/Musashi Techniques/`.
Manual player-step timings and physics callback intervals are diagnostics, not
rendered frame-time measurements or a full-army smoothness benchmark.
Run `musashi_assimilation_test.gd` and `numbered_skills_test.gd` after changing
the hotbar; existing assimilated skills remain selectable through Skills & Jump.

Equippable Musashi Leaping Strike:

```sh
godot --headless --path . --script res://tests/forest-shrine/musashi_leaping_strike_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/musashi_leaping_strike_test.gd
```

Checks manual double jumping, airborne attack overrides, ground attacks, native
enemy damage, landing, unequipping and interruption, Goemon/Rogue borrowing,
twelve repeated casts and five simultaneous native allies. Rendered captures
and logs belong in `build/Other Files/Asset Toolkit/Musashi Leaping Strike/`.

Saved-map regression for the retired raised courtyard and four side stairs:

```sh
godot --headless --path . --script res://tests/forest-shrine/raised_castle_test.gd
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/raised_castle_test.gd
```

Both sizes verify the 124.8-metre-wide courtyard at 41.6 metres elevation
(30% larger in each horizontal dimension and 30% higher), unchanged outer terrain and wall bases,
raised structures, disabled doors, saved-map compatibility, editor round trips
and map expansion. All six ordinary enemy types climb from every side, enter and
damage the actual shrine through native targeting, without manual movement goals.
The real player controller walks up every staircase without jumping. Desktop
captures and short simulation diagnostics go under
`build/Other Files/Castle Side Stairs/`; these are not full-battle frame timings.

Random map reinforcements (up to three ordinary enemies each second, alongside castle arrivals):

```sh
godot --headless --path . --script res://tests/forest-shrine/random_enemy_spawn_test.gd
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/random_enemy_spawn_test.gd -- --visual
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/random_enemy_spawn_test.gd -- --visual --large
```

The fixture checks timing, all ordinary roster types, exact counts, blocked
placement, shared capacity, pause and older saved castles with closed gates.
Desktop checks collect at least thirty mixed arrivals within twenty attempts,
cover all four quadrants including off-road ground, and require every native
enemy to attack real castle defenses. Blocked ground can reduce or defer a group.
Five identical spawn/retire cycles after a warm-up check reuse of the
existing spatial render batches and idle node/resource counts. Castle targets
stay alive for route verification. Timings are manually stepped diagnostics,
not full-battle frame times. Current captures/reports go under
`build/Other Files/Random Enemy Spawns/Anywhere/`; diagnostic logs are in
`build/Other Files/Random Enemy Spawns/raised-castle/`.
The castle group fixture isolates its own release gates with a stopped map-arrival
clock; the random-arrival fixture verifies both sources share one roster.

Kill reinforcements (each native enemy defeat adds two random ordinary enemies):

```sh
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/kill_reinforcements_test.gd
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/kill_reinforcements_test.gd -- --large
```

The fixture covers actual native kills, another generation from a spawned enemy,
simultaneous deaths, nonlethal/duplicate hits, ally deaths, cleanup, pause/reset,
blocked/partial placement, capacity retries and unchanged scheduled wave counts.
It verifies supported routes on both real map sizes and repeated spawn/retire reuse.
Evidence goes under `build/Other Files/Kill Reinforcements/`. Placement timings
are focused diagnostics, not a full-battle frame-rate or long-session benchmark.
The fixed-roster army benchmark clears this gameplay queue when replacing deaths
so its historical unit-count contract stays explicit.

Permanent card heroes defending the castle and hills across a wave reset:

```sh
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/legendary_hero_hunting_test.gd
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/legendary_hero_hunting_test.gd -- --large
```

Both sizes summon all five heroes through the actual card choice, verify native
outside-area rejection, hill-intruder acquisition, attacks/damage, reacquisition
after preparation and return home when a live target escapes. Captures and short
stepped CPU/resource reports go under `build/Other Files/Castle Defense AI/`
with the `Heroes-` prefix. This is not a full-battle
frame-time benchmark. The native `mirror_test.cpp` also covers wave persistence,
temporary-skill waiting and pursuit around cover on a hill at 20/30/60 Hz.

Paid mercenaries defending the castle and four hills on real Wind Meadow routes:

```sh
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/mercenary_hunting_test.gd
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/mercenary_hunting_test.gd -- --large
```

The fixture recruits all five kits, rejects distant enemies, verifies fresh damage
at each hill approach and checks return to castle posts and preparation. It
retains Ninja executions and replenishes the frozen soldier when needed. Short
stepped CPU timings and idle resource checks are focused diagnostics, not
full-battle frame times. Captures and reports go under
`build/Other Files/Castle Defense AI/`. `enemy_castle_pathing_test.gd` also checks
baseward progress, player interception and resuming shrine damage after the
player becomes untargetable. Closed gates and military buildings are tested when
present in the selected layout; the current open raised castle has neither.

Core state and map serialization:

```sh
godot --headless --path . --script tests/forest-shrine/model_test.gd
godot --headless --path . --script tests/forest-shrine/map_document_test.gd -- --test
```

Choose additional `*_test.gd` scripts for the affected feature. Native render, captured-pointer, shader, and visual checks require a real window. The commands retained below include both headless and native variants; they are alternatives, not a mandatory full-suite sequence.

Shared footstep cadence, including extreme movement speed and desktop audio:

```sh
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/footstep_cadence_test.gd
```

This checks the .30-second per-Hero audio limit without changing movement or
source samples. Recordings and logs go under
`build/Other Files/Asset Toolkit/Footstep Speed Limit/`.

Wave settings edited from the building map apply on START; edits during battle
apply to the next run. The focused fixture uses an isolated settings file and
checks actual UI edits, persistence, exact first-wave types/counts, native arrivals,
group settings, the countdown and active-run isolation:

```sh
godot --headless --path . --script res://tests/forest-shrine/wave_settings_test.gd
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/wave_settings_test.gd
```

Evidence goes under `build/Other Files/Asset Toolkit/Wave Settings/`.

Timed waves and the top-center countdown (first arrival on START, then every 60 seconds):

```sh
godot --headless --path . --script res://tests/forest-shrine/wave_timer_test.gd
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/wave_timer_test.gd -- --visual
```

The desktop fixture advances the real schedule through four arrivals, verifies native
ownership, pause and balance updates, and captures two window sizes/HUD scales.
It does not run a four-minute battle or measure full-army performance. Evidence goes
under `build/Other Files/Asset Toolkit/Wave Timer/`.

Team leveling and rendered card/reset acceptance:

```sh
godot --headless --path . --script res://tests/forest-shrine/team_progression_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/team_leveling_gameplay_test.gd
```

The [team leveling spec](../../docs/team-leveling-spec.md) records the initial
curve, shared bonuses, and reset semantics. Logs and captures belong under
`build/Other Files/Team Leveling/`.

## Human Cannon Tower

```sh
godot --headless --path . --script res://tests/forest-shrine/human_cannon_tower_test.gd
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/human_cannon_tower_test.gd
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/human_cannon_tower_test.gd -- --large
```

Checks the original sound bytes/imported PCM, both Human tower choices, placement,
worker garrison/repair/release, native splash bands and cover, actual worker firing,
target death during flight, upgrades, map roundtrip, pause and repeated pooled
volleys. Desktop runs capture the model, build menu and original missile burst.
The short manually stepped 16-shell volleys report frame/work timings and resource
counts; they are not a full-army or long-session benchmark. Evidence is under
`build/Other Files/Asset Toolkit/Human Cannon Tower/`.

## Dark Lumina 3 Water bubbles

Run `/Users/eric/Desktop/Play Goemon.command --script res://tests/forest-shrine/dark_lumina_3_water_test.gd`.
Checks floor/enemy contacts, silent expiry for both bubble generations, five radial
children on parent contact, secondary contact pops, pooled state reset, numbered
and borrowed Water, and nine accelerated ground/airborne volleys. Captures and
allocation/frame diagnostics go to `build/Other Files/Asset Toolkit/Dark Lumina 3/Water Contact/`.
The standalone `native/terrain_math/crowd/dark_lumina_3_test.cpp` also checks six
simultaneous bosses at 20/30/60 Hz: primary expiry, ground splits with silent child
expiry, and child wall contacts.

## Existing command reference

```sh
godot --headless --path . --script tests/forest-shrine/portals_roads_test.gd -- --test
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/portal_editor_test.gd -- --test
godot --path . --resolution 960x600 --fixed-fps 60 --script tests/forest-shrine/portal_editor_test.gd -- --test --visual
godot --headless --path . --script tests/forest-shrine/map_document_test.gd -- --test
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/map_editor_test.gd -- --test
godot --path . --resolution 960x600 --fixed-fps 60 --script tests/forest-shrine/map_editor_test.gd -- --test --visual
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/ddii_combat_view_test.gd -- --test
godot --path . --fixed-fps 60 --script tests/forest-shrine/ddii_combat_view_test.gd -- --test --visual
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/crosshair_preference_test.gd -- --test
godot --path . --fixed-fps 60 --script tests/forest-shrine/crosshair_preference_test.gd -- --test --visual
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/view_settings_test.gd -- --test
godot --path . --fixed-fps 60 --script tests/forest-shrine/view_settings_test.gd -- --test --visual
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/character_framing_test.gd -- --test
godot --path . --fixed-fps 60 --script tests/forest-shrine/character_framing_test.gd -- --test --visual
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/ninja_hit_drift_test.gd -- --test
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/training_dummy_test.gd -- --test
godot --path . --fixed-fps 60 --script tests/forest-shrine/training_dummy_test.gd -- --visual
godot --headless --path . --script tests/forest-shrine/compact_loadout_hud_test.gd -- --test
godot --path . --script tests/forest-shrine/compact_loadout_hud_test.gd -- --visual
godot --headless --path . --script tests/forest-shrine/hud_cleanup_test.gd -- --test
godot --headless --path . --script tests/forest-shrine/hud_polish_test.gd -- --test
godot --headless --path . --script tests/forest-shrine/low_fidelity_enemies_test.gd -- --test
godot --path . --script tests/forest-shrine/low_fidelity_enemies_test.gd -- --test
godot --path . --script tests/forest-shrine/dense_crowd_profile.gd -- --test --out=/tmp/forest-low-fidelity-profile
godot --headless --path . --script tests/forest-shrine/melee_responsiveness_test.gd -- --test
godot --path . --script tests/forest-shrine/melee_responsiveness_test.gd -- --test --visual
godot --headless --path . --script tests/forest-shrine/core_balance_test.gd -- --test
godot --headless --path . --script tests/forest-shrine/preparation_actions_test.gd -- --test
godot --path . --script tests/forest-shrine/preparation_actions_test.gd -- --test --visual
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/hud_polish_test.gd -- --test
godot --path . --script tests/forest-shrine/hud_portrait_render_test.gd -- --test
godot --path . --script tests/forest-shrine/hud_polish_tour.gd -- --test
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/hud_cleanup_test.gd -- --test
godot --path . --script tests/forest-shrine/hud_cleanup_tour.gd -- --test
godot --headless --path . --script tests/forest-shrine/south_spawn_test.gd
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/starter_fort_test.gd
godot --path . --script tests/forest-shrine/starter_fort_render_test.gd -- --test
godot --path . --script tests/forest-shrine/starter_fort_tour.gd -- --test
godot --headless --path . --script tests/forest-shrine/giant_staging_performance_test.gd
godot --headless --path . --script tests/forest-shrine/enemy_contact_performance_test.gd
godot --path . --script tests/forest-shrine/enemy_spawn_performance_test.gd -- --test
godot --headless --path . --script tests/forest-shrine/model_test.gd
godot --headless --path . --script tests/forest-shrine/simulation_test.gd
godot --headless --path . --script tests/forest-shrine/world_test.gd
godot --headless --path . --script tests/forest-shrine/integration_test.gd -- --test
godot --headless --path . --script tests/forest-shrine/lifecycle_test.gd
godot --headless --path . --script tests/forest-shrine/rogue_test.gd -- --test
godot --headless --path . --script tests/forest-shrine/definitive_test.gd
godot --headless --path . --script tests/forest-shrine/transition_test.gd -- --test
godot --headless --path . --script tests/forest-shrine/fog_target_test.gd -- --test
godot --headless --path . --script tests/forest-shrine/review_regression_test.gd
godot --path . --script tests/forest-shrine/integration_test.gd -- --test --visual
godot --path . --script tests/forest-shrine/definitive_test.gd -- --forest-title --visual
godot --headless --path . -- --tower-defense-test
godot --headless --path . -- --rogue-siege-tests
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/crosshair_test.gd
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/modern_combat_test.gd
godot --path . --script tests/forest-shrine/crosshair_tour.gd
godot --headless --path . --script tests/forest-shrine/enemy_roles_test.gd
godot --headless --path . --script tests/forest-shrine/enemy_visual_test.gd
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/enemy_contact_test.gd -- --test
godot --headless --path . --script tests/forest-shrine/enemy_integration_test.gd
godot --path . --script tests/forest-shrine/enemy_integration_tour.gd -- --visual
```

Check assertion/result markers, process exit status, and Godot script/render errors. A historical pass count or screenshot is not proof that the current source passes. Store newly generated captures, logs, and reports in `build/Other Files/` when the harness supports an output path. Keep bundled presets, custom maps, preferences, and user recordings intact.

Combined attack presentation: run `combined_attack_layers_test.gd` for original
quads, palettes, compact-weapon sampling, repeated resource reuse and all 83 bake
hashes. Run `strong_melee_brush_test.gd` through Play Goemon for the 19 melee
presentations and native ally repeats. `--fighters=28` also checks Kojiro's three
forward cuts across facing, reach and frame-rate cases, rear-windup suppression,
rendered outer-edge direction and retained glow.
`--output=res://build/Other Files/Asset Toolkit/Roster Combined/` selects the
current evidence folder; run without `--headless` for captures.

24-hero follow-up: `crescent_battle_benchmark.gd` keeps 24 pooled full heroes
among 120 allies against 240 enemies. Its fixture-only fixed logical IDs retain
native AI seeds across allocation changes. Live combat still depends on render
cadence: do not present separate runs as a controlled percentage speedup. Run
through Play Goemon, `-- --per-team=240 --allies=120 --duration=120 --scenario=open
--map=wind_meadow_large --await-focus --profile-spikes --out=<absolute folder>`.
`--diagnostic` saves failures with exit zero; always inspect report errors.

`sky_strike_direction_test.gd` covers overlapping-target facing/landing.
`prepared_rom_pose_test.gd` checks exact prepared versus original JSON sampling.
`character_profile_keys_test.gd` checks cached keys and live profile edits.
`kojiro_cosmetic_updates_test.gd` compares original cosmetic motion, pooling and
atlas cells; run through Play Goemon for reference pixel comparisons. Its
headless pass covers logic, not rendering or smoothness.

`maze_kunai_aim_test.gd` is the focused regular-pair regression under the current
skill rules. It covers independent aim and native damage, nearest alternate
selection, one/no enemies, cover, windup death, shared chain credit, repeated
pool/target cleanup, nine simultaneous copies and Saizo's unchanged single
kunai. Run `/Users/eric/Desktop/Play Goemon.command --script
res://tests/forest-shrine/maze_kunai_aim_test.gd` (add `--headless` for logic).
Captures go to `build/Other Files/Asset Toolkit/Maze Kunai Aim/`. The older broad
`crossgate_maze_test.gd` still contains historical fixed-skill expectations;
its earlier failures can leave extra targets in subsequent checks.

`crossgate_lancelot_test.gd` covers all eight original bow skins, source release
markers/audio, kunai-style auto-aim, cover/range, moving fire, pooled reuse,
key 1 亂射 shine/rapid retargeting/cooldown/cancellation and five simultaneous
native ally volleys. Run with `/Users/eric/Desktop/Play Goemon.command --script
tests/forest-shrine/crossgate_lancelot_test.gd` for rendered captures. Reports
are under `build/Other Files/Asset Toolkit/Lancelot/`; no app export is needed.

`lancelot_arrow_explosion_test.gd` checks key 2's charged arrow flight and
impact-centered 乾坤 explosion, native direct/splash damage, cover, wall contact,
misses, cancellation and repeated pool reuse. Play Goemon captures and logs are
under `build/Other Files/Lancelot Arrow Explosion/`.

`lancelot_shadows_test.gd` checks native keys 2/5/6, the original bow pose for
乾坤, 陽炎, five stationary 30-second barrage shadows, caster damage/upgrades,
simultaneous native contacts, reuse and expiry/death/switch cleanup. Run through
Play Goemon for rendered review; evidence is in `build/Other Files/Lancelot Shadows/`.

## Shared pet levels and attack audio

Run `/Users/eric/Desktop/Play Goemon.command --script res://tests/forest-shrine/pet_scaling_test.gd -- --crossgate-pet-test`. The fixture compares original/new level-one output, tests three five-pet packs against 116 attacking slimes at levels 1/10/30/99 without cards, then checks live XP, wounded HP, replacement, UI, pooled sound priority/gain and repeated resource use. `--native-only` skips the live fixture; `--live-only` skips the combat matrix. Evidence goes to `build/Other Files/Pet Scaling/`. Card-heavy and long-session balance remain separate work.

## Kili and Venoa buildings and rooms

Run `freyja_villages_habaru_test.gd` through Play Goemon with `-- --coastal-kili`
and `-- --coastal-venoa`. These traverse every original building/room link on
foot without F, compare recovered fixture and NPC counts, check source-specific
building meshes and capture exteriors, shops, hospitals, residences, kitchens
and teleport rooms. `-- --freyja-scale --gate-exteriors` checks all three Falan
crossings and walkable water; `-- --undersea-portals` checks the four cave mouths.
Evidence is in `build/Other Files/BlueCG Map Study/Coastal Village Rooms/`.
The fixtures use the existing saved venture without writing it. The four Kili
houses 3801/2/3/7 use recovered server maps; their captures are under
`BlueCG Map Study/Kili Original Houses/`. Asset-toolkit `test_kili_houses.py`
checks source hashes, distinct plans, door coordinates and malformed map rejection.
The server's control houses match the local Blue CG cache exactly; live Blue CG
variants of the four missing houses are not independently captured.

### Gentler arena opening and Cross Gate menus

Run `arena_menu_test.gd -- --crossgate-pet-test` through Play Goemon to check the
city → title → Arena · Slime Waves route, arena spawn, first slime pack and next
timed wave. Rendered evidence is in `build/Other Files/Arena Menu/`.

Run `slime_progression_test.gd -- --crossgate-pet-test` for cumulative wave counts,
entrance warnings, long-tick catchup, reset and preserved user balance overrides.
Run `crossgate_menu_test.gd -- --crossgate-pet-test` through Play Goemon for rendered
title, character/loadout/pet, settings/pause, upgrade and wave-HUD checks at
1280×800 and 960×600. Evidence is in `build/Other Files/Cross Gate Menu and Waves/`.

### Automatic pet defense

`world_enemy_target_spread_test.gd` verifies three world-slime replacement groups
against visible pet defenders, real damage on different targets, stable living
pursuits and warmed presentation resource reuse. It retains committed enemy
strike timing and normal body spacing. Run through
`Play Goemon.command --script res://tests/forest-shrine/world_enemy_target_spread_test.gd`;
logs and the reviewed capture use `build/Other Files/World Enemy Target Spread/`.
Native `crowd/target_decision_test.cpp` additionally covers external/native target
sharing, priorities, random ties, commitment boundaries and distant fallback.

`pet_defense_test.gd` runs focused guard/hunt/recall regressions and five mixed
pets through repeated automatic defense and H recalls on Falan Arena. Run through
`Play Goemon.command --script res://tests/forest-shrine/pet_defense_test.gd` for
rendered evidence in `build/Other Files/Pet Defense/`. The standalone native
`crowd/pet_defense_test.cpp` covers threat priority, active attack preservation,
cover, range, dead/sheltered targets and repeated commands at 20/30/60 Hz. It also
checks five distinct replacement choices, stable living targets and randomized
ties for automatic pets and bears. Logs use `build/Other Files/Pet Target Spread/`.
Replacement checks cover all 82 selectable pet appearances at 20/30/60 Hz.
The desktop fixture additionally runs hound, mantis, dragon-lizard and two bee
appearances through three replacement groups with real damage, lone-enemy sharing
and stable prepared-resource counts. Its player is Kaz; commands and hold checks
remain in the same fixture. The new capture is `Pet Defense/mixed-pets-scattered-targets.png`.

The same focused fixture now checks physical F stationary defense, key release
keeping defense active, the readable “F Defend” HUD label, repeated orders,
contacts while the player leaves, no pursuit/roaming after kills, and
G/H release. Hold captures and final verification live in
`build/Other Files/Pet Hold/`. Native tests include stationary contact filtering
and blocked attacks; normal damage and knockback remain under native combat.

`freyja_villages_habaru_test.gd -- --entry-controls` checks F beside a real
Falan doorway, automatic entry/exit, removed prompts, and normal/low-tide cave
access. Run through Play Goemon for a rendered capture. Travel fixtures now use
`walk_through_entry()` instead of synthesizing the retired F entrance action.

`pet_stance_hud_test.gd` checks recovered Cross Gate sprite pixels, right-click/F/Z HUD
selection, default Follow, 90 allocation-stable changes, pet lifecycle, both HUD
styles, and small-window/scaled layouts. Run with Play Goemon for captures in
`build/Other Files/Pet Stance HUD/`.
`pet_toggle_test.gd` covers P summon/unsummon across all nine Cross Gate
fighters, including queued and partial arrivals, native worker completion,
skill retirement, preserved selections/learned levels, bears/enemies, wave counts
and the Attack / Defend / Back HUD order. Run
`"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/pet_toggle_test.gd -- --crossgate-pet-test`
(add `--headless` before `--script` for logic checks). Captures and logs go to
`build/Other Files/Asset Toolkit/Pet Toggle/`. The older stance fixture retains
its visor reference; routine pet-toggle verification uses Cross Gate fighters.

## Outdoor monster progression — 2026-11-12

Run the existing Falan fixture with its focused progression branch:

```sh
"/Users/eric/Desktop/Play Goemon.command" --headless --script res://tests/forest-shrine/freyja_villages_habaru_test.gd -- --patrol-progression
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/freyja_villages_habaru_test.gd -- --patrol-progression
```

It checks exact species bases, +0/+2/+4 area levels, all 428 native patrol
spawns across four outdoor maps, repeated attack damage, once-only kill XP,
the name/level-only crosshair label, repeated HUD reuse and pause/death cleanup.
Desktop captures go to `build/Other Files/BlueCG Map Study/Monster Progression/`.
Use `monster-progression-desktop-final.log` for the final requested label.
Cave/boss levels use the focused fixture below; arena waves keep their own rules.

## Cave monster progression — 2026-11-12

```sh
"/Users/eric/Desktop/Play Goemon.command" --headless --script res://tests/forest-shrine/cave_progression_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/cave_progression_test.gd
```

Fresh results: 853 headless / 866 desktop checks pass across twelve maps.
The fixture checks actual native HP, repeated damage contacts for every skin,
18/20/22 bear floor scaling, both Parukes phases and replacement rebels,
once-only kill XP, name/level-only targeting and HUD node reuse. It finds a
reachable representative contact and clear camera angle without bypassing
navigation or cover. Desktop captures and source provenance are in
`build/Other Files/Cave Progression/`; final logs are
`cave-progression-headless-final.log` and `cave-progression-desktop.log`.
See `docs/cave-monster-progression.md` for historical versus adapted levels.

## Food drops and scattered chests

Run `"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/exploration_loot_test.gd` (add `--headless` for logic-only verification). The fixture uses isolated settings and actual native cave, outdoor and arena-slime deaths; checks all six food effects, 600-second expiry/refresh, HP clamping, wall/pause/death pickup rules, chest placement/re-entry, native slime returns and repeated 64-slot bursts. Desktop runs save normal/small HUD and loot captures in `build/Other Files/Explore Loot/`. Source art and local balance rules are documented in `assets/items/crossgate/README.md`.

Food stacking: the same food fixture now checks additive stacks, refreshing shared ten-minute timers, max-HP clamp/reset and icon counts below health. Evidence is under `build/Other Files/Explore Loot/Stacking/`. `pet_stance_hud_test.gd` also keeps three food effects active while checking pet/skill spacing, HUD scale and the Master Chief visor; desktop captures go into that folder's `Pet HUD/` subdirectory.

`food_magnet_test.gd` checks the 7.5 m food pull, actual walking into range,
20/30/60 Hz motion, single collection, consuming all three healing foods at full HP
without overhealing, healing chests at full HP, walls,
height, pause/travel/death, unchanged chest interaction and repeated 64-food
collection without retained nodes/resources. Run through Play Goemon for moving
batch validation and captures under `build/Other Files/Food Magnet/`.

Movement/defense foods: `exploration_loot_test.gd` now covers all eight foods, real walking speed, flight scaling, armor-hit reduction and five food icons. `pet_stance_hud_test.gd` exercises the two-row food grid beside pets/visor at multiple HUD scales. Current evidence goes to `build/Other Files/Explore Loot/Movement Defense/`. The jump-style menu fixture uses currently selectable Kaz/Ruby and available Cross Gate fire when checking saved loadouts; it no longer assumes hidden Goemon/Sonic entries are exposed in that menu.

## Pet attack skills

Run `"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/pet_loadout_test.gd` (add `--headless` for logic-only checks). Each of the five party pets has three selectors offering None and ten existing attack skills. The fixture covers actual dropdown opening, distinct slots, invalid/duplicate/fourth assignments, migration from a single skill, save/reload/rollback, preparation/cleanup, small-window layout and repeated menu openings alongside native pet lifecycle checks. Evidence goes to `build/Other Files/Pet Skills/`. `forest_pet_skills` maps stable pet keys to three strings, retaining empty positions; all-empty entries are omitted.

Run the same launcher with `--script res://tests/forest-shrine/pet_attack_skills_test.gd` for actual native source contacts (one through six), all offered attacks, edited projectile/combo counts, lethal combo retargeting, random three-skill choices, Hold, death/recall/resummon and five simultaneous casters. It compares five ordinary pets and five equipped pets against twenty native slimes, checks warmed resources/pool capacity, and records a short desktop frame sample. Captures and logs go to `build/Other Files/Pet Skills/Three Slots/`. Desktop review uses Kaz; no legacy character gameplay is required. The native assert suite is `native/terrain_math/crowd/pet_skills_test.cpp`; compile with the same crowd sources/flags as the existing guard/pet-defense tests. The native suite checks all 82 skins at 20/30/60 Hz with synthetic timing; the Godot fixture checks actual recovered directional timings.

`pet_skill_levels_test.gd` checks independent per-pet skill-family levels at 1 and 30, real native contacts and projectile quotas, physical damage, original shine tiers, pointer purchases in I → Pets, shared points, other-pet/character isolation, selected unsummoned pets, empty packs, capped/invalid/unequipped skills, Shin/Gold Qi aliases, committed cast snapshots, all nine Cross Gate character switches, recall/loadout preservation, run reset and repeated five-pet casts without pool/resource growth. Run through Play Goemon with `--script res://tests/forest-shrine/pet_skill_levels_test.gd` (add `--headless` for logic checks). Captures go to `build/Other Files/Pet Skills/Independent Levels/`. The native pet suite also checks 1–128 count validation and capacity preparation for combined level/tuning counts. The earlier Shared Levels evidence is historical and superseded.

`portrait_xp_hud_test.gd` checks all nine painted Cross Gate head portraits, warm charcoal HUD panels, bounded 256-pixel imports, green normal-health fill, the purple EXP bar and actual level beneath the top-left character portrait, no bottom shortcut panel, fractional XP without numeric XP text, level-up/cap/reset, all nine Cross Gate fighters, I/Shift+P, food/pet/skill spacing at multiple window sizes and HUD scales, and repeated control/resource reuse. Run through Play Goemon with `--script res://tests/forest-shrine/portrait_xp_hud_test.gd` (add `--headless` for logic checks). Captures go to `build/Other Files/Painted Portrait HUD/`.


`falan_gate_shortcuts_test.gd -- --east-il-road` checks all 30 distinct city-stone
trips, E/Esc menu behavior, unchanged save/world/native army, solid shrine
geometry and three gate round trips. Rendered mode verifies base tile pixels and
independent far-distance mip colors. Use Play Goemon for the desktop pass.
Evidence: `build/Other Files/Asset Toolkit/Falan Travel Stones/`.

`travel_stone_3d_review.gd` renders four shrine angles and each solid component;
it also checks that the shared crystal visibly turns. The travel fixture now
asserts shared imported meshes, real depth and no retired billboard ornaments.
Current 3D evidence: `build/Other Files/Asset Toolkit/Falan Travel Stones 3D/`.

`skin_head_hud_test.gd` covers the current selectable Cross Gate model/skin combinations and their explicit painted-head routes. It verifies actual model IDs, loaded 256-pixel textures, XP preservation, cached resource reuse and app include filters. Desktop runs capture every source model beside its HUD head under `build/Other Files/Asset Toolkit/Painted Portrait HUD/Skins/`. Run through Play Goemon; use `-- --catalog` for source-only reference boards. Review the boards visually in addition to the assertions.


Shift + Space jump: run `crossgate_jump_test.gd` through Play Goemon for actual
modified Space events across the selectable Cross Gate roster and weapon poses.
It checks takeoff, air jump, jump limits, echo, guard release, pause, defeat,
landing audio and airborne hits. `plain_dodge_test.gd` also checks Shift + Space
against an active native threat before checking the unchanged plain Space dodge.
Evidence belongs in `build/Other Files/Asset Toolkit/Cross Gate Jumps/`.

Space timed-dodge trial: run `timed_dodge_test.gd` through Play Goemon for real
Space events with the preserved shadow branch explicitly enabled by the test.
That branch is dormant in normal gameplay; `plain_dodge_test.gd` verifies the
current default across all Cross Gate identities: move outward, stay out, leave
no guaranteed shadow/reward and keep the next left click ordinary. Successful
Space dodges also roll the existing Counter Chance once against the warning's
attacker. The fixture checks 0% and 100% across the roster, rejected/repeated
presses and protected contacts without duplicate counters. Its evidence goes to
`build/Other Files/Asset Toolkit/Timed Dodge/Plain/`.

`plain_dodge_crowd_profile.gd` compares attack-only and repeated plain Space
dodges in the full rendered Falan Arena Large with a maintained native crowd.
Run through Play Goemon with `-- --count=600 --seconds=45 --label=600-first`.
It keeps normal enemy stats/AI, painterly art and player auto attacks; protected
player/objective health and disabled XP upgrades are explicit diagnostics.
It records raw frame intervals, focus, simulation time, event delivery,
population, nodes/resources/memory and source fingerprints under
`build/Other Files/Asset Toolkit/Timed Dodge/Plain Crowd/`. At its explicit 0%
Counter Chance it asserts no Space
shadow or counter reward. It requires desktop rendering; it is not a
normal-health survival soak.

The opt-in shadow fixture covers
Space events across the current Cross Gate identities, early/late success,
icon-only cues, penalty-free empty presses, actual native hit delivery,
protection expiry, no jumping, pause, C and saved-style
preservation. A successful Space moves the real body outward over the existing
13 source ticks and leaves its prepared shadow at the original position.
The next accepted left click counters the exact native attacker from that
shadow anchor, at normal speed/damage with 50% extra melee reach. An early
click lets the outward body step finish. The fixture checks all Cross Gate
identities, six-enemy source stability, fixed 20/30/60 Hz distance, paused travel,
shadow/body separation, fist reach, wall rejection, bounded range, invalid
sources and warmed reuse;
right clicks, automatic attacks and rejected/paused clicks preserve the reward.
It checks no automatic return and death/character cleanup.
Desktop captures and diagnostics go to
`build/Other Files/Asset Toolkit/Timed Dodge/Shadow Counter/`. Native forecasting/cover checks
are in `native/terrain_math/crowd/timed_dodge_test.cpp`; existing independent stat
reactions remain covered by `dodge_counter_stats_test.gd`.

`joint_attack_test.gd` checks natural normal melee contacts between every Cross
Gate player identity and a real native pet, two-participant event attribution,
window expiry, excluded skill/projectile/counter tickets and the original 2–10
HitCombo glyphs. It also checks repeated/group-growing titles, whole-title
capacity rejection and the shared effect cap. Run through Play Goemon for
desktop captures; add `--headless` for logic. Evidence goes to
`build/Other Files/Asset Toolkit/Joint Attack/`. Native formula, guard,
participant/order/target isolation, bear/companion and lifecycle checks are in
`native/terrain_math/crowd/joint_attack_test.cpp`. Original atlas preservation
is checked by `tests/asset-toolkit/test_crossgate_joint_attack.py`.


Shin special skin and shared sprite regression (2026-11-15): run
`crossgate_shin_test.gd` through Play Goemon for all 22 regular / nine visible
special appearances, every native stance and all eight facings, real native
enemy contacts, windup/recovery, five simultaneous allies per special skin,
old Classic save compatibility and warmed resource reuse. Desktop swing/contact
captures and logs live in `build/Other Files/Asset Toolkit/Shin Skin Fix/`.
`crossgate_sprite_ground_test.gd` renders below-foot effects with/without ground
projection, checks translucent counter effects and tests a solid wall.
`counter_animation_test.gd` checks every frame and final recovery of each current
Cross Gate fighter's supported weapons, atlas/material changes and airborne
afterimage snapshots. Its Kaz strips compare the normal ground-safe counter
with the old unprojected rendering in `build/Other Files/Asset Toolkit/Counter Animation/`.
Run both through Play Goemon. `weapon_equipment_test.gd` also performs
actual attacks for every native appearance/weapon route across the nine Cross
Gate fighters; Maze uses its current Kaz-gallery appearance before equipment saves.
Bee Blink Flurry: run `bee_blink_flurry_test.gd` through Play Goemon for actual
desktop main/pet hit sequences, critical-only levels 1–30, invulnerability,
1.5× speed, repeated use and simultaneous native pets. Run
`bee_blink_flurry_levels_ui_test.gd` for point purchases and both level-30 caps.
The native clock/opposite-side/cancellation regression is
`native/terrain_math/crowd/bee_flurry_test.cpp`. Evidence belongs under
`build/Other Files/Asset Toolkit/Bee Blink Flurry/`.

Pet audio: run `pet_audio_test.gd` through Play Goemon for all 616 identities in
all eight native attack directions, prepared idle/movement/hurt/death cues,
actual bee movement and mixer capture, real damage/death timing, source-loop
voice reuse, pause/recording/range, recall cleanup and repeated five-pet use.
Evidence belongs under `build/Other Files/Asset Toolkit/Pet Audio/`.


### Uru complete appearance inventory

Run `crossgate_uru_inventory_test.gd` through Play Goemon for all 32 Uru
appearances and 182 supplied weapon combinations: source-key identity, atlas
bounds in eight directions, exact native damage, weapon cycling, save/reload, native
copies, fixed weapons and repeated resource/pool reuse. Desktop mode plays a
short source attack for each alternative and captures all weapons plus the
scrollable gallery. Review captures separately from assertions. Reports are in
`build/Other Files/Asset Toolkit/Uru Complete Inventory/`.
`crossgate_attack_outline_test.gd` sweeps the current Cross Gate roster, all
distinct appearances and their supplied weapons. It checks every prepared basic
attack frame in eight directions against the live sprite region, anchor,
texture and shader texture, verifies inactive body/counter copies, then runs a
real attack/recovery per identity. Desktop mode captures five native phases,
a front view and alternate weapon contacts on flat arena ground. The 2026-11-16
run passed 2,836 checks: 16 identities, 269 appearances, 1,390 weapon routes and
221,455 frame states. Review the 40 contact sheets independently of assertions;
reports live under `build/Other Files/Asset Toolkit/Cross Gate Attack Silhouettes/`.
Use `tools/audit_crossgate_attack_art.py '../Magic Power'` alongside it to catch
extra source pixels, wrong anchors and unsafe green-key texture imports.

`test_emilia_staff_outline.py` reproduces the old detached head/hair contour,
checks filled staff silhouettes, neighboring ice pixels and all 40,573 original
Puck attack pixels. `emilia_attack_motion_test.gd` replays every prepared staff
frame in all eight facings for the three fitted skins, explicitly entering the
arena and using flat ground with a visible character. Inspect actual captures;
successful frame/clock assertions do not establish a clean moving silhouette.
Evidence is under `build/Other Files/Asset Toolkit/Emilia Attack Shadow/`.

`emilia_skin_review_test.gd` covers all twenty Emilia outfits and 95 supplied
weapon combinations: every prepared frame/action/facing, source-clock playback,
loop/end behavior, atlas/anchor integrity, exact native contacts, five native
copies per outfit, hover-free selection, uniform preview framing and warmed
resource reuse. Desktop checks additionally verify corrected transparent-edge
imports and capture selection plus original/fitted/Special attack poses. Evidence
lives under `build/Other Files/Asset Toolkit/Emilia Skin Review/`. The read-only
`tools/recover_crossgate_emilia.py '../Magic Power' --check` compares all eighteen
original preparations (including fitted staff art) against source without edits.

`crossgate_special_skins_test.gd` retains coverage of the fifteen correctly owned
cross-character special additions; `skin_head_hud_test.gd` covers matching
portraits across the complete current Cross Gate roster. No legacy sweep is
needed for this inventory change.


### Original model HUD heads and Uru/Rei ownership

`skin_head_hud_test.gd` now exports the current source/body-height catalog with
`-- --catalog`; `tools/prepare_crossgate_heads.py` builds/checks front-facing
source head PNGs. The desktop fixture covers actual models, all live head routes,
nearest filtering, XP retention and cache/resource reuse. Current reports and
uncropped comparison boards are in `build/Other Files/Asset Toolkit/Model HUD Heads/`.
`crossgate_uru_inventory_test.gd` rejects Rei 100700 / 100798 / 120428 / 109912
in Uru and keeps classic Ruby 100650 out of Rei. The Special fixture covers the
three transferred Rei outfits through their exact native weapon/contact paths.


### Bei, Moe, Ami and Shin 2.0 inventory

`bei_moe_ami_test.gd` covers the 72 Bei/Moe/Ami appearances and 14 Shin 2.0
additions in Shin Special: 465 supplied weapon combinations, every directional
attack frame, real contact damage, fixed pet/effect weapon restrictions, skin
save/reload and weapon cycling, original HUD heads, the real Equipment gallery,
native five-copy presentation, seven simultaneous five-copy attack cases, and
warmed repeated-use resource bounds. Run via
Play Goemon with `--script res://tests/forest-shrine/bei_moe_ami_test.gd`;
`--headless` omits rendered review and the short desktop sample. Source pixel,
origin and event preservation is checked separately by the special-skin exporter
with `--cast-only --check`. Evidence is in Asset Toolkit's `Bei Moe Ami/` and
`Shin 2.0 and Pirate Bei/` folders. The desktop frame sample is intentionally
small; it does not establish full-army or long-session performance.

### Falan city scenery recovery

`falan_city_recovery_test.gd -- --east-il-road` reuses the normal saved-map
entry flow, captures the office/pond/overview, checks the removal of inherited
valley scenery and travels through all three gates. It preserves user rocks,
heights and original city NPCs; exact retired tree markers remain loadable,
while changed markers retain dry-ground validation. Run through Play Goemon;
add `--headless` for assertions only. `--baseline` captures without the new
assertions, for matched review before another scenery change.
`test_falan_pond_archive.py` compares original pond graphics and nine source
anchors. Evidence belongs in `build/Other Files/Asset Toolkit/Falan City Recovery/`.

### Falan and southern-road solid foliage

Run `falan_road_scenery_test.gd -- --venoa-undersea` through Play Goemon. It
compares city and road captures, checks original-style shared tree paint/mesh
batches, reuses the full road/undersea travel fixture and preserves all 104
native bears. Add `--headless` for assertions or `--baseline` for pre-change
images. The fixture waits for physics after scripted positions so rendered
frame delays cannot skip a gate approach sample. Recovered batch identity uses
metadata because Godot renames duplicate sibling nodes.

`test_crossgate_flora.py` verifies original trunk/leaf triangle counts, UVs,
normals, vertex shading, embedded native paint and unchanged source masters.
`recover_crossgate_foliage.py --check` verifies the original-pixel recipe and
crown/shading samples. Evidence belongs in the Falan Road Recovery toolkit folder.

### Falan buildings and street props

Run `Play Goemon.command --script res://tests/forest-shrine/falan_buildings_props_test.gd -- --east-il-road`.
The fixture includes the city recovery/gate checks, all 57 source-referenced
house markers, seven solid lamp styles, house bounds and roof normals, all
113 native lamp stations on desktop, saved-edit guards and shared mesh reuse.
`--baseline` captures a collider signature and pre-change views. `--headless`
checks geometry and counts; Godot's dummy backend cannot validate GPU instance
transforms. City/model captures go to the Falan Buildings and Props toolkit
folder. `recover_falan_buildings.py --check` validates source paint, bindings
and provenance. Run `test_village_building_surfaces.py` after changing the
shared rectification helper; it preserves the older village atlases exactly.

Falan landmark and bench recovery: run `falan_landmarks_test.gd -- --east-il-road`
through the desktop launcher. It covers the six civic facade references,
prepared paint/material reuse, 70 city bench stations and source facings,
footprints, door apertures, saved collider/custom-marker preservation and three
city gate returns. Matched images and an isolated solid-bench study are saved
in `build/Other Files/Asset Toolkit/Falan Landmarks/`; headless skips GPU
transform readback and screenshots. Native paint reproduction:
`python3 tools/recover_falan_landmarks.py --check`.

Falan solid building shapes: `falan_building_shapes_test.gd -- --east-il-road`
through Play Goemon adds curved roof normals, closed scroll-crown geometry,
gallery bounds, 36 native flower-urn stations/footprints and shared mesh reuse
to the existing landmark/bench/save/gate checks. Evidence is kept separately
in `build/Other Files/Asset Toolkit/Falan Building Shapes/` via the inherited
fixture's `review_folder()` override. Native source paint checks remain
`python3 tools/recover_falan_landmarks.py --check`.

Falan carved facade and mansion finishing: run `falan_carvings_test.gd -- --east-il-road`
through Play Goemon. It adds original carving/glazing counts, shallow relief
bounds/winding/UVs, shared materials and cache reuse, mansion lantern/valances
and the mansion door aperture to the existing shape/bench/urn/save/gate checks.
Evidence is under `build/Other Files/Asset Toolkit/Falan Carvings/`. Reproduce
the native color, stone-finish and depth atlases with
`python3 tools/recover_falan_carvings.py --check`. The shared depth helper is
covered by `python3 -m unittest discover -s tests/asset-toolkit -p test_arena_carvings.py`,
including exact preservation of the existing arena carving PNG.

Falan interiors: `falan_interiors_test.gd -- --east-il-road` through Play Goemon
visits inn 1101, hospitals 1111/1112 and bank 1121 through the actual city links.
It checks furniture source stations/footprints, soft-cover normals, shared mesh
reuse, actual static collision bounds/transforms, original walk bits, return
links and saved adventure preservation. Matched room/bed and close furniture
captures plus original room studies are saved under
`build/Other Files/Asset Toolkit/Falan Interiors/`. The original bank-seat physics
slab is retained. This is a scenery fixture, not a full-army stress benchmark.
It also checks the three shared original clock/notice surfaces and the inn
clock's inward-facing direction. Reproduce their native paint with
`python3 tools/recover_falan_interior_details.py --check`.

Falan office/guild interiors: run `falan_office_interiors_test.gd -- --east-il-road`
through Play Goemon. It reuses the existing interior fixture for rooms 1091/1092,
with its own before-collision snapshot and matched views under
`build/Other Files/Asset Toolkit/Falan Office Interiors/`. It checks source
furniture stations/footprints, the unchanged staircase/collision/walk bits,
real city entry/return links, shared meshes/materials and saved adventure.
Referenced mesh faces must include the solid curved chair backs and rounded
desk tops; chairs must face their source-derived desks. Native notices and the
door-header crop share the existing interior atlas reproducibility check.

Kili exterior/approach recovery: `kili_recovery_test.gd -- --east-il-road`
through Play Goemon reuses the complete original coastal walking route and
both gate round trips. Its separate baseline records actual static collision,
native obstacle/building plans and links for both Sokia Coast and Kili. It checks
the seven original buildings plus equipment arcade, preserved facade material,
native tiled roof UVs, upward canopy cloth, shared wall/column meshes, recovered
tree paint/wind and Sokia cliff material. Evidence goes to
`build/Other Files/Asset Toolkit/Kili Village Recovery/`; building views follow
their bounds and are for visual review, not exact pixel comparisons. Reproduce
the new atlas with `python3 tools/recover_kili_surfaces.py --check`. The existing
`freyja_villages_habaru_test.gd -- --coastal-kili` covers all original room links.

## Black Prayer / Ruby recovery

Run `black_prayer_maze_test.gd` headless for the 32-seed × six-floor generator
checks. Run `black_prayer_recovery_test.gd -- --east-il-road` through Play Goemon
for native patrol persistence, physical seeded stairs, the original palace and
Ruby party, heal/ice phases and reward return. Source verification is
`python3 tests/forest-shrine/test_black_prayer_source.py` and
`python3 tools/recover_black_prayer.py --check`. Evidence lives in
`build/Other Files/Asset Toolkit/Ruby Dungeon Recovery/`; see
`docs/black-prayer-recovery.md` for limits and source evidence.


Ruby spell recovery: `ruby_spells_recovery_test.gd -- --east-il-road` follows the
six-floor route and observes all fourteen spells, typed statuses, real confused
movement, native healing, solid palace props and pooled cleanup. Use Play Goemon
for captures; use `--headless` for assertions. `ruby_compact_events_test.gd` tests
the normal compact event drain separately from recorded events. Native defenses,
regeneration, freeze/expiry and steering are checked by
`native/terrain_math/crowd/ruby_spells_test.cpp`. Source preparation checks are
`recover_ruby_spells.py --check` and `recover_ruby_scenery.py --check`. See
`docs/black-prayer-recovery.md` for exact source evidence and real-time limits.


Ruby's remaining effects/details: `ruby_remaining_effects_test.gd -- --east-il-road`
uses the real native ward contacts and Confusion state, verifies source-painted
solid columns/pictures and shared meshes/caps, and exercises twelve five-copy
presentation waves of six contact types. Run through Play Goemon for actual
rendering; its snapshot freezes preserve short flashes during capture. This
presentation stress is separate from native boss AI. `test_ruby_effect_factory.py`
re-executes the seven archived client resource selections with the existing inert
research fixture and explicitly labeled tier-initializer repair.


Holy Shield: `ruby_holy_shield_test.gd -- --east-il-road` extends the Ruby route
with both native hit channels, source-sized 110098 contact flashes, original
impact audio, twelve five-copy presentation waves and thirteen royal furniture
placements. It checks full compound footprints and linen UV orientation. Run
through Play Goemon for rendering. `test_ruby_holy_source.py` reproduces six
archived ordinary/Special/no-guard and sound-endpoint fixtures; actor/host
submissions are inert. Exact native turn scheduling remains outside this test.


Ruby furniture carvings: `ruby_carvings_test.gd -- --east-il-road` visits all six
maze floors and verifies 24 native-painted carved features and thirteen newly
solid source ornaments. It checks recursive compound bounds, source cells,
no new colliders, shared resources, repeat setup and the unchanged plain-chair
mesh. Use Play Goemon for rendered chair/cabinet/mirror/tripod review; native
paint, masks, contour/depth preparations reproduce with
`tools/recover_ruby_scenery.py --check`. Source art stays in the original archive.

Enemy fly-away deaths (native lethal criticals / 25% max-HP excess):

```sh
"/Users/eric/Desktop/Play Goemon.command" --headless --script res://tests/forest-shrine/enemy_fly_away_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/enemy_fly_away_test.gd
```

Covers shared Cross Gate corpse flights, original launch audio routing, one kill,
combo hold/release and bounded repeated mass cleanup. Desktop runs also capture
flight frames under `build/Other Files/Asset Toolkit/Enemy Fly Away/`.
The standalone native `crowd/death_launch_test.cpp` checks trigger boundaries,
directions, companion exclusions and slot reuse. The trigger/distance are Goemon
adaptations; sound 207 is original, with source/hash provenance.

### Recovered western route

`original_maps_test.gd` checks the existing Falan exploration's recovered
western caves, Shalena, snowy towns, university, Snow Mountain and cursed maze.
Use `-- --route-only` for on-foot round trips and native cave routing;
`-- --caves` covers secondary caves/interiors. The former adapted Frostpass
fixture is under excluded `reference/`; its old entry now runs this fixture.
See `assets/maps/original_crossgate/README.md` and current captures/logs in
`build/Other Files/Asset Toolkit/Shalena Recovery/`.

`original_map_assets_test.gd` builds all 158 fixed rooms plus two generated
snow rooms and checks all 1,665 object graphics, shared mesh batches, source
cell counts/anchors and uncovered descending stairs/pits. Use desktop rendering
for exact MultiMesh transform and snow-backing checks; Dummy rendering cannot
read back those transforms. `original_maps_test.gd -- --completeness` renders
twelve representative areas, saving the actual follow view before an elevated
inspection view with ceilings temporarily hidden. Current full coverage
reports are in `Shalena Recovery/Completeness/`.
The source-detail pass adds `original_maps_test.gd -- --refinement` for nine
areas. Asset coverage also checks mixed indexed/raw surface merging, corrected
snow/fixture categories, elongated prop facings and native projected extents
for the eighteen reviewed graphics. Evidence is in
`Shalena Recovery/Source Refinement/`.

`cursed_maze_recovery_test.gd` verifies all sixty original floor payloads,
stair-connected chamber populations, native identities/levels/poses, guardian
deaths and return persistence. It traverses the original component/stair graph
on foot, including backward stairs needed to reach other chambers. The two
new creature skins repeat native contacts in all eight directions. Source
verification is `python3 tests/forest-shrine/test_cursed_maze_source.py`; it
independently decodes 1,024 frame instances and checks pixels, origins, clocks,
contacts, audio and the pinned encounter/guardian data. Evidence and captures
are under `build/Other Files/Asset Toolkit/Cursed Maze/`.


R power combos: run `Play Goemon.command --script res://tests/forest-shrine/combined_formation_test.gd`
for same-step starts/impact, one-slot click buffering, six/twelve per-unit combo
links, held LMB across three strokes for every Cross Gate fighter and dagger
variant, release-to-stop, complete idle recovery, movement/focus cancellation,
whiffs, distant queued
approach, Cross Gate normal/dagger attacks, death/phase cleanup and warmed reuse.
Add `-- --motion-review` for captures. Native `crowd/combined_formation_test.cpp`
covers 20/30/60 Hz, settled native contacts, restarted/cancelled recovery and
missing/recycled members. Evidence belongs under
`build/Other Files/Asset Toolkit/Combined Formation/`.

Pet recall formation: run `Play Goemon.command --script res://tests/forest-shrine/pet_formation_test.gd`
for default summon/resummon placement, the approved five party slots, actual Z input, repeated recalls, facing/travel,
no teleporting and existing F/right-click controls. Captures go to
`build/Other Files/Asset Toolkit/Pet Formation/`. The native pet-defense suite
also checks the assigned posts at 20/30/60 Hz and a wall detour.


## Automatic 護衛 rescue

`Play Goemon.command --script res://tests/forest-shrine/bodyguard_action_test.gd`
checks that real rescue pushes preserve normal attacks and borrowed Qi charges
across the Cross Gate roster, plus native pet physical combos and ranged casts.
The same cast must keep its clock, target and ticket and reach a later contact.
Only the protector cancels its action. The native fixture also preserves pet
movement goals, velocity, counter state and retained sequence targets.

Run `/Users/eric/Desktop/Play Goemon.command --headless --script
res://tests/forest-shrine/bodyguard_test.gd` (put the command on one line).
Omit `--headless` for rendered dash/jump/hit/follow-up and Equipment captures
under `build/Other Files/Asset Toolkit/Bodyguard/`.

The fixture uses the Cross Gate roster and five representatives across the four
original pet families,
real native hit dispatch (including compact production events), character and pet
Equipment, 50% shuffle bags, interruption, transferred damage, exclamation marks,
pet follow-up and forty repeated contacts with warmed node/resource counts. It
uses a temporary test save and restores the character's ordinary maximum HP
before the Equipment captures. The native `crowd/bodyguard_test.cpp` additionally
covers walls, commands, exact transferred damage, life-drain confirmation,
multiple protectors and generation-safe retirement/reuse. Choose plain 護衛;
Tina's 護衛-Ⅲ retains its separately recovered rules.


護衛 level growth: run `Play Goemon.command --headless --script
res://tests/forest-shrine/bodyguard_levels_test.gd` on one line. It checks all
30 shared formulas and level previews, real character/pet point purchases,
individual levels and actual transferred damage at levels 2, 11 and 30 for the
character and five original-family representatives. The native 護衛 fixture
also checks exact chance distributions over 100 contacts and damage at every
level, ordinary-hit isolation, valid inputs, rest and pooled reuse. Evidence uses
`bodyguard-level-*.log` under Asset Toolkit. The original 護衛 test remains the
level-one rendered and repeated-use regression.

## Directional pet attack move

The responsiveness follow-up also checks whole-party acquisition of a nearby
arrival within 150 ms. Native checks cover late arrivals at 20/30/60 Hz and
starting from clear, spaced melee contact without orbiting to a reserved post.
Before/after logs are in `build/Other Files/Asset Toolkit/Pet Stickiness/`.

Run `Play Goemon.command --script res://tests/forest-shrine/pet_attack_move_test.gd`
(add `--headless` for logic checks). Actual RMB input sends all five pet families
and a summoned bear toward empty ground, engages forward enemies, immediately
interrupts their attacks on a fresh directional click, resumes the advance,
defends the destination and accepts F/Z overrides. Repeated commands
check prepared presentation counts. Native `crowd/attack_move_test.cpp` covers
20/30/60 Hz, cover, pursuit retention after passing an enemy, redirection, late
arrivals, player-threat priority and recycling. Evidence is under
`build/Other Files/Asset Toolkit/Attack Move/`. Empty-click hunt descriptions in
older entries are historical; the default automatic defense still spreads pets.


Explore area closeout checks (headless, no traversal/captures):
`explore_courtyard_visual_test.gd` covers 232 courtyard obstacles, its stair shape
and the uncompressed shared Il guild; `explore_venoa_buildings_test.gd` covers
six forms/seven placements, actual native projection and seven old shapes;
`explore_southern_walls_test.gd` covers fourteen forms/164 old shapes;
`explore_ghana_fronts_test.gd` covers eight building pieces, 46 walls, the native
open well, 73 rails, all 126 old shapes and all 21 Kili/Ghana source wall bounds.
Run each separately through Play Goemon with `--headless --script res://tests/forest-shrine/NAME.gd`.
`recover_ghana_details.py --check` and `recover_kili_wall_proportions.py --check`
verify the new source derivatives. Any script error fails verification even if
a later PASS line appears. Existing shutdown resource warnings remain; these
checks do not certify visual fidelity, frame time or leak-free behavior.

## Crowded enemy attack pace and damage

Run `"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/crowd_attack_pressure_test.gd`
(add `--headless` for logic only). The Falan Arena fixture compares one, three,
four, six, eight and fourteen ordinary melee enemies, exact damage, unchanged
first contact, one second of extra recovery at four enemies (two-second cap),
crowd clearing and repeated simultaneous combat
with prepared presentation counts. `native/terrain_math/crowd/crowd_pressure_test.cpp`
covers native boundaries, target exclusions, chase movement, committed swings,
charge isolation and reuse at 20/30/60 Hz. Logs and captures belong under
`build/Other Files/Asset Toolkit/Crowd Attack Pressure/`.

### Permanent chest food

`chest_nutrition_test.gd` exercises all sixteen recovered foods, the twenty-marble
reward bag, ordinary weapon preservation, character/pet progression, fractional
XP, capped/malformed saves, failed-write retry, recalled pets, reload/new-run and
travel persistence, F input, the two stock audio streams, source-pixel identity,
small-window receipts and repeated native/presentation reuse. Use Play Goemon
with `--script res://tests/forest-shrine/chest_nutrition_test.gd`; add `--headless`
for logic only. Evidence: `build/Other Files/Asset Toolkit/Chest Nutrition/`.


Food pickup and jelly updates (2026-11-27): `food_magnet_test.gd` now covers the
0.65-second rising orbit, moving eater, deferred effect/sound, pause/cover/cleanup,
64-slot repeated reuse, a complete13food/52miss shuffle bag, and red/blue/green
five-minute+50%bonuses across Cross Gate fighters. `chest_nutrition_test.gd`
checks the same flight for all16meals, soup replacements for the former jelly
meals, original-pixel hashes, changed-party recovery and duplicate-F rejection.
`map_swarm_test.gd` verifies that four deaths do not activate pursuit, while eating
original:15043 does. Native movement uses the bundled arena with -- --crossgate-pet-test, matching
normal play; separate source-map model checks cover reset/trigger rules. Current evidence belongs under `build/Other Files/Asset Toolkit/Melon Bread/`.
