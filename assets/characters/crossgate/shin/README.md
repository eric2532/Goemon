# Shin · Blue Cross Gate

## 水龍shin · purple hair — 2026-11-18

The user requested light lavender hair and slightly darker blue clothing for
appearance 900050. The existing offline `blue_theme` palette function maps its
original red hair to shaded lavender and darkens the outfit blue by 10%
across sword, spear, axe, bow, staff, dagger and boomerang poses. Body alpha,
frame regions, timing, grips, weapon pixels, edge flips and blue waves stay
unchanged. Original 100050 art is preserved. Rebuild with the existing sword
and all-weapon preparers, then refresh the HUD heads and cosmetic attachments.
The separately approved dialogue portraits are untouched. Dark hair-edge colors
retain the original cleanup classification so recoloring cannot fill a removed
blade pixel or alter the silhouette.

## Three-Weapon Combo equipment — 2026-11-18

The earlier sword-equipped experiment is now a separate **Three-Weapon Combo**
item (`weapon:three-weapon`). Ordinary Sword uses only sword frames and sounds.
Select the combo in Q → Weapons to cycle accepted left clicks through sword,
spear and axe with matching existing audio. Busy clicks do not advance it;
right click, skills and native companions keep their normal sword attacks.

Equipment derives this option only for looks with all three existing weapon
routes (226 of 274), using the wearer's own frames and sounds. Sword mechanics,
reach, clocks and contact count remain unchanged. Donor poses and audio are
prepared when equipping, not during attacks; all original artwork is preserved.
水龍shin retains the approved weapon art, ice impacts and waves. Its axe drawings
already reuse sword-cut body motion. The combined icon reuses the three selected
inventory sprites; see `assets/ui/crossgate/weapons/README.md`.

`water_dragon_primary_cycle_test.gd` checks ordinary swords, the separate saved
item/icon, active carried slots, incompatible-look preservation, source contracts
for every compatible look and live cycles across the supported Cross Gate roster.
Captures/logs are under `build/Other Files/Asset Toolkit/Shin Water Dragon/Primary Cycle/`
and its parent. Shared model setup also runs `mirror_movement_test.gd`.

## 水龍shin · all weapons — 2026-11-17

The user approved the seven-weapon preview and requested implementation, including
curved boomerang flight, ice sound and the blue Gold Lightning shockwave.
`tools/prepare_shin_water_weapons.py` prepares the six additional routes under
`900050/{axe,polearm,bow,staff,kunai,boomerang}/`. Original archives and other
Shin skins are preserved. The sword retains its approved edge flips and 10%
length reduction.

Axe, spear and staff movement reuse complete basic-Shin sword carrying poses,
with their already reviewed grips and blade axes. This retains coherent torso,
shoulder, elbow, wrist, hand and legs; it does not swap only legs or guess a
weapon angle. The axe and staff also reuse the approved complete sword-cut sequence, retimed
to their native contact clocks without changing damage or release timing. Spear
retains its native thrust; shaft/head pixels measure those projections,
with the approved sample overrides. `900050/weapon-fits.json` records the fitted poses.
The knife and boomerang reuse this carry and Shin's original unarmed throw
(action 7, exposed as the equipped action 5). Native release removes the held
weapon. The five held throw drawings use traced glove positions and measured
forearm axes, with the original body hiding occluded hands; they never use knee
or foot colors as grip candidates. Bow retains its native armed poses and posed string/arrow; its recovered
decorative arc is fitted to the palm and limb ends. Native running hides the bow;
do not invent a visible bow where the original body hides it.

All new attacks bake the existing blue Gold Lightning wave behind their original
body, aligned to each native contact/release. There is no extra effect hit or
runtime sprite fitting. The spear special counter also reuses a cool-palette copy of its original
counter burst, preserving the chroma key and returning to the original effect
when another skin is selected. Basic counters use the equipped normal frames, including
recovery and the wave, through the existing shadow player.

Impacts layer 水精 attack 264 onto each native weapon impact using prepared PCM
mixes 900010–900014. Thrown weapons reuse the existing sword impact plus ice.
Bow, knife and boomerang carry the prepared impact sample to actual projectile
contacts. Sound Studio gain/mute and shared sound voices remain authoritative.

The boomerang extends the existing recovered projectile and character pool. It
spins using sixteen offline rotations of the recovered 冰龍 item; its outward
and return legs bend to opposite sides and the final return follows the moving
owner. Swept contacts use bounded native army queries, with one hit per enemy
per throw. Walls and owner cleanup retire the lease. Pool reuse resets age,
curve origin/direction, damage/ticket and hit identities, sharing cached textures.
Normal and counter throws use the same release path and artwork. Later piercing
contacts keep primary camera feedback quiet while retaining their ice impacts. Native copies
retain their existing simulation and get the equipped ranged reach.

