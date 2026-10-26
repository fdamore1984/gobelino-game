extends Node
## Impostazioni del giocatore (autoload "Settings"). Per ora il gioco è
## solo in inglese: i testi passano comunque da data/translations.csv, così
## altre lingue si potranno aggiungere più avanti. All'avvio applica i
## comandi personalizzati dal giocatore (vedi Keybinds).

const LANGUAGE := "en"


func _ready() -> void:
	TranslationServer.set_locale(LANGUAGE)
	Keybinds.load_saved()
