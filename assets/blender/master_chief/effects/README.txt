Native Halo Combat Evolved Xbox weapon effects recovered from the user's disc

Runtime: assets/characters/master_chief/effects/manifest.json
Editable metadata: native_effects.json (identical copy of the runtime manifest)
Original extracted binary authoring tags: tags/<native path>.<native class>

Reproduction (no downloads, source map remains read-only):
  /tmp/goemon-halo-research/venv/bin/python tools/halo/extract_weapon_effects.py \
    /tmp/goemon-halo-research/maps/bloodgulch.map \
    /Users/eric/.codex/worktrees/painterly-gate-preview/Sonic \
    '/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/halo-native-effects'

Dependencies: refinery 2.6.0, reclaimer 2.11.2, Pillow. The tool uses those
packages at extraction time. No implementation of Halo or OpenCE is copied.
The original game assets are recovered solely from the user-supplied local map.
The manifest records the exact map SHA-256 and per-file hashes.

Manifest schema 1:
  tags[key] = {class, native_path, data, dependencies, optional map_values}
  tag_keys[class][native_path] = key
  bitmaps[native_path].files[] = {bitmap_index, path, width, height, sha256}
  sounds[native_path].files[] = {path, permutation, sample_rate, channels,
                              sample_frames, duration, sha256}
  weapons[slot] = {weapon, projectile, firing_effect, trigger, attachments,
                   functions, animation_sound_references,
                   animation_sound_events, markers}
  materials[] and material_effect_types[] preserve native array index labels.

Ordinary tag keys are full native backslash paths. Some native tag classes
share paths, e.g. pistol bullet projectile and damage_effect. Resolve with
  tags[tag_keys[reference.class][reference.path]]
The primary projectile/particle/effect/bitmap remains available at tags[path].
Collision entries use path + '.' + class. Tagref data retains {class,path}.

All named native fields and curves/functions are retained. Reflexives become
arrays. Native enums become name strings; their original integer values remain
in sibling _enum_values dictionaries. Bit flags remain integer masks with their
enabled names in sibling _flag_names dictionaries. Empty native references keep
an empty path. Raw data blobs become byte length/hash records in JSON; actual
raw pixels and compressed source audio remain in the extracted binary tags.

Important units:
  Lengths: native Halo world units. One world unit is 3.048 metres.
  Times: seconds. Angles: radians. Colors/functions/enum values: native.
  Atlas UVs and registration offsets: native normalized atlas coordinates.
  No Goemon arena or blast adaptation is applied to this manifest.

A few compiled map fields require their documented authoring conversion:
  projectile initial/final velocity: multiply by 30 (per tick to per second)
  light effect duration: divide by 30 (ticks to seconds)
  damage camera wobble period: divide by 30 (ticks to seconds)
  point_physics air/water friction: divide by 10000
  sound maximum bend per second: raise to power 30
These corrections are explicitly listed in manifest.units. Each affected tag
entry.map_values preserves the original compiled numbers. Other computed native
point physics fields (e.g. air_gravity_scale) remain untouched and available.

Sprite atlases:
  Use tags[bitmap].data.sequences[].sprites[].bitmap_index to select a PNG.
  left_side/right_side/top_side/bottom_side are the original UV rectangles.
  registration_point_x/y are native atlas offsets from the sprite top-left.
  Preserve the particle's native sequence indices, flags, animation rate,
  shader flags, blend/fade modes, state curves and colors during playback.
  PNGs are decoded original atlases, not repainted or hand-generated images.
  Cubemap files (the optional weapon flashlight) have cubemap_face 0..5.

Sounds:
  All available permutations are retained, including gunshots, pistol/AR
  casing ejection, shotgun pump/ready/reload animations, impacts and bounce
  material sounds. WAVs are decoded mono/stereo 16-bit PCM. A canonical PCM
  header replaces Reclaimer's incorrect RIFF length; decoded sample bytes are
  unchanged. Sound metadata retains native gain, distance, pitch, skip fraction,
  promotion, permutation and sample linkage. Animation sound frame indices are
  recorded; their timeline is the native 30 FPS weapon animation timeline.

Markers:
  Original JMS marker data is retained per weapon. godot_idle is model-local
  position/rotation at the first idle frame; godot_local is the converted
  bone-local marker. Both use metres and XYZW quaternion order. The converter
  exactly matches build_master_chief.py: conjugate JMS quaternion, transform
  through the original parent bone, rotate +90deg Blender Z, scale .03048,
  then export Y-up, giving position mapping (x,y,z) -> (-y,z,-x).

Scope:
  Follows every available visual/audio dependency of all four weapons, their
  projectiles, impact material responses, effect parts and particle states.
  It retains every impact material available in the Blood Gulch map. HUDs,
  ammo pickup objects and model meshes are outside this FX dependency closure;
  the project's existing native weapon/rocket models remain separate assets.
  This is data recovery, not an assertion of complete Halo engine emulation.

Light volume widget recovery:
  Both reachable light_volume tags are included, including the rocket's real
  20-billboard exhaust glow. A null native map is functional and defaults to
  the original rasterizer/glow bitmap, recovered as a 64x64 PNG. This implicit
  dependency is recorded explicitly, with defaults.light_volume_bitmap naming
  the reference; the native map field remains empty. Full frame exponents,
  dimensions, tint/alpha bounds, angle brightness and distance fades remain.
  Tag keys collide with rocket projectile and flashlight light; resolve class
  through tag_keys exactly as for bullet damage/projectile collisions.

Dependency coverage:
  coverage.supported_dependency_classes names the full visual/audio closure.
  missing reports unresolved dependencies within that closure only.
  coverage.external_dependencies explicitly lists models, animations, weapon
  HUDs, collision models and ammo inventory objects outside this FX extraction.
  Existing project meshes/animations are maintained separately.
  The only actual lens_flare-class tag belongs to the optional AR flashlight;
  weapon/explosion tags whose names include 'lens flare' are particle tags.