Prepare after changes:

```sh
python3 tools/prepare_shin_water_weapons.py '../Magic Power'
python3 tools/prepare_shin_water_weapon_anchors.py
python3 tools/prepare_crossgate_player_audio.py '../Magic Power'
```

`--weapon axe` (repeatable) limits the art bake. The anchor preparer carries
existing fitted native head points onto the new atlas regions; all other models'
packed anchors remain intact. It records a fresh derived-cache provenance after
baking. Review images under `build/Other Files/Asset Toolkit/Shin Water Dragon/All Weapons/`.
Use the focused `water_dragon_weapons_test.gd` for new projectile behavior;
visual-only edge changes continue to use images instead of test runs. No app
export is needed.

Current verification: the desktop launcher passed 77 focused runtime checks,
including source release timing, curved outward/return legs, a moving catch point,
exact once-per-target damage, counter projectiles/ice bindings, eight repeated
leases with varied origins and stable node/resource counts, four simultaneous
native companions, and restoration of original Shin's counter effect. Actual
input captures recorded walk `1:7`, Shift run `3:7`, then `1:7` after release.
The final counter palette adjustment was reviewed as art without another game
test run. Asset Toolkit source/PCM/cosmetic preservation passes. These checks do
not establish a full-army frame-time or long-session result.

## Basic Shin with 水龍劍 — 2026-11-17

Regular Shin now also offers **水龍shin**, saved appearance
900050. It stitches the existing red-haired/blue basic Shin sword poses
(100050 family, body source `original:2426` / 100053) and the preserved original
water-dragon sword item (`original:251582`, graphic serial 26300). The exact
56×47 item PNG is `900050/water-dragon-sword.png`. Its identity was checked
against https://atlantis.cgsword.com/item/!水龍之劍 and
https://guide.starcg.net/equipment/water-dragon; runtime artwork comes from the
local original archive. All previous Shin appearances and asset masters remain.

`tools/prepare_shin_water_dragon.py` reuses the existing blade transform and
atlas packer. `tools/shin_water_dragon_splices.json` records reviewed source
blade positions for 280 body drawings, including guard poses and body occlusion.
The sword retains its 1.725× width fit and is 10% shorter along the blade,
anchored to item grip (48,39). Blade-face orientation is reviewed per facing
and drawing, not assigned by a blanket wind-up/strike rule. The user-approved
edge-only corrections are preserved in `assets/references/shin_water_dragon/`.
S6/S7 retain their original recovery body poses; their earlier idle substitution
is removed. The existing S5 body recipe is unchanged by this approval.
Grip endpoints are traced from the native hand
rather than choosing an end of the visible blade fragment. The user rejected the earlier global-orientation fits;
technical passes on those versions did not establish correct-looking motion.
Resting poses use facing-specific edge orientation: directions 2–5 mirror the
item, while directions 6–7 retain its orientation so the silver edge faces down.
The previous blanket resting mirror was rejected in screenshots I6/I7; the rear
grip itself matches the original side-facing pose. The readable original
100193 sword/unarmed pair measures their grip, axis and projected blade width.
Matching basic-Shin unarmed frames protect body pixels during idle/walk/run
blade removal; explicit resting hilt masks remove the remaining original handle
without erasing the palm. Hidden rear blades remain hidden. The selection image
comes from the corrected front resting frame.
The item is transformed with nearest sampling and stitched behind the original
hands/body, replacing visible original blade pixels. Its eight views are fitted
from the one supplied item view. No new weapon/body art or animation is drawn.
Each reused pose retains its original shadow. Red hair/accents are palette-remapped to
blue; existing blue clothing, skin tones and source shading remain. The portrait
is cropped from the selected blue model through the existing head preparer/cache.
The default sword retains the original sword's frame counts,
clocks, contact, audio, skills, damage and native simulation owner.

The blue strike wave reuses Gold Lightning 111625 (`puk2:1108`), whose attack
has the same 25 source-frame positions. Existing wave frames retain their
original offsets, pixel silhouettes and order; swapping red/blue channels turns
gold into blue. The strike/recovery donor silhouettes (source frames 10, 11,
24, expanded two pixels) remove its old character/weapon. Raised silhouettes
are excluded because they cut a gap above the new character's head. The wave
is stitched behind the selected body in the prepared atlases. The existing
selection-time loader/material cache handles the three pages; attacks add no
loads, nodes, effect owners or material allocations. The wave cannot apply
extra damage. Three atlas pages contain 359 prepared drawings, about
32.6 MiB of RGBA texels before engine overhead; copies share those textures.

