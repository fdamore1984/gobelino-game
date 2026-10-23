class_name BossBar
extends Control
## Barra della vita del boss, in alto al centro, mentre lo si combatte.

const SIZE := Vector2(520, 16)
const COLOR_BAR := Color(0.85, 0.2, 0.25)

var boss: Enemy


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func _process(_delta: float) -> void:
	if boss != null and not is_instance_valid(boss):
		boss = null
	visible = boss != null and not boss.is_dead()
	if visible:
		queue_redraw()


func _draw() -> void:
	if boss == null or not is_instance_valid(boss):
		return
	var font := ThemeDB.fallback_font
	var bar := Rect2(Vector2((size.x - SIZE.x) / 2.0, 70.0), SIZE)
	var title := tr("BOSS_NAME")
	var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string_outline(font, Vector2(size.x / 2.0 - width / 2.0, bar.position.y - 8.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(size.x / 2.0 - width / 2.0, bar.position.y - 8.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.85, 0.4))
	draw_rect(bar.grow(3.0), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(boss.health) / boss.max_health, bar.size.y)), COLOR_BAR)
