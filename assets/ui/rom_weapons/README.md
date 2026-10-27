# Original Mystical Ninja weapon HUD art

Twenty unpainted weapon sprites and Yae's flute, recovered from the supplied USA
revision-0 ROM. `provenance.json` records the ROM identity, PIC IDs, crop rectangles
and pixel hashes. These native 24×24 PNGs use nearest-neighbor filtering in the HUD.
The full decoded atlases, raw RGBA16 pixels and native decoder evidence remain in
`build/Other Files/Asset Toolkit/Goemon Chain and Icons/`.

Goemon, Sasuke and Yae use their original weapon icons in the current HUD. The
other tiers and Ebisumaru images are preserved without changing the playable
roster or its equipped weapon tiers.

Golden Goemon's ryo uses the flaming icon in both the HUD and the existing coin
projectile. Reusing that original artwork as an in-world billboard is a visual
adaptation, not a claim to emulate the original projectile renderer. Normal and
flaming coin meshes/materials are prepared with Goemon's model and shared by
casts. The original body geometry, source motion and weapon JSON are unchanged.

The older 3D-rendered previews under `assets/ui/recovered_goemon/` are retained as
references; `tools/render_goemon_weapon_icons.gd` renders those preview files,
not these original ROM sprites.
