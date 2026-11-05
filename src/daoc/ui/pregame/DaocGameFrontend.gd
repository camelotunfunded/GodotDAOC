extends CanvasLayer
class_name DaocGameFrontend

const PregameScene := preload("res://scenes/ui/pregame/DaocPregameFlow.tscn")
const OnlineSessionConfig := preload("res://src/daoc/network/opendaoc/DaocOnlineSessionConfig.gd")
const OnlineRuntimeScript := preload("res://src/daoc/network/opendaoc/DaocOnlineRuntime.gd")
const V2_SHOWCASE_SCENE := "res://v2/V2Showcase.tscn"
const RosterScript := preload("res://src/daoc/ui/pregame/DaocPlayableRoster.gd")
const LoadingTexture := preload("res://assets/placeholders/loading.svg")
const LOADING_VIDEO_PATH := "res://assets/daoc/ui/loading/loading.ogv"
const LOADING_MUSIC_BASENAME := "loading"
const EXTERNAL_SPLASH_DIR := "pregame/splash"

var mode := ""
var selected_realm := 1
var _mode_panel: Control
var _mode_background: TextureRect
var _loading_panel: Control
var _loading_image: TextureRect
var _loading_video: VideoStreamPlayer
var _loading_label: Label
var _loading_progress: ProgressBar
var _loading_footer: Control
var _loading_music: AudioStreamPlayer
var _completion_video_started := false
var _flow: DaocPregameFlowController
var online_profile: Dictionary = {}
var _online_runtime: Node = null
var _pending_online_character: Dictionary = {}
var _pending_online_slot := -1
var _online_world_position: Dictionary = {}
var _has_server_playing_signal := false


func _ready() -> void:
	layer = 100
	_build_mode_panel()
	_build_loading_panel()
	if _flow == null:
		_flow = PregameScene.instantiate() as DaocPregameFlowController
	_flow.visible = false
	_flow.realm_confirmed.connect(_on_realm_confirmed)
	_flow.play_requested.connect(_on_play_requested)
	_flow.create_requested.connect(_on_create_requested)
	# 2026-09-27 : le bouton Options ouvre les options graphiques (memorisees).
	if _flow.has_signal("options_requested"):
		_flow.options_requested.connect(_open_graphics_options)
	if _flow.get_parent() == null:
		add_child(_flow)
	if _online_runtime == null:
		_online_runtime = OnlineRuntimeScript.new()
		_online_runtime.name = "OnlineRuntime"
	if _online_runtime.get_parent() == null:
		add_child(_online_runtime)
	_wire_online_runtime()
	_resume_after_quit_if_requested()


func _build_mode_panel() -> void:
	_mode_panel = ColorRect.new()
	_mode_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mode_panel.color = Color(0.015, 0.02, 0.035, 1.0)
	add_child(_mode_panel)
	_mode_background = TextureRect.new()
	_mode_background.name = "RandomSplashBackground"
	_mode_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mode_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mode_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_mode_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mode_background.modulate = Color(0.72, 0.72, 0.72, 1.0)
	_mode_panel.add_child(_mode_background)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-180, -105)
	box.custom_minimum_size = Vector2(360, 210)
	box.add_theme_constant_override("separation", 16)
	_mode_panel.add_child(box)
	var title := Label.new()
	title.text = "DARK AGE OF CAMELOT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Choisissez le mode de jeu"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	# V2 : la zone vitrine 2026 (res://v2), une scene Godot en metres, sans reseau.
	for entry in [["OFFLINE", "Monde local"], ["ONLINE", "Online"], ["V2", "V2 — zone vitrine 2026"]]:
		var button := Button.new()
		button.text = str(entry[1])
		button.custom_minimum_size.y = 52
		button.pressed.connect(_select_mode.bind(str(entry[0])))
		box.add_child(button)


