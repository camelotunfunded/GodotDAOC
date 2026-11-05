extends Node
class_name DaocCombatClient

## Emis a chaque changement de cible. L'interface s'y abonne pour alimenter
## `summary_target` et `summary_target_hits` : sans lui, cibler un rat ne
## remplissait jamais la fenetre de resume.
signal target_changed(object_id: int)

## P1-21A â€” le cote CLIENT de la couture.
##
## Ce noeud ne connait aucune regle de jeu. Il fait trois choses :
##   1. il envoie a l'autorite la position du joueur et ses INTENTIONS
##      (Â« je cible Â», Â« j'attaque Â») ;
##   2. il ecoute les evenements que l'autorite renvoie ;
##   3. il les traduit en pixels â€” barres, journal, anneau de cible, chute du
##      cadavre.
##
## Si on remplace `DaocLocalServer` par un vrai serveur OpenDAoC, ce fichier ne
## bouge pas : il parle a une autorite, pas a une implementation.

## Rayon de l'anneau de cible, en unites DAoC brutes. Heyveno mesure environ
## 68 unites : un anneau de 45 se lit au sol sans avaler le personnage.
const RING_RADIUS_RAW: float = 45.0

var host: Node3D = null
var player: Node3D = null
var server: DaocLocalServer = null
var hud: DaocCombatHud = null

var world_origin: Vector2 = Vector2(491520.0, 491520.0)
var target_radius_raw: float = 2400.0
var target_key: int = KEY_TAB
var attack_key: int = KEY_1
## P1-31B — les touches qui ARMENT un style pour le prochain coup, dans l'ordre
## des styles connus.
##
## CHOIX ASSUME : les touches 2, 3, 4 a cote de la touche d'attaque. Ce n'est pas
## la quickbar du client d'origine — celle de P1-21G-HF2 existe mais n'a aucune
## liaison de commande, et lui en inventer une ici la figerait avant qu'on sache
## ce qu'elle doit porter. Ces touches sont le chemin le plus court vers un
## verdict visuel, pas la forme definitive.
##
## ET C'EST `_input` DE CE NOEUD, PAS LE ROUTEUR. Le clic droit de P1-30 a coute
## une branche MORTE A L'ECRITURE parce que `DaocInputRouter` n'emet
## `world_click` que pour le bouton gauche. Ici la touche d'attaque et TAB
## passent deja par ce meme `_input` et fonctionnent en jeu : le chemin est
## prouve par l'usage, pas suppose.
var style_keys: Array = [KEY_2, KEY_3, KEY_4]
## P1-101 : (keycode, ctrl, alt) -> bool, la quickbar consomme la touche si sa case est remplie.
var quickbar_key_consumer: Callable = Callable()
var death_fall_seconds: float = 0.8
var log_to_console: bool = false

## P1-22D â€” la zone dont les coordonnees LOCALES alimentent `daoc_to_godot`.
## L'arbitre ne connait que des coordonnees MONDE ; `world_origin` fait le pont.
var zone_id: int = -1
## P1-22D â€” suivre les creatures que l'arbitre deplace. Decoche, les scenes
## restent ou le peuplement les a posees, comme avant P1-22D.
var npc_motion_enabled: bool = true
## P1-22B â€” effacer le corps a sa dissipation, le rallumer a la reapparition.
var corpse_visuals_enabled: bool = true

var current_target_id: int = -1

## Traduction resultat d'arbitrage -> geste joue sur la CIBLE. Les noms de clips
## sont ceux du contrat d'insertion exporte par le Character Lab depuis
## canims.csv ; un clip absent ne joue rien, il n'est jamais remplace.
const DEFENSE_CLIP_BY_RESULT: Dictionary = {
	"Parried": ["parry_high", "parry_low"],
	"Evaded": ["evade"],
	"Blocked": ["block_high", "block_low"],
}
## Variantes d'attaque. Le client d'origine alterne la hauteur du coup pour
## varier la silhouette ; aucune consequence de jeu n'y est attachee ici.
const ATTACK_CLIPS := ["attack_med", "attack_high", "attack_low"]
## Clips d'attente cherches, dans l'ordre, pour rendre une creature debout apres
## sa reapparition. Aucun n'est garanti : les scenes creatures n'ont ete
## exportees qu'avec leur mort, d'ou le repli sur la premiere image de celle-ci.
const IDLE_CLIPS := ["idle", "stand", "idle_01", "Idle"]

