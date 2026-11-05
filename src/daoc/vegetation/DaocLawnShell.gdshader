shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

// P1-119 — pelouse rase « en couches » (shell grass). La même grille de sol est
// dessinée N fois, chaque couche un peu plus haute ; ici on garde, par cellule
// de brin, un disque qui rétrécit avec la hauteur : l'empilement forme des brins
// courts, sans aucune carte plate. Purement visuel : aucune collision.
//
// COLOR.a porte le masque « pelouse » calculé par DaocGrassRemaster avec les
// mêmes règles que l'herbe (matière du sol, carte d'herbe, eau, bâtiments) ;
// COLOR.rgb la teinte du sol ; INSTANCE_CUSTOM.r la couche (0 = sol, 1 = pointe).

uniform float world_scale = 0.01;
instance uniform float appear = 1.0; // P1-133 : fondu d apparition du bloc
uniform float shell_height_raw = 9.0;
uniform float blade_spacing_raw = 2.6;
uniform float blade_thickness = 0.52;
uniform float blade_lean = 0.55;
uniform float fade_start_raw = 2400.0;
uniform float fade_end_raw = 3400.0;
uniform vec3 lawn_dark : source_color = vec3(0.21, 0.29, 0.09);
uniform vec3 lawn_light : source_color = vec3(0.47, 0.60, 0.24);
uniform float ground_tint_mix = 0.35;
uniform vec2 wind_direction = vec2(0.82, 0.57);
uniform float wind_speed = 1.35;
uniform float wind_sway_raw = 4.5;
uniform float wind_gust_strength = 0.7;
// Casse de la grille : deformation des rangees, deuxieme grille tournee, plaques.
uniform float warp_strength = 1.6;
uniform float clump_scale_raw = 55.0;
uniform float clump_gap = 0.28;
uniform float translucency = 0.4;
// P1-133 — Midgard : la meme pelouse en couches devient un manteau de NEIGE
// (choix artistique utilisateur du 2026-09-29). Pas de brins : une congere
// lisse dont la hauteur suit un bruit, sans vent, poudreuse et scintillante.
uniform float snow_mode = 0.0;
uniform vec3 snow_shadow : source_color = vec3(0.70, 0.76, 0.86);
uniform vec3 snow_light : source_color = vec3(0.95, 0.97, 1.0);
uniform float snow_drift_scale_raw = 38.0;

varying vec2 raw_xz;
varying float layer;
varying float mask;
varying vec3 ground_tint;
varying vec3 world_pos;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Un brin dans une grille (deformee, tournee) : x = touche, y = hauteur, z = alea.
vec3 blade_hit(vec2 p, float spacing, float seed, float lyr, float clump) {
	vec2 cell_uv = p / spacing;
	vec2 cell = floor(cell_uv) + seed;
	float h = mix(0.45, 1.0, hash12(cell)) * clump;
	if (lyr > h) {
		return vec3(0.0, h, hash12(cell + 17.0));
	}
	vec2 jitter = (hash22(cell) - 0.5) * 0.8;
	vec2 lean_dir = normalize(hash22(cell + 5.0) - 0.5 + vec2(0.001));
	vec2 f = fract(cell_uv) - 0.5 - jitter * (1.0 - blade_thickness * 0.5) - lean_dir * blade_lean * lyr * lyr;
	float radius = blade_thickness * 0.5 * (1.0 - lyr / max(h, 0.001));
	return vec3(length(f) <= radius ? 1.0 : 0.0, h, hash12(cell + 17.0));
}

