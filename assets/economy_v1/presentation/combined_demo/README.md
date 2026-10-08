# FireSiege · actual-model construction demo

This separate Blender scene places the delivered arrow tower and gold mine beside each other, using the shared progress bar, B prompt, hammer, and geometry-based gold completion pulse.

The six-second presentation shows building, release/decay, resumed building, and completion. The actual construction models are scrubbed from the same normalized progress value as their bars. Timing is illustrative only. No game code, cost handling, input system, wave system, or gameplay project is included or modified.

- `FireSiege_Combined_Construction_Demo.blend`: editable self-contained presentation scene
- `previews/FS_Combined_Construction_Hero.png`: completed models and completion feedback
- `previews/FS_Combined_Construction_Preview.mp4`: short animated demonstration
- `qa/source_manifest.json`: exact source file hashes and source animation ranges
- `scripts/`: reproducible Blender setup and rendering scripts

The original tower, mine, and four clean FX GLBs remain the runtime assets. This assembled demonstration is a presentation artifact, not a replacement runtime scene. The mine's work, reverse-build, and upgrade clips and the tower's recoil are intentionally omitted from the demonstration.

## Validation

Both bars were checked at normalized progress 0, 0.7, 0.4, and 1. Model visibility follows the same construction sampling, including the release reversal. Both completion ring morphs were checked hidden at start, visible during the pulse, and hidden at the end. Source hashes were verified against the final model exports before rendering.

## Current reference metadata

The combined scene records base mine income of 2 gold/second during combat only, and L1 tower cadence of one arrow every 0.5 seconds at 50 damage. Setup and pause income remain zero. These are reference metadata, not implemented game behavior; the presentation timing is still illustrative. A metadata-only refresh copied the corrected source root properties, with geometry, animation, materials, camera, lighting, and preview artwork unchanged.
