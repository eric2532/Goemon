# Dark Lumina 3 — recovered final form

Dark Lumina 3 is player **30** and native enemy **18**. Select him in the fighter
gallery. Set his count through the existing enemy/wave controls to fight him.
Old saved counts migrate with a zero count for new bosses; existing armies do
not silently gain extra units. Launch the current source with **Play Goemon.command**.

Wind steering, 2026-10-26: press **1**, then turn the camera while blowing.
The caster, attached wings, push cone and newly emitted gusts follow current
combat aim throughout the cast. Released gusts retain their flight direction.
Borrowed Wind uses the same controller. Other spells retain their existing aim,
and native bosses retain their existing targeting and timeline.
Wind audio restoration, 2026-10-27: the user reports that Wind is still missing
and requests audible playback. The shared silent-slot rule for its opening and
sustain has been removed. Both samples, Sound Studio preview, native bosses and
borrowed Wind use the existing routing again. Saved recordings, gains and explicit
mutes remain respected; Lumina's footsteps remain quiet. Shared army playback
applies Master volume once, rejects empty streams, and lets priority cues reclaim
an enemy loop if all eight voices are occupied. Player-owned loops remain
protected from ordinary army sounds. The SFX bus uses Godot's built-in limiter
to contain overlapping peaks while retaining 0.3 dB of output headroom after its
existing bus gain. No new audio players or sample assets are needed.

Historical Wind audio selection, 2026-10-26: the user chose candidates 1 and 2. AB9
`wind_start.wav` opens the cast, then the correctly recovered ABE sample
`wind_sustain.wav` loops while blowing. Completion/interruption stops owned
playback. The old, incorrectly extracted `wind_loop.wav` remains source evidence;
the existing Sound Studio `finale_wind_loop` slot now resolves to the corrected
sample, preserving saved mute/gain/custom recordings. AB9 is intentionally
audible in this adaptation although its retail dispatch is disabled.
Audibility correction, 2026-10-27: each Wind release moves the existing held
voice to the current blowing position; flying no longer leaves the sound at
the original height. Its cue gain is 1.0 instead of the generic loop gain .6.
Other loop gains and positions are unchanged.

Walking audio preference, 2026-10-27: the shared `step` slot is now silent for
player 30. Walking and running retain their movement and animation; existing
recordings are preserved. Other fighters retain their footsteps.

Size revision, 2026-10-24: the body, enlarged sword, all six skills, secondary
hazards, Sky copies and defeat effects are **3× their initial Goemon size** for
both the playable fighter and native enemies. Borrowed skills use that same
prepared kit. Hurt bounds, terrain footprint, melee contacts, projectile radii,
area coverage and placement match the new size. Projectile travel retains the
scaled distances and lifetimes; the later player control revision below uses
faster gestures and a free-moving primary combo.
`forest_enemy_roles.gd:DARK_LUMINA_3_SCALE` is the single size setting; native
Combat receives it as validated kit data. The body shader applies a separate
role size so the global enemy-size setting still works. Editable ROM/Blender
masters and the generated source pose bakes retain their original dimensions.

All 22 source sound cues have installed streams and playback routing, including
the restored Wind opening and sustain.
Held loops have prepared loop bounds. His audible range is 195 world units to
cover the larger skills; reused shared voices restore the ordinary range for
other sounds. The rendered fixture also captures non-silent PCM on the live
SFX bus while the six attacks run.

| Input | Move | Recovered behavior used in Goemon |
| --- | --- | --- |
| LMB | Default energy attack | Ground wave → first flying crescent → opposing flying crescent; one click per release, one early continuation can be buffered |
| 1 | Wind | Up to three sequential volleys; each has two attached mirrored wings, outward knockback, four paired-wing gusts per pulse plus an aimed attack for each newly pushed target |
| 2 | Water | Up to three sequential volleys; each has six falling shots and one selected eight-way burst |
| 3 | Fire | Up to three sequential volleys; each has 32 falling flames and lingering ground fire |
| 4 | Earth | Queue up to five presses before landing; one damaging wave per press |
| 5 | Sky | Fade/teleport, five standing copies, staggered upright launches, safe return |

