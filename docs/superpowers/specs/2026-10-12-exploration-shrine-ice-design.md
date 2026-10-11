# Fire Siege exploration, shrine combat, and ice towers

Date: 2026-10-12

Status: user approved this written design for implementation planning on 2026-10-12, including the supply caches. Gameplay implementation has not started.

## Intent and success criteria

The user wants a larger map with different places to explore while keeping defense battles. The main shrine must have health, and arriving enemies must stay and attack it at a cadence different from attacks against players. Moving the shrine nearer the enemy entrance should create urgency. Level 2 towers convert existing arrow towers into ice towers that slow enemies and deal no damage.

Confirmed choices:

- Exploration happens between waves, with unlimited preparation time. The player returns to defend and deliberately starts the next wave.
- Upgrading an arrow tower to level 2 replaces its damaging attack with a slowing ice attack. Keeping a tower at level 1 remains a valid choice.
- Preserve the crosshair version, existing character VFX, Ranger spread and curved shots, and the crowd optimizations from v2.49.1.
- Avoid a measurable performance regression in crowded gameplay. Do not promise a constant 60 FPS without evidence.

Deliver a separate playable macOS version using Godot 4.6.3, preserving the v2.49.1 app and ZIP. Work in the existing spirit-effects worktree; leave the primary checkout intact.

## Approach

Use one connected field with a compact defense corridor and three side districts. This keeps exploration and defense in the same world and supports short return paths. Merely enlarging the existing rectangle would add travel without distinct destinations. Separate maps would require loading and additional rules for shrine combat while the player is elsewhere.

Keep one enemy entrance, the existing 300-enemy active limit, five spawns per second, 300 enemies per wave, ten waves, and existing enemy roles. The larger map does not increase the enemy population or introduce roaming enemy simulation.

## Map layout and exploration

The expanded standard Fire Siege map uses a 320 by 480 metre playable rectangle, from x=-160 to 160 and z=50 to 530. This is approximately 3.1 times the current 160 by 310 metre area.

The central defense layout has:

- Enemy route: (0,110), (0,155), (0,195), (0,220), with all points at ground height.
- Shrine objective: (0,220), reducing the route from approximately 190 to 110 metres.
- Two defense stations at z=155 and z=195. Preserve the open corridor and clear tower work areas.
- Player start near (0,185), with clear approach and camera space.
- Hero and dog summon locations behind the rear defense station, separated from shrine attack positions and building footprints.
- Twelve tower sites, retaining eight approach sites and four forward parapet sites. Four mines remain available. Relocate sites that conflict with the new shrine court rather than deleting them.

The shrine objective is its visible energy altar in the main shrine compound. The pagoda stands behind it, with its foundation, windows, banners, lanterns, effects, and labels positioned relative to the objective. Enemies strike the altar; the health bar belongs to the whole shrine. Remove fixed z=300/331 assumptions from the expanded layout.

Districts:

| District | Approximate centre | Identity and exploration |
| --- | --- | --- |
| Sakura Grove | (-95,210) | Pink blossom canopy, stone lanterns, a small pavilion, and a winding loop with a direct path to the shrine court. |
| Neon Village | (95,240) | Dark timber and shoji forms, cyan and magenta trim, small alleys, and a clear return street. |
| Ruined Watchpost | (0,400) | Broken walls, bamboo, stone remnants, an open lookout clearing, and two paths back toward the shrine. |

Use low, walkable terrain and simple collision in this release. Make districts feel different through layout, silhouettes, ground treatments, and local emissive details. Do not introduce hills that require changing the current flat height contract. Decorative roofs and distant scenery do not block the enemy route.

Exploration reward: one supply cache per district, worth three gold, collected once per run during preparation by a living player approaching within 2.5 metres. Display the reward and collected state. Caches stay inactive during combat and cannot generate passive preparation income. Their collection flags reset on a new run and survive wave changes.

Keep existing hold-Y-for-three-seconds wave confirmation. Allow starting from anywhere; show the shrine direction and distance so the player can return first. Do not teleport the player, introduce an automatic wave timer, or pause active combat when the player leaves the defense corridor. Exploration is safe during preparation; wandering during a started wave leaves the shrine exposed.

## Shrine combat

Reuse the existing shrine health: 100 on normal difficulty and 50 on hard. Do not refill health between waves. The run ends when it reaches zero.

Replace the current Fire Siege arrival behavior, which removes an enemy and subtracts one HP, with admission into shrine combat. An arriving enemy remains alive, targetable by the player and towers, and counted in the wave's living population. Arrival itself causes no damage and grants no gold or kill credit.

A small shrine controller owns twelve attack positions around the energy altar at 5.5 metres radius. Positions must be inside clear floor space and outside structures. An enemy receives a free position when it reaches the final route segment and can start its strike clock within 1.25 metres of that position. Additional enemies wait around an outer ring at 10.5 metres radius; they do not overlap twelve enemies onto each position or attack through the queue. Waiting enemies remain killable and may fight a nearby player using their existing combat behavior. Freed positions are assigned in arrival order, with deterministic identity tie-breaking.

