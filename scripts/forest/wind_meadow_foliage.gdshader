shader_type spatial;
render_mode cull_disabled;
uniform bool tree = false;
uniform float strength = .12;
uniform bool canopy = false;
uniform bool canopy_cutaway = false;
uniform vec2 hero_position = vec2(0.0);
varying vec3 tint;
varying vec3 world;
void vertex(){
 vec3 origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
 float height=tree ? max(0.0,VERTEX.y-2.8)*.24 : max(0.0,VERTEX.y);
 float wave=sin(TIME*1.7+origin.x*.37+origin.z*.23)+.35*sin(TIME*2.8+origin.z*.7);
 VERTEX.x+=wave*strength*height*height;
 VERTEX.z+=cos(TIME*1.1+origin.x*.22)*strength*height*.4;
 if(!tree){VERTEX*=1.0-smoothstep(28.0,46.0,distance(origin.xz,CAMERA_POSITION_WORLD.xz));}
 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 tint=COLOR.rgb;
}
void fragment(){
 if(canopy && canopy_cutaway && distance(world.xz,hero_position)<10.0){discard;}
 ALBEDO=tint; ROUGHNESS=1.0; EMISSION=tint*.075;
}
void light(){
 float wrapped=clamp((dot(NORMAL,LIGHT)+.45)/1.45,0.0,1.0);
 DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*ATTENUATION*(.2+.8*smoothstep(.05,.9,wrapped))/3.14159265;
}
