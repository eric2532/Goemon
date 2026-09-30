# Goemon v2.14.0 — full ronin cloak

Blender garment revised against the supplied reference silhouette: a layered shoulder mantle and ankle-length wrap cover the torso and legs, retaining the crimson scarf tails, repairs and torn hems. Six meshes are exported. The original Goemon character master remains unchanged, verified by SHA-256 in blender-report.json. The reference is preserved in assets/references/ronin_cloak_user_reference.png.

Movement changes are limited to cloak-equipped Goemon:
- Visual stride cadence uses normal movement speed while gameplay still moves three times faster. Foot contact follows the boosted travel to avoid snapping/stretching short legs.
- Additional jumps use an upright tuck; original outfit and Edo retain their existing animation.
- The neckline remains fixed. Corrected Blender/glTF vertical UV inversion so weights drive hem and tail motion rather than lifting the collar.
- Lower panels billow against actual travel direction, including strafes; motion settles on stopping and through jumps. Shoulder coverage stays intact.

Validation:
- Rendered outfit suite: 32 passed.
- Motion suite: 4 passed; 64 rendered frames reviewed across idle, run, strafe and three jumps. Measured base/cloak phase advance: 1.14750048 / 1.14750051.
- Dash/audio regression: 39 passed.
- Chain weapon regression: 29 passed.
- Packaged application outfit suite: 32 passed.
- Release export succeeded. Universal Mac app version 2.14.0; codesign deep/strict verification passed.

The motion preview is cloak-motion.mp4. Final captures show the corrected anchored neckline. Previous app, source, Blender garment and export are preserved in backups/ronin-cloak/.