## P1-133 — hors ligne, meme traduction qu'en ligne : `style` de l'evenement
## (Style.Icon) -> styles.csv -> clip canims, famille de l'arme en main (P1-130)
## et VFX de coup (DaocMeleeHitVfx). Poses par DaocGameWorld.
var style_catalogue: RefCounted = null
var weapon_family: String = ""
var melee_vfx_enabled: bool = true
var melee_vfx_world_scale: float = 1.0
## P1-133 : -1 = hors ligne (etat de l arbitre local) ; 0/1 = dernier 0x74 serveur.
var server_attack_mode: int = -1

var _ring: MeshInstance3D = null
var _ready_done: bool = false
var _player_visual: Node = null
var _swing_index: int = 0


func setup(p_host: Node3D, p_player: Node3D, p_server: DaocLocalServer, p_hud: DaocCombatHud, options: Dictionary = {}) -> void:
	host = p_host
	player = p_player
	server = p_server
	hud = p_hud
	world_origin = options.get("world_origin", world_origin) as Vector2
	target_radius_raw = float(options.get("target_radius_raw", target_radius_raw))
	target_key = int(options.get("target_key", target_key))
	attack_key = int(options.get("attack_key", attack_key))
	log_to_console = bool(options.get("log_to_console", log_to_console))
	zone_id = int(options.get("zone_id", zone_id))
	npc_motion_enabled = bool(options.get("npc_motion_enabled", npc_motion_enabled))
	corpse_visuals_enabled = bool(options.get("corpse_visuals_enabled", corpse_visuals_enabled))

	if server != null:
		server.combat_event.connect(_on_combat_event)
		server.state_changed.connect(_on_state_changed)
		server.entity_died.connect(_on_entity_died)
		server.entity_removed.connect(_on_entity_removed)
		server.entity_moved.connect(_on_entity_moved)
		server.corpse_decayed.connect(_on_corpse_decayed)
		server.entity_respawned.connect(_on_entity_respawned)
	if hud != null:
		hud.set_hint("%s : cibler le plus proche   Â·   %s : attaquer / cesser" % [
			OS.get_keycode_string(target_key), OS.get_keycode_string(attack_key)
		])
		if server != null and bool(server.get("mirror_mode")):
			hud.push_line("Serveur OpenDAoC : entites, positions et jauges du serveur. Combat non branche (B6).")
		else:
			hud.push_line("Serveur local actif. Aucune connexion reseau.")
	_ready_done = true


func _process(_delta: float) -> void:
	if not _ready_done or server == null or not server.booted:
		return
	_push_player_position()
	_refresh_combat_stance()
	_refresh_hud()
	_refresh_ring()


## Le visuel est attache apres coup (`call_deferred`), donc on le cherche tant
## qu'il manque. Reconnu par sa capacite, pas par son nom : n'importe quel
## visuel sachant jouer un geste convient.
func _resolve_player_visual() -> Node:
	if _player_visual != null and is_instance_valid(_player_visual):
		return _player_visual
	_player_visual = null
	if player == null:
		return null
	for child in player.get_children():
		if child.has_method("play_one_shot") and child.has_method("set_combat_stance"):
			_player_visual = child
			break
	return _player_visual


## La garde suit l'engagement reel cote autorite, pas une intention locale.
func _refresh_combat_stance() -> void:
	var visual: Node = _resolve_player_visual()
	if visual == null:
		return
	# P1-133 : en ligne, le 0x74 du serveur fait foi (le miroir n attaque jamais).
	var stance := server_attack_mode == 1 if server_attack_mode >= 0 else server.is_attacking(server.player_object_id)
	visual.call("set_combat_stance", stance)


func _play_player_clip(clip_name: String) -> bool:
	var visual: Node = _resolve_player_visual()
	if visual == null:
		return false
	return bool(visual.call("play_one_shot", clip_name))


## Premier clip reellement present dans la scene, sans repli invente.
func _spawn_melee_vfx(attacker_id: int, target_id: int, result: String, style_color: Variant) -> void:
	if not melee_vfx_enabled or server == null:
		return
	var attacker_node: Node3D = player if attacker_id == server.player_object_id else server.get_node_for(attacker_id)
	var target_node: Node3D = player if target_id == server.player_object_id else server.get_node_for(target_id)
	# Le joueur local : son visuel porte le squelette, pas la capsule.
	if attacker_id == server.player_object_id and _resolve_player_visual() is Node3D:
		attacker_node = _resolve_player_visual() as Node3D
	if attacker_node != null and result != DaocCombatEnums.RESULT_FUMBLED:
		DaocMeleeHitVfx.spawn_trail(attacker_node, style_color, 0.45, melee_vfx_world_scale)
	if target_node != null:
		DaocMeleeHitVfx.spawn_impact(target_node, attacker_node, result, style_color, melee_vfx_world_scale)


