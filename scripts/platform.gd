extends Node
## Livello di astrazione sulla piattaforma (autoload "Platform").
## Il resto del gioco chiede qui cosa è disponibile, senza controllare
## direttamente il sistema operativo. Così le funzioni Steam si attivano
## solo dove esistono e Android resta supportato.

var is_mobile: bool = false
var is_desktop: bool = false
var is_steam_deck: bool = false
var steam_available: bool = false


func _ready() -> void:
	is_mobile = OS.has_feature("android") or OS.has_feature("ios")
	is_desktop = OS.has_feature("windows") or OS.has_feature("linuxbsd") or OS.has_feature("macos")
	# Steam imposta questa variabile d'ambiente quando avvia il gioco sullo
	# Steam Deck; avviato da altri programmi (per esempio dall'app di
	# itch.io in modalità desktop) si riconosce dal modello dell'hardware.
	is_steam_deck = OS.get_environment("SteamDeck") == "1" or _is_steam_deck_hardware()
	# Verrà aggiornato quando integreremo GodotSteam (solo desktop).
	steam_available = false


## Sullo Steam Deck in modalità desktop, se il gioco non è avviato da
## Steam, i comandi integrati arrivano come tastiera e mouse e il gioco non
## vede nessun controller: in quel caso conviene dire al giocatore come
## passare alla modalità controller.
func needs_deck_controller_hint() -> bool:
	return is_steam_deck and Input.get_connected_joypads().is_empty()


func _is_steam_deck_hardware() -> bool:
	if not OS.has_feature("linuxbsd"):
		return false
	var vendor := _read_first_line("/sys/devices/virtual/dmi/id/board_vendor")
	var product := _read_first_line("/sys/devices/virtual/dmi/id/product_name")
	# Jupiter è lo Steam Deck LCD, Galileo lo Steam Deck OLED.
	return vendor == "Valve" and product in ["Jupiter", "Galileo"]


func _read_first_line(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_line().strip_edges()


## True se vanno mostrati i controlli touch a schermo.
func use_touch_controls() -> bool:
	return is_mobile or DisplayServer.is_touchscreen_available()
