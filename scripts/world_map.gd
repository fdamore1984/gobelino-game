class_name WorldMap
extends Control
## Mappa completa (Select / M, o il pulsante a schermo): un'area grande
## attorno al giocatore con il terreno, casse, totem, mercanti, ingressi delle
## caverne, scale e uscite (vedi Minimap.draw_point). Il terreno si disegna a
## righe su qualche frame, così l'apertura non blocca il gioco. Mentre è
## aperta il gioco è in pausa; Select, M, B o Esc la chiudono.

## Metà del lato dell'area mostrata, in pixel del mondo, e campioni per lato.
const RANGE := 4800.0
const SAMPLES := 150
const ROWS_PER_FRAME := 15
const MAP_SIZE := 560.0
const COLOR_DIM := Color(0, 0, 0, 0.75)
const COLOR_TITLE := Color(1.0, 0.85, 0.4)
const COLOR_HINT := Color(1, 1, 1, 0.65)
const COLOR_UNKNOWN := Color(0.08, 0.1, 0.08)

var player: Player

var _image := Image.create(SAMPLES, SAMPLES, false, Image.FORMAT_RGB8)
var _texture: ImageTexture
var _center := Vector2.ZERO
var _next_row := SAMPLES


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_texture = ImageTexture.create_from_image(_image)


func is_open() -> bool:
	return visible


func open() -> void:
	if player == null or World.current == null:
		return
	visible = true
	get_tree().paused = true
	Sfx.play_ui("ui_confirm")
	_center = player.position
	_image.fill(COLOR_UNKNOWN)
	_texture.update(_image)
	_next_row = 0
	queue_redraw()


func close() -> void:
	visible = false
	get_tree().paused = false
	Sfx.play_ui("ui_move")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("map") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		# Il tasto che chiude (B, Start...) non deve anche schivare in gioco.
		UiNav.consume(event)
		close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible or _next_row >= SAMPLES:
		return
	var world := World.current
	var step := 2.0 * RANGE / SAMPLES
	for j in range(_next_row, mini(_next_row + ROWS_PER_FRAME, SAMPLES)):
		for i in SAMPLES:
			_image.set_pixel(i, j, world.map_color(_center + Vector2(-RANGE + (i + 0.5) * step, -RANGE + (j + 0.5) * step)))
	_next_row += ROWS_PER_FRAME
	_texture.update(_image)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_DIM)
	var font := ThemeDB.fallback_font
	var origin := (size - Vector2(MAP_SIZE, MAP_SIZE)) / 2.0 + Vector2(0, 10)
	draw_string(font, Vector2(0, origin.y - 18), tr("MAP_TITLE"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, COLOR_TITLE)
	draw_rect(Rect2(origin, Vector2(MAP_SIZE, MAP_SIZE)).grow(4.0), Color(0, 0, 0, 0.8))
	draw_texture_rect(_texture, Rect2(origin, Vector2(MAP_SIZE, MAP_SIZE)), false)
	var world := World.current
	if world and player:
		for point: Dictionary in world.points_of_interest(_center, RANGE):
			var at := _to_map(point["position"], origin)
			if Rect2(origin, Vector2(MAP_SIZE, MAP_SIZE)).has_point(at):
				Minimap.draw_point(self, world, point, at)
		var center := _to_map(player.position, origin)
		var facing := player.facing
		draw_colored_polygon(PackedVector2Array([center + facing * 13.0, center - facing * 8.0 + facing.orthogonal() * 9.0,
				center - facing * 8.0 - facing.orthogonal() * 9.0]), Minimap.COLOR_OUTLINE)
		draw_colored_polygon(PackedVector2Array([center + facing * 10.0, center - facing * 6.0 + facing.orthogonal() * 6.5,
				center - facing * 6.0 - facing.orthogonal() * 6.5]), Color.WHITE)
	draw_rect(Rect2(origin, Vector2(MAP_SIZE, MAP_SIZE)), Color(1, 1, 1, 0.5), false, 2.0)
	draw_string(font, Vector2(0, origin.y + MAP_SIZE + 34), tr("MAP_HINT") % Keybinds.hint("map"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, COLOR_HINT)


func _to_map(point: Vector2, origin: Vector2) -> Vector2:
	return origin + Vector2(MAP_SIZE, MAP_SIZE) / 2.0 + (point - _center) * MAP_SIZE / (2.0 * RANGE)
