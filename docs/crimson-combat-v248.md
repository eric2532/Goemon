# Fire Siege v2.48.0 — Samurai and roster VFX

Godot 4.6.3, following v2.47.0 on the existing isolated development branch.

## Play

Choose Samurai in the fighter selector. Hold LMB for left, right, diagonal,
forward and 180-degree turning cuts. Each cut commits its direction at start.
The narrow forward cut excludes side targets; the finisher covers a forward
semicircle. Releasing and waiting resets the combo; J automatic normal attacks
use the same five stages.

RMB / 3 launches a crimson energy arrow, roughly three times the utility
arrow's visual scale. It deals 150 base damage to each aligned target once,
pierces enemies, stops at solid terrain and has finite range. It uses the
existing 2.4-second secondary cooldown. E retains the ordinary 59-damage arrow.

R activates Crimson Overdrive for ten seconds. All five katana animation,
contact, recovery and hit-pause timings accelerate by five. An already committed
primary also accelerates. It does not accelerate movement or secondary/utility
cooldowns. The existing ultimate cooldown is 14 seconds. The red rim shader and
energy wisps disappear on expiration, death, hero switch or reset. Pause freezes
timers and shader clocks.

## Roster effects

The ten Rogue classes and Goemon share the upgraded moving-edge blade shader,
emissive projectile/thrust/impact materials and MultiMesh spark bursts. Their
existing palettes and weapon types remain distinct. All ten native ultimate
rims gain moving energy veins. Goemon's golden surge gains emissive flame bands;
Edo gains ember shells, flowing beam filaments and a patterned blue fire shield.
The approved GLB/Blender character art is untouched.

Spark bursts share one material and one mesh. A burst is one draw with six,
sixteen or twenty-four instances on Low, Medium or High. Transient effect entry
limits are 180/320/420; per effect frame impact presentation limits are 3/8/12.
Floating damage text is sampled at 3/8/12 labels per physics frame, with at
most 16/32/48 live labels. Every valid enemy still receives collision damage
regardless of either visual budget. The expensive text/tween allocation was
confirmed as the crowded ultimate slowdown: hiding existing labels reduced
draw calls but did not restore frame time; suppressing their creation in the
diagnostic fixture did. The production fix retains sampled damage text.
Extra shells and particles cast no shadows. Low keeps emissive silhouettes even
with environment glow disabled. Geometry caches remain bounded.

Shader emission feeds the existing Godot Forward+ glow setup. The relevant
engine documentation is [spatial shaders](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/spatial_shader.html)
and [environment/glow](https://docs.godotengine.org/en/4.6/tutorials/3d/environment_and_post_processing.html).

## Verification

`python3 tools/verify_spirit_fortress.py --godot <Godot-4.6.3> --output <directory>`
checks existing Fire Siege, equipment, auto attack, Ranger, map builder, Spirit,
neon and new Samurai combat. The added kit fixture exercises real input, poses,
enemy damage, obstruction, lifetime, manual/automatic sequencing and interruption.
Ten normal cuts take 3.961 seconds in the deterministic fixture; Overdrive takes
0.793 seconds. Regressions were first observed against the previous behavior.

Run `scripts/combat_vfx_tests.gd` with the actual rendered engine to verify spark
transform updates and budgets. A headless Dummy renderer does not retain
MultiMesh transform readback, so that visual test intentionally uses Metal.
`scripts/crimson_vfx_captures.gd` renders all twelve heroes and every Samurai cut
from the actual project. `scripts/crimson_vfx_performance.gd` records idle,
held primary and ultimate scenarios with 300 live enemies. See the distributed
PERFORMANCE.md and verification files for results and their limits.

The inherited headless shutdown resource diagnostics are recorded separately
from gameplay/script errors. Native app export, pack-level combat and rendered
VFX verification are required before delivery. Commits and exports stay local
unless explicitly published.
