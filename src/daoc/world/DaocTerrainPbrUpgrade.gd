extends RefCounted
class_name DaocTerrainPbrUpgrade

## Bascule Vanilla <-> PBR pour le SOL des zones.
##
## CE QUE C'EST. `generate_pbr_maps.py` a pose, a cote de chaque texture de
## terrain du client, ses voisines `<nom>_normal.png`, `<nom>_roughness.png`,
## `<nom>_ao.png` et `<nom>_metallic.png` (`zones/TerrainTex/`). Ce module les
## retrouve, les empile en trois `Texture2DArray` (normale RGB8, rugosite L8,
## occlusion L8) indexes EXACTEMENT comme le tableau `details` du cache splat,
## et les branche sur les materiaux de sol. La carte de metal n'est pas lue :
## un sol est un dielectrique, et un tableau de plus par zone ne vaut pas ce
## qu'il coute en VRAM.
##
## POURQUOI PASSER PAR LE MANIFESTE. Le sol ne lit pas `TerrainTex` en direct :
## il lit un cache disque pre-cuit par zone (`zoneNNN_splat/details/NN.png`),
## dont le `manifest.json` porte la liste `details` — le NOM de la texture
## source a chaque index. C'est ce lien, et lui seul, qui est suivi ici : le
## cache n'est pas retouche, l'outil Python non plus.
##
## REVERSIBLE PAR CONSTRUCTION. Le shader garde son chemin d'origine derriere
## `pbr_enabled = false` ; decocher rejoue ce chemin sans reconstruire un seul
## maillage. Les tableaux restent en memoire tant que la zone est residente.
##
## LES CONVERSIONS PEUVENT ETRE INCOMPLETES, et le module ne le cache pas : une
## couche sans cartes recoit une normale plate, une rugosite pleine et une
## occlusion neutre — elle est rendue comme en vanilla — et le rapport la NOMME
## dans `couches_sans_cartes`. C'est le rapport qu'il faut lire, pas la suite.

const CHECKPOINT := "TERRAIN_PBR_MATERIALS"

const TERRAIN_TEX_DIR := "zones/TerrainTex"
const SUFFIX_NORMAL := "_normal"
const SUFFIX_ROUGHNESS := "_roughness"
const SUFFIX_AO := "_ao"

## Le preset livre. `map_size` est la taille de chaque tranche : 1024 est le
## point d'equilibre VRAM (deux tableaux de plus par zone, en plus des 2048 de
## l'albedo). Le joueur sur petite config coupe simplement `enabled`.
const QUALITY_DEFAULTS := {
	"enabled": false,
	"map_size": 1024,
	"normal_strength": 1.0,
	"ao_amount": 1.0,
	"macro_variation_enabled": false,
	"macro_variation_scale": 96.0,
	"macro_color_strength": 0.08,
	"macro_roughness_strength": 0.12,
	"macro_seed": 173.0,
}

## Noms des parametres du shader `terrain_splat.gdshader`.
const PARAM_ENABLED := "pbr_enabled"
const PARAM_NORMALS := "normals"
const PARAM_ROUGHNESS := "roughness_maps"
const PARAM_AO := "ao_maps"
const PARAM_NORMAL_STRENGTH := "pbr_normal_strength"
const PARAM_AO_AMOUNT := "pbr_ao_amount"
const PARAM_VIRTUAL_RELIEF_ENABLED := "virtual_relief_enabled"
const PARAM_VIRTUAL_RELIEF_DEPTH := "virtual_relief_depth"
const PARAM_VIRTUAL_RELIEF_STEPS := "virtual_relief_steps"
const PARAM_MACRO_VARIATION_ENABLED := "macro_variation_enabled"
const PARAM_MACRO_VARIATION_SCALE := "macro_variation_scale"
const PARAM_MACRO_COLOR_STRENGTH := "macro_color_strength"
const PARAM_MACRO_ROUGHNESS_STRENGTH := "macro_roughness_strength"
const PARAM_MACRO_SEED := "macro_seed"


