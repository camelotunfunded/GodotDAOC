## NifReader — lecteur NIF in-engine, chemin "prebake" (GDScript).
##
## Architecture reprise de godotwind (MIT, (c) 2026 Liho) :
##   en-tete -> version -> liste de blocs -> aiguillage `match` par nom de type
##   -> arbre de blocs en memoire (puis NifConverter -> scene Godot).
##
## Couvre le chemin "ancien NIF" (< 10.x) auquel appartient le DAoC 4.2.2.0 :
##   * pas de table de tailles de blocs -> on NE PEUT PAS sauter un bloc inconnu ;
##   * chaque bloc est precede de son nom de type (chaine prefixee uint32) ;
##   * un bloc inconnu => on s'ARRETE FORT (offset + index) plutot que desync.
##
## NiTriShapeData suit ta disposition CONFIRMEE (NOTE_TERRAIN §11). Les autres
## lecteurs suivent la spec standard 4.2.2.0 (niflib) : HYPOTHESE a valider sur
## tes fichiers. Quand un bloc casse, le rapport pointe l'offset exact a corriger.
##
## Le chemin Gamebryo 10.1.0.0 DAoC est implemente separement : table
## globale de types, pas de block_sizes, layouts dedies NiObjectNET/NiAVObject/
## NiTriShapeData/NiTexturingProperty/NiSourceTexture/NiLODNode.
class_name NifReader
extends RefCounted

var br: NifBinaryReader = null

# Resultat
var version_str: String = ""
var version_int: int = 0
var signature: String = ""           # "NetImmerse" | "Gamebryo"
var blocks: Array[Dictionary] = []   # un Dictionary par bloc, cle "type"
var roots: Array[int] = []           # indices des blocs racines (footer)
var failed: bool = false
var fail_reason: String = ""
var suspect: String = ""
var fail_offset: int = 0
# Offset du debut du bloc en cours (longueur du nom de type).
# Certains scripts de scan l'utilisent pour dumper le bon hexdump.
var fail_block_start: int = 0
# Quand true, les erreurs restent dans fail_reason mais ne polluent pas la console.
# Utilise par DungeonLab pour les audits massifs de NIF, pas par defaut.
var quiet_errors: bool = false
# Les resync/soft-truncate ci-dessous sont des recuperations attendues pour les
# vieux NIF DAoC. On les garde en diagnostic local sans les exposer comme
# warnings Godot au lancement du viewer.
var quiet_recoverable_warnings: bool = true
var recoverable_warnings: Array = []
var _cur_idx: int = -1
var _cur_type: String = ""
var _cur_block_start: int = 0
var _num_blocks: int = 0
var _stop_reading_early: bool = false
var _gb10_skip_to_index: int = -1

# Etat du lecteur Gamebryo 10.1 (table globale des types).
var _gb10_mode: bool = false
var _gb10_user_version: int = 0
var _gb10_type_table: Array[String] = []
var _gb10_type_indices: Array[int] = []
var _gb10_block_type_names: Array[String] = []

# Garde-fous anti-desync
const MAX_VERTICES := 200000
const MAX_TRIANGLES := 400000
const MAX_BLOCKS := 100000
# Plafonds anti-emballement : tout compteur de liste lu du fichier qui depasse
# son plafond = desync -> on abandonne le fichier au lieu de boucler.
const MAX_PROPS := 4096
const MAX_CHILDREN := 65536
const MAX_TEX := 64


func read(path: String) -> bool:
	recoverable_warnings.clear()
	br = NifBinaryReader.new()
	if not br.open(path):
		return _fail("ouverture impossible", 0)

	# --- En-tete : ligne de signature + version ---
	var header_line := br.line_string()
	if header_line.find("NetImmerse File Format") >= 0:
		signature = "NetImmerse"
	elif header_line.find("Gamebryo File Format") >= 0:
		signature = "Gamebryo"
	else:
		return _fail("signature inconnue: '%s'" % header_line, 0)
	version_str = header_line

	version_int = br.u32()  # ex. 0x04020200 pour 4.2.2.0

	# Branche par famille de version.
	if version_int >= 0x0A000000:
		return _read_gamebryo10()

	# --- Chemin ancien NIF (DAoC 4.2.2.0) : num_blocks dans le header ---
	var num_blocks := br.u32()
	_num_blocks = num_blocks
	if num_blocks < 0 or num_blocks > MAX_BLOCKS:
		return _fail("num_blocks absurde (%d)" % num_blocks, br.pos())

	for i in range(num_blocks):
		if br.eof():
			return _fail("fin de fichier prematuree au bloc %d/%d (desync amont). %s" % [i, num_blocks, _trace()], br.pos())
		_cur_block_start = br.pos()
		var type_name := br.sized_string()
		if not _looks_like_type(type_name):
			suspect = str(blocks[blocks.size() - 1].get("type", "?")) if blocks.size() > 0 else "?"
			return _fail("nom de type invalide au bloc %d (='%s') — desync dans le bloc precedent. %s" % [i, type_name.c_escape(), _trace()], br.pos())
		_cur_idx = i
		_cur_type = type_name
		var block := _read_block(type_name, i)
		if failed:
			if br != null:
				br.close()
			return false
		block["type"] = type_name
		block["index"] = i
		# Offset du prefixe de longueur du nom de type, meme repere que le
		# catalogue produit par tools/scan/nif_catalog_scan.py. Permet de
		# confronter ce que le parseur consomme a la taille reelle du bloc.
		block["start_offset"] = _cur_block_start
		blocks.append(block)

		# Certains blocs d'effet/particules 4.x peuvent etre en fin de chaine utile
		# sans layout fiable. Si un lecteur ignorable demande un arret doux, on garde
		# les blocs deja lus pour permettre au converter de sortir la geometrie statique.
		if _stop_reading_early:
			br.close()
			return true

	# --- Footer : racines (guarde) ---
	if not br.eof():
		var num_roots := br.u32()
		if num_roots >= 0 and num_roots < 4096:
			for _r in range(num_roots):
				roots.append(br.i32())

	br.close()
	return true


## Lecteur Gamebryo 10.x (10.1.0.0 principalement).
##
## Layout confirme sur skull.nif / NF_b-fence1.nif :
##   header string + \n
##   version u32 LE            (deja lu dans read() -> version_int)
##   user_version u32          (= 0 pour DAoC 10.1.0.0)
##   num_blocks u32
##   num_block_types u16
##   block_types : n x (u32 len + string)
##   block_type_index : num_blocks x u16
##   num_groups u32
##   groups[]
##   blocs de donnees, sans nom de type et sans block_sizes
##
## NOTE : l'endian byte est ABSENT pour version < 20.0.0.4.
## Pour 10.1.0.0, user_version = 0 donc pas de bs_version non plus.
func _read_gamebryo10() -> bool:
	# Gamebryo 10.1.0.0 DAoC : table globale des types, MAIS PAS de table
	# block_sizes. Les blocs doivent donc etre lus par layout exact, comme les
	# vieux NetImmerse 4.x, sauf que le type de chaque bloc vient du header.
	#
	# Layout confirme sur skull.nif / NF_b-fence1.nif :
	#   user_version u32 (=0)
	#   num_blocks u32
	#   num_block_types u16
	#   block_types[] sized_string
	#   block_type_indices[] u16
	#   num_groups u32
	#   groups[] u32
	#   block_data[] sans nom de type et sans taille de bloc
	#   footer roots
	#
	# Ne JAMAIS lire block_sizes pour 10.1 : ca decale immediatement le flux.
	_gb10_mode = true
	_gb10_user_version = br.u32()

	var num_blocks := br.u32()
	_num_blocks = num_blocks
	if num_blocks < 0 or num_blocks > MAX_BLOCKS:
		return _fail("Gamebryo10: num_blocks absurde (%d)" % num_blocks, br.pos())

	# Champs Bethesda/modernes : non presents sur DAoC 10.1/user_version 0.
	# On garde ces branches pour ne pas relire faux si un fichier plus recent passe ici.
	if _gb10_user_version >= 10:
		br.u32()  # bs_version
	if _gb10_user_version >= 3:
		var export_len := br.u32()
		if export_len > 0 and export_len < 4096:
			br.skip(export_len)
		elif export_len >= 4096:
			return _fail("Gamebryo10: export string absurde (%d)" % export_len, br.pos())

	var num_types := br.u16()
	if num_types <= 0 or num_types > 4096:
		return _fail("Gamebryo10: num_block_types absurde (%d)" % num_types, br.pos())

	_gb10_type_table.clear()
	for _t in range(num_types):
		_gb10_type_table.append(br.sized_string())

	_gb10_type_indices.clear()
	_gb10_block_type_names.clear()
	for i in range(num_blocks):
		var type_idx := br.u16()
		if type_idx < 0 or type_idx >= _gb10_type_table.size():
			return _fail("Gamebryo10: block_type_index hors table (%d) au bloc %d" % [type_idx, i], br.pos())
		_gb10_type_indices.append(type_idx)
		_gb10_block_type_names.append(_gb10_type_table[type_idx])

	# A partir de 20.2.0.5, certains NIF ont une table block_sizes. Pas nos 10.1.
	# Si un fichier moderne arrive ici, on prefere un echec explicite plutot qu'un
	# parse partiel melangeant deux familles de format.
	if version_int >= 0x14020005:
		return _fail("Gamebryo moderne avec block_sizes non pris en charge par ce lecteur DAoC 10.1", br.pos())

	# String table globale : absente en 10.1/user_version 0.
	if version_int >= 0x14010003 or _gb10_user_version >= 11:
		var num_strings := br.u32()
		br.u32()  # max string length
		if num_strings < 0 or num_strings > 65536:
			return _fail("Gamebryo10: string table absurde (%d)" % num_strings, br.pos())
		for _s in range(num_strings):
			var slen := br.u32()
			if slen < 0 or slen > 65536:
				return _fail("Gamebryo10: string length absurde (%d)" % slen, br.pos())
			br.skip(slen)

	# Groups : pour les fichiers DAoC testes, num_groups=0 et c'est immediatement
	# suivi du premier bloc.
	var num_groups := br.u32()
	if num_groups < 0 or num_groups > 65536:
		return _fail("Gamebryo10: num_groups absurde (%d)" % num_groups, br.pos())
	for _g in range(num_groups):
		br.u32()

	var i := 0
	while i < num_blocks:
		if br.eof():
			return _fail("Gamebryo10: fin de fichier prematuree au bloc %d/%d" % [i, num_blocks], br.pos())

		_cur_idx = i
		_cur_type = _gb10_block_type_names[i]
		_cur_block_start = br.pos()
		_gb10_skip_to_index = -1

		if not _looks_like_type(_cur_type):
			return _fail("Gamebryo10: type non-Ni ou invalide '%s' au bloc %d" % [_cur_type, i], br.pos())

		# DAoC's Gamebryo 10.1 writer adds a vendor u32 before every block.
		var vendor_prefix := br.u32()
		var block := _read_block10(_cur_type, i)
		if failed:
			if br != null:
				br.close()
			return false

		block["type"] = _cur_type
		block["index"] = i
		block["start_offset"] = _cur_block_start
		block["daoc_vendor_prefix"] = vendor_prefix
		blocks.append(block)

		# HOTFIX P1-17A2-HF6 : certains clusters FX/particules Gamebryo10
		# (ALTSTONEHall11) sont inutiles pour le preview statique et contiennent des
		# layouts non stabilises. On peut les sauter en bloc vers le prochain type
		# statique fiable, tout en conservant des placeholders pour garder les indices
		# NIF alignes avec les references.
		if _gb10_skip_to_index > i:
			var skip_idx := i + 1
			while skip_idx < _gb10_skip_to_index:
				blocks.append({
					"type": _gb10_block_type_names[skip_idx],
					"index": skip_idx,
					"ignored": true,
					"gb10_soft_skipped_placeholder": true
				})
				skip_idx += 1
			i = _gb10_skip_to_index
			_gb10_skip_to_index = -1
			continue

		# HF7 : certains lecteurs de bloc peuvent choisir une fin douce du fichier.
		# Dans ce cas il ne faut pas tenter l'alignement vers le bloc suivant, puisque
		# br a volontairement ete deplace en fin de flux.
		if _stop_reading_early:
			break

		# En 10.1 il n'y a pas de block_sizes : pour les quelques queues ambiguës
		# (NiTexturingProperty, NiSourceTexture, tres gros NiTriShapeData), on recale
		# uniquement sur le layout attendu du bloc suivant, jamais par scan libre Ni*.
		# `_gb10_align_to_next_block` porte justement ces tests structures. Son appel
		# avait disparu lors de la consolidation HF7, laissant la fonction orpheline :
		# les objets 10.1 dont NiTexturingProperty porte une queue vendeur arrivaient
		# donc quelques octets trop tot dans NiSourceTexture. Si la position courante
		# est deja exacte, l'alignement ne deplace rien.
		# La majorite des blocs 10.1 ont un layout exact et doivent rester lus de
		# facon strictement sequentielle (notamment squelettes et animations). Seuls
		# les blocs vendeur dont la queue varie demandent un realignement structurel.
		var next_declared_type := str(_gb10_block_type_names[i + 1]) if i + 1 < num_blocks else ""
		var needs_alignment := _cur_type in [
			"NiTexturingProperty", "NiSourceTexture", "NiMaterialProperty",
			"NiAlphaProperty", "NiVertexColorProperty", "NiStencilProperty",
			"NiDitherProperty", "NiWireframeProperty", "NiSpecularProperty", "NiShadeProperty",
			"NiTextureEffect", "NiTextureTransformController", "NiFloatData",
		] or bool(block.get("gb10_keyframe_soft_skip", false)) \
			or bool(block.get("gb10_geometry_vendor_id", false)) \
			or bool(block.get("gb10_bad_triangle_indices", false)) \
			or (_cur_type in ["NiTriShapeData", "NiTriStripsData"] and next_declared_type in ["NiTriShape", "NiTriStrips"])
		if needs_alignment and i + 1 < num_blocks:
			if not _gb10_align_to_next_block(i, block):
				if br != null:
					br.close()
				return false
			if _stop_reading_early:
				break
		blocks[blocks.size() - 1]["end_offset"] = br.pos()

		i += 1

	# Footer roots. skull.nif finit par 1 racine/0 ; NF_b-fence1.nif par 0.
	if not br.eof() and br.pos() + 4 <= br.length():
		var num_roots := br.u32()
		if num_roots >= 0 and num_roots < 4096 and br.pos() + num_roots * 4 <= br.length():
			for _r in range(num_roots):
				roots.append(br.i32())

	br.close()
	return true


# --- Aiguillage Gamebryo 10.1 ---
func _read_block10(type_name: String, idx: int) -> Dictionary:
	match type_name:
		"NiNode":
			# Certains exports DAoC terminent un groupe de particules par un
			# NiNode vendeur (ex. Blizzard après embers) dont l'AVObject n'a pas
			# le layout du NiNode statique. La table annonce ensuite un
			# NiStringExtraData puis le vrai bâtiment. Ne pas laisser ce noeud FX
			# désynchroniser toute la géométrie qui suit.
			if _gb10_is_particle_tail_node(idx):
				return _read_unsupported_gamebryo10_soft(type_name, idx)
			return _read_ninode10()
		"NiBillboardNode":
			return _read_billboard_node10()
		"NiLODNode":
			return _read_lodnode10()
		"NiTriShape", "NiTriStrips":
			return _read_trishape10()
		"NiTriShapeData", "NiTriStripsData":
			return _read_trishapedata10()
		"NiMaterialProperty":
			return _read_material10()
		"NiTexturingProperty":
			return _read_texturing10()
		"NiSourceTexture":
			return _read_source_texture10()
		"NiPixelData":
			return _read_pixel_data10(idx)
		"NiZBufferProperty":
			return _read_zbuffer10()
		"NiVertexColorProperty":
			return _read_vertexcolor10()
		"NiAlphaProperty":
			return _read_alpha10()
		# Meme forme pour les quatre : NiProperty + un seul champ Flags (u16).
		# Verifie dans la spec bloc par bloc. NiWireframeProperty etait le
		# dernier blocage mesure sur les casques, apres le correctif du
		# decalage NiSourceTexture.
		"NiDitherProperty", "NiWireframeProperty", "NiSpecularProperty", "NiShadeProperty":
			return _read_simple_property10(type_name)
		"NiStencilProperty":
			return _read_stencil10()
		"NiStringExtraData":
			return _read_string_extra_data10()
		"NiIntegersExtraData":
			return _read_integers_extra_data10()
		"NiStringsExtraData":
			return _read_strings_extra_data(true)
		"NiIntegerExtraData":
			return _read_integer_extra_data(true)
		"NiVisData":
			return _read_vis_data()
		"NiRangeLODData":
			return _read_range_lod_data()
		"NiTextureTransformController":
			return _read_texture_transform_controller()
		"NiGeomMorpherController":
			return _read_geom_morpher_controller10()
		"NiMorphData":
			# Disposition identique en 4.x et 10.1.0.0 : Frame Name est
			# ver1=10.1.0.106 et Legacy Weight ver1=10.1.0.104, donc tous deux
			# absents ici. Le lecteur existant convient.
			return _read_morph_data()
		"NiScreenLODData":
			# Deux layouts vendeur coexistent dans les décors DAoC 10.1. Le LOD
			# écran n'est pas nécessaire au mesh statique : rejoindre le prochain
			# bloc déclaré évite de désynchroniser les bâtiments DR_*.
			return _read_unsupported_gamebryo10_soft(type_name, idx)
		"NiKeyframeController":
			return _read_keyframe_controller10()
		"NiKeyframeData":
			return _read_keyframe_data10()
		"NiSkinInstance":
			return _read_skin_instance10()
		"NiSkinData":
			return _read_skin_data10()
		"NiSkinPartition":
			return _read_skin_partition10()
		"NiAmbientLight", "NiDirectionalLight":
			return _read_light10(false)
		"NiPointLight", "NiSpotLight":
			return _read_light10(true)
		"NiTextureEffect":
			return _read_texture_effect10()
		"NiLightColorController":
			return _read_light_color_controller10()
		"NiPosData":
			return _read_simple_keydata(3)
		"NiFloatData":
			return _read_float_data10()
		"NiParticles", "NiParticlesData", "NiParticleSystemController", "NiParticleBomb", "NiParticleColorModifier", "NiParticleGrowFade", "NiParticleRotation", "NiGravity", "NiColorData":
			return _read_unsupported_gamebryo10_soft(type_name, idx)
		_:
			_fail("Gamebryo10 character block unsupported '%s' at index %d" % [type_name, idx], br.pos())
			return {"parse_status": "UNKNOWN_BLOCKING"}


