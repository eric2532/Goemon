# Goemon — Swarm Survival

A fully local Godot 4.6.1 survival action game set in Tidefall Sanctuary.

## Environment art

The colorful Edo environment reskin uses 13 original editable Blender assets and 128-pixel painted surface textures across Tidefall Sanctuary and the three dormant regions. Characters, gameplay, UI and collision remain unchanged. See [assets, screenshots and validation](docs/environment-reskin/README.md).

The main area now also has a 24-building original Blender town with connected shopfronts, a plaza and waterfront street. See the [before/after views and named building catalog](docs/tidefall-town/README.md). Existing routes remain open; the new closed buildings have solid collision.

## Play

Open **build/Goemon.app**, then select **Play**. The macOS application includes the game engine and all content. You do not need Godot, a terminal, an account, or an internet connection.

The application is a universal Apple Silicon / Intel macOS build. The project uses Godot's native Metal Forward+ renderer. Select Performance in Settings if needed.

## Survival rules — v2.7

- **One map:** Tidefall Sanctuary. The other three locations and their portals are hidden; their source assets remain available for later development.
- **Ten minutes:** the HUD counts down from 10:00. Staying alive until 00:00 wins; losing all vitality ends the run.
- **Periodic swarms:** up to 100 enemies arrive when the run begins, then another wave every 10 gameplay seconds. Each minute adds 10 enemies to each new wave: 100 in minute one, 110 in minute two, through 190 in minute ten. There are 60 waves (8,700 requested arrivals before capacity limits); the last arrives at 00:10 remaining.
- **Automatic pursuit:** ninjas, wind scouts and iron brutes spawn on clear ground around the hero and immediately run toward them. Surviving enemies remain between waves. Defeated enemies are replaced only by future waves.
- **Pause and retry:** Escape, Settings and Prototype Lab freeze the clock and waves. Restart survival / Try again resets the timer, population, kills and power-ups.

The default hard limit is **200 active enemies**, including practice enemies. Prototype Lab exposes a 32–400 limit that takes effect on the next run; changing it never removes living enemies. Each wave requests only available slots, discards overflow and replaces any previous unplaced request. Skipped demand does not accumulate or burst after kills; the next scheduled wave replenishes free slots. The ten-minute clock, 60-wave progression and wave-size growth remain intact. Spawning retains its 12-per-frame / 3 ms budget and safe placement checks. Swarm bodies use the animated crowd renderer without a full skeleton per actor. The default is a conservative population bound, not a measured Mac frame-rate guarantee.

The HUD shows time remaining, wave number and size, the next swarm countdown, enemies alive and kills. The former guardian/door expedition objective is inactive in this mode. Existing characters, weapons, abilities, healing drops and map traversal remain available.

## Weapons, power-ups and spells — v2.11

**Elemental orb prototype — v2.18:** every defeated enemy drops a random **1–5 orbs**, split between yellow attack-speed, blue ice and red fire. Yellow adds **+50% attack speed per stack, up to four stacks / 3× speed**, lasting 20 gameplay seconds and refreshing with each yellow pickup. The old damage and range orbs no longer drop.

Orbs within **8 m** automatically fly into the hero after a short drop animation. Nearby attraction starts with clear line of sight; attracted drops keep following a moving or jumping hero. Uncollected floor orbs last 90 gameplay seconds; attracted orbs do not expire in flight. The former 48-orb discard cap is removed.

Collect **five blue ice orbs** for an automatic ice burst beside the hero, freezing enemies within **7 m for two seconds**. Frozen enemies cannot move or begin attacks, and normal hits cannot shorten the freeze. Collect **five red fire orbs** for a fire-and-smoke explosion within **7 m**, dealing **100 base damage**. Cover blocks both effects. Ice and fire have independent HUD counters, preserve leftovers, and work with either character. Mass collections retain every completed set; effects are briefly staggered for readability. Pause freezes timers, and retry resets counts and pending effects.

