shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D grass_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform float variant_count = 12.0;
uniform float alpha_cutoff : hint_range(0.05, 0.95) = 0.28;
// P1-133 : fondu d apparition d un bloc neuf (0 -> 1, pose par DaocGrassRemaster),
// meme trame que le fondu de distance : plus de pop brutal devant le joueur.
instance uniform float appear = 1.0;
uniform float fade_start = 85.0;
uniform float fade_end = 120.0;
uniform vec2 wind_direction = vec2(0.82, 0.57);
uniform float wind_speed = 1.35;
uniform float wind_strength = 0.58;
uniform float wind_gust_strength = 0.72;
// P1-118 — pied dans l.ombre des voisines, pointe au soleil, lumiere qui
// traverse les brins a contre-jour, et une teinte poussee vers un vert franc.
uniform float root_darkening : hint_range(0.0, 1.0) = 0.3;
uniform float tip_brightening : hint_range(0.0, 0.5) = 0.14;
uniform float lushness : hint_range(0.0, 1.0) = 0.45;
uniform vec3 lush_tint : source_color = vec3(0.46, 0.66, 0.24);
uniform float translucency : hint_range(0.0, 1.0) = 0.45;
// Normales tirees vers le haut : une touffe s.eclaire comme le sol qui la porte,
// au lieu d.une carte verticale dont une face sur deux tourne le dos au soleil.
uniform float up_normal_bias : hint_range(0.0, 1.0) = 0.75;

varying vec3 world_position;
varying flat float instance_selector;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float grass_variant(float selector) {
	return min(floor(selector * variant_count), variant_count - 1.0);
}

void vertex() {
	float blade_height = 1.0 - UV.y;
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), up_normal_bias));
	vec3 before_wind = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float broad = sin(TIME * wind_speed + dot(before_wind.xz, wind_direction) * 0.055 + INSTANCE_CUSTOM.x * 6.28318);
	float detail = sin(TIME * wind_speed * 1.73 + dot(before_wind.zx, wind_direction) * 0.11 + INSTANCE_CUSTOM.y * 6.28318);
	float gust_wave = sin(TIME * wind_speed * 0.31 + dot(before_wind.xz, wind_direction) * 0.018 + INSTANCE_CUSTOM.y * 3.14159);
	float gust = mix(1.0, mix(0.42, 1.45, gust_wave * 0.5 + 0.5), wind_gust_strength);
	float sway = (broad + detail * 0.34) * wind_strength * mix(0.72, 1.18, INSTANCE_CUSTOM.z) * gust;
	vec2 wind_normal = normalize(wind_direction);
	vec2 cross_wind = vec2(-wind_normal.y, wind_normal.x);
	// Racine fixe, mais la moitie haute participe franchement au mouvement. Le
	// profil quadratique precedent ne rendait visible que les tout derniers pixels.
	float bend_profile = blade_height * (0.28 + 0.72 * blade_height);
	float flutter = sin(TIME * wind_speed * 3.1 + INSTANCE_CUSTOM.x * 17.0 + UV.y * 5.0);
	VERTEX.xz += (wind_normal * sway
		+ cross_wind * (detail * wind_strength * 0.22 + flutter * wind_strength * 0.08))
		* bend_profile;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	instance_selector = INSTANCE_CUSTOM.a;
}

void fragment() {
	// cull_disabled retourne la normale des faces arriere : vers le bas ici.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	float selector = fract(instance_selector + UV2.x);
	float variant = grass_variant(selector);
	float safe_count = max(variant_count, 1.0);
	float local_u = mix(0.002, 0.998, UV.x);
	vec2 atlas_uv = vec2((local_u + variant) / safe_count, UV.y);
	vec4 blade = texture(grass_texture, atlas_uv);
	vec3 blade_normal = texture(grass_normal_texture, atlas_uv).rgb;
	float distance_to_camera = distance(CAMERA_POSITION_WORLD, world_position);
	float distance_fade = (1.0 - smoothstep(fade_start, fade_end, distance_to_camera)) * appear;
	// Fondu trame : les touffes disparaissent progressivement sans transparence
	// couteuse ni ligne circulaire nette autour du joueur.
	float dither = hash12(floor(FRAGCOORD.xy));
	if (blade.a < alpha_cutoff || distance_fade < dither) {
		discard;
	}
	vec3 calibrated = mix(vec3(1.0), COLOR.rgb, 0.58);
	vec3 color = blade.rgb * calibrated;
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, lush_tint * (luma / 0.55), lushness * 0.5);
	float height01 = 1.0 - UV.y;
	color *= mix(1.0 - root_darkening, 1.0 + tip_brightening, smoothstep(0.0, 0.85, height01));
	ALBEDO = color;
	BACKLIGHT = color * translucency;
	NORMAL_MAP = blade_normal;
	NORMAL_MAP_DEPTH = 0.38;
	ROUGHNESS = 0.88;
	SPECULAR = 0.10;
}