func _read_objectnet10(b: Dictionary, flexible_controller_prefix: bool = false) -> void:
	# Gamebryo 10.1 DAoC observe :
	#   name sized_string
	#   num_extra_data_list u32 + refs[]
	#   [parfois 1 octet 0 avant controller sur certains NiProperty vides]
	#   controller_ref i32
	b["name"] = br.sized_string()
	var num_extra := br.u32()
	if not _guard(num_extra, MAX_PROPS, "gb10 num_extra_data_list"):
		return
	var extras: Array[int] = []
	for _e in range(num_extra):
		extras.append(br.i32())
	b["extra_data_refs"] = extras

	if flexible_controller_prefix:
		var p := br.pos()
		if p + 5 <= br.length():
			var next_i32 := _gb10_peek_i32(p)
			var prefix := _gb10_peek_u8(p)
			var shifted_i32 := _gb10_peek_i32(p + 1)
			if next_i32 != -1 and (prefix == 0 or prefix == 1) and shifted_i32 == -1:
				b["gb10_controller_prefix"] = br.u8()

	b["controller_ref"] = br.i32()


func _read_avobject10(b: Dictionary) -> void:
	_read_objectnet10(b, false)
	if failed:
		return
	b["flags"] = br.u16()
	var translation := br.vec3()
	var rotation := br.matrix33()
	var scale := br.f32()
	b["nif_transform"] = Transform3D(rotation.scaled(Vector3(scale, scale, scale)), translation)

	var num_props := br.u32()
	if not _guard(num_props, MAX_PROPS, "gb10 num_properties"):
		return
	var props: Array[int] = []
	for _p in range(num_props):
		props.append(br.i32())
	b["property_refs"] = props
	b["collision_object_ref"] = br.i32()


func _read_ninode10() -> Dictionary:
	var b := {}
	_read_avobject10(b)
	if failed:
		return b
	var n_children := br.u32()
	if not _guard(n_children, MAX_CHILDREN, "gb10 num_children"):
		return b
	var children: Array[int] = []
	for _c in range(n_children):
		children.append(br.i32())
	b["children"] = children

	var n_effects := br.u32()
	if not _guard(n_effects, MAX_CHILDREN, "gb10 num_effects"):
		return b
	for _e in range(n_effects):
		br.i32()
	return b


func _read_billboard_node10() -> Dictionary:
	var b := _read_ninode10()
	if not failed:
		b["billboard_mode"] = br.u16()
	return b


## NiDynamicEffect/NiLight dans les fichiers DAoC Gamebryo 10.1.0.0.
## La spec locale nif.xml confirme qu'avant 10.1.0.106 il n'y a pas de
## Switch State, mais bien Num Affected Nodes puis les Ptr correspondants.
func _read_light10(point: bool) -> Dictionary:
	var b := {}
	_read_avobject10(b)
	if failed:
		return b
	var num_affected := br.u32()
	if not _guard(num_affected, MAX_CHILDREN, "gb10 light affected nodes"):
		return b
	var affected: Array[int] = []
	for _i in range(num_affected):
		affected.append(br.i32())
	b["affected_node_refs"] = affected
	b["dimmer"] = br.f32()
	b["ambient"] = _color3()
	b["diffuse"] = _color3()
	b["specular"] = _color3()
	if point:
		b["constant_attenuation"] = br.f32()
		b["linear_attenuation"] = br.f32()
		b["quadratic_attenuation"] = br.f32()
	return b


## NiTextureEffect 10.1.0.0, d'apres le nif.xml local : NiDynamicEffect
## (NiAVObject + affected nodes), puis projection et reference texture.
## L'effet n'est pas necessaire au mesh statique, mais sa taille exacte est
## indispensable pour atteindre les surfaces qui le suivent.
func _read_texture_effect10() -> Dictionary:
	var b := {}
	_read_avobject10(b)
	if failed:
		return b
	var num_affected := br.u32()
	if not _guard(num_affected, MAX_CHILDREN, "gb10 texture effect affected nodes"):
		return b
	var affected: Array[int] = []
	for _index in range(num_affected):
		affected.append(br.i32())
	b["affected_node_refs"] = affected
	b["model_projection_matrix"] = br.matrix33()
	b["model_projection_transform"] = br.vec3()
	b["texture_filtering"] = br.u32()
	b["texture_clamping"] = br.u32()
	b["texture_type"] = br.u32()
	b["coordinate_generation_type"] = br.u32()
	b["source_texture_ref"] = br.i32()
	b["enable_plane"] = br.u8()
	b["plane_normal"] = br.vec3()
	b["plane_constant"] = br.f32()
	b["ps2_l"] = br.u16()
	b["ps2_k"] = br.u16()
	b["parse_status"] = "FULLY_PARSED"
	return b


## NiTimeController (26 octets) + LightColor ushort + NiPosData ref.
## Les champs Interpolator/Manager Controlled arrivent apres 10.1.0.0 et sont
## donc absents des NIF DAoC observes.
func _read_light_color_controller10() -> Dictionary:
	var b := {"parse_status": "FULLY_PARSED"}
	_read_time_controller(b)
	b["target_color"] = br.u16()
	b["data_ref"] = br.i32()
	return b


func _read_lodnode10() -> Dictionary:
	var b := _read_ninode10()
	if failed:
		return b
	# DAoC Gamebryo 10.1 observe sur NF_b-fence1 : queue de 10 octets :
	#   active_child i32 (=1)
	#   pad/unknown u16
	#   screen_lod_data_ref u16 (=37)
	#   pad/unknown u16
	# La logique LOD n'est pas necessaire pour le rendu statique : les enfants sont
	# deja dans children. On conserve tout de meme la ref LOD pour diagnostic.
	if br.pos() + 10 <= br.length():
		b["active_child"] = br.i32()
		br.u16()
		b["screen_lod_data_ref"] = br.u16()
		br.u16()
	return b


func _read_trishape10() -> Dictionary:
	var b := {}
	_read_avobject10(b)
	if failed:
		return b
	b["data_ref"] = br.i32()
	b["skin_instance_ref"] = br.i32()
	b["has_shader"] = br.boolb()
	if bool(b["has_shader"]):
		b["shader_name"] = br.sized_string()
		b["shader_unknown"] = br.u32()
	return b


func _read_material10() -> Dictionary:
	var b := {}
	_read_objectnet10(b, true)
	if failed:
		return b
	# Pas de flags u16 ici en 10.1 DAoC. Les couleurs suivent directement.
	b["ambient"] = _color3()
	b["diffuse"] = _color3()
	b["specular"] = _color3()
	b["emissive"] = _color3()
	b["glossiness"] = br.f32()
	b["alpha"] = br.f32()
	return b


func _read_zbuffer10() -> Dictionary:
	var b := {}
	_read_objectnet10(b, false)
	if failed:
		return b
	b["flags"] = br.u16()
	br.u32()  # Function / ZCompareMode
	return b


func _read_vertexcolor10() -> Dictionary:
	var b := {}
	_read_objectnet10(b, false)
	if failed:
		return b
	b["flags"] = br.u16()
	br.u32()  # Vertex Mode
	br.u32()  # Lighting Mode
	return b


func _read_texturing10() -> Dictionary:
	var b := {}
	_read_objectnet10(b, true)
	if failed:
		return b

	# Gamebryo 10.1 DAoC existe au moins en deux variantes pour
	# NiTexturingProperty :
	#   A) apply_mode u32 + texture_count u32
	#   B) flags u16 + apply_mode u32 + texture_count u32
	# HF6 : bdung1hall1_trans_mine.nif casse avec texture_count=1280 si on force A.
	# On tente donc A, puis B, puis un saut doux du bloc si les deux echouent.
	var payload_start := br.pos()
	b["gb10_texturing_layout"] = "apply_count"
	b["apply_mode"] = br.u32()
	var tex_count := br.u32()
	if tex_count < 0 or tex_count > MAX_TEX:
		br.seek(payload_start)
		if br.pos() + 10 <= br.length():
			b["flags"] = br.u16()
			b["apply_mode"] = br.u32()
			tex_count = br.u32()
			b["gb10_texturing_layout"] = "flags_apply_count"
	if tex_count < 0 or tex_count > MAX_TEX:
		b["ignored"] = true
		b["gb10_texturing_soft_skip"] = true
		b["gb10_texturing_error"] = "texture_count aberrant (%d, max %d)" % [tex_count, MAX_TEX]
		b["base_source_ref"] = -1
		br.seek(payload_start)
		return b

	b["texture_count"] = tex_count
	var base_source := -1
	for t in range(tex_count):
		if br.pos() + 1 > br.length():
			b["ignored"] = true
			b["gb10_texturing_soft_skip"] = true
			b["gb10_texturing_error"] = "fin prematuree avant slot texture %d" % t
			br.seek(payload_start)
			return b
		var has_tex := br.boolb()
		if has_tex:
			if br.pos() + 18 > br.length():
				b["ignored"] = true
				b["gb10_texturing_soft_skip"] = true
				b["gb10_texturing_error"] = "fin prematuree dans slot texture %d" % t
				br.seek(payload_start)
				return b
			var src := br.i32()
			br.u32()  # clamp mode
			br.u32()  # filter mode
			br.u32()  # uv set
			br.u16()  # ps2 L
			br.u16()  # ps2 K
			# Variante 10.1 : certains fichiers ont un ushort supplementaire apres K.
			# On ne le lit pas aveuglement ici : l'alignement vers le bloc suivant le
			# corrigera si necessaire, comme pour les autres queues 10.1.
			if t == 0:
				base_source = src
	b["base_source_ref"] = base_source
	return b

## Decide s'il faut sauter les 5 octets vendeur avant `use_external`.
## Compare les deux lectures possibles et retient celle dont le nom de fichier
## est plausible. Aucune supposition : c'est le contenu qui tranche.
func _gb10_source_texture_gap_needed() -> bool:
	return _gb10_source_texture_gap() > 0


## P1-118 — l'écart ne vaut pas toujours 5. Mesuré sur NF_b-fence1.nif : son
## NiTexturingProperty porte un u16 de plus par couche PLUS le compteur de
## textures de shader (10.0.1.0+), que `_read_texturing10` ne lit pas ; le
## NiSourceTexture suivant commence alors 8 octets trop tôt, son nom
## (`A_oldwood.dds`) était perdu et la barrière rendue blanche. On garde la
## règle du contenu : le premier décalage qui tombe sur un nom plausible.
func _gb10_source_texture_gap() -> int:
	var p := br.pos()
	for delta in [0, 5, 8, 4, 2, 6, 10, 12, 13]:
		if _gb10_plausible_texture_name_at(p + int(delta)):
			return int(delta)
	return 0


## A l'offset donne : un octet use_external, puis si == 1 une chaine dimensionnee
## qui doit ressembler a un nom de fichier de texture.
func _gb10_plausible_texture_name_at(p: int) -> bool:
	if p + 5 > br.length():
		return false
	var flag := _gb10_peek_u8(p)
	if flag != 1:
		return false
	var n := _gb10_peek_i32(p + 1)
	if n < 4 or n > 128 or p + 5 + n > br.length():
		return false
	var here := br.pos()
	br.seek(p + 5)
	var name := br.read_bytes(n).get_string_from_ascii()
	br.seek(here)
	if name.length() != n:
		return false
	var low := name.to_lower()
	# P1-118 : albhelm01_ava_f.nif nomme sa texture « B_plt1_helm1.nif » (erreur
	# de données Mythic, le NIF breton dit .tga). Le radical suffit au registre.
	for ext in [".dds", ".tga", ".bmp", ".png", ".nif"]:
		if low.ends_with(str(ext)):
			return true
	return false


func _gb10_plausible_sized_texture_name_at(p: int) -> bool:
	if p < 0 or p + 4 > br.length():
		return false
	var n := _gb10_peek_i32(p)
	if n < 4 or n > 260 or p + 4 + n > br.length():
		return false
	var here := br.pos()
	br.seek(p + 4)
	var name := br.read_bytes(n).get_string_from_ascii().to_lower()
	br.seek(here)
	for extension in [".dds", ".tga", ".bmp", ".png"]:
		if name.ends_with(str(extension)):
			return true
	return false


func _read_source_texture10() -> Dictionary:
	var b := {}
	# Correction fence/skull : NiSourceTexture 10.1 DAoC HERITE bien de
	# NiObjectNET. L'ancienne version lisait le debut comme "pre_ref + use_external",
	# ce qui faisait accepter de faux debuts de blocs dans les noms de textures et
	# decalait ensuite NF_b-fence1/NF_b-fence3 jusqu'au NiTriShapeData suivant.
	_read_objectnet10(b, false)
	if failed:
		return b

	# Jalon casques : dans une partie des fichiers, `use_external` ne suit pas
	# immediatement NiObjectNET. Mesure sur ADR_Dragonsworn_Helm_Heavy_AE_f.nif,
	# lu SANS resynchronisation donc dont les offsets font foi :
	#   bloc a 0x59D, NiObjectNET consomme 16 octets -> 0x5AD
	#   or use_external est en 0x5B2, car la longueur qui suit vaut 22, soit
	#   exactement celle de "cthLegs01_SS_Min_M.dds"
	# Il manque 5 octets, que la spec ne prevoit pas (NiTexture est vide).
	#
	# On ne devine pas : on desambiguise sur le CONTENU. Des deux lectures
	# possibles, on garde celle ou le nom de fichier qui suit est plausible.
	var gap := _gb10_source_texture_gap()
	if gap > 0:
		br.skip(gap)
		b["gb10_source_texture_vendor_gap"] = gap

	var use_external := br.u8()
	b["use_external"] = use_external
	if use_external == 1:
		b["file_name"] = br.sized_string()
		b["unknown_texture_ref"] = br.i32()
	else:
		# Les clients DAoC portent deux variantes sous le meme en-tete 10.1 : la
		# forme standard `nom + ref NiPixelData`, et la forme vendeur historique
		# `octet + ref`. Le contenu tranche, comme pour le gap externe ci-dessus.
		if _gb10_plausible_sized_texture_name_at(br.pos()):
			b["file_name"] = br.sized_string()
			b["pixel_data_ref"] = br.i32()
			b["gb10_internal_texture_layout"] = "named"
		else:
			b["file_name"] = ""
			b["internal_present"] = br.u8()
			b["pixel_data_ref"] = br.i32()
			b["gb10_internal_texture_layout"] = "vendor_legacy"

	br.u32()  # pixel layout
	br.u32()  # use mipmaps
	br.u32()  # alpha format
	br.u8()   # is static
	return b


## NiPixelData 10.1.0.0. Les octets de l'image embarquee ne sont pas exposes au
## convertisseur (les PNG runtime existent deja), mais ils doivent etre sautes
## exactement afin de poursuivre vers la geometrie.
func _read_pixel_data10(idx: int) -> Dictionary:
	# Plusieurs exports DAoC divergent du NiPixelFormat canonique sous le meme
	# numero 10.1. Le contenu embarque n'est pas consomme par Godot (le PNG runtime
	# est la source d'affichage). On saute tout le paquet de rendu associe jusqu'a
	# la prochaine geometrie declaree par la table de types ; cela evite de prendre
	# les motifs binaires des pixels pour de faux NiProperty.
	var out := {"parse_status": "STRUCTURE_ONLY", "ignored": true, "gb10_pixel_data_soft_skip": true}
	var target_index := idx + 1
	while target_index < _gb10_block_type_names.size() and str(_gb10_block_type_names[target_index]) not in ["NiTriShape", "NiTriStrips", "NiTriShapeData", "NiTriStripsData", "NiNode", "NiBillboardNode"]:
		target_index += 1
	if target_index >= _gb10_block_type_names.size():
		_stop_reading_early = true
		br.seek(br.length())
		return out
	var target_type := str(_gb10_block_type_names[target_index])
	var start := br.pos()
	for position in range(start + 1, br.length()):
		var looks := _gb10_block_looks_like(target_type, position)
		if not looks and target_type in ["NiNode", "NiBillboardNode"]:
			looks = _gb10_node_looks_like(position, false, true)
		if looks:
			br.seek(position)
			_gb10_skip_to_index = target_index
			out["soft_skipped_to_type"] = target_type
			out["soft_skipped_to_index"] = target_index
			out["skipped_bytes"] = position - start
			return out
	_stop_reading_early = true
	br.seek(br.length())
	return out


