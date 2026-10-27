# Playable Warcraft characters

Blademaster (stable ID 31) and Illidan (ID 32) are available in the normal
fighter gallery. Launch with `/Users/eric/Desktop/Play Goemon.command`, choose
Play, then select either fighter. Q opens the fighter / Skills & Jump menu.

## Meta meteor fully covered in purple fire — 2026-10-27

Fresh inspection of the original `DemonHunterMissile.mdx` found the previously
omitted 24-triangle rock geoset, `EQ_Rock2` texture and `Sphere09` rotation loop.
The existing recovery script now retains that geometry, UVs, normals, pivot and
native rotation keys, preparing samples of the original 667 ms spin offline.
The recovered core is enlarged to about 3.4 m across in Goemon.

The user's final direction is **flames covering the rock, with no exposed stone**.
Gameplay therefore uses animated purple fire over the original spinning mesh,
soft additive edges and a local 24-particle flame shroud. Its original rock
texture remains preserved in the recovery package. The existing purple glow,
cloud trail and impact bursts remain; the solid shape does not change damage,
hit area, release timing, speed, splash or lifetime. One shared mesh/material
and prepared spin track serve the existing 24 leases. All new nodes are prepared
on character selection, reset on reuse and hidden on impact.

See the [missile guide](../assets/characters/warcraft/demon-hunter/missile/README.md)
for source contracts. Fresh checks: 509 splash/reuse, 15 rendered core/flame,
14 rendered native-target/volley, 46 first-person and 5 fog assertions pass.
The rendered captures use Play Goemon, including Wind Meadow Valley for the
core review. Evidence: `build/Other Files/Asset Toolkit/Illidan Rock/`.
The performance guide records the focused measurements and their limits.
No character master, body animation, army pose bake or app export changed.


## First-person meta arms and fingers — 2026-10-27

Metamorphosis uses Chief's existing first-person camera, mouse look, overlay,
movement bob and fitted-volume aiming trace. Hold LMB to repeat casts; WASD
strafes. Both full arm chains are visible; the world body, head and wings stay
hidden in first person. Normal form restores the ordinary camera. Meta eyes
are now 3.0 m above the player, with an upward cover check below low ceilings;
Chief retains his 1.68 m eye point. Meta multiplies outgoing damage by ten,
including existing upgrade multipliers: an unmodified energy bolt deals 640
instead of 64. Reverse morph removes that multiplier.

The authoritative `Warcraft/assets/Illidan/Illidan.blend` now has five separate,
tapered digits per meta hand, in the existing alternate-body mesh `2 IllidanEvil`.
The edit adds 190 vertices / 340 triangles, weighted to the original two hand
bones. It keeps the original body, textures, UVs, weights, 17 geosets, 302 exported
joints, 24 clips and native black/purple colors. Normal-form hands are unchanged.
The user's follow-up identified a broken-looking left wrist: its 38° resting /
47° maximum casting bend is corrected to approximately 14° / 15° in `Stand
Alternate` and `Attack Alternate`. Only that wrist's rotation curves change;
other animation curves and clip timing stay intact. The thumb tips have a softer
curve. There is no runtime wrist solver or new skeleton.

One-time authoring scripts are `tools/add_illidan_fingers.py` and
`tools/correct_illidan_wrist.py`, `tools/prepare_illidan_relaxed_hands.py` and
`tools/angle_illidan_rest.py`; their guards refuse to overwrite later edits.
Continue normal edits in the saved Blender master and use the existing read-only
Warcraft exporter. Original source snapshots are retained in this Git repository
at `refs/codex/illidan-hand-source`, `refs/codex/illidan-fingers-before-wrist`,
`refs/codex/illidan-before-relaxed-hands` and `refs/codex/illidan-before-rest-angle`.
The original MDX/BLP archives and recovered import remain untouched. The historical
Warcraft `verify_blender.py` native polygon-count assertion describes the original
recovery; additive editing is instead checked against preserved original mesh
prefixes, unchanged unrelated animation curves and imported/runtime checks.

`scripts/illidan_viewmodel.gd` extends `master_chief_viewmodel.gd` and reuses
`warcraft_model.gd`. Selection prepares an owned index-only subset of the two
`Bone_Arm1_* Alternate` chains, preserving the current authored vertices, UVs,
weights, materials, the authored shape target and animation. The overlay blends
the relaxed shape and lowered presentation into casting over the existing clip
clock, then returns to rest; no meshes are rebuilt in that transition. The two
hand sockets frame the gesture; the
right socket supplies the muzzle. Chief's shared trace selects the crosshair
surface and checks eye-to-hand cover. The Warcraft controller retains the
0.26-second release, recovery, speed, splash and existing 24 projectile leases.
Release, pause, focus loss and reverse morph clear held fire. AI/mirror combat
keeps its existing owner. The Blademaster-only native atlas has no Illidan source
dependency and needs no rebuild for this hand edit.

Run `tests/forest-shrine/illidan_shooter_test.gd` through Play Goemon for arm
isolation, aiming, cover, held fire, raised eyes, damage and resource reuse.
Inspect ready, windup and release: the fingers should remain distinct and the
left palm should follow the forearm. Export/audit/comparison and correction
reports are under `build/Other Files/Asset Toolkit/Illidan Hands/`; rendered FPS
captures remain under `Illidan Shooter/`. See the performance guide for fresh
results and limits. No app export is needed.

