extends CanvasLayer
class_name DaocOnlineLoginWindow

## 2026-09-29 — la fenêtre de connexion Online, dans l'esprit du portail du
## client d'origine : une liste de serveurs (ajout possible), un champ compte et
## un champ mot de passe. Les serveurs intégrés (OpenDAoC, DOL local) sont
## toujours là ; si le profil privé (.env.local.json) porte les identifiants du
## serveur sélectionné, les deux champs sont préremplis.
##
## Rien n'est décidé ici : la fenêtre émet un profil vers le frontend, qui garde
## la main sur la connexion réelle. Le mot de passe n'est jamais journalisé.

signal connect_requested(profile: Dictionary)
signal cancelled

const SessionConfig := preload("res://src/daoc/network/opendaoc/DaocOnlineSessionConfig.gd")

## Combien de temps une tentative de connexion TCP a pour aboutir avant que le
## serveur soit déclaré hors ligne. Un simple connect/déconnexion, jamais de
## paquet de login : c'est une sonde d'accessibilité, pas une session.
const PROBE_TIMEOUT_SEC := 2.5

## Emplacement du serveur DOL local. Le bouton « Démarrer le serveur DOL »
## lance `dotnet DOLServer.dll` DIRECTEMENT (pas le .bat, qu'ESET bloque), dans
## une console à part ouverte par Godot.
## Chemin optionnel fourni par l'utilisateur. Le paquet public ne contient ni
## serveur, ni chemin propre à la machine de l'auteur.
static var DOL_SERVER_DLL := OS.get_environment("DOL_SERVER_DLL").strip_edges()

var _config: DaocOnlineSessionConfig = SessionConfig.new()
var _catalog: Array = []
var _selected_index := -1

var _probes: Array = []
var _dot_probing: Texture2D = null
var _dot_online: Texture2D = null
var _dot_offline: Texture2D = null

var _root: ColorRect = null
var _server_list: ItemList = null
var _account_edit: LineEdit = null
var _password_edit: LineEdit = null
var _character_edit: LineEdit = null
var _status: Label = null
var _add_panel: PanelContainer = null
var _new_name: LineEdit = null
var _new_host: LineEdit = null
var _new_port: LineEdit = null


func _ready() -> void:
	# Le frontend vit sur la couche 100 ; la fenêtre passe au-dessus.
	layer = 105
	_dot_probing = _make_dot(Color(0.65, 0.62, 0.35))
	_dot_online = _make_dot(Color(0.25, 0.85, 0.35))
	_dot_offline = _make_dot(Color(0.85, 0.25, 0.22))
	_build()
	refresh_catalog()


## Petit disque plein utilisé comme pastille d'état devant chaque serveur.
func _make_dot(color: Color) -> Texture2D:
	var size := 14
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := (size - 1) * 0.5
	var radius := center - 1.5
	for y in size:
		for x in size:
			var d := Vector2(x - center, y - center).length()
			if d <= radius:
				image.set_pixel(x, y, color)
			elif d <= radius + 1.0:
				# Bord adouci pour ne pas crénéler la pastille.
				image.set_pixel(x, y, Color(color.r, color.g, color.b, radius + 1.0 - d))
	return ImageTexture.create_from_image(image)


