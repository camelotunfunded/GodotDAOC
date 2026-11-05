extends RefCounted
class_name DaocPlayerEquipmentVisuals

## P1-93 — la POUPEE : ce que le personnage montre suit ce qu'il PORTE.
##
## La scene du Lab arrive cuite avec une panoplie dans ses textures. Ce module
## la RE-HABILLE d'apres l'inventaire de l'arbitre :
##   - armure fig3 (corps, jambes, bottes, bras, gants) = une TEXTURE Mskins
##     posee sur la piece de corps ; logement vide = peau raciale de l'apparence ;
##   - casque, armes, bouclier = un NIF d'`items/` converti par le meme
##     convertisseur que les decors et accroche a un os (`Bip01 R Held`,
##     `Bip01 L Shield`, `Bip01 Helmet`), comme le Lab le faisait hors ligne.
## Les pieces rigides cuites dans la scene sont retirees d'abord : si le sac
## dit « rien en main », la main est vide.
##
## Il ne DECIDE rien : il recoit l'instantane de DaocPlayerInventory (cote
## autorite) et le traduit. Les deux instances de la scene (marche/course) sont
## habillees a l'identique.

const TablesScript = preload("res://src/daoc/player/DaocEquipmentTables.gd")
const AssetRegistryScript = preload("res://src/daoc/DaocAssetIndexRegistry.gd")
const PbrUpgradeScript = preload("res://src/daoc/player/DaocPbrMaterialUpgrade.gd")
const WindingFixScript = preload("res://src/daoc/assets/DaocMeshWindingFix.gd")

const ARMOR_VISUAL_TO_MESH := {"body": "Body", "legs": "Legs", "boots": "Boots", "arms": "Arms", "gloves": "Gloves"}
const ATTACHMENT_BONES := {
	"head": "Bip01 Helmet",
	"right_hand": "Bip01 R Held",
	"left_hand": "Bip01 L Shield",
	"two_hand": "Bip01 R Held",
	"distance": "Bip01 R Back",
}
const META_EQUIPMENT_SLOT := "daoc_equipment_slot"
## P1-133 : os de la main et os de rangement (objects.csv Belt, voir
## DaocEquipmentTables.weapon_sheath_bone). Vide = l arme reste en main.
const META_HAND_BONE := "daoc_hand_bone"
const META_SHEATH_BONE := "daoc_sheath_bone"
const CATALOG_MANIFEST_PATH := "res://generated/client_catalog/catalog.manifest.draft.json"

var client_root: String = ""
var appearance_id: int = 2
var gender: String = "female"
var tables: RefCounted = null
var _registry: RefCounted = null
var _texture_cache: Dictionary = {}
var _last_report: Dictionary = {}
var _catalog_manifest: Dictionary = {}
## P1-133 : vrai hors combat (armes rangees), faux en mode combat (0x74 / attaque
## locale). Le client d origine demarre armes rangees.
var sheathed: bool = true


func configure(root: String, p_appearance_id: int, p_gender: String) -> Dictionary:
	client_root = root.replace("\\", "/").trim_suffix("/")
	appearance_id = p_appearance_id
	gender = p_gender.to_lower()
	tables = TablesScript.new()
	if not tables.load_tables(client_root):
		return {"ok": false, "reason": tables.load_error}
	_registry = AssetRegistryScript.new()
	_registry.configure({
		"daoc_client_root": client_root,
		"models_dir": client_root.path_join("items"),
		"texture_dirs": [client_root.path_join("items"), client_root.path_join("items/pskins")],
		"use_nif_reader": true,
		"link_textures": true,
		"prop_dense_lod_enabled": false,
		"log_missing_models": false,
		"export_missing_models_csv": false,
	})
	return {"ok": true, "tables": tables.table_counts()}