C retains the shared evade. With his default movement, hold Space to fly,
release to descend, and hold Shift to boost. An explicitly equipped jump style
still overrides the default. E/R/T
can receive skills through the existing shared loadout. All six skills
are available to other fighters through that same catalog; no second simulated
character is spawned to cast them.

The gameplay hotbar displays all five spell names and numbers. Its input handler
calls the same `select_number` method as the character adapter, rather than
consuming those keys as empty weapon slots. Wind, Water and Fire accept up to
three total presses, including the first. Repeats before the first release restart
the casting gesture; once firing starts, repeats append a complete volley without
cutting the current one short. Each volley retains its own original windup,
release markers and recovery. Extra presses at the cap do nothing; holding a key
does not queue more casts. Borrowed versions use the same queue. Evade, another
spell, an attack interruption or switching characters discards pending volleys.
Already released hazards retain their normal lifetime and damage.
Repeated Earth presses restart the
airborne gesture and upward motion, up to five total presses per slam. Each
accepted press also queues one damage wave. The queue locks on landing;
presses during its recovery do not restart it. Other number keys can interrupt a
current cast, and LMB returns immediately to the energy attack. This sequence permits normal
movement and resets after 0.7 seconds without a continuation. RMB has no attack
binding. The 40/16/16 source-frame sections reuse `801EF270` and the two halves of `801EF3B8`, with
contacts at local frames 28/11/7. Each cut gets its own existing attack ticket.
Evade clears both the stage and buffered continuation.
The full automatic source Sword rush remains available to native enemies and
through the shared Sword skill.

Player and borrowed gestures run at `CAST_RATE=3`. The three primary sections
take approximately 0.44/0.18/0.18 seconds before shared hit pauses and upgrades.
Every source release remains present in faster spells; Earth still waits for
a physical landing. Wind morph/orbit/loop timing follows the faster controller.
Native enemy cadence remains the boss timeline. The queued fire
workload prepares 256 existing projectile leases at setup, covering consecutive
three-volley queues at maximum pickup speed while airborne; it does not create a
second projectile system or load meshes/materials during attacks.

Spell tuning, 2026-10-24: on top of the earlier shared 3× size, Water sprites
and contact radii grow another 3× and Fire grows another 2×. Their scatter
radii initially grew from 18 to 54/36 metres respectively; all six water releases,
the selected eight-way burst, and all 32 flames remain. Ground fire uses
the same doubled radius in player/native combat. Earth's radius doubles
from 42 to 84 metres, with a larger recovered blast and debris ring.
All six spells deal 5× their previous damage; Sky deals 10× per clone.
The default LMB energy attack uses the Sword spell multiplier for melee contact
and retains the former RMB damage, contact sequence and projectiles.

Wind reuses each prepared inner/outer morph twice, mirrored across the caster,
and pushes targets outward at strength 24. Terrain and cover still block it.
Sky reuses the existing two-frame upright copy pose (`801EFA00`) during the
orbit and launch; travel changes yaw without tipping the body. The recovered
12-frame dive stream remains preserved in the editable master and pose bake.
The flying crescents lie in their source horizontal plane at opposite 33.75°
yaw offsets. As requested on 2026-10-26, both keep that launch orientation
throughout straight flight; the former 84.375°/second visual spin is removed
for the player, borrowed Sword skill, mirror allies and native enemies.
The former travel-axis tilt made one slash disappear edge-on to the gameplay
camera. Each release draws only its actual traveling projectile; the duplicate
stationary cross was removed. Floor impacts receive a small height offset. The recovered ground wave owns
an additive material override (source tpage 186, ABR 1); GLB alpha blending
previously left dark triangles around its glow. These changes select/transform
prepared data and do not alter Blender masters, source motion or pose bakes.

