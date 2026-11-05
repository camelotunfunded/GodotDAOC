extends Node
class_name DaocWaterTextureBinder

const DaocWaterMaterialFactoryScript = preload("res://src/daoc/water/DaocWaterMaterialFactory.gd")

## Keeps external client pixels out of PackedScene data. The builder serializes
## only the shader, DAoC recipe and client path; PNG pixels are bound after the
## generated/runtime branch enters the scene tree.

var client_root: String = ""


func configure(value: String) -> void:
	client_root = value.strip_edges().replace("\\", "/").trim_suffix("/")


func _ready() -> void:
	bind_now()


func bind_now() -> int:
	var bound := 0
	var parent := get_parent()
	if parent == null:
		return bound
	for child in parent.get_children():
		var mesh := child as MeshInstance3D
		if mesh == null:
			continue
		var material := mesh.material_override as ShaderMaterial
		if material == null or not bool(material.get_meta("daoc_water_shader", false)):
			continue
		if DaocWaterMaterialFactoryScript.bind_external_texture(material, client_root):
			bound += 1
	set_meta("daoc_water_bound_materials", bound)
	return bound
