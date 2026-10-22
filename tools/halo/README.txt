Local Halo asset pipeline

1. Create an isolated Python environment and install tools/halo/requirements.txt.
2. python tools/halo/extract_user_disc.py USER_DISC.iso /tmp/halo-extracted
   A user-supplied .7z containing one ISO is also supported; nothing modifies it.
3. python tools/halo/decode_extracted_assets.py /tmp/halo-extracted/data assets/blender/master_chief
4. /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/halo/build_master_chief.py

Runtime outputs in assets/characters/master_chief:
- master_chief.glb: native Chief body, held native AR, 19 Chief skeleton bones
  plus 3 weapon bones; idle/walk/airborne animations.
- assault_rifle_fp.glb: 37 native arms + 5 native weapon bones; 42-bone native
  authored idle/firing/reload/ready/melee/throw_grenade clips. Native primary
  trigger marker exported as Muzzle. Default visible rest is the idle pose.
- assault_rifle_shot.wav, assault_rifle_reload.wav, assault_rifle_dryfire.wav:
  decoded original Xbox sounds, with corrected standard RIFF length fields.

Source files, all extracted animations, decoded JSON, .blend rigs and baked
texture derivatives live in assets/blender/master_chief, under .gdignore.

Fidelity and adaptation:
- Original mesh geometry, UVs, authored normals, native two-bone vertex weights
  and original poses are retained. Reclaimer 2.11.2's Xbox compressed-vertex
  bone-index endian swap is corrected locally in the extraction script.
- Coordinates are converted from Halo X-forward/Y-left/Z-up into meters with
  X-right/Y-up/-Z-forward; 1 Halo world unit = 3.048 meters.
- Original multipurpose blue channel is the Xbox player-color mask; Chief's
  native color permutation (.341176,.403922,.145098) is baked into portable PNGs.
- Original legacy reflection shaders are approximated by glTF PBR materials;
  visor uses a gold reflective material. Transparent additive weapon display
  overlays are converted to emissive alpha materials with black made transparent.
- Body rifle attachment uses the native right-hand marker. FP Muzzle native idle
  position is approx (0.113006,-0.097625,-0.873681) in Godot camera space.
- FP default arms span approx x[-.308,.487], y[-.500,-.020], z[-.811,.321]; parts
  behind/below the first-person camera are intentional native arm geometry.
- Chief native body has feet approximately y=-.0018 and head y=1.998 meters.

Extracted original AR tag facts (weapon weapons\\assault rifle\\assault rifle):
15 rounds/second; 60-round magazine; initial total rounds 240; max total 600;
3.4-second reload; one round/shot; every third round is a tracer. Chief camera
height .62 world units standing and .35 crouching. Game damage, enemy interactions
and first-person movement are deliberately adapted to Goemon's arena systems.

Read-only engine references:
OpenCE source/camera/first_person_camera.c
OpenCE source/interface/first_person_weapons.c
OpenCE source/items/weapons.c
OpenCE source/units/bipeds.c
https://github.com/OpenCommunityEdition/OpenCE

See runtime PROVENANCE.txt: Microsoft game content is not licensed by OpenCE.

FPS loadout (keys 1 Rockets, 2 Pistol, 3 Shotgun, 4 Assault Rifle):
- rocket_launcher_fp.glb, pistol_fp.glb, shotgun_fp.glb: original cyborg hands,
  original weapon geometry and skeleton, native idle/firing/ready animations.
- rocket_projectile.glb: native rocket model; swept movement, splash, smoke-like
  exhaust streak and expanding flash are adapted Goemon gameplay/presentation.
- *_shot.wav: original retail weapon firing samples. rocket_explosion.wav is
  the frag-grenade explosion sound referenced by the retail rocket explosion.
- Original first-person primary-trigger markers drive each muzzle flash.
- Matching editable .blend rigs and metadata live beside the decoded JSON.

The extraction and decode commands now recover all three weapons in one pass.
To rebuild just these new models, add -- --weapons-only to the Blender command.
Runtime tuning is centralized in scripts/master_chief_weapons.gd. The prototype
uses infinite ammunition without reloads, pistol hitscan, a 12-pellet shotgun
with range falloff, and travelling rockets with wall-occluded enemy-only splash.
Keys 1-4 switch Chief's loadout, including the preserved original rifle models
and shared rifle audio overrides. Other fighters retain their controls.

Precision hits and rocket blast reference:
- Pistol headshots kill through the normal HP/death/loot pipeline. Rifle headshots
  deal 2x body damage. Shotgun pellets and rocket splash do not use head bonuses.
- Native soldiers use Part_07 (head_face), transformed by the same animated pose
  row and facing as the renderer. Other forest enemy head regions use the upper
  central body contact; legacy Ninja actors use their HeroModel head pivot.
- Retail damage tag weapons/rocket launcher/explosion stores falloff .5 and
  cutoff 2 Halo world units (1.524m and 6.096m). OpenCE damage.c's
  area_of_effect_cause_damage uses the cutoff sphere; its per-object function
  scales damage linearly between falloff and cutoff and checks occlusion.
- Goemon's ordinary soldier height is 6.048m versus Chief's approximately 2m.
  Arena adaptation uses 3x retail radii: full damage within 4.572m and an 18.288m
  cutoff. This replaces the earlier arbitrary 5m splash; walls still block it.
- The shared expanding/fading explosion effect now reaches the damage radius.
- rocket_blast_reference.json in assets/blender/master_chief records the map
  hash, original values, engine revision and separate arena adaptation.
  Recreate with the Halo Python environment:
  python tools/halo/inspect_rocket_blast.py bloodgulch.map OUTPUT.json
