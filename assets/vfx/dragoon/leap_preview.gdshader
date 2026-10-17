shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float inner_ratio = 0.6363636;
uniform float middle_ratio = 0.8181818;
void fragment() {
 float r=length(UV*2.0-1.0);
 if(r>1.0){discard;}
 float outer=1.0-smoothstep(0.005,0.015,abs(r-0.985));
 float inner=1.0-smoothstep(0.003,0.008,abs(r-inner_ratio));
 float middle=1.0-smoothstep(0.003,0.008,abs(r-middle_ratio));
 float center=1.0-smoothstep(0.015,0.030,r);
 float fill=0.095*(1.0-smoothstep(0.94,1.0,r));
 ALBEDO=mix(vec3(0.08,0.38,0.95),vec3(0.35,0.80,1.0),max(outer,center));
 ALPHA=clamp(fill+outer*0.40+(inner+middle)*0.12+center*0.35,0.0,0.55);
}
