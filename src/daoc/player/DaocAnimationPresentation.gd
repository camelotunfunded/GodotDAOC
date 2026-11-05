extends RefCounted
class_name DaocAnimationPresentation

## Reglage de lecture uniquement : les clips exportes restent inchanges.
## Source du choix utilisateur : user://daoc_options.cfg, ecran Options.

const CONFIG_PATH := "user://daoc_options.cfg"
const SECTION := "animations"
const KEY := "smooth_playback"
const DEFAULT_ENABLED := true
const BLEND_SECONDS := 0.20


static func load_enabled(fallback: bool = DEFAULT_ENABLED) -> bool:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return fallback
	return bool(config.get_value(SECTION, KEY, fallback))


static func save_enabled(enabled: bool) -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value(SECTION, KEY, enabled)
	config.save(CONFIG_PATH)


static func apply_to_tree(root: Node, enabled: bool) -> void:
	if root == null:
		return
	if root is AnimationPlayer:
		apply_to_player(root as AnimationPlayer, enabled)
	for child in root.get_children():
		apply_to_tree(child, enabled)


static func apply_to_player(player: AnimationPlayer, enabled: bool) -> void:
	if player == null or not enabled or bool(player.get_meta("daoc_smooth_playback", false)):
		return
	# Les scenes instanciees partagent leurs Resources. Une copie locale evite
	# qu'activer l'option sur un personnage transforme aussi les temoins OFF.
	for library_name in player.get_animation_library_list():
		var unique := player.get_animation_library(library_name).duplicate(true) as AnimationLibrary
		player.remove_animation_library(library_name)
		player.add_animation_library(library_name, unique)
	for library_name in player.get_animation_library_list():
		var library := player.get_animation_library(library_name)
		for animation_name in library.get_animation_list():
			var animation := library.get_animation(animation_name)
			for track in range(animation.get_track_count()):
				if animation.track_get_type(track) in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
					animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	player.set_meta("daoc_smooth_playback", true)


static func blend_seconds(enabled: bool) -> float:
	return BLEND_SECONDS if enabled else 0.0