## Empile les cartes d'une zone. `detail_names` est la liste `details` du
## manifeste splat, dans l'ordre : la tranche `i` des tableaux rendus correspond
## a la tranche `i` de `details`.
static func load_zone_maps(client_root: String, detail_names: Array, map_size: int) -> Dictionary:
	var report := {
		"checkpoint": CHECKPOINT,
		"ok": false,
		"client_root": client_root,
		"map_size": map_size,
		"couches_attendues": detail_names.size(),
		"couches_avec_cartes": 0,
		"couches_sans_cartes": [],
		"cartes_absentes": [],
		"normals": null,
		"roughness": null,
		"ao": null,
		"erreur": "",
	}
	if client_root.is_empty() or not DirAccess.dir_exists_absolute(client_root):
		report["erreur"] = "racine client introuvable : %s" % client_root
		return report
	if detail_names.is_empty():
		report["erreur"] = "manifeste splat sans couche"
		return report
	var size := maxi(16, map_size)
	var normal_images: Array[Image] = []
	var rough_images: Array[Image] = []
	var ao_images: Array[Image] = []
	for value in detail_names:
		var stem := str(value)
		var base := "%s/%s/%s" % [client_root, TERRAIN_TEX_DIR, stem]
		var normal_img := _load_linear(base + SUFFIX_NORMAL + ".png", size, Image.FORMAT_RGB8)
		var rough_img := _load_linear(base + SUFFIX_ROUGHNESS + ".png", size, Image.FORMAT_L8)
		var ao_img := _load_linear(base + SUFFIX_AO + ".png", size, Image.FORMAT_L8)
		var missing: Array = []
		if normal_img == null:
			missing.append(stem + SUFFIX_NORMAL)
		if rough_img == null:
			missing.append(stem + SUFFIX_ROUGHNESS)
		if ao_img == null:
			missing.append(stem + SUFFIX_AO)
		if missing.is_empty():
			report["couches_avec_cartes"] = int(report["couches_avec_cartes"]) + 1
		else:
			(report["couches_sans_cartes"] as Array).append(stem)
			for name in missing:
				(report["cartes_absentes"] as Array).append(name)
		# Valeurs NEUTRES pour ce qui manque : la couche est rendue comme en vanilla.
		normal_images.append(normal_img if normal_img != null else _solid(size, Image.FORMAT_RGB8, Color(0.5, 0.5, 1.0)))
		rough_images.append(rough_img if rough_img != null else _solid(size, Image.FORMAT_L8, Color.WHITE))
		ao_images.append(ao_img if ao_img != null else _solid(size, Image.FORMAT_L8, Color.WHITE))
	report["normals"] = _array_of(normal_images)
	report["roughness"] = _array_of(rough_images)
	report["ao"] = _array_of(ao_images)
	report["ok"] = true
	return report


static func _array_of(images: Array[Image]) -> Texture2DArray:
	var arr := Texture2DArray.new()
	arr.create_from_images(images)
	return arr


## Applique (ou retire) le PBR sur une liste de `MeshInstance3D` de sol, sans
## rien reconstruire. `options` : `enabled`, `normal_strength`, `ao_amount`,
## plus les trois tableaux `normals` / `roughness` / `ao` rendus par `load_zone_maps`.
static func apply(terrain_meshes: Array, options: Dictionary) -> Dictionary:
	var report := {"checkpoint": CHECKPOINT, "materiaux_traites": 0, "materiaux_ignores": 0}
	for value in terrain_meshes:
		var mi := value as MeshInstance3D
		if mi == null:
			continue
		var mat := mi.material_override as ShaderMaterial
		if mat == null:
			# Sol a texture unique (pas de splat) : il n'a pas de couches, donc
			# pas de cartes a empiler. Il reste tel quel, et ce n'est pas une erreur.
			report["materiaux_ignores"] = int(report["materiaux_ignores"]) + 1
			continue
		apply_to_material(mat, options)
		report["materiaux_traites"] = int(report["materiaux_traites"]) + 1
	return report


