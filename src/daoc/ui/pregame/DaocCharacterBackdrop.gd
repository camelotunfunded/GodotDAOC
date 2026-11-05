extends Control
class_name DaocCharacterBackdrop

enum BackdropMode { FLAT, IMAGE, VIDEO, REALTIME_3D }

const PALETTES := {
	1: {"top": Color("#4a211a"), "bottom": Color("#120908"), "accent": Color("#b16a39")},
	2: {"top": Color("#26385b"), "bottom": Color("#080b18"), "accent": Color("#7584b8")},
	3: {"top": Color("#35501e"), "bottom": Color("#0a1307"), "accent": Color("#82a84d")},
}

var realm_id := 1
var requested_mode := BackdropMode.FLAT
var active_mode := BackdropMode.FLAT
var fallback_used := false

@onready var flat_base: ColorRect = $FlatBase
@onready var image_layer: TextureRect = $ImageLayer
@onready var video_layer: VideoStreamPlayer = $VideoLayer


func _ready() -> void:
	set_realm(realm_id)
	reset_to_flat()


func set_realm(value: int) -> void:
	realm_id = clampi(value, 1, 3)
	var palette: Dictionary = PALETTES.get(realm_id, PALETTES[1]) as Dictionary
	if flat_base != null and flat_base.material is ShaderMaterial:
		var material := flat_base.material as ShaderMaterial
		material.set_shader_parameter("color_top", palette.get("top", Color.BLACK))
		material.set_shader_parameter("color_bottom", palette.get("bottom", Color.BLACK))
		material.set_shader_parameter("accent", palette.get("accent", Color.GRAY))


func set_mode(mode: BackdropMode) -> void:
	requested_mode = mode
	fallback_used = false
	match mode:
		BackdropMode.FLAT:
			_show_flat()
		BackdropMode.IMAGE:
			if image_layer != null and image_layer.texture != null:
				_show_only(image_layer)
				active_mode = BackdropMode.IMAGE
			else:
				fallback_used = true
				_show_flat()
		BackdropMode.VIDEO:
			if video_layer != null and video_layer.stream != null:
				_show_only(video_layer)
				video_layer.loop = true
				video_layer.play()
				active_mode = BackdropMode.VIDEO
			else:
				fallback_used = true
				_show_flat()
		BackdropMode.REALTIME_3D:
			fallback_used = true
			_show_flat()


func set_image(texture: Texture2D) -> void:
	image_layer.texture = texture
	set_mode(BackdropMode.IMAGE)


func set_video(stream: VideoStream) -> void:
	video_layer.stream = stream
	set_mode(BackdropMode.VIDEO)


func reset_to_flat() -> void:
	requested_mode = BackdropMode.FLAT
	fallback_used = false
	_show_flat()


func status_snapshot() -> Dictionary:
	return {
		"realm_id": realm_id,
		"requested_mode": BackdropMode.keys()[requested_mode],
		"active_mode": BackdropMode.keys()[active_mode],
		"fallback_used": fallback_used,
		"flat_complete": true,
		"image_supported": true,
		"video_supported": true,
		"realtime_3d_reserved": true,
	}


func _show_flat() -> void:
	_show_only(flat_base)
	active_mode = BackdropMode.FLAT


func _show_only(target: CanvasItem) -> void:
	flat_base.visible = target == flat_base
	image_layer.visible = target == image_layer
	video_layer.visible = target == video_layer
	if target != video_layer:
		video_layer.stop()
