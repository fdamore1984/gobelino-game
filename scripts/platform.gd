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
	# Steam imposta questa variabile d'ambiente quando gira sullo Steam Deck / SteamOS.
	is_steam_deck = OS.get_environment("SteamDeck") == "1"
	# Verrà aggiornato quando integreremo GodotSteam (solo desktop).
	steam_available = false


## True se vanno mostrati i controlli touch a schermo.
func use_touch_controls() -> bool:
	return is_mobile or DisplayServer.is_touchscreen_available()
