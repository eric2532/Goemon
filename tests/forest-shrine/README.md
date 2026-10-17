# Forest Shrine validation — v2.59.0

## Spawn portals and painted roads

The Map Editor palette now includes **Spawn Portal** and **Road · paint**. Portals rotate with **R**; the arrow marks the front exit. Paint a road from that opening toward the base with click/drag. **Road: 1 / 3 / 5 tiles** selects the brush width; five tiles clears giant-sized corridors. Painting clears trees in its footprint, and one Undo restores the entire stroke and those trees. Retracing a drag follows the cursor without painting an unintended loop. Roads support selection and single-tile deletion; structures and gates can stand above them.

With authored portals, finite waves release through those portals in rotation instead of the default southern edge. Composition, batch size, cadence and active cap remain controlled by the existing waves/balance. Visible portals may release enemies; blocked exits and nearby actors defer arrivals without consuming pending slots. Without portals, original edge spawning is unchanged.

Connected roads guide progress toward the base. Enemies leave the road for nearby targets and use collision-aware paths to rejoin their remaining forward route after combat. Existing walls/gates still physically block movement and can be attacked/breached; roads do not let enemies pass through them. Portal exit and road validation preserve giant terrain clearance. Portals/roads save as optional schema1 fields, so previous custom maps and the protected Original Map remain available.

```sh
godot --headless --path . --script tests/forest-shrine/portals_roads_test.gd -- --test
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/portal_editor_test.gd -- --test
godot --path . --resolution 960x600 --fixed-fps 60 --script tests/forest-shrine/portal_editor_test.gd -- --test --visual
```

The 31 model/document checks cover legacy loads, portal rotation and protection, whole-stroke undo/clearing, disk round-trips, invalid files, visible and blocked arrivals, exact wave counts, curved guidance, combat interruption/rejoin, actor clearance, wall blocking, multiple portals and giant safety. The 12 scene checks exercise real portal placement/rotation, road dragging/retracing/cancellation, focus guards, batch rendering, save and live wave release. `SONIC_PORTAL_CAPTURE_DIR` controls native screenshots.

## Building-view map editor

During preparation, click **Map Editor** beside Balance and Instant Restart. The overhead grid becomes a paused layout workspace. Choose a watchtower, wall, gate, mine, gold deposit or tree and click to place it for free. Select existing objects with **Select**, rotate structures with **R**, and remove them with **Delete**. Undo/Redo restores edits. Middle drag or WASD pans; the wheel zooms. Typing a map name does not activate game shortcuts.

**Save** stores a named layout in `user://forest_maps`; the saved-map picker and **Load** reopen it, including after relaunch or an app rebuild. Different names create separate files; replacing another saved map asks first. Loading a map or leaving unsaved edits asks before discarding them. **Back** restores the pre-editor run, while **Play map** starts a fresh preparation with the edited layout and current balance. Instant Restart retains that selected layout for the session. Maps contain layout data, not wave progress or runtime health/treasury.

**Original Map** always restores the immutable pre-editor forest snapshot bundled at `assets/maps/forest_shrine_original.json`. Editing/saving this template creates a separate custom file. The shrine, hero start and training dummy remain fixed and protected; structure overlaps, invalid files, blocked building entrances and stranded starting workers are rejected. This first editor authors the existing flat ground; it does not edit terrain elevation or enemy wave schedules.

```sh
godot --headless --path . --script tests/forest-shrine/map_document_test.gd -- --test
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/map_editor_test.gd -- --test
godot --path . --resolution 960x600 --fixed-fps 60 --script tests/forest-shrine/map_editor_test.gd -- --test --visual
```

The 35 document checks exercise round-trip saves, separate named maps, bounds/overlap/file rejection, undo/name retention, original parity and route safety. The 27 scene checks use real pointer/key routing, collision removal, text focus and pointer hover, overwrite/discard dialogs, saved-map loading, actual scene restart, preview isolation, original restoration and wave gating. `SONIC_MAP_CAPTURE_DIR` selects native screenshots.

## Shared DDII-inspired combat camera and aim

Forest uses a single perspective camera across melee, ranged and hybrid attacks, preserving saved distance, character offset, HUD scale and optional gold reticle. Its first forward step now follows smoothly without the legacy one-metre delay; other modes retain their existing buffer. Mouse look refreshes the camera immediately so a subsequent attack uses the new view before the next rendered frame.

Native and Rogue attacks share a horizontal aim point derived from the same crosshair ray. Forest raycasts start at the player's torso-depth plane, ignoring scenery between the camera and the character while still detecting cover ahead and excluding fog-hidden actors. Near/behind floor hits cannot flip a melee stroke backward; ranged projectiles retain the exact three-dimensional ray target and existing obstruction checks.

Actual ranged releases establish a 0.28-second aim-facing hold. Charging/ongoing ranged casts retain it, allowing camera-relative strafing while the body continues to face the aim. Native coin casts and Edo, Rogue ranged primaries and hybrid ranged abilities share this behavior. It expires back to movement-facing; melee starts, evasion and fighter/phase changes clear it. Committed melee direction, attack shapes, timing, damage, movement impulses and automatic background coins retain their own behavior. Ranged tracking reuses the existing per-tick aim point.

