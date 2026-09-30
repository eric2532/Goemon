# Verification — 2026-09-19

Environment: Godot 4.6.1, macOS 26.3.1, Apple M3, native Metal Forward+.

## Automated gameplay integration

PASS, with no script errors or resource-leak warnings in the final run:

- Physical camera-relative movement: more than 9 metres in one second.
- Jump delivered through Godot's input event pipeline.
- Light and heavy attack events damage / defeat an enemy.
- Pause and resume through input events.
- Cave obstruction pulls the camera closer.
- Full vermilion bridge crossing (x=10 to x=41.6).
- Temple stairs and interior entry (z=-21 to z=-40.5).
- Equipment toggle through input.
- Boss death triggers the victory state.
- Restart clears transient dodge state, restores health, and resets kills.
- Return to main menu and clean shutdown.

See `smoke.log` for the final output. Smoke tests run using the Godot editor/debug engine so assertions are enabled.

## Standalone app interaction

The exported, signed universal macOS application was launched through macOS Launch Services. Using the app's actual UI:

- Reached the main menu and clicked Play.
- Sent movement, jump, evade, and pause keys.
- Opened Settings and changed volume and sensitivity.
- Switched Performance / High graphics and visibly confirmed shadow changes.
- Switched fullscreen on, then returned to windowed mode.
- Returned to pause and exercised restart.
- Used actual left/right mouse clicks to defeat two ninjas; the HUD showed two defeated enemies.
- Quit through the pause menu; the application exited normally.

The restart inspection identified a retained dodge timer; it was fixed and covered by the subsequent automated test. Temple roofs also received two-sided collision for interior camera obstruction.

## Visual and export checks

- Rendered and inspected main-menu and gameplay screenshots.
- Captured 60 FPS at the default 1280×800 window on this M3 during the visual test. This is a spot measurement, not a benchmark guarantee for all hardware or scenes.
- Universal macOS release export completed using the locally installed templates.
- Bundle signature verified using `codesign --verify --deep --strict`.
- All models, environment geometry, effects, music, and sounds are original procedural content. No web search, downloads, or online assets were used.

# Four-area expansion — 2026-09-20

New automated suite: `tests/expansion.log` (`--expansion-test`).

Verified:

- Actual physical 1 and 2 key events select the pipe and visible coin weapon.
- Two Space presses produce an airborne second jump, with redirected horizontal momentum.
- A third Space press cannot add another jump; landing restores both jumps.
- Travelling coin projectiles hit enemies, inflict the expected light/heavy damage, and are stopped by solid walls.
- F cannot enter a boss-sealed exit; defeating the guardian unlocks it.
- Actual F input transitions to every generated area and back through return doors.
- Backtracking preserves a generated layout, surviving enemy health, defeated guardians, and collected sparks.
- All generated route samples have physical floor collision, and the character physically traverses the entrance route in all three new areas.
- Each generated area's boundary stops collision probes.
- Hisui's crystal volley damages the player; Hanami's wave hits grounded players and can be avoided with the double jump.
- All four guardians are required for expedition completion.
- Repeating a seed reproduces a layout; changing a seed changes it.
- Area retry resets only the current area, and pause/resume still work.

The original movement/combat/bridge/cave/temple regression suite also passes (`tests/expansion-regression.log`). The new areas were rendered and inspected in `area-1.png`, `area-2.png`, and `area-3.png`; the captured spot measurements were approximately 60 FPS on the local M3, not a guarantee for every scene or device.

The universal macOS v1.1 application was launched and tested through its actual UI: Play, key 2, coin attacks, key 1, two Space presses, lateral movement, pause, and Quit. The rebuilt application includes all content and requires no editor or terminal to play.

# Combat Lab update — 2026-09-20 / v1.2.0

