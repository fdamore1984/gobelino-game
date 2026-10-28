class_name HudActions
extends Control
## Barra delle azioni in basso a sinistra: pozioni (vita, mana, vigore),
## scudo, palla di fuoco, rune del cataclisma (h_bomb, colpo potente in aria)
## e inventario, ognuno con la sua icona, il tasto del
## controller scelto dal giocatore (vedi Keybinds),
## quante ne restano o la ricarica. Sui dispositivi touch non serve: ci
## sono già i pulsanti a schermo.

const SLOT := 58.0
const GAP := 8.0
const FONT_SIZE := 15
const COLOR_SLOT := Color(0.05, 0.07, 0.05, 0.72)
const COLOR_BORDER := Color(1, 1, 1, 0.16)
const COLOR_ACTIVE := Color(1.0, 0.85, 0.4)
const COLOR_KEY := Color(1, 1, 1, 0.85)
## Azioni: icona e azione dell'Input Map (per il tasto del controller).
const ACTIONS := [
	["potion", "potion"], ["mana", "mana_potion"], ["shield", "shield"], ["spell", "spell"],
	["stamina_potion", "stamina_potion"], ["h_bomb", "heavy_attack"], ["bag", "inventory"],
]

var player: Player

var _style := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(ACTIONS.size() * (SLOT + GAP) - GAP, SLOT + 14)
	_style.bg_color = COLOR_SLOT
	_style.border_color = COLOR_BORDER
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(10)


func _process(_delta: float) -> void:
	position = Vector2(16, get_viewport_rect().size.y - size.y - 12)
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var font := ThemeDB.fallback_font
	for i in ACTIONS.size():
		var rect := Rect2(Vector2(i * (SLOT + GAP), 0), Vector2(SLOT, SLOT))
		var kind: String = ACTIONS[i][0]
		var available := _is_ready(kind)
		var highlight := kind == "shield" and player.shield_active
		var style := _style.duplicate() as StyleBoxFlat
		if highlight:
			style.border_color = COLOR_ACTIVE
			style.set_border_width_all(3)
		draw_style_box(style, rect)
		UpgradeIcon.draw_icon(self, rect.get_center(), SLOT * 0.62, kind, false)
		draw_set_transform(Vector2.ZERO)
		if not available:
			draw_rect(rect.grow(-2), Color(0, 0, 0, 0.5))
		# Ricarica dello scudo: un settore scuro che si svuota, e i secondi.
		if kind == "shield" and player.shield_cooldown > 0.0 and not player.shield_active:
			var left := player.shield_cooldown / player.shield_cooldown_max
			_draw_pie(rect.get_center(), SLOT * 0.4, left)
			_text(font, str(ceili(player.shield_cooldown)), rect.get_center() + Vector2(0, 6), FONT_SIZE, Color.WHITE)
		var count := _count(kind)
		if count != "":
			_text(font, count, rect.position + Vector2(SLOT - 6, SLOT - 6), 13, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		# Tasto del controller, sotto lo slot.
		_text(font, Keybinds.primary(ACTIONS[i][1], "controller", true), rect.position + Vector2(SLOT / 2.0, SLOT + 14), 14, COLOR_KEY)


func _is_ready(kind: String) -> bool:
	match kind:
		"potion":
			return player.potions > 0 and player.health < player.max_health
		"mana":
			return player.mana_potions > 0 and player.mana < player.max_mana
		"stamina_potion":
			return player.stamina_potions > 0 and player.stamina < player.max_stamina
		"shield":
			return player.shield_active or player.shield_cooldown <= 0.0
		"spell":
			return player.mana >= Player.SPELL_COST
		"h_bomb":
			return player.h_bombs > 0
	return true


func _count(kind: String) -> String:
	match kind:
		"potion":
			return str(player.potions)
		"mana":
			return str(player.mana_potions)
		"stamina_potion":
			return str(player.stamina_potions)
		"h_bomb":
			return str(player.h_bombs)
		"spell":
			return str(roundi(Player.SPELL_COST))
		"bag":
			return str(player.inventory.items.size()) if not player.inventory.items.is_empty() else ""
	return ""


## Settore scuro (frazione ratio del cerchio) per la ricarica.
func _draw_pie(center: Vector2, radius: float, ratio: float) -> void:
	var points := PackedVector2Array([center])
	var steps := 24
	for k in steps + 1:
		points.append(center + Vector2.from_angle(-PI / 2.0 + TAU * ratio * k / steps) * radius)
	if ratio > 0.01:
		draw_colored_polygon(points, Color(0, 0, 0, 0.55))


func _text(font: Font, text: String, at: Vector2, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := at.x - (width if align == HORIZONTAL_ALIGNMENT_RIGHT else width / 2.0)
	draw_string_outline(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
