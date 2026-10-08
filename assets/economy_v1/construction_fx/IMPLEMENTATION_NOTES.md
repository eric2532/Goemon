# Construction feedback implementation notes

## Intended mechanic

The existing game controller, not these clips, must own normalized progress `p` in [0,1]. A valid nearby player stands in front of the site and holds B. Progress advances while the hold remains valid. Releasing B stops building and lets progress decay. Holding again resumes from the remaining value. Tower and mine purchase/upgrade share this visual interface. Spend gold only when the authoritative completion transaction succeeds.

Build seconds and decay tuning are not fixed by this asset pack. Range, front-facing tolerance, purchase/upgrade prices, and affordability/reservation behavior belong to the gameplay handoff and controller. The confirmed purchase prices are 5 gold for the tower and 10 gold for the mine; this pack contains no pricing logic. The preview contains arbitrary demonstration pacing only. No timing values in it are gameplay recommendations.

## Files and coordinate convention

| File | Root | Nodes of interest | Clip |
|---|---|---|---|
| `exports/FS_FX_Hammer_BuildLoop.glb` | `FX_HammerRoot` | `FX_HammerSwingPivot` | `Build_HammerLoop` |
| `exports/FS_FX_ProgressFrame.glb` | `FX_ProgressRoot` | `ProgressFill`, `Progress_Track` | None |
| `exports/FS_FX_BPrompt.glb` | `FX_BPromptRoot` | `BPrompt_Keycap`, `BPrompt_Letter` | None |
| `exports/FS_FX_CompletionPulse.glb` | `FX_CompletionRoot` | `Completion_OuterRing`, `Completion_InnerRing`, `Completion_Spark_01` … `10` | `Complete_GoldPulse` |

Blender units are meters, +Z up, −Y front, with each export root at its local origin. Standard glTF conversion makes +Y up and +Z front. Keep import scale at 1 initially; scale each complete FX root to the desired apparent size. Do not rescale only the hammer head or ring child.

The source `.blend` contains five scenes:

1. `01_Hammer_Loop` — isolated export source
2. `02_Progress_Frame` — isolated export source
3. `03_Optional_B_Prompt` — isolated export source
4. `04_Completion_Pulse` — isolated export source
5. `05_CONSTRUCTION_DEMO_illustrative` — studio, labelled placeholder pedestal, and illustrative state sequence

Only the four isolated sources are exported. The camera, studio lights, labels, pedestal, and demonstration keyframes are not in the GLBs.

## Progress bar and B prompt

- `FX_ProgressRoot` is a 2.2 m wide, 0.30 m high, 0.10 m deep frame; its front faces Blender −Y
- `ProgressFill` is 1.95 m wide at scale.x = 1
- The fill's mesh begins at its own local x = 0, and its parent-space left anchor is x = −0.975 m
- Set only the fill node's x scale to the clamped progress value. Leave its translation and other scale axes intact
- At exactly zero, hide the fill or use a tiny scale epsilon plus visibility false to avoid singular-transform issues in engines
- Increasing and decreasing p use the same property. There is no separate “decay animation,” and resuming must not reset the fill
- The bar should sit above the current construction/upgraded object and stay readable; billboard its complete root, not just the fill
- The optional B prompt is construction-only and is a separate GLB so touch/controller UIs can replace it without modifying the bar. A hold-Y wave-start confirmation can reuse the frame with its own label/input handling; do not reuse the B keycap for that interaction
- Show the B prompt when building is available. Hide it after completion; show the completed bar briefly or hide it according to the game's UI policy

The mine asset worker specified a build socket at Blender (0,0,3.2), and the completed tower is 3.785 m tall with a build socket at Blender (0,0,3.90). Resolve the current socket from the delivered model rather than hard-coding a world height. Parent the bar above the site, then move its local attachment height for stages/upgrades as needed.

## Hammer loop