func _read_float_data10() -> Dictionary:
	var b := {"parse_status": "FULLY_PARSED"}
	var count := br.u32()
	if not _guard(count, MAX_VERTICES, "gb10 float keys"):
		return b
	b["num_keys"] = count
	b["keys"] = []
	if count > 0:
		var interpolation := br.u32()
		b["interpolation"] = interpolation
		b["keys"] = _read_key_group_values(count, interpolation, 1)
	return b


func _read_alpha10() -> Dictionary:
	var b := {}
	_read_objectnet10(b, false)
	if failed:
		return b
	b["flags"] = br.u16()
	br.u8() # threshold
	return b


func _read_stencil10() -> Dictionary:
	var b := {}
	# Gamebryo 10.1 DAoC : on garde ce bloc non critique en mode robuste.
	# On lit seulement le NiObjectNET, puis l'alignement vers le bloc suivant saute
	# la queue exacte du stencil. C'est volontaire : le rendu statique n'a pas besoin
	# de la logique stencil, et les variantes de layout sont plus risquées que le skip.
	_read_objectnet10(b, false)
	if failed:
		return b
	b["ignored"] = true
	b["gb10_stencil_soft_skip"] = true
	return b


func _read_simple_property10(type_name: String) -> Dictionary:
	var b := {}
	b["gb10_simple_property"] = type_name
	_read_objectnet10(b, false)
	if not failed:
		b["flags"] = br.u16()
	return b


# Gamebryo 10.1 DAoC : NiStringExtraData ne suit pas le vieux layout 4.x
# `next_ref + bytes_remaining + string`. Les fichiers de donjon Stonehenge
# Barrows montrent : next/old ref, nom, puis chaîne utile. Sans ce bloc,
# ALTSTONEHall11 s'arretait juste apres le NiNode contenant extra_data_refs=[6].
func _read_string_extra_data10() -> Dictionary:
	# CORRIGE (jalon NIF_PARSER_DESYNC_ROOT_CAUSE).
	#
	# L'ancienne version lisait un `next_extra_data_ref` (i32) AVANT le nom.
	# La spec canonique est formelle : NiExtraData.`Next Extra Data` porte
	# ver2="4.2.2.0", donc il est ABSENT a partir de 10.0.1.0. Seul `Name`
	# subsiste. `Bytes Remaining` de NiStringExtraData est lui aussi ver2="4.2.2.0".
	#
	# Disposition 10.1.0.0 : Name (SizedString) + String Data (SizedString).
	# C'est exactement ce que fait deja _read_integers_extra_data10, verifie
	# contre mminotaurm.nif : les deux fonctions sont desormais coherentes.
	#
	# Mesure avant correction, sur 120 fichiers 10.1.0.0 : completion 31.1 %,
	# aucun fichier complet, et 9054 erreurs "longueur de chaine absurde"
	# emises depuis cette fonction. Voir reports/parser_health/.
	var b := {"parse_status": "FULLY_PARSED"}
	b["name"] = br.sized_string()
	b["string_data"] = br.sized_string()
	return b


# Gamebryo 10.1 standard layout confirmed against NifSkope's nif.xml and
# mminotaurm.nif: sized name, uint count, then count uint values.
func _read_integers_extra_data10() -> Dictionary:
	var b := {"parse_status": "FULLY_PARSED"}
	b["name"] = br.sized_string()
	var count := br.u32()
	if not _guard(count, MAX_CHILDREN, "gb10 integer extra data count"):
		return b
	var values: Array[int] = []
	for _i in range(count):
		values.append(br.u32())
	b["num_integers"] = count
	b["data"] = values
	return b


func _read_keyframe_controller10() -> Dictionary:
	var b := {}
	# Exact NiTimeController + NiKeyframeController layout for 10.1.0.0.
	b["next_controller_ref"] = br.i32()
	b["ctrl_flags"] = br.u16()
	b["frequency"] = br.f32()
	b["phase"] = br.f32()
	b["start_time"] = br.f32()
	b["stop_time"] = br.f32()
	b["target_ref"] = br.i32()
	b["data_ref"] = br.i32()
	b["parse_status"] = "STRUCTURE_ONLY"
	return b


func _read_keyframe_data10() -> Dictionary:
	var b := {"parse_status": "FULLY_PARSED"}
	var payload_start := br.pos()
	var num_rotation_keys := br.u32()
	if num_rotation_keys < 0 or num_rotation_keys > MAX_VERTICES:
		return _gb10_soft_skip_keyframe_data(b, payload_start, "rotation count %d" % num_rotation_keys)
	b["num_rotation_keys"] = num_rotation_keys
	var rotation_type := 1
	if num_rotation_keys > 0:
		rotation_type = br.u32()
	b["rotation_type"] = rotation_type
	if rotation_type != 4:
		b["rotation_keys"] = _read_key_group_values(num_rotation_keys, rotation_type, 4)
	else:
		b["xyz_order"] = br.f32()
		var axes: Array = []
		for _axis in range(3):
			var axis_count := br.u32()
			if axis_count < 0 or axis_count > MAX_VERTICES:
				return _gb10_soft_skip_keyframe_data(b, payload_start, "xyz count %d" % axis_count)
			var axis := {"count": axis_count, "interpolation": 0, "keys": []}
			if axis_count > 0:
				var axis_type := br.u32()
				axis["interpolation"] = axis_type
				axis["keys"] = _read_key_group_values(axis_count, axis_type, 1)
			axes.append(axis)
		b["xyz_rotation_keys"] = axes

	var translation_count := br.u32()
	if translation_count < 0 or translation_count > MAX_VERTICES:
		return _gb10_soft_skip_keyframe_data(b, payload_start, "translation count %d" % translation_count)
	b["num_translation_keys"] = translation_count
	b["translation_keys"] = []
	if translation_count > 0:
		var translation_type := br.u32()
		b["translation_type"] = translation_type
		b["translation_keys"] = _read_key_group_values(translation_count, translation_type, 3)

	var scale_count := br.u32()
	if scale_count < 0 or scale_count > MAX_VERTICES:
		return _gb10_soft_skip_keyframe_data(b, payload_start, "scale count %d" % scale_count)
	b["num_scale_keys"] = scale_count
	b["scale_keys"] = []
	if scale_count > 0:
		var scale_type := br.u32()
		b["scale_type"] = scale_type
		b["scale_keys"] = _read_key_group_values(scale_count, scale_type, 1)
	return b


func _gb10_soft_skip_keyframe_data(b: Dictionary, payload_start: int, reason: String) -> Dictionary:
	b["parse_status"] = "STRUCTURE_ONLY"
	b["ignored"] = true
	b["gb10_keyframe_soft_skip"] = true
	b["gb10_keyframe_error"] = reason
	br.seek(payload_start)
	return b


func _skip_quaternion_key10(interpolation: int) -> void:
	br.f32()
	for _component in range(4):
		br.f32()
	if interpolation == 3:
		br.f32(); br.f32(); br.f32()


func _skip_key_group10(value_width: int) -> void:
	var count := br.u32()
	if not _guard(count, MAX_VERTICES, "gb10 key group"):
		return
	if count == 0:
		return
	var interpolation := br.u32()
	for _key in range(count):
		br.f32()
		for _value in range(value_width):
			br.f32()
		if interpolation == 2:
			for _forward in range(value_width):
				br.f32()
			for _backward in range(value_width):
				br.f32()
		elif interpolation == 3:
			br.f32(); br.f32(); br.f32()


func _read_skin_instance10() -> Dictionary:
	var b := {"parse_status": "FULLY_PARSED"}
	b["data_ref"] = br.i32()
	b["skeleton_root_ref"] = br.i32()
	var num_bones := br.u32()
	if not _guard(num_bones, MAX_CHILDREN, "gb10 skin instance bones"):
		return b
	var bones: Array[int] = []
	for _i in range(num_bones):
		bones.append(br.i32())
	b["num_bones"] = num_bones
	b["bone_refs"] = bones
	return b


func _read_nif_transform10() -> Dictionary:
	var rotation := br.matrix33()
	var translation := br.vec3()
	var scale := br.f32()
	return {
		"rotation": rotation,
		"translation": translation,
		"scale": scale,
		"transform": Transform3D(rotation.scaled(Vector3(scale, scale, scale)), translation)
	}


func _read_skin_data10() -> Dictionary:
	var b := {"parse_status": "FULLY_PARSED"}
	b["skin_transform"] = _read_nif_transform10()
	var num_bones := br.u32()
	if not _guard(num_bones, MAX_CHILDREN, "gb10 skin data bones"):
		return b
	b["num_bones"] = num_bones
	b["skin_partition_ref"] = br.i32()
	var has_vertex_weights := br.boolb()
	b["has_vertex_weights"] = has_vertex_weights
	var bone_list: Array = []
	for bone_index in range(num_bones):
		var bone := {
			"bone_index": bone_index,
			"skin_transform": _read_nif_transform10(),
			"bounding_center": br.vec3(),
			"bounding_radius": br.f32()
		}
		var num_vertices := br.u16()
		if not _guard(num_vertices, MAX_VERTICES, "gb10 skin bone vertices"):
			return b
		bone["num_vertices"] = num_vertices
		var weights: Array = []
		if has_vertex_weights:
			for _weight in range(num_vertices):
				weights.append({"vertex": br.u16(), "weight": br.f32()})
		bone["vertex_weights"] = weights
		bone_list.append(bone)
	b["bone_list"] = bone_list
	return b


func _read_skin_partition10() -> Dictionary:
	var b := {"parse_status": "FULLY_PARSED"}
	var num_partitions := br.u32()
	if not _guard(num_partitions, MAX_CHILDREN, "gb10 skin partitions"):
		return b
	var partitions: Array = []
	for partition_index in range(num_partitions):
		var part := {
			"partition_index": partition_index,
			"num_vertices": br.u16(),
			"num_triangles": br.u16(),
			"num_bones": br.u16(),
			"num_strips": br.u16(),
			"weights_per_vertex": br.u16()
		}
		if not _validate_partition_counts(part):
			return b
		var bones: Array[int] = []
		for _bone in range(int(part["num_bones"])):
			bones.append(br.u16())
		part["bones"] = bones
		var has_vertex_map := br.boolb()
		part["has_vertex_map"] = has_vertex_map
		var vertex_map: Array[int] = []
		if has_vertex_map:
			for _vertex in range(int(part["num_vertices"])):
				vertex_map.append(br.u16())
		part["vertex_map"] = vertex_map
		var has_vertex_weights := br.boolb()
		part["has_vertex_weights"] = has_vertex_weights
		var vertex_weights: Array = []
		if has_vertex_weights:
			for _vertex in range(int(part["num_vertices"])):
				var row: Array[float] = []
				for _weight in range(int(part["weights_per_vertex"])):
					row.append(br.f32())
				vertex_weights.append(row)
		part["vertex_weights"] = vertex_weights
		var strip_lengths: Array[int] = []
		for _strip in range(int(part["num_strips"])):
			strip_lengths.append(br.u16())
		part["strip_lengths"] = strip_lengths
		var has_faces := br.boolb()
		part["has_faces"] = has_faces
		var strips: Array = []
		var triangles: Array = []
		if has_faces and int(part["num_strips"]) > 0:
			for strip_length in strip_lengths:
				var strip: Array[int] = []
				for _index in range(strip_length):
					strip.append(br.u16())
				strips.append(strip)
		elif has_faces:
			for _triangle in range(int(part["num_triangles"])):
				triangles.append([br.u16(), br.u16(), br.u16()])
		part["strips"] = strips
		part["triangles"] = triangles
		var has_bone_indices := br.boolb()
		part["has_bone_indices"] = has_bone_indices
		var bone_indices: Array = []
		if has_bone_indices:
			for _vertex in range(int(part["num_vertices"])):
				var row: Array[int] = []
				for _weight in range(int(part["weights_per_vertex"])):
					row.append(br.u8())
				bone_indices.append(row)
		part["bone_indices"] = bone_indices
		partitions.append(part)
	b["num_partitions"] = num_partitions
	b["partitions"] = partitions
	return b


func _validate_partition_counts(part: Dictionary) -> bool:
	for key in ["num_vertices", "num_triangles", "num_bones", "num_strips", "weights_per_vertex"]:
		var limit := MAX_TRIANGLES if key == "num_triangles" else MAX_VERTICES
		if int(part[key]) < 0 or int(part[key]) > limit:
			_fail("gb10 skin partition %s invalid (%d)" % [key, int(part[key])], br.pos())
			return false
	if int(part["weights_per_vertex"]) > 32:
		_fail("gb10 weights_per_vertex invalid (%d)" % int(part["weights_per_vertex"]), br.pos())
		return false
	return true


# Fallback GB10 pour blocs d'animation/FX non indispensables au rendu statique.
# Les NIF 10.1 DAoC n'ont pas de block_sizes : on ne peut pas faire un skip
# aveugle, mais on connait le type du bloc suivant via la table globale. On
# scanne donc jusqu'au prochain bloc plausible, puis on continue afin de garder
# la geometrie statique plus loin dans le fichier.
func _read_unsupported_gamebryo10_soft(type_name: String, idx: int) -> Dictionary:
	var b := {
		"ignored": true,
		"gb10_unsupported_type": type_name,
	}
	var start := br.pos()
	if idx >= _num_blocks - 1:
		b["soft_truncated"] = true
		b["skipped_bytes"] = br.length() - start
		_stop_reading_early = true
		br.seek(br.length())
		return b

	# HOTFIX P1-17A2-HF6 : les clusters particules/FX de Gamebryo10 sont hors
	# objectif pour DungeonLab statique. Scanner bloc par bloc vers le prochain
	# type FX est trop risqué : les contrôleurs courts ressemblent facilement à
	# des faux débuts de blocs et décalent ensuite NiDither/NiVertexColor. On
	# saute donc tout le cluster jusqu'au prochain bloc statique déclaré.
	var static_target_idx := _gb10_next_static_resume_index(idx)
	if static_target_idx > idx + 1:
		var static_target_type := _gb10_block_type_names[static_target_idx]
		var static_limit := br.length()
		for p in range(start + 1, static_limit):
			var looks_static := _gb10_block_looks_like(static_target_type, p)
			if not looks_static and static_target_type == "NiNode":
				looks_static = _gb10_node_looks_like(p, false, true)
			if looks_static:
				br.seek(p)
				_gb10_skip_to_index = static_target_idx
				b["soft_skipped_to_type"] = static_target_type
				b["soft_skipped_to_index"] = static_target_idx
				b["skipped_block_count"] = static_target_idx - idx - 1
				b["skipped_bytes"] = p - start
				return b

	var next_type := _gb10_block_type_names[idx + 1]
	var limit := br.length()
	# Fallback historique : pour un type inconnu isole, on tente encore de rejoindre
	# le type suivant immediat. Les types FX connus passent normalement par le saut
	# de cluster ci-dessus.
	for p in range(start + 1, limit):
		if _gb10_block_looks_like(next_type, p):
			br.seek(p)
			b["soft_skipped_to_type"] = next_type
			b["skipped_bytes"] = p - start
			return b

	_recoverable_warning("NIF GB10 SOFT-TRUNCATE: bloc '%s' illisible @0x%X ; conservation des blocs deja lus" % [type_name, start])
	b["soft_truncated"] = true
	b["skipped_bytes"] = br.length() - start
	_stop_reading_early = true
	br.seek(br.length())
	return b


func _gb10_is_particle_fx_type(type_name: String) -> bool:
	match type_name:
		"NiParticles", "NiParticlesData", "NiParticleSystemController", "NiParticleBomb", "NiParticleColorModifier", "NiParticleGrowFade", "NiParticleRotation", "NiGravity", "NiColorData":
			return true
		_:
			return false


func _gb10_is_structural_resume_type(type_name: String) -> bool:
	match type_name:
		"NiNode", "NiLODNode", "NiTriShape", "NiTriStrips":
			return true
		_:
			return false


func _gb10_is_static_resume_type(type_name: String) -> bool:
	if _gb10_is_structural_resume_type(type_name):
		return true
	match type_name:
		"NiTriShapeData", "NiTriStripsData", "NiMaterialProperty", "NiTexturingProperty", "NiSourceTexture", "NiZBufferProperty", "NiVertexColorProperty", "NiAlphaProperty", "NiDitherProperty", "NiStencilProperty", "NiStringExtraData":
			return true
		_:
			return false


func _gb10_is_particle_tail_node(idx: int) -> bool:
	if idx <= 0 or idx + 2 >= _gb10_block_type_names.size() or blocks.is_empty():
		return false
	if _gb10_block_type_names[idx + 1] != "NiStringExtraData":
		return false
	if not _gb10_is_structural_resume_type(_gb10_block_type_names[idx + 2]):
		return false
	var previous: Dictionary = blocks.back()
	var previous_name := str(previous.get("name", "")).to_lower()
	return previous_name.contains("ember") or previous_name.contains("smoke") \
		or previous_name.contains("bonfire") or previous_name.contains("particle")


