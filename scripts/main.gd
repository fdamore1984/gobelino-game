extends Node2D
## Scena principale di Gobelino. Punto di ingresso del gioco.
## Per ora è una schermata segnaposto che mostra versione e piattaforma,
## utile per verificare a colpo d'occhio le build caricate su itch.io.

@onready var _info: Label = %Info


func _ready() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version", "dev")
	var platform := OS.get_name()
	if Platform.is_steam_deck:
		platform += " (Steam Deck)"
	_info.text = "Versione %s\nPiattaforma: %s\nControlli touch: %s" % [
		version,
		platform,
		"sì" if Platform.use_touch_controls() else "no",
	]
	print("Gobelino avviato: versione %s su %s" % [version, platform])