## Blademaster original red and hero aura — 2026-10-27

The requested red version supersedes the charcoal choice below. The exporter
uses original team slot **00** for both `TeamColor00.png` and `TeamGlow00.png`
from `Warcraft/assets/Blademaster/original/ReplaceableTextures/`. Their original
BLPs and archive provenance remain in that package. This restores the red banner
and clothing accents while preserving the original green skin.

The native `HeroBladeMaster.mdx` already contains the hero aura: `Geoset_00`
and `Geoset_05` use replaceable texture ID 2 (TeamGlow), with original 0.75
opacity in Stand. The charcoal export dimmed these textures as well as the cloth.
Red slot 00 restores their brightness through the existing camera-facing glow
meshes. `Geoset_07` / `Geoset_08` use the original `Textures/Red_Glow3.blp`;
Bladestorm and Critical Strike retain their recovered GenericGlow2c / Flame4
particles. No additional aura simulation is needed. The existing red runtime
effect tint remains; the shared effect adapters retain control of their Godot
presentation.

Re-export with `-- Blademaster`, optimize/compare/activate `warcraft-blademaster`,
refresh imports, rebuild `tools/bake_warcraft_allies.gd` and capture portrait 31.
The player, five prepared Mirror Image bodies, native atlas and portraits use
the same red source. Both editable masters, 14 actions, all 1,732 geometry/skin/
animation accessors and opacity tracks are unchanged. Only the cloth composite
and two team-glow textures changed. Evidence and source hashes are under
`build/Other Files/Asset Toolkit/Blademaster Red/`. No app was exported.

Fresh desktop checks pass 434 character, 56 skill and 97 energy assertions,
including simultaneous copies and zero retained resources after repeat use.
Source preservation, 47,599 Warcraft imported assertions and 1,057 native atlas
assertions pass; representative source/candidate renders and gameplay captures
were inspected. These focused checks do not establish full-army performance.

## Human Peasant workforce — 2026-10-26

The normal workers now use the original Human Peasant (`hpea`) recovered from
the local Warcraft archives: native skin/geometry, all 22 exported actions,
Gold sack motions, portrait and exact construction/repair WAVs. The original
`SNDXAREP` event selects Repair / PeonRepair1–3.wav at 234 ms into Stand Work.
Its saved editable body and portrait masters remain in the adjacent
`Warcraft/assets/Peasant/` package. This worker is not another playable hero.

The existing workforce owns jobs/costs/movement/repairs and tower combat. Shared
prepared poses reuse the existing army format/shader; construction reuses its
four voices. No live worker skeleton, runtime retargeter, second simulation or
fallback was added. Goemon's bow and targeting share the new native hand grip.
The previous Goemon worker and sounds remain preserved as source assets.

See [the Peasant guide](../assets/characters/warcraft/peasant/README.md) for source
paths, audio provenance, offline bake, toolkit and desktop verification commands.
Fresh results and older baseline failures are recorded in the performance guide.
No app was exported; use the normal Play Goemon launcher.

## Illidan splash and recovered missile effects — 2026-10-26

The bolt now has a 0.9 m swept-contact radius and flies for four seconds at
28 m/s (up to 112 m). On enemy or wall contact it damages nearby enemies once:
64 base damage within 1 m, 32 within 3 m and 16 within 5 m. The direct target
always takes the full base hit. Native local queries, fitted hurt volumes and
line-of-sight checks retain cover and airborne contacts. A miss expires normally;
the impact particles do not create a lingering damage area.

Fresh archive inspection identifies the actual Meta asset as
`DemonHunterMissile`, selected by campaign unit **Eevm**. It includes a continuous
cloud trail and two impact squirts omitted by the former glow-only projectile.
These now use unchanged recovered textures and prepared Godot particles with
the requested purple tint and Unfogged materials. The 667 ms impact is cosmetic.
Warcraft's standard **Edmm** weapon explicitly uses splash and 50/150/250 source
radii with 100/50/25% factors. Campaign **Eevm** contains those same fields but
declares `missile`; the requested Goemon splash is explicitly enabled here.

The existing pool now warms 24 leases for longer flight plus impact playback.
No resources are loaded or constructed during flight or contact. Source
provenance, approximations and recovery instructions are in the
[missile guide](../assets/characters/warcraft/demon-hunter/missile/README.md).
Evidence belongs under `build/Other Files/Asset Toolkit/Illidan Splash/`.
No animation, melee timing, editable master, character GLB or army bake changed.
Fresh checks pass 142 focused combat, 14 desktop splash/render/reuse, 423 desktop
character, 97 desktop energy and 27 headless flight assertions. Five volleys of 24 shots add no
resources, nodes, cached textures or pool misses after warmup. These focused
results do not establish full-battle or long-session performance.

## Larger Illidan bolt — 2026-10-26