func _gb10_next_static_resume_index(idx: int) -> int:
	if _gb10_is_particle_tail_node(idx):
		# Le premier enfant racine suivant peut encore être le conteneur du
		# même effet (Anim006 dans DR_Alb_tavern). Si celui-ci est collé au
		# tail, reprendre à l'enfant racine d'après, qui est le décor statique.
		for parsed: Dictionary in blocks:
			var following: Array[int] = []
			for child_ref in parsed.get("children", []):
				if int(child_ref) > idx:
					following.append(int(child_ref))
			if following.size() >= 2 and following[0] <= idx + 2:
				return following[1]
		return idx + 2
	var particle_cluster := _gb10_is_particle_fx_type(_gb10_block_type_names[idx])
	var j := idx + 1
	while j < _gb10_block_type_names.size():
		var t := _gb10_block_type_names[j]
		if particle_cluster:
			if _gb10_is_structural_resume_type(t):
				return j
		elif _gb10_is_static_resume_type(t):
			return j
		j += 1
	return -1


func _read_trishapedata10() -> Dictionary:
	var b := {}
	# Deux variantes coexistent sous 10.1 : la plus recente ajoute un unknown_id
	# u32 avant num_vertices. On tranche sur la plausibilite de tout le prefixe
	# geometrie ; les anciens fichiers restent donc strictement inchanges.
	var payload_start := br.pos()
	var is_strips := _cur_type == "NiTriStripsData"
	if not _gb10_geometry_prefix_payload_looks_like(payload_start, false, is_strips) and _gb10_geometry_prefix_payload_looks_like(payload_start, true, is_strips):
		b["unknown_id"] = br.u32()
		b["gb10_geometry_vendor_id"] = true
	var num_vertices := br.u16()
	b["num_vertices"] = num_vertices
	if num_vertices > MAX_VERTICES:
		_fail("gb10 num_vertices=%d > max — desync probable" % num_vertices, br.pos())
		return b

	b["keep_flags"] = br.u8()
	b["compress_flags"] = br.u8()

	var verts := PackedVector3Array()
	if br.boolb():
		verts.resize(num_vertices)
		for i in range(num_vertices):
			verts[i] = br.vec3()
	b["vertices"] = verts

	# En 10.1 DAoC, ce champ encode le nombre de jeux UV dans les bits bas.
	var vector_flags := br.u16()
	b["vector_flags"] = vector_flags

	var normals := PackedVector3Array()
	if br.boolb():
		normals.resize(num_vertices)
		for i in range(num_vertices):
			normals[i] = br.vec3()
	b["normals"] = normals

	# Tangentes/bitangentes si presentes. Non observees sur skull/NF_b-fence1,
	# mais on les saute pour rester aligne.
	if (vector_flags & 0x1000) != 0:
		for _i in range(num_vertices):
			br.vec3()
		for _i in range(num_vertices):
			br.vec3()

	b["center"] = br.vec3()
	b["radius"] = br.f32()

	var colors := PackedColorArray()
	if br.boolb():
		colors.resize(num_vertices)
		for i in range(num_vertices):
			colors[i] = br.color4()
	b["colors"] = colors

	var num_uv := vector_flags & 0x3F
	if num_uv > MAX_TEX:
		_fail("gb10 num_uv_sets=%d > max — desync probable" % num_uv, br.pos())
		return b
	var uvs := PackedVector2Array()
	for s in range(num_uv):
		if s == 0:
			uvs.resize(num_vertices)
			for i in range(num_vertices):
				uvs[i] = Vector2(br.f32(), br.f32())
		else:
			for i in range(num_vertices):
				br.f32(); br.f32()
	b["uvs"] = uvs

	b["consistency_flags"] = br.u16()
	if _cur_type == "NiTriStripsData":
		return _read_tristrips_tail10(b, num_vertices)
	var num_triangles := br.u16()
	if num_triangles > MAX_TRIANGLES:
		_fail("gb10 num_triangles=%d > max — desync probable" % num_triangles, br.pos())
		return b
	var num_triangle_points := br.u32()  # normalement num_triangles * 3
	b["num_triangle_points"] = num_triangle_points

	# Gamebryo 10.1 ajoute un bool "has_triangles" avant le tableau d'indices.
	# Le bug precedent lisait ce byte comme le premier octet du premier index :
	# tous les indices etaient alors decales d'un octet, ce qui produisait de
	# grands triangles/glitches verticaux dans Godot.
	var has_triangles := br.boolb()
	b["has_triangles"] = has_triangles

	var indices := PackedInt32Array()
	if has_triangles:
		indices.resize(num_triangles * 3)
		for t in range(num_triangles):
			var i0 := br.u16()
			var i1 := br.u16()
			var i2 := br.u16()
			if i0 >= num_vertices or i1 >= num_vertices or i2 >= num_vertices:
				return _gb10_soft_trishapedata_bad_indices(b, num_vertices, t, i0, i1, i2)
			indices[t * 3 + 0] = i0
			indices[t * 3 + 1] = i1
			indices[t * 3 + 2] = i2
	b["indices"] = indices

	var num_match := br.u16()
	if not _guard(num_match, MAX_VERTICES, "gb10 num_match_groups"):
		return b
	for _g in range(num_match):
		var cnt := br.u16()
		if not _guard(cnt, MAX_VERTICES, "gb10 match_group_count"):
			return b
		for _k in range(cnt):
			br.u16()
	return b


func _read_tristrips_tail10(b: Dictionary, num_vertices: int) -> Dictionary:
	var num_triangles := br.u16()
	var num_strips := br.u16()
	if num_triangles > MAX_TRIANGLES or num_strips > MAX_TRIANGLES:
		_fail("gb10 strip counts invalid triangles=%d strips=%d" % [num_triangles, num_strips], br.pos())
		return b
	var strip_lengths: Array[int] = []
	for _strip in range(num_strips):
		strip_lengths.append(br.u16())
	var has_points := br.boolb()
	var indices := PackedInt32Array()
	var strips: Array = []
	if has_points:
		for strip_length in strip_lengths:
			var strip := PackedInt32Array()
			strip.resize(strip_length)
			for point in range(strip_length):
				var vertex := br.u16()
				if vertex >= num_vertices:
					return _gb10_soft_trishapedata_bad_indices(b, num_vertices, int(indices.size() / 3), vertex, vertex, vertex)
				strip[point] = vertex
			strips.append(Array(strip))
			indices.append_array(_destrip(strip))
	b["num_triangles"] = num_triangles
	b["num_strips"] = num_strips
	b["strip_lengths"] = strip_lengths
	b["has_points"] = has_points
	b["strips"] = strips
	b["indices"] = indices
	return b


func _gb10_soft_trishapedata_bad_indices(b: Dictionary, num_vertices: int, triangle_index: int, i0: int, i1: int, i2: int) -> Dictionary:
	# HOTFIX P1-17A2-HF7 : ALTSTONEHall11.nif peut contenir une section
	# Gamebryo10 dont le layout NiTriShapeData diverge apres les donnees de sommets.
	# Avant HF7, on faisait un _fail() dur et le DungeonLab repassait tout le chunk
	# en fallback alors que le lecteur avait deja conserve les surfaces statiques lues
	# en amont. Ici on stoppe proprement la suite du NIF, sans erreur rouge, et on
	# laisse le converter exploiter les meshes deja valides. Le bloc fautif reste
	# marque dans le rapport pour ne pas masquer le vrai chantier de layout.
	var reason := "gb10 triangle index hors sommets au triangle %d (%d,%d,%d) / nv=%d — layout NiTriShapeData probablement decale" % [triangle_index, i0, i1, i2, num_vertices]
	b["indices"] = PackedInt32Array()
	b["gb10_bad_triangle_indices"] = true
	b["gb10_bad_triangle_error"] = reason
	b["gb10_soft_ended_file"] = true
	_recoverable_warning("NIF GB10 SOFT-END: %s @0x%X ; surfaces deja lues conservees" % [reason, br.pos()])
	_stop_reading_early = true
	br.seek(br.length())
	return b


func _read_screen_lod_data10() -> Dictionary:
	var b := {}
	b["center"] = br.vec3()
	b["radius"] = br.f32()
	var n := br.u32()
	if not _guard(n, MAX_CHILDREN, "gb10 screen_lod_count"):
		return b
	var levels: Array[Dictionary] = []
	for _i in range(n):
		levels.append({"near": br.f32(), "far": br.f32()})
	b["levels"] = levels
	return b


func _gb10_align_to_next_block(cur_idx: int, cur_block: Dictionary = {}) -> bool:
	var next_type := _gb10_block_type_names[cur_idx + 1]
	# HOTFIX P1-17A2-HF5 : certains NiNode Gamebryo10 DAoC portent un
	# controller_ref valide (ex. ALTSTONEHall11/GeoSphere01 -> NiKeyframeController).
	# Le test strict historique exigeait controller=-1 et sautait donc un vrai NiNode,
	# decalant toute la suite jusqu'a un faux NiTexturingProperty.
	if next_type == "NiNode" and _gb10_node_looks_like(br.pos(), false, true):
		return true
	if _gb10_block_looks_like(next_type, br.pos()):
		return true

	var start := br.pos()
	var scan_limit := 1024
	if _cur_type == "NiSourceTexture":
		scan_limit = 65536
	# Fence3 a une queue de NiTriShapeData plus longue que Fence1. Comme les
	# Gamebryo 10.1 DAoC n'ont pas de block_sizes, on autorise un scan plus large
	# uniquement apres une geometrie deja lue, et avec des tests de bloc suivant
	# plus stricts que le vieux simple NiObjectNET.
	if _cur_type == "NiTriShapeData" or _cur_type == "NiTriStripsData":
		scan_limit = 131072
	if _cur_type == "NiPixelData":
		scan_limit = br.length() - start

	var limit := mini(br.length(), start + scan_limit)
	for p in range(start, limit):
		var looks_ok := _gb10_block_looks_like(next_type, p)
		# Autoriser les NiNode animes pendant les scans non geometriques. On garde le
		# scan post-NiTriShapeData strict pour eviter les faux positifs au milieu des
		# buffers de sommets/UV.
		if not looks_ok and next_type == "NiNode" and _cur_type != "NiTriShapeData" and _cur_type != "NiTriStripsData":
			looks_ok = _gb10_node_looks_like(p, false, true)
		if looks_ok:
			br.seek(p)
			_recoverable_warning("NIF GB10 ALIGN: bloc %d '%s' -> prochain '%s', saute %d octets @0x%X" % [cur_idx, _cur_type, next_type, p - start, p])
			return true

	# Dernier filet de securite pour decor statique : apres une geometrie Gamebryo
	# deja lue, si le bloc suivant ne s'aligne pas, on accepte le mesh courant et
	# on termine le fichier. Ici on ne conditionne PAS sur vertices/indices, car
	# Godot 4 peut typer differemment les PackedArray venant d'un Dictionary, et
	# le but est justement d'eviter que NF_b-fence3 soit marque missing apres son
	# bloc 28 NiTriShapeData.
	if _cur_type == "NiTriShapeData" or _cur_type == "NiTriStripsData":
		_recoverable_warning("NIF GB10 SOFT-END: impossible d'aligner '%s' apres bloc %d '%s' @0x%X ; geometrie conservee, fin douce du fichier" % [next_type, cur_idx, _cur_type, start])
		_stop_reading_early = true
		br.seek(br.length())
		return true

	return _fail("Gamebryo10: impossible d'aligner le bloc suivant '%s' apres bloc %d '%s'" % [next_type, cur_idx, _cur_type], start)


func _gb10_block_looks_like(type_name: String, pos: int) -> bool:
	match type_name:
		"NiNode":
			return _gb10_node_looks_like(pos, false)
		"NiBillboardNode":
			return _gb10_node_looks_like(pos, false)
		"NiLODNode":
			return _gb10_node_looks_like(pos, true)
		"NiTriShape", "NiTriStrips":
			return _gb10_trishape_looks_like(pos)
		"NiZBufferProperty", "NiVertexColorProperty":
			return _gb10_objectnet_looks_like(pos, false)
		"NiMaterialProperty":
			return _gb10_material_looks_like(pos)
		"NiTexturingProperty":
			return _gb10_objectnet_looks_like(pos, true)
		"NiSourceTexture":
			return _gb10_source_texture_looks_like(pos)
		"NiPixelData":
			return _gb10_pixel_data_looks_like(pos)
		"NiTextureEffect":
			return _gb10_objectnet_looks_like(pos, false)
		"NiAlphaProperty", "NiDitherProperty", "NiWireframeProperty", "NiSpecularProperty", "NiShadeProperty", "NiStencilProperty":
			return _gb10_objectnet_looks_like(pos, false)
		"NiStringExtraData":
			return _gb10_string_extra_data_looks_like(pos)
		"NiKeyframeController", "NiTextureTransformController", "NiParticleSystemController", "NiParticleBomb", "NiParticleColorModifier", "NiParticleGrowFade", "NiParticleRotation", "NiGravity", "NiGeomMorpherController":
			return _gb10_controller_looks_like(pos)
		"NiKeyframeData", "NiColorData":
			return _gb10_keydata_looks_like(pos)
		"NiFloatData":
			return _gb10_keydata_looks_like(pos)
		"NiMorphData":
			return _gb10_morph_data_looks_like(pos)
		"NiParticles":
			return _gb10_objectnet_looks_like(pos, false)
		"NiParticlesData":
			return _gb10_particles_data_looks_like(pos)
		"NiTriShapeData":
			return _gb10_trishapedata_looks_like(pos, false)
		"NiTriStripsData":
			return _gb10_trishapedata_looks_like(pos, true)
		"NiScreenLODData":
			return _gb10_screen_lod_looks_like(pos)
		_:
			return false


func _gb10_node_looks_like(pos: int, lod_node: bool = false, allow_controller: bool = false) -> bool:
	if pos < 0 or pos + 80 > br.length():
		return false
	var save := br.pos()
	br.seek(pos)

	br.i32() # old_extra_data_ref
	var name_len := br.u32()
	if name_len < 0 or name_len > 512 or br.pos() + name_len + 8 > br.length():
		br.seek(save)
		return false
	br.skip(name_len)

	var num_extra := br.u32()
	if num_extra < 0 or num_extra > MAX_PROPS or br.pos() + num_extra * 4 + 4 > br.length():
		br.seek(save)
		return false
	for _e in range(num_extra):
		var extra_ref := br.i32()
		if not _gb10_ref_plausible(extra_ref):
			br.seek(save)
			return false

	var controller_ref := br.i32()
	# Pour les scans larges post-geometrie, on garde le test historique strict
	# controller=-1 afin d'eviter les faux positifs dans les buffers. Pour l'alignement
	# exact/non-geometrique, on accepte aussi les NiNode animes si la reference pointe
	# vers un bloc valide (ALTSTONEHall11).
	if allow_controller:
		if not _gb10_ref_plausible(controller_ref):
			br.seek(save)
			return false
	else:
		if controller_ref != -1:
			br.seek(save)
			return false

	if br.pos() + 2 + 12 + 36 + 4 + 4 > br.length():
		br.seek(save)
		return false
	br.u16() # flags
	br.skip(12 + 36)
	var scale := br.f32()
	if scale <= 0.00001 or scale > 100000.0:
		br.seek(save)
		return false

	var num_props := br.u32()
	if num_props < 0 or num_props > MAX_PROPS or br.pos() + num_props * 4 + 4 > br.length():
		br.seek(save)
		return false
	for _p in range(num_props):
		var prop_ref := br.i32()
		if not _gb10_ref_plausible(prop_ref):
			br.seek(save)
			return false

	var collision_ref := br.i32()
	if not _gb10_ref_plausible(collision_ref):
		br.seek(save)
		return false

	if br.pos() + 4 > br.length():
		br.seek(save)
		return false
	var n_children := br.u32()
	if n_children < 0 or n_children > MAX_CHILDREN or br.pos() + n_children * 4 + 4 > br.length():
		br.seek(save)
		return false
	for _c in range(n_children):
		var child_ref := br.i32()
		if not _gb10_ref_plausible(child_ref):
			br.seek(save)
			return false

	var n_effects := br.u32()
	if n_effects < 0 or n_effects > MAX_CHILDREN or br.pos() + n_effects * 4 > br.length():
		br.seek(save)
		return false
	for _fx in range(n_effects):
		var fx_ref := br.i32()
		if not _gb10_ref_plausible(fx_ref):
			br.seek(save)
			return false

	if lod_node:
		# Queue LOD observee : 10 octets. On ne l'exige pas si on est proche de la
		# fin d'un scan, mais elle doit au moins tenir si presente.
		if br.pos() + 10 > br.length():
			br.seek(save)
			return false

	br.seek(save)
	return true


