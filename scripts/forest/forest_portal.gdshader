shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment(){
 vec2 p=(UV-vec2(.5))*2.0;
 float r=length(p);
 float angle=atan(p.y,p.x);
 float swirl=sin(r*26.0-angle*3.0-TIME*2.4)*.5+.5;
 float rim=smoothstep(.55,.95,r);
 vec3 color=mix(vec3(.10,.035,.30),vec3(.43,.20,.85),swirl*.8+rim*.2);
 color=mix(color,vec3(.65,.83,1.0),pow(swirl,9.0)*rim);
 ALBEDO=color;ALPHA=(1.0-smoothstep(.93,1.0,r))*.88;
}
