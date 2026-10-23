class_name HudStatus
extends Control
## Pannello di stato in alto a sinistra: ritratto con il livello, barre di
## vita (a segmenti), mana ed esperienza, livelli delle abilità, monete e
## nemici sconfitti. Tutto disegnato con forme geometriche.

const PANEL_SIZE := Vector2(440, 146)
## Il pannello è disegnato a questa scala, per coprire meno l'area di gioco.
const PANEL_SCALE := 0.72
const BAR_X := 104.0
const BAR_WIDTH := 320.0
const FONT_SIZE := 15
const SMALL_FONT_SIZE := 13
const COLOR_PANEL := Color(0.05, 0.07, 0.05, 0.72)
const COLOR_BORDER := Color(1, 1, 1, 0.14)
const COLOR_BAR_BACK := Color(0, 0, 0, 0.45)
const COLOR_HEALTH := Color(0.9, 0.25, 0.25)
const COLOR_HEALTH_LOW := Color(1.0, 0.45, 0.2)
const COLOR_MANA := Color(0.35, 0.55, 1.0)
const COLOR_XP := Color(1.0, 0.8, 0.3)
const COLOR_TEXT := Color(1, 1, 1, 0.92)
const COLOR_DIM_TEXT := Color(1, 1, 1, 0.6)
## Abilità mostrate sotto le barre: icona e valore.
const SKILLS := ["combo", "heavy", "dodge", "jump", "run"]

var player: Player
var kills := 0

var _panel := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(16, 16)
	size = PANEL_SIZE
	scale = Vector2(PANEL_SCALE, PANEL_SCALE)
	_panel.bg_color = COLOR_PANEL
	_panel.border_color = COLOR_BORDER
	_panel.set_border_width_all(2)
	_panel.set_corner_radius_all(14)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var font := ThemeDB.fallback_font
	draw_style_box(_panel, Rect2(Vector2.ZERO, size))
	_draw_portrait(font)

	# Vita: un segmento per punto vita.
	var low := player.health <= maxf(1.0, player.max_health / 3.0)
	_draw_heart(Vector2(BAR_X + 9, 26), 9.0)
	_draw_segments(Rect2(BAR_X + 24, 16, BAR_WIDTH - 24, 20), player.health, player.max_health, COLOR_HEALTH_LOW if low else COLOR_HEALTH)
	_text(font, "%d / %d" % [player.health, player.max_health], Vector2(BAR_X + BAR_WIDTH - 6, 31), FONT_SIZE, COLOR_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)

	# Mana.
	UpgradeIcon.draw_icon(self, Vector2(BAR_X + 9, 50), 18.0, "mana", false)
	draw_set_transform(Vector2.ZERO)
	_draw_bar(Rect2(BAR_X + 24, 43, BAR_WIDTH - 24, 14), player.mana / player.max_mana, COLOR_MANA)
	_text(font, "%d / %d" % [floori(player.mana), roundi(player.max_mana)], Vector2(BAR_X + BAR_WIDTH - 6, 55), SMALL_FONT_SIZE, COLOR_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)

	# Esperienza verso il livello successivo.
	var needed := player.experience_needed()
	_draw_bar(Rect2(BAR_X + 24, 66, BAR_WIDTH - 24, 8), float(player.experience) / needed, COLOR_XP)
	_text(font, tr("HUD_XP") % [player.experience, needed], Vector2(BAR_X + 24, 92), SMALL_FONT_SIZE, COLOR_DIM_TEXT)

	# Abilità (si leggono anche nell'elenco dei potenziamenti a destra).
	var x := 18.0
	var values := [player.max_combo_hits, player.max_heavy_chain, player.max_chained_dodges, player.max_jumps,
			"%d%%" % roundi(100.0 * (1.0 + player.run_speed_bonus))]
	for i in SKILLS.size():
		UpgradeIcon.draw_icon(self, Vector2(x + 11, 122), 22.0, SKILLS[i])
		draw_set_transform(Vector2.ZERO)
		_text(font, str(values[i]), Vector2(x + 26, 128), FONT_SIZE, COLOR_TEXT)
		x += 56.0
	# Monete e nemici sconfitti, a destra.
	var coin := Vector2(size.x - 112, 122)
	draw_circle(coin, 9.0, Items.color("gold").darkened(0.25))
	draw_circle(coin, 7.0, Items.color("gold"))
	_text(font, str(player.inventory.gold), coin + Vector2(14, 6), FONT_SIZE, COLOR_TEXT)
	var sword := Vector2(size.x - 46, 122)
	BodyParts.draw_sword(self, sword + Vector2(-8, 8), -PI / 4.0, 22.0, 3.0)
	_text(font, str(kills), sword + Vector2(12, 6), FONT_SIZE, COLOR_TEXT)


## Ritratto del goblin, con la stessa espressione del personaggio, e il
## livello in un distintivo.
func _draw_portrait(font: Font) -> void:
	var center := Vector2(52, 50)
	draw_circle(center, 34.0, Color(0, 0, 0, 0.35))
	draw_arc(center, 34.0, 0.0, TAU, 40, Color(1, 1, 1, 0.25), 2.0)
	GoblinArt.draw_head(self, center + Vector2(0, 6), 17.0, Vector2(0.35, 1).normalized(), player.expression(), GoblinArt.SKIN)
	var badge := center + Vector2(26, 28)
	draw_circle(badge, 15.0, Color(0.2, 0.15, 0.05))
	draw_circle(badge, 13.0, COLOR_XP)
	_text(font, str(player.level), badge + Vector2(0, 6), FONT_SIZE, Color(0.15, 0.1, 0.0), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_heart(center: Vector2, radius: float) -> void:
	draw_circle(center + Vector2(-radius * 0.45, -radius * 0.2), radius * 0.55, COLOR_HEALTH)
	draw_circle(center + Vector2(radius * 0.45, -radius * 0.2), radius * 0.55, COLOR_HEALTH)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-radius, 0), center + Vector2(radius, 0), center + Vector2(0, radius)]), COLOR_HEALTH)


func _draw_bar(rect: Rect2, ratio: float, color: Color) -> void:
	draw_rect(rect, COLOR_BAR_BACK)
	var fill := Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y))
	draw_rect(fill, color)
	draw_rect(Rect2(fill.position, Vector2(fill.size.x, rect.size.y * 0.35)), Color(1, 1, 1, 0.18))


## Barra a segmenti: uno per ogni punto, pieni fino a value.
func _draw_segments(rect: Rect2, value: int, maximum: int, color: Color) -> void:
	draw_rect(rect, COLOR_BAR_BACK)
	var gap := 3.0
	var width := (rect.size.x - gap * (maximum + 1)) / maximum
	for i in maximum:
		var segment := Rect2(rect.position + Vector2(gap + i * (width + gap), gap), Vector2(width, rect.size.y - gap * 2.0))
		if i < value:
			draw_rect(segment, color)
			draw_rect(Rect2(segment.position, Vector2(segment.size.x, segment.size.y * 0.35)), Color(1, 1, 1, 0.2))
		else:
			draw_rect(segment, Color(color, 0.15))


func _text(font: Font, text: String, at: Vector2, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := at.x
	if align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= width
	elif align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= width / 2.0
	draw_string_outline(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