```sh
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/ddii_combat_view_test.gd -- --test
godot --path . --fixed-fps 60 --script tests/forest-shrine/ddii_combat_view_test.gd -- --test --visual
```

The 59 headless checks (60 native) cover all twelve fighters' shared aim, stable camera, hybrid shot-to-strafe/recovery and ranged-to-melee transitions, Mage charging, actual native coin windup, Edo casts, evasion/role resets, forward/behind cover, upward/downward aim, saved preferences, building view and retained legacy follow buffer. The native-only check exercises captured mouse input and immediate aim response. `SONIC_DDII_CAPTURE_DIR` selects screenshots.

## Optional gold crosshair for every fighter

All twelve fighters, including melee and hybrid kits, share the gold centered crosshair. **Settings → Camera & HUD → Show crosshair** controls visibility, defaults to enabled for existing saves, persists automatically and resets to enabled. Hiding the reticle does not change camera input, attack direction, crosshair raycasts or projectile aiming. Live combat settings preview the toggle while battle remains paused; ordinary pause, roster, title, preparation and finished runs hide it.

The previous reachable-enemy brackets, gold crowd tint, fitted-range scans and highlight-only animation sampling are removed. Enemies retain their normal low-fidelity colors and existing blue freeze feedback.

```sh
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/crosshair_preference_test.gd -- --test
godot --path . --fixed-fps 60 --script tests/forest-shrine/crosshair_preference_test.gd -- --test --visual
```

The 39 headless checks (41 native) cover all twelve fighters with the setting on/off, combat preview, unchanged attack aiming, automatic save/reopen/relaunch, reset, malformed values, pause/resume and the building view. Native checks also confirm ordinary enemy color and retained freeze color. `SONIC_AIM_CAPTURE_DIR` selects screenshots. Settings layouts are checked at 125% HUD size and 960×600.

## Saved camera distance and HUD size

**Settings → Camera & HUD** exposes a paused preview with saved combat distance (7–22, default 12), HUD scale (65–125%, default 100%), and reset. Forest mouse-wheel zoom shares the distance preference; building-map zoom and legacy camera defaults remain independent. The view page previews the hubs without scaling crosshair, construction controls, or menus. Anchored scaling preserves portrait/loadout alignment, screen margins and building-bar clearance, including at the size limits. Camera preview keeps collision probes active while gameplay stays paused.

```sh
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/view_settings_test.gd -- --test
godot --path . --fixed-fps 60 --script tests/forest-shrine/view_settings_test.gd -- --test --visual
```

The 41 checks cover title and combat access, slider values, automatic disk saves/relaunch, live paused preview, scaling limits and actual scaled slot clicks, HUD bounds and map-action clearance, reticle/build-control isolation, reset, Escape navigation, mouse-wheel persistence, fighter/phase changes, camera occlusion and malformed/out-of-range preferences. `SONIC_VIEW_CAPTURE_DIR` controls screenshot output (default `/tmp`). Native views are checked at 1280×800 and 960×600.

### Character screen position

The same page includes **Character position**, from 10% higher to 15% lower in 1% screen-height increments. Zero preserves the existing framing. Moving toward Lower tilts the view upward around the camera's existing collision-tested position; zoom, HUD size, mouse orbit state and crosshair/projectile alignment stay independent. The adjustment limits extra movement near 45%/88% screen height without correcting an existing offscreen orbit framing, so the supported upward mouse aim remains available. The reference uses the smoothed follow point, preserving normal jump motion. Settings save automatically and reset with camera/HUD defaults; the building map is unaffected.

```sh
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/character_framing_test.gd -- --test
godot --path . --fixed-fps 60 --script tests/forest-shrine/character_framing_test.gd -- --test --visual
```

The 30 checks cover neutral compatibility, real projected displacement in both directions, zoom limits, live paused preview, camera position/orbit preservation, centered ray and actual projectile direction, full upward aim, obstruction handling, map isolation, reset, invalid preferences and application after relaunch. `SONIC_FRAMING_CAPTURE_DIR` selects native screenshot output (default `/tmp`).

## Ninja drift on confirmed hits

Forest Ninja normal attacks no longer apply forward velocity at startup or take the precontact approach step. Accepted direct primary hits schedule one follow-through impulse after the short contact plant; a third cut has the stronger original impulse. Misses, cover/fog rejection, background projectiles and elemental follow-ups cannot enable it. Matching attack tickets and consuming the impulse keep multi-target swings to one step. Other fighters, dash attacks, manual movement and aiming assistance retain their existing behavior.

```sh
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/ninja_hit_drift_test.gd -- --test
```

The 33 checks exercise all three empty swings, acquired targets outside physical reach, no movement before damage, real-hit travel and settling, a stronger finisher, multi-target hits, fog/behind/cover misses, manual walking, Ninja's separate dash, the immortal training dummy, boosted retirement and cancellation. Movement integration matches the engine's 60 Hz physics tick. Level, pickup and chain bonuses cannot discard a confirmed step when a swing ends during planting; explicit cancellation discards it.

