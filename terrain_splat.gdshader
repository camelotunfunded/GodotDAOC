shader_type spatial;
render_mode cull_disabled;

// Shared across all sectors of a zone:
uniform sampler2DArray details : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray masks   : filter_linear, repeat_disable;

// Sol PBR (option de qualité, décochée par défaut). Les trois tableaux sont
// indexés EXACTEMENT comme `details` : même tranche, même tuilage, même masque.
// Lus en LINÉAIRE (pas `source_color`) : ce sont des données, pas des couleurs.
//   normals        : normale tangente (OpenGL, Y+), une tranche par couche ;
//   roughness_maps : gris L8 ;  ao_maps : gris L8.
// Le sol est traité en diélectrique : pas de carte de métal.
// Sans `pbr_enabled`, le fragment est octet pour octet celui d'avant l'option.
uniform bool  pbr_enabled = false;
uniform sampler2DArray normals        : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray roughness_maps : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray ao_maps        : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float pbr_normal_strength : hint_range(0.0, 4.0) = 1.0;
uniform float pbr_ao_amount : hint_range(0.0, 1.0) = 1.0;
// P1-118 — un sol sec ne brille pas : plancher de rugosite hors pluie (les cartes
// photo descendaient a 0,3 et le chemin prenait des reflets bleus de ciel), et une
// part d.AO qui assombrit aussi la lumiere directe, pour que les creux restent
// lisibles en plein soleil.
uniform float dry_roughness_floor : hint_range(0.0, 1.0) = 0.0;
uniform float pbr_ao_light_affect : hint_range(0.0, 1.0) = 0.0;
uniform float dry_specular : hint_range(0.0, 1.0) = 0.5;

// Variation purement esthetique a grande echelle. Elle ne lit aucune heightmap,
// ne deplace aucun sommet et ne touche ni aux collisions ni aux coordonnees.
// Le bruit procedural casse seulement l'uniformite de couleur et de rugosite.
uniform bool macro_variation_enabled = false;
uniform float macro_variation_scale : hint_range(4.0, 512.0) = 96.0;
uniform float macro_color_strength : hint_range(0.0, 0.35) = 0.08;
uniform float macro_roughness_strength : hint_range(0.0, 0.5) = 0.12;
uniform float macro_seed : hint_range(0.0, 4096.0) = 173.0;

// Relief strictement virtuel : décale seulement la lecture des textures selon
// la vue. Aucun sommet, Z, corps de collision ou paquet réseau n'est modifié.
uniform bool virtual_relief_enabled = false;
uniform float virtual_relief_depth : hint_range(0.0, 0.08) = 0.018;
uniform int virtual_relief_steps : hint_range(2, 12) = 6;

// Etat humide pilote par la pluie. Il reste independant de l'option PBR :
// meme une couche sans cartes devient plus sombre et moins rugueuse.
uniform float weather_wetness : hint_range(0.0, 1.0) = 0.0;
uniform float wet_roughness : hint_range(0.02, 1.0) = 0.18;
uniform float wet_darkening : hint_range(0.0, 1.0) = 0.14;

// Per-sector recipe (one material per 8x8 patch):
uniform int   layer_count = 1;
uniform int   patch_x = 0;
uniform int   patch_y = 0;
uniform int   tex_slice[12];     // detail array slice for each layer
uniform float tiles[12];         // tiling across the zone (1 = 'overall', spans once)
uniform float mask_slice[12];    // mask array slice for each layer (k>0)
uniform vec4  chan_sel[12];      // which mask channel carries this layer's weight

uniform float tile_scale = 1.0;  // global knob to tune detail density at runtime

varying vec3 terrain_world_position;
varying vec3 terrain_world_tangent;
varying vec3 terrain_world_binormal;
varying vec3 terrain_world_normal;
varying vec3 terrain_camera_position;

void vertex() {
	terrain_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	terrain_camera_position = INV_VIEW_MATRIX[3].xyz;
	terrain_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	terrain_world_tangent = normalize(MODEL_NORMAL_MATRIX * TANGENT);
	// Le builder fixe le signe tangent à -1 : -cross(N,T) pointe donc vers +V.
	terrain_world_binormal = -normalize(cross(terrain_world_normal, terrain_world_tangent));
}

vec2 detail_uv(vec2 zuv, float t) {
	// t<=1 -> overall map, spans the whole zone once; otherwise tile.
	return (t <= 1.5) ? zuv : zuv * t * tile_scale;
}

float macro_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + macro_seed) * 43758.5453123);
}

