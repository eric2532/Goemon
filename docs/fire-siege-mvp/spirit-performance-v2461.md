# Spirit Fortress effects audit · v2.46.1

The report of lag throughout gameplay prompted a comparison with the preserved
v2.45 and v2.46 applications. The previous acceptance checks verified behavior
and rendering, but did not establish a performance baseline.

## Findings and fixes

| Technique | Audit result |
| --- | --- |
| Emission and glow | Glow was already enabled in v2.45. The integration modestly changes intensity and HDR threshold; Low disables the post effect. |
| Accent lighting | At most five distance-faded omni lights; only the shrine light casts shadows on High. Medium adds no omni shadow maps. |
| CPU particles | 116 bounded particles, with no accumulating emitters. The original lifetime alpha was ignored because vertex colors were disabled on the material. v2.46.1 enables vertex colors. |
| Depth fog | Native depth fog replaces existing exponential fog; volumetric fog is not enabled. Low restores the current worlds' original fog mode. |
| Water and foam | Two opaque shader planes, with no screen-copy refraction or transparency. v2.46.1 removes their unnecessary shadow passes. |
| Banner wind | Opaque custom vertex shader. v2.46.1 shares meshes by size and materials by color, permitting Forward+ instancing and updating each material clock once. |
| Floating stones | Six simple transforms and low-detail meshes. v2.46.1 removes decorative shadow casting. |
| Rune pulses | A few emissive meshes. v2.46.1 removes the pulse's opaque shadow, which previously persisted while the visible mesh faded. |

Particle automatic bounds are valid. Hiding the effects parent on Low stops
CPU particle simulation, and pausing freezes clocks and animations. Restarting
or changing maps frees the old instance. An independent review found no
remaining actionable code issues after these fixes.

Godot documents the particle material's vertex-color requirement in
[CPUParticles3D](https://docs.godotengine.org/en/stable/classes/class_cpuparticles3d.html#class-cpuparticles3d-property-color-ramp).
Its [geometry transparency documentation](https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html#class-geometryinstance3d-property-transparency)
explains the transparent pipeline and retained shadows. Shared opaque mesh
and material resources permit [automatic instancing](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html#use-automatic-instancing).

## Measurement method and limits

Rendered probes run serially on the local Apple M3 with Metal Forward+,
windowed at a requested 1280×800, VSync disabled, two seconds of warmup and
three seconds of samples per view. The report records the viewport texture size
as well as window size. Quality, camera and scene fixture are held constant
within each effects-on/off comparison. The 180/300 actor fixtures contain
real Ninja instances and the ordinary crowd renderer; the active fixture
resets actor positions before each sample and runs their physics.

The empty-map Medium views averaged approximately 7–8 ms in both preserved
versions. The original v2.46 active 300-actor fixture averaged 7.6–9.2 ms with
effects and 8.0 ms with effects disabled. A v2.45 fixture on Godot 4.6.1 averaged
7.4 ms. These short measurements overlap and do not reproduce a large
sustained slowdown throughout gameplay. They do not prove absence of lag in
long sessions, full-screen play, particular hero abilities or other workloads.

The High shrine shadow-isolation probe reduced its median draw count from
861 to 796 when only added decorative shadow casting was disabled. This
establishes avoidable rendering work, not a proportional FPS improvement.
The final exported v2.46.1 High build records 583 draws at spawn versus the
original build's 607, and 793 at the shrine versus about 861. Shrine geometry
falls from about 195,000 to 179,102 rendered primitives. The measured High
frame averages remain approximately 8 ms, with overlapping variation between
versions; the counter reductions do not establish that the reported lag is fixed.
With normal VSync, the 300-active-actor fixture on v2.45/Godot 4.6.1 averages
16.76 ms per frame; exported v2.46.1/Godot 4.6.3 averages 16.64–16.68 ms with
effects and 16.72 ms without. Both report a 1138×712 viewport texture within the requested
1280×800 window and sustain approximately 60 FPS in this short fixture.
The preserved original v2.46 also averages 16.73–16.76 ms with effects in the
same VSync fixture, so this comparison does not reproduce the original report.
The first Medium probe also recorded one 170 ms frame; its cause was not
isolated, so shader compilation is not asserted as the cause.

Metal returned zero for the measured GPU timer on this machine. GPU time is
therefore unavailable, not zero cost. Process/physics Performance monitors are
sampled by Godot at a lower rate and may retain startup values; use frame wall
time and rendering counters for the comparisons, not those stale values.

## Reproduction and verification

Run `scripts/spirit_fortress_performance.gd` with Godot 4.6.3 and an actual
renderer. It rejects headless rendering. For a preserved PCK, use the editor
executable with `--main-pack`, an absolute external `--script` path, and
`--output=/absolute/report.json`. Release-template executables do not allow
external script overrides.

```sh
Godot --path /absolute/project --script res://scripts/spirit_fortress_performance.gd -- --label=fixed-medium --output=/absolute/report.json
```

Add `--quality=2` for High, `--crowd` for 180 static actors, or
`--crowd --active --300` for 300 active actors. `--shadows` isolates decorative
shadow passes while preserving all other effects. `--vsync` keeps normal
VSync pacing instead of measuring uncapped capacity. Do not run benchmarks
concurrently with game instances, exports or tests.

Three new regression assertions failed against v2.46 and passed after the
fixes: particle fade material configuration, decorative shadow suppression,
and shared resources on identical banners. The existing tests still count
all three authored custom-map cloth instances, including rotated duplicates.
The full acceptance runner remains `tools/verify_spirit_fortress.py`.

Detailed logs, JSON measurements and final verification are under
`build/spirit-performance`; delivered evidence accompanies the new app.
