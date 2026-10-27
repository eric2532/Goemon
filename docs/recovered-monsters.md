# Vambee and Haya Wolf / reusable enemy workflow

## Gorilla and wolf are separate live enemies — 2026-10-23

Slow Guy/gorilla is native enemy type 16; Haya Wolf remains type 9. Both appear
in the ordinary roster and continuous camp cycle, subject to the saved enemy
counts. The legacy sword family includes Sword/Vambee/Gorilla and the spear
family includes Spear/Wolf. Explicit per-enemy counts use their own type entries.
The ordinary cap remains 240; adding a type does not add extra wave units.

Slow Guy reuses the preserved historical `haya_wolf.blend` master and its own
authored `assets/models/enemies/recovered_monsters/haya_wolf.glb`. The misleading
filename is retained to preserve the existing editable source. Its actual ROM
attack is `Source__801a1874`, 40 ticks: a planted arm swing, active on ticks
15–20, with attack sound 7E4, damage 18, and death sound A9C. The original OBB
and attack vectors are separate from the wolf's. It does not inherit kick travel.
All eight original clips remain, including walk, reactions and death.

The existing native attack engine accepts an optional exclusive contact-end
tick. Zero retains the old single-marker behavior. A windowed swing checks its
current target against the same exact segment/cover test, accepts a late entrant,
and delivers at most once. The existing per-attack hit flag resets on each new
attack; no extra target list, per-unit node, allocation or army scan is added.
Goemon's shared damage/knockback rules remain the victim response; the source
Musashi-only reaction script is not copied into the player controller.

Fresh evidence and limits: `build/Other Files/Asset Toolkit/Gorilla and Wolf/`.

## Wolf identity correction — 2026-10-23

The user correctly identified the earlier “wolf” as the gorilla, Slow Guy.
The old `haya_wolf.*` recovery, runtime resource and Blender master are preserved
at their historical paths. They are **not Haya Wolf**. The active wolf role now
uses `karate_wolf.*`, recovered from SC04 / FILE_004, with its own 13 meshes,
headband/ears, eight streams and flying-kick poses. Do not rename or regenerate
the preserved gorilla master over artist edits.

The actual wolf initializer at `80182FF0` passes descriptor `8019DB0C`; its
model pointer selects list `801A1134`. Its idle/walk/kick are `801A82F8`,
`801A8380`, `801A84D0`. Its kick launch is tick 15, sound A9D; death is A9E.
The earlier SC04 / FILE_002 list `8019BB40` and streams `801A16C4` onward
belong to Slow Guy. Its frame-15 attack and sound 7E4 did not prove wolf identity.
The old byte-preservation checks proved extraction fidelity, not the enemy name.

Evidence and current checks: `build/Other Files/Asset Toolkit/Vambee and Haya Wolf/Research/WOLF_CORRECTION.md`.

The user's “Vanbee” is the blue Vambee; the kicking wolf is Haya Wolf. These and
Slow Guy are ordinary enemies in Goemon's native army. Counts, the 240 normal
cap, portals, map data, controls and painterly environment retain their contracts.

## One runtime owner

`forest_enemy_roles.gd` is the shared registry for ordinary types and the boss.
The pre-existing `forest_thirstquencher_visual.gd` now handles compatible rigid
enemies through the same GPU pose atlas and texture/material batching. Its old
filename is historical; there is no second monster renderer or AI backend.
Each spatial batch groups one mesh/pose resource. NPCs own independent native
HP, timers, status and hit delivery without a live skeleton/AnimationPlayer each.

Native attack kits contain five phase durations, four contacts, the fitted melee
segment and radius, optional forward travel, opening/combo settings, the original
actor OBB and optional next form. New compatible attacks supply data to the same
state machine. Vambee's first defeat changes its type into its recovered torso
in the SAME native slot and handle; detached legs use the existing corpse pool.
The facade changes its shared collision shape once when that event arrives.
The torso's final defeat uses ordinary death/retirement and cannot hit a reused
slot. Boss patterns stay in the existing native owner; their encounter logic is
specialized while movement/queries/HP/status/events and game integration are shared.

The user's clarification was about reusable technology and Blender work, not
additional per-type tuning menus. Existing shared balance controls are reused.

## Playable enemies — 2026-10-24

The fighter gallery now includes Red Soldier (20), Blue Gunner (21), Green
Spearman (22), Vambee (23), Haya Wolf (24), Vambee Torso (25), Slow Guy (26)
and Skullpion (27). These stable player IDs map to the existing enemy type data;
they are not new army types. Detached Vambee legs remain a corpse effect.

