class_name Keybinds
## Comandi personalizzati: per ogni azione dell'Input Map (ACTIONS) si può
## cambiare il tasto della tastiera, il tasto del mouse e quello del
## controller (vedi OptionsPanel). Cambiare un dispositivo sostituisce tutti
## i tasti di quel dispositivo per l'azione e lascia stare gli altri; un
## dispositivo si può anche lasciare senza tasti (clear).
##
## Si salvano solo le azioni cambiate, in user://keybinds.json
## (azione -> dispositivo -> elenco di tasti, vuoto se lasciato senza
## tasti): così se una versione nuova
## cambia i tasti predefiniti di un'azione mai toccata, valgono quelli
## nuovi. Senza il file (versioni precedenti) restano i tasti predefiniti
## di project.godot. Si caricano all'avvio (vedi Settings).
##
## Le etichette dei tasti (label, describe) servono anche a ControlsPanel,
## HudActions e ai suggerimenti dei pannelli, così mostrano sempre i tasti
## scelti dal giocatore.

const PATH := "user://keybinds.json"
const DEVICES := ["keyboard", "mouse", "controller"]
## Azioni che si possono cambiare, nell'ordine del pannello delle opzioni
## (le azioni ui_* dei menù restano fisse).
const ACTIONS := [
	"move_up", "move_down", "move_left", "move_right", "move_click", "attack", "heavy_attack", "parry",
	"dodge", "jump", "interact", "run", "focus", "spell", "shield", "potion", "mana_potion",
	"stamina_potion", "inventory", "inventory_sort", "map", "lock_on", "menu",
]
## Azioni che devono avere almeno un tasto: senza, non si potrebbe più
## aprire il menù di pausa.
const REQUIRED := ["menu"]
## Tasti del mouse che si possono usare (non la rotella).
const MOUSE_BUTTONS := [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]
## Una levetta o un grilletto conta come tasto oltre questa inclinazione.
const AXIS_THRESHOLD := 0.6
## Sistemi che sanno tradurre un tasto fisico nella disposizione della
## tastiera in uso (sugli altri si mostra il nome sulla tastiera americana).
const LAYOUT_AWARE_SERVERS := ["Windows", "X11", "Wayland", "macOS"]

## Azioni cambiate: azione -> dispositivo -> tasti (dizionari, vedi _serialize).
static var _overrides := {}


## All'avvio: applica i comandi salvati sopra quelli predefiniti.
static func load_saved() -> void:
	_overrides = {}
	if FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_overrides = parsed
	_apply()


## Assegna all'azione il nuovo tasto per il suo dispositivo (al posto di
## quelli di prima) e salva.
static func rebind(action: String, event: InputEvent) -> void:
	var device := device_of(event)
	if device == "" or action not in ACTIONS:
		return
	if not _overrides.has(action):
		_overrides[action] = {}
	_overrides[action][device] = [_serialize(event)]
	_apply()
	_save()


## Lascia l'azione senza tasti per quel dispositivo e salva.
static func clear(action: String, device: String) -> void:
	if device not in DEVICES or not can_clear(action, device):
		return
	if not _overrides.has(action):
		_overrides[action] = {}
	_overrides[action][device] = []
	_apply()
	_save()


## L'azione si può lasciare senza tasti per quel dispositivo: non è tra
## quelle che ne devono avere almeno uno (REQUIRED), o ne ha su un altro.
static func can_clear(action: String, device: String) -> bool:
	if action not in ACTIONS:
		return false
	if action not in REQUIRED:
		return true
	for other: String in DEVICES:
		if other != device and not events(action, other).is_empty():
			return true
	return false


## Torna ai comandi predefiniti di tutte le azioni.
static func reset() -> void:
	_overrides = {}
	_apply()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## Comandi predefiniti (project.godot) con sopra quelli cambiati. Sullo
## Steam Deck Platform toglie tastiera e mouse dalle azioni mentre c'è il
## controller: prima li rimette, poi ricontrolla.
static func _apply() -> void:
	Platform.restore_desktop_events()
	InputMap.load_from_project_settings()
	for action: String in _overrides:
		if not InputMap.has_action(action):
			continue
		var by_device: Dictionary = _overrides[action]
		for device: String in by_device:
			for event in InputMap.action_get_events(action):
				if device_of(event) == device:
					InputMap.action_erase_event(action, event)
			for data: Variant in by_device[device]:
				var event := _deserialize(data)
				if event:
					InputMap.action_add_event(action, event)
	Platform.refresh_desktop_events()


static func _save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_overrides, "\t"))


## Dispositivo di un tasto: "keyboard", "mouse", "controller" ("" se nessuno).
static func device_of(event: InputEvent) -> String:
	if event is InputEventKey:
		return "keyboard"
	if event is InputEventMouseButton:
		return "mouse"
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return "controller"
	return ""


## L'evento è la pressione di un tasto che si può assegnare (non il
## rilascio, le ripetizioni, la rotella o una levetta appena toccata).
static func is_bindable(event: InputEvent) -> bool:
	if event.is_echo():
		return false
	if event is InputEventKey or event is InputEventJoypadButton:
		return event.is_pressed()
	if event is InputEventMouseButton:
		return event.is_pressed() and (event as InputEventMouseButton).button_index in MOUSE_BUTTONS
	if event is InputEventJoypadMotion:
		return absf((event as InputEventJoypadMotion).axis_value) >= AXIS_THRESHOLD
	return false


