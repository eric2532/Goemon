# Laruka waterfront — recovered original expansion art

The formerly missing map IDs 38046 and 38051 are present in the read-only
BlueCrossgate expansion pack. Their full GraphicInfo map serials are 238046
and 238051. Map DAT files compress these expansion IDs by subtracting 200000.
Nearby 38043/38044 resolve to 238043/238044; looking them up without expansion
incorrectly selects unrelated portrait images. Ground 25290 resolves to paving
225290. The original source files have not been modified.

The normalization rule is corroborated by this pinned
[map-reader implementation and format notes](https://github.com/josh-hsu/crossgate-editor/blob/cdc75f20d58155a25c018cd81f653c685859c9d1/doc/renderer-notes.md).
`provenance.json` records the exact expansion-pack rows, index-record hashes
and decoded RGBA hashes. PNGs here preserve the five original decoded images.
These are recovered images, with no newly invented replacement decoration.

`tools/prepare_il_laruka.py::laruka_lookup` resolves only the compressed IDs
used by Laruka. It does not change the shared archive index or portrait assets.
The same preparer packs original paint, restores the waterfront's 60 paving cells
and generates the land mask for the 15 source cap/bank placements. Existing
solid bank meshes supply depth below the caps; the source cell anchors stay fixed.
The courtyard's separate top and brick-skirt mesh follows the existing terrain
triangles. Its top reuses the native paving with consistent UV scale; the skirt
extends the recovered bank's brick material around exposed slopes. That skirt
is an inferred 3D continuation. It changes no terrain heights or collision.
Procedural meadow scatter skips the original paving and cap cells, preserving
the existing RNG draws for the surrounding scenery.

The original 2300 map and warp rows remain unchanged. NPCs, dialogue, quests
and doors retain their existing owners. Review images and focused checks are in
`build/Other Files/Asset Toolkit/Il and Laruka/Decorations/`.