func _build() -> void:
	_root = ColorRect.new()
	_root.name = "OnlineLoginBackdrop"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.color = Color(0.01, 0.015, 0.03, 0.72)
	add_child(_root)

	var panel := PanelContainer.new()
	panel.name = "OnlineLoginWindow"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-320, -215)
	panel.custom_minimum_size = Vector2(640, 430)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.09, 0.97)
	style.border_color = Color(0.75, 0.65, 0.4)
	style.set_border_width_all(1)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	panel.add_child(outer)

	var title := Label.new()
	title.text = "Connexion à un serveur"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
	outer.add_child(title)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(columns)

	# Colonne gauche : la liste des serveurs.
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	var left_label := Label.new()
	left_label.text = "Serveurs"
	left.add_child(left_label)
	_server_list = ItemList.new()
	_server_list.custom_minimum_size = Vector2(0, 250)
	_server_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_server_list.item_selected.connect(_on_server_selected)
	left.add_child(_server_list)
	var list_buttons := HBoxContainer.new()
	list_buttons.add_theme_constant_override("separation", 8)
	left.add_child(list_buttons)
	var add_button := Button.new()
	add_button.text = "Ajouter un serveur…"
	add_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_button.pressed.connect(_toggle_add_panel)
	list_buttons.add_child(add_button)
	var refresh_button := Button.new()
	refresh_button.text = "Actualiser l'état"
	refresh_button.pressed.connect(_start_probes)
	list_buttons.add_child(refresh_button)

	var launch_button := Button.new()
	launch_button.text = "Démarrer le serveur DOL local"
	launch_button.tooltip_text = "Lance dotnet DOLServer.dll dans une console (sans passer par le .bat)"
	launch_button.pressed.connect(_on_launch_dol_pressed)
	left.add_child(launch_button)

	# Colonne droite : les identifiants.
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)
	right.add_child(_make_field_label("Compte"))
	_account_edit = LineEdit.new()
	_account_edit.placeholder_text = "nom de compte"
	right.add_child(_account_edit)
	right.add_child(_make_field_label("Mot de passe"))
	_password_edit = LineEdit.new()
	_password_edit.secret = true
	_password_edit.placeholder_text = "mot de passe"
	right.add_child(_password_edit)
	right.add_child(_make_field_label("Personnage (optionnel)"))
	_character_edit = LineEdit.new()
	_character_edit.placeholder_text = "nom du personnage"
	right.add_child(_character_edit)

	_add_panel = _build_add_panel()
	_add_panel.visible = false
	outer.add_child(_add_panel)

	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(0.95, 0.75, 0.55))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(_status)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	outer.add_child(buttons)
	var cancel := Button.new()
	cancel.text = "Retour"
	cancel.custom_minimum_size = Vector2(120, 40)
	cancel.pressed.connect(func() -> void: cancelled.emit())
	buttons.add_child(cancel)
	var connect_button := Button.new()
	connect_button.text = "Se connecter"
	connect_button.custom_minimum_size = Vector2(160, 40)
	connect_button.pressed.connect(_on_connect_pressed)
	buttons.add_child(connect_button)


func _make_field_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.82, 0.82, 0.88))
	return label


func _build_add_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.13, 0.95)
	style.border_color = Color(0.5, 0.5, 0.6)
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	_new_name = LineEdit.new()
	_new_name.placeholder_text = "Nom"
	_new_name.custom_minimum_size = Vector2(150, 0)
	row.add_child(_new_name)
	_new_host = LineEdit.new()
	_new_host.placeholder_text = "Adresse IP / hôte"
	_new_host.custom_minimum_size = Vector2(180, 0)
	row.add_child(_new_host)
	_new_port = LineEdit.new()
	_new_port.placeholder_text = "Port"
	_new_port.text = "10300"
	_new_port.custom_minimum_size = Vector2(70, 0)
	row.add_child(_new_port)
	var confirm := Button.new()
	confirm.text = "OK"
	confirm.pressed.connect(_on_add_confirmed)
	row.add_child(confirm)
	return panel


func _toggle_add_panel() -> void:
	_add_panel.visible = not _add_panel.visible


func _on_add_confirmed() -> void:
	var host := _new_host.text.strip_edges()
	var port := int(_new_port.text.strip_edges())
	var name := _new_name.text.strip_edges()
	if host == "" or port < 1 or port > 65535:
		_status.text = "Adresse ou port invalide."
		return
	if not _config.save_user_server(name, host, port):
		_status.text = "Impossible d'enregistrer le serveur."
		return
	_new_name.text = ""
	_new_host.text = ""
	_new_port.text = "10300"
	_add_panel.visible = false
	_status.text = "Serveur ajouté."
	var key := SessionConfig.server_key(host, port)
	refresh_catalog()
	for i in _catalog.size():
		if SessionConfig.server_key(str(_catalog[i].get("host", "")), int(_catalog[i].get("port", 0))) == key:
			_server_list.select(i)
			_on_server_selected(i)
			break


func refresh_catalog() -> void:
	_catalog = _config.load_server_catalog()
	_server_list.clear()
	for i in _catalog.size():
		var entry: Dictionary = _catalog[i]
		var label := "%s  —  %s:%d" % [str(entry.get("name", "")), str(entry.get("host", "")), int(entry.get("port", 0))]
		if bool(entry.get("has_credentials", false)):
			label += "  ✔"
		_server_list.add_item(label, _dot_probing)
	_start_probes()
	if _catalog.is_empty():
		_status.text = "Aucun serveur configuré."
		return
	var target := 0
	# Ouvre sur le premier serveur dont les identifiants sont connus.
	for i in _catalog.size():
		if bool(_catalog[i].get("has_credentials", false)):
			target = i
			break
	_server_list.select(target)
	_on_server_selected(target)


