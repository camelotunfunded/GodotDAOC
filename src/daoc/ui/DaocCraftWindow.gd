extends CanvasLayer
class_name DaocCraftWindow

## P1-122 — la fenetre d'artisanat. Les competences, categories et recettes
## sont celles du livre du CLIENT (tdl.crf, DaocCraftRecipeBook) ; les noms et
## ingredients viennent de l'index precuit du dump OpenDAoC ; les points de
## chaque metier viennent du serveur (0x16/08, P1-83). « Fabriquer » envoie
## 0xED avec le CraftedItemID ; le serveur repond par le compte a rebours 0xF3
## (« Currently making … », P1-109) et le resultat dans la console.
##
## Une recette que le livre porte mais que le dump du serveur ne connait pas
## est GRISEE et le dit : le serveur la refuserait (Recipe.FindBy -> null).

signal craft_requested(recipe_id: int)

const INDEX_PATH := "res://data/gameplay/dol/p1_122_craft_index.json"

var book: DaocCraftRecipeBook = null
var server_skills: Dictionary = {}   # nom du metier (minuscules) -> points
var crafts_requested := 0
var selected_recipe_id := -1
var _index: Dictionary = {}
var _panel: PanelContainer = null
var _skills: OptionButton = null
var _categories: ItemList = null
var _recipes: ItemList = null
var _detail: Label = null
var _craft: Button = null


func _ready() -> void:
	layer = 23
	_panel = PanelContainer.new()
	_panel.name = "CraftWindow"
	_panel.position = Vector2(160, 80)
	_panel.custom_minimum_size = Vector2(620, 420)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.94)
	style.border_color = Color(0.75, 0.65, 0.4)
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	var title := Label.new()
	title.text = "Artisanat"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
	box.add_child(title)
	_skills = OptionButton.new()
	_skills.item_selected.connect(func(_i: int) -> void: _fill_categories())
	box.add_child(_skills)
	var lists := HBoxContainer.new()
	lists.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_categories = ItemList.new()
	_categories.custom_minimum_size = Vector2(200, 260)
	_categories.item_selected.connect(func(_i: int) -> void: _fill_recipes())
	lists.add_child(_categories)
	_recipes = ItemList.new()
	_recipes.custom_minimum_size = Vector2(390, 260)
	_recipes.item_selected.connect(_on_recipe_selected)
	_recipes.item_activated.connect(func(_i: int) -> void: request_selected())
	lists.add_child(_recipes)
	box.add_child(lists)
	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_theme_font_size_override("font_size", 11)
	box.add_child(_detail)
	var buttons := HBoxContainer.new()
	_craft = Button.new()
	_craft.text = "Fabriquer"
	_craft.disabled = true
	_craft.pressed.connect(request_selected)
	buttons.add_child(_craft)
	var close := Button.new()
	close.text = "Fermer"
	close.pressed.connect(hide_window)
	buttons.add_child(close)
	box.add_child(buttons)
	_panel.add_child(box)
	_panel.visible = false
	add_child(_panel)
	if FileAccess.file_exists(INDEX_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
		if parsed is Dictionary:
			_index = (parsed as Dictionary).get("recipes", {}) as Dictionary


func set_book(value: DaocCraftRecipeBook) -> void:
	book = value
	_fill_skills()


## Les metiers du 0x16/08 : [{name, points}].
func set_server_skills(skills: Array) -> void:
	server_skills.clear()
	for value in skills:
		var entry := value as Dictionary
		server_skills[str(entry.get("name", "")).to_lower()] = int(entry.get("points", 0))
	_fill_skills()


func recipe_entry(recipe_id: int) -> Array:
	return _index.get(str(recipe_id), []) as Array


func toggle() -> void:
	_panel.visible = not _panel.visible


func show_window() -> void:
	_panel.visible = true


func hide_window() -> void:
	_panel.visible = false


func is_shown() -> bool:
	return _panel != null and _panel.visible


func select_skill(skill_id: int) -> void:
	for index in range(_skills.item_count):
		if _skills.get_item_id(index) == skill_id:
			_skills.select(index)
			_fill_categories()
			return


func select_recipe(category_index: int, recipe_index: int) -> void:
	_categories.select(category_index)
	_fill_recipes()
	_recipes.select(recipe_index)
	_on_recipe_selected(recipe_index)


func request_selected() -> void:
	if selected_recipe_id <= 0 or recipe_entry(selected_recipe_id).is_empty():
		return
	crafts_requested += 1
	craft_requested.emit(selected_recipe_id)


func _fill_skills() -> void:
	if _skills == null or book == null:
		return
	var previous := _skills.get_selected_id()
	_skills.clear()
	for entry in book.skills:
		var skill := entry as Dictionary
		var name := str(skill["name"])
		var points := int(server_skills.get(name.to_lower(), -1))
		_skills.add_item("%s%s" % [name, "  (%d)" % points if points >= 0 else ""], int(skill["skill"]))
	if previous >= 0:
		select_skill(previous)
	elif _skills.item_count > 0:
		_skills.select(0)
		_fill_categories()


func _current_skill() -> Dictionary:
	if book == null or _skills.selected < 0:
		return {}
	return book.skill(_skills.get_item_id(_skills.selected))


func _fill_categories() -> void:
	_categories.clear()
	_recipes.clear()
	for category in _current_skill().get("categories", []):
		_categories.add_item(str((category as Dictionary).get("name", "")))


func _fill_recipes() -> void:
	_recipes.clear()
	var selected := _categories.get_selected_items()
	if selected.is_empty():
		return
	var category: Dictionary = (_current_skill().get("categories", []) as Array)[selected[0]] as Dictionary
	for recipe in category.get("recipes", []):
		var id := int((recipe as Dictionary).get("id", 0))
		var entry := recipe_entry(id)
		var name := str(entry[0]) if not entry.is_empty() else "%s #%d" % [str(category.get("name", "")), id]
		var index := _recipes.add_item("%4d  %s" % [int((recipe as Dictionary).get("level", 0)), name])
		_recipes.set_item_metadata(index, id)
		if entry.is_empty():
			_recipes.set_item_custom_fg_color(index, Color(0.5, 0.5, 0.5))


func _on_recipe_selected(index: int) -> void:
	selected_recipe_id = int(_recipes.get_item_metadata(index))
	var entry := recipe_entry(selected_recipe_id)
	if entry.is_empty():
		_detail.text = "Recette %d : absente de la base du serveur, il la refuserait." % selected_recipe_id
		_craft.disabled = true
		return
	var parts: Array = []
	for pair in entry[3]:
		parts.append("%d %s" % [int(pair[1]), str(pair[0])])
	_detail.text = "%s — niveau %d\nIngredients : %s" % [str(entry[0]), int(entry[1]), ", ".join(parts)]
	_craft.disabled = false
