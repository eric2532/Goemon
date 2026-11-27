uniform float route_finish=0.0;
uniform vec3 route_tint=vec3(.4,.4,.35);
uniform bool route_preserve_ink=false;
uniform sampler2D route_scope : filter_linear_mipmap,repeat_disable;
uniform vec4 route_scope_bounds=vec4(0.0);
float route_weight(vec3 point){
 if(route_finish<=0.0)return 0.0;
 if(route_scope_bounds.z<=0.0)return route_finish;
 vec2 uv=(point.xz-route_scope_bounds.xy)/route_scope_bounds.zw;
 if(any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0))))return 0.0;
 return route_finish*textureLod(route_scope,uv,1.0).r;
}