Automated suites pass:
- `combat.log`: single physical mouse click yields exactly 22 + 22 + 30 damage; alternating left/right/left poses; hold does not attack before release; 360° charge hits front and back once; right-click produces five separated fan projectiles; giant coin damages successive off-axis enemies once and stops at walls; R produces golden hair and larger/faster projectiles with extended real melee reach; retrigger cannot extend duration; expiry restores appearance; front flip rotates around X while steering and restores its pivot; tunable coin count/damage/HP; lab pause/cancel behavior; safe practice spawning; invincibility; saved settings.
- `combat-expansion-regression.log`: four-area progression, real F door interactions, all boss mechanics, generated routes and boundaries, backtracking, seed variation, and area retry.
- `combat-smoke.log`: movement, jump, automatic combo, separate heavy hit, pause/resume, camera collision, bridge traversal, temple entry, equipment, boss victory, restart, and menu.
- `combat-visual.log`: native Metal rendering; golden hair/aura and Prototype Lab screenshots inspected. Fixed underlying HUD overlap and numeric controls rounding the displayed defaults.

Standalone universal macOS v1.2.0 export completed and bundle signature verified. Through the exported application's actual interface: Play, F1, spawn five stationary dummies, resume, R, weapon keys 1/2, left/right clicks, two Space presses, Escape, pause-to-Lab button, edit damage multiplier to 1.5, restore defaults, return to pause, and Quit. The application exited normally. Final user tuning was restored to defaults.

No internet assets, external downloads, or web search were used.

# Blender asset migration — 2026-09-21 / v1.3.0

Audited the procedural asset construction and controller/visual/collision dependencies before editing. Source backup: backups/pre-blender-migration.tgz. First Blender iteration is archived separately; active asset folders contain no obsolete .blend1 copies.

15 Blender source files and corresponding GLBs are integrated:
Kai with blue/gold hair, ninja, four guardian variants, golden pipe, oval koban, cherry tree, green tree, palm, moss rock, paper lantern, torii, modular temple roof.

Validation:
- Blender 5.2.2 LTS authored and saved all sources locally. The separate normal exporter reopened and exported all 15 saved files successfully; it does not regenerate geometry.
- Game imports the seven-bone character rig, skinned meshes, named hair variants and 13 distinct editable animation clips. Gameplay continues to use the established pose/timing system via the rig adapter.
- Godot studio images inspect hero and gold variants from front, back, both sides and three-quarter; all enemies/guardians, weapons and environmental modules were also rendered and inspected.
- Iterated on flat side/rear hair, heavy smile, masked-face clipping, footwear, vest back, and a rock source pivot error. Verified corrected exports in Godot.
- tests/blender-visual.log: imported skeleton/clip checks pass, with actual gameplay, attack and charge images.
- tests/blender-combat.log: automatic combo, charged area attacks, split/piercing coins, transformation, front flip and tuning tests pass.
- tests/blender-smoke.log: movement, jump, heavy attack, pause, camera obstruction, bridge crossing, temple entry, boss victory, equipment and restart pass.
- tests/blender-expansion.log: full multi-area progression and encounter regression suite passes.
- tests/blender-areas.log: all three generated areas rendered with new modules; corrected ground-level rocks verified after re-export.
- Native Metal app exported as universal macOS 1.3.0; codesign --verify --deep --strict passes.
- Actual standalone UI exercised: Play, imported hero/golden form, weapon inputs, retry, Escape pause, F1 Prototype Lab and normal Quit. Native window captures initially showed stale startup/game frames; reconnecting/refreshing the live window revealed the current UI. Verbose runtime log reports no script or resource errors. Existing saved tuning values were preserved.

No external assets, web search or downloads were used. Models use embedded vertex colors, few PBR surfaces and UVs; editable source/reference assets are excluded from release. Current counts are in assets/models/manifest.json (hero ~17k triangles including both hair variants; ninjas/guardians ~9.7k; koban ~2.9k). These are prototype art assets, not a claim of production AAA character quality.

## v1.4 — supplied original character (2026-09-21)

