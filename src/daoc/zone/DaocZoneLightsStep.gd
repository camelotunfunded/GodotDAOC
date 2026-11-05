extends RefCounted
class_name DaocZoneLightsStep

## R4 — tranche 2a : les lumières de zone quittent le ZoneViewer.
##
## Les 49 lampes de la zone 51 viennent de `lights.csv` et sont bâties par
## `DaocLegacyVisuals`, hors du monolithe depuis P1-15C-A. Ce qui restait dans le
## viewer n'était qu'un relais de quatre lignes ; il appartient désormais à cette
## étape, et l'assembleur ne rappelle plus le viewer pour l'obtenir.
##
## AUCUN GARDE N'EST AJOUTÉ. Le relais d'origine ne testait aucun drapeau avant
## de construire : `legacy_lights_visible` et consorts agissent plus loin, dans
## le module. Introduire ici une condition qui n'existait pas changerait le
## comportement au lieu de déplacer la propriété — et R4 ne déplace que la
## propriété.
##
## CE QUI RESTE À DÉBRANCHER, et c'est écrit pour que ce ne soit pas oublié :
## `DaocLegacyVisuals` se configure lui-même depuis l'hôte, par
## `configure_from_host`. L'étape a changé de propriétaire, le module non. C'est
## le fil suivant à couper, et c'est là que des options de qualité graphique
## par réglage viendront se brancher proprement.


## Construit les lumières d'une zone. Le retour dit pourquoi rien n'a été fait
## le cas échéant : un silence non expliqué serait pire qu'un échec.
static func build(services: DaocZoneBuildServices, znum: int, origin3: Vector3,
		_settings: Dictionary = {}, log_enabled: bool = false) -> Dictionary:
	if services == null or not services.usable():
		return {"ok": false, "reason": "services indisponibles", "zone": znum}

	var visuals: RefCounted = services.visual_module()
	if visuals == null:
		return {"ok": false, "reason": "module visuel absent", "zone": znum}
	if not visuals.has_method("build_zone_lights"):
		return {"ok": true, "built": false, "reason": "module sans build_zone_lights",
			"zone": znum}

	visuals.call("build_zone_lights", znum, origin3)
	services.log_step(log_enabled, "zone%03d lights: bati par DaocZoneLightsStep" % znum)
	return {"ok": true, "built": true, "zone": znum}
