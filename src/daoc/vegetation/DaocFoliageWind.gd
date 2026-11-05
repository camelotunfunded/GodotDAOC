extends RefCounted
class_name DaocFoliageWind

## R10-HF2 — le vent dans les feuilles.
##
## Le Grass Remaster P1-20M anime l'herbe depuis le 2026-09-02 ; les arbres, eux,
## sont restés parfaitement immobiles. Un monde où l'herbe ondule sous des arbres
## figés se lit comme deux mondes superposés, et c'est ce que ce module corrige.
##
## LE VENT EST LE MÊME, LE MOUVEMENT NE L'EST PAS. `wind_direction`,
## `wind_speed` et la formule de rafale sont recopiées à l'identique du shader
## d'herbe — constantes comprises — pour qu'une rafale couche l'herbe et agite
## les branches AU MÊME INSTANT. Ce qui diffère est la façon de bouger : une lame
## d'herbe plie depuis sa racine, une feuille est portée par une branche qui
## oscille, et elle frissonne par-dessus, plus vite et dans tous les sens.
##
## LA DIRECTION DU VENT N'EST ÉCRITE NULLE PART, et c'est mesuré et non supposé :
## `DaocGrassRemaster` ne pose jamais `wind_direction`, il laisse la valeur par
## défaut du shader. C'est donc cette constante — `vec2(0.82, 0.57)` — qui fait
## office de direction commune, et le shader de feuillage la reprend telle
## quelle. Le jour où le vent DAoC pilotera vraiment la direction, il faudra la
## poser aux DEUX endroits.
##
## RÉVERSIBLE PAR CONSTRUCTION : `foliage_wind_enabled` décoché rend exactement
## le matériau d'avant ce jalon — le module n'est alors jamais appelé, et aucun
## `ShaderMaterial` n'est créé.

const FoliageWindShader = preload("res://src/daoc/vegetation/DaocFoliageWind.gdshader")
const SpeedTreeLeafWindShader = preload("res://src/daoc/vegetation/DaocSpeedTreeLeafWind.gdshader")
const VegetatedRoofWindShader = preload("res://src/daoc/vegetation/DaocVegetatedRoofWind.gdshader")

## Le paramètre qui identifie une carte de feuilles SpeedTree. Les matériaux
## cuits au Lab se répartissent en trois familles, mesurées et non supposées :
## `*_leaf` est un `ShaderMaterial` porté par `leaf_cards.gdshader` et porte
## `foliage_texture` ; `*_frond` est un `StandardMaterial3D` en alpha scissor,
## que le chemin générique traite déjà ; `*_bark` est opaque et doit le rester.
const SPEEDTREE_LEAF_TEXTURE_PARAM := "foliage_texture"


## Les réglages, avec les valeurs partagées avec l'herbe et celles qui lui sont
## propres.
##
## AUCUNE DES TROIS VALEURS DE FEUILLAGE N'EST CALIBRÉE. Elles sont plausibles,
## pas mesurées — au même titre que `speedtree_units_to_daoc = 12`. Ce sont des
## amplitudes en unités DAoC brutes, et seul un œil humain peut dire si une cime
## bouge trop ou pas assez.
static func default_settings() -> Dictionary:
	return {
		"foliage_wind_enabled": true,
		# Houle de canopée : lente, dans l'axe du vent, croissante avec la hauteur.
		"foliage_canopy_strength_raw": 40.0,
		# Frisson de feuille : rapide, court, déphasé par sommet.
		"foliage_leaf_flutter_strength_raw": 16.0,
		# Hauteur à laquelle l'amplitude est pleine. Sous elle, le mouvement
		# décroît jusqu'à zéro au pied du tronc.
		"foliage_wind_height_reference_raw": 1200.0,
		# P1-134 : trouees de lumiere dans l ombre du feuillage (0 = ombre pleine)
		# et taille d une trouee en unites DAoC brutes.
		"foliage_sunfleck_amount": 0.32,
		"foliage_sunfleck_cell_raw": 55.0,
		# Partagés avec le Grass Remaster, mêmes valeurs.
		"wind_speed": 1.35,
		"wind_gust_strength": 0.72,
	}