A floating **horseshoe magnet** appears on reachable ground shortly after starting, then every 30 seconds, with up to three active at once. The minimap marks magnets with **M**. Walk within 2.5 m to pull every existing orb across the map, including through cover. Magnets expire after 90 seconds so new ones can appear around a moving player. Sound Studio includes separate ice-burst, fire-burst and magnet slots.

New swarms use alternating sectors around the hero at **22–38 m**, with terrain-aware fallback. Pursuers have varied approach lanes and a short movement lead; they close directly for melee range. Coastlines, walls and narrow passages still constrain where enemies can spawn or approach.

Attack speed accelerates Goemon's full combo, heavy attacks, powered spin, coin throws and both legs of T Sky Strike. It also accelerates Edo's triple volleys, large fireball attacks, beam damage ticks, shield pulses, R cooldown and smoke teleport action. Projectiles fly faster with proportionally shorter lifetimes to preserve travel distance. Damage applies to every outgoing hit, including T, beam, shield and smoke. Buff duration, ordinary running/jumping and the survival clock still use normal gameplay time.

**Goemon — direct number attacks (v2.17):** the number keys now attack immediately instead of selecting a persistent weapon. **1** performs a single broad horizontal pipe swing for 48 base damage. **2** throws a normal coin, or a full-sized piercing giant coin during R. **3** performs a 140° chain-pipe fan sweep with **11 m base reach**, increased from 6.5 m, dealing 70 damage once per enemy; R keeps the flaming 110-damage sweep and increases its reach to 18.15 m before range-orb bonuses. Each action returns to the previously equipped weapon. Rapid taps queue up to eight additional number attacks, with no cooldown between animations; attack-speed orbs accelerate them. Holding a number key does not create OS-repeat attacks. E, C, T, pause, character switching and retry clear queued number attacks.

**Mouse attacks:** LMB retains the automatic three-hit pipe combo, and R changes it into the existing 360° wind spin. RMB retains the heavy strike. The robe still adds bonus coins to number attacks and mouse attacks, including the 16-coin ring on an R spin. The chain pipe's Blender asset, effects, collision checks, damage scaling and custom sound slots are preserved. Its long sweep appears only for the number-key attack, then restores the prior weapon.

**Clean combat visuals:** enemy attack-range rings, meteor target circles and the player's old charge/ground-aura circles are removed. Actual weapon trails, fire, smoke and shield effects remain visible; the hit areas themselves are unchanged.

**Edo:** a fixed fireball moveset, with no weapon switching. Tap LMB for three fireballs in a fan; hold it to repeat volleys. RMB immediately throws one larger explosive fireball (96 base damage, 3.8 m splash radius). Attack-speed boosts shorten both casts and accelerate projectile flight. During **R / Blue Surge**, hold LMB for the steerable shield beam. It passes through walls and every enemy in its path. Yellow attack-speed stacks lengthen it immediately: 38 / 57 / 76 / 95 / 114 m at the default base length. Release LMB to stop. R lasts seven seconds; its expiry ends the LMB beam. T now casts Meteor Rain; the beam stays on R + held LMB.

**Meteor Rain (T):** Edo plants his feet, raises his right arm overhead and drives it downward. The strike summons a random **4–12 falling fireballs**, first targeting separated nearby enemy groups within 80 m, then spreading remaining impacts across surrounding ground. Even with no enemies, the spell rains over several areas ahead. Each meteor deals **240 base damage** in a **5.5 m radius**, once per enemy per impact; overlapping meteors can hit the same enemy again. Solid cover blocks the blast. Every landing uses the same Blender-authored fire-and-smoke explosion as his E dodge. Damage and range orbs boost the blast; attack speed accelerates both the pose and rainfall. There is no cooldown: rapid T taps queue up to eight additional casts. Holding T does not auto-repeat. Dodging or taking an unshielded hit interrupts an unreleased spell; released meteors finish independently. Pause freezes falling meteors and clears uncast queued inputs; character switching and restart clear the rainfall.

