shader_type spatial;
render_mode unshaded;
uniform sampler2D facet_paint : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
varying float facet_light;
void vertex(){
 // Eight source frames turn the square crystal by one quarter-turn in 800 ms.
 float a=TIME*1.9634954085;
 mat3 turn=mat3(vec3(cos(a),0.0,-sin(a)),vec3(0.0,1.0,0.0),vec3(sin(a),0.0,cos(a)));
 VERTEX=turn*VERTEX;
 NORMAL=turn*NORMAL;
 facet_light=clamp(dot(NORMAL,normalize(vec3(-.65,.75,.50)))*.7+.45,0.0,1.0);
}
void fragment(){
 vec3 cyan=texture(facet_paint,UV).rgb*(.90+facet_light*.10);
 ALBEDO=cyan;
}