## Immortal shrine training dummy

A single low-poly wooden target occupies cell (2,2), beside the main base. It registers in the combat actor list but never the authoritative wave enemy dictionary, so tower AI, HUD counts and victory checks ignore it. Its finite HP is never reduced; hits still confirm AttackChain tickets, critical damage numbers and a brief visual reaction. The target cannot attack, move from knockback or bash, die, award rewards or block a wave. Capsule contact/segment queries match its full-height physics collider, including head-height shots. Preparation retains its paused building controls; attack the dummy during a wave.

```sh
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/training_dummy_test.gd -- --test
godot --path . --fixed-fps 60 --script tests/forest-shrine/training_dummy_test.gd -- --visual
```

The 46 checks cover spawn/placement, construction reservation, huge hits without non-finite health or death, damage and combo feedback, stationary behavior, no retaliation/reward, freeze expiry, full-height projectile contact/misses, real primary attacks from all twelve fighters, normal-enemy health, wave completion and persistent registration between waves/character changes. `SONIC_DUMMY_CAPTURE_DIR` selects the screenshot folder (default `/tmp`).

## Compact character HUD and empty loadout slots

The 380×84 character strip sits at the top left, centering an 82-pixel portrait above five empty loadout buttons. Wave information and map actions stack beneath it; shrine health sits beneath the resources on the right. All gaps follow HUD scaling, with building inspection below shrine health and contextual hints near the bottom. Health/damage trails and the two actual attack/cooldown indicators remain live. Click slots during preparation; combat captures the cursor for aiming, so use 1–5 then. Number selection emits one zero-based `loadout_slot_selected` index for future assignment wiring, without consuming current combat actions. Preparation numbers still build/recruit, and menus, key repeat, release and modified shortcuts do not select slots.

```sh
godot --headless --path . --script tests/forest-shrine/compact_loadout_hud_test.gd -- --test
godot --path . --script tests/forest-shrine/compact_loadout_hud_test.gd -- --visual
godot --headless --path . --script tests/forest-shrine/hud_cleanup_test.gd -- --test
godot --headless --path . --script tests/forest-shrine/hud_polish_test.gd -- --test
```

The loadout regression exercises real pointer/key routing, exclusive selection feedback, retained coin ability and construction controls, menu guards, fighter switching and portrait/frame/hotbar placement. `SONIC_HUD_CAPTURE_DIR` sets the capture folder (default `/tmp`). HUD fixtures use independent settings paths so saved core-balance edits do not invalidate default-wave/economy assertions.

## Low-fidelity enemy default

The production crowd renderer defaults to untextured, unshaded, shadowless shared boxes for each authoritative contact region. No pose images, animation textures, imported render meshes or detailed enemy materials are allocated on this path. Existing collision shapes and their authoritative transforms remain unchanged; freeze changes marker color, fog hides all compound parts, and dead actors shrink before cleanup. Hidden full-health bars skip fitted-surface queries. The detailed renderer's unit fixtures opt in explicitly with `low_fidelity=false`; it is not selected by saved graphics quality.

```sh
godot --headless --path . --script tests/forest-shrine/low_fidelity_enemies_test.gd -- --test
godot --path . --script tests/forest-shrine/low_fidelity_enemies_test.gd -- --test
godot --path . --script tests/forest-shrine/dense_crowd_profile.gd -- --test --out=/tmp/forest-low-fidelity-profile
```

The 65-check regression covers the production default, primitive geometry and bounded batches, no textures/shadows, visible/frozen/fogged enemies, damage, compound cleanup/death, hidden rig absence, and hidden-versus-damaged health bar fitting. Native before/after metrics and captures are retained under `build/Other Files/low-fidelity-enemies-20261016/verification/`. Frame timings are subject to the display cap; geometry and component CPU costs are reported separately.


## Responsive melee

Goemon, Pirate, Samurai, Ninja, Knight, Dragoon, Magic Swordsman and Master Thief use earlier articulated contact, a single reliable queued primary tap, shorter attacker-only hit pause, and a short contact protection window. Enemy recoil, damage, full swing lengths, attack shapes, Samurai's five cuts, three-hit finishers, special attacks, and Explorer's reference kit retain their own behavior. Boosted Samurai contacts never become slower, and their protection scales down with the faster swing. Goemon shares the same actual contact phase between his weapon pose, damage and foot planting.

```sh
godot --headless --path . --script tests/forest-shrine/melee_responsiveness_test.gd -- --test
godot --path . --script tests/forest-shrine/melee_responsiveness_test.gd -- --test --visual
```

The 140 checks cover real fitted-raider contact before/after windup, early-tap consumption exactly once, dodge cancellation, recovery vulnerability, unchanged damage/cadence and complete combo stages, boosted Samurai, special timing and input expiry, Explorer/Ranger isolation, enemy-versus-attacker pause, and native Goemon pose/timing agreement. `SONIC_MELEE_CAPTURE_DIR` controls native capture output (default `/tmp/sonic-melee-poses`). Release verification and comparisons with existing legacy fixture failures are saved under `build/Other Files/melee-responsiveness-20261016/verification/`.


