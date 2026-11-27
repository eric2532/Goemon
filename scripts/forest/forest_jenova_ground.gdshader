shader_type spatial;
#include "res://scripts/forest/forest_archive_palette.gdshaderinc"
render_mode cull_back;
uniform sampler2D native_texture : source_color,filter_linear_mipmap_anisotropic,repeat_disable;
uniform sampler2D masks_texture : filter_linear_mipmap_anisotropic,repeat_disable;
uniform sampler2D scope_texture : filter_linear,repeat_disable;
uniform sampler2D brush_texture : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform vec4 grass_color : source_color = vec4(.42,.47,.30,1.0);
uniform vec4 dirt_color : source_color = vec4(.48,.44,.32,1.0);
uniform vec4 stone_color : source_color = vec4(.55,.51,.45,1.0);
varying vec3 point;
void vertex(){point=VERTEX;}
float hash(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}
void fragment(){
 vec2 p=point.xz;
 vec2 mask=texture(masks_texture,UV).rg;
 float brush=texture(brush_texture,p*.055).g;
 float stroke=floor(brush*7.0)/7.0;
 float broad=texture(brush_texture,p*.018).g;
 vec3 grass=mix(grass_color.rgb,dirt_color.rgb,mask.g*.35)*(.91+stroke*.16+broad*.10);
 vec2 grid=p/vec2(1.30,.72);
 grid.x+=mod(floor(grid.y),2.0)*.5;
 vec2 edge=min(fract(grid),1.0-fract(grid));
 float seam=1.0-smoothstep(.018,.045+max(fwidth(grid.x),fwidth(grid.y)),min(edge.x,edge.y));
 vec3 paving=stone_color.rgb*(.94+hash(floor(grid))*.08-seam*.20+stroke*.055);
 vec3 color=mix(grass,paving,smoothstep(.12,.76,mask.r));
 float weight=texture(scope_texture,(p+vec2(151.5))/300.0).r;
 // Fade to exact native paint before the unchanged inaccessible boundary.
 ALBEDO=color*weight;
 EMISSION=archive_color(texture(native_texture,UV,1.0).rgb)*(1.0-weight)+color*.10*weight;
 ROUGHNESS=1.0;SPECULAR=.05;
}