**Fire dodge:** E teleports Edo to clear ground with fire-and-smoke explosions at departure and arrival. Each enemy can take 36 base damage once per dodge. Bright flame lobes expand into rising charcoal smoke. Editable Blender source: `assets/blender/vfx/Edo_Fire_Explosion.blend`; reproducible generator: `tools/build_edo_fire_explosion.py`; runtime meshes: `assets/models/vfx/edo_fire_burst.glb`.

Pausing stops held fire and beam and preserves the remaining R power; resume and press LMB again to fire. Switching characters, dodging and loss of window focus stop held attacks. Edo's 1 / 2 keys do nothing. Restart clears power-ups and transformations.

**Music settings (v2.17.1):** background music is **off by default**, including when upgrading an older settings file. Sound effects remain enabled at the existing master volume. Turn **Settings → Background music** on to play the locally supplied **TalesWeaver OST – Reminiscence**, looping through the menu and game; turn it off to stop the music immediately. The preference is saved across launches. The MP3 remains bundled at `audio/talesweaver_reminiscence.mp3` and follows the master volume when enabled.

## Attack sound priority and Goemon dash — v2.12

Player attacks have 16 reserved playback voices. Enemy attacks, reactions, impacts and footsteps cannot interrupt them. Impact sounds play at 45% of their former mix level, with at most two overlapping copies per impact type. Custom recordings retain their pitch and per-slot gain.

**Goemon E:** dash four metres toward the camera heading over 0.20 seconds, with 0.34 seconds of invulnerability and a shared 0.80-second evade cooldown. Each enemy touched takes only 4 base damage once, but is knocked strongly away; damage orbs apply. All three weapons support E, and walls stop the dash and block the shove. The heading locks for the short dash. Pause, character switching and restart cancel the dash and its protection. Two new Sound Studio slots cover the dash and shove.

## Ronin cloak — v2.16

Press **4** to wear or remove Goemon’s weathered crimson ronin cloak. A thick neck wrap, layered shoulder mantle and ankle-length body wrap cover his torso and legs, with a narrow front opening and two long scarf tails. Torn holes, frayed hems, scorched edges and old repairs retain the battle-worn look. The lower panels open and stream opposite his actual movement direction, including strafes, while the shoulders remain covered. Cloth motion settles smoothly after stopping and through jumps. The editable Blender scene includes Goemon for fitting; his original character source is unchanged. Garment source: `assets/blender/costumes/goemon_ronin_scarf.blend`; game export: `assets/models/costumes/ronin_scarf.glb`; generator: `tools/build_ronin_scarf.py`.

While Goemon wears it, normal movement, sprinting and slow walking are **3× faster**, and **Space can be pressed four times** for a quad jump. The jump dots and control hints update with the outfit. Taking it off restores normal speed and double jump; toggling in midair does not refill spent jumps. The short E dash and attack timings keep their existing behavior. The scarf works with every weapon and Golden Surge. Its selection survives character switching and retries, but only Goemon gains its effects; Edo keeps his normal movement and double jump. Cloth motion freezes on pause. The cloak now uses normal visual running cadence at the 3× travel speed, with adjusted foot contacts. Jump 1 keeps the normal lift, jump 2 performs a rising 360° vertical spin in the opposite direction to jump 3, jump 3 keeps its rising 360° spin, and jump 4 performs a forward flip around the torso. Each turn completes in 0.42 seconds during ascent. The base outfit and Edo retain their existing double jump animations.

While wearing the cloak, every pipe combo hit, heavy strike, chain throw and chain fan also launches a forward gold coin. Coin-weapon attacks gain one additional coin with a slight spread. During R, each pipe spin releases **16 coins in a full 360° ring** at contact, alongside its existing wind and melee damage. These are regular damaging projectiles (20 base damage each), affected by damage, attack-speed and range orbs and Golden Surge's coin size/speed bonuses. Walls stop them. Each attack releases its bonus once, even when it hits multiple enemies; removing the robe before contact cancels the bonus. Edo, T and E retain their existing attacks.

## Controls