At its assigned position, an enemy faces the altar and uses a dedicated shrine attack clock:

- One HP damage every 2.5 seconds for all current ordinary Fire Siege roles.
- The first hit requires a full 2.5 seconds after reaching the position. Telegraph the final 0.65 seconds with the existing windup pose.
- A strike applies damage once and briefly uses the strike pose. Recovery and the next windup fit inside the next 2.5-second cycle.
- Player attack timings, cooldowns, dash movement, and player damage are unchanged. Shrine attacks must never call the player-damage path.
- Slow affects movement only; it delays arrival but does not alter shrine strike intervals.
- Stun or freezing cancels a pending shrine strike. On recovery, begin a fresh full interval. Knockback outside contact range releases the position and requires reacquisition.
- Pause suspends the clock. Hero death does not stop attacks on the shrine. Run termination, restart, or a retired wave invalidates all assignments and pending contacts.
- Revalidate living status, current generation, current wave ownership, position ownership, stun/freeze state, contact distance, and unobstructed contact before a hit. A stale or blocked contact deals no damage.
- Do not replay missed attacks after a long frame. At most one contact per attacker per update, followed by a fresh interval.

Use the Fire Siege director as the owner of shrine health changes and defeat transitions. Keep actor movement and animation in Ninja through a dedicated shrine adapter; keep slot allocation and strike clocks isolated from normal player combat. Both existing arrival entry points (`can_breach` in enemy physics and the inherited `lane_direction` arrival callback) must enter this same behavior without removing actors or double-applying damage.

The wave clears only after all scheduled enemies have spawned and all living enemies, including attackers and waiting enemies, are defeated. Preserve once-only death bookkeeping and rewards. Existing escaped-actor recovery must not reset a valid shrine assignment.

HUD changes: retain shrine HP, display the number actively attacking it, and use an under-attack warning at most once every three seconds. Do not label arrival as a kill or completed breach. Keep hit flashes and impact effects bounded rather than creating a full particle burst and banner for every attacker.

## Level 2 ice towers

Level 1 construction remains automatic while standing beside an affordable site. It costs five gold, takes three seconds, and retains the current 50-damage arrow, 48-metre range, and 0.5-second firing interval. Mine construction and income remain unchanged.

At a completed level 1 arrow tower, press F to explicitly upgrade for ten additional gold. The purchase is immediate and atomic, requires a living grounded player in the existing build range with clear access, and is valid during preparation or combat. Show the price and conversion before the action. Insufficient funds, input repetition, an inaccessible tower, an already-level-2 tower, or a stale run cannot charge gold or apply a second upgrade. Upgrade acquisition must find completed level 1 towers independently of the unfinished-site search.

Level 2:

- Replaces damaging arrows with ice bolts; damage is exactly zero.
- Retains 48-metre range and fires once per second at a valid target.
- Applies a 0.6 movement multiplier for two seconds through the existing `apply_defense_slow` interface.
- Repeated hits refresh the effect; multiple ice towers do not multiply the slow or accumulate duration. Preserve existing boss resistance for modes that include bosses.
- Uses the existing 0.10 gold/second upkeep. Conversion does not add another tower to the powered count.
- Does not call `take_hit(0)`, cause hit reactions or stun, award damage credit, kill enemies, or grant kill rewards.
- Obstruction blocks the projectile and its slow. Stale, dead, out-of-range launch targets, retired generations, or expired projectiles do not receive effects.
- Conversion clears in-flight arrows from that tower so no hidden damaging arrows remain after the displayed upgrade. New ice shots follow the same validated target ownership and obstruction rules.

Retain the supplied tower GLB and its build and aiming setup. Add a small procedural ice crystal and cyan material accents as an adapter rather than editing the protected model. Use shared ice meshes/materials, bounded short-lived impact geometry, and the existing slow ring. Do not add a particle emitter or light per target. Update tower labels, interaction prompts, and HUD totals to distinguish arrow and ice towers. Level 2 is final in this release; no conversion back or level 3.

## Components and compatibility

- `TowerDefenseWorld` remains the public source of bounds, routes, spawns, building sites, base position, landmarks, and height queries. An expanded-layout helper owns the standard map's coordinates and district construction. Preserve the old compact layout for other world modes.
- `NeonShrine` and `SpiritFortressEffects` consume layout anchors for the expanded world; their trim, floating scenery, fog, and shrine effects must stay aligned with actual geometry. Shared hero materials and protected models remain untouched.
- `FireSiege` owns economy, tower progression, shrine HP, wave population, and terminal state. It delegates shrine allocation and attack timing to a focused controller.
- `Ninja` delegates shrine-specific movement and poses through an adapter only for current Fire Siege actors. Normal combat, legacy tower defense, adventure, and survival retain their existing behavior.
- `FireSiegeStructure` retains construction, targeting, launcher animation, and projectile validation, with a clear level/attack-type interface. Ice impact and arrow damage are separate branches.
- District caches are static markers with bounded preparation-only checks, not independent per-frame simulations.

