shader_type spatial;
render_mode cull_back;
varying vec3 point;
void vertex(){ point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float brush(vec2 p){ return sin(p.x*.19+sin(p.y*.23)*2.0)*sin(p.y*.13)+sin(p.x*.83+p.y*.57)*.2; }
void fragment(){
 float variation = brush(point.xz)*.5+.5;
 vec3 grass = mix(vec3(.15,.28,.055),vec3(.29,.43,.10),variation);
 float strokes=smoothstep(.6,.95,sin(point.x*17.0+sin(point.y+point.z*4.0)*2.0))*smoothstep(.0,.8,sin(point.z*8.0+point.x*1.7));
 grass*=1.0+strokes*.12;
 float path = abs(point.x-(-4.0+sin(point.z*.055)*5.0));
 float worn = 1.0-smoothstep(1.3,2.7+sin(point.z*.8)*.15,path);
 vec3 earth = mix(vec3(.32,.28,.17),vec3(.46,.41,.26),variation);
 float shore = length((point.xz-vec2(28.0,-13.0))/vec2(19.0,29.0));
 float sand = (1.0-smoothstep(1.0,1.13,shore));
 ALBEDO=mix(mix(grass,earth,worn*.85),vec3(.57,.57,.34),sand*.7);
 ROUGHNESS=1.0;
}