| Input | Action |
|---|---|
| W / S / A / D | Forward / backpedal / left and right strafe, relative to camera |
| Ctrl, held | Slow walk |
| Mouse | Orbit the camera |
| Mouse wheel | Zoom |
| Q | Toggle Goemon / Edo |
| 1 / 2 / 3 | Goemon: wide swing / coin throw (giant during R) / long chain sweep; rapid taps queue attacks |
| 4 | Goemon: toggle Ronin cloak, granting 3× movement and quad jump |
| Space, repeated | Double jump, or quad jump with Goemon’s scarf; WASD redirects airborne jumps |
| Shift, held | Accelerate into a sprint |
| Left mouse | Goemon: three-hit combo, or R wind spin. Edo: triple fireball; hold to repeat, or hold for beam during R |
| Right mouse | Goemon: heavy pipe strike / five-coin fan. Edo: large explosive fireball |
| R | Goemon: 30-second Golden Surge moveset. Edo: 7-second Blue Surge moveset and shield |
| T | Goemon: Sky Strike leap / hit / return. Edo: Meteor Rain (tap; rapid taps queue casts) |
| F1 | Prototype Lab: pause and edit gameplay values / spawn enemies |
| C | Evade, with brief invulnerability |
| E | Goemon: short forward dash and shove. Edo: fire-and-smoke teleport |
| Tab | Toggle soft targeting assistance |
| Escape | Pause / resume |

An attack automatically equips a stowed pipe. Melee hits require range, facing, and an unobstructed line of sight. Coins are unlimited, cooldown-limited physical projectiles: quick throws deal 20 damage per coin and split throws launch five coins for 24 damage each. They fly toward the camera heading, with optional soft assistance for unobstructed enemies within a forward cone; terrain and walls stop them. Coins now use the supplied oval koban reference: a beveled gold body, raised rim, engraved bars and original seal marks. Selecting a different weapon cancels any pending attack. Enemy wind-up animations telegraph attacks; evade and punish the recovery. Defeating a ninja restores some vitality. Spirit sparks also heal you.

## Sky Strike smoke and tenfold maps

The leap still takes 0.24 seconds out and 0.19 seconds back, deals 160 base damage, and accepts rapid queued T presses without a cooldown. It now has a dedicated rising takeoff whoosh and a heavy stomp impact, using the existing volume/mixing system. Blender-authored smoke billows replace the two circular effects, expanding upward on takeoff and outward with dust at impact. Editable source: `assets/blender/vfx/Sky_Strike_Smoke.blend`; export generator: `tools/build_sky_smoke.py`.

T has no target-distance cap and searches all living enemies in the loaded area. Short leaps retain their original arcs; obstructed routes try higher arcs to clear terrain. Completely enclosed paths can still block the leap. Damage, return position, rapid input queue, pause, and character-switch cleanup are preserved.

Each map's playable area is exactly **10×** the previous release (linear dimensions multiplied by √10). Nine connected outposts add shrines, courts, paths and scenery. Survival waves replace the former preplaced encounter population. Distant actors keep pursuing beyond 100 m; their models are hidden until approach to reduce rendering cost, and they remain available to T targeting. The minimap fits the entire expanded area.

## Combat expansion

Settings includes Edo beam width / diameter (0.5–6 m) and length (5–65 m). Defaults are 2.8 m and 38 m. Settings save locally and apply to the next beam. Attack-speed stacks multiply this base length and update the active beam immediately. Activate R, then hold LMB to channel the beam; release LMB to stop.

Enemies include the original ninja plus fast wind scouts, durable iron brutes, and ranged ember casters. Defeated enemies drop one energy orb: **yellow** grants 1.5× damage, **blue** adds 50% attack speed, up to four stacks / 3×, and **red** grants 1.5× melee reach / projectile hit width. Each lasts 20 gameplay seconds; collecting the same type refreshes its timer and blue adds a stack. Different types can coexist. Drops expire after 25 seconds and clear on area travel; active buffs carry between areas and reset on restart / new game.

Edo uses a refined playable derivative with balanced feet, compact proportions and broader shoulders to fit Goemon’s style. His original face, painted outfit and hair remain recognizable; the approved Blender master is preserved.

