class_name Items
## Oggetti che si trovano nelle casse, che lasciano i nemici abbattuti o che
## si comprano dai mercanti ("shop_only": solo dai mercanti, "boss_only":
## solo dai boss), definiti in data/items.json.
##
## Categorie: "gold" (monete), armi ("weapon"), equipaggiamento ("armor",
## "boots", "amulet", "ring": uno per tipo), libri di magia ("book", si
## leggono una volta e migliorano per sempre) e pozioni ("potion").
## Bonus possibili: damage (danni +%), health (vita massima), speed
## (velocità +%), mana (mana massimo), spell (potenza della magia +%),
## heal e restore_mana per le pozioni.

const DATA := preload("res://data/items.json")
## Categorie che si equipaggiano, una per tipo.
const EQUIPMENT := ["weapon", "armor", "boots", "amulet", "ring"]


static func get_item(id: String) -> Dictionary:
	return DATA.data["items"][id]


static func category(id: String) -> String:
	return get_item(id)["category"]


static func color(id: String) -> Color:
	var values: Array = get_item(id)["color"]
	return Color(values[0], values[1], values[2])


## Chiave di traduzione del nome.
static func name_key(id: String) -> String:
	return "ITEM_" + id.to_upper()


static func is_equipment(id: String) -> bool:
	return category(id) in EQUIPMENT


## Bonus dell'oggetto per una caratteristica (0 se non ce l'ha).
static func stat(id: String, key: String) -> float:
	return float(get_item(id).get(key, 0.0))


## Prezzo dal mercante (si vende a una parte del prezzo, vedi data/world.json).
static func value(id: String) -> int:
	return int(get_item(id).get("value", 0))


## Potenza dell'oggetto, per ordinare l'inventario: somma dei suoi bonus
## pesati con "power_weights" di data/items.json.
static func power(id: String) -> float:
	var total := 0.0
	var weights: Dictionary = DATA.data["power_weights"]
	for key: String in weights:
		total += stat(id, key) * float(weights[key])
	return total


## Oggetti rari che vendono solo i mercanti: nelle casse non ci sono.
static func shop_items() -> Array[String]:
	return _flagged("shop_only")


## Oggetti speciali che lasciano solo i boss.
static func boss_items() -> Array[String]:
	return _flagged("boss_only")


static func _flagged(flag: String) -> Array[String]:
	var result: Array[String] = []
	for id: String in DATA.data["items"]:
		if get_item(id).get(flag, false):
			result.append(id)
	return result


## Si trovano a caso (nelle casse e addosso ai nemici): non quelli dei
## mercanti né quelli dei boss.
static func _random_kind(item: Dictionary) -> bool:
	return not item.get("shop_only", false) and not item.get("boss_only", false)


## Quello che lascia un nemico abbattuto: ogni tanto monete o una pozione
## (di vita, di mana o di vigore), di rado un oggetto e molto di rado un oggetto raro
## dei mercanti.
static func enemy_drops(level: int) -> Array[Array]:
	var data: Dictionary = DATA.data["enemy_drop"]
	var drops: Array[Array] = []
	if randf() < float(data["gold_chance"]):
		var gold: Array = data["gold"]
		drops.append(["gold", randi_range(gold[0], gold[1]) + int(data["gold_per_level"]) * (level - 1)])
	if randf() < float(data.get("potion_chance", 0.0)):
		drops.append(["potion_health", 1])
	elif randf() < float(data.get("mana_potion_chance", 0.0)):
		drops.append(["potion_mana", 1])
	elif randf() < float(data.get("stamina_potion_chance", 0.0)):
		drops.append(["potion_stamina", 1])
	if randf() < float(data["rare_chance"]):
		var rare := shop_items()
		drops.append([rare[randi() % rare.size()], 1])
	elif randf() < float(data["item_chance"]):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var id := pick_random(level, rng)
		if id != "gold":
			drops.append([id, 1])
	return drops


static func chest_data() -> Dictionary:
	return DATA.data["chest"]


## Sceglie un oggetto a caso, pesato, tra quelli adatti al livello.
static func pick_random(level: int, rng: RandomNumberGenerator) -> String:
	var items: Dictionary = DATA.data["items"]
	var total := 0.0
	for id: String in items:
		if int(items[id].get("min_level", 1)) <= level and _random_kind(items[id]):
			total += float(items[id]["weight"])
	var roll := rng.randf() * total
	for id: String in items:
		if int(items[id].get("min_level", 1)) > level or not _random_kind(items[id]):
			continue
		roll -= float(items[id]["weight"])
		if roll <= 0.0:
			return id
	return "gold"