func _build_loading_panel() -> void:
	_loading_panel = ColorRect.new()
	_loading_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_panel.color = Color(0.01, 0.015, 0.03, 1.0)
	_loading_panel.visible = false
	add_child(_loading_panel)
	_loading_image = TextureRect.new()
	_loading_image.name = "LoadingArtwork"
	_loading_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_image.texture = LoadingTexture
	_loading_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_loading_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_loading_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_panel.add_child(_loading_image)
	_apply_random_external_splash()
	_loading_video = VideoStreamPlayer.new()
	_loading_video.name = "LoadingCompletionVideo"
	_loading_video.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Le decodeur video n'est pas initialise pendant les tests sans affichage.
	if DisplayServer.get_name() != "headless":
		_loading_video.stream = load(LOADING_VIDEO_PATH) as VideoStream
	_loading_video.expand = true
	_loading_video.loop = false
	_loading_video.visible = false
	_loading_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_panel.add_child(_loading_video)
	var footer := ColorRect.new()
	footer.name = "LoadingFooter"
	footer.anchor_left = 0.18
	footer.anchor_right = 0.82
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.offset_top = -150.0
	footer.offset_bottom = -28.0
	footer.color = Color(0.0, 0.0, 0.0, 0.78)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_panel.add_child(footer)
	_loading_footer = footer
	_loading_label = Label.new()
	_loading_label.anchor_right = 1.0
	_loading_label.offset_left = 24.0
	_loading_label.offset_top = 14.0
	_loading_label.offset_right = -24.0
	_loading_label.offset_bottom = 64.0
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.add_theme_font_size_override("font_size", 20)
	_loading_label.add_theme_color_override("font_color", Color(0.94, 0.94, 0.94))
	_loading_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_loading_label.add_theme_constant_override("shadow_offset_x", 2)
	_loading_label.add_theme_constant_override("shadow_offset_y", 2)
	footer.add_child(_loading_label)
	_loading_progress = ProgressBar.new()
	_loading_progress.name = "LoadingProgress"
	_loading_progress.anchor_left = 0.06
	_loading_progress.anchor_right = 0.94
	_loading_progress.anchor_top = 1.0
	_loading_progress.anchor_bottom = 1.0
	_loading_progress.offset_top = -47.0
	_loading_progress.offset_bottom = -17.0
	_loading_progress.min_value = 0.0
	_loading_progress.max_value = 100.0
	_loading_progress.show_percentage = true
	var progress_background := StyleBoxFlat.new()
	progress_background.bg_color = Color(0.04, 0.04, 0.05, 0.95)
	progress_background.border_color = Color(0.55, 0.58, 0.62, 1.0)
	progress_background.set_border_width_all(1)
	progress_background.set_corner_radius_all(5)
	_loading_progress.add_theme_stylebox_override("background", progress_background)
	var progress_fill := StyleBoxFlat.new()
	progress_fill.bg_color = Color(0.72, 0.08, 0.06, 1.0)
	progress_fill.set_corner_radius_all(4)
	_loading_progress.add_theme_stylebox_override("fill", progress_fill)
	footer.add_child(_loading_progress)
	# 2026-09-30 : l'entrée dans le monde prend l'écran d'origine (bannière de
	# région de loading.dat), posé par-dessus le reste du panneau.
	_original_loading = preload("res://src/daoc/ui/pregame/DaocOriginalLoadingScreen.gd").new()
	_original_loading.name = "OriginalLoadingScreen"
	_original_loading.visible = false
	_loading_panel.add_child(_original_loading)
	_loading_music = AudioStreamPlayer.new()
	_loading_music.name = "LoadingMusic"
	add_child(_loading_music)
	_load_optional_loading_music()


func _show_loading(text: String, progress: float) -> void:
	_loading_panel.visible = true
	if progress < 100.0 and not _completion_video_started:
		_loading_image.visible = true
		_loading_video.visible = false
		_loading_footer.visible = true
	_loading_label.text = text
	_loading_progress.value = clampf(progress, 0.0, 100.0)
	if _original_loading != null and _original_loading.visible:
		_original_loading.set_status(text, progress)
		return
	if _loading_music.stream != null and not _loading_music.playing:
		_loading_music.play()