## Une surface est-elle du FEUILLAGE ?
##
## Le marqueur existait déjà et n'a pas été inventé : `apply_textures` pose un
## `ALPHA_SCISSOR` sur les seules textures qui portent un canal alpha, et c'est
## exactement ce qui distingue une carte de feuilles d'un tronc plein.
##
## LA COUCHE DÉTAIL EXCLUT, et c'est délibéré : P1-21T a mesuré qu'elle porte le
## grain d'ÉCORCE et de pierre. Une surface qui en a une est un tronc ou un
## rocher — elle doit rester rigide, et elle perdrait sa couche détail en passant
## sur ce shader, qui ne la reproduit pas.
static func is_foliage_material(material: Material) -> bool:
	var base := material as BaseMaterial3D
	if base == null:
		return false
	if base.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR \
			and base.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
		return false
	if base.detail_enabled:
		return false
	return base.albedo_texture != null


## Construit le matériau animé à partir du matériau plat.
##
## Rend `null` quand la surface n'est pas du feuillage ou que le vent est
## décoché : l'appelant garde alors son matériau d'origine, inchangé.
static func build_material(source: Material, settings: Dictionary = {}) -> ShaderMaterial:
	var options := default_settings()
	for key: String in settings.keys():
		if options.has(key):
			options[key] = settings[key]
	if not bool(options["foliage_wind_enabled"]):
		return null
	if not is_foliage_material(source):
		return null

	var base := source as BaseMaterial3D
	var world_scale := float(settings.get("world_scale", 1.0))
	var asset_name := str(settings.get("asset_name", "")).to_lower()
	var building_tokens := ["house", "tavern", "forge", "smithy", "watchtower", "stable", "hut"]
	var is_building := false
	for token in building_tokens:
		if asset_name.contains(token):
			is_building = true
			break
	if is_building:
		# Dans les bâtiments DAoC, les textures alpha correspondent notamment au
		# chaume. Elles ne doivent jamais recevoir la flexion/frisure des arbres.
		# Les maisons et tavernes rurales reçoivent une variante dédiée très légère.
		if not asset_name.contains("house") and not asset_name.contains("tavern") and not asset_name.contains("hut"):
			return null
		var roof := ShaderMaterial.new()
		roof.shader = VegetatedRoofWindShader
		roof.set_shader_parameter("albedo_texture", base.albedo_texture)
		roof.set_shader_parameter("alpha_cutoff", base.alpha_scissor_threshold)
		roof.set_shader_parameter("wind_speed", float(options["wind_speed"]))
		roof.set_shader_parameter("wind_gust_strength", float(options["wind_gust_strength"]))
		roof.set_shader_parameter("roof_strength", 2.0 * world_scale)
		roof.set_meta("daoc_vegetated_roof_wind", true)
		return roof
	var shader_material := ShaderMaterial.new()
	shader_material.shader = FoliageWindShader
	shader_material.set_shader_parameter("albedo_texture", base.albedo_texture)
	shader_material.set_shader_parameter("alpha_cutoff", base.alpha_scissor_threshold)
	shader_material.set_shader_parameter("wind_speed", float(options["wind_speed"]))
	shader_material.set_shader_parameter("wind_gust_strength", float(options["wind_gust_strength"]))
	# Les amplitudes sont en unites DAoC brutes, comme celles de l'herbe, et
	# passent dans l'echelle monde par la meme multiplication.
	shader_material.set_shader_parameter("canopy_strength",
		float(options["foliage_canopy_strength_raw"]) * world_scale)
	shader_material.set_shader_parameter("leaf_flutter_strength",
		float(options["foliage_leaf_flutter_strength_raw"]) * world_scale)
	shader_material.set_shader_parameter("wind_height_reference",
		float(options["foliage_wind_height_reference_raw"]) * world_scale)
	shader_material.set_shader_parameter("sunfleck_amount", float(options["foliage_sunfleck_amount"]))
	shader_material.set_shader_parameter("sunfleck_cell", float(options["foliage_sunfleck_cell_raw"]) * world_scale)
	shader_material.set_shader_parameter("wind_enabled", 1.0)
	return shader_material


