shader_type spatial;
render_mode cull_disabled;
uniform bool animate = true;
uniform vec4 cloth_color : source_color = vec4(0.40,0.09,0.13,1.0);
uniform vec4 trim_color : source_color = vec4(0.94,0.72,0.43,1.0);
uniform float clock_time = 0.0;
uniform float neon_strength = 0.0;
void vertex() {
 float t=animate ? clock_time : 0.0;
 float free_edge=UV.y;
 VERTEX.z += sin(VERTEX.y*3.0+t*2.5+VERTEX.x)*0.23*free_edge;
 VERTEX.x += sin(VERTEX.y*4.0+t*1.8)*0.035*free_edge;
}
void fragment() {
 vec2 p=UV-vec2(0.5,0.46);
 float flower=0.15+0.025*cos(atan(p.y,p.x)*5.0);
 float crest=1.0-smoothstep(flower,flower+0.01,length(p));
 float border=step(UV.x,0.07)+step(0.93,UV.x)+step(0.92,UV.y);
 ALBEDO=mix(cloth_color.rgb,trim_color.rgb,clamp(crest+border,0.0,1.0));
 if(neon_strength>0.0){
  ALBEDO=mix(ALBEDO,vec3(.24,.80,.86),crest);
  EMISSION=(crest*vec3(.20,.80,.88)+clamp(border,0.0,1.0)*trim_color.rgb)*neon_strength;
 }
 ROUGHNESS=0.9;
}
