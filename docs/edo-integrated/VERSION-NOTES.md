# v2.53.0 Edo and Spell Shaders Crosshair Preview

The user-approved study 04 Edo is now playable: the red flame jacket, painted confident face, fuller temple hair and compact body proportions are retained. The approved study and original character masters are preserved. A separate editable Blender derivative adds 16 gameplay joints with normalized skin weights; the runtime asset uses one mesh, one material and a 2048-pixel paint atlas.

Fireball casts have a wind-up, shoulder and chest twist, articulated throwing arm and wrist, support-arm counterbalance, grounded knee/foot weight shift, release and recovery. The extension coincides with the existing projectile-release time. Moving and airborne casts retain locomotion. Meteor casts retain the overhead raise, ground strike and crouched recovery; the beam uses a braced stance and shoulder recoil.

Triple fireballs, giant fireball, meteor rain, fire dodge, Blue Surge and its piercing beam keep their existing combat rules. Fireballs and meteor cores use flowing ink-flame shaders; explosion flame and smoke meshes use painted, fading shader materials; the beam has animated bristles and hot veins; Blue Surge has a blue flowing ink rim. Effect clocks pause with the game. Existing spark, lobe and beam-ring counts are retained, and emission honors Reduced Flashes. The beam source follows the right hand while the original damage volume remains unchanged.

## Try Edo

Open the macOS app, choose Fire Siege / Beta, press **Q** and choose **Edo**. WASD moves; mouse aims; LMB fires the triple volley; RMB fires the giant fireball; T calls meteor rain; E performs the fire dodge; R activates Blue Surge, then hold LMB for the piercing beam. Space jumps; Shift sprints; C evades; J toggles nearest-visible-enemy auto attack; Esc opens pause/settings.

The expanded exploration map, discoveries, shrine defense, buildable gate, ice-tower upgrades, other characters and experimental crosshair remain included. Ranger's spread and curved shots are retained. This is a separate preview; the previous delivered game and main checkout are preserved.

## Verification and limits

- Godot 4.6.3.stable.official.7d41c59c4. Source and actual exported app pass all 17 Edo integration assertions covering skin joints, whole-body casting motion, projectile count/damage/spread, spell shaders, effect lifetime, pause cancellation and hero switching.
- The final exported pack passes 11 relevant regression suites: roster ink brush, AttackChain, Fire Siege controls, native range, shrine gate, crosshair, ten-wave campaign, auto lock, defense state, structures and ice towers. These contain 1,359 counted assertions plus AttackChain's zero-failure result.
- Actual native Metal Forward+ rendering completed the 18-view capture tour. Model front/side/back, casting poses, fireball effects and Blue Surge were visually inspected. A close camera facing into the beam can still have Edo obscured by its bright effect; this is a minor visual limitation.
- Legacy firecaster and meteor suites still have 9 and 1 failures respectively. Their exit codes, result summaries and assertion messages match the untouched v2.52.0 pack exactly. These existing expectation failures were recorded instead of changing combat values to satisfy them.
- Accelerated headless shutdown retains existing ObjectDB/resources-at-exit or DummyShader diagnostics. These are recorded separately from gameplay or shader errors. No script/shader errors appeared in the native visual tour.
- Independent review found no critical or important issues. Original approved-study/master hashes and all 16 protected character model hashes match, and the main checkout is clean.
- FPS benchmarking and full-session playtesting remain deferred at the user's request. No stable-60-FPS claim. Fixed-step functional tests do not measure rendering performance. The approved geometry has 95,548 triangles; its visual fidelity was preserved, and performance is unmeasured.

## Reproduce

Run Blender in background with `--python tools/build_edo_approved.py` to build from the packed study 04 source. Run Godot with `--headless --fixed-fps 60 -- --edo-redesign-test` for integration checks or `--fixed-fps 60 -- --edo-redesign-tour` for deterministic visual captures. Export the **Fire Siege Crosshair macOS** preset. Source and exported runtime suites use the same user-argument entry points.

This preview is a local build, not a GitHub publication.