The follow-up size request increases the bolt's visual width and height by 50%
(`pixel_size` 0.24 → 0.36), superseding the fourfold-size entries below. It reuses
the same purple texture and pooled sprite with the corrected Unfogged material.
Damage, 0.45 hit radius, release timing, speed and lifetime remain unchanged.
No Blender master, GLB, army bake or app export is needed. Same-camera old/new
captures and repeat-use results are in
`build/Other Files/Asset Toolkit/Illidan Bolt Size/`.
Fresh checks pass: 97 desktop energy/reuse assertions, five rendered fog
assertions and 27 headless flight assertions. The square remains absent.

## Building placement sound — 2026-10-27

General building placement uses Warcraft III's original `PlaceBuildingDefault`
cue, `Sound\Buildings\Shared\BuildingPlacement.wav`. Successful tower, barracks,
mine, wall, gate, shrine and enemy-castle placement plays once; a wall drag plays
once per successful batch. Worker hammering remains separate. The existing four
construction voices are reused, with no per-placement loading or nodes.
Source table and byte-for-byte preservation evidence are in
[`assets/audio/warcraft_building/`](../assets/audio/warcraft_building/README.md).

## Guard Tower sound recovery — 2026-10-26

The normal Forest arrow tower now uses the original Human Guard Tower's three
launch variations and its missile's `ArrowHit` impact. These four WAVs were
recovered byte-for-byte from the local Warcraft archives. Model event IDs,
patched unit selection, sound-table rows and file/PCM hashes are recorded in
[`assets/audio/warcraft_tower/`](../assets/audio/warcraft_tower/README.md).
The existing audio bank prepares them once; the shared voice pool handles
playback. Impact timing, visibility, pause, recording and master-volume behavior
retain their existing owners. The old tower-specific bow routing/counter was
removed; Ranger recordings and previews remain independent. No app was exported.

## Illidan bolt square in fog — 2026-10-26

The user clarified that the reported Meta attack problem was a square around
the bolt. Re-reading the original `IllidanMissile.mdx` confirms its
`Green_Glow3` layer uses additive blending (`FilterMode=3`) and
`Shading=33`: Unshaded (1) plus Unfogged (32). The Goemon projectile had additive
blending but omitted Unfogged, allowing scene fog to fill the whole sprite quad.
`warcraft_projectile.gd` now sets `material.disable_fog=true` during pool setup.
The existing purple texture, fourfold size, attack animation, release timing,
damage, collision, travel and pooling remain intact. No asset export is needed.

The desktop regression `tests/forest-shrine/warcraft_bolt_render_test.gd`
reproduces the old square and verifies the corrected material against an empty
background in fog: maximum corner-channel difference falls from 0.521569 to
0.003922, while the purple core remains visible. All five checks pass. The
desktop energy fixture passes 97 checks, including five rounds of twelve
simultaneous bolts with no resource/cache growth or pool misses. Captures and
logs are under `build/Other Files/Asset Toolkit/Illidan Meta Attack/`.
The desktop character fixture also passes 423 checks, including actual native
damage, cover, cancellation and repeated attacks, with zero resource growth.
Use Play Goemon, select Illidan, transform and fire toward foggy distant scenery.

## Illidan face depth and fourfold Metamorphosis bolt — 2026-10-25

Close-up desktop renders reproduced rear head/hair triangles covering Illidan's
face. The runtime adapter had forced every native material into ordinary alpha
blending. Native cutout surfaces (`mode == 1`) now use an alpha depth prepass,
so solid face pixels occlude the triangles behind them. Original textures, rigs,
motion and the wings' authored 0.8 opacity remain. Other blend modes keep their
previous path: applying the prepass to the alternate form's black silhouette
occluded its embedded purple glows in the first comparison and was rejected.
The shared adapter also serves player-model mirrors. Its dependent native
Blademaster atlas and both gallery portraits were rebuilt through their tools.

The existing purple Metamorphosis projectile is now **four times its immediately
previous width and height** (`pixel_size` 0.06 → 0.24). This supersedes the earlier
threefold-size entry below. It retains additive blending, release timing, damage,
0.45 hit radius, flight speed, lifetime and pool capacity. No model or material
is built during firing, and no editable master or GLB was changed.

Use Play Goemon, select Illidan, view his normal face from the front/side, press
1 to transform and fire repeatedly. The face should be solid, wings translucent,
alternate body glow purple and the projectile visibly larger. Evidence and
final test logs are under `build/Other Files/Asset Toolkit/Illidan Face/`;
`warcraft_energy_test.gd` also saves close-ups and same-camera bolt comparisons
under `Warcraft/Energy Colors/`. No app was exported.

Fresh desktop checks pass 97 visual/reuse, 423 character and 56 skill assertions.
Twelve simultaneous bolts over five reuse cycles add zero resources, cached
textures or pool misses; both character repeated-use segments and the shared
skill segment also retain zero resources. The twelve-sprite, fixed-camera
120-frame comparison measured old/new frame interval p95 18.530/18.574 ms and
max 19.848/25.010 ms. These short samples do not establish a speedup, full-battle
smoothness or long-session stability. No other regression job ran concurrently.
Native atlas checks (1,057), Warcraft imports (42,791), toolkit unit tests (67),
common imports (12,812), Musashi outfits/motion (98/25), structures (86) and
asset preservation pass. Existing scene-shutdown resource/RID warnings remain.

## Blademaster charcoal team color — 2026-10-25