- `reference-geometry.log`: all 460 supplied original triangles and UV corners match the Blender mesh after uniform scale/orientation, tolerance 0.00001. Complete rigid weights, seven bones, thirteen editable clips verified.
- `reference-visual.log`: imported skeleton, both switchable hair meshes, 13 animation clips and original-model pipe reach pass. Inspected source front/back/left/right, perspective reference render, Godot T pose and gameplay/attack/transformation captures.
- `reference-comparison.png`: authoritative screenshot, Blender reference-camera render, and actual Godot import. Camera framing iterated before saving. Geometry was not redesigned to compensate for lighting or projection differences.
- `reference-combat.log` and `reference-exported-combat.log`: combat suite reports zero failures for both project and standalone app, including three-hit chains, split/charged coins, surge, double jump/front flip and Prototype Lab. Existing saved tuning restored by test suite.
- `reference-smoke.log` and `reference-exported-smoke.log`: movement, jump, light/heavy hit flow, pause/resume, cave camera collision, boss victory, menu/restart, bridge and temple traversal passed. Exported smoke run used the actual macOS app executable with Metal rendering.
- `reference-desktop-export.log`: macOS 1.4.0 universal build exported successfully. `codesign --verify --deep --strict` passes. App bundle is at `build/Azure Ember.app`, portable archive at `build/Azure Ember.zip`.
- Normal app launch completed without startup/script errors. Native capture tooling returned stale frames during some UI checks; those frames were not used as evidence for menu actions. Exported automated input/state tests above verify the launch/gameplay/pause/menu paths independently.
- Known source limitation: archive supplies only normal blue hair/face. R uses identical original hair geometry in gold, without claiming an exact match to the separate gold/angry reference.

## v1.5 — rig and locomotion only (2026-09-21)

- Audit: seven rigid limb/head bones, no knees/elbows/ankles, flat hierarchy and time-only sine posing bypassed the imported animations. Mesh scale/root motion were not responsible.
- `locomotion-export.log` / `locomotion-preservation.log`: original 460 triangles and UV corners preserved; original PNG and Blender-packed atlas byte-identical. All skin weights normalized. Corrected source has 17 articulated bones and 24 actions. No geometry/material/texture redesign.
- `locomotion-test.log`: final rendered coastal-level test reports zero failures, including the normal collision-aware gameplay-camera pass. Checked forward walk/run/sprint, backward, both strafes, reversals, turning, jumping/falling/landing, slope contacts, stop settling and blocked movement. Bent elbows, fixed bone lengths, in-place root and animated hand attachment pass.
- `locomotion-metrics.json`: sampled final rendered pass maximum support reach residual ~0.000234 m, zero anchor drift and maximum segment-length residual ~0.000000209 m. These are sampled validation results, not a promise for arbitrary geometry or extreme tuning values.
- `locomotion-review.mp4`: actual runtime captures with original capture timing preserved. Includes three-quarter inspection and normal gameplay-camera views; not a performance benchmark. `locomotion-gameplay-contact-sheet.png` provides selected frames.
- `locomotion-headless.log`: movement regression pass. `locomotion-combat.log`: zero combat failures, including original combos/charged attacks/coins/surge/front flip/lab. `locomotion-smoke.log`: movement/jump/light/heavy, pause/resume, camera cave collision, boss victory, bridge/temple traversal, menu and restart pass.
- `locomotion-desktop-export.log`: macOS 1.5.0 universal export completed. App code signature passes strict/deep verification. The actual standalone app's `locomotion-exported-test.log` and `locomotion-exported-combat.log` both report zero failures.
- `tests/.gdignore` keeps QA captures out of Godot's asset import scan; test scripts remain in `scripts/` and export exclusions still omit raw QA artifacts.
- Current runnable build: `build/Azure Ember.app`; portable archive: `build/Azure Ember.zip`. Rig/pipeline notes: `docs/LOCOMOTION.md`.

## v1.6 — full-body anime motion (2026-09-21)

