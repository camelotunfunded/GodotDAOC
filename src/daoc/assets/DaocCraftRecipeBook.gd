class_name DaocCraftRecipeBook
extends RefCounted

## P1-122 — le livre de recettes du client d'origine : `data/ifd/tdl.crf`
## (aussi dans `data/ifd.mpk`), lu par game.dll `FUN_004fc13d` (eden.dll.c
## l.237709). Rien n'y est devine :
##
##   en-tete de 19 u32 : version (0x67 = 103, sinon « Invalid Recipe
##   Version »), taille du bloc de chaines, nombre de chaines, 0, puis par
##   royaume (Albion, Midgard, Hibernia) cinq u32 : nombre de recettes,
##   nombre de categories, decalage des recettes (0x58 octets chacune),
##   decalage des categories (0x68), decalage de l'index (0x7f8 u32) ;
##   bloc de chaines a 0x4C, suivi de ses decalages (u32).
##
##   index : 20 competences de 0x198 octets (FUN_004fd1e7) — u32 nom (chaine),
##   u32 ?, puis 0xcc u16 = categories (FUN_004fd1ff) ; le rang est l'enum
##   eCraftingSkill (1 Weaponcrafting ... 15 Basic Crafting).
##   categorie : u16 nom (chaine), u16 0, puis 50 u16 = recettes (FUN_004fd343).
##   recette : u32 CraftedItemID (la cle que 0xED envoie, recoupee sur
##   crafteditem.sql : 3451 = bronze_bracket), ..., u16 niveau requis a +0x0E,
##   puis 8 composants a +0x18 (u32 nombre, u32 : u16 haut = materiau).

const VERSION := 0x67
const HEADER_WORDS := 19
const STRINGS_AT := 0x4C
const RECIPE_SIZE := 0x58
const CATEGORY_SIZE := 0x68
const SKILL_SIZE := 0x198
const SKILL_COUNT := 20
const CATEGORY_SLOTS := 0xcc
const RECIPE_SLOTS := 50
const REALM_NAMES := {1: "Albion", 2: "Midgard", 3: "Hibernia"}

var error := ""
var realm := 1
var skills: Array = []   # [{skill, name, categories: [{name, recipes: [{id, level, components}]}]}]
var recipe_count := 0
var _data := PackedByteArray()
var _string_count := 0
var _blob_size := 0


static func load_from_client(client_root: String, realm_id: int) -> DaocCraftRecipeBook:
	var book := DaocCraftRecipeBook.new()
	book.realm = clampi(realm_id, 1, 3)
	var path := client_root.path_join("data/ifd/tdl.crf")
	if FileAccess.file_exists(path):
		book._data = FileAccess.get_file_as_bytes(path)
	else:
		var archive := DaocMpkArchive.open(client_root.path_join("data/ifd.mpk"))
		book._data = archive.read_file("tdl.crf") if archive.error == "" else PackedByteArray()
	book._parse()
	return book


func _parse() -> void:
	if _data.size() < HEADER_WORDS * 4:
		error = "tdl.crf absent"
		return
	if _data.decode_u32(0) != VERSION:
		error = "version de recettes inattendue %d" % _data.decode_u32(0)
		return
	_blob_size = _data.decode_u32(4)
	_string_count = _data.decode_u32(8)
	var base := 4 + (realm - 1) * 5
	var recipes_total := _data.decode_u32(base * 4)
	var categories_total := _data.decode_u32((base + 1) * 4)
	var recipes_at := _data.decode_u32((base + 2) * 4)
	var categories_at := _data.decode_u32((base + 3) * 4)
	var index_at := _data.decode_u32((base + 4) * 4)
	for skill in range(1, SKILL_COUNT):
		var at := index_at + skill * SKILL_SIZE
		var name_index := _data.decode_u32(at)
		if name_index == 0:
			continue
		var categories: Array = []
		for slot in range(CATEGORY_SLOTS):
			var category_index := _data.decode_u16(at + 8 + slot * 2)
			if category_index == 0 or category_index >= categories_total:
				continue
			var cat_at := categories_at + category_index * CATEGORY_SIZE
			var recipes: Array = []
			for recipe_slot in range(RECIPE_SLOTS):
				var recipe_index := _data.decode_u16(cat_at + 4 + recipe_slot * 2)
				if recipe_index == 0 or recipe_index >= recipes_total:
					continue
				recipes.append(_recipe(recipes_at + recipe_index * RECIPE_SIZE))
			if recipes.is_empty():
				continue
			recipe_count += recipes.size()
			categories.append({"name": string_at(_data.decode_u16(cat_at)), "recipes": recipes})
		if not categories.is_empty():
			skills.append({"skill": skill, "name": string_at(name_index), "categories": categories})


func _recipe(at: int) -> Dictionary:
	var components: Array = []
	for index in range(8):
		var count := _data.decode_u32(at + 0x18 + index * 8)
		if count == 0:
			continue
		components.append({"count": count, "material": _data.decode_u16(at + 0x1c + index * 8 + 2)})
	return {"id": _data.decode_u32(at), "level": _data.decode_u16(at + 0x0E), "components": components}


func string_at(index: int) -> String:
	if index <= 0 or index >= _string_count:
		return ""
	var at := STRINGS_AT + _data.decode_u32(STRINGS_AT + _blob_size + index * 4)
	var end := at
	while end < _data.size() and _data[end] != 0:
		end += 1
	return _data.slice(at, end).get_string_from_utf8()


func skill(skill_id: int) -> Dictionary:
	for entry in skills:
		if int((entry as Dictionary).get("skill", 0)) == skill_id:
			return entry as Dictionary
	return {}


func find_recipe(recipe_id: int) -> Dictionary:
	for entry in skills:
		for category in (entry as Dictionary).get("categories", []):
			for recipe in (category as Dictionary).get("recipes", []):
				if int((recipe as Dictionary).get("id", 0)) == recipe_id:
					var out := (recipe as Dictionary).duplicate(true)
					out["skill"] = int((entry as Dictionary).get("skill", 0))
					out["category"] = str((category as Dictionary).get("name", ""))
					return out
	return {}
