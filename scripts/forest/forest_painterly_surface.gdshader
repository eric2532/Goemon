shader_type spatial;
render_mode cull_back;
uniform vec4 base_color : source_color = vec4(.4,.25,.12,1);
uniform vec3 grain_axis = vec3(0,1,0);
// Wood, stone, slate, foliage, bark, imported painted art, mineral/metal.
uniform float surface_kind = 0.0;
uniform sampler2D brush_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_vertex_color = true;
uniform bool vertex_color_srgb = false;
uniform bool use_base_texture = false;
uniform sampler2D base_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform bool alpha_cutout = false;
uniform float alpha_threshold = .5;
uniform vec4 emission_color : source_color = vec4(0.0);
uniform float emission_strength = 0.0;
uniform bool fog_enabled = false;
uniform sampler2D visibility_map : filter_linear, repeat_disable;
uniform vec2 hero_position = vec2(0.0);
uniform bool canopy_cutaway = false;
uniform bool canopy_layer = false;
varying vec3 local_point;
varying vec3 world_point;
varying vec3 world_normal;
varying vec3 object_origin;
float hash(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}
void vertex(){
 local_point=VERTEX;world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);object_origin=(MODEL_MATRIX*vec4(0,0,0,1)).xyz;
}
void fragment(){
 if(fog_enabled && canopy_layer && canopy_cutaway && distance(object_origin.xz,hero_position)<15.0) discard;
 vec4 tex=use_base_texture ? texture(base_texture,UV*uv_scale+uv_offset) : vec4(1.0);
 if(alpha_cutout && tex.a*base_color.a<alpha_threshold) discard;
 vec3 vertex_color=use_vertex_color ? COLOR.rgb : vec3(1.0);
 if(vertex_color_srgb) vertex_color=pow(vertex_color,vec3(2.2));
 vec3 color=base_color.rgb*tex.rgb*vertex_color;
 vec3 normal=abs(normalize(world_normal));
 vec2 plane=normal.y>max(normal.x,normal.z) ? world_point.xz : (normal.x>normal.z ? world_point.zy : world_point.xy);
 float brush=dot(texture(brush_texture,plane/6.0).rgb,vec3(.2126,.7152,.0722));
 float stroke=floor(smoothstep(.025,.28,brush)*5.0)/5.0;
 color*=.80+stroke*.38;
 float along=dot(local_point,grain_axis);
 vec3 across=local_point-grain_axis*along;
 if(surface_kind<.5 || (surface_kind>3.5 && surface_kind<4.5)){
  float grain=sin((across.x+across.y+across.z)*22.0+sin(along*.9)*1.5);
  color*=.90+smoothstep(-.8,.2,grain)*.14;
  float moss=(1.0-smoothstep(.2,1.9,world_point.y))*.28;
  color=mix(color,vec3(.07,.12,.025),moss);
 }else if(surface_kind<2.5){
  vec2 size_=surface_kind<1.5 ? vec2(2.8,1.35) : vec2(1.45,.8);
  float row=floor(plane.y/size_.y);
  vec2 cell=fract(plane/size_+vec2(mod(row,2.0)*.5,0));
  vec2 seam=min(cell,1.0-cell);
  vec2 aa=fwidth(plane/size_);
  float edge=1.0-smoothstep(.012,.026+max(aa.x,aa.y),min(seam.x,seam.y));
  color*=1.0-edge*.22;
  float block=hash(floor(plane/size_+vec2(mod(row,2.0)*.5,0)));
  color*=.92+block*.16;
  color=mix(color,vec3(.09,.14,.055),smoothstep(.64,.9,brush)*.12);
 }else if(surface_kind<3.5){
  float tip=smoothstep(-2.0,3.6,local_point.y);
  color=mix(color,vec3(.16,.22,.055),.18+tip*.22);
  color*=.86+hash(object_origin.xz)*.26;
 }else if(surface_kind>4.5 && surface_kind<5.5){
  // Keep shrine markings and vertex colors; add a restrained painted finish.
  color*=.97+stroke*.07;
 }
 if(fog_enabled){
  vec2 sight=texture(visibility_map,(object_origin.xz/6.0+vec2(40.5))/80.0).rg;
  float explored=smoothstep(.04,.96,sight.r);float visible=smoothstep(.05,.9,sight.g);
  vec3 hidden=mix(pow(vec3(.075,.15,.13),vec3(2.2)),color,.48);
  hidden*=mix(.8,1.2,clamp(world_point.y/28.0,0.0,1.0));
  color=mix(hidden,color*mix(.50,1.0,visible),explored);
  float haze=smoothstep(60.0,255.0,distance(world_point.xz,hero_position));
  color=mix(color,pow(vec3(.42,.51,.44),vec3(2.2)),haze*.72*(1.0-visible*.45));
 }
 ALBEDO=color;EMISSION=color*.10+emission_color.rgb*emission_strength;
 ROUGHNESS=surface_kind>5.5 ? .65 : .96;SPECULAR=.18;
}
