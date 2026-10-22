Embedded vertex-painted Color palette: Game_Matte (roughness .72), Game_Metal (metallic .6 / roughness .42), Game_Glow (subtle emission). Palette models have no external textures, baked lighting or Blender-only shaders. Existing Godot world/effect materials remain in scripts.

The reference hero instead uses `Goemon_Original_Atlas`, the supplied UV texture with nearest sampling, roughness 1 and no added specular detail. `Surge_Gold` is the existing transformation color on an identical copy of source hair triangles. Both are plain glTF-compatible materials.