Default ground floating is 60% faster for player and native boss. Existing
shared flight reaches 36/64 horizontal speed and 18/32 ascent without/with
Shift, faster than Ben's 21/36 travel and 15/24 ascent. Releasing Space
descends at 10. Earth temporarily retains ordinary gravity for its physical
slam; flight resumes after the move. The hotbar legend shows these controls.

## Completeness polish — 2026-10-24

Water and Fire scatter radii grew to **81/54 metres**, another 1.5× farther.
The 2026-10-27 queue revision widens them a further 20% to **97.2/64.8 metres**
for player, borrowed skills and native enemies. Per-shot damage stays unchanged.
Fall height increases from 27 to 40.5 metres and the eight-way Water burst
travels for 1.65 seconds instead of 1.1. Release counts remain six Water drops,
eight secondary drops and 32 flames. Fire gains 1.5× width, two prepared trail
instances while falling and an above-ground base pivot. Body impacts settle
flames onto the floor below; landing removes their falling trails and reuse
restores them. Water splashes use the same bottom pivot.

Earth uses the recovered travelling wave and rising shared landing dust,
reaching its actual 84-metre contact radius. Wind's original
area only pushes; the later Wind revision below expands its damaging projectiles.
Their meshes, local queries and leases reuse the shared projectile system.

Water impact shows all 15 frames at its source two-tick holds. Secondary Water
uses those same frames at one tick each; Sky sparks retain all eight frames at
three ticks each. Non-looping effects now clamp rather than repeating their
first frames. Firefall audio starts after eight projectile ticks, Water sounds
on impact, Earth sounds at cast/landing, and grounded Fire shares one sustained
loop until its last flame expires. Ground flames no longer add an unrelated
BA3 impact sound on every landing. Sound Studio exposes all 22 active cues with
recording, gain and mute routed through the existing SoundLibrary. Foreground
cues reuse reserved attack voices instead of being dropped by spatial voice
throttling; simultaneous Fire/Sky/Sword cues have measured mix gains.

The body uses the recovered idle and elemental lighting palette with stronger
contrast and a subtle rim. Face/eye/gem details remain the recovered geometry;
no replacement texture or Blender re-export was necessary. Playable defeat now
retains its core sequence after the shared respawn cancellation.

## Wing alignment and stronger energy — 2026-10-24

Wind reflects the wing's local X column after yaw, fixing the world-axis mirror
that twisted it at diagonal facings. Player and borrowed cast wings follow the
caster's position, height and facing through an existing weak owner reference.
Native bosses retain their fixed cast origin. Both inner/outer layers, traveling
gusts and green impact gusts draw a mirrored pair.

Each Wind pulse launches four spread projectiles, for 88 baseline shots per cast.
The existing local push query also returns each newly caught victim once, adding
one aimed paired-wing attack per victim with a short lead for outward movement.
There is no separate army scan or target cap. Projectiles travel at 90 metres per
second for 1.2 seconds and retain normal cover/contact rules. Wind damage is
another **3×**: 73.125 per projectile before upgrades at the default 65 base damage.
The same kit and native lifecycle handle enemies. Selection prepares 256 Wind
leases; the complete focused fixture uses 424 shared leases with no misses across
three repeated casts among 51 targets. Greater densities can still use the
existing pool's growth path.

All three default energy releases have another **3× mesh size and contact radius** (6.3
metres) and **3× damage** (975 before upgrades at default base damage). One click
still releases the ground wave, and the next two clicks release opposing flying
crescents. This former RMB sequence is now the default LMB attack, with its
damage and click timing preserved. Enemy Sword and borrowed
Sword use the same prepared meshes, radius and damage data. No source geometry,
Blender master, pose bake or texture was changed.

## What was recovered

Identity was traced from retail SC07 FILE_004 module **0x73**, initializer
`801A0230`, descriptor `801AFBE4`, and part table `801B6E94`. This distinguishes
this humanoid final form from Dark Lumina 2 in FILE_003.