var _original_loading: DaocOriginalLoadingScreen = null


## Bannière de la région d'arrivée (0x88), comme le client d'origine.
func _begin_original_world_loading() -> void:
	if _original_loading == null:
		return
	var game := get_parent()
	var root := str(game.get("daoc_client_root")) if game != null else ""
	var region := int(_online_world_position.get("region_id", _pending_online_character.get("region_id", -1)))
	var chosen := _original_loading.prepare_for_region(root, region)
	print("ORIGINAL_LOADING=%s" % JSON.stringify(chosen))
	_original_loading.visible = true


func _hide_loading() -> void:
	if _original_loading != null:
		_original_loading.visible = false
	_loading_video.stop()
	_loading_music.stop()
	_loading_panel.visible = false
	_loading_image.visible = true
	_loading_video.visible = false
	_loading_footer.visible = true
	_completion_video_started = false


func _finish_loading_with_video() -> void:
	if _completion_video_started:
		return
	_completion_video_started = true
	_show_loading("Monde prêt", 100.0)
	# L'écran d'origine n'a pas de vidéo de fin : il disparaît, c'est tout.
	if _loading_video.stream == null or (_original_loading != null and _original_loading.visible):
		await get_tree().process_frame
		_hide_loading()
		return
	_loading_image.visible = false
	_loading_footer.visible = false
	_loading_video.visible = true
	_loading_video.play()
	# L'entree en jeu reste masquee jusqu'a la derniere image de la video.
	await _loading_video.finished
	_hide_loading()


func _load_optional_loading_music() -> void:
	var artwork_dir := ProjectSettings.globalize_path("res://../artwork")
	for extension in ["mp3", "wav"]:
		var path := artwork_dir.path_join("%s.%s" % [LOADING_MUSIC_BASENAME, extension])
		if not FileAccess.file_exists(path):
			continue
		if extension == "mp3":
			var mp3 := AudioStreamMP3.load_from_file(path)
			if mp3 != null:
				mp3.loop = true
				_loading_music.stream = mp3
		else:
			var wav := AudioStreamWAV.load_from_file(path)
			if wav != null:
				wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
				_loading_music.stream = wav
		return


## Le client d'origine fournit huit ecrans. Ils restent externes au depot :
## le mod les lit sans les copier ni modifier l'installation vanilla.
func _apply_random_external_splash() -> void:
	var game := get_parent()
	if game == null:
		return
	var client_root := str(game.get("daoc_client_root"))
	if client_root == "":
		return
	var directory := client_root.path_join(EXTERNAL_SPLASH_DIR)
	var candidates: Array[String] = []
	for index in range(1, 9):
		var path := directory.path_join("splash%d.tga" % index)
		if FileAccess.file_exists(path):
			candidates.append(path)
	if candidates.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var image := Image.new()
	var chosen := candidates[rng.randi_range(0, candidates.size() - 1)]
	if image.load(chosen) == OK and not image.is_empty():
		var texture := ImageTexture.create_from_image(image)
		if _mode_background != null:
			_mode_background.texture = texture
			_mode_background.set_meta("external_splash_path", chosen)


func _select_mode(value: String) -> void:
	mode = value
	if mode == "V2":
		# La vitrine remplace toute la scene de jeu : rien du client DAoC n'est monte.
		_mode_panel.visible = false
		_show_loading("Chargement de la zone vitrine V2…", 10.0)
		await get_tree().process_frame
		get_tree().change_scene_to_file(V2_SHOWCASE_SCENE)
		return
	if mode == "ONLINE" and not bool(online_profile.get("ok", false)):
		# Fenêtre de connexion (liste de serveurs + identifiants). Le profil est
		# choisi là, puis `_continue_mode_entry` reprend la suite. En reprise
		# après /quit, `online_profile` est déjà valide et on saute la fenêtre.
		_open_online_login()
		return
	await _continue_mode_entry()


