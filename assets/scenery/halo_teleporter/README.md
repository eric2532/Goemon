# Halo CE teleporter scenery

Original metal teleporter pad, energy surfaces, UVs and eight bitmap images recovered read-only from the supplied Xbox disc's `maps/bloodgulch.map`. See `provenance.json` for native paths and SHA-256 hashes; `native_tags.json` preserves parsed material definitions. Editable native JMS, tags and source images are in `source/`, excluded from Godot's import scan. No sound sample is included.

Reproduce with the local research Python environment and `tools/halo/extract_teleporter.py /path/to/bloodgulch.map` (or the supplied disc ISO). Extraction needs `tools/halo/requirements.txt`.

`halo_teleporter.gd` converts the original 346 vertices and 184 triangles from JMS coordinates once and shares three ArrayMeshes and their five materials across all entrances and editor previews. The native scenery is uniformly enlarged 10× to fit the current battle scale. Its original minimum height stays on the existing portal terrain anchor. The pad is visual scenery; existing spawn-clearance, routes and map data remain authoritative, without new collision bodies.

The column shader translates the native `teleporter_cone` Chicago material: two scrolling volumetric dust maps (U/V periods 6/-20 and -4/15), multiplied by the original green teleporter dust map with V scale 1.05. The pad's energy surface translates the native `teleporter_shield` generic combiner equations and scrolling plasma/mask textures at unconnected scenery A-out=0. Both use additive two-sided rendering and the original angle fade. Animation runs entirely through shader time. The generic stages whose outputs are overwritten have no visual contribution. This is a material translation into Godot's modern renderer; it does not run Halo's Xbox rasterizer. Metal uses original albedo images with Godot lighting.

Painterly styling skips this native scenery, preserving metal textures and green energy. All legacy and current maps and editor placement use the same replacement. No teleport sound or audio player is created. The source launcher uses this directly; no app export is required.
