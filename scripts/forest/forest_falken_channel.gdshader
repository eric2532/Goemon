shader_type spatial;
render_mode cull_back;

varying vec2 channel_point;
varying flat vec4 banks;

void vertex() {
 channel_point=VERTEX.xz;
 banks=COLOR;
}

void fragment() {
 vec2 p=channel_point;
 float current=sin(p.x*2.6+p.y*1.3-TIME*1.9+sin(p.y*.81-TIME*.5)*.9);
 float ripple=sin(p.y*3.8-p.x*.72+TIME*1.37);
 float glint=pow(max(0.0,current),12.0)*smoothstep(-.68,.9,ripple)*.65;
 vec4 distances=mix(vec4(1.0),vec4(UV.x,1.0-UV.x,UV.y,1.0-UV.y),banks);
 float edge=min(min(distances.x,distances.y),min(distances.z,distances.w));
 float shallow=1.0-smoothstep(.04,.34,edge);
 float seam=1.0-smoothstep(.045,.11,abs(edge-.090+ripple*.014));
 vec3 depth=mix(vec3(.014,.073,.094),vec3(.039,.183,.167),shallow);
 ALBEDO=depth*(.88+current*.10+ripple*.045)+vec3(.075,.21,.19)*(glint*.65+seam*.28);
 EMISSION=depth*.34+vec3(.028,.09,.10)*glint;
 ROUGHNESS=.26;
 SPECULAR=.47;
}
