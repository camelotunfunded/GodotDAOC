extends RefCounted
class_name DaocUiXmlParser

## P1-21C - lecteur des fenetres XML de l'interface DAoC d'origine.
##
## Le client decrit son interface dans `ui/<skin>/*.xml` : 67 fenetres pour
## `isles`. Ces fichiers ne portent AUCUNE logique - uniquement de l'apparence,
## de la position, et des NOMS que le moteur reconnait. Ce lecteur les restitue
## tels quels ; il n'invente aucune valeur par defaut et ne complete aucun trou.
##
## Les fichiers sont lus DIRECTEMENT dans le client via un chemin absolu ; rien
## n'est copie ni importe dans `res://`, comme pour les PNG de terrain et d'eau.
##
## Encodage : les fichiers declarent `ISO-8859-1`. Les octets >= 0x80 sont donc
## decodes en latin-1 avant analyse, sinon les libelles accentues sont corrompus
## silencieusement.
##
## Trois balises portent le meme mecanisme de liaison selon le type de controle :
## `Adapter`, `AdapterName` et `ColorAdapter`. Un lecteur qui n'en regarde qu'une
## perd la moitie des liaisons - les trois sont collectees ici.
##
## LA CASSE N'EST PAS SIGNIFIANTE. Le client ecrit indifferemment `AdapterName`
## et `Adaptername`, `ColorAdapter` et `Coloradapter` : sur `atlantis` + `isles`,
## 442 contre 115 pour la premiere paire, 306 contre 53 pour la seconde. Son
## propre moteur lit les deux, donc la comparaison se fait en minuscules. Une
## comparaison exacte perdait ces 168 liaisons en silence - dont les six barres
## d'etat de `summary.xml`, qui restaient grises faute d'etre reliees.
##
## `LabelAdapterName`, `StateAdapterName` et `BaseAdapterName` existent aussi
## dans le client mais designent d'AUTRES roles : ils ne sont pas ajoutes ici.

## Balises de liaison de donnees, toutes formes confondues. Comparees en
## minuscules par `_is_adapter_tag`, jamais directement.
const ADAPTER_TAGS := ["Adapter", "AdapterName", "ColorAdapter", "TextAdapterName"]

## Valeurs de liaison qui signifient explicitement "aucune source".
const ADAPTER_NONE := ["", "none"]


## Lit un fichier et renvoie son contenu indexe. Ne leve jamais : en cas
## d'echec le resultat porte le motif dans `errors`.
static func parse_file(absolute_path: String) -> DaocUiParseResult:
	var result: DaocUiParseResult = DaocUiParseResult.new()
	result.source_path = absolute_path

	var text: String = _read_text(absolute_path)
	if text == "":
		result.errors.append("fichier illisible ou vide : %s" % absolute_path)
		return result

	var parser: XMLParser = XMLParser.new()
	var opened: int = parser.open_buffer(text.to_utf8_buffer())
	if opened != OK:
		result.errors.append("XML illisible (code %d) : %s" % [opened, absolute_path])
		return result

	var root: Variant = _read_document(parser)
	if not (root is Dictionary):
		result.errors.append("racine XML absente : %s" % absolute_path)
		return result

	_index(root as Dictionary, result)
	return result


## Lit tous les `*.xml` d'un dossier de skin. Renvoie un resultat par fichier,
## trie par nom pour que deux executions donnent le meme ordre.
static func parse_directory(skin_dir: String) -> Array[DaocUiParseResult]:
	var out: Array[DaocUiParseResult] = []
	var names: PackedStringArray = _list_xml(skin_dir)
	for name: String in names:
		out.append(parse_file(skin_dir.path_join(name)))
	return out


