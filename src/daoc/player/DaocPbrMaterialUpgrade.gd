extends RefCounted
class_name DaocPbrMaterialUpgrade

## Bascule Vanilla <-> PBR pour les surfaces du joueur.
##
## CE QUE C'EST. Les cartes PBR (normal, rugosite, metal, occlusion) ont ete
## generees hors ligne par `tools/generate_pbr_maps.py`, A COTE des PNG d'origine
## du client : `pltBody01_Epic_Armsman_f.png` a pour voisin
## `pltBody01_Epic_Armsman_f_normal.png`. Ce module les retrouve et les branche
## sur les materiaux d'une scene de joueur DEJA chargee.
##
## POURQUOI PASSER PAR LE MANIFESTE. Les scenes `.tscn` exportees par le Lab
## embarquent leurs textures en sous-ressources `Image` : un materiau charge au
## runtime ne sait PAS de quel PNG client il vient, donc il ne peut pas trouver
## son voisin `_normal.png` tout seul. Le `.manifest.json` pose a cote de chaque
## scene porte le lien manquant, une entree `parts` par surface :
## `slot_name` -> `texture_relative`. C'est ce lien, et lui seul, qui est suivi
## ici. Aucun export n'est retouche.
##
## REVERSIBLE PAR CONSTRUCTION. Le materiau d'origine est conserve en meta sur
## chaque `MeshInstance3D` avant toute modification ; `restore()` le repose a
## l'identique. Bascule decochee, la scene est exactement celle d'avant.
##
## LES CONVERSIONS SONT EN COURS, et le module ne le cache pas. Une surface sans
## carte reste en vanilla sans casser les autres, et le rapport la NOMME dans
## `surfaces_sans_cartes`. Une suite verte sur ce module ne prouverait donc rien
## de la couverture : c'est le rapport qu'il faut lire.

const CHECKPOINT := "PLAYER_PBR_MATERIALS"

const META_ORIGINAL := "daoc_pbr_material_vanilla"
const META_APPLIED := "daoc_pbr_applied"
const META_SOURCE := "daoc_pbr_texture_relative"

## Suffixes produits par `generate_pbr_maps.py`. `_orm` n'est pas consomme ici :
## le generateur ne l'ecrit que sur demande, et aucune tenue joueur n'en a.
const SUFFIX_NORMAL := "_normal"
const SUFFIX_ROUGHNESS := "_roughness"
const SUFFIX_METALLIC := "_metallic"
const SUFFIX_AO := "_ao"

## La fibre capillaire est constituee de keratine. Son IOR physique retenu est
## 1,55. StandardMaterial3D exprime la reponse dielectrique avec
## `metallic_specular` (0,5 = F0 4 %), pas directement avec un IOR.
const HAIR_IOR := 1.55
const GODOT_SPECULAR_F0_MAX := 0.08


static func default_options() -> Dictionary:
	return {
		"normal_strength": 1.0,
		"roughness_amount": 1.0,
		# 0 eteint l'occlusion ambiante — la plus approximative des quatre cartes,
		# estimee depuis la couleur et non cuite depuis la geometrie.
		"ao_amount": 0.35,
	}