func _gb10_trishape_looks_like(pos: int) -> bool:
	# Oracle complet de NiTriShape/Strips. Le simple prefixe NiObjectNET produit
	# des faux positifs dans les buffers de cles d'animation (des floats 0/1 ont
	# justement l'apparence de petites longueurs et refs).
	if pos < 0 or pos + 90 > br.length():
		return false
	var save := br.pos()
	br.seek(pos)
	br.i32() # vendor prefix
	var name_len := br.u32()
	if name_len < 0 or name_len > 512 or br.pos() + name_len + 8 > br.length():
		br.seek(save)
		return false
	br.skip(name_len)
	var num_extra := br.u32()
	if num_extra < 0 or num_extra > MAX_PROPS or br.pos() + num_extra * 4 + 4 > br.length():
		br.seek(save)
		return false
	for _index in range(num_extra):
		if not _gb10_ref_plausible(br.i32()):
			br.seek(save)
			return false
	if not _gb10_ref_plausible(br.i32()): # controller
		br.seek(save)
		return false
	if br.pos() + 2 + 12 + 36 + 4 + 4 > br.length():
		br.seek(save)
		return false
	br.u16()
	br.skip(12 + 36)
	var scale := br.f32()
	if not is_finite(scale) or absf(scale) < 0.00001 or absf(scale) > 100000.0:
		br.seek(save)
		return false
	var num_props := br.u32()
	if num_props < 0 or num_props > MAX_PROPS or br.pos() + num_props * 4 + 13 > br.length():
		br.seek(save)
		return false
	for _index in range(num_props):
		if not _gb10_ref_plausible(br.i32()):
			br.seek(save)
			return false
	for _field in range(3): # collision, data, skin
		if not _gb10_ref_plausible(br.i32()):
			br.seek(save)
			return false
	var has_shader := br.u8()
	if has_shader > 1:
		br.seek(save)
		return false
	if has_shader == 1:
		if br.pos() + 4 > br.length():
			br.seek(save)
			return false
		var shader_len := br.u32()
		if shader_len < 0 or shader_len > 512 or br.pos() + shader_len + 4 > br.length():
			br.seek(save)
			return false
	br.seek(save)
	return true


func _gb10_ref_plausible(ref: int) -> bool:
	# Les references NIF sont des indices de blocs ou -1. Ce test evite les faux
	# positifs d'alignement au milieu des donnees float/texture.
	return ref == -1 or (ref >= 0 and ref < _num_blocks)


func _gb10_objectnet_looks_like(pos: int, flexible_controller_prefix: bool) -> bool:
	if pos < 0 or pos + 16 > br.length():
		return false
	var save := br.pos()
	br.seek(pos)
	br.i32()  # old_extra_data_ref
	var name_len := br.u32()
	if name_len < 0 or name_len > 512 or br.pos() + name_len + 8 > br.length():
		br.seek(save)
		return false
	br.skip(name_len)
	var num_extra := br.u32()
	if num_extra < 0 or num_extra > MAX_PROPS or br.pos() + num_extra * 4 + 4 > br.length():
		br.seek(save)
		return false
	br.skip(num_extra * 4)
	if flexible_controller_prefix:
		var p := br.pos()
		if p + 5 <= br.length():
			var next_i32 := _gb10_peek_i32(p)
			var prefix := _gb10_peek_u8(p)
			var shifted_i32 := _gb10_peek_i32(p + 1)
			if next_i32 != -1 and (prefix == 0 or prefix == 1) and shifted_i32 == -1:
				br.skip(1)
	# controller_ref existe ; sa valeur doit etre -1 ou pointer vers un bloc.
	# Sans ce filtre, les floats/zeros de NiSourceTexture pouvaient etre pris pour
	# un faux NiObjectNET, ce qui decalait les fences au bloc material suivant.
	if br.pos() + 4 > br.length():
		br.seek(save)
		return false
	var controller_ref := br.i32()
	if not _gb10_ref_plausible(controller_ref):
		br.seek(save)
		return false
	br.seek(save)
	return true


func _gb10_material_looks_like(pos: int) -> bool:
	# NiObjectNET complet + 14 floats de NiMaterialProperty. La verification de
	# l'alpha élimine les faux débuts trouvés dans les queues NiSourceTexture.
	if pos < 0 or pos + 72 > br.length():
		return false
	var save := br.pos()
	br.seek(pos)
	br.u32() # vendor prefix
	var name_len := br.u32()
	if name_len < 0 or name_len > 512 or br.pos() + name_len + 8 > br.length():
		br.seek(save)
		return false
	br.skip(name_len)
	var num_extra := br.u32()
	if num_extra < 0 or num_extra > MAX_PROPS or br.pos() + num_extra * 4 + 4 > br.length():
		br.seek(save)
		return false
	for _index in range(num_extra):
		if not _gb10_ref_plausible(br.i32()):
			br.seek(save)
			return false
	var controller_pos := br.pos()
	if controller_pos + 5 <= br.length():
		var direct := _gb10_peek_i32(controller_pos)
		var prefix := _gb10_peek_u8(controller_pos)
		var shifted := _gb10_peek_i32(controller_pos + 1)
		if direct != -1 and (prefix == 0 or prefix == 1) and shifted == -1:
			br.u8()
	if not _gb10_ref_plausible(br.i32()) or br.pos() + 56 > br.length():
		br.seek(save)
		return false
	var values: Array[float] = []
	for _index in range(14):
		values.append(br.f32())
	var ok := true
	for value in values:
		if not is_finite(value) or absf(value) > 1000000.0:
			ok = false
			break
	var alpha := values[13]
	ok = ok and alpha >= -0.01 and alpha <= 1.01
	br.seek(save)
	return ok


func _gb10_source_texture_looks_like(pos: int) -> bool:
	# NiSourceTexture 10.1 commence par NiObjectNET. Il faut donc verifier ce
	# prefixe puis lire use_external APRES le controller_ref. L'ancien test pos+4
	# prenait le name_len pour use_external, donc n'importe quelle zone remplie de
	# zeros ressemblait faussement a une texture interne.
	if pos < 0 or pos + 21 > br.length():
		return false

	var save := br.pos()
	br.seek(pos)
	br.i32() # old_extra_data_ref
	var name_len := br.u32()
	if name_len < 0 or name_len > 512 or br.pos() + name_len + 8 > br.length():
		br.seek(save)
		return false
	br.skip(name_len)

	var num_extra := br.u32()
	if num_extra < 0 or num_extra > MAX_PROPS or br.pos() + num_extra * 4 + 5 > br.length():
		br.seek(save)
		return false
	br.skip(num_extra * 4)

	var controller_ref := br.i32()
	if not _gb10_ref_plausible(controller_ref):
		br.seek(save)
		return false

	var use_external := br.u8()
	if use_external == 1:
		if br.pos() + 4 > br.length():
			br.seek(save)
			return false
		var slen := br.u32()
		var ok := slen > 0 and slen < 260 and br.pos() + slen + 17 <= br.length()
		br.seek(save)
		return ok
	elif use_external == 0:
		var ok_internal := br.pos() + 20 <= br.length()
		br.seek(save)
		return ok_internal

	br.seek(save)
	return false


func _gb10_pixel_data_looks_like(pos: int) -> bool:
	# `pos` inclut le prefixe vendeur consomme par la boucle principale.
	# Le format pixel (0..16) est la seule partie commune aux variantes DAoC.
	if pos < 0 or pos + 8 > br.length():
		return false
	var save := br.pos()
	br.seek(pos)
	br.u32() # vendor prefix
	var pixel_format := br.u32()
	var ok := pixel_format >= 0 and pixel_format <= 16
	br.seek(save)
	return ok


func _gb10_trishapedata_looks_like(pos: int, strips := false) -> bool:
	# Verification de toute la structure variable jusqu'aux indices. Le vieux
	# test de neuf octets acceptait des faux `num_vertices=65535` au milieu des
	# materiaux et faisait perdre les meshes des fences/cookfires.
	if pos < 0 or pos + 16 > br.length():
		return false
	return _gb10_geometry_prefix_payload_looks_like(pos + 4, false, strips) or _gb10_geometry_prefix_payload_looks_like(pos + 4, true, strips)


func _gb10_geometry_prefix_payload_looks_like(payload_pos: int, has_unknown_id: bool, strips := false) -> bool:
	var save := br.pos()
	br.seek(payload_pos)
	if has_unknown_id:
		br.u32()
	var nv := br.u16()
	br.u8(); br.u8() # keep/compress
	var has_vertices := br.u8()
	# 32768/65535 sont des motifs frequents dans les pixels compresses et non des
	# comptes de sommets. Les surfaces DAoC observees restent sous 30k ; le lecteur
	# reel conserve son plafond general plus haut une fois le bloc localise.
	if nv < 0 or nv > 30000 or has_vertices > 1 or (nv > 0 and has_vertices != 1):
		br.seek(save)
		return false
	if nv > 0:
		var first_vertex := br.vec3()
		for component in [first_vertex.x, first_vertex.y, first_vertex.z]:
			if not is_finite(component) or absf(component) > 10000000.0:
				br.seek(save)
				return false
		br.skip((nv - 1) * 12)
	if br.pos() + 3 > br.length():
		br.seek(save)
		return false
	var vector_flags := br.u16()
	var has_normals := br.u8()
	if has_normals > 1:
		br.seek(save)
		return false
	if has_normals == 1:
		br.skip(nv * 12)
	if (vector_flags & 0x1000) != 0:
		br.skip(nv * 24)
	if br.pos() + 17 > br.length():
		br.seek(save)
		return false
	br.skip(16) # center + radius
	var has_colors := br.u8()
	if has_colors > 1:
		br.seek(save)
		return false
	if has_colors == 1:
		br.skip(nv * 16)
	var uv_sets := vector_flags & 0x3F
	if uv_sets > MAX_TEX:
		br.seek(save)
		return false
	br.skip(nv * uv_sets * 8)
	# Le prefixe geometrie/attributs est stable et suffit a exclure les faux
	# candidats. La queue triangles/strips a plusieurs variantes vendeur ; c'est
	# le lecteur reel qui la qualifie ensuite et peut la terminer en mode doux.
	var ok := br.pos() + 2 <= br.length()
	if ok and nv == 0:
		# Un bloc vide est legitime dans certains catalogues, mais une zone de pixels
		# pleine de zeros ne doit pas devenir un bloc. Exiger aussi la queue vide.
		br.u16() # consistency
		if strips:
			ok = br.pos() + 5 <= br.length() and br.u16() == 0 and br.u16() == 0 and br.u8() == 0
		else:
			ok = br.pos() + 7 <= br.length() and br.u16() == 0 and br.u32() == 0 and br.u8() == 0
	br.seek(save)
	return ok


func _gb10_screen_lod_looks_like(pos: int) -> bool:
	if pos < 0 or pos + 20 > br.length():
		return false
	var n := _gb10_peek_u32(pos + 16)
	return n >= 0 and n < 256 and pos + 20 + n * 8 <= br.length()


func _gb10_string_extra_data_looks_like(pos: int) -> bool:
	if pos < 0 or pos + 12 > br.length():
		return false
	var save := br.pos()
	br.seek(pos)
	var next_ref := br.i32()
	if not _gb10_ref_plausible(next_ref):
		br.seek(save)
		return false
	var name_len := br.u32()
	if name_len < 0 or name_len > 512 or br.pos() + name_len + 4 > br.length():
		br.seek(save)
		return false
	br.skip(name_len)
	var data_len := br.u32()
	var ok := data_len >= 0 and data_len < 65536 and br.pos() + data_len <= br.length()
	br.seek(save)
	return ok


func _gb10_controller_looks_like(pos: int) -> bool:
	# Test volontairement large : ces blocs sont ensuite soft-skippes jusqu'au
	# type suivant connu. On exige seulement quelques references plausibles afin
	# d'eviter les faux positifs les plus grossiers dans les buffers de sommets.
	if pos < 0 or pos + 12 > br.length():
		return false
	var a := _gb10_peek_i32(pos)
	var b := _gb10_peek_i32(pos + 4)
	return _gb10_ref_plausible(a) or _gb10_ref_plausible(b)


func _gb10_keydata_looks_like(pos: int) -> bool:
	if pos < 0 or pos + 4 > br.length():
		return false
	var n := _gb10_peek_u32(pos)
	if n <= 0 or n > MAX_VERTICES:
		return false
	if pos + 8 > br.length():
		return false
	var key_type := _gb10_peek_u32(pos + 4)
	return key_type >= 0 and key_type <= 5


func _gb10_morph_data_looks_like(pos: int) -> bool:
	if pos < 0 or pos + 9 > br.length():
		return false
	var n_morphs := _gb10_peek_u32(pos)
	var n_verts := _gb10_peek_u32(pos + 4)
	return n_morphs > 0 and n_morphs <= MAX_CHILDREN and n_verts > 0 and n_verts <= MAX_VERTICES


func _gb10_particles_data_looks_like(pos: int) -> bool:
	# Les particules derivent de NiGeometryData ; le prefixe est suffisamment proche
	# du NiTriShapeData DAoC pour notre detection de debut de bloc.
	return _gb10_trishapedata_looks_like(pos, false)


func _gb10_peek_u8(pos: int) -> int:
	if pos < 0 or pos + 1 > br.length():
		return -1
	var save := br.pos()
	br.seek(pos)
	var v := br.u8()
	br.seek(save)
	return v


func _gb10_peek_u16(pos: int) -> int:
	if pos < 0 or pos + 2 > br.length():
		return -1
	var save := br.pos()
	br.seek(pos)
	var v := br.u16()
	br.seek(save)
	return v


func _gb10_peek_u32(pos: int) -> int:
	if pos < 0 or pos + 4 > br.length():
		return -1
	var save := br.pos()
	br.seek(pos)
	var v := br.u32()
	br.seek(save)
	return v


func _gb10_peek_i32(pos: int) -> int:
	if pos < 0 or pos + 4 > br.length():
		return -2147483648
	var save := br.pos()
	br.seek(pos)
	var v := br.i32()
	br.seek(save)
	return v


# --- Aiguillage par type de bloc ---
func _read_block(type_name: String, idx: int) -> Dictionary:
	match type_name:
		"NiNode":
			return _read_ninode()
		"NiTriShape", "NiTriStrips":
			return _read_trishape()
		"NiTriShapeData", "NiTriStripsData":
			return _read_trishapedata(type_name)
		"NiMaterialProperty":
			return _read_material()
		"NiTexturingProperty":
			return _read_texturing()
		"NiSourceTexture":
			return _read_source_texture()
		"NiZBufferProperty":
			return _read_zbuffer()
		"NiAlphaProperty":
			return _read_alpha()
		"NiVertexColorProperty":
			return _read_vertexcolor()
		"NiStencilProperty":
			return _read_stencil()
		"NiSpecularProperty", "NiShadeProperty", "NiWireframeProperty", "NiDitherProperty":
			return _read_simple_property(type_name)
		"NiLODNode":
			return _read_lodnode()
		"NiSwitchNode", "NiBillboardNode":
			return _read_ninode()
		"NiStringExtraData":
			return _read_string_extra_data()
		"NiStringsExtraData":
			return _read_strings_extra_data(false)
		"NiIntegerExtraData":
			return _read_integer_extra_data(false)
		"NiVisData":
			return _read_vis_data()
		"NiRangeLODData":
			return _read_range_lod_data()
		"NiTextureTransformController":
			return _read_texture_transform_controller()
		"NiExtraData", "NiTextKeyExtraData", "NiVertWeightsExtraData", "NiBinaryExtraData":
			return _read_generic_extra_data()
		"NiParticleSystemController":
			return _read_particle_system_controller()
		"NiGravity":
			return _read_gravity()
		"NiParticleRotation":
			return _read_particle_rotation()
		"NiParticleColorModifier":
			return _read_particle_color_modifier()
		"NiParticleGrowFade":
			return _read_particle_grow_fade()
		"NiParticleBomb":
			return _read_particle_bomb()
		"NiKeyframeController", "NiVisController", "NiAlphaController", "NiMaterialColorController", "NiLookAtController", "NiRollController":
			return _read_ctrl_data()
		"NiUVController":
			return _read_uv_controller()
		"NiGeomMorpherController":
			return _read_geom_morpher_controller()
		"NiFlipController":
			return _read_flip_controller()
		"NiPathController":
			return _read_path_controller()
		"NiKeyframeData":
			return _read_keyframe_data()
		"NiFloatData":
			return _read_simple_keydata(1)
		"NiPosData":
			return _read_simple_keydata(3)
		"NiColorData":
			return _read_simple_keydata(4)
		"NiUVData":
			return _read_uv_data()
		"NiMorphData":
			return _read_morph_data()
		"NiTextureEffect":
			return _read_texture_effect()
		"NiCamera":
			return _read_camera()
		"NiAmbientLight", "NiDirectionalLight":
			return _read_light(false)
		"NiPointLight", "NiSpotLight":
			return _read_light(true)
		# NiParticleMeshes herite de NiParticles SANS champ propre (spec : LEGACY
		# pre-10.1, aucun <add>). Meme disposition, donc meme lecteur.
		"NiParticles", "NiAutoNormalParticles", "NiRotatingParticles", "NiParticleSystem", "NiParticleMeshes":
			return _read_trishape()
		"NiParticlesData", "NiAutoNormalParticlesData":
			return _read_particles_data(false)
		"NiRotatingParticlesData":
			return _read_particles_data(true)
		"NiParticleMeshModifier":
			return _read_particle_mesh_modifier()
		"NiParticleMeshesData":
			return _read_particles_data(true, true)
		"NiPixelData":
			return _read_pixel_data()
		"NiPalette":
			return _read_palette()
		"NiSkinInstance":
			return _read_ignorable_binary_block("NiSkinInstance")
		"NiSkinData", "NiSkinPartition":
			return _read_ignorable_binary_block(type_name)
		_:
			# Bloc inconnu : impossible de sauter sans desync -> on s'arrete FORT.
			suspect = type_name
			_fail("bloc non gere '%s' (bloc %d) — ajoute son lecteur dans _read_block(). %s" % [type_name, idx, _trace()], br.pos())
			return {}