func _continue_mode_entry() -> void:
	_mode_panel.visible = false
	_show_loading("Chargement du client %s…" % ("local" if mode == "OFFLINE" else "en ligne"), 10.0)
	await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
	_hide_loading()
	_flow.network_enabled = mode == "ONLINE"
	_flow.start_with_empty_overview = mode == "ONLINE"
	_flow.visible = true
	_flow.show_realm_selection()


var _online_login: CanvasLayer = null


func _open_online_login() -> void:
	if _online_login == null:
		_online_login = preload("res://src/daoc/ui/pregame/DaocOnlineLoginWindow.gd").new()
		_online_login.name = "DaocOnlineLoginWindow"
		_online_login.connect_requested.connect(_on_online_login_confirmed)
		_online_login.cancelled.connect(_on_online_login_cancelled)
		add_child(_online_login)
	else:
		_online_login.show_window()


func _on_online_login_confirmed(profile: Dictionary) -> void:
	online_profile = profile
	# P1-133 : le serveur CHOISI (DOL local, OpenDAoC…) survit au rechargement de
	# scene du /quit ; en memoire seulement, jamais ecrit (mot de passe).
	if is_inside_tree():
		get_tree().root.set_meta("daoc_online_profile_in_use", profile.duplicate(true))
	if _online_login != null:
		_online_login.hide_window()
	_continue_mode_entry()


func _on_online_login_cancelled() -> void:
	if _online_login != null:
		_online_login.hide_window()
	mode = ""
	_mode_panel.visible = true


func _on_play_requested(slot_index: int, character_data: Dictionary) -> void:
	if not bool(character_data.get("valid", false)):
		return
	_flow.visible = false
	_show_loading("Entrée dans le monde avec %s…" % str(character_data.get("name", "personnage")), 25.0)
	await get_tree().process_frame
	if mode == "ONLINE":
		_pending_online_slot = slot_index
		_pending_online_character = character_data.duplicate(true)
		var result: Dictionary = _online_runtime.call("choose_character", character_data) as Dictionary
		if not bool(result.get("ok", false)):
			_show_online_failure(str(result.get("error", "sélection refusée")))
		return
	var game := get_parent()
	if game == null or not game.has_method("start_game_from_pregame"):
		await _show_loading_failure("Le monde de jeu n'est pas disponible.")
		return
	if game.has_signal("startup_progress"):
		var progress_receiver := Callable(self, "_on_world_startup_progress")
		if not game.is_connected("startup_progress", progress_receiver):
			game.connect("startup_progress", progress_receiver)
	_show_loading("Construction de la zone et des collisions…", 45.0)
	await get_tree().process_frame
	var result: Dictionary = game.call("start_game_from_pregame", mode, selected_realm, slot_index, character_data) as Dictionary
	if not bool(result.get("ok", false)):
		await _show_loading_failure("Le monde n'a pas pu etre initialise.")
		return
	if mode != "ONLINE":
		_show_loading("Monde prêt", 100.0)
		await get_tree().process_frame
		_hide_loading()


func _on_world_startup_progress(text: String, value: float) -> void:
	_show_loading(text, value)


func _show_loading_failure(message: String) -> void:
	_show_loading("Erreur : %s Retour à la sélection…" % message, 0.0)
	await get_tree().create_timer(1.5).timeout
	_hide_loading()
	_flow.visible = true
	_flow.show_character_selection(selected_realm)


