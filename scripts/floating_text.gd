class_name FloatingText
extends Node2D
## Breve scritta che sale e svanisce, per dare un riscontro sulle azioni
## di combattimento ("Schivato!", "Parato"...).

const LIFETIME := 0.8
const RISE_SPEED := 50.0
const FONT_SIZE := 22

var _text := ""
var _color := Color.WHITE
var _age := 0.0


## height_offset alza la scritta, per impilarne più di una sullo stesso punto.
static func spawn(parent: Node, at: Vector2, text: String, color: Color, height_offset := 0.0) -> void:
	var label := FloatingText.new()
	label._text = text
	label._color = color
	label.z_index = 100
	parent.add_child(label)
	label.global_position = at + Vector2(0, -50.0 - height_offset)


func _process(delta: float) -> void:
	_age += delta
	position.y -= RISE_SPEED * delta
	modulate.a = 1.0 - _age / LIFETIME
	if _age >= LIFETIME:
		queue_free()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	draw_string_outline(font, Vector2(-width / 2.0, 0), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(-width / 2.0, 0), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, _color)