- Main body: 17 rigid parts, 16 original motion streams, 830 triangles.
- Sky copy: its own 10-part, 253-triangle model and two source motion streams.
- Effects: 12 source groups (including five retained arena pieces), 65 sprite
  frames, original texture pages/CLUTs, and **50 vertex-morph endpoints** for
  wind, sword and core geometry. Arena pieces are preserved without replacing
  the current map.
- Sprite recovery resolves the actor's dynamic palettes and frame holds. The
  sword slash is an 8-bit texture; the other recovered sprite strips are 4-bit.
  Recovery rejects blank frames so a valid-looking VRAM address cannot silently
  produce an invisible attack.
- Audio: 22 named WAV assets plus the owning bank/sample/event catalogs and
  source hashes. Scene-local bank routing was resolved through SC07 FILE_002;
  the three referenced banks are retained in the research evidence.

The `-5` source animation terminator is a ping-pong stream, including its
repeated endpoint. Recovery now decodes this explicitly and preserves variable
holds. The morph decoder follows the source `80132288`, `8013240C`, and
`801325B8` routines: original vertex identity, base positions, delta positions,
and forward/reverse source segments. Wind is baked into shared shader pose
textures at initialization; the enlarged sword uses its original morph endpoints.

## Editable sources and export

The authoritative editable masters are:

- `assets/blender/enemies/recovered_monsters/dark_lumina_3.blend`
- `assets/blender/enemies/recovered_monsters/dark_lumina_3_sky_copy.blend`
- `assets/blender/enemies/recovered_monsters/dark_lumina_3_effects.blend`

Body/copy actions remain at 30 FPS with `Source__...` names. The effect master
contains editable `Morph_<descriptor>_start/end` shape keys. Preserve the flat
`Part_XX` hierarchy, pivots, paint, UVs and source action names. Do not regenerate
an existing master over artist edits.

Export the open saved master with `tools/export_recovered_monster.py`. The
exporter retains exact recovered geometry, pixels and morphs when unchanged,
and exports artist edits when either geometry or morph fingerprints differ.
Authored exports live separately under `assets/models/enemies/recovered_monsters/`.
Raw disc recoveries under `assets/characters/recovered_monsters/` are provenance.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background \
  assets/blender/enemies/recovered_monsters/dark_lumina_3.blend \
  --python tools/export_recovered_monster.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/bake_recovered_monsters.gd -- dark_lumina_3 dark_lumina_3_sky_copy
