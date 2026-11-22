// Original indexed pixels and pose remain authoritative; only cold surfaces change.
float ice_sprite_pixel(vec2 at) {
 if (any(lessThan(at, atlas_rect.xy)) || any(greaterThanEqual(at, atlas_rect.xy + atlas_rect.zw))) return 0.0;
 return step(0.5 / 255.0, texelFetch(pixels, ivec3(ivec2(at), int(atlas_rows.x)), 0).r);
}

vec3 ice_sprite_surface(vec3 paint, vec2 at, float cold) {
 if (abs(cold) < 0.001) return paint;
 float frost = abs(cold);
 vec2 p = at - atlas_rect.xy;
 float edge = 1.0 - min(min(ice_sprite_pixel(at + vec2(1, 0)), ice_sprite_pixel(at - vec2(1, 0))),
                        min(ice_sprite_pixel(at + vec2(0, 1)), ice_sprite_pixel(at - vec2(0, 1))));
 float inner = 1.0 - min(min(ice_sprite_pixel(at + vec2(2, 0)), ice_sprite_pixel(at - vec2(2, 0))),
                         min(ice_sprite_pixel(at + vec2(0, 2)), ice_sprite_pixel(at - vec2(0, 2))));
 float patch = sin(p.x * 0.26 + sin(p.y * 0.22)) * cos(p.y * 0.29 - p.x * 0.09);
 float coverage = smoothstep(0.62 - frost * 0.63, 0.9 - frost * 0.63, patch);
 float crack_a = 1.0 - smoothstep(0.35, 0.9, abs(p.x - (7.0 + p.y * 0.46 + sin(p.y * 0.4) * 1.2)));
 float crack_b = (1.0 - smoothstep(0.3, 0.8, abs(p.x - (37.0 - p.y * 0.55 + sin(p.y * 0.6))))) * step(14.0, p.y);
 float cracks = max(crack_a, crack_b) * smoothstep(0.45, 0.9, frost);
 float coat = frost;
 vec3 result = mix(paint, vec3(0.54, 0.83, 0.92), coat * (0.12 + coverage * 0.3));
 result = mix(result, vec3(0.64, 0.89, 0.98), coat * max(inner * 0.7, coverage * 0.48));
 result = mix(result, vec3(0.91, 0.98, 1.0), coat * max(edge * (0.42 + coverage * 0.55), cracks * 0.72));
 return result;
}
