shader_type spatial;
render_mode cull_disabled;
uniform bool animate = true;
uniform float clock_time = 0.0;
void vertex() {
 float t = animate ? clock_time : 0.0;
 VERTEX.y += (sin(VERTEX.x*2.2+t*1.6)+cos(VERTEX.z*2.8+t))*0.045;
}
void fragment() {
 float t = animate ? clock_time : 0.0;
 float wave=sin(UV.x*60.0+t*2.0+sin(UV.y*25.0-t))*sin(UV.y*42.0+t);
 float edge=min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y));
 float foam=(1.0-smoothstep(0.025,0.065,edge))*0.8+smoothstep(0.90,1.0,wave)*0.3;
 ALBEDO=mix(vec3(0.025,0.27,0.30),vec3(0.55,0.92,0.83),foam);
 ROUGHNESS=0.25;
 METALLIC=0.3;
 EMISSION=vec3(0.02,0.15,0.14)*foam;
 vec3 local_normal = normalize(vec3(cos(UV.x*60.0+t)*0.12,0.98,sin(UV.y*42.0+t)*0.12));
 NORMAL=normalize(mat3(VIEW_MATRIX) * MODEL_NORMAL_MATRIX * local_normal);
}
