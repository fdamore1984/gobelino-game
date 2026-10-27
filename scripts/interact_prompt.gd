class_name InteractPrompt
extends Button
## Suggerimento sopra l'elemento con cui si può interagire (cassa, mercante,
## totem, caverna, scala, uscita): il tasto scelto per interagire (A sul
## controller, E sulla tastiera se non cambiati) e "Interact". Toccandolo (o cliccandolo) si interagisce
## (segnale activated): non mentre il gioco è in pausa né nel frame in cui
## si chiude un menù, così il tocco che chiude la pausa non interagisce.

signal activated

const PANEL_SIZE := Vector2(150, 44)
const FONT_SIZE := 18
const KEY_RADIUS := 14.0
const COLOR_PANEL := Color(0.05, 0.07, 0.05, 0.82)
const COLOR_BORDER := Color(1, 1, 1, 0.3)
## Tasto A verde come sui controller, tasto della tastiera grigio.
const COLOR_BUTTON_A := Color(0.3, 0.72, 0.3)
const COLOR_KEY := Color(0.82, 0.82, 0.82)
const COLOR_TEXT := Color(1, 1, 1, 0.95)

var _panel := StyleBoxFlat.new()


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = true
	custom_minimum_size = PANEL_SIZE
	size = PANEL_SIZE
	visible = false
	_panel.bg_color = COLOR_PANEL
	_panel.border_color = COLOR_BORDER
	_panel.set_border_width_all(2)
	_panel.set_corner_radius_all(int(PANEL_SIZE.y / 2.0))
	pressed.connect(_on_pressed)


## Il clic sul suggerimento non è anche un attacco (clic sinistro).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		UiNav.consume(event)


func _on_pressed() -> void:
	if visible and not get_tree().paused and not UiNav.just_consumed():
		activated.emit()


## Mostra il suggerimento sopra il punto del mondo dato.
func show_at(world_point: Vector2) -> void:
	var screen := get_viewport().get_canvas_transform() * world_point
	position = (screen - Vector2(PANEL_SIZE.x / 2.0, PANEL_SIZE.y)).round()
	if not visible:
		visible = true
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_style_box(_panel, Rect2(Vector2.ZERO, PANEL_SIZE))
	var controller := not Input.get_connected_joypads().is_empty()
	var key := Vector2(PANEL_SIZE.y / 2.0 + 2.0, PANEL_SIZE.y / 2.0)
	Shapes.disc(self, key, KEY_RADIUS, COLOR_BUTTON_A if controller else COLOR_KEY)
	# Il tasto scelto dal giocatore (vedi Keybinds), non quello predefinito.
	var letter := Keybinds.primary("interact", "controller" if controller else "keyboard", true)
	draw_string(font, key + Vector2(-KEY_RADIUS, 6.5), letter, HORIZONTAL_ALIGNMENT_CENTER, KEY_RADIUS * 2.0, FONT_SIZE,
			Color.WHITE if controller else Color(0.1, 0.1, 0.1))
	draw_string(font, Vector2(key.x + KEY_RADIUS + 8.0, PANEL_SIZE.y / 2.0 + 6.5), tr("INTERACT"), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_TEXT)
