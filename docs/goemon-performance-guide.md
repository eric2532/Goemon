# Keeping Goemon smooth

Saved 2026-10-23 at the user's request: general gameplay now feels really smooth.
The user wants future performance work explained so they can learn the process.
This is project knowledge, based on source and saved reports, not a new benchmark.

## Kazi planted run and reduced bounce — 2026-11-06

The user clarified that the problem was sliding feet or excessive bounce.
The previous run often kept the visible boot under the torso instead of moving
one planted foot backward through stance. Eight replacement run masters now show
forward heel contact, backward stance travel, toe-off and recovery, preserving
Kazi's illustrated identity and long slim curved sword. Original and prior
illustrated masters remain intact. The active 56-sheet recipe selects these
runs from `assets/references/crossgate_kazi_hd/revisions/run-contact/masters/`;
each has its exact built-in ImageGen submission and hash sidecar.

The small runtime fix advances the normalized stride from actual horizontal
travel, including collision slowdown, rather than intended velocity. Blocked
movement holds phase and displays idle; airborne movement holds the stride and
emits no footfalls. Turns and walk/run transitions retain phase. A two-metre walk
cycle matches the existing cautious walking cadence; the illustrated run uses
4.4 metres per full cycle. That value comes from side-view stance travel of
1.219 m over 5/18 of a cycle (4.389 m, rounded to 4.4). The editable measurement
record is `revisions/run-contact/stride-calibration.json`. Existing player/native
mirror movement already supplies actual velocity, so no new owner, search,
retargeting, resource load, material or pool was needed. Goemon walking/landing
samples, recovered sword/contact cues, controls and combat timings remain intact.

Offline side-view crown travel falls from 3.24/4.72 prepared pixels to 1.89/.87
for right/left runs. These are pose-registration measurements, not frame times.
Other directions use the same physical stride with drawn foreshortening; the
18 discrete frames approximate continuous contact, not per-foot 3D locking.
The current atlases occupy 119.383 MiB RGBA, slightly below the prior 119.703 MiB,
shared once across Kazi instances. No quality, army count or terrain reduction
was used.

Fresh checks pass 82 desktop-launcher and 64 headless Kazi assertions, including
equal travel at different speeds producing equal phase, obstruction, opposite
foot contact, phase continuity, original audio, repeat attacks/resources and five
native allies. A moving-ground capture uses normal engine physics at the actual
10.2 m/s movement limit. Its earlier manual-step screenshot fixture exaggerated
reported speed because move_and_slide used render delta outside a real physics
callback; that rejected recording is preserved under Run Contact/Rejected/ and
is not evidence of normal gameplay. The replacement capture samples frames by
wall time, records timestamps and avoids an extra forced render. Its readback/PNG
capture rate is about 12 fps and must not be mistaken for game rendering FPS.
75 toolkit unit, 12,973 imported, 98 outfit, 25 motion and 86 structure checks
pass; asset audit reports 310 assets / zero read errors and preservation passes.
Earlier audio/shared-system counts below remain from the prior unchanged audio
implementation. No claim is made that the unrelated borrowed DL2 headless audio
failure below was fixed.

The Mac was unlocked and the previously pending foreground comparison completed.
Fresh standard Wind Meadow, 1280×800, painterly art, normal stats and 240 enemies /
96 allies were retained. These image comparisons hold the new distance-driven
clock constant: only the illustrated motions manifest differs among captured
source fingerprints. They do not independently isolate the clock change.
All runs retain full focus, real-time simulation, zero errors/changed inputs or
dropped hits, 2,124 resources and 8,623 nodes. CPU memory decreases slightly during
each after sample rather than growing.

| Foreground sample | FPS | p95 ms | p99 ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| Prior run artwork, 12.006 s | 103.70 | 17.569 | 28.135 | 36.432 |
| Corrected run artwork, 12.011 s | 112.07 | 16.874 | 20.936 | 66.426 |
| Corrected artwork repeat, 12 s | 111.97 | 16.946 | 25.204 | 67.261 |
| Corrected artwork with spike profiling, 12 s | see saved report | 16.854 | 22.835 | 40.521 |

Typical frame intervals did not regress in these short samples; this is not a
causal speedup or a hitch-free guarantee. Two after samples contain larger
66–67 ms hitches. The existing spike diagnostic did not reproduce a >50 ms frame,
so their cause is unconfirmed and must not be attributed to sprites or the native
army without more evidence. The background diagnostic has insufficient foreground
focus and is excluded from this comparison. Earlier 60-FPS pixel-art measurements
are historical; they were not collected under this fresh paired session.

Verify through Play Goemon: select Kazi and run alongside a visible ground detail,
then turn, accelerate, slow down and press into an obstacle. Look for a forward
heel plant/backward stance and a steady torso, with Goemon footsteps/landing.
Current evidence is under `build/Other Files/Cross Gate 102488/HD Preview/Run Contact/`:
`actual-running.gif` is sampled normal movement, `contact-before-after.gif` compares
rendered poses, and the before/after/repeat/diagnostic reports retain all spikes.
No app export or long-session soak ran. The previous first revision below is
historical and its locked-screen performance status is superseded here.

## Illustrated Kazi, first run revision and longer blade — 2026-11-06 (historical)

The user chose the illustrated concept across all animations, then requested a
better run, a longer sword retaining its slim curved shape, and Goemon's landing
sound as the shared default. Playable Kazi now uses 56 newly illustrated clips
(seven actions in eight directions), retaining 872 frame slots, original clip
durations and recovered sword sound markers. Original pixel art remains intact.
The approved style identity, longer-blade identity, editable sheets and exact
revision submission records are under `assets/references/crossgate_kazi_hd/`;
that directory is excluded from imports/exports. Runtime derivatives live in
`assets/characters/crossgate/kazi_hd/` and must be rebuilt with the saved baker.

The visible run problem was held poses followed by large stride jumps. New run
sheets provide distinct stride phases. Rendered review also exposed generated
row-baseline drift: feet could sink into the floor as the timeline crossed a
sheet row. Offline head registration removes those row offsets while retaining
movement within each row. Neutral-body measurement excludes the thin blade,
retains boots and calibrates running head width against idle so bent knees do
not shrink the body. Final fallen poses settle onto the floor. These are asset
preparation fixes, not a measured CPU/GPU bottleneck or runtime retargeting.
The standing body retains Goemon's 3.2206185 m reference height.

The existing Sprite3D, shared atlas cache and pooled native ally bodies remain
in use. Setup loads the eight shared atlases once; play changes their prepared
regions/offsets. The normalized full-stride clock retains phase across turning
and walking/running, uses the existing Goemon cadence and emits two grounded
footfalls per stride. Shared casting restarts at frame zero and advances through
the existing skill owner. Movement, melee queries, damage, reach, cancellation,
army ownership and attack sound timing retain their existing controllers.

Goemon's prepared walking sample remains the universal footstep fallback; the
prototype `audio/step.wav` is never a gameplay/preview fallback. The shared landing
fallback now also uses Goemon's prepared ROM event 21E. Distinct recovered audio,
authored silence and user recordings/gain/mutes keep priority. Skullpion's own
landing impact remains specialized through original_for, preserving its stomp.
No new audio pool, per-hit resource load or material construction was added.

Asset cost: 119.703 MiB RGBA texels across eight cropped shared atlases versus
85.5 MiB for original pixel art, an additional 34.203 MiB shared once, not per
ally. All 872 illustrated frames remain distinct. PNG disk size does not measure
GPU residency; no texture-quality or army-count reduction was used.

Fresh final validation passes 78 desktop-launcher and 61 headless Kazi checks,
236 footstep, 122 landing-audio, 161 shared-character checks, 75 toolkit unit tests,
12,973 imported checks, 98 Musashi outfit, 25 motion and 86 structure checks.
Asset audit reports 310 assets / zero read errors; active preservation passes.
The GLB audit does not audit sprite pixels: Kazi separately checks all source
clip durations/sound cues, 58 saved master/reference hashes, derivative hashes,
56 transparent grids with no opaque art crossing cell edges, and planted idle
frames. Desktop captures verify straight walking/running, size alongside Goemon,
attack, cast, hurt, final fall and five native allies. Real SFX recordings contain
Kazi's recovered sword/contact and exactly one Goemon physical landing. Twelve
repeated attacks retain no extra nodes/resources. These focused checks do not
certify a long session or full-army smoothness.

An unrelated borrowed Dark Lumina 2 shockwave headless audio assertion remains
failing with heard=[] (13/14 boss-audio assertions pass). Restoring the previous
shared-landing behavior reproduces that same failure; both diagnostic logs are
retained. Native Skullpion/Dark Lumina impact checks and override priorities pass.
This is not reported as an all-passing broader boss-audio suite.

A fresh original pixel-art control, collected earlier during this work, measured
60.006 FPS, p95 18.020 ms, p99 19.198 ms and max 20.415 ms over 12.015 seconds at
1280×800, normal stats, painterly standard Wind Meadow, 240 enemies / 96 allies,
full focus, matching simulation progress and zero errors/dropped hits.
The final illustrated revision has **no valid foreground performance result yet**:
macOS reports CGSSessionScreenIsLocked=Yes and Godot cannot acquire foreground
focus. The benchmark correctly refuses to measure; the failed attempt is saved
in `HD Preview/after-final.log`. Earlier measurements above/below remain historical
and must not be represented as passing on the final illustrated revision.

Verify through Play Goemon: select Kazi, walk/run straight and turn while moving,
check his boots stay grounded and compare body height with Goemon. Attack a target
and empty air, cancel with evade, then jump/land and listen for Goemon's footsteps
and landing. Review `HD Preview/run-before-after.gif` (sampled rendered poses,
not a live movement recording), the seven eight-direction GIFs and actual game
captures/audio. With the Mac unlocked, rerun the same 240/96 foreground benchmark
and compare its frame-time spikes and memory with `HD Preview/Before/` before
claiming unchanged smoothness. No app export or long-session soak was run.

## Kazi straight directions, Goemon size and recovered audio — 2026-11-06

The user noticed that straight travel displayed diagonal artwork. The original
sprite's actual direction order is NW, N, NE, E, SE, S, SW, W; the decoder's
generic direction labels start at N. The first port used those labels directly.
The smallest fix adds one to the existing eight-way index. Four explicit
front/back/left/right walk assertions failed before the fix and now pass for
walking and running. Original pixel origins, animation samples and phase
continuity are unchanged. The source contains 19 actions / 152 directional
clips; the seven bundled gameplay actions already contain all eight angles.
No extra 3D angles or interpolation are present in this source record.

Kazi now uses Goemon's shared 3.2206185 m standing-body reference. Front stand
clip 95 spans 83 pixels from hood top -76 to shoe edge 7, excluding the blade
and sparks. Pixel scale comes from that shared reference; the seven-pixel foot
offset grounds his shoes. A side-by-side desktop capture verifies the result.
Collision, movement, damage, contact reach and authored animation timing retain
their existing owners; no textures were rescaled or new meshes introduced.

The extractor now retains original frame sound cues and checks both recovered
PCM hashes. Sound 103 / cgply01a.wav plays at zero-based attack frames 3/7;
source direction 0 contains only frame 3. The attack captures its existing cue
array once, then advances a bounded cursor through it. Camera orbit cannot
replay a cue. Confirmed contact uses recovered generic Cross Gate physical
impact 255 / cgefc04.wav. Kazi-specific server impact selection is unverified;
this mapping remains an explicit Goemon adapter. Misses have swing audio only;
dodge, selection and focus cancellation discard pending attack sounds. Existing
SoundLibrary defaults, recordings/gain/mutes, nearby-ally admission and bounded
voice pools remain authoritative. No combat-time loads, new pool or material
creation were added. Twelve repeated attacks retain zero extra nodes/resources.

User direction: new characters default to Goemon's walking sound, and the early
prototype walking sound must never play again. The shared step fallback now
always uses the already-prepared Goemon sample; setup_audio no longer loads
audio/step.wav and its final fallback points to Goemon too. Distinct recovered
character samples and authored silence retain priority, as do custom recordings
and their gain/mute controls. This rule is saved in AGENTS.md. The old asset is
preserved as source history, without a gameplay/default-preview reference.

Fresh checks: 49 Kazi headless assertions, 236 shared-footstep assertions and
18 paired-Studio assertions pass. The preceding desktop check passes 61 Kazi
assertions, including the real SFX mix, saved audible attack audio, correct
straight directions, native hits, body-size comparison and five simultaneous
native allies. That desktop run predates the final shared-footstep replacement;
headless checks verify Kazi's actual movement uses Goemon after that change.
The nearby-ally suite passes 59 checks. Paired Studio retains its pre-existing
ObjectDB shutdown warning; this is not leak-free teardown certification.
Active asset preservation and exact source PCM assertions pass. Earlier full
toolkit/import results below remain historical for this follow-up.

The direction/size/sword-audio source completed a new 12.013 s foreground run
at 60.104 FPS, p95 17.960 ms, p99 18.581 ms and max 34.582 ms, with 240 enemies
and 96 allies, unchanged painterly art/counts/stats, zero errors or dropped hits,
full focus and simulation progressing in real time. This is a short diagnostic,
not a long-session guarantee or a measured speedup. The final shared-footstep
replacement was not graphically rebenchmarked: an already-open normal game held
the desktop launcher lock. That session was left intact and must restart to
load the latest cached scripts/audio defaults.

Verify after restarting Play Goemon: select Kazi, move straight away/toward the
camera and left/right, compare his body height with Goemon, and hit a nearby
enemy. Listen for Goemon footsteps, original sword swings and impact only on
contact. Use a wall or dodge to check rejected/cancelled hits. Current evidence,
source direction sheet, size comparison and actual mixed attack WAV are under
`build/Other Files/Cross Gate 102488/`. No app export or long-session soak ran.

## Kazi / Blue Cross Gate #102488 — initial port, 2026-11-06

The user confirmed the recovered sprite preview and identified him as Kazi
before implementation. Playable ID 34 preserves original directional 2D art,
including purple effects, in painterly Wind Meadow. No 3D reconstruction,
new enemy wave type, army simulation or per-unit retargeter was added.
The existing Hero owns movement, collision, health and skills; the recovered
combat adapter retains bounded native queries, exact melee/cover checks,
hit history and cancellation. Five simultaneous Kazi allies use existing native
pooled hero bodies. The mirror validator's upper kind changes from 133 to 134;
the universal native library was rebuilt and boundary/behavior tests pass.

The concrete asset cost was transparent sprite padding. The offline extractor
checks original pixels, trims only transparent margins, deduplicates frames and
packs by height. This reduces an initial eight 2048-square atlases (128 MiB)
to six cropped atlases (85.5 MiB RGBA, no mips) without removing frames or
rescaling art. All 56 selected source clips retain eight directions, 872 frame
references, source origins/durations and 824 unique images. Textures are loaded
once at selection and shared with allies. Combat changes only the existing
Sprite3D region and offset when its frame changes. PNG file size is not GPU
memory; this remains an 85.5 MiB selection cost.

Fresh paired foreground checks through Play Goemon use the same standard Wind
Meadow map, 1280×800, painterly scenery, normal stats, 240 enemies and 96 allies,
with movement and automatic attacks enabled. Each measured 12 seconds after
warmup. Goemon: 59.589 FPS, p95 19.026 ms, p99 22.530 ms, max 56.498 ms.
Kazi: 60.016 FPS, p95 18.372 ms, p99 19.427 ms, max 24.253 ms. Both retain all
240/96 units, full foreground focus, simulation progress matching wall time,
zero dropped hits, zero errors and unchanged fingerprints during measurement.
This shows no slowdown in this short workload; variation between these runs
does not establish a speedup or guarantee every battle/long session.

Focused checks pass 32 headless and 38 through Play Goemon. They cover
gallery/HUD identity, all eight facing directions, actual
movement, timed single damage, real native enemy damage, cover rejection,
dodge/selection cancellation, repeated attacks, range presentation and five
simultaneous native allies. Twelve repeated attacks retain zero extra nodes or
resources after normal label cleanup. The initial headless fixture counted
still-live labels as growth and aimed its camera at the old origin after moving
the actor; those fixture issues were corrected. Native mirror tests, 69 toolkit
Python tests, 12,973 imported checks, 98 outfit checks, 25 Musashi motion checks,
161 shared-character checks and 86 structure checks pass. Active optimized-asset
preservation passes; the GLB audit reads 310 assets without errors. The GLB audit
does not inspect sprite atlases: the extractor's exact pixel assertions do that.

Verify with Play Goemon: Q → Kazi, WASD/Shift to move/run and LMB/RMB to attack;
try a wall between the sword and target, dodge before contact, then switch
fighters. Damage must not arrive after cancellation or through solid cover.
Original BlueCG server hit timing/balance is unverified: the .6-second gesture
is original, while frame-5-of-11 contact, 33 base damage and the 3 m segment are
explicit Goemon adapters. Source/recovery instructions are beside the assets in
`assets/characters/crossgate/kazi/README.md`. Logs, captures and benchmark JSON
are under `build/Other Files/Cross Gate 102488/`. No app export, long-session soak
or full 2,000-per-team stress run was performed.

## Mountain King taunt interruption and instant enlarged slam — 2026-11-05

Taunt was rejected while Mountain King was attacking. A regression using the
real fourth-key path during auto attack reproduced it on the player and five
native allied Kings. Both Taunt and Thunder Clap now cancel the pending action
through the existing controller before starting. Repeating Taunt during its own
gesture still does not restart it. The existing eight-second native attraction,
reachability and saved slot overrides remain.

Thunder Clap now starts at the original .4-second animation contact pose and
releases damage, slow, sound and the prepared shockwave on input. The visual and
hit radius both multiply their former values by three: 22.5/27/31.5 metres at
ranks 1/2/3 before existing character/contact and skill-balance multipliers.
Damage, slow duration and strength, six-second cooldown, grounded input gate,
cover/visibility checks and airborne-target exclusion remain. Borrowed Thunder
Clap and native allied Kings use the same implementation. The old pending melee
or hammer cannot release after interruption; the slam cannot hit twice at the
former cast time. The effect snapshots its visual-size setting at cast time so
later attack tickets cannot resize a live shockwave.

This is an input/timing correction and requested range change, not a measured
CPU/GPU bottleneck fix. It reuses prepared motion, shared immutable effect frames,
the bounded native query, exact contacts and existing status leases. No new
simulation, renderer, pool, asset bake or combat-time resource loading was added.
The larger area can include more enemies; no army counts or art were reduced.

Fresh checks pass: Taunt 47 headless / 50 through Play Goemon; slam 39 headless /
42 through Play Goemon; full Mountain King kit 287 headless. They cover real
native pursuit, auto/manual attack interruption, all three radii, cover and
airborne exclusions, borrowed casts, Avatar, repeated use and five simultaneous
native allies. Normal/Avatar shockwave and taunt captures were visually reviewed.
Twelve repeated slams retain identical node/resource counts and zero projectile
pool misses after normal damage-label tweens finish. Initial cleanup checks
incorrectly counted still-visible damage labels while manually fast-forwarding
combat; the fixture now waits for their real-time lifecycle before comparing.
An initial test also queried an attack-slow field not exposed by unit_state;
that diagnostic remains saved, and existing slow delivery code was unchanged.

Desktop slam input p95/max are 1.348/3.327 ms; manual player/projectile-step
p95/max are .209/1.173 ms. These short shared-machine diagnostics are not rendered
frame intervals, a before/after FPS comparison or full-army/long-session proof.
Earlier gameplay smoothness and stress measurements remain historical.
Asset preservation, 69 toolkit Python tests, 12,973 imported checks, 98 Musashi
outfit checks, 13 player-motion checks and 86 structure checks pass. Source
snapshots, logs, reports and captures are in
`build/Other Files/Mountain King Slam/`. The native library was not changed.

Verify with Play Goemon: select Mountain King, enable auto attack and press 4;
reachable enemies should pursue him for eight seconds. During a hammer/axe swing
or Storm Bolt windup, press 2: the slam should start at impact immediately with
the enlarged shockwave and hit area. Try Avatar and borrowed Thunder Clap too.
Grounding, solid cover and cooldowns still apply; saved fourth-slot assignments
still take precedence. No app export or full-army/long-session soak was run.

## Normal movement/battle lag and army terrain checks — 2026-11-05

The user reported lag during ordinary movement and battles. A fresh foreground
Wind Meadow castle diagnostic with 240 enemies and 96 allies found native routing
and movement dominating simulation, rather than Storm Bolt or drawing. The first
12.6-second capture produced only three rendered frames, with an 8.73-second
maximum interval and 77.04 ms average native step. Simulation advanced only 2.28
seconds, so this is a severe catch-up failure, not a stable FPS baseline. Other
desktop CPU activity and swap were also present; do not attribute every delay on
this shared 8 GB Mac to one function.

The smallest fix changes one clearance eligibility condition in
`native/terrain_math/crowd/terrain.cpp`. Ordinary army bodies were larger than
the old one-cell cutoff and repeatedly rechecked terrain triangle edges. The
existing certified neighbourhood spans two cells: it can safely cover the body
plus the next .7 m sample, with a rounding margin. Eligible bodies now reuse that
certificate. Slopes outside its height bounds, cliffs, holes, unsupported layers,
custom rampart pieces and obstacles keep their exact checks. No counts, art,
combat, player controls, native ownership or map geometry were reduced.

The corrected universal native library was rebuilt and installed. The matching
12-second foreground castle run passes all benchmark gates: 73.51 FPS average,
22.543 ms p95, 24.805 ms p99 and 47.144 ms maximum frame interval. It retains
240 enemies and 96 allies, normal stats, live damage/deaths/replacements and zero
dropped hits; simulation advances 12.017 seconds in 12.012 seconds. Native step
average is 3.807 ms. Recorded source fingerprints differ only in terrain.cpp and
the rebuilt library. This is a short fixed-camera diagnostic, not a guarantee of
every normal-play scene or long-session/full-army performance. A second old-binary
confirmation lost focus and timed out; it is invalid comparison evidence. The
corrected library was restored and its hash verified afterwards.

The focused flat-corridor check reduces height samples from 2,550 to 389, retaining
the exact result. Expanded navigation tests compare normal and large map spacing
and larger radii against the uncached segment oracle; the separate clearance
oracle passes 974,401 checks; navigation passes 11,649 and the large-map native
castle assault passes 49 headless checks. Native binding/numeric smoke (1,000
sampled paths), six step-profile checks and active asset preservation also pass.
The large graphical assault was interrupted before its result and is retained
as an incomplete diagnostic. Headless fixtures still report shutdown RID/resource warnings;
a passing behavior result does not certify leak-free teardown. Earlier toolkit
and Mountain King results remain historical, not fresh verification of this fix.

Verify through Play Goemon on the same map, army sizes and camera: run across the
castle hills and fight a wave. If it stutters, first separate native-step time
from render time, then compare exact clearance work before changing visuals or
counts. Logs, captures, source checkpoint and before/after binaries are under
`build/Other Files/Lag Investigation/`. No app export or long-session soak was run.

## Mountain King Storm Bolt automatic targeting and blue hammer — 2026-11-05

The user rejected the first raised-throw trial as too high and requested automatic
closest-enemy selection. Acquisition and release return to the original 1.6 m
height without added upward tilt. Storm Bolt now selects the nearest living,
visible enemy with a clear line within 36 m, including behind the player, and
faces the original throw animation toward it. The existing bounded native query,
exact homing and cover checks remain. The original throw clips, .4 s release, speed, damage,
stun and cooldown remain. The red came from the recovered hammer's opaque team
layer: only additive spell energy had been recolored. The existing offline baker
now prepares that solid layer blue too, preserving extracted textures, geometry
and motion. There is no added combat-time asset loading or material construction.

The superseded raised-throw desktop checks passed 61 focused and 287 full-kit assertions, with
rendered windup/release/flight inspection, two-metre ridge clearance, native hit
and stun, cover blocking, borrowed Storm Bolt, repeated use and five concurrent
native allies. Twelve repeated throws retain zero extra nodes/resources and
zero pool misses. Asset preservation, 69 toolkit unit tests, 12,973 imported
checks, 98 outfit, 13 Musashi motion and 86 structure checks pass. The audit reads
310 assets without errors; existing budget warnings do not authorize redesign.

That trial's focused manual-step p95/max were 3.386/16.420 ms; full-kit rendered callback
interval p95/max were 45.953/145.747 ms. Other verification work overlapped these
short shared-desktop runs. These are diagnostics, not a controlled FPS comparison,
an isolated bottleneck, a speedup or proof of full-army smoothness. The user's
earlier smoothness report and historical measurements remain separate evidence.
Initial test diagnostics are retained: release floating-point timing required
one extra simulation step; height must be measured from the grounded player;
allied bodies must advance through their native mirror owner.

