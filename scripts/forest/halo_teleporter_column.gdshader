shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
// Retail teleporter_cone.shader_transparent_chicago: three native bitmap
// layers multiplied, additive, two-sided, fade_when_parallel. UV.y is flipped
// from JMS, hence the flipped V scroll signs and 1.05-scale offset below.
uniform sampler2D volumetric_dust : filter_linear_mipmap, repeat_enable;
uniform sampler2D teleporter_dust : filter_linear_mipmap, repeat_enable;
void fragment(){
 vec2 uv0=UV+vec2(TIME/6.0,TIME/20.0);
 vec2 uv1=UV+vec2(-TIME/4.0,-TIME/15.0);
 vec2 uv2=vec2(UV.x,UV.y*1.05-0.05);
 vec3 color=texture(volumetric_dust,uv0).rgb*texture(volumetric_dust,uv1).rgb*texture(teleporter_dust,uv2).rgb;
 float facing=abs(dot(normalize(NORMAL),normalize(VIEW)));
 ALBEDO=color*facing;
 ALPHA=1.0;
}