Sound Studio now has 20 additional recording slots for Goemon’s spin, giant toss and T, every Edo spell (including the sustained beam), and all five chain-pipe sounds. Use the search box to find an attack. Custom beam recordings loop while channeling. Each slot has record, preview, save, restore and volume controls. Sound Studio accepts only one active recording. Saving atomically replaces the selected slot’s prior WAV; no take history or layered takes are created. Renaming the game to Goemon preserves the existing settings and recordings in the legacy `Godot/app_userdata/Azure Ember` directory.

## Prototype Lab

**F1**, or **Pause → Prototype Lab**, opens the paused tuning interface. Tune health, outgoing damage, pipe reach, movement, coin damage/speed/count, powered spin / giant-coin damage, Golden Surge duration, and enemy health/damage. Spawn stationary dummies or practice enemies and test either R moveset. Obsolete Goemon charge-time controls are hidden.

Tuning saves locally. Invincibility, enemy-AI freeze and healing are available for experiments. Practice enemies disappear on restart. Pausing freezes survival, power-up and transformation timers.

## Explore Tidefall

The survival map retains its coast and beach, river and waterfall, cherry trees and palms, temple buildings with open interiors, walkable bridge, cave passage, western ruins, eastern Storm Court and outer training courts. Reaching Tidefall Temple restores vitality and establishes a recovery point. Spirit sparks remain collectible during the run.

Jade Grotto, Sakura Highlands and Sunforge Citadel are retained in the source but inaccessible during survival. There are no portal markers, travel controls or guardian objectives. Restart survival starts a fresh ten-minute run on Tidefall.

Both jumps recharge on landing. The second jump performs a forward somersault rather than a horizontal spin. The second jump refreshes upward velocity and can redirect horizontal momentum with WASD. Holding Space does not repeatedly jump. A third jump is not available. Ground waves test your actual height above terrain, so jumping is a functional counter.

## Presentation and systems

- Blender-authored, skinned chibi hero with reference-led blue/gold hair, facial features, layered clothing, a golden pipe, and simplified ninja/guardian variants.
- Procedural idle, jogging, sprinting, airborne, landing, evasion, and attack poses with continuous blending, squash, anticipation, and follow-through.
- Elevated perspective camera with mouse orbit, zoom, movement anticipation, FOV response, restrained banking, five obstacle probes, and foliage fading.
- Physical terrain, sloped stair approaches, bridge deck collisions, short step handling, buffered jumps, and fall recovery.
- Three light-combo stages, heavy knockback, short hit-stop, slash arcs, damage numbers, enemy telegraphs, and four distinct area guardians, including ranged volleys and jumpable ground waves.
- Main menu, pause menu, restart, defeat and victory states; saved volume, sensitivity, display mode, and graphics settings.
- Procedurally synthesized original music and action sounds; no downloaded assets or external dependencies.

This is a stylized procedural prototype, not a finished AAA production. Traversal is grounded running, sprinting, jumping, and evading; rail grinding, loop running, and wall running are not implemented. Live animation preserves code-driven combat timing through an imported seven-bone rig; Blender sources also include 13 editable/exported animation clips. The game has no persistent campaign save; settings persist locally.

## Blender asset pipeline

The v1.3 asset edition integrates 15 editable Blender sources and matching GLBs: Goemon (blue/gold hair), ninja, four guardians, pipe, oval koban, cherry/green trees, palm, moss rock, paper lantern, torii and modular temple roof. Working controllers, hitboxes, camera, bosses, Prototype Lab and area generation are retained.

See [the Blender workflow](docs/BLENDER_PIPELINE.md) for editing/exporting and [the audit](docs/ASSET_AUDIT.md) for migration decisions. Sources are under assets/blender; game exports are under assets/models. Preserve hand edits with tools/export_blender.py; the separate initial generator deliberately rebuilds models.

Terrain, water, grass, route assembly, bridge geometry and effects remain procedural. No online content was used. Blender sources and reference images are excluded from the standalone game.

## Project

