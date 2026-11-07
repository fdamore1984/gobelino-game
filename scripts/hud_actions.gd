class_name HudActions
extends Control
## Barra delle azioni in basso a sinistra: pozioni (vita, mana, vigore),
## scudo, palla di fuoco, rune del cataclisma (h_bomb, L2 + R2 in aria)
## e inventario, ognuno con la sua icona, il tasto del
## controller scelto dal giocatore (vedi Keybinds),
## quante ne restano o la ricarica. Sui dispositivi touch non serve: ci
## sono già i pulsanti a schermo.
## Caselle color crema col contorno nero e l'ombra piena, come i pulsanti
## del sito (vedi UiStyle); quante ne restano in un distintivo sull'angolo.

const SLOT := 58.0
const GAP := 8.0
const FONT_SIZE := 15
const COLOR_KEY := UiStyle.CREAM
## Azioni: icona e azione dell'Input Map (per il tasto del controller;
## più azioni insieme separate da "+").
const ACTIONS := [
	["potion", "potion"], ["mana", "mana_potion"], ["shield", "shield"], ["spell", "spell"],
	["stamina_potion", "stamina_potion"], ["h_bomb", "heavy_attack+focus"], ["bag", "inventory"],
]

var player: Player

var _style := UiStyle.box(UiStyle.CREAM, 16, 3, 3.0, UiStyle.INK)
var _active := UiStyle.box(UiStyle.ACCENT, 16, 3, 5.0, UiStyle.INK)
var _unavailable := UiStyle.box(Color(UiStyle.INK, 0.35), 13, 0, 0.0)
var _badge := UiStyle.pill(UiStyle.PANEL, 2)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(ACTIONS.size() * (SLOT + GAP) - GAP, SLOT + 14)


## Si ridisegna al più ogni REDRAW_INTERVAL secondi (attese e scorte non
## cambiano a ogni frame).
const REDRAW_INTERVAL := 0.05
var _redraw_timer := 0.0


func _process(delta: float) -> void:
	position = Vector2(16, get_viewport_rect().size.y - size.y - 12)
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = REDRAW_INTERVAL
		queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var font := ThemeDB.fallback_font
	for i in ACTIONS.size():
		var rect := Rect2(Vector2(i * (SLOT + GAP), 0), Vector2(SLOT, SLOT))
		var kind: String = ACTIONS[i][0]
		var available := is_ready(player, kind)
		var highlight := kind == "shield" and player.shield_active
		draw_style_box(_active if highlight else _style, rect)
		UpgradeIcon.draw_icon(self, rect.get_center(), SLOT * 0.62, kind, false)
		draw_set_transform(Vector2.ZERO)
		if not available:
			draw_style_box(_unavailable, rect.grow(-3))
		# Ricarica dello scudo: un settore scuro che si svuota, e i secondi.
		if kind == "shield" and player.shield_cooldown > 0.0 and not player.shield_active:
			var left := player.shield_cooldown / player.shield_cooldown_max
			_draw_pie(rect.get_center(), SLOT * 0.4, left)
			_text(font, str(ceili(player.shield_cooldown)), rect.get_center() + Vector2(0, 6), FONT_SIZE, Color.WHITE)
		var count := count_text(player, kind)
		if count != "":
			draw_badge(self, font, count, rect.position + Vector2(SLOT - 2, 0), _badge)
		# Tasto del controller, sotto lo slot.
		_text(font, _keys(ACTIONS[i][1]), rect.position + Vector2(SLOT / 2.0, SLOT + 14), 14, COLOR_KEY)


## Tasti del controller di una o più azioni ("heavy_attack+focus" -> "L2+R2").
func _keys(actions: String) -> String:
	var keys := PackedStringArray()
	for action in actions.split("+"):
		keys.append(Keybinds.primary(action, "controller", true))
	return "+".join(keys)


## La casella si può usare adesso (anche per i tasti a schermo, vedi TouchControls).
static func is_ready(who: Player, kind: String) -> bool:
	match kind:
		"potion":
			return who.potions > 0 and who.health < who.max_health
		"mana":
			return who.mana_potions > 0 and who.mana < who.max_mana
		"stamina_potion":
			return who.stamina_potions > 0 and who.stamina < who.max_stamina
		"shield":
			return who.shield_active or who.shield_cooldown <= 0.0
		"spell":
			return who.mana >= Player.SPELL_COST
		"h_bomb":
			return who.h_bombs > 0
	return true


## Quante ne restano, da scrivere nel distintivo ("" per nessun numero).
static func count_text(who: Player, kind: String) -> String:
	match kind:
		"potion":
			return str(who.potions)
		"mana":
			return str(who.mana_potions)
		"stamina_potion":
			return str(who.stamina_potions)
		"h_bomb":
			return str(who.h_bombs)
		"spell":
			return str(roundi(Player.SPELL_COST))
		"bag":
			return str(who.inventory.items.size()) if not who.inventory.items.is_empty() else ""
	return ""


## Distintivo a pillola con quante ne restano, centrato sull'angolo in
## alto a destra della casella.
static func draw_badge(canvas: CanvasItem, font: Font, text: String, at: Vector2, style: StyleBox, font_size := 13) -> void:
	var half_height := font_size * 0.77
	var width := maxf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 12.0, half_height * 2.0)
	canvas.draw_style_box(style, Rect2(at - Vector2(width / 2.0, half_height), Vector2(width, half_height * 2.0)))
	canvas.draw_string(font, at + Vector2(-width / 2.0, font_size * 0.38), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, UiStyle.CREAM)


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
	draw_string_outline(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, UiStyle.INK)
	draw_string(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