## `equipped` : logement eInventorySlot -> objet (avec `model`). Les racines
## sont les instances de la scene (marche, course) sous le DaocPlayerVisualRoot.
##
## P1-95 — SEUL LE JEU D'ARMES ACTIF EST MONTRE. Le Lab cuit tout ce que le
## personnage possede (epee + bouclier + baton + arc) ; le client d'origine ne
## montre que ce qui est en main : droite + gauche, OU deux mains, OU distance.
## `active_weapon_slots` est l'octet VisibleActiveWeaponSlots du 0x02 / 0x15 :
## quartet bas = logement de la main droite (10 + n), quartet haut = main
## gauche, 0xF = rien. -1 = inconnu (hors ligne) : deux mains si elle est seule
## en main, sinon droite + gauche ; l'arme a distance reste dans le dos, jamais
## en main.
func apply(visual_roots: Array, equipped: Dictionary, active_weapon_slots: int = -1) -> Dictionary:
	var report := {
		"ok": tables != null and tables.loaded, "armor": {}, "rigid": {}, "removed_baked": 0,
		"textures_applied": 0, "attachments": 0, "errors": [], "active_weapon_slots": active_weapon_slots,
		"weapons_shown": [], "weapons_hidden": [],
	}
	if not bool(report["ok"]):
		(report["errors"] as Array).append("tables non chargees")
		_last_report = report
		return report
	var by_visual: Dictionary = {}
	for slot_value in equipped.keys():
		var visual := str(TablesScript.INVENTORY_SLOT_TO_VISUAL.get(int(slot_value), ""))
		if visual != "":
			by_visual[visual] = equipped[slot_value]
	var shown := active_weapon_visuals(by_visual, active_weapon_slots)
	for visual in ["right_hand", "left_hand", "two_hand", "distance"]:
		if by_visual.has(visual) and not shown.has(visual):
			(report["weapons_hidden"] as Array).append(visual)
			by_visual.erase(visual)
	var two_handed_active := by_visual.has("two_hand")
	# La deux-mains active se tient dans la main droite.
	if by_visual.has("two_hand"):
		by_visual["right_hand"] = by_visual["two_hand"]
		by_visual.erase("two_hand")
	report["weapons_shown"] = shown

	for root_value in visual_roots:
		var root := root_value as Node
		if root == null:
			continue
		if str(root.get_meta("daoc_catalog_schema", "")).begins_with("daoc-modern-player-catalog/"):
			_apply_catalog_root(root, by_visual, report)
			continue
		report["removed_baked"] = int(report["removed_baked"]) + _remove_rigid_attachments(root)
		for visual in ARMOR_VISUAL_TO_MESH.keys():
			var resolved := _armor_texture_for(visual, by_visual.get(visual, {}) as Dictionary)
			(report["armor"] as Dictionary)[visual] = resolved
			if str(resolved.get("texture_relative", "")) == "":
				continue
			if _apply_armor_texture(root, str(ARMOR_VISUAL_TO_MESH[visual]), str(resolved["texture_relative"])):
				report["textures_applied"] = int(report["textures_applied"]) + 1
		for visual in ATTACHMENT_BONES.keys():
			if not by_visual.has(visual):
				continue
			var item := by_visual[visual] as Dictionary
			var attached := _attach_rigid(root, visual, item)
			(report["rigid"] as Dictionary)[visual] = attached
			if bool(attached.get("ok", false)):
				report["attachments"] = int(report["attachments"]) + 1
			else:
				(report["errors"] as Array).append("%s: %s" % [visual, str(attached.get("reason", ""))])
	# P1-133 : chaque arme apprend ou elle se range, puis prend l etat courant.
	for root_value in visual_roots:
		if root_value is Node:
			_tag_sheath_bones(root_value as Node, two_handed_active)
			apply_sheath_state(root_value as Node, _sheathed_for(root_value as Node))
	_apply_helm_hair(visual_roots, by_visual, report)
	_last_report = report
	return report


