shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D caustic_texture : source_color, repeat_enable, filter_linear;
uniform vec3 water_tint : source_color = vec3(0.18, 0.47, 0.58);
uniform float effect_strength : hint_range(0.0, 1.0) = 0.0;
uniform float distortion_strength : hint_range(0.0, 0.03) = 0.006;
uniform float caustic_strength : hint_range(0.0, 0.3) = 0.085;


void fragment() {
	vec2 caustic_uv_a = UV * 5.0 + vec2(TIME * 0.018, -TIME * 0.012);
	vec2 caustic_uv_b = UV.yx * 7.3 + vec2(-TIME * 0.011, TIME * 0.016);
	float caustic_a = texture(caustic_texture, caustic_uv_a).r;
	float caustic_b = texture(caustic_texture, caustic_uv_b).r;
	float caustic = mix(caustic_a, caustic_b, 0.42);
	vec2 distortion = vec2(caustic_a - 0.5, caustic_b - 0.5) * distortion_strength * effect_strength;
	vec3 scene_colour = textureLod(screen_texture, clamp(SCREEN_UV + distortion, vec2(0.001), vec2(0.999)), 0.55 * effect_strength).rgb;
	vec3 submerged_colour = mix(scene_colour, scene_colour * water_tint, 0.46);
	submerged_colour += water_tint * max(caustic - 0.48, 0.0) * caustic_strength;
	float vignette = smoothstep(0.82, 0.28, distance(UV, vec2(0.5)));
	submerged_colour *= mix(0.78, 1.0, vignette);
	COLOR = vec4(mix(scene_colour, submerged_colour, effect_strength), 1.0);
}