python3 tools/goemon_assets.py audit
python3 tools/goemon_assets.py check
```

Repeat the export command with the appropriate master after editing the copy or
effects. Refresh imports before tests. Body/copy `.res` files are generated pose
bakes; never edit them directly. Effect morphs read the authored GLB on setup.
The one-time `prepare_dark_lumina_3_morphs.py` adds missing recovered keys only to
an unchanged existing effect master and preserves already-authored keys.

## Shared runtime contracts

`scripts/forest/dark_lumina_3_kit.gd` supplies the six 30 Hz pose/marker timelines,
projectile parameters, prepared meshes and audio. Player combat is a small
adapter over the existing CharacterCombat, attack tickets, Hero movement,
local contact/cover queries and CharacterProjectilePool. Released hazards finish
through that pool; cast-bound wind/copies and held voices have owner IDs and
are removed on interruption. Projectiles reset state on reuse.

Native enemy AI is specialized code **inside the existing army Combat owner**.
It uses the same Unit, targeting, terrain movement, hit/status handling,
projectile container, events and renderer. No per-enemy scene, skeleton,
AnimationPlayer, material factory, backend selector or runtime retargeter was
added. The existing presentation keeps bounded MultiMeshes and eight spatial audio
voices. Player cues reuse the existing sixteen reserved attack voices. Simultaneous effects may be cosmetically capped; damage simulation is
independent of those caps.

## Fidelity boundaries

This is a playable Goemon adaptation of the six offensive move families,
using the recovered art, motion, effects and source release cadence. Terrain
movement, damage, collision, targeting, jump gravity and safe teleports use
Goemon's rules. Earth waits for a real landing. Sky copies use a closed orbit
on the current target position. It is not a byte-for-byte PSX encounter emulator.

The retail assimilation/core QTE and ending cameras are story sequences rather
than additional ordinary attacks. Their meshes, morphs and named sounds are
retained; defeat uses a compact core burst sequence. The numeric body clips are
preserved, while idle/hurt/death semantic choices are Goemon presentation adapters.
The ending mesh gets its source actor's additive material at setup, and the
compact effect uses the original initial 0x200/0x1000 scale. Its unchanged
authored mesh remains available for a future full cinematic.
The game's entire ending/cutscene and boss music are not transplanted.

Audio reconstructs source pitch, layered samples and delays into WAVs. PSX SPU
ADSR, reverb and interpolation are not emulated. `wind_start` (AB9) is the
user-selected opening gust despite its disabled retail call. Wind sustain uses
the source sample/pitch/loop region with Goemon's cast duration and audition
headroom, rather than emulating the sequence's 20-tick key-off and retriggering.
A full-bank catalog is not a claim that every scene alias is a boss sound.

## Verification and reproduction

Evidence belongs in `build/Other Files/Asset Toolkit/Dark Lumina 3/`.

```sh
python3 tests/asset-toolkit/test_dark_lumina_3_recovery.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tests/asset-toolkit/dark_lumina_3_import.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tests/forest-shrine/dark_lumina_3_test.gd
/Users/eric/Desktop/Play\ Goemon.command --resolution 1280x800 \
  --script tests/forest-shrine/dark_lumina_3_controls_test.gd
/Users/eric/Desktop/Play\ Goemon.command --resolution 1280x800 \
  --script tests/forest-shrine/dark_lumina_3_queue_test.gd
/Users/eric/Desktop/Play\ Goemon.command --resolution 1280x800 \
  --script tests/forest-shrine/dark_lumina_3_completeness_test.gd
/Users/eric/Desktop/Play\ Goemon.command --resolution 1280x800 \
  --script tests/forest-shrine/dark_lumina_3_visual.gd
/Users/eric/Desktop/Play\ Goemon.command --resolution 1280x800 \
  --script tests/forest-shrine/dark_lumina_3_defeat_visual.gd