Goemon's Blademaster uses original team-color slot **12**, charcoal `#282828`,
with its matching original team glow. `tools/export_warcraft_characters.py`
substitutes the existing `TeamColor12.png` / `TeamGlow12.png` during asset
preparation and records `team_color: 12` in the motion sidecar. The editable
body and portrait masters keep their original saved materials. Green skin,
geometry, rig, all 14 actions and combat timing are unchanged; no color work
was added to combat or frame loops.

Re-export only this character with `-- Blademaster`. This also renders the HUD
portrait from its original portrait master with the same team color. Follow the
staged optimization/comparison/activation checks below, then rebuild
`tools/bake_warcraft_allies.gd` and capture selection portrait `31`. Both native
ally presentation and player-model Mirror Image copies must match the player.
Evidence for this change is in `build/Other Files/Asset Toolkit/Blademaster Team 12/`.

Fresh validation: all 1,732 source accessors and motion tracks match the previous
export; only the body team-color composite and two glow textures changed. Both
saved masters are unchanged. Preservation, 67 toolkit unit tests, 42,791 imported
Warcraft checks, 1,057 native mirror checks and the required common asset/outfit/
motion/structure checks pass. Source/candidate comparison captured 72 pairs;
representative pairs and the refreshed portraits were inspected.
Desktop character/skill fixtures pass 423/56 checks, with zero repeated-use
resource growth and zero projectile-pool misses. Their frame-interval p95 values
are 17.491/17.619 ms, respectively. These short fixtures establish neither a
speedup nor full-army/long-session performance. Existing scene-shutdown resource
warnings remain. The player and live copies were visually checked; no app was exported.

## Illidan replacement — 2026-10-25

Slot 32 now uses the original winged `IllidanEvil.mdx` from the local expansion
archive. Its authoritative editable source is
`/Users/eric/Desktop/Projects_Codex/Warcraft/assets/Illidan/Illidan.blend`;
the same package contains the original portrait, packed textures, native files,
extraction hashes and editing README. The old DemonHunter masters remain intact.
The gallery and HUD say **Illidan**. The stable `demon-hunter` resource/skill keys
remain so saved settings and equipped Immolation still resolve.

All 24 body actions, 17 independently visible geosets, 302 exported joints,
76 billboard bones and four prepared emitters remain. The native source has
191 deforming bones and 1,546 triangles; GLB exports 1,534 nondegenerate
triangles. The optimized derivative preserves them and reduces material
resources from 17 to 6. It retains the 17-surface budget warning. Native
swimming actions and water-wake particles remain available without adding new
swimming gameplay. The game keeps the existing sounds and shared spell effects.

Only the exported `Attack` and `Attack 2` clips are fitted to the existing
0.9-second recovery; original Blender timing stays editable and unchanged.
The existing controller still owns the 0.26-second contact, damage, range,
cooldowns and movement. Model size and attack-speed settings keep slot 32's
existing defaults. Run the exporter with `-- Illidan` to export only this master,
then optimize/compare/activate `warcraft-demon-hunter` using the commands below.
Refresh effect metadata with `tools/recover_warcraft_effects.py`, rebuild the
shared-metadata-dependent mirror atlas, and capture portrait 32. The gallery
camera includes the full wingspan.

Fresh validation and captures live under
`build/Other Files/Asset Toolkit/Illidan/`. Native Blender checks pass for all
24 body and four portrait actions, packed textures, weights, deformation and
action-switch stability. There are 67 passing toolkit unit tests; both staged
and activated Warcraft imports pass 42,791 checks. Lossless preservation passes;
72 rendered source/candidate comparisons were captured, with representative
pairs reviewed. Native mirror validation passes 1,057 checks, common imported
assets 12,812, Musashi outfits 98, Musashi motion 25 and structures 86.

The desktop character fixture passes 423 checks, including Illidan identity,
both forms, original action coverage, unchanged recovery/contact behavior,
native targets, cover, death/respawn and repeated bolt leases. Pool misses and
repeated-special resource growth are both zero. Its focused frame interval
p95/max is 17.296/33.227 ms; manually stepped player/projectile work p95/max is
0.672/1.994 ms. This is a short rendered fixture, not a full-army benchmark or
long-session leak claim. Existing whole-scene teardown warnings remain.
Earlier Demon Hunter measurements later in this document describe the original
port, not fresh Illidan results. No app was exported.

The current desktop skills fixture also passes 56 checks, including Immolation,
borrowed skills, native mirror use and camera-facing effects. Repeated skill
use adds zero resources; its frame interval p95 is 17.233 ms and manually stepped
work p95 is 1.740 ms. Screenshots of normal form, transformed form, attacks,
Immolation and the refreshed portraits were inspected. Those figures retain
the same short-fixture limits above.

## Native energy colors and larger demon bolt — 2026-10-25

The original Warcraft glow geosets and spell particles now use purple for
Illidan and red for Blademaster. This includes the existing ground/weapon glows,
Immolation, Bladestorm, Critical Strike and Wind Walk/Mirror Image flash. The
original shapes, billboard motion, intensity/opacity tracks and particle
lifetimes remain. Blademaster's charcoal clothing and both fighters' skin,
wings and smoke are unchanged. Source GLBs and editable Blender masters retain
their original materials; these are owned runtime material overrides.