- Original mesh, UVs and packed/reference atlas remain unchanged: `anime-authoring.log` verifies all 460 original triangles/UV corners, normalized weights, 22 bones and 24 actions.
- Added middle spine, chest, clavicles and neck to the existing rig. Pelvis-led key poses propagate into counter-rotating chest, delayed shoulders/elbows/wrists, asymmetric arm swings and stronger leg recovery. Neck follows 68% of chest lean; head follows 48% (roughly 7° run, 10° sprint), retaining subtle counter-motion.
- Source side/three-quarter poses and rendered coastal gameplay sequences inspected. `anime-neck-review.jpg` shows idle/run/sprint head/neck posture; `anime-final-gameplay.jpg` shows actual gameplay-camera poses. `locomotion-review.mp4` contains the latest runtime captures with their capture timing preserved.
- `anime-locomotion.log` and `anime-visual.log`: zero failures. Checks include torso/clavicle/neck participation, chest/pelvis counter-rotation, more than 28° chest yaw range, fixed limb lengths, stance anchors, hand attachment, slope contact, backward/strafe/turning, jump/landing, stops and blocked movement. Toe-roll target prediction fixes the larger backward-stride reach issue.
- Final rendered pass: maximum sampled supporting-foot target residual 0.000000477 m, zero anchor drift, maximum limb-length residual 0.000000358 m. These sampled metrics do not establish correctness on arbitrary terrain or extreme tuning values.
- `anime-combat.log`: original combat regression suite reports zero failures.
- `anime-desktop-export.log`: universal macOS 1.6.0 exported; strict/deep code signature verification passes. Runnable application remains `build/Azure Ember.app`.
- Standalone `anime-exported-locomotion.log` and `anime-exported-combat.log` report zero test failures. Rendered Metal `anime-exported-smoke.log` passes movement, jumping, light/heavy combat, pause/resume, camera collision, boss victory, menu, bridge/temple traversal, equipment and restart, without script/resource errors.
- The exported headless tests still emit the pre-existing Godot DummyShader RID shutdown warning (also present in v1.5 logs). It does not occur in the rendered Metal smoke run; no unrelated renderer changes were made.

## v1.6.1 — supplied Sudden Impact gold hair

- `supplied-gold-import.log`: imported only three connected hair islands from the actual supplied OBJ. Existing 22-bone skeleton and 24 actions preserved; normal 460-triangle character, UVs and packed atlas verified unchanged.
- `supplied-gold-preservation.log`: all 190 original gold-hair triangles and UV corners match within 0.00001; original gold atlas is byte-identical in the textures folder and packed Blender source. All 110 hair vertices bind to Head.
- `supplied-gold-source-review.jpg`: front, back, both sides, three-quarter and sprint pose inspected in Blender. `supplied-gold-in-game.png` and `supplied-gold-gameplay.png`: imported material, scalp fit, distinct tall silhouette and actual R/aura gameplay view inspected. The base face remains unchanged.
- `supplied-gold-visual.log`: zero validation failures; original 24 clips, 22 bones, separate hair visibility, supplied triangle count, taller gold silhouette and hand attachment verified in the rendered game.
- `supplied-gold-export.log`: universal macOS 1.6.1 exported to `build/Azure Ember.app` / `.zip`. Original hair source lives in the existing `assets/blender/characters/kai.blend`; current export is `assets/models/characters/kai.glb`.
- Strict/deep macOS code signature verification passes. Standalone `supplied-gold-exported-combat.log` and `supplied-gold-exported-locomotion.log` both report zero failures, including R activation, timer non-extension, expiry/restoration, combat bonuses and existing locomotion/attachment checks. The previously documented headless DummyShader shutdown warning remains unrelated to this asset change.

## v1.6.2 — supplied Goemon pipe only

- `supplied-pipe-preservation.log`: saved Blender source has exactly one weapon mesh, no outfit/body/head or armature; original 910 vertices / 1,368 triangles and UVs preserved under rigid reorientation and uniform scale. All four packed 512px texture maps are byte-identical to the supplied archive.
- `supplied-pipe-source.png`, `supplied-pipe-godot.png`, `supplied-pipe-equipped.png`, `supplied-pipe-attack.png`: inspected source render, Godot material/open bowl, grip placement and actual gameplay attack. Imported custom normals are transformed with the mesh. Existing 22-bone character, 24 animations and supplied R hair remain unchanged.
- `supplied-pipe-visual.log`: rendered integration suite reports zero failures; hand attachment and current hero/gold-hair checks pass.
- `supplied-pipe-export.log`: universal macOS 1.6.2 exported. Strict/deep code signature verification passes. Editable source is `assets/blender/weapons/golden_pipe.blend`; game-ready model remains `assets/models/weapons/golden_pipe.glb`.
- `supplied-pipe-exported-combat.log` and `supplied-pipe-exported-locomotion.log`: standalone suites report zero failures, including three-hit combo, charged sweep, weapon switching, R effects, original locomotion and animated hand attachment. The pre-existing exported-headless DummyShader shutdown warning is unchanged.