Existing custom map documents and the map builder retain their saved bounds, routes, and object schema. Custom Fire Siege maps receive shrine combat and ice upgrades using their authored objective and sites; do not move their shrine or expand them automatically. The shrine controller selects clear positions within their bounds and rejects blocked ones; a map with fewer legal contact positions uses only those available. Custom layout support must not introduce attack positions inside walls. Failed position searches remain bounded and cannot cause off-map teleports or shrine hits through cover.

## Performance design

Keep the current crowd motion staggering and cached projectile queries. Do not add per-enemy navigation agents, per-frame full-population neighbor searches, or extra physics probes for scenery.

Partition scenery into approximately 64–80 metre spatial batches with tight bounds. Use MultiMesh for repeated trees, lantern trim, fences, and rubble, shared materials, modest mesh detail, and distance culling. Keep no more than 160 decorative trees, 24 buildings/pavilions, and 32 rocks in the expanded map. Cap scene composition explicitly; do not scale content density blindly with area. Keep readable landmarks visible farther than small decorative details.

Preserve the existing directional shadow distance and quality presets. Give small emissive details and ice effects no additional shadows. Keep the current dynamic light and particle budgets; district color comes mainly from materials. Add no new shadow-casting local lights. Distant districts must not continue CPU particle simulation solely because their render mesh was hidden.

Manage shrine waiting and reassignment centrally at up to five checks per second; active attack clocks cover at most twelve enemies. Use only bounded contact checks near a scheduled hit. Do not rebuild slot geometry or allocate a new projectile resource each frame. Pool up to four ice projectile visuals per tower, retire shots after three seconds, and retire all shots on conversion, wave cleanup, and restart.

## Validation and release criteria

Behavioral checks must cover the new failure boundaries:

- Routes, spawns, summon markers, tower work spots, districts, and caches are inside bounds and traversable; the enemy path remains clear. Camera and Ranger air aim work throughout the field.
- Preparation has no spawning or shrine damage; Y still requires a deliberate three-second hold. Cache rewards are collected once per run and inactive during combat.
- Shrine arrival preserves the enemy and its wave count. First hit timing, repeated 2.5-second hits, twelve-position limit, queue turnover, defeat at zero, and once-only death credit work.
- Pause, stun, freeze, knockback, death, hero switching, restart, large delta, blocked contact, and stale-generation attacks cannot produce invalid shrine hits.
- Level 1 auto-build remains intact. F upgrades exactly once for ten gold, maintains the tower upkeep count, and clears old arrows. Ice impacts reduce actual movement without HP loss, hit reaction, or kill credit. Refresh, expiry, obstruction, and stale projectile cases work.
- Custom map routes and collision validation remain compatible. Legacy modes keep their arrival behavior. Run the relevant existing Fire Siege, structure, auto-build, state, custom-map, crowd motion, projectile, crosshair, Ranger flight/storm, and character VFX regression suites.

Measure foreground rendered performance on the user's M3/8 GB Mac with Godot 4.6.3, Medium quality, matching v2.49.1 window/render size, and the release PCK. Use warmed, reproducible runs and record focus; exclude unfocused samples and keep cold-start stalls separate. Run performance checks sequentially without competing benchmarks.

Compare two kinds of workload:

1. The same durable 300-enemy Mage/Ranger primary, ultimate, and Ranger air scenarios used for v2.49.1, placed in the new defense corridor with shrine damage neutralized only by the diagnostic harness so the test lasts long enough. Confirm all 300 remain simulated.
2. Real gameplay with normal enemy health and shrine attacks, twelve tower sites exercised, and a representative arrow/ice mixture; exercise all twelve heroes' primary and ultimate attacks plus Ranger air aiming. Also traverse all districts during preparation and a busy active wave, checking scenery culling and frame-time spikes.

For matched warmed combat, investigate and fix a reproducible mean frame-time regression above 5% or a p95 regression above 2 milliseconds. Report both figures and scene population, rather than asserting 60 FPS from the frame cap. Repeat only cases with a regression or unresolved concern. The earlier v2.49.1 all-hero run ranged from about 50.45 to 60 FPS, while durable Mage/Ranger cases were about 59.64–60.01 FPS; this release must be assessed against those practical limits.

Visually inspect all three districts, the shorter defense route, aligned shrine art and effects, tower level distinction, shrine attack poses, and crosshair framing. Inspect Low/Medium/High for readable gameplay and bounded effects. Verify source and packaged behavior, protected asset hashes, universal macOS architectures, ZIP integrity, and code signature. Keep build diagnostics separate from shipped gameplay.

Export a new versioned app/ZIP and release notes with the source commit and measured limitations. Do not overwrite v2.49.1, claim unmeasured native-executable FPS, push, publish a GitHub release, or merge without a separate user request.
