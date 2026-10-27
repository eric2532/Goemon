shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform sampler2D wave_texture : source_color, filter_nearest, repeat_disable;
varying float fade;
varying float frame;
void vertex() {
 float tick=floor(INSTANCE_CUSTOM.x*30.0);
 frame=mod(tick,8.0);
 float rise[8]=float[8](2.0,3.5,4.5,4.25,4.0,3.0,2.0,1.0);
 float expansion=.375+(min(tick,8.0)*32.0+max(tick-8.0,0.0)*128.0)/4096.0;
 VERTEX.xz*=expansion;
 VERTEX.y*=tick<1.0?0.0:(tick<=8.0?rise[int(tick)-1]:1.0);
 float turn=tick*148.0*6.28318530718/4096.0;
 VERTEX.xz=mat2(vec2(cos(turn),-sin(turn)),vec2(sin(turn),cos(turn)))*VERTEX.xz;
 fade=clamp((1055.5-length(VERTEX.xz))/127.5,0.0,1.0);
}
void fragment() {
 vec4 paint=texture(wave_texture,vec2((121.0-frame*8.0)/256.0-UV.x,UV.y));
 ALBEDO=paint.rgb;
 ALPHA=paint.a*fade;
}
