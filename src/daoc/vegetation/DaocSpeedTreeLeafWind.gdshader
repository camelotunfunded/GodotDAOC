shader_type spatial;
render_mode cull_disabled, world_vertex_coords;

// R10-HF2 — le vent dans les CARTES DE FEUILLES SpeedTree.
//
// VARIANTE, PAS REMPLACEMENT. `generated/trees/leaf_cards.gdshader` est cuit
// dans le Character Lab et vit derrière une jonction exclue du dépôt : le
// modifier reviendrait à éditer la sortie d'un autre projet, et la prochaine
// regénération l'écraserait. Ce fichier est donc une COPIE possédée par le
// client, à laquelle le vent est ajouté — la géométrie de carte, elle, est
// reprise à l'identique et ne doit pas diverger.
//
// LE VENT DÉPLACE LE CENTRE DE LA CARTE, JAMAIS SES COINS. Une carte de feuille
// est un quad orienté vers la caméra autour de son centre natif ; bouger ses
// sommets indépendamment la déformerait au lieu de la faire voler. On déplace
// donc `center`, et le billboard s'applique ensuite, inchangé.
//
// CORRÉLÉ À L'HERBE : `wind_direction`, `wind_speed` et la formule de rafale
// sont celles de `DaocGrassRemaster.gdshader`, aux constantes près. Une rafale
// traverse l'herbe et les arbres au même instant.

uniform sampler2D foliage_texture : source_color, filter_linear_mipmap_anisotropic;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.5;

uniform vec2 wind_direction = vec2(0.82, 0.57);
uniform float wind_speed = 1.35;
uniform float wind_gust_strength = 0.72;
uniform float canopy_strength = 0.55;
uniform float leaf_flutter_strength = 0.30;
uniform float wind_height_reference = 300.0;
uniform float wind_enabled = 1.0;
// P1-118 — eclairage de couronne : la normale d.une carte pointe vers l.exterieur et
// le haut de l.arbre (melangee a celle de la carte), les feuilles du cote soleil
// s.eclairent, celles de l.autre cote restent dans l.ombre du houppier ; sans cela
// tout le feuillage regardait la camera et blanchissait face au soleil.
uniform float crown_normal_mix : hint_range(0.0, 1.0) = 0.7;
uniform float leaf_translucency : hint_range(0.0, 1.0) = 0.35;
// P1-133 — casser l homogeneite : chaque ARBRE (origine de son instance) puis
// chaque BRANCHE (paquet de cartes voisines, CUSTOM0 en espace modele) tire une
// teinte chaude/froide, une saturation et une luminosite. Calcule au sommet :
// quatre hash par sommet, rien au fragment.
uniform float tint_tree_strength : hint_range(0.0, 0.5) = 0.12;
uniform float tint_branch_strength : hint_range(0.0, 0.5) = 0.07;
uniform float tint_branch_size = 110.0;
varying vec3 v_tint;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
// P1-134 — TROUEES DE LUMIERE. Une foret dense ne laissait presque jamais
// passer le soleil. Dans la SEULE passe d ombre, la couronne perce des trous
// en bruit doux (taille `sunfleck_cell`, en unites monde) qui derivent avec le
// vent : les feuilles restent pleines a l oeil, le sol recoit des taches de
// soleil mouvantes. 0 = ombre pleine comme avant.
uniform float sunfleck_amount : hint_range(0.0, 0.8) = 0.32;
uniform float sunfleck_cell = 0.55;
varying vec3 v_fleck_world;

float fleck_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

// Le bruit est pris sur le plan PERPENDICULAIRE a la lumiere (`light_dir`) :
// un trou est une colonne alignee sur le soleil, qui traverse toutes les
// epaisseurs de feuilles au lieu d etre rebouche par la couche suivante.
bool sunfleck_hole(vec3 world, float time, vec3 light_dir) {
	if (sunfleck_amount <= 0.0) {
		return false;
	}
	vec3 axis_u = normalize(cross(light_dir, abs(light_dir.y) > 0.95 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0)));
	vec3 axis_v = cross(axis_u, light_dir);
	vec2 plane = vec2(dot(world, axis_u), dot(world, axis_v));
	vec2 drift = wind_direction * time * wind_speed * 0.06;
	float n = fleck_noise(vec3(plane / max(sunfleck_cell, 0.01) + drift, time * 0.05)) * 0.7
		+ fleck_noise(vec3(plane / max(sunfleck_cell * 0.45, 0.01) - drift * 1.7, 3.1 + time * 0.08)) * 0.3;
	return n < sunfleck_amount;
}