Fresh automatic-target results are stored separately under
`build/Other Files/Asset Toolkit/Mountain King/Storm Bolt Auto Target/`.
The desktop launcher passes 64 focused and 287 full-kit assertions: nearest enemy
behind the player instead of a farther aimed-at enemy, automatic facing, rejection
of a closer covered enemy, real native hit/stun, borrowed casting, twelve repeated
throws and concurrent native allies. There are zero pool misses or retained
nodes/resources, and active asset preservation passes. No assets or motion were
rebaked for this behavior change. Focused manual-step p95/max were 1.054/4.858 ms;
full-kit rendered callback interval p95/max were 71.911/144.993 ms. These short
automated desktop diagnostics do not isolate a performance bottleneck or certify
full-army frame times; the preceding toolkit/asset tests remain earlier results.
The earlier `Storm Bolt Review/` captures and measurements above describe the
superseded raised-throw trial, not verification of automatic targeting.
Verify with Play Goemon: press RMB/1 while facing away from nearby enemies.
Expect the nearest visible, unobstructed enemy to be selected automatically,
with normal homing and a blue hammer. Solid cover still blocks hits.
No app export or full-army/long-session benchmark was performed.

## Automatic Guard and Cannon Towers — 2026-11-05

The user requested towers that work without workers. Both tower types now own
one building cooldown and fire their configured volley automatically during a
wave. The former worker-cap setting is labeled **Shots per tower volley**; its
saved `tower_workers` key is retained so existing strength settings survive.
Default damage per shot, reload intervals, team upgrades, cannon splash/cover,
projectile flight and native damage delivery remain in the existing systems.
Acquisition uses the tower center and shares the existing native candidate
snapshot and fitted-contact cache across towers. No combat-time asset loading,
new simulation, renderer or pool was added.

Towers no longer offer worker jobs. Starting worker counts are preserved;
workers remain available for mining and repairs. Historical garrisons are
released through the existing safe exit lifecycle. Tooltips, inspection and
rally hints reflect this rule. Saved map formats and both valley sizes remain.

Fresh correctness checks pass 74 model assertions across both map sizes,
40 automatic-worker, 44 repair, 598 team-progression and 14 starting-state
checks. Native spatial-query and shared-snapshot checks pass 7 and 2 assertions.
Tall-tower contracts pass 18, starter-fort contracts 117 and incremental editor
document checks 32 assertions; Human building/repair visuals pass 49 headless
contract checks. A focused balance-menu/configuration run passes 43 checks,
including saved settings and an actual tuned native tower hit.
Rendered native combat passes 61 standard-map and 63 large-map assertions;
the large run uses Play Goemon, while the standard run used a separate graphical
instance because another session held the launcher lock. Five repeated 16-shell
volleys retain identical node/resource counts in each run. These short shared-
desktop diagnostics are not a controlled frame-time comparison or a full-army
or long-session performance certification. Active asset preservation, 69 toolkit
unit tests, 12,973 imported checks, 98 outfit and 86 structure checks also pass.

The randomized indexed/exhaustive targeting fixture still reports 10 failures
out of 165 checks. Replaying its exact tower-center inputs through the captured
pre-change workforce produces the same 10 failures; this change does not fix
that older targeting issue. Headless native fixtures also retain shutdown RID/
resource warnings. Logs and the baseline diagnostic are under
`build/Other Files/Automatic Towers/`; graphical captures/reports use the existing
`build/Other Files/Asset Toolkit/Human Cannon Tower/` location.

Verify with Play Goemon: build either tower, leave every worker outside, start
a wave and watch automatic volleys and normal damage. Adjust Shots per tower
volley and volley rate in Core Game Balance; workers should stay free and
tower cooldowns should update. No app export was made.

## Castle and four-hill defense — 2026-11-05

The user reports mercenaries getting stuck around buildings and asks them to
protect the castle around the four hills instead of hunting across the map.
Paid native guards now acquire enemies only inside a square centered on the
main shrine, extending 140 terrain units in each direction (280 metres on the
standard map, 420 on large). This includes the four hill shoulders while leaving
the enemy-fort arrivals outside. Recruits still appear at the castle, fight
reachable intruders in that area and return to their own preparation posts when
it is clear. Permanent card heroes use the same guard selection and return
posts; temporary Mirror Image summons retain their existing local behavior.
The preparation boundary preview and hiring feedback match this
rule; costs, saved maps and manual post placement are retained.

The existing nearest-contact index remains the first choice. A rejected outside
or unreachable nearest target uses the existing spatial grid, ordered contacts
and allied navigation to find an eligible enemy. Dragoon's airborne entrance
checks navigation from the ground below him instead of rejecting every target
because his entrance begins above ground. Existing native attacks, timing,
projectiles, shelters and pooled presentation remain in use.

Enemy troops keep local combat, taunts and retaliation. Distant civilians and
allies do not divert a targetless assault away from an existing main base. If no
actual combat contact is reachable, the same native owner picks reachable
staging ground progressively around the main shrine and marches there, while
retrying real targets on its existing decision clock. Staging goals are cached
separately from certified building attack approaches and invalidated by the
existing navigation/pose changes. Walls remain solid; a completely enclosed
region still requires an opening. Specialized boss attacks retain their owners.

Fresh verification passes nine native suites, including 2,420 nearest/guard
checks and 46 target-decision cases (outside-area rejection, square corners,
airborne acquisition, unreachable enemies, sealed-base staging, distant
civilian/ally rejection, death/stealth and gate reacquisition). Both painterly
desktop mercenary runs pass 40 checks each, with five kits delivering damage
at all four hill approaches and returning home. Idle resources do not grow
(node delta -2, resource delta 0 on each size). Stepped integration p95 is
3.002 ms standard / 3.210 ms large, with maxima 533.344 / 804.817 ms. These
include setup/navigation work and shared-desktop contention; they are neither
rendered frame intervals nor a controlled before/after comparison. Keep the
outliers visible rather than describing these as a full-battle smoothness pass.
Asset preservation, 69 toolkit unit tests, 12,973 imported checks, 98 outfit
and 86 structure checks pass. The headless hiring repeat passes 91 assertions without script errors. An
earlier run logged a separate `player_range` upgrade-data error and remains
as a diagnostic. The rendered enemy assault passes 49 checks on each size,
including all twelve troops resuming base damage when the player becomes
untargetable. Its existing shutdown resource/RID warnings remain; a passing
behavior run does not certify leak-free whole-game teardown. Permanent card
heroes pass 36 headless checks on each size, including real card recruitment,
hill combat, wave persistence, release of a live escaped target and return home,
with zero idle node/resource growth. Their timings were recorded amid other
Godot jobs and are correctness diagnostics, not an FPS comparison. A later
painterly desktop standard-map run passes 44 checks with the current card hero
catalog (including the added Illidan form), zero retained nodes/resources, and
rendered hill combat/return-home evidence. Its stepped p95/max are 6.827/518.853
ms amid other Godot work; these are not a rendered FPS or speedup claim.

This is a behavior correction, not a measured CPU bottleneck or a claimed FPS
improvement. The user's earlier smooth-gameplay report and older stress results
remain historical. Verification evidence is under
`build/Other Files/Castle Defense AI/`; the initial failed boundary/Dragoon
fixture is retained as `initial-diagnostic.log`.

To verify with Play Goemon: recruit the five types, start a wave and watch them
hold while enemies are outside the hills. Intruders in the defended area should
be engaged, then released when they leave; survivors return to the castle.
Move the player away or become untargetable while enemies pursue: they should
resume the main-base assault. The current open raised castle has no closed gate or
starting military buildings; the native fixture separately covers gate breaches
and sealed-base staging. Run
`mercenary_hunting_test.gd` (now a defensive-area regression) on both sizes and
`enemy_castle_pathing_test.gd` for the rendered base assault. No app export or
long-session/full-army performance certification was performed for this change.

## Terrain placement stalls — 2026-10-31 follow-up

The user reported severe lag when placing buildings after the terrain palette
addition. The earlier cursor callback profile did not measure committed edits.
Fresh desktop-launcher profiling found that each terrain placement rebuilt the
whole model and rendered meadow. Standard-map platform/corner commits took
3,787–3,909 ms, while ordinary towers took 27–33 ms and stone blocks 15 ms.

The smallest fix extends the existing incremental editor refresh. A terrain edit
keeps the model, meadow mesh, base collision and unaffected scenery/foliage;
it updates local support/cliff navigation cells, replaces the small raised-route
batch, refits affected scenery and regenerates nearby foliage chunks from their
stored random states. Removed route materials leave the fog registry. Discard
also restores the prior routes without rebuilding the meadow. Source/size,
roads, portals and deposit changes retain their existing complete setup path.
No army counts, art quality, geometry or foliage density were reduced.

Final live Apple M3 samples (two placements per piece, not a full-army benchmark):

| Map | Platform commit / first rendered frame | Corner commit / first rendered frame |
| --- | --- | --- |
| Standard | 30 ms / 34–35 ms | 38–39 ms / 41–43 ms |
| Large | 52 ms / 59–62 ms | 64–69 ms / 72–78 ms |

Commit includes validation and refresh; first-render time ends at the next
`frame_post_draw`, not at physical display presentation. There is no recorded
before-fix render interval. Concurrent desktop work can affect these short
samples, and large-map placement can still produce a short frame hitch. These
results address the measured multi-second stall, not all editor or battle costs.

The fresh modular fixture passes 3,579 checks, including actual player and both
native teams traversing ramps, corners and T-junctions. Both sizes pass 58 live
placement checks, including collision/native support, retained terrain/base
collision, local foliage updates, bounded repeated
place/delete resources and Back/discard restoration. The headless 675-check
oracle compares every allied/enemy navigation cell, exact native obstacle and
terrain data, stacked scenery support and distant cliff-cache retention with a
complete rebuild across platform/height/rotation/junction/deletion changes.
The fresh palette run passes 525 checks, covering actual module clicks, rotation,
height, undo, save/reload and native Play/Restart. An earlier run had three mouse
interference failures; its diagnostic log is retained separately. The shared
building-editor desktop regression passes 68 checks, including exact foliage
restoration, retained collision, undo/redo, zoom and native Play map.
Fresh toolkit checks also pass: 69 unit tests, 12,973 imported/preservation,
98 outfit and 86 structure assertions. Logs and before/after JSON are under
`build/Other Files/Asset Toolkit/Modular Environment/`.

To maintain this: run `terrain_placement_performance_test.gd` through the desktop
launcher, then repeat with `-- --large`. Compare validation and refresh timings
separately; retain untouched node identities and run `terrain_edit_reuse_test.gd`
against a fresh model whenever terrain cache invalidation changes. Verify actual
player/native traversal and appearance with the modular/palette fixtures. Keep
full saved-map validation and the normal native army owner. No app export or
full-army/long-session benchmark was performed for this fix.

## Modular environment checks — 2026-10-31

The [modular kit guide](wind-meadow/modular-kit.md) records the new ramp/deck
recipes and three existing-mesh scenery compositions. They reuse analytic
rampart support and the existing scenery/native obstacle owner. Both native
teams and the actual player traverse the three test arrangements through the
desktop launcher; repeated obstacle instancing retains bounded resources/nodes.
These are fresh correctness/render checks, not a new smoothness or frame-time
measurement. Earlier graphical fixture runs reported resource/RID warnings at
shutdown; they did not establish leak-free whole-game teardown. Keep new scenery
in the shared spatial batches and profile before increasing its density.

The 2026-10-31 follow-up adds L/T joints and height-aware scenery placement.
Fresh desktop verification passes 3,579 terrain/junction checks, including both
native teams reaching the exits without turn waypoints, and 46 stacking checks
covering planting on stone, per-layer editing, save/reload/restart, navigation
around the wall and bounded repeated edits. Existing ground-level map identities,
native combat/movement and scenery chunk batching remain in use. Height changes
rebuild only affected scenery chunks and publish the same elevated fitted boxes
to physics and native obstacles. No new frame-time profile was taken; the
earlier smoothness report and historical timings are not a fresh stress pass.

The next 2026-10-31 follow-up exposes seven terrain modules in the existing
editor palette. Cursor previews reuse cached immutable scenes, disable ghost
collision and check only the small module footprint against current placement
data. They retain the same game model and rendered terrain while moving, with
bounded nodes/resources in the desktop fixture. The initial implementation
used a full rebuild for committed terrain edits; the later placement-stall fix
above replaces that path with local updates. Saved module descriptors preserve grouped
L/T selection and exact native segments, and validation uses the current map
domain with the existing 24-segment limit. These cursor/correctness checks do
not measure whole-game frame times or establish new stress-test results.
The final palette fixture passes 525 desktop checks and 454 document checks.
Its sampled cursor callback is 0.121 ms median / 0.284 ms p95 on Apple M3;
this is CPU time inside the editor callback, not a rendering/FPS claim.
The fresh palette and terrain-navigation runs exit without the older shutdown
warnings; whole-game teardown has not been audited.

## Editor navigation and opening stalls — 2026-10-30, second follow-up

The user still reports lag and confirms that both dragging/zooming and opening
or changing tools feel bad. The earlier placement results did not verify these
paths and must not be presented as proof that the editor is smooth.

Desktop navigation fixtures exposed three separate costs. Road and Portal cursor
updates still cloned/validated the whole layout; one large-map road update took
102.815 ms. Large-map editor entry took 7,844.114 ms and discard took 6,076.831 ms
because each rebuilt the rendered world. Tool changes also serialized the entire
saved large map just to update the clean/dirty label, taking roughly 7–20 ms.
First use of two scenery pieces loaded their GLBs under the cursor, reaching
about 60–82 ms of preview setup in the diagnostic runs.

The fixes keep existing owners and art:

- Cursor checks for roads and portals use current local cells, reservations,
  footprints and counts. Actual edits and Save/Load still validate the whole
  document. Rock/prop protection, tree clearing, gates, portal exits and limits
  are retained.
- Entry creates an isolated authoring model while reusing the existing world
  when terrain, roads, deposits and portal state match. Discard restores the
  original model, worker data, gold and player progression binding. Changed
  structures/scenery/foliage use the existing refresh helpers; terrain collision
  metadata follows the active model. Incompatible layouts/objective state retain
  the complete reload path. Actual Play map still creates a fresh run.
- The saved-map picker reads and fully validates files to list titles; it no
  longer constructs a gameplay model for every picker entry.
- Tool/selection changes retain the existing dirty label. Actual document changes
  still recompute it. Scenery cache keys now use the same full source path for
  short and full asset names. Palette scenery is prepared once when the existing
  editor UI initializes, moving first-use import work out of cursor navigation.
- Idle frames avoid redundant camera updates, drag clamps immediately, and
  hovering editor controls skips map picking/preview validation.

A clean large-preset entry/discard run measured 513.227 / 5.454 ms and passed
seven checks including three additional open/discard cycles with bounded nodes
and resources. Later saved-large entry measurements during other desktop work
were about 0.6–0.8 seconds. This retains a short authoring-model setup pause;
it does not promise instant opening or asynchronous map loading.

Final standard navigation and saved-large live navigation each pass 60 checks:
ten pan scenarios (Select, Tower, Tree, Portal, Road at overview/close sizes),
repeated pinch/reverse, all 22 real palette hotkeys, UI hover, keyboard movement,
drag bounds, unchanged document/history and native ownership. The saved-large
run keeps the normal game process enabled with an extra timed editor probe;
the standard run times the editor callback directly with live rendering. These
are distinguished in their JSON reports. After palette preparation, saved-large
scenery tool selection plus first preview took about 1.7–2.5 ms; the handler
itself was about 0.2–0.3 ms. First building previews still prepare existing art
and took up to roughly 34 ms in that shared-desktop run. Road/Portal cursor work
stayed below 5 ms at p95 in every passing final scenario, rather than the earlier
full-document stalls. No army count, geometry, foliage density, shader quality
or shadow quality was reduced.

These are short navigation diagnostics, not proof of smooth full-army gameplay
or a long-session soak. Other Godot/import, Python and desktop rendering jobs
were active during later runs. Final saved-large frame intervals still include
large outliers, including p95 near 101 ms in the Select overview scenario, even
though editor work there was only 0.023 ms at p95. The earlier quieter saved-large
run had roughly 17–20 ms p95 intervals. Do not attribute every rendered hitch to
cursor code or claim an overall FPS improvement from these mixed-load runs.
Metal GPU timing returned zero/unavailable. First diagnostics are retained: an
initial reuse run queried missing collider metadata (now guarded), and an early
live fixture incorrectly treated the engine's sampled TIME_PROCESS monitor as
per-call editor time; its timing-gate failures are not production failures or
passing results. The corrected fixture uses a direct stopwatch.

Final regressions pass: 43 focused document/cache/picker assertions, 35 saved-map
assertions, 27 editor assertions, 41 preparation-camera assertions, 13 portal/road
assertions, 68 rendered large-map building/scenery/native-play assertions, active
asset preservation and 69 toolkit unit tests. The portal fixture initially failed
its road-retrace assertion on both current code and the saved original editor/
document/world/game scripts: its angled-camera endpoint lay inside the toolbar.
The fixture now centers that same path over editable ground and asserts the end
is outside the toolbar; the original road-content assertions are retained. The
initial failure and a separate viewport-only failed diagnostic remain in the
report folder. The rendered correctness run overlapped that diagnostic and is
not used for latency/FPS comparisons.

Verify through **Play Goemon → Tools → Map Editor**: open/back several times,
pan and pinch with Road/Portal selected, and switch every palette page/tool.
Hovering the controls should hide the map ghost; returning to the map restores
it. Place/rotate/delete scenery, Undo/Redo and Save/Load; discard must restore the
original run. Full terrain/road/portal commits and Play map can still rebuild the
world. Evidence and original source snapshots are under
`build/Other Files/Map Editor Navigation/`. No app export was requested.

## Building placement stalls and map-editor zoom — 2026-10-30 follow-up

The user still reports massive editor lag and cannot zoom in. That fresh report
supersedes any interpretation that the earlier scenery-only edit measurements
proved the whole editor smooth. Desktop source-launcher measurements found tower
placement still rebuilding the complete map: 4,300.743 ms standard and 7,315.027 ms
large. Moving building tools over cells also performed full-map validation,
about 9.6–10.6 ms per cell standard and 19.3–22.6 ms large in that short fixture.

The smallest retained fix extends the existing scenery preview path to buildings.
It keeps the model, terrain mesh/collision, background, unchanged structures,
workers and scenery batches. Changed buildings use `_make_building` /
`_remove_building`, including worker release, and update only affected navigation
cells and enemy path weights. The existing foliage builder is reused only for
36-metre ground chunks touching changed occupancy. Saved random states make
removing a building restore the original local plants exactly. There is no new
simulation owner, asset, geometry reduction, army reduction or material policy.
Cursor checks inspect current local occupancy/terrain and cached reservations;
committed edits and file save/load retain complete validation. A diagnostic
intermediate version retained the terrain but reset the model; its 473.574 ms
large-map model reset was still too expensive and is not the final path.

The editor had separate wheel-only zoom, fixed 12-metre steps and a 60-metre
close limit. It now reuses preparation's proportional wheel/fractional scroll,
trackpad pinch/scroll, +/− keys, 20-metre close limit and cursor anchoring. Text
fields, UI hover and confirmation dialogs retain input guards; construction's
public zoom guard and combat camera stay independent. Zoom over the map, with
the pointer outside the palette and bottom toolbar. The help line lists the keys.

Fresh final desktop fixture results, with no other test jobs running:

| Map | Initial tower placement | Repeated rotation median / p95 | Building cursor check per cell |
| --- | ---: | ---: | ---: |
| Standard | 23.544 ms | 18.150 / 18.527 ms | 0.081–0.168 ms |
| Large | 50.662 ms | 39.241 / 40.539 ms | 0.143–0.248 ms |

Each size passes 68 assertions, covering retained objects, physical collision,
local foliage clearance/exact restoration, all five building types/rotations,
full versus incremental grids/weights, normal worker release, undo/redo/delete,
bounded nodes/resources across twelve edits, real wheel/gesture/key input,
and Play map with exact authored data and the existing native army.
Both building and close-zoom captures were inspected. These are operation
latencies from short desktop fixtures, not rendered FPS, a long-session soak or
proof of full-army smoothness. Existing regressions pass: 89 desktop scenery
checks including save/load/restart/native play and UI fit, 41 headless preparation
camera checks, 27 headless editor checks and active asset preservation. The
scenery regression overlapped the two headless checks; its timings are not used
as a controlled comparison. Earlier diagnostics remain alongside the final logs.

Verify with **Play Goemon → Tools → Map Editor**: place a Tower/Farm/Wall,
select it, rotate, delete and undo repeatedly. Nearby plants clear and return;
distant scenery stays in place. Point at a piece and wheel/pinch closer, or use
+ and −, then pan with middle drag/WASD. Repeat on Large Meadow. Initial opening,
full-map loading, terrain, roads and portal changes, and Play map still use the
complete setup path and can pause; those operations were not optimized here.
Evidence is under `build/Other Files/Map Editor Responsiveness/`. No app export
or full-army/long-session benchmark was run.

## Expanded scenery grid and foliage style correction — 2026-10-30

The grid now has 22 tools over three numbered pages: its original nine, then
bush, cedar, pine, sakura, bamboo, river rock, moss boulder, stone block, wall cap,
wall corner, wall piece, rubble and fence. Optional saved-map `props` records
retain allowlisted kind IDs, scale and rotation. Old maps without that list keep
their layout. Assets share the existing setup cache, spatial batches, local
clearance queries and native owner; there is no extra scenery process per frame.
The fence's base scale is 1.875 so its existing 3.2-metre mesh meets the six-metre
map grid. Footprint rounding tolerates only 0.1 mm of quarter-turn float error at
shared edges. Actual physics/native bounds remain unchanged by that tolerance.

The user rejected the visibly faceted Cedar Pass tree crowns and clarified a
Breath of the Wild inspired scenery direction. Cedar, pine and sakura now reuse
the existing meadow bark and leaf cards in separate editable variants, with
organic crown silhouettes, restrained natural colors, soft wrapped lighting,
shared wind and canopy cutaway. Sakura uses muted rose/cream blossom shading.
Each retains 6,396 triangles and two parts, matching the original broadleaf's
geometry count. This is a higher foliage cost than the earlier 84/384/364-triangle
Cedar Pass placeholders. Bamboo retains its 1,236 triangles with softened normals
and meadow colors. Original masters/exports remain exact by protected hashes.
Asset preparation is documented in the adjacent Wind Meadow guide; later edits
use the normal exporter, not the one-time preparation script.

Tall pieces also exposed an editor picking bug: the old cursor ray returned a
roof hit, then treated that offset position as ground. Scenery colliders now
identify their owning map cell. Selection resolves that owner; placement/road
painting skips objects to find the existing tagged terrain surface. This affects
editor input only. Road painting and free castle placement also clear the four new tree kinds
through the existing lifecycle; Undo restores road-cleared tree data. Character
controls, physical cover, native movement, hills,
wave counts and combat ownership remain. Full map validation and a file-size
check keep unsupported/oversized saves from replacing a valid map.

Fresh desktop source-launcher runs pass 255 mixed-catalog assertions on the large
map and 257 in the final standard run, including every real tool/transform,
collision, save/load, history, restart and native play. Later focused checks also
verify that all four tree kinds reuse road clearing and that oversized saves
leave existing files intact (193 pure/import assertions). Close tree views and an active-game ground view were inspected.
The final standard run's repeated-edit median/p95 was 20.9/23.8 ms; the large run
was 43.4/46.1 ms. These short shared-desktop edit diagnostics are not a controlled
FPS comparison or proof of smooth full-army play. Node/resource counts remained
bounded across twelve repeated edits after warm-up. Full-map loading still
performs complete setup, and hundreds of the new tree variants have not been
stress-tested together. Preserve the user's older smooth gameplay report as
separate historical evidence.

The audit found no read errors or budget issues on the four prepared variants.
Named lossless recipes preserve every mesh/surface/triangle and offer no useful
reduction, so authored GLBs remain active and no candidate was promoted. Staged
and active preservation, 69 toolkit unit, 12,973 import, 98 outfit, 13 Musashi
motion and 86 structure checks pass. The earlier unrelated valley/legacy-arrival
fixture failures are recorded in the section below, not claimed as passing.

Verify via Play Goemon → Tools → Map Editor: use [ / ] for pages two/three,
place different foliage and wall modules, select tall pieces by their visible
surfaces, resize/rotate, and save/play/restart. View the crowns beside an original
meadow tree under the same light. Keep modular pieces as ground-level static
scenery/cover; open arches, elevated stacks and functional structures require
their actual support/opening/gameplay contracts. Evidence is under
`build/Other Files/Asset Toolkit/Map Catalog/`. No app export or long-session/full
forest benchmark was run.

## Modular map scenery and editor stalls — 2026-10-30

The user reports that the existing map editor feels very laggy and unresponsive.
That is a fresh editor report; the older smooth-gameplay experience above is not
an editor performance result. The editor now places existing broadleaf trees and
mossy boulders, with uniform 0.5×–2× size and individual rotation. R turns scenery
15°. A 3×3 asset grid uses 1–9 and keypad numbers. [ / ] and Page Up / Page Down
change pages when the catalog grows beyond nine assets; each page restarts at 1.
The current nine pieces fit one page. Name/number fields suppress these hotkeys.
Selected pieces expose the same numeric controls. Save/Load, Undo/Redo,
Play map and restart retain these transforms. Save/Play also commit a typed
numeric value before using the document, without requiring Enter first.