For visual-only sword adjustments, prepare the affected runtime art and refresh
its audio source hashes, HUD source region and cosmetic attachment coordinates.
The user requests images instead of test runs or full audit cycles for these
iterations. The approved Water Dragon set now supplies Sword, Axe, Spear, Bow,
Staff, Dagger and Boomerang through the existing equipment routes. Basic counters use the
equipped normal attack's frames and atlas, including the shorter sword.

Full recovery reference commands (the full/cast recovery calls the preparer too;
do not run the test/audit commands for visual-only iterations):

```sh
python3 tools/prepare_shin_water_dragon.py '../Magic Power'
python3 tools/prepare_crossgate_player_audio.py '../Magic Power'
'/Users/eric/Desktop/Play Goemon.command' --headless --script res://tests/forest-shrine/skin_head_hud_test.gd -- --catalog
python3 tools/prepare_crossgate_heads.py
python3 tools/prepare_crossgate_cosmetics.py
python3 tools/test_shin_water_dragon.py
'/Users/eric/Desktop/Play Goemon.command' --script res://tests/forest-shrine/shin_water_dragon_test.gd
python3 tools/goemon_assets.py audit
python3 tools/goemon_assets.py check
```

The head crop for `37:900050` is the unchanged `37:100050` crop. Source rebuilding
uses explicit saved splices; the game loads three prepared atlas pages on selection.
Review the rendered attacks and pose boards separately from technical tests.
Evidence belongs under `build/Other Files/Asset Toolkit/Shin Water Dragon/`.

Before the resting correction, four source/pixel tests and 877 focused desktop
checks passed, but missed the user's resting-edge/original-blade issue.
Original attack-art auditing reported zero mismatches across
223,447 source frames; the stitched derivative is verified separately by its
exact rebuild. Asset preservation, attack audio and selected-model head checks
pass; the GLB audit reads 319 assets without errors. Desktop captures include
the raised/downward poses, blue waves in all eight views, and five simultaneous
native copies. These checks do not establish full-army or long-session performance.

The earlier resting correction passed five Python source tests, two existing Red
Lightning transform tests and 918 focused desktop assertions, including the
actual selected appearance in Equipment/gallery, all resting frames and normal
movement with Shift press/release. The user then reported incorrect orientations;
numbered body-pose sheets under `Shin Water Dragon/Frame Review/` identified
I6/I7's upside-down edge. Swing sheets omit the wave only for grip inspection. Technical
success is not visual approval. The cosmetics atlas-attachment rebuild is being
performed by the separate full alignment preparation; toolkit preservation still
reports those stale dependencies until that preparation finishes.

The I6/I7 repair changes only six resting splice records, preserving 1.725×
scale and attack records. Its regression measures the silver blade pixels below
the grip-to-tip axis for each affected pose; it fails on the rejected recipe.
Current evidence is under `Shin Water Dragon/Side Grip Fix/`.
Fresh verification of that repair passes six Python tests and 918 desktop
assertions with no logged script errors. The rendered direction-6/7 resting
captures show the silver edge below the blade axis; normal walking, Shift
press/release, exact combat and repeated/native-copy checks also pass. The GLB
audit still reads 319 assets without errors. Full toolkit preservation continues
to report the separate cosmetics inputs as stale while its full rebuild runs.

The subsequent movement/swing review covers 160 body poses: 48 walk, 48 run,
64 attack, retaining all 25 timed attack-frame positions. Walking directions
2–5 mirror the edge; 6–7 retain it. Direction 7's walking grip is behind the
body, with its old hilt removed. Running directions 0–4 mirror and 5–6 retain
the edge; direction 7 remains hidden. Native 100193 sword/unarmed pixels and
the existing `RUN_BLADES`/`blade_axis` helper measure the seven visible running
views, including projected width. All six front/side strides keep the hand at
the same end and no longer reverse or collapse the blade. The running length
still uses 1.725×; thin views follow the source projection.

Attack wind-up records `5:0:1`, `5:1:2`, `5:1:3` had their hand/tip ends
reversed and are corrected against the original poses. The earlier assertion
for `5:1:2` encoded the wrong end, illustrating why metadata checks cannot
replace source/rendered inspection. Raised/cut edge settings, clocks, wave,
damage and the existing runtime are otherwise unchanged. Seventy-five splice
records change; no source body, motion or item art is newly authored.

Seven source tests pass on this recipe. Numbered sheets, source overlays and
animated eight-direction reviews are under `Shin Water Dragon/Motion Review/`.
The review crops fit the whole motion's bounds; previous fixed report crops
could cut off an enlarged tip even when the actual atlas was not clipped.

