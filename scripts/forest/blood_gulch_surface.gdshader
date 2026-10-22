shader_type spatial;
render_mode cull_disabled;
// Native source UVs and textures stay intact; sunlight and sky provide the shading.
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_ground_blend = false;
uniform float grass_scale = 60.0;
uniform sampler2D visibility_map : filter_linear, repeat_disable;
uniform vec4 surface_tint : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform float detail_scale = 12.0;
uniform bool use_detail = false;
uniform bool is_cliff = false;
uniform bool road_mode = false;
uniform bool show_grid = false;
uniform vec2 hero_position = vec2(0.0);
varying vec3 world_point;
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 uv=UV*uv_scale;
 if(road_mode)uv=world_point.xz*.16;
 vec4 texel=texture(albedo_texture,uv)*surface_tint;
 vec3 color=texel.rgb;
 if(road_mode){
  // Painted roads use native sand as quiet grain, not its black/white range.
  vec3 soil=texture(albedo_texture,uv,2.0).rgb;
  float soil_value=dot(soil,vec3(.2126,.7152,.0722));
  color=vec3(.30,.205,.105)*mix(.90,1.10,smoothstep(.02,.5,soil_value));
 }else if(use_ground_blend){
  // Native ground alpha is a sand/grass mask, never an opacity cutout.
  // Source blades have near-white highlights. Use their softened luminance as
  // restrained ground variation so daylight does not turn them into lime veins.
  vec3 blades=texture(grass_texture,uv*grass_scale*.8,2.0).rgb;
  float blade_value=dot(blades,vec3(.2126,.7152,.0722));
  float blade_variation=mix(.86,1.14,smoothstep(.02,.38,blade_value));
  float macro_variation=mix(.93,1.07,clamp(dot(texel.rgb,vec3(.3333))*3.0,0.0,1.0));
  vec3 grass=vec3(.13,.23,.065)*blade_variation*macro_variation;
  vec3 sand=texel.rgb*1.12;
  if(use_detail)sand*=mix(vec3(.88),vec3(1.16),texture(detail_texture,uv*detail_scale).rgb);
  color=mix(grass,sand,smoothstep(.15,.8,texel.a));
 }else if(use_detail){color*=mix(vec3(.82),vec3(1.18),texture(detail_texture,uv*detail_scale).rgb);}
 vec2 sight=texture(visibility_map,(world_point.xz/6.0+vec2(40.5))/80.0).rg;
 float explored=smoothstep(.04,.96,sight.r);
 float visible=smoothstep(.05,.9,sight.g);
 // Scouting remains legible while unexplored canyon scenery stays readable.
 float scouting=mix(.68,mix(.83,1.0,visible),explored);
 color*=scouting;
 if(show_grid && !is_cliff){
  vec2 line=abs(fract(world_point.xz/6.0+.5)-.5);
  float grid=smoothstep(.478,.499,max(line.x,line.y));
  color=mix(color,vec3(.72,.70,.42),grid*.22*explored);
 }
 ALBEDO=color;
 ROUGHNESS=.96;
 // A small diffuse floor preserves grass detail in the deepest canyon shade.
 EMISSION=color*.10;
}
