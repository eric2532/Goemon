# Sparse sky layout and performance checks

2026-10-02, Godot 4.6.1, Apple M3, Metal Forward+.

The sky now contains 784 islands, 308 connecting routes (22 per layer,
previously 1,358), and 1,025 physical cloud platforms (previously 3,500).
A local fixed seed varies island positions, crossing angles and widths, and
resting-cloud placement. Routes have at most two links per island and leave
unconnected islands for flight or descent. The first crossing remains available.

Enemy creation is queued and capped at four actors per director tick. The
rosters and defeat records remain immediate; unloaded islands keep their state.
HUD nearby-island searches refresh every 0.2 seconds or immediately after a
move exceeding 20 metres. Distance sorting computes each distance once;
island queries skip unrelated altitude layers. Panel StyleBox resources are cached.

## Rendered measurements

Run `godot --path . --script res://scripts/sky_performance_audit.gd -- --label=after`.
The audit uses active AI, three destination island/ground scenarios, 45 warm-up
frames and 180 measured frames per scenario. Reinforcements are postponed for
comparable actor populations. Camera heading matches the original layout's
starting heading; the revised layout changes world positions and surrounding
geometry. Vsync is requested off, and the frame cap is disabled. Desktop window
scheduling and live AI can affect timings. These are short representative runs,
not a controlled GPU benchmark.

| Scenario | Mean before / after (ms) | P95 before / after (ms) | Draw calls before / after | Nodes before / after |
| --- | --- | --- | --- | --- |
| Dawn, active AI | 11.49 / 17.23 | 20.97 / 19.24 | 896 / 786 | 33,304 / 23,417 |
| Middle sky, active AI | 11.64 / 16.69 | 19.20 / 18.47 | 1,107 / 1,026 | 33,387 / 23,519 |
| Ground, active AI | 11.53 / 16.67 | 19.81 / 20.51 | 1,060 / 991 | 33,330 / 23,455 |

Cloud count fell 71% and node count fell about 30%. Draw calls were lower in
these views. Sky P95 improved slightly, but average frame time increased and
ground P95 worsened. **These measurements do not establish an FPS gain.**
Do not present reduced object counts as a measured frame-rate improvement.
The raw JSON and screenshots are local ignored diagnostics in this directory.

## Gameplay validation

- `--descent-test`: all island/cloud collision surfaces, real walking and jumping
  across the initial route, landing across layers/map corners, defeat persistence,
  deterministic retries, freefall, ground giants and progression.
- `--flight-test`: sparse route degree/altitude/angle checks, complete surface
  coverage, bounded queued actor creation, flight and boost, pause, cape switching,
  cross-map encounter loading and returning from ground.
- `--district-test`: reinforcement and clear rules, actor limits, real AI pursuit
  and damage, all six furnished building entrances/cutaways, and ground giants.

For additional GPU headroom, the existing Settings quality selector offers
“Performance · no shadows” (also disables MSAA, SSAO and glow). A next profiling
pass should compare stationary views at fixed render resolution and sample CPU
and GPU timings separately before changing distant-detail batching or shadows.
