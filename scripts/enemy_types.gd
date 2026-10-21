class_name EnemyTypes
## Tipi di nemico, definiti in data/enemies.json.
##
## Ogni tipo ha vita, esperienza data, danno, dimensioni, velocità, "massa"
## (resistenza alle spinte), tempi e portata dell'attacco, aspetto e peso
## nella generazione casuale ([base, aumento per livello del giocatore]).
## I tipi con "summon" evocano altri nemici.

const DATA := preload("res://data/enemies.json")


static func get_type(id: String) -> Dictionary:
	return DATA.data[id]


static func ids() -> Array:
	return DATA.data.keys()


## Sceglie un tipo a caso, pesato: salendo di livello compaiono più
## spesso i nemici forti.
static func pick_random(player_level: int) -> String:
	var weights := {}
	var total := 0.0
	for id: String in ids():
		var weight: Array = get_type(id)["spawn_weight"]
		var value := maxf(weight[0] + weight[1] * (player_level - 1), 0.0)
		weights[id] = value
		total += value
	var roll := randf() * total
	for id: String in weights:
		roll -= weights[id]
		if roll <= 0.0:
			return id
	return ids()[0]
