shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform float frame = 0.0;
uniform float frames = 12.0;
uniform float playback_fps = 30.0;
uniform bool billboard = false;
uniform bool directional_billboard = false;
uniform vec2 sprite_forward = vec2(0.0, 1.0);
uniform bool instanced = false;
uniform bool frame_loop = true;
uniform bool instance_alpha = false;
uniform float opacity_scale = 0.7;
instance uniform float playback_age = -1.0;
varying float age;
varying float opacity;
void vertex() {
 age=playback_age>=0.0?playback_age:INSTANCE_CUSTOM.x;
 opacity=INSTANCE_CUSTOM.y;
 if(billboard) {
  vec4 right=INV_VIEW_MATRIX[0];
  vec4 up=INV_VIEW_MATRIX[1];
  if(directional_billboard) {
   vec2 heading=(VIEW_MATRIX*vec4(MODEL_MATRIX[2].xyz,0.0)).xy;
   if(dot(heading,heading)>0.000001) {
    heading=normalize(heading);
    heading=vec2(heading.x*sprite_forward.y-heading.y*sprite_forward.x,
                 heading.x*sprite_forward.x+heading.y*sprite_forward.y);
    right=INV_VIEW_MATRIX[0]*heading.y-INV_VIEW_MATRIX[1]*heading.x;
    up=INV_VIEW_MATRIX[0]*heading.x+INV_VIEW_MATRIX[1]*heading.y;
   }
  }
  MODELVIEW_MATRIX=VIEW_MATRIX*mat4(
   right*length(MODEL_MATRIX[0].xyz),
   up*length(MODEL_MATRIX[1].xyz),
   INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);
 }
}
void fragment() {
 float cell=instanced?(frame_loop?mod(floor(age*playback_fps),frames):min(floor(age*playback_fps),frames-1.0)):frame;
 vec4 pixel=texture(atlas,vec2(UV.x,(UV.y+cell)/frames));
 ALBEDO=pixel.rgb;
 ALPHA=pixel.a*opacity_scale*(instance_alpha?clamp(opacity*4.0,0.0,1.0):1.0);
}