The main observed stall was `refresh_document()` calling the complete preview
loader after each edit. That regenerated terrain meshes, dense foliage, forts,
workers and navigation. Cursor previews also cloned and validated the full map.
The smallest retained path now reuses the preview model, terrain and background,
updates changed grid occupancy, and rebuilds only affected existing 96-metre
scenery chunks. Unchanged chunks retain their nodes, meshes and materials.
Preview checks borrow the current map snapshot and inspect local occupied cells;
committed edits and file loads/saves still perform complete validation. Changes
to terrain, roads, buildings or portals retain the full reload path.

`forest_scenery.gd` owns the fitted bounds used by validation, picking, player
physics, script clearance and both native army teams. Chunk signatures include
those bounds as well as visible transforms, so editing a legacy tree cannot
leave a stale fixed-size collider. Existing maps keep their original tree
orientation and trunk behavior until a tree is explicitly transformed. There is
no second army owner, per-character renderer, runtime asset authoring, new
geometry, lower scenery quality or reduced army count. The boulder and tree
reuse `assets/models/environments/wind_meadow/` and the current batch helper.

Desktop source-launcher profile runs passed 63 authoring assertions per size.
The previous complete-refresh operation was timed on the same layout inside the
fixture; this is an operation comparison, not a checkout-to-checkout FPS test:

| Map | Complete refresh | Repeated scenery edit median / p95 |
| --- | ---: | ---: |
| Standard | 4,007 ms | 19.8 / 27.9 ms |
| Large | 7,541 ms | 38.1 / 41.2 ms |

The first pair of property changes took 173 ms standard / 78 ms large in those
runs. Play map still took about 4.7 / 8.5 seconds. These are short shared-desktop
observations; another Godot project was active, GPU timing was unavailable, and
no controlled whole-game speedup, full-army smoothness or long-session stability
is established. Initial opening, loading, terrain/structural edits and Play map
can still pause for seconds. Later correctness checks added bounds invalidation,
typed-value commits, native probe/physics parity checks and the numbered asset
grid; their acceptance logs are separate from these profile runs. The final
grid standard desktop diagnostic measured 46.1 / 56.0 ms median / p95 for edits.
The later large headless run measured 102.9 / 122.9 ms while other validation jobs
were active; that is not a rendered-editor performance measurement. These wider
ranges reinforce that the early profile values are not a smoothness guarantee.

Final desktop standard acceptance passes 87 checks, including all nine hotkeys,
keypad selection, paging/empty slots, typing guards and native field
probes around resized objects, exact physical/native box agreement, typed-value
saving and bounded nodes/resources across twelve repeated edits. The large
profile checks the same placement/save/play/restart path; final large headless
acceptance passes 66 checks after the physics/save safeguards. Screenshots were
rendered through the desktop launcher and inspected; headless checks alone are
not visual evidence. Final large desktop grid/paging acceptance passes 59 focused checks. Both the
numbered grid and toolbar fit 960×600, 1280×800 and 1920×1080.

Shared checks pass: 69 toolkit unit tests, 12,973 imported-asset checks, 98 outfit,
13 player motion, 86 structure, 35 saved-map document, 27 editor, 42 construction,
18 meadow-only and 497 native terrain assertions, plus active asset preservation.
The standalone native terrain fixture still emits shutdown resource/RID warnings.
Two older suites are not passes: the valley fixture fails six of 1,124 assertions
at terrain-support samples. A saved pre-task model produces the same six failures
across all 462 route samples, with zero before/current differences. The older
route-entry fixture fails eight of fourteen assertions because its historical
wave override accepts two spawn arguments while the unchanged route caller
passes three. Neither issue was hidden by changing terrain or fixture expectations.

Verify through **Play Goemon.command → Tools → Map Editor**: choose Tree or
Mossy Rock, set size/angle and place it. Select it, change both fields repeatedly,
then Undo/Redo. Save, load and Play map; walk into the rock/trunk and start a wave.
Check that distant scenery stays intact, the visible size matches blocking, and
restart retains the authored placements. Preserve full trust-boundary validation
when changing the preview cache. Evidence, earlier failed diagnostics, captures
and final input hashes belong under `build/Other Files/Map Scenery/`.
No app export or full-battle/long-session soak was run.

At the user's request, the saved legacy **My Forest Map** was moved to macOS
Trash. The current standard/large Wind Meadow presets and saved **Large Wind
Meadow Valley** remain. Excluded regression layouts and reusable scenery sources
remain outside the playable preset list.

## Two random enemies per kill — 2026-10-30

Every actual native enemy death now queues two extra ordinary enemies, including
deaths caused by allies/towers and deaths of the extra enemies themselves.
Nonlethal hits, form changes, ally deaths and cleanup/despawn are not defeats.
Native event serial deduplication remains the single kill boundary. The wave
owner attempts a pair on each world tick through the existing random-map
placement, connectivity and native arrival path. It retains the player/castle
clearance rules and active cap; blocked ground, stale navigation or full capacity
retain the unplaced arrivals. Restart clears the backlog, pause holds it, and
destroying the enemy objectives still ends the battle. Extra arrivals do not
consume configured wave counts or advance castle group strength. The fixed-size
army benchmark explicitly clears this gameplay queue while replacing each death
once, preserving its workload contract.

This is a difficulty mechanic, not a measured performance improvement. Reusing
the spatial snapshot and bounded pair placement avoids a whole-army scan or
resource construction in each death callback. Fresh launcher checks pass 166
assertions on each map size, plus 166 standard-map headless assertions. They cover
native kills, another generation, simultaneous deaths, partial/capacity/blocked
retries, reset/pause, supported routes and unchanged wave accounting. Twelve
spawn/retire cycles retain no extra nodes or resources after warm-up in these
fixtures. The short placement diagnostics include roughly 71–134 ms maxima across
the desktop runs, including cold native route setup and other test/app activity;
they are not isolated frame measurements,
a before/after speedup, or proof of smooth full-army/long-session play.

Preservation, 69 toolkit unit, 12,973 imported asset, 98 outfit, 13 Musashi motion,
86 structure, 37 wave timer, 81 group, 33 roster and 11 event-dispatch assertions
pass. The roster/event fixtures still emit shutdown resource warnings. Additional
regressions remain failures: random arrivals pass 99/100 assertions, failing the
older closed-castle assumption on the current map; the standalone arrival-queue
fixture passes 5/8 and emits null `actor_root.add_child` errors from its setup.
That setup path is unchanged in the saved pre-task runtime. These are recorded
separately from the passing real-scene native ownership/reuse checks.

Verify through Play Goemon: START, kill an enemy and watch the minimap for two
extra arrivals. Kill one of those to see another pair. At capacity, free space
to release queued arrivals; destroy the enemy statues to win. Evidence is under
`build/Other Files/Kill Reinforcements/`; commands are in the forest test README.
No app was exported. A sustained, growing-army stress test has not been run.

## Continued 24-hero work — 2026-10-30

The ordinary-gameplay experience reported above and the older stress results below
are historical. They do not establish that the current 24-hero workload is smooth.
The corrected workload still uses 240 enemies, 120 allies including all 24 full
heroes, normal stats, Wind Meadow large and the approved effects/colors.

Profiling found several repeat costs that do not require changing the artwork:

- Goemon hit effects retain their eight original texture pages and bind a page
  only when its frame changes. All sixteen heavy/light and reduced/full-flash
  desktop cases match the reference pixels; the full test passes 124 checks.
- Kojiro's five projectile profiles share immutable materials through the shader's
  existing per-instance frame parameter. Original nodes, atlas cells, trajectories,
  growth and lifetimes remain. The 8,762-check desktop comparison covers all five
  profiles, and the phoenix/homing orientation checks also pass.
- Repeated spark spheres share one immutable mesh. The scenery rock that edits
  its tessellation owns a duplicate. All 217 geometry/material checks pass; paired
  headless creation costs are roughly halved, not a whole-game FPS measurement.
- Warcraft models avoid writing unchanged opacity and avatar textures. A 113,436
  check comparison retains every sampled mesh color, visibility and texture page.
  The isolated Blademaster pose saving is about 9%; the other two models' timing
  differences are small/noisy. Do not extrapolate this to battle FPS.
- Melee assistance uses the existing ordered local candidate query before its
  unchanged contact, cover, visibility and scoring checks. A 240-enemy comparison
  keeps the same targets and combo retention while reducing point checks from
  36,920 to 1,836. Unknown populations retain the existing conservative fallback.

The native owner shares identical immutable air-collision geometry between enemy
and ally navigation. Equality includes field data, map bounds, layers and physical
faces/owners; navigation blockers remain independent. Copies use copy-on-write.
Geometry buffers reserve the existing triangle stream and collision-tree capacity
before filling, including later wall additions. The large-field regression's
shared buffer allocation falls from 67.2 MB to 42.8 MB. These are container-capacity
bytes in that fixture, not a measured whole-game resident-memory reduction.

Waypoint caching checks exact root/goal/radius/layer inputs before repeating goal
connections and clears on navigation updates. Goal connections are checked nearest
first with the original row-order ties. The focused case drops from ten segment
checks / 532 height reads to three / 222 with the same waypoint. Native coverage
includes 30,011 sharing/contact checks and 8,648 navigation comparisons.

A disabled mirror-body process state also suppressed Goemon's deferred pose and
reach wave. Leased bodies now run their normal presentation clocks, and retirement
stops the model clock. Earlier observations do not certify this corrected workload.

Benchmark focus holds pause both the scene tree and the game's always-processing
native owner. Reports distinguish active measurement time, wall time and recorded
focus waits. Acceptance checks all accounted time and rejects changed source hashes;
the accounting regression passes 24 checks and the hold regression passes six.
Never exclude a slow focused frame or count a diagnostic stack-sampling run as an
uncontaminated performance result. A concurrent native rebuild invalidated the
`Local Melee Battle` run; it is not an after-change speedup measurement.

The current rebuilt source still requires a passing coordinated rendered run.
Do not call the 24-hero request complete until the full 120 active seconds pass
55 FPS, p95 25 ms and p99 50 ms with unchanged inputs and normal combat activity.
Headless checks cannot establish smoothness. Evidence is under
`build/Other Files/Asset Toolkit/24 Hero Smoothness/`; no app has been exported.

Known fixture limits: `hidden_melee_assist_test.gd` has the same 32 failure messages
before and after local acquisition. The standalone native-query fixture also emits
the same shutdown resource warnings on its existing baseline. Keep those separate
from live gameplay errors and from the passing focused target-selection comparison.

## 24-hero follow-up and Sky Strike — 2026-10-30

The follow-up keeps 24 full hero bodies among 120 allies against 240 enemies,
with the same painterly map, combat stats, approved colors and attack effects.
It fixes Sky Strike's overlapping-target case: a horizontally zero contact
vector now uses the caster's facing, then forward if that too is zero. Normal
landing offsets, travel times and blast radius remain unchanged. The focused
reproduction failed before this fix and now passes 61 direction/landing checks.

Repeated ROM matrix conversion was avoidable CPU work. Goemon, Sasuke and Yae
now prepare the original JSON matrices once when first selected, sharing that
immutable data across samplers. Interpolation and part selection are unchanged.
A 538,002-check comparison against raw source sampling passes exactly, including
all clips, fractional samples, hidden parts and independent returned poses.
Paired isolated sampling costs fell about 40–42%; this is not a whole-game FPS
claim. Balance lookup caches only immutable character keys; live edited values
still apply. Redundant unchanged body-transform writes are skipped.

Kojiro's existing pooled dust and sparks skip redundant fixed-scale and unchanged
atlas-frame updates. Their nodes, trajectories, integer frame selection, scales,
timers and retirement stay original. Desktop reference comparisons of spark and
dust frames are pixel-identical; repeated fixed and fractional update steps keep
exact motion and lifetime. An extra MultiMesh batch experiment also matched
pixels but did not show a reliable full-battle benefit. It was removed entirely,
including the extra presenter process and visibility registry. Reuse the original
renderer until a controlled workload demonstrates a gain from adding machinery.

The fixture now assigns stable logical IDs to its 24 heroes so allocation changes
do not change native AI seeds. This changes only the test fixture. Render cadence
can still change the live battle's attack sequence, so historical FPS values
are separate observations, not a controlled before/after percentage.

The first corrected 120-second follow-up measured **44.009 FPS**, p95 34.379 ms,
p99 41.624 ms and max 64.749 ms, with full foreground focus, unchanged source
hashes and zero runtime errors. It retained 240 enemies and 120 allies. Memory
rose about 4.94 MB; a two-minute observation does not prove no leaks. This still
**fails** the 55 FPS / p95 25 ms target. Do not call this stress case smooth.

Two later batching runs also failed: 36.327 FPS (p95 49.970 ms) and
26.359 FPS (p95 68.234 ms). Both retained the full roster, full foreground focus,
unchanged source hashes and zero runtime errors. The batch layer was removed
instead of claiming a gain. Separate live runs vary with attack sequences and
host work; none of these failures establishes a controlled regression percentage.

An experimental dynamic ribbon buffer matched source geometry/colors and rendered
pixels, but gave no clear full-battle gain (42.412 FPS over 30 seconds). It was
removed. A GPU surface-readback version was slower still and was also removed.
Do not add readbacks, lower army counts or alter art quality to pass this case.
The final simpler source, with both experimental renderers removed, completed
120 seconds at **28.307 FPS**, p95 **67.360 ms**, p99 **172.765 ms**, max
592.048 ms. It maintained all 24 heroes / 240 enemies / 120 allies, with 21
simultaneous attacking heroes and 14 visible crescents, full foreground focus,
zero runtime errors and zero dropped hits. Source hashes stayed unchanged during
measurement. Memory rose 6.61 MB; long-session resource growth is unchecked.
That follow-up source result **fails all three performance thresholds**.
The isolated CPU savings do not establish an overall battle speedup. More work
on the full hero workload remains; do not describe this request as fully solved.

Checks for that follow-up passed 61 Sky Strike, 8,746 desktop cosmetic reference, 538,002 raw pose,
206 profile-key, 101 combined layer/bake, 700 Kojiro gameplay, 122 desktop phoenix,
13 retirement, 338 universal native mirror, 12,973 imported asset, 69 toolkit unit,
98 outfit, 25 Musashi motion/controller and 86 structure checks. Asset preservation
passes. The two Pirate movement assertions in the character-balance suite fail
with both the cached and original uncached lookup; record them separately. The
final Sky Strike test also exits without its earlier test-fixture resource warning.
One trailing blank line was removed from the existing presenter after measurement;
no runtime logic changed afterward.

The accepted changes and rejected experiment evidence are under
`build/Other Files/Asset Toolkit/24 Hero Optimization/`. No app was exported.

Verify through Play Goemon: test Sky Strike against an enemy directly under the
caster and compare Kojiro's dust/sparks, then repeat the 120-second fixture below.
Keep the window focused and stop other profiling jobs during measurement. Check
average FPS, frame-time tails, active counts, error logs and source hashes. The
remaining full-hero controller/contact work needs further profiling; the native
regular army result below is not evidence that this heavier case passes.

## Simultaneous ally crescent battle — 2026-10-30

Fresh rendered tests used Play Goemon, painterly Wind Meadow large, 1280×800,
normal combat stats and the native army. Per-death reinforcements maintained
240 enemies and 120 allies. No effect shape, color, size, opacity, cadence,
weapon, damage, cooldown, unit count or art quality was reduced to pass.

The regular 120-ally roster held 59.997 FPS over 30 seconds: p95 18.420 ms,
p99 19.507 ms, maximum 26.038 ms. It delivered 21,533 attacks, 21,153 damage
events and 2,024 deaths, with zero dropped hits and full foreground focus.
This is the regular army result, not evidence that 120 full hero models are cheap.

A separate heavier roster replaced 24 regular allies with three each of Goemon,
Musashi, Ben, Sasuke, Yae, Kojiro, Blademaster and Illidan. Existing native ownership,
AI and pooled legendary bodies drove their full controllers and effects.
An initial run stalled for seconds at a time. A death event removed its query
registration immediately, while the source enemy facade remained until the
existing retirement cleanup. The count mismatch made every subsequent melee
contact query fall back to the whole army. Profiling traced Sasuke/Yae's cost to
those contact queries, rather than the crescent mesh construction.

The fix retires the query registration at the same boundary as its facade and
also removes stale registrations when a logical ID is reused. The native query
still rejects dead handles. It preserves the custom-actor fallback, target order,
exact contact checks, event delivery and damage. The local-query regression failed
before the fix and passed after it; dead-handle exclusion is checked explicitly.

The subsequent 120-second 24-hero stress run improved substantially but **failed**
the smoothness target: 26.814 FPS, p95 82.221 ms, p99 186.139 ms, maximum
389.793 ms. It retained all 240/120 units, delivered 68,682 attacks and 69,986
damage events with zero dropped hits, and reached 23 simultaneous attacking
heroes and 15 visible crescents. It maintained 24 pooled hero bodies. Memory
rose about 10 MB with a peak four-resource increase during the run; this short
observation does not prove absence of leaks. Foreground focus was 95.2%, and
simulation time lagged wall time by 0.24 seconds. Source hashes stayed unchanged
through each measured run. GPU timings were unavailable on this Apple M3.
A later regular-army repeat could not retain foreground focus and stopped before
measurement; it supplies no after-fix FPS result.
Nine zero-vector quaternion errors in Sky Strike's wind beam were also
logged; those were unresolved in that historical run. The follow-up above fixes
the direction error; this old run remains a failed correctness result.

Event dispatch averaged 5.706 ms per physics step after the lifecycle fix, down
from 27.609 ms in the earlier short stalled run. Different lengths and simulation
progress mean these are diagnostic phase costs, not a controlled FPS speedup.
Remaining script/contact/terrain work needs further profiling before claiming
that dozens of full hero controllers are smooth. Do not hide that limit by
shrinking effects, skipping their animation or reducing the measured roster.

Fresh focused checks pass: thirteen retirement, five batch retirement, 10,008
registered-facade, 6,011 facade-batch, 37 query-proxy and eight snapshot checks.
The target-query cost fixture still has the same three failures on source before
and after this lifecycle fix; they are recorded separately, not counted as passes.
Asset preservation, 69 toolkit unit, 12,973 imported asset, 98 outfit, 25 Musashi
motion, 86 structure and 101 combined effect/bake checks also pass. No assets,
pose bakes or native binaries were changed by this investigation.

Repeat the saved fixture through Play Goemon with
`--script res://tests/forest-shrine/crescent_battle_benchmark.gd -- --per-team=240
--allies=120 --duration=120 --scenario=open --map=wind_meadow_large --await-focus
--profile-spikes --out=<absolute report directory>`. Compare equal workloads and
frame-time tails, not only average FPS. Reports, source snapshots, profiles,
captures and known failures are under
`build/Other Files/Asset Toolkit/Crescent Battle/`; the folder named `Mixed Final`
contains the **failed** stress result, not an approval. No app was exported.

## Preserve the approved effects; reduce their CPU work — 2026-10-30

The user explicitly likes Goemon's current effect and stopped further placement
changes for now. Preserve that appearance. The preceding character-path audit
made no runtime placement edits; its preliminary fixture/reports stay excluded
under `build/Other Files/Asset Toolkit/Crescent Paths/`. They are observations,
not authorization to redesign the accepted attacks.

The focused cost is effect mesh construction, not a measured whole-game frame
bottleneck. Empty inactive short ribbons now return before filtering samples or
clearing an already-empty mesh, while advancing the sample clock so the next
attack is immediate. Original glow quads pre-size their two packed arrays and
write vertices/colors directly instead of making seven temporary arrays for
every adjacent sample pair. Musashi computes each source-age palette once per
draw and reuses it for both his original and ink surfaces. The original expiry
filter remains: an in-place expiry experiment added complexity without a clear
active-crescent gain and was dropped. No new pools, caches, shared material
mutations, per-enemy work, asset/model loads or simulation changes were added.

A fresh alternating-order paired CPU microbenchmark runs ten 300-update chunks
per implementation after 300 warmup updates, with the saved pre-change source
and final source in the same process. Mean microseconds per update:

| Effect owner | Before | Final | Less CPU time |
| --- | ---: | ---: | ---: |
| Original glow ribbon | 45.096 | 17.811 | 60.5% |
| Musashi dual surface | 207.922 | 144.136 | 30.7% |
| Active ink crescent | 109.363 | 108.446 | About the same |

Idle updates are below one microsecond, near the timer's resolution, so do not
advertise their measured percentage. Earlier separate runs vary with host load;
the paired result avoids interpreting that load drift as a code change. These
are isolated effect CPU costs, not FPS gains or a full-battle benchmark. Prepared
mesh/material identities and resource counts stay stable over 3,000 updates per
owner in the benchmark, alongside the existing repeated-use fixtures.

A final 5,200-check reference comparison proves byte-identical mesh vertices,
indices, UVs and colors across ink, additive and alpha modes, including expiry,
heavy/light colors, reduced flashes, cadence and hiding. It also checks both
Musashi surfaces across Fusion/Lumina and gold flags. This protects Goemon's
current crescent shape, placement, color and timing. The 101 combined-layer
checks include idle-to-attack response, mixed lifetimes, original palettes,
900 reuse updates and all 83 native bake hashes. Original glow ten and Musashi
VFX fifteen pass. The 19-fighter desktop sweep passes 1,608 checks, including
native allies and Kojiro's 54 direction/rate cases. A final 604-check desktop
confirmation exercises Goemon and Musashi on the final source as well.

Asset preservation, 69 toolkit unit, 12,973 imported assets, 98 outfit, thirteen
motion and 86 structure checks pass. No asset or bake was changed. The shared
whole-scene ally fixture still has its previously observed one-resource increment;
keep that distinct from isolated owner reuse. Source snapshots, exact paired
rounds, geometry comparisons, captures and limitations live under
`build/Other Files/Asset Toolkit/Crescent Optimization/`. No app was exported.

Verify in Play Goemon: compare the same Goemon swings at normal and enlarged
reach, then Musashi's blue/red/gold effects. Their appearance and attack behavior
should be identical. For performance comparisons keep army size, camera, range
and attack counts the same; use the saved paired benchmark for effect-code cost
and a separate full-battle profile for any claimed FPS change.

## Illidan allied sound range follow-up — 2026-10-30

The user still heard allied Illidan attacking from far away. A focused reproduction
found two gaps in the earlier 15-metre filter: Immolation could start with an empty
controller ticket and inherit the player's audio ownership, and global weapon or
paired voices checked distance only when they started. Existing ordinary distant
melee, morph, demon launches and impacts already passed the launch filter.

Warcraft's sound helper now supplies the actual caster's weak source ticket when
there is no current attack. Existing weapon and paired voice pools retain that
ticket on every reuse; SoundLibrary's existing process stops playing voices when
their allied source leaves range or disappears. Player and enemy tickets retain
their existing behavior. This is an audio correctness fix, not a measured CPU
bottleneck or claimed speedup. It adds a bounded check of the existing 28 weapon /
impact / general voices and eight paired voices, with no new pools, army searches,
asset loading, simulation, animation, damage or attack timing changes.

The reproduction failed the two new gap assertions before the fix. Fresh checks
pass 59 headless and 63 through Play Goemon, including the real Illidan controller,
Immolation before any attack, normal and demon sounds, moving out of range,
paired-voice cutoff, player reuse and five mixed native allies. The existing 1,000
repeated distant requests retain the same voice pool and no extra nodes/resources.
Desktop SFX recordings peak at 14,537/32,768 for Illidan's nearby melee and exactly
zero at 25 metres; Blademaster's comparison peaks at 7,358 and zero. These are
focused mix checks, not a full-battle or long-session audio/performance benchmark.
Shared audio passes 40 checks and preparation passes six. Asset preservation,
69 toolkit unit, 12,973 imported asset, 98 outfit, 25 Musashi motion/controller and
86 structure checks pass. Logs and WAVs are under
`build/Other Files/Asset Toolkit/Illidan Audio/`. No app was exported.

Verify through Play Goemon: recruit Illidan, approach his attacks, then move more
than 15 metres away while a sound is playing. His sounds should stop; test his
fire aura as well as normal and demon attacks. Your own attacks remain audible.

## Kojiro's rear windup must not become a long crescent — 2026-10-30

The user still saw the first crescent behind Kojiro after the earlier angle fix.
The source pose confirms why: at the source tick-15 hit marker the first sword
is still pulled back, then snaps forward around ticks 17–18. Matching the sword's
angle amplified the wrong phase. Earlier orientation assertions passed while
missing this visual error. Check a complete cut and player-facing direction as
well as blade attachment; angle matching alone is insufficient.

Contact now arms the existing presentation. The new crescent waits for the
physical tip to be in front of Kojiro and the blade direction to point forward,
then samples that authored movement. It uses at most three recent pose seeks to
seed skipped render poses, restoring the current animation cursor afterward.
The second cut snaps to a static final pose; if only one forward sample exists,
a small .12-radian cap bends toward the target so that cut remains visible.
The long crescent fades in .18 seconds. His compact original pink-purple glow
retains its 16/30-second fade, sampling window and original endpoints. Cancel,
hiding or a finished cut clears pending emission. Hit marker, damage, hit shape,
reach, cooldown, projectile behavior and native ownership remain unchanged.
This intentionally puts the large visual on the forward snap a few source ticks
after contact; damage still occurs at its original marker.