func _play_first_available(clip_names: Array) -> bool:
	var visual: Node = _resolve_player_visual()
	if visual == null:
		return false
	for clip_name_value in clip_names:
		var clip_name := str(clip_name_value)
		if bool(visual.call("has_clip", clip_name)):
			return bool(visual.call("play_one_shot", clip_name))
	return false


## Le monde bouge cote client ; l'autorite doit le savoir pour juger la portee.
func _push_player_position() -> void:
	if player == null or server.player_object_id < 0:
		return
	var daoc_x: Variant = player.get("daoc_x")
	var daoc_y: Variant = player.get("daoc_y")
	var daoc_z: Variant = player.get("daoc_z")
	# Les capsules DAoC exposent ces trois champs. Un hote de test ou un futur
	# avatar peut ne fournir que sa position 3D : ce repli garde le client de
	# combat decouple du script visuel concret.
	var x_raw := float(daoc_x) if daoc_x != null else player.global_position.x - world_origin.x
	var y_raw := float(daoc_y) if daoc_y != null else player.global_position.z - world_origin.y
	var z_raw := float(daoc_z) if daoc_z != null else player.global_position.y
	server.set_entity_world_position(server.player_object_id, Vector3(
		world_origin.x + x_raw,
		world_origin.y + y_raw,
		z_raw
	))


func _input(event: InputEvent) -> void:
	if not _ready_done or server == null or not server.booted:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event.ctrl_pressed or key_event.alt_pressed:
		return
	# P1-101 : une case de quickbar remplie a la priorite sur 1 = attaque, 2-4 = styles.
	if quickbar_key_consumer.is_valid() and bool(quickbar_key_consumer.call(key_event.keycode, false, false)):
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode == target_key:
		target_nearest()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == attack_key:
		toggle_attack()
		get_viewport().set_input_as_handled()
	elif style_keys.has(key_event.keycode):
		arm_style_slot(style_keys.find(key_event.keycode))
		get_viewport().set_input_as_handled()


# --------------------------------------------------------------------------
# Intentions
# --------------------------------------------------------------------------

## P1-31B — arme le style occupant ce rang parmi ceux que le joueur CONNAIT.
##
## LE CLIENT NE CHOISIT RIEN, il designe. Il demande la liste a l'autorite, en
## prend le n-ieme et renvoie son NOM ; c'est l'arbitre qui decide si le style
## est appris, si son ouverture est satisfaite, ce qu'il coute et ce qu'il rend.
## Un rang qui deciderait ici de la legalite ferait tomber P1-28.
func arm_style_slot(slot_index: int) -> Dictionary:
	if server == null or not server.has_method("request_style"):
		return {"ok": false, "reason": "arbitre sans styles"}
	if slot_index < 0:
		return {"ok": false, "reason": "rang invalide"}
	var known: Array = server.known_styles(server.player_object_id)
	if slot_index >= known.size():
		# UN RANG VIDE N'EST PAS UNE PANNE. Sous le niveau 8 un personnage ne
		# connait AUCUN style — aucun n'existe sous le niveau de specialisation 2
		# et l'auto-entrainement donne niveau / 4. Le dire evite de chercher un
		# bug qui n'existe pas.
		if hud != null:
			hud.push_line("Aucun style a ce rang (%d connu(s))." % known.size())
		return {"ok": false, "reason": "rang vide", "known": known.size()}

	var style_name := str((known[slot_index] as Dictionary).get("name", ""))
	var result: Dictionary = server.request_style(server.player_object_id, style_name)
	result["style_name"] = style_name
	# MEME REGLE QU'AU RAMASSAGE : les refus sont RENDUS et non emis, donc sans
	# relais un appui de touche ne dit rien et le joueur croit que la touche
	# n'existe pas. C'est exactement ce qui s'est produit avec le clic droit.
	if hud != null:
		if bool(result.get("ok", false)):
			hud.push_line("%s : arme pour le prochain coup." % style_name)
		else:
			hud.push_line("%s : %s." % [style_name, str(result.get("reason", "refus sans motif"))])
	return result


## Le client ne sait pas qui est vivant : il DEMANDE a l'autorite.
func target_nearest() -> Dictionary:
	var from: Vector3 = server.get_entity_world_position(server.player_object_id)
	var found: Dictionary = server.nearest_attackable(from, target_radius_raw, server.player_object_id)
	if not bool(found.get("ok", false)):
		_set_target(-1)
		if hud != null:
			hud.clear_target()
			hud.push_line("Aucune cible a portee de vue.")
		return found
	_set_target(int(found.get("object_id", -1)))
	if hud != null:
		hud.push_line("Cible : %s (niv %d)." % [str(found.get("name", "?")), int(found.get("level", 0))])
	return found