## Core game balance and map boundaries

The building map’s Balance button opens Core Game Balance directly and saves starting gold, watchtower health/damage/cadence/capacity, wave count and four enemy-type counts per wave. Gold and waves snapshot at a new run; tower edits apply live. Default wave sizes and compositions remain unchanged. The HUD previews the configured next wave and counts pending plus alive enemies. Forest edges clamp movement; falls recover locally for all twelve fighters.

```sh
godot --headless --path . --script tests/forest-shrine/core_balance_test.gd -- --test
```

The 180-check regression covers title-to-Play settings, disk round trips, input sanitization, resizing waves, live tower health and staffing, actual tower shot cadence/damage, exact mixed and multiple-Daruma spawns, empty waves, configured victory, direct map entry, pause/Escape navigation, active-run wave isolation, and all four edges plus falls for every fighter. Native layout verification also checks both settings screens and scrolling to wave 50.


## Direct building-map actions

The preparation map has **Balance** and **Instant Restart** buttons under the enemy hub. Balance opens the core editor directly; Back, Escape and reset preserve its return to the building map. Instant Restart uses the existing scene restart immediately, with no confirmation or fighter-selection step. Both map actions hide during waves and modal menus. Core balance is removed from Settings; character settings remain there.

```sh
godot --headless --path . --script tests/forest-shrine/preparation_actions_test.gd -- --test
godot --path . --script tests/forest-shrine/preparation_actions_test.gd -- --test --visual
```

The 14-check regression exercises direct entry/exit, live edits, reset, Escape, pause/combat visibility, removal from Settings, and an actual scene restart preserving the fighter and restoring the treasury. Native captures save to `/tmp/sonic-building-actions.png` and `/tmp/sonic-building-balance.png`.

## Lacquer HUD polish — v2.59.0

The bottom hub uses an overlapping circular gold medallion with a face-and-shoulders crop of each fighter's existing portrait. Shared SVG artwork supplies soft lacquer frames, gold trim, faint grain, mouse-button symbols and a radial cooldown mask. The thicker health bar uses jade, amber and red states plus a brief delayed damage trail; healing and hero/max-health changes snap the trail to the correct value. Pause and roster menus preserve its animation. Both native fighters show shared action recovery; Rogue classes show their actual primary/secondary cooldowns. Edo’s sustained beam shows an active primary with no invented countdown, and its interrupting secondary stays ready. Enemy counts have a tighter layout and a distinct giant accent. Gold and worker counts occupy separate matching badges, with gold grouped by thousands.

All artwork is cached in 2D; the portrait shader samples a single cropped texture and does not create a portrait camera. The native color regression compares the real HUD crop against independently drawn atlas samples for all twelve characters, including circular transparency. It catches an implicit uncropped texture multiplication that headless checks cannot reveal.

```sh
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/hud_polish_test.gd -- --test
godot --path . --script tests/forest-shrine/hud_portrait_render_test.gd -- --test
godot --path . --script tests/forest-shrine/hud_polish_tour.gd -- --test
```

The behavior test covers currency boundaries, immediate health updates, delayed damage feedback, pause/resume, healing, danger colors, fighter switching, cached portraits and both cooldown transitions. The rendered tour saves preparation, combat, damage/recovery states and a twelve-portrait contact sheet under `tests/forest-shrine/hud-polish/`; use `FOREST_HUD_CAPTURE_DIR` for packaged captures. The portrait color test requires the real renderer and should be excluded from headless suite loops.

The 28 Forest headless suites passed after the final beam-state fix. Four rendered suites passed, including the 72-check portrait color test and the existing enemy-spawn and atmosphere checks. The complete starter scene uses 931 draw calls, compared with 927 for v2.58.0's HUD in the same fixture; this is a draw-budget comparison, not an FPS claim. Release logs retain existing intermittent headless shutdown warnings; the dedicated HUD behavior regression also passed a clean verbose rerun.


## Compact HUD — v2.58.0

The enemy hub shows four illustrated types and their remaining counts, including waiting spawns; preparation previews the next wave. The right status hub shows gold and healthy workers. The selected fighter's authored portrait, current/max health bar, and left/right attack icons occupy the bottom center. Portraits and attack textures change only when the fighter changes; there are no continuously rendered portrait cameras. Shrine health remains a small top-center bar. Floating structure/deposit names, the persistent control/ability paragraphs, and the on-screen Q picker are removed; the Q key and preparation building cards remain functional. Contextual placement/rally feedback and transient notifications remain.

```sh
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/hud_cleanup_test.gd -- --test
godot --path . --script tests/forest-shrine/hud_cleanup_tour.gd -- --test
```

The behavioral regression checks all twelve portraits and pairs of attack icons, health updates, next-wave composition, pending/alive handover, giant defeat, ordinary arrivals, empty-wave counts, available-worker counts and separation from preparation controls. The native-rendered tour saves preparation, Knight, Edo and Ranger views to `tests/forest-shrine/hud-cleanup/`; `FOREST_HUD_CAPTURE_DIR` chooses an external folder for packaged validation.