This is a presentation correction, not a measured CPU bottleneck fix. It reuses
the same bounded ribbon, prepared meshes and owned materials. No asset export,
model loading, retargeting, new simulation, army search or bake change was added.
Fresh 479 desktop and 478 headless checks pass. Their 54 direction cases cover
all three cuts, normal/fourfold reach, three world-facing directions and
30/60/120 Hz. Both stored tips and rendered outer edges remain in front. They
also check original-marker native damage without duplicate hits, retained glow,
reduced flashes, cancellation and five native Kojiro allies over five repeats.
Those five allies' focused desktop manual presentation p95/max is .684/.713 ms;
manual player step p95/max is .681/2.418 ms. Callback intervals include captures
and the manually stepped rate matrix, so they are not render-FPS measurements.

Fresh checks also pass 700 Kojiro gameplay, ten original-glow and 98 combined
layer/hash assertions (including all 83 bake hashes). Asset preservation,
69 toolkit unit, 12,973 imported assets, 98 outfit, thirteen motion and 86
structure checks pass. An intermediate temporal-only prototype failed 18 cases
because its static second-cut endpoint provided one sample; the forward cap
corrects that. Logs, capture, exact tested hashes and limits are under
`build/Other Files/Asset Toolkit/Kojiro Forward Cut/`. The earlier shared-fixture
one-resource increment remains separate. No full-battle or long-session claim.

Verify through Play Goemon: click once, watch the short original glow on the
backswing, then the longer pink crescent on the forward snap. Repeat all three
cuts, turn around, increase reach, cancel mid-swing and try reduced flashes.
The weapon remains compact. No app was exported.

## Original effects alongside crescents, with Kojiro alignment — 2026-10-30

The user now wants each character's original attack effects together with the
new crescent. Ben regains his original .34-opacity warm-yellow alpha ribbon;
Blademaster and Illidan regain their .65-opacity red/violet additive physical
blade ribbons. Their existing extended ink owners stay intact. Musashi draws his
original additive Gouraud quads from the same sixteen-pair source samples and
weapon-specific blue/red/gold colors alongside the new pigment surface. Both
surfaces share his original descriptor clock and clear/fade together. The other
Rogue melee classes retain an original pigment brush at the compact weapon while
the stronger owner follows full reach. This stays inside each existing admitted
ribbon slot and lifetime; its bounded child expires/cancels with the parent.
Magic Swordsman and Samurai keep their existing purple/crimson effects; Goemon,
Sasuke, Yae, Chief, Mountain King and enemy effects were already retained.

The user's follow-up identifies Kojiro's detached-looking horizontal fan. His
crescent now samples the authored sword at contact and two source ticks earlier
to get its cutting plane. Its leading edge lies along the physical sword; its
broad body trails .9 radians behind that edge, anchored at the blade base. Reach
extension preserves the sword's pitch and yaw. Temporary pose sampling restores
the previous animation position before combat continues. Pink-purple RGB,
original additive glow, hit shape, damage and contact timing remain unchanged.
A visual plane may now differ from the horizontal damage fan: the range circle
and exact combat queries continue to describe gameplay.

This is requested presentation work, not a measured bottleneck fix or speedup.
Prepared original meshes/materials are reused, and no new simulation, global
search, retargeting, attack-time model loading or asset export was added. Three
hundred cycles each of the Ben, Musashi and Rogue ribbon owners (900 combined
updates) retain their prepared resources without growth. Existing hidden-layer,
cancellation and reduced-flash rules apply to the restored layers. Musashi's
previous-weapon fade now owns independent prepared geometry instead of sharing
the active surface being cleared.

Fresh evidence: the 19-fighter sweep passes 1,569 desktop and 1,575 headless
assertions before the last Kojiro alignment refinement. The final targeted desktop
run passes 442 assertions, including all three cuts, original glow, leading-edge
alignment, broad crescent, restored pose, unchanged distant native hit and five
Kojiro allies. Five native allies each of Ben, Musashi, Blademaster, Illidan and
Knight repeat three attacks, including reduced flashes, cancellation and hiding.
Final focused warm manual presentation p95 for these five-body groups is
1.898/1.028/.532/1.099/2.206 ms respectively; maximum is 4.197 ms. The 19-fighter
run occurred under other application/test activity. These are manually stepped
presentation diagnostics, not controlled FPS or full-battle smoothness results.

Original-layer/fresh-bake checks pass 98, Kojiro gameplay 700, original Kojiro
ribbon ten, Musashi VFX fifteen, current native Magic energy 371 and roster ink
feedback 132. All 83 recorded bake hashes are current after regenerating the
existing native pose and Warcraft atlases. Asset preservation, toolkit unit 69,
imported assets 12,973, Musashi outfit 98, motion thirteen and structures 86 pass.
The older main-scene Magic ink fixture still reports seven failures against its
unextended tip/contact assumptions; that log is retained separately. The shared
whole-scene ally fixture still rises by one resource after warmup, separate from
the isolated owners. Full logs, captures, tested hashes and limitations are in
`build/Other Files/Asset Toolkit/Roster Combined/validation.json`.

Verify in Play Goemon: attack with Ben, Musashi, Blademaster, Illidan and Knight;
look for their original weapon-local glow with the farther crescent. Repeat at
larger reach, cancel/switch mid-cut, and enable reduced flashes. With Kojiro,
click through all three cuts and confirm the pink crescent follows the sword's
cutting plane instead of a separate level disc. No app was exported.

## Kojiro's original glow plus the new crescent — 2026-10-30

The user prefers Kojiro's old blade effect too and requests both at once. The
model now prepares a second instance of the existing ribbon owner for his exact
original physical-blade quads: additive pink-purple vertex colors, 30 Hz sample
cadence and 16/30-second fade. The existing ink owner keeps the new extended
contact crescent intact. Both use Kojiro's original RGB (240,120,240), owned
materials and prepared meshes. Cancellation, fighter hiding and hidden donor
layers clear them, and reduced flashes subdue both. Other fighters keep their
current ink mode; the restored additive flag is used only for Kojiro's old layer.

This adds one requested visual layer, not a measured bottleneck fix or speedup.
Neither layer changes collision, reach, damage, native ownership, animations or
projectile behavior. No model/animation transfer, asset export, new simulation,
per-enemy search or combat-time material/model loading was added. Keep the
physical blade endpoints separate from the extended range endpoints so future
reach changes cannot enlarge the weapon or erase either effect.

Fresh verification passes 253 desktop and 1,334 headless roster assertions,
700 Kojiro gameplay checks and ten original-layer checks. The latter verifies
exact original quad positions, additive material, RGB, byte-quantized alpha fade,
expiry, hidden layers, reduced-flash reset and 500 repeated uses with no retained
resources. Five real native Kojiro allies show both layers together over five
repeats, reuse both mesh/material identities, and clear both on cancel. Their
manual presentation p95/max is 1.109/1.481 ms in the desktop fixture; player-step
p95/max is .459/1.363 ms. Physics callback gaps include screenshot/reset work
(p95/max 20.828/94.432 ms), not a controlled rendered-frame benchmark.

Asset preservation and all 83 existing bake source hashes remain valid; no pose
bake changed. Fresh toolkit unit (69), imported asset (12,973), outfit (98),
Musashi motion (13) and structure (86) checks pass. Evidence, captures, tested
input hashes and limits are in
`build/Other Files/Asset Toolkit/Kojiro Combined/`. These are focused results,
not a full-battle or long-session smoothness claim. The earlier shared-fixture
one-resource increment remains separate from the isolated owner result.

Verify in Play Goemon: select Kojiro, click through all three cuts and look for
the original glow following the compact physical sword while the broad
pink-purple crescent shows the longer reach. Cancel/switch during a cut and test
reduced flashes. No app was exported.

## Strong crescents in each fighter's colors — 2026-10-30

The user likes Magic Swordsman's current crescent and wants similarly strong
feedback across characters, especially Kojiro, with each fighter's proper colors.
Magic's existing ribbon geometry is now the shared array builder. A new owned
shader flag applies its dark body, bright edge and moving filaments to other
palettes. The original purple path stays unchanged: before/after desktop sword
and wave-3 images are pixel-identical, and the 378-check reference fixture passes.
Ranged characters retain their existing projectile presentation and colors.

Kojiro's former thin physical-blade ribbon did not communicate his extended
contact fan. His normal/air contact marker now paints a broad pink-purple
crescent from that existing fan/reach, including when render frames skip the
contact. This is a visual addition; its source ticks, three cuts, damage,
projectile travel, cover checks and native hit owner are unchanged. His physical
weapon stays compact. Sloping ground can occlude the horizontal fan; the focused
far-hit fixture suspends both native hurtbox and caster above terrain to isolate
reach/duplicate hits, while gameplay captures use the actual flat courtyard.

The shared short-ribbon owner reuses one prepared ArrayMesh and material with at
most 18 samples/104 vertices, and uses the same curve/taper as Magic. It now serves
Goemon, Ben, Sasuke, Yae, Kojiro and Warcraft blades. Musashi retains the original
16-pair cadence, descriptors, Fusion/Lumina RGB, fades and separate layers with
the stronger shading. Mountain King's hammer, Dark Lumina's claw and Chief's
energy sword reuse prepared contact crescents. Cancellation, hidden donor layers
and fighter switching clear geometry. No model/animation export, runtime
retargeting, new simulation, army-wide search or combat-time material/model
loading was added. Native kit/pose/Warcraft bakes were regenerated from source;
all 83 recorded bake source hashes pass.

Colors follow the existing attack palettes: gold Goemon, warm-yellow Ben,
ivory/gold Sasuke, jade Yae, pink-purple Kojiro, native blue/red/gold Musashi,
red Blademaster, violet Illidan, authored blue Mountain King, green Dark Lumina
and cyan Chief. Rogue classes retain their configured attack tints and Samurai's
crimson. These are owned materials; do not recolor the shared shader resource or
another character's material. Reduced flashes lower emission on the new owners.

This corrects reach readability, not a measured CPU bottleneck or claimed
speedup. Fresh headless and desktop coverage sees effects for 19 melee IDs,
checks their palettes, real distant native damage without duplicate hits,
interruption/expiry, five native allies, and 800 isolated ribbon reuses without
retained resources. Whole-scene resources still grow by one in the short ally
fixture; this is reported separately and not attributed to the ribbon owners.
Desktop captures and callback timings include resets, screenshot activity and
other validation processes; they are not a controlled FPS or full-battle result.
The final Musashi-only desktop rerun checks its added pigment clock.

Fresh checks pass 1,220 headless and 1,241 desktop assertions in the roster fixture,
126 in the final Musashi desktop check, 699 Kojiro, 287 Mountain King, 3,714 modular
spell, 21 Chief sword, 58 Warcraft melee, 17 Ben, 15 Musashi VFX and seven hidden
trail/idle checks. Asset preservation, 69 toolkit unit, 12,973 imported asset,
98 outfit, 13 Musashi motion and 86 structure checks pass; audit reads 306 assets
without errors. Detailed snapshots, earlier fixture failures/corrections,
rendered evidence and limits are under
`build/Other Files/Asset Toolkit/Strong Melee/`. No app was exported.

Verify through Play Goemon: compare Magic Swordsman with Kojiro's three clicks,
then increase only Kojiro's Melee reach. Expect a broad pink-purple crescent at
contact and the same compact sword. Try Goemon, Musashi, Sasuke, Yae, Ben and the
Warcraft heroes; check their own colors, then switch or cancel during a cut.
Repeat with reduced flashes. Keep art strength separate from damage/reach and
profile the same army, camera, range and cast count when checking performance.

## Faint melee outline and compact weapons — 2026-10-30

The user wants a barely noticeable reach circle and larger attack ranges without
oversized weapons. Wind Meadow's ground and privately owned stair material now
mix a thin neutral outline at 10% strength into their existing opaque shading.
There is no filled disc, extra ground mesh, army ring or added draw pass. The
player's basic melee envelope is cached until fighter/range/growth/buff/model
settings change. Facing, height, exact contact shapes and cover still gate hits;
the outline is a guide, not a guarantee. Projectile travel is not shown as melee.

This is a presentation change, not a measured bottleneck correction or speedup.
`WeaponProportions.MAX_REACH_VISUAL_SCALE` caps reach-driven weapon enlargement
at 1.35. Goemon's original native swing also stretches his pipe internally; that
stretch is bounded in presentation. His uncapped `pipe_pose` still owns the same
convex sweep. Sasuke/Yae keep their full contact/source endpoint functions while
rendered poses are bounded. Rogue contact fitting samples the original uncapped
pose, then its existing painted brush extends beyond the compact weapon. Native
army atlases retain separate compact mesh poses and full wave endpoints. Rebuild
kit/pose bakes after changing these source contracts; do not shrink damage reach,
change timing, add per-unit retargeting or restore another army backend to fix art.

The added Goemon/Sasuke/Yae waves reuse the existing short ribbon class and its
setup-time materials. Expiry releases samples/geometry and hiding a fighter clears
its ribbon. No new simulation, per-enemy search or combat-time model/material
loading was added. Existing face texture caches and unrelated scene work are not
proof of a wave leak: whole-scene resource counts rose slightly during the short
fixture. Check the wave owners separately and report that distinction.

Fresh final runs pass 94 headless and 96 desktop assertions, including five
simultaneous native allies. Eight hundred isolated ribbon reuses retain no
resources; full-scene resource counts still rise by one after fixture warmup,
which is not attributed here. Moving-circle world sync p95/max are .041/.048 ms
and five-ally presentation p95/max are 1.168/1.641 ms on the final desktop run.
These are short manually stepped diagnostics, not a speedup or frame-rate claim.
Fresh results, screenshots, input hashes and limits are in `build/Other Files/Asset Toolkit/Attack Reach/validation.json` and
its adjacent logs. Fresh checks also pass original Goemon contact (11), compact
Gold Pipe presentation (8), Sasuke/Yae reach, custom native army tuning (42),
1,792 native pose-transfer assertions, 69 toolkit unit tests, 12,973 imported
asset checks, 98 Musashi outfit, 13 Musashi motion and 86 structure checks.
The native pose fixture still reports whole-scene shutdown resource/RID warnings.
Asset preservation passes and audit reads 306 assets with no read errors. These
are focused correctness/presentation checks, not a full-battle FPS baseline or
long-session soak; the user's 2026-10-23 smoothness report remains historical.

Verify with Play Goemon: start battle, look for the faint ground outline, then
increase Melee reach in Character Balance and attack. The circle and wave should
extend while the held weapon stays compact. Test stairs and grass, switch fighters
and repeat, then reset the range setting. No app was exported.

## Illidan AI stays in Meta — 2026-10-30

The user reported Illidan wasting movement and taking hits while repeatedly
transforming back and forth. The native mirror/recruit selector randomly chooses
his Secondary and numbered Meta inputs even after transformation. Both reached
the player's reversible toggle, restarting the planted morph animation.
`warcraft_combat.gd` now redirects an already-transformed AI's morph request to
its existing bolt attack, including while the form-toggle cooldown is running.
Normal AI can still transform; manual player toggles and retirement/reset remain.

This is an AI decision correction, not a measured frame-time bottleneck or
speedup. It adds one shared check and reuses native decisions, existing combat,
animation/contact clocks and the prepared projectile pool. Do not add another
controller, per-frame asset loading, or an arbitrary form timer to solve this.

The focused `illidan_ai_form_test.gd` reproduces the old behavior and checks both
inputs, manual reversal, five native allies, repeated bolt damage, pool/resource
reuse and retirement/reuse. It isolates navigation to test form decisions;
terrain-routing coverage belongs in the existing native movement fixtures.
Fresh verification passes 47 focused headless and 48 desktop-launcher checks,
45 first-person shooter checks, 56 shared Warcraft skill checks on rerun,
asset preservation, 69 toolkit unit, 12,973 imported-asset, 98 outfit,
13 Musashi motion and 86 structure checks. The five-allied repeat run has no
pool misses or retained node/resource growth. Its desktop step p95 is 2.377 ms;
frame intervals are p95 17.076 ms / maximum 323.958 ms. These are short fixture
diagnostics including resets/capture activity, not a controlled speedup,
full-battle smoothness claim or long-session test. One earlier shared-skill run
reported 30 extra Blademaster-summon nodes; both the in-memory pre-fix control
and final rerun pass. The intermittent result is retained, not claimed fixed.
Evidence and limitations are under `build/Other Files/Asset Toolkit/Illidan AI/`.
Verify through Play Goemon with an allied Illidan: after his first transformation,
watch him keep Meta and attack instead of repeatedly planting to change form.
Select Illidan yourself to confirm both manual toggle controls still reverse.
No app was exported.

## Statue-only opening and nearby ally attacks — 2026-10-30

Both bundled Wind Meadow sizes now start with only the player statue. Home
towers, walls, gates and mines are removed from the preset building lists;
the raised courtyard, four stairs, enemy castles, workers and build options
remain. Loading user-saved maps still preserves their authored buildings.
Older opening/fortress results below describe the previous preset.

The user reported noisy battles with many allies. Source inspection found that
hero weapon/paired voices and ally hit feedback could use the global mix,
while native mercenary cues used a 65-metre radius. This is a sound-density
correction, not a measured frame-time bottleneck or claimed speedup. The smallest
fix gates those existing paths within 15 metres of the player (including height),
using the attack ticket's existing weak source reference. Sustained allied spell
audio stops out of range. Enemy and player cues keep their existing ranges.
The camera remains the 3D listener; reducing its attenuation radius would also
silence nearby allies when the third-person camera sits farther behind.

No simulation, attack timing, damage, army count, art, audio pool or combat-time
resource loading was added. Keep the check at shared playback boundaries and
retain ticket ownership for delayed sounds; do not scan armies or suppress their
combat events to reduce noise. The single range lives in
`scripts/move_audio.gd` as `ALLY_SOUND_DISTANCE`.

Fresh checks pass 50 focused headless assertions and 52 through Play Goemon,
including both presets, a saved custom tower, the exact radius boundary,
height separation, native mercenary cues, five native allied bodies, paired
voices, borrowed Dark/Finale cues and loop cutoff. A thousand repeated distant
requests retain zero nodes/resources and the same voice pool. Actual desktop
SFX recordings peak at 7,358/32,768 for the nearby attack and exactly zero for
the distant attack. The rendered statue-only opening was inspected. Valley
checks pass 1,124 assertions and paid mercenary hunting passes 23 headless and
23 through Play Goemon. Finale Wind steering/audio passes 66 assertions and
Musashi player motion passes 13.
Asset preservation, 69 toolkit unit, 12,973 imported-asset, 98 outfit and
86 structure checks pass. These are focused correctness checks, not a full-army
audio mix, long-session soak or controlled frame-time comparison.

The older paired-move suite still fails three Dragoon sweep/landing assertions.
A temporary control with proximity checks disabled also fails the same three
(plus two native-primary checks); that suite is not counted as passing or fixed.
Dark Lumina 2's 123-check gameplay fixture has the same five footstep/claw/grab
failures with filtering enabled and disabled, with unchanged input hashes in
both final runs. Its earlier run also failed the input-hash check because the
presentation source was edited during that run; it is excluded. No movement or
contact correction was attempted as part of this audio request.
Evidence and recordings are under `build/Other Files/Ally Audio/`.

Verify with Play Goemon: restart on either preset, build any defenses yourself,
recruit mercenaries/hero allies and start battle. Approach their attacks to hear
them, then move more than 15 metres away. Your own attacks should stay audible.
No app was exported.

## Human Cannon Tower — 2026-10-30

The build menu now offers the original Warcraft Human Cannon Tower in slot 5
alongside the Guard Tower. It costs 200 ryo and uses the same workers, placement,
repairs, tower upgrades and native army damage/death owner. Shells follow a fixed
arcing destination and deliver full, half and tenth splash damage within 3, 6 and
7.5 metres of fitted ground-enemy bodies. World cover blocks damage. A target dying
does not cancel an already launched shell.

This is an asset/gameplay addition, not a measured speedup or an isolated new
bottleneck. The smallest integration extends the existing workforce projectiles,
native local enemy query and pooled visual/audio systems. The prepared original
tower is 215 triangles/two surfaces and the shell is ten triangles/one surface.
Meshes, textures and all sound resources load at setup; 16 shells and 16 original
impact bursts warm the existing projectile pool once. Reuse clears transforms,
emission and lifetimes. Attacks do not load models or create materials. Larger
volleys retain all shots and use the existing bounded idle pool.

Fresh standard-map verification through Play Goemon passes 62 assertions,
including native damage, cover, worker firing/release, pause, saved-map roundtrip,
all twelve original WAV/imported PCM hashes and five simultaneous 16-shell
volleys. After warmup the run stayed at 8,322 nodes and 1,841 resources. Cannon
work p95 was 0.778 ms; rendered frame intervals were p95 28.534 ms, maximum
88.518 ms on Apple M3/Metal at 1280×800. Other project work overlapped this short,
manually stepped run, so these are diagnostics, not a controlled FPS comparison,
full-army stress test or new claim of general smoothness. The 2026-10-23 user
experience above remains separate historical evidence.

The final large-map desktop run also passes all 62 assertions. Its repeated
volleys stayed at 13,034 nodes / 1,841 resources, with cannon work p95 0.893 ms,
frame interval p95 38.267 ms and maximum 108.309 ms. Large-map captures were
inspected. The same short-run and concurrent-work limits apply; this does not
establish a new full-battle performance baseline.

Verify with **Play Goemon.command**: open Build, press **5**, place a Cannon Tower
and let idle workers join automatically. Start combat; listen for the three firing/three explosion
variants and watch nearby enemies take smaller splash hits. Compare the Guard
Tower's faster single-target arrows. Sources and editing contracts are in the
Wind Meadow building guide and `assets/audio/warcraft_cannon/README.md`.
Run `tests/forest-shrine/human_cannon_tower_test.gd` through the launcher for a
repeatable check. Current logs, captures and limits are recorded in
`build/Other Files/Asset Toolkit/Human Cannon Tower/VALIDATION.md`.

The user's same-day follow-up shares the original "Job's done" completion cue
with every successful building purchase, once per purchase (including a dragged
wall). It reuses the four prepared placement voices and adds no loading or new
audio nodes. Preparation inspection now contains repair and removal; manual
Assign workers / Auto assign controls are removed. Automatic staffing and combat
worker commands continue through the existing workforce. The focused
`building_placement_audio_test.gd` covers the cue pair, silent failures, mute,
recording, pause, repeated reuse and the simplified inspection panel. Follow-up
evidence is under `build/Other Files/Asset Toolkit/Construction and Level Audio/`.

## Random arrivals across the valley — 2026-10-30

During battle, up to three enemies arrive each second. Random groups sample the
whole map, including off-road ground, instead of only road cells. The existing
native terrain connectivity proves a route to the
castle before admitting each enemy. Older saved castles with closed doors may
use a reachable gate exterior. Ground, scenery, worker and body-clearance checks,
bounded retries, the one-second group timer, wave roster and active cap remain.
Terrain changes defer a group until native navigation has refreshed; they do not
consume queued enemies. No second army controller or rendering system was added.

Rendered testing exposed movement defects behind the earlier road-only
restriction. Flow costs measured horizontal travel, but candidate scoring added
vertical distance, making slow troops turn back uphill. Long corridor samples
could also skip a tiny unsupported stair shoulder that blocked the next step.
The shared native selector now uses horizontal costs. Long field corridors also
check terrain triangle boundaries, where body-clearance differences can peak
between the usual samples. Checking only the immediate step proved insufficient
on the narrower stairs: troops could alternate between two partial approaches.
The corrected corridor certificate keeps the existing exact route cache.
Switching between a nearby tower and the shrine could also restart direct
steering into the cliff. Changed goals now check their actual segment before
choosing direct or routed movement. A reduced native assault fixture reproduces
the failure and verifies both attackers at 24- and 42-metre stair widths.
Castle target bounds also use the building's actual foundation height, matching
the stair work's obstacle and contact bounds.

These are correctness fixes, not a measured frame-rate improvement. To verify,
use Play Goemon, press START and watch groups appear away from the enemy castles
and roads, then approach the castle and climb its stairs. Repeat on the large
valley. Pause stops arrivals; a full army or exhausted roster delays them. The
focused fixture keeps defenses alive to observe every enemy's first real attack.
Its manually advanced simulation times are not rendered frame times or evidence
of full-battle, long-session smoothness. The lane-only results below are historical.

Fresh desktop verification on the 24-metre stairs passes 231 standard-map and
240 large-map checks, with all thirty enemies attacking on each map. All six
ordinary types, all four quadrants and off-road arrivals are covered. The large
fixture allows partial/deferred groups and collects thirty arrivals within twenty
attempts; it does not require unsafe placement to fill every group. Five repeated
spawn/retire cycles after one warm-up retain zero nodes and resources on both.
All 17 native suites pass on unchanged source snapshots, including 5,641 navigation
checks and the reduced target-switch regression. The tested universal library's
SHA-256 is `d0621fcb0d4956dd7057cabf433e62b6f0ed8a2aa5f8f6e0961547f4d6a13740`.
Current captures/reports are under `build/Other Files/Random Enemy Spawns/Anywhere/`;
logs and native fixtures are under `Random Enemy Spawns/raised-castle/`.

## Enemy Skullpion statues — 2026-10-30

