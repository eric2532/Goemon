# Forest Shrine tests

Run checks from the source checkout being changed. The desktop game launchers point at the complete painterly source; see [the project README](../../README.md).

These are test entry points, not a record of the current build passing. Read each script's setup and flags before running it. Some older fixtures encode historical maps or balance defaults; assess failures against the behavior being changed.

## Focused checks

Automatic Guard/Cannon Towers:

```sh
godot --headless --path . --script res://tests/forest-shrine/automatic_towers_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/human_cannon_tower_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/human_cannon_tower_test.gd -- --large
```

Checks empty-tower volleys, worker reservations, cooldowns, saved volley settings,
team upgrades, visibility/death guards and map restart. The graphical fixture
checks actual native Guard/Cannon hits, unchanged splash/cover and repeated
16-shell presentation with stable node/resource counts. Logs for the worker-free
change are under `build/Other Files/Automatic Towers/`; rendered captures remain
under `build/Other Files/Asset Toolkit/Human Cannon Tower/`.

Editor navigation, entry/discard and palette switching:

```sh
godot --headless --path . --script res://tests/forest-shrine/map_editor_navigation_document_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/map_editor_navigation_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/map_editor_navigation_test.gd -- --large --live
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/map_editor_navigation_test.gd -- --large --entry-only
```

The document fixture compares road/portal local checks with complete validation,
including both map sizes, scenery/gates/edges, limits, atomic commits, saved-picker
validation and canonical asset-cache aliases. The desktop fixture measures actual
pan frames, all 22 palette hotkeys and repeated pinch input. `--live` retains the
normal game process plus a timed editor probe; otherwise it times the editor
callback directly. `--entry-only` checks repeated open/discard, restored run data,
scene reuse and bounded resources. `--layout=/absolute/path.json` reads a specific
map without writing it; `--saved` prefixes that run's output filenames. `--baseline`
labels reference captures and skips new-path timing/reuse assertions; it does not
restore old production code. Capture/log/JSON output belongs under
`build/Other Files/Map Editor Navigation/`. GPU timing may be unavailable; preserve
frame outliers and other desktop load when reporting results.

Building edit responsiveness and shared editor zoom:

```sh
godot --headless --path . --script res://tests/forest-shrine/map_editor_responsiveness_test.gd -- --document-only
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/map_editor_responsiveness_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/map_editor_responsiveness_test.gd -- --large
```

Checks local/full building validation agreement, all five building types and
rotations, incremental/fresh navigation grids and weights, normal worker release,
retained terrain/structures/scenery, local plant clearance and exact restoration,
physical collision, undo/redo/delete, native Play map, bounded repeated edits, wheel/fractional
scroll/pinch/trackpad/+− input and text/UI/modal guards. Desktop runs capture the
building and close view. Reports belong under
`build/Other Files/Map Editor Responsiveness/`; operation timings are not FPS.

Terrain-module placement stalls and local refresh parity:

```sh
godot --headless --path . --script res://tests/forest-shrine/terrain_edit_reuse_test.gd
"/Users/eric/Desktop/Play Goemon.command" --audio-driver Dummy --script res://tests/forest-shrine/terrain_placement_performance_test.gd
"/Users/eric/Desktop/Play Goemon.command" --audio-driver Dummy --script res://tests/forest-shrine/terrain_placement_performance_test.gd -- --large
```

Compares incremental terrain edits with a complete model, including every team's
navigation grid, exact native terrain/obstacles, stacked scenery and distant cliff
cache retention. Live runs time actual placement validation, refresh, deletion and
next rendered frame; check retained base terrain/collision, local foliage,
bounded nodes/materials/resources and discard restoration. Reports belong under
`build/Other Files/Asset Toolkit/Modular Environment/`. `--baseline` labels a
reference and skips new reuse assertions; it does not restore old source. These
are edit latencies, not full-army FPS. Use the palette and modular fixtures for
interactive rotation/height/save/restart and player/native traversal coverage.

Expanded scenery catalog and meadow-style tree variants:

```sh
godot --headless --path . --script res://tests/forest-shrine/map_catalog_test.gd -- --document-only
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/map_catalog_test.gd -- --visual
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/map_catalog_test.gd -- --visual --large
```

Checks all thirteen additions, source mesh roots, batching/material contracts,
meadow canopy/wind, data allowlisting, adjacent rotated module edges, actual grid
hotkeys/placement/selection/resize/rotation, physical/native blockers, save/load,
delete/history, restart, native play and bounded repeated edits. Visual runs
capture all three tree forms and a ground-level active-game view. Asset audits,
protected source hashes, staged lossless passes and captures are under
`build/Other Files/Asset Toolkit/Map Catalog/`. The first failed fixtures are
retained diagnostics: roof hits exposed incorrect selection coordinates, and
an enlarged fence needed its clear rotation before its size change.

Map scenery authoring and editor responsiveness:

```sh
godot --headless --path . --script res://tests/forest-shrine/map_scenery_test.gd -- --document-only
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/map_scenery_test.gd -- --visual --profile
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/map_scenery_test.gd -- --visual --profile --large
```

Checks all nine number keys, keypad selection, page switching and empty slots,
text-focus protection, real placement/selection input, size/rotation, overlap/boundary rejection,
old map compatibility, local/full preview validation agreement, incremental/full
navigation agreement, unchanged scenery chunks, bounded repeated edits, save/load,
Play map, restart, both native teams' blockers and toolbar fit at three sizes.
The fixture uses temporary preferences/maps, avoids stealing keyboard focus and
forces its capture draws so a hidden window does not hang on a draw signal.
`--profile` times the previous full refresh operation on the same layout alongside
new scenery edits; these are edit latencies, not whole-game FPS measurements.
Logs and inspected captures belong under `build/Other Files/Map Scenery/`.

Simultaneous native ally crescent stress test:

```sh
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/crescent_battle_benchmark.gd -- --per-team=240 --allies=120 --duration=120 --scenario=open --map=wind_meadow_large --await-focus --profile-spikes "--out=/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Asset Toolkit/Crescent Battle/Repeat"
```

Maintains 240 enemies, 96 regular allies and 24 full hero allies through the
existing native lifecycle and pooled legendary owner. Three each of Goemon,
Musashi, Ben, Sasuke, Yae, Kojiro, Blademaster and Illidan keep their normal stats,
AI, attacks and approved effects. The inherited benchmark checks frame-time
thresholds, population, event delivery, simulation time and unchanged inputs;
the extra report records simultaneous attacks/crescents and per-second resources.
Keep the window foreground and avoid other profiling/tests during measurement.
The current 24-hero result fails the smoothness thresholds; see the fresh evidence
and remaining limits in [the performance guide](../../docs/goemon-performance-guide.md).
`army_retirement_test.gd` protects bounded queries between death and facade cleanup.

With `--await-focus`, both simulation owners pause during focus loss. Reports keep
active `measurement_seconds`, total `wall_seconds` and `focus_wait_seconds` separate;
acceptance verifies their accounting and rejects any `changed_inputs`. The focused
`army_benchmark_coverage_test.gd` and `benchmark_focus_hold_test.gd` cover these gates.

`goemon_hit_frame_cache_test.gd` and `kojiro_cosmetic_updates_test.gd` compare the
prepared effects with their reference behavior; desktop runs add pixel comparisons.
`shared_sphere_test.gd` checks geometry/material isolation, and
`warcraft_material_updates_test.gd` checks original opacity and texture pages.
`melee_assist_local_test.gd` compares acquisition/order/retention against a full
240-enemy scan. Its standalone native-query shutdown warnings also occur in the
existing `army_candidate_marshalling_test.gd`; they are not counted as clean exits.

Illidan AI form commitment:

```sh
godot --headless --path . --script res://tests/forest-shrine/illidan_ai_form_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/illidan_ai_form_test.gd
```

Checks both manual Meta toggles, both AI toggle inputs during cooldown, five
native recruits making repeated random choices, real bolt damage, bounded pool
reuse, retirement and body reuse. AI transforms once and redirects later form
requests to its existing bolt attack. Evidence belongs under
`build/Other Files/Asset Toolkit/Illidan AI/`. This is a behavior regression,
not a full-army performance benchmark.

