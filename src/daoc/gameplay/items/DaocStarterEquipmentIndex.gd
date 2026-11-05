extends RefCounted
class_name DaocStarterEquipmentIndex

## P1-24 — l'équipement de départ d'un métier, lu dans l'index pré-cuit.
##
## CE QU'IL EST, ET CE QU'IL N'EST PAS. C'est l'équipement que `starterequipment`
## donne au métier, résolu dans `itemtemplate` : une arme, un bouclier, six
## pièces d'armure pour un Armsman, avec leurs vraies valeurs — DPS, vitesse,
## qualité, condition, type de dégâts.
##
## **Ce n'est PAS l'équipement de Heyveno.** La capture P1-20E porte un
## `CharacterOverview` avec des MODÈLES d'objets, pas leurs `Id_nb` : un modèle
## d'épée ne dit pas quelle épée. Le rapprochement se fait donc par le MÉTIER, et
## la provenance s'appelle `DUMP_STARTER` pour que personne ne la confonde avec
## `CAPTURE`. Pour un personnage de bas niveau c'est proche ; pour un niveau 40
## c'est une approximation déclarée.
##
## MÊME CONTRAT QUE `DaocMobDbIndex` : l'index porte l'empreinte de ses sources,
## et un index absent n'est pas une erreur — l'appelant retombe sur le
## `PLACEHOLDER` de P1-21A et le dit.

const INDEX_PATH := "res://data/gameplay/dol/p1_24_starter_equipment_index.json"

const BASIS_DUMP_STARTER := "DUMP_STARTER"

## `eInventorySlot` — GameServer/gameutils/IGameInventory.cs:27.
## `Item_Type` d'`itemtemplate` porte ce numéro de logement.
const SLOT_RIGHT_HAND := 10
const SLOT_LEFT_HAND := 11
const SLOT_TWO_HAND := 12
const SLOT_DISTANCE := 13
const SLOT_HEAD := 21
const SLOT_HANDS := 22
const SLOT_FEET := 23
const SLOT_TORSO := 25
const SLOT_LEGS := 27
const SLOT_ARMS := 28

## Les six logements d'armure, ceux que `CalculateArmorHitLocation` peut tirer.
const ARMOR_SLOTS := [SLOT_HEAD, SLOT_HANDS, SLOT_FEET, SLOT_TORSO, SLOT_LEGS, SLOT_ARMS]

## `eObjectType.Cloth` — GameServer/GlobalConstants.cs:150. Une armure de tissu
## a un plafond de facteur d'armure DEUX FOIS PLUS BAS que les autres.
const OBJECT_TYPE_CLOTH := 32

var loaded: bool = false
var error: String = ""

var _by_class: Dictionary = {}
var _items: Dictionary = {}
var _source: Dictionary = {}
var _missing: Array = []


func load_index(path: String = INDEX_PATH) -> bool:
	loaded = false
	error = ""
	if not FileAccess.file_exists(path):
		error = "index absent : %s" % path
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		error = "index illisible : %s" % path
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		error = "index mal formé"
		return false
	var payload: Dictionary = parsed as Dictionary
	_by_class = payload.get("by_class", {}) as Dictionary
	_items = payload.get("items", {}) as Dictionary
	_source = payload.get("source", {}) as Dictionary
	_missing = payload.get("missing_item_templates", []) as Array
	loaded = not _items.is_empty()
	if not loaded:
		error = "index vide"
	return loaded


func source_fingerprint() -> Dictionary:
	return _source.duplicate(true)


## Les objets d'un métier, tels quels. Rend un tableau vide pour un métier
## inconnu — jamais un objet par défaut, qui serait une invention.
func items_for_class(class_id: int) -> Array:
	var out: Array = []
	if not loaded:
		return out
	for value in (_by_class.get(str(class_id), []) as Array):
		var item: Variant = _items.get(str(value), null)
		if item != null:
			out.append((item as Dictionary).duplicate())
	return out


## L'arme de mêlée du métier — main droite d'abord, deux mains ensuite.
##
## LE BOUCLIER N'EN EST PAS UNE. Il occupe le logement 11 (main gauche) et son
## `Object_Type` vaut 42 ; le prendre pour une arme ferait frapper avec, ce qui
## est un vrai coup dans DAoC mais pas l'attaque par défaut.
func melee_weapon_for_class(class_id: int) -> Dictionary:
	var two_handed: Dictionary = {}
	for value in items_for_class(class_id):
		var item: Dictionary = value as Dictionary
		var slot: int = int(item.get("item_type", 0))
		if slot == SLOT_RIGHT_HAND:
			return item
		if slot == SLOT_TWO_HAND:
			two_handed = item
	return two_handed


## Le bouclier du métier, s'il en a un.
##
## `Object_Type` vaut 42 (`eObjectType.Shield`) et son `Type_Damage` porte sa
## TAILLE — 1 petit, 2 moyen, 3 grand — et non un type de dégâts. Troisième sens
## du même champ dans ce dump, après « type de dégâts » sur une arme.
func shield_for_class(class_id: int) -> Dictionary:
	for value in items_for_class(class_id):
		var item: Dictionary = value as Dictionary
		if int(item.get("object_type", 0)) == OBJECT_TYPE_SHIELD:
			return item
	return {}


## `eObjectType.Shield` — GlobalConstants.cs:161.
const OBJECT_TYPE_SHIELD := 42


## Les pièces d'armure, indexées par logement. Un métier peut n'en avoir aucune.
func armor_by_slot(class_id: int) -> Dictionary:
	var out: Dictionary = {}
	for value in items_for_class(class_id):
		var item: Dictionary = value as Dictionary
		var slot: int = int(item.get("item_type", 0))
		if ARMOR_SLOTS.has(slot):
			out[slot] = item
	return out


## L'index est-il à jour avec les dumps du disque ?
##
## Rend `true` quand il n'y a pas de quoi trancher — dumps absents — parce qu'un
## outil hors ligne peut légitimement travailler sans eux. Rend `false` seulement
## quand une source EXISTE et NE CORRESPOND PAS.
func matches_sources(source_root_resolver: Callable) -> bool:
	for table in _source.keys():
		var recorded: Dictionary = _source[table] as Dictionary
		var path: String = str(source_root_resolver.call(str(table)))
		if path == "" or not FileAccess.file_exists(path):
			continue
		if int(FileAccess.get_modified_time(path)) != int(recorded.get("modified", -1)):
			return false
	return true


## Le niveau de la PANOPLIE d'un métier, et non celui d'un objet isolé.
##
## POURQUOI LA PANOPLIE ET PAS L'ARME. Mesuré : l'épée d'entraînement de
## l'Armsman déclare `Level = 0`, c'est-à-dire RIEN — pas « niveau zéro ». Ses
## six pièces d'armure déclarent 2. Prendre le niveau de l'arme au pied de la
## lettre rendait la panoplie grise dès le niveau 3, ce qui est faux : elle est
## grise dès le niveau 5, comme son armure.
##
## Un objet sans niveau déclaré prend donc celui de la panoplie à laquelle il
## appartient. Une panoplie entièrement muette rend 1 — le niveau d'un
## personnage neuf, et le seul plancher qui ne soit pas un choix.
func kit_level(class_id: int) -> int:
	var highest := 0
	for value in items_for_class(class_id):
		highest = maxi(highest, int((value as Dictionary).get("level", 0)))
	return maxi(1, highest)


func missing_item_templates() -> Array:
	return _missing.duplicate()