Verification passed all 27 Forest headless suites, the 78-check HUD regression, and three native-rendered suites. Packaged HUD, normal-title launch, screenshots, signature and installed boot checks also passed. The historical tower-defense suite passed. The retired `--rogue-siege-tests` suite currently fails 19 checks (legacy launch/director assertions and older combat expectations); the identical 19 failures reproduce in the archived v2.57.1 app and without this change's shared-game/player notification edits. These failures are recorded in the release's `source-regressions/legacy-report.json` and baseline comparison. Existing headless teardown resource warnings remain recorded separately.


## South-only enemy entries — v2.57.1

All five waves now spawn ordinary enemies at the southern forest edge, aligned with the starter fort's single gate. Daruma's near and far staging also stays south; the old north/east/west and four-corner fallbacks are removed. Far southern diagonal approaches remain available if towers watch the center lane. Full-footprint visibility and fitted clearance still validate every giant entry. The starter towers cover the old 84–96m southern staging, so the usual production giant now starts farther south rather than appearing in shared sight.

```sh
godot --headless --path . --script tests/forest-shrine/south_spawn_test.gd
```

The regression checks all 992 enemies over four seeds and five waves, the unchanged finite wave counts, one giant in each of waves 3–5, southern fallback under scouting, and restored entries after temporary vision clears. A fully watched map waits for an unseen entry instead of spawning on another side.


## Ready starter fort — v2.57.0

Each new run and retry begins with a continuous palisade surrounding the shrine, both mines and two towers. Exactly one 12-metre gate admits the hero and workers. Six miners retain full three-person mine crews; two extra guards begin on the tower decks and fire without player assignment. The fort is free, its ground is already explored, and the first wave can start immediately. Normal shared enemy visibility, construction, repair, demolition and breaches remain active.

The model/physics regression checks the closed enclosure, nonoverlapping footprints, every workplace route, all four outside routes through the single gate, 676 hero-sized physical sweeps around the perimeter, enemy gate blocking, live arrows from both guards, enemy breach pressure, and retry. A rendered regression checks the drawing budget and translucent wall preview. Wall logs and caps use shared meshes and per-section batches, reducing the preparation scene from 3,038 to 915 draw calls without changing the collider joins.

```sh
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/starter_fort_test.gd
godot --path . --script tests/forest-shrine/starter_fort_render_test.gd -- --test
godot --path . --script tests/forest-shrine/starter_fort_tour.gd -- --test
```

The tour saves preparation and both sides of the gate under `tests/forest-shrine/starter-fort/`; set `FOREST_FORT_CAPTURE_DIR` to an external directory for packaged runs. The fixture helper `empty_settlement.gd` explicitly restores six idle workers and removes all starter defenses for tests that construct their own layout. Production opening tests instead verify eight workers and the completed fort.


## Daruma staging and target performance — v2.56.2

Daruma's real wave-director spawn additionally searched all 96 staging positions and selected a cheapest shrine approach for each, even when only a few near positions could be chosen. With 0/10/30 valid towers, the v2.56.1 packaged game took 87/117/123 ms to validate and spawn the giant. The optimized search retains the original coordinate order and fog/nearest-ring rules, validates eligible entries lazily, shares the shrine contact ring, and stops each reachability search at its first valid route. The clearance grid prepares between waves or at the wave transition. Spawn validation measured 2.2–2.4 ms. Staging plus actor creation measured 5.6 ms in the rendered source scene and 14.2 ms in the packaged app.

First target selection with 30 towers took 20.3 ms. Searching candidates by a conservative path-cost lower bound reduced it to 2.3 ms, preserving the cheapest reachable target and insertion-order ties. Independent review compared 78 cases against the previous exhaustive behavior, including changing fog, demolition, off-grid positions and symmetric target ties. A rendered moving-giant check found no sustained rendering slowdown in this fixture; it establishes the route-search hitches rather than ruling out every possible settlement layout.

```sh
godot --headless --path . --script tests/forest-shrine/giant_staging_performance_test.gd
FOREST_GIANT_REPORT=/tmp/giant-lag.json godot --path . --script tests/forest-shrine/giant_lag_profile.gd -- --test
```

The performance regression uses legally placed, nonoverlapping towers on the production forest and invokes `waves.spawn_one()`. Calling `spawn_enemy()` alone bypasses staging and cannot catch this hitch. Profiles and regression logs live under `tests/forest-shrine/performance-giant/`.

## Enemy spawn and contact performance — v2.56.1

First-time fitted collider generation blocked the real Metal renderer for 24–81 ms per enemy role. The hulls now populate their shared cache during scene loading; first spawns measured 0.16–1.82 ms. Repeated Lantern contact queries fell from 0.316 ms to 0.018 ms by using native convex clipping for outside entries. The original clipping path retains interior, stationary and tangent contacts. In the same 60-enemy scene, actor update time fell from 7.40 ms to 1.23 ms. These are CPU/spawn timings, not an FPS improvement claim: both controlled rendered runs maintained approximately 60 FPS on Apple M3.