## Cible une entite par son identifiant, quelle que soit l'origine de la demande
## — TAB, souris, ou une commande. Un seul chemin change la cible (`_set_target`),
## donc l'anneau, le HUD et les fenetres d'origine suivent tous de la meme facon.
## Renvoie l'instantane de la cible avec `ok`, ou `ok=false` si l'entite est
## inconnue de l'autorite.
func target_object(object_id: int, announce: bool = true) -> Dictionary:
	if server == null:
		return {"ok": false, "reason": "aucune autorite"}
	var snapshot: Dictionary = server.snapshot(object_id)
	if snapshot.is_empty():
		return {"ok": false, "reason": "entite inconnue"}
	_set_target(object_id)
	if announce and hud != null:
		hud.push_line("Cible : %s (niv %d)." % [str(snapshot.get("name", "?")), int(snapshot.get("level", 0))])
	snapshot["ok"] = true
	return snapshot


func target_self(announce: bool = true) -> Dictionary:
	if server == null or server.player_object_id < 0:
		return {"ok": false, "reason": "joueur inconnu"}
	return target_object(server.player_object_id, announce)


## Resout un clic ecran vers l'entite sous le pointeur, puis la cible.
##
## Les PNJ n'ont pas de corps physique dans cette scene : un `intersect_ray`
## physique ne les toucherait pas. On teste donc le rayon de la camera active
## contre l'EMPRISE VISUELLE (AABB monde) de chaque entite pointable, et on
## retient la plus proche le long du rayon. `pixel_tolerance` elargit l'emprise
## d'une marge exprimee en pixels a la profondeur de la cible, pour rattraper une
## silhouette fine (un rat) quand le rayon passe juste a cote. `max_distance_raw`
## (>0) rejette une cible trop lointaine, mesuree au sol comme le HUD.
func pick_target_at_screen(screen_position: Vector2, pixel_tolerance: float = 8.0, max_distance_raw: float = 0.0) -> Dictionary:
	if host == null or server == null:
		return {"ok": false, "reason": "hote absent"}
	var best_id: int = _pick_object_at_screen(screen_position, pixel_tolerance, false)
	if best_id == -2:
		return {"ok": false, "reason": "camera absente"}

	if best_id < 0:
		if hud != null:
			hud.push_line("Aucune cible sous le pointeur.")
		return {"ok": false, "reason": "rien sous le pointeur"}

	if max_distance_raw > 0.0 and server.player_object_id >= 0:
		var from: Vector3 = server.get_entity_world_position(server.player_object_id)
		var target_position: Vector3 = server.get_entity_world_position(best_id)
		var ground: float = Vector2(from.x, from.y).distance_to(Vector2(target_position.x, target_position.y))
		if ground > max_distance_raw:
			if hud != null:
				hud.push_line("Cible trop loin.")
			return {"ok": false, "reason": "hors de portee", "object_id": best_id}

	return target_object(best_id)


## P1-30 — LE RAMASSAGE DEVIENT ATTEIGNABLE.
##
## `DaocLocalServer.loot_corpse` existait depuis P1-22C et n'avait AUCUN appelant
## hors des suites : ni touche, ni commande, ni clic, ni fenetre. Le jalon avait
## prouve la REGLE du butin, jamais son acces — un verdict visuel du 2026-09-09 a
## bute dessus, l'utilisateur cherchant a ramasser un corps que rien ne permettait
## d'ouvrir.
##
## LE GESTE EST UNE DECISION, PAS UNE LECTURE. Aucune capture ne porte le geste
## d'origine de DAoC : les 17 opcodes de P1-20E ont ete enumeres et aucun n'est un
## ramassage. Le CLIC DROIT sur le cadavre est donc CHOISI ici — il laisse le clic
## gauche au ciblage de P1-21H, qu'il ne faut pas surcharger. A remplacer sans
## etat d'ame le jour ou une capture dira mieux.
##
## LE CLIENT NE DECIDE DE RIEN : il designe un cadavre et transmet. Le contenu, la
## distance, le « deja pille » et le refus sont tous rendus par l'arbitre. Une
## regle de butin ecrite ici ferait tomber P1-28 en nommant ce fichier.
func loot_at_screen(screen_position: Vector2, pixel_tolerance: float = 8.0) -> Dictionary:
	if host == null or server == null:
		return {"ok": false, "reason": "hote absent"}
	if not server.has_method("loot_corpse"):
		return {"ok": false, "reason": "arbitre sans butin"}
	if server.player_object_id < 0:
		return {"ok": false, "reason": "joueur inconnu"}

	var corpse_id: int = _pick_object_at_screen(screen_position, pixel_tolerance, true)
	if corpse_id == -2:
		return {"ok": false, "reason": "camera absente"}
	if corpse_id < 0:
		if hud != null:
			hud.push_line("Aucun corps sous le pointeur.")
		return {"ok": false, "reason": "rien sous le pointeur"}

	var result: Dictionary = server.loot_corpse(server.player_object_id, corpse_id) as Dictionary
	result["object_id"] = corpse_id
	# UN SUCCES N'EST PAS REPETE ICI. L'arbitre emet deja un evenement `loot`
	# portant son propre texte, que le journal affiche par le chemin ordinaire ;
	# le redire produirait la ligne en double. Seuls les REFUS sont relayes, parce
	# qu'ils sont RENDUS et non emis — sans cela un clic refuse ne dit rien, et
	# l'utilisateur croit que le geste n'existe pas. C'est exactement ce qui vient
	# de se produire.
	if not bool(result.get("ok", false)) and hud != null:
		hud.push_line("Ramassage impossible : %s." % str(result.get("reason", "refus sans motif")))
	return result


