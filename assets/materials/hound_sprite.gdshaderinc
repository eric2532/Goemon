uniform sampler2DArray pixels : filter_nearest, repeat_disable;
uniform sampler2D frames : filter_nearest, repeat_disable;
uniform sampler2D palette : source_color, filter_nearest, repeat_disable;
uniform float enemy_size = 1.0;
instance uniform bool use_world_pet_sizes = false;
instance uniform float map_enemy_scale = 1.0;
uniform bool companion_pet_sizes = false;
uniform float pet_scales[617];
uniform float pixel_size;
uniform int clip_rows;
uniform int actions_per_skin = 6;
uniform int guard_clip = 0;
uniform bool has_snow_guards = false;
uniform int snow_guard_skins[2];
uniform int snow_guard_frames[16];
varying flat vec4 atlas_rect;
varying flat vec2 atlas_rows;
varying flat vec2 reaction;
varying flat float ice_coat;
varying flat float guard_border;
#include "enemy_ice_sprite.gdshaderinc"

vec4 frame_entry(int index) {
 int width = textureSize(frames, 0).x;
 return texelFetch(frames, ivec2(index % width, index / width), 0);
}

bool frame_contains(ivec2 pixel) {
 return all(greaterThanEqual(pixel, ivec2(0))) && all(lessThan(pixel, ivec2(atlas_rect.zw)));
}

bool frame_ink(ivec2 pixel) {
 if (!frame_contains(pixel)) return false;
 return texelFetch(pixels, ivec3(ivec2(atlas_rect.xy) + pixel, int(atlas_rows.x)), 0).r > 0.0;
}

bool near_frame_ink(ivec2 pixel) {
 for (int y = -1; y <= 1; y++) {
  for (int x = -1; x <= 1; x++) {
   if ((x != 0 || y != 0) && frame_ink(pixel + ivec2(x, y))) return true;
  }
 }
 return false;
}

void vertex() {
 vec2 facing = -MODEL_MATRIX[2].xz;
 vec2 right = normalize(MAIN_CAM_INV_VIEW_MATRIX[0].xz);
 vec2 back = normalize(MAIN_CAM_INV_VIEW_MATRIX[2].xz);
 float angle = atan(dot(facing, right), -dot(facing, back));
 int direction = int(mod(round(angle * 8.0 / TAU) + 1.0, 8.0));
 int skin = int(INSTANCE_CUSTOM.x + 0.5);
 int packed_state = int(INSTANCE_CUSTOM.y + 0.5);
 int state = packed_state % 256;
 guard_border = 0.0;
#ifndef HOUND_AFTERIMAGE
 if (packed_state >= 256) guard_border = 1.0;
#endif
 int clip = state % 8;
 int locked_direction = state / 16 - 1;
 if (locked_direction >= 0) {
  direction = locked_direction;
 }
 int source_clip = clip == 6 ? guard_clip : (clip == 7 ? (actions_per_skin == 8 ? 7 : 2) : clip);
 vec4 timing = frame_entry((skin * actions_per_skin + source_clip) * 8 + direction);
 float seconds = INSTANCE_CUSTOM.z;
 float elapsed = (clip < 2 || clip == 5) ? mod(seconds, timing.z) : clamp(seconds, 0.0, timing.z);
 int pose = int(min(floor(elapsed / timing.z * timing.y), timing.y - 1.0));
 // 雪山 地獄妖犬's 46-frame bite repeats frames 6–21 before landing at 38.
 if (clip == 7 && timing.y == 46.0 && pose >= 22) {
  pose = 38 + (pose - 22) / 3;
 }
 int frame = int(timing.x) + pose;
 if (clip == 6 && has_snow_guards) {
  if (skin == snow_guard_skins[0]) frame = snow_guard_frames[direction];
  if (skin == snow_guard_skins[1]) frame = snow_guard_frames[8 + direction];
 }
 atlas_rect = frame_entry(clip_rows + frame * 2);
 vec4 placement = frame_entry(clip_rows + frame * 2 + 1);
 atlas_rows = placement.zw;
 reaction = vec2(float(state % 16 >= 8), state % 16 >= 8 ? max(0.0, INSTANCE_CUSTOM.w - seconds) : INSTANCE_CUSTOM.w);
 float ice_bits = fract(INSTANCE_CUSTOM.y);
 ice_coat = ice_bits > 0.1875 ? -(ice_bits - 0.25) * 8.0 : ice_bits * 8.0;
 vec2 source = placement.xy - guard_border + UV * (atlas_rect.zw + 2.0 * guard_border);
 float scale = (timing.w > 0.0 ? timing.w : pixel_size) * enemy_size * map_enemy_scale * ((use_world_pet_sizes || companion_pet_sizes) ? pet_scales[skin] : 1.0) * length(MODEL_MATRIX[1].xyz);
 vec3 world = MODEL_MATRIX[3].xyz + INV_VIEW_MATRIX[0].xyz * source.x * scale
   + INV_VIEW_MATRIX[1].xyz * (10.0 - source.y) * scale;
 POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
 vec2 padded_size = atlas_rect.zw + 2.0 * guard_border;
 ivec2 local_pixel = ivec2(clamp(floor(UV * padded_size), vec2(0.0), padded_size - 1.0) - guard_border);
 ivec2 pixel = ivec2(atlas_rect.xy) + local_pixel;
 int index = frame_contains(local_pixel) ? int(round(texelFetch(pixels, ivec3(pixel, int(atlas_rows.x)), 0).r * 255.0)) : 0;
 int palette_columns = textureSize(palette, 0).x / 256;
 int palette_row = int(atlas_rows.y);
 vec4 original = texelFetch(palette, ivec2(index + (palette_row % palette_columns) * 256, palette_row / palette_columns), 0);
#ifdef HOUND_AFTERIMAGE
 ALBEDO = original.rgb;
 ALPHA = original.a * reaction.y;
#else
 if (original.a < 0.5) {
  if (guard_border < 0.5) discard;
  if (!near_frame_ink(local_pixel)) discard;
  ALBEDO = vec3(0.14, 0.49, 1.0);
  ALPHA = 1.0;
 } else {
  ALBEDO = ice_sprite_surface(original.rgb, vec2(pixel), ice_coat);
  ALBEDO = mix(ALBEDO, vec3(1.0, 0.82, 0.73), clamp(reaction.y * 3.0, 0.0, 0.55));
  ALPHA = original.a;
 }
 ALPHA_SCISSOR_THRESHOLD = 0.5;
#endif
}