Statue-only presets and nearby ally attack audio:

```sh
"/Users/eric/Desktop/Play Goemon.command" --headless --script res://tests/forest-shrine/nearby_ally_audio_test.gd
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/nearby_ally_audio_test.gd
```

Checks both preset building lists, custom-tower preservation, the 15-metre
player/source boundary (including height), global and native ally cues, paired
voices, delayed/held spell ownership and repeated bounded reuse. The desktop
run also captures the actual nearby/distant SFX mix and statue-only opening
under `build/Other Files/Ally Audio/`. It is not a full-army performance test.

Enemy Skullpion statue objectives:

```sh
godot --headless --path . --script res://tests/forest-shrine/enemy_statue_model_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/enemy_castle_damage_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/enemy_castle_damage_test.gd -- --large
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/enemy_castle_placement_test.gd -- --visual
```

The model test proves source hashes, posed triangles and rotated statue bounds.
The castle fixture uses real melee/bullets, repeated hits, independent wall
breaches, destruction, collision removal, victory and restart. Placement covers
the shared statue ghost, new objectives, save/reload and enlarged maps. The
placement site is outside the raised castle's side stairs. Logs and sculpture
captures belong in `build/Other Files/Asset Toolkit/Skullpion Statue/`; battle
captures use `Asset Toolkit/Wind Meadow/Castle Breaches/` beneath Other Files.
These short fixtures do not establish full-army or long-session performance.

Musashi recovered sword techniques and one-press skills:

```sh
godot --headless --path . --script res://tests/forest-shrine/musashi_techniques_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/musashi_techniques_test.gd
```

Uses the current Wind Meadow terrain and native enemy contacts. Checks X Slash,
Tenderize and Desperado body phases, default keys 1–3, reassigned slots, miss and
interruption behavior, repeated use, and five allies executing mixed combos.
Captures and logs belong under `build/Other Files/Asset Toolkit/Musashi Techniques/`.
Manual player-step timings and physics callback intervals are diagnostics, not
rendered frame-time measurements or a full-army smoothness benchmark.
Run `musashi_assimilation_test.gd` and `numbered_skills_test.gd` after changing
the hotbar; existing assimilated skills remain selectable through Skills & Jump.

Equippable Musashi Leaping Strike:

```sh
godot --headless --path . --script res://tests/forest-shrine/musashi_leaping_strike_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/musashi_leaping_strike_test.gd
```

Checks manual double jumping, airborne attack overrides, ground attacks, native
enemy damage, landing, unequipping and interruption, Goemon/Rogue borrowing,
twelve repeated casts and five simultaneous native allies. Rendered captures
and logs belong in `build/Other Files/Asset Toolkit/Musashi Leaping Strike/`.

Raised castle courtyard and four side stairs:

```sh
godot --headless --path . --script res://tests/forest-shrine/raised_castle_test.gd
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/raised_castle_test.gd
```

Both sizes verify the 124.8-metre-wide courtyard at 41.6 metres elevation
(30% larger in each horizontal dimension and 30% higher), unchanged outer terrain and wall bases,
raised structures, disabled doors, saved-map compatibility, editor round trips
and map expansion. All six ordinary enemy types climb from every side, enter and
damage the actual shrine through native targeting, without manual movement goals.
The real player controller walks up every staircase without jumping. Desktop
captures and short simulation diagnostics go under
`build/Other Files/Castle Side Stairs/`; these are not full-battle frame timings.

Random map reinforcements (up to three ordinary enemies each second, alongside castle arrivals):

```sh
godot --headless --path . --script res://tests/forest-shrine/random_enemy_spawn_test.gd
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/random_enemy_spawn_test.gd -- --visual
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/random_enemy_spawn_test.gd -- --visual --large
```

