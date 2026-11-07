class_name Missions
extends RefCounted
## Missioni brevi dei mercanti (vedi ShopPanel e Game): ogni
## mercante ne propone una, una sola alla volta si può accettare, e
## danno una direzione all'esplorazione. Parametri in data/missions.json.
## - "clear" (libera la radura): una banda di nemici, con un élite, si
##   accampa lontano; arrivandoci vicino ("trigger" pixel) compare (vedi
##   Game._update_mission) e la missione finisce quando sono tutti abbattuti;
##   allontanandosi troppo ("release") la banda sparisce e torna quella che
##   resta.
## - "crate" (recupera il forziere): un forziere lontano da trovare e aprire.
## L'obiettivo si sceglie dove si arriva a piedi dal mercante (vedi
## World.reach_field), tra "distance" pixel; sulla mappa c'è la bandierina
## (vedi World.marks). La ricompensa (denaro, un oggetto, esperienza) arriva
## subito, a missione compiuta. Si salva solo la missione accettata
## (save_state): i campi mancanti dei salvataggi vecchi vogliono dire
## nessuna missione.

const DATA := preload("res://data/missions.json")
const TYPES := ["clear", "crate"]

## Missione accettata ({} se nessuna): tipo, obiettivo, nemici in tutto e
## già abbattuti (clear), denaro della ricompensa.
var active := {}
## Missione proposta da ogni mercante (posizione del banco -> missione),
## finché non la si accetta.
var _offers := {}


## La missione che propone il mercante in merchant (la sceglie la
## prima volta): {} se non ne trova una possibile.
func offer_for(merchant: Vector2, world: World, level: int) -> Dictionary:
	if _offers.has(merchant):
		return _offers[merchant]
	var target := _pick_target(merchant, world)
	if target == Vector2.INF:
		return {}
	var reward: Dictionary = DATA.data["reward"]
	var clear: Dictionary = DATA.data["clear"]
	var enemies: Array = clear["enemies"]
	var offer := {
		"type": TYPES[randi() % TYPES.size()], "target": target, "killed": 0,
		"total": mini(roundi(float(enemies[0]) + float(enemies[1]) * (level - 1)), int(clear["max"])),
		"gold": randi_range(int(reward["gold"][0]), int(reward["gold"][1])) + int(reward["gold_per_level"]) * (level - 1),
	}
	_offers[merchant] = offer
	return offer


## Accetta la missione del mercante (se non ce n'è già una).
func accept(merchant: Vector2) -> bool:
	if not active.is_empty() or not _offers.has(merchant):
		return false
	active = (_offers[merchant] as Dictionary).duplicate()
	active["spawned"] = false
	_offers.erase(merchant)
	return true


func is_active() -> bool:
	return not active.is_empty()


## Testo della missione in corso per l'HUD.
func status_text() -> String:
	if active.is_empty():
		return ""
	if active["type"] == "clear":
		return TranslationServer.translate("MISSION_STATUS_CLEAR") % [int(active["killed"]), int(active["total"])]
	return TranslationServer.translate("MISSION_STATUS_CRATE")


## Esperienza della ricompensa al livello dato.
static func reward_xp(level: int) -> int:
	return int(DATA.data["reward"]["xp_per_level"]) * level


## Un punto da cui si arriva a piedi dal mercante, tra "distance" pixel
## (Vector2.INF se non se ne trova).
func _pick_target(merchant: Vector2, world: World) -> Vector2:
	var distance: Array = DATA.data["distance"]
	var climb := Enemy.HOP_LEVELS * world.level_height + World.STEP_TOLERANCE
	var field := world.reach_field(merchant, float(distance[1]) + World.CELL, climb)
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in field:
		var gap := World.cell_center(cell).distance_to(merchant)
		if gap >= float(distance[0]) and gap <= float(distance[1]):
			candidates.append(cell)
	if candidates.is_empty():
		return Vector2.INF
	return world.free_position_near(World.cell_center(candidates[randi() % candidates.size()]), 40.0)


## Stato da salvare: la missione accettata (o niente).
func save_state() -> Dictionary:
	if active.is_empty():
		return {}
	return {"type": active["type"], "target": SaveGame.array(active["target"]), "killed": active["killed"],
			"total": active["total"], "gold": active["gold"]}


func load_state(data: Dictionary) -> void:
	active = {}
	if data.is_empty() or not str(data.get("type", "")) in TYPES or not data.has("target"):
		return
	active = {"type": str(data["type"]), "target": SaveGame.vector(data["target"]), "killed": int(data.get("killed", 0)),
			"total": int(data.get("total", 4)), "gold": int(data.get("gold", 40)), "spawned": false}
