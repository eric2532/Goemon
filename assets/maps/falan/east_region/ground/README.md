# Continental ground derivatives

The authoritative layouts and graphic bindings remain in `original_crossgate/east/catalog.json` and the pinned source manifests. When prepared, compressed scenes here contain the existing ground owner's exact chunk meshes for maps33000 and43000. They add no land, simplify no geometry and own no collision or gameplay. Without valid scene/manifest pairs, the original owner builds the same source ground.

Regenerate from the complete current source:

```sh
zsh '/Users/eric/Desktop/Play Goemon.command' --headless --script res://tools/bake_east_continental_ground.gd
```

The baker compares every serialized/reloaded chunk's vertices, normals, UVs, transforms, primitive and material references/parameters. Source signatures and scene hashes are checked at setup; stale derivatives fall back to the original owner and need regeneration. Do not edit generated `.scn` or `.json` files. Evidence is under `build/Other Files/Asset Toolkit/East Gate Region/Continental Ground/`.