Each standard/large Wind Meadow enemy castle now has a destructible stone
Skullpion statue in place of the central farm. Its existing castle HP setting,
reinforcement ownership and victory rule remain: walls can be breached
independently, but the statue must fall to defeat that castle. Placement previews,
the build portrait, health labels and victory text show the same objective.
Old unexpanded saved valleys keep their original farm objectives.

This is requested gameplay/art, not a measured bottleneck fix. The saved
Skullpion GLB's prepared `Castle_Cling` pose is frozen offline into one shared
static mesh/material, preserving all 1,037 triangles. Its 81 source surfaces use
a 1032×1032 engraving atlas with duplicate image pages shared. The original
Blender master, GLB, textures and boss motion remain untouched. There is no boss
simulation, skeleton or AnimationPlayer for statues. The existing shrine
pedestal, stone-block rubble, pooled hit effects and static objective owner are
reused. Combat, physical collision and native navigation share the pedestal and
22 fitted part bounds, including rotation and removal on destruction.

Fresh desktop-launcher checks pass 137 assertions on each valley size, covering
actual pipe/bullet damage, independent wall breaches, four statue defeats,
collision release, victory and restart. The standard headless fixture passes
134. Placement/save/reload checks pass 43 assertions, including the statue ghost
and a newly placed castle. The fixture's site moved clear of the new side stairs.
Its camera must be aimed after teleporting between forts; the initial
headless attempt aimed away from the third/fourth statues. The model check
verifies every posed triangle, source hash and all rotated collision bounds;
2,988 existing Skullpion motion checks also pass. Asset preservation, 69 toolkit
unit, 12,973 imported-asset, 98 Musashi outfit, 13 Musashi player-motion and 86
structure checks pass. Front, angle, overview and destroyed-state captures were
reviewed in the actual painterly game. The standalone model check and icon
exporter complete but report resource/RID warnings at shutdown; the castle
lifecycle checks exit cleanly.

No full-army benchmark, controlled frame-time comparison or long-session memory
test was run. Concurrent development/testing makes the fixture's recorded frame
samples unsuitable for a smoothness claim. Earlier performance results remain
historical. To keep this cheap, rebuild the static resource after source edits
with `tools/build_skullpion_stone_statue.gd`; do not instantiate the animated boss
for each castle or rebuild stone materials during attacks.

Verify through Play Goemon: enter an enemy courtyard (or breach a panel), attack
the labelled Skullpion statue, then check its rubble, open collision and stopped
reinforcements. Destroy every statue to win. Repeat on the large valley and a
newly placed castle. Logs and art evidence are under
`build/Other Files/Asset Toolkit/Skullpion Statue/`; battle results/captures are in
`build/Other Files/Asset Toolkit/Wind Meadow/Castle Breaches/` and its `Large/`
subfolder. No app was exported.

## Musashi sword techniques and one-press skills — 2026-10-30

The user requested more of Musashi's original resources, especially X Slash,
then asked for one press to perform each complete combo. The default hotbar is
now 1 X Slash, 2 Tenderize, 3 Desperado, 4 Rotation, 5 Mighty Strike. Saved custom
assignments are preserved; Skills & Jump still offers the other recovered skills.
Elemental Lumina spells were excluded as requested.

This fixes missing behavior, not a measured frame-time bottleneck. Most body
motions already existed. The small runtime change connects their phases inside
Musashi's existing combat and source-motion clocks, with existing native queries,
collision, damage and ally ownership. The new Tenderize continuation is prepared
with Lumina drawn; the original sprite, blade endpoints and both Desperado trails
are recovered data. No runtime animation retargeting or second army is needed.
Character setup prepares four reusable X Slash impacts and the second sword trail.
Reassigned Musashi combo skills also reuse his visible body and combat owner.

To verify, use Play Goemon, select Musashi and press 1, 2 or 3 near an enemy.
Each button starts with Fusion and advances automatically; missing a target
still plays the sequence but cannot create a hit. Watch the two rising cuts in
Tenderize and both swords during Desperado's leap. Test a miss, repeat each skill,
then interrupt or change fighters to check that no pending cut resumes later.
Preserve the 30Hz source event windows and exact contact checks when editing.

Recovery provenance and limitations are in
`assets/characters/recovered_musashi/README.md`. Current focused evidence is in
`build/Other Files/Asset Toolkit/Musashi Techniques/`. The source/optimized sweep
contains 132 image pairs: 131 are identical; one Tenderize image differs at one
pixel along the overlapping blades. Bone/sample/texture preservation passes;
the inspected poses retain both weapons. These checks establish no emulator
parity or long-session/full-army frame-time claim. Concurrent map/character work
also makes short timing maxima unsuitable as a controlled speed comparison.

Fresh Play Goemon verification passes 90 checks, including all automatic phases,
reassignment, a borrowed combo, interruptions, twelve repeated casts and five
native allies running mixed combos. Repeated casts retain zero additional nodes
or resources. Their manually timed player step is 0.969ms p95 / 3.765ms maximum;
these numbers exclude rendering and full-army work. All captured test input hashes
stay unchanged during that run. A final 86-check headless run also verifies the
lethal-contact flash through the existing native death lifecycle. The 592 numbered-skill and 78 assimilation checks
also pass. A broader skill-balance fixture passes its assertions but logs an
unrelated obsolete Knight charge call and concurrent Mountain King audio casing
warnings; it is not counted as a clean whole-roster result. See validation.txt in
the evidence folder for asset checks and the exact tested native-library hash.

## Central courtyard enlargement — 2026-10-30

The central courtyard is now 30% wider and deeper (96 → 124.8 metres), and
its elevation rises 30% (32 → 41.6 metres). The four stairs scale with it:
31.2 metres wide, with a 124.8-metre run, preserving the original slope.
The statue and enemy forts retain their existing model sizes. The shared
prepared terrain still owns player collision and native army movement;
visible treads retain the same batch and piece count. Saved maps without
`raised_castle` keep their original terrain. Earlier stair and 32-metre
courtyard results below describe the previous dimensions.

This is a layout change, with no measured speedup or full-battle performance
claim. Verify both sizes with `tests/forest-shrine/raised_castle_test.gd`
through Play Goemon: walk up all four stairs and watch native attackers enter
and damage the base. Current captures and logs are under
`build/Other Files/Castle Side Stairs/`.

Fresh verification of these dimensions passes 263 headless checks and 265
rendered desktop checks across both sizes, including 56 autonomous attackers
and eight real player climbs per run. Both rendered overview captures were
inspected. Asset preservation, 69 toolkit unit tests, 12,973 imported asset
checks, 98 outfit checks and 86 structure checks also pass. These focused
results do not establish full-army frame times.

## Castle side stairs — 2026-10-30

The four sides of the raised castle now have broad stone stairs connecting the
valley roads to the existing courtyard. Each is 24 metres wide and climbs the
32-metre rise over 96 metres, with a level landing across the old doorway.
The shorter footprint keeps the inner road ring clear. Doors stay removed;
towers, statue, outer walls, original trees and both map sizes are retained.

This is a requested layout change, not a measured performance bottleneck or
speedup. The existing terrain field prepares the courtyard, stairs and collision
at setup. Fine visible treads reuse batched static boxes and the shared stone
material; the player and armies use the same smooth triangles beneath them.
There are no per-enemy stair controllers, per-frame resource loads or new pools.
Native obstacle bounds now use each building's actual foundation height: sampling
the new landing as a wall base would otherwise create an invisible wall above
the real masonry. The same foundation is used by cached corridor contacts.

The temporary exterior-only portal validation is removed. Map validation again
requires a route from every enemy entrance to the shrine. Old saved maps without
`raised_castle` retain their original terrain and doors. Raised layouts retain
the stairs through editor save/reload and map expansion.

Verify through Play Goemon: walk up each side without jumping, then start combat
and watch approaching enemies climb onto the courtyard. The focused
`tests/forest-shrine/raised_castle_test.gd` checks all six ordinary enemy types
from all four sides, using native autonomous targeting and actual shrine damage,
plus the real player controller and physics. Evidence is under
`build/Other Files/Castle Side Stairs/`. Short manually stepped simulation timings
are diagnostics, not a full-army or long-session frame-time benchmark.

Fresh narrowed-field verification passes 350 headless checks, including 48
ordinary-enemy climbs across all four sides/both sizes, eight off-axis assaults,
eight actual player-controller climbs and the unchanged 8.5-metre giant ground
footprint. The user requested the reduction from 42 to 24 metres (about 43%
narrower); no unit collision size or combat tuning was reduced. An earlier
42-metre desktop fixture passed 352 assertions. Both sizes also retain the
1,206 valley checks; 497 native terrain, 49 wall-height, 35 map-document,
69 toolkit unit, 12,973 imported-asset, 98 outfit, 13 Musashi motion and 86
structure checks passed during this work. These results precede or accompany
other active game edits and are not a full-battle performance acceptance run.

The wider random-spawn crowd fixture exposed tiny-step/target-approach stalls.
The completed shared movement fixes now pass all thirty autonomous castle
attackers on both standard and large maps with the narrowed stairs. The earlier
28/30 run remains a failed historical diagnostic. See the random-arrivals section
above and `build/Other Files/Random Enemy Spawns/raised-castle/` for final evidence.

## Raised castle courtyard — 2026-10-30

The user requested a lift-only first stage, with stairs running along the sides
of the walls in a later step. The bundled standard and large layouts opt into
`raised_castle`: the courtyard is level at the existing 32-metre wall top, while
the original perimeter wall and gateway frames remain at their original height.
Towers, the statue, workers and the player use the lifted floor. The existing
breached-gate lifecycle hides the door panels and disables their colliders;
permanently removed panels cannot return through worker repairs.

This is a layout change, not a measured performance bottleneck or speedup.
Terrain heights are prepared and cached at setup using the existing field and
mesh builder. Physics, native army movement and accelerated corridor queries
share the resulting triangles. Models, scenery, counts and combat are reused.
Old saved layouts without the flag retain their original floor and doors; map
capture, reload and resize preserve the flag. Only the interior field samples
change. No app export is needed for this iteration.

At this first stage, the courtyard had no walkable connection to the outside.
Portal validation temporarily checked only arrival routes to the gateway
exteriors. The side-stair follow-up above restores the shrine-approach proof;
these original lift-only results remain historical.

Run `tests/forest-shrine/raised_castle_test.gd` through Play Goemon to inspect both
map sizes and check physical floor heights, native movement, doors, spawn height,
editor serialization, older saved maps and map expansion. Evidence is under
`build/Other Files/Raised Castle/`. This focused check establishes no full-army
or long-session smoothness claim.

Fresh verification passes 106 desktop and 104 headless raised-castle checks,
1,194 valley checks, 49 wall-height checks, 54 legacy gate-breach/repair checks,
18 map-catalog checks and 35 map-document checks. Active asset preservation,
69 toolkit unit, 12,812 imported-asset, 98 Musashi outfit, 13 Musashi player-motion
and 86 structure checks pass. The older pure-model fixture still fails its two
fog-memory assertions: production retired fog before this change. The wall-height
fixture passes its assertions but reports dummy-renderer resources at shutdown;
the focused raised-castle fixture exits cleanly. No full-battle benchmark was run.


## Random map reinforcements — 2026-10-29

During battle, the existing wave owner now attempts a group of three ordinary
enemies every second, starting one second after START. These enemies appear
directly at random clear points along Wind Meadow's connected lanes and use the
same native army arrival queue, target selection, castle assault and pooled
presentation as castle troops. Castle entrances keep their existing groups and
boss entries. Map groups use opening strength and cannot unlock or grow a castle
group. They draw from the configured wave roster rather than adding uncounted
enemies; full capacity, an exhausted roster or blocked ground can reduce or defer
the group. The 240-enemy cap, one-minute waves, pause and objective victory remain.

This is requested pacing, not a performance optimization. Initial desktop tests
found that unrestricted hillside sampling could strand an enemy even with a
nonempty grid route, and that two clearing retries could miss an entire group.
The smallest correction uses the existing connected lane cells on elevated maps
and bounded retries across four potential clearings. Placement still checks real
terrain, trees, structures, body spacing, workers and a route to the castle.
Arrivals stay at least 90 metres from the shrine and 20 from the player. Do not
replace this with a separate enemy controller or a whole-army search per enemy;
the group shares the existing spawn spatial snapshot and cached navigation.

Fresh model checks cover 30/60/144 Hz timing, all six ordinary types, partial
groups, exact roster accounting, capacity, preparation/restart and blocked
placement. Desktop verification on both standard and large Wind Meadow checks ten
groups of three, native ownership and all thirty enemies attacking real castle
defenses. The focused fixture holds those defenses alive and advances simulation
manually; its timings establish no full-battle FPS or long-session smoothness
claim. The original unrestricted and retry-only failures remain in the logs.

Final verification passes 92 model checks and 174 checks through the desktop
launcher on each map size. Five repeated spawn/retire cycles retain zero nodes
and resources on both. The ten measured group placements have maximum CPU times
of 1.282 ms on standard and 3.053 ms on large; manually stepped 50-ms native
updates have p95 CPU times of 6.276/6.294 ms. These are short fixture diagnostics,
not controlled before/after measurements or rendered frame times. Existing wave
timer (37), castle groups (81), roster (33), asset preservation, toolkit unit (69),
imported assets (12,812), Musashi outfit/motion (98/25) and structure (86) checks
pass. The older roster fixture still reports six resources in use at process
exit despite its passing assertions; the new desktop fixture exits cleanly.

Verify through Play Goemon: press START and watch the minimap for small new groups
away from the enemy castles. They should walk toward your castle and engage its
defenses, while castle troops continue arriving. Pause to stop both arrival
clocks. Clear enemies to free slots if the army reaches its existing cap. Repeat
on the large valley. The fixture and commands are in the forest test README;
captures and reports are under `build/Other Files/Random Enemy Spawns/`.
No app was exported and no assets or native simulation code were changed here.

## Legendary card heroes seek enemies and survive wave resets — 2026-10-29

The user reported that legendary heroes summoned by a card stayed still instead
of finding enemies. The fresh desktop baseline reproduced 21 failed movement,
acquisition, attack/damage and next-wave expectations. Permanent heroes reused
Mirror Image's 48-metre direct-sight search, so enemies beyond the castle never
qualified. Preparation also reset their native action count, speed, reach and
approach while leaving their character bodies alive; later waves had no native
hero controller configuration.

The smallest fix marks permanent arrivals with the existing recruit home data.
Their original nearby target sharing stays intact; when it finds no enemy they
reuse the shared native nearest-contact index and existing terrain routes.
Recruit goals already sample destination ground height, allowing hills and
castle passages. Wave preparation now preserves the prepared hero action setup
and body busy state. An attack command still requires clear contact through
cover. Temporary Mirror Images retain their local search and fifteen-second
lifetime. Existing health, damage, attack timing, skills, models and pools remain
under their current owners; no renderer, pathfinder or army scan was added.

Fresh Play Goemon desktop checks pass all 31 assertions on both standard and
large Wind Meadow. All five card heroes acquire the distant entrance, leave
the castle, reach it and start their existing attacks together; native damage,
next-wave reacquisition and zero additional idle nodes/resources are verified.
Outbound and fighting captures were inspected. Native assertions also exercise
cover on a hill at 20/30/60 Hz, persistent hero configuration and unchanged
temporary-summon waiting.

All 16 native suites pass, alongside 47 legendary lifecycle, 338 universal
Mirror Image, 4,109 native runtime, 69 toolkit Python, 12,812 imported-asset,
98 Musashi outfit, 13 Musashi player-motion and 86 structure checks. Active
asset preservation passes. The initial all-native command omitted the generated
Finale header include path; its regenerated import fixture and corrected native
rerun pass, with the initial compile diagnostic retained separately.
The native-runtime fixture still reports shutdown resource/RID warnings; those
are separate from the passing live idle node/resource checks.

Manually stepped CPU p95/max is 1.157/257.877 ms on standard and .997/658.446 ms
on large. Maxima include navigation/world setup; the standard baseline was
.667/223.940 ms while heroes never moved. These are different workloads and
short diagnostics, with rendering between batches of simulation steps. They
establish neither a speedup nor full-battle smoothness or long-session stability.

Verify through Play Goemon: choose “A legend joins”, start a wave and stand back.
The hero should leave the castle toward enemies, then continue finding targets
after finishing that wave and starting another. Repeat on the large valley.
The repeatable commands are in the forest test README; evidence is under
`build/Other Files/Legendary Hero Hunting/`. No app was exported.

## Mercenaries seek enemies across the valley — 2026-10-29

Paid Dragoon, Ranger, Ninja, Knight and Explorer recruits now acquire the nearest
living enemy from their current position throughout battle. Their preparation
posts no longer impose an 18-metre combat boundary. They pursue replacement
targets, return home when no enemies remain, and retain their existing hiring,
food, health, attacks, shelter recovery and preparation placements. This
supersedes the local guard-area behavior recorded under October 25 below.

The measured failure was behavioral, not a frame-time bottleneck: the baseline
desktop fixture failed all twelve distant acquisition/travel/combat expectations.
The smallest fix reuses the existing native nearest-contact hierarchy rather
than adding a search or simulation. Its enemy positions are shared per pose
revision and body contacts are refined only for competitive candidates. The
2,419-check nearest-query fixture passes; its dense 2,000-enemy case fits seven
bodies. Keep that shared index when extending recruitment or targeting.

Real-map checks also exposed horizontal approach goals retaining the recruit's
starting height. That prevented a route to an enemy on higher ground. Paid
mercenary goals now sample their destination's existing support surface in the
shared native goal setter. A focused native check routes around a wall on a hill
at 20/30/60 Hz. This adds no pathfinder, renderer, combat-time asset loading or
per-unit animation work. Temporary summons and enemy goals retain their owners.

Fresh Play Goemon desktop checks pass all 23 assertions on each of standard and
large Wind Meadow. All five real paid kits leave home, reach a distant raised
enemy entrance, deal native damage, replace targets and return. The fixture
replenishes ordinary targets after Ninja's unchanged execution kills, rather
than disabling that skill. Captured fighting and outbound views were inspected.
Idle searches retain zero additional nodes/resources on both sizes. Hiring (91),
bunker recovery (27), native runtime (4,109), native core, preservation, Python
toolkit (69), imported assets (12,812), Musashi outfit/motion (98/25) and structure
checks (86) pass. The universal native library was rebuilt.

Manually stepped CPU p95/max is .427/221.320 ms on standard and .560/509.610 ms
on large; maxima include initial navigation/world setup. The baseline standard
was .373/223.953 ms while the recruits stayed idle, so these are different
workloads and establish no speedup. Rendering is sampled between manual steps;
these are focused diagnostics, not full-battle frame times or a long-session
resource soak. Earlier fixture failures and traces are retained separately.

Verify through Play Goemon: recruit with M, start a wave and stand back. Recruits
should head out through the castle's open passages, cross the hills and fight
enemies near their entrances. After the last enemy dies they should return home;
injured survivors should still use their existing Farm recovery. Repeat on the
large valley. Evidence is under `build/Other Files/Mercenary Hunting/` and the
repeatable commands are in the forest test README. No app was exported.

## Kojiro rising phoenix and doubled speed — 2026-10-29

The user found the flat phoenix too flat and requested both a gradual climb and
raised head, with twice the forward speed. Its existing release now uses 32
rather than 16 source units per tick. Upward acceleration is 2 metres/second²:
it gains one metre after one second and four after two, in addition to the
original aim. The sprite lifts its head another 15 degrees over two seconds,
then holds that pose. Midpoint movement keeps the climb consistent at different
frame rates. Existing per-step segment contacts and solid-cover checks use this
rising path, including at the faster speed.

This supersedes the phoenix's flat travel below. The three white homing birds,
wind sheets, damage, release timing, eight fire frames, size/hit growth and
three-second lifetime remain unchanged. The unchanged lifetime means twice the
forward travel range before solid cover. Player, borrowed and native-owned ally
casts continue sharing the same controller, prepared visuals and projectile pool.
This is requested motion tuning, not a measured performance bottleneck fix;
it adds no combat-time resource loading, materials, nodes or target searches.

Fresh headless and Play Goemon desktop runs each pass 699 checks, including
climb at 20/30/60 Hz and
half-second steps, the exact doubled release speed, reset pose/lift, independent
overlapping flights, borrowed casts and simultaneous allies. Rendered phoenix
orientation and progressive-pose checks pass 122. Preservation, 69 Python toolkit,
12,812 imported asset, 98 outfit, 25 Musashi motion and 86 structure checks pass.
The final Apple M3 desktop fixture has zero focus losses, zero pool misses and
zero idle resource deltas; stepped CPU p95 is .949 ms and rendered interval
p95/max is 17.723/49.119 ms over 3,944 frames. These are focused diagnostics,
not a controlled speedup, full-battle benchmark or long-session result. Prior
flat-flight measurements below remain historical.
Wind Meadow shoulder and raised-camera captures show the climb and progressive
head lift on the final source.

An initial desktop run lost casts and stopped on an unchecked empty release
list. The fixture now protects manually stepped casts from desktop focus changes
and reports a missing release before reading it; the final rerun passes. This
test isolation changes no gameplay controls. The interrupted log is retained.

Verify through Play Goemon: cast RMB/T down an open lane and watch the phoenix
pick up height and gradually lift its head as it grows. It should cross the
lane twice as fast. Turn and repeat, then try a borrowed cast and Mirror Image;
press 1 to confirm the three white birds retain their existing flight.
Evidence is in `build/Other Files/Asset Toolkit/Kojiro/Phoenix Rise/`.
No app was exported and no asset rebuild was needed.

## Kojiro flat bird flight — 2026-10-29

The user approved a flat, head-first phoenix alongside Dark Lumina 3's second
sword wave, then requested matching flat flight for the three small white birds.
The phoenix now lies centered in its flight plane, with its image's lower head
leading and upper plume trailing. Its launch center is 3.9 metres above the
caster, matching that sword wave, and retains building-growth scaling. White
birds keep their original sprite and 45-degree fan; a prepared diagonal image
offset aligns their beaks with velocity, including each existing homing step.
The fire's eight frames, two-second visual growth, original hit growth, damage,
speed, release markers, lifetimes, steering and cover/contact checks are retained.
This approved pose supersedes the upright presentation described on October 26.

This is an appearance/muzzle correction, not a measured performance bottleneck
fix. It reuses the existing projectile leases, shared meshes and prepared owned
materials. Orientation changes add no resource loading, geometry, pool, material
or target search in combat. Flat sprites naturally become thin when viewed
edge-on; low shoulder and raised views must both be reviewed, rather than making
the sprites face the camera and losing the approved flight direction.

Fresh headless and Play Goemon desktop runs each pass 644 checks, including repeated leases, preserved
growth, borrowed casts, five simultaneous allied phoenixes and fifteen allied
white birds. Metal rendering passes 116 checks for each sprite across 32
camera/flight combinations, checking actual head/tail marker direction against
velocity rather than treating the quad's normal as its nose. Separate native
piercing/cover/lifetime checks pass 45 with no retained nodes or resources.
Preservation, 69 Python toolkit, 12,812 imported asset, 98 Musashi outfit,
25 Musashi motion and 86 structure checks pass. These are fresh focused results,
not a full-army benchmark or long-session soak.

The final Apple M3 desktop run reports zero focus losses or pool misses, zero
idle resource deltas, manually stepped CPU p95 .918 ms and rendered intervals
p95/max 17.819/74.986 ms over 3,944 frames. Baseline p95/max was
17.198/152.643 ms over 3,914 frames; these are fixture diagnostics with capture
and setup effects, not a controlled speed comparison or evidence of hitch-free
battles. The baseline desktop run missed one native melee follow-up; the final
run passes it without changing melee code. Its failed baseline log is retained.
Wind Meadow shoulder and raised-camera captures were inspected on final source.

Verify with Play Goemon: select Kojiro, cast RMB/T into open space and turn before
repeating. The phoenix should fly flat with its head first and tail behind while
growing. Press 1 for three white birds: they should keep the same flat posture
while turning toward targets. Repeat with a borrowed spell or Mirror Image.
Evidence is under `build/Other Files/Asset Toolkit/Kojiro/Flat Bird Flight/`.
No app export or asset rebuild is needed for these script-only changes.

## Four remaining combat test suites resolved — 2026-10-29

The follow-up investigation found fixture and expectation errors in all four
remaining suites. No gameplay, animation, sound, knockback or performance code
needed changing. The current shared impact work and subsequent audio edits are
preserved; protected sound, player, hit/knockback, native combat and projectile
files match the source checkpoint from the start of this follow-up.

Musashi's movement check ran during his legitimate recovered landing pose. It
now lets that source animation finish before testing a run. Its sword check
edited a wave record after native ownership and assumed the enemy had 1,000 HP;
it now creates a known ordinary native target with HP set before import and
asserts that starting HP before checking the unchanged contact window.

Ben's "grounded" fixture was actually airborne with `flying=true`, so the
controller correctly chose the aerial barrage and landing sequence. Real body
physics now settles him first, with an explicit floor/flight assertion. Ed's
beam was correctly clipped to about 7.15 metres by a downward aim into the
ground, despite an unobstructed maximum of about 37.48 metres. The visibility
fixture now aims along a level lane. Neither flight rules nor beam collision,
length, timing or audio were changed. Test projectile cleanup uses retirement
through the existing pool instead of destroying prepared nodes.