## Selecteur partage par le ciblage et le ramassage. Rend l'`object_id` le plus
## proche le long du rayon, `-1` si rien, `-2` si aucune camera n'est active —
## une distinction qui compte : « rien sous le pointeur » est un resultat, une
## camera absente est une panne, et les confondre ferait passer la seconde pour
## un clic dans le vide.
##
## `want_corpse` bascule la population regardee. Le vivant et le mort partagent
## le meme noeud — `_on_corpse_decayed` masque la scene sans la detruire — donc
## seul l'arbitre sait lequel est lequel, et c'est `is_corpse` qui tranche.
func _pick_object_at_screen(screen_position: Vector2, pixel_tolerance: float, want_corpse: bool) -> int:
	var viewport: Viewport = host.get_viewport()
	var camera: Camera3D = viewport.get_camera_3d() if viewport != null else null
	if camera == null:
		return -2

	var origin: Vector3 = camera.project_ray_origin(screen_position)
	var direction: Vector3 = camera.project_ray_normal(screen_position)
	var viewport_height: float = float(viewport.get_visible_rect().size.y)
	var tan_half_fov: float = tan(deg_to_rad(camera.fov) * 0.5)
	var can_test_corpse: bool = server.has_method("is_corpse")

	var best_id: int = -1
	var best_t: float = INF
	# Le joueur n'appartient pas au peuplement des PNJ en ligne, mais son avatar
	# reste une cible valide pour les soins et améliorations.
	# P1-103 : LE JOUEUR NE PASSE PLUS EN PREMIER. En vue a la troisieme
	# personne il occupe le centre de l'ecran et sa boite est TOUJOURS la plus
	# proche de la camera : un clic sur un PNJ derriere lui rendait le joueur
	# (« le ciblage a la souris ne fonctionne pas », 2026-09-21). Son avatar
	# reste ciblable, mais seulement si rien d'autre n'est sous le pointeur.
	for entry_value in server.targetable_entries():
		var entry: Dictionary = entry_value as Dictionary
		if bool(entry.get("is_player", false)):
			continue
		var object_id: int = int(entry.get("object_id", -1))
		if want_corpse:
			# Un cadavre n'est pas seulement « pas vivant » : une entite retiree du
			# monde ne l'est pas non plus. On demande donc a l'arbitre.
			if not can_test_corpse or not bool(server.is_corpse(object_id)):
				continue
		# LE CIBLAGE N'EST PAS FILTRE SUR `alive`, ET C'EST VOULU : c'etait deja
		# le cas avant P1-30, et `_on_entity_died` efface la cible par son propre
		# chemin. Ajouter un filtre ici changerait P1-21H au lieu de le partager.
		var node: Node3D = entry.get("node") as Node3D
		if node == null:
			continue
		var box: AABB = _world_visual_aabb(node)
		if pixel_tolerance > 0.0 and viewport_height > 0.0 and tan_half_fov > 0.0:
			var center: Vector3 = box.position + box.size * 0.5
			var depth: float = maxf(origin.distance_to(center), 0.001)
			# Taille monde d'un pixel a cette profondeur, pour une camera perspective.
			var world_per_pixel: float = depth * tan_half_fov * 2.0 / viewport_height
			box = box.grow(pixel_tolerance * world_per_pixel)
		var t: float = _ray_aabb_entry_distance(origin, direction, box)
		if t < 0.0:
			continue
		if t < best_t:
			best_t = t
			best_id = object_id
	if best_id < 0 and not want_corpse and player != null and is_instance_valid(player):
		var player_box := _world_visual_aabb(player)
		if pixel_tolerance > 0.0 and viewport_height > 0.0 and tan_half_fov > 0.0:
			var player_depth := maxf(origin.distance_to(player_box.get_center()), 0.001)
			player_box = player_box.grow(pixel_tolerance * player_depth * tan_half_fov * 2.0 / viewport_height)
		if _ray_aabb_entry_distance(origin, direction, player_box) >= 0.0:
			best_id = server.player_object_id

	return best_id


