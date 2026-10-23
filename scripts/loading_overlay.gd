class_name LoadingOverlay
extends Control
## Schermata d'attesa mentre si genera il territorio (gioco in pausa):
## testo e barra di avanzamento.

const BAR_SIZE := Vector2(420, 14)
const COLOR_BAR := Color(1.0, 0.85, 0.4)

var _label := Label.new()
var _progress := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	add_child(_label)


func show_progress(text: String, progress: float) -> void:
	visible = true
	_label.text = text
	_label.reset_size()
	_label.position = (size - _label.size) / 2.0 - Vector2(0, 30)
	_progress = progress
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	var bar := Rect2((size - BAR_SIZE) / 2.0 + Vector2(0, 20), BAR_SIZE)
	draw_rect(bar.grow(3.0), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(_progress, 0.0, 1.0), bar.size.y)), COLOR_BAR)