## Applique les cartes PBR aux surfaces de `visual_root` decrites par le
## manifeste. `client_root` est la racine du client DAoC decompresse : elle est
## seulement LUE.
static func apply(visual_root: Node, manifest_path: String, client_root: String,
		options: Dictionary = {}) -> Dictionary:
	var settings := default_options()
	for key in options.keys():
		settings[str(key)] = options[key]

	var report := {
		"checkpoint": CHECKPOINT,
		"ok": false,
		"mode": "pbr",
		"manifest_path": manifest_path,
		"client_root": client_root,
		"surfaces_attendues": 0,
		"surfaces_traitees": 0,
		"cartes_appliquees": 0,
		"surfaces_sans_cartes": [],
		"surfaces_absentes": [],
		"cartes_absentes": [],
		# Surfaces dont la carte `_metallic` existe mais est entierement noire.
		# C'est le symptome d'une ligne mal classee dans le CSV d'inventaire, pas
		# d'une conversion manquante — les deux se soignent differemment.
		"cartes_metal_vides": [],
		"erreur": "",
	}

	if visual_root == null:
		report["erreur"] = "visual_root_absent"
		return report
	if client_root.strip_edges() == "":
		report["erreur"] = "racine_client_non_renseignee"
		return report

	var manifest := _read_manifest(manifest_path)
	if manifest.is_empty():
		report["erreur"] = "manifeste_illisible: %s" % manifest_path
		return report

	var parts := manifest.get("parts", []) as Array
	report["surfaces_attendues"] = parts.size()

	for part_value in parts:
		var part := part_value as Dictionary
		if part == null:
			continue
		var slot_name := str(part.get("slot_name", ""))
		var texture_relative := str(part.get("texture_relative", ""))
		if slot_name == "" or texture_relative == "":
			continue

		# Le manifeste ecrit `head`, la scene nomme le noeud `Head`.
		var node_name := slot_name.substr(0, 1).to_upper() + slot_name.substr(1)
		var mesh_instance := visual_root.find_child(node_name, true, false) as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			(report["surfaces_absentes"] as Array).append(node_name)
			continue

		var maps := _resolve_maps(client_root, texture_relative)
		if maps.is_empty():
			(report["surfaces_sans_cartes"] as Array).append(node_name)
			continue

		var applied := _apply_to_mesh(mesh_instance, maps, settings, node_name)
		if applied <= 0:
			(report["surfaces_sans_cartes"] as Array).append(node_name)
			continue

		if bool(maps.get("metallic_empty", false)):
			(report["cartes_metal_vides"] as Array).append(node_name)

		mesh_instance.set_meta(META_SOURCE, texture_relative)
		report["surfaces_traitees"] = int(report["surfaces_traitees"]) + 1
		report["cartes_appliquees"] = int(report["cartes_appliquees"]) + applied
		for missing_suffix in _missing_suffixes(client_root, texture_relative):
			(report["cartes_absentes"] as Array).append("%s%s" % [node_name, str(missing_suffix)])

	# Une tenue partiellement couverte reste un succes : les conversions sont en
	# cours, et refuser la bascule pour une seule surface manquante rendrait le
	# reglage inutilisable jusqu'a la toute derniere texture.
	report["ok"] = int(report["surfaces_traitees"]) > 0
	if not bool(report["ok"]) and str(report["erreur"]) == "":
		report["erreur"] = "aucune_surface_couverte"
	return report


## Repose les materiaux vanilla conserves par `apply()`.
static func restore(visual_root: Node) -> Dictionary:
	var report := {
		"checkpoint": CHECKPOINT,
		"ok": true,
		"mode": "vanilla",
		"surfaces_restaurees": 0,
	}
	if visual_root == null:
		report["ok"] = false
		return report
	for mesh_instance in _mesh_instances(visual_root):
		if not mesh_instance.has_meta(META_ORIGINAL):
			continue
		var originals := mesh_instance.get_meta(META_ORIGINAL) as Array
		var mesh := mesh_instance.mesh
		if mesh == null:
			continue
		for surface_index in range(mini(mesh.get_surface_count(), originals.size())):
			mesh.surface_set_material(surface_index, originals[surface_index] as Material)
		mesh_instance.remove_meta(META_ORIGINAL)
		if mesh_instance.has_meta(META_APPLIED):
			mesh_instance.remove_meta(META_APPLIED)
		report["surfaces_restaurees"] = int(report["surfaces_restaurees"]) + 1
	return report