func _on_realm_confirmed(realm_id: int) -> void:
	selected_realm = realm_id
	if mode != "ONLINE": return
	_show_loading("Connexion au serveur OpenDAoC…", 15.0)
	# P1-129 : revenir au choix du royaume (bouton « Realm ») puis reconfirmer
	# relancait `start` sur la session ouverte : refuse en silence
	# (`session_already_started`), liste vide. Une session deja servie est
	# RECONNECTEE pour le royaume choisi, comme le retour apres /quit.
	_last_overview = {}
	var result: Dictionary = {}
	if _overview_received_count > 0 and _online_runtime.has_method("restart"):
		result = _online_runtime.call("restart", online_profile, realm_id) as Dictionary
	else:
		result = _online_runtime.call("start", online_profile, realm_id) as Dictionary
		if str(result.get("error", "")) == "session_already_started" and _online_runtime.has_method("restart"):
			result = _online_runtime.call("restart", online_profile, realm_id) as Dictionary
	if not bool(result.get("ok", false)):
		_show_online_failure(str(result.get("error", "connexion impossible")))


func _wire_online_runtime() -> void:
	_online_runtime.character_overview_received.connect(_on_online_overview)
	_online_runtime.state_changed.connect(_on_online_state_changed)
	_has_server_playing_signal = _online_runtime.has_signal("server_playing_received")
	if _has_server_playing_signal:
		_online_runtime.server_playing_received.connect(_on_server_playing_received)
	_online_runtime.connection_failed.connect(_show_online_failure)
	_online_runtime.player_position_changed.connect(func(value: Dictionary): _online_world_position = value.duplicate(true))
	if _online_runtime.has_signal("client_world_loading_requested"):
		_online_runtime.client_world_loading_requested.connect(_on_client_world_loading_requested)


func _on_client_world_loading_requested() -> void:
	_begin_original_world_loading()
	_show_loading("Chargement de la zone avant l'entrée du personnage…", 35.0)
	await get_tree().process_frame
	_pending_online_character["online_position"] = _online_world_position.duplicate(true)
	var game := get_parent()
	if game == null or not game.has_method("start_game_from_pregame"):
		_show_online_failure("monde de jeu indisponible")
		return
	if game.has_method("attach_online_runtime"):
		game.call("attach_online_runtime", _online_runtime)
	var result: Dictionary = game.call("start_game_from_pregame", mode, selected_realm,
		_pending_online_slot, _pending_online_character) as Dictionary
	if not bool(result.get("ok", false)):
		_show_online_failure("construction de zone impossible")
		return
	_show_loading("Finalisation de l'entrée dans le monde…", 90.0)
	await get_tree().process_frame
	var resumed: Dictionary = _online_runtime.call("finish_client_world_loading") as Dictionary
	if not bool(resumed.get("ok", false)):
		_show_online_failure(str(resumed.get("error", "PlayerInit impossible")))


## Des que la liste du serveur arrive, les personnages qui n'ont pas encore
## de scene assemblee par le Lab sont exportes EN ARRIERE-PLAN (processus
## Godot separe, hors ligne, ~1 min par personnage). La scene est prise en
## compte au prochain clic sur le personnage, puis dans le monde.
@export var auto_export_online_characters := true
var _export_pid := -1


func _on_online_overview(overview: Dictionary) -> void:
	_overview_received_count += 1
	_last_overview = overview.duplicate(true)
	_hide_loading()
	_flow.apply_character_overview(overview)
	_maybe_export_online_characters(overview)
	_conclude_pending_create(overview)


# --- 2026-09-30 : création simplifiée ----------------------------------------

var _create_window: DaocCharacterCreateWindow = null
var _pending_create_name := ""


func _on_create_requested(slot_index: int) -> void:
	if mode != "ONLINE":
		return
	if _create_window == null:
		_create_window = preload("res://src/daoc/ui/pregame/DaocCharacterCreateWindow.gd").new()
		_create_window.name = "DaocCharacterCreateWindow"
		_create_window.create_confirmed.connect(_on_create_confirmed)
		add_child(_create_window)
	_create_window.open_for(selected_realm, slot_index)


