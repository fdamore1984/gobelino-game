class_name XpOrb
extends Loot
## Sfera gialla d'esperienza: la lasciano i nemici abbattuti e le casse
## aperte (vedi Game._drop_xp). L'esperienza arriva solo raccogliendola
## (vedi Player.pickup con "xp"), non uccidendo. Come gli altri oggetti a
## terra salta fuori e poi vola verso il giocatore come attirata da una
## calamita, ma da più lontano (MAGNET_RANGE_ORB) e non sparisce mai. È una
## sfera gialla luminosa che non prende luci (si vede anche al buio), più
## grande quanta più esperienza contiene (size_scale). Raccogliendone
## tante di fila il suono sale di tono (vedi _chime).
##
## Non è nel gruppo "loot" (niente puntini sulla minimappa) ma in GROUP:
## lasciando un posto o salvando le sfere rimaste si danno subito al
## giocatore (vedi Game._collect_orbs), così l'esperienza non va persa.

const GROUP := "xp_orbs"
const MAGNET_RANGE_ORB := 230.0
const ORB_RADIUS := 7.0
const COLOR_ORB := Color(1.0, 0.86, 0.15)
const COLOR_CORE := Color(1.0, 0.98, 0.75)
const COLOR_GLOW := Color(1.0, 0.8, 0.1, 0.45)
## Raccolte a meno di CHAIN_TIME secondi l'una dall'altra fanno salire il
## tono di CHAIN_PITCH a sfera, fino a CHAIN_MAX sfere.
const CHAIN_TIME := 0.5
const CHAIN_PITCH := 0.035
const CHAIN_MAX := 20

static var _chain := 0
static var _chain_msec := 0

## Grandezza rispetto alla sfera normale (vedi Game._drop_xp).
var size_scale := 1.0


func _init() -> void:
	item_id = "xp"


func _ready() -> void:
	super()
	remove_from_group("loot")
	add_to_group(GROUP)
	material = Enemy._unshaded_material()


func magnet_range() -> float:
	return MAGNET_RANGE_ORB


## Suono della raccolta, più acuto se se ne raccolgono tante di fila.
static func chime(at: Vector2) -> void:
	var now := Time.get_ticks_msec()
	_chain = mini(_chain + 1, CHAIN_MAX) if now - _chain_msec < CHAIN_TIME * 1000.0 else 0
	_chain_msec = now
	Sfx.play("xp", at, 1.0 + CHAIN_PITCH * _chain, -4.0)


func focus_spot() -> Vector3:
	var at := global_position + _center()
	return Vector3(at.x, at.y, ORB_RADIUS * size_scale * 4.0)


func _draw() -> void:
	var center := _center()
	var radius := ORB_RADIUS * size_scale
	var pulse := 0.5 + 0.5 * sin(_age * 7.0 + position.x * 0.05)
	Shapes.disc(self, Vector2(0, -_lift + 4.0), radius * 0.8, Shapes.SHADOW)
	var focus := LowHealthVignette.focus_held()
	Shapes.glow(self, center, radius * (2.6 + 0.4 * pulse) * (FOCUS_SCALE if focus else 1.0), COLOR_GLOW)
	Shapes.ink_disc(self, center, radius, COLOR_ORB, 2.0)
	draw_circle(center + Vector2(-radius * 0.3, -radius * 0.3), radius * 0.4, COLOR_CORE)