## Emprise monde d'une entite : union des AABB de tous ses `VisualInstance3D`,
## transformees en coordonnees monde. Independant de la presence d'un corps
## physique.
func _world_visual_aabb(node: Node3D) -> AABB:
	var accumulated: AABB = AABB()
	var has_any: bool = false
	var stack: Array = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is VisualInstance3D:
			var visual: VisualInstance3D = current as VisualInstance3D
			var world_box: AABB = visual.global_transform * visual.get_aabb()
			if has_any:
				accumulated = accumulated.merge(world_box)
			else:
				accumulated = world_box
				has_any = true
		for child in current.get_children():
			stack.append(child)
	if not has_any:
		# Aucune geometrie visible : on retombe sur un petit volume au pivot pour
		# rester pointable sans inventer de taille.
		return AABB(node.global_position - Vector3(20.0, 20.0, 20.0), Vector3(40.0, 40.0, 40.0))
	return accumulated


## Distance d'entree du rayon dans l'AABB (methode des tranches), ou -1 si le
## rayon ne la touche pas devant lui. Un rayon partant a l'interieur renvoie 0.
func _ray_aabb_entry_distance(origin: Vector3, direction: Vector3, box: AABB) -> float:
	var box_min: Vector3 = box.position
	var box_max: Vector3 = box.position + box.size
	var t_min: float = -INF
	var t_max: float = INF
	for axis in 3:
		var o: float = origin[axis]
		var d: float = direction[axis]
		if absf(d) < 0.0000001:
			if o < box_min[axis] or o > box_max[axis]:
				return -1.0
			continue
		var t1: float = (box_min[axis] - o) / d
		var t2: float = (box_max[axis] - o) / d
		if t1 > t2:
			var swap: float = t1
			t1 = t2
			t2 = swap
		t_min = maxf(t_min, t1)
		t_max = minf(t_max, t2)
		if t_min > t_max:
			return -1.0
	if t_max < 0.0:
		return -1.0
	return maxf(t_min, 0.0)


func toggle_attack() -> Dictionary:
	if server.player_object_id < 0:
		return {"ok": false, "reason": "aucun joueur"}
	if server.is_attacking(server.player_object_id):
		return server.stop_attack(server.player_object_id)
	if current_target_id < 0:
		# Confort : attaquer sans cible prend la plus proche, comme le client
		# d'origine le fait avec sa touche d'attaque.
		var found: Dictionary = target_nearest()
		if not bool(found.get("ok", false)):
			return {"ok": false, "reason": "aucune cible"}
	var result: Dictionary = server.request_attack(server.player_object_id, current_target_id)
	if not bool(result.get("ok", false)) and hud != null:
		hud.push_line("Impossible d'attaquer : %s." % str(result.get("reason", "?")))
	return result


## Un seul endroit change la cible, donc un seul endroit previent l'interface.
func _set_target(object_id: int) -> void:
	if current_target_id == object_id:
		return
	current_target_id = object_id
	target_changed.emit(object_id)


func clear_target() -> void:
	_set_target(-1)
	if hud != null:
		hud.clear_target()


# --------------------------------------------------------------------------
# Retours de l'autorite
# --------------------------------------------------------------------------

func _on_combat_event(event: Dictionary) -> void:
	var text: String = str(event.get("text", ""))
	if hud != null:
		hud.push_line(text)
	if log_to_console and text != "":
		print("COMBAT %s" % text)
	_animate_event(event)


