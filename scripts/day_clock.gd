class_name DayClock
extends Control
## Ciclo del giorno nell'HUD, a sinistra della minimappa: mezzo cerchio di
## cielo con il sole che lo attraversa di giorno e la luna di notte (vedi
## DayNight). Nel sotterraneo mostra ancora l'ora di fuori, più spento.

const PANEL_SIZE := Vector2(84, 52)
## Distanza dal bordo destro dello schermo: la minimappa più uno spazio.
const RIGHT_MARGIN := 196.0 + 10.0
const TOP_MARGIN := 16.0
## Il sole si muove piano: basta ridisegnare ogni tanto.
const REDRAW_INTERVAL := 0.25
const ARC_RADIUS := 30.0
const COLOR_PANEL := Color(0.05, 0.07, 0.05, 0.72)
const COLOR_BORDER := Color(1, 1, 1, 0.14)
const COLOR_SKY_DAY := Color(0.38, 0.62, 0.92)
const COLOR_SKY_NIGHT := Color(0.07, 0.09, 0.24)
const COLOR_SUN := Color(1.0, 0.86, 0.3)
const COLOR_MOON := Color(0.9, 0.92, 1.0)
const COLOR_GROUND := Color(0.2, 0.38, 0.18)
## Buio del mondo a cui il cielo dell'indicatore è del tutto notturno.
const NIGHT_DARKNESS := 0.6
## Stelle: posizione nel mezzo cerchio (angolo, distanza 0-1).
const STARS := [Vector2(0.5, 0.7), Vector2(1.1, 0.45), Vector2(1.7, 0.8), Vector2(2.3, 0.55), Vector2(2.7, 0.75), Vector2(1.4, 0.25)]

var day_night: DayNight

var _panel := StyleBoxFlat.new()
var _redraw_timer := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -RIGHT_MARGIN - PANEL_SIZE.x
	offset_right = -RIGHT_MARGIN
	offset_top = TOP_MARGIN
	offset_bottom = TOP_MARGIN + PANEL_SIZE.y
	_panel.bg_color = COLOR_PANEL
	_panel.border_color = COLOR_BORDER
	_panel.set_border_width_all(2)
	_panel.set_corner_radius_all(10)


func _process(delta: float) -> void:
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = REDRAW_INTERVAL
		queue_redraw()


func _draw() -> void:
	if day_night == null:
		return
	modulate.a = 0.55 if day_night.is_overridden() else 1.0
	draw_style_box(_panel, Rect2(Vector2.ZERO, size))
	var horizon := Vector2(size.x / 2.0, size.y - 10.0)
	var night := clampf(day_night.sky_darkness() / NIGHT_DARKNESS, 0.0, 1.0)
	var sky := COLOR_SKY_DAY.lerp(COLOR_SKY_NIGHT, night)
	# Mezzo cerchio di cielo sopra l'orizzonte, con il prato sotto.
	var dome := PackedVector2Array()
	for k in 25:
		dome.append(horizon + Vector2.from_angle(PI + PI * k / 24.0) * (ARC_RADIUS + 4.0))
	draw_colored_polygon(dome, sky)
	draw_rect(Rect2(Vector2(horizon.x - ARC_RADIUS - 4.0, horizon.y - 1.0), Vector2(ARC_RADIUS * 2.0 + 8.0, 4.0)), COLOR_GROUND)
	for star: Vector2 in STARS:
		var at := horizon + Vector2.from_angle(-star.x) * ARC_RADIUS * star.y
		Shapes.disc(self, at, 1.2, Color(1, 1, 1, night * 0.9))
	# Il sole (o la luna) sale da sinistra, passa in alto e tramonta a destra.
	var angle := PI + PI * clampf(day_night.sky_progress(), 0.0, 1.0)
	var at := horizon + Vector2.from_angle(angle) * (ARC_RADIUS - 6.0)
	if day_night.is_day():
		for k in 8:
			var ray := Vector2.from_angle(TAU * k / 8.0)
			draw_line(at + ray * 7.5, at + ray * 10.0, COLOR_SUN, 1.5)
		Shapes.disc(self, at, 6.0, COLOR_SUN)
	else:
		Shapes.disc(self, at, 6.0, COLOR_MOON)
		Shapes.disc(self, at + Vector2(3.0, -2.0), 5.0, sky)
