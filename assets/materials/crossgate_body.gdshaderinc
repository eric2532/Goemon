uniform sampler2D sprite_texture : source_color, filter_linear;
instance uniform bool grounded = true;
instance uniform float layer_depth = 0.0;
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

void fragment() {
 vec4 art = texture(sprite_texture, UV) * COLOR;
 ALBEDO = art.rgb;
 ALPHA = art.a;
#ifndef CROSSGATE_SHADOW
 ALPHA_SCISSOR_THRESHOLD = 0.5;
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