## v1.7.0 — microphone Sound Studio

- Main-menu and paused Settings link to the new recording page. Device enumeration detects Default, external microphone and built-in MacBook Air microphone. UI inspected at the normal app resolution.
- `sound-studio-exported-test.log`: rendered Metal standalone suite reports zero failures. Generated audio passes through the actual muted capture bus (48 kHz, 40,960 mixed frames, zero discarded frames), creates a trimmed PCM WAV and persists/reloads without loss. Custom throw playback uses the saved stream at original pitch; restore-default and pause/menu teardown pass.
- Tests intentionally use generated audio; no private microphone audio was recorded. Physical speech capture and the user's first permission prompt have not been manually exercised.
- Caught and fixed missing microphone usage-description export key and an undersized capture buffer during standalone validation. Final Info.plist includes NSMicrophoneUsageDescription and signature entitlements include com.apple.security.device.audio-input.
- `sound-studio-combat.log`: original combat regression suite reports zero failures. Existing defaults, including separate light/heavy coin impacts, remain intact.
- `sound-studio-export.log`: universal macOS 1.7.0 app and ZIP exported. Recordings/config are stored in user data, outside the app bundle.
- Final code signature passes strict/deep verification. `sound-studio-smoke.log`: rendered standalone launch/gameplay, movement/jump/combat, pause/resume, camera obstruction, boss, traversal, menu/restart checks all pass without script/resource errors.

## v1.7.1 — directional shoulders/head

- `directional-authoring.log`: source rig/clip update preserves all original normal-character triangles/UVs/atlas and all supplied gold-hair triangles/UVs/atlas. 22 bones and 24 actions retained. Supplied pipe and Sound Studio are untouched.
- Shoulder poses open 0.025 m per side without editing mesh coordinates. Strafe arms retain forward/back flow. Actual local velocity drives smoothed pelvis/spine/chest/neck steering after head stabilization, so the upper body participates in sideways movement, reversals and air steering.
- Tests now check a modest shoulder-width increase and signed head turns toward each strafe direction, alongside existing foot contacts, fixed limb lengths, jumps, turns and hand attachment. A longer reversal exposed a reach limit; increasing the temporary support-crouch allowance to 0.28 m resolves it without changing limb lengths or sliding anchors.
- `directional-combat.log`: standalone combat regression reports zero failures.
- `directional-export.log`: macOS 1.7.1 app/ZIP exported; strict/deep signature verification passes. `tests/locomotion-review.mp4` is refreshed with the final rendered locomotion pass, including both strafes through the normal gameplay camera.
- Final `directional-visual.log` reports zero failures with both gameplay-camera strafe directions inspected. Existing source mesh/atlas verification and supplied gold hair checks pass. The final movement preview uses this post-fix capture sequence.
- Final standalone `directional-exported-test.log`: zero locomotion failures, including shoulder width, head steering, fixed limb lengths and weapon attachment. Final rendered maximum supporting-foot target residual was 0.000000477 m. The previously documented exported-headless DummyShader shutdown warning persists independently of these animation changes.

## v1.7.2 — energetic breathing idle

