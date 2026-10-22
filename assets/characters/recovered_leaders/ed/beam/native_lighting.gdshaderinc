// SC06/016 room801891DC, original GTE NCCT/NCCS integer stages.
// COLOR_0.r stores a byte normal index. A 2xN texture preserves raw Q12 bytes.
// Modern pose orientation is quantized to Q12; native growth scale is supplied
// separately so scene fit, pickup growth and adapted attack range do not light it.
uniform vec3 native_scale = vec3(1.0);
uniform sampler2D native_normals : filter_nearest, repeat_disable;

int native_dot(ivec3 a, ivec3 b) {
	return a.x*b.x + a.y*b.y + a.z*b.z;
}
vec3 native_axis(vec3 axis, vec3 fallback) {
	float magnitude = length(axis);
	return magnitude > 0.000001 ? axis / magnitude : fallback;
}
ivec3 native_gpu_rgb(vec3 packed_normal, ivec3 rgb, mat4 model) {
	float row = (floor(packed_normal.r*255.0+0.5)+0.5)/float(textureSize(native_normals,0).y);
	ivec3 low_bytes = ivec3(round(textureLod(native_normals,vec2(0.25,row),0.0).rgb*255.0));
	ivec3 high_bytes = ivec3(round(textureLod(native_normals,vec2(0.75,row),0.0).rgb*255.0));
	ivec3 n = low_bytes + high_bytes*256 - ivec3(4096);
	ivec3 scale_q12 = ivec3(round(native_scale * 4096.0));
	// MODEL columns are Godot-world vectors; C=(x,-y,-z) returns source world.
	vec3 cx = native_axis(model[0].xyz, vec3(1.0,0.0,0.0)) * vec3(1.0,-1.0,-1.0);
	vec3 cy = native_axis(model[1].xyz, vec3(0.0,1.0,0.0)) * vec3(1.0,-1.0,-1.0);
	vec3 cz = native_axis(model[2].xyz, vec3(0.0,0.0,1.0)) * vec3(1.0,-1.0,-1.0);
	// 80020F34 scales each integer rotation column, then80052F04 forms L*R.
	ivec3 x = (ivec3(round(cx*4096.0))*scale_q12.x) >> ivec3(12);
	ivec3 y = (ivec3(round(cy*4096.0))*scale_q12.y) >> ivec3(12);
	ivec3 z = (ivec3(round(cz*4096.0))*scale_q12.z) >> ivec3(12);
	ivec3 light0 = ivec3(0,-4096,0);
	ivec3 light1 = ivec3(0,-1365,-3900);
	ivec3 light2 = ivec3(0,4096,0);
	ivec3 l0 = ivec3(native_dot(light0,x),native_dot(light0,y),native_dot(light0,z)) >> ivec3(12);
	ivec3 l1 = ivec3(native_dot(light1,x),native_dot(light1,y),native_dot(light1,z)) >> ivec3(12);
	ivec3 l2 = ivec3(native_dot(light2,x),native_dot(light2,y),native_dot(light2,z)) >> ivec3(12);
	ivec3 ir = clamp(ivec3(native_dot(l0,n),native_dot(l1,n),native_dot(l2,n)) >> ivec3(12),ivec3(0),ivec3(32767));
	ivec3 color = ivec3(native_dot(ivec3(401,2875,819),ir),native_dot(ivec3(819,2875,401),ir),native_dot(ivec3(1220,3276,1638),ir));
	ir = clamp(ivec3(2048)+(color >> ivec3(12)),ivec3(0),ivec3(32767));
	return clamp((rgb*ir) >> ivec3(12),ivec3(0),ivec3(255));
}