```

The import test checks every original body/copy pose and produces `finale_kit.h`
for `native/terrain_math/crowd/dark_lumina_3_test.cpp`. That native fixture checks
all six moves at 20/30/60 Hz, melee contact, secondary hazards, cancellation,
cleanup and invalid data. The shared playable-enemy suite also checks actual
sword contact, selection, collision and borrowed skills on the complete roster.

Rendered validation and performance figures are recorded separately in the
performance guide. Earlier interrupted or paused captures are not passing
evidence. Shutdown resource/RID warnings remain in the existing full-scene test
harness; fixed pool counts during use do not establish a long-session leak guarantee.

## Source effects and first-wave silhouette — 2026-10-24

The casting aura and core rays restore the original additive texture-page modes
(41 and 59, ABR 1). The aura also needs its source actor's 3/4/3 scale, relative
offset, attachment, eight source ticks and cycling CLUT. `801A9B80` rotates the
16-color palette at `(352,343)` by four entries per tick. The recovery command
`python3 tools/recover_dark_lumina_aura.py` prepares four source palette phases
as `dark_lumina_3_effects/cast_aura_cycle.png`, with provenance in the adjacent
JSON. Its sampled first-phase pixels match the unchanged original GLB. The
existing atlas shader plays those phases; combat performs no texture uploads.

Sprite materials use full source opacity. Wind retains its textured inner
blend and its actor's additive outer layer; the morph shader no longer applies
the unrelated 0.55 attenuation. Core rays remain additive. The compact defeat
now presents the recovered burst mesh as eight planes at source rolls
`0x100 + i*0x200`, scale `0x300/0x1000`, lasting 24 source ticks. All are prepared
meshes/materials in the existing shared presentation batches.

Earth landing at `801A12C0` calls shared `801830D8` / actor `0x352`. It now reuses
DL2's nineteen-sector textured travelling wave, including rise, rotation,
scroll and fade, instead of the procedural amber annulus. Each combat release
now creates one wave and applies the existing area damage once. Player and
borrowed Earth collect up to five presses before landing, repeating the airborne
gesture and restoring the original upward velocity on each accepted press, then
release that many waves 28 controller ticks apart (about 0.31 seconds at the
default cast rate).
The last queued wave extends recovery when needed. All waves stay centered on
the landing point, reuse the same damage ticket, and preserve damage, range and
cover checks. Landing dust plays once. Dodge, another attack, damage interruption
or character switching clears unreleased waves. Native bosses retain their one
landing damage pulse, now matched by one visible wave.

The first energy release previously switched to the flying-crescent impact
graphic. Ground-wave contacts now retain the same prepared mesh, size, facing
and flight height; enemy body contact no longer lifts the visual up the target.
Cross releases retain their own crescent. Native impact events carry this
distinction through the same army event owner. Source Water/Fire/Sky impacts
also replace generic impact graphics; Sky retains its complete 24-tick flash.
Original attack controls, release timing, damage, travel and hit rules remain.

Fresh verification and captures are under `build/Other Files/Asset Toolkit/Dark
Lumina Effects Restoration/`. The source asset library and editable masters
were preserved. This restores the combat and compact defeat presentation;
the story assimilation/QTE, full ending and cinematic cameras remain outside
the playable adaptation described above. No app export is needed.

## Wind sound candidates — 2026-10-26

ROM event **ABE** has dispatch type 5 (`05 0F 00 01`), which selects a scripted
sound through `80034314`, owner offset `0x18`, and 12-byte descriptors. The current
`recover_monster_audio.py` handles type 5 like an ordinary type-1 sample event,
reading owner offset `0x14` and 20-byte records instead. Its named Wind WAV is
therefore bank 100/sample 2, not the sound selected by the actual sequence.

ABE's correct descriptor is `800C8C8C`, pointing at `800C8A00`. Its first command
selects bank 94, lookup 12, sample 9 (`sample_7c2b6ff8fa8c4ed9`), pitch `0x4A00`,
volume 100 and a 20-driver-tick key-off. The source sample has real ADPCM loop
markers at frames 1 and 372. These addresses and fields are checked against the
retail executable and scene owner by the preview script.

Listening candidates and `source-audit.json` live under
`build/Other Files/Asset Toolkit/Dark Lumina 3/Wind Sound Candidates/`:
the former installed sound for comparison, the correctly selected Wind
sample, disabled AB9 startup, and Kojiro's recovered A37 Wind release. AB9 is
byte-identical to the installed Firefall WAV; it is not a confirmed additional
retail layer. Kojiro's cue is an alternative from another attack.

The user subsequently selected candidates 1 and 2. Runtime uses a fresh,
unfaded recovery of candidate 1 and the unchanged AB9 WAV, not the three-second
audition files. `python3 tools/recover_dark_lumina_3_audio.py --wind-only`
rebuilds `wind_sustain.wav` and its provenance, asserting the actual type-5
dispatch, descriptor, command and ADPCM markers. Its 44.1 kHz loop spans samples
56–20,888. The regression recomputes those bytes and verifies the unchanged
opening WAV. Prepared playback uses the existing eight spatial voices, with
one opening voice and one held voice per audible cast; cancellation releases
both. No playback resources are loaded during attacks.

Other type-5 cues from the generic extractor still need review; their old
source-hash checks prove reproducibility, not correct sound selection. Original
recovery files and user recordings are preserved. Current rendered evidence and
the integrated SFX recording are in `Wind Audio Mix/` under the evidence root.