## Traduit un evenement d'arbitrage en geste. Le joueur est le seul acteur
## anime ici : les PNJ n'ont pas encore de clips de combat exportes, seulement
## leur mort. Rien ne leur est substitue en attendant.
func _animate_event(event: Dictionary) -> void:
	if str(event.get("kind", "")) != "swing":
		return
	var player_id: int = server.player_object_id
	var attacker_id: int = int(event.get("attacker_id", -1))
	var target_id: int = int(event.get("target_id", -1))
	var result: String = str(event.get("result", ""))
	var style_info: Dictionary = {}
	if style_catalogue != null and int(event.get("style", 0)) > 0:
		style_info = style_catalogue.call("resolve", int(event.get("style", 0)))
	var style_color: Variant = style_info.get("color") if bool(style_info.get("ok", false)) else null
	_spawn_melee_vfx(attacker_id, target_id, result, style_color)

	if attacker_id == player_id:
		# Le coup part meme quand il rate : c'est la parade ou l'esquive d'en
		# face qui l'annule, pas l'absence de geste.
		_swing_index += 1
		var clips := DaocWeaponAnimationFamily.attack_clips(weapon_family, _swing_index)
		if str(style_info.get("clip", "")) != "":
			clips.push_front(str(style_info["clip"]))
		_play_first_available(clips)
		return

	if target_id != player_id:
		return
	if DEFENSE_CLIP_BY_RESULT.has(result):
		_play_first_available(DaocWeaponAnimationFamily.defense_clips(weapon_family, result))
	elif int(event.get("damage", 0)) > 0:
		_play_player_clip("flinch")


## P1-22D â€” l'arbitre a deplace une creature ; on repose sa scene au bon endroit.
##
## LE `z` VIENT D'ICI, PAS DU SERVEUR. L'arbitre decide du X et du Y ; lui seul
## ne connait pas le relief. C'est l'hote qui echantillonne le sol, exactement
## comme le peuplement le fait a la creation â€” sans quoi une creature qui
## descend une pente resterait a l'altitude de son point de depart.
func _on_entity_moved(object_id: int, world_position: Vector3) -> void:
	if not npc_motion_enabled or host == null or server == null:
		return
	var node: Node3D = server.get_node_for(object_id)
	if node == null or not is_instance_valid(node):
		return
	var local_x: float = world_position.x - world_origin.x
	var local_y: float = world_position.y - world_origin.y
	var ground_z: float = world_position.z
	if host.has_method("sample_daoc_floor_z"):
		ground_z = float(host.call("sample_daoc_floor_z", zone_id, local_x, local_y, world_position.z))
	if not host.has_method("daoc_to_godot"):
		return
	var placed: Vector3 = host.call("daoc_to_godot", zone_id, local_x, local_y, ground_z) as Vector3
	# On tourne la creature vers son deplacement : une scene qui glisse de cote
	# se lit immediatement comme un defaut, meme sans animation de marche.
	var previous: Vector3 = node.global_position
	node.global_position = placed
	var travel: Vector2 = Vector2(placed.x - previous.x, placed.z - previous.z)
	if travel.length() > 0.001:
		node.rotation.y = atan2(travel.x, travel.y)


## P1-22B â€” le corps se dissipe : on efface la scene sans la detruire. Elle
## resservira a la reapparition, et reinstancier une scene DAoC complete coute
## exactement ce que R2 a rendu visible.
func _on_corpse_decayed(object_id: int, _snapshot: Dictionary) -> void:
	if not corpse_visuals_enabled or server == null:
		return
	var node: Node3D = server.get_node_for(object_id)
	if node != null and is_instance_valid(node):
		node.visible = false


## P1-22B â€” la creature revient : on rallume sa scene a son point d'apparition,
## debout, et on efface la cible du joueur si elle la designait morte.
func _on_entity_respawned(object_id: int, _snapshot: Dictionary) -> void:
	if not corpse_visuals_enabled or server == null:
		return
	var node: Node3D = server.get_node_for(object_id)
	if node == null or not is_instance_valid(node):
		return
	node.visible = true
	# La chute du cadavre a couche la scene : on la redresse. Sans cela une
	# creature reapparait vivante ET a plat ventre.
	node.rotation.x = 0.0
	node.rotation.z = 0.0
	# VERDICT VISUEL DU 2026-09-09 : la creature revenait EN POSTURE DE MORT.
	# Redresser la rotation ne defait que le repli par tween. Une creature qui
	# possede un clip "death" garde sa DERNIERE IMAGE, parce que `_play_death`
	# le joue en LOOP_NONE et que plus rien ne le rembobine ensuite.
	_reset_death_pose(node)
	_on_entity_moved(object_id, server.get_entity_world_position(object_id))


func _on_state_changed(_object_id: int, _snapshot: Dictionary) -> void:
	# Le HUD relit l'etat a chaque frame ; ce signal sert surtout aux futurs
	# consommateurs (flottants de degats, sons).
	pass


