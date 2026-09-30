# Edo playable character · v2.2

The approved second character is named Edo. Historical asset paths and class names retain `musashi` to preserve existing references. The same Hero instance owns movement, collision, health, jumps, evasion, camera following and world interactions for both characters. Switching never reloads the level or respawns enemies.

## Controls

- **Q:** toggle Goemon / Edo. Key-repeat is ignored; one press performs one switch.
- **1/2:** Goemon pipe / coins; Edo fists / fireballs. Goemon mouse attacks, charge timing, E equip/stow, R Golden Surge and damage values are unchanged.
- Edo: **LMB** left punch; click again during the stroke for right punch, then again for the left finisher. Each click queues at most one successor. One click stops after one punch.
- **RMB hold/release:** right hook. Quick release, 0.35-second short charge, and 1.05-second full charge. Holding never auto-fires.
- **2 + LMB:** throw a normal fireball immediately, without charging. **Hold T:** channel a continuous beam in either weapon mode; release T to stop. The beam follows camera aim and solid cover stops it. RMB remains the hook.
- **E:** disappear in damaging smoke and reappear on random safe ground within 75 metres. Departure and arrival smoke each cover four metres and deal 12 damage, at most once per enemy per teleport; a short hop accompanies the smoke. C remains a directional evade.
- **R:** seven-second fire shield. Invulnerable while active; 10 damage every 0.6 seconds in a 2.3m radius. Fourteen-second cooldown starts at activation. Shield cannot stack or refresh itself.
- Existing WASD, Ctrl walk, Shift sprint, higher double jump, C evade, mouse camera, zoom, Tab assist and F doors are shared.

The HUD shows the selected character, mode, charge and shield status. Switching cancels abilities and removes Edo’s in-flight projectiles; returning starts in a valid idle state. Evade cancels an unfinished strike or charge. Pause/lab/menu/travel cleanup cancels Edo abilities. Cooldown advances while Edo is active and gameplay is running. New expeditions clear it. Shared HP remains unchanged when switching.

## Architecture

`Hero.ROSTER` registers visual adapters and optional ability components. `active_ability` receives input, simulation ticks, hit reactions, dodge interruption, damage-protection checks and cancellation. Goemon retains its existing controller combat branch and `HeroLocomotion` implementation. Additional entries implement this adapter contract and provide a compatible model; they do not duplicate movement or health.

Edo’s combat state machine is in `assets/characters/musashi/combat/musashi_combat.gd`. Configurable damage, charge thresholds, ranges, durations, projectile speed, shield tick and knockback live in `combat/default_balance.tres` / `balance.gd`, editable in Godot's Inspector. Global Prototype Lab damage and enemy tuning still apply.

`animations/motion.gd` layers dedicated fists/guard/charge/throw poses over locomotion. It drives hips, chest, head, upper arms, forearms, legs and feet, with interpolated anticipation, contact, follow-through and recovery. This is procedural runtime animation, not a reuse of the pipe swing with its mesh hidden. The Blender file contains the editable skin and neutral clip; combat choreography is edited in the motion script.

Fireball, beam and shield are reusable scenes under `assets/vfx`. Fireball subclasses `GoldCoin` to retain the established segment sweep, wall occlusion, victim radius and hit-once behavior. Quick fireballs retain orange fire and trailing embers. Holding T creates `EdoFireBeam`: a default 38m maximum length, 1.4m radius, continuous channel with 18 base damage every 0.2 seconds. Nine radial wall probes truncate its visible length, while target line-of-sight checks protect enemies behind cover. Beam damage is scheduled independently of frame rate, and the effect owns its looping audio. Damage and hit feedback use existing enemy `take_hit` / game `confirm_impact`. Shield checks line of sight and applies scheduled ticks independently of frame rate. Flame audio is locally synthesized and the shield loop is owned by its effect node.

## Approved asset preservation

The immutable visual master remains `assets/blender/enemies/musashi/Final/Musashi_Final.blend`.
SHA-256: `3542e31714cc4571e076f5b99b0dc81eb7cdbd859cf9d38393102f2b14d2004c`.

