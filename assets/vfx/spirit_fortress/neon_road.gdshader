shader_type spatial;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 grid=abs(fract(world_position.xz/vec2(3.0,4.0))-.5);
 float grout=smoothstep(.46,.49,max(grid.x,grid.y));
 float grain=sin(world_position.x*18.3)*sin(world_position.z*21.7);
 ALBEDO=mix(vec3(.08,.105,.15),vec3(.035,.05,.08),grout)+grain*.006;
 ROUGHNESS=.82;
 METALLIC=.15;
}
