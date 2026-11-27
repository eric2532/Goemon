shader_type spatial;
render_mode cull_back, depth_prepass_alpha;
uniform sampler2D native_mask : filter_nearest, repeat_disable;
uniform bool use_native_mask = true;
uniform float maximum_opacity = 0.62;
uniform vec4 glass_color : source_color=vec4(0.6,0.8,0.9,0.35);
void fragment() {
 if(use_native_mask && texture(native_mask,UV).a<0.5) { discard; }
 // The unseen glass has its own round-surface shading. A grazing rim gives
 // the original curved envelope depth without wrapping its front painting.
 float edge=pow(1.0-clamp(abs(dot(normalize(NORMAL),normalize(VIEW))),0.0,1.0),3.0);
 ALBEDO=mix(glass_color.rgb,vec3(0.88,0.94,0.96),edge*0.45);
 ALPHA=mix(glass_color.a*0.55,maximum_opacity,edge);
 ROUGHNESS=0.18;
 SPECULAR=0.75;
 RIM=0.35;
}
