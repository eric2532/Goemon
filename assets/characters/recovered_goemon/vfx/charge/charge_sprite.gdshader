shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D source_texture : filter_nearest, repeat_disable;
uniform vec2 source_size=vec2(32.0,64.0);
uniform bool billboard=true;
uniform bool use_environment_combiner=true;
uniform vec3 primitive_color=vec3(1.0,0.9607843,0.7215686);
uniform vec3 environment_color=vec3(1.0,0.9803922,0.1411765);
uniform float opacity=1.0;
void vertex(){
 if(billboard){
  vec3 source_scale=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
  MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*source_scale.x,INV_VIEW_MATRIX[1]*source_scale.y,INV_VIEW_MATRIX[2]*source_scale.z,MODEL_MATRIX[3]);
 }
}
vec4 native_texel(ivec2 at){
 // Source charge and coin-impact tiles clamp both axes.
 return texture(source_texture,(clamp(vec2(at),vec2(0.0),source_size-vec2(1.0))+vec2(.5))/source_size);
}
void fragment(){
 vec2 coordinate=clamp(UV*source_size,vec2(0.0),source_size-vec2(1.0));
 ivec2 base=ivec2(floor(coordinate));
 vec2 f=floor(fract(coordinate)*32.0)/32.0;
 vec4 a=native_texel(base);vec4 b=native_texel(base+ivec2(1,0));vec4 c=native_texel(base+ivec2(0,1));vec4 d=native_texel(base+ivec2(1,1));
 vec4 pixel=f.x+f.y<1.0?a+f.x*(b-a)+f.y*(c-a):d+(1.0-f.x)*(c-d)+(1.0-f.y)*(b-d);
 // Original FC309A61/5536FF7F charge combiner, original primitive/env bytes.
 vec3 color=use_environment_combiner?mix(environment_color,primitive_color,pixel.rgb):pixel.rgb;
 ALBEDO=mix(color/12.92,pow((color+vec3(.055))/1.055,vec3(2.4)),step(vec3(.04045),color));
 ALPHA=pixel.a*opacity;
}
