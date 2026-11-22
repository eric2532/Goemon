vec3 enemy_ice_surface(vec3 paint, vec3 position, vec3 normal, vec3 view, float cold) {
 float coat = abs(cold);
 if (coat < 0.001) return paint;
 vec3 p = position * 3.0;
 float patch = sin(p.x + sin(p.y * 0.7)) * cos(p.z + p.y * 0.9);
 float coverage = smoothstep(0.62 - coat * 0.63, 0.9 - coat * 0.63, patch);
 float rim = pow(1.0 - abs(dot(normalize(normal), normalize(view))), 2.5);
 float crack = 1.0 - smoothstep(0.03, 0.10, abs(sin(p.x + p.y * 0.46 + sin(p.z * 1.3))));
 vec3 result = mix(paint, vec3(0.54, 0.83, 0.92), coat * (0.12 + coverage * 0.3));
 result = mix(result, vec3(0.64, 0.89, 0.98), coat * max(rim * 0.7, coverage * 0.48));
 return mix(result, vec3(0.91, 0.98, 1.0), coat * max(rim * 0.65, crack * smoothstep(0.45, 0.9, coat) * 0.65));
}
