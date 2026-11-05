extends RefCounted
class_name DaocOnlineSessionConfig

const LOCAL_PROFILE_PATH := "res://.env.local.json"
## Serveurs ajoutés par le joueur depuis la fenêtre Online, hors du profil privé
## (qui, lui, n'est pas réinscriptible : il vit dans res:// et porte les
## identifiants). Ce fichier-ci reste dans user:// et ne stocke pas de mot de passe.
const USER_SERVERS_PATH := "user://daoc_online_servers.json"

## Les deux serveurs toujours proposés. Les identifiants ne sont PAS ici : ils
## viennent du profil privé (.env.local.json), rapprochés par host:port.
const BUILTIN_SERVERS := [
	{"name": "OpenDAoC (Eden)", "host": "135.125.201.202", "port": 10300},
	{"name": "DOL local", "host": "127.0.0.1", "port": 10300},
]


func load_local_profile(path: String = LOCAL_PROFILE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "reason": "profil privé absent", "path": path}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "reason": "profil privé illisible", "path": path}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "JSON privé invalide", "path": path}
	return normalize_profile((parsed as Dictionary).get("opendaoc", {}) as Dictionary, path)


func normalize_profile(raw: Dictionary, source: String = "memory") -> Dictionary:
	var host := str(raw.get("host", "")).strip_edges()
	var port := int(raw.get("port", 0))
	var account := str(raw.get("account", "")).strip_edges()
	var password := str(raw.get("password", ""))
	var character := str(raw.get("character", "")).strip_edges()
	var missing: Array[String] = []
	if host == "": missing.append("host")
	if port < 1 or port > 65535: missing.append("port")
	if account == "": missing.append("account")
	if password == "": missing.append("password")
	return {
		"ok": missing.is_empty(),
		"reason": "" if missing.is_empty() else "champs manquants: " + ", ".join(missing),
		"host": host,
		"port": port,
		"account": account,
		"password": password,
		"character": character,
		"source": source,
	}


## Clé de rapprochement d'un serveur : host + port, en minuscules.
static func server_key(host: String, port: int) -> String:
	return "%s:%d" % [str(host).strip_edges().to_lower(), int(port)]


func _read_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return (parsed as Dictionary) if typeof(parsed) == TYPE_DICTIONARY else {}


## Rassemble les identifiants connus (compte / mot de passe / personnage) du
## profil privé, indexés par host:port, pour préremplir la fenêtre Online.
func _known_credentials(path: String) -> Dictionary:
	var creds := {}
	var private := _read_json_dict(path)
	var sources: Array = []
	if private.has("opendaoc"):
		sources.append(private["opendaoc"])
	for entry in private.get("servers", []):
		if typeof(entry) == TYPE_DICTIONARY:
			sources.append(entry)
	for raw in sources:
		var host := str((raw as Dictionary).get("host", "")).strip_edges()
		var port := int((raw as Dictionary).get("port", 0))
		if host == "" or port < 1:
			continue
		creds[server_key(host, port)] = {
			"account": str((raw as Dictionary).get("account", "")).strip_edges(),
			"password": str((raw as Dictionary).get("password", "")),
			"character": str((raw as Dictionary).get("character", "")).strip_edges(),
		}
	return creds


## Catalogue affiché par la fenêtre Online : serveurs intégrés + serveurs
## ajoutés par le joueur, chacun enrichi des identifiants connus s'il y en a.
func load_server_catalog(path: String = LOCAL_PROFILE_PATH) -> Array:
	var creds := _known_credentials(path)
	var catalog: Array = []
	var seen := {}
	var add_entry := func(name: String, host: String, port: int, builtin: bool) -> void:
		host = host.strip_edges()
		if host == "" or port < 1 or port > 65535:
			return
		var key := server_key(host, port)
		if seen.has(key):
			return
		seen[key] = true
		var known: Dictionary = creds.get(key, {})
		catalog.append({
			"name": name.strip_edges() if name.strip_edges() != "" else host,
			"host": host,
			"port": port,
			"account": str(known.get("account", "")),
			"password": str(known.get("password", "")),
			"character": str(known.get("character", "")),
			"has_credentials": str(known.get("account", "")) != "" and str(known.get("password", "")) != "",
			"builtin": builtin,
		})
	for entry in BUILTIN_SERVERS:
		add_entry.call(str(entry.get("name", "")), str(entry.get("host", "")), int(entry.get("port", 0)), true)
	for entry in _read_json_dict(USER_SERVERS_PATH).get("servers", []):
		if typeof(entry) == TYPE_DICTIONARY:
			add_entry.call(str((entry as Dictionary).get("name", "")), str((entry as Dictionary).get("host", "")), int((entry as Dictionary).get("port", 0)), false)
	return catalog


## Ajoute (ou met à jour) un serveur dans le fichier user://, sans mot de passe.
func save_user_server(name: String, host: String, port: int) -> bool:
	host = host.strip_edges()
	if host == "" or port < 1 or port > 65535:
		return false
	var data := _read_json_dict(USER_SERVERS_PATH)
	var servers: Array = data.get("servers", [])
	var key := server_key(host, port)
	var updated := false
	for entry in servers:
		if typeof(entry) == TYPE_DICTIONARY and server_key(str((entry as Dictionary).get("host", "")), int((entry as Dictionary).get("port", 0))) == key:
			(entry as Dictionary)["name"] = name.strip_edges()
			updated = true
			break
	if not updated:
		servers.append({"name": name.strip_edges(), "host": host, "port": port})
	data["servers"] = servers
	var file := FileAccess.open(USER_SERVERS_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


## Construit un profil de connexion à partir d'un serveur choisi et des
## identifiants saisis dans la fenêtre.
func profile_from_inputs(host: String, port: int, account: String, password: String, character: String) -> Dictionary:
	return normalize_profile({
		"host": host, "port": port,
		"account": account, "password": password, "character": character,
	}, "online_window")


func redacted_snapshot(profile: Dictionary) -> Dictionary:
	return {
		"ok": bool(profile.get("ok", false)),
		"host": str(profile.get("host", "")),
		"port": int(profile.get("port", 0)),
		"account_configured": str(profile.get("account", "")) != "",
		"password_configured": str(profile.get("password", "")) != "",
		"character": str(profile.get("character", "")),
		"source": str(profile.get("source", "")),
		"reason": str(profile.get("reason", "")),
	}