## Tasti dell'azione per un dispositivo. Comprende quelli di tastiera e
## mouse che sullo Steam Deck Platform tiene da parte mentre c'è il
## controller: sono comunque i comandi scelti e il pannello delle opzioni
## li deve mostrare.
static func events(action: String, device: String) -> Array[InputEvent]:
	var found: Array[InputEvent] = []
	if InputMap.has_action(action):
		for event in InputMap.action_get_events(action) + Platform.hidden_events(action):
			if device_of(event) == device:
				found.append(event)
	return found


## Tasti di più azioni per un dispositivo, senza ripetizioni ("A / Space"),
## o un trattino se non ce ne sono.
static func describe(actions: Array, device: String) -> String:
	var labels: Array[String] = []
	for action: String in actions:
		for event in events(action, device):
			var text := label(event)
			if text not in labels:
				labels.append(text)
	return " / ".join(labels) if not labels.is_empty() else TranslationServer.translate("BIND_NONE")


## Primo tasto dell'azione per un dispositivo ("" se non ce n'è); short:
## nome breve, dove c'è (le frecce della croce, per la barra delle azioni).
static func primary(action: String, device: String, short := false) -> String:
	var found := events(action, device)
	return label(found[0], short) if not found.is_empty() else ""


## Tasti dell'azione per i suggerimenti dei pannelli: il primo del
## controller e quello della tastiera ("R3 / C").
static func hint(action: String) -> String:
	var labels: Array[String] = []
	for device: String in ["controller", "keyboard"]:
		var text := primary(action, device)
		if text != "" and text not in labels:
			labels.append(text)
	return " / ".join(labels) if not labels.is_empty() else TranslationServer.translate("BIND_NONE")


## Nome di un tasto da mostrare al giocatore (short: vedi primary).
static func label(event: InputEvent, short := false) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.keycode
		if key.physical_keycode != KEY_NONE:
			# Il nome del tasto nella disposizione della tastiera del giocatore,
			# dove il sistema lo sa dire.
			code = key.physical_keycode
			if DisplayServer.get_name() in LAYOUT_AWARE_SERVERS:
				var local := DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode)
				if local != KEY_NONE:
					code = local
		return OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		return _translated("BIND_MOUSE_%d" % (event as InputEventMouseButton).button_index, "BIND_MOUSE", (event as InputEventMouseButton).button_index)
	if event is InputEventJoypadButton:
		var index := (event as InputEventJoypadButton).button_index
		if short and TranslationServer.translate("BIND_JOY_SHORT_%d" % index) != "BIND_JOY_SHORT_%d" % index:
			return TranslationServer.translate("BIND_JOY_SHORT_%d" % index)
		return _translated("BIND_JOY_%d" % (event as InputEventJoypadButton).button_index, "BIND_JOY", (event as InputEventJoypadButton).button_index)
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var side := "POS" if motion.axis_value >= 0.0 else "NEG"
		return _translated("BIND_AXIS_%d_%s" % [motion.axis, side], "BIND_AXIS", motion.axis)
	return ""


## Testo tradotto della chiave, o quello generico con il numero se la
## chiave non c'è (tasti rari).
static func _translated(key: String, fallback: String, number: int) -> String:
	var text := TranslationServer.translate(key)
	return text if text != key else TranslationServer.translate(fallback) % number


## Un tasto come dizionario per il file JSON (solo quello che serve).
static func _serialize(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key := event as InputEventKey
		return {"type": "key", "physical": int(key.physical_keycode), "keycode": int(key.keycode)}
	if event is InputEventMouseButton:
		return {"type": "mouse", "button": int((event as InputEventMouseButton).button_index)}
	if event is InputEventJoypadButton:
		return {"type": "joy_button", "button": int((event as InputEventJoypadButton).button_index)}
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		return {"type": "joy_motion", "axis": int(motion.axis), "value": 1.0 if motion.axis_value >= 0.0 else -1.0}
	return {}


## Tasto letto dal file (null se non valido). Vale per qualsiasi
## controller e mouse (device -1), come i tasti predefiniti.
static func _deserialize(data: Variant) -> InputEvent:
	if not (data is Dictionary):
		return null
	var entry: Dictionary = data
	match str(entry.get("type", "")):
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = int(entry.get("physical", 0)) as Key
			if key.physical_keycode == KEY_NONE:
				key.keycode = int(entry.get("keycode", 0)) as Key
			key.device = -1
			return key
		"mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = int(entry.get("button", MOUSE_BUTTON_LEFT)) as MouseButton
			mouse.device = -1
			return mouse
		"joy_button":
			var button := InputEventJoypadButton.new()
			button.button_index = int(entry.get("button", 0)) as JoyButton
			button.device = -1
			return button
		"joy_motion":
			var motion := InputEventJoypadMotion.new()
			motion.axis = int(entry.get("axis", 0)) as JoyAxis
			motion.axis_value = signf(float(entry.get("value", 1.0)))
			motion.device = -1
			return motion
	return null