`warcraft_effects.gd` prepares and caches neutral copies of existing colored
textures during selection/setup, preserving brightness and alpha without
modifying the shared source images. Reused models, mirrors and projectiles use
those copies; casting does not recreate textures or materials. Rebuild the
native atlas after changes to this shared preparation code.

The existing demon bolt is purple and three times its previous visual diameter
(`pixel_size` 0.02 → 0.06). Its black-backed native glow uses additive blending.
The 0.26-second animation release, 64 base damage, 28 m/s speed, 0.45 hit radius,
2.5-second lifetime and shared projectile pool are unchanged. The original
metamorphosis ranged clip is `Attack Alternate`; `Spell Alternate` is a separate
casting action. Normal-form `Attack 2` is Illidan's spinning glaive attack.

Focused evidence is under `build/Other Files/Asset Toolkit/Warcraft/Energy Colors/`.
`warcraft_energy_test.gd` checks source-texture isolation, original body materials,
effect hues, native particle playback, real ranged release and five rounds of
twelve simultaneous reused bolts with stable resource/cache counts. Its small/
large captures compare the same purple bolt at both sizes in a clear view,
not the old green render. Final energy checks pass 74 headless / 79 desktop
assertions, with no pool misses or resource/cache growth. The desktop character
fixture passes 423 checks and the current skills fixture passes 56, including
five simultaneous copies and settled repeated-cast counts. The initial skills
run counted live impact flashes; the settled run has zero node/resource delta.
Native atlas checks pass 1,057 assertions with zero sampled transform error.
Preservation, 67 toolkit unit tests, 12,812 imported asset checks, 98 Musashi
outfit checks and 86 structure checks pass. The two-model audit has no read
errors; the existing 9/17-surface budget warnings remain. These are focused checks,
not a full-army benchmark or long-session soak. No app was exported.

## Controls

| Character | Left click | Right click | 1 | 2 | 3 |
| --- | --- | --- | --- | --- | --- |
| Blademaster | Attack → Attack 2 → Attack Slam, one click per cut | Critical Strike (original Attack Slam) | Bladestorm | Wind Walk | Mirror Image |
| Illidan | Two glaive cuts; demon form fires a purple bolt | Toggle Metamorphosis | Toggle Metamorphosis | Toggle Immolation | — |

Both reuse WASD, sprint, jump, evade, health, progression, character balance,
audio settings and the five assignable skill slots. Bladestorm, Wind Walk, Mirror Image and Immolation are available
in the shared skill catalog and can be equipped on another fighter. Metamorphosis belongs to Illidan's own body.
These are Goemon combat adaptations, not a Warcraft RTS rules implementation:
Bladestorm lasts 3 seconds, deals twelve 24-base-damage pulses and has an 8-second
cooldown. Normal cuts deal 48 base damage; the slam deals 90. Demon bolts deal
64, travel at 28 m/s and expire after 2.5 seconds or the first enemy/solid contact.
Metamorphosis is a toggle with a 2-second cooldown. Existing damage, attack-speed,
reach, growth and cooldown settings apply. Warcraft has no jump clips, so shared
jump physics uses the original ready pose in the air.

Normal-form Illidan's second jump now adds one forward somersault (2026-10-26).
It reuses Hero's existing second-jump presentation clock and torso-pivot turn,
timed to Musashi's `FLIP_DURATION` of 8/30 seconds. The intact `Stand Ready` rig,
glaives and wings turn together; the first jump, collision, lift and attack
timings stay unchanged. The visual transform resets on other poses, so attacks,
morphing, landing and reselection cannot retain a partial turn. Meta flight stays
upright. No incompatible Musashi bone animation was copied into the Warcraft
skin, and no Blender master or GLB was changed. Rebuild the dependent native
atlas after changing this shared model adapter. The focused rendered/reuse test
is `tests/forest-shrine/illidan_flip_test.gd`; evidence is in
`build/Other Files/Asset Toolkit/Illidan Flip/`.

As of 2026-10-26, transformed Illidan uses Dark Lumina 3's existing shared flight:
hold **Space** to rise, release it to descend, and hold **Shift** to boost.
Horizontal speed is 36/64, ascent is 18/32 and descent is 10, using the same
acceleration and progression scaling as Dark Lumina 3. Normal Illidan retains
his double jump. An explicitly equipped Jump Style overrides this default;
**Original** restores form-dependent flight. Reversing Metamorphosis in midair
restores ordinary gravity; switching fighters resets the form. Airborne attacks
still use the original combat and the current pooled bolt visual. The existing
`Stand Ready Alternate` pose supplies the floating presentation without asset
changes. HUD/gallery hints include the controls.

Jump audio uses the shared recovered Goemon/Yae takeoff effect (ROM event `21D`,
`assets/audio/recovered_yae/event_21d.wav`), without a character voice. This is
an intentional cross-game default, not a recovered Warcraft jump cue. The old
generated jump beep is no longer loaded. Sound Studio recordings, gain and mute
still apply to each fighter.

Character Balance exposes **Model size ×** (default 6) and **Attack speed ×**
(default 3) for both fighters. Values save independently, apply immediately to
the selected fighter and reset to these defaults. Model size scales the original
visible model, including its weapons and both Illidan forms; collision and
the separate Melee reach setting retain their own values. Attack speed advances
normal cuts, the critical strike and demon-bolt release/animation together,
before existing level, combo and power-up bonuses. Skill durations, pulse counts,
cooldowns, per-hit damage and projectile travel keep their existing settings.

