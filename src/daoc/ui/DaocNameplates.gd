extends Node
class_name DaocNameplates

## Les noms au-dessus des tetes, comme le client d'origine : nom, puis
## « <Guilde> » en dessous, lisibles a taille constante a l'ecran.
##
## Les categories reprennent /shownames et /hidenames de game.dll
## (eden.dll.c, FUN autour de la ligne 76330) : self, players, monsters,
## graves, enemies, group, guild, all. Ici self / players / monsters sont
## effectives ; les autres sont acceptees et memorisees.
## Les choix vivent dans user://daoc_options.cfg, section [names].

const CONFIG_PATH := "user://daoc_options.cfg"
const CATEGORIES := ["self", "players", "monsters", "graves", "enemies", "group", "guild"]
const PLATE_NAME := "Nameplate"
const REFRESH_SECONDS := 0.25

## Racine de la population (les enveloppes Entity_<oid>_Model_<id>).
var population_root: Node = null
## Noeud du joueur local et son identite.
var local_player: Node3D = null
var local_name := ""
var local_guild := ""
## Au-dela, le nom disparait (unites Godot = unites DAoC a world_scale 1).
var max_distance := 3500.0
var show := {"self": true, "players": true, "monsters": true, "graves": true, "enemies": true, "group": true, "guild": true}

var _accum := 0.0


func _ready() -> void:
	add_to_group("daoc_nameplates")
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	for key in CATEGORIES:
		show[key] = bool(cfg.get_value("names", key, show[key]))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	for key in CATEGORIES:
		cfg.set_value("names", key, bool(show[key]))
	cfg.save(CONFIG_PATH)


## /shownames et /hidenames. Rend la ligne a afficher dans la console.
func handle_command(command: String) -> String:
	var parts := command.strip_edges().to_lower().split(" ", false)
	if parts.is_empty():
		return ""
	var visible := parts[0] == "/shownames"
	if parts.size() == 1:
		return "Use: %s [players] [monsters] [graves] [self] [enemies] [group] [guild] [all]" % parts[0]
	var changed: Array = []
	for index in range(1, parts.size()):
		var word := parts[index]
		if word == "all":
			for key in CATEGORIES:
				show[key] = visible
			changed = ["all"]
			break
		if word in CATEGORIES:
			show[word] = visible
			changed.append(word)
	if changed.is_empty():
		return "Use: %s [players] [monsters] [graves] [self] [enemies] [group] [guild] [all]" % parts[0]
	save_settings()
	refresh()
	return "Names %s: %s" % ["shown" if visible else "hidden", ", ".join(changed)]


func set_category(key: String, visible: bool) -> void:
	if key in CATEGORIES:
		show[key] = visible
		save_settings()
		refresh()


func _process(delta: float) -> void:
	_accum += delta
	if _accum < REFRESH_SECONDS:
		return
	_accum = 0.0
	refresh()


func refresh() -> void:
	if population_root != null and is_instance_valid(population_root):
		for child in population_root.get_children():
			var wrapper := child as Node3D
			if wrapper == null or not wrapper.has_meta("daoc_entity_type"):
				continue
			var kind := str(wrapper.get_meta("daoc_entity_type"))
			var category := "players" if kind == "player" else ("monsters" if kind == "npc" else "")
			if category == "":
				continue
			_sync_plate(wrapper, str(wrapper.get_meta("daoc_entity_name", "")),
				str(wrapper.get_meta("daoc_entity_guild", "")), bool(show[category]),
				Color(1.0, 1.0, 1.0) if kind == "player" else Color(0.55, 0.87, 0.86))
	if local_player != null and is_instance_valid(local_player):
		_sync_plate(local_player, local_name, local_guild, bool(show["self"]), Color(1.0, 1.0, 1.0))


func _sync_plate(owner_node: Node3D, entity_name: String, guild: String, visible: bool, color: Color) -> void:
	var plate := owner_node.get_node_or_null(PLATE_NAME) as Label3D
	if entity_name.strip_edges() == "" or not visible:
		if plate != null:
			plate.visible = false
		return
	if plate == null:
		plate = _make_plate()
		owner_node.add_child(plate)
	var text := entity_name if guild.strip_edges() == "" else "%s\n<%s>" % [entity_name, guild]
	if plate.text != text:
		plate.text = text
	plate.modulate = color
	plate.position = Vector3(0.0, _head_height(owner_node), 0.0)
	plate.visibility_range_end = max_distance
	plate.visible = true


func _make_plate() -> Label3D:
	var plate := Label3D.new()
	plate.name = PLATE_NAME
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.fixed_size = true
	plate.pixel_size = 0.0011
	plate.font_size = 22
	plate.outline_size = 6
	plate.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	plate.line_spacing = -2.0
	plate.no_depth_test = false
	plate.shaded = false
	plate.double_sided = true
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Times New Roman", "Georgia", "serif"])
	plate.font = font
	return plate


## Sommet du modele dans le repere de l'enveloppe, mis en cache (un modele ne
## grandit qu'au 0xDB, qui rescale Visual : le cache suit son echelle).
func _head_height(owner_node: Node3D) -> float:
	var visual := owner_node.get_node_or_null("Visual") as Node3D
	var scale_key := visual.scale.y if visual != null else 1.0
	if owner_node.has_meta("daoc_nameplate_height") and is_equal_approx(float(owner_node.get_meta("daoc_nameplate_scale_key", -1.0)), scale_key):
		return float(owner_node.get_meta("daoc_nameplate_height"))
	var top := -INF
	for mesh_value in owner_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_value as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
			continue
		var aabb := mesh_instance.mesh.get_aabb()
		var to_owner := _transform_to(mesh_instance, owner_node)
		for corner in 8:
			var point := to_owner * (aabb.position + Vector3(
				aabb.size.x if corner & 1 else 0.0,
				aabb.size.y if corner & 2 else 0.0,
				aabb.size.z if corner & 4 else 0.0))
			top = maxf(top, point.y)
	var height := (top + 12.0) if top > 0.0 and top < 2000.0 else 110.0
	owner_node.set_meta("daoc_nameplate_height", height)
	owner_node.set_meta("daoc_nameplate_scale_key", scale_key)
	return height


func _transform_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := node.transform
	var current := node.get_parent()
	while current != null and current != ancestor:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result
