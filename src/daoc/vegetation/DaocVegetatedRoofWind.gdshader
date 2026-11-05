shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform float alpha_cutoff : hint_range(0.05, 0.95) = 0.5;
uniform vec2 wind_direction = vec2(0.82, 0.57);
uniform float wind_speed = 1.35;
uniform float wind_gust_strength = 0.72;
uniform float roof_strength = 0.025;

void vertex() {
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float long_wave = sin(TIME * wind_speed * 0.22
		+ dot(world_position.xz, wind_direction) * 0.012);
	float gust_wave = sin(TIME * wind_speed * 0.31
		+ dot(world_position.xz, wind_direction) * 0.018);
	float gust = mix(1.0, mix(0.65, 1.15, gust_wave * 0.5 + 0.5), wind_gust_strength);
	// Le chaume reste solidaire de la charpente : petite respiration verticale,
	// sans flexion de canopée ni frisson individuel de feuille.
	VERTEX.y += long_wave * roof_strength * gust;
}

void fragment() {
	vec4 roof = texture(albedo_texture, UV);
	if (roof.a < alpha_cutoff) {
		discard;
	}
	ALBEDO = roof.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.08;
}