- Full hammer extent is approximately 1.04 m tall and 0.65 m wide before animation; the preview scales its root to 0.7
- Root `FX_HammerRoot` is the attachment transform; `FX_HammerSwingPivot` is the local grip pivot
- Clip `Build_HammerLoop` lasts exactly 1.0 s with matching first and last poses
- The GLB contains only the pivot's rotation track. It does not include world movement or gameplay callbacks
- Loop only while a valid build/upgrade hold is active. Stop or fade it when released, out of range, facing away, blocked, or complete
- The visual hammer tempo is independent of the gameplay build duration. Do not map one swing to a cost or a progress increment
- Scrubbing or reversing the loop is possible, but is not necessary for decay. A stopped/hidden hammer is the clearer released state

## Completion pulse

- Root `FX_CompletionRoot` sits at ground center. Nominal outer ring radius is 1.5 m, expanding from approximately 0.9 m to 2.19 m over the clip
- Clip `Complete_GoldPulse` is a single 1.0 s one-shot, starting and ending with effectively invisible spark scale (0.00001) and collapsed ring thickness
- Zero-scale spark endpoints are avoided because Godot attempts to decompose their transforms during import; a visually negligible epsilon keeps the basis valid.
- Two ring meshes use the `ThinToZero` blend shape to reduce tube thickness to zero while their transforms expand the radius
- Ten spark meshes rise gently and shrink away. There are no explosion debris, physics, or particle emitters
- All dynamic channels are standard glTF translation, rotation, scale, and morph weights. There are no animated material properties
- The material uses gold base color plus constant emission. Bloom may be added by the engine, but is optional; the core ring/diamond geometry remains visible without it
- Choose a root scale that clears the model footprint. The default suits the tower; the larger mine may need a larger root scale
- Play exactly once after the completion transaction succeeds. Do not trigger merely because the bar visually reaches 100% or a demonstration clip ends
- Stop/hide or recycle the root after the clip finishes. Reset to clip time 0 before reusing it for a later upgrade

The rings require morph-target animation support. If the chosen renderer cannot import those weights, keep the morph-capable GLB as source and replace the ring presentation deliberately; do not silently ship permanently thick rings.

## Engine integration checklist (Godot 4 / equivalent)

Use the explicit GLBs rather than importing the multi-scene `.blend` into the game. Godot supports binary glTF; the files are self-contained and need no sidecar textures. Official reference: [Godot 4.3, available 3D formats](https://docs.godotengine.org/en/4.3/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html).

1. Import each GLB as a reusable visual scene and inspect its imported animation names
2. Set `Build_HammerLoop` to loop explicitly in the imported animation settings. Keep `Complete_GoldPulse` non-looping
3. Confirm that the completion animation includes both ring blend-shape tracks and all 10 spark transforms
4. Place visual instances under a gameplay-owned attachment node. Keep progress/currency/state logic out of imported assets
5. Find `ProgressFill` by a stable scene reference and drive its local x scale from authoritative normalized progress
6. Disable shadows/collision for the world-space bar and prompt if the game's visual style requires it; these are visual assets, not hitboxes
7. Test with bloom disabled, then with the target project's exposure/lighting. Avoid replacing the subtle gold cue with a large bloom flash
8. Check release → decay → resume, loss of eligibility, zero progress, simultaneous completion attempts, final affordability failure, repeated upgrades, and completion-trigger deduplication
9. Test billboard orientation and occlusion at actual gameplay camera angles

The exported structure and Blender re-import have been verified. A disposable Godot 4.6.3 headless project also parsed all four GLBs, generated their scenes, confirmed their clips and mesh counts, evaluated the hammer at 0, 0.5, and 1.0 seconds, and evaluated the completion clip at 0, 0.25, and 1.0 seconds. The hammer moves and returns to its exact starting orientation. The ring morph and spark scale correctly become visible and then disappear. This is asset-level engine verification; no target-game integration or gameplay run was performed.

## Reproducibility

`scripts/build_fx.py` rebuilds source scenes and GLBs with Blender 4.3.2. `scripts/verify_roundtrip.py` reimports each GLB into a fresh scene and writes the QA report. `scripts/render_previews.py` renders the source demo, with the PNG sequence sampled at 12 fps and encoded at 24 fps by duplicating frames. Scripts currently point to this package's original workspace; set `OUT` for another computer.

The installed Cycles build lacks OpenImageDenoise, so source-file Cycles denoising is disabled. Delivered previews use Eevee. This affects presentation rendering only, not the exported geometry or animation.