## Lance une sonde TCP par serveur. On ne se contente pas de « connexion en
## cours » : chaque sonde poursuit son polling dans `_process` jusqu'à réussite
## ou expiration, puis repeint la pastille.
func _start_probes() -> void:
	_close_probes()
	for i in _catalog.size():
		var entry: Dictionary = _catalog[i]
		if i < _server_list.item_count:
			_server_list.set_item_icon(i, _dot_probing)
		var peer := StreamPeerTCP.new()
		var err := peer.connect_to_host(str(entry.get("host", "")), int(entry.get("port", 0)))
		if err != OK:
			_server_list.set_item_icon(i, _dot_offline)
			continue
		_probes.append({"peer": peer, "index": i, "deadline": Time.get_ticks_msec() + int(PROBE_TIMEOUT_SEC * 1000.0)})
	set_process(not _probes.is_empty())


func _close_probes() -> void:
	for probe in _probes:
		var peer := probe.get("peer") as StreamPeerTCP
		if peer != null:
			peer.disconnect_from_host()
	_probes.clear()
	set_process(false)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var still_active: Array = []
	for probe in _probes:
		var peer := probe.get("peer") as StreamPeerTCP
		var index := int(probe.get("index", -1))
		if peer == null or index < 0 or index >= _server_list.item_count:
			continue
		peer.poll()
		var status := peer.get_status()
		if status == StreamPeerTCP.STATUS_CONNECTED:
			_server_list.set_item_icon(index, _dot_online)
			peer.disconnect_from_host()
		elif status == StreamPeerTCP.STATUS_ERROR or now >= int(probe.get("deadline", 0)):
			_server_list.set_item_icon(index, _dot_offline)
			peer.disconnect_from_host()
		else:
			still_active.append(probe)
	_probes = still_active
	if _probes.is_empty():
		set_process(false)


func _on_server_selected(index: int) -> void:
	if index < 0 or index >= _catalog.size():
		return
	_selected_index = index
	var entry: Dictionary = _catalog[index]
	_account_edit.text = str(entry.get("account", ""))
	_password_edit.text = str(entry.get("password", ""))
	_character_edit.text = str(entry.get("character", ""))
	if bool(entry.get("has_credentials", false)):
		_status.text = "Identifiants préremplis depuis le profil privé."
	else:
		_status.text = "Saisis le compte et le mot de passe pour ce serveur."


func _on_connect_pressed() -> void:
	if _selected_index < 0 or _selected_index >= _catalog.size():
		_status.text = "Choisis un serveur."
		return
	var entry: Dictionary = _catalog[_selected_index]
	var profile := _config.profile_from_inputs(
		str(entry.get("host", "")), int(entry.get("port", 0)),
		_account_edit.text.strip_edges(), _password_edit.text,
		_character_edit.text.strip_edges())
	if not bool(profile.get("ok", false)):
		_status.text = "Connexion impossible : %s" % str(profile.get("reason", "profil invalide"))
		return
	connect_requested.emit(profile)


## Lance le serveur DOL local via une console Godot, puis re-sonde l'état pour
## que la pastille passe au vert dès qu'il écoute.
func _on_launch_dol_pressed() -> void:
	if not FileAccess.file_exists(DOL_SERVER_DLL):
		_status.text = "DOLServer.dll introuvable : %s" % DOL_SERVER_DLL
		return
	var dir := DOL_SERVER_DLL.get_base_dir().replace("/", "\\")
	# cmd /k : la fenêtre reste ouverte pour lire les logs même si le serveur
	# s'arrête. `open_console = true` fait ouvrir la console par Godot lui-même,
	# donc c'est Godot qui lance dotnet, pas le .bat surveillé par ESET.
	var command := "cd /d \"%s\" && dotnet DOLServer.dll" % dir
	var pid := OS.create_process("cmd.exe", ["/k", command], true)
	if pid <= 0:
		# Repli sans console dédiée si l'ouverture de console échoue.
		pid = OS.create_process("cmd.exe", ["/k", command])
	if pid <= 0:
		_status.text = "Échec du lancement du serveur DOL."
		return
	_status.text = "Serveur DOL en cours de démarrage… (~30 s) puis « Actualiser l'état »."
	_relaunch_probe_later()


func _relaunch_probe_later() -> void:
	# Le serveur met ~25-35 s à écouter (chargement des régions). On re-sonde
	# trois fois, toutes les 12 s, pour attraper le passage en ligne sans action
	# manuelle.
	for _i in 3:
		await get_tree().create_timer(12.0).timeout
		if not visible:
			return
		_start_probes()


func show_window() -> void:
	visible = true
	refresh_catalog()


func hide_window() -> void:
	_close_probes()
	visible = false


func _exit_tree() -> void:
	_close_probes()