Explorer's test now spawns, moves and despawns native targets instead of
inserting legacy dictionaries. The old type-2 prototype has no current native
contact mesh; the distant-root check now uses the current native boss and its
fitted bounds. Its near surface is explicitly asserted inside the real weapon
reach while the root remains over 20 metres away. Side targets, distance,
rear/height, sight, cover, invalid geometry, stale references and movement-wall
checks remain. It also uses an isolated settings file.

Warcraft's old minimum footstep count assumed the earlier cadence. It now
asserts the exact existing every-other-step count and original Goemon sample,
observing all dispatched voices rather than only the final voice in a tick.
The suite now uses Wind Meadow. Sample, cadence, pitch and playback code are
unchanged.

Fresh headless and Play Goemon desktop runs both pass all 529 checks: Musashi
25, Ben/Ed 34, Explorer 36 and Warcraft 434. The desktop runs use Metal on the
Apple M3; representative captures and diagnostic logs are saved. Warcraft's
repeated projectile checks retain 64 prepared instances with zero pool misses;
its repeated special checks report zero resource growth. These are correctness
fixtures, with manual clocks, capture stalls and other project checks running
at times; they are not a new full-battle performance or long-session result.
Preservation, 69 Python toolkit checks, 12,812 imported-asset checks, Musashi
outfit/motion/player-motion 98/25/13 and 86 structure checks also pass.

Keep test setup honest: initialize native HP before importing, let actual body
physics establish grounded/flight state, and isolate clear-line tests from
intentional scenery blocking. A mismatched fixture can look like an early hit,
a wrong attack or a missing effect. Evidence, baseline probes and source
checkpoint are in `build/Other Files/Asset Toolkit/Unresolved Combat Tests/`.
No app export or new full-army benchmark was needed for these test-only repairs.

## One-minute wave concept — 2026-10-29

The user clarified that START must release wave one immediately. Later waves
arrive at 1:00, 2:00 and 3:00. Each wave retains its full 60-second interval,
including the final wave, so four waves still have a four-minute timer; any
surviving enemies require defeat afterward. Empty waves retain their minute. Castle destruction
still permits its existing early victory. The top-center HUD shows the next-wave
countdown and total schedule remaining, then asks the player to clear the enemies.
Pause, settings and fighter selection retain the existing stopped world clock.

This is requested pacing, not a measured bottleneck fix. The existing wave owner
keeps the clock and finite roster; arrivals reuse native lifecycle, entrance
clearance, group gates and active caps. Pending counts carry across minute
boundaries, so crowded entrances cannot silently discard enemies. Group growth
resets each numbered wave. The final castle mix no longer repeats indefinitely;
this supersedes the historical growing-group/mix scheduling descriptions below.
Existing next-wave enemy balance updates still run at each timed boundary.

Fresh model checks cover exact minute boundaries at 30/60/144 Hz, four arrivals
despite surviving enemies, empty waves, clock formatting, restarts, capacity and
backlogged counts. The desktop launcher fixture checks native arrivals, pause,
fighter selection, balance updates and rendered HUD placement at 1280×800 and
960×600 with normal/max HUD scale. The initial delayed-opening version passed
37 model / 60 desktop checks; the immediate-opening follow-up has separate
`immediate-*.log` evidence in the same folder, passing 37 model and 61 desktop
timer checks plus 81 group, 33 roster and 199 balance checks. The adapted
group fixture passes 81 model/native and 97 desktop checks, including real attack
gates, growth, damage scaling and fractional XP. It advances the schedule explicitly; this is
not an uninterrupted four-minute battle or a full-army performance measurement.
Preservation, toolkit/import, outfit, structure, balance, roster, group and
Musashi player-motion checks pass. The reference army fixture freezes its HUD
with its background because its retired wave owner has no live clock. The older
HUD cleanup test reports five portrait-switch assertions; they are retained as
failures, separate from the passing timer layout checks.

Verify through Play Goemon: choose four waves in Tools → Core Game Balance,
restart to apply composition, then press START. Expect 01:00 for the next wave
and 04:00 total, with wave one already entering and wave two due in one minute. Pause and resume, then
let earlier enemies survive into the next minute. Timing/UI evidence is under
`build/Other Files/Asset Toolkit/Wave Timer/`. No app was exported.

## Whole roster impact review — 2026-10-29

The user liked the shared impact direction and requested checks across the rest
of the characters and skills, keeping the existing sounds and knockback. The
catalog has 20 selectable fighters and 88 assignable skills. Keep the existing
shared contact visuals; this review adds no extra hit pause, particles, sound
layer, knockback, material, pool or simulation.

The concrete bug was effect ownership during borrowed-skill cleanup. A borrowed
Rogue controller on an AI copy uses `RogueSharedClassEffects`, but its inherited
exit handler deleted that shared node as if it owned a standalone AI effect
node. Later attacks called a freed object. The smallest fix excludes controllers
with a spell owner from that deletion. Standalone AI controllers still clean up
their own effects. Ranger's full Rapid Shot check now passes 246 checks, including
native damage from all ten arrows and repeated pooled volleys; it previously
logged freed-effect errors and missed the damage assertions.

Fresh shared checks pass: 3,398 modular spell checks, 577 native numbered-input
checks, 153 shared ownership/lifecycle checks and 254 shared feedback checks.
These cover all 88 catalog entries and the 32 supported receiving bodies,
including hidden compatibility fighters; this is functional coverage, not a
claim that every borrowed combination was visually reviewed. Knight fourth
swing/held guard/lion, Ninja's three-hit refresh, Chief weapons/ballistics/sword,
Sonic, Skullpion, Kojiro, both Dark Lumina forms and Warcraft skill checks also
exercise their native contracts. Several old fixtures needed current native
target positions, a hidden-bar null check, merged sword-surface expectations, an
actually close sword target, a clear elevated lion lane or a headless-safe draw
wait. These repairs change tests only.

Through Play Goemon, painterly Wind Meadow runs cover 93 native primary/hotbar
cases plus 39 focused context/aim follow-ups: 20,940 focused physics steps, no
script errors or projectile pool misses, and at most 76 of the existing 384
native effect records. Captures were inspected for melee, piercing, counter,
beam, bazooka, energy sword and Wind impacts. Every selectable primary confirms
native damage after the Chief fixture enables the required camera focus.
Support, movement and context-dependent skills can legitimately report no
damage in this stationary fixture; those rows are not claimed as impact passes.
The follow-ups exercise the actual counter, airborne Dragon Leap, charged Hail
and all five Chief weapons. Screenshot encoding interrupts the initial capture
run, and some follow-ups overlap headless checks: do not use their frame maxima
as gameplay performance evidence. The fixture now excludes its capture interval.

Fresh full-battle evidence is separate: a 24.003-second foreground desktop run
on the Apple M3 retains 240 native enemies and 96 allies with ordinary stats,
normal deaths and reinforcements on painterly Wind Meadow. Six Wind casts launch
468 shots, with 740 prepared projectiles and zero pool misses. The battle records
2,946 damage events, 305 deaths, zero dropped hit events and unchanged measured
source inputs. Frame mean/p95/p99/max are 9.631/17.436/23.379/43.656 ms; shared
presentation averages .727 ms per rendered frame. All battle acceptance checks
pass. Metal GPU timestamps are unavailable. This is one short stress run, not a
before/after speedup measurement or a long-session leak/feel guarantee.

Preservation, 69 toolkit unit checks, 12,812 imported-asset checks, Musashi outfit
and player motion checks, and 86 structure checks pass. At this review stage,
four older suites reported Musashi movement/early-contact expectations, Ben/Ed leader fixture
expectations, Warcraft walking-sound expectations and an Explorer fixture that
inserts legacy enemy dictionaries. They are recorded in the review report and
were not counted as passes. All four are resolved by the follow-up above.
Headless fixture exit diagnostics are also retained.

Verify through Play Goemon: try melee, Ranger's held Rapid Shot, Dragon Leap,
Ed's beam and Chief's weapons; switch fighters, equip/remove borrowed skills,
then attack again. Contacts should remain visible and responsive with the same
sounds and recoil. Reports, captures, source checkpoint and isolated visual
rollback patch are under `build/Other Files/Asset Toolkit/Whole Roster Impact
Review/`. No app export was made.

## Frost Dragon roar for Dragon Leap — 2026-10-29

Dragon Leap now uses the recovered Frost Dragon opening roar (retail event B37,
SC04/011, bank slot 51) as its built-in Voice layer. It plays once at actual
landing as the hunting dragon emerges, alongside the existing landing impact.
Native allies reuse that default on their first landing pulse through the
existing spatial voice pool and overlap throttle. Saved voice recordings, gain,
mute and Restore default retain their existing behavior. The source bank,
pitch/layer records and recovery limitations are preserved with the asset.

This fixes a missing sound, not a measured frame-time bottleneck. The smallest
change adds a prepared default to SoundLibrary and dispatches it from the native
landing event. There is no new audio player, pool, simulation or combat-time
asset loading; damage, travel, animation and shockwave timing are unchanged.
Fresh focused checks pass 29 headless and 32 through Play Goemon on painterly
Wind Meadow, including both airborne buttons, one voice per landing, custom
takes, gain/mute/defaults, grounded-sweep isolation, eight simultaneous native
landings and 1,000 repeated plays with unchanged live node/resource counts.
The desktop mixer capture peaks at .684 with zero clipped samples. The rendered
landing was inspected. The fixture emits shutdown resource/RID diagnostics;
stable repeated playback does not establish whole-game leak freedom.

Existing landing audio (31), paired moves (46), character audio (40), recording
defaults (182), native Dragoon effects (13), toolkit Python (69), imported assets
(12,812), Musashi outfit/motion/player motion (98/25/13), structures (86) and
preservation pass. The asset audit reads 302 models without errors. No full-army
audio-mix, long-session or new frame-time benchmark was performed.

Verify through Play Goemon: choose Dragoon, jump and click either mouse button;
listen for the roar when the dragon emerges at landing. Its Voice layer in Sound
Studio previews the same sound. Keep future audio changes in these prepared
defaults and existing playback owners. Evidence and the original source catalog
are under `build/Other Files/Asset Toolkit/Dragoon Frost Dragon Audio/`.
No app was exported.

### Quieter landing and full-size hunting dragon — 2026-10-29

The user kept B37 as the landing sound and requested 20% less volume. Both the
landing weapon impact and Voice now multiply playback gain by .8 in the shared
resolver; saved gain/mute/takes remain effective. The voice pool now consumes
that resolved gain, just as Studio preview and native spatial playback do.
Grounded lance sweeps and other fighters retain their levels. This addresses
audibility, not a measured CPU bottleneck. The desktop mix has lower average
signal level; the existing SFX hard limiter retains the same peak ceiling, so
unchanged peak amplitude does not mean the gain adjustment was bypassed.

The ground dragon really was smaller: its .7 visual scale is now 1.15, matching
the existing diving dragon. Native kit data already reads that same constant,
so no new renderer or native simulation change is needed. Damage, contact width,
targeting, speed, lifetime, mesh/shader and source animations are unchanged.
Fresh checks pass: roar 31 headless / 34 desktop, hunt 48 headless / 48 desktop,
native effects 14, landing 31, paired moves 46 and recording defaults 182.
The native desktop segment keeps eight dragons for three cycles, 115 presentation
nodes and 1,156 resources before/after. All 567 measured frames had focus; frame
p95/max were 17.578/75.285 ms and native step p95/max .971/2.755 ms. These are
short fixture diagnostics, not a controlled speedup or full-battle certification.
The larger player and allied dragons were rendered and inspected. The fixture's
shutdown resource/RID diagnostics remain separate from stable live reuse counts.

At this step, ground-attack sounds remained in review: original events 8C2
(7.91 seconds) and 907 (2.49 seconds) were supplied as listening previews before
assignment at the user's request. Verify through Play Goemon by jumping
and using either attack button: listen at landing and compare the dragon's
size during descent and hunting. Evidence is in the Frost Dragon toolkit's
`Quieter Landing and Size/` and `Ground Attack Review/` folders. No app export,
full-battle mix test or long-session benchmark was performed.

### Selected 08 for the opening ground pass — 2026-10-29

The user selected preview 08, the original BA9 three-layer sample-6 cue with
its deeper ending, for ground hunting. The installed `ground_attack.wav`
matches that approved preview byte for byte, including its .4 peak headroom.
The B37 landing WAV and both existing .8 landing-gain rules are unchanged.
Sound Studio's separate Hunting dragon · ground attack slot retains independent
recording, gain, mute and Restore default controls.

The new cue plays once on the first follow-up pulse, .26 seconds after landing,
within the opening .35-second hunting pass. Player and native allies reuse the
same existing pulse delivery and voice pools. Later pulses, dashes and damage
events cannot repeat it. There is no new timer, event, pool, per-frame asset load
or native simulation change; travel, damage, targeting, size and lifetime retain
their existing values. This is an audio addition, not a measured bottleneck fix.

Fresh focused checks pass 52 headless / 55 through Play Goemon on painterly
Wind Meadow. They cover separate landing/hunt streams and levels, one hunt cue,
custom takes/gain/mute/defaults, grounded-sweep isolation, eight simultaneous
native landings and 2,000 alternating requests with unchanged live node/resource
counts. Actual desktop mixer output is saved. The fixture advances the real
pending-pulse timers; its first diagnostic omitted that advancement and is not
counted as a gameplay failure or passing verification. Shutdown resource/RID
diagnostics remain separate from stable live reuse counts.

Existing landing (31), paired moves (46), recording defaults (182), native
Dragoon (36), effects (14), hunt (48), toolkit Python (69), imports (12,812),
Musashi outfit/motion (98/25), structures (86) and preservation pass. Audit reads
302 models without errors. No full-battle mix, long-session or new frame-time
benchmark was run. Verify through Play Goemon: jump and attack, hear the retained
landing followed by 08 as the full-size dragon starts hunting, then repeat or
cancel. Evidence is under the Frost Dragon toolkit's `Selected Ground Attack/`.
No app was exported.

## Impact visibility follow-up — 2026-10-29

The user could not see the first shared feedback trial. That report is the
acceptance signal: its modest heavy-only spark change left ordinary hits tiny,
and Goemon's main recovered burst had not changed. Rendered checks also show
native sparks originate inside the victim's body, so simply enlarging that
mesh still hides much of it. Do not count a passing VFX routing test as proof
that the feedback is noticeable at normal gameplay distance.

The follow-up enlarges shared foreground impacts to 1.6× and Goemon's recovered
burst to 2×, retaining their existing art, colors, sounds and durations. Reduced
Flashes retains their previous sizes. Native damage uses the existing painted
spark as three rotated camera-facing rays in the same MultiMesh batch, with
normal/heavy/critical scales 3.0/3.8/4.6. There is still one .18-second effect
record per victim under the same 384-record cap (at most 1,152 contact rays).
Muzzle sparks keep their original size and single-instance presentation.

For a live enemy facade, the existing local contact helper places the burst on
the camera-facing hurtbox surface at the damage event's height, with a .04 m
depth offset. This is a cosmetic viewing adaptation; damage, cover and collision
still use their original contacts. Missing/retired facades retain the event's
position. Reduced Flashes dims the native contact instances to 35% opacity.
No new mesh, texture, material, per-unit renderer, pool or global army search is
introduced. Player clocks, damage, native recoil/stun and camera kick remain
unchanged. The Goemon responsiveness fix is retained.

Fresh checks pass 254 headless / 255 desktop impact assertions, including drawn
camera-facing transforms, bounded crowd geometry, original muzzle behavior,
Goemon scaling and reduced-flash handling. The Wind Meadow desktop review
passes 16 checks, including visible-surface placement and reduced-flash GPU
parameters. Six fighter contact counts remain 25/8/8/99/8/1, matching the earlier
trial, with zero retained nodes/resources after repeated hits. Actual Goemon
and Magic Swordsman contact captures were inspected. The fixture now waits two
physics ticks after contact to capture submitted VFX and explicitly clears its
presentation state between isolated fighters. These are fixture corrections,
not changes to game hit timing. The last six-fighter run lost focus for much of
its duration; its timings are not accepted performance evidence.

The separate final 20.018-second foreground Metal/Apple M3 castle check uses
painterly Wind Meadow with 240 enemies and 96 allies, normal stats and per-death
reinforcements. Counts stay at 240/96 throughout; 2,395 damage events, 237 deaths,
zero dropped hits, full focus and unchanged tracked inputs pass the existing
acceptance gates. Frame mean/p95/p99/max is 16.653/19.883/29.918/36.578 ms;
presentation averages .692 ms per render. This is a short current-source check,
not a matched speedup or long-session stability claim. Historical stress tests
and the user's earlier smooth-gameplay experience remain separate evidence.

Existing combat VFX 42, weapon audio 371, Goemon response 22, Goemon runtime 22,
asset preservation, toolkit Python 69, imports 12,812, outfit 98, motion 25 and
structures 86 pass. The broad army suite retains the same 12 Ranger comparisons
out of 220. The recoil fixture passes 134/138, retaining four boss hurt-pose/wall
expectations that reproduce identically with the pre-trial visual scripts.
Neither broad suite is counted as passing. The native library/combat source and
player/roster controllers match their pre-trial hashes. Separate Dragoon roar
and gain edits appeared in Sound Library during this follow-up; they are
preserved, excluded from this trial's patch, and fully explain that file's hash
change. This feedback task did not edit audio.

Evidence: `build/Other Files/Asset Toolkit/Shared Hit Feedback Trial/Visible Follow-up/`.
Use the reopened Play Goemon source window to judge normal-hit visibility;
the exported app has not been rebuilt. The main trial folder's updated
`experiment.patch` reverses the entire visual experiment while preserving the
Goemon pause fix and unrelated edits. The earlier subtle version is also saved
at `refs/codex/shared-hit-feedback-subtle-2026-10-29`. No app export or long soak.

## Shared impact visual trial — 2026-10-29

The user approved a reversible first pass across the roster, emphasizing that
the current hit sounds and enemy jolt are already good. This trial therefore
changes cosmetics in two existing owners only: shared weapon impacts and the
native army's pooled damage spark. All controller/audio/native-combat source
hashes checked against the checkpoint are unchanged, including the earlier
Goemon responsiveness fix. There is no new simulation, renderer, asset or pool.

Piercing and blunt styles now reach their existing dedicated geometry instead
of the common painted burst. Every family still uses the existing ink shader;
blade, Magic Swordsman purple and Samurai red retain their current identities.
Shared heavy geometry uses 1.5 rather than 1.35 scale; impact opacity fades
linearly for a shorter bright tail. Authored family particle presets remain
bounded by the same displayed-frame/live budgets and reduced-flash controls.
The native spark retains one instance and .18 s per victim, with cosmetic scale
1.0/1.2/1.4 for normal/heavy/critical hits. Damage, stun, physical recoil,
attack pauses, camera kick, hit sounds and saved audio preferences are unchanged.

Fresh checks pass: 200 headless / 201 desktop impact assertions, including all
14 named styles, legacy colors/identities, fade, reduced flashes, budget limits,
expiry and 5,000 repeated native impacts without retained nodes/resources.
Existing combat VFX 42, weapon audio 371 and Goemon response 22 pass. Asset
preservation, 69 toolkit unit, 12,812 imported, 98 outfit, 25 motion and 86
structure checks pass. The broad army presentation suite retains 12 Ranger
skin/contact comparison failures out of 220; all 12 reproduce identically with
the pre-trial effects and presentation scripts in an isolated current project.
That suite is not counted as passing. Older failure reports remain historical.

Paired Play Goemon Metal checks on painterly Wind Meadow use six fighters and
12 native enemies. Both pass 14 checks with matching confirmed contacts:
Goemon 25, Ninja 8, Knight 8, Dragoon 99, Magic Swordsman 8 and Ranger 1.
Repeated native hits leave zero additional nodes/resources; the effect capacity
stays 384. Before/after player-plus-native step p95 is 1.712/1.894 ms, max
48.268/16.443 ms; frame p95 is 20.833/20.139 ms, max 148.687/146.299 ms.
These short capture fixtures include first-use work; focus is 1152/1152 before
and 1150/1152 afterward. They do not establish a performance improvement,
full-army smoothness or long-session stability. Actual gameplay captures and a
rendered light/heavy family comparison were inspected. An initial fixture that
omitted advancement of the native cosmetic clock is retained as a diagnostic,
not used for the paired figures above.

To judge the trial, use Play Goemon and compare regular cuts, Dragoon/Ranger
piercing hits and heavy/critical contacts. Listen for the familiar samples and
watch the existing enemy recoil while judging the new effect shapes. Keep or
revert based on play feel; no app export was requested or made.

Checkpoint: `refs/codex/shared-hit-feedback-before-2026-10-29`. Evidence and a
reverse-apply-checked `experiment.patch` live under
`build/Other Files/Asset Toolkit/Shared Hit Feedback Trial/`. Follow its
`Rollback.txt` to remove only this experiment, preserving the previous Goemon
pause fix and unrelated work. Avoid resetting the whole working tree.

## Goemon pipe contact pause restored — 2026-10-29

The user reported that Goemon gets stuck or swings too slowly when he hits.
A fresh desktop-launcher check on Wind Meadow reproduced extra player freeze:
the recovered pipe bypassed the existing short melee pause because its
`pipe_contact_phase` is -1. Each stage therefore used the full victim feedback
pause (35/60/95 ms). At 60 Hz, three real contacts added 13 frozen ticks
(217 ms) to the unchanged 78-tick missed sequence.

The smallest fix includes the recovered pipe in the existing responsive pause
rule: 25/25/45 ms for the three stages, also 45 ms for the heavy pipe. The same
fixture now takes seven frozen ticks (117 ms), saving 100 ms per connected
triplet: 91 total ticks before, 85 afterward. Animation source timing, weapon
sweeps, damage, reach, victim recoil, coins, allied feedback and other fighters'
pauses retain their existing rules. A longer incoming-hit pause is preserved.
This fixes contact latency; it is not evidence of a CPU/GPU speedup.

The focused desktop check passes 23 assertions, including real three-hit and
missed sequences, repeat duration, simultaneous feedback, heavy/victim pauses,
projectile isolation and zero retained nodes/resources after cosmetic cleanup.
Its manually driven physics fixture uses the real engine step and painterly
Wind Meadow. The final run is focused for all 248 sampled frames: frame p95/max
20.952/135.189 ms and player-step p95/max 2.582/8.183 ms. This short fixture
includes first-use work and a screenshot; those diagnostics do not establish
general FPS or a matched rendering improvement. Earlier diagnostic runs lost
focus. The earlier smooth-gameplay report and historical stress results remain
separate.

Fresh headless checks pass: response 22, original gameplay 43, exact pipe
hitboxes 11, enlarged sweeps 47 and movement cancellation 106. Preservation,
69 toolkit unit tests, 12,812 imported checks, 98 outfit, 25 motion, 13 player
motion and 86 structures pass. Two older fixtures retain one failure each:
the no-backlog test manually ends stage one and expects the whole triplet to be
inactive, and the native enemy test expects Dark Lumina 3 to start an ordinary
attack in its short interruption setup. Both identical failures reproduce in an
isolated copy with the pre-fix `game.gd`; neither suite is counted as passing.
All real Goemon contact/damage cases in that native suite pass. The rendered
launcher run saves all nine native enemy contact captures and passes 92/93
checks, retaining only the same boss interruption-setup failure. Soldier and
wolf contact/recoil captures were inspected alongside the Wind Meadow check.

Verify through Play Goemon: click once into empty space, then into a surviving
enemy, and repeat. All three pipe contacts should land once with a brief impact
beat rather than the longer stuck feeling; check heavy hits and dodge as well.
For regression use `tests/forest-shrine/goemon_hit_response_test.gd`. Before/after
reports, the source checkpoint and the inspected Wind Meadow contact capture are
under `build/Other Files/Asset Toolkit/Goemon Hit Responsiveness/`. No app export
or full-army/long-session benchmark was requested or performed.

## Shared Goemon footstep defaults — 2026-10-28

### Shared footstep speed limit — 2026-10-29

Increasing movement speed also increased ground-contact events, repeatedly
starting the unchanged sound. Hero now reuses its existing `foot_time` field to
leave at least .30 simulation seconds between audible footsteps. Slower cues
still follow their contacts; extra cues are discarded, never queued. Every
Hero owns its interval, which freezes while paused and clears on selection.
Sonic uses the same gate; Musashi's source foot markers and Dark Lumina 2's
walking stomps now route through it too. Their source markers, movement,
animation/combat clocks, dust, samples, pitch policies, levels and saved Studio
controls retain their existing owners. The earlier Warcraft alternate-step
filter remains, with the shared limit also protecting higher speeds.

This fixes sound density, not a measured frame-time bottleneck. It adds no
audio player, resource load, pool or army work. Fresh Play Goemon checks pass
78 cadence assertions across nine movement owners at normal/extreme speeds,
including 120 movement speed for Illidan and Kojiro, audible mixer output,
stopping, independent heroes, pause/selection and 10,000 blocked requests without
node/resource growth. At 30/60/120 Hz, a request every tick permits ten cues in
three seconds. The default/Studio fixture passes 185 headless and 218 desktop
checks, including 19,000 requests reusing the existing voices/resources.