Final Play Goemon verification passes 1,015 assertions with no logged script
errors: 48 walk, 48 run and 200 timed attack captures, source clocks/contacts,
normal movement with Shift press/release, repeated use and five native copies.
Combat aiming originally repeated some camera facings; the capture fixture now
resets facing after the damage check and asserts eight distinct directions.
All 160 body poses were reviewed against source frames and the rendered movement
board separately from those assertions. The complete cosmetics rebuild has
finished, and `goemon_assets.py check` now passes all preservation groups,
including attack audio and character attachments. The GLB audit reports 319
assets and zero read errors. No app export or new full-army profile was run.

The user then rejected R4-01 and recovery S5-08/S6-08/S7-08. Their grip/axis
matches the original source, but the blade face was wrong: direction 4 also
needs the running mirror across all six stride poses, and recovery pose 7 in
directions 5–7 must retain the strike's mirror. This changes nine `edge_flip`
values only, preserving anchors, scale, body pixels and gameplay. Before/after
views and updated motion sheets are under `Shin Water Dragon/Grip Review/`.
The preceding technical pass did not visually approve these rejected frames.

Latest visual approval (2026-11-17): the user approved the bottom rows of both
`Edge Review/` sheets and requested implementation. Exact targets are S0-05,
S0-06, S0-07, S2-02, S2-03, S1-01, S3-02, S3-03, S6-08 and S7-08. These
reflect the blade face around the same source axis and grip, preserving the
pictured body and scale. S6/S7 use the original ending drawings, not idle.
Approved-only PNGs and exact recipe values are saved in
`assets/references/shin_water_dragon/`; the folder is excluded from imports.
The source preparer uses explicit `body_pose` entries only, rather than forcing
every ending into idle. Tests were not run for this visual-only implementation,
as requested. The older test counts and rejected revisions below are history.
The approved runtime bake has 359 drawings across three shared pages. Audio
and HUD head caches are regenerated. Cosmetic head positions for this variant
are carried from the existing basic-Shin source frames, adjusting only the
atlas origin/offset; unchanged body/head pixels do not need another fit.
The one-model dependency preparation is recorded in `Approved Edges/`.
Other models' packed attachment records are retained. The cosmetics chat owns
the final complete attachment/preservation pass; model atlases and portrait
preparation are held stable for it. No tests or app export were run here.
This nine-pose revision passes seven source tests, 1,015 desktop assertions
and the complete toolkit preservation check after rebuilding audio, heads and
cosmetic attachments. The final capture set contains 48 walk, 48 run and 200
timed swing images. Capture keys now keep the selected direction fixed across
the sequence; re-querying live facing could otherwise repeat a view despite
eight distinct starting views. The reported poses are also captured together
in `reported-gameplay.png`. These checks establish reproducibility, timing and
reuse; compare the before/after artwork separately. No app was exported.

The user rejected the mirrored S5-08/S6-08/S7-08 again: changing blade face
alone retained the recovery's reverse wrist. Those three unique recovery
drawings now reuse the complete existing sword-resting pose `0:direction:0`.
The saved `body_pose` reference and copied resting splice turn torso, arm,
wrist, hand and weapon together. Source action-5 positions 21–24 retain their
original clocks and existing wave; position 24 has no wave and shares exactly
the resting atlas cell. This is three whole source-pose reuses, not new artwork,
an isolated arm/leg edit or runtime retargeting. Original recovery masters remain.
Eight source tests pass; the new regression rejects the old frame and verifies
the complete resting-cell reuse. Evidence is under `Recovery Turn/`.
Fresh desktop verification passes 1,018 assertions, including the three exact
resting-cell checks, 48 walk/48 run/200 timed swing captures, Shift controls,
repeated use and five native copies. The gameplay board shows the sword down
beside the body in the three returned poses. Original clocks and attack contact
damage are unchanged. The GLB audit reads 319 assets without errors. No app
export or full-army profile was run.

Water Dragon's user-requested ice hit layer uses 水精 `original:2902` /
101512 attack effect 264 (`cgefc13.wav`) over existing sword impact 134.
Prepared mix 900010 uses the existing PCM mixer: original pitch, complete
tails, one shared peak attenuation capped at 30000, and one cached hit voice.
Only appearance 900050's impact route changes; swing 104, regular Shin and
user recordings/gain/mute precedence remain intact. This is selected by
the skin root, not its shared original sword key. No model atlas changes are
needed when adjusting this audio recipe. Rebuild/check with the existing
`prepare_crossgate_player_audio.py`; `--water-dragon --visual` on
`crossgate_player_audio_test.gd` covers eight directions, hit/miss, original
Shin, Studio preview, cached voices, overrides, and five native copies.
The focused desktop run passes 83 checks over 17 attack cases and records the
real SFX mixer to `Water Audio/weapon-audition.wav`. Source PCM/rebuild checking
and the skin-isolation/source-effect regression pass. Full toolkit checking
currently reports only the separately edited cosmetics `head-fits.json` input
as stale; two complete attachment preparations ran, but the other chat changed
that input during preparation. Do not describe that global check as passed.