```sh
godot --headless --path . --script tests/forest-shrine/enemy_contact_performance_test.gd
godot --path . --script tests/forest-shrine/enemy_spawn_performance_test.gd -- --test
FOREST_LAG_REPORT=/tmp/forest-lag.json godot --path . --script tests/forest-shrine/enemy_lag_profile.gd -- --test
```

Run the spawn test with the real renderer: headless collider generation does not reproduce the original stalls. The profile separates first spawns, simulation, fitted actors, crowd submission, world updates, and rendered median/p95 frame times for 0/12/24/60 enemies. Measurements live under `tests/forest-shrine/performance-lag/`. All 23 headless Forest behavioral suites passed; `definitive_test.gd` requires no `--test` argument because it verifies the normal title launch. Contact/review/integration/modern-combat/Rogue harnesses retain their documented headless exit-resource warnings.

## Existing Forest checks

Requires Godot 4.6.1. Run from the repository root:

```sh
godot --headless --path . --script tests/forest-shrine/model_test.gd
godot --headless --path . --script tests/forest-shrine/simulation_test.gd
godot --headless --path . --script tests/forest-shrine/world_test.gd
godot --headless --path . --script tests/forest-shrine/integration_test.gd -- --test
godot --headless --path . --script tests/forest-shrine/lifecycle_test.gd
godot --headless --path . --script tests/forest-shrine/rogue_test.gd -- --test
godot --headless --path . --script tests/forest-shrine/definitive_test.gd
godot --headless --path . --script tests/forest-shrine/transition_test.gd -- --test
godot --headless --path . --script tests/forest-shrine/fog_target_test.gd -- --test
godot --headless --path . --script tests/forest-shrine/review_regression_test.gd
godot --path . --script tests/forest-shrine/integration_test.gd -- --test --visual
godot --path . --script tests/forest-shrine/definitive_test.gd -- --forest-title --visual
```

The model suite covers grid occupancy, explored placement, real prices and atomic wall lines, rotated entrances, gate routing, and remembered/shared vision. The simulation suite covers job reservations and previews, deliveries, no preparation income, repair, wounds, safe retreat, perimeter spawns, barrier breach, and the full five-wave victory loop.

The world suite checks actual construction colliders, friendly gate passage, and settlement bounds. Integration clicks a real build card and the actual 3D battlefield, checks phase/camera changes and combat building rejection, exercises live rally/pause, attacks a real raider with Goemon input, and rejects invisible auto-targets. Lifecycle checks cover main-menu launch, shrine defeat, retry, and return to the Forest Shrine title. The review regressions verify repair access after construction, fresh rally input after pause, gradual tower exits through the entrance, staffed tower damage, and chain impacts hidden by fog.

The Rogue suite exercises every native class primary attack against real forest raiders, Fire Siege Crosshair perspective framing, Q roster transitions, health/cooldown preservation, fog filtering, shield bash, freeze/slow effects, and untargetable fighters. The definitive suite verifies normal launch, all twelve choices, preparation/combat transitions, selected-fighter retry, and Forest-only title return.

Rendered integration saves `preparation.png`, `placement.png`, `battle.png`, and `exploration.png` here. Inspect these for overlapping UI, ghost alignment, forest cutaway, and current/remembered fog. Generated images are ignored by Git.

Existing mode regression commands:

```sh
godot --headless --path . -- --tower-defense-test
godot --headless --path . -- --rogue-siege-tests
```

These commands retain historical coverage. The tower-defense suite passes in v2.58.0; Rogue Siege currently reports 19 pre-existing failures, as recorded above. Tests print a `*_RESULT` marker and exit nonzero on assertion failures. Also inspect output for Godot script/render errors, which can occur independently of an exit code.

## Playtest

Open `build/Goemon.app`, select **PLAY FOREST SHRINE**, choose a fighter, inspect the completed enclosure and its one gate, watch six miners walk to the two mines, and check the two guards already on their towers. Start the first wave immediately, or add defenses if desired. Hold **V** to lead available workers to a different job. Watch the assignment counts while holding; release to reserve those jobs. Use **WASD**, mouse attacks, and **C** to defend; **Escape** pauses. Between waves, recruit, repair, and expand. Wounded workers return in preparation.

Initial values need player feedback: two finite deposits, eight workers, 1,000,000 starting gold for testing, five finite waves, no save/load, and a fixed forest layout. Terrain art and worker animation are prototype assets. The free starter fort has one gate, two staffed towers and two mines. Six miners reserve their jobs immediately; the two guards start on their decks. Mining begins in the first wave. Wall sections normally span six cells (36 metres), with fitted shorter sections at the starter fort joins.

## Review and implementation decisions

A fresh independent review found four important defects: blocked repair access, key-repeat rally after pause, chain impact feedback in fog, and tower crews bypassing their entrance. Each was reproduced in a failing regression before correction; no minor findings were deferred.

The approved first-version scope uses two starter deposits beside the shrine. Extra forest deposits and expanded artwork remain future design work. Teardown warnings in a fast headless integration run were investigated separately: allowing the same short audio/effect settling interval used by the existing game produced three consecutive clean reruns.

Implementation decisions recorded during the work:

- Proceeded with implementation after the explicit approval to use the spec and build, superseding the earlier discussion-only request. All changes are recorded in Git.
- Built a separate scene that inherits existing game services. This preserves established modes, at the cost of maintaining the adapter when shared combat changes.
- Corrected a tower test fixture to use explored ground; unexplored placement rejection was the intended behavior.
- Removed an empty, stale worktree index lock only after checking its age and confirming no process held it. No index data was removed.
- Kept the nearby-deposit prototype scope from the latest request. Broader resource exploration will need a later map/economy pass.
- Treated the intermittent headless shutdown warning as a teardown timing issue after verbose inspection and clean repeated runs, rather than changing gameplay resource ownership without evidence.

## Previous delivered build — v2.28.0

macOS release **2.28.0** passed bundle-signature verification, headless main-menu and direct Forest Shrine launch, and rendered native launch on Apple M3 / Metal. Six Forest Shrine test suites passed; the model reported 20 checks, workforce/waves 34, and post-review regressions 15, alongside world/integration/lifecycle checks. Existing Tower Defense passed and Rogue Siege passed all 173 checks.

The main launch icon is `build/Goemon.app`. The prior 2.27.0 app is preserved under `build/Other Files/Goemon-v2.27.0-before-Forest-Shrine.app`. Release screenshots, logs, and ZIP are stored under `build/Other Files/Forest Shrine v2.28.0/`.

The forced headless main-menu shutdown prints one dummy-renderer shader allocation warning in both the prior 2.27.0 app and this build. Rendered native main-menu and Forest Shrine launches are clean; this is an existing headless-exit limitation, not a new gameplay failure.

## Definitive combat review — v2.29.0

A fresh review found that retained Goemon Sky Strike could automatically target a forest raider outside shared vision. A real-scene regression failed for both target selection and impact before correction. Selection and impact now check current forest visibility; visible targets retain normal damage. No minor findings were deferred.

## Current delivered build — v2.29.0

`build/Goemon.app` now launches the Forest Shrine title only. All eleven fighters use the original Rogue Siege combat and close battle camera, with overhead grid placement only between waves. Ten Forest suites and all 173 existing Rogue Siege checks passed after the final fog fix. The native bundle passed signature verification and headless launch; the exported PCK passed the definitive scene-flow suite. Rendered title, roster, preparation, and combat captures were inspected. Native UI automation was unreliable, so packaged scene-flow verification used the Godot test harness against the exported PCK.

The previous app is preserved at `build/Other Files/Goemon-v2.28.0-before-Definitive-Forest.app`. The release ZIP, screenshots, and test/export logs live in `build/Other Files/Forest Shrine v2.29.0/`.

Implementation decisions: historical modes remain available through explicit development commands while hidden from normal launch. The approved work was integrated locally into the existing feature branch. A stale, empty worktree index lock was removed after checking its age and confirming it had no process owner; no index data was removed.


## Definitive crosshair correction · v2.54.0

The current build merges the full Fire Siege Crosshair v2.53.1 baseline (`aa7f1d2`), preserving its camera, authored character assets, animations, combat actions and effects. The earlier v2.29 angled-camera release below is historical. Normal launch opens only Forest Shrine; the overhead grid is used only for preparation.

New checks:

```sh
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/crosshair_test.gd
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/modern_combat_test.gd
godot --path . --script tests/forest-shrine/crosshair_tour.gd
```

The crosshair suite checks perspective/orthographic transitions, twelve heroes, pause/roster return, reticle state and battlefield continuity. Captured-cursor and mouse-look assertions also run in a real window because Godot's headless DisplayServer cannot capture a pointer. The modern-combat suite checks Samurai's five-cut combo and blade ink, Ranger's upward five-arrow curved fan, updated Edo beam, Goemon native effects, and visibility in auto-lock, center-ray targeting, projectile contact queries, elemental neighbors, meteor selection and fire impact presentation.

All twelve Forest suites passed behavioral assertions. Existing modern Fire Siege suites also passed: Edo redesign 19 checks, Samurai combat 42, Magic Swordsman ink 33, equipment combat 63, roster ink 442, and auto-lock 59. Some accelerated headless harnesses print audio-resource cleanup warnings on exit; they reported no gameplay script errors. A first fixed-fps rendered harness crashed in Godot 4.6.1 teardown after its assertions passed; the real-time rendered tour using normal `quit_clean()` completed and exited successfully. Its title, roster, preparation, battle, Samurai, Edo and pause captures were inspected.

The latest committed Edo assets are included. The separate chat's uncommitted `edo_new_design` work is intentionally not included or changed.

The macOS v2.54.0 bundle passed deep/strict signature verification and native headless boot. Its exported PCK passed definitive launch/retry/title flow, 15 crosshair checks and 20 modern-combat checks. Installed at `build/Goemon.app`; the v2.29 backup is `build/Other Files/Goemon-v2.29.0-before-Crosshair-Forest.app`. Release ZIP, rendered captures, and verification logs are in `build/Other Files/Forest Shrine v2.54.0/`.

## Surrounding forest atmosphere · v2.54.1

