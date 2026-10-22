shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
// Retail teleporter_shield.shader_transparent_generic, specialized to this
// scenery's unconnected A-out (0). The seven combiner stages reduce to these
// equations: stages 3/4 write alpha which stage 5 overwrites. Original texture
// channels, .4 constant, cyan lower-bound color, periods and additive fade are
// retained. These are original green bitmap effects, not a procedural swirl.
uniform sampler2D plasma : filter_linear_mipmap, repeat_enable;
uniform sampler2D energy_mask : filter_linear_mipmap, repeat_enable;
uniform sampler2D shield : filter_linear_mipmap, repeat_enable;
void fragment(){
 vec4 p0=texture(plasma,UV+vec2(-TIME/10.0,-TIME/6.0));
 vec4 mask=texture(energy_mask,UV);
 vec4 detail=texture(shield,UV);
 float c0=0.6*mask.a+0.4*p0.a;
 float c1=detail.a*0.5+(1.0-detail.a)*c0;
 float a1=detail.b*0.5+(1.0-detail.b)*c0;
 // Stage 1 reads stage 0's blue register, before the color writeback.
 float contrast=clamp(c1+0.5-a1,0.0,1.0);
 // The second plasma layer writes stage-0 alpha, which stage 1 overwrites
 // without reading it. Stages 3/4 are similarly overwritten by stage 5.
 float alpha=contrast+contrast*(1.0-contrast);
 vec3 color=clamp((vec3(alpha)+vec3(0.0,0.329412,0.423529))*detail.rgb,0.0,1.0);
 float facing=abs(dot(normalize(NORMAL),normalize(VIEW)));
 ALBEDO=color*facing;
 ALPHA=1.0;
}
