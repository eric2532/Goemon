# Fire Siege: ten waves and Blender flame validation

```sh
godot --headless --path . --fixed-fps 60 -- --defense-fire-test
godot --path . -- --defense-fire-visual
godot --path . -- --defense-fire-benchmark
```

The older `--tower-defense-beta-test`, `--tower-defense-beta-visual`, and `--tower-defense-beta-benchmark` flags now dispatch to this current suite. The historical single-wave performance report remains in `tests/tower-defense-beta/`.

The functional suite drives all ten actual 600-enemy rosters through the regular spawn and death paths. It verifies twelve seconds between waves, the 180-enemy cap, batches of at most eight arrivals, central-lane assignments, exactly 6,000 resolved enemies, victory only after wave ten, no eleventh wave, and complete retry reset. Every round checks the real capsule, visual model, maximum health, damage multiplier, and march speed against its configured growth. Opening- and final-wave enemies inflict actual melee damage on the hero, and the largest final-wave capsule is collision-tested through all six wall gaps at the center and both outer formation positions. `progression.json` records the measured progression.

The six wall lines contain twelve outer artillery guns and twelve inner flame towers. Checks exercise an actual F upgrade, imported Blender meshes, nine authored animation tracks, changing local mesh transforms, forward-cone damage, safe targets behind/outside the cone, physical cover blocking damage and shortening the visible jet, pause freezing flame damage and animation, and a flame kill paying one bounty without hero healing/progression exploits. The shared movement, pipe combo, hotkey attacks, Sky Strike, surge, gold-cloak flight, and Edo combat checks also run. Godot imports Blender's `flame_loop` name as `flame` because it consumes the `_loop` suffix; the runtime recognizes that imported name and explicitly enables looping.

The rendered performance fixture uses 180 real final-wave enemies at 1.9× size, durable health, normal AI, and all 24 mixed defenses distributed across the six stations. It requires all twelve fire towers and twelve artillery guns to fire during sampling and includes real flame damage pulses and Blender animation updates. After a 2.2-second warmup, it records approximately four seconds (120–480 frames) at 1280×800, quality 1, disabled VSync, and unlimited FPS. `performance.json` reports frame, process, physics, rendering CPU, and GPU timing, draw calls, peak nodes/shells/active flames, live population, damage pulses, and animation time. Unsupported GPU timing is marked unavailable.

2026-10-04: all 93 new headless functional checks passed with exit status 0 and no warnings or errors. The standard three-lane regression also passed all 59 checks after correcting the route recovery at its converging outer-lane bends. Imported flame meshes total 2,364 triangles with nine animated tracks. The final rendered functional run passed all 93 checks after refining the orange flame materials and jet proportions; screenshots show the distinct projector, live jet, blocked fire, final-wave enemy scale, and ten-wave victory.

The final stress benchmark completed without failed checks on Apple M3 using Godot 4.6.1, Forward Plus/Metal, 1280×800, and quality 1. Its 241 measured frames covered approximately four seconds after warmup:

| Metric | Result |
| --- | ---: |
| Real living wave-ten attackers | 180 throughout, at 1.9× size |
| Towers firing during measurement | 12 flame + 12 artillery |
| Mean frame / approximate FPS | 16.67 ms / 60 FPS |
| Frame p95 / maximum | 18.10 ms / 20.62 ms |
| Mean physics / rendering CPU | 3.50 ms / 1.05 ms |
| Real flame damage pulses | 216 |
| Accumulated Blender animation time | 26.4 seconds across the flame towers |
| Peak active flames / shells | 12 / 10 |
| Peak scene nodes | 2,139 |

See `performance.json` and `benchmark.log` for detailed frame, process, physics, and render measurements. GPU timing was unavailable from the Metal backend; the recorded zeros are explicitly marked unavailable. These are measured results for this machine and short stress fixture.

The independent natural-play soak used regular 60 Hz simulation, all 24 towers upgraded through purchases with the starting gold, and an inactive invincible hero outside the lane. With no forced damage or time skips, the defenses killed all 6,000 attackers, cleared all ten waves, preserved all 100 shrine health, and produced zero breaches or runtime warnings. The run covered 770.37 simulated seconds, held the live-enemy peak at 180, and peaked at 2,259 scene nodes. `natural-soak.json` and `natural-soak.log` preserve its per-wave results and fixture details.

Release 2.20.0 was exported as a universal macOS application, passed strict deep code-signature verification, and opened successfully from `build/Goemon.app`; its main menu visibly offers Tower Defense / Fire Siege. A 1,800-frame accelerated boot of the packaged defense mode found no script or missing-resource errors. Forced headless shutdown reports the existing dummy-renderer shader RID/audio resource cleanup warnings; the orderly functional, rendered, and natural-soak runs exit cleanly. The previous 2.19.1 app is preserved in `build/Other Files/Goemon-before-Fire-Siege-2.19.1.app`.