- `idle-authoring.log`: original normal-character and supplied gold-hair geometry, UVs and packed atlases remain verified; 22 bones / 24 actions preserved. Only Idle pose/motion changed in the authoring tool.
- Idle elbows are gently bent (runtime minimum ~28°); arms have ~0.137 m lateral hand-to-shoulder clearance. A full cycle measures ~0.027 m pelvis rise/fall, ~0.044 m head rise/fall and ~9° knee bend variation, with planted support anchors.
- `idle-test.log` and `idle-visual.log`: zero failures for complete breathing cycle, arm clearance, idle→walk/run transitions, strafe/turning, jumps/landing, slopes, foot contact and hand attachment. Source three-quarter pose and actual inspection/gameplay-camera cycles visually inspected.
- `idle-preview.mp4` is a short runtime idle preview; `locomotion-review.mp4` includes the complete movement regression and a full idle cycle through the normal gameplay camera.
- `idle-export.log`: universal macOS 1.7.2 app/ZIP exported. Existing character design, supplied pipe/R hair and Sound Studio preserved.
- Strict/deep app signature passes. Final standalone `idle-exported-test.log` and `idle-combat.log` both report zero failures.

## v1.7.3 — shorter idle arms, full action reach

- `idle-arms-authoring.log`: original mesh/UV/atlas and supplied gold-hair preservation checks pass. Idle limb segments are posed at 90% scale/length, shoulder origins remain anchored and global hand size remains one. Other authored motion retains full length.
- Corrected rotated-bone export shear by using uniform limb-segment scales with compensated full-size hand transforms. Runtime reach transitions advance on physics updates, independent of rendering speed.
- New runtime checks measure upper/lower segment ratios for both arms, verify hand scale, and check full reach during a stationary combo plus return to compact idle after the complete three-hit sequence. Existing breathing, shoulder width, foot contacts, directional head response and attachment checks remain enabled.
- Godot close-up idle/weapon attachment and rendered idle→attack→idle transitions inspected. Existing character mesh, textures, supplied pipe/gold hair, Sound Studio and combat hit timing/range are preserved.
- `idle-arms-export.log`: universal macOS 1.7.3 app/ZIP exported.
- Final `idle-arms-visual.log`, `idle-arms-exported-test.log` and `idle-arms-combat.log` all report zero failures. Strict/deep application signature verification passes. `idle-arm-preview.mp4` shows the compact breathing stance and transition into the full-reach combo.

## v1.7.4 compact natural idle

- Blender source verification passed: original 460 body/normal-hair triangles and UVs, packed atlas, and 190 supplied gold-hair triangles preserved. Export/import completed.
- Rendered asset and actual coastal gameplay inspection completed; `compact-idle-review.png` shows both inspection and normal gameplay framing. `idle-arm-preview.mp4` contains the idle/attack transition.
- Rendered locomotion suite: zero failures, 525 captured frames. Arm ratios measured 0.81002 / 0.80997; full-size hands retained, minimum elbow bend 0.605 radians, lateral hand clearance 0.130 m. Full stationary attack reach and idle recovery passed.
- Rebuilt standalone macOS v1.7.4 passes code-signature verification, exported locomotion suite and combat suite, all zero failures. Logs: `compact-idle-blender.log`, `compact-idle-import.log`, `compact-idle-assets.log`, `compact-idle-visual.log`, `compact-idle-exported-test.log`, `compact-idle-combat.log`.

## v1.8.0 game feel

- Approved Blender source, GLB and textures were not regenerated or edited. Runtime-only overlays preserve compact idle and authored locomotion.
- `feel-locomotion-final.log`: zero failures, including idle arm ratios, feet/anchors on slopes and reversals, breathing, torso response and pipe attachment.
- `feel-combat-final.log`: zero failures; original triple-hit totals, charged sweep, piercing/split coins, wall occlusion, surge, tuning and pause behavior remain intact.
- `feel-visual-final.log`: zero failures, 138 rendered frames from actual coastal gameplay. Reviewed contact poses, heavy/light/coin effects, recoil, turn, braking and jump. `game-feel-preview.mp4` preserves frame timestamps.
- The initial acceleration assertion inherited movement from an evade; isolating it with a player reset fixed the test setup. Final rendered and exported runs pass.
- Exported v1.8.0 app passes signature verification, new feel suite and existing combat suite (`feel-exported-test.log`, `feel-exported-combat.log`). Both report zero failures. The known Godot headless DummyShader RID shutdown warning remains; rendered run has no script errors.
- Standard app launch reaches the menu (`feel-standalone-menu.png`). Direct game-feel testing used scripted actual inputs/controller execution in the rendered level, rather than a subjective human play session.