Preservation, toolkit Python (69), imports (12,812), outfit (98), motion (25),
player motion (13) and structures (86) pass. The broader Musashi audio suite
retains the same three Lumina sword-clip/hit-timing failures on both current
source and a fresh isolated pre-fix source overlay; its footstep checks pass.
No full-army frame-time benchmark or long-session audio mix was run.

Verify through Play Goemon: compare walking with a high Run speed as Illidan,
Kojiro or a Goemon class, then stop/jump. Sound frequency should stay bounded
while travel stays fast; Footstep preview/recording/gain/mute still work. Adjust
`Hero.FOOTSTEP_INTERVAL` for a different shared ceiling; do not change WAV pitch
or movement/animation clocks to tune sound density. Evidence and recordings are
under `build/Other Files/Asset Toolkit/Footstep Speed Limit/`. No app was exported.

### Kojiro uses Musashi's footsteps — 2026-10-29

Kojiro's formerly silent step slot now reuses Musashi's prepared
`foot_contact.wav` through the existing SoundLibrary and bounded voices.
His stride events and .22 playback level stay unchanged. This is a sound-default
correction, with no measured performance bottleneck or new playback system.
Fresh checks pass 163 headless and 196 through Play Goemon on painterly Wind
Meadow, covering slow/fast walking, stopping, Studio overrides/gain/mute/defaults
and 19,000 requests with stable nodes/resources/cache. Asset preservation passes.
These are focused checks, not a full-army benchmark or long-session test.
Verify by walking/running as Kojiro through Play Goemon; use Restore default in
Sound Studio if a saved take overrides Footstep. Evidence is under
`build/Other Files/Asset Toolkit/Kojiro/Footsteps/`. No app was exported.

### Illidan and Blademaster cadence — 2026-10-29

The user found their fast movement produced too many step sounds. Hero's existing
playback handler now sounds only odd-numbered stride events for fighters 31/32,
halving their walking/running cues. The same counter still drives every dust
burst; movement, animations, sample, pitch, volume and saved Studio controls stay
unchanged. This adds one sound gate and no timer, resource, pool or army work.
Fresh checks pass 151 headless / 181 through Play Goemon on painterly Wind Meadow,
including exact alternate-step counts at slow/fast input, stopping silence,
custom takes, gain/mute/defaults and 18,000 requests with stable resources.
Preservation, toolkit Python (69), imports (12,812), outfit (98), motion (25),
player motion (13) and structures (86) pass. No frame-time or long-session
benchmark was run for this sound-density adjustment. Verify through Play Goemon:
walk/run as either fighter and listen for one cue per two strides. Evidence is
under `build/Other Files/Asset Toolkit/Shared Goemon Footsteps/cadence-*.log`.
No app was exported.

The user requested one Goemon step sound for Goemon-like characters, Ed, Ben,
Illidan and Blademaster. The central `SoundLibrary.GOEMON_FOOTSTEP_IDS` list
covers Goemon, Edo, the ten Goemon-based classes, Sasuke, Yae and those four
additional fighters (18 total). All share the existing event `217` WAV at source
pitch. This supersedes Sasuke's native `218` gameplay default below; that original
sample and its recovery evidence remain intact. Other fighters retain their
defaults or authored silence. Recordings, gain, mute and Restore default work
through the existing Sound Library policy.

The user's later controlled Ninja/Dragoon check found the shared footsteps too
quiet. Both were already implemented: real keyboard input through the engine's
physics loop confirms event `217`, source pitch and repeated playback for
Goemon, Ninja and Dragoon. The old `.22` gameplay cue reached only 2.36% peak
at the user's saved 58% output level. Shared-family steps now use `.65`, reaching
6.98% peak (+9.41 dB) in the same output-level check, with no clipped samples.
The original WAV, timing, other fighters' levels and saved controls are unchanged.
This is an audibility correction, not a measured performance improvement. A
nonzero recording alone does not establish a useful listening level; check real
movement at the user's normal volume as well as Studio preview.

The updated regression explicitly walks Dragoon as well as Ninja, checks cue
level and passes 147 headless / 177 desktop assertions across ten representative
fighters. The 18,000-request reuse check, recording defaults (182), movement
response (140), preservation, toolkit unit (69), imports (12,812), outfit (98),
motion (25) and structures (86) pass. Live keyboard before/after recordings and
level verification are under `build/Other Files/Asset Toolkit/Footstep Audibility/`.
No full-battle audio-mix or new frame-time benchmark was run.

The focused test also found that Goemon-based classes bypassed both updates to
their existing distance-based stride counter and the footstep playback path.
Their controller now advances that counter from actual ground travel, then uses
Hero's single shared playback handler. Other movement owners retain their timing,
and dust effects retain their previous scope. No new gait timer, asset, pool,
audio player or army simulation was added. This is a sound/default correction,
not a measured frame-time bottleneck fix or a full-battle smoothness claim.

Before the gain correction, focused checks passed 136 headless and 163 desktop on
Wind Meadow. They cover all 18 default/preview routes, preserved defaults for the
other 14 fighters, real walking/running on nine representative fighters including
all four named additions, standing silence, recording controls and Restore
default. 18,000 overlapping requests retain the same nodes, resources and sample
cache. Nine desktop mixer recordings are audible and unclipped. The desktop
fixture disables manual input; an earlier paused run is excluded.

Goemon/Sasuke/Yae/leader audio (166/78/91/56), prepared audio (6), recording
defaults (182), movement response (140) and Yae footfalls (23) pass. Preservation,
69 toolkit unit tests, 12,812 imported checks, 98 Musashi outfit, 25 motion and
86 structure checks pass. The broader Musashi audio suite has three sword-clip
and hit-timing failures out of 43 checks; all three reproduce with the pre-change
versions of the modified runtime scripts in an isolated project. They are not
counted as passing or changed to hide the failures. No long-session army or
frame-time benchmark was run for this audio change.

Verify through Play Goemon: walk as a Goemon-based class and the four named
fighters, stop, then preview Footstep in Sound Studio. Restore default returns
the shared sample; deliberate custom recordings still override it. Keep future
roster defaults in the central list and reuse the stride counters and existing
voices. Logs, recordings, captures and the Musashi baseline comparison are under
`build/Other Files/Asset Toolkit/Shared Goemon Footsteps/`. No app was exported.

## Original Goemon, Sasuke and Yae footsteps — 2026-10-28

The original ordinary-land walking handler selects event `217` for Goemon and
Yae, and `218` for Sasuke. Goemon now shares Yae's already recovered sample;
Sasuke's existing `event_218.wav` replaces his silent walking default. Yae's
sound was already correct. All three retain saved recordings, gain/mute controls
and original event pitch. Current movement cadence is unchanged.

This corrects sound selection, not a measured frame-time bottleneck. The smallest
fix reuses prepared audio and the existing voice pool. Keep this pattern for
future movement sounds: resolve samples during setup, then reuse them during
walking. Do not decode, load files or create players for individual steps.

Fresh source verification executes every frame of four original gaits for each
character (12 cases); both fresh sequencer renders match the installed WAVs byte
for byte. Focused gameplay passes 33 headless and 42 desktop-launcher checks on
Wind Meadow, including repeated walking/running, source pitch, Studio previews,
recording overrides, gain/mute and 3,000 overlapping requests with no extra
nodes, resources or cached samples. All three desktop mixer recordings are
audible with no clipped samples. These focused checks do not establish full-army
frame times, long-session resource growth or bit-exact console DSP; original
RSP filtering and room reverb remain outside the dry reconstruction.

Related checks pass: Goemon audio 166, Sasuke 78, Yae 91, prepared audio 6,
recording defaults 182, toolkit unit 69, imported assets 12,812, Musashi outfit
98, motion 25 and structures 86. The asset audit reads 302 assets with no errors;
active derivative preservation passes. No geometry or animations were changed.

Verify through Play Goemon: select each of the three characters and walk, then
preview its Footstep entry in Sound Studio. A saved custom take still overrides
the built-in sound; Restore default deliberately returns that slot to the ROM
sample. Reproduce the source proof with `tools/verify_goemon_footsteps.py` using
the existing Goemon recovery Python environment. Evidence is under
`build/Other Files/Asset Toolkit/Original Footsteps/`. No app was exported.

## Castle-first assault with local defense aggro — 2026-10-28

The user reported lag and enemies staying in place after the military-target
change below. This supersedes that global military-first policy. Enemies now
march on the shrine/castle and divert to a reachable tower or barracks only
within the existing 28-unit local combat range, measured from its footprint edge.
A sealed objective still requires a reachable gate breach. Dead/untargetable or
distant defenses release aggro; nearby players, defenders, taunts and retaliation
retain their existing rules. Skullpion's separate tall-fort approach applies the
same military distance limit while retaining its climbing and attack patterns.

The measured bottleneck was repeated native target/approach work for distant
military objectives. The smallest fix filters those candidates before expensive
approach checks, inside the existing native targeting owners. No new AI system,
per-unit pathfinder, renderer, pool, asset loading or army-count/art reduction was
added. Keep this filter before reachability work when extending enemy targeting.

The first matched foreground Wind Meadow castle runs kept 240 enemies, 96 allies,
normal soldier stats, painterly scenery and unchanged tracked inputs. Native
decision work fell from 34.846 to 1.220 ms per simulation step (96.5% less), and
FPS rose from 3.07 to 54.55. The baseline simulated only 8.67 seconds during 23.78
wall seconds; the corrected run simulated 19.98 during 20.04. This establishes a
large reduction in targeting work, not fully stable frame times: the corrected
run still missed the benchmark's 55 FPS / 25 ms p95 gates, with p95 33.191 ms and
max 198.350 ms. Its population, normal-stat, focus and event-delivery checks pass.
The user's October 23 smoothness report remains historical experience.

A later 30-second run recorded 25.65 FPS and p95 103.860 ms while a separate
CPU-heavy `/tmp/cg-solve-stream` process was running. That process started after
the first matched comparison. The later run is not accepted as a controlled final
performance confirmation, and neither run establishes long-session smoothness.
The initial attempted baseline was paused by level-up cards and is excluded.
The benchmark now suppresses kill XP only in its test subclass so measurements
retain initial stats and never pause for cards; normal game progression is intact.

Fresh behavior checks pass 38 native targeting cases, all 16 native suites
(including specialized bosses), 44 target-handoff checks, 58 soldier timing/damage
checks and 4,109 runtime checks. Rendered standard and large Wind Meadow fixtures
each pass 77 checks: twelve troops from all four bases advance, breach gates,
engage local defenses, damage the shrine, intercept the player and return.
The fixtures also reject military targets outside the aggro radius. Captures of
castle approaches and attacks were inspected. The universal dylib was rebuilt.
Asset preservation, 69 toolkit unit tests, 12,812 imported checks, 98 Musashi
outfit, 13 motion and 86 structure checks pass. Benchmark coverage passes 14.

The older query-cost fixture still fails four of five expectations, identically
with the committed native library in an isolated project. It is not counted as
passing or changed to hide its failures. The initial all-native runner needed
the generated `finale_kit.h`; regenerating it with the existing import fixture
allowed that last suite to pass. Existing scene-fixture RID/resource teardown
warnings remain; this work does not certify a long-session leak soak.

Verify through Play Goemon: start a wave away from the player and watch enemies
advance toward the castle. Place a defense near their route and another far away:
only the nearby one should draw them off course. Destroy it and watch the assault
resume. A defense behind sealed walls should not freeze troops outside; they
should use a reachable gate. Repeat on the large valley. For repeatable rendered
checks run `tests/forest-shrine/enemy_castle_pathing_test.gd`, adding `-- --large`
for the large map. Logs, traces, captures and `verification.json` are under
`build/Other Files/Enemy Targeting/Castle Aggro/`. No app was exported.

## Barracks and towers before workers and the castle — 2026-10-28

Historical policy, superseded by the local-aggro correction above.

Enemies then preferred the nearest reachable barracks or tower over exposed workers
and the shrine. After a defense dies, the existing decision pass selects another
living defense. Sealed defenses still require a reachable gate breach. Nearby
players and fighting defenders can intercept; taunts and retaliation retain their
existing owners. Specialized boss patterns, damage, attack timing and wave counts
are unchanged. This supersedes the earlier shrine-first assault advice below.

This is requested targeting behavior, not a measured performance bottleneck fix.
The smallest change reuses building assault priorities and extends their native
handoff clamp. Local combat stays above military objectives, while workers stay
below them. It adds no army scan, pathfinder, renderer, pool or asset loading.
The user's earlier smoothness report and historical benchmarks remain separate.

Fresh checks pass 32 native targeting cases, 22 worker/target handoff checks,
58 soldier timing/damage checks and 4,109 native runtime checks. Native group
combat and all three specialized boss suites pass. The Play Goemon fixture passes
76 rendered Wind Meadow checks with twelve sword/gun/spear troops from all four
bases: breach gates, attack defenses before the accessible shrine, resume shrine
damage after defenses become invalid, intercept the player and return afterward.
Protected assets, 69 toolkit unit tests, 12,812 imported checks, 98 Musashi outfit,
13 player-motion checks and 86 structure checks pass. The older hunting fixture still fails the
same nine of twelve expectations with both the previous committed native library
and this revision. Scene teardown resource/RID warnings remain; these focused
checks do not establish long-session resource growth or full-battle smoothness.

Verify through Play Goemon: place a barracks and tower with an exposed worker
nearby, start a wave and stand away from it. Watch enemies attack the reachable
military buildings first, then fall back after both are destroyed. A defense
inside closed walls may need a gate breach first. Evidence is under
`build/Other Files/Enemy Targeting/`. No app was exported.

## Configured castle waves — 2026-10-28

Wind Meadow castles now progress through every configured wave instead of
refilling Wave 1 forever. Counts are shared across all castles: 200 swords
means 200 total, followed by the next configured mix. A switch happens at the
next spawn after the exact count is reached, including inside a growing group.
Empty waves are skipped; the final mix repeats while keeps survive. An empty
final mix leaves no arrivals. Existing enemies remain alive. Destroying every
keep still wins; a new run resets the mix and group progression.

Each entrance retains its independent attack-or-wipe release gate, 10/11/12…
group growth, health/damage/XP tier, blocked-exit retries and active cap across
mix changes. Count settings continue to use the run snapshot. The smallest fix
changes the existing exhausted-roster refill to advance through saved mixes.
It adds no simulation, renderer, asset loading, pool or per-unit update. This
is a pacing correction, not a measured bottleneck fix or performance claim.

Fresh verification passes 99 model/native wave checks and 115 checks through
the desktop launcher, including rendered swords → Vambees → wolves, unchanged
per-entrance growth and real death XP. Core Balance passes 191 checks in both
headless and desktop runs; its updated text and both enemy captures were
inspected. Roster (34), reinforcement combat (71), camps (18), event dispatch
(11), protected-asset preservation, toolkit unit (69), imports (12,812), Musashi
outfit (98), motion (13) and structures (86) also pass. The headless roster and
event fixtures emit resource/RID teardown warnings; both desktop runs exit
cleanly. No long-session performance or resource-growth claim follows.
Evidence is under `build/Other Files/Asset Toolkit/Wave Groups/`
(`castle-waves-*.log`, `castle-wave-2-vambee.png`, `castle-wave-3-wolves.png`
and `growth-settings.png`). No app was exported.

Verify through Play Goemon: set distinct enemy types in successive waves and
start a new run. After the configured total spawns across all castles, watch
for the next type while each entrance's groups keep growing. Empty waves should
skip; the final type should keep arriving until its keep falls. Historical
Wave-1-only and numbered-wave-reset notes below describe the earlier behavior.

## Stronger level-up cards and editable rarity odds — 2026-10-28

The user found level-up rewards too subtle. Normal Character cards now add 30%
attack/spell damage or 20% attack cadence, up from 15%/10%. Normal Tower cards
add 30% damage/durability or 25% firing rate; Worker cards add 50% repair rate
or 25% movement. Silver/Gold/Diamond still add two/three/four ordinary ranks;
revival and the legendary rewards retain their existing behavior. Bonuses stay
additive within each stat and multiply with configured balance. Cards show the
current and resulting team multiplier, including existing legendary tower stacks.

Core Game Balance now exposes four rare-card percentages in 0.01-point steps.
Normal fills the remainder; controls cannot total over 100%. Zero disables a
rarity, and 100% can force one after the others are zeroed. Defaults remain
84.75/10/4/1/0.25%. Settings save automatically, apply next run and do not reroll
an active offer. Old saves retain defaults; invalid files clamp/fall back safely.
This supersedes the earlier advice to edit rarity thresholds in source.

This is requested balance/UI work, not a measured performance bottleneck fix.
The smallest change strengthens the existing multiplier data and snapshots
prepared rarity thresholds during model reset. Player/copies, native allies,
towers and workers retain their current combat owners and presentation. No
per-frame loading, material creation, army scans or additional pools were added.
The total preview reads those same multipliers without changing rank state.

Fresh progression checks pass 546 assertions, including exact custom odds across
all 10,000 outcomes, disabled/forced rarities, malformed saves, stronger tower
arrows/repairs and real native damage/contact cadence. A native ally at two
damage ranks now lands 30.4 damage against the same 19 baseline; the immediately
preceding source landed 24.7. This is a damage comparison, not an FPS benchmark.
Core Balance passes 199 assertions headless and through Play Goemon, covering
percentage limits, fractional persistence, default reset and next-run snapshots.
The launcher gameplay fixture passes 137 desktop checks (123 headless), including
1280×800/960×640 card layouts, exact bonus/total previews, character switches,
five simultaneous mirrors, legendary rewards and repeated card cleanup. Inspected
captures show the new controls and both card layouts. Five repeated choices
retain zero nodes/resources. The short paused-card frame p95/max was
17.867/18.425 ms; this does not establish full-battle smoothness or long-session
balance. The user's October 23 smoothness report remains historical experience.

Protected-asset preservation, 69 toolkit unit tests, 12,812 imported checks,
98 Musashi outfit, 13 motion and 86 structure checks also pass. Native runtime
(4,109) and repair (44) assertions pass; the broad native headless fixture emits
resource/RID teardown warnings. The final progression and both desktop fixtures
exit cleanly. These checks do not claim a long-session army/resource-growth soak.

Verify through Play Goemon: earn a normal Character card and compare damage or
attack cadence, then repeat with a rare card. In preparation choose Core Game
Balance → Level-up Card Chances, edit the percentages, and start a new run.
Use 100% Legendary with the others zero for a quick reward check, then restore
your preferred odds. Run rewards still clear on restart; saved odds persist.
Evidence is under `build/Other Files/Team Leveling/Stronger Cards/`.
No app was exported.

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

### Shorter meta fingers follow-up — 2026-10-28

The user still found the fingers too long/creepy and suggested more thickness or
10% less length. The smallest refinement shortens the four non-thumb finger
chains and claws another 10% from the fuller-palm version, retaining thickness,
thumbs, fuller palms and authored casting keys. This changes the existing mesh
and finger bind positions offline; it adds no runtime work and addresses no
measured performance bottleneck. The 33,094 triangles, two surfaces/materials,
37 bones, palm Muzzle socket and native combat/pooling path are retained.

Fresh source assertions verify all eight chains at .9 segment length and preserve
unrelated rig transforms, animation keys, topology, weights, UVs, vertex colors
and material assignments. The audit reads 302 assets without errors; its existing
close-up triangle-budget warning remains. The regenerated lossless candidate
passes preservation but still offers no draw reduction and is larger, so gameplay
continues using the authored source. All 24 synchronized source/candidate render
pairs have zero pixel difference, and 425 direct imported-pose checks pass.

Fresh Play Goemon verification passes 46 shooter checks with zero retained nodes,
zero retained resources and zero pool misses after repeat firing. Rendered frame
p95/max are 18.424/34.926 ms; stepped work p95 is .766 ms. These are short fixture
diagnostics, not a controlled speed comparison or a full-army/long-session test.
Actual Wind Meadow captures show rest, windup and cast with 40 enemies and zero
pool misses. Toolkit Python 69, imported assets 12,812, Musashi outfit 98 and
structures 86 pass. The Musashi locomotion fixture initially missed its 30 Hz
trajectory during concurrent checks; its separate rerun passes all 33, with both
logs retained. Active and staged preservation pass.

Additional packed-source review compares the actual imported game scene with
the dynamically imported candidate. The generic strict comparison flags one
near-zero finger-transform component; the explicit precision report bounds all
425 checks within .0001. An earlier attempt to load the excluded staging file as
a PackedScene is unsupported; it does not indicate a failure loading the game's
authored source. Those diagnostic logs are retained alongside the passing direct
import and desktop checks rather than counted as strict comparison passes.

To verify, launch Play Goemon, select Illidan, enter meta and alternate resting
hands with held fire: long fingers should look shorter while their thickness,
fuller palms and thumb opening remain familiar. Evidence and the guarded one-time
edit live in `build/Other Files/Asset Toolkit/Illidan Hands/Shorter Fingers/`;
the previous editable source is `refs/codex/illidan-before-second-finger-shortening`.
No app was exported.

### Slightly stronger meta fingers — 2026-10-28

The user requested a little more strength in the finger shape. The saved sculpt
now has 12% fuller finger/claw cross-sections, fading into the existing smooth
bases. Shortened lengths, palm bulk, rig, animation keys, weights, topology, UVs,
vertex colors and materials are preserved. This is an offline surface edit with
the same 33,094 triangles/two surfaces; it adds no runtime work and fixes no
measured performance bottleneck. The larger lossless candidate remains unused.

Fresh Play Goemon checks pass all 46 shooter assertions with zero retained nodes,
resources or pool misses. Frame p95/max are 16.951/33.278 ms and stepped work p95
is .521 ms; these short diagnostics establish neither a speedup nor long-session
or full-army performance. Wind Meadow rest/windup/cast captures with 40 enemies
were inspected. Fresh checks pass: Python 69, finger imported poses 425, shared
imports 12,812, Musashi outfit 98, structures 86 and active preservation. Audit
reads 302 assets without errors; the existing close-up triangle warning remains.

Both source/candidate capture sweeps have 23 exact pairs and one initial
frame with mean channel difference .000927/255, max 10/255; visual review finds
no silhouette discrepancy. Geometry/skin/animation preservation passes. The
unrelated Musashi locomotion fixture still fails its 30 Hz trajectory in both
attempts: its initial steps report 60 Hz deltas after changing clocks, matching
the earlier intermittent fixture issue. It does not load these hands; no movement
code was changed or that failure counted as a pass.

Verify through Play Goemon by alternating rest and held fire in Illidan meta:
fingers should feel fuller while keeping their shorter shape and open-palm cast.
Evidence, the guarded one-time edit and comparison recheck are under
`build/Other Files/Asset Toolkit/Illidan Hands/Stronger Fingers/`; the preceding
editable source is `refs/codex/illidan-before-stronger-fingers`. No app export.

### Fuller meta palm girth — 2026-10-28

The user requested more palm girth to match the stronger fingers. The saved
surface is up to 15% deeper and 8% wider through the palm/thumb pad, fading into
the wrists and finger roots. Smoothing only the volume mask avoids a thumb-pad
ridge without smoothing away the approved sculpt. The shortened/thicker digits,
claws, rig, animation keys, weights, UVs, vertex colors and materials are retained.
This is an offline shape edit, not a measured bottleneck fix; it adds no runtime
work and keeps 33,094 triangles, two surfaces/materials and 37 bones.

Fresh Play Goemon verification passes 46 shooter checks with zero retained
nodes/resources and zero pool misses after repeat casts. Frame p95/max are
17.564/36.560 ms, stepped work p95 .750 ms: focused diagnostics, not a controlled
speedup or full-army/long-session result. Actual Wind Meadow rest/windup/cast
views with 40 enemies were inspected. The final 24 source/candidate capture
pairs have zero pixel difference, and 425 imported-pose checks pass. The larger
candidate still offers no draw reduction, so gameplay retains the authored GLB.
Audit reads 302 assets without errors; the close-up triangle warning remains.
Python 69, shared imports 12,812, Musashi outfit 98, Musashi player motion 13,
structures 86 and active preservation pass. The earlier 33-check clock-switching
fixture failures remain historical; that separate fixture was not rerun here.

Verify in Play Goemon: enter Illidan meta and alternate resting hands with held
fire. The palm and thumb pad should look fuller with smooth transitions; the
shorter fingers and open cast should remain familiar. Evidence and the guarded
sculpt are under `build/Other Files/Asset Toolkit/Illidan Hands/Fuller Palm Girth/`;
the previous editable source is `refs/codex/illidan-before-palm-girth`. No app export.

### Integrated nails and smaller hand proportions — 2026-10-28

The user found the old broad conical nails looked like triangle cookies. The
saved sculpt now uses thinner curved dorsal nail plates, inset skin-colored
roots fading into dark keratin, and rounded exposed fingertip pads. All ten
digit chains are another 10% shorter; palm breadth is 10% narrower, with finger
roots moved inward to match. Finger thickness, palm depth, authored animation
keys and the central Muzzle socket are retained. Source assertions verify every
segment ratio and 844 central-palm width/depth samples. This is an offline art
change, not a measured bottleneck fix. Root colors use the existing claw material
and prepared vertex colors; no runtime construction or new textures are needed.

