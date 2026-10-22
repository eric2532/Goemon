shader_type spatial;
render_mode cull_back, unshaded;
uniform sampler2D visibility_map : filter_linear, repeat_disable;
uniform vec4 base_color : source_color = vec4(0.38,0.53,0.27,1.0);
uniform bool ground_surface = false;
uniform bool show_grid = false;
uniform vec2 hero_position = vec2(0.0);
uniform bool canopy_cutaway = false;
uniform bool canopy_layer = false;
varying vec3 world_point;
varying vec3 object_origin;
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;object_origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;}
void fragment(){
 vec2 sample_point=ground_surface ? world_point.xz : object_origin.xz;
 vec2 map_uv=(sample_point/6.0+vec2(40.5))/80.0;
 vec2 sight=texture(visibility_map,map_uv).rg;
 if(canopy_layer && canopy_cutaway && distance(object_origin.xz,hero_position)<15.0) discard;
 vec3 color=base_color.rgb*COLOR.rgb;
 float noise=sin(world_point.x*.11+sin(world_point.z*.17))*sin(world_point.z*.23);
 if(ground_surface){
  color=mix(vec3(.25,.38,.22),vec3(.46,.56,.29),noise*.18+.6);
  float track=min(abs(world_point.x-9.0*sin(world_point.z*.014)),abs(world_point.z-8.0*sin(world_point.x*.018)));
  float path=1.0-smoothstep(3.0,8.0,track);
  float court=1.0-smoothstep(16.0,29.0,length(world_point.xz));
  color=mix(color,vec3(.57,.48,.32),max(path*.68,court*.82));
  color=pow(color,vec3(2.2));
  if(show_grid){vec2 line=abs(fract(world_point.xz/6.0+.5)-.5);float grid=smoothstep(.478,.499,max(line.x,line.y));color=mix(color,vec3(.85,.78,.56),grid*.22*sight.r);}
 }
 // Woodland is scenery, not scouting information. Only the visibility map
 // controls explored paths/grid and remembered versus currently lit ground.
 float explored=smoothstep(.04,.96,sight.r);
 float visible=smoothstep(.05,.9,sight.g);
 vec3 hidden;
 if(ground_surface){
  hidden=pow(mix(vec3(.16,.235,.205),vec3(.20,.28,.23),noise*.2+.5),vec3(2.2));
 }else{
  hidden=mix(pow(vec3(.075,.15,.13),vec3(2.2)),color,.48);
  hidden*=mix(.8,1.2,clamp(world_point.y/28.0,0.0,1.0));
 }
 color=mix(hidden,color*mix(.50,1.0,visible),explored);
 // Horizontal distance keeps preparation readable even with its high camera.
 // Successive rows fade into sage mist instead of ending at a black horizon.
 float haze=smoothstep(60.0,255.0,distance(world_point.xz,hero_position));
 vec3 mist=pow(vec3(.42,.51,.44),vec3(2.2));
 color=mix(color,mist,haze*.72*(1.0-visible*.45));
 ALBEDO=color;ROUGHNESS=1.0;
}