# --- NiObjectNET : socle commun (nom, extra data, controleur) ---
func _read_objectnet(b: Dictionary) -> void:
	b["name"] = br.sized_string()
	b["extra_data_ref"] = br.i32()   # 4.x : ref unique
	b["controller_ref"] = br.i32()


# --- NiAVObject : transform + proprietes + bbox ---
func _read_avobject(b: Dictionary) -> void:
	_read_objectnet(b)
	b["flags"] = br.u16()
	var translation := br.vec3()
	var rotation := br.matrix33()
	var scale := br.f32()
	b["velocity"] = br.vec3()         # present <= 4.2.2.0 (spec standard, A VALIDER)
	# Transform BRUTE en espace NIF (non convertie). Le convertisseur l'accumule
	# le long de l'arbre puis convertit les sommets finaux via coordinate_system.
	b["nif_transform"] = Transform3D(rotation.scaled(Vector3(scale, scale, scale)), translation)
	var num_props := br.u32()
	if not _guard(num_props, MAX_PROPS, "num_properties"):
		return
	var props: Array[int] = []
	for _p in range(num_props):
		props.append(br.i32())
	b["property_refs"] = props
	# Has Bounding Box : booleen 1 OCTET en 4.2.2.0 (NOTE_TERRAIN §11), PAS un u32.
	var has_bb := br.boolb()
	if has_bb:
		_read_bounding_volume()


func _read_ninode() -> Dictionary:
	var b := {}
	_read_avobject(b)
	if failed:
		return b
	var n_children := br.u32()
	if not _guard(n_children, MAX_CHILDREN, "num_children"):
		return b
	var children: Array[int] = []
	for _c in range(n_children):
		children.append(br.i32())
	b["children"] = children
	var n_effects := br.u32()
	if not _guard(n_effects, MAX_CHILDREN, "num_effects"):
		return b
	# P1-119 : conservees (NiTextureEffect = carte d.environnement des effets de
	# sort, P1-76) ; 7445071 les avait remises en « ignorees ».
	var effects: Array[int] = []
	for _e in range(n_effects):
		effects.append(br.i32())
	b["effect_refs"] = effects
	return b


func _read_trishape() -> Dictionary:
	var b := {}
	_read_avobject(b)
	if failed:
		return b
	b["data_ref"] = br.i32()
	b["skin_instance_ref"] = br.i32()
	return b


## Base NiGeometryData 4.x : sommets/normales/couleurs/UV, SANS topologie.
## Utilisee par NiTriShapeData ET par NiParticlesData. Le bug V3 venait du fait
## qu'on lisait les particules comme des triangles, donc on avalait tout le reste
## du fichier.
func _read_geometrydata_base() -> Dictionary:
	var b := {}
	var num_vertices := br.u16()
	b["num_vertices"] = num_vertices
	if num_vertices > MAX_VERTICES:
		_fail("num_vertices=%d > max — desync probable" % num_vertices, br.pos())
		return b

	var verts := PackedVector3Array()
	if br.boolb():
		verts.resize(num_vertices)
		for i in range(num_vertices):
			verts[i] = br.vec3()
	b["vertices"] = verts

	var normals := PackedVector3Array()
	if br.boolb():
		normals.resize(num_vertices)
		for i in range(num_vertices):
			normals[i] = br.vec3()
	b["normals"] = normals

	b["center"] = br.vec3()
	b["radius"] = br.f32()

	var colors := PackedColorArray()
	if br.boolb():
		colors.resize(num_vertices)
		for i in range(num_vertices):
			colors[i] = br.color4()
	b["colors"] = colors

	# num_uv_sets : 6 bits de poids faible = nombre de jeux d'UV.
	var num_uv_raw := br.u16()
	var num_uv := num_uv_raw & 0x3F
	var uv_sets: Array = []
	for s in range(num_uv):
		var uv_set := PackedVector2Array()
		uv_set.resize(num_vertices)
		for i in range(num_vertices):
			uv_set[i] = Vector2(br.f32(), br.f32())
		uv_sets.append(uv_set)
	b["uv_sets"] = uv_sets
	b["uvs"] = uv_sets[0] if not uv_sets.is_empty() else PackedVector2Array()
	return b


## NiTriShapeData — DISPOSITION CONFIRMEE (NOTE_TERRAIN §11).
## Booleens sur 1 octet ; pas de flag has_uv/has_triangles separe.
func _read_trishapedata(type_name: String) -> Dictionary:
	var b := _read_geometrydata_base()
	if failed:
		return b

	# --- Triangles ---
	var indices := PackedInt32Array()
	if type_name == "NiTriShapeData":
		var num_triangles := br.u16()
		if num_triangles > MAX_TRIANGLES:
			_fail("num_triangles=%d > max — desync probable" % num_triangles, br.pos())
			return b
		br.u32()  # num_triangle_points (= num_triangles*3), redondant
		indices.resize(num_triangles * 3)
		for t in range(num_triangles):
			indices[t * 3 + 0] = br.u16()
			indices[t * 3 + 1] = br.u16()
			indices[t * 3 + 2] = br.u16()
		# Match groups : UNIQUEMENT pour NiTriShapeData (pas les strips).
		var num_match := br.u16()
		for _g in range(num_match):
			var cnt := br.u16()
			for _k in range(cnt):
				br.u16()
	else:
		# NiTriStripsData (4.x) : PAS de flag has_points (uniquement en 10.x+),
		# les strips sont TOUJOURS presents ; PAS de match groups. (cf. godotwind)
		var _num_triangles := br.u16()  # num_triangles total (info, ignore)
		var num_strips := br.u16()
		var strip_lengths: Array[int] = []
		for _s in range(num_strips):
			strip_lengths.append(br.u16())
		for s in range(num_strips):
			var strip := PackedInt32Array()
			strip.resize(strip_lengths[s])
			for k in range(strip_lengths[s]):
				strip[k] = br.u16()
			indices.append_array(_destrip(strip))

	b["indices"] = indices

	# V5 : certains NIF DAoC 4.1/4.2 ont une variante de queue NiTriShapeData /
	# NiTriStripsData qui n'est pas encore parfaitement decrite. Le symptome est
	# exactement celui vu apres V4 : le bloc suivant est lu comme un nom vide ou
	# invalide, avec NiTriShapeData/NiTriStripsData comme dernier suspect.
	# Pour le viewer statique, la geometrie utile est deja chargee ici ; on se
	# recale donc au prochain header Ni* au lieu de perdre tout le modele.
	_soft_resync_after_geometry(type_name)
	return b

