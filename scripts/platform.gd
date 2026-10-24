extends Node
## Livello di astrazione sulla piattaforma (autoload "Platform").
## Il resto del gioco chiede qui cosa è disponibile, senza controllare
## direttamente il sistema operativo. Così le funzioni Steam si attivano
## solo dove esistono e Android resta supportato.

var is_mobile: bool = false
var is_desktop: bool = false
var is_steam_deck: bool = false
## PC portatile da gioco con Windows (MSI Claw, ROG Ally, Legion Go...):
## si riconosce dal modello o dallo schermo touch.
var is_handheld_pc: bool = false
var steam_available: bool = false

## Controller virtuale creato da Steam Input (anche sullo Steam Deck).
const VALVE_VENDOR := 0x28de
const STEAM_VIRTUAL_GAMEPAD := 0x11ff
const STEAM_DECK_CONTROLLER := 0x1205
## Disposizione dei pulsanti del controller virtuale di Steam su Linux
## (come un controller Xbox 360), dal database dei controller di SDL.
const STEAM_VIRTUAL_GAMEPAD_LAYOUT := "a:b0,b:b1,x:b2,y:b3,leftshoulder:b4,rightshoulder:b5,back:b6,start:b7,guide:b8,leftstick:b9,rightstick:b10,leftx:a0,lefty:a1,lefttrigger:a2,rightx:a3,righty:a4,righttrigger:a5,dpup:h0.1,dpright:h0.2,dpdown:h0.4,dpleft:h0.8,platform:Linux"
## Comandi integrati dello Steam Deck letti direttamente (senza Steam).
const STEAM_DECK_LAYOUT := "a:b3,b:b4,x:b5,y:b6,leftshoulder:b7,rightshoulder:b8,back:b11,start:b12,guide:b13,leftstick:b14,rightstick:b15,leftx:a0,lefty:a1,rightx:a2,righty:a3,lefttrigger:a9,righttrigger:a8,dpup:b16,dpdown:b17,dpleft:b18,dpright:b19,platform:Linux"

## Tasti e clic tolti dalle azioni mentre sullo Steam Deck c'è un
## controller, da rimettere quando il controller sparisce.
var _removed_desktop_events := {}
## Sui PC con schermo touch i controlli a schermo compaiono solo dopo aver
## toccato lo schermo e spariscono appena si usa il controller o la tastiera.
var _touch_active := false


func _ready() -> void:
	is_mobile = OS.has_feature("android") or OS.has_feature("ios")
	is_desktop = OS.has_feature("windows") or OS.has_feature("linuxbsd") or OS.has_feature("macos")
	# Steam imposta questa variabile d'ambiente quando avvia il gioco sullo
	# Steam Deck; avviato da altri programmi (per esempio dall'app di
	# itch.io in modalità desktop) si riconosce dal modello dell'hardware.
	is_steam_deck = OS.get_environment("SteamDeck") == "1" or _is_steam_deck_hardware()
	# Sullo Steam Deck si gioca sempre a schermo intero, anche in modalità
	# desktop (in modalità gioco lo schermo è già tutto del gioco). Va fatto
	# a finestra pronta: qui all'avvio sarebbe troppo presto.
	is_handheld_pc = OS.has_feature("windows") and ("Claw" in OS.get_model_name() or DisplayServer.is_touchscreen_available())
	# Sui portatili da gioco con Windows (per esempio l'MSI Claw 8) lo stesso.
	if (is_steam_deck or is_handheld_pc) and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode.call_deferred(DisplayServer.WINDOW_MODE_FULLSCREEN)
	# Verrà aggiornato quando integreremo GodotSteam (solo desktop).
	steam_available = false
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	for device in Input.get_connected_joypads():
		_fix_joypad_mapping(device)
	_update_desktop_events()


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		_fix_joypad_mapping(device)
	_update_desktop_events()


## Se Godot non conosce la disposizione dei pulsanti di un controller
## Valve (succede quando Steam gli dà un numero di versione diverso da
## quello del database), legge i pulsanti nell'ordine grezzo e B, dorsali
## e grilletti finiscono su altri comandi: qui gli si dà quella giusta.
func _fix_joypad_mapping(device: int) -> void:
	if Input.is_joy_known(device):
		return
	var info := Input.get_joy_info(device)
	var vendor: int = info.get("vendor_id", 0)
	var product: int = info.get("product_id", 0)
	var name := Input.get_joy_name(device)
	var layout := ""
	if vendor == VALVE_VENDOR and product == STEAM_DECK_CONTROLLER:
		layout = STEAM_DECK_LAYOUT
	elif (vendor == VALVE_VENDOR and product == STEAM_VIRTUAL_GAMEPAD) or "Steam Virtual Gamepad" in name:
		layout = STEAM_VIRTUAL_GAMEPAD_LAYOUT
	if layout == "" or not OS.has_feature("linuxbsd"):
		return
	Input.add_joy_mapping("%s,%s,%s" % [Input.get_joy_guid(device), name, layout], true)


## Sullo Steam Deck in modalità desktop Steam può continuare a mandare i
## tasti del layout desktop (per esempio Esc sul tasto B, le frecce sulla
## croce) anche dopo il passaggio alla modalità controller: finché c'è un
## controller, le azioni ignorano tastiera e mouse.
func _update_desktop_events() -> void:
	if not is_steam_deck:
		return
	var has_joypad := not Input.get_connected_joypads().is_empty()
	if has_joypad and _removed_desktop_events.is_empty():
		for action in InputMap.get_actions():
			var removed: Array[InputEvent] = []
			for event in InputMap.action_get_events(action):
				if event is InputEventKey or event is InputEventMouseButton:
					removed.append(event)
					InputMap.action_erase_event(action, event)
			if not removed.is_empty():
				_removed_desktop_events[action] = removed
	elif not has_joypad and not _removed_desktop_events.is_empty():
		for action: StringName in _removed_desktop_events:
			for event: InputEvent in _removed_desktop_events[action]:
				InputMap.action_add_event(action, event)
		_removed_desktop_events.clear()


## True se gli eventi di tastiera e mouse vanno ignorati (vedi sopra).
func ignores_desktop_input() -> bool:
	return not _removed_desktop_events.is_empty()


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


func _input(event: InputEvent) -> void:
	if is_mobile:
		return
	if event is InputEventScreenTouch:
		_touch_active = true
	elif event is InputEventJoypadButton or event is InputEventKey \
			or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5):
		_touch_active = false


## True se vanno mostrati i controlli touch a schermo: sempre sui telefoni,
## sui PC con schermo touch solo dopo averlo toccato (vedi _input).
func use_touch_controls() -> bool:
	return is_mobile or (_touch_active and DisplayServer.is_touchscreen_available())