## v1.9.0 choreographed three-hit pipe combo

- Character/pipe Blender sources, imported models, meshes, materials and textures were not modified. Runtime-only pose and controller changes.
- `combo-release-visual.log`: zero failures, 149 rendered gameplay frames, nine in-environment key-pose views. Verified diagonal opener, left sweep/load and right finisher, continuous stage seams, ordered one-click strikes, growing hit-stop, input buffering, recovery and real finisher knockback.
- Final articulated arm error was below 0.1 mm after pose evaluation; planted foot error was below 0.001 mm. The initial strict arm test sampled before the render-side rig evaluation; moving it after HeroModel evaluation corrected that sampling issue without relaxing the 3 mm limit.
- Visual iteration corrected an overly upright pipe: explicit wrist aim now tracks the diagonal/left/right arcs, retaining the original hand attachment and weapon scale. `combo-keypose-review.png` and `pipe-combo-preview.mp4` show final poses and gameplay. Preview timings follow captured frame timestamps; this is not a performance benchmark.
- Existing combat and locomotion suites pass on the exported app (`combo-exported-combat.log`, `combo-exported-locomotion.log`). Release combo suite is `combo-release-exported-test.log`. The known Godot dummy-renderer shutdown RID warning may appear in headless logs; rendered validation has no script errors.

## v1.9.1 charge stance

- Replaced the legacy shoulder-only charge overlay with bounded articulated right-arm positioning. Original character and pipe assets remain unchanged.
- `charge-final-visual.log`: zero failures. Both weapons point to the character's right while holding; the wrist remains outside the shoulder; release, cancellation and weapon switching recover. Tested moving during charge and Golden Surge. Maximum segment-length error under 0.08 mm; minimum elbow bend about 57.4°.
- Inspected `charge-hold-1.png`, `charge-hold-2.png`, `charge-release-1.png`, `charge-release-2.png` and `charge-gameplay.png` in the actual coastal environment.
- `charge-combat.log`, `charge-combo.log`, `charge-locomotion.log`: all report zero failures. Standard damage, charge behavior, one-click choreography and approved idle/locomotion remain functional.
- Standalone release v1.9.1 export and signature validation completed. Exported charge checks are in `charge-exported-test.log`.

## v1.9.2 reference koban

- Saved editable Blender source and exported the coin GLB: 1,024 triangles, one mesh, two materials, approximately 119 KB including packed color/normal maps. Godot import completed without errors.
- Inspected Blender front, back and three-quarter renders (`koban-source-*.png`), Godot studio view (`blender-koban.png`), and giant charged coin in the real coastal environment (`blender-charged-coin.png`). Both faces have correctly oriented stamps and the long, rounded thin silhouette.
- `koban-game-visual.log` reports zero asset failures. `koban-combat.log` reports zero failures including normal/split/piercing coins, charge damage, wall blocking and surge scaling. No gameplay or character/pipe changes.
- Standalone v1.9.2 exported and signature verified. Exported combat regression log: `koban-exported-combat.log`.

## v1.9.3 repeated-attack deformation fix

- Reproduced progressive bone scaling with rapid click events through the real controller: before-fix scale exceeded 2× (`attack-soak-before.log`).
- Reset local skeletal poses before each AnimationTree seek, then apply only the current frame's procedural layers. No changes to mesh, textures, authored clips, attack choreography or intentional compact idle proportions.
- Exported 7,200-tick/120-second attack-spam test passes (`scale-fix-exported-soak.log`). After warm-up, maximum scale changes by less than 0.000001; character/root stay at original scale. Maximum temporary blend scale is ~1.011, with no cumulative growth.
- Combo, locomotion and both-weapon charge tests pass (`scale-fix-combo.log`, `scale-fix-locomotion.log`, `scale-fix-charge.log`). Inspected the rendered pipe charge; the visual session closed before completing its second-weapon pass, so full charge regression was completed headlessly.
- Standalone v1.9.3 rebuilt, signature verified and exported attack-spam suite reports zero failures.
