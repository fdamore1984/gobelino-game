class_name BossBar
extends Control
## Barra della vita del boss, in alto al centro, mentre lo si combatte.
## Mentre il boss carica una magia il bordo della barra si accende.

const SIZE := Vector2(520, 16)
const COLOR_BAR := Color(0.85, 0.2, 0.25)
const COLOR_CASTING := Color(1.0, 0.55, 0.35)

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
	# Ogni boss ha il suo nome ("name" del tipo in data/enemies.json).
	var title := tr(str(EnemyTypes.get_type(boss.type_id).get("name", "BOSS_NAME")))
	var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string_outline(font, Vector2(size.x / 2.0 - width / 2.0, bar.position.y - 8.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(size.x / 2.0 - width / 2.0, bar.position.y - 8.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.85, 0.4))
	draw_rect(bar.grow(3.0), Color(0, 0, 0, 0.6))
	if boss.is_casting():
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 60.0)
		draw_rect(bar.grow(4.0), Color(COLOR_CASTING, 0.5 + 0.5 * pulse), false, 2.0)
	# Un segmento per punto vita, come la vita del giocatore.
	var gap := 2.0
	var segment := (bar.size.x - gap * (boss.max_health - 1)) / boss.max_health
	for k in boss.health:
		draw_rect(Rect2(bar.position + Vector2(k * (segment + gap), 0), Vector2(segment, bar.size.y)), COLOR_BAR)