## Selected Special attack audio — 2026-11-17

The user's numbered gallery follows the first nine selectable Special skins:

| Number | Skin | Swing | Confirmed impact |
| --- | --- | --- | --- |
| 1 | 106707 Glowing Sword | Regular sword 104 + Fire rise 282 | Regular sword 134 + Fire impact 266 |
| 2 | 109140 Ember Shields | 104 + 282 | 134 + 266 |
| 3 | 111624 Gold Runes | 104 + 282 + dragon call 172 | 134 + 266 |
| 4 | 111625 Gold Lightning | 104 | 134 + lightning candidate 290; no Fire |
| 5 | 118986 Gold Crescents | Regular punch 102 + Meteor fall 262 + Fire burst 267 | No duplicate blast |
| 6 | 118987 Yellow Flame | 104 + 282 | 134 + 266 |
| 7 | 118993 Red Lightning | 104 + 282 | 134 + 266 + 290 |
| 8 | 108313 Gold Polearm | Regular polearm 108 | Regular polearm 138 |
| 9 | 120440 All White / Red Weapons | Sword 104 / polearm 108 | Sword 134 / polearm 138 |

These are user-selected adaptations, not claims that the silent source skins
originally assigned these cues. Fire level 10 selects original resource 110140
(alternatives 110141/110142), whose existing rise/impact samples are 282/266.
Dragon call 172 is Golden Dragon `original:2965` action 6. The user auditioned
and selected 290 from 雷公 `joy-ex:963` action 5; its archive name is not a
dedicated thunder label. Number 4 explicitly excludes both Fire cues.
After auditioning the alternatives, the user selected Meteor fall 262 + Fire
burst 267 for number 5, replacing 氣功彈 impact 255. The initial implementation
made these sounds hit-only. After the user reported silence, number 5's three
layers now play together at the visible punch release, including empty swings.
Its explicit silent impact marker prevents a second blast when it connects;
damage, contacts and source frame clocks remain unchanged. Number 9's other weapon routes retain
their own original sounds; its actual equipped polearm already uses 108/138.

`tools/prepare_crossgate_player_audio.py '../Magic Power'` prepares six Shin
layered WAV derivatives alongside the unchanged original samples; the same bank
also holds three Kaz Fire mixes. Every input is verified
against original PCM. Layers start together at the existing swing/contact cue,
retain their full tails and original pitch, and share one attenuation if needed
to keep the prepared peak within 30000. No hard clipping, runtime mixing, extra
voice, resource loading during attacks, or contact/timing change is introduced.
Do not edit `special-mix-*.wav` directly; rebuild and run the preparer with
`--check`, followed by `python3 tools/goemon_assets.py check`.

Run the existing `crossgate_player_audio_test.gd` through Play Goemon with
`-- --shin-special --visual` for all nine skins, all weapon routes/eight facings,
hit/miss checks, selected-weapon Studio previews, recording/mute/gain precedence,
cached-voice reuse, five native copies of each skin and a real mixer recording.
Evidence and the numbered gallery live under
`build/Other Files/Asset Toolkit/Shin Special Review/`.

The selected layers also follow shared weapon skills. Prepared per-clip caches
provide effect contacts for Qi/Moon/Spirit gestures and a complete impact for
one-contact Bee Flurry/counters; Combo and charged melee keep their native
patterns. Pure elemental spells keep their own casting sounds. The focused
`crossgate_skin_skill_audio_test.gd` covers all nine reviewed looks and Kaz 1/4;
its receipts and actual desktop recordings are under
`build/Other Files/Asset Toolkit/Skin Skill Audio/`.

Goemon shows two fighters in Character Select. The original 22 regular appearances
cycle sword, polearm and unarmed with **Z**; two recovered fixed sword looks
bring regular Shin to 24; Blue Water Dragon brings the current total to 25. Shin Special has 23 distinct
weapon and aura looks, including the 14 Shin 2.0 additions documented below. Choose **All White / Red Weapons** to swap between the
original red sword (120440) and legacy second stance (120441); explicit Staff
and Spear equipment use the reviewed routes in `../weapons/README.md`.
Gold Polearm (108313) remains selectable. Classic Spear (100055) and Classic
Sword (100053) are hidden duplicates of regular Shin's weapons; their source
records, saved selection and per-skin loadouts remain readable. The selected
skin is saved. Regular Shin starts with the sword in every skin. Shin Special
starts in the skin's first archived stance.