func _on_create_confirmed(data: Dictionary) -> void:
	var result: Dictionary = _online_runtime.call("create_character", data) as Dictionary
	if not bool(result.get("ok", false)):
		_create_window.set_status("Envoi impossible : %s" % str(result.get("error", "?")), true)
		return
	_pending_create_name = str(data.get("name", ""))
	# Filet : sans liste en retour, la fenêtre ne doit jamais rester figée.
	var waited_for := _pending_create_name
	await get_tree().create_timer(create_reply_timeout_sec).timeout
	if _pending_create_name == waited_for and _create_window != null and _create_window.visible:
		_pending_create_name = ""
		_create_window.allow_retry("Pas de réponse du serveur après %d s. Réessayez, ou revenez au choix du royaume." % int(create_reply_timeout_sec))


@export var create_reply_timeout_sec := 10.0


## DOL renvoie la liste après un 0xFF, que la création ait réussi ou non :
## le nom présent dans la liste tranche.
func _conclude_pending_create(overview: Dictionary) -> void:
	if _pending_create_name == "" or _create_window == null:
		return
	var created := false
	for value in overview.get("characters", []) as Array:
		if value is Dictionary and str((value as Dictionary).get("name", "")) == _pending_create_name:
			created = true
	if created:
		_create_window.close()
	else:
		_create_window.allow_retry("Le serveur a refusé « %s » (nom déjà pris ou invalide ?)." % _pending_create_name)
	_pending_create_name = ""


func _maybe_export_online_characters(overview: Dictionary) -> void:
	if not auto_export_online_characters or _export_pid > 0:
		return
	var missing: Array = []
	for value in overview.get("characters", []) as Array:
		if value is Dictionary and str((value as Dictionary).get("name", "")) != "":
			if RosterScript.exported_online_scene_for(str((value as Dictionary).get("name", ""))) == "":
				missing.append(str((value as Dictionary).get("name", "")))
	if missing.is_empty():
		return
	var godot := OS.get_executable_path()
	var project := ProjectSettings.globalize_path("res://")
	_export_pid = OS.create_process(godot, PackedStringArray(["--headless", "--path", project,
		"--script", "res://tools/p1_73_export_online_characters.gd", "--no-header"]))
	print("P1_73_AUTO_EXPORT=%s" % JSON.stringify({"pid": _export_pid, "missing": missing}))


func _on_online_state_changed(state: String) -> void:
	if state != "PLAYING": return
	# Compatibilite des faux runtimes historiques : en production PLAYING public
	# est publie seulement par _on_server_playing_received, apres stabilisation.
	if not _has_server_playing_signal:
		_on_server_playing_received()
		return
	await _finish_loading_with_video()


func _on_server_playing_received() -> void:
	_show_loading("Synchronisation du monde serveur…", 92.0)
	_pending_online_character["online_position"] = _online_world_position.duplicate(true)
	var game := get_parent()
	if game != null and game.has_method("start_game_from_pregame"):
		# Le runtime part AVANT le monde : le peuplement en ligne s'y abonne
		# pendant son montage et rejoue les entites deja recues.
		if game.has_method("attach_online_runtime"):
			game.call("attach_online_runtime", _online_runtime)
		game.call("start_game_from_pregame", mode, selected_realm, _pending_online_slot, _pending_online_character)
		if game.has_method("wait_for_online_world_settled"):
			_show_loading("Chargement des structures et des créatures proches…", 95.0)
			await game.call("wait_for_online_world_settled")
	if _online_runtime.has_method("publish_client_playing"):
		_online_runtime.call("publish_client_playing")
	else:
		await _finish_loading_with_video()


func _show_online_failure(reason: String) -> void:
	_show_loading("Connexion Online interrompue : %s" % reason, 0.0)
	_flow.visible = true


func set_online_runtime_for_test(runtime: Node) -> void:
	_online_runtime = runtime


func set_flow_for_test(flow: DaocPregameFlowController) -> void:
	_flow = flow


func mode_snapshot() -> Dictionary:
	return {
		"mode": mode,
		"realm": selected_realm,
		"flow_visible": _flow != null and _flow.visible,
		"online": OnlineSessionConfig.new().redacted_snapshot(online_profile),
	}