The selected fighter uses the existing Hero, CharacterCombat, skill loadout,
attack tickets, local native target queries and projectile/audio pools. NPC
ownership, formations, wave counts and specialized boss encounter patterns stay
in the native army. Ordinary selected enemy bodies reuse the same immutable
mesh, material and baked 30 Hz pose atlas. Skullpion reuses his existing visual.
Models initialize on selection. No runtime animation retargeter or additional
army simulation was introduced, and no editable asset was regenerated.

Idle, movement, attacks and hit reactions use recovered clips. Equipped spells
use the receiving enemy's original attack gesture while their source controller
retains effect, motion and hit timing. This is a compatible casting gesture,
not an exact transfer of every donor's skeletal animation. Soldier attacks use
the existing phase controller; other attacks read the shared enemy registry.
The gunner uses the original three-shot burst and bullet meshes through the
existing projectile pool.

At the user's request, playable Skullpion keeps the full enemy boss scale: the
same 30 × 25 × 40 targeting bounds, a matching world collision box and a wider
camera. Selection finds nearby clear ground so the enlarged body does not begin
inside castle walls. Native enemy melee, shots and boss areas use those player
bounds; ordinary fighter hit checks remain unchanged. LMB uses sand blast,
RMB jump stomp, unassigned E the tail sweep and unassigned R Poison Drill. Equipped E/R/T spells keep
priority. The tail's animation, turn and six contacts run at 3× speed: 1.1 seconds
instead of 3.3. Sand reuses the boss plume, audio and six original damage pulses,
with the original narrow forward arc and solid-cover checks.

Space and RMB now launch at 160 m/s, with up to 260 m/s of directional air
travel. Rising gravity is 320 m/s² and falling gravity 720 m/s²; the default
leap reaches about 40 m and returns in about 0.9 seconds. The existing full-size
CharacterBody handles castle collisions. RMB damages on actual touchdown,
then recovers in 0.2 seconds. Explicitly equipped jump styles retain their own
motion. No authored model, animation resource or native NPC pattern changed.

Player Poison Drill runs the original tail animation, three ground strikes and
prepared drill effect at 10× speed: first contact at 0.19 seconds, subsequent
contacts at 0.28/0.37 seconds and recovery complete at 0.467 seconds (before
existing attack-speed modifiers). The original tail-burial pose is aligned with
the first emergence, then the tail recovers after the third strike. Each
emergence selects the nearest living,
visible ground enemy within 125 m through the native local query, respecting
solid cover and retargeting after deaths. It keeps the original 19 m ground
area, 65% base damage per strike and 55% movement speed for four seconds.
It requires ground contact; missing a target or cancelling clears the effect.
The native enemy encounter also has Charge, Bouncing Volley and Wall Climb.
Those remain NPC patterns; the shared spell picker can still equip abilities
from other fighters.
Shared player health, movement and respawn rules apply. Full NPC encounter AI
is not run on the player.

Run `Play Goemon.command --script
res://tests/forest-shrine/playable_enemies_test.gd` for rendered gameplay checks.
Evidence is in `build/Other Files/Playable Enemies/`; performance measurements
and their limits are in `docs/goemon-performance-guide.md`. Gallery portraits
come from `tools/capture_playable_enemy_portraits.gd`, which renders the same
runtime models into `assets/characters/playable_enemies/`.

## Recovery and provenance

`tools/recover_vambee_wolf.py` reuses the existing rigid TMD assembly helper.
The primary sources are USA SLUS-007.26 overlays:

| Asset | Source | Parts | Source clips |
|---|---|---:|---:|
| Haya Wolf (`karate_wolf`) | SC04 / FILE_004 | 13 | 8 |
| Slow Guy (historical `haya_wolf` path) | SC04 / FILE_002 | 12 | 8 |
| Vambee | SC03 / FILE_089 | 10 | 19 |
| Green Vambee | same overlay | 10 | 19 shared |
| Blue / green torso | same overlay | 6 each | 4 shared |
| Blue / green detached legs | same overlay | 5 each | 1 shared |

All 24 Vambee streams are partitioned by their actual part counts, not applied
blindly to ten parts. Haya's eight streams include 39 uncompressed pose frames
among packed frames. Each pointer's tag selects the 8-byte or 12-byte transform
format. Source geometry, colors, UVs, resolved texture pages/material pixels,
source addresses and hashes remain in the recovery manifests. Numeric clips
remain available even where semantic names are inferred. Green geometry is kept
for editing/review; it does not add a flying simulation to normal waves.

