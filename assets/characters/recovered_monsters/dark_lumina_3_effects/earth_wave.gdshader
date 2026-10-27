shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform sampler2D paint_texture : source_color, filter_linear, repeat_enable;
uniform bool textured=false;
uniform float radius=1.0;
varying vec2 ground;
varying float progress;
void vertex(){ground=VERTEX.xz/radius;progress=1.0-INSTANCE_CUSTOM.y;}
void fragment(){
 float r=length(ground);
 float rim=smoothstep(.52,.82,r)*(1.0-smoothstep(.94,1.02,r));
 float bands=.55+.45*sin(r*45.0-progress*12.0);
 vec3 paint=textured?texture(paint_texture,UV+vec2(progress*.12,0)).rgb:COLOR.rgb;
 vec3 amber=mix(vec3(.55,.10,.015),vec3(1.0,.72,.24),rim);
 ALBEDO=amber*(.6+paint*.4)*(1.0+rim);
 ALPHA=clamp(rim*bands*(1.0-smoothstep(.65,1.0,progress)),0.0,1.0);
}
