shader_type spatial;
render_mode cull_disabled;
uniform bool still = false;
varying vec3 world_pos;
varying float crest;
void vertex(){
 vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 float t = still ? 0.0 : TIME;
 float a = sin(wp.x * 0.42 + wp.z * 0.25 - t * 1.15);
 float b = sin(wp.z * 0.62 - wp.x * 0.19 - t * 0.78);
 float c = sin(wp.x * 0.95 + wp.z * 0.7 - t * 1.7);
 float wave = a * 0.14 + b * 0.09 + c * 0.035;
 VERTEX.y += wave;
 crest = wave;
 world_pos = wp;
}
void fragment(){
 float t = still ? 0.0 : TIME;
 vec2 p = world_pos.xz;
 float a = sin(p.x * 0.42 + p.y * 0.25 - t * 1.15);
 float b = sin(p.y * 0.62 - p.x * 0.19 - t * 0.78);
 vec3 n = normalize(vec3(-0.14 * 0.42 * cos(p.x * 0.42 + p.y * 0.25 - t * 1.15) + 0.09 * 0.19 * cos(p.y * 0.62 - p.x * 0.19 - t * 0.78), 1.0, -0.14 * 0.25 * cos(p.x * 0.42 + p.y * 0.25 - t * 1.15) - 0.09 * 0.62 * cos(p.y * 0.62 - p.x * 0.19 - t * 0.78)));
 NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
 float foam = smoothstep(0.13, 0.24, crest) * (0.5 + 0.5 * sin(p.x * 2.3 + p.y * 1.8 - t));
 ALBEDO = mix(vec3(0.025, 0.10, 0.15), vec3(0.12, 0.30, 0.34), 0.4 + 0.2 * (a + b)) + foam * vec3(0.28, 0.35, 0.34);
 ROUGHNESS = 0.28;
 SPECULAR = 0.7;
}
