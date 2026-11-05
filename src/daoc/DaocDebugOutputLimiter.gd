extends RefCounted
class_name DaocDebugOutputLimiter

## P1-N6E: garde-fou commun pour les sorties debug/console/F12.
## Objectif: aucun snapshot profond ne doit être imprimé brut dans la console Godot.

const DEFAULT_MAX_CHARS: int = 900
const DEFAULT_MAX_LINES: int = 24
const DEFAULT_MAX_ARRAY_ITEMS: int = 8
const DEFAULT_MAX_DICT_KEYS: int = 12
const DEFAULT_MAX_DEPTH: int = 2


func compact_text(value: String, max_chars: int = DEFAULT_MAX_CHARS, max_lines: int = DEFAULT_MAX_LINES) -> String:
	var text := str(value)
	if text == "":
		return ""
	var split: PackedStringArray = text.split("\n", false)
	var out: PackedStringArray = PackedStringArray()
	var count: int = mini(split.size(), max_lines)
	for i in range(count):
		out.append(str(split[i]))
	if split.size() > max_lines:
		out.append("... <truncated %d line(s)>" % (split.size() - max_lines))
	var joined: String = "\n".join(out)
	if joined.length() > max_chars:
		return joined.substr(0, max_chars) + " ... <truncated %d chars>" % (joined.length() - max_chars)
	return joined


func compact_value(value: Variant, max_chars: int = DEFAULT_MAX_CHARS, max_depth: int = DEFAULT_MAX_DEPTH) -> String:
	return compact_text(str(compact_variant(value, max_depth)), max_chars, DEFAULT_MAX_LINES)


func compact_variant(value: Variant, max_depth: int = DEFAULT_MAX_DEPTH, max_array_items: int = DEFAULT_MAX_ARRAY_ITEMS, max_dict_keys: int = DEFAULT_MAX_DICT_KEYS) -> Variant:
	return _compact_variant_inner(value, max_depth, max_array_items, max_dict_keys, 0)


func compact_report_detail(value: Variant, max_chars: int = DEFAULT_MAX_CHARS) -> String:
	return compact_value(value, max_chars, DEFAULT_MAX_DEPTH)


func _compact_variant_inner(value: Variant, max_depth: int, max_array_items: int, max_dict_keys: int, depth: int) -> Variant:
	if depth >= max_depth:
		return _leaf_summary(value)
	var t: int = typeof(value)
	if t == TYPE_DICTIONARY:
		var d: Dictionary = value as Dictionary
		var out: Dictionary = {}
		var keys: Array = d.keys()
		var count: int = mini(keys.size(), max_dict_keys)
		for i in range(count):
			var key: Variant = keys[i]
			out[str(key)] = _compact_variant_inner(d[key], max_depth, max_array_items, max_dict_keys, depth + 1)
		if keys.size() > max_dict_keys:
			out["_truncated_keys"] = keys.size() - max_dict_keys
		return out
	if t == TYPE_ARRAY:
		var arr: Array = value as Array
		var out_arr: Array = []
		var count_arr: int = mini(arr.size(), max_array_items)
		for i in range(count_arr):
			out_arr.append(_compact_variant_inner(arr[i], max_depth, max_array_items, max_dict_keys, depth + 1))
		if arr.size() > max_array_items:
			out_arr.append("... <truncated %d item(s)>" % (arr.size() - max_array_items))
		return out_arr
	if t == TYPE_PACKED_BYTE_ARRAY or t == TYPE_PACKED_STRING_ARRAY or t == TYPE_PACKED_INT32_ARRAY or t == TYPE_PACKED_INT64_ARRAY or t == TYPE_PACKED_FLOAT32_ARRAY or t == TYPE_PACKED_FLOAT64_ARRAY or t == TYPE_PACKED_VECTOR2_ARRAY or t == TYPE_PACKED_VECTOR3_ARRAY or t == TYPE_PACKED_COLOR_ARRAY:
		var out_packed: Array = []
		var i: int = 0
		for item in value:
			if i >= max_array_items:
				break
			out_packed.append(_compact_variant_inner(item, max_depth, max_array_items, max_dict_keys, depth + 1))
			i += 1
		var total: int = 0
		for _item in value:
			total += 1
		if total > max_array_items:
			out_packed.append("... <truncated %d item(s)>" % (total - max_array_items))
		return out_packed
	if t == TYPE_VECTOR2:
		var v2: Vector2 = value as Vector2
		return "(%.2f, %.2f)" % [v2.x, v2.y]
	if t == TYPE_VECTOR3:
		var v3: Vector3 = value as Vector3
		return "(%.2f, %.2f, %.2f)" % [v3.x, v3.y, v3.z]
	if t == TYPE_OBJECT:
		return str(value)
	return value


func _leaf_summary(value: Variant) -> Variant:
	var t: int = typeof(value)
	if t == TYPE_DICTIONARY:
		var d: Dictionary = value as Dictionary
		var out: Dictionary = {"_type": "Dictionary", "size": d.size()}
		for key_name in ["scope", "state_name", "phase", "ui_phase", "name", "realm_name", "rule_confirmed", "no_runtime_import"]:
			if d.has(key_name):
				out[key_name] = d[key_name]
		return out
	if t == TYPE_ARRAY:
		return {"_type": "Array", "size": (value as Array).size()}
	if t == TYPE_PACKED_BYTE_ARRAY or t == TYPE_PACKED_STRING_ARRAY or t == TYPE_PACKED_INT32_ARRAY or t == TYPE_PACKED_INT64_ARRAY or t == TYPE_PACKED_FLOAT32_ARRAY or t == TYPE_PACKED_FLOAT64_ARRAY or t == TYPE_PACKED_VECTOR2_ARRAY or t == TYPE_PACKED_VECTOR3_ARRAY or t == TYPE_PACKED_COLOR_ARRAY:
		var count: int = 0
		for _item in value:
			count += 1
		return {"_type": "PackedArray", "size": count}
	if t == TYPE_OBJECT:
		return str(value)
	return value