The smoother nails add 1,980 triangles, bringing this single-player close-up to
35,074, with the same two meshes/materials and 37 bones. The deliberate close-up
budget warning remains. Audit reads 302 assets without errors. The regenerated
lossless candidate passes preservation but offers no draw reduction, so gameplay
retains the authored GLB. Rendered source/candidate review has 23 exact pairs and
one initial frame with mean channel difference .0000164/255, max 10/255, with no
visible silhouette discrepancy. Source hashes match the reviewed exports.

Fresh Play Goemon verification passes all 46 shooter checks, including repeated
fire and recovery, with zero retained nodes/resources or pool misses. Frame
p95/max are 17.074/32.974 ms, stepped work p95 .542 ms. These short diagnostics
establish neither a speedup nor full-army/long-session performance. Fresh checks
also pass: Python 69, finger imported poses 425, shared imports 12,812, Musashi
outfit 98, Musashi player motion 13, structures 86 and active preservation. The
older clock-switching fixture caveat remains historical and was not rerun.

Verify in Play Goemon: enter Illidan meta, inspect curled resting nails and the
open-palm cast, then hold/release fire. Nail bases should stay seated, fingertips
rounded and palms narrower. Wind Meadow captures with 40 enemies and all reports
are under `build/Other Files/Asset Toolkit/Illidan Hands/Integrated Nails/`; the
preceding editable source is `refs/codex/illidan-before-integrated-nails`.
The regular game was reopened after the desktop checks. No app was exported.

### Fuller finger connections and smoother forearms — 2026-10-28

The user identified pinched finger/palm connections, then requested smoother,
less cylindrical forearms. Topology inspection finds one continuous skin piece
per hand/arm, so the connection issue is the shape rather than detached parts.
The eight long-finger roots and nearby webbing now flare smoothly into the palm;
sampled root radii are about 22–24% fuller. Forearm/visible-arm facets are rounded,
with a gentle muscle-to-wrist taper and oval cross-sections. Alternating smoothing
passes preserve bulk; final skin volume is 1.017 times the preceding sculpt.

The forearm pass protects all completed hand vertices exactly. Both edits retain
the current lengths, palm proportions, nails, topology, weights, UVs, vertex
colors, materials, 37-bone rig, casting keys and Muzzle socket. These are offline
surface edits with the same 35,074 triangles and two surfaces/materials. There
is no measured performance bottleneck or extra runtime work: correct appearance
in the prepared mesh and keep the existing animation/combat/pooling path.

Fresh final Play Goemon checks pass all 46 shooter assertions with zero retained
nodes/resources or pool misses. Frame p95/max are 17.973/33.306 ms, stepped work
p95 .761 ms. These short diagnostics establish neither a speedup nor full-army
or long-session performance. Fresh checks also pass: Python 69, finger imported
poses 425, shared imports 12,812, Musashi outfit 98, player motion 13, structures
86 and active preservation. Audit reads 302 assets without errors; the existing
close-up triangle warning remains. The larger lossless candidate is unused.

Wind Meadow rest/cast views with 40 enemies were inspected. Final source/candidate
review has 23 exact render pairs and one initial frame with mean channel error
.001032/255, max 8/255, with no visible shape discrepancy. Earlier root-only
captures/checks are retained separately and do not substitute for final checks.

Verify through Play Goemon: alternate curled resting hands with held fire. The
finger bases should flow into the palm and the forearms should taper smoothly
without losing the current bulk. Evidence and guarded sculpt scripts are under
`build/Other Files/Asset Toolkit/Illidan Hands/Stronger Finger Roots/` and
`build/Other Files/Asset Toolkit/Illidan Hands/Smoother Forearms/`. Preceding source
refs are `refs/codex/illidan-before-stronger-finger-roots` and
`refs/codex/illidan-before-smoother-forearms`. No app was exported.

### Human buildings and angled preparation view — 2026-10-28

The user approved a blend of Warcraft Human shapes and Wind Meadow's painted
finish: barracks become farms visually and in UI, and towers use the roofed
Guard Tower. The existing archive reader/converter/importer, saved-master export,
shared painterly shader and rubble workbench were reused. Saved building IDs,
footprints, costs, food capacity, repairs, native shelter/combat and colliders
are retained. The enclosed tower conceals its pooled crew body/bow; recall
restores the same body. No unit count, combat timing or army backend changed.

This addresses an art request, not a measured performance bottleneck. Completed
tower/farm exports now have one static mesh/two surfaces and 156/171 triangles
(the former authored models had 7,695/4,773). These asset counts are not a frame-
time result. Resources are prepared at building setup and materials are shared;
there is no new per-frame import, retargeter, pool or combat-time construction.
Rubble reuses the new meshes and existing stone blocks, with grounded fragments
and the same bounded castle lifecycle. Editable sources and original native
animation data are preserved; construction timing was not changed.

The user also approved a building-camera offset of (55,150,118), about 25 degrees
around the map and 49 degrees downward. Existing orthographic picking/anchored
zoom remain. Preparation and map-editor panning use shared screen-aligned ground
directions; the combat camera remains unchanged.

Fresh desktop-launcher checks pass 50 building and 41 camera assertions, including
repairs, garrison/recall, placement previews, five rebuild/removal cycles, bounded
shared-material/structure counts and unchanged collider identities. Active and
staged preservation pass; 244,019 staged imported checks, 69 toolkit Python,
12,812 common imports, 98 outfit, 86 structure, 1,206 valley and 90 final castle
destruction checks pass. Native bunker/lifecycle/current-worker-target checks
pass 27/36/44. All 16 source/candidate render pairs are exact, with final hashes;
ten extracted runtime textures match their embedded sources. No full-army or
long-session benchmark or controlled speedup is claimed.

Three older fixtures remain failing: legacy GDScript shelter ownership (1/3),
the worker fixture's old 10-HP expectation versus the unchanged 12.5 production
rate (1/44), and the pure-model indexed/exhaustive tower-target oracle (8/165).
The latter loads no art and its runtime files were already modified before this
request. These are recorded as failures, with current native alternatives
separately reported, not hidden or fixed by restoring an old backend.

Verify through Play Goemon: build a Farm, check five more food, recruit/repair,
assign and recall a tower worker, and drag/zoom in preparation and the editor.
Start combat to confirm its existing camera and tower firing. Review a breached
enemy tower and defeated farm/keep for matching low rubble. Fresh evidence and
limitations are in `build/Other Files/Asset Toolkit/Warcraft Human Buildings Review/VALIDATION.md`.
The regular source game was reopened; no app export was made.


## Mountain King / authored blue glow — 2026-10-30

Slot 33 extends the existing Warcraft controller, Hero controls, local native
contacts/statuses and character projectile lease pool. Native HIT carries timed
stun and Thunder Clap attack slow; Avatar copies use kind 133 in the same native
ownership. Skullpion pauses for stun and slows attack clock/charge travel together.
No enemy simulation or live retargeter was added. The saved Blender master now
contains the requested blue glow; the exporter marks it as authored color, so
the loader uses the packed texture directly. Source geometry/UVs/rig/action hashes
were identical before/after this color edit.

Spell meshes and particle frames are prepared offline and shared as immutable
resources. Selection warms projectiles/status visuals; repeated hits refresh the
same caster/target status lease. The focused 282-check headless run had zero pool
misses, including five simultaneous allied Avatars. This demonstrates bounded
reuse in that fixture, not a long-session leak test or a full-army stress result.
The first desktop 276-check run passed, but its 24.521ms p95 / 151.933ms maximum
rendered intervals were measured during shared desktop/build activity. Do not
interpret them as an isolated baseline, an FPS improvement, or proof of smooth
full-army play. After the authored-blue export, 72 rendered asset comparisons and
the 282-check headless fixture passed. A fresh full gameplay capture yielded to
the user's open game; that session was left untouched. Earlier rendered results
and the tested library hashes are kept in
`build/Other Files/Asset Toolkit/Mountain King/`.

The subsequent armor/clothing follow-up edits packed body/portrait atlas regions
and the existing team-color layer, including Avatar armor. Geometry, UVs, skin
weights, rest rig and all action curves remain identical. It adds no combat-time
work or new material instances. Fresh checks pass 287 focused headless gameplay
assertions and 61,384 source/candidate plus 61,382 active imported assertions;
69 toolkit tests and 72 synchronized asset renders pass. Full desktop gameplay
retest yielded to the user's open game; these results do not establish current FPS.

To verify: use Play Goemon, select Mountain King, run/attack, cast 1 Storm Bolt,
2 Thunder Clap and3 Avatar repeatedly, then switch fighters and respawn. Check blue
aura in normal and stone forms, hammer impact sound, attack/slow/stun expiry, and
that Avatar adds/removes 500 HP exactly once. The focused fixture and asset pipeline
commands are in `docs/recovered-warcraft.md`. If profiling exposes cast spikes,
first check for a pool miss or work moved from selection into the cast loop; keep
all armies, art and source behavior intact when measuring. No new bottleneck was
isolated here, so no broader performance optimization is claimed.


## 2026-10-30: equippable Musashi Leaping Strike

The user requested an aerial attack skill usable by other fighters and chose
attack-while-airborne as its trigger. Equip **Leaping Strike · Air Attack** in
any numbered slot under Q → Skills & Jump. Either attack button after either
jump starts the dive; the assigned skill key also works airborne. Space stays
manual. Borrow Musashi's Variable Double Jump separately through Jump Style.
Unequipping restores ordinary aerial attacks and cancels an active native dive.

This adds behavior, not a measured performance fix. The smallest change reuses
Fusion4's recovered apex/downstroke/landing phases, existing local native combat
queries, jump budget and prepared spell owners/effects. Other fighters retain
their own compatible attack gestures. No animation transfer, runtime retargeter,
new simulation, asset export or repeated combat-time resource loading was added.
The skill is an adaptation of that verified sequence; it is not claimed to be
the still-unidentified original Rumparoni-SP.

Fresh desktop-launcher validation passes 56 assertions: manual first/second
jumps, both attack buttons, unchanged ground attacks, native enemy damage and
landing, equipping/unequipping, interruptions, Goemon and Magic Swordsman
borrowing, twelve repeated casts and five simultaneous native allies. All three
rendered character captures were reviewed. Repeated use retained zero nodes
and resources. Manual player-step p95 was 1.078 ms and maximum 9.013 ms; physics
callback interval p95 was 17.628 ms and maximum 66.051 ms. These include fixture
resets and are diagnostics, not a rendered-frame benchmark or a claim of smooth
full-army gameplay. The larger callback gap has not been attributed to this skill.

Active asset preservation, 69 toolkit unit checks, 12,973 imported asset checks,
98 outfit checks, 13 Musashi motion checks, 86 structure checks, 3,714 modular
spell checks, 592 numbered-skill checks and 86 existing Musashi technique checks
pass at this test revision. Evidence
and tested-input hashes are under
`build/Other Files/Asset Toolkit/Musashi Leaping Strike/`. No app was exported.
To verify by hand, equip the skill, jump once or twice, click attack, then remove
it and repeat. Try the same equipment on another fighter and confirm normal
movement returns after landing. A full-army/long-session benchmark was not run
for this skill change.


## Dark Lumina 3 Water: five-bubble pops — 2026-10-30

The requested Water sequence now pops every falling bubble into five radial
bubbles, each of which pops once without spawning another generation. The old
randomly selected eight-way split is removed from both the player/borrowed
adapter and native enemy combat. Six primary drops, queued casts, spread, travel,
hit/cover checks, primary damage and half-damage children stay with the existing
owners. Recovered bubble/pop sprites, shared materials, native queries and
projectile pools are reused; no asset export, animation transfer, new simulation
or per-enemy renderer was added.

The concrete allocation issue was the old 32-shot Water pool. Two repetitions
of nine accelerated airborne volleys reached 100 concurrent shots and caused
68 misses after the five-child change. Preparing 128 Water shots on selection
removes those combat-time allocations. Fresh desktop-launcher checks pass all
36 assertions, including ground/timeout/enemy contact, both pop generations,
pooled state reset, borrowed Water and repeated queues. The shared prepared pool
remains at 836 with zero misses and zero retained nodes/resources in that fixture.
Fresh native checks pass six simultaneous bosses producing six parent and thirty
child pops at 20/30/60 Hz; existing six-family native checks also pass.

Desktop manual-step p95 was 5.360 ms; callback interval p95/max were
21.008/175.223 ms. Existing headless queue/regression work overlapped this run,
and the earlier diagnostics also shared desktop/build activity. These are short
fixture diagnostics, not a controlled before/after comparison, rendered FPS
measurement, speedup or proof of smooth full-army play. The 159-check elemental
queue suite and 128-check six-family gameplay suite pass. Toolkit Python 69,
common imports 12,973, Musashi outfit 98, Musashi player motion 13 and structures
86 pass. Earlier diagnostic fixture failures are retained separately, including
a target removed from the test list and child contacts counted as parent contacts;
the final fixture isolates the parent's hit and passes. The completeness suite
passes 127 checks on an unchanged rerun; its first headless run missed the Fire
audio-count assertion. That diagnostic remains recorded, not counted as a pass;
no Fire audio logic was changed to suppress it.

Verify through Play Goemon: select Dark Lumina 3 and press 2 Water repeatedly,
then equip Water on another fighter. Each falling bubble should visibly pop into
five travelling bubbles, which pop and disappear without another split. Check
`dark_lumina_3_water_test.gd` and `dark_lumina_3_queue_test.gd` when changing this
attack again; watch pool misses before changing capacity. Reports, captures and
tested-input hashes are in `build/Other Files/Asset Toolkit/Dark Lumina 3/Water Bubbles/`.
No app was exported or full-army/long-session soak run for this change.


### Water pops only on contact — 2026-10-30 follow-up

The user clarified that bubbles must only pop when they touch something. The
previous implementation sent both collision and lifetime expiry through impact,
so a bubble could pop and split in empty air. Water now uses silent retirement
for expiry in both the shared player/borrowed projectile and native enemy
runtime. Contact still plays the recovered pop and creates five children; child
contacts pop without another split. Native child bubbles also use the existing
ground-height contact check. Other spell expiry behavior is retained.

This fixes the impact condition, not a measured CPU/GPU bottleneck. Existing
lifetime caps still bound missed projectiles: an unhit bubble can disappear
quietly, without pop graphics, sound, damage or children. Cast/release counts,
damage, travel, cover checks, prepared assets and the existing 128-shot Water
pool remain. There is no new physics owner, per-unit renderer or resource loading
in combat. The earlier timeout-splitting measurements above are historical and
do not verify this contact-only revision.

To verify, use Play Goemon and cast 2 Water at ground, scenery and enemies.
Contact should create the five-bubble ring; a missed airborne bubble must never
play a pop or split when its lifetime ends. Borrow Water on another fighter and
repeat. The focused fixture separately checks untouched parents/children before
expiry, silent expiry, parent ground/enemy contacts, secondary ground contacts,
numbered/borrowed casts and nine fast ground/airborne volleys. Full volleys still
release six parents; children are required only for actual contacts.

Fresh source checks pass: native six-family regressions plus six simultaneous
bosses in three contact/expiry scenarios at 20/30/60 Hz; toolkit Python 69; common
imports 12,973; Musashi outfit 98; Musashi motion 13; structures 86; active asset
preservation. Headless Water passes all 26 checks with zero pool misses or
retained nodes/resources and a 72-shot peak. Evidence and captures live in
`build/Other Files/Asset Toolkit/Dark Lumina 3/Water Contact/`. The first desktop
attempt changed camera/gameplay state while running; it is retained as a failed
diagnostic. The fixture now isolates physical input and calls the existing
numbered-skill handler directly. No source input behavior was changed.

The corrected desktop-launcher run passes all 33 checks with zero pool misses,
zero retained nodes/resources and a 79-shot peak. Captures verify an untouched
bubble, silent expiry, the contact split and the secondary contact pop. Manual
step p95 is 1.931 ms; callback interval p95/max are 18.886/1012.197 ms. The
large callback gap is not attributed to Water, and this shared-desktop fixture
is not a controlled FPS comparison or proof of full-army smoothness. Production
inputs and the rebuilt universal native library match the recorded hashes.
No app export or full-army/long-session benchmark was run for this follow-up.

## Free level-up offers, named companies/heroes and player reach — 2026-11-05

Level-ups now draw three distinct cards across the full eligible catalog, with
independent unchanged rarity odds. Tower/Worker/Character remain descriptive
labels, not slot restrictions. There are nine ordinary and twelve legendary
cards. Far-reaching Strikes adds +25% melee reach per normal rank to the
controlled character only (+50/75/100% for Silver/Gold/Diamond); it follows
character switching and resets with the run. Five named hero cards replace the
random hero reward. Five named company cards each grant five of the same troop.
Heavenly Artillery and Royal Workforce remain in the shared legendary pool.

This is requested gameplay work, not an isolated performance bottleneck fix.
The smallest change adds one multiplier to the existing melee reach setting and
uses existing contact shapes, painted waves and cached terrain outline. Mirror
approach distance now reads the body's own reach so a player-only card cannot
make copies stop outside their real reach. Rewards use the existing native
mercenary/mirror owners, safe-arrival checks, batch rollback and pooled models.
Card icons reuse cached selection art. No new simulation, art, renderer, combat
resource loading or effect pool was introduced.

Fresh checks pass: progression 598; existing team gameplay 123 headless; named
hero combat/lifetime/reuse 47 headless; the new catalog fixture 126 headless and
130 through Play Goemon with painterly scenery. The latter checks real native
contact beyond baseline reach, fourteen fighter switches, five simultaneous
mirror copies without the player-only range bonus, every named hero and company,
blocked rewards, repeated company reuse and UI cleanup. Inspected captures show
all-Character offers, named companies and named heroes at 1280×800 and 960×640.
Repeated company choices retain no additional nodes/resources after warmup.
Asset preservation, 69 toolkit Python checks, 12,973 imported checks, 98 Musashi
outfit checks, 13 player-motion checks and 86 structure checks pass.

The desktop fixture sampled the cached outline query plus reach lookup for 240
calls at zero/five ranks: p95 .479/.028 ms, maxima 8.293/.207 ms. Headless p95
was .018 ms in both cases. These short shared-machine diagnostics do not show
a speedup, isolate the desktop outlier, or establish full-army FPS/long-session
balance. The user's October 23 smoothness report and earlier stress results
remain historical. Further optional desktop battle reruns yielded to a regular
source game already holding the launcher lock; that game was left running.

Verify through Play Goemon: earn Far-reaching Strikes, compare the faint melee
outline and actual reach, then switch fighters. Expect allies to keep their own
reach. Pick a named Legendary card and check that exact hero or five matching
troops arrive. All three offers may share a category. For faster reward testing,
change rarity odds for a new run through Core Game Balance, then restore your
preferred odds. Evidence and source hashes are under
`build/Other Files/Team Leveling/Free Draft/`. No app was exported.

### Mountain King legendary follow-up — 2026-11-05

Mountain King now has his own `Mountain King joins` card in the shared
Legendary pool. The catalog has 22 cards: nine ordinary and thirteen legendary,
including six named heroes. Slot 33 joins the existing hero-reward allowlist;
its prepared model, portrait, Storm Bolt, Thunder Clap, Bash, Avatar and native
kind 133 reuse the same summon owner. No new animation, renderer, combat loop
or pool was added. There is no isolated performance bottleneck or new FPS claim
for this catalog-only change. Rarity odds remain unchanged.

Verify in a new Play Goemon run: choose Mountain King joins and check that he
arrives at the castle, fights with his existing skills, and survives character
switching until defeated or the run ends. Evidence is under
`build/Other Files/Team Leveling/Mountain King/`; the preceding five-hero
measurements remain historical. No app export was requested.

Fresh follow-up checks pass: 601 progression assertions, including a forced
Legendary coverage sweep; 54 six-hero native summon/combat/lifetime/reset checks
headless; asset preservation; 69 toolkit unit checks; 12,973 imported checks;
98 outfit, 13 motion and 86 structure checks. The initial default-odds sample
missed one legendary and failed its catalog-coverage assertion; coverage now
forces Legendary while independent default-odds checks remain intact. The desktop
launcher yielded to an already-running verification, so no fresh rendered
Mountain King card, frame-time result or full-army soak is claimed here.

### Mountain King cosmetic taunt — 2026-11-05

Historical first implementation; the aggro follow-up below supersedes its
cosmetic-only targeting rule and verification instructions.

The user requested a taunt-looking skill and chose gesture/war cry only.
Mountain King's empty fourth slot now plays his existing `Stand - 3` challenge
gesture and original `HeroMountainKingWarcry1`. Avatar uses `Alternate Stand - 3`.
The existing controller owns its 3.167-second duration, grounded stance and
interruption/finish lifecycle. It deals no damage and changes no enemy targeting
or defensive stats. Existing saved fourth-slot assignments still override it.
Native-owned allied Mountain Kings reuse the same controller and prepared rig.
No animation transfer, export, renderer, resource loading or new pool was added.

Fresh focused checks pass 29 headless assertions and 31 through Play Goemon
with painterly scenery. They cover the fourth-key path, original audio, Avatar,
interruptions, no damage/aggro, assignment overrides, twelve repeated gestures
and five simultaneous native allies. Repeats retain no additional nodes or
resources; projectile pool misses remain zero. Normal and Avatar captures were
visually reviewed. The final desktop manual-step p95/max are 2.568/19.727 ms;
these include fixture work and concurrent checks, not rendered frame intervals,
a controlled speed comparison or evidence of full-army smoothness. This is a
cosmetic addition, not a measured bottleneck fix. Earlier smoothness reports
and measurements remain historical.

Asset preservation, 69 toolkit unit tests, 12,973 imported checks, 98 Musashi
outfit checks, 13 player-motion checks and 86 structure checks pass. The broader numbered-controls suite
reports 593/594 assertions, failing Blademaster's key-2 activation; its isolated
control also fails. No Blademaster logic was changed for this task. Initial taunt
fixture failures and final passing results remain in
`build/Other Files/Mountain King Taunt/`: the fixture now settles newly created
allied physics bodies, disables their auto attack and pauses automatic game
updates while manually stepping actions. Production behavior was not relaxed.

Verify with Play Goemon: select Mountain King, press **4**, then repeat in Avatar.
He should raise/spread both weapons and shout, without harming or attracting
enemies. Evade or switch fighters to cancel. A saved skill in slot 4 takes
precedence; remove that assignment to restore the native taunt. No app export
or full-army/long-session benchmark was run.

### Mountain King attracts enemies; red Avatar icon — 2026-11-05

The user now requests actual attraction and a red version of the Avatar icon.
The earlier taunt deliberately had no aggro, so this addresses missing requested
behavior, not an isolated CPU/GPU bottleneck. Each shout now publishes eight
seconds of player taunt priority through the existing external-target snapshot.
Native allied Mountain Kings reuse their existing `buff_left` lifetime and
taunt selection; no new simulation, renderer, per-caster army scan or resource
pool was added. Their status enters through the existing native HIT binding.
Normal reachability, targetability, death and native ownership still apply.
The original gesture/audio and all other skill damage/timing remain intact.
Interrupting the gesture retains the timed effect; death or character switching
clears the player's taunt, and native despawn retires allied taunts safely.

Slot 4 draws the exact existing Avatar texture through a preloaded immutable
red material. The blue Avatar icon and model materials remain independent.
No bitmap, geometry or animation was exported or transferred.

Fresh checks pass 46 headless and 49 desktop-launcher assertions, including
three real native soldiers switching from ordinary objectives and closing
roughly 9.5 metres toward Mountain King in two simulated seconds. The fixture
first certifies three walkable routes on the actual Wind Meadow map. Its initial
castle-side positions were on disconnected raised ground and correctly failed
the approach check; these diagnostics remain preserved. Normal/Avatar icon
and gesture captures plus native pursuit were visually reviewed. An initial
pixel sampler used logical HUD coordinates on a stretched viewport and produced
a false color failure; that fragile check was removed, retaining the artwork/
material isolation assertions and actual rendered review.

Twelve repeated gestures retain no additional nodes/resources, with zero pool
misses; five simultaneous native allies receive the same timed status. Native
Mountain King, mirror and 46-case target-decision suites pass; new native cases
cover player/allied acquisition, movement, expiry, overlapping taunters, death,
slot reuse and invalid team at 20/30/60 Hz. Existing Knight integration passes
33 assertions and retains its teardown RID/resource warnings. The universal
native library was rebuilt while the game was closed. Asset preservation,
69 toolkit unit tests, 12,973 imported checks, 98 outfit, 13 player-motion and
86 structure checks pass. Earlier broad-control failures above were not rerun
or reclassified as passing by this follow-up.

Final desktop manual player/projectile-step p95/max are .428/.854 ms; native
integration runs outside that sample. These short diagnostic timings are not
rendered frame intervals, a controlled performance comparison or evidence of
full-army smoothness. Evidence and source/library hashes are under
`build/Other Files/Mountain King Taunt/Aggro/`.

Verify through Play Goemon: press **4** on reachable ground and watch nearby
troops redirect toward Mountain King for eight seconds. Try Avatar and check
the fourth icon is red while the third stays blue. Closed walls, height layers
and disconnected routes still block pursuit; a taunt does not teleport enemies
or breach the castle. Existing slot-4 overrides take precedence. No app export
or long-session/full-army benchmark was run.