The fixture checks timing, all ordinary roster types, exact counts, blocked
placement, shared capacity, pause and older saved castles with closed gates.
Desktop checks collect at least thirty mixed arrivals within twenty attempts,
cover all four quadrants including off-road ground, and require every native
enemy to attack real castle defenses. Blocked ground can reduce or defer a group.
Five identical spawn/retire cycles after a warm-up check reuse of the
existing spatial render batches and idle node/resource counts. Castle targets
stay alive for route verification. Timings are manually stepped diagnostics,
not full-battle frame times. Current captures/reports go under
`build/Other Files/Random Enemy Spawns/Anywhere/`; diagnostic logs are in
`build/Other Files/Random Enemy Spawns/raised-castle/`.
The castle group fixture isolates its own release gates with a stopped map-arrival
clock; the random-arrival fixture verifies both sources share one roster.

Kill reinforcements (each native enemy defeat adds two random ordinary enemies):

```sh
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/kill_reinforcements_test.gd
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/kill_reinforcements_test.gd -- --large
```

The fixture covers actual native kills, another generation from a spawned enemy,
simultaneous deaths, nonlethal/duplicate hits, ally deaths, cleanup, pause/reset,
blocked/partial placement, capacity retries and unchanged scheduled wave counts.
It verifies supported routes on both real map sizes and repeated spawn/retire reuse.
Evidence goes under `build/Other Files/Kill Reinforcements/`. Placement timings
are focused diagnostics, not a full-battle frame-rate or long-session benchmark.
The fixed-roster army benchmark clears this gameplay queue when replacing deaths
so its historical unit-count contract stays explicit.

Permanent card heroes defending the castle and hills across a wave reset:

```sh
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/legendary_hero_hunting_test.gd
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/legendary_hero_hunting_test.gd -- --large
```

Both sizes summon all five heroes through the actual card choice, verify native
outside-area rejection, hill-intruder acquisition, attacks/damage, reacquisition
after preparation and return home when a live target escapes. Captures and short
stepped CPU/resource reports go under `build/Other Files/Castle Defense AI/`
with the `Heroes-` prefix. This is not a full-battle
frame-time benchmark. The native `mirror_test.cpp` also covers wave persistence,
temporary-skill waiting and pursuit around cover on a hill at 20/30/60 Hz.

Paid mercenaries defending the castle and four hills on real Wind Meadow routes:

```sh
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/mercenary_hunting_test.gd
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/mercenary_hunting_test.gd -- --large
```

The fixture recruits all five kits, rejects distant enemies, verifies fresh damage
at each hill approach and checks return to castle posts and preparation. It
retains Ninja executions and replenishes the frozen soldier when needed. Short
stepped CPU timings and idle resource checks are focused diagnostics, not
full-battle frame times. Captures and reports go under
`build/Other Files/Castle Defense AI/`. `enemy_castle_pathing_test.gd` also checks
baseward progress, player interception and resuming shrine damage after the
player becomes untargetable. Closed gates and military buildings are tested when
present in the selected layout; the current open raised castle has neither.

Core state and map serialization:

```sh
godot --headless --path . --script tests/forest-shrine/model_test.gd
godot --headless --path . --script tests/forest-shrine/map_document_test.gd -- --test
```

Choose additional `*_test.gd` scripts for the affected feature. Native render, captured-pointer, shader, and visual checks require a real window. The commands retained below include both headless and native variants; they are alternatives, not a mandatory full-suite sequence.

Shared footstep cadence, including extreme movement speed and desktop audio:

```sh
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/footstep_cadence_test.gd
```

This checks the .30-second per-Hero audio limit without changing movement or
source samples. Recordings and logs go under
`build/Other Files/Asset Toolkit/Footstep Speed Limit/`.

Wave settings edited from the building map apply on START; edits during battle
apply to the next run. The focused fixture uses an isolated settings file and
checks actual UI edits, persistence, exact first-wave types/counts, native arrivals,
group settings, the countdown and active-run isolation:

```sh
godot --headless --path . --script res://tests/forest-shrine/wave_settings_test.gd
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/wave_settings_test.gd
```

Evidence goes under `build/Other Files/Asset Toolkit/Wave Settings/`.

Timed waves and the top-center countdown (first arrival on START, then every 60 seconds):

