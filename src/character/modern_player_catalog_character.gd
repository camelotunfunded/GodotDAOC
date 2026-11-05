class_name ModernPlayerCatalogCharacter
extends Node3D

## Assemble les objets rigides optionnels exportes par le Character Lab sur
## les os du squelette. Le client peut ensuite les remplacer sans reconstruire
## le personnage entier quand l'inventaire online change.


func _ready() -> void:
	var skeleton := get_node_or_null("Rig/Skeleton3D") as Skeleton3D
	if skeleton == null:
		return
	for child_value in get_children():
		var child := child_value as Node
		if not child.has_meta("daoc_attach_bone"):
			continue
		var bone_name := str(child.get_meta("daoc_attach_bone"))
		if skeleton.find_bone(bone_name) < 0:
			continue
		child.owner = null
		remove_child(child)
		var attachment := BoneAttachment3D.new()
		attachment.name = "%sAttachment" % str(child.get_meta("daoc_equipment_slot", "item")).to_pascal_case()
		attachment.set_meta("daoc_equipment_slot", str(child.get_meta("daoc_equipment_slot", "item")))
		skeleton.add_child(attachment)
		attachment.bone_idx = skeleton.find_bone(bone_name)
		attachment.add_child(child)
