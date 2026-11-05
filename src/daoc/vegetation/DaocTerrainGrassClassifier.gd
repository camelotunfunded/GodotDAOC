extends RefCounted
class_name DaocTerrainGrassClassifier

## Classe les noms du dossier client zones/TerrainTex sans importer ses images.
##
## IMPORTANT : une texture « overall » (tiles <= 1.5) colore une zone entiere
## mais ne decrit pas la matiere sous les pieds. Elle est donc toujours exclue
## au runtime, meme si son nom contient forest/grass. C'est ce qui empeche une
## carte comme ForestSauvage.png de couvrir routes, falaises et villages d'herbe.

const VEGETAL_TOKENS: PackedStringArray = [
	"grass", "clover", "forest_floor", "forestfloor", "undergrowth",
	"groundcover", "moss", "leafy", "leaves", "evergreen", "pineneedle",
	"scrub", "treeroot", " roots", "_roots", "mushroom", "greenbrush",
	"peatbog", "bog_ground", "island_forest", "grnd_mixed",
]

const BARE_OR_HARD_TOKENS: PackedStringArray = [
	"dirt", "soil", "sand", "rock", "stone", "cliff", "cobble", "paved",
	"pebble", "rubble", "mud", "snow", "ice", "lava", "sulfur", "coral",
	"ocean", "river", "water", "crater", "cavewall", "floor", "grid",
	"nukelayer", "fieldsoil", "path",
]


static func classify(texture_name: String, tiles: float = 256.0) -> Dictionary:
	var base := texture_name.get_file().get_basename().to_lower().replace("-", "_")
	if tiles <= 1.5:
		return {"vegetal": false, "reason": "overall_map_tiles_1"}
	for token in VEGETAL_TOKENS:
		if base.contains(token):
			return {"vegetal": true, "reason": "vegetal_token:%s" % token}
	for token in BARE_OR_HARD_TOKENS:
		if base.contains(token):
			return {"vegetal": false, "reason": "bare_or_hard_token:%s" % token}
	return {"vegetal": false, "reason": "not_identified_as_vegetal"}


static func is_vegetal(texture_name: String, tiles: float = 256.0) -> bool:
	return bool(classify(texture_name, tiles).get("vegetal", false))
