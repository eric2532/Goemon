float brush_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float brush_noise(vec2 p) {
 vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
 return mix(mix(brush_hash(i), brush_hash(i + vec2(1.0, 0.0)), f.x),
            mix(brush_hash(i + vec2(0.0, 1.0)), brush_hash(i + vec2(1.0)), f.x), f.y);
}