float macro_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	vec2 smooth_local = local * local * (3.0 - 2.0 * local);
	float a = macro_hash(cell);
	float b = macro_hash(cell + vec2(1.0, 0.0));
	float c = macro_hash(cell + vec2(0.0, 1.0));
	float d = macro_hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, smooth_local.x), mix(c, d, smooth_local.x), smooth_local.y);
}

vec2 virtual_relief_uv(vec2 base_uv, float slice) {
	if (!virtual_relief_enabled || !pbr_enabled) return base_uv;
	vec3 view_world = normalize(terrain_camera_position - terrain_world_position);
	vec3 view_tangent = normalize(vec3(dot(view_world, terrain_world_tangent),
		dot(view_world, terrain_world_binormal), dot(view_world, terrain_world_normal)));
	float grazing_guard = max(abs(view_tangent.z), 0.28);
	vec2 travel = view_tangent.xy / grazing_guard * virtual_relief_depth;
	vec2 uv = base_uv;
	float layers = float(max(virtual_relief_steps, 2));
	float layer_depth = 1.0 / layers;
	float ray_depth = 0.0;
	for (int step = 0; step < 12; step++) {
		if (step >= virtual_relief_steps) break;
		float height = 1.0 - texture(ao_maps, vec3(uv, slice)).r;
		if (ray_depth >= height) break;
		uv -= travel / layers;
		ray_depth += layer_depth;
	}
	return uv;
}

void fragment() {
	vec2 luv = UV;                                              // local patch uv 0..1
	vec2 zuv = (vec2(float(patch_x), float(patch_y)) + luv) / 8.0; // zone uv 0..1

	// opaque base
	vec2 base0 = detail_uv(zuv, tiles[0]);
	vec3 uv0 = vec3(virtual_relief_uv(base0, float(tex_slice[0])), float(tex_slice[0]));
	vec3 col = texture(details, uv0).rgb;
	vec3 nrm = vec3(0.5, 0.5, 1.0);
	float rough = 1.0;
	float occl = 1.0;
	if (pbr_enabled) {
		nrm = texture(normals, uv0).rgb;
		rough = texture(roughness_maps, uv0).r;
		occl = texture(ao_maps, uv0).r;
	}

	for (int k = 1; k < 12; k++) {
		if (k >= layer_count) break;
		float w = dot(texture(masks, vec3(luv, mask_slice[k])), chan_sel[k]);
		vec2 basek = detail_uv(zuv, tiles[k]);
		vec3 uvk = vec3(virtual_relief_uv(basek, float(tex_slice[k])), float(tex_slice[k]));
		vec3 d = texture(details, uvk).rgb;
		col = mix(col, d, w);
		if (pbr_enabled) {
			// Mélange de normales par `mix` : approximatif mais cohérent avec
			// le mélange d'albédo ; la re-normalisation est faite par Godot.
			nrm = mix(nrm, texture(normals, uvk).rgb, w);
			rough = mix(rough, texture(roughness_maps, uvk).r, w);
			occl = mix(occl, texture(ao_maps, uvk).r, w);
		}
	}
	ALBEDO = col * mix(1.0, 1.0 - wet_darkening, weather_wetness);
	float macro_signed = 0.0;
	if (macro_variation_enabled) {
		float safe_scale = max(macro_variation_scale, 0.001);
		float broad = macro_noise(terrain_world_position.xz / safe_scale);
		float medium = macro_noise(terrain_world_position.xz / (safe_scale * 0.37) + vec2(19.0, 7.0));
		macro_signed = (mix(broad, medium, 0.32) - 0.5) * 2.0;
		ALBEDO *= 1.0 + macro_signed * macro_color_strength;
	}
	if (pbr_enabled) {
		NORMAL_MAP = nrm;
		NORMAL_MAP_DEPTH = pbr_normal_strength;
		rough = mix(max(rough, dry_roughness_floor), rough, weather_wetness);
		ROUGHNESS = clamp(mix(rough, wet_roughness, weather_wetness)
			+ macro_signed * macro_roughness_strength, 0.02, 1.0);
		AO = mix(1.0, occl, pbr_ao_amount);
		AO_LIGHT_AFFECT = pbr_ao_light_affect;
	} else {
		ROUGHNESS = clamp(mix(1.0, wet_roughness, weather_wetness)
			+ macro_signed * macro_roughness_strength, 0.02, 1.0);
	}
	SPECULAR = mix(dry_specular, 0.82, weather_wetness);
}
