shader_type spatial;
render_mode unshaded,cull_disabled;
uniform sampler2D source_art : source_color,filter_nearest_mipmap,repeat_disable;
void vertex(){
 vec3 up=vec3(0.0,1.0,0.0);
 vec3 right=normalize(cross(up,INV_VIEW_MATRIX[2].xyz));
 vec3 back=normalize(cross(right,up));
 float scale=length(MODEL_MATRIX[0].xyz);
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(right,0.0),vec4(up,0.0),vec4(back,0.0),MODEL_MATRIX[3]);
 VERTEX*=scale;
}
void fragment(){
 vec4 paint=texture(source_art,UV);
 if(paint.a<.5)discard;
 ALBEDO=paint.rgb;
}