Open `project.godot` in Godot 4.6.1 and press Run. The configured main scene is `scenes/main.tscn`.

The private development repository is [eric2532/Goemon](https://github.com/eric2532/Goemon). It includes gameplay source, runtime assets, editable Blender sources, tools and validation notes. Builds, Godot caches, local backups, Blender recovery files and generated test captures are excluded from Git. The archived Musashi visual-development ZIP also stays local.

For a fresh checkout, clone the repository with an authenticated GitHub account, then open `project.godot` in Godot and allow the assets to import. To create the macOS application described above, use the `macOS` export preset; create the local `build/` directory first.

To upload future changes from this project folder:

```sh
git status
git add .
git commit -m "Describe the game update"
git push
```

Review `git status` before committing to confirm that only the intended files are included.

- `scripts/game.gd`: startup, menus, settings, audio, effects, game state, integration tests.
- `scripts/prototype_lab.gd`, `scripts/tuning.gd`: live gameplay tuning UI and persisted values.
- `scripts/surge_aura.gd`: original animated golden energy effect.
- `scripts/combat_tests.gd`: physical-input combat and tuning integration tests.
- `scripts/player.gd`: input, movement, attacks, health, traversal.
- `scripts/camera.gd`: responsive orbit, follow, zoom, collision.
- `scripts/hero_model.gd`: original model and procedural animation.
- `scripts/enemy.gd`: ninja and boss behavior.
- `scripts/world.gd`: terrain, architecture, vegetation, water, particles.
- `scripts/hud.gd`: HUD, objective, minimap, combat feedback.
- `scripts/gold_coin.gd`: original cash-coin mesh and swept projectile collision.
- `scripts/expedition_area.gd`: seeded connected maps and confined boundaries.
- `scripts/area_gate.gd`: large, always-open portals and return doors.
- `scripts/swarm_survival.gd`: countdown, growing waves, safe spawn placement and victory.
- `scripts/survival_tests.gd`: survival rules, pursuit, pause/retry, win/loss and crowd-load checks.
- `scripts/endless_encounters.gd`: retained legacy encounter support.
- `assets/vfx/fire_beam/fire_beam.gd`: Edo’s piercing fire ray, stack-based length and timed damage.
- `scripts/boss_wave.gd`: expanding jumpable boss attacks.
- `scripts/expansion_tests.gd`: gameplay and multi-area regression tests.
- `export_presets.cfg`: universal macOS release preset.

## Verification

Current chain weapon, recording, meteor and combat checks:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --chain-test
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --chain-visual
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --meteor-test
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --meteor-visual
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --firecaster-test
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --firecaster-visual
```

`tests/chain-pipe/` contains weapon/recording checks, in-game captures and the Blender asset review. `tests/meteor.log` checks the pose, targeting, damage, orb scaling, queued taps, pause and cancellation. `tests/edo-meteor/*.png` shows the casting pose, falling fireballs and explosions. `tests/firecaster.log` verifies startup music, volley repetition, large-fireball splash, stacked floor orbs, beam penetration/steering, dodge damage and effects, cleanup and Goemon regressions. `tests/edo-firecaster/*.png` shows the in-game effects and Blender preview. Earlier combat tests describe retired Edo controls.

Current survival checks:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --survival-test
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --survival-test --survival-load
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --survival-visual
```

`tests/survival.log` records the current survival integration results. `tests/survival-*.png` contains visual captures. Older expedition tests and release notes below describe previous modes; door, guardian and fixed-population assertions no longer apply to the active survival mode.


`tests/expansion.log` records weapon selection, double jumping, projectile hits and wall blocking, real door interactions, backtracking state, all guardians, generated route floors, actual traversal, map boundaries, deterministic seeds, new-seed variation, and area retries. `tests/area-visual.log` records rendered spot checks of the new maps.

`tests/expansion-regression.log` records the automated integration checks: physical movement, jump input, light/heavy attack input, pause/resume input, cave-camera obstruction, full bridge crossing, temple stair entry, equipment toggle, boss victory, and return to menu. `tests/export.log` records the release export. PNGs in `tests/` document visual inspection.

Combat update checks are recorded in `tests/combat.log`, `tests/combat-smoke.log`, and `tests/combat-expansion-regression.log`.

Developer-only test commands:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --combat-test
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --expansion-test
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --smoke-test
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --visual-test --capture-only
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release macOS 'build/Goemon.zip'
```

### Reference-accurate hero update (1.4)
The active hero now uses the user-supplied original Goemon mesh and atlas, preserving its 460 triangles and UVs. Editable source: `assets/blender/characters/kai.blend`; embedded-texture game export: `assets/models/characters/kai.glb`. Comparison: `tests/reference-comparison.png`. The original reference and attribution are retained under `assets/references/goemon_original`. See `docs/BLENDER_PIPELINE.md` for rig mapping, update/export workflow and the blue-only source limitation of the gold transformation.

### Locomotion update (1.5)
The original character mesh and texture are unchanged. The hero now uses an articulated 17-bone rig, 24 editable animations, speed/direction blending, planted-foot terrain correction and hand-bone weapon attachments. Ctrl walks; S backpedals; A/D strafe. See `docs/LOCOMOTION.md` for the audit, animation pipeline and validation. Motion review: `tests/locomotion-review.mp4`.

## Anime locomotion update — v1.6

The existing character now runs with pelvis-led twist, a counter-rotating chest, dynamic clavicles, larger arm arcs, delayed hands and stronger leg drive. The neck and head lean forward into running and sprinting while keeping the face controlled. The model and textures are unchanged. Editable source and export instructions are in `docs/LOCOMOTION.md`.

## Supplied gold hair — v1.6.1

R now swaps to the actual taller Sudden Impact hairstyle from the supplied model, with its original texture. The normal character, face, locomotion and transformation mechanics are preserved. Both editable hair variants live in `assets/blender/characters/kai.blend`.

## Supplied pipe — v1.6.2

The equipped pipe now uses the actual weapon from the supplied Goemon Outfit archive, with its original gold/silver textures. The outfit was excluded. Editable weapon source: `assets/blender/weapons/golden_pipe.blend`.

## Sound Studio — v1.7.0

Open **Settings → Sound Studio · Record sounds**. Choose your microphone and a sound slot, press **Record**, then **Stop → Listen to take → Save take**. Record up to eight seconds for swings, impacts, coin throws, jumps and other effects. Each slot has volume and Restore default controls. The first recording may ask for macOS microphone permission. Your recordings stay on this computer and persist between game sessions. See `docs/SOUND_STUDIO.md`.

## Directional body motion — v1.7.1

Sideways movement now carries a subtle directional turn and lean through the hips, shoulders and head, including smooth reversals. The shoulder stance is slightly more open through the rig. Character meshes, textures, R hair, supplied weapon and Sound Studio remain intact.

## Ready idle — v1.7.2

The idle stance now has gently bent elbows, arms held slightly away from the body, and a slow breathing cycle through the chest, head, hips and knees with planted feet.

## Compact idle arms — v1.7.3

Idle arms are about 10% shorter, with shoulders connected and full-size hands. Movement and attacks blend back to normal reach; the ready stance and breathing remain.

### v1.7.4 — relaxed compact idle
Idle arms are another 10% shorter, with a little more elbow bend, wider shoulder stance and outward clearance. Breathing and full attack reach are preserved.

### v1.8.0 — game feel
Added transient acceleration/braking/pivot and jump/landing reactions over approved locomotion, faster attack contact, local hit-stop, directional enemy recoil and camera impulses, contact sparks, and separate reaction/environment audio. Evade cancels attacks; late heavy input buffers. See `docs/GAME_FEEL.md`.

### v1.9.0 — choreographed pipe combo
One click now flows through a fast diagonal opener, wide left sweep, and loaded right power finisher. Full-body pose layers, continuous hand paths, planted feet and stronger finishing knockback/feedback preserve the approved character and pipe assets. See `docs/PIPE_COMBO.md`.

### v1.9.1 — right-side charge stance
Pipe and coin charges use a coiled stance with a bent elbow, raised free-hand guard and weapon aimed right. Bounded arm IK replaces the legacy charge rotation; hold/release/cancel blend back into existing movement.

### v1.9.2 — reference-style koban
The thrown/held coin now uses a thin, long rounded gold koban with modeled rim, engraved-looking bands and dark stamps on both sides. Editable Blender source and exported GLB are included.

## v2.1 · Controls, encounters and jumps

Q toggles characters; 1/2 select weapons for the active character. Evade is C. Regular encounters originally contained three times as many enemies (54 in Tidefall and 36 in each generated area); the tenfold-map release increases these totals to 540 and 360, with one guardian per area. Both characters jump roughly 50% higher; first and second jump launch speeds are adjustable in Prototype Lab.

## v2.2 · Edo fire beam and free exploration

Character names are Goemon and Edo. Edo’s fully charged ranged attack channels a 2.8-metre-wide fire ray for three seconds, reaching up to 38 metres in clear space. It follows his position and camera aim, stops at solid cover and deals 18 base damage every 0.2 seconds. Tap LMB still throws a normal fireball. Mouse turning steers the beam continuously. Its fire shield automatically protects Edo and burns nearby enemies throughout the channel, including while R is on cooldown. The automatic shield ends with the beam; an independently active R shield keeps its remaining duration. Switching character or weapon, evading or travelling cancels the beam.

Portals now have tall stone frames, a luminous animated interior, an overhead beacon, clear destination labels and a six-metre interaction radius. All doors remain open while regular enemies respawn indefinitely. Q switches Goemon/Edo; 1/2 remain weapon selectors; C remains evade. Character geometry is unchanged.

`tests/edo-beam/` contains new gameplay checks, rendered beam/portal captures and release validation. Run `--edo-test` for the automated feature suite or `--edo-visual` for rendered captures.

## v2.5 · Area stomp, pursuit, and smoke teleport

Goemon’s T landing hits every enemy within five metres (160 base damage each, solid cover blocks damage). The leap timing, unlimited target range, return, sounds and queued presses stay the same. Range pickups also expand the landing radius.

Enemies now pursue across the full map using a shared terrain-aware route field, including distant enemies with hidden models. Portals have a bright swirling energy surface, orbiting rim, particles and a tall cyan beacon. Press F within six metres to travel.

Edo’s LMB fireball fires without charging. Hold T in either weapon mode for an immediate beam; release T to stop. E teleports to random clear ground within 75 metres (about 100 footsteps): departure and arrival smoke deal 12 base damage within four metres, once per enemy, and Edo hops before vanishing and after reappearing. The dodge cooldown is 0.75 seconds. C remains the directional evade. Pause, character switching and map travel safely cancel abilities.

Validation: `--aoe-edo-test` runs the updated combat, teleport and cross-map pursuit checks; `--aoe-edo-visual` also captures effects and portals in `tests/aoe-pursuit-edo/`.

## v2.6 · Crowd performance and Goemon stride

The full map and enemy population are retained. Ordinary enemies use a 2,694-triangle close model; beyond the nearest 32 detailed combatants, a shared 777-triangle mesh animates on the GPU in one crowd batch. Guardians retain their original models. Enemy names appear only at close range, and distant enemies keep pursuing while their rendering is culled. Physics bodies, health, damage, drops and unlimited T targeting remain active for every enemy.

Enemy routes are cached briefly, navigation-field rebuilding is spread across frames, and grounded movement interpolates collision-checked short segments. Full collision physics still handles guardians, hit reactions and airborne enemies. This avoids hundreds of redundant ground-contact solves every frame.

Goemon's running and sprinting use shorter foot travel, lower swing clearance, an earlier heel lift and more hip clearance. Terrain foot planting, original limb lengths, player speed, combat timings and jumps are preserved.

`--performance-audit` records frame timings for the full map and a 541-enemy crowd and captures running poses. Results, Blender mesh generation logs and regression checks are in `tests/performance-legs/`.
