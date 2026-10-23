class_name Items
## Oggetti che si trovano nelle casse o si comprano dai mercanti
## ("shop_only": solo dai mercanti), definiti in data/items.json.
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


## Oggetti rari che vendono solo i mercanti: nelle casse non ci sono.
static func shop_items() -> Array[String]:
	var result: Array[String] = []
	for id: String in DATA.data["items"]:
		if get_item(id).get("shop_only", false):
			result.append(id)
	return result


static func chest_data() -> Dictionary:
	return DATA.data["chest"]


## Sceglie un oggetto a caso, pesato, tra quelli adatti al livello.
static func pick_random(level: int, rng: RandomNumberGenerator) -> String:
	var items: Dictionary = DATA.data["items"]
	var total := 0.0
	for id: String in items:
		if int(items[id].get("min_level", 1)) <= level and not items[id].get("shop_only", false):
			total += float(items[id]["weight"])
	var roll := rng.randf() * total
	for id: String in items:
		if int(items[id].get("min_level", 1)) > level or items[id].get("shop_only", false):
			continue
		roll -= float(items[id]["weight"])
		if roll <= 0.0:
			return id
	return "gold"
