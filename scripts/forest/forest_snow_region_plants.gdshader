shader_type spatial;
render_mode cull_disabled;
uniform vec4 leaf_color : source_color=vec4(.4,.5,.3,1.0);
uniform float snow_amount=0.0;
uniform float height=1.0;
varying float level;
varying vec3 normal_;
void vertex(){level=VERTEX.y/max(height,.1);normal_=NORMAL;}
void fragment(){
 float snow=smoothstep(.26,.75,level)*smoothstep(-.2,.6,normal_.y)*clamp(snow_amount*2.0,0.0,1.0);
 ALBEDO=mix(leaf_color.rgb,vec3(.86,.92,.94),snow);
 ROUGHNESS=1.0;SPECULAR=.04;
}
