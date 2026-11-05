shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

// P1-118 — chaume. Purement visuel : aucun sommet ne quitte sa place au-delà
// d'une respiration de quelques unités, aucune collision n'est touchée.
//
// Trois couches, parce qu'une seule ne tient pas à la distance où l'on regarde
// un toit : la couleur d'origine (128 à 512 px, dessinée par Mythic), un relief
// tiré de sa luminance (les brins clairs dépassent, les creux s'assombrissent),
// et une couche de détail haute fréquence — normale et grain d'un chaume photo
// CC0 — qui donne les brins de près sans changer la palette du client.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D detail_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_detail = false;
uniform bool use_alpha = false;
uniform float alpha_cutoff : hint_range(0.05, 0.95) = 0.5;
uniform float detail_scale = 3.0;
uniform float detail_normal_strength = 1.1;
uniform float detail_color_strength = 0.45;
uniform float base_relief_strength = 2.2;
uniform float cavity_strength = 0.55;
uniform vec3 sheen_color : source_color = vec3(1.0, 0.86, 0.55);
uniform float sheen_strength = 0.35;
uniform vec2 wind_direction = vec2(0.82, 0.57);
uniform float wind_speed = 1.35;
uniform float wind_gust_strength = 0.72;
uniform float roof_strength = 0.0;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void vertex() {
	if (roof_strength > 0.0) {
		vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float long_wave = sin(TIME * wind_speed * 0.22 + dot(world_position.xz, wind_direction) * 0.012);
		float gust_wave = sin(TIME * wind_speed * 0.31 + dot(world_position.xz, wind_direction) * 0.018);
		float gust = mix(1.0, mix(0.65, 1.15, gust_wave * 0.5 + 0.5), wind_gust_strength);
		VERTEX.y += long_wave * roof_strength * gust;
	}
}

void fragment() {
	vec4 base = texture(albedo_texture, UV);
	if (use_alpha && base.a < alpha_cutoff) {
		discard;
	}
	// Relief de la couleur d'origine : différences finies de luminance.
	vec2 texel = 1.0 / vec2(textureSize(albedo_texture, 0));
	float h = luma(base.rgb);
	float hx = luma(texture(albedo_texture, UV + vec2(texel.x, 0.0)).rgb);
	float hy = luma(texture(albedo_texture, UV + vec2(0.0, texel.y)).rgb);
	vec3 relief = normalize(vec3((h - hx) * base_relief_strength, (h - hy) * base_relief_strength, 1.0));
	// Creux : plus sombre que le voisinage flou (mip plus bas).
	float around = luma(textureLod(albedo_texture, UV, 3.0).rgb);
	float cavity = clamp(1.0 - max(0.0, around - h) * 3.0 * cavity_strength, 0.35, 1.0);

	vec3 color = base.rgb;
	vec3 n = relief;
	if (has_detail) {
		vec2 duv = UV * detail_scale;
		vec3 d = texture(detail_albedo, duv).rgb;
		// Le détail module la valeur autour de 1 : la teinte reste celle du client.
		float dl = luma(d) / max(0.001, luma(textureLod(detail_albedo, duv, 10.0).rgb));
		color *= mix(1.0, clamp(dl, 0.4, 1.8), detail_color_strength);
		vec3 dn = texture(detail_normal, duv).xyz * 2.0 - 1.0;
		dn.xy *= detail_normal_strength;
		// Mélange « whiteout » des deux normales tangentes.
		n = normalize(vec3(relief.xy + dn.xy, relief.z * dn.z));
	}
	ALBEDO = color * mix(1.0, cavity, 0.8);
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	AO = cavity;
	AO_LIGHT_AFFECT = 0.35;
	ROUGHNESS = 0.88;
	SPECULAR = 0.25;
	// Brins secs : un léger reflet chaud rasant, que le chaume réel a au soleil bas.
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = sheen_color * color * fres * sheen_strength * 0.25;
}