func _apply_catalog_root(root: Node, by_visual: Dictionary, report: Dictionary) -> void:
	_load_catalog_manifest()
	report["removed_baked"] = int(report["removed_baked"]) + _remove_rigid_attachments(root)
	for visual in ARMOR_VISUAL_TO_MESH.keys():
		var mesh_instance := root.find_child(str(ARMOR_VISUAL_TO_MESH[visual]), true, false) as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		if not mesh_instance.has_meta("daoc_catalog_base_material"):
			mesh_instance.set_meta("daoc_catalog_base_material", mesh_instance.get_surface_override_material(0))
		var resolved := _armor_texture_for(visual, by_visual.get(visual, {}) as Dictionary)
		(report["armor"] as Dictionary)[visual] = resolved
		var material: Material = null
		var mskin_id := -1
		if by_visual.has(visual):
			var item_result: Dictionary = tables.resolve_equipment_model(int((by_visual[visual] as Dictionary).get("model", 0)), visual, appearance_id)
			var mskin: Dictionary = item_result.get("mskin", {}) as Dictionary
			mskin_id = int(mskin.get("mskin_id", -1))
			material = _catalog_material("mskin_%d" % mskin_id)
		else:
			# Ne jamais restaurer le mskin_217/220 générique cuit par l'ancien Lab :
			# c'était précisément le tissu identique collé à toutes les races.
			# `_armor_texture_for` fournit la peau raciale quand elle est connue ;
			# à défaut on conserve la matière courante au lieu d'inventer une race.
			material = null
		if material != null:
			# P1-133 : le materiau du catalogue ne porte que l albedo ; ses cartes PBR
			# sont a cote du PNG client (resolved.texture_relative).
			var rel := str(resolved.get("texture_relative", ""))
			if rel != "" and material is StandardMaterial3D:
				material = (material as StandardMaterial3D).duplicate(false)
				_apply_pbr_maps(material as StandardMaterial3D, PbrUpgradeScript._resolve_maps(client_root, rel))
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				mesh_instance.set_surface_override_material(surface_index, material)
			mesh_instance.set_meta("daoc_mskin_id", mskin_id if mskin_id >= 0 else int(mesh_instance.get_meta("daoc_mskin_id", -1)))
			report["textures_applied"] = int(report["textures_applied"]) + 1
		elif str(resolved.get("texture_relative", "")) != "" and _apply_catalog_texture(mesh_instance, str(resolved["texture_relative"])):
			report["textures_applied"] = int(report["textures_applied"]) + 1
	for visual in ATTACHMENT_BONES.keys():
		if not by_visual.has(visual):
			continue
		var item := by_visual[visual] as Dictionary
		var attached := _attach_catalog_rigid(root, visual, item)
		if not bool(attached.get("ok", false)):
			attached = _attach_rigid(root, visual, item)
		(report["rigid"] as Dictionary)[visual] = attached
		if bool(attached.get("ok", false)):
			report["attachments"] = int(report["attachments"]) + 1
		else:
			(report["errors"] as Array).append("%s: %s" % [visual, str(attached.get("reason", ""))])


func _load_catalog_manifest() -> void:
	if not _catalog_manifest.is_empty() or not FileAccess.file_exists(CATALOG_MANIFEST_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_MANIFEST_PATH))
	if parsed is Dictionary:
		_catalog_manifest = parsed as Dictionary


func _catalog_resource_path(relative: String) -> String:
	return relative if relative.begins_with("res://") else "res://%s" % relative.trim_prefix("/")


func _catalog_material(key: String) -> Material:
	var entry: Dictionary = (_catalog_manifest.get("materials", {}) as Dictionary).get(key, {}) as Dictionary
	var path := _catalog_resource_path(str(entry.get("resource", "")))
	return load(path) as Material if path != "res://" and ResourceLoader.exists(path) else null


## Variante de secours pour un skin qui n'est pas encore precalcule dans le
## catalogue : seule la surcharge de materiau change, jamais le maillage partage.
func _apply_catalog_texture(mesh_instance: MeshInstance3D, texture_relative: String) -> bool:
	var texture := _load_texture(texture_relative)
	if texture == null:
		return false
	var maps: Dictionary = PbrUpgradeScript._resolve_maps(client_root, texture_relative)
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var base := mesh_instance.get_surface_override_material(surface_index) as StandardMaterial3D
		var material := base.duplicate(false) as StandardMaterial3D if base != null else StandardMaterial3D.new()
		material.albedo_texture = texture
		material.albedo_color = Color.WHITE
		_apply_pbr_maps(material, maps)
		mesh_instance.set_surface_override_material(surface_index, material)
	mesh_instance.set_meta("daoc_texture_path", client_root.path_join(texture_relative))
	return true


