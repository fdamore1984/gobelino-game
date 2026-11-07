class_name DamagePopups
extends Node2D
## Numeri dei danni (opzione Numeri dei danni, vedi Settings): quando un
## nemico perde vita, dal punto colpito salta fuori il danno del colpo
## (vedi Enemy.take_points e Enemy.shown_damage), moltiplicato per "scale"
## di "damage_numbers" in data/world.json e variato a caso di "variance",
## così i numeri sono grandi (decine all'inizio, centinaia e migliaia
## più avanti) e mai tutti uguali; dalle migliaia hanno il separatore
## ("1.250" in italiano, "1,250" in inglese) e un carattere più grande. Il
## numero sale un poco, si allarga di colpo e
## svanisce in LIFETIME secondi. Bianchi per i colpi normali, arancioni per
## i colpi potenti, gialli e più grandi con il punto esclamativo per il
## contrattacco (vedi Player._counter_strike). Contorno a inchiostro nel
## font del gioco; non prendono luce, quindi si leggono anche al buio. Un
## solo nodo li disegna tutti, al più MAX_POPUPS insieme (nelle orde i
## numeri sono tanti).

const LIFETIME := 0.75
const RISE := 42.0
const MAX_POPUPS := 40
const FONT_SIZE := 22
const BIG_FONT_SIZE := 27
const CRITICAL_FONT_SIZE := 32
## Da qui il numero è "grande" (BIG_FONT_SIZE).
const BIG_NUMBER := 1000
const OUTLINE := 6
const COLOR_NORMAL := Color(1.0, 1.0, 1.0)
const COLOR_HEAVY := Color(1.0, 0.62, 0.25)
const COLOR_CRITICAL := Color(1.0, 0.88, 0.2)

static var current: DamagePopups

var _popups: Array[Dictionary] = []


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func _ready() -> void:
	z_index = 60
	material = Enemy._unshaded_material()
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	set_process(false)


## Un numero in at (posizione a terra), alzato di lift, per un colpo con
## quel danno (vedi Enemy.shown_damage): kind è "normal", "heavy" o
## "critical" (il contrattacco, che vale anche "critical_bonus" in più).
static func spawn(at: Vector2, lift: float, damage: float, kind := "normal") -> void:
	if current == null or not Settings.damage_numbers:
		return
	if current._popups.size() >= MAX_POPUPS:
		current._popups.pop_front()
	var value := shown_value(damage, kind)
	current._popups.append({"at": at + Vector2(randf_range(-10, 10), 0), "lift": lift, "text": format(value) + ("!" if kind == "critical" else ""),
			"kind": kind, "big": value >= BIG_NUMBER, "age": 0.0, "drift": randf_range(-14, 14)})
	current.set_process(true)


## Numero da mostrare per un colpo con quel danno (vedi in cima).
static func shown_value(damage: float, kind := "normal") -> int:
	var data: Dictionary = World.DATA.data["damage_numbers"]
	var variance := float(data["variance"])
	var value := damage * float(data["scale"]) * randf_range(1.0 - variance, 1.0 + variance)
	if kind == "critical":
		value *= 1.0 + float(data["critical_bonus"])
	return maxi(roundi(value), 1)


## Il numero con il separatore delle migliaia della lingua del gioco.
static func format(value: int) -> String:
	var separator := "." if TranslationServer.get_locale().begins_with("it") else ","
	var digits := str(value)
	var result := ""
	while digits.length() > 3:
		result = separator + digits.right(3) + result
		digits = digits.left(digits.length() - 3)
	return digits + result


func _process(delta: float) -> void:
	for k in range(_popups.size() - 1, -1, -1):
		_popups[k]["age"] += delta
		if _popups[k]["age"] >= LIFETIME:
			_popups.remove_at(k)
	queue_redraw()
	if _popups.is_empty():
		set_process(false)


func _draw() -> void:
	var font := UiStyle.bold()
	for popup in _popups:
		var t: float = popup["age"] / LIFETIME
		var kind: String = popup["kind"]
		var size := CRITICAL_FONT_SIZE if kind == "critical" else (BIG_FONT_SIZE if popup["big"] else FONT_SIZE)
		# Esce più grande e si assesta, poi svanisce nell'ultimo terzo.
		var pop := 1.0 + 0.6 * maxf(1.0 - t / 0.18, 0.0)
		var alpha := clampf((1.0 - t) / 0.35, 0.0, 1.0)
		var color := COLOR_CRITICAL if kind == "critical" else (COLOR_HEAVY if kind == "heavy" else COLOR_NORMAL)
		var at: Vector2 = popup["at"] + Vector2(float(popup["drift"]) * t, -float(popup["lift"]) - RISE * ease(t, 0.4))
		var text: String = popup["text"]
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_set_transform(at, 0.0, Vector2(pop, pop))
		draw_string_outline(font, Vector2(-width / 2.0, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, OUTLINE, Color(UiStyle.INK, alpha))
		draw_string(font, Vector2(-width / 2.0, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, alpha))
	draw_set_transform(Vector2.ZERO)