## Couverture PBR d'un manifeste, SANS rien charger ni modifier. Sert aux
## rapports et aux tests : c'est la mesure honnete de l'avancement des
## conversions, tenue par tenue.
static func inspect_coverage(manifest_path: String, client_root: String) -> Dictionary:
	var report := {
		"checkpoint": CHECKPOINT,
		"ok": false,
		"manifest_path": manifest_path,
		"surfaces": [],
		"surfaces_completes": 0,
		"surfaces_totales": 0,
	}
	var manifest := _read_manifest(manifest_path)
	if manifest.is_empty():
		return report
	var parts := manifest.get("parts", []) as Array
	report["surfaces_totales"] = parts.size()
	for part_value in parts:
		var part := part_value as Dictionary
		var texture_relative := str(part.get("texture_relative", ""))
		if texture_relative == "":
			continue
		var directory := _resolve_directory(client_root, texture_relative)
		var stem := texture_relative.get_file().get_basename()
		var entry := {
			"slot_name": str(part.get("slot_name", "")),
			"texture_relative": texture_relative,
			"resolved_dir": directory,
		}
		var complete := directory != ""
		for pair in [
			["normal", SUFFIX_NORMAL], ["roughness", SUFFIX_ROUGHNESS],
			["metallic", SUFFIX_METALLIC], ["ao", SUFFIX_AO],
		]:
			var present := false
			if directory != "":
				present = FileAccess.file_exists(directory.path_join("%s%s.png" % [stem, str(pair[1])]))
			entry[str(pair[0])] = present
			complete = complete and present
		if complete:
			report["surfaces_completes"] = int(report["surfaces_completes"]) + 1
		(report["surfaces"] as Array).append(entry)
	report["ok"] = true
	return report


static func _apply_to_mesh(mesh_instance: MeshInstance3D, maps: Dictionary,
		settings: Dictionary, slot_name: String = "") -> int:
	var mesh := mesh_instance.mesh
	if mesh == null:
		return 0

	# Le materiau vanilla est conserve AVANT toute modification, une fois : une
	# seconde application ne doit pas archiver un materiau deja PBR.
	if not mesh_instance.has_meta(META_ORIGINAL):
		var originals: Array = []
		for surface_index in range(mesh.get_surface_count()):
			originals.append(mesh.surface_get_material(surface_index))
		mesh_instance.set_meta(META_ORIGINAL, originals)

	var vanilla_materials := mesh_instance.get_meta(META_ORIGINAL) as Array
	var applied := 0
	for surface_index in range(mesh.get_surface_count()):
		if surface_index >= vanilla_materials.size():
			continue
		var vanilla := vanilla_materials[surface_index] as StandardMaterial3D
		if vanilla == null:
			continue
		# Toujours repartir du materiau VANILLA archive : une seconde bascule
		# avec d'autres intensites ne doit pas empiler ses reglages.
		#
		# Duplication SUPERFICIELLE, et c'est deliberé : une copie profonde
		# recopierait aussi la texture de couleur, soit sept images embarquees
		# dupliquees en memoire pour ne rien changer a l'image. Le PBR complete
		# le materiau vanilla, il ne le remplace pas — la couleur reste la meme
		# ressource, partagee.
		var material := vanilla.duplicate(false) as StandardMaterial3D
		material.resource_name = "%s_pbr" % str(vanilla.resource_name)
		if slot_name.to_lower() == "hair":
			material.metallic_specular = _ior_to_godot_specular(HAIR_IOR)

		if maps.has("normal"):
			material.normal_enabled = true
			material.normal_texture = maps["normal"] as Texture2D
			material.normal_scale = float(settings.get("normal_strength", 1.0))
			applied += 1
		if maps.has("roughness"):
			material.roughness_texture = maps["roughness"] as Texture2D
			material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			# `roughness` sert de MULTIPLICATEUR quand une carte est branchee.
			material.roughness = clampf(float(settings.get("roughness_amount", 1.0)), 0.0, 1.0)
			applied += 1
		if maps.has("metallic"):
			material.metallic_texture = maps["metallic"] as Texture2D
			material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			material.metallic = 1.0
			applied += 1
		if maps.has("ao") and float(settings.get("ao_amount", 0.35)) > 0.0:
			material.ao_enabled = true
			material.ao_texture = maps["ao"] as Texture2D
			material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			material.ao_light_affect = clampf(float(settings.get("ao_amount", 0.35)), 0.0, 1.0)
			applied += 1

		mesh.surface_set_material(surface_index, material)

	if applied > 0:
		mesh_instance.set_meta(META_APPLIED, true)
	return applied