func _attach_catalog_rigid(root: Node, visual: String, item: Dictionary) -> Dictionary:
	var skeleton := _find_skeleton(root)
	if skeleton == null:
		return {"ok": false, "reason": "squelette absent"}
	var model_id := int(item.get("model", 0))
	# Le draft indexe encore les casques par Model seulement, alors que ce Model
	# pointe vers un NIF different pour chaque race/sexe. Ne jamais reutiliser le
	# casque breton precalcule sur une autre apparence.
	if visual == "head" and appearance_id != 2:
		return {"ok": false, "reason": "casque catalogue d'une autre apparence", "model_id": model_id}
	var lookup_visual := "two_hand" if visual == "right_hand" and (_catalog_manifest.get("rigid_items", {}) as Dictionary).has("model_%d_two_hand" % model_id) else visual
	var key := "model_%d_%s" % [model_id, lookup_visual]
	var entry: Dictionary = (_catalog_manifest.get("rigid_items", {}) as Dictionary).get(key, {}) as Dictionary
	if entry.is_empty():
		return {"ok": false, "reason": "objet absent du catalogue", "model_id": model_id}
	var path := _catalog_resource_path(str(entry.get("scene", "")))
	var packed := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if packed == null:
		return {"ok": false, "reason": "scene catalogue absente", "model_id": model_id}
	var bone_name := _equipment_bone(visual, item, str(entry.get("bone", ATTACHMENT_BONES.get(visual, ""))))
	if skeleton.find_bone(bone_name) < 0:
		return {"ok": false, "reason": "os d'attache absent: %s" % bone_name, "model_id": model_id}
	var attachment := BoneAttachment3D.new()
	attachment.name = "%sAttachment" % visual.to_pascal_case()
	attachment.bone_idx = skeleton.find_bone(bone_name)
	attachment.set_meta(META_EQUIPMENT_SLOT, visual)
	attachment.set_meta("daoc_model_id", model_id)
	skeleton.add_child(attachment)
	attachment.add_child(packed.instantiate())
	return {"ok": true, "source": "catalog", "bone": bone_name, "model_id": model_id}


func last_report() -> Dictionary:
	return _last_report.duplicate(true)


func _armor_texture_for(visual: String, item: Dictionary) -> Dictionary:
	if item.is_empty():
		var base: Dictionary = tables.base_armor_texture(visual, gender, appearance_id)
		return {"ok": bool(base.get("ok", false)), "source": "base_cloth", "model_id": 0,
			"texture_relative": str(base.get("runtime_relative", "")), "reason": str(base.get("reason", ""))}
	var resolved: Dictionary = tables.resolve_equipment_model(int(item.get("model", 0)), visual, appearance_id)
	if not bool(resolved.get("ok", false)) or str(resolved.get("texture_relative", "")) == "":
		# Objet sans texture Catacombs : on garde la base plutot qu'une piece
		# cuite d'une autre tenue, et on le dit.
		var base: Dictionary = tables.base_armor_texture(visual, gender, appearance_id)
		return {"ok": false, "source": "unresolved_fallback_base", "model_id": int(item.get("model", 0)),
			"texture_relative": str(base.get("runtime_relative", "")), "reason": str(resolved.get("reason", ""))}
	return {"ok": true, "source": "objects_pskin_mskin", "model_id": int(item.get("model", 0)),
		"texture_relative": str(resolved["texture_relative"]), "label": str(resolved.get("label", ""))}