## Convertit une bande de triangles (triangle strip) en triangles independants.
func _destrip(strip: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in range(strip.size() - 2):
		var a := strip[i]
		var bb := strip[i + 1]
		var c := strip[i + 2]
		if a == bb or bb == c or a == c:
			continue
		if i % 2 == 0:
			out.append(a); out.append(bb); out.append(c)
		else:
			out.append(a); out.append(c); out.append(bb)
	return out


func _read_material() -> Dictionary:
	var b := {}
	_read_objectnet(b)
	b["flags"] = br.u16()
	b["ambient"] = _color3()
	b["diffuse"] = _color3()
	b["specular"] = _color3()
	b["emissive"] = _color3()
	b["glossiness"] = br.f32()
	b["alpha"] = br.f32()
	return b


func _read_texturing() -> Dictionary:
	var b := {}
	_read_objectnet(b)
	b["flags"] = br.u16()
	b["apply_mode"] = br.u32()
	var tex_count := br.u32()
	if not _guard(tex_count, MAX_TEX, "texture_count"):
		return b
	var base_source := -1
	var texture_slots: Array = []
	for t in range(tex_count):
		var has_tex := br.boolb()
		if has_tex:
			var src := br.i32()
			var clamp_mode := br.u32()
			var filter_mode := br.u32()
			var uv_set := br.u32()
			var ps2_l := br.u16()
			var ps2_k := br.u16()
			texture_slots.append({
				"slot": t,
				"source_ref": src,
				"clamp_mode": clamp_mode,
				"filter_mode": filter_mode,
				"uv_set": uv_set,
				"ps2_l": ps2_l,
				"ps2_k": ps2_k,
			})
			# "Unknown1" (ushort) : present UNIQUEMENT <= 4.1.0.12. Conditionne a la
			# version reelle du fichier (les NIF DAoC vont de 4.1.0.12 a 4.2.2.0).
			if version_int <= 0x0401000C:
				br.u16()   # unknown1 (4.1.0.12 et anterieurs)
			# Texture de bump (slot 5) : luma bias (2 floats) + matrice de bump (4 floats).
			if t == 5:
				br.f32(); br.f32()
				br.f32(); br.f32(); br.f32(); br.f32()
			if t == 0:
				base_source = src   # texture de base = slot 0
	b["base_source_ref"] = base_source
	b["texture_slots"] = texture_slots
	return b


func _read_source_texture() -> Dictionary:
	var b := {}
	_read_objectnet(b)
	var use_external := br.u8()
	if use_external == 1:
		b["file_name"] = br.sized_string()   # nom du .dds/.tga (sans chemin, voir §11)
	else:
		br.u8()                              # unknown byte
		b["pixel_data_ref"] = br.i32()       # NiPixelData embarque (rare ici)
		b["file_name"] = ""
	br.u32()   # pixel layout
	br.u32()   # use mipmaps
	br.u32()   # alpha format
	br.u8()    # is static
	return b


## Proprietes "simples" : NiObjectNET + flags u16. (NiSpecular/Shade/Wireframe/Dither.)
func _read_simple_property(_type_name: String) -> Dictionary:
	var b := {}
	_read_objectnet(b)
	b["flags"] = br.u16()
	return b


## NiZBufferProperty : Flags(u16) + Function(u32) [present >= 4.1.0.12].
func _read_zbuffer() -> Dictionary:
	var b := {}
	_read_objectnet(b)
	b["flags"] = br.u16()
	if version_int >= 0x0401000C:
		br.u32()   # Function (ZCompareMode)
	return b


## NiAlphaProperty : Flags(u16) + Threshold(1 octet).
func _read_alpha() -> Dictionary:
	var b := {}
	_read_objectnet(b)
	b["flags"] = br.u16()
	br.u8()        # Threshold
	return b


## NiVertexColorProperty : Flags(u16) + Vertex Mode(u32) + Lighting Mode(u32)
## [les deux uint presents <= 20.0.0.5, donc pour toutes nos versions].
func _read_vertexcolor() -> Dictionary:
	var b := {}
	_read_objectnet(b)
	b["flags"] = br.u16()
	br.u32()       # Vertex Mode
	br.u32()       # Lighting Mode
	return b


## NiStencilProperty (ancien layout <= 10.0.1.2) : PAS de Flags u16 ; commence par
## Stencil Enabled(1 octet) puis 7 uint. Best-effort, A VALIDER si rencontre.
func _read_stencil() -> Dictionary:
	var b := {}
	_read_objectnet(b)
	b["flags"] = br.u16()   # MANQUAIT : flags (2 octets) avant enabled
	br.u8()        # Stencil Enabled
	br.u32()       # Stencil Function
	br.u32()       # Stencil Ref
	br.u32()       # Stencil Mask
	br.u32()       # Fail Action
	br.u32()       # Z Fail Action
	br.u32()       # Pass Action
	br.u32()       # Draw Mode
	return b


## NiLODNode (DAoC 4.x) : derive de NiSwitchNode, pas seulement de NiNode.
##
## Les NIF DAoC observes ont, apres les enfants/effects de NiNode :
##   active_child/ref u32 + center vec3 + radius/extent f32
## puis directement le header du bloc suivant.
## L'ancien lecteur sautait seulement vec3 : il tombait donc au milieu de ces
## 20 octets et lisait des floats comme un nom de type (ex. "AD*", "42").
##
## Comme les vieux NIF n'ont pas de table de tailles de blocs, on reste prudent :
## on essaie plusieurs queues plausibles et on retient celle qui aligne exactement
## le prochain header de type. Pour le viewer statique, ces champs LOD ne servent
## pas encore, donc l'objectif prioritaire est la synchronisation.
func _read_lodnode() -> Dictionary:
	var b := {}
	_read_avobject(b)
	if failed:
		return b

	var n_children := br.u32()
	if not _guard(n_children, MAX_CHILDREN, "num_children"):
		return b
	var children: Array[int] = []
	for _c in range(n_children):
		children.append(br.i32())
	b["children"] = children

	var n_effects := br.u32()
	if not _guard(n_effects, MAX_CHILDREN, "num_effects"):
		return b
	for _e in range(n_effects):
		br.i32()

	var tail_start := br.pos()
	# 36 = disposition dominante DAoC 4.x observee (confirmee sur ~19 fichiers via
	# resync avant l'ajout de ce candidat) ; 44 = variante plus rare avec 2 champs
	# supplementaires. Chaque candidat reste verifie par _next_is_type_header().
	var candidates := [36, 20, 16, 12, 24, 28, 32, 44]
	for size in candidates:
		br.seek(tail_start + size)
		if _next_is_type_header():
			b["lod_tail_size"] = size
			return b

	# Variante standard possible : center vec3 + num_levels u32 + ranges near/far.
	br.seek(tail_start + 12)
	if br.pos() + 4 <= br.length():
		var n_levels := br.u32()
		if n_levels >= 0 and n_levels <= 64:
			br.seek(tail_start + 12 + 4 + n_levels * 8)
			if _next_is_type_header():
				b["lod_tail_size"] = 16 + n_levels * 8
				b["lod_levels"] = n_levels
				return b

	# Dernier recours diagnostic : resynchroniser vers le prochain vrai type Ni*.
	br.seek(tail_start)
	if _resync_to_next_type_header("NiLODNode", 128):
		b["lod_tail_size"] = br.pos() - tail_start
		b["lod_resynced"] = true
		return b

	_fail("NiLODNode: impossible de retrouver le prochain header de bloc apres offset 0x%X" % tail_start, tail_start)
	return b


## NiStringExtraData : NiExtraData (next ref + bytes_remaining) + chaine. (cf. godotwind)
func _read_string_extra_data() -> Dictionary:
	var b := {}
	b["next_extra_data_ref"] = br.i32()
	var _bytes_remaining := br.u32()
	b["string_data"] = br.sized_string()
	return b


## Extra data generique : next ref + bytes_remaining + on saute les donnees
## (bytes_remaining donne la taille -> sautable sans desync).
func _read_generic_extra_data() -> Dictionary:
	var b := {}
	b["next_extra_data_ref"] = br.i32()
	var bytes_remaining := br.u32()
	if bytes_remaining > 0 and bytes_remaining < 16777216:
		br.skip(bytes_remaining)
	return b


## NiTimeController : base commune a tous les controleurs. (cf. godotwind)
func _read_time_controller(b: Dictionary) -> void:
	b["next_controller_ref"] = br.i32()
	b["ctrl_flags"] = br.u16()
	b["frequency"] = br.f32()
	b["phase"] = br.f32()
	b["start_time"] = br.f32()
	b["stop_time"] = br.f32()
	b["target_ref"] = br.i32()


## Controleurs "base + data ref" : Keyframe / Vis / Alpha / MaterialColor / LookAt / Roll.
func _read_ctrl_data() -> Dictionary:
	var b := {}
	_read_time_controller(b)
	b["data_ref"] = br.i32()
	return b


## NiParticleSystemController : pour le viewer statique, on ignore la simulation.
##
## Les variantes DAoC 4.1/4.2 n'ont pas toutes exactement la meme queue.
## Lire seulement NiTimeController et esperer tomber juste desynchronise certains
## modeles (brghouse/demonportal/BAvTeleporter). Ici on traite ce bloc comme
## ignorable et on saute jusqu'au prochain vrai header de bloc Ni*.
func _read_particle_system_controller() -> Dictionary:
	return _read_ignorable_particle_block("NiParticleSystemController")


## NiParticleModifier : socle commun (next modifier ref + controller ptr), 8 octets.
## Confirme empiriquement : la taille totale (base + champs propres) des blocs
## ci-dessous colle exactement aux "saute N octets" releves via resync avant
## que ces lecteurs dedies n'existent (44/25/12/16/56 = 8 + champs propres).
func _read_particle_modifier_base(b: Dictionary) -> void:
	b["next_modifier_ref"] = br.i32()
	b["controller_ref"] = br.i32()


## NiGravity : NiParticleModifier + decay/force/type/position/direction (36 octets).
func _read_gravity() -> Dictionary:
	var b := {}
	_read_particle_modifier_base(b)
	b["decay"] = br.f32()
	b["force"] = br.f32()
	b["force_type"] = br.u32()
	b["position"] = br.vec3()
	b["direction"] = br.vec3()
	return b


## NiParticleRotation : NiParticleModifier + random axis(bool) + axis(vec3) + speed(float).
func _read_particle_rotation() -> Dictionary:
	var b := {}
	_read_particle_modifier_base(b)
	b["random_initial_axis"] = br.boolb()
	b["initial_axis"] = br.vec3()
	b["rotation_speed"] = br.f32()
	return b


## NiParticleColorModifier : NiParticleModifier + ref vers NiColorData (4 octets).
func _read_particle_color_modifier() -> Dictionary:
	var b := {}
	_read_particle_modifier_base(b)
	b["color_data_ref"] = br.i32()
	return b


## NiParticleGrowFade : NiParticleModifier + grow(float) + fade(float).
func _read_particle_grow_fade() -> Dictionary:
	var b := {}
	_read_particle_modifier_base(b)
	b["grow"] = br.f32()
	b["fade"] = br.f32()
	return b


## NiParticleBomb : NiParticleModifier + decay/duration/deltaV/start/decayType/
## symmetryType/position/direction (48 octets).
func _read_particle_bomb() -> Dictionary:
	var b := {}
	_read_particle_modifier_base(b)
	b["decay"] = br.f32()
	b["duration"] = br.f32()
	b["delta_v"] = br.f32()
	b["start"] = br.f32()
	b["decay_type"] = br.u32()
	b["symmetry_type"] = br.u32()
	b["position"] = br.vec3()
	b["direction"] = br.vec3()
	return b


## Blocs particules / forces ignores pour le rendu statique.
## Sans table de tailles, le seul saut fiable en vieux NIF est la resynchro vers
## le prochain header de type. C'est volontairement reserve aux blocs non
## geometriques qui bloquent les derniers modeles 4.x.
func _read_ignorable_particle_block(type_name: String) -> Dictionary:
	var b := {}
	var start := br.pos()
	# Les effets 4.x peuvent etre tres longs ; on scanne jusqu'a la fin du fichier
	# plutot que de rester limite a 128 Ko.
	var max_scan := maxi(4096, br.length() - start)
	if _resync_to_next_type_header(type_name, max_scan):
		b["ignored"] = true
		b["skipped_bytes"] = br.pos() - start
		return b

	# Fallback volontairement doux : si l'effet est illisible mais non geometrique,
	# on garde le modele statique deja parse au lieu de jeter tout le NIF.
	_recoverable_warning("NIF SOFT-TRUNCATE: %s illisible apres 0x%X ; conservation des blocs deja lus" % [type_name, start])
	_stop_reading_early = true
	br.seek(br.length())
	b["ignored"] = true
	b["soft_truncated"] = true
	return b


## Saut doux generique pour blocs non critiques de vieux NIF 4.x sans table de tailles.
## Utilise pour NiSkinInstance/NiSkinData et les data d'animation quand ils se desynchronisent.
func _read_ignorable_binary_block(type_name: String) -> Dictionary:
	var b := {}
	var start := br.pos()
	var max_scan := maxi(4096, br.length() - start)
	if _resync_to_next_type_header(type_name, max_scan):
		b["ignored"] = true
		b["skipped_bytes"] = br.pos() - start
		return b
	_recoverable_warning("NIF SOFT-TRUNCATE: %s illisible apres 0x%X ; conservation des blocs deja lus" % [type_name, start])
	_stop_reading_early = true
	br.seek(br.length())
	b["ignored"] = true
	b["soft_truncated"] = true
	return b


## NiUVController : base + uv_set(u16) + data ref.
func _read_uv_controller() -> Dictionary:
	var b := {}
	_read_time_controller(b)
	br.u16()   # uv set
	b["data_ref"] = br.i32()
	return b


## NiGeomMorpherController : base + data ref + always_update(1 octet).
func _read_geom_morpher_controller() -> Dictionary:
	var b := {}
	_read_time_controller(b)
	b["data_ref"] = br.i32()
	br.u8()    # always update
	return b


## NiFlipController : base + texture_slot + 2 floats + liste de sources.
func _read_flip_controller() -> Dictionary:
	var b := {}
	_read_time_controller(b)
	br.u32()   # texture slot
	br.f32()   # time start (Morrowind)
	br.f32()   # delta
	var n := br.u32()
	if not _guard(n, MAX_CHILDREN, "flip num_sources"):
		return b
	for _i in range(n):
		br.i32()
	return b


## NiPathController : base + champs de trajectoire.
func _read_path_controller() -> Dictionary:
	var b := {}
	_read_time_controller(b)
	br.i32()   # bank direction
	br.f32()   # max bank angle
	br.f32()   # smoothing
	br.u16()   # follow axis (s16)
	br.i32()   # path data ref
	br.i32()   # percent data ref
	return b


func _color3() -> Color:
	return Color(br.f32(), br.f32(), br.f32(), 1.0)


# === Blocs "data" (clés d'animation) — base commune _read_key_group ===
# Types d'interpolation : 1=LINEAR, 2=QUADRATIC, 3=TCB, 4=XYZ, 5=CONSTANT.

## Lit num_keys clés ; value_size 1=float, 3=vec3, 4=quaternion.
func _read_key_group(num_keys: int, key_type: int, value_size: int) -> void:
	if not _guard(num_keys, MAX_VERTICES, "num_keys"):
		return   # plafond central : protege TOUS les blocs de cles d'un emballement
	for _i in range(num_keys):
		br.f32()  # time
		_read_key_value(value_size)
		if key_type == 2:      # QUADRATIC : forward + backward
			_read_key_value(value_size)
			_read_key_value(value_size)
		elif key_type == 3:    # TCB : tension, continuity, bias
			br.f32(); br.f32(); br.f32()


func _read_key_value(value_size: int) -> void:
	if value_size == 1:
		br.f32()
	elif value_size == 3:
		br.vec3()
	elif value_size == 4:
		br.f32(); br.f32(); br.f32(); br.f32()   # quaternion


## Reads and retains animation keys. NIF quaternions use W, X, Y, Z order.
func _read_key_group_values(num_keys: int, key_type: int, value_size: int) -> Array:
	var result: Array = []
	if not _guard(num_keys, MAX_VERTICES, "num_keys"):
		return result
	for _i in range(num_keys):
		var key := {"time": br.f32(), "value": _read_animation_key_value(value_size)}
		if key_type == 2:
			key["forward"] = _read_animation_key_value(value_size)
			key["backward"] = _read_animation_key_value(value_size)
		elif key_type == 3:
			key["tension"] = br.f32()
			key["continuity"] = br.f32()
			key["bias"] = br.f32()
		result.append(key)
	return result


func _read_animation_key_value(value_size: int) -> Variant:
	if value_size == 1:
		return br.f32()
	if value_size == 3:
		var value := br.vec3()
		return [value.x, value.y, value.z]
	if value_size == 4:
		return [br.f32(), br.f32(), br.f32(), br.f32()]
	return null


## NiFloatData(size 1) / NiPosData(size 3) / NiColorData(size 4).
func _read_simple_keydata(value_size: int) -> Dictionary:
	var n := br.u32()
	if not _guard(n, MAX_VERTICES, "num_keys"):
		return {}
	if n > 0:
		var t := br.u32()
		# P1-119 : cles CONSERVEES (NiFloatData = alpha des effets de sort, P1-76).
		return {"keys": _legacy_effect_keys(_read_key_group_values(n, t, value_size), value_size), "key_type": t}
	return {"keys": []}


## Un groupe de clés flottantes prefixe par son compte (pour NiUVData).
func _read_float_key_map() -> void:
	var n := br.u32()
	if n == 0:
		return
	var t := br.u32()
	_read_key_group(n, t, 1)


## NiKeyframeData : clés rotation + (XYZ) + translation + echelle.
func _read_keyframe_data() -> Dictionary:
	var b := {"parse_status": "FULLY_PARSED"}
	var payload_start := br.pos()

	var num_rot := br.u32()
	if num_rot < 0 or num_rot > MAX_VERTICES:
		return _soft_abort_legacy_data_block(b, "NiKeyframeData", payload_start, "num_rot_keys aberrant (%d, max %d)" % [num_rot, MAX_VERTICES])
	b["num_rotation_keys"] = num_rot
	if num_rot > 0:
		var rot_type := br.u32()
		if rot_type < 0 or rot_type > 5:
			return _soft_abort_legacy_data_block(b, "NiKeyframeData", payload_start, "rot_type aberrant (%d)" % rot_type)
		b["rotation_type"] = rot_type
		if rot_type != 4:
			b["rotation_keys"] = _read_key_group_values(num_rot, rot_type, 4)
		if rot_type == 4:  # XYZ : 3 axes de clés flottantes
			# KFA 4.2.2 (classic_horse_*.kfa) stores the XYZ order before
			# the three scalar key groups, as does the later 10.x layout.
			b["xyz_order"] = br.f32()
			var axes: Array = []
			for _axis in range(3):
				var n_axis := br.u32()
				if n_axis < 0 or n_axis > MAX_VERTICES:
					return _soft_abort_legacy_data_block(b, "NiKeyframeData", payload_start, "num_axis_keys aberrant (%d, max %d)" % [n_axis, MAX_VERTICES])
				var axis := {"count": n_axis, "interpolation": 0, "keys": []}
				if n_axis > 0:
					var axis_type := br.u32()
					if axis_type < 0 or axis_type > 5:
						return _soft_abort_legacy_data_block(b, "NiKeyframeData", payload_start, "axis_key_type aberrant (%d)" % axis_type)
					axis["interpolation"] = axis_type
					axis["keys"] = _read_key_group_values(n_axis, axis_type, 1)
				axes.append(axis)
			b["xyz_rotation_keys"] = axes
	else:
		b["rotation_type"] = 0
		b["rotation_keys"] = []

	var num_trans := br.u32()
	if num_trans < 0 or num_trans > MAX_VERTICES:
		return _soft_abort_legacy_data_block(b, "NiKeyframeData", payload_start, "num_trans_keys aberrant (%d, max %d)" % [num_trans, MAX_VERTICES])
	b["num_translation_keys"] = num_trans
	b["translation_keys"] = []
	if num_trans > 0:
		var trans_type := br.u32()
		if trans_type < 0 or trans_type > 5:
			return _soft_abort_legacy_data_block(b, "NiKeyframeData", payload_start, "trans_key_type aberrant (%d)" % trans_type)
		b["translation_type"] = trans_type
		b["translation_keys"] = _read_key_group_values(num_trans, trans_type, 3)

	var num_scale := br.u32()
	if num_scale < 0 or num_scale > MAX_VERTICES:
		return _soft_abort_legacy_data_block(b, "NiKeyframeData", payload_start, "num_scale_keys aberrant (%d, max %d)" % [num_scale, MAX_VERTICES])
	b["num_scale_keys"] = num_scale
	b["scale_keys"] = []
	if num_scale > 0:
		var scale_type := br.u32()
		if scale_type < 0 or scale_type > 5:
			return _soft_abort_legacy_data_block(b, "NiKeyframeData", payload_start, "scale_key_type aberrant (%d)" % scale_type)
		b["scale_type"] = scale_type
		b["scale_keys"] = _read_key_group_values(num_scale, scale_type, 1)
	# P1-119 : 7445071 a range les cles sous d.autres noms et en tableaux ;
	# DaocSpellEffectScenes (P1-76) lit rot_keys / trans_keys en Quaternion / Vector3.
	# Alias ajoutes, la forme de Codex reste intacte.
	b["rot_type"] = int(b.get("rotation_type", 0))
	b["rot_keys"] = _legacy_effect_keys(b.get("rotation_keys", []), 4)
	b["trans_keys"] = _legacy_effect_keys(b.get("translation_keys", []), 3)
	return b


## P1-119 — cles au format historique : {time, value} avec Quaternion (w,x,y,z
## du NIF), Vector3 ou float, comme les rendait _read_key_group avant 7445071.
func _legacy_effect_keys(keys: Array, value_size: int) -> Array:
	var out: Array = []
	for key_value in keys:
		var key := key_value as Dictionary
		var v: Variant = key.get("value")
		if value_size == 4 and v is Array and (v as Array).size() == 4:
			v = Quaternion(float(v[1]), float(v[2]), float(v[3]), float(v[0]))
		elif value_size == 3 and v is Array and (v as Array).size() == 3:
			v = Vector3(float(v[0]), float(v[1]), float(v[2]))
		out.append({"time": float(key.get("time", 0.0)), "value": v})
	return out

func _soft_abort_legacy_data_block(b: Dictionary, context: String, payload_start: int, reason: String) -> Dictionary:
	b["ignored"] = true
	b["soft_skip_reason"] = reason
	br.seek(payload_start)
	var max_scan := maxi(4096, br.length() - payload_start)
	if _resync_to_next_type_header(context, max_scan):
		b["skipped_bytes"] = br.pos() - payload_start
		return b
	_recoverable_warning("NIF SOFT-TRUNCATE: %s %s apres 0x%X ; conservation des blocs deja lus" % [context, reason, payload_start])
	_stop_reading_early = true
	br.seek(br.length())
	b["soft_truncated"] = true
	return b


## NiUVData : 4 groupes de clés flottantes (U/V translation, U/V echelle).
func _read_uv_data() -> Dictionary:
	_read_float_key_map()
	_read_float_key_map()
	_read_float_key_map()
	_read_float_key_map()
	return {}


## NiMorphData : num_morphs + num_vertices + relative_targets, puis par morph
## un groupe de clés (type TOUJOURS lu) + un offset par sommet.
## P1-89 — les cibles de morphing sont CONSERVEES : le bouclier d.Amethyste
## (alb_eshield1_hit) nait avec un rayon de 2,7 et gonfle a 50 par son
## NiGeomMorpherController ; sans les cibles, il restait minuscule.
## RESTAURE le 2026-09-23 (P1-119) : 7445071 avait remis l.ancienne version
## qui jetait les cibles — le bouclier avait de nouveau disparu.
func _read_morph_data() -> Dictionary:
	var num_morphs := br.u32()
	var num_vertices := br.u32()
	if not _guard(num_morphs, MAX_CHILDREN, "num_morphs") or not _guard(num_vertices, MAX_VERTICES, "morph_verts"):
		return {}
	var relative := br.u8() != 0
	var morphs: Array = []
	for _m in range(num_morphs):
		var n := br.u32()
		var t := br.u32()   # type toujours lu pour les morphs
		var keys: Array = []
		if n > 0:
			keys = _read_key_group_values(n, t, 1)
		var verts := PackedVector3Array()
		verts.resize(num_vertices)
		for v in range(num_vertices):
			verts[v] = br.vec3()
		morphs.append({"keys": keys, "vertices": verts})
	return {"relative": relative, "num_vertices": num_vertices, "morphs": morphs}


# === Lumieres & effets ===
func _read_dynamic_effect(b: Dictionary) -> void:
	_read_avobject(b)
	if failed:
		return
	# Important DAoC 4.x : dans ces NIF NetImmerse, NiDynamicEffect ne porte pas
	# ici la liste affected_nodes lue par le patch precedent. Lire un u32 a cet
	# endroit avalait le float dimmer (= 1.0 / 0x3F800000) des NiLight et cassait
	# cotssign / HCelttreetower. Les affected nodes sont absents ou geres ailleurs
	# dans cette famille de fichiers.


## NiAmbientLight/NiDirectionalLight (point=false) ; NiPointLight/NiSpotLight (point=true).
func _read_light(point: bool) -> Dictionary:
	var b := {}
	_read_dynamic_effect(b)
	if failed:
		return b
	br.f32()                 # dimmer
	_color3(); _color3(); _color3()   # ambient / diffuse / specular
	if point:
		br.f32(); br.f32(); br.f32()  # constant / linear / quadratic atten
	_resync_to_next_type_header("Light")
	return b


## NiCamera : frustum + viewport + lod_adjust + scene ptr (+ champ >= 4.2.1.0).
func _read_camera() -> Dictionary:
	var b := {}
	_read_avobject(b)
	if failed:
		return b
	for _i in range(6):
		br.f32()   # frustum L/R/T/B/near/far
	for _i in range(4):
		br.f32()   # viewport L/R/T/B
	br.f32()       # lod adjust
	br.u32()       # scene pointer (inutilise)
	if version_int >= 0x04020100:   # uniquement >= 4.2.1.0
		br.u32()
	_resync_to_next_type_header("NiCamera")
	return b


## NiTextureEffect : matrice projection + champs, avec conditionnels de version.
func _read_texture_effect() -> Dictionary:
	var b := {}
	_read_dynamic_effect(b)
	if failed:
		return b
	br.matrix33()  # model projection matrix
	br.vec3()      # model projection translation
	b["filtering"] = br.u32(); b["clamping"] = br.u32(); b["texture_type"] = br.u32(); b["coord_gen"] = br.u32()
	# P1-119 : conserve (carte d.environnement amethmap du bouclier, P1-76).
	b["source_texture_ref"] = br.i32()
	br.boolb()     # clipping plane enable (1 octet pour nos versions)
	br.vec3(); br.f32()   # clipping plane (normale + distance)
	br.u32()       # PS2 (<= 10.2.0.0)
	if version_int <= 0x0401000C:   # unknown short, uniquement <= 4.1.0.12
		br.u16()
	_resync_to_next_type_header("NiTextureEffect")
	return b


## NiParticlesData / NiAutoNormalParticlesData / NiRotatingParticlesData.
## Contrairement a NiTriShapeData, ces blocs n'ont PAS de liste de triangles :
## ils heritent de NiGeometryData puis ajoutent seulement des champs particules.
## `extra_mesh_ref` : NiParticleMeshesData herite de NiRotatingParticlesData et
## ajoute un seul champ, `Unknown Link 2` (Ref vers un NiAVObject).
func _read_particles_data(rotating: bool, extra_mesh_ref: bool = false) -> Dictionary:
	var b := _read_geometrydata_base()
	if failed:
		return b

	var num_verts: int = int(b.get("num_vertices", 0))

	# Si le prochain bloc commence deja ici, certains exports DAoC n'ont pas de
	# queue particule exploitable : c'est valide pour notre rendu statique.
	if _next_is_type_header():
		return b

	var extra_start := br.pos()

	# CORRIGE (jalon NIF_PARTICLE_BLOCK_FAMILY) depuis reference/nif_spec/nif.xml.
	#
	# L'ancienne version lisait TOUJOURS un `num_particles` (u16). La spec le donne
	# avec ver2="4.0.0.2" : il est ABSENT des versions du client DAoC
	# (4.1.0.12, 4.2.1.0, 4.2.2.0). Deux octets de trop, rattrapes ensuite par
	# _resync_to_next_type_header — le meme schema que le i32 surnumeraire de
	# _read_string_extra_data10.
	#
	# Disposition NiParticlesData pour nos versions :
	#   Num Particles   ushort   ver2="4.0.0.2"    -> ABSENT
	#   Particle Radius float    ver2="10.0.1.0"   -> present
	#   Has Radii       bool     ver1="10.1.0.0"   -> ABSENT
	#   Num Active      ushort                     -> present
	#   Has Sizes       bool                       -> present
	#   Sizes           float[Num Vertices] si Has Sizes
	#   Has Rotations   bool     ver1="10.0.1.0"   -> ABSENT
	#   (champs Bethesda 20.x : tous absents)
	#
	# NiRotatingParticlesData ajoute :
	#   Has Rotations 2 bool     ver2="4.2.2.0"    -> present
	#   Rotations 2     Quaternion[Num Vertices] si Has Rotations 2
	const VER_NUM_PARTICLES_MAX := 0x04000002
	if br.pos() + 8 <= br.length():
		if version_int <= VER_NUM_PARTICLES_MAX:
			b["num_particles"] = br.u16()
		b["particle_radius"] = br.f32()
		b["num_active"] = br.u16()

		if not _next_is_type_header() and br.pos() < br.length():
			var has_sizes := br.boolb()
			b["has_sizes"] = has_sizes
			if has_sizes:
				var count := num_verts
				if count >= 0 and count <= MAX_VERTICES and br.pos() + count * 4 <= br.length():
					br.skip(count * 4)
				else:
					br.seek(extra_start)

		if rotating and not _next_is_type_header() and br.pos() < br.length():
			var has_rotations := br.boolb()
			b["has_rotations_2"] = has_rotations
			if has_rotations:
				var count := num_verts
				if count >= 0 and count <= MAX_VERTICES and br.pos() + count * 16 <= br.length():
					br.skip(count * 16)
				else:
					br.seek(extra_start)

	if extra_mesh_ref and not _next_is_type_header() and br.pos() + 4 <= br.length():
		b["particle_mesh_ref"] = br.i32()

	# On se recale au bloc suivant. Si on n'y arrive pas, ne pas condamner tout le
	# modele : ces blocs sont des particules/FX, pas la geometrie principale.
	if not _resync_to_next_type_header("NiParticlesData", maxi(4096, br.length() - br.pos())):
		_recoverable_warning("NIF SOFT-TRUNCATE: NiParticlesData illisible apres 0x%X ; conservation des blocs deja lus" % extra_start)
		_stop_reading_early = true
		br.seek(br.length())

	return b

## NiPixelData : format + masques + mipmaps + donnees brutes (taille auto -> sautable).
func _read_pixel_data() -> Dictionary:
	br.u32()                 # format
	for _i in range(4):
		br.u32()             # color masks
	br.u32()                 # bits per pixel
	br.u32(); br.u32()       # compare bits
	br.i32()                 # palette ref
	var num_mipmaps := br.u32()
	br.u32()                 # bytes per pixel
	if _guard(num_mipmaps, MAX_CHILDREN, "num_mipmaps"):
		for _i in range(num_mipmaps):
			br.u32(); br.u32(); br.u32()   # width / height / offset
	var num_pixels := br.u32()
	if num_pixels > 0 and num_pixels < 67108864:
		br.skip(num_pixels)
	return {}


## NiPalette : flag alpha + nb d'entrees + entrees RGBA.
func _read_palette() -> Dictionary:
	br.u8()                  # use alpha
	var n := br.u32()
	if _guard(n, 4096, "palette_entries"):
		for _i in range(n):
			br.u32()
	return {}


## Bounding volume TYPE (u32) + donnees selon le type. (cf. godotwind)
## C'etait le gros bug : la bounding box n'est PAS une boite fixe, elle est typee.
func _read_bounding_volume() -> void:
	var bv_type := br.u32()
	match bv_type:
		0:   # SPHERE : center + radius
			br.vec3(); br.f32()
		1:   # BOX : center + axes(3x3) + extents
			br.vec3(); br.matrix33(); br.vec3()
		2:   # CAPSULE : center + axis + extent + radius
			br.vec3(); br.vec3(); br.f32(); br.f32()
		3:   # LOZENGE : radius + 2 extents + center + 2 axes
			br.f32(); br.f32(); br.f32(); br.vec3(); br.vec3(); br.vec3()
		4:   # UNION : count + sous-volumes recursifs
			var n := br.u32()
			if _guard(n, MAX_CHILDREN, "bv_union_count"):
				for _i in range(n):
					_read_bounding_volume()
		5:   # HALFSPACE : plan(4) + origine(3)
			br.f32(); br.f32(); br.f32(); br.f32(); br.vec3()
		0xFFFFFFFF:  # BASE : aucune donnee
			pass
		_:
			# Type inconnu : on ne peut pas sauter sans risque -> on signale.
			failed = true
			suspect = _cur_type
			fail_offset = br.pos()
			fail_reason = "bounding volume type inconnu %d en lisant '%s' @ 0x%X" % [bv_type, _cur_type, br.pos()]
			if not quiet_errors:
				push_error("NIF: " + fail_reason)


## Resynchronisation douce apres un bloc de geometrie triangulee.
## Reserve aux vieux NIF DAoC 4.x sans table de tailles : on ne peut pas
## connaitre la taille exacte du bloc a priori. Si le layout local varie,
## on prefere conserver le mesh deja lu et reprendre au prochain header Ni*.
func _soft_resync_after_geometry(context: String) -> void:
	if failed:
		return
	# Si c'est le dernier bloc, inutile de chercher un nouveau header.
	if _cur_idx >= _num_blocks - 1:
		return
	if _next_is_type_header():
		return

	var start := br.pos()
	var max_scan := maxi(4096, br.length() - start)
	if _resync_to_next_type_header(context, max_scan):
		return

	# Aucun header retrouve : on garde tout ce qui a deja ete lu. C'est mieux
	# qu'un echec dur pour un asset de decor, surtout quand le mesh courant existe.
	_recoverable_warning("NIF SOFT-TRUNCATE: %s illisible apres 0x%X ; conservation des blocs deja lus" % [context, start])
	_stop_reading_early = true
	br.seek(br.length())


## Trace des derniers blocs lus, pour identifier celui dont le lecteur desynchronise.
func _trace() -> String:
	var seq := PackedStringArray()
	var start := maxi(0, blocks.size() - 6)
	for k in range(start, blocks.size()):
		seq.append("%d:%s" % [k, str(blocks[k].get("type", "?"))])
	return "blocs lus juste avant: [%s] (le dernier est le suspect)" % ", ".join(seq)


## Un nom de type NIF valide = identifiant ASCII court (lettres/chiffres/_).
func _looks_like_type(s: String) -> bool:
	if s.length() < 2 or s.length() > 60:
		return false
	# DAoC NetImmerse/Gamebryo : les vrais types rencontres ici sont des types Ni*.
	# Les faux types courts comme "42", "7u", "w6" sont des symptomes de desync.
	if not s.begins_with("Ni"):
		return false
	for i in range(s.length()):
		var c := s.unicode_at(i)
		var ok := (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95
		if not ok:
			return false
	return true


func _next_is_type_header() -> bool:
	return _looks_like_type(br.peek_sized_ascii())


func _resync_to_next_type_header(context: String, max_scan: int = 4096) -> bool:
	# Pas besoin de resync si on est deja exactement au bon endroit.
	if _next_is_type_header():
		return true
	var start := br.pos()
	var limit := mini(br.length() - 6, start + max_scan)
	for p in range(start, limit):
		br.seek(p)
		var next_type := br.peek_sized_ascii()
		if _looks_like_type(next_type):
			br.seek(p)
			_recoverable_warning("NIF RESYNC: %s saute %d octets vers prochain bloc %s @0x%X" % [context, p - start, next_type, p])
			return true
	br.seek(start)
	return false


func _recoverable_warning(message: String) -> void:
	recoverable_warnings.append(message)
	if not quiet_recoverable_warnings:
		push_warning(message)


# =====================================================================
# Blocs implementes depuis reference/nif_spec/nif.xml (jalon
# NIF_SPEC_CONFORMANCE_AND_TOP_BLOCK_COVERAGE).
#
# Motivation : ces blocs ne portent pas de geometrie, mais un bloc dont on
# ignore la taille desynchronise TOUT ce qui suit. Les lire exactement
# supprime des resynchronisations heuristiques.
#
# Dispositions issues de la spec, pour les versions du client DAoC
# (4.1.0.12, 4.2.1.0, 4.2.2.0, 10.1.0.0) :
#
#   NiExtraData (base)  ver <= 4.2.2.0 : Next Extra Data (Ref i32)
#                       ver >= 10.0.1.0 : Name (SizedString)
#   bool                1 octet depuis 4.1.0.1 -> toutes nos versions
#   Flags               u16      TexType / TransformMember : u32
# =====================================================================


## NiStringsExtraData : NiExtraData + Num Strings + Data[] (SizedString).
## Aucun `bytes_remaining` : ce champ appartient a NiStringExtraData (singulier).
func _read_strings_extra_data(with_name: bool) -> Dictionary:
	var b := {"parse_status": "FULLY_PARSED"}
	if with_name:
		b["name"] = br.sized_string()
	else:
		b["next_extra_data_ref"] = br.i32()
	var count := br.u32()
	if not _guard(count, MAX_CHILDREN, "NiStringsExtraData num_strings"):
		return b
	var values: Array[String] = []
	for _i in range(count):
		values.append(br.sized_string())
	b["num_strings"] = count
	b["data"] = values
	return b


## NiIntegerExtraData : NiExtraData + Integer Data (u32).
func _read_integer_extra_data(with_name: bool) -> Dictionary:
	var b := {"parse_status": "FULLY_PARSED"}
	if with_name:
		b["name"] = br.sized_string()
	else:
		b["next_extra_data_ref"] = br.i32()
	b["integer_data"] = br.u32()
	return b


## NiGeomMorpherController, variante Gamebryo 10.1.0.0.
##
## Les cheveux du client utilisent des morph targets : 702 fichiers de
## figures/fig3/ echouaient uniquement parce que ce bloc manquait au dispatch
## 10.x. Il etait deja gere en 4.x, mais la disposition differe d'un champ.
##
## Chaine : NiInterpController -> NiTimeController -> NiObject.
##
##   NiTimeController                                        26 octets
##   NiInterpController.Manager Controlled  ver1=10.1.0.104  ABSENT en 10.1.0.0
##   Extra Flags   Flags(u16)               ver1=10.0.1.2    PRESENT   2
##   Data          Ref(i32)                                            4
##   Always Update byte                     ver1=4.0.0.1     PRESENT   1
##   Num Interpolators                      ver1=10.1.0.106  ABSENT
##                                                            total = 33
##
## `Extra Flags` est la seule difference avec la variante 4.x : l'oublier
## decalait la lecture d'exactement deux octets.
func _read_geom_morpher_controller10() -> Dictionary:
	var b := {"parse_status": "FULLY_PARSED"}
	_read_time_controller(b)
	b["extra_flags"] = br.u16()
	b["data_ref"] = br.i32()
	b["always_update"] = br.u8()
	return b


## NiParticleMeshModifier — LEGACY pre-10.1, donc chemin 4.x uniquement.
##
## NiParticleModifier (base, herite NiObject) :
##   Next Modifier  Ref  i32
##   Controller     Ptr  i32   ver1="4.0.0.2" -> present sur toutes nos versions 4.x
## Champs propres :
##   Num Particle Meshes  uint
##   Particle Meshes      Ref[N]
##
## Taille = 12 + 4*N octets. Remplace le contournement par resynchronisation.
func _read_particle_mesh_modifier() -> Dictionary:
	var b := {"parse_status": "FULLY_PARSED"}
	b["next_modifier_ref"] = br.i32()
	b["controller_ref"] = br.i32()
	var count := br.u32()
	if not _guard(count, MAX_PROPS, "NiParticleMeshModifier num_particle_meshes"):
		return b
	var refs: Array[int] = []
	for _i in range(count):
		refs.append(br.i32())
	b["num_particle_meshes"] = count
	b["particle_mesh_refs"] = refs
	return b


## NiVisData : herite NiObject (aucun champ de base).
## Num Keys + Keys de type Key<byte> avec ARG=1 -> pas de tangentes ni TBC.
## Chaque cle = float temps + 1 octet valeur = 5 octets.
func _read_vis_data() -> Dictionary:
	var b := {"parse_status": "FULLY_PARSED"}
	var count := br.u32()
	if not _guard(count, MAX_CHILDREN, "NiVisData num_keys"):
		return b
	var times: Array[float] = []
	var values: Array[int] = []
	for _i in range(count):
		times.append(br.f32())
		values.append(br.u8())
	b["num_keys"] = count
	b["key_times"] = times
	b["key_values"] = values
	# P1-119 : forme lue par DaocSpellEffectScenes (P1-76, NiVisController).
	var vis_keys: Array = []
	for i in range(times.size()):
		vis_keys.append({"time": times[i], "visible": values[i] != 0})
	b["vis_keys"] = vis_keys
	return b


## NiRangeLODData : herite NiLODData -> NiObject, tous deux sans champ.
## LOD Center (Vector3) + Num LOD Levels + LODRange[] (near f32, far f32).
## Les `Unknown Ints` de LODRange sont ver2="3.1", donc absents ici.
func _read_range_lod_data() -> Dictionary:
	var b := {"parse_status": "FULLY_PARSED"}
	b["lod_center"] = br.vec3()
	var count := br.u32()
	if not _guard(count, MAX_PROPS, "NiRangeLODData num_lod_levels"):
		return b
	var near_extents: Array[float] = []
	var far_extents: Array[float] = []
	for _i in range(count):
		near_extents.append(br.f32())
		far_extents.append(br.f32())
	b["num_lod_levels"] = count
	b["near_extents"] = near_extents
	b["far_extents"] = far_extents
	return b


## NiTextureTransformController.
## Chaine d'heritage : NiTimeController -> NiInterpController ->
## NiSingleInterpController -> NiFloatInterpController -> ce bloc.
##
## Pour nos versions, les champs des classes intermediaires sont ABSENTS :
##   NiInterpController.Manager Controlled  ver 10.1.0.104 a 10.1.0.108
##   NiSingleInterpController.Interpolator  ver >= 10.1.0.104
## Notre 10.1.0.0 (0x0A010000) est anterieur a 10.1.0.104 (0x0A010068).
##
## Disposition effective, identique en 4.x et en 10.1.0.0 : 39 octets.
func _read_texture_transform_controller() -> Dictionary:
	var b := {"parse_status": "FULLY_PARSED"}
	# --- NiTimeController, 26 octets
	b["next_controller_ref"] = br.i32()
	b["flags"] = br.u16()
	b["frequency"] = br.f32()
	b["phase"] = br.f32()
	b["start_time"] = br.f32()
	b["stop_time"] = br.f32()
	b["target_ref"] = br.i32()
	# --- champs propres, 13 octets
	b["shader_map"] = br.boolb()
	b["texture_slot"] = br.u32()
	b["operation"] = br.u32()
	b["data_ref"] = br.i32()
	return b


func _guard(n: int, maxv: int, what: String) -> bool:
	# Compteur de liste lu du fichier : s'il depasse, c'est une desync -> on
	# abandonne le fichier (au lieu d'iterer un range() geant et de figer le jeu).
	if n < 0 or n > maxv:
		failed = true
		suspect = _cur_type
		fail_offset = br.pos()
		fail_block_start = _cur_block_start
		fail_reason = "%s aberrant (%d, max %d) en lisant le bloc %d '%s' @ offset 0x%X — desync : corriger le lecteur de '%s'" % [what, n, maxv, _cur_idx, _cur_type, br.pos(), _cur_type]
		if not quiet_errors:
			push_error("NIF DESYNC: " + fail_reason)
		return false
	return true


func _fail(reason: String, offset: int) -> bool:
	failed = true
	fail_offset = offset
	fail_block_start = _cur_block_start if _cur_block_start != 0 else offset
	fail_reason = "%s @ offset 0x%X (%d)" % [reason, offset, offset]
	if not quiet_errors:
		push_error("NIF FAIL: " + fail_reason)
	if br != null:
		br.close()
	return false
