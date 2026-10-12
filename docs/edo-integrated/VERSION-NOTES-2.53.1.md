# v2.53.1 Edo Rogue-style Movement Preview

Edo now uses the same direction-aware stepping controller as the Rogue roster. This corrects the older forward-only marching gait and its sharp running knee/ankle bends. Sideways and backward travel guide the steps, with the roster's stride cadence, eased weight shifts, arm counter-swing, strafe turn and body bob. His legs retain the straighter, intact silhouette used by the Rogue characters. Landing briefly absorbs weight and settles back into the normal stance.

Edo's approved study 04 geometry, body proportions, face, hair, jacket, paint and skin weights are unchanged. This is an animation correction. His dynamic fireball casting remains, including the moving throwing-hand arc while his legs continue walking. Triple volley, giant fireball, meteor rain, fire dodge, Blue Surge/beam and their new shaders remain included. Combat values, abilities, collision and movement speed were not changed.

Open the app, choose Fire Siege / Beta, then **Q → Edo**. WASD moves; mouse aims; Shift sprints; Space jumps; LMB fires the triple volley; RMB fires the giant fireball; T calls meteors; E performs the fire dodge; R activates Blue Surge, then hold LMB for the piercing beam. J toggles nearest-visible-enemy auto attack. The exploration map, discoveries, shrine defense, gate, ice towers, other characters and experimental crosshair remain included.

## Verification and limits

- Godot 4.6.3.stable.official.7d41c59c4. Nine real-model gait assertions pass: lateral stepping, bounded forward swing during strafe, straight running knees, stop settling, frame-rate-independent cadence, rotated-root axes, reset/reuse, landing drop and recovery.
- All 19 Edo integration assertions pass in source and the actual exported native executable, including moving-cast hand arc/active legs and the previous attack/spell preservation checks.
- Relevant exported-pack regression suites pass: gait, Fire Siege controls, native range, roster ink brush, shrine gate, crosshair, ten-wave campaign, auto lock, defense state, structures and ice towers.
- Shared-lighting front/side comparisons use real Edo and Explorer game assets at four stepping phases. The actual gameplay tour exercises Edo, Explorer and Ninja walking, turning, running, jumping/landing, attacking while moving and stopping. Preview videos represent deterministic simulation and cannot measure FPS.
- The older Fire Siege motion suite reports 95 assertions with one failure: its Magic Swordsman wave expectation remains 79 damage while the existing long-range wave uses 100. Exit code, summary and error message match the untouched v2.53.0 pack exactly. No Magic Swordsman combat code changed. The older v2.53.0 release also documents nine firecaster and one meteor expectation failures; this animation patch does not repair those unrelated legacy tests.
- Existing headless teardown ObjectDB/resource/DummyShader diagnostics are kept in the evidence. They are not hidden as gameplay or shader failures.
- Independent review found no Critical or Important code issues. Review requested additional rotated-root/reset/moving-cast coverage; all four added assertions pass. Final aesthetic acceptance belongs to the user.
- Approved Edo model/source/paint hashes, original master hashes and all 16 protected other-character hashes are preserved. The earlier playable build and main game checkout are preserved.
- FPS benchmarking and full-session playtesting remain deferred at the user's request. Geometry and VFX counts are unchanged; no stable-60-FPS claim.

Run `Godot --headless --path . --script scripts/edo_gait_tests.gd` for gait checks, `Godot --headless --fixed-fps 60 --path . -- --edo-redesign-test` for ability checks, or `Godot --fixed-fps 60 --path . -- --edo-gait-tour` for gameplay captures. Export the Fire Siege Crosshair macOS preset. This is a separate local preview, not a GitHub publication.