func _apply_armor_texture(root: Node, mesh_name: String, texture_relative: String) -> bool:
	var mesh_instance := root.find_child(mesh_name, true, false) as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null:
		return false
	var texture := _load_texture(texture_relative)
	if texture == null:
		return false
	var maps: Dictionary = PbrUpgradeScript._resolve_maps(client_root, texture_relative)
	# Chaque instance a son propre maillage : deux tenues differentes sur deux
	# personnages ne doivent pas partager une ressource.
	if not mesh_instance.has_meta("daoc_equipment_mesh_owned"):
		mesh_instance.mesh = mesh_instance.mesh.duplicate(true)
		mesh_instance.set_meta("daoc_equipment_mesh_owned", true)
	var mesh := mesh_instance.mesh
	for surface_index in range(mesh.get_surface_count()):
		var current := mesh.surface_get_material(surface_index) as StandardMaterial3D
		var material := current.duplicate(false) as StandardMaterial3D if current != null else StandardMaterial3D.new()
		material.resource_name = "%s_%s" % [mesh_name, texture_relative.get_file().get_basename()]
		material.albedo_color = Color.WHITE
		material.albedo_texture = texture
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_apply_pbr_maps(material, maps)
		material.set_meta("daoc_texture_path", client_root.path_join(texture_relative))
		mesh.surface_set_material(surface_index, material)
	mesh_instance.set_meta("daoc_texture_path", client_root.path_join(texture_relative))
	return true


func _load_texture(texture_relative: String) -> Texture2D:
	var key := texture_relative.to_lower()
	if _texture_cache.has(key):
		return _texture_cache[key] as Texture2D
	var path := client_root.path_join(texture_relative)
	if not FileAccess.file_exists(path):
		_texture_cache[key] = null
		return null
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		_texture_cache[key] = null
		return null
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	texture.resource_name = texture_relative.get_file().get_basename()
	_texture_cache[key] = texture
	return texture


func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


## Retire les pieces rigides, cuites par le Lab ou posees ici plus tot.
func _remove_rigid_attachments(root: Node) -> int:
	var skeleton := _find_skeleton(root)
	if skeleton == null:
		return 0
	var removed := 0
	for child in skeleton.get_children():
		if child is BoneAttachment3D and (child.has_meta(META_EQUIPMENT_SLOT) or str(child.name).ends_with("Attachment")):
			skeleton.remove_child(child)
			child.queue_free()
			removed += 1
	return removed


func _attach_rigid(root: Node, visual: String, item: Dictionary) -> Dictionary:
	var skeleton := _find_skeleton(root)
	if skeleton == null:
		return {"ok": false, "reason": "squelette absent"}
	var bone_name := _equipment_bone(visual, item, str(ATTACHMENT_BONES[visual]))
	if skeleton.find_bone(bone_name) < 0:
		return {"ok": false, "reason": "os d'attache absent: %s" % bone_name}
	var resolved: Dictionary = tables.resolve_equipment_model(int(item.get("model", 0)), visual, appearance_id)
	if not bool(resolved.get("ok", false)):
		return {"ok": false, "reason": str(resolved.get("reason", "")), "model_id": int(item.get("model", 0))}
	var nif_relative := str(resolved.get("nif_relative", ""))
	if nif_relative == "":
		return {"ok": false, "reason": "objet sans NIF rigide", "model_id": int(item.get("model", 0))}
	var template: Node3D = _registry.get_model(nif_relative.get_file())
	if template == null:
		return {"ok": false, "reason": "NIF item non converti: %s" % nif_relative, "model_id": int(item.get("model", 0))}
	var instance := template.duplicate() as Node3D
	instance.name = "%sModel%d" % [visual.to_pascal_case(), int(item.get("model", 0))]
	WindingFixScript.apply(instance, true)  # P1-129 : objets equipes seulement
	_texture_untextured_surfaces(instance, nif_relative)
	var item_texture := str(resolved.get("item_texture_relative", ""))
	if item_texture != "":
		_override_textures(instance, item_texture)
	var attachment := BoneAttachment3D.new()
	attachment.name = "%sAttachment" % visual.to_pascal_case()
	attachment.bone_name = bone_name
	attachment.set_meta(META_EQUIPMENT_SLOT, visual)
	attachment.set_meta("daoc_model_id", int(item.get("model", 0)))
	attachment.set_meta("daoc_source_nif", nif_relative)
	skeleton.add_child(attachment)
	attachment.add_child(instance)
	return {"ok": true, "bone": bone_name, "nif_relative": nif_relative, "model_id": int(item.get("model", 0)),
		"label": str(resolved.get("label", "")), "item_texture": item_texture}


