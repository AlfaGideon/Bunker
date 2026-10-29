shader_type spatial;
render_mode cull_disabled;
uniform bool still = false;
varying vec3 world_pos;
void vertex(){
 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 float t = still ? 0.0 : TIME;
 VERTEX.y += 0.035 * sin(world_pos.x * 0.8 + t * 1.3) * cos(world_pos.z * 0.6 - t * 0.9);
}
void fragment(){
 float t = still ? 0.0 : TIME;
 vec2 p = world_pos.xz;
 float wave = sin(p.x * 1.4 + p.y * 0.7 + t * 1.5) * cos(p.y * 1.2 - t * 0.8);
 float ripples = pow(max(0.0, sin(p.x * 3.0 + p.y * 2.4 + wave * 1.4 - t * 2.0)), 7.0);
 ALBEDO = mix(vec3(0.035, 0.12, 0.17), vec3(0.18, 0.32, 0.35), wave * 0.22 + 0.35) + ripples * vec3(0.1, 0.16, 0.17);
 ROUGHNESS = 0.28;
 METALLIC = 0.05;
 SPECULAR = 0.65;
}