## P1-77 — apres un /quit, DaocGameWorld recharge la scene et laisse une
## consigne sur la racine : on saute l'ecran de mode, on reconnecte au royaume
## d'avant et la liste des personnages (0xFD) rouvre la selection toute seule.
func _resume_after_quit_if_requested() -> void:
	var root := get_tree().root if is_inside_tree() else null
	if root == null or not root.has_meta("daoc_resume_after_quit"):
		return
	var note: Dictionary = root.get_meta("daoc_resume_after_quit") as Dictionary
	root.remove_meta("daoc_resume_after_quit")
	if str(note.get("mode", "")) != "ONLINE":
		return
	resumed_after_quit = note.duplicate(true)
	call_deferred("_resume_online_selection", int(note.get("realm_id", 1)))


var resumed_after_quit: Dictionary = {}


## P1-115 (retour live du 2026-09-25, /stuck) : la scene rechargee se
## reconnecte AVANT que le serveur ait libere la session precedente ; la
## premiere reponse est vide et la liste ne revenait qu a la main (bouton de
## royaume). On retente toutes les `resume_retry_interval_sec` jusqu a ce que
## la liste arrive, au plus `resume_retry_max`.
@export var resume_retry_interval_sec := 5.0
@export var resume_retry_max := 12
var _overview_received_count := 0
var _last_overview: Dictionary = {}
var resume_attempts := 0


func _resume_online_selection(realm_id: int) -> void:
	# Reprise automatique après /quit : on recharge le profil privé pour ne pas
	# rouvrir la fenêtre de connexion au milieu d'une session déjà engagée.
	var root := get_tree().root if is_inside_tree() else null
	if root != null and root.has_meta("daoc_online_profile_in_use"):
		online_profile = (root.get_meta("daoc_online_profile_in_use") as Dictionary).duplicate(true)
	elif not bool(online_profile.get("ok", false)):
		online_profile = OnlineSessionConfig.new().load_local_profile()
	await _select_mode("ONLINE")
	if mode != "ONLINE":
		return
	resume_attempts = 0
	_last_overview = {}
	while resume_attempts < resume_retry_max:
		resume_attempts += 1
		_show_loading("Retour à la sélection du personnage… (essai %d)" % resume_attempts, 15.0)
		if resume_attempts == 1 or not _online_runtime.has_method("restart"):
			_on_realm_confirmed(realm_id)
		else:
			# 2026-09-27 : un second `start` sur la session ouverte etait refuse
			# en silence ; on ferme et on reconnecte vraiment.
			selected_realm = realm_id
			var result: Dictionary = _online_runtime.call("restart", online_profile, realm_id) as Dictionary
			if not bool(result.get("ok", false)):
				print("RESUME_RETRY_FAILED=%s" % str(result.get("error", "")))
		await get_tree().create_timer(resume_retry_interval_sec).timeout
		# Une liste NON vide = le serveur a libere la session : fini.
		if not (_last_overview.get("characters", []) as Array).is_empty():
			return


var _graphics_options: CanvasLayer = null


func _open_graphics_options() -> void:
	if _graphics_options == null:
		_graphics_options = preload("res://src/daoc/ui/DaocGraphicsOptionsWindow.gd").new()
		_graphics_options.name = "DaocGraphicsOptionsWindow"
		add_child(_graphics_options)
		_graphics_options.animation_polish_changed.connect(_on_animation_polish_changed)
		# L'ouverture peut arriver pendant le signal du bouton, avant le _ready de
		# la nouvelle CanvasLayer. Laisser une trame garantit que son panneau existe.
		_graphics_options.call_deferred("show_window")
	else:
		_graphics_options.show_window()


func _on_animation_polish_changed(enabled: bool) -> void:
	if _flow != null and _flow.has_method("set_animation_polish_enabled"):
		_flow.call("set_animation_polish_enabled", enabled)
