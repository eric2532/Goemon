# Goemon cosplay roster

The user approved this direction on 14 October 2026: every playable hero uses
Goemon's actual body, painted face and spiky hair, with the hero's colors,
costume details, equipment and existing playstyle. This supersedes the older
instruction to create distinct faces and body types.

Goemon remains the reference. Eleven costumes cover Edo, Pirate, Samurai,
Ninja, Mage, Knight, Dragoon, Magic Swordsman, Ranger, Explorer and Master Thief.
Helmet crests, cheek guards and the side-worn demon mask leave the common face
and hair recognizable. Ranger and Mage wear small hats over the original hair.

## Review and playable preview

- `roster-front.png`, `roster-three-quarter.png`, `roster-side.png` and
  `roster-back.png` show the editable models under identical studio lighting.
- `runtime/` contains actual Godot 4.6.3 front, profile, back, three-quarter,
  run and attack captures, plus Pirate's drinking pose.
- `gameplay/` contains twelve captures from the exported app in Fire Siege.
- `../../build/goemon-cosplay/Goemon Cosplay.app` is the separate local playable
  preview. The existing `build/Goemon.app` is preserved.
- `../../build/goemon-cosplay/Goemon Cosplay.zip` is the exported archive.

The primary game, class selector and portraits now select the cosplay assets.
Old model files are retained. The initial costume pass preserved combat; the
subsequent attack alignment pass below corrects basic melee reach and motion.

## Goemon running update

The playable preview also includes the user's 14 October side/rear running
reference update. Goemon leans forward, keeps a compact bent-elbow arm swing,
and raises the trailing heel with its sole turned backward. The existing
terrain foot contacts and combat overlays remain active. This changes Goemon's
forward run and sprint, with smooth entry and exit; the other classes retain
their own animation systems and playstyles.

`../goemon-run-reference/goemon-run.gif` and `goemon-run.mp4` show synchronized
side, rear and rear three-quarter views. Twelve new silhouette/rig checks,
the complete locomotion suite, and pipe-combo tests pass. The exported PCK
also passes the twelve new checks; its hash and results are recorded in
`../goemon-run-reference/verification.json`.

## Attack and full-body run alignment

The 14 October follow-up fits all basic melee attacks to the shared Goemon
body. Native melee costumes use the original articulated hip/chest/wrist
choreography, retimed to their existing combo contacts. Elbows and knees now
use the original joints instead of moving as single rigid pieces. Lance thrusts,
bow shots, fire casting, damage, combo clocks and class abilities remain distinct.

The invisible threefold melee multiplier is removed. Native melee reach is
measured from the posed weapon; Goemon uses the actual pipe geometry, and its
trail and building/enemy hits share that reach. Weapon range upgrades visibly
scale the weapon. Ranged projectiles keep their previous travel distances.
Edo releases fireballs after the final hand pose; his beam shell and damage
start from the same hand. Mage and Ranger launch from their posed hand/bow.

All twelve fighters now retain opposing hip/shoulder turns, bent elbows and
trailing heel recovery. Goemon already had torso turn in his authored clips;
his arm override now follows that turning chest. The other costume adapters
use all the relevant joints in the existing 22-bone skeleton. No new joints or
changes to Goemon’s source mesh were needed.

The follow-up rear-view reference clarified the connected weight shift: the
whole body banks with the stride, the rear arm opens behind the shoulder,
and the recovering knee and sole follow the turning hip frame. The old
straight-ahead leg solve and independent ready-weapon shoulder offsets no
longer undo that motion. Ground contact stays anchored, recovery clearance
is measured above the floor, and partial-speed/diagonal pose blends preserve
limb lengths through the connected hierarchy.

See `../unified-run/` for the latest three-angle Goemon and twelve-character
running previews and verification; `../attack-alignment/` records the
preceding attack correction.

The subsequent arm-height and pacing correction raises both ends of the arm
swing by roughly 25–30 cm. The forward forearm sweeps inward across the chest
while the trailing arm opens outward and behind the shoulder; they trade
places with the turning torso every half stride. All twelve rigs share a
speed-based cadence: 1.65 full
left/right cycles per second at normal run speed (10.2), and 2.05 at sprint
speed (18). Ground-contact duration changes with cadence and foot travel so
slower animation does not introduce foot sliding. Gameplay movement speeds
remain unchanged. `../run-pacing/` records that pacing pass, captured and
played at real time with fixed ground markings, plus verification results.

## Shared Goemon jump

The 14 October jump reference adds a shared airborne silhouette to all twelve
fighters: both arms open beside the shoulders, elbows bend slightly upward,
and both knees tuck the heels behind the body with the soles facing back.
The legs extend during descent and the arms blend back into movement on
landing. The controller still determines jump height, steering and gravity;
attacks, casting and special flips/dives retain their action poses.

The ground-to-air transition also preserves leg lengths when terrain probes
lose contact on the last grounded frame. The full locomotion suite now passes,
resolving the earlier edge-transition drift recorded in the unified-run report.
See `../jump-reference/` for the three-angle and all-twelve previews and the
latest verification record. The playable cosplay app and archive include this
jump update alongside the running, attack and settings changes above.

