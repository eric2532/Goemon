shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform sampler2D pose_texture : filter_nearest, repeat_disable;
uniform sampler2D paint_texture : source_color, filter_nearest, repeat_disable;
uniform bool textured=false;
uniform vec4 tint : source_color=vec4(1.0);
uniform int pose_count=1;
uniform bool loop_pose=false;
uniform float pose_start_tick=0.0;
varying float opacity;
void vertex(){
 int row=int(floor(INSTANCE_CUSTOM.x*30.0+pose_start_tick));
 row=loop_pose?row%pose_count:clamp(row,0,pose_count-1);
 VERTEX=texelFetch(pose_texture,ivec2(int(round(UV2.x)),row),0).xyz;
 opacity=clamp(INSTANCE_CUSTOM.y*5.0,0.0,1.0);
}
void fragment(){
 vec4 paint=COLOR*tint;
 if(textured)paint*=texture(paint_texture,UV);
 ALBEDO=paint.rgb;ALPHA=paint.a*opacity;
}
