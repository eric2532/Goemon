uniform sampler2D sprite_texture : source_color, filter_linear;
instance uniform bool grounded = true;
instance uniform float layer_depth = 0.0;
instance uniform vec4 food_glow : source_color = vec4(0.0);
instance uniform vec4 food_frame = vec4(0.0, 0.0, 1.0, 1.0);
varying vec3 world_pixel;
varying float ground_y;

void vertex() {
 mat4 facing = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
 facing[3].xyz += INV_VIEW_MATRIX[2].xyz * layer_depth;
 mat4 size = mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
                  vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
                  vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
 MODELVIEW_MATRIX = VIEW_MATRIX * facing * size;
 world_pixel = (facing * size * vec4(VERTEX, 1.0)).xyz;
 ground_y = MODEL_MATRIX[3].y + 0.05;
}

// Treat the current atlas frame boundary as transparent, never a neighboring pose.
float food_alpha(vec2 uv) {
 if (any(lessThan(uv, food_frame.xy)) || any(greaterThanEqual(uv, food_frame.zw))) return 0.0;
 return texture(sprite_texture, uv).a;
}

void fragment() {
 vec4 art = texture(sprite_texture, UV) * COLOR;
 ALBEDO = art.rgb;
 ALPHA = art.a;
#ifndef CROSSGATE_SHADOW
 ALPHA_SCISSOR_THRESHOLD = 0.5;
 if (food_glow.a > 0.0 && art.a >= 0.5 && world_pixel.y > ground_y) {
  vec2 step_uv = 1.75 / vec2(textureSize(sprite_texture, 0));
  float inner = 1.0;
  for (int y = -1; y <= 1; y++) {
   for (int x = -1; x <= 1; x++) {
    if (x != 0 || y != 0) inner = min(inner, food_alpha(UV + vec2(float(x), float(y)) * step_uv));
   }
  }
  float border = (1.0 - inner) * food_glow.a;
  ALBEDO = mix(art.rgb, food_glow.rgb, border * 0.85);
  EMISSION = food_glow.rgb * border * 1.4;
 }
#endif
 vec3 point = world_pixel;
 // Original effects below the feet lie on the ground, while walls still occlude them.
 if (grounded && point.y < ground_y) {
  vec3 ray = CAMERA_POSITION_WORLD - point;
  if (ray.y > 0.0001) point += ray * clamp((ground_y - point.y) / ray.y, 0.0, 1.0);
 }
 vec4 clip = PROJECTION_MATRIX * VIEW_MATRIX * vec4(point, 1.0);
 DEPTH = clip.z / clip.w;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
 DEPTH = DEPTH * 0.5 + 0.5;
#endif
}