static func apply_to_material(mat: ShaderMaterial, options: Dictionary) -> void:
	var enabled := bool(options.get("enabled", false))
	var normals: Texture2DArray = options.get("normals", null) as Texture2DArray
	var roughness: Texture2DArray = options.get("roughness", null) as Texture2DArray
	var ao: Texture2DArray = options.get("ao", null) as Texture2DArray
	# Coche sans tableaux = rien a montrer : on reste en vanilla plutot que
	# d'echantillonner un sampler vide (noir), ce qui aplatirait le sol.
	if normals == null or roughness == null or ao == null:
		enabled = false
	mat.set_shader_parameter(PARAM_ENABLED, enabled)
	if normals != null:
		mat.set_shader_parameter(PARAM_NORMALS, normals)
	if roughness != null:
		mat.set_shader_parameter(PARAM_ROUGHNESS, roughness)
	if ao != null:
		mat.set_shader_parameter(PARAM_AO, ao)
	mat.set_shader_parameter(PARAM_NORMAL_STRENGTH,
		clampf(float(options.get("normal_strength", QUALITY_DEFAULTS["normal_strength"])), 0.0, 4.0))
	mat.set_shader_parameter(PARAM_AO_AMOUNT,
		clampf(float(options.get("ao_amount", QUALITY_DEFAULTS["ao_amount"])), 0.0, 1.0))
	mat.set_shader_parameter(PARAM_VIRTUAL_RELIEF_ENABLED,
		bool(options.get("virtual_relief_enabled", false)) and enabled)
	mat.set_shader_parameter(PARAM_VIRTUAL_RELIEF_DEPTH,
		clampf(float(options.get("virtual_relief_depth", 0.018)), 0.0, 0.08))
	mat.set_shader_parameter(PARAM_VIRTUAL_RELIEF_STEPS,
		clampi(int(options.get("virtual_relief_steps", 6)), 2, 12))
	mat.set_shader_parameter(PARAM_MACRO_VARIATION_ENABLED,
		bool(options.get("macro_variation_enabled", QUALITY_DEFAULTS["macro_variation_enabled"])))
	mat.set_shader_parameter(PARAM_MACRO_VARIATION_SCALE,
		clampf(float(options.get("macro_variation_scale", QUALITY_DEFAULTS["macro_variation_scale"])), 4.0, 512.0))
	mat.set_shader_parameter(PARAM_MACRO_COLOR_STRENGTH,
		clampf(float(options.get("macro_color_strength", QUALITY_DEFAULTS["macro_color_strength"])), 0.0, 0.35))
	mat.set_shader_parameter(PARAM_MACRO_ROUGHNESS_STRENGTH,
		clampf(float(options.get("macro_roughness_strength", QUALITY_DEFAULTS["macro_roughness_strength"])), 0.0, 0.5))
	mat.set_shader_parameter(PARAM_MACRO_SEED,
		clampf(float(options.get("macro_seed", QUALITY_DEFAULTS["macro_seed"])), 0.0, 4096.0))
	# P1-118 — sol sec mat et creux lisibles au soleil ; absents = rendu d.avant.
	mat.set_shader_parameter("dry_roughness_floor", clampf(float(options.get("dry_roughness_floor", 0.0)), 0.0, 1.0))
	mat.set_shader_parameter("pbr_ao_light_affect", clampf(float(options.get("ao_light_affect", 0.0)), 0.0, 1.0))
	mat.set_shader_parameter("dry_specular", clampf(float(options.get("dry_specular", 0.5)), 0.0, 1.0))


## Ce que le materiau affiche VRAIMENT — pour une suite qui refuse de croire
## l'appelant.
static func material_state(mat: ShaderMaterial) -> Dictionary:
	if mat == null:
		return {}
	return {
		"enabled": bool(mat.get_shader_parameter(PARAM_ENABLED)),
		"normals": mat.get_shader_parameter(PARAM_NORMALS),
		"roughness": mat.get_shader_parameter(PARAM_ROUGHNESS),
		"ao": mat.get_shader_parameter(PARAM_AO),
		"normal_strength": float(mat.get_shader_parameter(PARAM_NORMAL_STRENGTH)),
		"ao_amount": float(mat.get_shader_parameter(PARAM_AO_AMOUNT)),
		"virtual_relief_enabled": bool(mat.get_shader_parameter(PARAM_VIRTUAL_RELIEF_ENABLED)),
		"virtual_relief_depth": float(mat.get_shader_parameter(PARAM_VIRTUAL_RELIEF_DEPTH)),
		"virtual_relief_steps": int(mat.get_shader_parameter(PARAM_VIRTUAL_RELIEF_STEPS)),
		"macro_variation_enabled": bool(mat.get_shader_parameter(PARAM_MACRO_VARIATION_ENABLED)),
		"macro_variation_scale": float(mat.get_shader_parameter(PARAM_MACRO_VARIATION_SCALE)),
		"macro_color_strength": float(mat.get_shader_parameter(PARAM_MACRO_COLOR_STRENGTH)),
		"macro_roughness_strength": float(mat.get_shader_parameter(PARAM_MACRO_ROUGHNESS_STRENGTH)),
		"macro_seed": float(mat.get_shader_parameter(PARAM_MACRO_SEED)),
	}


## Une carte lue en LINEAIRE : ce sont des donnees, pas des couleurs. Le PNG est
## remis a la taille du tableau (toutes les tranches doivent etre egales) et au
## format demande — L8 pour une carte grise, quatre fois moins de VRAM qu'en RGBA.
static func _load_linear(path: String, size: int, format: int) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img == null:
		return null
	if img.get_width() != size or img.get_height() != size:
		img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	img.convert(format)
	img.generate_mipmaps()
	return img


static func _solid(size: int, format: int, color: Color) -> Image:
	var img := Image.create(size, size, false, format)
	img.fill(color)
	img.generate_mipmaps()
	return img
