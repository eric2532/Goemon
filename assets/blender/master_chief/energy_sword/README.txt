HALO CE ENERGY SWORD — LOCAL DISC RECOVERY AND PLAYABLE ADAPTATION

Source: user-supplied retail Xbox Halo: Combat Evolved disc, maps/a50.map.
No engine/game source code is incorporated. No assets were downloaded.

Native recovered content
- Actual weapons\energy sword\energy sword world-model: 136 vertices, 128
  triangles, original UVs and es handle/es blade top/es blade bottom surfaces.
- Original energy sword bitmap, shader_model handle and two transparent Chicago
  blade shaders. Both retail blade shaders use ADD framebuffer blending.
- Original glow1/glow2 marker chains, cyan glow/light tags, sword weapon/melee
  damage effect, sword detonation effects, and their dependency tags/bitmaps.
- Native Elite sword animation foley and detonation sound decoded from Xbox
  ADPCM. energy_sword_swing.wav is stand_sword_melee_uh.wav without resynthesis.
  This is animation foley; no invented native first-person swing or idle hum.

Playable first-person adaptation
Retail CE's sword weapon tag has empty first_person_model and
first_person_animations references. It was not a player first-person weapon.
This viewmodel attaches the actual campaign sword mesh to the Chief's native
pistol right-hand idle/ready/melee animation rig. The empty left support hand
and its arm are omitted. The firing clip is the native pistol melee arm clip
retargeted to hold the sword, not an authentic CE first-person sword animation.
The sword's grip transform is recorded in energy_sword_fp_metadata.json.

The Blender source and glTF preserve editable native materials and atlas.
Blender/glTF emission is a portable approximation of the retail additive shader;
Godot can apply its unshaded additive material to 'es blade top' and 'es blade
bottom' using energy_sword_texture.png. The original native shader fields and
plasma glow behavior remain in native_tags.json and the tags directory.

Coordinates/units
Native JMS: X forward, Y left, Z up; 100 JMS units = 3.048 metres.
Delivered GLB: metres, X right, Y up, -Z forward. Do not rescale again.
BladeBase, BladeTip, and Muzzle markers follow the sword's skeletal attachment.
Native marker chains are exported as SwordGlow1_0 through SwordGlow1_4 and
SwordGlow2_0 through SwordGlow2_4. Their complete original positions and
rotations include the original frame blades bone transform and remain attached
to frame handle. energy_sword_glow.png is the unchanged native glow sprite.
AnimationPlayer: idle (2s), ready (1.1667s), firing (1.5s). Firing may be sped up
for gameplay cadence. Damage tag is 151 plasma, radius .5 Halo units / 1.524m;
this damage radius is not evidence of an original player melee reach.

Rebuild from local disc/map
1. With requirements.txt dependencies:
   python tools/halo/extract_energy_sword.py /path/to/disc.iso
   (An extracted a50.map is accepted instead.)
2. /Applications/Blender.app/Contents/MacOS/Blender --background --python
   tools/halo/build_energy_sword.py
3. Import the project in Godot. Keep the generated GLB image sidecars and
   .import resource settings with the asset.

The tool also depends on the already-recovered Chief arm mesh/textures and
pistol animation files under assets/blender/master_chief/source_data.
