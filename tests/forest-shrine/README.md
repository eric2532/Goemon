# Forest Shrine tests

Run checks from the source checkout being changed. The desktop game launchers point at the complete painterly source; see [the project README](../../README.md).

These are test entry points, not a record of the current build passing. Read each script's setup and flags before running it. Some older fixtures encode historical maps or balance defaults; assess failures against the behavior being changed.

## Focused checks

Core state and map serialization:

```sh
godot --headless --path . --script tests/forest-shrine/model_test.gd
godot --headless --path . --script tests/forest-shrine/map_document_test.gd -- --test
```

Choose additional `*_test.gd` scripts for the affected feature. Native render, captured-pointer, shader, and visual checks require a real window. The commands retained below include both headless and native variants; they are alternatives, not a mandatory full-suite sequence.

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