## Balance and recording settings

Open **Settings · Balance & recordings** from the Forest Shrine title or
Escape pause menu. **Character balance · Choose a fighter** edits independent
profiles for all twelve fighters: base maximum HP, damage multiplier, run and
sprint speeds, and both jump launch speeds. Goemon additionally has pipe,
coin and surge controls; Edo has beam width and length. Invincibility,
incoming enemy damage and healing the current fighter are shared playtest
controls. Existing class differences and saved prototype values are the
baseline until a character receives an override. Reset changes only the
selected character back to that saved baseline.

Profiles save automatically in a separate `character_balance` section of the
existing local settings file. Selecting an editor profile does not switch the
fighter in the game. Sound Studio restores the previous recording, preview,
save, per-slot volume and restore-default controls and uses the same recording
folder. Both menus preserve preparation/battle pause behavior.

The 32-check settings integration suite exercises menus, independent profiles,
legacy settings, reload/reset, precision, real movement/jumps/damage and actual
Goemon coin/Edo beam values. Forest title and transition regressions, 20 modern
combat checks, 76 class combat checks, music settings and Sound Studio pass.
`../character-settings/` contains rendered menu previews and verification data.

## Sources and animation

- Master: `assets/blender/characters/kai.blend`, kept read-only.
- Editable variants: `assets/blender/characters/goemon_cosplay/`.
- Runtime exports and portraits: `assets/models/characters/goemon_cosplay/`.
- Generator: `tools/build_goemon_cosplay.py`.
- Shared rig adapter: `scripts/goemon_cosplay_rig.gd`.
- Edo choreography adapter:
  `assets/characters/musashi/animations/goemon_cosplay_motion.gd`.

The Skin and Hair_Normal geometry and UVs are copied without sculpting or
resizing. The original face atlas remains intact. Class colors are separate
materials; added costumes follow Goemon's existing 22-bone skeleton. Rogue's
class pose controls drive those bones, including the 75-degree arm lowering
from the original T pose. Edo retains his casting and movement choreography.
Native weapons retain their authored geometry and axes, with grips fitted to
Goemon's palms. Pirate's flask remains attached to the body for its drinking
animation; Samurai's separate scarf tail retains its wind animation.

## Verification

`tools/verify_goemon_cosplay.py` reads the actual GLBs and compares body/hair
positions and UV seams against the exported Goemon baseline, accounting for
the classes' opposite facing direction and floating-point export tolerance.
All eleven variants pass. The builder also asserts exact Blender vertex and
UV preservation before export and checks the original master SHA-256.

The runtime suite checks all ten class skeletons, lowered arm poses, visible
skinned hand motion, finite head poses, body depth, weapons and the flask's
body-relative drinking attachment: 72 checks pass. Edo's 19 casting and VFX
checks and the 76 class combat checks pass. The existing pose suite passes
27 checks. The rendered studio tour produced 68 captures, followed by seven
updated Pirate views including drinking after the attachment correction.
The movement and roster suites pass 95 and 99 assertions respectively.

The exported PCK passes the same 72 rig checks when run with Godot 4.6.3.
The actual release app passes all 15 rendered Fire Siege gameplay checks at
normal frame timing, including Magic Swordsman's energy wave and Explorer's
cross-slash dash. An earlier accelerated run failed two Explorer preview
assertions; both pass at normal timing, and the full combat suite independently
checks Explorer's secondary. The app also passes macOS code-signature validation.

Two existing test expectations were stale before this redesign: Magic
Swordsman's wave already deals 100 damage, and Samurai's secondary already
fires a 28-metre Crimson Arrow. Their assertions now verify these existing
rules, including one-time damage and applying growth once; gameplay code was
not altered to satisfy the tests.

The headless movement suite logs an exit-time resource cleanup diagnostic
after its assertions. It is recorded in `build/goemon-cosplay/verification/`;
the standalone rig and rendered studio checks finish without script errors.

## Reproduction

Use Blender 5.2.2 and the project's Godot 4.6.3 runtime:

```sh
blender -b --python tools/build_goemon_cosplay.py
blender -b --python tools/render_goemon_cosplay.py
godot --headless --path . --editor --import
python3 tools/verify_goemon_cosplay.py
godot --headless --path . --script scripts/goemon_cosplay_tests.gd
godot --path . --script scripts/goemon_cosplay_tour.gd
godot --headless --path . -- --edo-redesign-test
godot --headless --path . -- --rogue-combat-upgrade-test
godot --headless --path . -- --fire-siege-motion-test
godot --headless --path . -- --rogue-roster-v235-test
```

The studio tour regenerates selector portraits. Import them before exporting
a release. Its optional `-- --hero=pirate` selects one hero for focused review.

The next coordination pass (`../run-coordination/`) gives all twelve rigs a
stronger shared waist, spine and shoulder turn. Hands open farther from the
hips while passing the body, keeping the inward forward-arm fold. Each airborne
foot follows a small inward arc that fades before contact; the slower cadence
and planted-foot timing remain unchanged. That directory contains the current
real-time run/sprint preview and paired key poses.