The existing woodland now remains visible beyond unexplored ground, with muted tree silhouettes, green ground, and successive rows fading into sage mist. Paths and the building grid still require exploration; enemies still require current shared vision. This is a renderer-only change: forest positions, collisions, navigation, buildings, workers, combat and camera settings are unchanged.

Run the rendered regression with `godot --path . --script tests/forest-shrine/atmosphere_test.gd`. It compares real pixels with the unknown forest drawn versus hidden, checks that showing scenery grants no exploration or vision, verifies unseen raiders are absent from crowd batches, and then verifies their appearance after scouting. It saves preparation, zoomed overview, four battle directions and the forest approach for inspection. Run it in a real window; headless rendering is explicitly rejected.

The regression failed with the original shader (zero forest pixels) and passed with the new shader. Model, simulation, world, fog targeting, crosshair, modern combat and definitive launch suites also passed. The accelerated fog-target and modern-combat harnesses retain their previously documented shutdown resource warnings; the rendered atmosphere run exits cleanly.

The v2.54.1 macOS bundle passed deep/strict signature validation, native headless boot, and definitive launch flow against its exported PCK. The same exported PCK passed the rendered atmosphere regression with 8,640 changed forest pixels and no failures. Set `FOREST_ATMOSPHERE_CAPTURE_DIR` to an external directory when running the rendered test against a packaged PCK. A fresh independent review reported no findings; the existing starting-camera worker occlusion and headless cleanup warnings were outside this visual change.

The current app remains `build/Goemon.app`. Its previous version is backed up as `build/Other Files/Goemon-v2.54.0-before-Forest-Atmosphere.app`; the v2.54.1 ZIP, packaged screenshots, and verification logs are under `build/Other Files/Forest Shrine v2.54.1/`. The other chat's uncommitted Edo redesign is untouched.

## Four enemy roles — v2.55.0

The approved rounded, textured models replace Forest Shrine’s old crowd. Other game modes retain their existing enemies. Raider targets the hero (300 HP, 6 m/s); Archer targets healthy workers, including visible tower crews (65 HP, 5 m/s,24 m arrow range); Lantern targets the shrine (55 HP, 10 m/s). Daruma uses the massive v02 model (23.1 m tall),3,000 HP and 0.75 m/s movement in every wave. It targets the nearest reachable tower or wall, commits to that target, strikes for 120 after 1.5 s windup and recovers for 3.5 s. Gates and other blocking structures can be breached; missing primary targets fall back to the shrine.

One Daruma is introduced in each of waves 3–5. Near staging is 80–100 m away and entirely outside current shared sight. If towers cover those positions, validated farther approaches and corner entries keep spawning possible. This exceptional case increases travel time; it never speeds up or teleports the giant. Wide cardinal and diagonal forest approaches fit the actual core and outstretched fists. The five wave counts remain 24/36/48/60/80.

Giant feet, shell and fists have compound fitted hurt shapes. All twelve heroes can damage the visible low areas; arrows target the same posed geometry. Ordinary knockback is reduced 90% and routine flinch is ignored, while freeze pauses movement and attack progress. The giant’s health bar stays near the visible lower surface rather than above its head.

Focused commands:

```sh
godot --headless --path . --script tests/forest-shrine/enemy_roles_test.gd
godot --headless --path . --script tests/forest-shrine/enemy_visual_test.gd
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/enemy_contact_test.gd -- --test
godot --headless --path . --script tests/forest-shrine/enemy_integration_test.gd
godot --path . --script tests/forest-shrine/enemy_integration_tour.gd -- --visual
```

Native front/side/back, walk and strike snapshots are in `docs/enemy-concepts/runtime-v01`. Values are the initial balancing pass; the user’s role priorities, giant scale and very slow/high-health requirements are fixed. The original editable .blend and GLB sources are preserved.

## Melee engagement

`godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/melee_engagement_test.gd -- --test` exercises hero retaliation, refresh/expiry, untargetability, tower and zero-damage exclusions, interrupted simulation windups, bounded combo knockback, shared visible/fitted recoil, archer hero contact and cover, and grounded strike/recovery/air movement across the melee roster. Reach checks cover the 12% extension beyond the prior fitted weapon boundary and actual Knight hits/misses on either side of the new limit. Movement checks cover the roughly 70 ms plant, full movement before/after it, and Goemon's immediate-contact energized combo transitions. Ranger keeps moving at contact. Goemon's pipe path is checked separately from the native Rogue kits.

Run the same script without `--headless` and add `--visual` after `--test` for native contact and recoil captures in `/tmp/sonic-melee-render/`.

`godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/hidden_melee_assist_test.gd -- --test` checks gentle turning in both directions for all nine melee fighters, camera ownership, real Hero-loop aim/pitch/retreat/dodge release, cover and visibility, combo continuity and expiry, freed targets, ranged/automatic targeting exclusions, and a bounded step through native collision. Run it without `--headless` and with `--visual` for native captures in `/tmp/sonic-soft-render/`. The Explorer regression now uses targets inside the gentle front cone; the giant-foot fixture aims toward the actual nearby foot, and the 240-actor acquisition regression requires at least one real fitted query.