## Le materiau qui compte est celui que `apply_textures` a pose EN SURCHARGE
## sur l'instance ; le materiau du maillage est celui du convertisseur, sans
## texture. On lit donc la surcharge d'abord.
func _effective_material(mi: MeshInstance3D, surface_index: int) -> StandardMaterial3D:
	var override := mi.get_surface_override_material(surface_index) as StandardMaterial3D
	if override != null:
		return override
	return mi.mesh.surface_get_material(surface_index) as StandardMaterial3D


## Certains NIF d'items (casque albHelm01) ne nomment aucune texture sur leur
## forme mais en portent une comme NiSourceTexture ailleurs dans le fichier —
## le Lab retombe dessus, on fait pareil : sans cela le casque est blanc.
func _texture_untextured_surfaces(instance: Node, nif_relative: String) -> void:
	var untextured: Array = []
	for mesh_instance in instance.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh_instance as MeshInstance3D
		if mi.mesh == null:
			continue
		for surface_index in range(mi.mesh.get_surface_count()):
			var material := _effective_material(mi, surface_index)
			if material == null or material.albedo_texture == null:
				untextured.append([mi, surface_index])
	if untextured.is_empty():
		return
	var reader := NifReader.new()
	if not reader.read(client_root.path_join(nif_relative)) or reader.failed:
		return
	var texture: Texture2D = null
	var texture_name := ""
	for block_value in reader.blocks:
		var block := block_value as Dictionary
		if str(block.get("type", "")) != "NiSourceTexture":
			continue
		var file_name := str(block.get("file_name", ""))
		if file_name == "":
			continue
		texture = _registry.get_texture(file_name)
		if texture != null:
			texture_name = file_name
			break
	if texture == null:
		return
	for entry in untextured:
		var mi := entry[0] as MeshInstance3D
		var surface_index := int(entry[1])
		var base := _effective_material(mi, surface_index)
		var material := base.duplicate(false) as StandardMaterial3D if base != null else StandardMaterial3D.new()
		material.resource_name = texture_name
		material.albedo_texture = texture
		material.albedo_color = Color.WHITE
		material.roughness = 1.0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.set_surface_override_material(surface_index, material)


## `ApplyTexture` d'objects.csv : la meme epee existe en plusieurs finitions,
## la texture de l'objet remplace celle que le NIF nomme.
func _override_textures(instance: Node, texture_relative: String) -> void:
	var texture := _load_texture(texture_relative)
	if texture == null:
		return
	# P1-129 : les cartes PBR suivent la couleur. Le casque albHelm01 arrivait
	# avec celles de sa texture NIF (plaque : metal 1,0) sous une peau de cuir :
	# du metal pur sans reflet, donc NOIR.
	var maps: Dictionary = PbrUpgradeScript._resolve_maps(client_root, texture_relative)
	for mesh_instance in instance.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh_instance as MeshInstance3D
		if mi.mesh == null:
			continue
		for surface_index in range(mi.mesh.get_surface_count()):
			var base := _effective_material(mi, surface_index)
			var material := base.duplicate(false) as StandardMaterial3D if base != null else StandardMaterial3D.new()
			material.albedo_texture = texture
			material.albedo_color = Color.WHITE
			material.normal_enabled = maps.has("normal")
			material.normal_texture = maps.get("normal", null) as Texture2D
			material.roughness_texture = maps.get("roughness", null) as Texture2D
			if not maps.has("roughness"):
				material.roughness = 0.85
			material.ao_enabled = maps.has("ao")
			material.ao_texture = maps.get("ao", null) as Texture2D
			# Meme regle que l armure (`_apply_armor_texture`) : jamais de carte
			# metallic sur une peau d objet — celle du cuir rendait le casque noir.
			material.metallic_texture = null
			material.metallic = 0.0
			material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			mi.set_surface_override_material(surface_index, material)


