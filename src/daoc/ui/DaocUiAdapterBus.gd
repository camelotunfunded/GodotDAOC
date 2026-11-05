extends RefCounted
class_name DaocUiAdapterBus

## P1-21D - les canaux de donnees nommes entre le jeu et l'interface.
##
## Le XML ne porte aucune valeur : un controle declare le NOM du canal qui
## l'alimente (`time_of_day`, `group_health0`) et attend. Ce bus est l'autre
## bout - il detient la valeur courante et previent les controles abonnes.
##
## Choix acte : POUSSEE SUR CHANGEMENT, pas sondage par image. Republier une
## valeur identique ne reveille personne. Sonder 194 canaux a chaque image
## couterait plus cher pour un resultat identique.
##
## Les jauges recoivent un POURCENTAGE. Ce n'est pas une convention interne :
## le format ne possede aucune balise `Max`, `Range` ou `Total`, donc une barre
## ne peut structurellement pas connaitre son maximum.
##
## Le bus n'invente aucun canal. Un controle abonne a un nom jamais publie
## reste a sa valeur d'origine, et le nom apparait dans `subscribed_unknown` -
## un canal muet doit se voir, pas se confondre avec une valeur vide.

## Emis quand un canal change de valeur.
signal channel_changed(channel: String, value: Variant)

## Nom de canal -> valeur courante.
var values: Dictionary = {}

## Noms attendus par au moins un controle mais jamais publies.
var subscribed_unknown: Dictionary = {}

## Abonnements oublies parce que leur proprietaire avait disparu.
var dropped_subscriptions: int = 0

var _subscribers: Dictionary = {}


## Publie une valeur. Sans changement effectif, rien n'est emis.
func publish(channel: String, value: Variant) -> bool:
	var name: String = channel.strip_edges()
	if name == "" or name.to_lower() == "none":
		return false
	if values.has(name) and _same(values[name], value):
		return false
	values[name] = value
	subscribed_unknown.erase(name)
	channel_changed.emit(name, value)
	_deliver(name, value)
	return true


## Publie un lot. Renvoie le nombre de canaux reellement modifies.
func publish_many(batch: Dictionary) -> int:
	var changed: int = 0
	for channel: String in batch:
		if publish(channel, batch[channel]):
			changed += 1
	return changed


## Abonne un appelable a un canal. Il est appele immediatement si le canal
## porte deja une valeur, pour qu'un controle cree en retard ne reste pas vide.
##
## `owner` est le noeud qui porte l'abonnement. Une lambda qui capture un noeud
## LIBERE reste un `Callable` valide : seul le proprietaire permet de savoir
## qu'elle ne doit plus etre appelee. Sans lui, fermer une fenetre laisse ses
## liaisons vivantes et la prochaine valeur publiee ecrit dans le vide.
func subscribe(channel: String, handler: Callable, owner: Object = null) -> void:
	var name: String = channel.strip_edges()
	if name == "" or name.to_lower() == "none" or not handler.is_valid():
		return
	if not _subscribers.has(name):
		_subscribers[name] = [] as Array
	# `has_owner` est fige ICI, tant que l'objet est vivant : une instance
	# liberee se compare EGALE a null, donc `owner != null` ne permet plus de
	# distinguer "sans proprietaire" de "proprietaire disparu".
	(_subscribers[name] as Array).append({
		"handler": handler, "owner": owner, "has_owner": owner != null,
	})
	if values.has(name):
		handler.call(values[name])
	else:
		subscribed_unknown[name] = int(subscribed_unknown.get(name, 0)) + 1


## Appelle les abonnes encore vivants et oublie les autres.
func _deliver(name: String, value: Variant) -> void:
	var entries: Array = _subscribers.get(name, [] as Array) as Array
	var alive: Array = []
	for entry: Dictionary in entries:
		if bool(entry.get("has_owner", false)) and not is_instance_valid(entry["owner"]):
			dropped_subscriptions += 1
			continue
		var handler: Callable = entry["handler"]
		if not handler.is_valid():
			dropped_subscriptions += 1
			continue
		alive.append(entry)
		handler.call(value)
	if alive.size() != entries.size():
		_subscribers[name] = alive


## Oublie tous les abonnements dont le proprietaire a disparu.
func prune() -> int:
	var removed: int = 0
	for name: String in _subscribers.keys():
		var entries: Array = _subscribers[name] as Array
		var alive: Array = []
		for entry: Dictionary in entries:
			if bool(entry.get("has_owner", false)) and not is_instance_valid(entry["owner"]):
				removed += 1
				continue
			alive.append(entry)
		if alive.is_empty():
			_subscribers.erase(name)
		else:
			_subscribers[name] = alive
	dropped_subscriptions += removed
	return removed


## Coupe explicitement les Callables capturant des controles. Necessaire lors
## d'un changement de session et dans les tests : attendre leur invalidation
## laisserait un cycle RefCounted jusqu'a l'arret du moteur.
func clear() -> void:
	_subscribers.clear()
	values.clear()
	subscribed_unknown.clear()


func get_value(channel: String, fallback: Variant = null) -> Variant:
	return values.get(channel.strip_edges(), fallback)


func has_channel(channel: String) -> bool:
	return values.has(channel.strip_edges())


func subscriber_count(channel: String) -> int:
	return (_subscribers.get(channel.strip_edges(), [] as Array) as Array).size()


func get_debug_snapshot() -> Dictionary:
	return {
		"channels": values.size(),
		"subscribed_channels": _subscribers.size(),
		"subscribed_unknown": subscribed_unknown.size(),
		"dropped_subscriptions": dropped_subscriptions,
	}


func _same(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right):
		return false
	return left == right