void vertex() {
	vec3 center = (MODEL_MATRIX * vec4(CUSTOM0.xyz, 1.0)).xyz;
	float tree_seed = hash13(floor(MODEL_MATRIX[3].xyz * 0.37) + 0.5);
	float branch_seed = hash13(floor(CUSTOM0.xyz / max(tint_branch_size, 1.0)) + tree_seed * 91.0);
	float warm = (tree_seed - 0.5) * 2.0 * tint_tree_strength + (branch_seed - 0.5) * 2.0 * tint_branch_strength;
	float sat = 1.0 + (hash13(vec3(tree_seed * 53.0, branch_seed, 7.0)) - 0.5) * 2.0 * tint_tree_strength * 1.5;
	float val = 1.0 + (branch_seed - 0.5) * 2.0 * tint_branch_strength;
	v_tint = vec3(warm, sat, val);
	vec3 delta = CUSTOM1.xyz;
	float scale = length(MODEL_MATRIX[0].xyz);

	if (wind_enabled > 0.5) {
		vec2 wind_normal = normalize(wind_direction);
		vec2 cross_wind = vec2(-wind_normal.y, wind_normal.x);

		// La rafale, partagee avec l'herbe : c'est elle qui synchronise.
		float gust_wave = sin(TIME * wind_speed * 0.31
			+ dot(center.xz, wind_direction) * 0.018);
		float gust = mix(1.0, mix(0.42, 1.45, gust_wave * 0.5 + 0.5), wind_gust_strength);

		// CUSTOM0.y est la hauteur de la carte dans l'arbre, en espace MODELE :
		// l'origine d'un arbre est a son pied. Une carte basse bouge peu, la
		// cime bouge pleinement - sans quoi le feuillage se detacherait du tronc,
		// qui reste rigide parce qu'il porte un materiau opaque.
		float height_ratio = clamp(CUSTOM0.y / max(wind_height_reference, 1.0), 0.0, 1.4);

		// Houle de canopee, lente et large.
		float canopy = sin(TIME * wind_speed * 0.68 + dot(center.xz, wind_normal) * 0.010);
		vec2 canopy_offset = wind_normal * canopy * canopy_strength * height_ratio * gust;

		// Frisson, rapide et dephase PAR CARTE : le hash porte sur le centre, donc
		// tous les sommets d'une meme carte partagent la meme phase et la carte
		// reste rigide - c'est ce qui la fait voler au lieu de se tordre.
		float phase = hash13(floor(center * 0.35)) * 6.28318;
		float flutter = sin(TIME * wind_speed * 4.7 + phase);
		float flutter_cross = cos(TIME * wind_speed * 3.9 + phase * 1.7);
		vec2 leaf_offset = (wind_normal * flutter + cross_wind * flutter_cross)
			* leaf_flutter_strength * height_ratio * gust;

		float lift = sin(TIME * wind_speed * 3.3 + phase * 2.3)
			* leaf_flutter_strength * 0.5 * height_ratio * gust;

		center.xz += canopy_offset + leaf_offset;
		center.y += lift;
	}

	// Geometrie de carte reprise a l'identique de leaf_cards.gdshader : le
	// convertisseur calcule ses cartes pour sa camera par defaut sur +X, et on
	// ne fait pivoter que la carte autour de son centre natif.
	VERTEX = center + scale * (-INV_VIEW_MATRIX[0].xyz * delta.z
		+ INV_VIEW_MATRIX[1].xyz * delta.y + INV_VIEW_MATRIX[2].xyz * delta.x);
	vec3 outward = vec3(CUSTOM0.x, 0.0, CUSTOM0.z);
	float outward_len = length(outward);
	vec3 crown_model = normalize((outward_len > 0.001 ? outward / outward_len : vec3(0.0)) + vec3(0.0, 0.9, 0.0));
	vec3 crown_world = normalize(mat3(MODEL_MATRIX) * crown_model);
	NORMAL = normalize(mix(INV_VIEW_MATRIX[2].xyz, crown_world, crown_normal_mix));
	// Le centre de la carte, pas le sommet : la carte fait face a la LUMIERE dans
	// la passe d ombre, et un bruit pris sur ses coins tournerait avec elle.
	v_fleck_world = center + (VERTEX - center) * 0.35;
}

void fragment() {
	if (IN_SHADOW_PASS && sunfleck_hole(v_fleck_world, TIME, normalize(INV_VIEW_MATRIX[2].xyz))) {
		discard;
	}
	vec4 color = texture(foliage_texture, UV);
	float luma = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 tinted = mix(vec3(luma), color.rgb, v_tint.y) * v_tint.z;
	tinted *= vec3(1.0 + v_tint.x, 1.0 + v_tint.x * 0.35, 1.0 - v_tint.x);
	color.rgb = clamp(tinted, 0.0, 1.0);
	ALBEDO = color.rgb;
	BACKLIGHT = color.rgb * leaf_translucency;
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	ROUGHNESS = 1.0;
}