```sh
godot --headless --path . --script res://tests/forest-shrine/wave_timer_test.gd
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/wave_timer_test.gd -- --visual
```

The desktop fixture advances the real schedule through four arrivals, verifies native
ownership, pause and balance updates, and captures two window sizes/HUD scales.
It does not run a four-minute battle or measure full-army performance. Evidence goes
under `build/Other Files/Asset Toolkit/Wave Timer/`.

Team leveling and rendered card/reset acceptance:

```sh
godot --headless --path . --script res://tests/forest-shrine/team_progression_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/team_leveling_gameplay_test.gd
```

The [team leveling spec](../../docs/team-leveling-spec.md) records the initial
curve, shared bonuses, and reset semantics. Logs and captures belong under
`build/Other Files/Team Leveling/`.

## Human Cannon Tower

```sh
godot --headless --path . --script res://tests/forest-shrine/human_cannon_tower_test.gd
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/human_cannon_tower_test.gd
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/human_cannon_tower_test.gd -- --large
```

Checks the original sound bytes/imported PCM, both Human tower choices, placement,
worker garrison/repair/release, native splash bands and cover, actual worker firing,
target death during flight, upgrades, map roundtrip, pause and repeated pooled
volleys. Desktop runs capture the model, build menu and original missile burst.
The short manually stepped 16-shell volleys report frame/work timings and resource
counts; they are not a full-army or long-session benchmark. Evidence is under
`build/Other Files/Asset Toolkit/Human Cannon Tower/`.

## Dark Lumina 3 Water bubbles

Run `/Users/eric/Desktop/Play Goemon.command --script res://tests/forest-shrine/dark_lumina_3_water_test.gd`.
Checks floor/enemy contacts, silent expiry for both bubble generations, five radial
children on parent contact, secondary contact pops, pooled state reset, numbered
and borrowed Water, and nine accelerated ground/airborne volleys. Captures and
allocation/frame diagnostics go to `build/Other Files/Asset Toolkit/Dark Lumina 3/Water Contact/`.
The standalone `native/terrain_math/crowd/dark_lumina_3_test.cpp` also checks six
simultaneous bosses at 20/30/60 Hz: primary expiry, ground splits with silent child
expiry, and child wall contacts.

## Existing command reference

