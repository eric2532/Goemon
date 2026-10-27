# Keeping Goemon smooth

Saved 2026-10-23 at the user's request: general gameplay now feels really smooth.
The user wants future performance work explained so they can learn the process.
This is project knowledge, based on source and saved reports, not a new benchmark.

## Rainbow legendary team cards and heroes — 2026-10-27

The three slots roll independently: 84.75% normal, 10% silver, 4% gold,
1% diamond and 0.25% legendary. These odds supersede the four-rarity odds below.
Legendary Tower grants 5× total tower damage (including future towers; repeated
choices multiply again), Worker grants ten free workers, and Character chooses
evenly between five random mercenaries and one random hero. Heroes are Goemon,
Musashi, Kojiro, Blademaster and Illidan, with equal odds. They stay until defeated
or the run ends. Rewards work during battle without gold/food admission checks;
workers and regular mercenaries still count toward food usage. Heroes use native
summon slots. Blocked arrivals preserve the card and RNG; partial mercenary
grants roll back. Stale clicks cannot grant twice. Every reward is run-only.

This is requested gameplay/UI work, not a measured bottleneck fix. The smallest
implementation reuses the card shader for larger rainbow halos and sparkles,
workforce recruitment, mercenary pools, and the native mirror-body lifecycle.
The normal five-copy skill still expires after fifteen seconds. Legendary heroes
use independent indefinite leases, their own prepared models/stats and existing
skills. Character changes leave their identity intact. Only the rolled hero is
prepared while the choice is paused; retired bodies and projectiles are reused.
Navigation, targeting, health and action decisions stay in the native army.
No extra army simulation, model, animation bake or renderer was added.

Mixed-hero testing exposed Goemon coins reading the main player's model/stats.
The shared coin methods now accept the actual caster for aim, damage and pool
ownership. Ordinary player calls retain their defaults. Keep future summon
skills in these shared systems; do not load models in attack or hit loops.

Fresh verification: 439 progression/workforce/native checks, 123 headless card
gameplay checks, 50 desktop hero checks through Play Goemon, 338 mirror-image
regression checks and five charged-coin contact checks pass. The original three
legendary rewards also passed 137 desktop checks before the hero addition,
including paused rainbow animation, keyboard choices, smaller windows, repeated
rewards and real native mercenary hits. The final hero run covers all five heroes
together for sixteen simulated seconds, player switching, actual native hits,
prepared Goemon projectiles, defeat, body reuse and new-run callback cleanup.
Final protected-asset preservation passes; this iteration also passed 69 toolkit
unit, 12,812 import, 98 outfit, 25 motion and 86 structure checks.

The optional old `native_primary_range_tests.gd` suite reports 9/12 passes:
its two triple-pipe-reach checks and triple-coin-lifetime check still assume a
3× basic-range multiplier. Both HEAD and current `player.gd` specify 1×; this
feature does not change that setting. Treat that suite as outdated evidence,
not a passing regression check. No full-battle performance or long-session
balance/resource-growth claim follows from the focused runs above. Earlier
smoothness reports remain historical.

Verify through Play Goemon: choose a rainbow reward, check the exact count or
tower damage, then use the hero alongside another player character. Try defeat,
a repeated summon and a fresh run. Tune rarity in `team_progression.gd` with its
spec/tests; keep arrival checks and rollback. Evidence is under
`build/Other Files/Team Leveling/` (`legendary-*.log`, `04-*` through `08-*`).
No app was exported.

## Illidan's spinning meteor under purple flames — 2026-10-27

This is requested visual work, not a measured bottleneck fix. The original Meta
missile includes a 24-triangle rock and a 667 ms rotation loop that the former
glow/particle recovery omitted. The core is now about 3.4 m across. The user's
clarification requires **complete purple fire coverage, with no exposed stone**:
an animated fire material and a local flame shroud cover the recovered shape,
softening its polygon outline. The original stone texture is preserved in the
asset package; the live surface shows flames. Existing glow/trail/impact art
and all damage, collision, speed, timing and native-query behavior remain.

The smallest integration extends `warcraft_projectile.gd` and its recovery
script. One mesh, fire material and prepared animation are shared by the
existing pool. Each lease adds one mesh node and one 24-particle emitter, using
the existing flame texture/quad/material and trail envelopes. Geometry and
quaternion samples are prepared once; flight updates orientation and an instance
shader clock. No assets/materials are loaded or built during firing or hits.
Reset restores spin, flame age and particles; impact hides both core and shroud.
Keep these in the existing lease, not a separate projectile/army owner.

Fresh verification passes 509 focused splash/reuse assertions, 15 rendered
meteor assertions in Wind Meadow Valley, 14 rendered native-target/repeated
volley assertions, 46 first-person assertions and 5 fog assertions. Five volleys
of 24 return to the warm pool without resource growth or misses. First-person
repeat firing retained zero nodes/resources and zero pool misses. Toolkit
preservation and 69 unit tests pass, as do 12,812 imported checks, 98 outfit,
25 Musashi motion and 86 structure checks. The asset audit reads 302 assets
with zero errors. The additional native mesh is 26 vertices / 24 triangles,
one surface/material; no geometry optimization or character bake is needed.

The focused 24-shot rendering comparison measured frame p95/max of
17.385/19.166 ms with core/shroud hidden and 17.133/19.527 ms visible. Both cases
retain spin and particle processing, so this isolates visibility cost rather
than the entire implementation cost. Manual collision/spin work for all 24
visible shots was 0.754 ms p95. Native volley frame p95/max was 17.102/34.064 ms;
first-person repeat firing was 17.160/33.036 ms. These short runs do not establish
a speedup, full-battle smoothness or long-session stability. Historical user
smoothness reports and earlier stress results remain historical.

Verify with Play Goemon: choose Illidan, transform and fire while grounded or
flying. Expect a large purple flaming meteor, with no bare rock or hard polygon
outline, followed by the existing trail and burst. Try repeated fire, a target,
a wall and pause/resume. Keep the original spin/core in the missile sidecar;
adjust visual coverage during setup, without changing hit radii or reducing
enemy counts. Captures/logs: `build/Other Files/Asset Toolkit/Illidan Rock/`.
Source/recovery details: `assets/characters/warcraft/demon-hunter/missile/README.md`.
No app was exported.

## Rare team upgrade cards — 2026-10-27

Each of the three level-up cards now rolls independently: 85% normal, 10% silver,
4% gold and 1% diamond, following the user's preference for rarer special cards.
Silver/gold/diamond add two/three/four ordinary ranks through the existing shared
team multiplier. A +15% damage card becomes +30%/+45%/+60%; it does not multiply
the whole base damage by two/three/four. Worker revival uses the same wound timer
with 12/6/4/3-second durations and remains a single unlock. Offers retain their
rarities through refresh and clear together on selection or a fresh run.

This is requested UI and balance work, not a measured bottleneck fix. One shared
canvas shader gives the three cards metallic sweeps, colored edges and sparkles.
Each card owns its material, prepared with the popup; shader time animates during
pause without creating per-frame nodes, materials or particles. The existing
maroon panels, icons, keyboard controls, combat/native multipliers and rank
stacking are reused. No new army renderer, asset rebake or combat effect is added.

Fresh checks pass 403 progression/workforce/native assertions and 77 desktop
gameplay assertions through Play Goemon. Coverage includes all eight cards at
all four rarities, 10,000 reproducible offers, independent slot probabilities,
mixed-rarity stacking, real revival durations and native diamond damage/contact
timing. The rendered test verifies 1280×800 and 960×640 layouts, animated shine
while paused, keyboard choice, character switches, five summoned copies,
queued choices, normal-card shine reset and a fresh-map reset. Five repeated
choices retained zero nodes/resources. Protected-asset preservation, 69 toolkit
unit tests, 12,812 imported checks, 98 outfit, 25 motion and 86 structure checks
also pass.

The short paused-card sample measured frame p95/max of 17.226/34.070 ms; choosing
cards took 1.415–9.426 ms, including the existing native Character-kit refresh.
These are focused observations, not a controlled before/after comparison,
full-battle performance claim or long-session balance test. Older smoothness
reports remain historical. Verify through Play Goemon by earning levels and
checking the rarity label, exact bonus and rank jump; all three slots can be rare
together. Tuning odds belongs in `team_progression.gd::rarity_from_roll` and the
matching spec/tests. Evidence is under `build/Other Files/Team Leveling/`
(`rarity-*.log`, `desktop.json`, and the `02-*` captures). No app was exported.


## Illidan first-person Metamorphosis — 2026-10-27

The requested view is first person, with both full arms and distinct fingers.
It reuses Chief's eye camera, mouse look, separate-depth overlay, movement bob
and exact world/enemy trace. Reverse morph and fighter changes restore the
previous camera; pause/focus loss clear held fire. The user's crouched-view
feedback led to a 3.0 m meta eye height (Chief stays 1.68 m), with a ceiling check
before raising the camera. Meta outgoing damage is multiplied by ten, including
existing upgrade modifiers. An unmodified bolt now launches with 640 damage;
reversing the transformation removes the bonus.

`illidan_viewmodel.gd` prepares an owned index-only subset of the two complete
arm chains once on character selection, retaining authored vertices, UVs, weights,
materials and tracks. Source hand sockets frame the casting gesture. No assets,
meshes or materials are rebuilt per shot. The Warcraft controller retains release
timing, recovery, projectile speed, splash, native targeting and the existing
24-lease projectile pool. Chief's shared trace prevents eye-to-hand cover bypass.

The editable Illidan master now adds ten tapered digits inside the existing
alternate body: 190 vertices / 340 triangles, taking the source from 1,534 to
1,874 triangles. It adds no bones, meshes, materials or texture memory. All 17
geosets remain independently controlled; the audit's existing 17-surfaces versus
8 budget warning does not authorize merging form/effect controls. The user's
left-wrist feedback exposed a 38° resting / 47° casting bend. Its rotation is now
prepared offline in the two existing meta clips, reducing this to about 14° / 15°.
The final follow-up adds a `RelaxedHands` shape and eases the six arm tracks
from idle to the existing release pose and back. In the resting FPS view, the
left arm rotates 30° counterclockwise and the right 30° clockwise; these offsets
fade out before release. The overlay lowers the relaxed hands and changes an
existing mesh shape weight as the cast progresses. This adds no skeleton or
per-frame mesh construction. Original colors, release timing and other clips
remain. Do not add a runtime wrist solver or reimport over the saved edits.

This is requested perspective/art/balance work, not a measured bottleneck fix.
The desktop run before the final relaxed-pose revision passed 45 shooter assertions,
with zero retained nodes/resources and zero pool misses. Measured frame p95/max
was 18.038/34.263 ms and manual gameplay work p95 was 0.882 ms. These focused
results are not a full-army benchmark or a long-session soak. Asset preservation,
69 toolkit unit tests, 47,599 imported Warcraft checks and 1,057 native army
checks also passed; the native Blademaster pose error remained zero.
Earlier shoulder-camera evidence is superseded by first-person results.

Verify through Play Goemon: select Illidan, press 1 or RMB to transform, aim with
the mouse, hold LMB while strafing, and hold Space to fly. Watch both hands at rest, windup and release: loose fingers and the requested
resting angles should transition into the cast and settle back smoothly. Try close cover, pause/resume, reverse morph and Chief
switching. Evidence is under `build/Other Files/Asset Toolkit/Illidan Hands/`,
with FPS captures under `Illidan Shooter/`. The normal Wind Meadow capture uses
unchanged wave settings (40 live enemies observed). No app is exported for these
iterations. See `docs/recovered-warcraft.md` for editable source and preservation.

## Blademaster and Illidan moving attacks — 2026-10-27

Their shared controller explicitly overwrote grounded attack velocity with zero.
Removing normal attacks from that override lets the existing player movement run
during melee and transformed bolts. Metamorphosis still plants its transition.
The shared attack slowdown, committed aim, hit feedback pause, animation/contact
clock, damage, reach and projectile pool are unchanged. This is a movement bug
fix, not a measured performance bottleneck or speedup; it adds no runtime work.

Fresh headless and desktop-launcher runs each pass 145 checks: all four movement
directions, all three Blademaster cuts, both Illidan cuts and transformed bolts,
movement through windup/recovery, one contact per attack, unchanged facing and
the planted morph. The fixture uses the existing physics-step driver because
`move_and_slide()` reads Godot's actual physics delta. Both rendered attack views
were inspected. These focused results do not establish full-battle performance
or long-session stability and are separate from historical smoothness reports.

Additional fresh checks pass: 434 isolated desktop character assertions, 56
desktop skill assertions with five simultaneous native-backed copies and zero
retained nodes/resources, 58 headless melee checks, asset preservation, 69 toolkit
unit tests, 12,812 imported checks, 98 outfit, 25 Musashi motion and 86 structure
checks. Earlier broad headless runs reported one walking-audio and one summon
node-count failure; another desktop game interrupted the initial character run.
Those earlier logs are retained and are not counted as passing. The isolated
desktop reruns passed without changing those fixtures or gameplay to hide failures.

Verify via Play Goemon: hold a movement key while clicking through either melee
combo, then transform Illidan and fire while walking. Movement should continue
at the existing attack pace; brief hit feedback and the morph transition remain.
Keep movement in the shared player controller when adding future attacks instead
of introducing a second locomotion loop. Logs are `build/Other Files/warcraft-moving-*.log`;
captures/reports are under `build/Other Files/Asset Toolkit/Warcraft/Moving Attacks/`.
No app was exported.

## Dark Lumina 3 sequential elemental queues — 2026-10-27

Wind, Water and Fire now accept three total presses, including the first, and
play complete volleys one after another. Before the first release, another
accepted press restarts the existing gesture. After release begins it appends a
volley without truncating any shots. The cap prevents further resets; evade,
another attack, focus loss and character changes cancel pending volleys normally.
Borrowed skills use the same controller. Earth's five airborne repeats and one
damaging wave per press are unchanged. Water/Fire scatter radii widen by 20%,
from 81/54 to 97.2/64.8 metres, including the shared native enemy kit.

The smallest change is one bounded count and wrapping the existing source
timeline for each volley. Wind keeps its current aiming and four attached layers;
each volley resets its target history and owned sound before starting again.
Water retains one eight-way burst source per six-drop volley. Fire retains all
32 flames and normal ground-fire pulses. No per-shot damage, source animation,
native attack cadence, local query or projectile lifetime was changed.

The measured allocation issue was overlapping Fire, not a new renderer cost.
The first three-volley stress case reached 96 active flames against 80 prepared
leases. Consecutive queues at the existing maximum pickup speed, high in the air,
reached 256 active flames; a 96-lease trial needed another 160 leases during play.
Preparing 256 through the existing pool at character/skill setup covers that
observed workload. Meshes and materials remain shared and reuse resets the same
projectile state. This moves the measured allocation to setup; it is not a claim
that arbitrarily stacked future speed upgrades can never grow the pool.

Fresh checks pass: 171 headless queue assertions and 144 desktop assertions via
Play Goemon, covering one/two/three/over-cap presses, early/late input, borrowed
skills, cancellations, exact full-volley counts, spread and consecutive fast
airborne queues. Both final runs retain 740 prepared leases, with zero misses
and zero retained node/resource growth. The desktop run's manual-step p95 was
1.334 ms; frame p95/max were 17.100/109.811 ms. Other work was running on the
machine; these are focused observations, not a controlled speedup comparison or
an explanation of every spike. The earlier interrupted desktop run is retained
as failed evidence, separate from the passing rerun.

Regressions pass: Earth 97, controls 70, Wind steering/audio 66, modular skills
3,398, numbered hotbar 577, toolkit Python 69, imported assets 12,812, Musashi
outfit 98, motion 13 and structures 86. Protected-asset preservation and the
original Lumina body/copy pose comparison pass. Fresh native C++ checks cover
all six move families at 20/30/60 Hz and three six-boss/96-ally Wind stress runs.

The separate desktop native encounter also passes 83 assertions with six bosses
and 120 troops over 3,600 simulation steps. All six move families occur, the
presentation stays at 115 nodes, and captured audio peaks at 0.684. Native-step
p95/max were 2.052/47.967 ms; wall-frame p95/max were 17.569/531.395 ms. This run
used the same imported painterly source directly because another test held the
desktop launcher lock. Concurrent tests and captures prevent treating its frame
times as an isolated benchmark; the maximum spike is not claimed resolved.

Verify through Play Goemon: tap 1, 2 or 3 once for one volley, then repeat three
times for three volleys. Press again during firing and confirm the current
volley completes; a fourth press adds nothing. Check Water/Fire over a wider
patch of ground, then evade and confirm pending casts stop. Keep future fixes on
the shared timeline and existing pool, and measure overlap before increasing
capacity. Evidence and captures are under
`build/Other Files/Asset Toolkit/Dark Lumina 3/Queued Elements/`. No app was
exported and no long-session/full-army soak is claimed.

## Stronger reinforcements and scaled XP — 2026-10-27

The user requested that later groups become stronger and award more EXP as their
numbers grow. Each entrance now advances independently: group 1 uses base stats
and 1 XP; group 2 has ×1.2 health, ×1.1 damage and 1.2 XP; group 3 has ×1.4 health,
×1.2 damage and 1.4 XP. Growth is linear. Existing count settings, release gates,
active population cap, routes, attack timing, art and movement remain intact.

This is balance work, not a measured bottleneck fix or speedup. The smallest
change stores the group reward on the existing enemy row and two scalar
multipliers on its existing native unit. Shared melee/area/beam code applies
damage once, and existing projectiles snapshot it at release. Vambee carries its
health multiplier into its crawling form. Recycled units reset both multipliers.
New groups do not rebuild shared kits, rescan the army or create extra resources.
XP uses integer tenths alongside the existing level accumulator, preserving
fractions through level-ups. The HUD includes fractions in its text and meter.

Fresh checks: 71 reinforcement-combat assertions cover all ten enemy types
against native allies and the external hero, unchanged contact counts, damage
after shooter retirement, form changes, validation and stale/reused handles.
137 progression checks pass. The desktop launcher passes 86 group assertions,
including real second/third-group native HP, independent entrances, capped and
blocked spawn retries, exact death rewards and the rendered 2.6/20 XP meter.
The existing desktop team-leveling fixture passes 51 assertions, including all
kill owners, player death, summons, queued choices, repeated UI cleanup and reset.

Shared regressions pass: wave roster 34, native runtime 4,109, worker 247 and
soldier combat 58; native C++ core, Skullpion, Dark Lumina 2 and Dark Lumina 3
assertions pass. Protected-asset preservation, 69 toolkit Python tests, 12,812
import checks, 98 outfit checks, 25 recovered-Musashi motion checks and 86
structure checks pass. Some headless fixtures still report resource/RID teardown
diagnostics; both desktop fixtures exit cleanly. These are focused correctness
checks, separate from the user's historical smoothness report. No controlled
frame-time comparison, full-army soak or long-run balance claim is made.

Verify via Play Goemon: let one entrance's first group engage, then fight its
next group. Each second-group defeat should add 1.2 EXP, including tower/ally
kills; third-group defeats add 1.4. Older survivors retain their original spawn
reward. Watch the gold bar across a level-up, then restart to return to opening
strength and zero EXP. Keep new scaling on spawn-owned data rather than changing
all living enemies whenever one entrance advances. The percentages need normal
play feedback, especially in long battles. Details are in `team-leveling-spec.md`.
Evidence is under `build/Other Files/reinforcement-*.log`,
`build/Other Files/Reinforcement Scaling/`, and the Wave Groups/Team Leveling
capture folders. No app was exported.

## Blademaster original red and restored hero glow — 2026-10-27

This is a requested appearance change, not a measured performance fix. The
charcoal export used TeamColor12 and TeamGlow12 together. The same exporter now
selects the original Warcraft slot 00 textures: red clothing/banner and red hero
glow. Native TeamGlow00 peaks at 127/255 red; the charcoal export peaked at
20/255 in all three channels. Restoring the source texture restores the glow's
brightness without adding another aura or changing any frame/attack loop.

Reuse the existing two team-glow geosets, camera-facing bones, attack glows and
prepared spell emitters. Player and summoned bodies share the prepared resources;
the optimized model, native pose atlas and both portraits are rebuilt offline.
Both editable Blender masters, all 14 actions, all 1,732 source accessors and
opacity tracks are unchanged. The asset remains 543 triangles / nine independent
surfaces; the surface-budget warning does not authorize removing effects.

Verify through Play Goemon: choose Blademaster, inspect his red banner/clothing
and ground/body glow from the front and back, use Bladestorm and Wind Walk, then
summon five copies. Repeat casts and switch fighters to check reset and instance
isolation. Existing combat owns damage, timings and movement. Evidence is under
`build/Other Files/Asset Toolkit/Blademaster Red/`; original texture paths and
rebuild steps are in `docs/recovered-warcraft.md`. No app was exported.

Fresh checks pass 434 desktop character, 56 desktop skill and 97 desktop energy
assertions, including five simultaneous native-backed copies. Repeated attacks
and settled summons retain zero resources; summons also retain zero nodes and
projectile-pool misses remain zero. Character/skill frame-interval p95 was
17.044/17.245 ms; the character maximum was 52.212 ms. These focused results are
not a full-army benchmark, a long-session soak or a measured speedup.

Preservation, 69 toolkit Python tests, 47,599 Warcraft imported assertions,
1,057 native atlas assertions, 12,812 common import assertions, 98 outfit,
13 player-motion and 86 structure checks pass. Seventy-two source/candidate
rendered pairs were captured and representative poses inspected. Existing
headless atlas scene-shutdown resource/RID diagnostics remain separate from
the zero-growth live checks. The initial glow assertion incorrectly required
an intensity above the original texture's 127/255 maximum; the corrected test
checks the original red hue/brightness and rejects the former charcoal texture.

## Taller home walls, stronger doors and mercenary audit — 2026-10-27

Home-castle walls now stand 32 m instead of 16 m in both meadow sizes and
user-authored layouts. The existing stone/painterly art and fracture overlay are
scaled during building setup; physical boxes and gameplay height queries use the
same height. Foundations retain their terrain depth. Enemy castle panels and
collapse art retain their 16 m contract. Gate openings, tower decks, footprints,
map files and wave counts are unchanged. No new geometry, renderer or per-frame
work was added, and this is not a measured performance improvement.

Friendly doors now have 2,500 HP instead of 2,000. A worker's existing quarter-
second pulse restores 12.5 HP for one ryo instead of 10: 50 HP/s at the same
four-ryo-per-second cost. Two workers still share funds safely, stop at full
health, and wait for an occupied breach to clear before closing the door. Team
repair upgrades multiply the existing cadence. Instant preparation repair keeps
its existing price of one ryo per 10 HP; only worker repair efficiency increased.

Fresh checks pass 49 desktop height/map/clearance assertions through Play Goemon,
44 automatic repair checks, 23 gate damage/rebuild checks and 131 team progression
checks. Both standard and large valley captures were inspected. Preservation,
69 toolkit unit tests, 12,812 imported checks, 98 outfit, 13 motion, 86 structure,
90 enemy-castle damage and 54 enemy-castle pathing checks pass. Old wall-durability fixtures still contain superseded destructible-wall
and childless-door assumptions; their failures are not counted as passing.

The requested mercenary check is an audit, not a skill update. Mercenaries use
native kit data and AI, not the player's configurable spell loadout. Dragoon's
hunting dragon is wired through native combat and pooled presentation; Knight's
fourth primary swing and shield counter are present. Knight has no native Royal
Lion Rush. Ranger still uses the older five-arrow fan, not the player's newer
held ten-arrow Rapid Shot. Ninja retains Shadow Cut, stars and Anbu; Explorer is
still the dedicated blade-combo kit. Changing a player skill does not automatically
change its native mercenary equivalent.

Fresh hiring, Knight, Dragoon and Dragoon-effect tests pass. The desktop hunting
dragon suite passes 47 checks, including eight simultaneous dragons over three
cycles, with 115 presentation nodes and 1,148 resources before and after. Its
frame p95/max was 17.079/60.402 ms; this focused diagnostic is not a controlled
before/after performance comparison or a full-battle benchmark. The audit also finds
one Ninja multi-victim contact failure, the previously documented Ranger close-
standoff failure, and Explorer source-fingerprint/timing mismatches. No native
combat, pose bake, or skill behavior was changed to conceal those findings.
Check and rebuild affected profiles/poses from their authoritative source before
claiming complete player/mercenary parity; do not merely update hash metadata.
Fixture shutdown resource warnings remain separate from successful assertions.

Verify with Play Goemon: inspect the central walls, inspect a door's 2,500 HP,
then let one worker repair it for one second (50 HP before team upgrades). Check
normal gate passage and a fully rebuilt breach. Evidence, exact test results and
captures are under `build/Other Files/Castle Defense Update/`. No app export or
full-army/long-session performance certification was performed.

## Illidan and Blademaster regular cuts — 2026-10-27

The user requested slightly better regular-attack reach and cutting glow like
Kojiro/Musashi. Both Warcraft fighters now use 3.6 rather than 3.0 base melee
reach, retaining their existing modifiers, contact timing, damage, facing and
cover checks. Their native profile/mirror approach uses the same constant.
Spin, Immolation and transformed bolts keep their existing ranges and behavior.

There was no measured gameplay bottleneck to fix. The smallest implementation
reuses Kojiro's existing leader ribbon on the original weapon bones: one red
sword and two purple glaives. Nodes/materials are prepared with the model; only
the bounded ribbon mesh is rebuilt while the cut/fade is visible. No new pool,
asset load in combat, retargeting, controller or army simulation was added.
Existing cancellation clears samples on dodge, hurt, selection, death and mirror
retirement. The original GLBs, animations and editable masters remain unchanged.

Fresh checks pass 58 assertions both headlessly and through Play Goemon. They
cover every combo's extended boundary, one hit per cut, windup, rear/cover
rejection, imported blade endpoints, visible cuts, fading, alternate form and
six simultaneous fighters. Repeated cuts retain zero nodes/resources after
cancellation. In the desktop ribbon-disabled/enabled comparison, six Blademasters'
manually stepped p95 was .497/.698 ms; six Illidans' was .913/1.719 ms. Enabled
frame p95 was 16.982/17.307 ms respectively. The initial maximum intervals of
165.533/158.961 ms include deliberate screenshot readback; the fixture now
excludes that capture interval from frame samples. These short fixture results
are not full-battle, long-session or speedup claims, and remain separate from
the user's historical smoothness report.

Preservation, 69 toolkit Python tests, 12,812 imported-asset checks, 98 outfit,
25 Musashi motion, 86 structure, 434 Warcraft character, 620 Kojiro and 56 desktop
Warcraft skill assertions pass. The latter includes real native mirror combat
and settled summon/cancel cleanup. The current native atlas passes 1,057 checks with zero pose error; ribbons
do not alter its prepared skin geometry. Existing native fixture shutdown
resource diagnostics remain separate from the zero live repeated-cut growth.

Verify in Play Goemon: select each fighter, click through the regular combo and
try an enemy just beyond the old reach. Watch for a brief red/purple blade sweep,
then dodge, change fighters and summon five mirrors. Keep the existing local hit
query and prepared weapon attachments when tuning this further. Evidence is in
`build/Other Files/Asset Toolkit/Warcraft/Melee/` and
`build/Other Files/warcraft-melee-{headless,desktop}.log`. No app was exported.

## Team leveling and gold XP meter — 2026-10-27

This feature adds shared run progression, not a measured bottleneck fix or a
speedup. One model-owned state holds XP and chosen ranks. Player attacks and
pooled mirror bodies read existing damage/attack-speed multipliers; native
allies receive the same bonuses through their existing kit profiles. Profiles
refresh once when a Character card is chosen. Towers, repairers and revival
reuse the existing workforce tick. Repair selection still runs every half second
and enemy danger checks keep using local native queries. No per-unit controller,
asset rebake, new effect pool, or per-frame resource loading was added.

The maroon/silver choice UI exists only while selecting an upgrade. Simulation
pauses for all queued choices. Its three cards reuse prepared art and the HUD
portrait material; freed cards retain no extra nodes/resources in repeated checks.
The separate gold XP bar below castle health fills from shared enemy defeats.
Run state clears on restart/new game while character changes and waves retain it.

Fresh checks pass 131 progression/workforce/native-contact assertions and 51
rendered gameplay assertions through Play Goemon. These include all kill owners,
XP during player death, queued choices, keyboard selection, two window sizes,
five real summoned copies, repeat choices and a fresh-map reset. A separate
24-worker desktop fixture passes 46 assertions across five repeated workload
cycles, retaining zero nodes/resources. Its world-sync CPU p95/max was
1.000/1.423 ms and frame interval p95/max 18.146/33.812 ms. This focused worker
fixture is not a full-army benchmark, long-session soak or controlled speedup.

Native runtime (4,109), tower index (1,005), repairs (44), shared skills (3,398),
numbered controls (577), character balance (176), reward audio (42), toolkit
Python (69), imported assets (12,812), outfit (98), motion (13), structures (86)
and protected-asset preservation pass. The older worker fixture counted render
frames for a two-second spawn delay; it now waits simulation frames. The balance
fixture now checks the actual 32-fighter roster instead of a stale hardcoded 30.
Existing worker-fixture shutdown RID/resource diagnostics remain separate from
its zero live workload growth.

Verify in Play Goemon: defeat 20 enemies with any friendly combination, choose
one Tower/Worker/Character card, change fighters and repeat. Try revival after
workers are wounded, then restart: the gold bar and ranks must return to their
starting state. Preserve the single shared progression owner and existing combat
paths when adding cards. Initial percentages/XP need normal-play balancing;
no app export was made. See [the spec](team-leveling-spec.md) and fresh evidence
under `build/Other Files/Team Leveling/`.

## Sound Studio defaults and recordings — 2026-10-27

The user wants the current sounds to remain built-in defaults, with working
personal recordings and a reliable return to default. Goemon, Sasuke and Yae
previously saved takes but bypassed them during playback. Previews and direct
voices also repeated that policy separately. Previously ignored files remain
preserved and inactive until explicitly saved again, preventing an unexpected
return to old sounds. All now use the existing shared playback resolver: a saved
take overrides the installed sound, while Restore selects the built-in default, clears that sound's gain/mute and blocks old shared
recording inheritance. This selection survives restart; saving another take
clears the default marker. Source-silent defaults remain silent until deliberately
recorded. Original samples, their pitch/variant weights and gameplay timing remain
unchanged. No app export is needed for these source changes.

The Studio groups each active move once, labels built-in/recorded/silent states
accurately, and uses Restore default for both weapon and voice. Retired generic
enemy reactions, old orb pickups, unused Kojiro cues, aggregate transformation,
obsolete bomb termination and redundant Ed/Ben combo rows are hidden. Their
compatibility keys and saved files remain readable; cleanup does not delete user
recordings. Restore removes only the selected sound's local take, as before.
Game SFX are muted during capture and the prior bus mute/music state is restored
when recording ends. Microphone monitoring stays off.

The three DL3 sustained slots prepare owned looping versions of custom PCM when
loaded or saved. Combat reuses them; one-shot previews and source samples remain
unchanged. Reset releases the custom loop. This closes a recorded-Wind gap without
per-cast resource creation, another audio pool or simulation. It is a correctness
change, not a measured performance bottleneck fix or speedup claim.

Verify through Play Goemon → Settings → Sound Studio. Choose a sound, Record,
Stop, Listen to take and Save take. Try it in gameplay, then Restore default and
relaunch to confirm the installed sound returns. For Wind, select Dark Lumina 3,
search Wind and use the sustained slot; hold the attack longer than the recorded
clip, turn/rise, evade and repeat. The recording should loop with the attack and
stop with its owner. Other characters and sounds should retain their own settings.

Fresh desktop checks pass 187 recording/default assertions and 75 Wind
assertions; headless recording/default checks pass 182 and Wind 66. The real
capture bus is fed synthetic PCM, then the result is saved, dispatched through
gameplay, restored and reloaded. Wind's saved clip loops beyond its one-shot
length, retains one voice, and cancellation releases it. Repeated casts retain
zero extra nodes/resources and no misses in the same 564-projectile pool. Player
and three-owner mixer captures have zero clipped samples. These are focused
correctness checks; the Wind fixture includes a 1,012 ms interval and is not
claimed as smooth gameplay or a performance improvement.

Shared checks pass 18 Studio UI, 40 character audio, 46 paired-move audio,
166 Goemon audio, 11 Sasuke sound-gameplay, 13 Yae sound-gameplay, nine shared
sound-gameplay, six resource-preparation and 577 numbered controls. The UI is
rendered and inspected with the real default/recording controls. Asset
preservation, 69 toolkit Python tests, 12,812 imported-asset checks, 98 outfit,
13 Musashi motion and 86 structure checks also pass. Intermittent fixture
shutdown resource diagnostics remain; the repeated live checks retain no nodes
or resources. No long-session or full-battle audio certification was performed.

Fresh evidence and synthetic capture tests are under
`build/Other Files/Asset Toolkit/Sound Studio Defaults/`. These tests never sample
private microphone audio. An older Musashi audio fixture has three clip/contact
expectation failures that also reproduce against the pre-change source; those
are excluded from passing counts. Full-battle/long-session behavior and physical
microphone input are separate from these focused checks.

## Wind audio restored and shared playback audit — 2026-10-27

The user reports that DL3 Wind is still missing and requests restored sound.
The immediate cause was an explicit Sound Library silence rule for both Wind
slots; the old regression passed by expecting silence. Remove those two entries,
keep the user's quiet Lumina footsteps, and reuse the corrected prepared sustain
and opening sample. Saved recordings, gains and explicit user mutes still apply.
No sample recovery, character animation, damage, release timing or counts changed.

The shared eight-voice spatial pool also multiplied game volume before the Master
bus applied it again. It now uses the same single Master-volume application as
other SFX. Priority playback first uses an idle or ordinary voice, then can reclaim
an enemy-owned loop under saturation. Ordinary sounds cannot take held voices.
Empty streams consume no voice or throttle. Existing cancellation resets ownership
on reuse; no pool or audio node was added. Three simultaneous native Wind owners
then exposed clipped mixer samples. The SFX bus now uses Godot's built-in hard
limiter at -3.3 dB before its existing +3 dB bus gain, retaining 0.3 dB of output
headroom at full Master volume. Quiet samples keep their existing level; mixed
peaks are contained. These are routing/audibility corrections,
not a measured frame-time bottleneck fix or a performance improvement claim.

The paired-move audit also reproduced a delayed Samurai cut losing its voice when
a buff replaced the foreground attack ticket. Delayed shared melee/projectile
releases now pass their original controller ticket to the existing audio router.
The old Ranger preview assertion was corrected to its already-installed recovered
power-arrow sample. Combat logic and assets retain their original owners.

Verify with Play Goemon: select Dark Lumina 3, press **1**, turn and rise while
blowing, then evade and repeat. The opening and held sound should play and follow
the gust release point ahead of the caster; completion/evade should stop it.
Try borrowed Wind and native bosses together, then check Sound Studio's Wind
preview/gain/mute. Keep Master/SFX buses and the bounded voice pool when extending
sounds; check real mixed PCM as well as whether a player reports `playing`.

Fresh checks pass 73 Wind assertions through the desktop launcher and 65
headlessly. The player-only and three-native-owner SFX captures have zero clipped
samples (peak .143 and .684); the pre-limiter three-owner capture clipped 74
samples. Repeated casts retain zero nodes/resources and no misses in the same
564-projectile pool. Desktop frame p95/max is 17.873/57.488 ms and isolated step
p95 is 2.128 ms; these include short-fixture work, not normal-world certification.
Shared checks pass 46 paired-move, 40 character-audio, six preparation, 28 bow,
128 DL3 gameplay, 127 DL3 completeness and 577 numbered-control assertions.
Preservation, 69 toolkit Python tests, 12,812 imported-asset checks, 98 outfit,
13 Musashi motion and 86 structure assertions pass. An older standalone Samurai
fixture fails in its unchanged legacy target helper before gameplay validation;
it is excluded from passing counts and recorded in the evidence report.

Evidence and fresh verification are recorded in
`build/Other Files/Asset Toolkit/Dark Lumina 3/Wind Audio Fix/`.
Earlier silent-preference measurements below are historical and superseded.
No app was exported; no full-battle or long-session performance claim is made.

## Lumina 3 walking audio preference — 2026-10-27

The user also disliked Lumina 3's walking sound. Player 30 now silences `step`
through the existing shared Sound Library rule. This adds no frame work,
resources or audio players; movement and other fighters' footsteps retain their
existing behavior. This is an audio preference, not a performance fix.
Verify through Play Goemon by walking and running as Lumina 3, then switching to
Goemon: Lumina's steps should be silent and Goemon's should remain audible.

Fresh focused checks pass 48 headless and 52 desktop assertions, including
repeated Lumina footstep requests starting no voice and Goemon retaining his
footsteps. Repeated Wind checks retain zero extra nodes/resources and no pool
misses. Asset preservation passes. No new performance claim or app export.
Logs: `build/Other Files/Asset Toolkit/dark-lumina-footsteps-*`.

## Wind attack silenced by preference — 2026-10-27

Historical behavior, superseded by the Wind audio restoration below.

The user clarified that the disliked sound was the Wind attack, not ordinary
floating movement. Its opening gust and sustained blowing now use the existing
shared silent-slot rule. This applies to the player, native bosses and borrowed
Wind without adding an audio player, resource load or simulation. Footsteps,
other spell sounds, steering, release counts, damage and movement are unchanged.
Recovered WAVs and saved recordings remain intact. This is an audio preference,
not a measured performance fix; the earlier lag investigation remains open.

Verify through Play Goemon: select Dark Lumina 3, press **1**, turn and rise
while blowing, then cancel and repeat. The wings and gusts should still work
without the opening/blowing sound. Other attacks should remain audible.

Fresh checks pass 50 desktop and 46 headless Wind assertions, plus 128 DL3
gameplay assertions. They cover steering, all 22 four-gust pulses and damage,
three native audio owners, borrowed Wind, saved-recording preservation and
repeated cancellation with zero retained nodes/resources or pool misses.
The desktop fixture recorded frame p95/max 17.617/321.011 ms, including capture
work; this is not a performance improvement or full-battle result. Logs use
`build/Other Files/Asset Toolkit/dark-lumina-wind-silent-*`. No app export.

## Wind audibility and reported general lag — 2026-10-27

The measurements below are historical. The later silence rule was removed by
the Wind audio restoration described above.

The user reported silence and lag throughout normal play through Play Goemon.
The earlier isolated cast checks did not reproduce their full play conditions.
With a copy of their actual settings (volume .58, camera distance 21, quality 0,
existing balance/waves), the held Wind voice stayed at its first release point
while Lumina rose more than 100 metres. Renewing a loop extended its lifetime
but never moved its source. Wind now updates that same voice's position on each
release and uses cue gain 1.0 rather than the generic .6. Samples, pitch,
cancellation, custom recordings and the eight-voice pool remain unchanged.
Other held sounds retain their positions and gains.
The user subsequently confirmed, "wind is there now." This establishes audible
playback in their own session; it does not confirm that general lag is fixed.

Fresh headless Wind checks pass 38 assertions, including a 120-metre ascent
without restarting/adding a voice, cue gain and the earlier control/ownership
checks. Normal repeated casts retain zero extra nodes/resources and 564 prepared
projectiles with no misses. The six-boss/120-troop desktop fixture passes 83
checks over 3,600 steps, fixed 115 presentation nodes and audio peak .903.
Asset preservation passes. No models, animation data or app export changed.

General lag is not yet established as fixed. Initial diagnostics included
expensive recording saves between measured phases; a native stack sample showed
diagnostic image/audio work, so those intervals are excluded from the clean
run. With unchanged graphics, balance and populations, the fresh foreground
normal-world run averaged about 60 FPS: idle p95/max 18.792/32.863 ms, standing
Wind 18.638/34.197 ms, rising Wind 21.666/28.529 ms. Metal GPU timings were
unavailable. This is a short reproduction, not a controlled performance gain,
dense-battle certification or a dismissal of the user's report. No speculative
simulation or quality change was made. The live watch records five-second
foreground gameplay frame summaries and work associated with spikes so the
user's actual lag can be investigated.
That live session subsequently captured real 74–139 ms stalls with 32–68 active
enemies, including time in world ticks, native waits and a navigation refresh.
These are separate from diagnostic file-save intervals. Asked specifically about
normal movement in the session where Wind was audible, the user then answered,
"It felt smooth." This confirms their experience in that session; it does not
erase the captured outliers or establish a controlled performance improvement.
No speculative simulation, collision-cache or graphics change was made. Resume
profiling if noticeable lag returns or a longer battle reproduces it.

A follow-up map check found 1,136 box colliders and one concave terrain collider,
with no convex rampart hulls; a proposed convex-hull cache change therefore would
not benefit this map and was not implemented. Twelve exact-geometry refreshes
through the desktop launcher measured a 63.985 ms cold export and warm mean/max
8.703/11.166 ms. These isolated timings are diagnostic evidence, not whole-frame
performance or proof that collision export caused every earlier stall.

Evidence and the development-only probes are under `build/Other Files/Asset
Toolkit/Dark Lumina 3/Live Wind Diagnosis/`. Mixed battle recordings contain
other combat sounds and cannot establish Wind's isolated loudness numerically.
Verify by pressing **1**, rising/turning while blowing and cancelling; the
sustained sound should remain with the attack instead of fading into the distance.

## Dark Lumina 3 Wind audio audit — 2026-10-26

The user still heard something missing after steering was fixed. A fresh ROM
trace found an extraction error: Wind event ABE is type 5, a scripted sequence
read through owner offset `0x18` and 12-byte descriptors. The current recovery
tool reads ordinary 20-byte event records at owner offset `0x14` for both types.
That selects bank 100/sample 2 instead of the sequence's bank 94/sample 9.
The earlier steering test correctly established audible playback and cleanup,
but its hash check only matched the mistaken recovery manifest. Its statement
that the original blowing sound was routed correctly is superseded here.

Correctly selected dry Wind, disabled AB9 startup and Kojiro Wind candidates
are prepared under `build/Other Files/Asset Toolkit/Dark Lumina 3/Wind Sound
Candidates/`, with executable/owner hashes and source-routing assertions in
`source-audit.json` and `prepare_previews.py`. At the audit stage these were
listening previews only; the subsequent selection below changes runtime audio.
Original source assets and user recordings remain unchanged. Three-second
Wind auditions extend the source samples and normalize peak headroom; they do
not emulate PSX ADSR/reverb, the original note's key-off or actor retriggering.
See `docs/dark-lumina-3.md` for exact addresses and the remaining recovery scope.
This is an audio-fidelity finding, not a performance measurement. Future fixes
must preserve prepared playback and validate source dispatch type before
claiming that a named recovered WAV is the correct original effect.

## Dark Lumina 3 selected Wind mix — 2026-10-26

The user selected sound candidates 1 and 2. The unchanged AB9 sample opens the
cast; a fresh recovery of ABE's actual bank 94/sample 9 sustains the blowing.
The dedicated recovery asserts the sequence descriptor and sample markers,
preserving its pitch and loop samples 56–20,888. Its duration follows the Goemon
cast, with audition headroom; PSX envelopes/reverb and exact retail retriggering
are not emulated. AB9 remains disabled in the retail ROM and is intentionally
enabled here by the user's choice. Other type-5 sounds still need a source audit.

This is an audio correction, not a measured performance bottleneck or speedup.
The smallest runtime change adds the opening cue to the prepared kit, maps the
existing Wind loop slot to the corrected WAV and plays the opening through the
existing spatial voice pool. Owner cancellation stops both sounds. Saved mute,
gain and custom recording choices still apply. There is no per-cast file load,
new audio player or projectile pool.

Fresh verification passes 41 rendered and 36 headless Wind checks, including
turning, exact pulses/damage, interruption, borrowed casts and Sound Studio
overrides. Repeated casts retain zero extra resources/nodes, with 564 prepared
projectiles and zero pool misses. The 4.53-second live SFX capture has peak
0.193 and no clipped samples. The six-boss/120-troop desktop encounter passes
83 checks over 3,600 native steps, all six move families and 115 fixed
presentation nodes; its combined audio peak is 0.939. Frame p95/max is
17.067/61.519 ms for the focused cast and 17.042/203.243 ms for the encounter.
These short diagnostics include capture/fixture overhead and do not establish
hitch-free play or long-session leak freedom. Historical smoothness reports
and previous profiles are separate evidence.

Asset audit reads 301 assets with no errors; preservation, 69 toolkit tests,
12,812 imported asset checks, 98 outfit checks, 13 motion checks, 86 structure
checks and 128 DL3 gameplay checks pass. Evidence and the combined sound preview
are in `build/Other Files/Asset Toolkit/Dark Lumina 3/Wind Audio Mix/`.
Verify through Play Goemon: select Lumina 3, press **1**, listen for the opening
gust followed by sustained wind, turn while blowing, then evade. Both sounds
must stop with cancellation. No app export or model/animation rebuild was needed.

## Dark Lumina 3 airborne slam repeats — 2026-10-26

The user clarified that repeated Earth presses should restore the previous
airborne movement, capped at five total presses per slam. Each accepted repeat
now restarts the existing gesture/marker clock, restores upward velocity to 13
and plays the prepared cast cue. The initial press counts as one; after press
five, further input cannot reset the clock or add upward movement. The same
damage ticket and wave count survive each repeat. Physical landing still locks
the queue and releases one damaging wave per accepted press. Borrowed Earth
uses the same implementation. Recovery, cancellation and per-wave damage retain
the preceding queue implementation's rules.

The change is a small branch in the existing controller, with no new resources,
animation data, per-frame searches or native army behavior. Enforce the press
cap before resetting motion; clamping only the wave count would still allow
unlimited airborne restarts. This is a behavior correction, not a measured
performance bottleneck fix or speedup.

Fresh headless and desktop checks each pass 97 assertions, including actual
upward travel after accepted repeats, ignored sixth/later presses, borrowed
casts, exact native-target damage, landing, interruption, long frames and reuse.
The same new regression failed 20 assertions before the correction. The desktop
run retained zero nodes/resources, 564 prepared projectile leases with zero pool
misses and 115 presentation nodes. Frame interval p95/max was 18.006/207.006 ms;
manually stepped work p95 was 1.256 ms. These short diagnostics include fixture
and capture work and do not establish hitch-free or long-session play. Earlier
native stress results and the user's historical smoothness report are separate.

Controls (70), toolkit unit tests (68), imported assets (12,812), Musashi outfits
(98), player motion (13), structures (86) and asset preservation also pass on
this source. No asset export, animation bake or new native stress run was needed.

Verify through Play Goemon: tap **4** repeatedly before landing and watch him
lift/restart the airborne gesture on each accepted press, up to five total.
Further presses must not keep him airborne. He should then land and release
the matching number of damaging waves. Logs and inspected airborne/landing
captures are under `build/Other Files/Asset Toolkit/Dark Lumina 3/Ground Slam/
Airborne Repeats/`. No app export was made.

## Dark Lumina 3 Wind steering — 2026-10-26

The user reported being unable to turn while blowing. The attached wings already
followed `hero.facing`, but the cast captured that direction only at startup and
normal attack movement kept it locked. Earlier alignment fixtures assigned
facing directly, so they did not prove that the player could steer the cast.

The smallest fix refreshes combat aim and caster yaw in the existing Wind tick,
before its release markers. Attached wings, local push queries and new gusts
then use that same direction. Borrowed Wind shares the controller; existing
native boss targeting and other spell locks stay unchanged. Released gusts keep
their current trajectories. This is a control correction, not a measured CPU
bottleneck or speedup. It adds no asset loading, pool, renderer or army scan.

Historical playback checks found a non-silent held stream that stopped on
completion/interruption. They did not establish correct ROM sound selection:
the subsequent audio audit found the extracted `wind_loop.wav` used the wrong
table. The user later selected a corrected sustain and the disabled AB9 startup
as an intentional addition; see the current Wind audio selection above.

Fresh focused checks pass 36 on the desktop launcher and 31 headlessly, covering
four aim directions, body/wings/gusts, borrowed Wind, 22 four-shot pulses, damage,
other spell locks and repeated interruption. Both repeated workloads
retain zero additional nodes/resources; the prepared pool stays at 564 with
zero misses in both runs. Desktop frame interval p95/max was 17.137/38.285 ms.
The six-boss/120-troop desktop fixture passes 81 checks across 3,600 native steps,
all six move families and 115 fixed presentation nodes. Its frame p95/max was
17.278/194.330 ms; these isolated runs do not establish hitch-free full-world
play, a speedup or long-session leak freedom. The user's historical smoothness
report and earlier stress measurements remain separate evidence.

Asset preservation, 68 toolkit unit tests, 12,812 imported asset checks,
98 Musashi outfit checks, 13 motion checks, 86 structure checks, 126 DL3 gameplay
checks and 70 control checks pass. Evidence is under
`build/Other Files/Asset Toolkit/Dark Lumina 3/Wind Steering/`.
Verify with Play Goemon: select Lumina 3, press 1 and sweep the camera left/right
while blowing, then evade and repeat. Both wings and fresh gusts should turn;
the blowing loop should stop with the cast. No app was exported.

## Dark Lumina 3 queued ground slam — 2026-10-26

Historical verification of the first queue implementation. The user's subsequent
airborne-repeat correction restores the jump/gesture restart on accepted presses;
the unchanged-jump behavior described below is superseded.

Repeated Earth presses previously cancelled the current jump and restarted its
attack ticket. The landing cue also created two visual waves for one damage
pulse. Earth now collects up to five presses before physical landing, keeping
the same jump, animation clock and ticket. Landing locks the count; recovery
presses do not restart the attack. Each queued wave applies the existing local
area/cover check once and emits one recovered wave from the landing position.
Releases are 28 controller ticks apart (about 0.31 seconds at the default rate),
with enough recovery for the last wave. Per-wave damage and radius are unchanged.
Interruptions clear unreleased waves. Borrowed Earth uses the same controller;
native bosses keep one landing damage pulse and now show one matching wave.

This fixes behavior; no CPU/GPU bottleneck or speedup is claimed. Reuse the
existing batched wave mesh, prepared audio and bounded native target query.
Landing dust is emitted once, so five waves do not multiply that decoration.
Do not add per-wave models, materials, timers or another army simulation.

Fresh checks pass 58 focused assertions in both headless and desktop runs:
one through five presses, over-cap input, native target damage per wave, actual
landing, interruption before/after contact, held-key repeat, borrowed skills,
repeated reuse and long frames. The pre-fix desktop regression failed 32 of its
53 assertions. The final desktop run retains zero nodes/resources, 564 prepared
projectiles with zero pool misses and 115 presentation nodes. Frame interval
p95/max was 17.771/60.570 ms; manually stepped work p95 was 1.110 ms. These are
short fixture diagnostics, separate from the user's historical smoothness report
and older stress tests; they do not establish hitch-free or long-session play.
The final fixture also waits longer for effects and adds five edge-case checks,
so its timing is not a controlled speed comparison with the original fixture.

The rendered shared-effects suite passes 71 checks, including twelve simultaneous
Earth cues with exactly twelve waves and stable resources after repeated use.
The native encounter passes 81 checks across all six move families with six
bosses and 120 troops over 3,600 steps, keeping 115 presentation nodes. Its frame
p95/max was 17.265/201.115 ms (including capture work); native step p95 was
1.793 ms. The observed spikes are not evidence of hitch-free full-world play.
Shared checks pass: controls 70, modular skills 3,398, numbered controls 577,
toolkit Python 68, imported assets 12,812, Musashi outfits 98 and structures 86.
Asset preservation passes. No assets were exported or rebaked.

Verify with Play Goemon: select Dark Lumina 3, press **4** once, then repeat with
two through five taps before landing. Count the waves and damage hits; a sixth
tap adds nothing. Dodge before landing, then cast once again to verify a clean
queue. Logs, the pre-change source snapshot and inspected one/five-wave captures
are under `build/Other Files/Asset Toolkit/Dark Lumina 3/Ground Slam/`.
No app export was made.

## Wall break-and-fall animation — 2026-10-26

Enemy castle wall panels now split into six masonry chunks, tumble and fade over
1.35 seconds into the existing low rubble. Local dust stays below the upper
courses so the fall is visible. Breach health, collision removal, navigation,
neighboring panels and reinforcement ownership are unchanged. Ordinary pause
freezes the fall; the victory screen lets the final falls finish.

This is a visual change, not a measured bottleneck fix. It reuses the existing
Wind Meadow stone-block mesh and atlas, with one prepared MultiMesh and an owned
fade material per castle. A break updates fixed instance slots; it does not load
assets, create rigid bodies or allocate new meshes/materials. Idle and completed
effects stop processing. Panel width is applied before rotation so narrow panels
retain solid chunk proportions while falling. Original editable assets are intact.

Fresh launcher verification passes 93 rendered checks; the headless fixture
passes 90. Checks cover real pipe/bullet damage, immediate passage, distinct
falling/rotating poses without shrinkage, duplicate notifications, simultaneous
four-castle falls, pause/victory and map restart. Prepared node counts stay fixed.
The 84-frame simultaneous-fall sample recorded animation-work p95/max
3.010/3.230 ms and frame intervals p95/max 17.473/25.809 ms. This short fixture
pauses battle simulation on victory; it is not a full-army performance result,
controlled speedup or long-session leak check. Earlier large-map hitch findings
and the user's historical smoothness report remain separate evidence.

Toolkit unit tests (68), imported assets (12,812), Musashi outfits (98), motion
(13), structures (86) and asset preservation pass. Verify through Play Goemon:
break a wall panel and watch its upper blocks separate, tip and fall; walk or
shoot through immediately, break neighboring panels, then destroy the final keep.
Logs are `build/Other Files/wall-fall-*.log`; inspected staged-fall captures and
timings are under `build/Other Files/Asset Toolkit/Wind Meadow/Castle Breaches/`.
No app was exported.

## Dark Lumina 3 straight sword waves — 2026-10-26

The second and third sword waves already travelled straight, but their visible
crescents had opposite 33.75-degree yaw offsets. Both player/shared Sword and
native enemy releases now use zero offset, aligning the leading crest with
travel. The existing prepared meshes, pools, hit checks, piercing, damage,
release timing and speed are unchanged. This is an orientation correction,
not a measured performance bottleneck or speedup; it adds no per-frame work.

Fresh desktop-launcher verification passes 108 checks, including four firing
directions, repeated leases, native target contacts, cover and lifetime. The
prepared pool stays at 738 with zero misses and no retained node/resource growth.
Native six-move checks pass at 20/30/60 Hz, including all three sword releases
at four headings. Asset preservation, 68 toolkit unit tests, 12,812 imported
asset checks, 98 Musashi outfit checks, 13 motion checks and 86 structure checks
pass. A separate rendered run passes 81 checks with six native bosses and 120
troops over 3,600 simulation steps, reaching all six attack families with a fixed
115 presentation nodes. Its frame interval p95/max was 20.924/1,009.138 ms;
the observed spikes mean this is not evidence of hitch-free play or a speedup.
These fixtures do not establish normal full-world or long-session performance.

Verify through Play Goemon: select Dark Lumina 3 and click through the three
sword attacks, then turn and repeat. Both raised crescents should point directly
along their flight paths instead of angling left and right. Logs are under
`build/Other Files/Asset Toolkit/Dark Lumina 3/Straight Waves/`; inspected
`straight-yaw-*.png` captures are in the sibling `Piercing Combo/` folder.
No app export was made.

## Enemy assault without waiting rows — 2026-10-26

The user reported enemies standing in straight waiting lines instead of trying
to kill the shrine or player. This was an explicit native combat rule: building
attackers received formation rows, and only row zero could attack. A fresh
regression against the previous source allowed only four of 28 melee troops to
damage a gate; the other 24 waited for front-row deaths.

The smallest fix removes that formation allocator, its per-unit state and its
attack permission gate. Troops use their existing reachable attack destination,
shared terrain flow, stable approach lanes and bounded local separation. Every
troop may attack when its original facing, reach and exact-contact checks pass.
Gunners with clear shots no longer wait behind an artificial firing rank. The
nearby-player candidate also remains available if there is no surviving assault
building. Shrine priority, gate breaching, the 28-unit local interception range,
taunts, retaliation, hidden/dead-target rejection, damage and attack timings keep
their existing owners. Specialized bosses keep their native attack patterns.

This corrects behavior, not a measured CPU/GPU bottleneck. It adds no simulation,
renderer, resource pool, per-unit pathfinder or whole-army target scan. Crowds can
bunch together at narrow gates; they no longer wait for a scripted row vacancy.
More enemies can land attacks together, so an undefended shrine or nearby player
will face more pressure without any increase to individual damage or wave counts.

Fresh native checks cover all 28 melee attackers, all 12 gunners and all 32 mixed
troops damaging the gate, nearby-player pursuit, return to the objective, breaches,
four building faces and narrow passages. The same assault regression fails on
the pre-fix source. Fourteen native suites pass, including target decisions,
terrain/cache/worker movement, lifecycle, mirrors and the three specialized boss
families. The desktop launcher passes all 54 real-valley checks: twelve troops
from all four bases damage gates, then the shrine after a breach; each attacks
the player when approached and returns to the shrine when the player becomes
untargetable. Gate, shrine and player captures were inspected. Initial fixture
failures incorrectly expected troops outside the existing 28-unit radius to
retarget; those logs remain separate from final acceptance.

A fresh 30-second normal-stat Wind Meadow battle maintained all 240 enemies and
96 allies, with 100% foreground focus, unchanged tracked inputs, 3,617 damage
events, no dropped hits and all 365 deaths reinforced. Average FPS was 60.07;
frame interval p95/p99/max was 19.914/27.868/35.424 ms. Native work averaged
0.827 ms. Resources stayed at 1,815; memory rose about 0.4 MB while live effects
and nodes varied. This is short-run acceptance, not a long-session leak or
stutter-free claim. The original user smoothness report and older stress results
remain separate evidence.

In the isolated native approach benchmark, the same 240-enemy/240-ally workload
changed from mean/p95 0.197/0.712 ms to 0.124/0.201 ms; at 2,000 per team it changed
from 1.587/5.559 ms to 1.344/5.111 ms. These are simulation-only observations with
different resulting combat behavior, not a controlled rendered-game speedup.

Shared checks pass: soldier timing/damage 58, runtime 4,109, worker 247, asset
preservation, 68 toolkit unit tests, 12,812 imported-asset checks, 98 Musashi outfit
checks, 13 focused player-motion checks and 86 structure checks. An additional
older `scripts/recovered_musashi_tests.gd` run failed its running-animation and
early-sword-contact expectations (21/23 passed); those remain unresolved and are
not counted as passing. Existing whole-scene teardown RID/resource warnings
remain. No app was exported.

Verify via Play Goemon: let a wave reach a gate, approach the attackers, then move
away. Troops near you should turn and attack; others should keep attacking the
castle. Breach a gate and watch them advance to the shrine. Gunners should fire
whenever they have a clear shot. Preserve exact contacts and terrain clearance
when changing this behavior; do not restore waiting rows to hide congestion.
Evidence is under `build/Other Files/Enemy Assault/`. No app export is needed.

## Large-map castle destruction stalls — 2026-10-26

The user now reports serious lag on the bigger map, especially when breaking an
enemy castle. This supersedes any assumption that the earlier smooth-gameplay
report applies to enlarged maps. Resizing/placement tests had not established
full-battle performance there.

Fresh profiling reproduced the main cause: enemy forts were exported as unowned
static scenery. Removing one panel changed the supposedly permanent collision
prefix, rebuilding the entire terrain collision tree for both native teams.
On the large preset, the native update took 1,078–1,280 ms per destruction;
the slowest measured frame was 2,134 ms, followed by simulation catch-up.

The fix gives each enemy fort an existing mutable collision owner and exports
unchanging scenery before mutable buildings, independent of scene-tree order.
The native terrain tree can then survive panel and keep destruction. Unchanged
box shapes also reuse their prepared local faces. Actual shape changes,
transforms, ownership, disabled/deleted colliders and world resets still
invalidate the appropriate cached data. All collision triangles, army counts,
terrain, visuals, health, breach rules and reinforcement behavior are retained.
Saved physics heights differ slightly from the native field's stored samples;
do not discard either representation as an exact duplicate without proving it.

Fresh desktop-launcher diagnostics, each with 240 enemies and 96 allies, normal
stats, continuous replacement of deaths and three panel breaks plus one keep:

- Large preset, 24 seconds, foreground throughout: native updates 27–70 ms;
  destruction frames 115–281 ms. Average 49.6 FPS, frame p95/p99 34.9/80.1 ms.
  This still fails the full-battle 55 FPS/25 ms p95 acceptance thresholds.
- Standard valley expanded twice to 2.25× width (721×721 field), gameplay
  camera, 24 seconds: 57.6 FPS, p95/p99 20.7/36.7 ms, maximum 167.3 ms.
  Destruction frames were 128–152 ms. Focus was only 86.3%, so this does not
  qualify as a fully foreground performance pass.
- Both final runs retained the complete populations, matched simulation time,
  delivered damage without event gaps and had unchanged tracked runtime inputs.
  Short-run memory varied with live effects; these are not long-session leak
  checks. GPU timestamps were unavailable. The before run had a longer warmup
  and other desktop work overlapped early attempts, so do not claim a controlled
  overall FPS speedup. The collision rebuild bottleneck and its removal were
  directly observed. Brief hitches and slower overhead battles remain.

Fresh checks pass: collision cache 14, terrain 497, lifecycle 36, Dragoon 36,
castle damage 80, latest native castle pathing 54, toolkit Python 68, imported
assets 12,812, Musashi outfits 98, player motion 13, structures 86 and asset
preservation. Ranger standoff still fails one of 21 assertions with both the
changed exporter and a saved copy of the previous exporter. The broader older
`recovered_musashi_tests.gd` also reports two animation/contact expectations;
do not count that suite as passing. Existing shutdown resource/RID warnings
remain. Other concurrent pathing work changed its fixture during this task;
the final 54-check result is recorded separately from the earlier failures.

Verify via **Play Goemon.command**: enlarge the valley, start a wave, break
several panels, walk through the gaps, then destroy the keep. Neighboring walls
must remain solid, and only the destroyed keep stops its reinforcements.
For repeatable measurement use `tests/forest-shrine/large_map_castle_profile.gd`
through the launcher with `--map=wind_meadow_large --per-team=240 --allies=96
--duration=24 --profile-spikes --await-focus`; use `--map=wind_meadow
--expansion=2.25 --ground-view` for the expanded case. Keep other benchmarks
closed and the game focused. Logs, reports and inspected battle captures are in
`build/Other Files/Large Map Castle Lag/`. Earlier large-preset reports inherited
the harness's standard-map hash labels; field widths identify the measured
layouts. Future reports include the correct source asset paths/hashes.
No app was exported; use the desktop source launcher for these changes.

## Resize the current map from preparation — 2026-10-26

The main map now has **Smaller ÷1.5**, a current-size label, and **Bigger ×1.5**
beside Build and Tools. This supersedes the earlier Tools → Bigger map preview
workflow below. The editor still offers fresh standard and large presets under
**New preset…**. Resizing stays in the same run: building/castle coordinates,
health, workers, money and wave progress are retained. Save in the map editor
to retain the authored layout across restarts; resizing alone does not overwrite
an existing saved map. Width/length steps are 1×, 1.5× and 2.25×, with a maximum
of 5.0625× the starting area.

The extra land needs real terrain, physics and native army paths. Extending the
bounds alone leaves enemies outside the old cliff ring. The implementation keeps
the inner terrain and moves the outer cliff rim outward, extending the existing
meadow heights/material. Render and collision triangles use the same expanded
heightfield sent to the native runtime. Checks refuse cropping saved objects,
stranding characters, or changing support heights under buildings/castles.
Existing vegetation and army counts remain intact. New land is open meadow;
it does not automatically generate additional trees, castles or armies.

Preparation performs the terrain/physics/navigation rebuild. This causes a
visible pause; the buttons show **Resizing…** and ignore duplicate clicks while
busy. The bounded field cache avoids repeating height generation during
validation, saving or subsequent resizing. There is no new per-frame terrain
generator or army simulation. The first desktop expansion took about 6.4 seconds
in the initial focused run and about 20.3 seconds starting from the large preset;
a later standard-map run alongside regression tests took longer.
These are setup observations, not gameplay FPS or a controlled speed comparison.
The larger fields use more geometry/memory, and full-battle performance and a
long-session soak have not been measured. The user's older smoothness report
does not establish performance on these expanded layouts.

Verify via Play Goemon: add a free enemy castle, press Bigger, then place another
castle beyond the original edge. Start a wave to check its reinforcements. Return
to preparation and try Smaller: occupied outer space must block the change.
Resize an otherwise unchanged map both ways, then save/load it in Map Editor.
The focused fixture checks placement preservation, inner terrain, navigation,
native reinforcements, repeated resizing, size limits, serialization, input
guards and UI fit at 960×600, 1280×800 and 1920×1080. Logs and inspected desktop
captures are under `build/Other Files/Map Resize/`. No app export is required.

Fresh desktop verification passes 49 checks on each starting preset. Shared
checks pass: original valley 1,206, document 35, castle placement 40, preparation
hotkeys 45, zoom 37 and map editor 27. Asset preservation, 68 toolkit unit tests,
12,812 imported-asset checks, 98 Musashi outfit checks, 13 motion checks and
86 structure checks pass. The earlier failed route/placement experiments remain
in the development logs; final acceptance uses `desktop-final.log` and
`desktop-large.log`. These focused checks do not establish full-battle performance.


## Warcraft Human Peasant workforce — 2026-10-26

The user's request replaces the Goemon worker with the exact original Human
Peasant model and construction sounds. This is an asset integration, not a
newly measured bottleneck or speedup. Keep the user's earlier smooth-gameplay
experience distinct from the focused results below.

The smallest integration changes the existing workforce presentation, portrait
and construction audio. Jobs, health, costs, navigation, repair pulses, tower
cadence/damage and normal native army ownership remain with their existing
controllers. The tower bow and projectile muzzle now share the original Peasant
right-hand socket; native arms are not stretched to the old Goemon socket.
Native Stand/Walk, Gold cargo, Attack mining and Stand Work repair motions are
sampled offline into the existing army pose-texture format/shader. Every worker
shares immutable geometry, textures, materials and atlas data; there is no live
skeleton, per-worker animation loading or runtime retargeter. Construction and
repair reuse the existing four voices, with bounded simultaneous work sounds.
Do not replace this with one new skeleton/renderer/controller per worker.

Fresh checks: 68 toolkit unit tests, 12,812 common imported-asset checks,
98 Musashi outfit checks, 13 motion checks and 86 structure checks pass. All
22 native body and four portrait actions pass Blender preservation/deformation
and action-switch checks. Source/candidate Warcraft imports pass 47,599 checks,
and the active worker atlas, body/cargo/tool visibility, shared bow socket,
native 234 ms work event and unchanged file/imported PCM pass 2,260 checks.
The 452 triangles stay intact; toolkit material resources decrease from six to
three while all six independently visible geosets remain. The six-surface budget
warning is retained. Preservation passes, and 72 source/candidate image pairs
plus native job, front/side/back, bow, portrait and gameplay renders were reviewed.

The final **desktop launcher** fixture passes 46 checks with 24 workers,
five repeat cycles (600 rendered updates) and zero retained nodes/resources.
Normal native combat and its unchanged enemy wave spawning also pass. Its world
presentation CPU p95/max are 1.035/1.491 ms; frame intervals p95/max are
17.876/33.402 ms. These are short fixture diagnostics, not a controlled comparison,
full-battle stress result or long-session stability claim. Desktop construction
placement passes 34 checks; automatic jobs pass 40, and tower/worker visual
contracts pass 14. Existing fixture shutdown resource/RID warnings remain.

Two older regressions remain outside the worker change: tower targeting reports
eight failed assertions with both the new and restored original muzzle; the
unchanged historical fortification assertions independently report three wall/
gate failures. Baseline logs preserve both reproductions. Do not count these
suites as passing. An earlier desktop fixture's simulated recording flag caused
SoundLibrary errors because it had no capture buffer; the final fixture pauses
that recorder while checking the playback gate and has no script errors.

Verify with Play Goemon: recruit a worker, place a structure, watch the red Human
Peasant mine/carry the native gold sack, damage a repairable structure and listen
for hammering, then start a wave and check occupied towers. Work audio must stop
for explicit pause, mute or recording. Original Goemon sources and editable
Warcraft masters remain intact; no runtime backend selector or fallback was
added. The exported app was not replaced.

Maintenance commands and source contracts are in
`assets/characters/warcraft/peasant/README.md`. Re-export only `-- Peasant`, audit,
stage/compare/activate its toolkit candidate, refresh imports, rebuild
`tools/bake_warcraft_worker.gd`, regenerate the portrait, run preservation and
focused/shared checks, then verify through the launcher. Never rewrite hashes
to bypass a stale bake. Evidence is in
`build/Other Files/Asset Toolkit/Warcraft/Peasant/`, with comparison pairs in
`Asset Toolkit/warcraft-peasant/` and `build/Other Files/peasant-*.log`.

## Free castle testing and larger valley — 2026-10-26

Preparation now offers free enemy castles on Wind Meadow Valley and a larger
valley preview under Tools → Bigger map. Castle setup shares the existing layout,
individual damage targets, wall batches, reinforcement groups and native army.
Hover caches placement checks; the ghost is prepared when selected/rotated.
Committing a castle clears only its footprint/exit trees and rebuilds navigation
and tree presentation during preparation, never in the combat loop. No new army
simulation or asset-loading loop was added. The full castle needs level ground;
its exit and actors/buildings remain protected. Save a custom map to retain edits.

The larger preset is 1.5× wider/longer (2.25× area). It is baked ahead of play with
`tools/build_wind_meadow_map.gd -- --large`, reusing the same art and generator.
The field is 481×481 instead of 321×321; render/physics geometry, foliage and trees
increase with the area. The four initial enemy castles move farther out while
the central fort stays the same size. This is a requested testing space, not a
measured bottleneck fix or speedup. The existing army cap remains 240. Full-battle
frame time and long-session memory on the large preset have not been measured;
the user's older smoothness report does not establish large-map performance.

Verify through Play Goemon: Build → Enemy castle works with zero gold, R rotates,
the ghost marks its exit, and right click/Escape cancels. Start combat to check
reinforcements and destroy its keep to stop that source. Tools → Bigger map opens
a preview; Back restores the current run and Play map starts the larger layout.
The editor's Map size menu can return to the standard preset. Preserve the baked
terrain/native-navigation contract when adding sizes rather than stretching only
the visible mesh or changing bounds alone.

Fresh focused checks pass headlessly and through the desktop launcher, including
zero-cost placement, rotation/cancel, collision and actor protection, tree removal,
map serialization, native reinforcements, destruction, size preview/restore,
placement and spawning beyond the old boundary, and larger native terrain/bounds.
Shared checks pass: standard valley 1,206, map document 35, preparation hotkeys 45,
building placement 34, toolkit Python 68, imported assets 12,812, Musashi outfits 98,
motion 25 and structures 86. Asset audit reports 299 assets with zero read errors;
preservation passes. Existing motion-fixture teardown RID/resource warnings remain.
Logs are `build/Other Files/enemy-castle-*.log`; inspected rendered captures are in
`build/Other Files/Enemy Castle Testing/`. No app was exported.

## Dark Lumina 3 straight sword blades — 2026-10-26

The user saw the second and third sword waves turning in flight. Their velocity
was already constant; the player projectile and native packed presentation were
rotating the crescent graphics with age. Both now retain their opposing 33.75°
launch angles throughout flight. The same prepared projectile serves borrowed
Sword and mirror allies. Damage, piercing, release timing, size, speed, lifetime
and solid-cover checks retain their existing owners and values. No assets were
changed and no new frame loop, pool, material or army query was added. This is a
visual correction, not a measured performance bottleneck or speedup.

Fresh focused checks pass 88 assertions headlessly and through the desktop
launcher, including both blades' fixed orientation and straight displacement
at 20/30/60 Hz and a long step, simultaneous releases, native enemy contacts,
duplicate-hit suppression, cover, expiry and reused leases. The pool remains
738 with zero misses or growth; this fixture also prepares Kojiro as a reference.
Rendered captures were inspected. Native packed-projectile checks pass 2,190
assertions, including both crescent angles at four flight ages. The native
universal library was rebuilt. The focused fixture disables live input while
manually stepping attacks; an earlier desktop repeat stopped advancing shots
for part of its frame loop and is not counted as acceptance. The 70-check
controls fixture passes headlessly;
restoring the old player spin fails its orientation check. Broader rendered
controls runs have varying non-sword spell completion/release/cleanup failures;
the old-spin desktop baseline also has a spell-release failure. Those runs are
diagnostics, not a passing whole-controls result.

Asset preservation, 68 toolkit unit tests, 12,812 imported-asset checks,
98 Musashi outfit checks, 13 motion checks and 86 structure checks pass.
Existing fixture shutdown resource/RID warnings remain. These focused checks
do not establish full-battle frame time or long-session stability.

Verify with Play Goemon: select Dark Lumina 3 and click through the ground wave
and both raised blades into a row of enemies. Each blade should keep its launch
angle instead of swiveling while it travels. Repeat after turning the camera.
Logs are `build/Other Files/dl3-straight-*.log`; final focused captures and reports
are under `build/Other Files/Asset Toolkit/Dark Lumina 3/Piercing Combo/`.
No app was exported.

## Kojiro gradual phoenix growth — 2026-10-26

The phoenix starts at half its previous launch width/height and grows linearly
to the existing maximum over two seconds, then holds that size until expiry.
The previous visual reached maximum at 1.6 seconds. This is visual tuning,
not a measured performance bottleneck or speedup. The existing contact growth,
damage, travel, release timing and three-second lifetime remain unchanged;
early in flight the damage footprint is therefore larger than the artwork.
Keep contact scale separate from visual scale and preserve independent skill
size/hit-area settings. The shared pooled update changes only prepared node
scale; it adds no resource loading, materials, geometry or army queries.

Fresh desktop-launcher verification passes 620 checks, including growth samples,
native hits/cover, borrowed casts, three volleys of twelve reused phoenixes and
five simultaneous native-owned allies. Pool misses, focus losses, repeated-flight
node/resource growth and measured idle resource deltas are zero. The rendered
orientation fixture passes 116 checks, and six fixed-camera growth samples were
visually reviewed. Manually stepped player/projectile CPU p95 is 0.993 ms; the
3,914 rendered intervals have p95/max 18.693/46.517 ms. These are isolated-fixture
diagnostics, not a controlled before/after comparison, full-battle result or
long-session soak. The user's earlier smoothness report remains historical.
Asset preservation, 68 toolkit unit tests, 12,812 imported-asset checks,
98 Musashi outfit checks, 13 motion checks and 86 structure checks also pass.

Verify with Play Goemon: choose Kojiro and cast the phoenix into open space;
watch its small launch expand steadily for two seconds. Repeat and try borrowed
casts or Mirror Image. Logs are in `build/Other Files/Asset Toolkit/Kojiro/Phoenix
Growth/`; fixed-camera images are `Phoenix Flight/after-growth-*`. No asset or app
was exported. The earlier flight-angle checks below describe that prior snapshot.

## Kojiro phoenix flight angle — 2026-10-26

The user still saw a forward phoenix cast pointing right. The previous
camera-facing shader rolled the entire frontal bird image toward screen-projected
velocity. Its synthetic tip/tail test checked that rotation, rather than whether
the actual bird stayed upright. The smallest correction disables billboarding
only for the phoenix and sets its existing pooled node's yaw/pitch from launch
velocity, with no roll. The face follows travel and the wings stay level. The
original frontal atlas stays upright; laying it flat made it nearly invisible
at the normal low camera height and was rejected during rendered inspection.

This is a presentation correction, not a measured performance bottleneck or
speedup. Straight movement, aiming, muzzle, growth, damage, hit volumes, release
timing and homing steering retain their existing owners and values. Setup still
prepares materials once; each reused launch sets its own orientation. No new
frame loop, army query, resource loading, material creation or simulation was
added. Physical single-plane art naturally foreshortens in side-on views.

Fresh Metal checks cover 32 camera/flight combinations, including the low
shoulder view, pitched/vertical flight and camera-aligned shots. Reproducing the
old camera-facing presentation fails 29 of 116 physical-orientation checks; the
final presentation passes all 116. Real-art before/after captures were inspected.
The separate homing bird renderer retains all 45 passing checks. Preservation,
68 toolkit unit tests, 12,812 imported-asset checks, 98 Musashi outfit checks,
25 motion checks and 86 structure checks pass. These focused results do not
establish full-army frame rate or long-session stability.

The desktop launcher passes 449 gameplay assertions with zero focus losses or
pool misses, including original and borrowed spells, actual aim/muzzle, native
damage, solid cover, three volleys of twelve reused phoenixes and five native-owned
Kojiro allies casting together. Idle resource deltas are zero for both measured
fighters. Manually stepped player/projectile CPU p95 is 0.983 ms; the fixture's
3,914 rendered intervals have p95 18.619 ms and max 46.156 ms. These are focused
fixture timings, not a controlled speedup or full-battle result. Existing
whole-scene shutdown resource/RID warnings remain in the logs.

Verify through Play Goemon: choose Kojiro and cast RMB/T straight ahead, rotate
the camera, then cast while airborne. The bird should keep level wings and face
its travel direction instead of rolling toward the right. Evidence is under
`build/Other Files/Asset Toolkit/Kojiro/Phoenix Flight/`; gameplay captures and
timings retain the existing `Kojiro/Ground Combo/` destination. No app or asset
was exported. The earlier 2026-10-24 billboard results below are historical and
are superseded for phoenix orientation by this correction.

## Per-skill balance controls — 2026-10-26

Settings → Skill Balance now saves visual size, hit area, travel speed and damage
multipliers by stable skill ID, including native-only Illidan bolts and Skullpion
attacks. Every value starts at 1× the current approved behavior. Unsupported
values are marked N/A; buffs and body-only presentation do not acquire invented
projectiles or damage. Reset restores only the selected skill. Saved profiles
reject unknown IDs/fields, nonnumeric/nonfinite values and out-of-range settings.
Existing equipment, character balance and user preferences are preserved.

This is requested tuning, not a measured bottleneck fix or speedup. Original and
borrowed controllers attach four scalar snapshots to their existing attack
tickets. Released attacks retain those values across resetting settings or
changing fighters. Damage goes through the existing enemy/building attribution;
visual size and contact radius are independent. Shared projectile leases restore
their prepared visual scale and per-use state, so reuse does not multiply the
previous cast's values. No new simulation, renderer, resource-loading loop,
material duplication or army-wide target search was added. Keep future skills in
the same catalog/ticket/pool paths and declare only the values they actually use.

Fresh focused verification passes 647 assertions in headless mode and through
Play Goemon, covering automatic save/reload, reset isolation, original and borrowed
skill IDs, damage to native enemy HP exactly once, aura contact, fast swept hits,
cover, twenty reused projectiles, five rounds of twelve simultaneous bolts with
no pool growth/misses or retained resource growth, and five simultaneous
native-owned mirror allies using the same tuning. The desktop settings capture
was inspected. These are focused correctness/reuse checks, not a full-battle or
long-session performance claim; the user's earlier smoothness report remains
historical. Whole-scene shutdown RID/resource warnings remain in the test logs.

Shared regressions pass 3,398 modular-skill checks, 577 numbered-input checks,
423 Warcraft-character checks, 338 universal mirror checks, 10 projectile-pool
checks, 68 toolkit unit tests,
12,812 imported-asset checks, 98 Musashi outfit checks, 13 motion checks and
86 structure checks. Asset preservation passes. Logs are
`build/Other Files/skill-balance-*.log`; the desktop capture is
`build/Other Files/Asset Toolkit/Skill Balance/settings.png`. No assets or app
were exported.

To verify: launch Play Goemon, open Settings → Skill Balance, choose Illidan's
Metamorphosis Bolt, change Visual size and fire again. Reset it, then try Travel
speed independently: the bolt should move faster without changing its size.
Immolation's Hit area should reach farther independently of the aura's appearance.
Change Damage and compare hits, then reopen the game to check saving. Use Reset
this skill to recover its approved baseline. Larger contact areas can visit more
nearby enemies and larger effects cover more pixels; profile an actual battle
before treating extreme multipliers as performance-neutral.

## Model size for every playable fighter — 2026-10-26

Settings → Character Balance now exposes Model size × for all 32 playable IDs,
including hidden fighters and playable bosses. The existing common-row schema
owns its 0.1–10× validation, independent profiles, saving and reset. Warcraft
fighters retain their 6× defaults; everyone else retains 1× relative to their
authored presentation. The initial fighter also applies its saved scale during
setup, without requiring a switch away and back. Selection, live edits and
Mirror Image continue using the existing model scale. Collision, melee reach,
attack rate and prepared assets keep their separate owners.

This is a settings change, not a measured bottleneck fix. The production change
moves one row and adds one setup assignment; there is no new frame loop, model
loader, material creation, pool or army simulation. Fresh desktop balance checks
pass 272 assertions, including every fighter's immediate edits, invalid input,
save/reload, independent editing, reselection, reset and collision preservation.
The rendered pursuit fixture passes 23 checks, including five simultaneous
copies of a resized Goemon and both Warcraft fighters; menu and gameplay captures
were inspected. The full-roster mirror fixture passes 338 checks at a saved
1.7× size, covering all five copies and original attack paths for every fighter.
Preservation, 67 toolkit unit tests, 12,812 imported-asset checks, 98 outfit
checks, 13 Musashi motion checks and 86 structure checks also pass.
No controlled speedup or full-battle/long-session result is
claimed. Existing scene-shutdown resource/RID warnings remain.

Verify through Play Goemon: open Settings → Character Balance, select any fighter
and adjust Model size × at the top of the left panel. Reselect the fighter,
restart, then Reset to check persistence and the original default. Summon Mirror
Image to check five copies at the saved size. Large visual models can overlap;
use the existing separate Melee reach control when tuning reach. Logs and captures
are under `build/Other Files/Asset Toolkit/Model Size/`. No app was exported.

## Illidan splash and missile effects — 2026-10-26

The user requested a bigger damage area and longer flight, then clarified that
the bolt should travel longer rather than leave a damaging ground effect.
Contact radius is now 0.9 m and flight lasts four seconds at 28 m/s. The first
enemy or wall contact resolves one splash: full/half/quarter damage within
1/3/5 m. Direct hits retain 64 base damage. Warcraft's standard Meta weapon
supplies the 50/150/250 source-radius and 100/50/25% falloff pattern; the campaign
Illidan row has those fields but a different weapon-type flag. This is explicit
Goemon tuning, not a claim of exact campaign behavior.

The native army remains the only enemy simulation. Each impact asks the existing
local candidate query once, then checks fitted hurt volumes and wall visibility.
The existing projectile pool also owns the recovered cloud trail and two impact
emitters. Textures, three shared immutable meshes/materials and per-lease particle
nodes are prepared on selection. Flight and contact create no such resources.
Twenty-four leases (previously twelve) accommodate the longer flight plus 667 ms
of cosmetic impact playback at the default maximum chain rate. Higher custom
attack rates can still grow the existing pool normally. Particles reset on reuse;
fading explosions cannot inflict repeat damage. Art uses original textures and
emitter values, with Godot approximations for Warcraft tail geometry/timing.

Fresh checks pass 142 focused combat assertions and 14 desktop gameplay/render
assertions. They cover all falloff boundaries, direct/full damage, nearby native
enemy hits, distant misses, airborne targets, solid cover, pause, the final flight
segment, lifetime, ally attribution and repeated leases. Five volleys of 24 shots
retain 3,652 nodes / 1,794 resources, zero pool misses and unchanged texture cache.
The final rendered fixture's frame p95/max is 17.610/20.059 ms; manually stepped
player/projectile work p95 is 0.968 ms. This is requested combat/VFX work, not a measured bottleneck
fix or speedup; these short tests do not establish full-battle or long-session
smoothness. Existing whole-scene shutdown resource/RID warnings remain.

Shared checks pass: 423 desktop character assertions, 97 desktop energy checks,
27 headless flight checks,
68 toolkit unit tests, 12,812 imported-asset checks, 98 Musashi outfit checks,
13 motion checks, 86 structure checks and preservation. The audit reads 299
assets with zero errors; existing geometry budgets do not authorize art changes.
The five rendered fog assertions pass with the new particle setup.
The two additional source textures are 256×256 and 64×64. No character master,
GLB, army pose bake or app export was changed.

Verify with Play Goemon: transform Illidan, shoot a group, then a target behind
a wall. Nearby exposed enemies should receive one falling-strength splash;
the wall must block targets behind it. Fire into open space and watch the longer
purple cloud trail and impact burst. Recovery details are in
`assets/characters/warcraft/demon-hunter/missile/README.md`; evidence is in
`build/Other Files/Asset Toolkit/Illidan Splash/`.

## Illidan bolt size follow-up — 2026-10-26

The requested larger projectile increases its visual width and height by 50%
(`pixel_size` 0.24 → 0.36). This is visual tuning, not a bottleneck fix. It changes
one setup value on the existing pooled sprite, preserving the Unfogged material,
damage, 0.45 hit radius, release timing, speed and lifetime. The larger quad can
cover more pixels; no repeated texture/material creation or army work was added.

Fresh desktop energy checks pass 97 assertions with no resource/cache growth or
pool misses across five rounds of twelve simultaneous bolts. Same-camera captures
show the old and new sizes. The twelve-bolt frame p95/max was 18.447/20.776 ms at
0.24 and 17.748/18.282 ms at 0.36; this short sample does not demonstrate a speedup
or establish full-battle/long-session performance. The headless flight fixture
passes 27 checks. Preservation, 67 toolkit unit tests, 12,812 imported-asset
checks, 98 Musashi outfit checks, 13 motion checks and 86 structure checks pass.
The five rendered fog assertions also pass at the larger size; that isolated
renderer ran directly because an interactive Play Goemon session held the
launcher lock. The full energy fixture above ran through the desktop launcher.

Verify through Play Goemon: select Illidan, transform and fire while grounded
and flying. Expect a larger purple glow with the same contact behavior.
Evidence: `build/Other Files/Asset Toolkit/Illidan Bolt Size/`.
No app was exported; earlier full-character results remain historical.

## Warcraft tower audio — 2026-10-26

The arrow tower now uses the Human Guard Tower missile's three original launch
clips and ArrowHit contact cue. This is a sound replacement, not a measured
performance bottleneck fix or speedup. The smallest change prepares the original
WAVs through the existing character audio bank at tower setup and uses the same
28-voice SFX pool. Launches keep the 15 ms overlap limit; impacts keep 35 ms.
There is no new audio manager, per-shot asset loading or extra processing loop.
Existing arrow flight, damage, arrival events and Ranger overrides retain their
owners. Godot's default WAV compression was disabled for these four small clips
after the first test caught changed imported PCM; originals remain untouched.

Fresh desktop verification passes 28 checks, including exact imported PCM/rate,
all three launch variations, arrival-only impact, recording, hidden events,
mute, pause, overlap limits and Ranger recording/preview priority. Five volleys
of twelve shots reuse the same voices/cache and retain zero resources after
cleanup. This focused reuse check does not establish full-battle frame times or
long-session behavior; the earlier gameplay smoothness report remains historical.
Asset preservation, 67 toolkit unit tests, 12,812 imported asset checks,
98 Musashi outfit checks, 13 motion checks and 86 structure checks pass.
The geometry audit reads 299 assets with zero read errors; its existing budget
warnings do not describe these audio files or authorize geometry changes.

Verify through Play Goemon: build an arrow tower and start a wave. Listen for
the firing variations and a separate contact sound when each arrow arrives.
The test and recovery details are in
[`assets/audio/warcraft_tower/README.md`](../assets/audio/warcraft_tower/README.md);
logs are under `build/Other Files/Asset Toolkit/Warcraft/Tower Audio/`.
No app was exported.

## Illidan bolt square in fog — 2026-10-26

The reported Meta attack problem was clarified as a square around its bolt.
This was a rendering flag omission, not a measured performance bottleneck:
the original Warcraft missile glow is Unfogged, while the imported projectile
allowed scene fog to color its entire additive sprite. The smallest fix sets
`disable_fog` on its existing material once during pool setup. It adds no
per-frame work, textures, materials, models or pools. Animation and combat
timing, fourfold size, damage, travel and hit checks retain their existing owners.

Fresh desktop rendering reproduces the square and passes five regression
checks after the fix; corner brightness relative to the background falls from
0.521569 to 0.003922. The desktop energy fixture passes 97 checks, including five
cycles of twelve simultaneous reused bolts without resource/cache growth or
pool misses. Its twelve-bolt frame p95/max is 16.982/17.157 ms. This short fixture
is not a before/after speedup measurement or a full-battle/long-session claim.
Existing whole-scene shutdown resource/RID warnings remain.

The desktop character fixture passes 423 checks with zero resource growth and
pool misses. Preservation, 67 toolkit unit tests, 12,812 imported-asset checks,
98 Musashi outfit checks, 13 player motion checks and 86 structure checks pass.

Verify through Play Goemon: select Illidan, transform, and fire toward foggy
distant scenery; the purple glow should have no rectangular fog background.
Evidence: `build/Other Files/Asset Toolkit/Illidan Meta Attack/`; focused test:
`tests/forest-shrine/warcraft_bolt_render_test.gd`. No app was exported.

## Illidan second-jump front flip — 2026-10-26

Normal Illidan now turns forward once on his second jump at Musashi's eight-tick
(8/30-second) pace. His skinned Warcraft rig differs from Musashi's rigid-part
rig, so the small runtime change reuses Hero's existing torso-pivot somersault
and jump clock while retaining Illidan's original ready pose. It rotates the
existing body node before updating camera-facing glows. It loads no resources,
constructs no materials and performs no bone retargeting during the jump.
The first jump, hit/collision geometry, lift, combat timing and Meta flight keep
their existing owners. Other poses reset the transform. Original assets are
unchanged; the shared adapter's dependent native atlas was regenerated.

This is requested presentation, not a measured performance bottleneck or speedup.
Fresh desktop verification passes 39 assertions: forward direction, complete
rotation at Musashi's duration, upright collision, no jump damage, first/third
presses, landing, attack/morph interruption, Meta flight, equipped single jump,
reselection and repeated use. Four unobstructed turn captures were inspected.
After warmup, five more cycles retained 3,967 nodes / 1,837 resources and the same
animation player. Focused frame p95/max was 17.901/22.281 ms; manually stepped
player work p95 was 0.550 ms. These short fixture observations do not establish
full-battle or long-session performance; historical smoothness reports remain
separate. Existing scene-shutdown resource/RID warnings remain.

Verify through Play Goemon: use normal Illidan with Original Jump Style, press
Space, release and press again in the air. Expect one forward turn, then an
upright descent. Attack or press 1 during the flip, land and repeat. Evidence:
`build/Other Files/Asset Toolkit/Illidan Flip/`; focused fixture:
`tests/forest-shrine/illidan_flip_test.gd`. No app was exported.

## Illidan Metamorphosis flight — 2026-10-26

Meta Illidan now enables the same existing Hero flight path as Dark Lumina 3:
hold Space to rise, release to descend and Shift to boost. The smallest change
adds the current form to `Hero.can_fly`; the shared input, movement, collision,
acceleration and flight speeds remain their owners. Normal Illidan keeps his
double jump, explicit Jump Style equipment retains priority and reversing the
form in midair restores gravity. The existing alternate ready pose supplies the
floating body. No model, animation, material, pool or army simulation was added.

This is requested movement behavior, not a measured bottleneck or speedup.
Fresh desktop checks pass 28 assertions, matching Dark Lumina 3's normal/boosted
velocity and descent, airborne bolt release, form reversal, equipment priority,
fighter switching and repeated real landings. Five reuse cycles retain the same
node/resource counts and zero pool misses after landing effects settle. The
initial headless count included still-live landing effects and is not a passing
result; the settled headless run passes 27 checks. The focused desktop frame
p95/max is 16.894/33.296 ms; manually stepped player work p95 is 0.314 ms.
These short checks do not establish full-battle or long-session performance;
earlier smoothness reports remain historical.

Shared regressions pass: jump styles 666, Warcraft characters 423, universal
mirrors 338, Dark Lumina 3 tuning/flight 37, toolkit unit tests 67, imported
assets 12,812, Musashi outfits/motion 98/25 and structures 86. Existing
whole-scene shutdown resource/RID warnings remain; the live repeated-flight
counts are stable. No character assets were edited or re-exported.

Verify with Play Goemon: select Illidan, press 1, hold Space, steer with WASD,
hold Shift, release Space, fire while airborne and reverse form. Select Original
in Skills & Jump if another jump style is equipped. Evidence and the rendered
capture are under `build/Other Files/Asset Toolkit/Illidan Flight/`; the focused
fixture is `tests/forest-shrine/illidan_flight_test.gd`. No app was exported.

## Growing groups per spawn spot — 2026-10-26

Each spot now starts at ten and independently releases eleven, twelve and so on
after a member of its current group starts attacking. A wiped-out group also
advances. Core Game Balance exposes Starting group size (10) and Growth per
group (1); zero growth restores fixed groups. Both settings save through the
existing validated balance schema and apply next run. Each numbered wave resets
growth. Finite rosters retain their exact totals and final partial groups;
barracks keep repeating their selected mix. Old saves receive the new defaults
without changing their composition. This supersedes the fixed-ten pacing below.

The smallest change adds one target count to each existing portal group and
increments it only when that group advances. Retries, blocked mouths and active
caps retain the same target. The native army, attack events, placement and pooled
presentation remain the owners. There is no new simulation or per-unit frame
loop. This is requested pacing, not a measured bottleneck fix or speedup; larger
later groups can increase active combat load, subject to the existing cap.

Fresh model/native checks pass 65 assertions, including independent growth,
partial groups, final totals, reset, caps, blocked/destroyed entrances, repeated
camp groups through fifteen, custom growth and zero growth. The painterly desktop
fixture passes 75 assertions: one spot releases 10, 11 and 12 native enemies while
the other three remain at ten. The desktop balance fixture passes 191 checks,
including defaults, validation, editing, save/reload, active-run isolation and
reset. Both captured views were inspected. Roster (34), camps (18), toolkit Python (68),
imported assets (12,812), Musashi outfit (98), motion (13), structures (86) and
asset preservation also pass. These are focused correctness checks; no fresh
full-battle frame-time or long-session result is claimed. Existing whole-scene
shutdown resource/RID diagnostics remain in the settings/roster fixtures.

Verify through Play Goemon: open Tools → Core Game Balance and leave Starting
group size at 10 and Growth per group at 1, then start a new run. Let one spot's
group attack; expect eleven next, then twelve after that group's own attack.
Other spots wait independently. A narrow entrance may need several retries.
Settings and gameplay captures plus logs are under
`build/Other Files/Asset Toolkit/Wave Groups/growth*`. No app was exported.

## Ten enemies per spawn spot — 2026-10-26

The fixed group size below is historical; the growing-group follow-up above
supersedes it while preserving the independent attack gates.

The user clarified that each of the four spots should send ten enemies, so the
opening now contains forty, subject to entrance clearance and the existing active
cap. Each spot has an independent group: any member starting an attack releases
that spot's next ten. The other spots continue waiting for their own attacks.
An older group's attacks cannot release its replacement; a wiped-out group can
advance. Three-portal and custom maps use ten per available portal, while maps
without portals retain one ten-enemy group. Finite wave totals remain unchanged.

The small change keeps groups keyed by the existing portal index and passes that
index into the existing placement helper, including the broad-boss fallback.
Blocked or destroyed spots cannot redirect their next group through another
spot. An enemy's existing source record selects its group in constant time;
waiting checks visit only ten stored IDs per spot. Native attack startup,
combat, pooled presentation, navigation and placement clearance are unchanged.
This is a pacing correction, not a measured performance fix or speedup.

Fresh model/native checks pass 49 assertions: four groups of ten, independent
and simultaneous advancement, stale attacks, partial groups, death, cap limits,
blocked and destroyed entrances, nonportal maps, boss source attribution and
startup before damage for all enemy types. Roster (34), camps (18), Skullpion
(74), valley (1,206), portal editor (12), toolkit unit (67), imported assets
(12,812), Musashi outfit (98), motion (13), structures (86) and preservation
also pass. The painterly desktop fixture passes 57 assertions: it observes
10/10/10/10 native arrivals, then 20/10/10/10 after one spot starts attacking,
with the other three groups unchanged. The saved rendered capture was inspected.
These are focused correctness checks, not frame-time measurements. Evidence is
under `build/Other Files/Asset Toolkit/Wave Groups/per-spot-*.log` and
`per-spot-attack-start.png` in the same folder.

Verify through Play Goemon: let ten enemies emerge from each of the four spots.
Trigger an attack from just one direction and watch only that spot release its
next ten. A narrow mouth can fill its group over several short retries as
previous arrivals move clear; no enemies are discarded to force a batch to fit.
No app export or full-battle/long-session benchmark was made.

## Enemy groups of ten — 2026-10-26

The single shared group described below is historical; the per-spot correction
above supersedes it.

Wave and camp arrivals fill one group of ten, then wait for any member of that
group to start an attack before admitting the next ten. The user clarified
that startup should count, so this supersedes the initial landed-hit gate.
Misses or later interruptions still count. Older groups' attacks cannot release
a newer group. If every member dies before attacking, the next group may enter
anyway. Blocked entrances and the active cap can delay members of a group;
unsuccessful attempts never consume the wave roster. Finite waves retain their
exact totals, including a final group smaller than ten.

This is requested pacing, not a measured performance fix. The spawner retains
at most ten IDs. Ordinary enemies and both Lumina forms publish attack startup
through the existing native event stream; Skullpion does so for attacks but
not climbing or exposed-core reactions. Compact event delivery retains the
source ID. No army scan, new simulation, renderer or pool is added. Native hit timing, damage, targeting,
collision and portal placement retain their existing owners.

Initial landed-hit verification passed 20 model and 26 desktop assertions.
Those results are historical for that earlier trigger. Fresh startup checks
pass 40 model/native and 46 painterly desktop assertions: every selectable enemy
type reports startup before damage in full and compact event delivery, and the
rendered game releases the second group while the player still has full health.

Shared checks pass: event delivery 11, soldier attack timing/damage 58, native
runtime 4,109, worker parity 247, Skullpion 74, DL2 25 with 23,275 pose samples,
DL3 126, roster 34, toolkit unit 67, imported assets 12,812, Musashi outfit 98,
motion 13, structures 86 and preservation. The Skullpion cue fixture now uses
open ground for its manually placed boss and reads compact events before scene
callbacks drain them. Its former probe overlapped the fort. The exposed-core
check confirms that receiving heavy hits cannot release reinforcements.

Final results are in the `attack-start-*.log` files and
`native-attack-start.png` under `build/Other Files/Asset Toolkit/Wave Groups/`.
The earlier camps (18), valley (1,206) and portal editor (12) checks passed for
the original grouping change and were not repeated for the startup follow-up.
Existing isolated-fixture shutdown resource/RID warnings remain. No full-battle
frame-time benchmark, long-session soak or app export was made.

Verify through Play Goemon: start a wave, watch the first ten arrive, and let
one reach a target. The next ten should start entering when its attack begins,
before damage lands. Repeated attacks from the old group must not release more
while the new group is still approaching.

## Illidan face depth and fourfold bolt — 2026-10-25

The reported weird face was reproduced as a transparency/depth-sorting error:
triangles behind the face were drawing over it. This is a rendering correction,
not a measured CPU bottleneck. The smallest fix uses Godot's alpha depth prepass
for the existing native cutout materials at model setup. It preserves texture
alpha and wing opacity. Keep other blend modes as authored: giving the alternate
form's black body the same prepass hides its embedded purple glow. Front, side
and three-quarter desktop captures distinguish this from a rig or texture defect.

Metamorphosis bolts reuse the same prepared Sprite3D and projectile pool at
`pixel_size` 0.24 instead of 0.06: four times the width and height, with unchanged
damage, hit radius, release timing and travel. That increases a visible bolt's
screen area, so judge repeated shots in the renderer rather than using headless
logic tests to claim smoothness. There is no per-shot loading, resource creation,
new pool or change to army counts. The shared model's dependent native atlas and
gallery portraits were regenerated; original editable assets remain intact.

Fresh desktop checks pass 97 visual/reuse, 423 character and 56 skill assertions,
with zero repeated-use resource growth and no projectile-pool misses. Holding
twelve bolts in the same scene/camera for 120 rendered frames at each size gave
old/new frame p95 18.530/18.574 ms and max 19.848/25.010 ms. This is a short
visual-cost diagnostic, not a speedup or full-army/long-session guarantee.
No other regression job ran concurrently. Native atlas, imported assets,
toolkit unit, outfit/motion, structure and preservation checks pass. Existing
whole-scene shutdown resource/RID warnings remain.

Verify through Play Goemon: inspect Illidan's face from several angles, transform,
fire several shots, reverse form and switch fighters. Preserve the purple body
glow and wing transparency while checking the face. Details and current evidence
are in `docs/recovered-warcraft.md` and `build/Other Files/Asset Toolkit/Illidan Face/`.
The user's historical smoothness report remains separate from this focused work.
No app was exported.

## Illidan model replacement — 2026-10-25

Illidan now occupies Demon Hunter's stable slot 32. This is an asset replacement,
not a bottleneck fix or measured speedup. Reuse `warcraft_model.gd`, the existing
combat/skill controller, native local queries and projectile pool. The original
24-action Blender master stays in `Warcraft/assets/Illidan/Illidan.blend`;
the exporter prepares both melee recoveries at 0.9 seconds so the replacement
does not change the existing contact/recovery contract. All other gameplay
settings keep their owners. The stable asset and skill keys intentionally stay
`demon-hunter` for saved settings.

Illidan adds wings and more native bones: 302 exported joints and 76 billboard
bones versus the previous 234/55. Four prepared emitters retain morph smoke,
demon attack energy and swimming wakes. They remain selection-time setup and
prepared tracks; combat does not reload assets or construct materials. The
lossless derivative keeps 1,534 triangles and 17 geosets, reducing duplicate
materials from 17 to 6. Preserve the surface-budget warning and original art.

Fresh desktop character checks pass 423 assertions with zero projectile-pool
misses and zero repeated-special resource growth. Focused rendered frame interval
p95/max is 17.296/33.227 ms; manually stepped player/projectile work p95/max is
0.672/1.994 ms. Native mirror checks pass 1,057 and active imported Warcraft
motion checks 42,791. This short fixture does not establish full-army performance
or long-session memory stability. Existing whole-scene teardown warnings remain.
The current desktop skill fixture passes 56 checks with zero repeated-use
resource growth (frame interval p95 17.233 ms; stepped work p95 1.740 ms).
These results are separate from the user's historical smoothness report and
the previous Demon Hunter measurements below.

Verify with Play Goemon: select **Illidan**, inspect wings and both glaives,
alternate melee clicks, press 1 to transform and fire, then reverse form. Press
2 beside enemies for Immolation, jump/evade, and switch fighters. Keep future
changes on the same prepared-asset path. Source and rebuild instructions are in
[recovered-warcraft.md](recovered-warcraft.md); evidence is under
`build/Other Files/Asset Toolkit/Illidan/`. No app was exported.

## Shared jump effect — 2026-10-25

The user rejected the generated jump beep heard on Blademaster and Demon Hunter.
Both lacked a character-specific jump cue and reached `audio/jump.wav`. The
shared fallback and startup sound table now reuse the existing voice-free
Goemon/Yae ROM event `21D`, `assets/audio/recovered_yae/event_21d.wav` (0.095 s).
Its bytes match the recovered Goemon `event_21d_dry.wav`. This shared binding is
an adaptation, not a Warcraft source cue. Character-specific recovered jumps,
authored silence, user recordings, gain and mute keep their existing priority.
The prototype WAV is preserved but no longer loaded by game startup.

This is an audio choice correction, not a measured performance bottleneck.
The fix uses a preloaded immutable sample and the existing voice pool. Fresh
checks passed 56 headless and 60 painterly desktop assertions: roster-wide
routing, three ground/double-jump repetitions per Warcraft fighter, Studio
controls and 2,000 overlapping cues with unchanged node/resource/cache counts.
The desktop mixer recording is non-silent; asset preservation passed. Existing
scene-shutdown RID/resource warnings remain. An initial headless run overlapped
Warcraft mirror edits and hit a missing `dispose` method at shutdown; the final
rerun has no script errors. No full-battle benchmark, long soak or app export
was performed.

Verify via Play Goemon: select Blademaster or Demon Hunter, tap Space, then
tap again airborne. Both takeoffs should use the short recovered effect.
Keep future shared defaults in `SoundLibrary.shared_default_for` and the
startup sound table so new characters cannot reach the old beep. Evidence is
under `build/Other Files/Asset Toolkit/Shared Jump Audio/`.

## Independent castle breaches and health balance — 2026-10-25

The follow-up replaces shared castle damage with independent wall panels no
longer than six metres, gates, towers and keeps. Each starts with 6,000 HP.
Core Game Balance exposes separate fortification and keep health values; edits
apply on the next run. Breaking a panel opens its collision and native navigation
while the keep, neighboring panels and reinforcements remain active. Destroying
the keep clears the remaining fortifications; all four keeps still decide victory.
Wide attacks can hit multiple nearby panels. Bullet contacts select the first
panel in their path. Saved map layouts exclude transient health and breach state.

This is a gameplay change, not a measured bottleneck fix. The existing objective
contact code represents each section, with static physics targets and no idle
processing. Native combat first checks the four castle bounds, then only nearby
panels, instead of adding every wall to each local target query. Intact panels
share one mesh batch per castle. Ruins retain four prepared batches and the same
two bounded emitters; a local breach reveals low rubble and localized dust.
Repeated hits reuse fracture geometry, materials and particle resources. Only
the most recently struck panel's health label is shown, avoiding overlapping
readouts during wide swings. Player controls, army counts and damage are retained.

Fresh checks pass 80 headless and 81 painterly desktop breach assertions, including
actual player movement through a destroyed panel, real pipe/bullet contacts,
neighbor collision, persistence, restart, reinforcements and victory. Related
regressions pass: wall visuals 36, old camps 18, valley 1,206, core balance 184,
native candidate ordering 207, bounded combat 15, Sonic 58, map documents 35 and
native castle routing 33. Toolkit unit tests (65) and asset preservation pass.
Earlier attempts during unrelated Warcraft edits had missing-resource compile
errors and are not counted; the `*-verified.log` runs have no script errors.
The headless dummy renderer does not return MultiMesh transforms, so rubble
height is checked in the desktop fixture. Walking advances on physics ticks.

One hundred hits retained the same node count and fracture/material/chip
resources. The final desktop fixture averaged 16.65 microseconds per hit,
maximum 311; opening one panel took 2.820 ms synchronously. Healthy/damaged
90-frame samples averaged 16.093/16.149 ms, p95 20.778/17.068 ms, maximum
112.362/19.037 ms, with 336/345 draw calls. Other project regression work ran
concurrently: these are diagnostics, not a controlled speed comparison or
full-battle smoothness result. Existing scene-shutdown resource/RID warnings
remain. No long-session or full-run balance claim is made, and no app was exported.

Verify through Play Goemon: start a wave, damage one panel and watch its own
health and cracks, break it, then walk or shoot through the gap. Adjacent walls
must remain solid. Attack the keep to stop that camp's reinforcements. Change
the two health settings and start a new run to verify the chosen balance.
Evidence is under `build/Other Files/Asset Toolkit/Wind Meadow/Castle Breaches/`.
The earlier shared-health results below are historical, not validation of this
follow-up implementation.

## Enemy castle cracking and ruins — 2026-10-25 (before independent panels)

The user requested wall health, stronger cracks and destroyed-castle assets.
Castles already had 600 shared HP and physical melee/projectile contacts, but
their prepared wall-fracture nodes never received that health. The smallest fix
connects those nodes to the existing objective and fades impact feedback only
while active. Enemy forts use denser, wider fractures in four stages; ordinary
player walls retain their previous settings. A readable WALLS HP label follows
the struck face. Shared positional wall audio supplies the stone cracking.

Four editable ruin assets reuse the saved wall, gate, tower, barracks and stone
block masters and their painted atlas. The originals were verified unchanged.
Four static batches per castle are prepared at setup and revealed on defeat;
two fixed-size emitters reuse stone chips and soft radial dust. Hits do not load
assets, rebuild scenes or allocate new castle meshes/materials. Cosmetic rubble
adds no physics bodies. The original model still removes collision/navigation,
stops that camp's reinforcements and decides victory. Counts and combat stats
were not reduced. This is visual feedback work, not a measured CPU bottleneck fix.

Fresh final checks: 45 headless and 45 painterly desktop castle assertions,
36 wall visuals, 18 old-camp gameplay, 830 valley, 65 toolkit unit, 12,812 imported
asset, 98 Musashi outfit, 13 Musashi motion and 86 structure assertions passed.
Asset audit and preservation passed. One hundred hits retained the same castle
node count and fracture/material/chip resources. Synchronous hit handling
averaged 28.26 microseconds, maximum 385; destruction took 1.248 ms in the desktop
fixture. These are local calls, not whole-frame or long-session measurements.

The short fixed-camera samples recorded healthy/damaged mean frame intervals
16.351/16.329 ms and p95 17.148/17.100 ms, with 357/369 draw calls. Other
headless regression work overlapped this run, so these are diagnostic samples,
not a controlled speed comparison or full-army smoothness certification.
Existing fixture shutdown RID/resource warnings remain. No app was exported.

Verify through Play Goemon: start a wave, hit an enemy fort from outside, and
watch the nearby HP readout and spreading fractures. Continue until the fort
becomes rubble, walk through its former wall and confirm reinforcements stop.
Keep edits in the prepared resources and existing objective; do not build debris
or load models for each hit. Source/asset guidance is in the Wind Meadow
building `START_HERE.md`. Evidence and six inspected desktop captures are under
`build/Other Files/Asset Toolkit/Wind Meadow/Castle Damage/`.

## Recovered Warcraft playable heroes — 2026-10-25

Blademaster (31) and Demon Hunter (32) reuse Hero movement/health/progression,
CharacterCombat selection and focus cancellation, native local AttackChain
queries, SoundLibrary's prepared originals and the shared projectile lease pool.
Their original Blender rigs and all 36 body clips remain intact. Demon Hunter's
opacity and prepared particle tracks are exported at 30 Hz; models/materials are
created at selection, never reconstructed by attacks. Twelve prepared demon bolts
reset age, velocity, damage and attack attribution on every lease. The native
army owner, wave counts, scenery and existing character behavior are retained.

This is character integration, not a measured performance fix. The workbench and
rebuild/check commands are in [recovered-warcraft.md](recovered-warcraft.md).
Original Blender masters and all 121 WAVs have matching source hashes. Lossless
candidates retain every geoset, skin and clip while reducing material resources
from 9 to 6 and 17 to 7. The 9/17-surface budget warnings remain because those
parts have independent form/effect visibility; a warning is not permission to
reduce the artwork. Source and activated import comparisons pass 32,211 checks.

Focused headless checks pass 375 assertions including native soldier contacts,
solid cover, form switching, shared skills, original audio, real death/respawn
and 100 repeated projectile leases, with zero pool misses. The initial desktop
snapshot passed 366 checks with p95 manually timed player/projectile work 0.710 ms
and real-time frame interval p95 17.823 ms. That snapshot predates the corrected
smoke alpha, original impact mapping and expanded lifecycle/cover tests; it is
not a final-source full-battle or speedup result. The final desktop run passed
all 375 checks, with p95 player/projectile work 0.645 ms and real-time frame
interval p95 18.111 ms. Both repeated-special segments had zero resource change
after setup, and the projectile pool had zero misses. These are focused fixture
measurements, not a full-battle benchmark; concurrent project work was not
controlled. The initial wall fixture placed
the enemy's hit box through the wall; the corrected fixture separates shapes.
Existing whole-scene shutdown resource/RID warnings remain. The user's historical
smoothness report remains separate, and no long-session leak claim is made.

Verify with Play Goemon: select each fighter, click through the original attacks,
spin beside native enemies as Blademaster, transform and fire as Demon Hunter,
then reverse form, jump, evade, switch fighters and try a borrowed skill. Keep
new characters on these prepared animation/audio and shared contact/pool paths.
Evidence: `build/Other Files/Asset Toolkit/Warcraft/` plus the two toolkit
comparison folders. No app was exported.

## Warcraft size and attack balance — 2026-10-25

The requested sixfold model size and triple attack speed are defaults in
Character Balance for Blademaster (31) and Demon Hunter (32). Saved overrides
remain independent. Selection and balance edits set the existing model's scale;
the existing shared attack multiplier advances the original animation and
contact clock together. This is balance tuning, not a measured CPU/GPU fix.
No model loading, reconstruction or new pool was added to an attack loop.

Size is visual: collision and Melee reach retain their separate values. Attack
speed applies to ordinary cuts, the critical strike and demon shots; skill
durations, pulses, cooldowns, damage per hit and projectile travel retain their
existing owners. Other fighters keep their current defaults. Original models,
editable masters, animation samples and optimized assets are unchanged.

Fresh desktop launcher checks passed 47 balance/menu assertions and 407 gameplay
assertions, including ten repeated triple-speed contacts per fighter, original
combo order, attack-clock/animation alignment, native victims, cover and both
demon forms. The prepared projectile pool stayed at 52 with zero misses; both
repeated attack/special segments added zero resources. Focused rendered interval
p95/max was 17.950/33.982 ms, with manually stepped player/projectile work
p95/max 0.828/2.922 ms. These are fixture measurements, not a controlled speedup
or full-battle smoothness claim. Existing teardown resource warnings remain.
Earlier repeat attempts exposed fixture target-list cleanup and live camera
steering; their logs remain diagnostic, not accepted gameplay results.
Preservation, 65 toolkit unit tests, 12,812 imported asset checks, 98 Musashi
outfit checks, 13 motion checks and 86 structure checks passed.

Verify through Play Goemon: open Settings → Character Balance, select either
fighter and check Model size × = 6 and Attack speed × = 3. Change each control,
reselect the fighter and use Reset to restore these defaults. Repeat cuts,
transform and fire, then switch fighters to check isolation. Current evidence
is in `build/Other Files/Asset Toolkit/Warcraft/Balance/`; earlier Warcraft
timings above remain historical. No app export or full-battle soak was requested.

## Summoned dragon concept applied — 2026-10-25

The user approved the Red-Eyes-inspired concept in
`assets/references/dragoon_summon/approved-concept.png` and requested the live
summoned model match it. The existing procedural dragon bake now has a
forward-reaching head, open jaw, red eyes, overlapping black neck/chest armor,
tucked claws, curved wings and a balancing tail. It retains one shared mesh
surface and no textures: 7,794 vertices / 5,744 triangles, versus the previous
3,434 / 6,056. More vertices represent separate flat armor/membrane normals;
fewer triangles alone do not establish a speedup.

This is an art correction, not a measured CPU bottleneck. Geometry is prepared
once, and the existing player cache and native army batch still own presentation.
The shader flaps wings about their shoulders with matching normals; its culling
bounds include the displaced poses. Dissolve grain no longer punches small holes
in the tail before expiry. Travel, targeting, exact contacts, damage, three-second
lifetime, landing waves, character animation and attachment transforms are kept.
No new simulation, skeleton, per-cast asset load or pose-atlas rebuild is required.

Fresh rendered desktop-launcher checks passed 46 assertions, including ten reused
player casts and three cycles of eight native dragons. All 567 measured frames
had foreground focus; resources stayed at 1,133 and presentation nodes at 115.
Frame median/p95/p99/max were 16.670/18.686/31.035/70.801 ms. Native-step
median/p95/max were 0.276/0.586/1.264 ms. This short stationary-target fixture
does not certify full-world smoothness or long-session stability. The pre-edit
run passed 42 assertions but had only 34/567 focused frames, making its timing
diagnostic rather than a valid controlled before/after comparison. The user's
historical smooth-gameplay report remains separate. Existing fixture shutdown
resource/RID warnings remain; stable in-run counts do not certify leak freedom.

Related headless tests passed: native Dragoon 36, army effects 13, effect lifecycle
7, lance sweep 25, landing audio 31 and packed projectile buffers 2,184. Asset
preservation, 65 toolkit unit tests, 12,812 imports, 98 outfit, 13 Musashi motion
and 86 structure assertions passed. The hunt fixture additionally checks finite
mesh data, wing markers, geometry budget and bounds at both flap extremes.
Front/side/back/three-quarter and gameplay views were inspected.

Verify with Play Goemon: select Dragoon, use Dragon Leap, and inspect the diving
and hunting dragon while moving the camera. Recruit allied Dragoons and repeat.
Keep future art changes in the prepared generator/shader, and compare the same
scene before/after in the foreground before making a performance claim. Edit
instructions are in `docs/dragoon-motion-workbench/dragon-hunt.txt`; evidence is
in `build/Other Files/Asset Toolkit/Dragoon Redesign/`. No app was exported.

## Mercenaries recruit at the castle — 2026-10-25

During preparation, M opens five clickable cards: 1 Ninja, 2 Dragoon, 3 Ranger,
4 Explorer and 5 Knight. A click or fresh key press purchases one ally directly
on clear ground near the shrine; it no longer requests a placement click.
Prices, two-food accounting, health, native kits and combat markers are retained.
The existing placement checks reject buildings, obstacles, occupied posts and
unexplored terrain before payment. A blocked base spends nothing. Idle facades
are reused after death with a fresh native handle. Cards fit an 800-pixel window;
feedback moves below the character HUD when the top row has insufficient space.

This fixes input/behavior, not a measured CPU bottleneck. Native defenders now
query the existing local enemy grid around their 18-metre guard area, refine
actual body contacts, and return to their post when no target remains inside.
They retain their shared attack, projectile, shelter and pooled presentation
systems. Recruitment searches only when requested, not every combat frame.
Player spell/weapon digits outside the mercenary menu keep their existing role.

Fresh checks passed 86 hiring assertions headlessly on the original map and
86 through the painterly desktop launcher on Wind Meadow, after earlier
82-assertion desktop passes on both maps. These cover all five real card clicks,
all keys, held-key suppression, prices/food, blocked ground, death/reuse, native
waiting, attacking and returning. Menu shortcuts passed 45, hiring parity 31,
Knight 33, bunker 27, soldiers 58 and native nearest/guard queries 2,418 checks.
Asset preservation passed; no authored asset, animation bake or export changed.

A separate 20-second normal-stat Metal battle maintained 240 enemies/96 allies,
delivered 2,231 damage events with no gaps, and reinforced all 236 deaths.
It recorded 63.02 FPS and frame p95/p99/max 20.057/28.496/67.436 ms, with native
work averaging 0.784 ms. However, foreground focus was only 73.9%, so its
performance acceptance failed. This is diagnostic evidence, not a validated
smoothness result or a before/after speedup. Existing fixture shutdown resource
warnings remain; no long-session soak or app export was performed.

Verify through Play Goemon: open M, click Knight or press 5, then recruit each
other type. Each should appear at the base immediately. Start a wave and let
enemies approach; defenders should fight locally and return when clear.
Evidence is under `build/Other Files/Mercenary Base Hiring/`. The first hiring
fixture's empty-victim error is retained separately; its target had been killed
by the original Ninja execution behavior, and the final fixture handles death.

## Explorer light cutting sound — 2026-10-25

The user reported Explorer's missing cutting sound and requested Musashi's light
attack sound, like Knight's contact feedback. Explorer already resolved confirmed
contacts to the shared Musashi sword-hit/Fusion-finisher samples, but his blade
swings still selected the older mixed slash recordings. SoundLibrary now assigns
the recovered `fusion_swing.wav` to Explorer's blade and paired primary/secondary
weapon slots. Knight and the other fighters retain their own swing choices and
existing contact sounds. Saved recordings, gain and mute retain priority.

This is a requested audio routing change, not a measured frame-time bottleneck.
One prepared sample plays through the existing bounded voices; combat timing,
damage, movement, models and native army ownership are unchanged. Fresh tests
passed 381 headless and 392 painterly desktop-launcher assertions: nine actual
Explorer cuts with confirmed light/heavy contact audio, all ten older Rogue
classes damaging a native victim with sound, both shared playback routes,
recording/gain/mute and 200 repeated cuts without node/resource growth. The new
Musashi swing assertions failed before the change. Five desktop SFX captures
are non-silent with zero clipped samples. These checks do not establish subjective
loudness, full-battle performance or long-session leak freedom. Existing fixture
shutdown RID/resource warnings remain.

Asset preservation, 65 toolkit unit tests, 12,812 imported checks, 98 outfit,
25 Musashi motion and 86 structure assertions passed. Evidence and recordings:
`build/Other Files/Asset Toolkit/Explorer Cut Audio/`. Verify through Play Goemon:
select Explorer, click three consecutive light attacks and strike an enemy;
compare contact feedback with Knight. Keep future sample substitutions in the
prepared sound map, without adding audio players or loading files on each hit.
No app was exported.

## Reachable targets and the main castle — 2026-10-25

The user reported enemies getting stuck near trees and requested a main-castle
assault. Native targeting now certifies a reachable destination before accepting
a target. Buildings use clear standing points around their perimeter rather than
asking movement to enter their solid footprint. The shrine has assault priority;
a reachable gate becomes the breach target while the shrine is sealed off.
Reachable taunts, retaliation and defenders within 28 metres retain local combat.
After a breach, troops select the shrine. Skullpion keeps its specialized climbing
and attack patterns in the same native owner.

The existing terrain grid shares connected-region labels for reachability,
avoiding a separate flow for every candidate. Waypoints also certify their final
connection to the destination. A continuously walking troop reuses its successful
building approach; navigation revisions, explicit pose changes, target changes
and changed building bounds prevent stale reuse. Enemies with no reachable target
retry on their existing 0.1-second decision clock. Ranged units already able to
shoot, including elevated gunners, keep valid contacts. No scenery, army count,
combat stat, attack marker or player control was reduced. No second simulation,
renderer or per-enemy script was added.

Fresh final-source checks passed 15 native suites, including 18 targeting cases,
5,596 waypoint/cache comparisons, trunk detours at 20/30/60 Hz, body-width limits,
gate formations, lifecycle, bosses and specialized movement. The desktop castle
fixture passed 33 checks: sword, gun and spear troops from all four real bases
damaged the gate, then all twelve damaged the shrine after a breach. The final
headless soldier regression passed 58 checks. Instance buffers, defender
retention, bunkers, Skullpion departures, valley checks, 65 toolkit unit tests,
12,812 imports, Musashi outfits, structures and asset preservation also passed.
Initial elevated-gunner and fixture stale-gate assertion failures remain separate
diagnostics; active attacks can retain the old gate identity until they finish.

The final foreground Metal battle maintained 240 enemies and 96 allies for
30 seconds, passing all acceptance gates, with 9,165 damage events, no dropped
hits and 889 death replacements. FPS averaged 59.93; frame interval p95/p99/max
was 20.271/23.557/50.363 ms. Focus was 100% and tracked inputs stayed unchanged.
Native work averaged 1.538 ms: 1.161 ms in decisions and 0.224 ms in movement.
These are current acceptance measurements, not a controlled speedup or a claim
that every frame stays within 16.7 ms. Preliminary native timings overlapped other
work and are diagnostic only. Fixture shutdown resource/RID warnings remain;
no long-session leak certification or app export was made.

Verify with Play Goemon: start an assault, watch troops detour around trunks and
converge on a reachable castle gate, then breach it and watch them enter toward
the shrine. Keep body clearance and final path connections when changing
navigation; a nearby target is not necessarily accessible. Run
`tests/forest-shrine/enemy_castle_pathing_test.gd` for the real-map check.
Logs, route traces and the final battle report/capture are under
`build/Other Files/Pathing Investigation/`, with accepted timing in `Final Battle/`.

## Shared kill reward audio — 2026-10-25

The user still heard the prototype sound when other characters killed enemies
with special attacks. The earlier Skullpion change only replaced his `spark`
cue. Native player-attributed kills call Hero.award_kill; a level gain emits
`spark`, so this reward overlaps the character's own special attack sound.
SoundLibrary's shared `spark` default now reuses the same recovered Skullpion
`core_recover.wav`. This also replaces the shared pickup/energy default;
character originals, authored silence, saved takes, gain and mute keep priority.
No death scream, damage, level threshold or special-attack event was changed.

The smallest fix is one shared default using an existing prepared resource and
voice pool. Fresh checks passed 40 headless and 41 painterly desktop assertions:
all 30 IDs resolve recovered audio or their authored silence, five characters'
native kills carrying special-projectile tickets award a level with the recovered
cue, repeated rewards keep node counts stable, and Studio controls still work.
The separate character recording regression passed 40 checks; asset preservation
passed. Logs are `build/Other Files/Asset Toolkit/shared-kill-audio-*.log`, with a
non-silent mixer capture under `Kill Reward Audio/`. These checks cover shared
kill delivery, not every skill's complete animation/projectile sequence or a
full-battle performance measurement. Existing fixture shutdown resource/RID
warnings remain. No app was exported.

Verify through Play Goemon: use special attacks as Ninja, Dragoon or Musashi and
listen when kills raise a level. Future reward changes belong in the shared
default; changing one character's map leaves the same prototype cue elsewhere.

## Skullpion playable audio — 2026-10-25

The user disliked the prototype jump and killing sounds. Playable Skullpion now
reuses his recovered `tail_sweep` for jump takeoff and `core_recover` for kill-earned
levels. These are deliberate effect reuse, not newly proven retail jump/reward
triggers. The user clarified that killing means Skullpion killing other enemies;
his hurt/death defaults are preserved. This initial change kept other fighters'
defaults; the shared reward correction above supersedes that scope. Shared
prototype files and user recordings remain preserved. His existing recovered
landings and native boss cues are unchanged.

SoundLibrary prepares the samples on selection through the existing audio cache
and plays them through the existing voice pool at source pitch. No new audio
pool, simulation or combat-time loading was added. Fresh painterly desktop
launcher checks passed all 12 assertions after the scope clarification, covering
actual Space input, a kill-earned level, preserved
hurt/death defaults, Studio preview/gain/mute/recording priority and 200 repeated
cues with unchanged node/cache counts. A non-silent SFX mixer capture
is under `build/Other Files/Asset Toolkit/Skullpion/Playable Audio/`; logs are
`build/Other Files/Asset Toolkit/skullpion-audio-*.log`. Whole-scene shutdown
resource/RID warnings remain. This is an audio choice correction, not a measured
frame-time improvement or long-session result. No app was exported.
Asset preservation passed. The broader native boss regression passed 71 of 72
checks; its warning-point dispatch assertion failed before the audio assertions.
That native targeting/event issue remains outside this sound substitution.

Verify through Play Goemon: choose Skullpion, tap Space, defeat enough enemies
to level up, then take damage. Keep future cue changes in the existing prepared
audio map instead of loading samples in movement or damage loops.

## Character jump height and AI enemy balance — 2026-10-25

This is a requested tuning interface, not a measured performance fix. Settings →
Character Balance exposes Jump height × for all 30 stable playable IDs, including
fighters hidden from selection menus. 1× preserves current movement. Ordinary
launches multiply velocity by the square root of height; Musashi/Kojiro and Sonic
scale their prepared source trajectories vertically, retaining release-to-shorten
and jump counts. Equipped jumps use the wearer's height setting. Skullpion and
DL2 retain their original leap gravity and now scale their jump/stomp launches.
Ben/DL3 flight and other attack travel retain their existing controls. Legacy
launch-speed settings remain saved; source-authored jumps still own their source
launch speed. Native Dragoon's existing prepared jump value uses the same height.

Settings → Enemy Balance uses the existing balance screen layout for all ten AI
roles: base HP, base attack damage and movement speed, with existing shared enemy
multipliers beside them. Wave counts remain in Core Game Balance, which links to
the new screen. Player and AI profiles save separately, while recovered assets,
attack kits and native army simulation remain shared. Editing playable Vambee
must not change hostile Vambee, and the reverse must also hold. Legacy Skullpion
health/speed preferences remain its baseline when no individual override exists.
Reset clears only the selected AI override. Shared health × continues to exclude
Skullpion; shared speed/damage × retain their existing scope.

AI edits apply on the next wave (or a new run). That boundary copies profiles
into the private run snapshot and invalidates the existing wave-stat cache once;
native kit refresh consumes those cached stats. There is no new per-unit scan,
renderer, controller, resource load or combat-time allocation path.

Fresh focused checks passed 122 assertions through the painterly desktop
launcher; the expanded headless check passed 172, including native Dragoon
height and twelve AI soldiers repeating two attack cycles with all 48 edited-
damage contacts delivered once. They cover character/enemy menu entries, save/
reload, malformed values, reset isolation, next-wave snapshots, native profile
payloads and spawned HP. Ten actual jump comparisons cover ordinary/Rogue,
Musashi, Sonic, both leaping bosses, Kojiro and equipped styles. At 2×, measured
apices were about twice their original heights. Both menu captures were inspected.
Asset preservation, 65 toolkit unit tests, 12,812 imports, 98 outfit checks,
13 Musashi motion checks, 86 structure checks and 10 balance hot-path checks passed.
The existing character/core balance regressions passed 32/184 checks, native
soldier combat passed 58, and full jump-style regression passed all 636 checks
at default 1×. The initial character fixture failed three stale assumptions
(old Goemon damage bonuses and a nondeterministic spawn); its diagnostic log
remains separate from the accepted deterministic regression.
These are correctness checks, not a new full-battle or long-session measurement.
Whole-scene fixture shutdown RID/resource warnings remain in the logs.

Verify with Play Goemon: choose a fighter in Character Balance, set Jump height
to 2× and jump, then reset. Try Musashi/Sonic with short and held presses and an
equipped jump. In Enemy Balance change one type's HP/damage/speed, start the next
wave and verify only that AI type changes. Keep per-type tuning at the existing
wave/native-kit boundary; do not couple it to the playable character profile.
Evidence: `build/Other Files/Character and Enemy Balance/`. No app was exported.

## Dark Lumina 3 piercing click sequence — 2026-10-25

LMB now releases one Kojiro **Wind** ground wave, then the two existing opposing
energy blades, one click per release. The first shot reuses Kojiro's prepared
wind mesh, shader, growth, dust, fitted scale, forward muzzle, travel speed and
three-second lifetime. It retains Lumina's release timing, damage and sound.
The blades retain their existing timing, size, damage, speed and lifetime.
Each shot can hit multiple enemies once each and still stops at solid cover.
The native NPC and borrowed Sword timelines retain their previous behavior.

This is a requested behavior change, not a measured performance fix. The blades
use the existing native local candidates and precise contacts, with per-lease
victim history reset by the shared projectile pool. Wind and dust are prepared
at selection; no donor character, new renderer or combat-time asset load is
needed. Twelve wind and 128 dust leases bring a DL3-only prepared pool to 564.

Fresh desktop-launcher checks passed 70 control assertions and 72 piercing
assertions, covering actual clicks, three native victims, 20/30/60 Hz and a long
step, repeated overlap, duplicate suppression, walls, expiry and lease reset.
Both runs had zero pool misses or growth; the contact fixture also selects
Kojiro as a scale reference, so its initial pool is 738. The corrected Wind and
blade captures were inspected. These focused checks do not establish full-army
frame time or long-session stability. Existing fixture shutdown RID/resource
warnings remain. Earlier phoenix-wave trial logs are diagnostics, not the final
Wind acceptance. Evidence: `build/Other Files/Asset Toolkit/Dark Lumina 3/Controls/kojiro-wind-desktop.log`,
`Dark Lumina 3/piercing-wind-desktop.log` and `Dark Lumina 3/Piercing Combo/`.

Verify with Play Goemon: select Dark Lumina 3 and click through Wind wave,
blade, blade into a row of enemies. Each should keep moving through the group;
a wall should still stop it. No app was exported.

## Dark Lumina 2 fire scatter and square artifact — 2026-10-24

The reported rectangle was visible patterned scenery in the recovered `ember.png`
atlas, not a newly measured performance bottleneck. Its original pixels remain
preserved for research. The prepared charge material now reuses the intact round
fire animation and its square aspect ratio, and the existing effect batch places
it at the mouth using the caster's yaw. This is a visual substitution pending
correct recovery of the original ember VRAM page. No new effect nodes, material
creation during attacks, texture upload, simulation or pool was added.

The shared fire spread rises from ±320 to ±400 source angle units (±35.15625°),
25% wider for player, borrowed and native casts. Existing homing derives its turn
rate from this same value. Twelve shots, damage, speed, lifetime, contact rules,
attack timing and sounds retain their existing settings.

Fresh desktop launcher validation passed 145 checks: all sixteen charge frames
have transparent silhouettes, both facing offsets are correct, three player
casts and one borrowed cast emit all twelve shots, a direct hit lands once, and
twelve native bosses emit all 72 pairs with matching wider directions. The
projectile pool stayed at 76 with zero misses; post-cast resource counts were
1737/1737/1737, and prepared presentation nodes stayed fixed. Charge and outward
fire captures were inspected. The initial resource assertion included first-use
setup and failed; its diagnostic report remains separate from the accepted run.

Native tests passed at 20/30/60 Hz. Fresh checks also passed 65 toolkit unit tests,
12,812 imports, 25 DL2 checks / 23,275 source poses, 98 Musashi outfit checks,
13 motion checks, 86 structure checks and asset preservation. These focused
checks do not establish full-battle FPS or long-session leak freedom. Existing
fixture shutdown resource/RID warnings remain. No authored asset or app export
was changed. Evidence is under `build/Other Files/Asset Toolkit/Dark Lumina 2/Fire Breath/`.

Verify with Play Goemon: select Dark Lumina 2, cast Paired Fireballs, and watch
the round glow at the mouth followed by the wider outward fan. Repeat and try
the same skill on another fighter. Reuse prepared intact sprites when an atlas
contains unrelated pixels; do not try to hide a bad recovery with more glow.

## First Wind burst and other first-cast work — 2026-10-24

The user requested another pass without reducing effects or shots. A deeper
trace exposed a diagnostic error: the earlier manual fixture stepped native
combat without dispatching its events each step. Its first push drained that
backlog. The fixture now dispatches normally. Earlier first-burst numbers below
remain historical, not a clean estimate of normal-game event delivery.

The corrected fixture still found expensive repeated projectile work. Candidate
discovery now projects the existing native grid result directly into the
caller's current source ordering. It retains no query/order cache and checks
proxy lifetime. Rigid sweeps reuse existing transforms and the same box/contact
math; other shapes retain the original compound solver. All 10,368 comparisons
across nine rigid kinds, three sizes, four yaws and four radii matched hit times
and points exactly. 207 candidate checks cover arbitrary order, same-frame
movement, retirement, reused generations, freed objects and malformed input.

The shared projectile pool validates its next idle lease instead of rescanning
all idle objects for every shot; exhaustion counts only surviving nodes.
Wind rejects out-of-cone points before cover rays. Reused finale shots retain
unchanged mesh assignments. Only ground fire scans/stops its owned sustain on
retirement; transient impacts retain their original lifetimes. No emission
marker, fan lane, aimed-victim ledger, collision radius, damage, travel, cooldown,
sound playback or animation was reduced.

The existing six-frame hidden graphics warmup now submits the actual prepared
DL2/DL3 effect meshes/materials, which were missing. The shared SoundLibrary
cache prepares selected fighters' and initialized borrowed skills' original
cues/profiles, and the existing eight paired voices are created at audio setup.
Recordings, gain, mute, pitch, weighting and Studio selection remain unchanged.
Preparation preserves gameplay RNG; repeated cue resolution creates no audio
resources. This adds no simulation, renderer or effect pool.

In the corrected 240-target high-HP desktop fixture, the first release's
projectile CPU cost fell from 37.786 to 17.797 ms and its frame interval from
77.766 to 49.148 ms. Repeated projectile p95 fell from 4.057 to 1.779 ms.
These focused manual-fixture results still exceed a 16.7 ms budget at the
densest release. Whole-run logs retain unrelated startup/idle intervals over
250 ms; do not call 49 ms the whole-run maximum. Metal GPU timestamps were
unavailable, so no GPU-cost attribution is made.

Ten other skills were cast twice against 240 targets through the launcher:
DL3 Water/Fire/Sky, DL2 fireballs, Kojiro homing/Wind, Sasuke Hail, Yae lock-on,
Ben bombs and Ed fireballs. All 30 checks passed with no pool growth or misses.
After audio preparation, Sasuke's largest release step was 7.614 ms (previously
13.394) and Yae's 3.349 ms (previously 7.796). These are player/projectile CPU
samples, not whole-world FPS. Other differences were mixed; no universal speedup
is claimed. Transient whole-scene resource deltas remain in the reports and are
not called leaks or zero-growth certification.

The final normal-stat 45-second Wind Meadow battle maintained 240 enemies and
96 allies throughout, with 10 Wind casts / 910 Wind shots, no pool misses,
19,411 damage events, no dropped hits and all 1,761 deaths reinforced. Focus
was 100% and tracked inputs stayed unchanged. All benchmark gates passed.
Whole-battle p95/p99/max intervals were 18.436/25.057/65.496 ms; casting frames
were 18.931/26.681/65.493 ms. The first 3.52-second window peaked at 37.948 ms.
This is a normal-world check, not proof that every dense cast stays at 60 FPS
or a long-session leak certification. The earlier pre-audio battle's separate
180.568 ms maximum remains in `Battle/`; use `Final Battle/` for the final run.

Fresh correctness checks passed: 32 desktop Wind checks, 43 rendered graphics
warmup checks, 10 pool-lifecycle checks, six audio-preparation checks, 3,074
shared-spell checks, 430 weapon-query checks, 103 packed-sync checks, eight
nearest-contact and eight event-delivery checks, 16 paired-Studio and 40 shared
audio checks, Kojiro gameplay/piercing 395/45, and Sasuke/Yae gameplay 10/13.
Asset preservation, 65 toolkit unit tests, 12,812 import checks, 98 outfit,
13 Musashi motion and 86 structure checks passed. Native smoke/numeric checks
also passed. Existing fixture shutdown RID/resource warnings remain.
Fresh DL3 imported poses/effects and the native six-move suite at 20/30/60 Hz
passed too. Its six-boss / 96-victim Wind stress repeated three times, reached
598 simultaneous projectiles and completed with a 0.196 ms maximum native
step. This is simulation evidence, not a rendered smoothness measurement.
An extra six-boss desktop fixture was lock-rejected while a regular game was
open and is not counted as passed. A later speculative instance-buffer
preallocation trial did not improve the first release and was reverted;
`buffer-prepared.log` is diagnostic evidence, not the accepted final change.
The initial event-delivery fixture lacked the current unit-kind field/adapter;
it was corrected without changing its assertions. The weapon-query fixture's
retired role-2 asset was replaced with the current Skullpion role, retaining
144 targets and both rigid/compound geometry. Failed diagnostic logs remain.

Verify in Play Goemon: select DL3 and cast Wind into a group before any warm-up
casts, then repeat. Check both wings, all four fan lanes and aimed shots at
newly pushed victims. Try the other skills after switching fighters or equipping
them on another body. Keep setup at selection/initialization, retain exact hit
math and lifetime checks, and measure first use before adding pools.
Evidence and checkpoints are under
`build/Other Files/Asset Toolkit/Dark Lumina 3/Wind Burst/`. Concurrent effects
restoration and cooldown-menu work were preserved and are outside this fix.
No authored assets were edited and no app export was requested.

## Optional player cooldown bypass — 2026-10-24

Settings → No Character Cooldowns is a saved, default-off preference for the
human-controlled fighter. Existing character controllers clear their own cooldown
clocks before player input and physics; equipped and retired spell cooldowns use
the same loadout. Active attacks, charge preparation, contacts, buffs and travel
keep their existing duration. Chief's sword retains its active swing until contact
finishes, so clearing its cooldown cannot restart it before a hit. AI characters
and the native army retain their ordinary clocks. No new simulation, search,
asset loading or effect pool was added. This is a requested behavior change,
not a measured performance bottleneck or speed improvement.

Fresh checks passed: 60 headless and 63 desktop-launcher assertions covering all
30 fighters, saved preferences, normal/disabled clocks, AI isolation, real dodge
and Rogue input, Edo shield duration, borrowed/retired skills, three repeated lion
casts and Chief sword continuation. The lions reused their two prepared leases.
The Settings and charge/release captures were inspected. Numbered controls passed
545 assertions, shared spells 3,074 and Chief gameplay 29; asset preservation,
63 toolkit unit tests, 12,812 import checks,
98 Musashi outfit checks, 13 motion checks and 86 structure checks also passed.
Existing fixture shutdown RID/resource diagnostics remain. These are focused
correctness and rendered checks, not a full-battle or long-session stress test.
Unlimited casting can increase simultaneous effects; measure that workload before
changing pool capacities or claiming it stays smooth. Evidence is under
`build/Other Files/Character Cooldowns/`.

Verify through Play Goemon: open Settings, enable No Character Cooldowns, resume,
cast a skill, then cast again once its move finishes. Switch fighter or equip a
borrowed skill and repeat. Turn it off to restore normal waits; the preference
survives restarting the game. No app export was made.

## Dark Lumina 3 Wind query hitches — 2026-10-24

The user reported lag specifically from the green Wind wings. A fresh desktop
launcher fixture reproduced it with 240 native troops: the first Wind phase
peaked at 81.117 ms of player-projectile CPU work and a 121.356 ms frame.
Repeated casts peaked at 84.800 ms of projectile work. The pool stayed at 424
prepared leases with no misses or resource growth. Per-query instrumentation
found repeated candidate sorting taking about 2 ms for 50–60 candidates,
plus exact contacts. Many simultaneous shots multiply these small costs.

The smallest fix keeps the existing shared query and exact contacts. Local
candidate sorting now resolves each source index once, instead of searching
the full enemy array in every sort comparison. Nearest-contact searches stop
after a visible contact at t=0, since nothing later can be closer and source
order already owns ties. Cover and prior-hit exclusions still run first.
No Wind count, damage, size, push, speed, timing, sound or scenery was changed.

With both fixes, the same first phase peaked at 33.164 ms of projectile work
and a 76.833 ms frame; the repeated phase peaked at 23.521 ms and a 28.715 ms
frame. First-phase projectile p95 was 2.438 ms before / 2.542 ms after, while
repeat p95 was 6.130 / 4.336 ms: this primarily reduces burst spikes, rather
than proving a general FPS increase. First and repeated phases emitted the
same 346 and 300 shots across their two casts, with no misses or resource
growth. Both first phases and the final repeat were focused for all 540 frames;
the original repeat had 30 unfocused frames. The final idle phase lost focus
for 146 frames and is not an accepted idle comparison. Metal returned zero
for GPU timestamp measurements, so those fields do not establish GPU cost.

This diagnostic uses high-HP targets and manual simulation to preserve a
repeatable crowded workload. It is not a normal-stat full-world battle or a
long-session leak test. The first mass release still hitches; its controller
work peaked at 20.733 ms and the remaining projectile peak is also visible.
Do not claim the spell is hitch-free. A future investigation should measure
the initial aimed-shot burst before changing visual quality or shot counts.

Fresh checks passed: eight nearest-contact cases (overlap ties, excluded hits,
closer later hits, cover and stationary contacts), 430 native weapon-query
checks, 3,074 shared-spell checks, and 24 headless / 32 desktop Wind checks.
The desktop check retained both mirrored wings, pushed-target hits and three
repeated casts among 51 native targets; its pool stayed at 424 with zero misses.
These correctness checks are separate from the controlled timing comparison.
Asset preservation, 63 toolkit unit tests, 12,812 imported-asset checks,
98 Musashi outfit checks, 13 player-motion checks, 86 structure checks and
110 native box-filter checks also passed. The rendered wing captures were
inspected; no authored asset or native library was rebuilt for this fix.

Verify through Play Goemon: select Dark Lumina 3 and cast Wind into a crowded
group repeatedly. Keep both green wings, the four-way barrage and the aimed
shots at pushed victims. Reproduce the diagnostic with
`--script res://tests/forest-shrine/dark_lumina_3_wind_profile.gd -- --label=review`.
Evidence and source checkpoints are under
`build/Other Files/Asset Toolkit/Dark Lumina 3/Wind Lag/`. Concurrent sword-input
work changed the combo adapter during this investigation; its Wind path was
unchanged and those input changes are outside this performance fix. No app
export was requested or performed. Existing fixture shutdown RID/resource
warnings remain separate from the bounded live pool measurements.

## Kojiro's piercing homing birds — 2026-10-24

The user requested that the three birds pass through multiple enemies. Their
first contact previously retired the projectile. The smallest change removes
that retirement and clears the homing target when it is hit, letting the bird
continue along its current heading. Existing per-bird hit history prevents
repeat hits on the same victim. Walls, three-second lifetime, damage, speed,
spread, size, timing and audio retain their existing settings. Player and
borrowed casts share this path; Kojiro is not a native NPC army kit.

This is a behavior change, with no measured performance bottleneck. It reuses
native local candidate queries, precise contacts and prepared impact sparks;
there is no added target search, asset loading or new pool. More enemies hit
can produce more existing contact effects, so repeat the actual crowded
workload before making claims about army frame time or increasing capacity.

Fresh focused tests reproduced 28 failures before the change and passed all
45 checks afterward. The final desktop-launcher Metal run also passed all 45,
with all 112 rendered frames focused, zero pool misses and no node/resource
growth. It checks three overlapping birds against three native enemies in a
row at 20/30/60 Hz and a long step, duplicate suppression, wall obstruction,
lease reset and lifetime. Three-bird manual CPU-step p95 was 0.645 ms in this
small fixture; this is not total frame time or a full-army benchmark. The
existing Kojiro gameplay suite passed 395 headless checks, including borrowed
skills, release counts, steering and repeated casts. Asset preservation,
63 toolkit unit tests, 12,812 import checks, 98 outfit checks and 86 structure
checks passed. Existing whole-scene shutdown resource/RID warnings remain.

Verify with Play Goemon: select Kojiro and cast Homing Shots through a row of
enemies. Each bird should continue after contact, damage each enemy once, and
stop at a wall or expire. Evidence and captures are under
`build/Other Files/Asset Toolkit/Kojiro/Piercing/`. No app export or long-session
stress run was performed.

## Dark Lumina 3 default energy attack — 2026-10-24

The former RMB energy sequence is now the default LMB attack: ground wave,
then two opposing flying cuts, one click per release with one buffered
continuation. RMB has no attack action. The separate plain-cut mode is removed;
the default/automatic attack entry uses the energy sequence too. Existing
source sections, release markers, damage, timing, cover checks and prepared
projectiles are reused. Native enemies and the borrowed Sword skill retain
their existing behavior. The HUD and roster hints describe the new binding;
the generic enemy hint no longer overwrites DL3's specific attack tooltip.

Fresh desktop-launcher Metal verification passed all 70 control checks,
including real LMB/RMB events, three releases, retained 975 projectile damage,
melee contact, buffering, spell interruption, evade and repeated Fire reuse.
The pool stayed at 424 with zero misses. The fixture now allows eight seconds
for the last falling flames and their lingering ground fire to expire; the old
six-second cleanup wait could end too early. Its direct melee assertion uses a
fixed target aim; the mouse-binding assertions still use actual input events.
Earlier diagnostic runs failed these fixture assumptions and the tooltip check;
they are retained separately and are not acceptance results.

Asset preservation, 63 toolkit unit tests, 12,812 imported-asset checks,
98 Musashi outfit checks and 86 structure checks passed. Energy-cut captures
were inspected. These are focused correctness/render checks, not a new
performance bottleneck finding, full-army benchmark or long-session leak claim.
Existing fixture shutdown resource/RID warnings remain. Verify in Play Goemon:
select Dark Lumina 3, click LMB three times for wave/crescent/crescent, and check
that RMB cannot attack, queue another cut or interrupt a numbered spell.
Evidence: `build/Other Files/Asset Toolkit/Dark Lumina 3/Controls/`, especially
`default-attack-desktop-verified.log`. No app was exported.

## Dark Lumina 2 fire/audio and combat buffs — 2026-10-24

A later user request increases DL2's fire again: three times its previous sprite
and collision size, double flight speed, twelve balls per cast, and a 2× source
animation clock. All attack reach doubles, damage rises from 80 to 400, and base
health becomes 5,000 for player and native enemies. Borrowed skills use the same
kit. Explicit saved health overrides and progression remain authoritative.
No body/animation assets or scenery were changed, and full army counts remain.

Missing player walking/fire sounds were competing for the army's eight spatial
voices and global 35 ms gate. Player and borrowed cues now use the existing
foreground sound pools with source character 29, preserving recordings, gains,
mutes and source pitch. The army still uses its bounded shared audio mix.
The current repeated fire workload prepares 36 pooled projectiles on selection;
combat does not load models/materials or add another enemy simulation.

Fresh desktop launcher evidence: 130 gameplay checks, 49 spin checks and 46 stomp
checks passed with all manual frames focused except one stomp frame. The desktop
mixer recorded audible walking and fire. Saturating all army voices and its gate
did not suppress foreground cues; recordings, gains and mutes passed. Repeated
casts emitted twelve shots each with no pool misses or growth. All 21 original
motions rendered. Native tests additionally check release timing at 20/30/60 Hz,
5× damage and extended spin/stomp contacts. The shared audio suite passed 40
checks and 12 source-asset unit tests passed. Asset preservation passed.

The fresh 120-second Metal/Apple M3 stress run kept 240 enemies and 96 allies,
normal stats and per-death reinforcement, with all effects. It averaged 56.04 FPS,
p95 24.12 ms, p99 30.89 ms, maximum 140.53 ms, 132,923 damage events, zero dropped
hits and 3,031 deaths/replacements. Focus stayed at 100%; tracked inputs did not
change. Resources stayed at 1,790 and presentation nodes at 115. Scene nodes and
memory grew as live corpses/effects changed; this is not a long-session leak
certification. Counts/effects were not reduced. The benchmark's acceptance checks
passed, but occasional hitches remain. These stronger, faster attacks change
battle behavior, so do not present the earlier 62.78 ms maximum as current.

The worst frame included five native catch-up steps, 59.65 ms in movement and
27.18 ms in decisions; navigation topology/collider refresh was zero on that
frame. A later performance investigation should profile those movement queries
and catch-up behavior before changing the scenery or effects. Existing fixture
shutdown RID/resource warnings remain. The broader balance-menu suite also fails
on its outdated 18-character picker and Goemon/Edo UI assumptions, then stops at
a missing Edo control. It is not reported as passing; focused DL2 health checks
cover defaults, unchanged Goemon/Edo baselines and retained saved overrides.

Verify with Play Goemon: select DL2, listen to walking, cast Paired Fireballs,
and check the 5,000 base HP display. See `docs/dark-lumina-2-recovery.md` for exact
kit fields. Current raw results, audio recordings, source hashes and captures are
under `build/Other Files/Asset Toolkit/Dark Lumina 2/Fire and Audio Buffs/`.
No app export or long-session soak was requested or performed.

## Kojiro's three homing birds — 2026-10-24

The user reported that the three flying birds looked odd. Fresh ROM decoding
confirmed the existing sprite pixels and three-shot spread. The mismatch was
visual orientation: the original rotates each sprite with its changing heading,
but our homing birds kept a fixed screen angle. The existing directional
billboard now accounts for the diagonal art, and the projectile updates its
orientation after steering. This changes existing transforms and one prepared
material parameter; it adds no combat-time loading, meshes, materials or pools.

The focused Metal renderer check reproduced 21 failures before the change and
passed all 45 assertions afterward. The desktop launcher also passed 395 gameplay
assertions, including repeated pool reuse and steering, and the existing phoenix
render checks passed all 45 assertions. This is correctness and appearance
evidence, not a fresh FPS benchmark. To verify by eye, cast the three white homing birds from different
camera angles and watch their heads turn toward the target. Their current size,
speed, spread, sounds and hit behavior remain unchanged. See
`docs/recovered-kojiro.md` for ROM addresses and the saved comparison.

## Startup work — 2026-10-24

The user reported that launching had become slower. Fresh startup measurements
found two costs: opening the headless editor importer on every desktop launch
(**4.91 seconds** with no asset work), and checking each Wind Meadow plant
candidate against all map roads and camps while preparing the scenery.

The launcher now compares source/import metadata with the snapshot saved after
a successful import. Unchanged launches skip the editor; source additions,
edits, renames/deletions, import settings, missing/changed imported files,
class/extension caches and engine changes still refresh. The kernel lock and
standalone `--script` behavior remain intact. The full-project snapshot check
was about **0.7 seconds**. Its cache is disposable; see `docs/godot-iteration.md`.

Wind Meadow now selects nearby road segments/camps once per existing 36-metre
chunk and reuses the height already sampled for each accepted plant. Rejections
still precede the same random draws. No density, visibility range, asset,
material, collision, army count or combat setting was reduced. All **1,338
scenery MultiMesh buffers / 467,694 instance records matched the saved original
byte for byte** after the change, including the mountains after the foliage RNG.

Fresh paired desktop-launcher Metal runs at 1280×800 measured scene preparation
at **7.70 seconds before and 4.60–5.34 seconds after**. Scene load through first
draw fell from **10.25 to 7.09–8.15 seconds**. These windows were unfocused;
these are startup observations, not foreground gameplay-FPS measurements.
Total launcher-to-combat-material-ready time was **16.14 seconds before and
13.88–14.71 seconds after**. The native library changed during these runs, so
each correctly refreshed imports; this is not a measured full-game repeat-launch
cache speedup. An isolated real-Godot launcher regression separately verifies
that an unchanged relaunch bypasses the importer and a new global class triggers
an import before gameplay. Do not count the later lock-rejected desktop attempt
as another successful run; a regular game was then running and was left alone.

Fresh checks passed: **21,300** original-distance road-clearance comparisons
at both supported map sizes, including chunk/road boundaries; **686** valley
checks (native routes, collision, castles, attacks, victory and map switching);
**8** launcher checks; snapshot edit/delete/rename/engine/cache invalidation
checks; **63** toolkit unit tests; **12,812** imported asset checks; **98** outfit
checks; **86** structure checks; and asset preservation. Startup captures were
inspected. Existing fixture shutdown RID/resource warnings remain. No app export
or full-army frame-rate/long-session claim was made.

To verify, close the game, double-click Play Goemon, then close/reopen without
editing assets. The second launch should print `Goemon assets are up to date.`
and bypass the editor scan. After an asset or native build, expect one refresh.
For scenery work, compare the actual instance buffers before changing density:
removing repeated searches can shorten loading while preserving every plant.
Evidence and the `startup_benchmark.gd` reports are in
`build/Other Files/Startup Optimization/`.

## Dark Lumina 2 / Skullpion skill spikes and stomp wave — 2026-10-24

The user reported stalls when many of these bosses cast together and questioned
DL2's stomp wave. Fresh foreground profiling found several separate costs:
repeated animation setup and effect-list scans, unchanged terrain triangles being
exported again after wall damage, rebuilding their native collision tree, and
rebuilding entire route grids for each unit radius after the same obstacle change.
One instrumented wall-break frame spent about 67 ms rebuilding route grids and
47 ms refreshing navigation. These were CPU preparation costs, not permission
to remove units, reduce particles, turn off audio or lower the scenery quality.

The shared renderer now groups effect records in one pass, avoids submitting
empty batches, and seeks Skullpion's existing animation without restarting it
every frame. Stationary slope alignment is reused until the boss or terrain
changes. Collider exports reuse exact local vertices/world transforms and prune
disabled, removed or changed shapes. The native collision tree retains its
unchanged terrain prefix and rebuilds the building tail; capsule/projectile
candidates retain source order. The spherical boss sweep retains the original
edge-roundoff/tie order, and climb queries reject walls that provably cannot beat
the closest valid footing. No attack timing, damage, target checks or counts changed.

For unchanged terrain, native route grids now recertify cells/edges within the
changed obstacle's radius plus one edge. Flow fields and route certificates are
invalidated. Heights, holes, ramparts, bridge layers and domain edits still rebuild
completely. Tests compare all cached grid heights/open flags/edges and route
choices against fresh rebuilds, including both boss radii and raised layers.
Keep the original positive edge direction when checking boundary segments;
reversing a segment can change floating-point terrain samples.

Two fresh 120-second Metal/Apple M3 runs kept **240 enemies and 96 allies** active,
starting with 48 of each boss, with normal stats and per-death reinforcements.
The run before the final navigation changes averaged 45.85 FPS, p95 33.08 ms,
p99 42.14 ms and maximum 211.66 ms. The accepted final run averaged **57.55 FPS**,
**p95 20.92 ms, p99 23.50 ms and maximum 62.78 ms**. It passed all benchmark
acceptance checks, stayed focused throughout, delivered 145,216 damage events
with no event gaps, and reinforced all 2,914 deaths. Tracked inputs did not change.
Prepared effect nodes stayed at 115 and resources at 1,791. Whole-scene nodes
fluctuate with retiring bosses/corpses; this is a two-minute result, not a
ten-minute leak certification or a promise of 60 FPS in every scene.

The stomp previously used unrelated dome meshes. The corrected shared effect
uses actor 0x352's nineteen original textured ground sectors, eight-frame UV
scroll, rise/rotation and outward fade. The editable source is
`assets/blender/enemies/recovered_monsters/dark_lumina_2_stomp.blend`; export it
with `tools/dark_lumina_effects_blender.py --stomp`. Existing masters, the body
pose bake, landing audio, both grounded damage pulses and borrowed skills remain
intact. See `docs/dark-lumina-2-recovery.md` for the ROM trace.

Fresh checks passed: 46 rendered stomp assertions (601/602 frames focused),
39 spin assertions, 72 Skullpion assertions, nine collision-export invalidation
checks, 1,907 frozen capsule comparisons, 1,026 air-query checks, 3,396 navigation
checks and 974,401 terrain-clearance checks. Native boss suites, 62 toolkit unit
tests, 12,812 import checks, 98 outfit checks, 86 structure checks, asset audit
and preservation checks also passed. The broader presentation suite separately
reports 12 Ranger authored-skin/pose-bake comparison failures; its other 208
checks pass, and no Ranger assets were changed here. Existing fixture shutdown
RID/resource warnings remain.

Verify through Play Goemon with a crowded boss wave: cast together, let area
attacks destroy a wall, and watch both the travelling ground ring and frame time.
When investigating another stall, inspect the slow frame's native/navigation
breakdown before changing effects. Reuse prepared data only when its geometry,
transform and ownership still match; never keep a cache through a real wall or
terrain change without recertifying it. Evidence, raw frame samples and captures
are under `build/Other Files/Asset Toolkit/Boss Skill Performance/`; the accepted
run is in `Final Cached/`. No app export was made.

## Kojiro phoenix drawing angle — 2026-10-24

The user confirmed that the RMB/T phoenix angle was wrong while its sound and
attack were correct. Fresh ROM inspection shows a camera-facing sprite whose
screen corners rotate with the caster's heading; the previous upright 3D plane
was an incorrect interpretation. Only the phoenix now opts into directional
billboarding in the existing shared atlas shader. The bird's head follows travel
projected into Goemon's rotatable camera. A directly camera-aligned shot has an
upright fallback. Current aim, muzzle offset, 3× size/damage, growth, speed,
timing and audio remain unchanged, as do the original art and editable master.

This was a presentation mismatch, with no measured performance bottleneck.
The fix adds a few vertex calculations for this effect and reuses prepared
materials and pooled projectiles; it adds no per-frame CPU search or loading.
Fresh Metal pixel tests cover 24 camera/flight combinations: 21 of 45 checks
failed before the fix and all 45 pass afterward. Focused headless and rendered
gameplay suites pass 381 assertions each, including actual aim, native damage,
wall obstruction, repeated casts, lease reset and borrowed skills. The final
rendered run used a separate Godot window because another test held the desktop
launcher; earlier launcher runs exposed fixture assumptions about post-release
position and manually stepped jumps. Those checks now sample the launch instant,
use actual flight direction for the muzzle offset and resume real physics frames
for physical jumps. The final run had one focus loss, zero pool misses and no
idle resource growth. Existing whole-scene shutdown RID/resource warnings remain.
Asset preservation, 61 toolkit unit tests, 12,812 import checks, 98 Musashi outfit
checks and 86 structure checks also pass. These results do not establish
full-army frame rate or long-session stability.

Verify with Play Goemon: cast RMB/T, turn the camera to a side view while the
bird travels, then cast from the air. It should keep its visible bird silhouette
and point along travel. Keep orientation in the existing renderer, separate
from the already-correct combat timing. Evidence is in
`build/Other Files/Asset Toolkit/Kojiro/Phoenix Angle/`; ROM addresses and the
projection adaptation are documented in `docs/recovered-kojiro.md`. No app or
asset export was performed.

## Musashi and Kojiro size adjustment — 2026-10-24

The user requested Musashi 20% smaller and Kojiro 10% smaller than their current
sizes. Musashi's existing intrinsic multiplier changes from 2.55 to 2.04; Kojiro
fits to 90% of his previous Goemon-height body. The shared character-size contract
keeps their capsules and camera anchors aligned. Sword endpoints and source-based
reach/effects follow the fitted models, and Kojiro's forward wave muzzle follows
his resized torso. Existing source-space travel scales with its owner; animation
clocks, damage, cooldowns and input rules retain their existing controllers.
Original meshes, outfits, source poses, exports and native army bakes are intact.

This is a proportion adjustment, with no measured performance bottleneck or
new runtime system. Reuse these constants for future changes instead of editing
the authored geometry or adding a separate size updater. Check standing feet,
weapons/contact, body clearance and camera position together; verify growth and
switching back to Goemon so a temporary root scale cannot accumulate.

Fresh focused checks passed: Musashi size/native contacts 18, physical movement
13, finisher 32, repeated assimilation skills 78, and Kojiro gameplay 373.
Asset preservation, 60 toolkit unit tests, 12,812 imported checks, 98 outfit
checks and 86 structure checks passed. The desktop launcher fixture passed 17
checks for size, camera/collision alignment, walking, jumping, landing, attack
completion and Musashi's full outfit. The accepted run's tracked inputs stayed
unchanged; both unobstructed captures were inspected. Manual player-step p95 was
0.873 ms; rendered interval p95/max was 17.57/35.62 ms. An earlier capture retake
lost window focus and auto-paused, producing two fixture failures. The accepted
repeat uses the existing smoke-test flag to suppress that automatic pause; normal
game focus behavior is unchanged. These are focused results, not a full-wave
benchmark or long-session leak claim. Existing shutdown RID/resource warnings
remain. Evidence is in `build/Other Files/Asset Toolkit/Character Size 20261024/`.

Verify with Play Goemon by switching between Musashi and Kojiro at the same
camera distance, then walking, jumping and using their normal attacks and skills.
No app or asset export was performed.

## Humanoid landing correction — 2026-10-24

The user heard an oversized sound on Goemon and clarified that only landing
should change. The earlier shared Skullpion impact below was reaching ordinary
humanoids. The ROM's normal Goemon landing handlers select event 21E, the same
sample already packaged for Yae. Executing both handlers for all four original
characters passed eight cases; a fresh sequencer render matches that existing
0.175-second WAV byte for byte. No audio asset, jump effect or voice was edited.

The smallest fix adds the humanoid landing policy to the existing SoundLibrary
and connects Rogue's existing airborne-to-floor transition to Hero.play_sound.
All 25 humanoid roster entries use this prepared sample, including Musashi,
Sasuke and previously silent Kojiro. Existing recordings retain their policy,
with gain/mute controls intact. Non-humanoid defaults and dedicated attack
impacts retain their existing paths. No new voice pool, runtime loading, native
army simulation or per-frame search was introduced.

The focused regression reproduced 78 failures before the fix and passed all
120 headless checks afterward. It covers real floor contact on every humanoid,
source ownership, Skullpion's physical falls/stomp, recording controls and 2,500
overlapping humanoid events with unchanged live node/resource counts. Fresh
related checks passed: character recording 40, Goemon audio 166, Musashi audio
43, Sasuke audio 78, Yae audio 91 and Dragoon landing 31. Asset preservation,
60 toolkit unit tests, 12,812 import checks, 98 outfit checks and 86 structure
checks also passed. The fresh desktop-launcher Metal run at 1280×800 passed
124 assertions, including the same physical landings and bounded reuse. Its
SFX mixer capture is non-silent with no clipped samples; Goemon/Knight landed
captures were inspected. All eight tracked runtime/audio inputs stayed unchanged
through the run. Existing whole-scene shutdown RID/resource diagnostics remain;
these checks do not establish full-battle smoothness or long-session leak freedom.
No app was exported.

This corrects sound choice and missing dispatch; no frame-time bottleneck or
whole-army speedup was established. Verify through Play Goemon: jump and land
as Goemon, Knight, Musashi, Sasuke and Kojiro, then check Landing in Sound Studio.
Keep jump voices, skill impacts and footstep markers separate from the ordinary
landing slot. Evidence is under `build/Other Files/Asset Toolkit/Humanoid Landing
Audio/`; the ROM proof is in `build/Other Files/Goemon ROM Recovery/Audio/`.

## Shared landing audio — 2026-10-24

Historical policy: the humanoid correction above supersedes this default for
ordinary humanoid landings. The heavy boss impact remains available.

The user approved Skullpion's recovered ground impact and disliked the generated
shared landing sound. The existing `land` default now uses that impact, with
Dark Lumina 2's recovered slam if the primary resource is unavailable. Character
originals, intentional silence, saved recordings, gain and mute retain their
existing priority. SoundLibrary resolves the prepared sample once during setup;
ordinary landings use the existing voice pool at source pitch. Native Skullpion
presentation resolves the same default when initialized. The playable stomp
keeps its timed dust burst but lets Hero's physical landing own its sole sound.

Fresh checks passed 43 headless and 45 desktop-launcher Metal assertions,
including three physical falls, one stomp without duplicate audio, fallback,
recording controls, all roster previews and 100 repeated plays with unchanged
node/resource counts. The desktop SFX capture is audible with zero clipped
samples. Native boss presentation passed 72 checks, character recording passed
40, and asset preservation passed. Recorded runtime inputs stayed unchanged
during the desktop run. Evidence is in
`build/Other Files/Asset Toolkit/Landing Audio/`.

This is an audio substitution, with no newly established frame-time bottleneck
or full-army performance claim. Keep samples prepared and reuse the existing
landing event and voice pools. Verify through Play Goemon by jumping/falling,
using Skullpion's RMB stomp, then changing Landing gain/mute in Sound Studio.
No app export or long-session soak was performed. Existing full-scene shutdown
RID/resource diagnostics remain in the fixture logs.

## Kojiro sound-bank correction — 2026-10-24

The user reported wind/sea-like sounds on Kojiro's cuts and other attacks. The
previous recovery used the scenery bank from SC03/14 with Kojiro's event table.
The original duel loader instead replaces resource 57 with SC03/17. Rebuilding
only the audio from that bank fixes attack voices, all three spell releases,
hurt and defeat. For example, the misassigned 8.389-second homing "voice" becomes
the correct 0.243-second cue. Earlier sound-recovery claims for the scenery and
alternate banks are superseded; the model/motion evidence is unaffected.

The USA sword event is disabled and refers to an absent tone. The player now
reuses the prepared Musashi Fusion cut once at each sword strike marker and the
shared sword impact on confirmed contact. These are explicit player adaptations.
Do not revive the old incorrectly labelled sword WAV. Existing voice pools,
selection-time caching, sound ownership, saved takes, gain and mute remain in use;
there is no combat-time decoder or new pool. Geometry and animation were untouched.

Fresh desktop-launcher Metal checks passed 92 assertions, covering three grounded
cuts, two aerial cuts, three spells, borrowed skills, cancellation, studio
previews and recording controls. Eight SFX captures contain nonzero audio and
zero clipped samples. Dispatching 800 overlapping sound events after warmup
showed no node/resource/cache growth. These checks establish routing and bounded
reuse, not subjective listening quality, full-wave FPS or a long-session leak
result. No new performance bottleneck was identified. Existing fixture shutdown
resource/RID warnings remain separate from the passing live checks. The focused
Kojiro gameplay suite passed 369 checks; shared hit audio passed 345. Asset
preservation, 59 toolkit unit tests, 12,812 imported checks, 98 Musashi outfit
checks and 86 structure checks passed. Selected runtime/audio inputs and the
editable model/export hashes stayed unchanged throughout verification.

Verify through Play Goemon: choose Kojiro, click LMB three times, then try his
homing, phoenix and wind skills. A sword cut should have a short blade cue and
contact impact; wind belongs to the wind spell. Use Sound Studio for individual
previews. Rebuild with `python3 tools/recover_kojiro.py --audio-only`, then run the
source recovery test and `tests/forest-shrine/kojiro_audio_test.gd`. Preserve the
separate-bank loader regression: finding a character in an overlay does not
establish that the bank packaged with that overlay owns its battle sounds.
Evidence: `build/Other Files/Asset Toolkit/Kojiro/Audio Correction/`. No app export.

## Shared combat audio defaults — 2026-10-24

The user disliked early generated sounds, especially when killing enemies, and
asked to use the Musashi ROM audio system. Generic light/heavy, projectile,
chain/shove and environment contacts now reuse prepared Musashi samples through
`SoundLibrary.COMBAT_DEFAULTS`. These are deliberate shared defaults, not claims
that every weapon used those events in the original game. Character-specific
originals, dedicated claymore impacts, intentional silence and saved takes keep
their existing priority. Studio previews and both playback routes agree.

The old extra `enemy_reaction` hurt beep defaults to silence. Native soldiers
already own their confirmed pitch-bend death cry; recovered monsters/bosses keep
their own reaction/death events. Removing the generic layer lets those sounds
play cleanly. A saved extra reaction remains available under the existing
recording policy, with gain/mute intact; Studio labels an empty default as silent.
Samples are prepared once and played at their prepared pitch through the existing
bounded voice pools. No new runtime decoder, asset load per contact or army owner
was added. The existing recovery does not emulate the complete original SPU.

Fresh desktop-launcher Metal checks passed 346 assertions, including repeated
real contacts across native enemy kinds, lethal soldier hits, preserved death
accounting, recording/mute/gain, and no node/resource growth during 100 overlapping
contact pairs. Four captured SFX outputs were non-silent with no clipped samples.
Headless checks passed 40 recording/studio, 16 paired-studio, 43 Musashi audio,
166 Goemon audio and 13 soldier-death assertions. Two old studio fixtures assumed a roster index or a
now-hidden hero; they now use visible stable IDs. The Musashi audio fixture now
chooses a fixed red soldier instead of a random wave type, after its Lumina
contact assertion failed in the initial run. Asset preservation, 58 toolkit unit,
12,812 imported, 98 Musashi outfit and 86 structure checks passed.

No performance bottleneck was established, and this is not a full-army FPS or
long-session leak test. Existing harness shutdown RID/resource warnings remain.
Verify using Play Goemon: hit and defeat soldiers, then open Sound Studio to
preview contacts or record an extra reaction. For future replacements, edit the
shared default/character event maps and reuse prepared samples; keep native
death ownership, source pitch, mute/gain and bounded voices. Evidence and audible
captures are in `build/Other Files/Asset Toolkit/ROM Combat Audio/`. No app export
was performed.

## Combined-source battle verification — 2026-10-24

After Kojiro's three-motion grounded combo and asset checks finished, the latest
complete source was imported through Play Goemon. The two shared fixes below
remain intact. Fresh idle-work 7, modular-skill 3,040 and shared-character 144
checks pass, as does asset preservation. Kojiro's completed rendered 369-check
fixture also has unchanged recorded inputs. The hidden-ribbon microcheck still
takes 0.404 ms for 1,000 updates; its historical pre-fix value is 44.927 ms.
No further production change was justified by this follow-up.

The following foreground Metal runs used Apple M3, 1280×800, painterly Wind
Meadow, normal stats, 240 native enemies and 96 allies. All 648 recorded runtime
and selected asset inputs stayed unchanged across the sequence. Every run had
100% focus, sustained populations, zero hit-event gaps and no script errors or
missing assets. There were no competing Godot, Blender, import or native-build
jobs. Existing shutdown resource/RID warnings remain separate from these checks.

| Run | FPS | Mean / p95 / p99 frame ms | Result |
| --- | ---: | --- | --- |
| 60s Green Spearman control A | 70.10 | 14.26 / 18.81 / 21.77 | Pass |
| 60s same body, repeated Kojiro wave/homing/wind | 50.17 | 19.92 / 30.78 / 36.84 | FPS and p95 fail |
| 60s immediate control B | 49.29 | 20.27 / 30.27 / 36.30 | FPS and p95 fail |
| 360s all-enemy matrix | 40.63 | 24.58 / 36.55 / 53.43 | Frame and simulation-time gates fail |
| 45s Kojiro diagnostic with script/step profiling | 79.72 | 12.53 / 16.51 / 19.36 | Gates pass; diagnostic only |

The control also slowing down means the first control/skill difference is not
an isolated skill cost. The instrumented repeat passing is not a code speedup.
The profile's active donor-step p95 was 0.156–0.194 ms per controller, with idle
p95 0.052–0.159 ms. A single homing step reached 5.673 ms; these timings do not
include every projectile, presentation or GPU cost. Native-step means varied
from 0.52 to 1.16 ms across the uninstrumented short runs. GPU timing remains
unavailable. This does not establish a new reproducible game bottleneck to fix.

The matrix completed all ten playable enemy bodies and thirty borrowed skill
slots. Full-size Skullpion was retained and its capture inspected. Pool misses
were zero throughout; prepared projectile count stopped growing at 660 after
the seventh body. Per-body resource changes were 0–6; fixed-body short runs
ended at their starting resource counts. Matrix memory rose from 512.0 to
547.3 MiB while selecting new kits, so this is not a long-session leak test.
Its 771.7 ms maximum includes character selection and capture pauses; per-body
samples exclude two seconds after selection. Skullpion's own interval measured
26.36 / 36.86 / 50.65 ms mean/p95/p99. Functional fixtures cover contacts,
held/charged releases, cancellation, movement, cooldowns and switching; the
wide-camera battle fixture alone does not prove every borrowed shot hits a troop.

Host snapshots every five seconds recorded persistent macOS Storage analysis,
other background CPU work, active memory compression/swap traffic and about
5–6 GiB of swap. These observations are a confounder, not proof that Storage
caused every stall. The source is stable, but **full-battle smoothness is still
unaccepted**. Repeat the matched control/skill comparison with background work
settled before attributing the change to a skill or making another optimization.
Keep the counts, art, boss scale and skill behavior unchanged. Do not select only
the fastest passing run as evidence. No app was exported.

Evidence: `build/Other Files/Playable Enemies/Settled Battle Checks/Combined Source/`
contains `summary.json`, the 648-input fingerprints, individual benchmark
reports/captures, host samples and regression logs. The small
`build/Other Files/Playable Enemies/monitor_battle.py` wrapper reuses the existing
battle fixtures and records host load; it does not change game settings.

## Sustained portable-skill follow-up — 2026-10-24

The first settled-source follow-up ran 240 native enemies and 96 allies with
painterly scenery on Apple M3/Metal at 1280×800. A six-minute diagnostic cycled
through all ten playable enemy bodies, their primary attacks and thirty borrowed
skill slots, including full-size Skullpion and both enlarged Dark Lumina forms.
Populations stayed at 240/96, hit delivery had no gaps, and projectile reuse had
zero pool misses. All 635 recorded runtime inputs stayed unchanged during that
run. This verifies coverage and reuse, **not smoothness**: mean/p95/p99 frame
times were 28.84/51.26/95.13 ms. Character selection and capture/setup pauses
also affect its whole-run maximum and simulation-time gate; per-body samples
exclude the first two seconds after selection. No counts, art or damage were
reduced.

Short runs varied: the control passed at 63.86 FPS (p95/p99 20.69/25.34 ms),
the first repeated-skill run failed at 38.61 FPS (39.94/65.75 ms), and a repeat
with spell-step instrumentation passed at 65.94 FPS (19.64/22.23 ms). Later
debugger profiles also slowed in the control. These are not a reliable causal
before/after FPS comparison. Background CPU activity and roughly 6.7 GiB of
system swap were observed on this 8 GiB machine; that is context, not proof of
the source of every stall. GPU timing remains unavailable. Ed, Sasuke and
Musashi controller-step p95 values in the passing profile were below 0.8 ms.

Two concrete issues were reproduced and fixed. Equipped Kojiro donor
controllers incorrectly followed the wearer's automatic primary attacks;
only selected Kojiro now responds to that automatic input, as the other shared
controllers already do. Invisible donor blade ribbons also rebuilt geometry
every tick. The existing shared ribbon skips construction when its render
layers are zero and clears old points before it becomes visible again. Visible
trails, authored motion, hit timing and projectile behavior retain their paths.
A matched headless microcheck of 1,000 hidden-ribbon updates fell from 44.927 ms
to 0.404 ms. This measures the removed CPU work, not a whole-frame FPS gain.

Fresh checks at the fix snapshot: the new regression reproduced three failures
before the changes and passed all seven afterward, both headless and rendered;
modular skills 3,040, shared character systems 144, Ben slash/trail 17 and
rendered Kojiro 365 passed. The earlier rendered all-enemy fixture passed 246.
Asset preservation passed at that snapshot. Existing shutdown RID/resource
warnings remain. No app was exported and no long-session leak claim is made.

The first after-fix battle rerun was stopped when new Kojiro grounded-combo
animation/export work resumed in the shared checkout. That interrupted run has
no acceptance result; the combined-source follow-up above supersedes its pending
verification status. Evidence and reusable fixtures are under
`build/Other Files/Playable Enemies/Settled Battle Checks/`; the regression is
`tests/forest-shrine/spell_idle_work_test.gd`. Preserve the automatic-input owner
guard and skip invisible presentation work when adding future borrowed skills.

## Armored Dragoon hunt — 2026-10-24

Dragon Leap now releases a winged steel dragon with red eyes after landing.
The original three 64-base-damage shockwaves remain. The dragon then hunts for
three seconds, travelling at 42 m/s and choosing a new pass every 0.35 seconds.
Each pass deals 192 base damage once per victim, with existing damage/critical
modifiers. It seeks nearby visible enemies, sweeps exact contacts along its
path and stops its current pass at solid cover. The player can keep moving.

The smallest implementation extends the existing projectile owners. Player
casts reuse the Rogue projectile cache; allies use native Projectile records
and one shared MultiMesh batch. Target selection and swept contacts query the
local native grid. Dragon-only player shots skip the old whole-projectile
target snapshot. Per-pass hit history prevents damage on every frame, and
short substeps preserve contacts through a long frame. No new army controller,
renderer, per-cast resource loading or runtime retargeting was added. The
editable procedural mesh reuses the old body/head/tail and adds wings/armor:
3,434 vertices, 6,056 triangles, one surface and no textures. Existing character
animation, weapon grips and army pose atlases are unchanged.

Fresh checks: 42 desktop Metal hunt assertions, 36 native Dragoon combat,
25 player sweep, 31 landing audio, 13 army effect and 2,168 packed-projectile
checks pass. Hunt coverage includes ten player casts, three cycles of eight
simultaneous allied dragons, target changes, caster retirement, physical cover,
three-second expiry, reset and character changes. The old native radius fixture
now samples just inside the fitted outer contact edge; the player sweep fixture
now spawns actual native actors and places them outside the attacker's body.
Those fixture corrections supersede the earlier Dragoon failure note above;
the shockwave radii and sweep timing/damage were not changed. Asset preservation,
45 toolkit unit tests, 12,812 imported asset checks, 98 Musashi outfit checks and
86 structure checks passed during this work.

The final focused rendered fixture measured eight dragons over three cycles on
Apple M3/Metal at 1280×800. All 567 measured frames had foreground focus.
Native-step median/p95/p99/max were 0.162/0.313/0.386/0.900 ms; rendered-frame
values were 16.662/17.055/20.317/79.375 ms. Resources stayed at 1,141 and the
presentation retained 108 nodes. This short fixture manually advances the
native runtime with stationary targets; it is not full-world FPS evidence.
No new CPU bottleneck was established. Keep setup at selection, a shared mesh,
local queries and per-pass hit history when changing the design or damage.

The separate 30-second Wind Meadow battle retained 240 enemies and 96 allies,
normal stats, the camp roster and zero dropped hits. Mean/p95/p99/max frame
times were 24.44/54.68/122.43/614.51 ms, with mean native step 2.47 ms. It failed
the frame-time and foreground acceptance checks (82.9% focus). The pre-change
run also failed, at 78.84/166.68/284.42/1051.56 ms. Other project changes and
background activity were not isolated, so these are not a controlled speedup
comparison or proof that the dragon caused the stalls. Saved after-run source
hashes matched at review. The user's historical smoothness report remains
separate evidence; full-battle performance needs a controlled foreground rerun.

Evidence: `build/Other Files/Asset Toolkit/Dragoon Hunt/summary.json`, screenshots,
`native-desktop-profile.json` and `After Battle/`. Run the desktop launcher with
`--script res://tests/forest-shrine/dragoon_hunt_test.gd -- --visual`, then try
Dragon Leap in normal play. Check the red-eyed winged silhouette, original
landing shockwaves, three seconds of moving attacks, repeated passes and cover.
Edit/rebuild instructions are in `docs/dragoon-motion-workbench/dragon-hunt.txt`.
No app export or long-session soak was performed. Existing shutdown resource/RID
diagnostics remain separate from passing assertions and stable in-run counts.

## Physical hit response — 2026-10-23

The user requested faster stagger and knockback after the flash fix below.
Two delays were confirmed: accepted damage waited for the next native step to
select the hurt pose, and a post-step pipe contact could render the cached
pre-hit snapshot. Accepted ordinary enemy hits now select their existing hurt
pose immediately. The coordinator refreshes the render snapshot once per frame
when pending hits require it; multiple victims share that refresh. Physics and
contact snapshots stay immutable. This supersedes the next-tick behavior
described in the earlier flash-only report. Frozen victims keep their held pose
until thaw, and movement still goes through native terrain collision.

Goemon's pipe/heavy-pipe tickets now start the shared knockback 50% faster and
decay it faster. Soldiers, Vambee, wolf, torso and gorilla use the same rule.
At 60 Hz, light/heavy first-step travel changes from 0.020/0.050 m to
0.030/0.075 m. Reaching half the old push takes 50/67 ms instead of 83 ms;
total travel increases only 6.6%/4.7%. Stagger remains 16/30 seconds. Damage,
combo timing, other characters' impulses and explicit skill pushes retain their
existing values. No runtime retargeting, extra renderer, per-victim whole-army
scan, asset loading or additional collision system was introduced.

Fresh final checks: native recoil 108, real Goemon contacts 98 and desktop Metal
contacts 77 pass. They cover immediate GPU pose publication, attack cancellation,
Vambee splitting, frozen victims, repeated hits, ordinary/custom impulses and
wall collision. Earlier checks during this change passed presentation 220,
soldier combat 58, terrain 497 and asset preservation. Ninja and Dragoon each
retain one allied contact-test failure; both reproduce with the saved pre-change
native library. Do not describe those suites as passing.

The final 30-second foreground Wind Meadow battle maintained 240 enemies plus
96 allies, normal stats and the six-type camp roster, on Apple M3/Metal at
1280×800. Mean/p95/p99/max frame times were 10.96/18.44/24.92/106.27 ms;
mean native simulation cost was 0.615 ms. Full focus, zero dropped hits and the
existing benchmark acceptance checks passed. Recorded game-source hashes matched
at review. The isolated 106 ms spike remains; this is not a spike-free claim or
a matched before/after FPS comparison. An earlier run overlapped another native
rebuild and lost focus, so it is excluded. No new CPU bottleneck was established.

Evidence: `build/Other Files/Asset Toolkit/Physical Recoil/summary.json` and
`Final Performance/`. Run `enemy_recoil_test.gd` and
`recovered_enemy_hits_test.gd` through the desktop launcher, then try light and
heavy pipe hits on surviving enemies in normal Play. Look for the hurt pose at
contact, a prompt push, successful following combo hits and walls still stopping
movement. Preserve counts and art when repeating the foreground benchmark.
No long-session soak, other-hardware test or app export was performed. Existing
shutdown resource/RID diagnostics remain separate from passing combat assertions.

## Gorilla and wolf together — 2026-10-23

Slow Guy/gorilla is now a separate native enemy (16), alongside Haya Wolf (9).
It reuses the preserved Blender master and original 40-tick arm swing, sound,
hurtbox and contact segment. Its active interval is source ticks 15–20. A small
data field extends the shared native attack engine with an exclusive contact-end
tick; the existing per-attack hit flag prevents repeat damage. Other enemies
retain their single-marker attacks. The wolf keeps its existing flying kick.
There is no second simulation, per-unit skeleton, per-frame asset load, extra
target list or full-army scan. Both editable originals and immutable recoveries
remain byte-identical. Existing shared victim knockback is still a port adapter.

Fresh checks: source/Blender toolkit 35 tests; imported/native monsters 124 checks
and 15,756 source part matrices; real Goemon hits/interruption 92; hit-flash/packed
instances 2,913; soldier combat 58; pooled presentation 220; camp contracts 18.
Asset preservation passes. The desktop closeup shows both enemies using the
actual native renderer and their different original attacks.

The short desktop comparison held 240 enemies plus 240 stationary native
targets. Five-type control versus six-type roster: native-step p95 0.354 / 0.368
ms, 12 / 13 visual batches, no measured node/resource growth in either run.
Both frame p95 values were about 16.67 ms, so that capped fixture does not prove
an FPS improvement or full-battle headroom. No new bottleneck was established.

A separate 30-second Wind Meadow ground-camera battle maintained 240 enemies
and 96 allies, full foreground focus, 30.05 seconds of simulation and zero dropped
hits. Resources stayed at 1,382. Mean/p95/p99/max frame times were
12.76 / 23.87 / 43.08 / 534.63 ms, with mean native step 1.364 ms. The benchmark's
acceptance checks passed, but the large stalls mean this is not a smoothness
claim or a controlled comparison with historical runs. Background CPU work and
window focusing were not isolated. An initial focus-timeout attempt was excluded.
Do not attribute those stalls to the gorilla without a controlled profile.

Evidence: `build/Other Files/Asset Toolkit/Gorilla and Wolf/summary.json` and
`Battle/`. Verify the source active window with `recovered_monsters_test.gd`,
the two native-rendered attacks with `tools/capture_karate_wolf.gd`, then repeat
the existing foreground ground-camera benchmark with the current camp roster.
Keep counts and art intact; avoid observing the desktop during timing.
No long-session soak, other-hardware check or app export was performed. Existing
shutdown resource/RID diagnostics remain separate from the combat assertions.

## Shared blade contact audio — 2026-10-23

Blade fighters without recovered contact events now reuse Musashi's sword-hit
and Fusion finisher samples: Pirate, Samurai, Ninja, Knight, Dragoon, Explorer,
Master Thief and Ben. Dragoon's piercing lance contact uses the same light hit.
Goemon, Musashi, Sasuke, Yae and Magic Swordsman retain their existing contacts.
Character recordings and mutes still apply. The samples are preloaded once;
confirmed contacts reuse the existing bounded audio voices, with source pitch.
No new simulation, per-enemy audio nodes or combat-time asset loading was added.

Fresh checks: `tests/forest-shrine/weapon_hit_audio_test.gd` passes 136 checks
through `Play Goemon.command --script res://tests/forest-shrine/weapon_hit_audio_test.gd -- --visual`
on Metal. Repeated Knight hits damage all seven ordinary native enemy forms and
play the selected sample; rejected dead targets remain silent. Repeated pooled
playback shows no node/resource growth. Musashi audio passes 43 checks and asset
preservation passes. Logs: `build/Other Files/Asset Toolkit/Weapon Hit Audio/`.
These verify routing/playback, not subjective loudness or full-army frame times.
No listening assessment, new stress benchmark or app export was performed;
shutdown resource/RID diagnostics remain. Verify the mix by comparing confirmed
Ninja/Knight/Explorer cuts, Dragoon thrusts and Ben slashes with Goemon's pipe.

## Knight fourth swing — 2026-10-23

After approving the shared hit sounds, the user requested a powerful fourth
Knight swing with Musashi's last-hit sound. The first three base hits remain
42/42/61; the fourth deals 76, with a 0.68-second swing and the existing responsive
contact adjustment. It reuses the articulated overhead motion, sword/shield
grip correction and contact/recovery machinery. The fourth contact plays
Musashi's actual `fusion_fourth_hit` sample (`lumina_rotation.wav`), rather than
his third-cut sound. Misses do not play it; saved heavy-hit recordings, volume
and mute still apply. The native allied Knight cycles through the same four
attacks, and sends one pooled spatial cue per connected finisher, including
when several enemies are struck. No new per-unit renderer or audio pool exists.

Fresh checks: fourth-swing suite 68 in both headless and desktop Metal runs,
shared weapon audio 136, Knight
guard/timing 33, source/baked presentation 220 and custom tuning 42 pass. The
eight-Knight fixture repeats two full combos per fighter with matching raw
damage, heavy contact and sound-cue delivery. Shared pose atlases and mesh
distance derivatives were rebuilt; asset preservation passes. The guard edge
fixture now places its inside target at x=6.2: the hexagon's lower shoulder at
soldier height is narrower than its maximum six-metre upper corner. This is a
fixture correction; shield geometry is unchanged. Logs and rendered evidence
belong in `build/Other Files/Asset Toolkit/Knight Fourth Swing/`.
These are focused correctness checks, not a fresh full-army performance result.
The desktop capture shows the prepared overhead stroke, surviving native victim
and 76-damage contact; its log is `desktop.log` and the image is `combo.png`.
No new CPU bottleneck was measured or claimed. Test through the desktop launcher
with `tests/forest-shrine/knight_fourth_swing_test.gd -- --visual --native`, then
try four consecutive LMB swings with Knight in normal play. No app export.

## Hit responsiveness: missing enemy feedback — 2026-10-23

After the registration audit below, the user clarified that Goemon's hits still
feel less responsive. A direct response probe found a concrete presentation
defect: accepted damage immediately starts the existing 0.115-second flash,
but both enemy instance packers wrote zero in its place, and the rigid enemy
shader never consumed it. This affected surviving soldiers and recovered
enemies alike. Old soldiers often die quickly, making their immediate death
more obvious; the tougher enemies expose the missing surviving-hit cue. Higher
HP changes the number of hits, not how quickly damage is registered.

The smallest fix forwards the existing per-unit flash through the unused
instance alpha and uses the same brief hit emission as the allied crowd shader.
No extra mesh, material, draw batch, node, timer or whole-army scan is added.
Damage, health, controls, source animations and attack timing stay unchanged.
The native hurt pose begins on the next simulation tick for all these enemies;
the flash clock and HP are already present immediately at contact. That shared
next-tick animation behavior was not changed. Freeze continues to use the
existing paused animation/flash clocks.

Fresh evidence: the probe previously showed flash timer 0.115 / GPU value 0
for soldier, Vambee, wolf and torso. It now shows 0.115 in both places.
The instance suite passes 2,905 checks, including all six ordinary types,
unhit neighbours, no-damage rejection, expiry, slot reuse and identical native
and script packing. Presentation 220, real Goemon contacts 69 and desktop
rendered contacts 51 pass; asset preservation passes. Rendered captures show
the new cue at actual pipe contact. This fixes a confirmed feedback gap, but
the user still needs to judge whether the full subjective feel is resolved.

A fresh 30-second Wind Meadow ground-camera battle on Apple M3/Metal,
1280×800, maintained 240 enemies plus 96 allies, normal stats and full focus,
with no lost hit events, passes the existing frame limits. Mean/p95/p99/max
were 7.59 / 16.69 / 25.45 / 46.70 ms. Mean native simulation cost was 0.465 ms
versus 0.508 ms in the pre-fix camp run. The prior run paced near 60 FPS while
this run was uncapped; do not claim an FPS gain or exact tail-latency equivalence
from those different pacing conditions. All other recorded game source hashes
and the earlier recovered enemy bake hashes match. No new CPU bottleneck was
identified. No screenshots were taken during timing.

Evidence: `build/Other Files/Asset Toolkit/Hit Response/summary.json`.
Verify with a surviving Vambee/wolf: a confirmed pipe contact should briefly
flash only its victim; misses should not flash, and the next strike should
still use its original timing. Repeat the existing instance/contact tests and
the foreground camp-roster benchmark when changing this path. No long soak,
other-hardware test or app export was performed; existing shutdown resource/RID
diagnostics remain.

## New enemy hit and physics audit — 2026-10-23

The user reports that the new valley feels smooth, but Goemon hitting the new
enemies feels odd. A focused audit found no different victim rule: soldiers,
Vambee, the corrected wolf and the crawling torso share damage, 16/30-second
stagger, knockback and attack interruption. Real Goemon pipe triplets hit all
forms at close range with the same scaled damage. A Vambee split during the
combo retains the same handle, changes the fitted collider, and receives the
remaining hits once each. At longer range, knockback can carry the low crawler
below/outside the high third swing; the actual pipe must still touch its hurtbox.

The configured base HP differs substantially: old soldiers have 64/80/72,
Vambee has 160 plus a 160-HP torso, and the wolf has 640. Shared health tuning
still applies. This is a plausible explanation for the different feel, not proof
of the user's subjective cause. No health, hitbox, animation, damage, count or
gameplay physics changes were made by this audit. The wolf identity correction
in the separate recovery task completed during testing; final checks use its
verified `karate_wolf` runtime, not the earlier gorilla.

Fresh checks passed: Goemon/native contact 69, desktop-rendered contact 51,
pipe geometry/cover 11, soldier combat 58, player adapters 41, recovered
poses/combat 78 (13,032 part samples), native terrain 497 and valley 433.
Terrain checks include hills, wall routing, gate changes, bridge support layers,
steep edges and pause. Asset preservation also passed. These are focused checks,
not a guarantee that every possible physics interaction is covered.

The existing benchmark had spawned only old soldiers. Its default now follows
the map's existing roster: the five-type camp cycle for Wind Meadow, normal
wave families elsewhere. `--soldiers-only` retains a test control; normal
gameplay still has one native army owner. No new runtime bottleneck was found,
so the smallest complete change is better regression coverage and measurement.

Fresh 30-second foreground tests on Apple M3, Metal Forward+, 1280×800, Wind
Meadow ground camera, normal stats and maintained 240 enemies plus 96 allies:

| Frame time | Old soldiers | Current camp roster |
| --- | ---: | ---: |
| Mean | 16.662 ms | 16.666 ms |
| p95 | 17.987 ms | 18.567 ms |
| p99 | 18.940 ms | 19.612 ms |
| Maximum | 21.236 ms | 23.662 ms |

Both held approximately 60 FPS, full foreground focus, sustained combat and no
lost hit events. Mean native simulation cost was 0.527 / 0.508 ms per step;
resource count stayed at 1,354 in both short recordings. This supports no major
regression in this scenario, while p95 was 0.58 ms higher for the camp roster.
It does not establish uncapped GPU headroom or leak freedom. GPU timings were
unavailable. All recorded game/native source hashes match; the benchmark itself
was refined to select the camp ratio after the soldiers-only control, whose
behavior did not change. The human benchmark character is Explorer; real Goemon
weapon contacts were checked separately in the rendered fixture.

Evidence and exclusions: `build/Other Files/Asset Toolkit/Enemy Physics and Hits/summary.json`.
Use `Play Goemon.command --script res://tests/forest-shrine/recovered_enemy_hits_test.gd -- --visual`
to review contacts. Repeat `large_army_benchmark.gd` with the existing Wind
Meadow ground-camera command in the valley section, adding `--soldiers-only` for the control.
Do not take screenshots during timing: initial observation runs contained
isolated 79–90 ms stalls and were superseded by the clean recordings. Historical
figures elsewhere in this guide describe their own source and test conditions.
No long soak, 2,000-versus-2,000, other hardware test or app export was performed.
Existing baseline Godot shutdown resource/RID warnings remain.

## Wolf identity correction — 2026-10-23

The earlier wolf recovery was actually Slow Guy/gorilla. Role 9 now loads the
verified 13-part Haya Wolf (`karate_wolf`) and its original flying-kick animation
and sounds. The old gorilla recovery and editable master remain intact. This
changes asset/profile data in the existing native army, with no extra simulation,
per-unit skeleton, asset loading during attacks, or new rendering owner.

No new performance bottleneck was measured. The smallest correction replaces
the mistaken source, refreshes its shared pose bake, and fits the source hurt
box/kick segment. Existing balance, travel adapter, wave counts and scenery stay.
Fresh source/Blender checks, 78 native/imported checks and 13,032 part-pose
comparisons pass. A desktop Metal fixture renders 240 enemies and 240 native
targets with simultaneous attacks and zero measured node/resource growth.
Its frame times are capped around 16.67 ms and focus is not validated, so they
do not establish an FPS gain or general-gameplay smoothness. Earlier reports
about the misnamed asset do not validate the corrected wolf.

Verify with `tests/forest-shrine/recovered_monsters_test.gd` and the desktop
`tools/capture_recovered_monsters.gd`; close-up identity/kick review uses
`tools/capture_karate_wolf.gd`. Evidence lives in
`build/Other Files/Asset Toolkit/Vambee and Haya Wolf/Research/`.
No long-session soak or app export was performed. Existing shutdown resource/RID
diagnostics remain; passing combat checks do not claim to resolve teardown.


## Wind Meadow playable valley — 2026-10-23

Wind Meadow Valley replaces the default map. The original Twin Ramparts castle
perimeter, gate origin/collider, tower decks and worker contracts remain intact;
its visual parts reuse the approved Wind Meadow GLBs. Four destructible barracks
at north/east/south/west use the existing enemy-objective hit/damage and spawn
contracts. This map runs one continuous assault until all four fall. The normal
240-enemy cap remains unchanged; the separate three-camp prototype retains its
1,000 cap and final enemy statue. Earlier maps and saved maps remain available.

Fresh Metal/Apple M3 measurements at 1280×800 used the real game, 240 enemies and
96 allies, default combat stats, explicit death reinforcements and a fixed ground
camera for 30 seconds per map. Both retained all units, full foreground focus,
normal simulation time, sustained combat and zero dropped hits; both passed the
benchmark acceptance checks. Values are end-to-end frame times, not GPU timings.

| Ground camera | Old Blood Gulch | Final Wind Meadow |
| --- | ---: | ---: |
| Mean | 7.61 ms | 6.67 ms |
| 95th percentile | 11.60 ms | 9.24 ms |
| 99th percentile | 14.24 ms | 10.33 ms |

An earlier denser-distance grass run cost 11.02 ms mean / 16.43 ms p95. The
smallest fix was reducing the draw range to 48 m, with GPU shrink-out from
28–46 m. Approved grass geometry, short blade size, near density, characters,
army counts and combat stayed intact. This keeps distant tiny blades from
consuming the near-camera budget; the painted ground supplies distant detail.
Plants use spatial MultiMeshes, shared resources, GPU wind and no per-plant
process scripts. Trees support the existing hero canopy cutaway. One baked
triangular field drives physics, native armies and accelerated corridor queries.
Distant mountains and the coarse terrain apron have no gameplay collision.

Actual Goemon controller traversal from inside the castle, through its gate to
barracks approaches: normal running 14.1 / 25.5 / 26.7 / 39.9 seconds for
south/east/west/north; held sprint 8.0 / 14.6 / 15.3 / 22.7 seconds. All slopes
and gate passages passed without floor falls. Four native soldiers also routed
from the actual barracks exits to the castle gate with real terrain/obstacles.
These are measured routes, not straight-line distance divided by a speed value.

Evidence, source hashes, raw frames, captures and route timings:
`build/Other Files/Asset Toolkit/Wind Meadow/Valley/performance-summary.json`.
Focus-invalid attempts are retained but excluded from the comparison. The
separate earlier overhead study is historical, before final grass/apron tuning.
After timing, a render-only apron edge was blended into the horizon using the
same triangles and draw calls; the playable field, collision and near foliage
match the timed revision. That margin-only adjustment was visually reviewed,
not independently timed. No long-session soak, other hardware test or app
export was performed. Existing
Godot resource/RID warnings at process shutdown also occur on the baseline;
this task does not claim to resolve global teardown diagnostics.

To verify changes, run the desktop Play launcher with
`--always-on-top --script res://tests/forest-shrine/large_army_benchmark.gd -- --scenario=castle --map=wind_meadow --per-team=240 --allies=96 --duration=30 --await-focus --ground-view`,
then repeat with `--map=blood_gulch`. Keep the test window in front and use the
absolute `/Applications/Godot.app` path for computer-control selection: an old
backup shares Godot's bundle identifier. Compare only reports with no errors.


## Shared character foundation — 2026-10-23

Every playable fighter uses `Hero` for movement/body ownership, health,
progression, attack attribution and the spell loadout. The dedicated and Rogue
combat controllers now inherit `scripts/character_combat.gd` for caster identity,
selection setup and focus cancellation. Goemon's weapon helpers remain on Hero
and use the same focus boundary. Unique inputs, source clocks, move rules,
rigs and animation clips remain in their character adapters.

`AttackChain` owns bounded enemy queries, exact contact dispatch, nearest swept
contacts and cover rays. Goemon/Edo/Ed/Ben/Sasuke/Yae projectile nodes use one
`CharacterProjectiles` service. It prepares visuals, restores per-use state,
clears prior targets/tickets/hits and removes a deleted caster's cached shots.
Level changes resize Goemon's existing MultiMesh batches. Musashi and Chief
keep their authored fixed-slot renderers and use the common slot lifecycle;
Rogue keeps its existing effects renderer and uses the common lease retirement
helper. Human Rogue shots now reuse that renderer's cache too. Generation
checks prevent an old flight from retiring an instance reused by a new flight.
The native C++ army and its batched presentation remain the NPC runtime.

Original event maps use `character_audio_bank.gd` for immutable samples and
weighted variants, then the existing SoundLibrary/MoveAudio playback paths.
Character-specific samples, pitch, silence and duplicate variant weights are
preserved. Changing a shared engine/helper should reach every kit; changing a
move's damage, timing, animation or sound belongs in its existing profile.

Fresh checks: all 18 fighters pass the 93-check shared-system suite, including
health retention, selection/focus, spell ownership, native audio caching,
100 repeated projectile leases with no node/resource growth, homing reset,
Ben scale reset, level-dependent coin batches and caster deletion. The desktop
launcher also ran this suite with Metal and painterly scenery, capturing the
roster. In that fixture, constructing/freeing 100 source ice projectiles took
10,363 microseconds; reusing 100 prepared shots took 1,121 microseconds. This
measures projectile setup CPU cost, not FPS or a full-army frame-time result.

Run `tests/forest-shrine/shared_character_systems_test.gd` headlessly, or through
`Play Goemon.command --script res://tests/forest-shrine/shared_character_systems_test.gd -- --visual`
for rendered captures. Detailed results live under
`build/Other Files/Asset Toolkit/Shared Character Systems/`. The regression
checks include source combat/controls, Chief ballistics/headshots, spells,
army projectile buffers/presentation, source audio, imported motion/outfits and
asset preservation. Chief fixtures now reset authoritative native enemies
instead of changing copied model rows. Untextured native faces retain their
geometry/colors while receiving a zero UV channel for shared mesh batching.

An additional native Ranger standoff positioning check failed (gap 5); that
untouched movement path is not counted as passing here. Older main-scene
coin/combo/Rogue-mode tests still assume superseded controls
and menu behavior and failed when additionally attempted; they are not counted
as passing. Existing shutdown resource-cache warnings also remain (present in
saved pre-refactor logs). No full-army stress benchmark or per-move listening
review was repeated, and no app was exported.

## Musashi enemy abilities — 2026-10-23

The five requested original abilities are available on the recovered Musashi:
3 D-Kick, 4 Fence, 5 Homing, 6 Grenade and hold 7 for repeated 3-Way fire.
1 remains Lumina Rotation and 2 remains Mighty Strike. The gold cape button
moves beside the extended action row; other fighters keep their five slots.

Six original body streams live in a separate shared AnimationLibrary. The
existing Musashi body GLB, optimized derivative, equipment and old animations
remain unchanged. New projectile meshes retain the disc's geometry, UVs and
vertex colors; native module palette uploads restore the missing rocket and
grenade textures. Eight weapon/contact sound events use recovered ADPCM samples
and source pitch curves. Full PS1 SPU envelopes, interpolation and reverb are
not emulated. D-Kick has its original contact sound; its module supplies no
separate launch sound call.

Repeated shots and effects use prepared reusable instances and shared source
meshes/textures. Every reuse clears target, ticket, hit list, age, velocity and
visibility. Idle skill presentation stops processing. Exact fitted sweeps run
after the native army's local candidate query. These choices address the risk
of repeated allocation and broad army scans; no new desktop frame-time
bottleneck has been measured. Damage, 3D targeting, terrain collision and plume
placement are adaptations to Goemon rather than a full PS1 engine emulation.

Fresh automated checks cover every imported added pose against the optimized
rig, source geometry/audio provenance, original release markers, repeated held
fire, real native-enemy damage/tracking, grenade bounces, walls, roster changes,
queued sword input and complete pool reset. Repeated empty-range 3-Way fire
showed no node or resource growth in the focused headless fixture. This is not
a rendered smoothness result or a full-army benchmark. The user requested that
the current game session remain running, so the desktop visual/audio playtest
and Metal frame-time capture are pending; no app export was made.

Recovery uses `tools/recover_musashi_assimilation.py` with the bundled Python
runtime (NumPy/Pillow), then Godot's `tools/bake_musashi_assimilation.gd`.
`tools/recover_musashi_audio.py --driver-pitch --sound HEX:NAME` recovers the
events listed in `assets/audio/recovered_musashi/assimilation_provenance.json`.
Run the asset audit/check and `tests/forest-shrine/musashi_assimilation_test.gd`
after changes. Once the desktop launcher is free, use
`Play Goemon.command --script res://tools/capture_musashi_assimilation.gd` for
the actual painterly/Metal capture. Reports belong under
`build/Other Files/Asset Toolkit/Musashi Assimilation/`.

## Original Goemon weapons — 2026-10-23

Goemon's chain now uses the existing shared `character_combat.gd` lifecycle and
`AttackChain` target/contact/cover helpers. Its original 30 Hz extension samples
are interpolated for rendering; ground startup/hold/catch are 70/71/72, and air
startup/hold are 75/76. An airborne return resumes jump/fall; landing selects the
ground hold/catch. Both attack buttons throw forward. The former fan attack and
powered endpoint explosion are removed. This does not add the original game's
special grapple blocks to current maps.

The old chain contact loop visited the whole enemy list. It now asks the shared
native spatial query for nearby candidates before the same precise contact and
cover checks. That removes a scaling risk; no before/after CPU bottleneck was
measured. Keep this shared path when adding weapon moves.

Original 24×24 ROM weapon art now supplies Goemon, Sasuke and Yae's HUD icons.
Golden Goemon keeps his pipe/chain; ryo fires immediately as one flaming charged
coin, without a hold. It uses the other chat’s shared projectile cache and original
charged hit/audio behavior. Normal/flaming meshes and immutable materials are
prepared at character setup, so repeated casts do not rebuild source meshes or
load textures. The in-world flame is the recovered HUD sprite on a billboard,
an explicit visual adaptation.

Fresh focused checks cover native trajectory samples, real ground/air/landing
poses, forward hits, cover, one hit per victim on return, roster/focus reset,
normal/golden inputs, pooled flaming/ordinary projectile reuse, icon identities and repeated
use. The empty-range repeated-chain fixture retained 1,272 resources (node count
3,336 → 3,332). A short foreground Metal capture through `Play Goemon.command`
was visually reviewed for ground throw, air throw and flaming ryo. Its frame
figures describe a small weapon fixture, not a full-army performance result.

Concurrent enemy recovery produced NPC-profile/mesh setup errors in those
broader scene runs. Keep them recorded separately from the Goemon assertions;
repeat a clean complete-game check after that work is finished. No app export
was made. Evidence and reproduction scripts are in
`build/Other Files/Asset Toolkit/Goemon Chain and Icons/`; run
`tests/forest-shrine/goemon_rom_weapons_test.gd`,
`scripts/goemon_weapon_controls_tests.gd`, and
`tools/capture_goemon_rom_weapons.gd` through the desktop launcher for visual
review. Historical smoothness reports above remain separate evidence.


## What helped and why

1. **Use one native army simulation.** The C++ runtime owns NPC simulation;
   Godot presents it and connects it to gameplay. Avoid restoring independent
   per-unit script simulation alongside it. Moving calculations to C++ helps,
   but copying all the results into thousands of Godot objects can still cost
   more than the calculations themselves.
2. **Look nearby before doing precise work.** Spatial grids narrow melee,
   targeting, terrain and tower candidates. Keep the original precise contact,
   range, priority and visibility checks for those candidates. A fast search
   must still find the same valid hit, including at cell boundaries.
3. **Share snapshots and copy only what readers need.** Packed arrays carry
   current state between native simulation, gameplay and rendering. The current
   code defers model dictionary publication and ally field refresh until needed.
   Avoid reconstructing every enemy record for each reader or physics step.
   Preserve ownership and generation checks so retained snapshots and reused
   unit slots cannot expose stale or overwritten state.
4. **Batch drawing and presentation.** The current army renderer uses MultiMesh
   batches, baked pose data and native instance/projectile buffers. Damage
   numbers and effects use pooled presentation paths. Avoid adding a complete
   animated scene tree or fresh effect objects for every ordinary soldier/hit.
   Preserve independent animation, equipment, flashes and visible bounds.
5. **Skip unchanged work.** Reuse visibility results with proper invalidation;
   refresh only changed painterly scenery; avoid polling idle units and writing
   unchanged poses. Terrain probes for cosmetic presentation can be batched.
   Damage, deaths and gameplay events must still arrive promptly and in order.
6. **Optimize assets through the existing preservation pipeline.** Reduce
   redundant mesh/material work without changing approved art, animation,
   joints, sockets or hit regions. Follow `tools/asset_pipeline/README.md`;
   generated derivatives are rebuilt from authored sources, never hand-edited.

## Whenever changing a character or skill

The user explicitly requested these habits for all future character/skill work.
Editing a model or skill freely is fine; repeated construction during gameplay
is the cost to watch.

- Reuse compatible existing animations, combos and attack patterns before
  creating replacements. Inspect both rigs, rest poses, proportions and weapon
  attachments first. Transfer matching motion directly where possible; retarget
  differing rigs during asset preparation and correct grips, feet and posture.
  Reuse is a default, not a reason to change the requested character design.
- Follow `docs/BLENDER_PIPELINE.md`, `assets/blender/AGENTS.md` and the nearest
  asset/workbench guide. Preserve editable originals and unsaved user work;
  export through the matching GLB/animation JSON pipeline. Saving a Blender
  action alone may not update gameplay. Rebuild affected army pose bakes and
  optimized derivatives from their sources, then check preservation, motion,
  weapon contacts and rendered gameplay. Prefer prepared animation data over
  adding per-unit runtime retargeting.
- Animation transfer and attack behavior are separate. Reuse existing combat
  logic for combos where appropriate and align poses to its events; leave hit
  timing, damage, reach, cooldowns and travel owned by the controller unless
  changes are requested. Verify the transferred attack for the player and for
  simultaneous army use when applicable before claiming performance is kept.
- Set up the selected model and resources once, then reuse the character and
  play its animations. Adjust existing shader parameters for glow or color.
  Keep individual effects isolated so changing one actor cannot recolor others
  through a shared material. Occasional character-switch setup is acceptable.
- Use the existing combat, projectile and effect systems. Reuse or pool effects
  that occur frequently rather than loading assets and constructing nodes on
  every hit. Do not build new pooling infrastructure for an occasional object
  without evidence that it needs it.
- Before reusing an effect/projectile, reset its position, target, damage,
  timers, visibility and remaining per-use state. Clear obsolete callbacks and
  references; the next use must not inherit a previous target or hit.
- Changing damage or cooldown values should update skill data/logic, without
  rebuilding visual objects. Use local target queries and shared snapshots
  rather than a full-army scan or copy for each attack.
- Test repeated attacks and overlapping effects. If the army uses the skill,
  also test many units using it together. Check appearance, hit accuracy,
  timing, frame-time spikes and resource growth; compare with the same scene
  before the change. Preserve the requested design, counts and visual quality.
- Explain the relevant choice briefly while making the change, so the user
  learns how to keep new characters and skills efficient.

## What to do next time something stutters

1. Reproduce it through `/Users/eric/Desktop/Play Goemon.command`. Record the
   map, character, army counts, camera, action and whether it is a first-use hitch
   or sustained slowdown. Keep a Git checkpoint of the relevant source before
   changing it; a commit hash alone does not describe uncommitted changes.
2. Measure the same scene before and after, at the same resolution with the
   game window in the foreground and one benchmark/game process running.
   Separate shader/import warmup from steady gameplay. Save logs and captures
   under `build/Other Files/`.
3. Inspect frame times and CPU/GPU costs. About 16.7 ms per frame is 60 FPS;
   p95 and p99 show the slower frames that averages hide. Repeated physics
   catch-up steps are a clue to CPU overload. Fewer draw calls alone do not
   prove smoother gameplay. Headless tests cannot verify rendered performance.
4. Change the largest measured cost first, using existing helpers. Keep army
   counts, combat timing, player controls and scenery consistent so a smaller
   workload cannot masquerade as a faster implementation.
5. Run the focused correctness tests, then repeat the foreground measurement
   and play the original scenario. Check attacking, summoning, deaths, effects,
   hills, bridges and portals. For long battles, also check memory and resource
   growth. Keep results only if behavior and appearance remain correct.

Use `/Users/eric/Desktop/Edit Goemon.command` to edit this same project. After
native C++ changes, rebuild with `./native/terrain_math/build.sh` while the game
is closed, then refresh imports. The Play launcher refreshes changed imports.
An app export is needed only when the user requests a build or distribution.

## Where to check and reproduce

- Simulation and transfers: `native/terrain_math/crowd/`,
  `native/terrain_math/crowd_binding.cpp`, and `scripts/forest/crowd/`.
- Focused regressions in `tests/forest-shrine/`: `army_worker_test.gd`,
  `army_snapshot_consistency_test.gd`, `army_box_filter_test.gd`,
  `army_model_publication_test.gd`, `army_idle_poll_test.gd`,
  `army_instance_buffers_test.gd`, `army_projectile_buffers_test.gd`,
  `army_event_dispatch_test.gd`, and `army_cosmetic_terrain_test.gd`.
- Example focused check from the project root:

  ```sh
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/forest-shrine/army_model_publication_test.gd
  ```

- The foreground stress fixture is
  `tests/forest-shrine/large_army_benchmark.gd`. For a short diagnostic run:

  ```sh
  /Applications/Godot.app/Contents/MacOS/Godot --path . --always-on-top --script res://tests/forest-shrine/large_army_benchmark.gd -- --scenario=castle --per-team=240 --allies=96 --duration=20 --await-focus
  ```

  Its default output is `build/Other Files/Large Army Rebuild/Benchmarks/`.
  This fixed-camera stress scene differs from ordinary play. Its acceptance
  checks require active combat, maintained populations, no lost hits, matching
  simulation/wall time and foreground rendering, as well as frame-time limits.
  A 20-second run cannot establish long-session stability.

- Historical evidence: `docs/combat-map-performance.md`,
  `build/Other Files/Smooth Gameplay/Performance Report.txt`, and
  `build/Other Files/Large Army Rebuild/Execution/Native Engine Copy Decisions/optimization-report.json`.
  These cover different development stages. The October 22 report still failed
  its 2,000-enemies-plus-2,000-allies stress gates; it does not establish the
  performance of today's uncommitted source. Preserve that distinction.
- Run `python3 tools/goemon_assets.py check` after source changes, and the
  relevant preservation/import/motion/render checks when assets change.

## How to teach this in future work

Explain each change as: **what repeated work caused the delay → what we changed
→ what measurement and gameplay check show**. Define technical terms when they
first matter. Teach from the actual scene and evidence, one bottleneck at a
time. The reusable habit is: measure, remove redundant work, preserve behavior,
then measure and play again.


## Skullpion castle pattern example (2026-10-23)

### Barracks spawn clearance fix (2026-10-23)

The four Wind Meadow barracks admitted Skullpion 24 metres from their centres.
His native movement radius is 18 metres and each barracks extends 8.5 metres
from its centre, plus the existing 0.05-metre collision margin. Those starts
overlapped the native solids, so movement correctly refused every step: all four
bosses travelled zero metres in a fresh 20-second simulation probe. This was a
spawn correctness defect, not a measured frame-time bottleneck.

`forest_enemy_navigation.gd::move_clear` now checks the same live camp boxes
already supplied to native navigation. The existing boss spawn fallback chooses
a clear point 30 metres from the barracks centre. No boss size, speed, counts,
combat timing, native movement or artwork changed. Keep new map solids consistent
between spawn clearance and native navigation; testing only a boss already beside
the castle misses this failure.

The corrected probe moved all four simultaneous bosses 34.29–34.78 metres in
20 seconds. The desktop launcher also rendered their departure in the actual
painterly scene. Evidence and before/after logs are under
`build/Other Files/Asset Toolkit/Skullpion/Movement/`. Repeat with
`Play Goemon.command --script res://tests/forest-shrine/skullpion_spawn_test.gd`;
normal play should show the boss leaving the barracks after arrival. This is a
focused movement check, not a fresh full-army performance or long-session result.
Fresh checks: desktop spawn/movement 24, boss combat/presentation 72, wave roster
30 and camp gameplay 18 pass; asset preservation passes. The final focused run
and diagnostic repeat had stable node/resource counts; an earlier scene-wide
resource check fluctuated and is retained in `initial-resource-check.log`, so
these short checks do not establish leak freedom. Existing camp/roster shutdown
resource diagnostics remain. No assets were exported and no app was built.

### Historical castle pattern checks

The castle-first pattern keeps movement, jump gravity, landing and attack order
inside the existing native army owner. It reuses the recovered animations,
existing projectile batches, owned effects and four audio voices. Castle-face
searches run at most once per 0.75 seconds while seeking; active movement reuses
the selected face and current native state. This avoids adding per-frame model
loading or a second script physics simulation.

Fresh focused evidence is in
`build/Other Files/Asset Toolkit/Skullpion/Pattern/`: three repeated cycles per
castle side on both authored castle maps passed, as did native simultaneous-boss
checks. A short rendered three-boss diagnostic had stable node/resource counts;
native-step p99 was 0.650 ms. Rendered frame p99 was 21.852 ms versus 20.550 ms
for the earlier climb/descent behavior. The new jump/landing/attack workload is
different, so this is a cost check, not evidence of a frame-rate improvement or
of full-army/long-session performance. Use the saved JSON and fixture to repeat
that comparison before extending the pattern further.

## Soldier light polish (2026-10-23)

The user selected the light Blender polish for the three ordinary soldiers.
Their narrow bevels increase each model from 356–390 to 2,916–2,998 triangles;
the shader now uses scene lighting so those surfaces are visible. The potential
cost is additional geometry and lighting, not a measured new simulation
bottleneck. Keep the native army owner, original STEP motion and shared pose
textures. The final GPU bake groups the approved models into three surfaces per
type, with no per-soldier skeleton, model loading or material creation in combat.

Fresh evidence is in `build/Other Files/Asset Toolkit/Soldier Polish/`.
The matched 20-second castle tests used 240 enemies and 96 allies at 1280×800 on
Apple M3, with both windows focused throughout, normal stats, maintained
populations and zero dropped hits. Average frame time was 16.790 ms before and
16.663 ms after; p95 was 18.383 → 18.043 ms and p99 27.122 → 18.701 ms. This
supports no observed slowdown in this short test; it does not establish an FPS
improvement, larger-army capacity or long-session stability. GPU timing was
unavailable. An earlier after-run lost foreground focus and is excluded from the
comparison. These are current results, separate from the user's earlier report
that general gameplay feels smooth.

All 77 original clips retain exact exported animation samples, skin binds and
texture bytes. Imported motion, batching and combat checks passed, and the
native renderer captured idle/run/attack samples from four angles in the
painterly world. Editable sources and their non-destructive exporter are
documented in `assets/blender/enemies/thirstquencher/README.md`. After later
source exports, rebuild the reviewed derivatives and soldier runtime resources;
repeat the same foreground battle before claiming performance is preserved.

## Recovered Vambee and Haya Wolf (2026-10-23)

These enemies reuse the native Unit, attack phases, local queries, hit events,
GPU pose textures and existing corpse/effect/audio pools. Compatible future
enemies add registry and attack-profile data, then use the same Blender exporter
and offline pose bake. Vambee changes into its crawling form in the same native
slot. No per-unit skeleton or combat-time asset loading was added. This avoids
repeated setup work; it does not identify a new measured bottleneck.

Fresh desktop evidence is in
`build/Other Files/Asset Toolkit/Vambee and Haya Wolf/VALIDATION.md`.
The same painterly map/camera ran 240 enemies and 240 inert native targets,
comparing the prior three ordinary types with the five-type mixed roster. Each
used 90 warmup frames and 300 measured frames with repeated simultaneous attacks
and normal pooled presentation. Frame p95 was 16.667 ms in both; p99 was
16.667 → 18.056 ms. Native-step p95 was 0.423 → 0.500 ms and p99
0.593 → 0.591 ms. Both had zero measured node/resource growth. Background
applications were uncontrolled, so these are short cost checks, not evidence of
an FPS improvement, long-session stability or 2,000-versus-2,000 capacity.

To verify later edits, export the saved Blender master, refresh imports, rebuild
the shared pose bake, run the source/motion/contact checks, then repeat
`Play Goemon.command --script res://tools/capture_recovered_monsters.gd`.
Check visible kick/grab timing and the crawling form as well as frame times.
Keep the workbench at 30 FPS: changing FPS after import retimes the motion.
The exporter preserves exact recovered geometry when its fingerprint is
unchanged, avoiding Blender normal/color quantization; intentional geometry or
paint edits export the saved artist mesh. See `docs/recovered-monsters.md`.

## Separate wave settings and retired enemy assets — 2026-10-23

Wave counts now select each current enemy independently, including the crawling
Vambee form and Skullpion. Barracks repeat the selected Wave 1 mix. Selection
and migration happen during setup; spawning reuses the same native owner and
preloaded pooled presentation. Active caps and spawn cadence are unchanged.
Retired Daruma/forest exports no longer load during startup or portal validation.

Fresh checks cover exact per-type counts, exclusion, multiple bosses, saved
settings, camp repetition, native monster attacks, map editing and rendered menu
layout through the desktop launcher. No new bottleneck was measured and no new
long battle benchmark was run. Historical timing figures above do not certify
custom mixes: many large bosses may cost more than ordinary soldiers. The
existing large-army benchmark uses its canned roster, so record the actual mix
when profiling custom wave settings. Evidence: `build/Other Files/Asset Toolkit/Enemy Cleanup/`.


## Steerable extended chain pipe — 2026-10-23

At the user's request, Goemon can turn the chain during flight with his existing
aim. The tip stays at full extension for one extra second at normal attack speed;
the existing speed multiplier still scales the move. Original release, outward
travel, return and body poses remain. This extends the earlier Original Goemon
weapons entry above. Damage, reach and one hit per victim per throw remain the
same. A wall hit starts the return, including during a sideways swing.

The smallest change stays in the existing chain controller. Turning is bounded
to 360 degrees per attack second and subdivided by the existing 30 Hz trajectory
steps, so a sudden aim change follows a swept path. Contacts continue through
native local candidate queries and exact hit/cover checks. Models, chain links,
materials, effects and lifecycle cancellation are reused. The normal native NPC
roster does not cast this player chain skill; no second army path was added.

Fresh checks: steering 57 headless / 61 desktop Metal, original weapons 55,
weapon controls 28 and combat polish 22 pass; asset preservation passes.
They cover three native victims along an arc, unchanged damage, no repeat hits,
opposite aim, long updates, sideways cover, ground/air/landing, speed modifiers,
selection/focus/dodge cancellation and repeated use. The rendered launcher
fixture has 240 native enemies, with three near the swing. After warming the
same workload and letting transient effects expire, nodes stay at 4,076 and
resources at 1,301. Rendered captures were inspected for extension and steering.

A same-process headless comparison with 240 distant stationary native enemies
measured active chain-tick p95 of 0.039 ms before / 0.071 ms after. Whole-cast CPU
p95 was 0.884 / 7.925 ms, spread over a longer attack; the after-run maximum
single tick was 3.499 ms. Steering and the added second intentionally perform
more contact/ray work. No new frame-time bottleneck was established. These
focused costs and the desktop checks do not certify full-battle smoothness;
historical benchmarks elsewhere remain separate evidence.

Verify with `Play Goemon.command --script res://tests/forest-shrine/chain_pipe_steering_test.gd -- --visual`,
then press 3 in normal play and move the mouse across a group while the chain is
extended. Each enemy should react once; turning back should not repeat damage.
Keep target searches local if extending this move further. Evidence and the
before-change CPU reference are under `build/Other Files/Asset Toolkit/Chain Steering/`.
No app export or full-battle stress/long-session soak was performed. Existing
shutdown resource/RID diagnostics remain separate from the passing assertions.

## Playable spell portability audit — 2026-10-23

The 62 registered spells accept all 18 internal playable IDs (13 currently
visible in the gallery). Fresh headless and desktop Metal runs each pass 1,510
modular-spell assertions: every assignment, every spell on a foreign body, six
spell types on every body, and focused lifecycle/damage checks. This is not a
complete casting matrix or proof that every three-slot combination works.
Transferred spells retain the wearer's locomotion pose; full casting-body
animation retargeting remains a documented limitation.

Two rendered probes expose a first-use cost: the loadout constructs the spell
controller, hidden donor rig and prepared presentation inside the first input
call. Final Apple M3 timings were 36.540 ms for Ed's Beam, 47.883 ms for Ben's
Bomb Barrage and 107.776 ms for Magic Swordsman's Energy Wave. Five prepared
repeats had median input costs of 1.295, 0.253 and 0.104 ms respectively. These
are synchronous input-handler costs, not complete frame times. Background
applications were uncontrolled; the earlier probe also overlapped other checks.
The proposed smallest fix is to prepare the existing instances at equipment or
selection time, then verify the first rendered cast for additional shader costs.
No gameplay fix was made during this audit.

Correctness also needs attention: equipped Knight's Code on Knight applies its
50% defense twice, once in the loadout and once in the native character adapter.
Fresh probes reproduce 25 damage from a 100-damage hit versus 50 with the
original control. Apply the modifier once and test native and foreign wearers.
Musashi's D-Kick, Fence, Homing, Grenade and held 3-Way are absent from the spell
catalogue; exposing them must preserve their existing motion and release rules.

A 30-second foreground Wind Meadow sample with 240 enemies, 96 allies and ten
alternating Ed/Sasuke/Musashi casts started every cast and dropped no hit events,
but failed the performance and simulation-time gates (13.15 FPS, frame p95
136.244 ms). It does not establish the cause. Concurrent scenery work changed
the terrain resolution during the audit; forest_model.gd changed between the
spell run and its follow-up control. That control also lost foreground focus
and is excluded. Earlier attempts lost focus or encountered a transient missing
scenery import. There is no valid matched comparison or smoothness certification
from these runs. Repeat on stable source with uninterrupted focus before
attributing the battle cost to spells. Historical smoothness evidence remains
separate, and no long-session or other-hardware check was performed.

Evidence, reproduction scripts, source hashes and exclusions are under
`build/Other Files/Skill Compatibility Audit/`. Start with `REPORT.txt`,
`probe.json` and `battle-summary.json`. Exit-time resource/RID diagnostics remain.
Only diagnostic artifacts and this guide were added; no app was exported.

## Expanded Wind Meadow and four castles — 2026-10-23

The default valley now spans 960 × 960 metres of terrain, twice the old width
and depth. Four enemy castles reuse the starter fort's 102 × 78 metre perimeter,
wall heights, towers and raised gates; each contains the existing barracks.
Native army ownership, the 240-enemy cap, roster counts, spawn cadence and
controls stay intact. Four objectives keep the existing 600 HP each and victory
rule. Boss exits move to 72 metres from each centre; fallback arrivals now retain
their source camp and cannot use destroyed camps. Old saved valleys keep the
original terrain and barracks through their default `terrain_scale: 1`.

The expanded field retains 3-metre samples, with physics and native queries
using the same origin and data. Castle colliders supply both combat and native
obstacles; cached obstacle arrays refresh after destruction. Worker grids leave
the gateways open. Combat volumes sit 6 cm outside the masonry so a castle's
own solid cannot swallow a pipe/bullet hit. No enemy renderer or simulation was
added. Building assets, Blender masters, materials and animations are reused.

The initial expanded battle missed the frame limits (22.56 ms mean, 28.41 ms
p95). Its native simulation averaged 0.724 ms. Inspection found all 485 trees
in one map-wide MultiMesh batch, causing off-screen trees to be submitted with
visible ones. Trees now use the existing batching helper in 96-metre regions;
all tree transforms, meshes, materials, shadows and counts remain. Setup also
caches the immutable scaled road routes instead of rebuilding them for every
plant placement. These changes remove redundant setup/render work, without
reducing scenery density or army counts.

The final 20-second foreground Metal test on Apple M3, 1280×800, maintained
240 enemies and 96 allies with zero dropped hits and passed the existing
acceptance gates. Mean/p95/p99/max frame times were 17.31 / 22.00 / 32.51 /
174.68 ms; native simulation averaged 1.123 ms. The isolated stall remains.
The old-map comparison lost focus (80.4%), and `player.gd` changed concurrently
between the expanded pre/post runs. These are therefore a short final acceptance
check, not a controlled FPS-improvement claim or evidence of long-session
stability. GPU timing was unavailable. Earlier measurements in this guide do
not certify this expanded map.

Evidence, the map snapshots, source hashes, full battle reports and rendered
castle views are in `build/Other Files/Asset Toolkit/Wind Meadow/Castles/`.
The final valley suite passes 686 checks in both headless and desktop Metal runs.
Focused checks cover native routes from all four bases, large-boss departure,
real player gate clearance, pipe/bullet damage, destruction, victory, map
round trips, previous maps and preparation zoom. Asset preservation passes.
A concurrent Yae launch indentation error prevented parsing during an early
run; its three statements were restored inside their existing per-projectile
loop and the Yae gameplay check passed. A later concurrent Sonic model referenced
a missing export directory; its root now points at the existing recovered GLBs.
Earlier interrupted/error logs are not
acceptance evidence. Existing shutdown resource/RID warnings remain.

Verify using `Play Goemon.command --script res://tests/forest-shrine/wind_meadow_valley_test.gd -- --capture`,
then run `skullpion_spawn_test.gd` and the existing ground-camera army benchmark.
Keep the window focused and avoid concurrent source edits for timing comparisons.
The next performance change should measure the actual workload first; continue
sharing nearby tree batches and the existing native combat owner. No app export,
long-session soak or other-hardware test was performed.


## Recovered weapon and skill size — 2026-10-23

The user initially chose 3× larger weapons, projectiles and spell effects
for Sasuke, Yae and Musashi, using Goemon's readability as the reference.
After playing, they requested a 65% reduction of that result. The current shared
multiplier is therefore 1.05× the original (3 × 0.35). Character bodies remain
unchanged; all affected weapons, shots and spell/contact sizes share the revision.
`scripts/weapon_proportions.gd::RECOVERED_SKILL_SCALE` is the shared multiplier.
Sasuke's kunai/hair, ice/hail, bombs and charge effects, Yae's katana/shield,
bazooka/missiles, and Musashi's seven numbered skills use it. Body models and
editable assets remain unchanged. Source recovery fixtures can still request
original-size poses. Damage, event timing, travel speed, lifetimes and grenade
bounces remain the existing controller's responsibility. Enlarged contact/blast
areas intentionally reach more targets; this is a gameplay size change.

Projectiles apply their size to prepared visuals at launch, with fresh size on
every lease. Musashi stores effect units separately from travel units: borrowing
his spells on another fighter must not shrink their source-model presentation
or change the existing trajectory. His spin sweeps the whole enlarged blade so
nearby targets cannot fall inside a hollow tip-only arc. It uses the shared local
candidate query, then fitted contacts and cover checks. Yae's extended barrel
checks cover before spawning its missile. Ordinary native army kits do not cast
these player spells; the native simulation and army counts were not changed.

Fresh evidence is under `build/Other Files/Asset Toolkit/Weapon Scale/`.
The desktop launcher rendered the enlarged weapons, projectiles, trails and
explosions at the initial 3× setting with Metal/painterly scenery; 107 focused desktop assertions passed,
including body/hair preservation, growth, character switching, barrel cover and
repeated overlapping spell reuse without node/resource growth or pool misses.
The source combat/gameplay, reach, Musashi assimilation (78), charged actions
(40), rotation VFX (11), imported motion (25), shared systems (98) and optimized
asset preservation checks passed. The older `musashi_rotation_contacts_test.gd`
cannot run on current source because it writes the removed `low_fidelity` field;
that attempted fixture is not counted as passing.

A short same-process Metal comparison reused the saved pre-change assimilation
script and then the script at the initial 3× setting, firing the same repeated three-way volleys
at 1280×800. Both had 240/240 focused measured frames. Frame p95/p99 was
17.369/20.651 ms before and 18.781/21.665 ms after; skill CPU p95/p99 was
0.580/0.699 ms before and 0.521/0.751 ms after. Node growth was zero in both;
resources changed by +1 before and 0 after. Larger effects cover more screen
area. These short, capped measurements do not establish an FPS improvement,
full-army smoothness or long-session stability; background activity was not
controlled. No new frame-time bottleneck was established.

Intermediate desktop runs logged a missing Sonic model route from concurrent
work; that error was absent from the final 3× desktop verification. Existing
shutdown resource/RID diagnostics remain. No app was exported.

To verify later changes, use `Play Goemon.command --script
res://tests/forest-shrine/recovered_skill_scale_test.gd -- --visual`, then play
each fighter normally. Check close and distant spin contacts, a bazooka beside
a wall, growth/reset, and overlapping shots. Keep visual size separate from
speed and refresh size on every pooled launch; never multiply the previous
lease's scale or scale the entire character to enlarge equipment.

The user's later 65% reduction is now freshly checked at the final 1.05×
multiplier: desktop Metal 107 assertions, both native reach suites and 40
Musashi charged-action assertions pass. Projectile pools report zero misses;
body proportions, growth/reset and borrowed spell sizing remain correct.
Final-size captures and logs use `reduced-desktop.log` and `reduced-*.log` in
the same evidence directory. The timings above describe the earlier 3× version,
not the reduced version; no new long battle or app export was performed.

## Sonic recovery and character cost — 2026-10-24

Sonic now reuses the player body/controller contract, native army queries,
attack tickets, audio cache and skill loadout. His original rigid limbs and
retail seam welds were prepared as an ordinary GPU skin through the editable
Blender workflow. Only the visible body or spin ball evaluates animation.
Selection pays resource setup once; charge reuses one audio player, and hit
queries use the existing nearby snapshot. No enemy simulation, per-frame mesh
rebuild, asset loading loop or per-unit retargeting was introduced. Native army
counts, scenery quality, terrain and portals were not reduced for this change.

The measurable asset cost was 28 mesh instances with 42 surfaces. The smallest
fix was the existing lossless optimizer: one mesh with 10 surfaces, preserving
all 1,993 triangles, texture bytes, joints and original motion samples. The
rendered imported comparison measured 42 versus 10 draw calls with matching
appearance across 96 image pairs. This is a draw-work reduction, not an FPS
improvement claim. The remaining materials preserve the original art.

The initial integration snapshot passed 40 assertions headless and on desktop Metal;
Sonic's staged and packed motion checks each passed 27,159 assertions. Repeated
skills retained their existing nodes and bounded resource ownership. Castle
contacts, native enemies, walls, borrowed skills and cancellation were checked.
See `docs/recovered-sonic.md` for recovery, fidelity limits and the other checks.
These results are separate from the user's earlier report that general gameplay
felt smooth and from the historical army stress measurements in this guide.

A short 1280×800 Apple M3/Metal test compared Goemon and Sonic on the same idle
battlefield with world simulation paused only in the fixture. Each sample timed
180 rendered frames and one explicit Hero physics step per frame; that CPU
measurement excludes AnimationPlayer evaluation and rendering. The first fully
focused pair measured Hero CPU p95 0.832 ms for Goemon and 0.965 ms for Sonic;
frame median/p95 was 16.707/19.509 ms and 16.630/21.120 ms respectively. Resource
count changed by zero during all four measured samples. A later Sonic sample
lost focus for 24/180 frames and is excluded from comparisons. Whole-frame
spikes occurred in both fighters, background load was not controlled, and no
new simulation bottleneck or full-army smoothness certification was established.
Exit-time resource/RID warnings remain. No long-session soak was performed.

Evidence: `build/Other Files/Asset Toolkit/Sonic/profile.json`,
`gameplay-desktop.log`, `verification-source-hashes.json`, and
`Imported Comparison/comparison.json`. Final tracked verification inputs did
not change during the desktop run. An earlier elevated-platform fixture made
camera targeting unreliable; it was corrected to use the actual terrain height.
An artificial legacy building fixture was replaced with a real castle target.
Those intermediate failures are not acceptance evidence.

To verify a future Sonic change, run `Play Goemon.command --resolution 1280x800
--script res://tests/forest-shrine/sonic_gameplay_test.gd -- --profile`, then play
Sonic normally from Q. Repeat Spin Dash, jump/homing, wall collisions and castle
hits. Keep the window focused and close competing exports/capture tools before
comparing timings. Preserve the Blender master and source clip duration, rebuild
the derivative after asset edits, and review imported movement before activation.
Do not treat the recovered parameter table as proof of identical SADX physics:
Goemon still owns contact, damage, camera and world rules.

## Portable skills and playable enemies — 2026-10-24

The user's earlier report that normal gameplay felt smooth remains the gameplay
baseline. The following checks are fresh, focused evidence for portable skills
and eight selectable enemies; they do not re-certify older stress tests.

The measured first-input bottleneck was constructing donor controllers, rigs
and effects during the cast. Equipment/character selection now prepares only
the assigned spell runtimes (at most three distinct slots). Input starts those
prepared controllers. Removing a spell retires its controller while retaining
its remaining cooldown. Ed's beam and companion shield reuse the existing
projectile pool; their per-cast clocks, references, audio and visibility reset,
while the original persistent native phase state remains intact. Selection may
still pause briefly while a previously unused model is prepared.

The same focused desktop Metal/M3 probe measured Ed's first input at 2.965 ms
(previous audit: 36.540 ms), Ben's bombs at 0.407 ms (47.883 ms) and Energy Wave
at 0.161 ms (107.776 ms). These are input-handler CPU timings, not whole-frame
GPU times or a controlled FPS comparison. The intermediate change that only
prepared controllers still left a 46.603 ms Ed beam setup; preparing and reusing
the beam/shield removed that remaining cold construction. The original beam
phase, damage and impact suites passed 21, 61 and 12 assertions respectively.

Correctness fixes: Knight's Code now reduces damage once on Knight as well as
foreign wearers (100 becomes 50). The catalog includes Musashi's missing D-Kick,
Fence, Homing, Grenade and 3-Way abilities. Transferred D-Kick uses the existing
Musashi movement clock; release clears the original held state. At the
focused-check snapshot the catalog had 69 skills and 27 stable playable IDs
(22 visible); subsequent parallel character/skill additions change those counts.

New enemy fighters use Hero/CharacterCombat and the shared skill, contact,
projectile and audio systems. Their ordinary models reuse the existing pose
atlases; Skullpion reuses his existing animated visual. NPCs remain native army
actors. Skullpion keeps the enemy boss's full scale, fitted collision, widened
camera and native incoming-hit bounds. Existing ordinary fighter contact rules
remain unchanged. See `docs/recovered-monsters.md` for controls and animation
reuse limits. No Blender originals, pose bakes or optimized model derivatives
were changed for this adapter.

At that snapshot, clean headless checks passed: modular skills 2,339 (every assignment combination,
every spell on a foreign body, six representative casts on every fighter), shared
character systems 130, and native target decisions 8,613 plus focused large-body
melee/projectile assertions. The native extension was rebuilt for both macOS
architectures. Optimized asset preservation checks passed. Headless results
establish logic coverage only. Exit-time resource/RID diagnostics remain, so
these runs do not establish leak-free shutdown or long-session stability.

Rendered enemy verification through the desktop launcher subsequently passed
238 assertions on Metal, including the newly registered Dark Lumina 2 body,
full-size Skullpion movement away from castle walls, camera framing, attack
contacts, casting gestures, switch-back collision and pooled reuse. The original
native fitted-target regression passed 2,410 checks; native Skullpion encounter
checks also passed. `skullpion-gameplay.png` shows the actual player camera.
The later gallery regression passed 167 assertions on the expanded roster;
final optimized-asset preservation checks also passed.
After the transient pose/profile errors cleared, a fresh rerun passed all
3,040 modular-skill assertions and 144 shared-system assertions without script
errors (`spells-current.log`, `shared-current.log`). These supersede the failed
intermediate broad run below, while the performance comparison remains pending.

Full-army performance is **not certified on the combined latest source**.
The first 240-enemy/96-ally control measured 49.18 FPS, frame p95/p99
30.61/81.99 ms with focus and stable inputs, before the final large-body changes.
A later control measured 59.46 FPS and 19.07/22.40 ms, but player/loadout files
changed during it. Neither establishes a matched improvement. The repeated-spell
comparison was invalidated by a temporarily missing Sonic effect script; do not
use its FPS as acceptance evidence. Other active chats were changing player,
skill, native ABI and asset inputs and running simultaneous render/bake tools.
A later broad run reached 3,040 assertions without assertion failures but logged
native pose/profile errors during concurrent edits, so it is not a clean pass.
Repeat the full comparison once the shared source settles; retain army counts,
painterly rendering, foreground focus and source-hash checks.

Two parallel enemy additions referenced missing runtime pose resources during
verification. Their existing bake tool regenerated only `dark_lumina_2` and
`dark_lumina_3` from the existing authored assets; originals were not changed.
The read-only asset audit reported no read errors. Those repairs do not replace
the separate recovery/motion acceptance checks owned by their character work.

Evidence lives in `build/Other Files/Playable Enemies/`. For later verification,
run the focused `playable_enemies_test.gd` through `Play Goemon.command`, then
select the new fighters through Q. Check movement, primary attacks, E/R/T,
release/cancel, switching characters and full-size Skullpion near walls. Keep
resource preparation on selection and retain local fitted hit queries; do not
add per-enemy live skeletons or runtime retargeting to the native army.

## Musashi fixed outfit and smaller body — 2026-10-24

Musashi now always starts in his latest full-equipment outfit (mask 31). The
gallery outfit picker and saved-outfit override are removed; recovered texture
variants remain available to the asset comparison tools. Old saved preferences
are ignored without deleting user settings. `character_proportions.gd` changes
his existing size multiplier from 3.0 to 2.55, exactly 15% smaller. The same
contract scales his capsule, camera anchor, reach and source-space travel;
animation clocks, damage and cooldowns remain unchanged. No new runtime work
or performance bottleneck was introduced or measured by this settings change.

Fresh assertions pass for size/native contacts (18), physical movement (13),
finisher (32), assimilation/repeated skills (78), outfits (98), and controls/
old-save/gallery behavior (38 headless and 38 desktop Metal). Asset preservation,
toolkit unit/import and structure checks also pass. The desktop captures show
the full outfit and removed menu option. Concurrent Dark Lumina setup errors
appear in several scene logs, including the desktop run; these are focused
Musashi results, not a clean whole-game or performance certification. Existing
shutdown resource diagnostics remain. Evidence and exclusions are recorded in
`build/Other Files/Asset Toolkit/Musashi Appearance/RESULTS.txt`.

Verify through `Play Goemon.command` by choosing Musashi from Q, moving,
double-jumping and attacking, then switching away and back. For automated
rendered checks, use `--script res://tests/forest-shrine/musashi_recovery_controls_test.gd -- --visual`.
No new benchmark, long-session soak, asset export or app build was performed.


## Ranger universal Rapid Shot — 2026-10-24

Ranger now has T · Rapid Shot: tap or hold for ten simultaneous arrows every
0.25 seconds across the existing approximately 55-degree fan. Q → Equip spells
can assign `ranger/rapid-shot` to any fighter's E, R or T. The original five-arrow
secondary, primary third-shot rhythm, native allied Ranger kit and army counts
remain unchanged. Rain powers the new volley. Base per-arrow damage remains
25, or 38 with Rain, through the existing wearer's damage and contact rules.

This reuses the existing fan launcher, flight variation, local native contact
queries, attack tickets, audio and arrow pool. Ten arrows share one launch cue;
no new simulation, renderer, model, retargeting or per-arrow asset loading was
added. Native Ranger uses his existing bow pose; borrowed skills retain the
receiving fighter's existing presentation contract. Holding the skill takes
priority over ordinary primary fire; release, dodge, selection and focus loss
clear held state. Each volley keeps its own hit history and ticket.

The repeat fixture reaches thirty overlapping arrows. The old preparation
count of 24 would not cover that workload; setup now prepares 32 arrows of
each Ranger variant within the existing 64-idle-arrow limit. Six seconds of
continuous ordinary fire used only prepared arrow nodes. Both measured desktop
samples had zero node and resource growth after warmup. This is a bounded
short repeat check, not proof for every growth/powerup/loadout combination.

The desktop launcher/Metal run passed 229 focused assertions, including native
and borrowed input, every then-registered playable body, ten fitted native
contacts, solid cover, Rain, hold/release/interruption, two assigned keys sharing
one spell, cooldown preservation and pooled reset. The existing five-arrow pose
regression passed 17 checks after correcting its fixture to read native-owned
HP and exclude pool checkout generations from geometry comparisons.

A 1280×800 Apple M3 sample compared five and ten arrows at the same 0.25-second
cadence with world simulation paused only in the fixture. Both had 180/180
focused frames. Frame p95 was 17.979 / 19.433 ms, skill-plus-effect CPU p95
3.886 / 5.841 ms, and maximum frame time 26.554 / 207.320 ms. Concurrent imports,
headless tests and character edits were active; some recorded source hashes
changed during the run. These are diagnostic observations, not a controlled
before/after comparison, an FPS improvement, or a smoothness certification.
No stable frame-time bottleneck was established. The earlier user report of
smooth gameplay and historical battle measurements remain separate.

Evidence is under `build/Other Files/Asset Toolkit/Ranger Rapid Shot/`, including
`desktop.log`, `profile.json`, `rapid-shot.png` and verification-input hashes.
Earlier attempts overlapped native rebuilds and unfinished character assets;
they are not acceptance evidence. The rendered run still logged the concurrent
missing Dark Lumina 2 portrait; existing exit-time resource/RID diagnostics
remain. No asset export, app build or long-session/full-army stress test was
performed for this skill.

To verify, run `Play Goemon.command --resolution 1280x800 --script
res://tests/forest-shrine/ranger_rapid_shot_test.gd -- --visual`, then select Ranger
in ordinary play, tap/hold T, release, dodge and try Rain. Equip Rapid Shot on
another fighter through Q. Keep the window focused and stop competing build/test
work before comparing frame times. If a larger ranged workload starts allocating
arrows, measure its maximum overlap and prepare the existing pool at selection;
do not rebuild meshes in the firing loop or reduce the ten-arrow volley.

The later whole-catalog regression was not accepted despite zero failed
assertions: it overlapped unfinished Sonic effects and Dark Lumina 3 controller
edits and emitted parse/runtime errors. Its output is retained in
`modular-spells.log`; do not describe the whole catalog as freshly passing.
The focused Rapid Shot input also accepts a new hold during its short cooldown,
so holding again resumes at the next allowed volley rather than requiring
another press. The internal action still enforces the 0.25-second interval.

The last focused headless attempt reached 234 assertions with none failed, but
concurrent Dark Lumina mesh/collision data and portrait errors remained. It is
not a clean whole-project acceptance run. Preserve the earlier desktop evidence
and repeat the full regression after those independent asset changes settle.

## Knight Royal Lion Rush — 2026-10-24

Knight's unused T slot now gathers energy for 0.8 seconds and releases a
shield-blue lion at 60 m/s for five seconds. It deals 360 base damage once per
victim, with a 22-strength native push and a 14-second cooldown. It follows
terrain/bridge surfaces on a fixed horizontal heading and stops at solid cover.
Existing saved T assignments take precedence; the spell picker can restore or
lend the move. Normal RMB guard, E/R abilities and the four sword swings remain.
Native army Knights retain their existing kit; this is a player/loadout spell.

Selection prepares two lions in the existing character projectile cache. Each
lease resets direction, position, age, size, damage, hit history, animation and
caster/ticket references. The native local query supplies candidates, followed
by swept fitted contacts and cover checks, so a fast shot cannot jump over a
victim. Charge reuses the fitted shield-bracing pose without granting defense.
The spirit reuses Iwa's quadruped skin and authored motion in a separate editable
master; the original dog is unchanged. Its model has 12,890 triangles, one
surface and 24 deform joints, with no runtime retargeting or per-cast model load.
See `assets/blender/vfx/knight_lion/README.md` for editing and export commands.

An artificial repeated-cast check initially accumulated 54 transient impact
nodes while the fixture's cosmetic clock was stopped. This was not proof of a
live-game leak. The smallest change was to rely on the native pooled hit flash
and damage numbers instead of adding generic impact geometry per lion victim.
Final repeated casts kept node/resource counts unchanged and had no pool misses.
No new full-battle CPU bottleneck was established, and army counts/art were not
reduced. Keep sweeping short local segments and preparing effects at selection
when extending this skill.

Fresh evidence under `build/Other Files/Asset Toolkit/Knight Lion/` includes
32 headless lion checks and 30 desktop Metal lion checks (the two extra headless
assertions check RMB raise/release), 33 native Knight checks, 68 fourth-swing
checks, 46 toolkit unit tests, 12,812 imported asset checks, 98 Musashi outfit
checks and 86 structure checks. Asset preservation passes. Source animation
curves retain their recorded hash; exported motion differs from the donor by at
most 0.000000976, and bind matrices by 0.000000238, from float32 export rounding.
The final desktop lion run has no script errors. Earlier attempts during other
character edits had missing boss resources or parse errors and are excluded.
The old `knight_held_guard_test.gd` stopped on its obsolete `hit_actor.bar.visible`
assumption (native enemies no longer create that bar); do not count it as passing.
Shutdown resource/RID diagnostics remain separate from passing assertions.

The final small paused-world Metal fixture alternated 180 idle / 180 active-lion
frames twice at 1280×800 on Apple M3, with all 720 measured frames focused.
Frame p95 was 17.608 / 17.203 ms, then 17.055 / 17.975 ms. Active projectile CPU
p95 was 0.207 and 0.212 ms; resource growth was zero in every sample. These are
short incremental skill-cost measurements, not an FPS improvement, full-army
smoothness certification or long-session soak. Background activity was not
isolated. Earlier focus-losing samples are excluded. The user's historical
smoothness report remains separate evidence.

Verify through `Play Goemon.command --resolution 1280x800 --script
res://tests/forest-shrine/knight_lion_test.gd`, then select Knight and tap T in
normal play. Look for the brief shield-braced charge, running blue lion, one hit
per victim, forward recoil and cover stopping the shot. Dodge during charge,
repeat after cooldown, and confirm ordinary sword/guard controls still work.
No app export was made.

The current Wind Meadow field check also drove the real T input, native targets
and ordinary terrain: all three lane targets took damage and no lion remained
after its lifetime. `field-charge.png`, `field-rush.png` and `field-lion.png`
show the actual field. An initial desktop field run also encountered a transient
missing `origin` declaration in concurrent Dark Lumina work; the subsequent
headless field run has no script errors. That independent declaration is now
present. The final charge-ring placement surrounds the wearer for visibility
from the rear camera; projectile motion and the measured released-lion workload
are unchanged. No clean full-battle performance claim follows from these checks.

## Magic Swordsman purple energy — 2026-10-24

His sword swings now reuse Musashi's `lumina_swing.wav`; Energy Wave reuses
`lumina_rotation.wav`, the sound actually triggered by Musashi's Mighty Strike
counter. The existing SoundLibrary resolves both move and legacy slots, retaining
recordings, gain, mute, bounded voices and source pitch. Other fighters sharing
those event names keep their own defaults. No new audio files are loaded in combat.

The existing blade ribbon and two prepared wave surfaces now have a broader
purple band, dark core, white-violet edge and moving filaments. An owned shader
parameter confines this treatment to Magic Swordsman; other palettes keep it off.
Reduced flashes still lower emission. Reuse clears the old wave clock and pose.
Authored bodies, weapons, motion, damage, timing, travel and hit queries remain
unchanged. No Blender export, pose rebake or optimized model rebuild is required
for these material/procedural-effect changes. The native ally roster does not
include this fighter; testing uses real native victims and overlapping player
waves, without adding a second army implementation.

Fresh focused checks: 239 headless and 242 desktop Metal assertions pass, including
all three swing sounds, preview/recording/mute behavior, real blade-tip tracking,
three repeated piercing casts, unchanged 100 damage, 22 m/s speed, 2.5 m half-width,
expiry, eight overlapping effects and 100 prepared reuses. The desktop fixture
has zero node/resource growth during its 240-frame overlap sample. Asset
preservation passes. These are focused checks, not a fresh full-army or long-soak
result. No new CPU bottleneck was established and no smoothness gain is claimed.

Musashi audio passed 43 checks on repeat; its initial contact assertion failed.
The broader weapon-audio suite retains one Kojiro contact-preview failure, also
reproduced using the saved pre-change SoundLibrary in memory. An intermediate
headless attempt encountered a concurrent Dark Lumina script parse error and is
excluded; the final focused headless run is clean. Existing shutdown resource/RID
diagnostics remain separate from the passing assertions.

Evidence: `build/Other Files/Asset Toolkit/Purple Energy/`. Run
`Play Goemon.command --resolution 1280x800 --script res://tests/forest-shrine/magic_energy_test.gd -- --visual`,
then try the three sword cuts and RMB Energy Wave in normal play. Listen for
Lumina's swing and Mighty Strike's release, look for the violet-white crescent,
and confirm one hit per enemy plus ordinary cooldown/range. Keep the same
prepared surfaces and per-material flag for later revisions. No app was exported.
The final desktop field rerun (`field-final.log`) is also free of script errors:
three targets damaged, zero remaining lions, with the final surrounding charge
rings and painterly scenery visually reviewed. Existing shutdown diagnostics
remain. Captures now reflect this final rerun.

A same-process Apple M3/Metal comparison at 1280×800 rendered eight old waves
and then eight updated waves, using the saved pre-change effect factory/shader
and a fixed independent camera. Each used 90 warmup and 240 measured frames,
full foreground focus and identical logged camera transforms. Frame median/p95/
p99/max were 16.663/17.179/17.889/18.379 ms before and
16.655/17.382/19.412/20.294 ms after. Both had zero node/resource growth.
The p95 difference was 0.203 ms in this short capped sample; it does not establish
uncapped GPU headroom, a full-battle result or long-session stability. Other
chats were active on the machine. Earlier moving-camera/focus-invalid comparisons
are retained as `camera-invalid-*` and excluded; use `comparison.json` and its
matching screenshots for the final pair. Historical army measurements above do
not validate this effect change.


## Kojiro: prepared rigid motion and shared effects (2026-10-24)

Kojiro is player ID 28 and a donor to the existing spell equipment system. He
uses the shared player controller, native army queries/damage, character audio
bank, projectile pool and leader trail. He does not add a second army simulator.
The editable source and rebuild instructions are in [recovered-kojiro.md](recovered-kojiro.md).

The actual integration fault was a coordinate-scale error: Godot wraps the ROM
root, so reading the outer scale launched effects 100 times too far. The smallest
fix was one source-coordinate helper using the inner root. A focused assertion
now guards that scale. The model remains 500 triangles. Lossless optimization
keeps all fifteen animated parts and twenty surfaces while reducing duplicate
materials from twenty to four and vertices from 1,500 to 445. The source geometry,
texture pixels and motion are preserved; no automatic decimation was used.

The initial integration used 180 prepared Kojiro projectile/effect leases. Its
rendered fixture reported zero pool misses, including overlapping homing casts,
and stable pool size through repeated lease/reset checks. Static quad geometry
is shared; each effect owns its mutable animation material. The existing sword
trail now accepts an optional sampling interval: Kojiro uses 30 Hz and a 16-tick
lifetime, bounded to at most seventeen retained samples even on a 120 Hz display.
Other fighters retain their existing trail defaults.

Initial integration evidence, before the movement/pacing refinement below: the
desktop launcher on Apple M3/Metal completed 286 checks with
zero failures, zero focus losses and no script errors. The controlled idle CPU
probe reported p95 0.070 ms for Goemon and 0.086 ms for Kojiro, with zero resource
change in both samples. These are manually timed player/projectile steps; the
fixture renders initial attacks in real time and advances bulk lifecycle checks
with a controlled clock. They are not total frame times or an FPS improvement.
No stable performance bottleneck or full-army/long-session certification is
claimed. Background project work was not isolated. Earlier runs disturbed by
focus changes, concurrent incomplete scripts, or fixture survival are excluded.
The user's earlier report of smooth ordinary gameplay remains separate evidence.

Other initial checks: 46 asset-toolkit unit tests; 1,575 imported pose comparisons
for each of the authored and optimized models (zero position error, maximum
basis-component error 7.7e-9); 252 rendered source/candidate pairs with zero
pixel difference; 12,812 toolkit integration checks; 98 Musashi outfit checks;
86 structure checks; and 17 Ben slash checks. Existing exit-time resource/RID
warnings remain in the game test harness; zero growth during the tested workload
does not establish that all shutdown ownership is clean.

To verify manually, open Play Goemon, choose Kojiro with Q, use LMB on the ground
and in the air, E for homing, R for wind and RMB/T for the wave. Cast repeatedly,
try a wall, dodge during windup, switch fighters, then equip one of his skills on
Goemon. Inspect both appearance and response before increasing workloads. Keep
resource preparation on selection, the current local target queries and shared
pool reset rules. Evidence is in `build/Other Files/Asset Toolkit/Kojiro/`.

### Kojiro movement and attack pacing refinement (2026-10-24)

The user reported an odd run and slow attacks. ROM dispatch and sampled foot
paths showed that the forward-run label pointed at a lateral cycle. The fix
selects the existing forward run (`801e22a0`) and accumulates stride time per
step; the old `total_time * current_speed` expression jumped phases whenever
speed changed. No replacement rig, runtime retargeting or edited animation
samples were needed. Ground LMB now has two separately clicked sections from
the existing sword motion, with one buffered continuation and an expiring combo
window. The return section's damage contact is a player adaptation. All attacks
use 2× playback through the same combat and shared-skill controllers.

The measured allocation problem appeared when casts were repeated at their new
rate with an unobstructed three-second flight. The original wall-bounded fixture
retired shots early and missed this workload. The corrected probe observed peaks
of 18 homing shots, 132 sparks and 124 dust effects; the former preparation was
12, 96 and 48. Increase preparation only for those existing pools to 18, 144 and
128, retaining 12 wave and 12 wind leases. Kojiro now prepares 314 leases on
selection. Repeated attacks still reuse immutable geometry and owned effect
materials; there is no new effect renderer or reduced particle count.

Fresh final desktop evidence on Apple M3/Metal: **308 checks, zero failures,
zero focus losses and zero pool misses**, including eight back-to-back casts of
each special with full flight lifetime, native damage, walls, buffered clicks,
focus cancellation and skill donors. The fixture's 354 prepared leases include
40 existing coin leases. Idle resource deltas were zero; its manually measured
idle p95 was 0.086 ms for Goemon and 0.123 ms for Kojiro. This fixture explicitly
visits prepared pool entries, so those CPU timings are not complete game frame
times and do not establish an FPS regression or improvement. Highest stacked
attack-speed bonuses and full-army stress were not certified. Existing harness
exit-time RID/resource warnings remain separate from the zero live-growth result.

Also freshly passed: 56 toolkit unit tests; 1,575 imported pose comparisons each
for authored and optimized Kojiro (zero position error, maximum basis error
7.7e-9); 12,812 toolkit integration checks; 98 Musashi outfit checks; 86 structure
checks; and the active asset hash/preservation check. The Blender master and GLB
samples were unchanged, so no derivative rebuild was needed. Current captures,
logs and ROM movement/attack contact sheets are under
`build/Other Files/Asset Toolkit/Kojiro/Movement Review/`.

To verify the feel, use Play Goemon, select Kojiro, accelerate, stop and turn.
Tap LMB once, then tap again for the rising return; try an early buffered tap and
wait beyond the combo window. Repeat E/R/T and equip the same skills on Goemon.
Keep playback rates in the combat adapter, preserve numeric source actions, and
repeat the unobstructed pool probe whenever cast cadence changes.


## Sonic movement refinement and blue effects — 2026-10-24

This revision corrects movement fidelity, not a measured simulation bottleneck.
The previous adapter treated the source running threshold as a hard cap and
cut upward velocity when jump was released. The supplied disc's action routines
instead continue accelerating above that threshold, add lift while jump is
held, and preserve Spin Dash momentum into a jump. The adapter now follows
those rules, the source steering/braking, charge accumulation, and bounded
Homing Attack with its short miss recovery. See `docs/recovered-sonic.md` for
the source addresses and remaining differences in terrain/contact behavior.

The original blue trail and aura go through the existing editable Blender and
normal GLB export workflow. One controller prepares one aura and eight trails
once, reusing immutable meshes and two owned material overrides: at most 196
additional effect triangles. Frame updates only move, scale and hide them.
Borrowed skills use the same effects and clear their trails after completion;
Sonic's native and equipped Homing Attack share the airborne-use restriction.
The native army owner, counts, scenery, damage and local hit-query path remain.

To verify, run `Play Goemon.command --resolution 1280x800 --script
res://tests/forest-shrine/sonic_gameplay_test.gd -- --visual --motion-profile`, then choose
Sonic with Q and play normally. Compare tapping versus holding Space, build
speed with WASD, hold/release RMB or E, jump from a dash, and press Space again
or R in the air. Check the blue effect, a missed homing attempt, walls and
landing. Equip the same skills on Goemon and repeat. Keep the desktop window
focused; use the same workload and no competing render/bake jobs for timing
comparisons. Do not infer full-army smoothness from the paused-world fixture.


Fresh verification for this refinement: 58 focused assertions passed headless
and on desktop Metal; the shared skill suite passed 3,040 and movement
cancellation passed 106. The final desktop input hashes remained unchanged.
The asset preservation, imported motion, outfit and structure checks are
recorded in `docs/recovered-sonic.md`. Jump/charge/release captures were reviewed.

The final 1280×800 Apple M3 sample measured 480 rendered frames of repeated
full-charge Spin Dashes, with all 480 frames focused. The fixed effect owner
retained nine instances and resource count changed by zero during that sample.
One explicitly timed Hero physics step per rendered frame had p95 1.389 ms;
this excludes AnimationPlayer evaluation and rendering. Frame median/p95/max
was 16.678/28.911/171.833 ms. Background jobs were uncontrolled, and these
whole-frame spikes prevent a smoothness or FPS-improvement claim. The test
pauses world simulation/spawning only in its fixture; it does not establish
full-army performance. No new simulation bottleneck was isolated. The earlier
idle-character measurements above are historical and are not a matched control
for this moving workload or the current combined source.

Evidence: `build/Other Files/Asset Toolkit/Sonic/Movement/profile.json`,
`gameplay-desktop-final.log`, `gameplay-headless-final.log`, `skills-final.log`,
`movement-cancel.log`, `inputs.json`, `inputs-after.json`, and the three PNG
captures. Focus-interrupted intermediate attempts are excluded. Existing
exit-time resource/RID warnings remain; stable counts in this short sample do
not certify leak-free shutdown. No full-army soak or app export was performed.


## Assignable jump styles — 2026-10-24

Q → Skills & Jump → Jump Style now saves an optional movement choice per
playable fighter. Original keeps the character's native movement path. Choices
reuse Goemon's double jump, Chief's single jump, Dragoon's high jump/hover,
Ranger's double jump/glide, Musashi's source-timed double jump, Sonic's
variable-height jump and Ben's propeller flight. Borrowed styles retain the
receiving model's animations; no rig/asset transfer or runtime retargeting was
added. Sonic's own model can show its existing jump ball. Borrowing his jump
does not grant contact damage or homing; E/R/T and weapon attacks remain separate.
Ben's borrowed flight uses his existing rise, boost and descent constants.

The existing Hero body still owns collision and movement. One small movement
profile connects the shared, Rogue, Musashi and Sonic paths; combat-owned travel
keeps priority. Selection/equipment resolves settings and prepares source data.
Jumps reuse Sonic's actual vertical calculation and Musashi's source tick,
without loading assets, creating models/materials or adding army controllers in
the jump loop. Input buffers expire before controller delegation so a spent
borrowed jump cannot fire later on landing. Wall hops, jump budgets and native
army ownership remain intact. These are player loadouts, not new native NPC AI.

Fresh checks: 508 assertions pass headlessly and through Play Goemon.command
on desktop Metal at 1280×800, including every style on the current 30-fighter
roster, saved defaults, donor trajectory comparisons, held/repeated input,
ceilings, wall hops, native victims and separate homing. The existing spell
suite passes 3,040 checks, and asset preservation passes. After 20 warmup jumps,
another 20 leave node and resource counts unchanged after landing effects
retire. This is a focused repeat-use check, not a long-session leak guarantee.
The initial one/two-resource warmup increase is not represented as steady growth.

No new performance bottleneck was established. Optional frame-time samples were
affected by concurrent desktop work and focus changes; no FPS improvement or
full-army smoothness claim follows. An existing 30 Hz Musashi locomotion fixture
has one timing assertion failure on both the pre-change and current source:
its rate switch initially supplies 60 Hz steps. The literal source-tick checks
and same-body jump comparisons pass. Existing shutdown resource/RID warnings
remain. Interrupted desktop attempts are excluded; the final fixture isolates
scripted input from other desktop activity.

Concurrent work changed player.gd during the desktop run. A final 508-check
headless run verified the resulting source with all eleven recorded inputs
unchanged; see headless-source-hashes.json.

Evidence: build/Other Files/Jump Styles/{headless.log,desktop.log,summary.json,
measurements-desktop.json,verified-source-hashes.json,picker.png}. Repeat with
Play Goemon.command --resolution 1280x800 --script
res://tests/forest-shrine/jump_styles_test.gd -- --visual. In normal play, assign
Ben to another fighter, hold/release Space and add Shift; try Sonic with a tap
and a hold, then select Original. Attacks should remain on their existing keys.
No app export or full-army stress run was performed for this change.


## Playable Skullpion fast leap and sand primary — 2026-10-24

The user reported that Skullpion felt slow and requested a fast castle-clearing
leap, a heavy fall, sand blast as primary and a three-times-faster tail turn.
The relevant source delays were the shared 15.55 m/s jump / 30 m/s² gravity
and the 3.3-second tail sequence. This was movement and attack tuning; no new
rendering or army CPU bottleneck was established.

The smallest change stays in Hero and the existing recovered-enemy adapter.
Space and RMB launch at 160 m/s; directional air travel accelerates toward
260 m/s. Rising/falling gravity is 320/720 m/s². CharacterBody still sweeps the
full 30 × 25 × 40 collision box. Wall jumps retain their push-off recovery;
explicitly equipped jump styles retain their own rules. The first slower air
travel tuning touched the far castle wall, so acceptance now requires the
entire body to pass the far edge while airborne before the first landing.

LMB now uses the recovered sand plume/audio and original six forward damage
pulses. Unassigned E uses the tail sweep at a shared 3× animation/contact clock,
finishing in 1.1 seconds. Equipped E spells still take priority. RMB keeps jump
stomp, with one hit on actual physical landing and 0.2 seconds of recovery.
Prepared effects/audio, local native queries and existing hit tickets are reused;
there are no new combat-time asset loads, meshes, materials or army owners.
Native NPC patterns, counts, scenery and authored assets remain unchanged.

Fresh focused desktop Metal checks through Play Goemon.command passed 31
assertions with unchanged recorded runtime inputs. They cover native enemy
sand damage, six pulses, direction/cover, exact tail timing and visible rotation,
cancellation, repeated reuse, jump/stomp/wall-hop motion, a complete crossing of
the real Wind Meadow enemy castle, custom jump/spell overrides and switching
back to Goemon. The measured flat-ground leap rose 41.23 m and returned in
0.90 seconds. Twelve repeated sand/tail pairs had zero resource-count growth
and retained the same presentation nodes. The fixture's Hero-step CPU p95 was
2.369 ms; this includes mixed actions and is not whole-frame timing, a matched
before/after comparison or proof of full-army smoothness. Other chats were active.

Asset preservation, 54 toolkit unit tests, 12,812 imported checks, 98 Musashi
outfit checks and 86 structure checks passed. The broader playable-enemy suite
reported 246 checks with two failures for Dark Lumina 3 movement/attack behavior;
it is not a clean whole-roster pass. Earlier focused runs with wall-touching
travel or a concurrently rebuilt native library are excluded from acceptance.
Exit-time resource/RID diagnostics remain; no long-session leak claim is made.

Evidence: build/Other Files/Asset Toolkit/Skullpion Controls/desktop.log,
desktop-results.json, sand-blast.png, tail-sweep.png, castle-leap.png and the
asset/regression logs. Re-run Play Goemon.command --resolution 1280x800 --script
res://tests/forest-shrine/skullpion_controls_test.gd. In normal play, select
Skullpion with Q, hold a direction and tap Space across a castle, then try LMB,
RMB and E. Keep E unassigned and Jump style set to Original to test these native
controls. Preserve the full collision body, contact counts and resource reuse
when tuning the four leap constants or the tail clock. No app export or new
full-army stress test was performed. The user's earlier smooth-gameplay report
and historical measurements elsewhere in this guide remain separate evidence.

After the accepted desktop run, another change updated only Kojiro’s control-hint
wording in player.gd. Reversing that text in memory reproduced the verified
SHA256 exactly; no player motion or combat code changed. That review is saved
in Skullpion Controls/post-verification-review.json.

## Playable Skullpion fast Poison Drill — 2026-10-24

The user requested direct control, very little delay and a tail drill aimed at
the closest enemy. The existing encounter's first drill contact was at 1.9 s;
the whole sequence took 4.67 s. This is a verified action-delay issue, not a
newly established CPU or rendering bottleneck.

Unassigned R now starts the existing Poison Drill through the recovered-enemy
adapter. A 10× attack clock puts contacts at 0.19/0.28/0.37 s and completion at
0.467 s, before existing attack-speed modifiers. Each contact queries the current
native local candidates for the nearest living, visible ground enemy within
125 m and checks cover and the actual ground surface. Deaths can retarget later
strikes; misses, cancellation and character switches clear presentation. The
original 19 m ground area, 65% damage per strike and 55% movement speed for four
seconds remain. Equipped R spells retain priority; this native drill starts on
the ground. NPC patterns and wave counts were not changed.

Rendered review caught that the recovered body clip buries the tail at 3.7 s,
after the encounter's first hit marker. The player model now remaps that same
prepared clip so burial coincides with the first contact and recovery follows
the final hit. No authored animation, mesh, material or pose bake was changed.
Drill, particles and audio reuse the existing initialized presentation; no
combat-time resource loading, scene construction or new army owner was added.

Fresh final desktop Metal validation through Play Goemon.command passes 24
focused assertions, including the buried tail pose, nearest/behind targeting,
three exact contacts, native poison slow, area/air/cover/range checks, retargeting,
misses, cancellation, equipped-R priority and switching fighters. The final
Wind Meadow capture shows the tail underground and the original drill emerging
beside its victim. Twelve repeated casts retained all presentation nodes and
had zero resource-count growth. Attack-plus-model CPU step p95 was 2.012 ms in
this small fixture with the army paused; this is not whole-frame timing,
before/after profiling, or evidence of full-army/long-session smoothness.
All recorded runtime inputs remained unchanged throughout the accepted run.

Fresh headless checks also pass: 24 drill, 31 existing Skullpion controls (including
the full-body castle crossing), 72 NPC boss, 56 toolkit unit, 12,812 imported,
98 Musashi outfit and 86 structure assertions. Asset preservation passes. The
NPC test's outdated assumption that Skullpion was the last enemy type was fixed
to exclude his actual type when counting ordinary troops; no production wave
logic changed. Existing shutdown resource/RID diagnostics remain separate from
the passing repeated-use checks. No new full-army stress test or app export was
performed; the user's earlier smooth-gameplay report remains separate evidence.

Evidence is under build/Other Files/Asset Toolkit/Skullpion Drill/, including
desktop-results.json, desktop.log and first-emergence.png. To verify, run
Play Goemon.command --resolution 1280x800 --script
res://tests/forest-shrine/skullpion_drill_test.gd, or select Skullpion in normal
play, leave R unassigned and press R near enemies. Watch the nearest ground
target, try a second cast and try cancelling. Keep native local queries, the
three hit markers, source-pose alignment and presentation reuse when tuning.

## Magic Swordsman crescent direction correction — 2026-10-24

The user rejected the transverse rainbow orientation in the earlier purple-energy
revision. This is a presentation correction, not a measured simulation bottleneck.
The same two cached `_blade` surfaces now curve along travel: their bright convex
rim leads in local +Z, while their hollow and pointed ends trail. The shared
release controller cycles five rolls around the travel axis. It never changes
velocity to create that variation, and the plane stays fixed during flight.
The visible span is shorter and offset along the cut so both points clear a
normal ground release; the existing three trails follow that visual center.
Projectile origins, collision width, damage, speed, range, cooldown and sword
animation remain unchanged. Musashi's sound routing remains as above.

Fresh final desktop checks pass 350 assertions through `Play Goemon.command` on
Metal, including six consecutive casts (covering the angle-cycle wrap), upward,
downward and oblique aim, above-ground tips, unchanged piercing damage to three
native victims, reduced flashes and 100 pooled reuses. All five ground-release
views were visually reviewed. Eight simultaneous prepared effects had zero node
and resource growth over 240 focused frames: median 16.667 ms, p95 17.347 ms,
p99 18.100 ms and maximum 19.453 ms. This is a small fixture with the army paused,
not fresh full-army or long-session evidence. The earlier 239/242-check results
above describe the initial revision, not this corrected shape. Existing test
shutdown resource/RID warnings remain separate from the passing assertions.

Evidence is under `build/Other Files/Asset Toolkit/Purple Energy/Direction/`.
Files prefixed `flat-angle-`, `ground-clipped-` and `focus-invalid-` are excluded
iterations. To verify, launch the current source, choose Magic Swordsman and use
RMB at least six times. Check the complete moon silhouette, the forward edge and
changing angle; then jump and aim above/below a target. Preserve the existing
pool and prepared resources when iterating. No Blender geometry, rigs or motion
were changed, so this correction requires no asset export, pose bake or model
optimization. No app was exported.

The existing `combat_polish_tests.gd` wave-release/cancel section also passes all
seven focused checks; the asset toolkit preservation check passes. A same-process
old/new eight-wave comparison recorded zero node/resource growth for both, but
lost window focus (63/240 and 0/240 frames). Its timings are excluded; subsequent
comparison attempts were blocked by other desktop test runs. No before/after
speed improvement is claimed. Use the final focused desktop figures above only
for this small workload, keeping the user's earlier smooth-gameplay report
separate from these measurements.


## Dark Lumina 2 recovery and shared skills — 2026-10-24

These are the initial recovery results, before the later size/speed tuning below.

Dark Lumina 2 is native enemy role 17 and playable fighter 29. Its 714-triangle,
19-part body and 21 original motion streams use the existing rigid pose atlas.
NPC decisions, damage, local queries and projectiles stay in the native army;
the player and borrowed skills use the existing character adapter and pool.
Sounds, effect meshes and sprite strips are prepared during initialization.
Two owned shockwave materials restore the source transparency flag once at
setup, without changing another asset's materials or loading during attacks.

No new CPU bottleneck was established. Rendered testing did reveal a contact
bug: the player's claw could run past a close target before its source hit
frame. The smallest fix uses the native boss's stopping distance and a cached
nearby target. Borrowed claws retain that movement through the shared skill
owner. Hit frames, six paired fireballs, damage rules and physical slam landing
remain in their existing combat owners.

Fresh desktop checks through Play Goemon.command passed 30 assertions on Metal
at 1280 × 800. They cover original presentation, all three borrowed skills,
close grab/contact/release, physical jump/landing, repeated six-shot volleys,
focus cancellation, defeat and pool retirement. All 3,077 stepped frames had
foreground focus; the eleven recorded runtime inputs stayed unchanged. Five
volleys emitted 30 shots, with zero pool misses or growth. Hero/projectile/
presentation step CPU p95 was 1.671 ms; that isolated manual step is not FPS.

A separate normal-physics painterly run used twelve additional native bosses
and the playable boss for 780 rendered frames (776 focused). After warmup,
resources and total nodes had zero growth; presentation retained 110 nodes,
with 18 native shots and six effects active at peak. Direct frame intervals
were median 16.657 ms, p95 17.327 ms, p99 17.597 ms and maximum 27.267 ms on
Apple M3. The JSON also retains Godot's slower-updating process/physics monitor
samples; those are not the direct per-frame interval measurement. This short
scene is not a full default-wave stress benchmark or a controlled before/after
comparison. Other chats were active. It does not replace the user's earlier
smooth-gameplay report or validate historical stress runs on current source.

The shared character suite passed 144 checks and the shared spell suite passed
3,040. Recovery tests verify every preserved source pose, audio sequence and
effect stream. During this recovery, 54 toolkit unit tests, 12,812 imported
checks, 98 Musashi outfit checks, 86 structure checks and asset preservation
passed. Native tests cover attacks at 20/30/60 steps per second. Earlier desktop
attempts with fixture collision, duplicate projectile stepping or changed
shared inputs are superseded by the accepted 30-check run.
The final native/pose rerun passed 16 checks and 23,275 source-part samples.
After the desktop checks, another chat added a Skullpion-only pose branch to
the shared model. It was inspected; DL2's pose/skill/death paths are unchanged.
That follow-up is recorded separately in final-input-check.json.

To verify manually, choose Dark Lumina 2 with Q. LMB/T grabs, E releases three
pairs of fireballs, and RMB/R jumps and produces two shockwaves after landing.
Try a nearby target, then one farther away; repeat E and switch fighters.
Assign each of his three skills to another fighter in the shared skill picker.
Use the wave editor to add native Dark Lumina 2 enemies without altering other
counts. Keep the prepared pool, local queries, source contact markers and
shared pose atlas when editing. Re-export the saved Blender master and rebuild
its pose bake after changing motion; see docs/dark-lumina-2-recovery.md.

Evidence: build/Other Files/Asset Toolkit/Dark Lumina 2/{gameplay-rendered.log,
gameplay-results.json,live.log,live-results.json,verified-source-hashes.json,
final-input-check.json} and paired-fireballs.png, grab.png, shockwave.png,
death.png and live-*.png. Repeat through the desktop launcher with
`--script res://tests/forest-shrine/dark_lumina_2_gameplay_test.gd` and
`--script res://tests/forest-shrine/dark_lumina_2_live_test.gd`.
No app export or long-session soak was performed.
Existing shutdown resource/RID diagnostics remain; stable short-run counts do
not establish that the whole game is leak-free. Original dry audio, pitch and
sequence timing are retained; PSX hardware ADSR/reverb are not emulated.

## Dark Lumina 3 final form — 2026-10-24

The final form is player 30/native enemy 18, with six shared skills: Sword,
Wind, Water, Fire, Earth and Sky. Its 17-part body and 16 source motion streams
reuse the rigid army pose atlas. Sky copies reuse their own recovered 10-part
model in the same renderer. Wind/core vertex morphs are prepared into GPU pose
textures at initialization, and sword growth uses the recovered endpoints.
All enemy decisions, local queries, damage and projectiles stay inside native
Combat. Player and borrowed casts use CharacterCombat/CharacterProjectilePool;
repeated effects and audio use the existing bounded presentation.

No new CPU bottleneck was established. Rendered checks found two concrete
visibility problems: a prepared projectile MultiMesh lacked its identity
transform, and dynamic ROM sprite palettes were unresolved. The smallest fixes
initialize the existing instance and resolve source palette assignments during
recovery. Sword slashes additionally require the original 8-bit texture mode;
the other strips use 4-bit pixels. Source frame holds now drive the existing
atlas shader. These fixes restore the effects without reducing attack counts,
replacing art, loading resources during combat or adding per-unit renderers.

Fresh checks passed 57 asset-toolkit unit tests, 12,812 imported checks, 98
Musashi outfit checks, 86 structure checks and asset preservation. Finale
recovery checks compare every source pose and all 50 morph endpoints across
the Blender export, while the Godot import check also samples every body/copy
pose. Gameplay passed 53 checks covering repeated six-move cycles, cleanup and
transfer of all six skills; the playable enemy suite passed 246, and packed
projectile buffers passed 2,177. The native fixture checks releases and actual
sword contact, airborne Earth, secondary hazards, cancellation and cleanup at
20/30/60 steps per second.

The final desktop Metal run at 1280 × 800 passed 10 rendered assertions: all
six player casts completed, then six native bosses and 120 ordinary enemies
ran for 3,600 physics steps and reached every move family. Presentation stayed
at 110 nodes. Native-step median/p95/max were 0.569/0.907/21.289 ms; direct
rendered-frame intervals were 16.666/17.765/196.923 ms. The maximum is a real
outlier in this capture run, which includes PNG saves and concurrent desktop
work; its cause was not isolated. This is a manually advanced, invincible
fixture with protected buildings, not a controlled before/after benchmark or
proof of full-wave smoothness. Source hashes recorded during the final run
matched afterward. Earlier blank-palette or interrupted captures are superseded.

A later defeat-only correction restores the ending actor's additive flag and
uses its initial 0.125 scale for the compact sequence. Five additional rendered
checks passed across three deaths, including effect expiry and fixed node
counts. That focused scene ran directly in Godot with painterly scenery while
an existing desktop game held the launcher lock; its timings are not used as
performance evidence. The main six-move/army run above used the desktop launcher.
The two modified runtime files and focused test have separate verified hashes
in defeat-source-hashes.json; the imported-model and asset checks passed again.

To verify manually, launch Play Goemon.command, press Q and select Dark Lumina 3.
Use 1–6 for the six moves (LMB Sword, RMB Sky); E/R/T initially equip
Fire/Earth/Wind. Try repeated water/fire volleys, dodge out of Wind/Sky, switch
fighters, and assign the six skills to another fighter. Add Dark Lumina 3 in
the existing wave controls without altering the other counts. Keep source
release markers, local contacts, owner-bound cancellation and the prepared
pools when iterating. Re-export saved Blender masters and rebuild body/copy
pose bakes after motion edits; see docs/dark-lumina-3.md.

Evidence lives under build/Other Files/Asset Toolkit/Dark Lumina 3/; reproduce
the rendered fixture with the desktop launcher and
`--script res://tests/forest-shrine/dark_lumina_3_visual.gd`.
The original story QTE is adapted to a compact core defeat sequence, and PSX
SPU ADSR/reverb are not emulated. No app export or long-session soak was done.
Existing full-scene shutdown resource/RID warnings remain; stable pool counts
do not establish that the entire game is leak-free. These checks do not rerun
historical stress tests or replace the user's earlier smooth-gameplay report.

### Dark Lumina 3 size and audio recheck — 2026-10-24

The user requested three-times larger spells and a larger body for both the
enemy and selectable fighter. One role-size constant now drives the body
shader, shared prepared effects, Sky copies, native kit, collision bounds,
melee contacts, projectile radii, placement and area coverage. Enlarged travel
uses the existing attack windows. ROM meshes, editable Blender masters and
source pose bakes retain their original scale. Effects still reuse the same
meshes, bounded batches and player projectile leases; no per-cast asset loading
or additional simulation owner was added.

All 21 active sound streams have nonzero duration and pass playback routing
checks; all 22 preserved WAV files contain non-silent PCM. Three held sounds
retain prepared loop bounds. His sound range is 195 world units, and the shared
voice restores the ordinary 65-unit range on reuse. Both normal and heavy
native hit cues are checked. The desktop test also captures live SFX-bus PCM
while all six attacks run, rather than assuming that installed WAV files imply
audible playback.

A standalone native test caught Earth reading Dark Lumina 2's jump setting;
Earth now uses its own existing launch value inside the same native owner.
The fixture deliberately configures only the final-form kit, so it catches
that accidental cross-character dependency. Native tests also verify the
expanded Wind boundary and an actual enlarged sword-wave hit, alongside all
six release patterns at 20/30/60 Hz. Gameplay/media checks passed 126, including
all five Sky copies being removed on cancellation and a playing Wind loop
stopping with its caster. The
playable roster passed 246, projectile buffers passed 2,177, and 58 toolkit
unit tests passed. Imported assets passed 12,812 checks, Musashi outfits 98,
structures 86, and the asset audit read all 288 assets without errors.

The first larger rendered battle failed its coverage assertion because it
looked only at the final bounded event history, which had dropped early cast
events. The fixture now accumulates coverage each step and clears its test
history without changing gameplay event delivery or army counts. Evidence for
this revision belongs under Dark Lumina 3/Scale 3x/. Earlier figures above
describe the initial-size version, not this enlarged revision.

The accepted 3× desktop run passed 80 assertions on Apple M3/Metal at 1280 × 800.
All six player casts completed and the SFX bus captured 2,725,888 audio frames
with a nonzero peak. Six native bosses plus 120 ordinary enemies completed
3,600 simulation steps and reached all six families; presentation retained
110 nodes. Direct frame intervals were median/p95/max 16.715/23.392/473.534 ms;
native-step values were 1.094/2.649/76.452 ms. The high outliers remain visible
in the report. This protected, manually advanced scene includes screenshot
work and concurrent desktop activity; it is not a matched before/after study,
full-wave stress test or long-session leak check. No isolated CPU/GPU bottleneck
was established. Do not describe this as guaranteed smooth 60 FPS. The ordinary
gameplay smoothness reported by the user in October remains separate evidence.
Runtime source hashes matched after the accepted run; the later headless test
adds cancellation assertions without changing the rendered runtime.

To maintain it, edit DARK_LUMINA_3_SCALE once, rebuild native/terrain_math with
its existing build.sh, then rerun the focused tests and desktop launcher.
Do not also rescale the Blender masters or multiply per-cast instance scales.
Check the actual hit edge, looping/cancelled audio, body clearance and repeated
projectile reuse. Larger transparent effects cover more pixels, so judge frame
times in rendered play instead of inferring speed from unchanged triangle counts.


## Sonic wall/hurt audio and source playback rates — 2026-10-24

The issue was audible fidelity rather than a measured frame-time bottleneck.
The initial voice mapping used raw bank WAV rates; some effect preparation also
reapplied instrument tuning and used sequence notes that the native SoundCall
path bypasses. `tools/sonic/audio.py` now prepares PCM aliases using the supplied
image's note 48, 44.1 kHz reference, positive fine tuning and native SRC
quantization. Raw recovered waveforms are preserved. See the source addresses,
rate table and fidelity limits in `docs/recovered-sonic.md`.

The smallest runtime change uses the existing sound library and voice pool:
one cached synchronized hurt effect/voice resource and a wall reaction at the
existing collision transition. Setup prepares these resources on selection;
there is no new audio player pool, combat-time file loading or sound timer.
The existing hurt setting owns both layers, including mute, gain and custom
takes. Blocked damage does not play either layer. Wall pushing cannot emit a
reaction every frame. No motion, damage, army counts or scenery were reduced.

Fresh checks passed: 22 focused audio assertions headless and 28 through the
desktop launcher, 58 Sonic gameplay assertions, 58 toolkit unit tests and the
active asset preservation check. Desktop SFX capture confirms emitted wall
pitch against the source-derived waveform at correlation 0.999729. The test's
32 wall/hurt cycles returned to zero node/resource growth after existing hit
sparks expired. A tight initial batch counted live spark tweens before their
normal expiry; that fixture failure is excluded and was not a live-game audio
leak. No matched CPU/FPS benchmark, full-army soak or original-console recording
comparison was performed. The earlier gameplay/performance measurements in this
guide remain historical. Existing harness shutdown diagnostics remain.

To verify, use Play Goemon, choose Sonic with Q, dash into a wall, continue
pushing it, then take a hit and try again during invulnerability. Check the
wall reaction happens once and hurt plays its effect and voice together. Tap
Space and hold/release RMB to hear the corrected jump and Spin Dash rates.
The Sound Studio hurt mute/volume or a saved hurt take should control the whole
hurt cue. The focused desktop command and the output clips (`wall-hit.wav`,
`hurt.wav`, `jump.wav`) are recorded under
`build/Other Files/Asset Toolkit/Sonic/Audio Integration/`. No app export was
performed. Preserve prepared imports' sample rate and uncompressed PCM settings;
never apply the root-note adjustment to an already tuned WAV header again.

## Dark Lumina 2 size, fire and control tuning — 2026-10-24

These changes apply to the playable fighter, native enemy and borrowed skills,
as requested. Body dimensions are 3×, the complete claw/grab/miss sequence runs
at 3×, and ground speed is 20% higher. Fire sprites, contact radius and trail
spacing are 3×. Fire speed rises from 8.64 to 25.92 while lifetime remains 3.5 s,
so its travel budget grows from 30.24 to 90.72 without increasing the number of
shots left alive between casts. Damage, six releases per cast, contact counts,
wave counts and original audio stay intact. Both actors reuse the 160 launch,
320 rising gravity and 720 falling gravity used by Skullpion's player controls.

The shared role shader scales the original geometry; matching bounds cover
hits, navigation, spawn clearance, construction clearance, camera and culling.
The claw's forward motion follows its faster clock and larger reach. Keeping
its old travel speed would miss targets at the enlarged maximum reach. The
native airborne capsule fits the torso instead of using the much wider ground
footprint; this prevents a wide capsule from pushing its feet above the floor.
Walking cadence uses the larger stride. There is no new actor simulation,
renderer, per-frame asset load or runtime retargeter.

All 21 actions remain in the editable Blender master and were rendered in the
existing scene. All 23,275 original part samples match the exported/baked data
(maximum error 0.0000358848). Source geometry remains 714 triangles / 19 parts.
The audit's original 60 authored surfaces still exceed its warning budget;
the existing runtime batching is retained, with no geometry or texture loss.
The source/audio/effect recovery checks, 58 toolkit unit tests, 12,812 import
checks, 98 Musashi outfit checks, 86 structure checks, 144 shared-character
checks and 3,040 shared-skill checks passed. Native correctness checks pass at
20/30/60 steps per second, including three claw contacts, both landing pulses,
cancellation, enlarged fire radius and its 90.72 travel budget. Native jump
height is approximately 38.6 and its feet return to ground level.

The final desktop functional run passed 89 checks over 2,806 manually stepped
frames, with 30 shots, zero pool misses and no pool growth. It includes the
retimed claw at maximum reach, miss recovery, Space jump, physical slam landing,
all three borrowed skills, interruption, original death and all 21 motion
captures. The recorded runtime inputs stayed unchanged during that run. A subsequent
one-line cancellation adjustment also clears horizontal borrowed-leap momentum;
three focused checks verify ascent, descent and retained playable-boss controls. The OS reported zero focused frames despite the visible rendered window;
its p95 manual step CPU time of 7.438 ms is correctness evidence, not a claim
about focused gameplay FPS. Other chats were using the desktop launcher, and
checks were queued without closing their games.

To verify manually, run Play Goemon.command, choose Dark Lumina 2 with Q, use
Space and movement across clear ground, try LMB on a nearby target and one at
the edge of reach, then repeat E at near and distant targets. RMB/R should land
before either shockwave fires. Add native Dark Lumina 2 in the wave editor and
try his three skills on another fighter through the shared skill picker.
Tune the constants in scripts/forest/dark_lumina_kit.gd; keep pose markers,
physical landing, prepared projectile reuse and local target queries together.
Evidence is under build/Other Files/Asset Toolkit/Dark Lumina 2/Tuning/.
No app export or long-session soak was performed. Existing shutdown resource/RID
warnings remain; short-run resource counts cannot establish absence of leaks.


### Kojiro grounded follow-up, larger spells and centered waves (2026-10-24)

The reverse-cut attempt below is historical; the three-motion grounded combo
recorded later in this guide supersedes it. The spell and wave fixes remain.

The user reported only one convincing grounded hit, weak damage, undersized
spells and incorrect phoenix/purple-wave direction. The second Kojiro section
sampled the sword's recovery instead of a complete cut. It now plays the first
24 source ticks backward after the first cut, with its own contact seven
playback ticks into that return. Each click owns one cut; one early click can
queue the next. Both work while grounded. This is a player adaptation using the
same editable source action, with original feet, grip and fast 2× playback.
No Blender master, original animation sample or optimized derivative changed.

Kojiro's adapter triples base melee damage to 72, homing damage to 96 and wave/
wind damage to 144. Existing upgrades, receiving-fighter multipliers and chain
bonuses still apply. One scale in the existing projectile presentation triples
all spell geometry, hit volumes, sparks and dust, preserving wind's relative
sheet sizes and every projectile's speed, release count and lifetime. Repeated
effects retain their prepared meshes/materials and shared pool; local native
queries and hit ownership remain unchanged.

The phoenix was camera-billboarded. Its upright page now faces along velocity
and grows above the flight plane so the enlarged bird is not buried in the
floor. It launches from the caster's center at torso height plus a forward
offset, using existing projectile aim; grounded casts stay level. Purple
Swordsman waves use the same centered release convention instead of launching
sideways from a changing sword position. Their convex leading edge, varied
cutting roll, speed, piercing, audio and damage remain intact. Borrowed versions
reuse these same controllers.

No new CPU bottleneck was established. Fresh desktop-launcher Metal checks on
Apple M3 passed 365 Kojiro assertions with zero failures and zero focus losses.
Real mouse events delivered both grounded hits against a native opponent while
its recoil advanced; after closing distance, another grounded click connected.
The fixture also checks player crosshair headings, upright flight, wall blocking,
tripled damage/size, all skill donors, cancellation and eight consecutive casts
of each special with unobstructed full lifetimes. The 354 prepared leases
(including 40 existing coin leases) had zero misses or growth. Idle resource
deltas were zero. Manual player/projectile step p95 was 0.851 ms; idle p95 was
0.092 ms for Goemon and 0.103 ms for Kojiro. Across 2,185 rendered physics-frame
intervals, median/p95/max were 16.660/17.110/34.153 ms. This small fixture excludes
PNG-save pauses and bulk lifecycle checks; it is not a full-wave benchmark or a
controlled before/after comparison. Other desktop work was active.

The purple-wave desktop run passed 378 checks, including centered launches,
multiple directions and unchanged native piercing damage. Eight overlapping
prepared waves showed zero node/resource growth. Its timed overlap sample had
no foreground-focus frames, so its timing numbers are excluded from performance
claims. Rendered captures were inspected separately. The shared skill suite
passed 3,040 checks; 58 toolkit unit tests, 12,812 imported checks, 98 Musashi
outfit checks, 86 structure checks, 1,575 Kojiro imported pose comparisons and
asset preservation also passed. Recorded runtime/master/export input hashes
matched after the final rendered runs. Early flat-bird and incomplete input
fixture runs are superseded by the accepted desktop evidence.

To verify, launch Play Goemon, choose Kojiro and tap LMB twice without jumping;
try buffering the second click during the first swing. Move back into reach if
a target retreats. Cast E/R/T, turn the camera and repeat, then equip those
skills on another fighter. Select Magic Swordsman and check RMB from several
headings: the crescent should leave centrally with its outer edge leading.
Keep size separate from travel speed, tune damage in the player adapter, and
repeat the full-flight pool check if attack cadence changes.

Evidence: build/Other Files/Asset Toolkit/Kojiro/Combat Corrections/, including
its Purple/ captures. No app export, full-army stress run or long-session soak
was performed. Existing harness shutdown RID/resource warnings remain; stable
live workload counts do not establish that the entire game is leak-free.

The initial 780-frame upgraded enemy run passed with 48 native projectiles and
15 effects at peak. Direct rendered intervals were median 16.667 ms, p95
17.778 ms, p99 25.397 ms and maximum 71.953 ms. The earlier unmodified 780-frame
observation had p95 17.490 ms, p99 21.376 ms and maximum 34.439 ms. This is not
an isolated benchmark: foreground focus differed and other chats were active.

A longer 1,560-frame run retained twelve bosses and repeated player casts. It
passed both simultaneous-use checks, reached 48 native projectiles / 16 effects,
and kept presentation at 110 nodes. Resources rose from 1,738 to 1,741 during
first-cycle setup, then stayed at 1,741 across frames 780, 1,020, 1,260 and 1,559.
Total nodes ended six lower than at warmup; no ongoing resource growth was
observed. Direct rendered intervals were median 16.680 ms, p95 23.198 ms,
p99 64.077 ms and maximum 133.558 ms. The window reported zero focused frames.
These measurements include spikes and do not establish unchanged smoothness
or identify a new CPU/GPU bottleneck. A focused, isolated trace is needed before
attributing those spikes or proposing a further performance change. Do not
reduce army counts, effects or art to hide them. The separate manual-step CPU
measurements above are not frame intervals.


### Kojiro: three distinct grounded clicks (2026-10-24 clarification)

The user clarified that consecutive ground clicks repeated the same cut instead
of reaching Kojiro's other attacks. Reversing that cut did not meet the request.
The smallest complete fix keeps the existing combo controller and selects three
motions: the original main slash, a prepared turning cut, then a prepared
somersault cut. Each click advances one section; an early click buffers one
continuation. The shared player remains grounded, including during the
somersault's baked visual lift. Original air attacks remain available after a jump.

Two additional actions in the authoritative Kojiro Blender master adapt original
`801e2660` / `801e2708`. Whole-pose offsets clear the floor; entry and recovery are
prepared at 30 FPS. Original contact tick 15, grip/body relationships during the
cuts, all 21 numeric actions and exact geometry/paint are preserved. The shared
rigid exporter now records authored extra actions in its manifest. The rebuilt
optimized asset retains all 500 triangles, 15 independently animated parts and
20 surfaces, reducing vertices 1,500→445 and materials 20→4. The surface-budget
warning remains; it does not authorize removing animated parts. There is no new
runtime retargeter, frame-loop loading, projectile pool or army owner. Kojiro is
player-only, so an army pose bake is not applicable.

Fresh desktop-launcher Metal evidence on Apple M3 passed 369 assertions with zero
failures and zero focus losses. Real mouse clicks hit an advancing native target
for 72, 75.6 and 79.2 damage, including existing chain bonuses; the third hit
followed closing distance after native recoil. Tests cover separate clicks,
buffering, a fourth-click wrap, expiry, held-input non-repetition, cancel/reset,
original air attacks and shared donor spells. The 3× damage/effect sizes, centered
phoenix path and existing corrected run remain. The prepared 354 leases had no
misses or growth; idle resource deltas were zero.

This small fixture measured manual player/projectile step p95 0.736 ms. Idle
Goemon/Kojiro p95 was 0.094/0.112 ms. Across 2,334 rendered intervals,
median/p95/max were 16.654/17.450/36.566 ms. These are fresh isolated observations,
not a controlled comparison or a full-army smoothness claim. No new performance
bottleneck was established. Earlier gameplay experience and stress measurements
remain historical. Preserve the current workload and prepared assets when tuning
this combo; do not load or retarget motion in attacks.

Source, staged and active imports each passed 1,575 original pose comparisons
plus 540 prepared relative-pose/grip comparisons and every prepared frame's floor
check. All 276 synchronized capture pairs across 23 clips/four views were pixel
identical between authored and optimized assets. Asset preservation, 58 toolkit
unit tests (the updated five-test Kojiro suite was rerun), 12,812 toolkit import
checks, 98 Musashi outfit and 86 structure checks passed. Rendered gameplay poses
were inspected. An early raw-GLTF test dropped immutable tracks using the API
default; it was corrected to the existing toolkit import settings before accepting
staged results. That fixture failure did not justify modifying asset data.

Verify with Play Goemon: select Kojiro and click LMB three times in succession,
or buffer each next click during a swing. Expect cut → turn → flip, one hit per
click, without pressing Space. Let the combo window expire to restart at the
first cut; keep within reach when enemies recoil. Continue using E/R/T and the
shared skill equipment screen as before. Edit the saved Blender actions, export
with the shared exporter, rebuild the `kojiro` candidate and repeat motion/grip,
preservation and desktop checks after future pose changes.

Evidence: `build/Other Files/Asset Toolkit/Kojiro/Ground Combo/`. No app export,
full-army stress run or long-session soak was performed. Existing harness shutdown
RID/resource warnings remain; stable live counts do not prove the whole game
leak-free.


## Dark Lumina 3: visible spell keys and quick sword cuts — 2026-10-24

The user reported that the enlarged fighter was hard to play. The immediate
input bug was in the existing HUD: it consumed 1–5 as numbered loadout slots,
but Dark Lumina had no actions in those slots. The same slot selector now calls
his controller's select_number method. Five named buttons and a short control
legend show 1 Wind, 2 Water, 3 Fire, 4 Earth and 5 Sky. Switching fighters restores
the ordinary slot labels. Physical keyboard events are tested with the real
HUD visible, so a direct call to the combat adapter cannot hide this failure.

LMB now uses three existing source sections: the forward cut from 801EF270,
then the first and second cross-cuts from 801EF3B8. The existing combat adapter,
local contact query, per-cut hit set and attack ticket own the sequence. Early
clicks buffer one continuation; a 0.7-second gap restarts the sequence. Normal
movement remains available during primary cuts. RMB retains the full sword
rush, wave and cross-slashes. A numbered spell or LMB can interrupt a current
spell, and evade/selection/focus cancellation clears buffered cuts.

The old primary replayed the 204-tick boss attack (6.8 seconds). The new primary
sections are 40/16/16 source ticks at the player's 3× cast rate: about
0.44/0.18/0.18 seconds before existing hit pauses and upgrades. Contacts use
local ticks 28/11/7. All player and borrowed spell release markers remain present
at the faster rate; Earth still waits for actual landing. Waiting Sky copies,
Wind morphs, orbit timing and held Wind audio follow the same cast rate. Native
enemies keep their original timeline. Prepared fire leases rise from 40 to 80
because the faster repeated workload has more overlapping ground flames; this
reuses the existing pool and introduces no attack-loop asset loading.

Fresh desktop-launcher Metal verification at 1280×800 on Apple M3 passed 51
assertions. Real 1–5 key events reach all spells, all names are visible, each
sword click connects once, the fourth wraps, early clicks buffer, idle/cancel
resets work, every projectile release survives compression, and four consecutive
32-flame casts retire fully. The 168 prepared character leases (including the
existing Goemon leases) had zero misses or growth. The original finale suite
passed 126 checks, the complete playable roster 246 and shared spells 3,040.
Asset preservation, 58 toolkit unit tests, 12,812 imported checks, 98 Musashi
outfit checks and 86 structure checks passed. Existing Blender geometry,
source motions and army pose bakes were reused, so no master export was needed.

This small rendered control fixture measured manual player/projectile-step p95
1.172 ms. Direct rendered intervals were median/p95/max 16.661/17.081/33.845 ms;
PNG saves are outside those intervals. These observations are not a controlled
speed comparison or a full-wave smoothness claim. No new CPU/GPU bottleneck
was isolated. The earlier general smoothness report and army stress figures
remain separate evidence. Early captures with a hidden HUD and a fixed-frame
buffer assertion are superseded; the accepted run verifies visible controls
and waits for the actual buffered transition through ordinary hit pauses.

Keep cast rate separate from visual size and source geometry. When changing
speed again, check every release, physical Earth landing, Wind/copy timing,
held-loop cancellation and worst-case repeated Fire leases. Do not increase
pool capacity without a measured repeated workload. Evidence is under
build/Other Files/Asset Toolkit/Dark Lumina 3/Controls/, with runtime hashes
unchanged after the accepted desktop run. Reproduce with Play Goemon.command
and --script tests/forest-shrine/dark_lumina_3_controls_test.gd. No app export,
full-army stress run or long-session soak was performed. Existing full-scene
shutdown resource/RID warnings remain separate from these passing assertions.

## Dark Lumina 3: wings, spell coverage and flight — 2026-10-24

The user reported a single-looking Wind wing, diving waiting copies, the wrong
RMB crescent angle, slow floating, and weak/small spells. Wind's inner/outer
layers previously occupied one side; both prepared morph meshes now render on
two mirrored sides in the existing batches. Its local hits push outward at
strength 24 rather than pulling inward. Native enemy Wind uses the same outward
impulse on allies and the playable Hero, including the Rogue movement owner.
A flat native contact fixture moved a target about 1.8 m in 0.1 s; the original
map's walls correctly prevented displacement in an earlier fixture position.

Waiting and launched Sky copies select the already baked two-frame upright
pose instead of the 12-frame dive. Their travel basis preserves world up.
The recovered cross sprite's convex rim now leads along travel in a diagonal
cut plane; billboard camera facing cannot erase that orientation. Original
meshes, textures, source motions, Blender masters and pose bakes stay intact.
No per-clone animation player or runtime retargeting was added.

On top of the existing 3× kit size, Water grows another 3× and Fire another 2×;
their scatter radii grow from 18 to 54/36 m. Ground-fire contact grows with the
flame. Earth's local radius doubles from 42 to 84 m, with a larger blast/ring.
All six spells gain at least 5× damage; Sky gains 10× per copy. Sword rush melee
also gains 5×; the fast LMB combo retains its previous damage. The shared kit's
radius/damage entries feed both player and native combat, with every original
release and secondary hazard retained. This is intentional balance tuning,
not a measured optimization. No new bottleneck was isolated.

Player/native ground floating is 60% faster. Default Space flight reuses the
existing shared movement: 36/64 horizontal speed and 18/32 ascent without/with
Shift, versus Ben's 21/36 and 15/24. Release Space to descend. Explicit equipped
jump styles still override the default, and Earth temporarily retains physical
gravity so its landing cannot be trapped in flight. The control legend includes
flight. No extra character/controller or effect pool was introduced.

Fresh Play Goemon.command Metal checks on Apple M3 at 1280×800 passed 35 tuning
assertions and 80 encounter/media assertions. The focused tuning fixture
retained 168 prepared leases, with zero misses or growth and complete hazard
retirement. Its manual player/projectile-step p95 was 1.084 ms; direct frame
median/p95/max was 16.662/17.478/33.369 ms. Other short headless validation jobs
ran during parts of this tuning fixture, so it is not an isolated comparison.

The subsequent encounter ran six final bosses plus 120 ordinary native enemies
for 3,600 steps, reached all six spell families and retained 110 presentation
nodes. The SFX bus supplied 1,293,312 non-silent PCM frames. Native-step
median/p95/max was 0.603/1.003/26.380 ms; wall-frame median/p95/max was
16.669/17.047/200.771 ms. This harness's wall maximum includes capture pauses.
All 675 recorded runtime inputs stayed unchanged through this encounter.
These observations do not establish full-wave or long-session smoothness.

Focused headless tuning passed 37 checks (including two extra shared-knockback
checks), controls 51, finale/media 126, shared spells 3,040 and playable enemies
246. Asset preservation passed; toolkit unit/import checks passed 59/12,812,
Musashi outfit 98 and structures 86. The standalone native fixture passed all
six families at 20/30/60 Hz, outward Wind impulse/damage, expanded Earth boundary,
long-range Sword contact, secondary hazards and cleanup. Its Sword target sits
0.1 m above the floor to avoid an exact sphere/capsule tangent. Existing full-
scene shutdown RID/resource warnings remain; fixed in-use counts are not proof
of a long-session leak fix.

Verify through Play Goemon.command: select Dark Lumina 3, use 1–5 and RMB, fly
with Space/Shift, release Space, and cast Earth from the air. Check both wings,
upright copies, outward movement against an unobstructed troop, full scattered
volleys and the actual landing blast. For future changes, compare hit radii and
VFX size together, keep camera billboarding away from travel-aligned slashes,
and repeat worst-case Fire/clone cancellation before increasing pool capacity.
Evidence and captures are under build/Other Files/Asset Toolkit/Dark Lumina 3/
Spell Tuning/; run dark_lumina_3_spell_tuning_test.gd and dark_lumina_3_visual.gd
through the desktop launcher. No app export or long-session soak was performed.

## Dark Lumina 2: recovered walking markers and spin — 2026-10-24

This recheck identified a recovery-label problem, not a measured CPU bottleneck.
The source's B53 walking sound was already correct, but its 65-unit range did
not follow the requested enlarged body/camera. The player also used a generic
footstep path and an approximate stride cue; native held-victim status 210 could
accidentally request the same step sound. The shared range is now 195, walking
uses the original cycle's frames 15/53, and native walking has its own cue 214.
Changing speed advances a continuous distance-based pose clock. Idle/air travel
and frozen clocks do not add footsteps.

The two existing 27-frame “hurt” streams are directional spin poses. The ROM
rotates the actor in code, which was absent from the recovered skeletal keys.
The existing prepared atlas now supplies those poses alongside a small shared
yaw table. B56 is their layered cry. Native enemy decisions, contact/cover tests,
status handling and presentation remain inside the native army owner; the
player and borrowed spin reuse the recovered character controller and shared
skill system. T defaults to spin; LMB remains the accelerated claw. Saved custom
assignments remain intact.

Two prepared MultiMesh batches draw dust and the source's recovered flying floor
tiles: up to eight dust puffs and one fragment per active source tick, represented
by two effect records per spin. Rotation and original floor pixels are retained;
dust appearance/fragment trajectories and the single radial contact at tick 7
are Goemon adaptations. No model loading, material creation or particle-node
construction occurs in the attack loop. Both cancellation and expiry use the
existing bounded effect records. Body masters and the pose bake remain unchanged.

Fresh validation of this revision passed native spin/step/old-attack checks at
20/30/60 steps per second, 39 headless gameplay assertions, 21 pose/runtime checks
covering 23,275 source part samples, 60 toolkit tests, asset preservation, 12,812
import comparisons, 98 Musashi outfit checks, 86 structures, 144 shared-character
checks and 3,074 shared-skill checks. The isolated gameplay checks include both
spin directions, early cancellation, borrowed-body rotation, one contact per
cast, walking speed changes, studio overrides/mutes and twelve simultaneous
bursts repeated three times with stable presentation nodes. Headless results do
not establish visual quality, audible mixer output or frame-rate smoothness.
Existing whole-scene shutdown resource/RID diagnostics remain.

Desktop verification through Play Goemon.command passed 49 functional assertions,
including mixer captures for walking and both spin directions, with 669/672 manual
frames focused. Those stereo recordings contain no clipped samples (walking peak
0.184, spin peak 0.126). The isolated player/presentation step p95 was 0.899 ms;
that excludes the normal world loop and is not a frame-rate claim.

A final normal-physics painterly run kept all twelve additional bosses for 1,800
rendered frames, all focused, with 2,290 native simulation steps. Eight enemies
entered spin (459 observed spin frames). Presentation stayed at 113 prepared nodes;
resources grew by zero after warmup. Whole-scene node count ended three lower,
with the difference consisting of MultiMeshInstance3D nodes. An earlier assertion
requiring the entire changing world tree to stay identical was too broad; it is
retained in initial-live-results.json. A subsequent paused run is retained as
paused-live-results.json and is not accepted combat/performance evidence.

Final direct frame intervals were median 16.898 ms, p95 34.072 ms, p99 35.911 ms
and maximum 318.876 ms. This crowded scene still has frame spikes; no controlled
before/after CPU bottleneck attribution or general smoothness claim is made.
Godot's slow-updating process/physics monitor values are also retained, but must
not be substituted for measured frame intervals. Counts/art/skills were not
reduced. The final fixture blocks gameplay key input and fixes its review camera
so another desktop interaction cannot pause it midway.

Concurrent DL3 work edited shared player/native/presentation files and rebuilt the
universal library during this review. The DL2 paths were inspected, rebuilt and
rechecked; input hashes and the earlier snapshots are retained separately. These
results do not validate unrelated concurrent changes, historical stress runs or
a long session. Blender masters, all 21 streams and the existing pose bake remain
intact. No app export was requested or performed. Evidence and scripts:
`build/Other Files/Asset Toolkit/Dark Lumina 2/Spin and Walking/`,
`tests/forest-shrine/dark_lumina_2_spin_test.gd` and
`tests/forest-shrine/dark_lumina_2_spin_live_test.gd`.

To verify, run Play Goemon.command, select Dark Lumina 2, walk at changing speeds,
then press T near a target and beyond its reach. Check that stomps follow planted
steps, the entire body turns with its spin cry and flying ground fragments, and
cancelling T stops future hits/effect emissions. Borrow Spin Attack on another
fighter, then add native DL2 enemies in the wave editor and check simultaneous
use. Keep normal counts and painterly scenery. No app export is needed.


## Dark Lumina 2: airborne stomp and landing waves — 2026-10-24

The missing behavior was an aerial control path: RMB/R during an ordinary jump
started the grounded slam's upward leap again. The existing shared controller
now enters its prepared descending pose immediately, stops horizontal drift and
stomps down. Native enemies use the same minimum descent speed within their
existing army movement owner. Both owners wait for actual ground contact before
releasing the original dome and ring; the player's old delay after landing is
removed. No new simulation, effect node, material or asset load was added.

A fresh desktop launcher run passed 41 checks, with 601/602 stepped frames
focused. It covered grounded leap, rising RMB/R stomp, borrowed aerial stomp,
cancellation and twenty repeated twelve-way wave batches with fixed prepared
nodes/resources. First impact followed landing within two physics frames.
The isolated player/presentation CPU step p95 was 0.837 ms; this is not gameplay
FPS or a controlled performance comparison. Native tests at 20/30/60 Hz checked
floor-gated pulses, descent and twelve simultaneous stomps. Source pose checks
(21 assertions, 23,275 part samples), 3,074 shared-skill checks and asset
preservation passed. Body/animation assets were reused without re-export.

Choose DL2, press Space, then RMB or R while rising: he should turn downward,
land and emit both energy waves. Try the shared skill on another fighter and
cancel before landing. Evidence: build/Other Files/Asset Toolkit/Dark Lumina 2/
Jump Stomp/. These focused checks do not supersede the crowded-scene frame spikes
reported above or establish long-session performance. No app export was made.


## Kojiro: shared spinning double jump — 2026-10-24

Kojiro now defaults to the existing Musashi jump style. Explicit equipment
choices still take precedence, and restoring Original does not write a settings
override. Musashi's source tick owns lift, release-dependent height and the
two-jump budget. Kojiro reuses his existing rigid somersault, Source__801e2708,
at the shared eight-tick flip duration defined by Musashi's model. His fifteen
parts and sword remain in their original animation; this adds no rig transfer,
asset load, material construction, combat owner or army simulation. Jumping
plays only the pose. Actual air attacks retain priority and all their contacts.

Fresh desktop-launcher Metal validation passed 636 jump-style checks, including
24 Kojiro double-jump cycles, no third jump, landing reset, explicit equipment
overrides, attack interruption and character reselection. Rendered flip captures
were inspected. After four warmup cycles, twenty more kept node/resource counts
unchanged. Kojiro's held apex was 3.33234 m versus Musashi's 3.33267 m; his short
hop was 1.94238 m. The existing Kojiro combat suite passed 373 headless checks.
Asset preservation, 60 toolkit unit tests, 12,812 import checks, 98 Musashi outfit
checks, 25 Musashi motion checks and 86 structure checks passed. Existing whole-
scene shutdown resource/RID diagnostics remain separate from these assertions.

No new performance bottleneck was identified. A 360-frame isolated rendered
Hero sample was fully focused: CPU-step p95 0.573 ms, frame-interval p95/max
17.834/31.938 ms. Another Godot process was present during this run, so these
are observations rather than a controlled before/after speed comparison or a
full-army smoothness claim. The user's earlier smoothness report and historical
stress results remain separate evidence. No counts or art settings were reduced.

Verify through Play Goemon.command: choose Kojiro, leave Jump Style on Original,
press Space, then release and press Space again while airborne. Expect a single
somersault; a third press gives no lift. Release early for a short first jump.
Try an air attack during the flip and jump again after landing. Keep the shared
Musashi movement and flip duration when adjusting this behavior; do not copy a
new controller or add attack events to the jump animation. Evidence is under
build/Other Files/Asset Toolkit/Kojiro/Double Jump/. No app export or long-session
army stress test was performed.

## DL2 and Skullpion stomp landing audio — 2026-10-24

DL2's generic landing was silent because his source slot filter had no `land`
slot. Hero-owned DL2 landing events now select his prepared original B52 slam
through the existing recording slot, and the following wave cue does not replay
that impact. Skullpion retains his original ground impact and existing physical
landing ownership. Borrowed/native DL2 cues still deliver their own impact; native
stomps use the existing bounded priority voice selection. No audio player, sound
resource or pool is created by a landing.

Fresh focused desktop checks record the actual mixer and count impacts across the
whole action, including ordinary and aerial stomps, borrowing, normal falls and
saved overrides/mutes. Source pitch is retained and the captured boss impacts have
no clipped samples. The 72-check Skullpion suite, 3,074 shared-skill checks and
asset preservation passed. Evidence: build/Other Files/Asset Toolkit/Boss Stomp
Audio/. This is audio/correctness evidence, not a new frame-rate benchmark or a
long-session test. No app export was made.

The final boss stomp audio run passed 18 assertions over 636 manually stepped
frames (635 focused), with four non-clipped mixer captures.

## Five numbered special slots — 2026-10-24

The user requested a consistent 1–5 layout across every playable fighter. The
problem was input routing: the forest HUD consumed numbers for mostly empty
weapon slots, while specials lived on E/R/T and Musashi extended to 7. This was
not an identified CPU/GPU bottleneck. The existing spell loadout now caches five
native shortcuts at selection/equipment time and forwards presses/releases to
the existing character owner. Explicit borrowed spells still use the existing
prepared spell instances. There is no new army owner, animation system, effect
pool or attack-time asset load. Edo's polling-based held beam also recognizes
its numbered input, including release.

The HUD names all five slots. Q → Skills & Jump edits all five, with the original
E/R/T save keys preserved as slots 1/2/3 and two additional saved slots. Existing
letter shortcuts remain available. Goemon defaults to Dash, Surge, Sky Strike,
Coins and Chain Pipe. Musashi defaults to Rotation, Mighty Strike, D-Kick,
Grenade and held 3-Way; Fence, Homing, Guard and Charged Rotation remain in the
picker. E charge/R guard remain available. Chief keeps five weapons unless a
slot is explicitly assigned a spell. Mouse attacks, movement, jumping, cape
keys and preparation menus retain their separate roles. Ordinary enemies with
no extra native specials have empty slots ready for equipped skills.

Fresh validation passed 537 headless controls assertions before the final small
Mage-slot/menu-layout additions. The final desktop-launcher Metal fixture passed
546 assertions across all 30 stable playable IDs, including actual keyboard
presses, native ability starts, held/charged releases, all five custom slots,
save/reload, repeat suppression, pause/focus/selection cancellation, sprinting
casts and repeated Musashi 3-Way pool retirement without node/resource growth.
The final HUD and equipment captures were inspected at 1280×800 and 960×600;
Done/Restore stay visible below the scroll area. Nine recorded input/HUD sources
were unchanged throughout that run. The native army combat/animation data was
not edited by this controls change, so this was a player-input test, not a new
simultaneous-army skill benchmark.

Fresh related checks passed: shared spells 3,074; compact hotbar 33; preparation
hotkeys 45; Goemon weapons 26 and combat polish 22; Musashi assimilation 78;
asset preservation; toolkit Python/import checks 60/12,812; Musashi outfit 98;
structures 86. Two broader existing fixtures remain unsuccessful: guard hiring
accesses the removed helper `invuln` property, and Chief roster UI reports its
selected-card visibility assertion. Neither is accepted as a passing suite.
Existing shutdown RID/resource warnings also remain.

Final manual player-step p95 was 0.907 ms; direct rendered frame median/p95/max
was 16.664/18.009/169.138 ms. The fixture recorded 284 unfocused stepped frames,
with other project work running during the session. These are diagnostic
observations, not a controlled speed comparison, full-wave smoothness result,
or long-session leak claim. The earlier smooth-gameplay report and historical
stress measurements remain separate. An earlier rendered run is retained as
`initial-rendered.json`; its clipped equipment footer was fixed before the final
captures and checks.

Verify with Play Goemon.command: read the named 1–5 list, tap each available
special and hold/release those marked Hold. Try Musashi 4/5, Sasuke 1, Yae 1/2,
Ed 4 and Ranger 3. Equip a different skill in Q → Skills & Jump, switch fighters
and return, then confirm the saved assignment and its release/cooldown. Keep
future bindings in `spell_catalog.gd` and the shared loadout; do not duplicate
combat logic merely to add another key. Evidence and the reproducible fixture:
`build/Other Files/Controls 1-5/` and
`tests/forest-shrine/numbered_skills_test.gd`. No app export was made.

## Dark Lumina 3 completeness and clicked energy — 2026-10-24

The missing presentation had concrete causes: a stationary slash duplicated the
traveling energy projectile, one crescent tilted edge-on, Water/Sky effects were
retired before their source frame holds completed, and centered flame/splash
sprites buried half their height below the floor. Foreground boss cues could
also lose voices to the spatial sound throttle. Fire added an unrelated BA3
impact to every ground flame, producing clipped mixer captures. These are
presentation/correctness findings, not an established whole-game CPU bottleneck.

The smallest fixes reuse the existing controller, prepared meshes, shader
parameters, projectile leases, native projectile batches and SoundLibrary.
The wave also needs an owned additive material: source tpage 186 uses ABR 1,
which GLB cannot represent. Alpha blending had left dark triangles around it.
Native release cues now carry their actual source marker, so a coarse step
crossing frame 88 does not mislabel the first wave as a flying crescent.
RMB now uses the same click/buffer lifecycle as LMB: ground wave, flying crescent,
opposing flying crescent, one release per click. Source crescents turn about
local up at opposite 33.75° offsets and 84.375°/second; they do not tilt about
travel. Reused leases reset that orientation. Native bosses and the borrowed
Sword skill retain the full source rush. No per-unit retargeting, new renderer,
particle-node factory or audio pool was added.

Earth reuses its recovered annulus for two expanding crests and existing dust.
Wind's push area remains separate from its 44 visible damaging gusts. Water/Fire
reach another 1.5× farther, Fire retains its wider body/two falling trails and
settles onto the floor after body contact. The new repeated Wind workload warms
24 leases on selection; this fixture's complete shared pool stays at 192 with
zero misses. All 21 active ROM cues are prepared and exposed in Sound Studio;
foreground cues use the existing sixteen reserved attack voices. The eight
spatial voices retain bounded simultaneous NPC playback and sustained loops.

Fresh checks passed: 76 actual mouse/number-input assertions through the desktop
launcher; 122 headless and 138 desktop completeness assertions; native six-move
checks at 20/30/60 Hz; and 2,183 packed-projectile assertions including opposing
yaw, spin and malformed input. The final completeness run recorded all six
families, clicked energy and defeat: all eight stereo WAVs contain zero clipped
samples. Earlier clipping captures and the initial six-failure controls attempt
are retained as diagnostic evidence, not acceptance results. The successful
controls repeat passed the same LMB contacts without changing their timing.

An accepted completeness run kept all 57 tracked runtime inputs unchanged.
Its frame-interval median/p95/max was 16.653/17.568/85.295 ms, with an isolated
player/presentation step p95 of 0.883 ms. The 192 prepared leases did not grow;
200 repeated foreground sounds reused nodes/resources and cached streams.
These focused numbers exclude normal world-loop work and do not establish
full-battle smoothness or long-session leak freedom. Fresh shared-skill checks
(3,074), playable enemy checks (246), spell tuning (37), asset preservation,
60 toolkit unit tests, 12,812 imports, 98 Musashi outfits and 86 structures passed.
Existing whole-scene shutdown RID/resource diagnostics remain.

Verify with Play Goemon: select Dark Lumina 3, click RMB once and wait for the
low wave to stop the sequence, then click three times to see the two raised
crescents. Try an early second click, LMB and evade. Cast Wind at nearby troops,
Earth on landing, and Water/Fire over open terrain; check their Sound Studio
slots and repeated casts. Evidence is in `build/Other Files/Asset Toolkit/Dark
Lumina 3/Completeness/`, with actual input captures in `Dark Lumina 3/Controls/`.
Authored meshes, Blender masters and pose bakes were preserved; no app export
or long-session soak was performed.

The separate six-boss/120-troop desktop fixture passed 81 assertions over 3,600
native simulation steps and reached every move family. Presentation stayed at
114 prepared nodes; the live player-plus-NPC SFX capture peaked at 0.943 per
channel, below clipping. Native-step median/p95/max was 0.669/0.946/23.981 ms;
frame intervals were 16.663/17.159/199.677 ms. The largest spike remains visible
in the evidence; these are isolated-fixture measurements, not a controlled
speedup or a normal full-world benchmark. Later shared presentation grouping
changes were followed by another 138-check desktop completeness pass. A further
repeat had stalled on frame_post_draw when the window stopped drawing; its
occluded-completeness-desktop.log is not accepted. The capture helper now uses
the existing force_draw path so an occluded window cannot hang a screenshot.

The final additive-wave check is selected with --blade-only after the script's
-- separator. It covers the full Sword release, three requested clicks, original
sound routing, pooled reset and defeat without repeating the five untouched
spell families. Its separate rendered-blade-results.json preserves the complete
suite's report. All original GLB/Blender files remain unchanged.

Final blade acceptance passed 108 headless and 114 desktop assertions, including
the additive material, one ground wave/two flying releases, three distinct source
sounds, pooled orientation reset and complete defeat. All 57 tracked runtime
inputs stayed unchanged during the final desktop check. The shared pool stayed
at 192 with zero misses; all eight retained recordings have zero clipped samples.
The final blade capture's isolated step p95 was 0.677 ms; its maximum frame
interval was 315.021 ms including forced captures, so it is not a smoothness
benchmark. Native cue-marker assertions also pass at 20/30/60 Hz after the exact
release-tick correction. `runtime-before-blade.json`, `runtime-review.json`,
`rendered-blade-results.json` and `audio-analysis.json` preserve this evidence.

## Skullpion / Dark Lumina 2 speed and shared sand beam — 2026-10-24

The user requested fivefold movement, a larger/longer Skullpion sand beam using
Ed's logic, and faster preparation. These are movement/attack tuning changes,
not a measured CPU/GPU bottleneck. Player ground multipliers are now 5 for
Skullpion and 6 for DL2 (previously 1 and 1.2). Native DL2's existing profile
inherits the same fivefold increase. Skullpion's saved boss-speed setting also
feeds its native kit through BOSS_MOVE_SPEED=5; changing only Roles.DATA would
have been overridden by that setting. Existing walking presentation follows the
faster movement; fast leaps and all other attack clocks retain their owners.

Ed and playable Skullpion now call AttackChain.beam_pulse: local candidate
queries, fitted segment contact, one hit per victim per pulse, an end plane,
per-victim cover and the existing breakable-building path. Ed retains its source
art, shield, timing and damage. Skullpion retains its recovered dust mesh/pixels
and existing voices. Its prepared crossing mesh gives the previously flat plume
thickness; its visible width doubles, its hit reach grows from 125 to 250 metres,
and its radius is 28.8 metres. Visual and damage endpoints clip to world cover.
Only the 2.33-second preparation is compressed fivefold, to 0.466 seconds;
active/recovery animation remains at its existing rate. Holding LMB or slot 4
sustains and steers the beam, release/cancellation stops damage and audio, and
Ed's 0.2-second interval replaces the old 0.3-second cone pulses. Per-pulse damage
is unchanged, so the new cadence/held duration intentionally increases total
output. Native bosses keep finite casts within their existing army owner, with
nine pulses and the same dimensions/cover rules. No new simulation, per-unit
retargeting, attack-time mesh/material/audio loading or projectile pool was added.

Fresh desktop launcher validation passed 47 checks, including real walking,
200-metre fitted contacts, side/end limits, held mouse/number release, steering,
cover, cancellation, repeated reuse and unchanged runtime hashes. 515 of 520 stepped
frames were focused on Apple M3/Metal; repeated casts grew resources by zero.
Isolated Hero step p95 was 1.930 ms and rendered interval p95 was 17.229 ms.
The maximum interval was 843.563 ms including fixture setup/captures; these
focused results are not a full-battle smoothness claim. Native tests cover
20/30/60 Hz, side/center cover and twelve simultaneous nine-pulse casts. Ed's
61-check regression, shared spells 3,074, numbered controls 545, Skullpion drill
24, DL2 spin 39, toolkit Python/import checks 63/12,812, Musashi outfit/motion
98/25 and structures 86 passed. Original models, textures, poses and editable
masters remain intact; asset preservation passed. Existing fixture shutdown
RID/resource diagnostics remain separate from bounded runtime reuse.

Verify with Play Goemon: select each boss and walk/run, then hold Skullpion's LMB
or 4, steer across distant troops, aim at a wall and release. Keep speed in the
existing player/native profile contracts and beam contacts in the shared helper.
Evidence: `build/Other Files/Asset Toolkit/Boss Speed and Sand Beam/`.
A final normal-stat 60-second Metal battle kept all 240 enemies and 96 allies
active (48 initial bosses of each kind). It passed the benchmark's checks with
64.30 FPS average, p95/p99/max intervals 19.279/22.751/55.349 ms, 38,704 damage
events, no event gaps and all 740 deaths reinforced. Focus was 100%; tracked
benchmark inputs stayed unchanged. Prepared shared presentation nodes remained
115 and resources 1,740. Whole-scene nodes varied with the ongoing battle, so this
is not long-session leak certification. An earlier requested 120-second run ended
in ordinary shrine defeat at 97.9 seconds and is retained in Battle/, not counted
as a completed two-minute acceptance run. Faster hostile bosses change difficulty.
The final accepted report/capture is in Final Battle/.

That earlier battle exposed zero-length tower-arrow launch directions when a
large target overlaps the muzzle. Launch now uses the same direction guard as
the existing flight updater, retaining the default orientation for a zero-length
shot; impacts and arrow simulation are unchanged. The desktop fixture covers the
overlap. Native sand also compensates for the existing projectile sweep's 4 cm
forward half extent, so the first blocking building can take damage while units
behind it remain protected. Native tests cover that exact first-wall case.
The final player fixture also verifies that shortening only the windup leaves
the attack countdown within its actual duration and keeps held ownership alive.
No app export or long-session soak was performed.


## Dark Lumina 3: aligned wings and expanded energy — 2026-10-24

The user's new report concerns misaligned Wind wings, more attacks on pushed
victims and triple Wind/RMB damage and energy size. This is separate from the
user's earlier report that normal gameplay felt smooth. The diagnosed alignment
bug was a world-axis reflection (`Basis.scaled`) applied after yaw. Reflecting
the local X column fixes both layers at arbitrary facings. Existing weak owner
references now keep player/borrowed wings attached during movement and flight;
native bosses retain their fixed cast origin. Traveling and impact gusts draw
both wings in the existing batch.

The shared local push query returns newly caught victims using the existing
per-cast hit ledger; each receives one aimed paired-wing projectile, with a lead
for its outward movement. Four repeated fan shots replace two, for 88 baseline
shots per cast plus the newly caught victims. This avoids a separate army scan
and avoids multiplying victim volleys by all 22 pulses. Wind shots travel at
90 metres/second for 1.2 seconds. Damage triples to 73.125 per shot at default
base damage. The measured repeated workload warrants 256 prepared Wind leases;
three casts among 51 native targets keep the complete pool at 424 with no misses.
Greater densities can still grow the existing pool. Wind impacts use their own
paired green gust instead of also creating generic golden impact visuals.

All three RMB meshes and contact radius grow another threefold, to a 6.3-metre
radius; damage triples to 975 at default base damage. Click sequencing, source
release markers, LMB and cover checks remain intact. Shared prepared kit data
also feeds enemy and borrowed Sword. No source/Blender/pose-bake change or new
simulation, renderer, retargeter or audio system was required.

Fresh tests passed: controls 76, completeness 123, media/borrowed skills 126,
spell tuning 37, packed projectile buffers 2,184, shared spells 3,074, native
six-move tests at 20/30/60 Hz, native Skullpion regression, asset preservation,
63 toolkit unit tests, 12,812 import checks, 98 outfits and 86 structures. The
broader playable-enemy suite passed DL3 but ended at 245/246: Skullpion's original
attack failed its contact assertion. This run is not a whole-roster pass.

The fresh six-boss/120-troop desktop launcher fixture passed 81 checks across
3,600 native steps and all six move families. Its prepared presentation node
count stayed at 115. Live SFX peak was 0.903, below clipping. Native integration
step median/p95/max was 0.652/0.953/29.258 ms; rendered frame intervals were
16.662/17.293/192.020 ms. The maximum remains visible in evidence. A separate
native-only stress used six bosses, 96 allies and three repeats, reaching 598
projectiles with a maximum native step of 0.190 ms. These isolated measurements
are not a controlled speedup or a full-world smoothness/long-session leak claim.
Existing fixture shutdown RID/resource diagnostics remain.

Verify in Play Goemon: cast Wind, turn diagonally and float sideways to check
both attached wings; push a spread-out group and watch aimed green pairs reach
them. Click RMB three times to see the larger ground wave and two crescents.
Keep mirror transforms local, deduplicate target volleys within the cast, and
repeat the expanded workload before changing pool capacity. Current evidence is
under `build/Other Files/Asset Toolkit/Dark Lumina 3/Wind And Energy/`, including
angle captures, native stress, live audio peak and desktop timing reports.
A final normal-stat 60-second Metal battle kept all 240 enemies and 96 allies
active (48 initial bosses of each kind). It passed the benchmark's checks with
64.30 FPS average, p95/p99/max intervals 19.279/22.751/55.349 ms, 38,704 damage
events, no event gaps and all 740 deaths reinforced. Focus was 100%; tracked
benchmark inputs stayed unchanged. Prepared shared presentation nodes remained
115 and resources 1,740. Whole-scene nodes varied with the ongoing battle, so this
is not long-session leak certification. An earlier requested 120-second run ended
in ordinary shrine defeat at 97.9 seconds and is retained in Battle/, not counted
as a completed two-minute acceptance run. Faster hostile bosses change difficulty.
The final accepted report/capture is in Final Battle/.

That earlier battle exposed zero-length tower-arrow launch directions when a
large target overlaps the muzzle. Launch now uses the same direction guard as
the existing flight updater, retaining the default orientation for a zero-length
shot; impacts and arrow simulation are unchanged. The desktop fixture covers the
overlap. Native sand also compensates for the existing projectile sweep's 4 cm
forward half extent, so the first blocking building can take damage while units
behind it remain protected. Native tests cover that exact first-wall case.
The final player fixture also verifies that shortening only the windup leaves
the attack countdown within its actual duration and keeps held ownership alive.
No app export or long-session soak was performed.

Final focused desktop acceptance passed all 32 checks, with local mirrors at
0/45/90/225 degrees, movement/flight attachment, three click releases, real
contacts on separated pushed targets and three repeated casts among 51 targets.
Its pool stayed at 424 with zero misses; all nine tracked runtime inputs stayed
unchanged. Frame interval median/p95/max was 16.650/17.759/23.580 ms and isolated
manual step p95 was 4.074 ms. These focused timings include the fixture work,
not a normal full-world benchmark. Angle views and three enlarged energy
releases were inspected; the separate encounter view confirms both large wings.

## Both Dark Lumina forms: source effects and impact shape — 2026-10-24

The user reported missing glow/effects and a first energy wave that changed
shape on enemy contact. This investigation found presentation mismatches, not
a new measured CPU bottleneck: lost PSX additive material flags, fixed opacity
attenuation, a frozen casting-aura palette, a procedural Earth ring substituted
for shared actor 0x352, and missing defeat layers. Ground-wave impact incorrectly
selected the flying-crescent graphic and could move it up to the enemy's body.

The smallest fixes reuse prepared kit materials, the existing atlas/morph
shaders, character projectile leases and army MultiMeshes. Lumina sprites select
full source opacity while unrelated users keep the previous default. Wind keeps
its textured inner blend and additive outer layer. The casting aura prepares
four recovered CLUT phases offline, retaining its source scale/offset/attachment
and eight-tick presentation; combat plays the prepared atlas. Earth shares the
same recovered flame-wave mesh/shader as DL2. Existing batches present DL2's
additive defeat dome/ring/fragment and DL3's eight radial burst planes. No new
per-enemy renderer, runtime texture upload, asset loader or material factory was
introduced in attack/hit loops. Combat stats, release counts, damage, cooldowns,
travel and hit delivery remain under their existing controllers.

The first low energy wave now retains its mesh, size, facing and flight height
on contact. Native impact events distinguish it from the following crescents;
player, borrowed and enemy presentation consume the same prepared effects.
Source impacts replace duplicate generic graphics while preserving feedback.

Fresh desktop Metal checks passed 67 focused effect assertions and 139 DL3
completeness assertions covering all six families, source sounds and repeated
leases. DL3's pool stayed at 424 with no misses. DL2 passed 130 gameplay checks
over 2,806 focused manual frames, with 60 released shots, pool 76 and no misses.
The focused repeated workload includes twelve simultaneous stomp/defeat
sequences, all 96 burst planes, delayed cleanup, and stable 115 prepared
presentation nodes/resources. These are focused correctness checks, not FPS
measurements. Headless transform readback is unsupported by Godot's Dummy
renderer, so movement/facing attachment is checked in the desktop run.

A fresh 60-second normal-stat battle kept all 240 enemies and 96 allies active,
starting with 48 each of DL2, DL3 and three soldier types, reinforcing every
death. It passed the harness's acceptance checks at 60.07 FPS average, p95/p99
18.78/24.83 ms and maximum 162.99 ms. Focus was 100%, tracked runtime inputs
stayed unchanged, 50,797 damage events were delivered with no gaps, and all
3,358 deaths were reinforced. Resources stayed at 1,773; whole-scene nodes and
memory varied with corpses/effects, so this is not a long-session leak claim.
Occasional hitches remain. Metal GPU timestamps were unavailable, and this
run does not establish a controlled speedup. The saved subclass determines the
actual roster; an annotation corrects the inherited harness's default roster
label without changing its raw report. Original additive defeat flashes are
very bright when multiple bosses die together; no count or art reduction was
used to pass the battle.

Fresh source/toolkit checks passed 65 Python tests, 12,812 imported asset checks,
98 Musashi outfit checks, 86 structure checks, 3,074 shared-spell checks, native
six-move checks at 20/30/60 Hz and 23,275 original DL2 pose samples. All 223
tracked protected assets retained their hashes; optimized preservation passed.
The effect audit found no read errors or budget warnings. Existing fixture
shutdown RID/resource diagnostics remain. No app export was made.

Verify in Play Goemon: select DL3, strike a nearby enemy with the first energy
release and watch it retain its low crest. Cast Wind, Water/Fire and Earth;
look for the animated blue casting aura and travelling orange flame waves.
Select DL2 for the fire/charge/impact sprites and both stomp waves. Review
defeat layers and simultaneous use through `dark_lumina_effects_test.gd`.
Evidence, source disassembly, four palette captures, the protected-asset hashes
and the normal-stat battle are under `build/Other Files/Asset Toolkit/Dark
Lumina Effects Restoration/`. Original story/QTE/camera emulation and a
long-session soak remain outside these checks.


## Warcraft shared skills and five native mirrors — 2026-10-25

Wind Walk, Mirror Image and toggle Immolation extend the existing skill catalog,
spell-instance lifecycle and AttackChain. Mirrors are five timed kind-31 leases
in the current native army, using its AI, local queries, combat, spatial upload
and pooled audio. There are no mirror actor/skeleton nodes or second simulation.
Critical Strike remains the recovered Attack Slam and original sound/contact.
Recovered emitter resources are created at selection; their nodes inherit the
visible model's rotation/size. Aura hits use pooled army feedback. The only
camera-dependent pose correction affects the original billboard effect bones.

No gameplay bottleneck or speedup is claimed. The small implementation avoids
predictable repeated workloads: whole-army scans, per-hit materials and per-clone
controllers. A 57-bind / 362-row atlas prepares the original mirror animation
offline. Its sampled transforms match the source exactly, with original nine
geosets and opacity. Keep effect textures, emitter metadata and editable masters
as the source of truth; rebuild the atlas if its fingerprints become stale.

Fresh headless and desktop skill runs each pass 55 checks. All five mirrors cast
one storm each and continue melee; repeated cast/cancel adds zero nodes/resources.
The desktop fixture's frame interval p95 is 17.466 ms and manually timed
player/native/presentation work p95 is 1.295 ms. No unrelated benchmark ran
concurrently. These short fixture results are separate from the user's historical
smoothness report and from earlier character/balance timings above. They do not
establish full-army performance or long-session memory behavior. Existing scene
shutdown warnings remain. The older Explorer hunting test has three guard-radius
expectation failures; the guard branch is unchanged by this skill work.

Verify via Play Goemon: Blademaster right click / third combo for Critical Strike,
2 for Wind Walk, attack to break stealth, 3 for five mirrors; wait 15 seconds,
recast after cooldown, then switch fighters. Demon Hunter 2 toggles Immolation:
stand beside enemies for several one-second ticks, move behind solid cover and
toggle off. Q → Skills & Jump equips these spells on another fighter. Model size
is still visual, so the enlarged mirrors overlap around a single small target;
collision/reach were not scaled to hide this. Details, source paths, rebuild
commands and current check counts are in [recovered-warcraft.md](recovered-warcraft.md).
No app was exported.

## Universal Mirror Image and Wind Walk — 2026-10-25

The marching behavior and measurements in this section are historical. The
immediate-pursuit follow-up below supersedes the opening formation and march.

The Wind Walk rectangle was a blending error, not a performance bottleneck:
black-backed glow art was being alpha blended. A prepared additive material
removes that rectangle; the caster's translucent model remains visible.

Mirror Image now copies the selected fighter instead of always spawning a
Blademaster. Five character bodies/controllers are prepared on selection, with
loadout changes prepared when equipped. Casts reuse those bodies and existing
projectile pools. The native army still owns their health, nearby target queries,
formation and marching. The single adapter runs the original character attack
motion only while attacking. No legacy army backend, per-enemy renderer or runtime
retargeter was added. Source assets, ordinary army counts and quality are retained.

The opening spreads for 1.2 seconds and marches for another two seconds before
engaging. Movement follows the cast direction independently of the player.
Attack choices are random; Bladestorm is optional and copies cannot summon more
copies. The native handle accompanies each command so a retired generation cannot
command a reused body. Expiry, death, selection and cancellation clear held inputs,
projectile leases and effects. Ally feedback avoids pausing or kicking the real
player's camera when an image lands a hit.

Fresh verification for this change:

- Universal headless fixture: 338 checks, all 32 character models and original
  attack paths, equipped offensive skills added after Mirror Image, no recursion,
  no caster hit pause, independent marching, separation, expiry, worker completion,
  stale-command rejection and native death. Headless timings are not evidence of
  rendered smoothness.
- Desktop launcher: 56 skill checks, including Wind Walk's rendered appearance,
  five simultaneous attacking images, randomized choices, repeated cast/cancel and
  no retained resource growth. The open-field rendered formation check passes nine
  assertions across Blademaster, Goemon and Demon Hunter with real native terrain.
  Its frame p95/max was 17.393/33.380 ms; native/copy/presentation work p95/max was
  1.482/1.896 ms. This is a focused fixture, not a controlled speedup or full-army soak.
- Shared regressions: 3,398 modular skills, 577 numbered controls, 4,109 native
  runtime, 423 Warcraft character, 10 projectile-pool and five worker-target checks.
  Master Chief gameplay (29) and ballistics (27) pass. The native mirror assertion
  test verifies boundary validation, independent movement, a non-storm first choice,
  all random choices, busy suppression and stale generations.
- Preservation check, 67 toolkit unit tests, 12,812 imported-asset checks, 98 Musashi
  outfit checks, 13 motion checks and 86 structure checks pass. No asset or app export.

Two older Master Chief sword-fixture failures (blade/glow expectation and its
close-range hit placement) also reproduce with the controller before the mirror
changes. They are not counted as passing. The fixture's removed renderer flag and
stale pose assignment were updated to the native runtime. Whole-scene teardown
resource/RID warnings remain; the live repeated-summon resource delta was zero.
Logs, reports and captures are in `build/Other Files/Asset Toolkit/Warcraft/Mirror Image/`
and the `build/Other Files/mirror-*.log` files.

To verify the feel, use Play Goemon, select Blademaster and press 2 for Wind Walk:
there should be a translucent fighter without a rectangular background. Press 3
for Mirror Image, then turn or move away: the five copies spread and continue
forward independently. Equip Mirror Image on another fighter in Skills & Jump;
the copies should look like that fighter and use its prepared attacks. Repeat
casts after cooldown and watch for frame spikes or lingering shots. Keep the
existing separate model-size, reach and attack-speed balance controls; do not
change army counts or art quality to hide a regression.

## Warcraft native energy colors and larger bolt — 2026-10-25

Illidan's original glow meshes/particles now use purple; Blademaster's use red.
The smallest change is a hue-neutral copy of each existing glow texture, cached
at selection/setup, plus owned material/particle tints. Preserve brightness,
alpha, regenerated mip levels and original animated geometry. Keep shared source
images untouched so skin/clothing or another instance cannot inherit a tint.
The same prepared resources serve mirror copies and pooled projectiles; no new
aura system, per-cast texture conversion or frame-loop material creation is needed.

The demon bolt's visual diameter is three times larger. Its native black-backed
texture now uses additive blending to avoid a visible square. Release timing,
damage, swept hit radius, flight speed, lifetime and pool capacity are unchanged.
There is no measured gameplay bottleneck or speedup claim for these visual edits.
This is separate from the user's historical report that ordinary gameplay feels
smooth and from the older stress measurements elsewhere in this guide.

Verify in Play Goemon: select each fighter, inspect its ground/weapon glow, cast
Bladestorm or Immolation, and summon mirrors. Illidan's transformed left click
should throw the larger purple bolt. Repeat casts and switch fighters to catch
stale particles or shared-material changes. Keep army counts, art and combat
settings unchanged while judging the result. Focused logs and comparison captures
are in `build/Other Files/Asset Toolkit/Warcraft/Energy Colors/`; the energy test
checks twelve simultaneous bolts over five reuse cycles and stable resource/cache
counts. These focused checks do not establish full-army or long-session performance.

Fresh verification: 79 rendered energy checks, 423 character checks and 56 skill
checks pass through the desktop launcher. Five rounds of twelve simultaneous
bolts add no cached textures/resources or pool misses. The settled mirror run
adds zero nodes/resources; an earlier immediate count included live hit flashes.
Native atlas preservation passes 1,057 checks with zero transform error; toolkit
preservation and the required common import/outfit/structure checks also pass.
The skill fixture's frame interval p95 was 17.173 ms and manually stepped work
p95 2.011 ms. These are short-fixture observations, not a controlled speedup.
Existing whole-scene teardown warnings remain. No app was exported.

## Mirror Image immediate pursuit — 2026-10-25

The user removed the march opening: images now immediately pursue the nearest
living enemy visible to the existing 48-unit local search, regardless of the
caster's facing. They wait when no local target is visible and reacquire when
one appears or their target dies. The 1.2-second formation, two-second march
and forward marching fallback were removed, including their unused native state
and setup arguments. Spawn clearance, five copies, native navigation/health,
random attacks, lifetime, damage and cooldowns retain their existing owners.
This shared skill behavior also applies when another fighter equips Mirror Image.

This is a behavior correction, not a measured performance bottleneck fix.
It reuses the current native spatial query and prepared character bodies. Earlier
engagement exposed an existing Goemon copy coin call that dropped its attack
ticket; passing that existing ticket preserves ally hit feedback. No new model,
material, pool or army simulation was introduced. The repeat-cast fixture now
compares after temporary hit effects settle on both sides of the measurement.

Verify with Play Goemon: select Blademaster, face away from nearby enemies and
press 3. All five images should turn toward enemies immediately, without forming
ranks or marching first. Move away, let them defeat a target, then repeat after
the cooldown. With no visible enemy nearby, they wait until a target appears or
their 15-second lifetime ends. Keep the existing local search and native movement
when extending this behavior; avoid whole-army scans or per-copy pathfinding.

Fresh verification passes the native mirror assertions, 338 universal-character
checks, 12 desktop pursuit checks and 56 desktop Warcraft skill checks. Repeated
cast/cancel retained zero nodes and zero resources after effect cleanup. The
pursuit fixture recorded frame p95/max 17.357/31.602 ms and manually stepped
native/copy/presentation work p95/max 2.862/22.518 ms. The repeated-skill fixture
recorded frame p95 17.173 ms and stepped work p95 2.011 ms. These are short
fixture diagnostics, not a controlled speedup or full-battle/long-session result.
The old march baseline had no enemy and is not a like-for-like performance test.

Shared checks passed: native runtime 4,109, worker 247, toolkit Python 67,
imported assets 12,812, Musashi outfit 98, motion 13 and structures 86. Asset
preservation passed after the source edits. Initial coin-attribution and unsettled
node-count failures remain in the earlier logs; final runs have zero failed
assertions. Existing whole-scene shutdown RID/resource warnings remain. Evidence:
`build/Other Files/mirror-hunt-*.log` and pursuit captures/report under
`build/Other Files/Asset Toolkit/Warcraft/Mirror Image/`. No app was exported.

## Mirror Image spacing — 2026-10-25

The user found the immediate-pursuit copies too bunched up. They previously
spawned only 1.5 units apart and shared the same contact destination. They now
spawn around the caster at a radius of 4–8 units, based on visible model scale,
and use different approach sides at 80% of their existing attack reach. The
existing spawn-clearance search can tighten spacing in cramped places. A blocked
approach falls back to the normal contact destination; collision sizes and actual
attack reach are unchanged.

The native local query still favors nearby visible enemies, with a soft preference
for targets other copies have not claimed. A lone enemy remains valid for all
five. The existing shared native decision pass collects the few mirror claims
once; copies reuse that small list instead of scanning the army for one another.
A prepared direction per lease selects the approach. Original controllers still
own attacks, damage, effects, cooldowns and the 15-second lifecycle. This is a
spacing change, not a measured CPU/GPU bottleneck fix or speedup.

Verify through Play Goemon: summon near several spread-out enemies and watch
copies choose different opponents. With one enemy, they approach different sides.
They still engage immediately and may visually overlap during large attack poses
or in tight terrain; spacing does not increase melee reach or change model size.

Fresh checks pass: native assertions for distinct attack positions, five separate
nearby target choices, blocked-side fallback, validation, immediate pursuit and
lifecycle; 20 rendered spacing/pursuit checks; and 56 rendered Warcraft skill
checks. Repeated casts retain zero nodes/resources after effect cleanup. The
rendered spacing fixture recorded frame p95/max 17.194/33.464 ms and stepped
native/copy/presentation work p95/max 3.870/22.600 ms. The repeat-skill run recorded
frame p95 17.140 ms and stepped work p95 2.084 ms. These are focused diagnostics,
not a full-army stress test or a controlled speed comparison; the spacing fixture
now observes longer attacks and adds a crowd-target case.

Native runtime (4,109), worker (247), toolkit Python (67), imported assets
(12,812), Musashi outfit (98), motion (13), structures (86) and asset preservation
pass. The previous 338-character assertion run is historical and was not repeated
for this spacing change. Existing whole-scene teardown RID/resource warnings
remain. Logs are `build/Other Files/mirror-scatter-*.log`; inspected captures and
`scatter-desktop.json` are under
`build/Other Files/Asset Toolkit/Warcraft/Mirror Image/`. No app was exported.

## Illidan meta first-person hands — 2026-10-27

This is an appearance/animation change, not a measured simulation bottleneck fix.
The user approved natural resting wrists and curled fingers, then requested a
clearer open-palm cast, twice-thicker arms, and twice-sized palms/fingers/claws.
The prepared close-up sculpt uses 33,094 triangles, two meshes/materials, and 37
bones. The generic hero triangle budget warns at 12,000; keep this deliberate
single-player close-up detail rather than silently reducing it or instancing it
for the army. The lossless candidate is larger and offers no draw reduction,
so gameplay retains the authored source. Twenty-four synchronized rendered
source/candidate pairs have zero pixel difference; 425 imported-pose checks pass.

Load the prepared GLB once on selection; during combat seek its two baked clips.
It reuses Chief's viewport, bob and world-muzzle mapping, the existing shared aim
trace and the existing bolt pool. There is no per-frame mesh building, asset
loading, material creation or retargeting. The world/army model and native combat
owner remain separate. Keep finger joints and the exported palm socket together
when resizing. The immediate socket update prevents a frame-old muzzle position
from corrupting the release and eye-to-hand cover check.

Fresh desktop shooter verification passes 42 checks with zero retained nodes,
zero retained resources and zero pool misses after repeated firing. Its rendered
frame p95/max were 17.013/19.274 ms and stepped work p95 was .410 ms. Background
asset verification was also running; these are short fixture diagnostics, not a
controlled speedup measurement or a long-session/full-army stress result. The
existing user's report of smooth general gameplay remains historical experience.

Verify through Play Goemon: select Illidan, enter meta, check the curled resting
hands, hold LMB while aiming and strafing, then release. Palms should open and
push forward at the shot, all five fingers remain attached, and the pose returns
to rest. Test close cover, pause/resume, reverse morph and character switching.
The actual Wind Meadow captures and logs are under
`build/Other Files/Asset Toolkit/Illidan Hands/Final/` and its parent folder.
No app export was requested or made.

Additional checks for this hand revision: toolkit Python 69, shared imported
assets 12,812, Musashi outfit 98 and structures 86 pass. Staged preservation also
passes. The older 434-check Warcraft desktop fixture first missed its final
repeated-contact expectations (9/10 Blademaster and 0/10 Illidan); a diagnostic
rerun of the unchanged fixture passed all 434 with correct launch positions.
That fixture manually steps CharacterBody movement outside the dedicated physics
step driver and remains timing-sensitive; this revision does not claim to fix
that harness. The focused 42-check shooter fixture uses the existing physics-step
driver and passes on the final source. Both older-fixture logs are retained as
`final-characters-desktop.log` and `characters-debug-final.log` beside the hand
captures, rather than treating the earlier failure as a gameplay pass.

### Thumb opening and finger-length refinement — 2026-10-27

The four non-thumb finger chains are now 10% shorter, while the thumbs spread
farther during the cast. This only edits prepared mesh/bind data and six authored
thumb animation curves; triangle count, surfaces, runtime allocation and combat
logic are unchanged. No new performance bottleneck or speedup is claimed.
The fresh desktop fixture passes 46 checks, including both thumbs opening and
returning to rest, with zero retained nodes/resources and zero pool misses.
Frame p95/max were 17.959/34.140 ms and stepped work p95 was .788 ms; these remain
short fixture diagnostics, not a controlled comparison or long-battle result.
The imported source/candidate pose checks pass 425 assertions. Source preparation
also asserts .9 segment length for all eight affected finger chains. The older
434-check harness caveat above remains historical and was not retested for this
asset-only follow-up. Logs and actual gameplay captures are in
`build/Other Files/Asset Toolkit/Illidan Hands/Thumb Spread/`.

### Fuller palms and smoother finger bases — 2026-10-27

The user approved a fuller palm with less prominent finger-base bones. This is
an offline sculpt change in the same editable hand master: the palms and wrist
transitions are smoother, and the oversized MCP bulges taper into the existing
finger shafts. Claws, bind rig, skin weights, topology, animation keys, materials
and the 33,094-triangle/two-surface budget are unchanged. It adds no runtime work
and is not a measured performance optimization. The source sculpt script checks
the preserved rig, animation, weights, topology and claws before saving.

Fresh Play Goemon verification passes all 46 shooter checks, including repeated
aimed casting and pose recovery, with zero retained nodes/resources and zero
pool misses. Rendered frame p95/max were 17.231/33.451 ms and stepped work p95 was
.592 ms. These are short fixture diagnostics, not a controlled before/after
benchmark or a long-session/full-army stress test. Actual Wind Meadow captures
show both resting and open casting hands with 40 enemies; the existing pooled
bolt path reports zero misses. The imported source/candidate checks pass 425,
toolkit Python checks 69, shared imported assets 12,812, Musashi outfit 98 and
structures 86. Preservation passes, and all 24 synchronized source/candidate
render pairs have zero pixel difference with hashes matching the final exports.
The lossless candidate still offers no draw reduction, so gameplay uses the
authored source. The older broad Warcraft fixture caveat above still applies.

To verify the appearance, launch Play Goemon, select Illidan, enter meta and
alternate between resting and held fire: the fingers should flow into the fuller
palm without large round joints, and the thumbs should still spread during the
cast. Evidence is under
`build/Other Files/Asset Toolkit/Illidan Hands/Fuller Palms/`. No app was exported.