static func _list_xml(skin_dir: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(skin_dir)
	if dir == null:
		return names
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.to_lower().ends_with(".xml"):
			names.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	names.sort()
	return names


# ---------------------------------------------------------------------------
# lecture brute

static func _read_text(absolute_path: String) -> String:
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return ""
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	if bytes.is_empty():
		return ""
	return _decode_latin1(bytes)


## Latin-1 fait correspondre chaque octet a son point de code : la conversion
## est directe. Le chemin ASCII est privilegie car la quasi-totalite des
## fichiers n'a aucun octet haut.
static func _decode_latin1(bytes: PackedByteArray) -> String:
	var has_high: bool = false
	for byte: int in bytes:
		if byte >= 0x80:
			has_high = true
			break
	if not has_high:
		return bytes.get_string_from_ascii()
	var parts: PackedStringArray = PackedStringArray()
	for byte: int in bytes:
		parts.append(String.chr(byte))
	return "".join(parts)


## Descend jusqu'au premier element et lit tout son sous-arbre.
static func _read_document(parser: XMLParser) -> Variant:
	while parser.read() == OK:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			if parser.is_empty():
				return {}
			return _read_element(parser)
	return null


## Lit le sous-arbre de l'element courant, dont la balise ouvrante vient d'etre
## consommee. Renvoie une String pour une feuille, un Dictionary sinon.
static func _read_element(parser: XMLParser) -> Variant:
	var children: Dictionary = {}
	var text: String = ""
	while parser.read() == OK:
		var kind: int = parser.get_node_type()
		if kind == XMLParser.NODE_ELEMENT:
			var child_name: String = parser.get_node_name()
			var value: Variant = "" if parser.is_empty() else _read_element(parser)
			_append_child(children, child_name, value)
		elif kind == XMLParser.NODE_ELEMENT_END:
			break
		elif kind == XMLParser.NODE_TEXT:
			text += parser.get_node_data()
	if children.is_empty():
		return text.strip_edges()
	return children


## Une balise repetee devient un Array ; une balise unique reste sa valeur.
static func _append_child(children: Dictionary, key: String, value: Variant) -> void:
	if not children.has(key):
		children[key] = value
		return
	var current: Variant = children[key]
	if current is Array:
		(current as Array).append(value)
		return
	children[key] = [current, value]


# ---------------------------------------------------------------------------
# indexation

static func _index(root: Dictionary, result: DaocUiParseResult) -> void:
	for key: String in root:
		var entries: Array = _as_array(root[key])
		if key == "WindowTemplate":
			for entry: Variant in entries:
				if entry is Dictionary:
					result.windows.append(entry as Dictionary)
		elif key.ends_with("Template"):
			for entry: Variant in entries:
				if entry is Dictionary:
					_store_template(result, key, entry as Dictionary)
	_walk(root, result)


static func _store_template(result: DaocUiParseResult, type_name: String, entry: Dictionary) -> void:
	if not result.templates.has(type_name):
		result.templates[type_name] = {}
	var by_name: Dictionary = result.templates[type_name]
	var name: String = str(entry.get("Name", ""))
	if name == "":
		name = "#%d" % by_name.size()
	by_name[name] = entry


## Parcours integral : compte les controles, collecte les liaisons, les
## commandes et les identifiants de fenetre, quel que soit leur niveau.
static func _walk(node: Dictionary, result: DaocUiParseResult) -> void:
	for key: String in node:
		var value: Variant = node[key]
		var entries: Array = _as_array(value)

		if key.ends_with("Def"):
			result.control_counts[key] = int(result.control_counts.get(key, 0)) + entries.size()
		elif key == "WindowId":
			for entry: Variant in entries:
				var window_id: String = str(entry).strip_edges()
				if window_id != "" and not result.window_ids.has(window_id):
					result.window_ids.append(window_id)
		elif _is_adapter_tag(key):
			for entry: Variant in entries:
				_count_name(result.adapters, str(entry))
		elif key.to_lower() == "onclickevent":
			for entry: Variant in entries:
				_count_name(result.events, str(entry))

		for entry: Variant in entries:
			if entry is Dictionary:
				_walk(entry as Dictionary, result)


## Vraie si la balise est une liaison, quelle que soit sa casse.
static func _is_adapter_tag(key: String) -> bool:
	var lowered: String = key.to_lower()
	for tag: String in ADAPTER_TAGS:
		if tag.to_lower() == lowered:
			return true
	return false


static func _count_name(bag: Dictionary, raw: String) -> void:
	var name: String = raw.strip_edges()
	if ADAPTER_NONE.has(name.to_lower()):
		return
	bag[name] = int(bag.get(name, 0)) + 1


static func _as_array(value: Variant) -> Array:
	if value is Array:
		return value as Array
	return [value]
