extends RefCounted
class_name DaocServerInstructionDb

## P1-17E2C — DB abstraite des mécaniques serveur DOL/OpenDAoC.
## Les fichiers .db sont du JSON lisible par Godot. Ils stockent les contrats
## et slots d'instructions identifiés, mais n'appliquent aucune logique runtime.

const SCOPE: String = "P1-17E2C abstract server instruction db"
const CHECKPOINT: String = "P1_17E2C_ABSTRACT_SERVER_DB"
const DEFAULT_MANIFEST_PATH: String = "res://data/server_instruction_db/manifest_p1_17e2c.db"

var manifest: Dictionary = {}
var records: Array = []
var records_by_id: Dictionary = {}
var records_by_domain: Dictionary = {}
var records_by_priority: Dictionary = {}
var backend_records: Dictionary = {}
var server_profiles: Array = []
var table_slots: Array = []
var loaded_files: Array = []
var warnings: Array = []
var errors: Array = []
var last_load_result: Dictionary = {}


func load_default() -> Dictionary:
	return load_manifest(DEFAULT_MANIFEST_PATH)


func load_manifest(path: String) -> Dictionary:
	_clear()
	var parsed_manifest: Dictionary = _read_json_dictionary(path)
	if not bool(parsed_manifest.get("ok", false)):
		errors.append(str(parsed_manifest.get("error", "manifest load failed")))
		last_load_result = _result(false, path)
		return last_load_result
	manifest = parsed_manifest.get("data", {}) as Dictionary
	if str(manifest.get("checkpoint", "")) != CHECKPOINT:
		warnings.append("manifest checkpoint mismatch: %s" % str(manifest.get("checkpoint", "")))
	var base_dir: String = path.get_base_dir()
	var includes: Array = manifest.get("includes", []) as Array
	for include_value in includes:
		var include_name: String = str(include_value).strip_edges()
		if include_name == "":
			continue
		_load_db_file(base_dir.path_join(include_name))
	_rebuild_indexes()
	_validate_loaded_state()
	last_load_result = _result(errors.is_empty(), path)
	return last_load_result


func query(criteria: Dictionary = {}) -> Array:
	var out: Array = []
	for record_value in records:
		var record: Dictionary = record_value as Dictionary
		if _matches(record, criteria):
			out.append(record.duplicate(true))
	return out


func get_record(record_id: String) -> Dictionary:
	var key: String = record_id.strip_edges()
	if records_by_id.has(key):
		return (records_by_id[key] as Dictionary).duplicate(true)
	return {}


func get_records_for_backend(backend: String) -> Array:
	var key: String = backend.strip_edges().to_lower()
	if backend_records.has(key):
		return _duplicate_array(backend_records[key] as Array)
	return []


func get_server_profile(backend: String) -> Dictionary:
	var key: String = backend.strip_edges().to_lower()
	for profile_value in server_profiles:
		var profile: Dictionary = profile_value as Dictionary
		if str(profile.get("backend", "")).strip_edges().to_lower() == key or str(profile.get("id", "")).strip_edges().to_lower() == key:
			return profile.duplicate(true)
	return {}


func get_table_slot(slot_id: String) -> Dictionary:
	var key: String = slot_id.strip_edges()
	for slot_value in table_slots:
		var slot: Dictionary = slot_value as Dictionary
		if str(slot.get("id", "")) == key:
			return slot.duplicate(true)
	return {}


func build_backend_context(backend: String) -> Dictionary:
	var profile: Dictionary = get_server_profile(backend)
	var backend_key: String = str(profile.get("backend", backend)).strip_edges().to_lower()
	return {
		"ok": not profile.is_empty(),
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"abstract_only": true,
		"runtime_enabled": false,
		"backend": backend_key,
		"server_profile": profile,
		"instruction_records": get_records_for_backend(backend_key),
		"table_slots": _duplicate_array(table_slots),
		"warnings": warnings.duplicate(true),
		"errors": errors.duplicate(true),
	}


func summarize() -> Dictionary:
	var domains: Dictionary = {}
	var priorities: Dictionary = {}
	var high_risk: int = 0
	for record_value in records:
		var record: Dictionary = record_value as Dictionary
		var domain: String = str(record.get("domain", "unknown"))
		var priority: String = str(record.get("priority", "unknown"))
		domains[domain] = int(domains.get(domain, 0)) + 1
		priorities[priority] = int(priorities.get(priority, 0)) + 1
		if str(record.get("risk", "")).to_lower().contains("high"):
			high_risk += 1
	return {
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"abstract_only": true,
		"record_count": records.size(),
		"domain_counts": domains,
		"priority_counts": priorities,
		"high_risk_count": high_risk,
		"profile_count": server_profiles.size(),
		"table_slot_count": table_slots.size(),
		"loaded_files": loaded_files.duplicate(true),
		"warnings": warnings.duplicate(true),
		"errors": errors.duplicate(true),
	}


func debug_snapshot() -> Dictionary:
	return {
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"default_manifest_path": DEFAULT_MANIFEST_PATH,
		"last_load_result": last_load_result.duplicate(true),
		"summary": summarize(),
	}


func _clear() -> void:
	manifest.clear()
	records.clear()
	records_by_id.clear()
	records_by_domain.clear()
	records_by_priority.clear()
	backend_records.clear()
	server_profiles.clear()
	table_slots.clear()
	loaded_files.clear()
	warnings.clear()
	errors.clear()
	last_load_result.clear()


