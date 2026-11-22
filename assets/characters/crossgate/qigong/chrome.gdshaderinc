vec3 rainbow_chrome(vec2 uv, float brightness, float time) {
 vec2 p = (uv - 0.5) * 2.0;
 float z = sqrt(max(0.0, 1.0 - dot(p, p)));
 float horizon = p.y + 0.25 * p.x + 0.12 * sin(time * 0.5);
 float silver = mix(0.12, 0.85, smoothstep(-0.12, 0.18, horizon));
 float reflection = (horizon + 0.32) * 5.0;
 silver += 0.45 * exp(-reflection * reflection);
 vec3 rainbow = 0.5 + 0.5 * cos(6.283185 * (p.x * 0.40 + p.y * 0.35 + z * 0.10 + time * 0.025 + vec3(0.0, 0.333333, 0.666667)));
 vec3 metal = mix(vec3(silver), rainbow * (0.35 + 0.65 * silver), 0.45);
 float glint = pow(max(0.0, dot(vec3(p, z), normalize(vec3(-0.4, -0.55, 0.8)))), 26.0);
 float rim = pow(1.0 - z, 3.0) * 0.35;
 return clamp((metal + vec3(glint * 0.85 + rim)) * mix(0.75, 1.0, brightness), vec3(0.0), vec3(1.0));
}
