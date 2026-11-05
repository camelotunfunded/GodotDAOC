shader_type spatial;
render_mode depth_prepass_alpha, cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_texture : hint_roughness_r, filter_linear_mipmap;
uniform sampler2D metallic_texture : hint_default_black, filter_linear_mipmap;
uniform sampler2D ao_texture : hint_default_white, filter_linear_mipmap;
uniform float roughness_amount : hint_range(0.0, 1.0) = 1.0;
uniform float normal_strength : hint_range(0.0, 4.0) = 1.0;
uniform float dielectric_specular : hint_range(0.0, 1.0) = 0.5815071;

uniform float hair_top_y = 1.0;
uniform float hair_bottom_y = 0.0;
uniform float tip_start : hint_range(0.0, 1.0) = 0.3;
uniform float motion_amplitude = 0.08;
uniform float medium_lod_scale : hint_range(0.0, 1.0) = 0.45;
uniform float medium_lod_distance = 1800.0;
uniform float far_lod_distance = 4200.0;
uniform vec2 wind_direction = vec2(0.8, 0.25);
uniform float wind_speed = 1.35;

varying float motion_weight;

void vertex() {
	float height = max(hair_top_y - hair_bottom_y, 0.001);
	float down = clamp((hair_top_y - VERTEX.y) / height, 0.0, 1.0);
	motion_weight = smoothstep(tip_start, 1.0, down);
	float distance_to_camera = distance(NODE_POSITION_WORLD, CAMERA_POSITION_WORLD);
	float lod_scale = 1.0;
	if (distance_to_camera > medium_lod_distance) {
		lod_scale = medium_lod_scale;
	}
	if (distance_to_camera > far_lod_distance) {
		lod_scale = 0.0;
	}
	float phase = TIME * wind_speed + VERTEX.y * 0.11 + VERTEX.x * 0.07;
	float sway = sin(phase) + sin(phase * 0.47 + 1.7) * 0.42 + sin(phase * 1.83 + 0.4) * 0.16;
	vec2 direction = normalize(wind_direction + vec2(0.0001));
	VERTEX.xz += direction * sway * motion_amplitude * motion_weight * lod_scale;
}

void fragment() {
	vec4 albedo = texture(albedo_texture, UV);
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;
	ALPHA_SCISSOR_THRESHOLD = 0.25;
	NORMAL_MAP = texture(normal_texture, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = max(texture(roughness_texture, UV).r * roughness_amount, 0.58);
	// La keratine est un dielectrique : son IOR pilote SPECULAR, jamais METALLIC.
	METALLIC = 0.0;
	SPECULAR = dielectric_specular;
	AO = texture(ao_texture, UV).r;
}