## P1-128 — une scene PRE-CUITE par le Lab (online_<nom>.tscn, selection de
## personnage, apercus) porte TOUTES les armes possedees : le Friar montrait
## masse + baton dans la main droite et le bouclier a gauche. Sans rebatir la
## scene, cette fonction ne laisse visibles que les attaches du jeu d armes
## actif (meme regle que `apply`, pour toutes les classes et races). Les
## attaches sont MASQUEES, pas detruites : un changement d arme les rallume.
static func filter_baked_weapons(root: Node, active_weapon_slots: int) -> Dictionary:
	var result := {"shown": [], "hidden": [], "active_weapon_slots": active_weapon_slots}
	if root == null:
		return result
	var attachments: Dictionary = {}
	for visual in ["right_hand", "left_hand", "two_hand", "distance"]:
		var node := root.find_child("%sAttachment" % str(visual).to_pascal_case(), true, false) as Node3D
		if node != null:
			attachments[visual] = node
	var shown := active_weapon_visuals(attachments, active_weapon_slots)
	for visual in attachments.keys():
		var visible := shown.has(visual)
		(attachments[visual] as Node3D).visible = visible
		(result["shown" if visible else "hidden"] as Array).append(visual)
	return result


## Octet VisibleActiveWeaponSlots d un personnage de l overview (0xFD) :
## `active_weapon_right` | `active_weapon_left` << 4, -1 si inconnu.
static func active_weapon_slots_from_overview(character: Dictionary) -> int:
	var raw: Dictionary = character.get("raw", {}) as Dictionary
	var right: Variant = character.get("active_weapon_right", raw.get("active_weapon_right", null))
	var left: Variant = character.get("active_weapon_left", raw.get("active_weapon_left", null))
	if right == null or left == null:
		return -1
	return (int(right) & 0x0f) | ((int(left) & 0x0f) << 4)


## Les visuels d'arme a MONTRER, d'apres l'octet VisibleActiveWeaponSlots.
static func active_weapon_visuals(by_visual: Dictionary, active_weapon_slots: int) -> Array:
	const SLOT_VISUAL := {0: "right_hand", 1: "left_hand", 2: "two_hand", 3: "distance"}
	var shown: Array = []
	if active_weapon_slots >= 0:
		for nibble in [active_weapon_slots & 0x0f, (active_weapon_slots >> 4) & 0x0f]:
			if SLOT_VISUAL.has(nibble):
				var visual := str(SLOT_VISUAL[nibble])
				if by_visual.has(visual) and not shown.has(visual):
					shown.append(visual)
		return shown
	# Inconnu : regle du client d'origine par defaut.
	if by_visual.has("two_hand") and not by_visual.has("right_hand"):
		shown.append("two_hand")
	else:
		for visual in ["right_hand", "left_hand"]:
			if by_visual.has(visual):
				shown.append(visual)
	return shown


## P1-129 — les cheveux sous le casque. `items.csv` porte par NIF de casque la
## colonne « Helm Hair » (1, 2, 3, 5) : 1 = casque ouvert, les cheveux restent ;
## au-dela le client d origine retire la chevelure, sinon elle traverse le
## casque (« il ne fit pas avec la tete »). Sans casque, les cheveux reviennent.
func _apply_helm_hair(visual_roots: Array, by_visual: Dictionary, report: Dictionary) -> void:
	var mode := -1
	var hide := false
	if by_visual.has("head"):
		var resolved: Dictionary = tables.resolve_equipment_model(int((by_visual["head"] as Dictionary).get("model", 0)), "head", appearance_id)
		mode = int(resolved.get("helm_hair_mode", -1))
		# Un casque non resolu n est pas dessine : ne pas rendre la tete chauve.
		hide = bool(resolved.get("ok", false)) and mode != 1
	report["helm_hair_mode"] = mode
	report["hair_hidden"] = hide
	for root_value in visual_roots:
		var root := root_value as Node
		if root == null:
			continue
		var hair := root.find_child("Hair", true, false) as Node3D
		if hair != null:
			hair.visible = not hide


