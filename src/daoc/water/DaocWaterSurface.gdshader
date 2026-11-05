shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// The colour texture is loaded at runtime from the original DAoC client.
// No texture is imported or copied into res://.
uniform sampler2D daoc_water_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

uniform vec3 shallow_colour : source_color = vec3(0.16, 0.40, 0.45);
uniform vec3 deep_colour : source_color = vec3(0.025, 0.105, 0.18);
uniform vec3 foam_colour : source_color = vec3(0.72, 0.84, 0.82);
uniform float water_opacity : hint_range(0.05, 1.0) = 0.62;
uniform float world_uv_scale : hint_range(0.00001, 0.02) = 0.00055;
uniform float wave_strength : hint_range(0.0, 4.0) = 1.15;
uniform float refraction_strength : hint_range(0.0, 0.08) = 0.012;
uniform float depth_distance : hint_range(1.0, 8000.0) = 900.0;
uniform float shore_distance : hint_range(1.0, 1000.0) = 95.0;
uniform vec2 flow_direction = vec2(1.0, 0.0);
uniform float flow_speed : hint_range(-0.25, 0.25) = 0.0;
uniform float ambient_drift : hint_range(0.0, 0.1) = 0.012;

// 2026-09-19 — Berges. La surface plate coupe le relief le long d'une ligne
// brisee ; ce qui la cache est une BANDE, pas une ligne. Deux traitements :
//   shore_mode 0 : ECUME (plage/ocean) — un ourlet blanc qui monte et redescend
//                  sur le sable au rythme des vagues, dechire par la texture ;
//   shore_mode 1 : MOUSSE (lac, riviere, marais) — la surface se fond dans le
//                  sol sur les bas-fonds, tachetee de vert d'algue.
uniform int shore_mode : hint_range(0, 1) = 0;
uniform float shore_band_distance : hint_range(1.0, 2000.0) = 260.0;
uniform float shore_strength : hint_range(0.0, 1.0) = 0.85;
uniform float shore_wave_speed : hint_range(0.0, 3.0) = 0.9;
uniform vec3 moss_colour : source_color = vec3(0.26, 0.40, 0.18);
// Fondu des bords OUVERTS du polygone de la bande (UV2 : x en travers, y le
// long). Sans UV2 (mer lointaine) le fondu est coupe par edge_fade = 0.
uniform float edge_fade : hint_range(0.0, 0.5) = 0.0;

varying vec3 water_world_position;
varying vec2 band_uv;


void vertex() {
	water_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	band_uv = UV2;
}


float linear_depth_at(vec2 screen_uv, float raw_depth, mat4 inverse_projection) {
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec3 ndc = vec3(screen_uv, raw_depth) * 2.0 - 1.0;
	#else
		vec3 ndc = vec3(screen_uv * 2.0 - 1.0, raw_depth);
	#endif
	vec4 view_position = inverse_projection * vec4(ndc, 1.0);
	return -(view_position.z / view_position.w);
}


float water_height(vec2 uv) {
	vec3 sample_colour = texture(daoc_water_texture, uv).rgb;
	return dot(sample_colour, vec3(0.299, 0.587, 0.114));
}


// Bruit de berge : deux lectures de la texture d'eau a des echelles grossieres,
// lentes et independantes du courant. Il dechire l'ourlet d'ecume et tachete
// la mousse sans ajouter de texture.
float shore_noise(vec2 world_xz, float speed) {
	vec2 slow = vec2(TIME * 0.011 * speed, -TIME * 0.007 * speed);
	float a = water_height(world_xz * 0.0011 + slow);
	float b = water_height(world_xz * 0.0037 - slow * 1.7);
	return mix(a, b, 0.45);
}


