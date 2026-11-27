# Scoped East cliff relief candidate

The six meshes derive from unchanged native cliff images and the existing authoritative profile/source metadata. Shared `forest_original_cliffs.gd` and its source files remain unchanged. Only the East Gate, North Coast and Alyut cliff owner uses these derivatives.

`tools/prepare_east_stone_profiles.py::source_contour_profile` replaces the old fitter's92%uniform upper-height floor with the visible native top contour. Source-high sides determine the crown. The source footprint cells and anchors remain authoritative for layout/navigation; the old mesh box is only a reference. Native-alpha-supported art overhang is recorded with original pixel/RGBA samples. Hidden depth, closure, interpolation and the source-correlated relief depths are inferred separately. Cave void caps are not candidates for this whole-volume fitter.

`tools/prepare_east_cliff_relief.py` reuses the16-side/7-level native topology, rounds it with three closed Loop subdivisions, and adds0.22–0.70m rounded relief measured from original stone-patch centres/radii. Unseen sides continue the same source palette and stone design; caps sample adjacent visible detail. Original RGB remains byte-identical; only alpha of unrecorded border/large neutral occlusion regions changes. Enclosed painted crevices remain.

ECR3 assigns each observed face one material. It does not overlay coplanar paint and body geometry. Native RGBA supplies the visible paint; unrecorded alpha falls back to coarse source-derived stone/moss color inside the same closed surface. Hidden faces use the same measured boulder tints, native foliage median and the existing fixed-scale Fort rock grain. No front sprite is wrapped around the whole back, and no UV edge clamping is used. The encoded full mesh remains closed; all edges have two incident faces. The rendered body/front index sets replace one another exactly.

`forest_east_cliff_relief.gd` loads prepared geometry once per family at map setup. Sparse crest masks retain their existing shallow native artwork and low-resolution family spur. All125 Alyut placements,579 native cliff navigation cells, original doors/portals, terrain and closed non-water substrate keep their existing owners. The East source basis is tested against the source-grid inverse transform.

Rebuild with a Python environment containing Pillow and NumPy:

```sh
PYTHONPATH=/private/tmp/east-cliff-python python3 tools/prepare_east_cliff_relief.py --publish
PYTHONPATH=/private/tmp/east-cliff-python python3 tools/prepare_east_cliff_relief.py --check
python3 -m unittest discover -s tests/forest-shrine -p 'test_east_cliff_relief_source.py' -v
```

Single-family studies use `--serial 12538`. Artifacts go to `build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Relief Preview/`. Offline source, clay and colored physical studies are separate from visual acceptance. Actual reachable normal/second/source-face captures use `tests/forest-shrine/east_field_crag_angles.gd` through the desktop launcher. Source and geometry contracts alone do not establish acceptable gameplay appearance.


The closed-volume follow-up is currently a private review candidate. `tools/prepare_east_cliff_volumes.py` is its canonical preparer; the older `prepare_east_cliff_relief.py` command forwards to it. Default output is `build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Volume Candidates/`, with native/source and reverse contact sheets. `--check` checks that private folder; `--publish` writes runtime assets, and `--check --publish` verifies runtime freshness. No runtime volume publication has occurred yet.

The source-facing detailed body rebuilds directly from unchanged native images, shared source profiles and the East-only contour fitter. Its reproduction proof matches the retained body to floating-point noise. Complete rounded River Rock derivatives supply actual closed stone volumes; pale stone and moss use separate native-derived colors. Only measured original-alpha fringe missing from the body is restored as shallow artwork at adjacent source depth. The recorded native-view paint and reconstructed reverse materials remain distinct. Upper occlusion, hidden depth and fringe placement are explicit inference; original3D is not claimed. Per-family source placement counts, exact buffer payloads and actual camera/frame measurements are kept separately.