## Fresnel normal d'un dielectrique : F0 = ((ior - 1) / (ior + 1))².
## Godot encode ensuite F0 sur l'intervalle 0..8 % dans metallic_specular.
static func _ior_to_godot_specular(ior: float) -> float:
	var safe_ior := maxf(ior, 1.0)
	var ratio := (safe_ior - 1.0) / (safe_ior + 1.0)
	return clampf((ratio * ratio) / GODOT_SPECULAR_F0_MAX, 0.0, 1.0)


## Retrouve les cartes voisines du PNG d'origine.
##
## LE PIEGE, mesure sur la tenue epique d'Armsman : le manifeste ecrit parfois le
## chemin DECLARE — `figures/Mskins/pltBody01_Epic_Armsman_f.png` — alors que le
## fichier vit dans un sous-dossier de mskin : `figures/Mskins/mskin018/...`.
## Une resolution litterale rendrait « aucune carte » sur une tenue pourtant
## couverte a 100 %. On retombe donc sur les sous-dossiers immediats du parent.
static func _resolve_maps(client_root: String, texture_relative: String) -> Dictionary:
	var directory := _resolve_directory(client_root, texture_relative)
	if directory == "":
		return {}
	var stem := texture_relative.get_file().get_basename()
	var maps: Dictionary = {}
	for entry in [
		["normal", SUFFIX_NORMAL], ["roughness", SUFFIX_ROUGHNESS],
		["metallic", SUFFIX_METALLIC], ["ao", SUFFIX_AO],
	]:
		var path := directory.path_join("%s%s.png" % [stem, str(entry[1])])
		if not FileAccess.file_exists(path):
			continue
		var image := Image.load_from_file(path)
		if image == null or image.is_empty():
			continue
		maps[str(entry[0])] = ImageTexture.create_from_image(image)
		# Une carte entierement noire est INERTE : elle occupe un canal sans rien
		# y mettre. Le rapport doit la nommer, sinon le reglage correspondant
		# parait casse alors que c'est la donnee qui manque.
		if str(entry[0]) == "metallic" and _is_black(image):
			maps["metallic_empty"] = true
	return maps


## Balayage clairseme : on cherche s'il existe UN pixel non nul, pas une moyenne.
static func _is_black(image: Image) -> bool:
	var width := image.get_width()
	var height := image.get_height()
	if width <= 0 or height <= 0:
		return true
	var step := maxi(1, mini(width, height) / 64)
	for y in range(0, height, step):
		for x in range(0, width, step):
			if image.get_pixel(x, y).r > 0.004:
				return false
	return true


static func _missing_suffixes(client_root: String, texture_relative: String) -> Array:
	var directory := _resolve_directory(client_root, texture_relative)
	if directory == "":
		return []
	var stem := texture_relative.get_file().get_basename()
	var missing: Array = []
	for suffix in [SUFFIX_NORMAL, SUFFIX_ROUGHNESS, SUFFIX_METALLIC, SUFFIX_AO]:
		if not FileAccess.file_exists(directory.path_join("%s%s.png" % [stem, suffix])):
			missing.append(suffix)
	return missing


static func _resolve_directory(client_root: String, texture_relative: String) -> String:
	if client_root.strip_edges() == "" or texture_relative.strip_edges() == "":
		return ""
	var normalized := texture_relative.replace("\\", "/")
	var stem := normalized.get_file().get_basename()
	var declared := client_root.path_join(normalized.get_base_dir())
	if FileAccess.file_exists(declared.path_join("%s.png" % stem)):
		return declared
	# Retombee : les sous-dossiers immediats de `figures/Mskins`.
	for sub in DirAccess.get_directories_at(declared):
		var candidate := declared.path_join(str(sub))
		if FileAccess.file_exists(candidate.path_join("%s.png" % stem)):
			return candidate
	return ""


static func _read_manifest(path: String) -> Dictionary:
	if path.strip_edges() == "" or not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary


static func _mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		result.append(root as MeshInstance3D)
	for child in root.get_children():
		result.append_array(_mesh_instances(child))
	return result
