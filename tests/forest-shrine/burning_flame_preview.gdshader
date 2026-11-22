shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
#include "res://assets/vfx/edo/brush_noise.gdshaderinc"
uniform float burn_clock=0.0;
varying flat vec2 phase_opacity;
void vertex() { phase_opacity=INSTANCE_CUSTOM.xy; }
void fragment() {
 float y=1.0-UV.y;
 float phase=burn_clock*5.0+phase_opacity.x*5.0;
 float flow=brush_noise(vec2(UV.x*5.5,y*3.0-burn_clock*3.8));
 float sway=sin(y*9.0-phase)*0.08*y;
 float width=0.34*pow(max(0.0,1.0-y),0.7);
 float silhouette=1.0-smoothstep(width,width+0.05,abs(UV.x-0.5+sway));
 float height_mask=smoothstep(0.0,0.12,y)*(1.0-smoothstep(0.75+flow*0.22,1.0,y));
 float hot=smoothstep(0.3,0.82,flow);
 vec3 pigment=mix(vec3(0.8,0.035,0.008),vec3(1.0,0.35,0.025),flow);
 pigment=mix(pigment,vec3(1.0,0.83,0.32),hot*0.9*(1.0-y));
 ALBEDO=pigment;
 ALPHA=silhouette*height_mask*phase_opacity.y*(0.5+flow*0.5);
}
