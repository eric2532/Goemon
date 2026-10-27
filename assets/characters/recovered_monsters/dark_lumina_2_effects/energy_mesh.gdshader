shader_type spatial;
render_mode unshaded, cull_back, blend_add, depth_draw_never;
varying float opacity;
void vertex(){opacity=clamp(INSTANCE_CUSTOM.y*4.0,0.0,1.0);}
void fragment(){ALBEDO=COLOR.rgb;ALPHA=COLOR.a*opacity;}