func _on_entity_died(object_id: int, _snapshot: Dictionary) -> void:
	if object_id == server.player_object_id:
		var visual := _resolve_player_visual()
		if visual != null and visual.has_method("play_persistent"):
			visual.call("play_persistent", "death")
		else:
			_play_player_clip("death")
		return
	if object_id == current_target_id:
		# La cible reste affichee morte une frame de plus, puis disparait.
		_set_target(-1)
	_play_death(object_id)


## Un retrait du flux n'est pas une mort : on efface la cible et l'anneau sans
## jouer d'agonie. L'arbitre a deja annule les combats qui la concernaient.
func _on_entity_removed(object_id: int, _snapshot: Dictionary, _reason: String) -> void:
	if object_id == current_target_id:
		clear_target()


## Mort d'un PNJ. Les scenes preconverties portent deja leur clip `death` natif :
## on le joue quand il existe. Sinon, et seulement sinon, le corps bascule â€” un
## repli explicite, pas une animation inventee.
func _play_death(object_id: int) -> void:
	var node: Node3D = server.get_node_for(object_id)
	if node == null:
		return
	var animation_player: AnimationPlayer = _find_animation_player(node)
	if animation_player != null and animation_player.has_animation("death"):
		var animation: Animation = animation_player.get_animation("death")
		if animation != null:
			# Une agonie ne boucle pas. Les scenes creatures ont ete construites
			# avant que cette distinction existe.
			animation.loop_mode = Animation.LOOP_NONE
		animation_player.stop()
		animation_player.play("death")
		return
	var tween: Tween = node.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(node, "rotation:x", node.rotation.x - PI * 0.5, death_fall_seconds)


## Rembobine la mort. `stop()` seul NE SUFFIT PAS : il arrete la lecture mais
## laisse le squelette sur la pose deja appliquee. Il faut en REAPPLIQUER une.
## On prefere un clip d'attente ; a defaut la PREMIERE image de l'agonie, qui
## est par construction le debout dont elle part.
func _reset_death_pose(node: Node3D) -> void:
	var animation_player: AnimationPlayer = _find_animation_player(node)
	if animation_player == null:
		return
	animation_player.stop()
	for clip_name_value in IDLE_CLIPS:
		var clip_name := str(clip_name_value)
		if animation_player.has_animation(clip_name):
			animation_player.play(clip_name)
			return
	if not animation_player.has_animation("death"):
		return
	animation_player.play("death")
	animation_player.seek(0.0, true)
	animation_player.stop()


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null


# --------------------------------------------------------------------------
# Affichage
# --------------------------------------------------------------------------

func _refresh_hud() -> void:
	if hud == null:
		return
	hud.update_player(server.snapshot(server.player_object_id))
	if current_target_id < 0:
		hud.clear_target()
		return
	var snapshot: Dictionary = server.snapshot(current_target_id)
	if snapshot.is_empty():
		hud.clear_target()
		return
	var player_position: Vector3 = server.get_entity_world_position(server.player_object_id)
	var target_position: Vector3 = server.get_entity_world_position(current_target_id)
	var distance: float = Vector2(player_position.x, player_position.y).distance_to(
		Vector2(target_position.x, target_position.y))
	hud.update_target(snapshot, distance, distance <= server.melee_range_raw)


func _refresh_ring() -> void:
	if host == null:
		return
	if current_target_id < 0:
		if _ring != null:
			_ring.visible = false
		return
	var node: Node3D = server.get_node_for(current_target_id)
	if node == null:
		if _ring != null:
			_ring.visible = false
		return
	_ensure_ring()
	_ring.visible = true
	_ring.global_position = node.global_position


func _ensure_ring() -> void:
	if _ring != null:
		return
	_ring = MeshInstance3D.new()
	_ring.name = "DaocTargetRing"
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = RING_RADIUS_RAW * 0.82
	mesh.outer_radius = RING_RADIUS_RAW
	mesh.rings = 24
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.86, 0.35, 0.9)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.78, 0.25)
	material.emission_energy_multiplier = 1.6
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	_ring.mesh = mesh
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(_ring)


func get_debug_snapshot() -> Dictionary:
	var visual: Node = _resolve_player_visual()
	return {
		"target_object_id": current_target_id,
		"attacking": server != null and server.player_object_id >= 0 and server.is_attacking(server.player_object_id),
		"target_key": OS.get_keycode_string(target_key),
		"attack_key": OS.get_keycode_string(attack_key),
		"world_origin": [world_origin.x, world_origin.y],
		"player_visual_found": visual != null,
		"player_visual": (visual.call("build_status_report") if visual != null and visual.has_method("build_status_report") else {}),
	}