Run `python3 tools/recover_crossgate_shin.py "/Users/eric/Desktop/Projects_Codex/Magic Power"`
from Sonic to regenerate the atlases, portraits and motion manifests from the
preserved Magic Power client. The exporter checks each decoded frame against
its packed pixels and retains the original offsets and all eight facings. It
exports standing, walking, running, attacking, hurt and fall clips.
The original **Red Lightning (118993)** record supplies identical walk and run
pixels/origins in all eight facings, both at 900 ms. The prepared gameplay run
uses the complete six-frame, 500 ms **sword** run from **White Hair / Black and
Red (100181)**, source 100184 / `joy:858`. This supersedes the initial lower-body
only transfer, which left the walking arm and sword pose above running legs.

The native hands, forearms and body now move together. **White Hair / Silver and
Red (100193)** sword 100196 / `joy:865` exposes the same native blade in a readable
color. Subtracting its matching unarmed pose distinguishes blade pixels from
clothing; traced search bands constrain the offline axis/width measurement.
Red Lightning's fully visible direction-4 sword supplies the original blade and
glow artwork, projected onto those source weapon axes. Native hand/body pixels
retain their occlusion. In direction 7 the native body hides the blade entirely;
only the native grip is shown, rather than inventing a blade angle through him.
Outer lightning retains its source frame order/origins outside the replacement
area. Idle, walk, attack, cast, hurt, guard, fall, portraits and combat retain
their original data. No runtime retargeting or extra sprite layer is added.

`python3 tools/prepare_shin_red_lightning_run.py` rebuilds the prepared derivative.
Full recovery and `--cast-only` also reapply it. `original_run` retains the original
run records; base atlases and original cast pages stay unchanged. The derivative
uses one additional cast-prefix page through the existing selection-time loader.
Do not edit that generated page manually. Source-preservation tests check the
original run; `test_shin_red_lightning_run.py` separately checks every native
body/hand frame, the carried red blade, preserved outer aura, axis stability,
original pages and exact repeatable rebuilds. Source studies, the short reviewed
prototype and eight-facing motion review are in
`build/Other Files/Asset Toolkit/Red Lightning Run/Grip/`.
All regular and special skins, including unarmed stances, also export original
action 6 in all eight facings. Add `--cast-only` to refresh just the cast pages
and their motion entries. `cast_pages` counts the prepared pages; aura skins can
need more than one. Some aura casts have no unique release marker, so their
presentation does not define elemental hit timing.

## Regular Shin skills

| Weapon | 1 | 2 | 3 | 4 |
| --- | --- | --- | --- | --- |
| Sword | 乾坤 | 連擊 | — | 明鏡止水 |
| Polearm | 諸刃 | Toggle 反擊 | 一石二鳥 | 明鏡止水 |

While 反擊 is on, a damaging hit triggers a 1,500 base damage retaliation toward the attacker.
Shin stays planted for the opening shine when he turns the toggle on.
A translucent 陽炎 afterimage swings from where he took the hit. Shin still
loses HP and can move, dodge, or continue his own attack or skill through
the hit and the retaliation. During a shadow swing, the latest incoming
attacker and the spot where they hit Shin are queued for the next retaliation.
Each successive hit adds 0.25× speed after the first, up to 3×. Two seconds
without a hit, a normal attack, or another skill resets the speed. The toggle
stays on until Shin switches weapons or turns it off. A known native attacker
must be in reach and clear of cover.

The physical opening shine uses the original Lv. 10–11 charge sheet 110100
and cue 251 (cgefc00.wav). The effect spans five standing heights and the
original source origin sits at Shin's torso. Weapon strikes land on the
recovered contact frame, with the original weapon swing sounded earlier.
The ground circle uses Kaz's line style and shows Shin's basic melee reach.
Shin and Shin Special match Kaz's standing body height in gameplay and
Character Select. Weapons and auras are excluded when measuring height.

乾坤 and 諸刃 empower the existing normal attack, sharing 5,000 base damage
across its native contacts. The sword/weapon reach (or arrow contact) determines
damage; the red EX 111046 / blue EX 111047 burst is cosmetic at the confirmed
victim's body centre. It has no damaging splash circle and never appears on a
miss. Base burst/charge size is 10.8 m, with 親子丼 scaling both the visual and
actual skill area. The default Shin sword's contact flash uses the low blade
midpoint, separate from the victim-centred explosion. Assets/motion are unchanged.

