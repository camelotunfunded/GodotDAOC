extends RefCounted
class_name DaocZoneVegetationStep

## R4 — tranche 2b : la végétation de zone quitte le ZoneViewer.
##
## Les cartes d'herbe — `Grass Vanilla` historique ou `Grass Remaster` piloté par
## `grassmapALT`, validés en P1-20M — sont bâties par `DaocLegacyVisuals`, hors du
## monolithe depuis P1-15C-A. Ce qui restait dans le viewer n'était qu'un relais
## de quatre lignes ; il appartient désormais à cette étape.
##
## L'étape reçoit la carte de hauteurs `hb` et sa résolution `res` : la
## végétation est placée d'après le relief, elle ne peut pas s'en passer. Ce sont
## les mêmes données que le terrain vient de consommer, transmises telles quelles
## et jamais relues.
##
## AUCUN GARDE N'EST AJOUTÉ. Le relais d'origine ne testait aucun drapeau avant
## de construire — `build_vegetation` et `vegetation_render_mode` agissent plus
## loin, dans le module. Introduire ici une condition qui n'existait pas
## changerait le comportement au lieu de déplacer la propriété.
##
## CE QUI RESTE À DÉBRANCHER : `DaocLegacyVisuals` se configure lui-même depuis
## l'hôte par `configure_from_host`. L'étape a changé de propriétaire, le module
## non. C'est le fil suivant à couper, et c'est là que le choix Vanilla/Remaster
## et d'éventuelles densités par niveau de qualité viendront se brancher.


static func build(services: DaocZoneBuildServices, znum: int, origin3: Vector3,
		hb: PackedByteArray, res: int, _settings: Dictionary = {},
		log_enabled: bool = false) -> Dictionary:
	if services == null or not services.usable():
		return {"ok": false, "reason": "services indisponibles", "zone": znum}

	var visuals: RefCounted = services.visual_module()
	if visuals == null:
		return {"ok": false, "reason": "module visuel absent", "zone": znum}
	if not visuals.has_method("build_zone_vegetation"):
		return {"ok": true, "built": false, "reason": "module sans build_zone_vegetation",
			"zone": znum}

	# Une carte de hauteurs vide donnerait une vegetation posee sur rien : on le
	# dit plutot que de laisser le module produire un tapis a plat.
	if hb.is_empty() or res <= 0:
		return {"ok": false, "reason": "carte de hauteurs absente ou resolution nulle",
			"zone": znum, "heightmap_bytes": hb.size(), "resolution": res}

	visuals.call("build_zone_vegetation", znum, origin3, hb, res)
	services.log_step(log_enabled,
		"zone%03d vegetation: batie par DaocZoneVegetationStep (res=%d)" % [znum, res])
	return {"ok": true, "built": true, "zone": znum, "resolution": res}
