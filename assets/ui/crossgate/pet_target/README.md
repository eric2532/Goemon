# Original direction pointer for pet focus

`pointer.png` is the unchanged 20×12 Blue Cross Gate graphic 22190,
`original` archive row 18969, decoded with Magic Power's `cg_library.image_from_record`.
Its original blue RGBA pixels, dimensions and transparency are preserved; hashes
and source details are in `provenance.json`.

The user selected this shape with a red color on 2026-11-17. `forest_ui.gd`
uses one owned material with the existing equipment tint shader (`ff3434`) and
displays it at 2× with nearest filtering, 96 screen pixels above the focused
enemy's fitted bounds and existing half-unit world offset, to clear the pets.
The red color and overhead targeting use are Goemon adaptations. Never recolor
the PNG or mutate another UI element's material to change this marker.

The original candidate gallery and unmodified alternatives are excluded review
artifacts under `build/Other Files/Asset Toolkit/Pet Surround/Target Art/`.
