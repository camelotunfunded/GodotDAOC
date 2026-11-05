shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

// R10-HF2 — le vent dans les feuilles.
//
// CORRELE A L'HERBE, MAIS PAS IDENTIQUE. Le vent souffle dans la meme direction
// et les MEMES rafales traversent les deux : `wind_direction`, `wind_speed` et
// la formule de rafale sont recopiees a l'identique de
// `DaocGrassRemaster.gdshader`, y compris ses constantes. Une rafale qui couche
// l'herbe doit agiter les arbres au meme instant, sinon les deux se lisent comme
// deux mondes superposes.
//
// CE QUI DIFFERE, ET POURQUOI. Un brin d'herbe est une lame encastree : il plie
// depuis sa racine, tout entier, dans le sens du vent. Une feuille est portee
// par une branche : l'ensemble oscille lentement, et la feuille FRISSONNE par
// dessus, vite, court, et dans tous les sens - y compris vers le haut, ce que
// l'herbe ne fait jamais.
//
// D'ou trois couches au lieu de deux :
//   * la houle de canopee, lente, dans l'axe du vent, d'amplitude croissante
//     avec la HAUTEUR dans l'arbre - le tronc ne bouge pas, la cime oscille ;
//   * le frisson de feuille, rapide et de faible amplitude, dephase par la
//     POSITION du sommet pour que deux feuilles voisines ne battent jamais
//     ensemble ;
//   * un battement VERTICAL, moitie moins ample, qui evite l'effet « drapeau »
//     d'un mouvement purement horizontal.
//
// L'AMPLITUDE EST PROPORTIONNELLE A LA HAUTEUR LOCALE et non uniforme : sans
// cela le feuillage se detacherait du tronc, qui lui reste rigide - il est
// opaque, donc il ne recoit pas ce materiau.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform float alpha_cutoff : hint_range(0.05, 0.95) = 0.5;

// Partages avec l'herbe, valeurs identiques.
uniform vec2 wind_direction = vec2(0.82, 0.57);
uniform float wind_speed = 1.35;
uniform float wind_gust_strength = 0.72;

// Propres au feuillage.
uniform float canopy_strength = 0.55;
uniform float leaf_flutter_strength = 0.30;
uniform float wind_height_reference = 300.0;
uniform float wind_enabled = 1.0;

varying vec3 world_position;
// P1-133 — variation par arbre et par branche (voir DaocSpeedTreeLeafWind).
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
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float tree_seed = hash13(floor(MODEL_MATRIX[3].xyz * 0.37) + 0.5);
	float branch_seed = hash13(floor(VERTEX / max(tint_branch_size, 1.0)) + tree_seed * 91.0);
	v_tint = vec3((tree_seed - 0.5) * 2.0 * tint_tree_strength + (branch_seed - 0.5) * 2.0 * tint_branch_strength,
		1.0 + (hash13(vec3(tree_seed * 53.0, branch_seed, 7.0)) - 0.5) * 3.0 * tint_tree_strength,
		1.0 + (branch_seed - 0.5) * 2.0 * tint_branch_strength);
	if (wind_enabled >= 0.5) {

	vec2 wind_normal = normalize(wind_direction);
	vec2 cross_wind = vec2(-wind_normal.y, wind_normal.x);

	// La rafale, recopiee de l'herbe a la constante pres : c'est ELLE qui
	// synchronise les deux vegetations.
	float gust_wave = sin(TIME * wind_speed * 0.31
		+ dot(world_position.xz, wind_direction) * 0.018);
	float gust = mix(1.0, mix(0.42, 1.45, gust_wave * 0.5 + 0.5), wind_gust_strength);

	// Hauteur dans l'arbre, en espace MODELE : l'origine d'un arbre est a son
	// pied, donc VERTEX.y mesure directement la distance au sol. Bornee, pour
	// qu'un arbre geant ne parte pas en vrille.
	float height_ratio = clamp(VERTEX.y / max(wind_height_reference, 1.0), 0.0, 1.4);

	// Couche 1 — la canopee, lente et large.
	float canopy = sin(TIME * wind_speed * 0.68
		+ dot(world_position.xz, wind_normal) * 0.010);
	vec2 canopy_offset = wind_normal * canopy * canopy_strength * height_ratio * gust;

	// Couche 2 — le frisson, rapide et dephase par sommet.
	float phase = hash13(floor(world_position * 0.35)) * 6.28318;
	float flutter = sin(TIME * wind_speed * 4.7 + phase);
	float flutter_cross = cos(TIME * wind_speed * 3.9 + phase * 1.7);
	vec2 leaf_offset = (wind_normal * flutter + cross_wind * flutter_cross)
		* leaf_flutter_strength * height_ratio * gust;

	// Couche 3 — le battement vertical, moitie moins ample.
	float lift = sin(TIME * wind_speed * 3.3 + phase * 2.3)
		* leaf_flutter_strength * 0.5 * height_ratio * gust;

	VERTEX.xz += canopy_offset + leaf_offset;
	VERTEX.y += lift;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	}
	v_fleck_world = world_position;
}

void fragment() {
	if (IN_SHADOW_PASS && sunfleck_hole(v_fleck_world, TIME, normalize(INV_VIEW_MATRIX[2].xyz))) {
		discard;
	}
	vec4 leaf = texture(albedo_texture, UV);
	if (leaf.a < alpha_cutoff) {
		discard;
	}
	float luma = dot(leaf.rgb, vec3(0.299, 0.587, 0.114));
	vec3 tinted = mix(vec3(luma), leaf.rgb, v_tint.y) * v_tint.z;
	leaf.rgb = clamp(tinted * vec3(1.0 + v_tint.x, 1.0 + v_tint.x * 0.35, 1.0 - v_tint.x), 0.0, 1.0);
	ALBEDO = leaf.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