## Preserved source and runtime structure

### Regular cut reach and blade ribbons — 2026-10-27

Blademaster and normal-form Illidan use a 3.6-unit primary reach (previously 3.0),
through `warcraft_kit.gd`. Existing contact-size, melee-reach, pickup and skill
multipliers still apply. The native Blademaster profile and these fighters'
mirror approach ranges use the same base. Original contact timing, combo order,
damage, facing and cover checks remain in `warcraft_combat.gd`; Bladestorm,
Immolation and Metamorphosis bolts keep their existing ranges.

The selected model prepares one red sword ribbon or two purple glaive ribbons
using Kojiro's existing `recovered_leader_trail.gd`. `warcraft_model.gd` stores
blade endpoints in the original Sword / L_stand_blade / R_stand_blade bone space;
the tips are checked against the imported weighted mesh vertices. No animation,
GLB or Blender source is changed. Ribbons sample during the source contact window
(0.12 seconds before through 0.16 seconds after contact), fade over 0.18 seconds,
and clear on cancellation, selection, death and mirror retirement. Alternate-form
bolts and borrowed invisible rigs do not draw melee ribbons. The shared ribbon
still rebuilds its small dynamic mesh while visible; its node and material are
prepared once, with no per-cut model/material load or new effect pool.

Run `tests/forest-shrine/warcraft_melee_test.gd` through Play Goemon for boundary,
cover, blade attachment, cancellation and six simultaneous fighter checks. Its
captures and ribbon-disabled/enabled focused timings are under
`build/Other Files/Asset Toolkit/Warcraft/Melee/`. The native pose atlas must retain
its current model-source fingerprint even though these ribbons do not alter poses.

The [workbench instructions](../assets/blender/characters/warcraft/AGENTS.md)
point to the single authoritative saved masters in the Warcraft project. Both
master hashes are recorded in the exported motion sidecars and were unchanged
by export. Blademaster retains 14 body actions / 84 joints; Illidan retains
24 body actions / 302 total joints, including its effect bones. All 42 + 79
recovered WAVs remain available; attacks, impacts, spin, morph, death and demon
shots use originals through the existing audio bank. Portrait/showcase Blender
files and the native archives remain in the source project.

GLBs live under `assets/models/characters/warcraft/`; prepared visibility,
particles, portraits and original audio under `assets/characters/warcraft/`.
`tools/export_warcraft_characters.py` exports saved edits; it never saves a master.
GLB carries skin animation, while the sidecar retains custom opacity and prepared
particle tracks. Materials and particle nodes are prepared once per selected
model; attacks only seek animation and update existing presentation. Materials
are owned by each model so one form cannot hide another character. Original
mesh names, weights, UVs and joints remain intact. Palette/team-layer composition
and dark-smoke alpha are prepared during export, not rebuilt during combat.

Godot uses the existing Hero / CharacterCombat lifecycle, AttackChain's native
local queries and precise contact checks, and CharacterProjectiles' lease pool
(12 prepared demon bolts). There is no second army runtime, new enemy controller
or runtime retargeter. Universal Mirror Image uses the same native owner for
movement, targeting, health and retirement, with five prepared instances of the
selected character model/combat. The original GLBs remain unchanged. The older
`assets/characters/ally_crowd/31.res` atlas remains a preserved reference.
Wave counts, scenery and other fighters retain their existing ownership.

## Added Warcraft skills and recovered glows — 2026-10-25

- Wind Walk gives 8 seconds of stealth, a translucent body and 50% faster movement.
  The first offensive attack ends stealth and carries double damage through the
  existing AttackChain ticket/hit filter. Cooldown: 12 seconds.
- Mirror Image creates five copies of the current caster for 15 seconds. They
  spawn around the caster with wider spacing and approach a shared enemy from
  different sides within their existing attack reach. Blocked sides fall back
  to the normal approach; cramped spawn areas use the existing clearance search.
  They immediately pursue visible enemies within their existing local search range,
  favoring nearby targets that other images have not claimed. They still team up
  on a lone enemy and randomly choose the caster's normal attacks and equipped skills.
  They wait when no nearby enemy is visible; there is no formation/march opening
  or compulsory Bladestorm, and they cannot summon more images.
  Native health, local queries and terrain movement remain
  under the army owner; attacks use the existing character controllers and
  pooled projectiles. Cooldown: 22 seconds. No gold, food or mercenary slot cost.
- Immolation toggles on/off. While active it deals 30 base damage in a 3.5-unit
  radius once per second, through existing native candidates and exact contact /
  solid-cover checks. Existing player damage and contact/range modifiers apply.
  Turning it off, dying or changing fighters clears it. There is no mana drain.
- Critical Strike keeps the original **Attack Slam**, its source contact at
  0.733 seconds of animation, and the recovered **CriticalStrike.wav**. Attack
  speed advances both animation and contact together. It is right click and
  the third normal combo cut, not a replacement animation.