Sword 連擊 keeps seven hops and the recovered 111029 EX. Each hop uses the
wearer's native attack contacts and divides the per-hop damage across them.
It favors fresh targets, can repeat on a lone living target, and immediately
retargets after a kill. Every confirmed primary/splash hit has body-centred
feedback; splash follows the saved skill/food area, with cover checks. The
original charge sound and charge-to-last-contact invulnerability remain.
反擊 uses the 18-frame green EX effect 111053 with the original
standard counter WAV, cue 253. The EX sheet carries no embedded sound.
The 2026-11-16 EX re-audit now verifies the source selector: internal values
below 12 choose ordinary impacts, while 12 and above choose EX. This is an
internal field, not a displayed BlueCG skill level. The operator's
[2015-07-11 announcement](https://www.bluecg.net/forum.php?mod=viewthread&tid=72802)
explicitly says BlueCG Lv.11 battle skills use official Lv.15 effects; the
[2017-04-15 update](https://www.bluecg.net/forum.php?mod=viewthread&tid=190414)
moves fixed-target Combo to displayed Lv.12 and adds Lv.11 Two Birds/Swift
effects. Native selection and the documented public-level policy are verified
separately; a current live-server packet/launcher comparison is still absent.

| Skill | Ordinary resource | EX resource | Documented BlueCG level |
| --- | --- | --- | --- |
| 連擊 | 110133 | 111029 | 11; fixed-target form 12 after the 2017 update |
| 諸刃 | 110134 | 111047 | 11 |
| 乾坤 | 110135 | 111046 | 11 |
| 反擊 | 110153 | 111053 | 11 |
| 一石二鳥 | 110473 | 111054 | 11 |
| 迅速果斷 | 110473, direction 1 | 111049 | 11 |
| 氣功蛋 projectile | 110016 | 111055 | 11 |
| 明鏡止水 cast | 110180 | 111017 | 11 |
| 恢復魔法 arrival | 110176 | 111019 | 11 |

The new audit decodes the original V3 records and checks the existing four
bundled Shin EX masters pixel-for-pixel. It also corrects the earlier assertion
that Qi had no separate EX projectile. Common physical charge has EX 111016;
elemental charge has EX 111001; Recovery cast has EX 111014. Elemental EX
targets are Meteor 111002 (+ variants 111003/111004), Ice 111005, Fire 111008
(+ variants 111009/111010), and Wind 111011. These are separate EX stages
beyond the ordinary four-size inventory. The audit does not silently change
Goemon's 30-level mapping or current gameplay. Evidence, replayable isolated
native checks, original decoded frames and the ordinary/EX preview are under
`build/Other Files/Asset Toolkit/EX Rank Mapping/`.

一石二鳥 hits the first enemy in the polearm's 15 m thrust for 3,750 base
damage. A separate impact behind that enemy sweeps 120 degrees out to
52 m for 9,000 base damage. The rear sweep requires the first contact.
The front and rear use recovered 110473 in source directions 0 and 1.
Direction 1 replays the same packed cells in reverse. The front contact
plays the stance's polearm contact cue and cue 255 (cgefc04.wav). The
base damage uses the published Lv. 11
75% and 180% split applied to Goemon's 5,000 reference. Goemon adapts
the original paired formation to a rear cone.

明鏡止水 plays Shin's original magic cast, action 6, with the equipped
weapon. The recovered standard Lv. 11 cast 110180 appears at half
height with opening cue 261 (cgefc10.wav). Its glow ends at the pose's
release marker. The heal resolves after the casting pose finishes and
plays cue 256 (cgefc05.wav). The archived Meditation command queues
state 0x4e with cue 256 and state 0x9d for the recovery result.
The user-defined level rules (2026-11-16) restore 5% of current missing HP at
level 1, +1 percentage point per level to 34% at level 30. The cooldown is ten
seconds. Original meditation ranks 1–3 use 110183 (90×89), 4–6 use 110182
(157×156), 7–9 use 110181 (265×267), and 10–11 share 110180 (340×342, with
gold sparkles). Our levels 1–9 / 10–18 / 19–27 / 28–30 select those exact
drawings at a fixed world size per source pixel, with no extra level enlargement.
All four retain seven frames, source origins, cast/release timing and sounds.
The large master stays at `shin/meditation.png`; three smaller sheets and their
manifest are under `skill_tiers/`, loaded by the existing setup cache. Rebuild
with `tools/recover_crossgate_skill_tiers.py '../Magic Power'`. Fresh source
rank/cue evidence comes from the archive's `h_meditate` table and
`research/skill-correction-20261031/support-visual-probes.json` (protocol 12).
The green number uses the same
healing digits as Uru and follows the wearer. Native and shared loadout routes
use the same family level and cast snapshot; no new mana cost is added.

The shared 明鏡止水 icon pairs the default red-haired Shin's sword cast frame
3 from action 6, direction 5, with frame 3 of the original 110180 shine.

When Shin takes damage, the same shared gold hit spark and floating number
follow Shin and show his actual HP loss.

From Sonic, run
`python3 tools/recover_crossgate_shin_skills.py '../Magic Power'`
to regenerate the six skill sheets, five icons and skill WAVs. The
exporter checks the packed pixels and retains the source offsets and frame order.
For the opening shine, the local Magic Power archive's
`godot/assets/humanoid-spells/110100.png` and Goemon's
`qigong/charge.png` are byte-identical. The static charge rank table and
Lv. 11 乾坤 render are under the archive's
`research/physical-sequences-20261102/`.

## Basic melee and movement

Both mouse buttons use the same melee action. The controller uses one source
contact marker, or the middle of the clip when there is no usable marker.
Attack clips faster than 650 ms are played at 650 ms with proportional contact
timing. Weapon and aura pixels do not add extra hit checks or projectiles.
The recovered sword and polearm use their original swing and contact samples.
Special attacks retain every original frame, origin, body and effect pixel together
on the existing sprite. Do not cut them with a body mask or replace obscured poses:
that removes hands/weapons and freezes the swing. Their prepared weapon type is
Sword, Spear or Fist, so the normal hit range follows the existing matching stance.
The shared Cross Gate body shader keeps below-foot effect pixels on the ground
without bypassing wall depth; airborne poses keep normal depth. Material setup
belongs to appearance selection, and old skin materials are released on a swap.
Effect artwork is cosmetic; it does not add damage or projectiles. Goemon's
prepared footstep and landing samples supply movement audio.

Both fighters use the shared Cross Gate jump in `scripts/crossgate_model.gd`.
Run `python3 tools/recover_crossgate_jump_guards.py '../Magic Power'` to
prepare the missing guard poses for Kaz, Maze and Shin from their source
records. Uru uses the guard in his main atlas. Maze and Shin each load
their selected look's guard sheet, with one row per weapon in the same
order as the motion manifest. The cells are 120 × 132 with source origin
at (62, 100). New Cross Gate looks should supply all eight guards per
stance, plus the run, hurt and fall clips used by the shared jump.

For a complete Shin animation check, run
`python3 -m unittest discover -s tests/asset-toolkit -p test_crossgate_shin_casts.py`
and `/Users/eric/Desktop/Play\ Goemon.command --fixed-fps 60 --script res://tests/forest-shrine/shin_animation_test.gd`.
The source check compares every prepared idle, walk, run, attack, cast, hurt and
fall frame/origin against the archive, including equipment weapon routes. The
game fixture checks guards, all eight facings, frame playback and real movement
for both visible skins and saved Classic variants. Reports and desktop captures
go under `build/Other Files/Asset Toolkit/Shin Animation Review/`. The test uses
temporary settings and does not change the player's saved loadouts.
Append `-- --red-lightning-only` for the focused fix check, including every run
frame/facing, five native copies and repeated animation without resource growth.
The player walks without Shift and runs while holding Shift; Ctrl's slow walk
takes priority. The focused check also presses/releases the real Shift binding
during player physics and covers the shared selection across the Cross Gate roster.
Focused results and captures go under `build/Other Files/Asset Toolkit/Red Lightning Run/`.

## Shin 2.0 in Shin Special — 2026-11-16

The requested 120352 design and its reviewed related artwork belong to existing
fighter 38, Shin Special. The gallery now has 23 selectable appearances: the nine
existing Special skins plus 14 additions with 58 exact source weapon choices.
The two hidden classic saved-loadout routes remain preserved. Regular Shin and
the Special default 106707 stay at their existing IDs.

`tools/crossgate_shin_2_skins.json` records eight full six-weapon colors
(100882, 105050, 105056, 105062, 105068, 106756, 120346 and 120352), gold weapons
120418 (five supplied choices), fixed gold sword 100299, crimson polearm 108312,
gray fists 120383, gray/purple wings 120382 and purple rune/sword aura 120445.
Pet/effect artwork is selectable under the same fighter; it does not add a new
companion species. Missing native weapon artwork is not fabricated.

Source family metadata merges differently colored 120352 weapons into 120346
and assigns ambiguous labels to 120418. Use the reviewed pack-qualified keys in
the JSON, not inferred numeric siblings. Front/quarter attack frames were
inspected for grips, swing paths and existing effects. Body height is 80 pixels,
measured from this model's body rather than its weapons or aura. Shared timed
combat, atlas loading, weapon selection, head caching and native copies are reused.

The shared special-skin exporter includes this inventory in `--cast-only`.
Keep its generated CAST_CATALOG merge in `scripts/shin_skins.gd` and its explicit
HUD crops in `assets/ui/portraits/crossgate/model-head-crops.json`. Rebuild/check
with the commands in `../bei-moe-ami-README.md`. The focused
`bei_moe_ami_test.gd` also exercises all 14 Shin additions. Discovery, source
motion boards and follow-up evidence are under
`build/Other Files/Asset Toolkit/Shin 2.0 and Pirate Bei/`.
