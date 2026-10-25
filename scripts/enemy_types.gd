class_name EnemyTypes
## Tipi di nemico, definiti in data/enemies.json.
##
## Ogni tipo ha vita, esperienza data, danno, dimensioni, velocità, "massa"
## (resistenza alle spinte), tempi e portata dell'attacco, aspetto e peso
## nella generazione casuale ([base, aumento per livello del giocatore]).
## I tipi con "summon" evocano altri nemici, quelli con "magic" (il boss)
## lanciano anche magie da lontano.
##
## Quanti nemici girano in superficie dipende dal livello del giocatore
## (voce "population" di data/world.json): pochi all'inizio, sempre di più
## salendo, fino a un massimo.

const DATA := preload("res://data/enemies.json")
const WORLD_DATA := preload("res://data/world.json")


static func get_type(id: String) -> Dictionary:
	return DATA.data[id]


static func ids() -> Array:
	return DATA.data.keys()


static func exists(id: String) -> bool:
	return DATA.data.has(id)


## Nemici da tenere attorno al giocatore in superficie al suo livello.
static func population(player_level: int) -> int:
	var data: Dictionary = WORLD_DATA.data["population"]
	var count: Array = data["count"]
	return clampi(floori(float(count[0]) + float(count[1]) * (player_level - 1)), 1, int(data["max"]))


## Sceglie un tipo a caso, pesato: salendo di livello compaiono più
## spesso i nemici forti.
static func pick_random(player_level: int) -> String:
	var weights := {}
	var total := 0.0
	for id: String in ids():
		var weight: Array = get_type(id)["spawn_weight"]
		var value := maxf(weight[0] + weight[1] * (player_level - 1), 0.0)
		if value <= 0.0:
			# Il boss (peso zero) non compare mai a caso.
			continue
		weights[id] = value
		total += value
	var roll := randf() * total
	for id: String in weights:
		roll -= weights[id]
		if roll <= 0.0:
			return id
	return ids()[0]