Reassigning a native skill cannot stack two Wind Walks, two auras or two mirror
armies on the same caster. Power/timer state follows the existing controller and
spell-instance lifecycle; switching and death retire native mirror leases.
Mana Burn is intentionally excluded at the user's request.

The original MDX flags identify 13 Blademaster and 76 Illidan billboard
nodes that the Blender camera constraints could not reproduce in the game.
`warcraft_model.gd` faces only those effect bones toward the active camera,
including the four upright-only nodes, while preserving their animated position
and scale. Ordinary body/weapon animation stays on the original rig. The mirror
atlas carries the same effect flags, original per-geoset opacity and all nine
geosets through the existing army batch upload. Its 57 used skin binds are
sampled at 60 Hz, including the original Critical Strike.

`tools/recover_warcraft_effects.py` reads the original MDX JSON/PNG assets and
records their hashes in `assets/characters/warcraft/effects/sources.json`.
Reusable pieces include Clouds8x8FadeWhite (Immolation), GenericGlow2c (spin),
Flame4 (slam), and Green_Glow2/3 (spell glows). Three prepared emitters reuse
the original atlas layout, size curves, rates and lifetimes with the requested
red/purple hues. They live under
the visible model so its rotation and Model size setting apply automatically;
combat only starts/stops prepared nodes. Immolation hit feedback uses the
existing pooled army presentation. No Blender master was edited.

Godot particle presentation remains an adaptation, not a complete MDX particle /
ribbon emulator. The original Blademaster ribbon trail is not reconstructed;
body glow meshes and spell particles are restored. The shadow demon is
intentionally very dark. Demon bolts recolor the recovered green glow purple without
emulating the standalone MDX missile particle system.

## Rebuild and verify

For effect recovery or changes to the model/ally pose preparation:

```sh
python3 tools/recover_warcraft_effects.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/bake_warcraft_allies.gd
python3 tools/goemon_assets.py audit
python3 tools/goemon_assets.py check
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/forest-shrine/army_warcraft_test.gd
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/warcraft_skills_test.gd
```

The generated mirror resource records source fingerprints; never edit it or its
hashes to bypass a stale-source failure. Original model exports still follow the
preservation/optimization workflow below, then rebuild the mirror atlas.


```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/export_warcraft_characters.py
python3 tools/goemon_assets.py audit assets/models/characters/warcraft
python3 tools/goemon_assets.py optimize --asset warcraft-blademaster
python3 tools/goemon_assets.py optimize --asset warcraft-demon-hunter
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/asset-toolkit/warcraft.gd
python3 tools/goemon_assets.py compare --asset warcraft-blademaster --capture
python3 tools/goemon_assets.py compare --asset warcraft-demon-hunter --capture
# Review preservation, imported motion and captures before activation.
python3 tools/goemon_assets.py activate --asset warcraft-blademaster
python3 tools/goemon_assets.py activate --asset warcraft-demon-hunter
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import
python3 tools/goemon_assets.py check
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/asset-toolkit/warcraft.gd -- --packed
"/Users/eric/Desktop/Play Goemon.command" --script res://tools/capture_playable_enemy_portraits.gd -- 31 32
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/warcraft_characters_test.gd
```

## Original Demon Hunter port validation (historical)

The initial lossless candidates retained 543 / 1,241 exported triangles, 9 / 17 geosets,
and all actions and joints. Materials reduce from 9 → 6 and 17 → 7; independent
visibility prevents merging the geosets. The surface budget warnings are retained
and do not authorize decimation. Source/candidate motion checks cover every clip
at five times, with 32,211 assertions; rendered comparison saved 72 pairs per
character. Tiny isolated edge-pixel differences remain after vertex welding.
The initial port's desktop and headless gameplay runs each passed 375 checks with zero
projectile-pool misses. Repeated specials added no resources after setup. The
desktop real-time segment had p95 frame interval 18.111 ms; manually timed player
and projectile work had p95 0.645 ms. These focused timings do not include a
full-army stress load or establish an improvement over other fighters.
The desktop gameplay fixture covers selection, imported actions, original audio,
melee and bolt contacts, interruption, shared jump, transformation/reversal,
borrowed Bladestorm, native army targets, walls, death/respawn and 100 repeated
projectile leases. Reports and captures are in
`build/Other Files/Asset Toolkit/Warcraft/`; toolkit comparison pairs are beside
that folder in `warcraft-blademaster/` and `warcraft-demon-hunter/`.

That port's checks also included 65 toolkit unit tests, 12,812 toolkit import assertions,
98 Musashi outfit checks, 13 Musashi motion checks and 86 structure checks.
The numbered-slot regression also passes 571 checks, including both new IDs.
The broader gallery suite selects every visible fighter but retains eight stale
expectations about hidden balance entries and the old secondary shortcut; those
failures are not counted as passing. The current balance screen intentionally
includes hidden IDs, as documented in the character-balance guide.
Early integration/import and cover diagnostics are retained separately from the
accepted final logs. Whole-scene fixture shutdown resource/RID warnings remain.
This is not a full-army performance benchmark or a long-session leak test.
No app was exported.


## Added-skill validation