Zero-hold poses are externally advanced by the original engine; previews give
each one tick. Redirects are recorded; standalone previews stop at the redirect.
Goemon adapts world travel, damage, grabbing and target release to its shared
combat controller. Haya's launch is source frame 15; the port keeps its existing
single-contact/travel adapter and current balance rather than emulating the
original airborne contact loop. Vambee's frame-13 bite
marker, fitted grab segment and two-stage damage behavior are port adapters;
this is not a full emulation of the original victim-tether scripts.

`tools/recover_monster_audio.py` follows dispatch → scene resource level map →
scene column → layered records → complete VAB lookup → tone → original ADPCM.
The driver at `8002F4E4` confirms source level 50 maps to column 1 for Haya and
level 35 maps to column 2 for this Vambee stage. Shared resource bank 31 is also
retained. The catalogs include 53 wolf-stage, 54 preserved Slow Guy-stage and 99 Vambee/shared event aliases,
and complete samples from their retained banks; aliases are not counted
as distinct enemy actions. Haya kick `A9D`, death `A9E` and landing `83C`,
Vambee bite `A9B` and final disappearance `CBA`, plus descriptor contact/reaction
events are traced. Candidate/unused scene mappings stay identified as such.

Audio is authentic dry SPU ADPCM with source pitch curves, layer delays and
relative volumes. The shared pitch decoder now supports the source-traced
absolute/relative delayed forms 5–9. PSX ADSR, Gaussian interpolation, reverb and
held-loop key-off envelopes are not emulated. No replacement sounds were made.
Full catalogs and raw samples are under
`build/Other Files/Asset Toolkit/Vambee and Haya Wolf/Audio Catalog/`.

## Blender → runtime

Eight editable masters live in `assets/blender/enemies/recovered_monsters/`.
Read that folder's AGENTS.md. The generic exporter reads the open saved master;
it never regenerates meshes from a generator over artist changes. Example:

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b assets/blender/enemies/recovered_monsters/vambee.blend --python tools/export_recovered_monster.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/bake_recovered_monsters.gd
python3 tools/goemon_assets.py audit assets/characters/recovered_monsters assets/models/enemies/recovered_monsters
python3 tools/goemon_assets.py check
```

The immutable disc recovery stays separate from authored exports. The bake
prefers an authored export when present, records both actual source hashes,
and retains all source clips. Vambee has been through this complete editable
round trip. Near-integer key times are snapped to the exact 30 Hz float32 value
before Godot import: otherwise STEP resampling can repeat the previous pose.
Original source poses must continue to pass until the artist intentionally
changes them; do not update preservation assertions to hide an unintended drift.
The workbench also fingerprints local geometry, normals, UVs, colors and paint
independently of poses. For an unchanged mesh, the exporter retains its exact
recovered geometry/material/texture data while exporting the edited motion.
This prevents Blender's normal and byte-color quantization from changing an
otherwise untouched asset. A geometry/paint edit exports the artist's actual
mesh instead. Vambee's untouched round trip is checked for every oriented
triangle attribute and exact texture bytes, as well as all source poses.

Checks and desktop capture:

```sh
python3 -m unittest discover -s tests/asset-toolkit -p 'test_vambee_wolf_recovery.py'
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/forest-shrine/recovered_monsters_test.gd
/Users/eric/Desktop/Play\ Goemon.command --script res://tools/capture_recovered_monsters.gd
```

Evidence, performance limits and remaining checks are recorded in
`build/Other Files/Asset Toolkit/Vambee and Haya Wolf/VALIDATION.md`.

## Dark Lumina 2 — second-form battle recovery

Enemy role 17 and playable ID 29 use the verified SC07 / FILE_003 module 0x72
body: 19 parts, 21 motions, 714 triangles. The body and effects have separate
editable masters in the existing recovered-monsters Blender workbench. The
native combat owner, rigid pose atlas, pooled presentation and modular skill
system are reused. Existing waves receive a zero count for the new type.
See [the recovery, controls and maintenance guide](dark-lumina-2-recovery.md)
for source addresses, all recovered sounds/effects, export commands and tests.

## Dark Lumina 3 final form — 2026-10-24

Verified module 0x73, SC07 FILE_004, is native role 18 and playable fighter 30.
The main body, separate sky copy, all 16 body motion streams, six offensive
families, sprite effects, 50 morph endpoints and 22 audio assets are recovered.
It shares the existing native army, rigid GPU renderer, projectile/presentation
pools and transferable skill catalog. Existing wave counts migrate unchanged,
with zero new bosses until selected. See [the recovery/workbench guide](dark-lumina-3.md)
for controls, exact source addresses, editable masters, checks and adaptation limits.