void vertex() {
	layer = INSTANCE_CUSTOM.r;
	mask = COLOR.a;
	ground_tint = COLOR.rgb;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	raw_xz = wp.xz / world_scale;
	float lift = layer * shell_height_raw * world_scale * smoothstep(0.05, 0.5, mask);
	float gust_wave = sin(TIME * wind_speed * 0.31 + dot(raw_xz, wind_direction) * 0.0009);
	float gust = mix(1.0, mix(0.35, 1.5, gust_wave * 0.5 + 0.5), wind_gust_strength);
	float wave = (sin(TIME * wind_speed * 1.7 + dot(raw_xz, wind_direction) * 0.012)
		+ 0.45 * sin(TIME * wind_speed * 3.1 + dot(raw_xz, wind_direction.yx) * 0.031)) * gust;
	VERTEX.y += lift;
	VERTEX.xz += wind_direction * wave * wind_sway_raw * world_scale * layer * layer * (1.0 - snow_mode);
	NORMAL = vec3(0.0, 1.0, 0.0);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	float dist_raw = distance(CAMERA_POSITION_WORLD, world_pos) / world_scale;
	float fade = (1.0 - smoothstep(fade_start_raw, fade_end_raw, dist_raw)) * appear;
	float dither = hash12(floor(FRAGCOORD.xy));
	vec2 cell_uv = raw_xz / blade_spacing_raw;
	vec2 cell = floor(cell_uv);
	// Bord irregulier brin par brin : chaque cellule a son propre seuil de masque,
	// la lisiere s.effiloche au lieu de suivre la grille.
	// Sol : lisiere en bruit lisse (pas de carres de cellule vus de pres) ;
	// brins : seuil propre a chaque brin, qui effiloche le bord.
	float edge = layer > 0.001 ? mix(0.15, 0.6, hash12(cell + 91.0))
		: mix(0.18, 0.55, value_noise(raw_xz / 22.0) * 0.7 + value_noise(raw_xz / 6.0) * 0.3);
	if (mask < edge || fade < dither) {
		discard;
	}
	// Plaques : la densite et la hauteur varient par zones de ~50 unites, avec
	// de vrais trous, au lieu d.un tapis uniforme.
	if (snow_mode > 0.5) {
		// Congere : hauteur lisse a deux octaves, trous rares ; chaque couche
		// sous la surface du bruit est pleine, d ou un volume doux sans brins.
		float drift = value_noise(raw_xz / snow_drift_scale_raw) * 0.7 + value_noise(raw_xz / (snow_drift_scale_raw * 0.27)) * 0.3;
		float surface = smoothstep(0.12, 0.85, drift) * smoothstep(0.1, 0.7, mask);
		if (layer > surface || (layer <= 0.001 && surface < 0.04 + 0.08 * dither)) {
			discard;
		}
		float ts = clamp(layer / max(surface, 0.001), 0.0, 1.0);
		vec3 snow = mix(snow_shadow, snow_light, 0.35 + 0.65 * ts);
		float sparkle = step(0.985, hash12(floor(raw_xz * 1.7) + floor(TIME * 0.5)));
		ALBEDO = snow;
		ROUGHNESS = mix(0.75, 0.35, sparkle);
		SPECULAR = 0.35 + 0.6 * sparkle;
		BACKLIGHT = snow * 0.08;
	} else {
	float clump_n = value_noise(raw_xz / clump_scale_raw) * 0.65 + value_noise(raw_xz / (clump_scale_raw * 0.31)) * 0.35;
	float clump = smoothstep(clump_gap - 0.15, clump_gap + 0.25, clump_n) * mix(0.7, 1.15, clump_n) * smoothstep(0.15, 0.8, mask);
	// Dans les vrais trous, le sol du terrain reparait.
	if (layer <= 0.001 && clump < 0.1 + 0.15 * dither) {
		discard;
	}
	float h = clump;
	float blade_rand = hash12(cell + 17.0);
	if (layer > 0.001) {
		// Grille A deformee par un bruit : les rangees ondulent.
		vec2 warp = vec2(value_noise(raw_xz / 9.0), value_noise(raw_xz / 9.0 + 31.0)) - 0.5;
		vec3 a = blade_hit(raw_xz + warp * blade_spacing_raw * warp_strength, blade_spacing_raw, 0.0, layer, clump);
		// Grille B tournee de ~37 deg, pas 1,13 : aucun alignement ne survit.
		mat2 rot = mat2(vec2(0.799, 0.602), vec2(-0.602, 0.799));
		vec3 b = blade_hit(rot * raw_xz - warp * blade_spacing_raw, blade_spacing_raw * 1.13, 57.0, layer, clump);
		if (a.x < 0.5 && b.x < 0.5) {
			discard;
		}
		vec3 hit = a.x > 0.5 ? a : b;
		h = hit.y;
		blade_rand = hit.z;
	}
	float t = clamp(layer / max(h, 0.001), 0.0, 1.0);
	// Le sol de la pelouse (couche 0) prend deja le ton moyen : de loin, quand les
	// brins passent sous le pixel, on voit une pelouse et non un tapis sombre.
	vec3 color = layer > 0.001 ? mix(lawn_dark, lawn_light, 0.3 + 0.7 * t) : lawn_dark * 0.85;
	color *= mix(0.82, 1.18, blade_rand);
	color = mix(color, color * ground_tint * 1.6, ground_tint_mix);
	ALBEDO = color;
	BACKLIGHT = color * translucency * t;
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
	}
}
