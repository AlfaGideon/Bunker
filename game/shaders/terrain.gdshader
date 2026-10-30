shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(0.3, 0.35, 0.3, 1.0);
uniform float dryness = 0.0;
varying vec3 world_pos;
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise2(vec2 p) {
 vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
 return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec2 p = world_pos.xz;
 float broad = noise2(p * 0.18);
 float detail = noise2(p * 2.3);
 float grain = noise2(p * 9.0);
 float tracks = smoothstep(0.6, 0.8, noise2(p * vec2(0.4, 1.5)));
 vec3 earth = mix(tint.rgb * 0.58, tint.rgb * 1.18, broad * 0.65 + detail * 0.35);
 earth = mix(earth, tint.rgb * vec3(1.12, 0.98, 0.78), dryness * tracks * 0.28);
 ALBEDO = earth * (0.88 + 0.22 * grain);
 ROUGHNESS = 0.93;
}