## Une carte de feuilles SpeedTree, cuite au Lab ?
##
## Reconnue par son PARAMÈTRE et non par son chemin : le paquet d'arbres vit
## derrière une jonction locale, et un chemin en dur y serait le quatrième piège
## de lettre de lecteur de la journée.
static func is_speedtree_leaf_material(material: Material) -> bool:
	var shader_material := material as ShaderMaterial
	if shader_material == null or shader_material.shader == null:
		return false
	return shader_material.get_shader_parameter(SPEEDTREE_LEAF_TEXTURE_PARAM) != null


## La variante ventée d'un matériau de cartes SpeedTree.
##
## La géométrie de carte est reprise à l'identique du shader du Lab : le vent
## déplace le CENTRE de la carte, jamais ses coins, sans quoi le quad se
## déformerait au lieu de voler.
static func build_speedtree_leaf_material(source: Material,
		settings: Dictionary = {}) -> ShaderMaterial:
	var options := default_settings()
	for key: String in settings.keys():
		if options.has(key):
			options[key] = settings[key]
	if not bool(options["foliage_wind_enabled"]):
		return null
	if not is_speedtree_leaf_material(source):
		return null

	var shader_material := source as ShaderMaterial
	var world_scale := float(settings.get("world_scale", 1.0))
	var animated := ShaderMaterial.new()
	animated.shader = SpeedTreeLeafWindShader
	animated.set_shader_parameter(SPEEDTREE_LEAF_TEXTURE_PARAM,
		shader_material.get_shader_parameter(SPEEDTREE_LEAF_TEXTURE_PARAM))
	# `alpha_cutoff` est ecrit `null` dans les .tres du Lab : la valeur par
	# defaut du shader s'applique alors, et la recopier telle quelle poserait un
	# seuil nul qui ferait disparaitre la decoupe des feuilles.
	var cutoff: Variant = shader_material.get_shader_parameter("alpha_cutoff")
	if cutoff != null:
		animated.set_shader_parameter("alpha_cutoff", float(cutoff))
	animated.set_shader_parameter("wind_speed", float(options["wind_speed"]))
	animated.set_shader_parameter("wind_gust_strength", float(options["wind_gust_strength"]))
	animated.set_shader_parameter("canopy_strength",
		float(options["foliage_canopy_strength_raw"]) * world_scale)
	animated.set_shader_parameter("leaf_flutter_strength",
		float(options["foliage_leaf_flutter_strength_raw"]) * world_scale)
	animated.set_shader_parameter("wind_height_reference",
		float(options["foliage_wind_height_reference_raw"]) * world_scale)
	animated.set_shader_parameter("sunfleck_amount", float(options["foliage_sunfleck_amount"]))
	animated.set_shader_parameter("sunfleck_cell", float(options["foliage_sunfleck_cell_raw"]) * world_scale)
	animated.set_shader_parameter("wind_enabled", 1.0)
	return animated


## La variante ventée d'un matériau, quelle que soit sa famille. Rend `null`
## quand la surface doit rester telle quelle — un tronc, par exemple.
static func build_any(source: Material, settings: Dictionary = {}) -> ShaderMaterial:
	var leaf := build_speedtree_leaf_material(source, settings)
	if leaf != null:
		return leaf
	return build_material(source, settings)


## Anime le feuillage de tout un sous-arbre déjà texturé.
##
## Utilisé par le chemin SpeedTree, dont les matériaux sont cuits hors ligne dans
## le Lab et ne passent donc jamais par `apply_textures`.
##
## Rend le nombre de surfaces réellement converties — un compte, et pas un
## booléen : « le vent est activé » et « quatre-vingts surfaces bougent » ne
## disent pas la même chose, et c'est la seconde qui se vérifie.
static func animate_subtree(root: Node, settings: Dictionary = {}) -> int:
	if root == null:
		return 0
	var converted := 0
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for node in meshes:
		var mesh_instance := node as MeshInstance3D
		var mesh: Mesh = mesh_instance.mesh
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			var current: Material = mesh_instance.get_surface_override_material(surface)
			if current == null:
				current = mesh.surface_get_material(surface)
			var animated := build_any(current, settings)
			if animated != null:
				mesh_instance.set_surface_override_material(surface, animated)
				converted += 1
	return converted