Historical validation before universal copies: the desktop launcher and headless
skill fixture each passed **55 checks**:
original Critical Strike/contact/audio, Wind targeting/speed/opening damage,
Immolation cadence/cover/toggle, all three borrowed skills, duplicate assignments,
five one-time native storms followed by sword hits, expiry, repeated lease reuse,
death/respawn and camera-facing effects. Desktop captures were inspected.
The desktop segment recorded five storms and 52 normal mirror contacts; repeated
cast/cancel added zero nodes and zero resources. Frame interval p95 was
17.466 ms; manually timed player/native/presentation work p95 was 1.295 ms.
Those measurements describe the earlier fixed-Blademaster implementation, not
the current universal copies or a full-army soak.
The sixfold visual size remains separate from the existing collision and reach
settings, so giant mirror models can visually overlap around one small enemy.

Native kit / pose preservation passes 1,057 checks (maximum sampled transform
error zero), packed buffer parity 3,018, native runtime 4,109 and knight 33.
Current character checks pass 407; modular skills 3,398; numbered controls 577;
idle skill work 7. Both activated Warcraft imports pass 32,211 checks. Audit
reads 299 assets without errors; preservation, 65 toolkit unit tests, 12,812
import checks, 98 Musashi outfit checks, 13 motion checks and 86 structure checks
pass. No additional source GLB/Blender export or app export was needed.

The broader `army_hunting_test` still has three Explorer guard/pursuit failures:
its assertions expect unrestricted pursuit, but the current native guard-radius
branch retains the guard post. This change does not alter that existing branch
or weaken those assertions. Known whole-scene teardown RID/resource warnings
remain; zero growth in this short repeated-use check is not a long-session leak
claim. Early fixture failures (immortal dummy, intersecting cover, unfrozen
victim and live mouse camera steering) are retained as diagnostics, not counted
as passing runs. Full logs: `build/Other Files/Asset Toolkit/Warcraft/` and
`build/Other Files/Large Army Rebuild/Tests/`.


## Universal Mirror Image and Wind Walk correction — 2026-10-25

Wind Walk's green source glow is additive art: its black pixels must contribute
no light. Its prepared material now uses additive blending, removing the dark
translucent rectangle while preserving the translucent character.

`scripts/forest/crowd/mirror_body.gd` is a single pooled adapter for the existing
Hero models/controllers. Native kinds 101–132 identify the copied fighter. Five
bodies are prepared when the skill/character is selected, reused on casts and
retired through the native lifecycle. Their clocks run with army integration,
including the worker and compact-event paths, independently of caster hit pauses.
Enemy pursuit stays native; only an authored attack uses existing character
motion. Projectile leases and held inputs are cleared before reuse. Master Chief
copies aim from their own bodies and do not control the player's camera.

The current universal fixture checks all 32 models, scales and original attack
paths, borrowed offensive skills, prevention of recursive summons, waiting without
a target and expiry. Native and rendered fixtures check immediate pursuit; the
native fixture also checks nearest-target choice and target loss. See the
performance guide for current measurements and limits; earlier fixed-Blademaster
validation above is historical.

## Illidan meta first-person hands — 2026-10-27

The player’s transformed form uses Chief’s existing first-person camera, overlay,
bob, shared aimed trace, and pooled bolts. Eyes are raised to 3 metres with a
ceiling guard. The complete body is hidden in this view. Meta multiplies existing
outgoing damage by ten (the unchanged base-64 bolt deals 640 before other boosts).
Leaving meta or changing character restores the ordinary camera and damage.

The approved resting concept uses straight wrists, palms slightly inward, and
loosely curled fingers. The close-up sculpt adds anatomical palms, thumb pads,
knuckles, tendons, charcoal/violet skin variation and tapered claws. Subsequent
requests doubled arm thickness, then doubled palms/fingers/claws. Its expressive
cast opens/fans the fingers and pushes the palms forward, returning to rest.
The controller still owns release timing, damage, movement and repeat-fire cadence.

The authoritative FPS master and export/check instructions are in
`assets/blender/characters/warcraft/AGENTS.md`. This replaces the old runtime
triangle-filtered full-body clone. Only the prepared two-mesh model and its 37-bone
rig are loaded on selection; combat seeks baked clips and updates the existing
socket. Native army/world presentation retains the external Warcraft master.
The rejected screen-space 30-degree rotations were removed from that master;
its exported source again matches the previously validated active derivative.

The isolated hand viewport uses layer 1: the previous layer-20 setup rendered
unlit silhouettes on the tested Metal path. Muzzle transforms are evaluated from
the current wrist pose immediately, avoiding the imported attachment’s delayed
update during the release/cover check. Keep this synchronized with the shot trace.

Focused correctness and rendered gameplay evidence is under
`build/Other Files/Asset Toolkit/Illidan Hands/`. The reference concept is not a
captured gameplay frame; actual final renders are under that folder’s `Final/`.

The subsequent hand refinement spreads both casting thumbs farther, with a
20-degree additional base opening and 8-degree mid/tip extension. The other four
fingers and their claws are 10% shorter along their length; their thickness,
palms, thumbs and enlarged arms retain their prior size. All eight finger chains
were shortened together with their skin and claw geometry in the editable master.
Idle/recovery thumb keys, the palm muzzle, clip timing and combat remain unchanged.
Evidence for this refinement is in `Illidan Hands/Thumb Spread/` under Asset Toolkit.
