extends RefCounted
class_name DaocUiServerBridge

## P1-21E - traduit ce que sait l'autorite de combat vers les canaux nommes.
##
## `DaocLocalServer` parle en instantanes ; l'interface attend des canaux. Ce
## pont ne fait que traduire, il ne calcule ni ne devine rien.
##
## REGLE D'UNITE, heritee du format : une jauge recoit un POURCENTAGE, parce
## qu'aucune balise `Max`, `Range` ou `Total` n'existe dans le XML - une barre
## ne peut structurellement pas connaitre son maximum.
##
## La VIE est deja publiee en pourcentage. L'endurance suit le contrat local
## OpenDAoC normalise 0..100 de `DaocCombatEntityState` et peut donc alimenter
## directement `summary_player_end`.
##
## P1-23C — LA MANA A ENFIN UNE ECHELLE, quand l'arbitre en connait une.
## `CalculateMaxMana` donne le plafond, l'instantane rend `mana_percent`, et
## cette jauge cesse d'etre muette. MAIS LE COMPTAGE RESTE : un metier sans
## caracteristique d'incantation a un pool NUL, `mana_percent` est alors absent,
## et la valeur retourne dans `unpublished_for_lack_of_scale`. Une jauge de mana
## vide chez un guerrier est CORRECTE et non un defaut de pont.
##
## PROVENANCE par canal :
##   CAPTURE      nom, niveau, `health_percent` - reellement observes
##   PLACEHOLDER  rien n'est publie sous ce statut

## Canaux alimentes par l'instantane du joueur.
const PLAYER_CHANNELS := {
	"stats_name": "name",
	"stats_level": "level",
	"summary_player_hits": "health_percent",
	"summary_player_end": "endurance",
	"summary_player_power": "mana_percent",
}

## Canaux alimentes par l'instantane de la cible.
const TARGET_CHANNELS := {
	"summary_target": "name",
	"summary_target_hits": "health_percent",
}

## Valeurs que l'instantane porte sans echelle connue : jamais vers une jauge.
const UNSCALED_FIELDS := ["mana"]

var bus: DaocUiAdapterBus = null
var server = null

## Identifiant du joueur cote autorite.
var player_object_id: int = -1

## Cible courante, -1 si aucune.
var target_object_id: int = -1

var published_updates: int = 0
var unpublished_for_lack_of_scale: int = 0


func setup(local_server, adapter_bus: DaocUiAdapterBus, p_player_object_id: int) -> Dictionary:
	server = local_server
	bus = adapter_bus
	player_object_id = p_player_object_id
	if server == null or bus == null:
		return {"ok": false, "reason": "serveur ou bus absent"}

	if server.has_signal("state_changed"):
		server.state_changed.connect(_on_state_changed)
	if server.has_signal("entity_died"):
		server.entity_died.connect(_on_entity_died)
	if server.has_signal("entity_removed"):
		server.entity_removed.connect(_on_entity_removed)

	push_player()
	return {"ok": true, "player_object_id": player_object_id}


## Declare la cible suivie par l'interface. `-1` efface les canaux de cible.
func set_target(object_id: int) -> void:
	target_object_id = object_id
	if object_id < 0:
		bus.publish("summary_target", "")
		bus.publish("summary_target_hits", 0)
		return
	_push(object_id)


func push_player() -> void:
	if player_object_id >= 0:
		_push(player_object_id)


func get_debug_snapshot() -> Dictionary:
	return {
		"player_object_id": player_object_id,
		"target_object_id": target_object_id,
		"published_updates": published_updates,
		"unpublished_for_lack_of_scale": unpublished_for_lack_of_scale,
	}


# ---------------------------------------------------------------------------

func _on_state_changed(object_id: int, _snapshot: Dictionary) -> void:
	if object_id == player_object_id or object_id == target_object_id:
		_push(object_id)


## Une mort n'efface pas la cible : le joueur doit voir qu'elle est a zero.
func _on_entity_died(object_id: int, _snapshot: Dictionary) -> void:
	if object_id == player_object_id or object_id == target_object_id:
		_push(object_id)


## Un despawn efface les canaux de la cible ; contrairement a une mort, il ne
## reste aucun instantane a afficher a zero.
func _on_entity_removed(object_id: int, _snapshot: Dictionary, _reason: String) -> void:
	if object_id == target_object_id:
		set_target(-1)


func _push(object_id: int) -> void:
	if server == null or bus == null:
		return
	var snapshot: Dictionary = server.snapshot(object_id)
	if snapshot.is_empty():
		return

	var mapping: Dictionary = PLAYER_CHANNELS if object_id == player_object_id else TARGET_CHANNELS
	if object_id == player_object_id:
		# « Merchant » n est que la valeur de previsualisation du XML.
		bus.publish("summary_title", str(snapshot.get("name", "")))
		if server.has_method("experience_report"):
			var progress: Dictionary = server.call("experience_report", object_id) as Dictionary
			var floor := int(progress.get("level_floor", 0))
			var ceiling := int(progress.get("next_level_at", floor))
			var total := int(progress.get("total_experience", floor))
			var percent := 0.0
			if ceiling > floor:
				percent = clampf(float(total - floor) * 100.0 / float(ceiling - floor), 0.0, 100.0)
			bus.publish("summary_exp_coarse", int(round(percent)))
			bus.publish("summary_exp_fine", int(round(fmod(percent * 10.0, 100.0))))
	# P1-100 (2026-09-21, retour utilisateur) : LE JOUEUR EST UNE CIBLE COMME UNE
	# AUTRE. Se cibler soi-meme (buffs de groupe) doit remplir la ligne de cible
	# du summary ; avant, l identite du joueur ne prenait jamais les canaux de cible.
	if object_id == player_object_id and target_object_id == player_object_id:
		for channel: String in TARGET_CHANNELS:
			if not mapping.has(channel):
				mapping = mapping.duplicate()
				mapping[channel] = TARGET_CHANNELS[channel]
	for channel: String in mapping:
		var field: String = mapping[channel]
		if not snapshot.has(field):
			continue
		var value: Variant = snapshot[field]
		# UN CHAMP PRESENT MAIS NUL N'EST PAS UNE VALEUR. `mana_percent` vaut
		# `null` quand le metier n'a pas de pool : le publier ecrirait zero dans
		# une jauge, ce qui se lit comme « vide » au lieu de « sans objet ».
		if value == null:
			continue
		# Les pourcentages partent en entier : l'original n'affiche pas de decimale.
		if field == "health_percent" or field == "mana_percent":
			value = int(round(float(value)))
		if bus.publish(channel, value):
			published_updates += 1

	for field: String in UNSCALED_FIELDS:
		if not snapshot.has(field):
			continue
		# Comptee SEULEMENT si aucune echelle n'a ete trouvee pour elle.
		if field == "mana" and snapshot.get("mana_percent", null) != null:
			continue
		unpublished_for_lack_of_scale += 1
