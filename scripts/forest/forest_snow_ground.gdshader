shader_type spatial;
#include "res://scripts/forest/forest_archive_palette.gdshaderinc"
uniform sampler2D native_texture : source_color,filter_linear_mipmap_anisotropic,repeat_disable;
uniform sampler2D earth_texture : filter_nearest,repeat_disable;
uniform sampler2D brush_texture : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 point;
void vertex(){point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 // Guttered atlas mip 1 calms enlarged dither while retaining native paving edges.
 vec4 tex=mix(texture(native_texture,UV,1.0),texture(native_texture,UV),.28);
 if(tex.a<.1)discard;
 vec3 native=archive_color(tex.rgb);
 float snow=smoothstep(.60,.82,min(native.r,min(native.g,native.b)));
 float broad=texture(brush_texture,point.xz*.027).g;
 float fine=texture(brush_texture,point.xz*.23).g;
 vec3 drift=mix(vec3(.69,.80,.86),vec3(.93,.96,.96),smoothstep(.18,.82,broad));
 drift*=.96+floor(fine*6.0)/6.0*.06;
 // Native snow edges, stone pavers and exposed ground retain their exact masks.
 float vegetation=smoothstep(.015,.08,native.g-native.b)*smoothstep(-.08,.035,native.g-native.r);
 vec3 earth=mix(vec3(.36,.34,.29),vec3(.43,.46,.29),vegetation)*(.90+broad*.18);
 float dark_ground=1.0-smoothstep(.52,.68,dot(native,vec3(.2126,.7152,.0722)));
 // Continuous low-frequency paint suppresses tile-to-tile dither; retain paving and snow silhouettes.
 vec3 ground=mix(native,earth,(1.0-snow)*dark_ground*.72*texture(earth_texture,UV).r);
 vec3 color=mix(ground,drift,snow*.88);
 // A restrained fill keeps chunk-shadow triangles from reading as texture seams.
 ALBEDO=color*.78;EMISSION=color*.26;ROUGHNESS=1.0;SPECULAR=.025;
}
