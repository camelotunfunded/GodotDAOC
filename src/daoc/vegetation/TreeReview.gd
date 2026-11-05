extends Node3D
## Standalone offline review. Never loads ZoneViewer, skybox or network code.

const Batches = preload("res://src/daoc/vegetation/DaocSpeedTreeBatches.gd")
var rows: Array = []
var client := ""
var registry := DaocAssetIndexRegistry.new()
var models: Node3D
var camera: Camera3D
var selection: OptionButton
var units: SpinBox
var notes: Label
var headings: Array[Label] = []
var target := Vector3.ZERO
var distance := 40.0
var angle := 0.0

func _ready() -> void:
	client = OS.get_environment("DAOC_CLIENT_ROOT").replace("\\", "/")
	if client.is_empty():
		client = ProjectSettings.globalize_path("res://../../Dark Age of Camelot")
	registry.configure({"daoc_client_root": client, "prop_detail_layer_enabled": true, "extra_texture_dirs": [client.path_join("zones/Dnifs"), client.path_join("Newtowns/zones/Nifs")]})
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("272e37")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -35, 0)
	add_child(light)
	camera = Camera3D.new()
	camera.fov = 42
	camera.far = 10000
	add_child(camera)
	camera.make_current()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := VBoxContainer.new()
	panel.position = Vector2(18, 14)
	canvas.add_child(panel)
	var title := Label.new()
	title.text = "ARBRES DAoC — comparaison hors ligne"
	title.add_theme_font_size_override("font_size", 22)
	panel.add_child(title)
	var controls := HBoxContainer.new()
	panel.add_child(controls)
	selection = OptionButton.new()
	selection.custom_minimum_size.x = 510
	controls.add_child(selection)
	var scale_label := Label.new()
	scale_label.text = "Taille SpeedTree (à valider) : "
	controls.add_child(scale_label)
	units = SpinBox.new()
	units.min_value = 1
	units.max_value = 30
	units.step = 0.5
	units.value = 12
	controls.add_child(units)
	var turn := Button.new()
	turn.text = "Tourner de 90°"
	turn.pressed.connect(func(): angle += PI / 2; _camera())
	controls.add_child(turn)
	notes = Label.new()
	panel.add_child(notes)
	var columns := HBoxContainer.new()
	columns.position = Vector2(18, 120)
	columns.size.x = get_viewport().get_visible_rect().size.x - 36
	canvas.add_child(columns)
	for i in 3:
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		columns.add_child(label)
		headings.append(label)
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/trees/nif/manifest.json"))
	for row in document.rows:
		if row.get("status") == "READY_FOR_VISUAL_REVIEW":
			selection.add_item(row.path)
			rows.append(row)
	var selected := 0
	for i in rows.size():
		if str(rows[i].path).to_lower() == "zones/nifs/elm1/elm1.nif":
			selected = i
	selection.select(selected)
	selection.item_selected.connect(_show_model)
	units.value_changed.connect(func(_value): _show_model(selection.selected))
	_show_model(selected)

func _show_model(index: int) -> void:
	if models != null:
		remove_child(models)
		models.queue_free()
	models = Node3D.new()
	add_child(models)
	var row: Dictionary = rows[index]
	var token := str(row.path).get_file().get_basename()
	var abs_path := client.path_join(row.path)
	var original: Node3D = registry._model_cache.get(abs_path) if registry._model_cache.has(abs_path) else registry._get_model_nif(abs_path, token)
	var native := original.duplicate() as Node3D if original != null else Node3D.new()
	var cooked: Node3D = load(row.scene).instantiate()
	var modern := Node3D.new()
	var batches := Batches.new()
	batches.configure(client, {"world_scale": 0.01, "speedtree_units_to_daoc": units.value})
	var replaced := batches.try_add({"file": token + ".nif", "fixture_id": 0, "transform": Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.01), Vector3.ZERO)})
	if replaced:
		batches.finish(modern)
	else:
		modern.free()
		modern = cooked.duplicate()
		modern.scale = Vector3.ONE * 0.01
	native.scale = Vector3.ONE * 0.01
	cooked.scale = Vector3.ONE * 0.01
	var entries: Array[Node3D] = [native, cooked, modern]
	var boxes: Array[AABB] = []
	var width := 1.0
	var height := 1.0
	for entry in entries:
		models.add_child(entry)
		var bb := _bounds(entry)
		boxes.append(bb)
		width = maxf(width, maxf(bb.size.x, bb.size.z))
		height = maxf(height, bb.end.y)
	var labels := ["NIF actuel" if original != null else "NIF actuel : lecture impossible", "NIF corrigé", "SpeedTree" if replaced else "NIF conservé (sans substitution)"]
	for i in 3:
		entries[i].position.x += (i - 1) * width * 1.2 - boxes[i].get_center().x
		headings[i].text = "%s\nHauteur : %.0f unités DAoC" % [labels[i], boxes[i].size.y * 100]
	target = Vector3(0, height * 0.45, 0)
	distance = maxf(height * 2.2, width * 3.0)
	_camera()
	notes.text = "%d NIF disponibles • Même échelle et même sol • Le réglage de taille ne modifie pas le client" % rows.size()

func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "GeometryInstance3D", true, false):
		var current := AABB()
		if mi is MeshInstance3D:
			current = mi.global_transform * mi.mesh.get_aabb()
		elif mi is MultiMeshInstance3D:
			current = mi.global_transform * mi.multimesh.get_aabb()
		else:
			continue
		box = current if first else box.merge(current)
		first = false
	return box

func _camera() -> void:
	camera.position = target + Vector3(sin(angle), 0.13, cos(angle)) * distance
	camera.look_at(target)

func _exit_tree() -> void:
	registry.clear_runtime_caches()
