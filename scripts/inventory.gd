class_name Inventory
extends RefCounted
## Inventario del giocatore: oggetti raccolti, equipaggiamento indossato
## (un oggetto per tipo), monete e bonus dei libri già letti. Gli effetti
## sul personaggio li applica Player (vedi Player.use_item).

## Oggetti posseduti (id di data/items.json), nell'ordine in cui sono arrivati.
var items: Array[String] = []
## Tipo di equipaggiamento -> indice in items dell'oggetto indossato.
var equipped := {}
var gold := 0
## Bonus permanenti dei libri letti: caratteristica -> valore.
var learned := {}


func add(id: String) -> void:
	items.append(id)


## Somma di un bonus tra equipaggiamento indossato e libri letti.
func bonus(key: String) -> float:
	var total: float = learned.get(key, 0.0)
	for slot: String in equipped:
		total += Items.stat(items[equipped[slot]], key)
	return total


func is_equipped(index: int) -> bool:
	return equipped.values().has(index)


## Indossa l'oggetto (o lo toglie se è già indossato).
func toggle_equip(index: int) -> void:
	var slot := Items.category(items[index])
	if equipped.get(slot, -1) == index:
		equipped.erase(slot)
	else:
		equipped[slot] = index


## Toglie l'oggetto dall'inventario (libri letti, pozioni bevute),
## aggiornando gli indici dell'equipaggiamento.
func remove(index: int) -> void:
	items.remove_at(index)
	for slot: String in equipped.keys():
		if equipped[slot] > index:
			equipped[slot] -= 1


## Legge un libro: il suo bonus diventa permanente.
func learn(id: String) -> void:
	for key: String in ["spell", "mana", "damage", "health", "speed"]:
		var value := Items.stat(id, key)
		if value != 0.0:
			learned[key] = learned.get(key, 0.0) + value
