uniform vec2 attack_center=vec2(0.0);
uniform float attack_radius=0.0;
vec3 attack_range_ink(vec3 color,vec3 point,vec3 normal){
 if(attack_radius<=0.0 || normal.y<.3){return color;}
 float edge=abs(length(point.xz-attack_center)-attack_radius);
 float aa=max(fwidth(edge),.025);
 float ring=1.0-smoothstep(.035,.035+aa,edge);
 return mix(color,vec3(.72,.76,.65),ring*.10);
}
