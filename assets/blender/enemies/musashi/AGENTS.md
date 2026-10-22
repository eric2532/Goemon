# MUSASHI_FINAL_APPROVED — canonical asset

Visual development is complete. The user's final instruction approved this character, requested consolidation, and explicitly required stopping afterward.

## Single source of truth

`Final/Musashi_Final.blend` is the FINAL APPROVED CHARACTER. Use this file for all future work. Do not substitute a model from Archive. Keep all assets and outputs inside this Sonic asset folder.

The approved design is locked: proportions, head, face, eyes, eyebrows, nose, mouth, ears, hair and silhouette, torso, jacket, sleeves, vest, pants, hands, wraps, shoes, stance, and reference-view camera. No redesign, likeness optimization, topology changes, rigging, animation, export or Godot import unless the user explicitly requests the relevant next phase.

Final materials use deliberate painted tonal regions with subtly softened edges, warm peach skin, near-black green hair, muted crimson/burgundy clothing, subdued ochre/orange print, charcoal vest planes and separated dark shoes. Do not automatically continue subjective material revisions either.

## Verified technical state

The material pass changed no geometry. Cleanup removed only 12 isolated microscopic zero-volume duplicate hair triangle pairs (24 faces / 36 vertices). All remaining face positions, winding, smoothing, material bindings and vertices are unchanged; all other character geometry and the camera match the approved source exactly. The silhouette is pixel-identical before/after cleanup. Only 14 of 2,592,000 color pixels differ, at most 1/255.

The final character has 86 meshes, 46,177 vertices, 90,160 triangles and 30 used material datablocks. Do not merge or optimize these merely for cleanliness. Open facial graphic sheets, open-ended trim/wrap tubes, and intentional layered intersections are preserved. No armature or actions exist.

`MUSASHI_PaintRest` is shader-only rest-coordinate data. Preserve it: it is not an unused modeling attribute. The original reference image is packed and also lives at `Final/Reference/Musashi_Original_Reference.png`. The final file has no linked libraries or missing image dependencies.

Read `Final/FINAL_REPORT.md` and `Final/RIGGING_READINESS.md` before the next phase. Joint topology/deformation, layered weights/attachments, and material baking or game-shader translation require planned next-phase work; these findings are not authorization to modify the locked master.

## Validation and recovery

- `Final/Tools/verify_final.py -- --audit-only` reloads and checks the canonical file without saving changes. Run it through Blender's background Python interface. Omitting `--audit-only` also writes a validation render.
- `Final/Validation/approved_geometry_manifest.json` is the original geometry baseline; `technical_cleanup_exception.json` records the sole tightly scoped exception. Do not regenerate baselines from changed geometry to bypass failures.
- `Archive/Musashi_Development_Backup.blend` is the verified pre-cleanup development backup.
- `Archive/Musashi_Visual_Development.zip` preserves nine old development stages, original reference copies, historical instructions and final-pass development sources. Its manifest verifies all 255 files. It is recovery history, not an active alternative master.

The parent `assets/blender/.gdignore` continues to exclude these source files from Godot import. Rigging/game integration begins only when explicitly requested.