```sh
godot --headless --path . --script tests/forest-shrine/portals_roads_test.gd -- --test
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/portal_editor_test.gd -- --test
godot --path . --resolution 960x600 --fixed-fps 60 --script tests/forest-shrine/portal_editor_test.gd -- --test --visual
godot --headless --path . --script tests/forest-shrine/map_document_test.gd -- --test
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/map_editor_test.gd -- --test
godot --path . --resolution 960x600 --fixed-fps 60 --script tests/forest-shrine/map_editor_test.gd -- --test --visual
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/ddii_combat_view_test.gd -- --test
godot --path . --fixed-fps 60 --script tests/forest-shrine/ddii_combat_view_test.gd -- --test --visual
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/crosshair_preference_test.gd -- --test
godot --path . --fixed-fps 60 --script tests/forest-shrine/crosshair_preference_test.gd -- --test --visual
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/view_settings_test.gd -- --test
godot --path . --fixed-fps 60 --script tests/forest-shrine/view_settings_test.gd -- --test --visual
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/character_framing_test.gd -- --test
godot --path . --fixed-fps 60 --script tests/forest-shrine/character_framing_test.gd -- --test --visual
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/ninja_hit_drift_test.gd -- --test
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/training_dummy_test.gd -- --test
godot --path . --fixed-fps 60 --script tests/forest-shrine/training_dummy_test.gd -- --visual
godot --headless --path . --script tests/forest-shrine/compact_loadout_hud_test.gd -- --test
godot --path . --script tests/forest-shrine/compact_loadout_hud_test.gd -- --visual
godot --headless --path . --script tests/forest-shrine/hud_cleanup_test.gd -- --test
godot --headless --path . --script tests/forest-shrine/hud_polish_test.gd -- --test
godot --headless --path . --script tests/forest-shrine/low_fidelity_enemies_test.gd -- --test
godot --path . --script tests/forest-shrine/low_fidelity_enemies_test.gd -- --test
godot --path . --script tests/forest-shrine/dense_crowd_profile.gd -- --test --out=/tmp/forest-low-fidelity-profile
godot --headless --path . --script tests/forest-shrine/melee_responsiveness_test.gd -- --test
godot --path . --script tests/forest-shrine/melee_responsiveness_test.gd -- --test --visual
godot --headless --path . --script tests/forest-shrine/core_balance_test.gd -- --test
godot --headless --path . --script tests/forest-shrine/preparation_actions_test.gd -- --test
godot --path . --script tests/forest-shrine/preparation_actions_test.gd -- --test --visual
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/hud_polish_test.gd -- --test
godot --path . --script tests/forest-shrine/hud_portrait_render_test.gd -- --test
godot --path . --script tests/forest-shrine/hud_polish_tour.gd -- --test
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/hud_cleanup_test.gd -- --test
godot --path . --script tests/forest-shrine/hud_cleanup_tour.gd -- --test
godot --headless --path . --script tests/forest-shrine/south_spawn_test.gd
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/starter_fort_test.gd
godot --path . --script tests/forest-shrine/starter_fort_render_test.gd -- --test
godot --path . --script tests/forest-shrine/starter_fort_tour.gd -- --test
godot --headless --path . --script tests/forest-shrine/giant_staging_performance_test.gd
godot --headless --path . --script tests/forest-shrine/enemy_contact_performance_test.gd
godot --path . --script tests/forest-shrine/enemy_spawn_performance_test.gd -- --test
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
godot --headless --path . -- --tower-defense-test
godot --headless --path . -- --rogue-siege-tests
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/crosshair_test.gd
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/modern_combat_test.gd
godot --path . --script tests/forest-shrine/crosshair_tour.gd
godot --headless --path . --script tests/forest-shrine/enemy_roles_test.gd
godot --headless --path . --script tests/forest-shrine/enemy_visual_test.gd
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/enemy_contact_test.gd -- --test
godot --headless --path . --script tests/forest-shrine/enemy_integration_test.gd
godot --path . --script tests/forest-shrine/enemy_integration_tour.gd -- --visual
```

Check assertion/result markers, process exit status, and Godot script/render errors. A historical pass count or screenshot is not proof that the current source passes. Store newly generated captures, logs, and reports in `build/Other Files/` when the harness supports an output path. Keep bundled presets, custom maps, preferences, and user recordings intact.

Combined attack presentation: run `combined_attack_layers_test.gd` for original
quads, palettes, compact-weapon sampling, repeated resource reuse and all 83 bake
hashes. Run `strong_melee_brush_test.gd` through Play Goemon for the 19 melee
presentations and native ally repeats. `--fighters=28` also checks Kojiro's three
forward cuts across facing, reach and frame-rate cases, rear-windup suppression,
rendered outer-edge direction and retained glow.
`--output=res://build/Other Files/Asset Toolkit/Roster Combined/` selects the
current evidence folder; run without `--headless` for captures.

24-hero follow-up: `crescent_battle_benchmark.gd` keeps 24 pooled full heroes
among 120 allies against 240 enemies. Its fixture-only fixed logical IDs retain
native AI seeds across allocation changes. Live combat still depends on render
cadence: do not present separate runs as a controlled percentage speedup. Run
through Play Goemon, `-- --per-team=240 --allies=120 --duration=120 --scenario=open
--map=wind_meadow_large --await-focus --profile-spikes --out=<absolute folder>`.
`--diagnostic` saves failures with exit zero; always inspect report errors.

`sky_strike_direction_test.gd` covers overlapping-target facing/landing.
`prepared_rom_pose_test.gd` checks exact prepared versus original JSON sampling.
`character_profile_keys_test.gd` checks cached keys and live profile edits.
`kojiro_cosmetic_updates_test.gd` compares original cosmetic motion, pooling and
atlas cells; run through Play Goemon for reference pixel comparisons. Its
headless pass covers logic, not rendering or smoothness.
