# Edo — new design prototype

The user chose a new character design on 2026-10-13 after rejecting further
likeness work on the original reference. This prototype keeps Edo's black hair,
crimson palette, confident expression and fire identity. Its body, hair, face
artwork and costume are newly built. It is an **unrigged visual review asset**;
it has not replaced the playable character and has no animation or combat claims.

The design has swept faceted hair, a cropped crimson jacket, an asymmetric
shoulder mantle, a charcoal vest and tapered trousers, forearm wraps and blue
boots. The face artwork sits on a volumetric head with an integrated nose.

## Review

Open `preview.html` for the packaged interactive review. It contains the model
data, angle presets, drag rotation, a clay-material toggle and a comparison with
the genuine Goemon model. The Three.js library loads from cdnjs; model data and
textures are embedded. `tools/edo_new_design/viewer.template.html` is a build
input with a data placeholder, **not the runnable preview**.

Static renders: `front.png`, `three-quarter.png`, `side.png`, `back.png` and
`goemon-comparison.png`. Both characters use shared lighting in the comparison.

Editable Blender sources:

- `assets/blender/characters/edo_new_design/edo_cinder_duelist.blend`
- `assets/blender/characters/edo_new_design/edo_goemon_review.blend`
- `assets/blender/characters/edo_new_design/face.png`

Exchange model: `assets/models/characters/edo_new_design/edo_cinder_duelist.glb`.

## Rebuild

From the repository root, use Python with Pillow for the face and Blender for
the model. The model script appends Goemon for comparison without saving changes
to the Goemon master.

```sh
python3 tools/edo_new_design/paint_face.py
blender --background --python tools/edo_new_design/build.py
python3 tools/edo_new_design/package_viewer.py --output /absolute/output/edo-new-design.html
```

The final command produces an inline visualization fragment. The saved
`preview.html` is its standalone wrapper. Mesh data is compressed into the
fragment; it is not fetched from a server.

## Verification

Blender exported the 10,408-triangle prototype and rendered all five review
views. The GLB header and length were verified. SHA-256 checks confirm that the
Goemon master and current Edo source/export were unchanged; see `validation.json`.
The packaged viewer was tested in Chrome at desktop and 360px widths: side-view
selection, clay toggle and Goemon comparison worked, with no page errors or
horizontal overflow. Saved browser captures are `viewer-check.png`,
`viewer-clay-check.png` and `viewer-mobile-check.png`.

Approval of the visual direction is the next review step. Rigging, deformation,
game-camera lighting and playable integration remain future work.
