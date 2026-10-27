shader_type spatial;
uniform sampler2D roads : filter_linear, repeat_disable;
uniform sampler2D cliff : source_color, filter_linear_mipmap, repeat_enable;
uniform bool show_grid=false;
uniform float map_extent=240.0;
varying vec3 world;
varying vec3 normal_world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;normal_world=(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 float patch=sin(world.x*.031+sin(world.z*.043)*1.8)*.5+.5;
 float brush=sin(world.x*1.8+sin(world.z*2.7)*2.0)*sin(world.z*3.1)*.009;
 vec3 grass=mix(vec3(.15,.28,.055),vec3(.29,.43,.10),patch)+brush;
 float detail=1.0-smoothstep(.2,.7,max(length(dFdx(world.xz)),length(dFdy(world.xz))));
 float strokes=smoothstep(.6,.95,sin(world.x*17.0+sin(world.z*4.0)*2.0))*smoothstep(0.0,.8,sin(world.z*8.0+world.x*1.7));
 grass*=1.0+strokes*.12*detail;
 float path=texture(roads,(world.xz+map_extent)/(map_extent*2.0)).r;
 vec3 earth=mix(vec3(.32,.28,.17),vec3(.46,.41,.26),patch);
 float rock=smoothstep(.24,.65,1.0-normalize(normal_world).y);
 vec3 weights=pow(abs(normalize(normal_world)),vec3(4.0));weights/=weights.x+weights.y+weights.z;
 vec3 stone=(texture(cliff,world.zy*.045).rgb*weights.x+texture(cliff,world.xz*.045).rgb*weights.y+texture(cliff,world.xy*.045).rgb*weights.z)*vec3(.78,.88,.92);
 ALBEDO=mix(mix(grass,earth,path*.9),stone,rock);
 if(show_grid){vec2 grid=abs(fract((world.xz+3.0)/6.0)-.5);ALBEDO*=1.0-.13*max(smoothstep(.48,.5,grid.x),smoothstep(.48,.5,grid.y));}
 ROUGHNESS=1.0;
}