The separate `Musashi_Playable.blend` holds a 16-bone rig and the complete approved 46,177-vertex / 90,160-triangle surface. The derivative joins surface objects into one draw surface, creates a UV atlas and bakes the approved shader base colors to 4096×4096. No source vertices are removed or redesigned. Uniform 0.30 scaling and a 180-degree forward conversion match the game's units. The original asymmetric stance is retained in the bind pose. Image-left/right source labels become anatomical left/right rig labels. Facial graphics and hair move rigidly with the head; sleeve prints share sleeve weighting.

Game export: `assets/characters/musashi/model/musashi.glb`. Painted atlas: `assets/characters/musashi/materials/musashi_painted.png`. The engine supplies dynamic lighting, so game-lit colors will differ from the reference studio render. The dense approved mesh is retained; a mobile LOD/retopology pass has not been performed.

Rebuild derivative from the approved master (replaces the derivative, never the master):

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b -t 6 --python tools/build_musashi_playable.py
```

For hand-edited rig exports, use `tools/export_blender.py` on `Musashi_Playable.blend`. It routes this derivative to the correct game path and skips the locked visual master and archive files.

## Validation

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --musashi-test
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --musashi-visual
```

Logs and rendered captures are in `tests/musashi`. Tests exercise physical Q input switching, movement, jumps, evade, one/two/three punches, interruption, each hook stage and multiple targets, exact fireball damage and sustained beam hits, wall collision, enemy death, shield immunity/expiration/ticks at 20 and 120 updates per second, incompatible charges and switch cleanup. Existing Goemon combat and pipe choreography regression suites are also run unchanged with their physical input bindings updated.

The exported macOS release is tested separately. Its headless renderer reports a `RendererDummy::DummyShader` allocation at shutdown; the previous standalone build produces the same message. Normal rendered gameplay is checked separately. The Musashi test harness waits for physics frames so first-launch shader compilation cannot prematurely end a charge test.

## v2.1 encounter and jump changes

Every existing regular encounter receives two separated companions. Original encounter IDs and boss counts remain intact; added enemies participate in the existing area save/revisit system. Companion placement checks terrain elevation, spacing, bounds and static collision. Tidefall has 36 regular enemies; generated areas have 27 each, plus their original guardian.

Shared launch speeds are 15.55 m/s and 14.45 m/s (first / second jump), about 50% more height at unchanged gravity. Both are exposed in Prototype Lab. `--controls-test` verifies weapon keys, Q toggle/repeat prevention, C evade, measured jump heights for both characters, counts/placement/persistence in all four areas.

## Endless encounters and open doors · v2.2

`EndlessEncounters` recycles one slot per regular encounter after a six-second delay. Capsule overlap, terrain, bounds, player distance and door clearance checks keep replacements on safe ground. Fixed slot IDs and pruning freed enemies prevent the live population or saved encounter map from growing indefinitely. Bosses and practice spawns are excluded. Pausing and travel suspend spawning.

Every forward and return door is always open; guardian progress no longer gates travel. The large portals include an animated cyan interior, beacon, labels and a six-metre interaction radius. The HUD supplies a camera-relative direction marker. Travel immediately cancels Edo’s beam.

Run `--edo-test` or `--edo-visual` to validate beam duration, follow/aim, thickness, wall cover, cancellation, tick scheduling, normal fireballs, all six forward/backtracking transitions without boss kills, repeated safe respawns, population bounds and pause/resume behavior. Logs and captures are under `tests/edo-beam/`.

The beam follows horizontal mouse movement while T is held. An automatic fire shield provides damage immunity and nearby burn ticks for the entire channel, without consuming or resetting the separate R cooldown. It uses one shared visual effect and preserves any remaining manual R shield when the beam ends.

Current v2.5 controls and smoke/pursuit regression checks are covered by `--aoe-edo-test` and `--aoe-edo-visual`. Older beam/weapon-toggle suites describe superseded controls. Beam duration is now controlled by the held T key; width and length remain in Settings.