void fragment() {
	vec2 direction = normalize(flow_direction + vec2(0.0001, 0.0001));
	vec2 base_uv = water_world_position.xz * world_uv_scale;
	vec2 drift_a = direction * TIME * (ambient_drift + flow_speed);
	vec2 drift_b = vec2(-direction.y, direction.x) * TIME * (ambient_drift * 0.63 - flow_speed * 0.37);
	vec2 uv_a = base_uv + drift_a;
	vec2 uv_b = base_uv * 1.73 + drift_b;

	vec2 texel = 1.0 / vec2(textureSize(daoc_water_texture, 0));
	float left_h = water_height(uv_a - vec2(texel.x, 0.0));
	float right_h = water_height(uv_a + vec2(texel.x, 0.0));
	float down_h = water_height(uv_b - vec2(0.0, texel.y));
	float up_h = water_height(uv_b + vec2(0.0, texel.y));
	vec3 world_normal = normalize(vec3(
		(left_h - right_h) * wave_strength,
		1.0,
		(down_h - up_h) * wave_strength
	));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);

	float scene_raw_depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	float scene_depth = linear_depth_at(SCREEN_UV, scene_raw_depth, INV_PROJECTION_MATRIX);
	float surface_depth = max(-VERTEX.z, 0.0);
	float water_depth = max(scene_depth - surface_depth, 0.0);
	float depth_factor = smoothstep(0.0, depth_distance, water_depth);
	float shore_factor = 1.0 - smoothstep(0.0, shore_distance, water_depth);

	vec2 refraction_offset = world_normal.xz * refraction_strength * (0.25 + 0.75 * depth_factor);
	vec2 refracted_uv = clamp(SCREEN_UV + refraction_offset, vec2(0.001), vec2(0.999));
	vec3 behind_water = textureLod(screen_texture, refracted_uv, mix(0.0, 1.4, depth_factor)).rgb;
	vec3 texture_tint = mix(texture(daoc_water_texture, uv_a).rgb, texture(daoc_water_texture, uv_b).rgb, 0.42);
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
	vec3 water_colour = mix(shallow_colour, deep_colour, depth_factor);
	water_colour = mix(water_colour, texture_tint, 0.18);

	// Keep shallow terrain readable through the surface while deep water retains
	// a DAoC-coloured body. Godot's environment supplies the sky reflection.
	ALBEDO = mix(behind_water * mix(vec3(0.92), shallow_colour, 0.18), water_colour, 0.34 + depth_factor * 0.38);
	ROUGHNESS = mix(0.24, 0.08, fresnel);
	SPECULAR = 0.78;
	METALLIC = 0.0;
	CLEARCOAT = 0.55;

	float foam_noise = smoothstep(0.46, 0.70, mix(left_h, up_h, 0.5));
	float foam = shore_factor * foam_noise * (1.0 - depth_factor) * 0.34;
	float alpha = clamp(water_opacity + depth_factor * 0.10 + fresnel * 0.08, 0.05, 0.94);

	// ---- Berge -------------------------------------------------------------
	float noise = shore_noise(water_world_position.xz, shore_wave_speed);
	// Profondeur normalisee dans la bande de berge, 0 au sol, 1 au large.
	float band = clamp(water_depth / shore_band_distance, 0.0, 1.0);
	if (shore_mode == 0) {
		// Ecume : la limite de l'ourlet oscille (vague qui monte et se retire),
		// et le bruit la dechire en langues. Trois ourlets decales donnent
		// l'ecume qui reste sur le sable derriere la vague.
		float swell = 0.5 + 0.5 * sin(TIME * shore_wave_speed * 1.3 + water_world_position.x * 0.0021 + water_world_position.z * 0.0017 + noise * 5.0);
		float reach = mix(0.30, 0.80, swell);
		float hem = 1.0 - smoothstep(reach * 0.45, reach, band + (noise - 0.5) * 0.45);
		float lace = smoothstep(0.30, 0.62, noise);
		float wet_line = 1.0 - smoothstep(0.0, 0.10, band);
		float surf = shore_strength * clamp(hem * (0.35 + 0.65 * lace) + wet_line * 0.55, 0.0, 1.0);
		foam = max(foam, surf);
		// L'ecume est opaque : c'est elle qui couvre la ligne du relief.
		alpha = mix(alpha, 0.94, surf * 0.65);
		EMISSION = foam_colour * foam * 0.16;
	} else {
		// Mousse : les bas-fonds virent au vert d'algue tachete et la surface
		// s'efface en s'approchant du sol, pour que la limite geometrique
		// disparaisse dans la vase et l'herbe.
		float speckle = smoothstep(0.38, 0.72, noise);
		float moss = shore_strength * (1.0 - smoothstep(0.0, 1.0, band)) * (0.35 + 0.65 * speckle);
		vec3 moss_tint = mix(moss_colour, foam_colour * 0.75, speckle * 0.35);
		ALBEDO = mix(ALBEDO, moss_tint, moss * 0.85);
		ROUGHNESS = mix(ROUGHNESS, 0.85, moss);
		float ground_blend = 1.0 - smoothstep(0.0, 0.45, band);
		alpha = mix(alpha, 0.22, ground_blend * shore_strength);
		alpha = max(alpha, moss * 0.55);
		foam *= 0.25;
		EMISSION = foam_colour * foam * 0.10;
	}
	ALBEDO = mix(ALBEDO, foam_colour, foam);

	// Bords ouverts du polygone : le fondu par UV2 supprime l'arete droite
	// d'une bande qui s'arrete au milieu d'un bas-fond.
	if (edge_fade > 0.0) {
		float across = min(band_uv.x, 1.0 - band_uv.x);
		float along = min(band_uv.y, 1.0 - band_uv.y);
		float rim = smoothstep(0.0, edge_fade, across) * smoothstep(0.0, edge_fade * 0.5, along);
		alpha *= mix(0.15, 1.0, rim);
	}
	ALPHA = clamp(alpha, 0.05, 0.97);
}