func _load_db_file(path: String) -> void:
	var parsed: Dictionary = _read_json_dictionary(path)
	if not bool(parsed.get("ok", false)):
		errors.append(str(parsed.get("error", "db load failed")))
		return
	loaded_files.append(path)
	var data: Dictionary = parsed.get("data", {}) as Dictionary
	var kind: String = str(data.get("db_kind", ""))
	if not bool(data.get("abstract_only", false)):
		warnings.append("db file not marked abstract_only: %s" % path)
	match kind:
		"daoc_unified_client_instruction_contracts":
			_add_records(data.get("records", []) as Array)
		"daoc_backend_instruction_contracts":
			var backend: String = str(data.get("backend", "unknown")).strip_edges().to_lower()
			backend_records[backend] = _duplicate_array(data.get("records", []) as Array)
		"daoc_abstract_server_profiles":
			server_profiles = _duplicate_array(data.get("server_profiles", []) as Array)
		"daoc_server_table_slots":
			table_slots = _duplicate_array(data.get("table_slots", []) as Array)
		"daoc_abstract_server_instruction_schema":
			# Schema is validated indirectly below. Keep it in loaded_files only.
			pass
		_:
			warnings.append("unhandled db kind %s in %s" % [kind, path])


func _add_records(new_records: Array) -> void:
	for record_value in new_records:
		if typeof(record_value) != TYPE_DICTIONARY:
			warnings.append("ignored non-dictionary instruction record")
			continue
		var record: Dictionary = (record_value as Dictionary).duplicate(true)
		records.append(record)


func _rebuild_indexes() -> void:
	records_by_id.clear()
	records_by_domain.clear()
	records_by_priority.clear()
	for record_value in records:
		var record: Dictionary = record_value as Dictionary
		var record_id: String = str(record.get("id", ""))
		if record_id == "":
			warnings.append("instruction record without id")
		else:
			records_by_id[record_id] = record
		var domain: String = str(record.get("domain", "unknown"))
		var priority: String = str(record.get("priority", "unknown"))
		_append_index(records_by_domain, domain, record)
		_append_index(records_by_priority, priority, record)


func _append_index(index: Dictionary, key: String, record: Dictionary) -> void:
	if not index.has(key):
		index[key] = []
	var arr: Array = index[key] as Array
	arr.append(record)
	index[key] = arr


func _validate_loaded_state() -> void:
	if records.is_empty():
		errors.append("no unified instruction records loaded")
	if server_profiles.is_empty():
		errors.append("no abstract server profiles loaded")
	if table_slots.is_empty():
		errors.append("no server table slots loaded")
	var expected: int = int(manifest.get("expected_record_count", -1))
	if expected >= 0 and records.size() != expected:
		errors.append("expected %d unified records, loaded %d" % [expected, records.size()])
	for record_value in records:
		var record: Dictionary = record_value as Dictionary
		if bool(record.get("implemented_runtime_effect", true)):
			errors.append("record has runtime effect enabled: %s" % str(record.get("id", "")))
		if not bool(record.get("abstract_only", false)):
			errors.append("record is not abstract_only: %s" % str(record.get("id", "")))


func _matches(record: Dictionary, criteria: Dictionary) -> bool:
	if criteria.has("domain") and str(record.get("domain", "")).to_lower() != str(criteria.get("domain", "")).to_lower():
		return false
	if criteria.has("priority") and str(record.get("priority", "")).to_lower() != str(criteria.get("priority", "")).to_lower():
		return false
	if criteria.has("backend"):
		var backend: String = str(criteria.get("backend", "")).to_lower()
		if backend == "dol" and str(record.get("dolsharp_evidence", "")) == "" and str(record.get("dol_source_url", "")) == "":
			return false
		if backend == "opendaoc" and str(record.get("opendaoc_evidence", "")) == "" and str(record.get("opendaoc_source_url", "")) == "":
			return false
	if criteria.has("tag"):
		var tag: String = str(criteria.get("tag", "")).to_lower()
		var tags: Array = record.get("tags", []) as Array
		var found: bool = false
		for tag_value in tags:
			if str(tag_value).to_lower() == tag:
				found = true
				break
		if not found:
			return false
	if criteria.has("mechanic_contains"):
		var needle: String = str(criteria.get("mechanic_contains", "")).to_lower()
		var hay: String = "%s %s %s %s" % [str(record.get("mechanic", "")), str(record.get("godot_contract_or_model", "")), str(record.get("client_godot_impact", "")), str(record.get("next_action", ""))]
		if not hay.to_lower().contains(needle):
			return false
	return true


func _read_json_dictionary(path: String) -> Dictionary:
	if path.strip_edges() == "":
		return {"ok": false, "error": "empty db path"}
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "db file not found: %s" % path}
	var text: String = FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "db file is not a JSON dictionary: %s" % path}
	return {"ok": true, "data": parsed as Dictionary}


func _result(ok: bool, path: String) -> Dictionary:
	return {
		"ok": ok,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"path": path,
		"record_count": records.size(),
		"profile_count": server_profiles.size(),
		"table_slot_count": table_slots.size(),
		"loaded_files": loaded_files.duplicate(true),
		"warnings": warnings.duplicate(true),
		"errors": errors.duplicate(true),
	}


func _duplicate_array(input: Array) -> Array:
	var out: Array = []
	for item in input:
		if typeof(item) == TYPE_DICTIONARY:
			out.append((item as Dictionary).duplicate(true))
		elif typeof(item) == TYPE_ARRAY:
			out.append((item as Array).duplicate(true))
		else:
			out.append(item)
	return out
