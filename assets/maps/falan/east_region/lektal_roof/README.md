# Lektal native house1233255

`tools/prepare_east_lektal_roof.py` prepares the bounded original paint and independently measured surface patches. `scripts/forest/forest_east_lektal_roof.gd` reuses the complete house from the East landmark library. Original wall/roof vertices, footprint, anchor and navigation are preserved. Only this appearance on maps43000/43700uses the roof derivative; adjacent annexes and other region owners remain separate.

The chimney and hatch have real depth. Their bases intersect the reused roof triangles; the numerical attachment proof is retained in mesh metadata. Original front paint is clipped to the chimney, and hidden brick/log/slate finish uses independently scaled source patches. Hidden construction is inferred. The roof's UV phase continues over complete hips. Original source atlases and shared building masters are preserved.

The asset gallery under `build/Other Files/Asset Toolkit/East Gate Region/Hourglass Studies/` includes a low reverse view because the large source roof hides the short rear walls from above. Its6/0current capture check is separate from actual-map placement, camera and visual review in `Actual Maps/`.