## P1-133 — pose sur chaque arme en main l'os de la main et l'os de rangement.
func _tag_sheath_bones(root: Node, two_handed_active: bool) -> void:
	var skeleton := _find_skeleton(root)
	if skeleton == null or tables == null:
		return
	for child in skeleton.get_children():
		var attachment := child as BoneAttachment3D
		if attachment == null or not attachment.has_meta(META_EQUIPMENT_SLOT):
			continue
		var slot := str(attachment.get_meta(META_EQUIPMENT_SLOT))
		if slot != "right_hand" and slot != "left_hand":
			continue
		if not attachment.has_meta(META_HAND_BONE):
			attachment.set_meta(META_HAND_BONE, attachment.bone_name if attachment.bone_name != "" else skeleton.get_bone_name(attachment.bone_idx))
		var hand_visual := "two_hand" if slot == "right_hand" and two_handed_active else slot
		var sheath_bone: String = tables.weapon_sheath_bone(int(attachment.get_meta("daoc_model_id", 0)), hand_visual)
		if sheath_bone != "" and skeleton.find_bone(sheath_bone) < 0:
			sheath_bone = ""
		attachment.set_meta(META_SHEATH_BONE, sheath_bone)


## P1-133 — degainer / rengainer : l'objet change d'os, rien d'autre. Les points
## Back/Belt du squelette DAoC sont orientes pour recevoir le meme NIF que la
## main, comme dans le moteur d'origine. Rend le nombre d'armes deplacees.
static func apply_sheath_state(root: Node, want_sheathed: bool) -> int:
	if root == null:
		return 0
	var skeletons: Array = root.find_children("*", "Skeleton3D", true, false)
	if root is Skeleton3D:
		skeletons.append(root)
	var moved := 0
	for skeleton_value in skeletons:
		var skeleton := skeleton_value as Skeleton3D
		for child in skeleton.get_children():
			var attachment := child as BoneAttachment3D
			if attachment == null or str(attachment.get_meta(META_SHEATH_BONE, "")) == "":
				continue
			var bone := str(attachment.get_meta(META_SHEATH_BONE)) if want_sheathed else str(attachment.get_meta(META_HAND_BONE, ""))
			var idx := skeleton.find_bone(bone)
			if idx < 0 or attachment.bone_idx == idx:
				continue
			attachment.bone_name = bone
			attachment.bone_idx = idx
			moved += 1
	return moved


static func _find_skeleton_static(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton_static(child)
		if found != null:
			return found
	return null


## L'etat vient de la garde du visuel qui porte cette racine (set_combat_stance) ;
## sans visuel (apercu de selection), `sheathed`.
func _sheathed_for(root: Node) -> bool:
	var node: Node = root
	for _i in 4:
		if node == null:
			break
		if node.has_method("set_combat_stance"):
			return not bool(node.get("combat_stance"))
		node = node.get_parent()
	return sheathed


## P1-133 — les quatre cartes de `generate_pbr_maps.py` posees a cote du PNG
## (`_normal`, `_roughness`, `_metallic`, `_ao`). Avant : le metal etait FORCE a
## zero et l'AO ignoree, donc une plaque se rendait comme du cuir mat ; et le
## chemin catalogue (36 races) n'en posait aucune. Absentes : on retire tout.
func _apply_pbr_maps(material: StandardMaterial3D, maps: Dictionary) -> void:
	if maps.has("normal"):
		material.normal_enabled = true
		material.normal_texture = maps["normal"] as Texture2D
	else:
		material.normal_enabled = false
		material.normal_texture = null
	if maps.has("roughness"):
		material.roughness = 1.0
		material.roughness_texture = maps["roughness"] as Texture2D
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	else:
		material.roughness_texture = null
		material.roughness = 0.85
	if maps.has("metallic"):
		material.metallic = 1.0
		material.metallic_specular = 0.5
		material.metallic_texture = maps["metallic"] as Texture2D
		material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	else:
		material.metallic_texture = null
		material.metallic = 0.0
	if maps.has("ao"):
		material.ao_enabled = true
		material.ao_texture = maps["ao"] as Texture2D
		material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		material.ao_light_affect = 0.35
	else:
		material.ao_enabled = false
		material.ao_texture = null


func _equipment_bone(visual: String, item: Dictionary, fallback: String) -> String:
	if visual != "left_hand":
		return fallback
	var bone: String = tables.weapon_hand_bone(int(item.get("model", 0)), visual)
	if bone != "":
		return bone
	# Le type 42 est Shield dans eObjectType, si la table client manque.
	if item.has("object_type"):
		return "Bip01 L Shield" if int(item["object_type"]) == 42 else "Bip01 L Held"
	return fallback
