class_name Obstacle
extends Node2D
## Ostacolo naturale del mondo, disegnato con forme geometriche: albero,
## sasso, cespuglio, cassa, il totem al centro di un'arena, il banco di un mercante,
## l'ingresso di una caverna, il mausoleo in rovina che porta alle
## catacombe ("metro"), le scale del sotterraneo e, nelle catacombe, i
## sarcofagi bassi ("bench") e gli scheletri a terra ("corpse"). La posizione è la base a terra, così
## l'ordinamento per y lo mette davanti o dietro ai personaggi; viene
## disegnato più in alto quanto il blocco di terreno su cui si trova. Gli effetti (blocco,
## rallentamento) sono gestiti da World.

## La chioma degli alberi diventa trasparente quando il giocatore ci passa dietro.
const CANOPY_FADE_ALPHA := 0.4
## Elementi con cui si interagisce: in modalità focus restano a colori con
## un'aura bianca attorno (vedi LowHealthVignette).
const INTERACTIVE := ["chest", "cave", "metro", "stairs", "exit", "merchant", "totem"]
const COLOR_AURA := Color(1, 1, 1, 0.55)
## Urto del giocatore (vedi flash): luminosità in più e durata.
const FLASH_BOOST := 0.7
const FLASH_TIME := 0.3

var type_id := ""
var radius := 20.0
var _type: Dictionary
var _variant := 0
var _canopy_alpha := 1.0
var _opened := false
## Altezza del terreno sotto l'ostacolo.
var _lift := 0.0
## Ingresso della caverna: direzione della parete in cui si apre.
var _edge := Vector2.RIGHT
## Fiamme e bagliori che si vedono anche al buio (bracieri delle
## catacombe, alito del mausoleo): un nodo figlio senza luci.
var _glow: Node2D
## Aura della modalità focus disegnata adesso.
var _aura_shown := false
var _flash_tween: Tween


func setup(data: Dictionary, type: Dictionary) -> void:
	type_id = data["type"]
	radius = data["radius"]
	position = data["position"]
	_variant = data["variant"]
	_lift = data["elevation"]
	_type = type
	_edge = data.get("edge", Vector2.RIGHT)
	# Disegnato una volta sola; solo gli alberi controllano il giocatore e
	# il totem si anima.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# La torcia lo illumina come il punto del terreno su cui sta, in pianta.
	material = LightShaders.feet()
	set_process(type_id == "tree" or type_id in INTERACTIVE)
	if type_id == "metro" or (type_id == "stairs" and _in_crypt()):
		_glow = Node2D.new()
		_glow.material = Enemy._unshaded_material()
		_glow.draw.connect(_draw_glow)
		add_child(_glow)
	if type_id in INTERACTIVE:
		add_to_group(LowHealthVignette.FOCUS_GROUP)


## Il giocatore ci è appena andato a sbattere: l'ostacolo si illumina per un
## attimo (solo lui, senza contorni attorno).
func flash() -> void:
	if _flash_tween and _flash_tween.is_running():
		return
	modulate = Color(1.0 + FLASH_BOOST, 1.0 + FLASH_BOOST, 1.0 + FLASH_BOOST)
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, FLASH_TIME)


## Si può ancora usare (cassa chiusa, caverna non completata, totem pronto).
func _is_active() -> bool:
	var world := World.current
	match type_id:
		"chest":
			return not _opened
		"cave", "metro":
			return world == null or not world.is_cave_cleared(position)
		"totem":
			return world == null or world.totem_state(position) == "ready"
	return type_id in INTERACTIVE


## Modalità focus: dove resta a colori e quanto è grande (raggio 0: no).
func focus_spot() -> Vector3:
	if not _is_active():
		return Vector3.ZERO
	var at := global_position - Vector2(0, _lift + _aura_height())
	return Vector3(at.x, at.y, radius * 2.2)


## Altezza del centro dell'aura sopra la base.
func _aura_height() -> float:
	match type_id:
		"chest":
			return radius * 0.6
		"merchant":
			return radius * 1.4
		"totem":
			return radius * 1.4
		"metro":
			return radius * 0.8
	# Archi nella parete.
	return radius


func _process(_delta: float) -> void:
	if type_id in INTERACTIVE:
		var aura := LowHealthVignette.focus_held() and _is_active()
		if aura != _aura_shown:
			_aura_shown = aura
			queue_redraw()
	if type_id == "cave":
		return
	if type_id in ["totem", "merchant", "stairs", "exit", "metro"]:
		queue_redraw()
		if _glow:
			_glow.queue_redraw()
		return
	if type_id == "chest":
		# Brilla finché è chiusa; poi si ridisegna aperta.
		_opened = World.current != null and World.current.is_chest_opened(position)
		queue_redraw()
		return
	var player: Node2D = World.current.player if World.current else null
	var target := 1.0
	if player:
		# Confronto sullo schermo: anche il giocatore è disegnato alla sua altezza.
		var player_lift: float = World.current.elevation_at(player.global_position)
		var offset := player.global_position - Vector2(0, player_lift) - (global_position - Vector2(0, _lift))
		# Dietro l'albero (più in alto sullo schermo) e sotto la chioma.
		if offset.y < 0.0 and offset.y > -radius * 3.2 and absf(offset.x) < radius * 1.1:
			target = CANOPY_FADE_ALPHA
	if not is_equal_approx(target, _canopy_alpha):
		_canopy_alpha = move_toward(_canopy_alpha, target, 0.1)
		queue_redraw()


func _color(index: int) -> Color:
	var colors: Array = _type["colors"]
	var color: Array = colors[index % colors.size()]
	return Color(color[0], color[1], color[2])


func _type_color(key: String) -> Color:
	var color: Array = _type[key]
	return Color(color[0], color[1], color[2])


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _variant
	draw_set_transform(Vector2(0, -_lift))
	if _aura_shown:
		Shapes.glow(self, Vector2(0, -_aura_height()), radius * 2.4, COLOR_AURA)
	match type_id:
		"tree":
			_draw_tree(rng)
		"rock":
			_draw_rock(rng)
		"bush":
			_draw_bush(rng)
		"totem":
			_draw_totem()
		"chest":
			_draw_chest()
		"merchant":
			_draw_merchant()
		"cave":
			_draw_cave()
		"stairs":
			_draw_stairs()
		"exit":
			_draw_exit()
		"metro":
			_draw_mausoleum()
		"bench":
			_draw_sarcophagus(rng)
		"corpse":
			_draw_skeleton(rng)


func _draw_shadow(width: float) -> void:
	draw_set_transform(Vector2(0, -_lift), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, width, Shapes.SHADOW)
	draw_set_transform(Vector2(0, -_lift))


## Contorno a inchiostro (stile fumetto): disegnati prima del pieno, un
## cerchio, un poligono o un rettangolo un po' più grandi, neri.
func _ink_circle(center: Vector2, circle_radius: float, alpha := 1.0) -> void:
	draw_circle(center, circle_radius + Shapes.INK_WIDTH, Color(Shapes.INK, alpha))


func _ink_polygon(points: PackedVector2Array, alpha := 1.0) -> void:
	for grown in Geometry2D.offset_polygon(points, Shapes.INK_WIDTH, Geometry2D.JOIN_ROUND):
		draw_colored_polygon(grown, Color(Shapes.INK, alpha))


func _ink_rect(rect: Rect2) -> void:
	draw_rect(rect.grow(Shapes.INK_WIDTH), Shapes.INK)


## Tronco e chioma: tonda (latifoglia) o a strati di triangoli (abete).
func _draw_tree(rng: RandomNumberGenerator) -> void:
	_draw_shadow(radius * 0.9)
	var trunk := _type_color("trunk")
	var trunk_height := radius * 1.1
	_ink_rect(Rect2(-radius * 0.18, -trunk_height, radius * 0.36, trunk_height))
	draw_rect(Rect2(-radius * 0.18, -trunk_height, radius * 0.36, trunk_height), trunk)
	draw_rect(Rect2(-radius * 0.18, -trunk_height, radius * 0.12, trunk_height), trunk.lightened(0.15))
	var leaves := _color(rng.randi())
	leaves.a = _canopy_alpha
	var dark := leaves.darkened(0.25)
	if rng.randf() < 0.35:
		for k in 3:
			var width := radius * (1.1 - k * 0.25)
			var base_y := -trunk_height * 0.6 - k * radius * 0.7
			var tip_y := base_y - radius * 1.3
			_ink_polygon(PackedVector2Array([Vector2(-width, base_y), Vector2(width, base_y), Vector2(0, tip_y)]), _canopy_alpha)
			draw_colored_polygon(PackedVector2Array([Vector2(-width, base_y), Vector2(width, base_y), Vector2(0, tip_y)]), dark if k == 0 else leaves)
			draw_colored_polygon(PackedVector2Array([Vector2(0, base_y), Vector2(width, base_y), Vector2(0, tip_y)]), leaves.darkened(0.12))
	else:
		var center := Vector2(0, -trunk_height - radius * 0.55)
		# Contorno unico attorno a tutta la chioma.
		_ink_circle(center + Vector2(0, radius * 0.2), radius, _canopy_alpha)
		_ink_circle(center + Vector2(-radius * 0.45, 0), radius * 0.7, _canopy_alpha)
		_ink_circle(center + Vector2(radius * 0.4, -radius * 0.1), radius * 0.75, _canopy_alpha)
		_ink_circle(center + Vector2(0, -radius * 0.45), radius * 0.7, _canopy_alpha)
		draw_circle(center + Vector2(0, radius * 0.2), radius, dark)
		draw_circle(center + Vector2(-radius * 0.45, 0), radius * 0.7, leaves)
		draw_circle(center + Vector2(radius * 0.4, -radius * 0.1), radius * 0.75, leaves)
		draw_circle(center + Vector2(0, -radius * 0.45), radius * 0.7, leaves.lightened(0.08))
		draw_circle(center + Vector2(-radius * 0.25, -radius * 0.55), radius * 0.3, Color(leaves.lightened(0.2), 0.6 * _canopy_alpha))


## Masso irregolare con la faccia superiore più chiara.
func _draw_rock(rng: RandomNumberGenerator) -> void:
	_draw_shadow(radius * 1.05)
	var color := _color(rng.randi())
	var points := PackedVector2Array()
	var sides := rng.randi_range(6, 8)
	for k in sides:
		var angle := TAU * k / sides + rng.randf_range(-0.2, 0.2)
		points.append(Vector2(cos(angle), sin(angle) * 0.75) * radius * rng.randf_range(0.8, 1.05) + Vector2(0, -radius * 0.45))
	_ink_polygon(points)
	draw_colored_polygon(points, color.darkened(0.15))
	var top := PackedVector2Array()
	for point in points:
		top.append(point * 0.65 + Vector2(0, -radius * 0.35))
	draw_colored_polygon(top, color.lightened(0.1))
	points.append(points[0])
	draw_polyline(points, color.darkened(0.4), 2.0)


## Cespuglio: gruppo di cerchi, a volte con le bacche.
func _draw_bush(rng: RandomNumberGenerator) -> void:
	_draw_shadow(radius * 0.95)
	var color := _color(rng.randi())
	var blobs := []
	for k in 5:
		blobs.append([Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.9, -0.3)) * radius, radius * rng.randf_range(0.4, 0.6)])
	for blob: Array in blobs:
		_ink_circle(blob[0] + Vector2(0, 4), blob[1])
		_ink_circle(blob[0], blob[1])
	for blob: Array in blobs:
		draw_circle(blob[0] + Vector2(0, 4), blob[1], color.darkened(0.3))
	for blob: Array in blobs:
		draw_circle(blob[0], blob[1], color)
		draw_circle(blob[0] + Vector2(-blob[1] * 0.3, -blob[1] * 0.3), blob[1] * 0.35, color.lightened(0.12))
	if rng.randf() < 0.5:
		var berries := _type_color("berries")
		for k in 4:
			draw_circle(Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-1.0, -0.3)) * radius, 2.5, berries)


## Totem di pietra a tre blocchi con occhi luminosi: azzurri e con un
## anello pulsante a terra quando si può avviare la sfida, rossi durante la
## sfida, spenti dopo.
func _draw_totem() -> void:
	var state := World.current.totem_state(position) if World.current else "ready"
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
	var glow := _type_color("glow")
	if state == "active":
		glow = _type_color("active")
	elif state == "used":
		glow = _type_color("used")
	if state != "used":
		draw_set_transform(Vector2(0, -_lift), 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, radius * 2.2 + pulse * 10.0, 0.0, TAU, 40, Color(glow, 0.35 + 0.3 * pulse), 5.0)
		draw_set_transform(Vector2(0, -_lift))
	_draw_shadow(radius * 1.1)
	var stone := _type_color("stone")
	var y := 0.0
	for k in 3:
		var width := radius * (1.0 - k * 0.18)
		var height := radius * (0.9 - k * 0.1)
		y -= height
		# Faccia davanti e lato in ombra, come un blocco squadrato.
		_ink_rect(Rect2(-width, y, width * 2.0, height))
		draw_rect(Rect2(-width, y, width * 2.0, height), stone.darkened(0.05 * k))
		draw_rect(Rect2(width * 0.55, y, width * 0.45, height), stone.darkened(0.25))
		draw_line(Vector2(-width, y), Vector2(width, y), stone.lightened(0.2), 2.0)
		# Occhi e bocca incisi, con la luce dello stato.
		var eye := Color(glow, 0.6 + 0.4 * pulse) if state != "used" else glow
		draw_circle(Vector2(-width * 0.38, y + height * 0.38), width * 0.13, eye)
		draw_circle(Vector2(width * 0.18, y + height * 0.38), width * 0.13, eye)
		draw_line(Vector2(-width * 0.4, y + height * 0.75), Vector2(width * 0.2, y + height * 0.75), stone.darkened(0.45), 3.0)
	# In cima una punta.
	draw_colored_polygon(PackedVector2Array([Vector2(-radius * 0.5, y), Vector2(radius * 0.5, y), Vector2(0, y - radius * 0.7)]), stone.lightened(0.1))


## Cassa di legno con le fasce di metallo: chiusa brilla un poco, aperta
## mostra il coperchio alzato e l'interno vuoto.
func _draw_chest() -> void:
	_draw_shadow(radius * 1.2)
	var wood := _color(0)
	var metal := _type_color("metal")
	var width := radius * 1.3
	var height := radius * 0.9
	_ink_rect(Rect2(-width, -height, width * 2.0, height))
	draw_rect(Rect2(-width, -height, width * 2.0, height), wood)
	draw_rect(Rect2(width * 0.55, -height, width * 0.45, height), wood.darkened(0.25))
	for x: float in [-width * 0.6, width * 0.4]:
		draw_rect(Rect2(x, -height, width * 0.18, height), metal.darkened(0.2))
	if _opened:
		draw_rect(Rect2(-width, -height - 4.0, width * 2.0, 6.0), wood.darkened(0.6))
		draw_colored_polygon(PackedVector2Array([Vector2(-width, -height - 2.0), Vector2(width, -height - 2.0), Vector2(width * 0.9, -height - radius * 1.1), Vector2(-width * 0.9, -height - radius * 1.1)]), wood.lightened(0.05))
		return
	var lid := PackedVector2Array([Vector2(-width, -height), Vector2(width, -height), Vector2(width * 0.85, -height - radius * 0.6), Vector2(-width * 0.85, -height - radius * 0.6)])
	_ink_polygon(lid)
	draw_colored_polygon(lid, wood.lightened(0.12))
	draw_rect(Rect2(-4.0, -height - 3.0, 8.0, 9.0), metal)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 300.0)
	draw_circle(Vector2(width * 0.7, -height - radius * 0.7), 2.0 + pulse * 1.5, Color(1.0, 0.95, 0.6, 0.6 + 0.4 * pulse))


## Banco del mercante: pali e tenda a strisce, il mercante col cappello a
## punta dietro il bancone di legno con la merce in mostra e un'insegna con
## la moneta che brilla, per riconoscerlo da lontano.
func _draw_merchant() -> void:
	_draw_shadow(radius * 1.5)
	var wood := _type_color("wood")
	var robe := _type_color("robe")
	var skin := _type_color("skin")
	var gold := _type_color("gold")
	var width := radius * 1.3
	var height := radius * 0.75
	var top := -height - radius * 2.0
	for x: float in [-width, width - 5.0]:
		draw_rect(Rect2(x, top, 5.0, radius * 2.0), wood.darkened(0.3))
	# Il mercante dondola appena, come se respirasse.
	var breath := sin(Time.get_ticks_msec() / 400.0) * 1.5
	var body := Vector2(0, -height - 6.0 + breath * 0.5)
	var head := body + Vector2(0, -radius * 0.55 + breath * 0.3)
	_ink_circle(body, radius * 0.42)
	_ink_circle(head, radius * 0.28)
	draw_circle(body, radius * 0.42, robe)
	draw_circle(head, radius * 0.28, skin)
	Shapes.eyes(self, head + Vector2(0, -1), radius * 0.09, Vector2.DOWN)
	draw_colored_polygon(PackedVector2Array([head + Vector2(-radius * 0.36, -radius * 0.14), head + Vector2(radius * 0.36, -radius * 0.14),
			head + Vector2(radius * 0.12, -radius * 0.85)]), robe.darkened(0.25))
	draw_line(head + Vector2(-radius * 0.42, -radius * 0.14), head + Vector2(radius * 0.42, -radius * 0.14), robe.darkened(0.45), 3.0)
	# Tenda inclinata a strisce, col bordo a festoni.
	var stripes := 6
	var back := top
	var front := top + radius * 0.45
	for k in stripes:
		var x0 := -width - 6.0 + (width * 2.0 + 12.0) * k / stripes
		var x1 := -width - 6.0 + (width * 2.0 + 12.0) * (k + 1) / stripes
		var color := _color(k)
		draw_colored_polygon(PackedVector2Array([Vector2(x0 * 0.92, back), Vector2(x1 * 0.92, back), Vector2(x1, front), Vector2(x0, front)]), color)
		draw_circle(Vector2((x0 + x1) / 2.0, front), (x1 - x0) / 2.0, color.darkened(0.08))
	# Bancone con la merce.
	_ink_rect(Rect2(-width, -height, width * 2.0, height))
	draw_rect(Rect2(-width, -height, width * 2.0, height), wood)
	draw_rect(Rect2(width * 0.6, -height, width * 0.4, height), wood.darkened(0.25))
	draw_rect(Rect2(-width - 4.0, -height - 5.0, width * 2.0 + 8.0, 6.0), wood.lightened(0.15))
	draw_circle(Vector2(-width * 0.6, -height - 10.0), 5.0, Items.color("potion_health"))
	draw_circle(Vector2(-width * 0.38, -height - 9.0), 4.0, Items.color("potion_mana"))
	draw_rect(Rect2(width * 0.15, -height - 11.0, 14.0, 7.0), Items.color("book_fire"))
	draw_line(Vector2(width * 0.5, -height - 4.0), Vector2(width * 0.85, -height - 16.0), Items.color("sword_steel"), 3.0)
	# Insegna con la moneta sopra la tenda.
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 300.0)
	var board := Vector2(0, top - 10.0)
	_ink_circle(board, 9.0)
	draw_circle(board, 9.0, gold.darkened(0.3))
	draw_circle(board, 7.0, gold)
	draw_circle(board + Vector2(7, -7), 1.5 + pulse * 1.5, Color(1.0, 0.97, 0.7, 0.5 + 0.5 * pulse))


## Arco nella parete (caverna, scale, uscita): bordo di pietre e interno
## del colore dato. Restituisce i punti dell'interno.
func _draw_arch(inside: Color) -> PackedVector2Array:
	var width := radius * 1.1
	var height := radius * 2.0
	var arch := PackedVector2Array()
	var rim := PackedVector2Array()
	for k in 17:
		var angle := PI * k / 16.0
		arch.append(_edge * cos(angle) * width + Vector2(0, -sin(angle) * height))
		rim.append(_edge * cos(angle) * (width + 7.0) + Vector2(0, -sin(angle) * (height + 7.0)))
	var stone := _color(1)
	_ink_polygon(rim)
	draw_colored_polygon(rim, stone.darkened(0.2))
	draw_colored_polygon(arch, inside)
	for k in 7:
		var angle := PI * k / 6.0
		draw_circle(_edge * cos(angle) * (width + 4.0) + Vector2(0, -sin(angle) * (height + 4.0)), 6.0, stone)
	return arch


## Direzione dalla parete verso chi guarda (sul pavimento davanti all'arco).
func _out_of_wall() -> Vector2:
	var normal := _edge.orthogonal()
	return normal if normal.y > 0.0 else -normal


## Ingresso della caverna: un arco buio nella parete della montagna;
## chiuso da massi se il sotterraneo è già completato.
func _draw_cave() -> void:
	_draw_arch(_color(0))
	var width := radius * 1.1
	var height := radius * 2.0
	if World.current and World.current.is_cave_cleared(position):
		var rubble := _type_color("cleared")
		for k in 6:
			draw_circle(_edge * (k - 2.5) * width * 0.35 + Vector2(0, -8.0 - (k % 2) * 10.0), 11.0, rubble.darkened(0.1 * (k % 3)))
		return
	# Un filo d'aria fredda che esce dal buio.
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 500.0)
	draw_circle(Vector2(0, -height * 0.35), width * 0.35, Color(0.4, 0.5, 0.7, 0.08 + 0.06 * pulse))


## Passaggio che scende al piano sotto: un arco buio nella parete, con i
## gradini che spariscono nel buio e una luce fredda che pulsa dal fondo.
func _draw_stairs() -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 350.0)
	_draw_arch(_color(0))
	var width := radius * 1.1
	var height := radius * 2.0
	var stone := _color(1)
	for k in 4:
		var y := -3.0 - k * 7.0
		var w := width * (0.9 - k * 0.18)
		draw_line(_edge * -w + Vector2(0, y), _edge * w + Vector2(0, y), stone.darkened(0.25 + k * 0.15), 4.0)
	draw_circle(Vector2(0, -height * 0.55), width * 0.4, Color(_type_color("glow"), 0.12 + 0.18 * pulse))


## Uscita verso la superficie: un arco nella parete pieno di luce calda,
## che si allunga sul pavimento davanti.
func _draw_exit() -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 400.0)
	var light := _type_color("glow")
	var out := _out_of_wall()
	draw_set_transform(Vector2(0, -_lift) + out * radius * 0.8, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, radius * 1.2, Color(light, 0.12 + 0.08 * pulse))
	draw_set_transform(Vector2(0, -_lift))
	_draw_arch(Color(light, 0.85))
	var height := radius * 2.0
	draw_circle(Vector2(0, -height * 0.45), radius * 0.6, Color(1, 1, 1, 0.25 + 0.2 * pulse))


func _in_crypt() -> bool:
	return World.current != null and World.current.dungeon != null and World.current.dungeon.is_metro()


## Bagliori che si vedono anche al buio, sul nodo senza luci (_glow).
func _draw_glow() -> void:
	_glow.draw_set_transform(Vector2(0, -_lift))
	if type_id == "metro":
		if World.current and World.current.is_cave_cleared(position):
			return
		# Dal buio della porta sale un alito verde e la runa sopra brilla.
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 600.0)
		var sign_color := _type_color("sign")
		var door_h := radius * 1.25 * 0.82
		_glow.draw_circle(Vector2(0, -6 - door_h * 0.45), radius * 0.45, Color(sign_color, 0.06 + 0.06 * pulse))
		_glow.draw_circle(Vector2(0, -6 - radius * 1.25 - radius * 0.28), 4.0, Color(sign_color, 0.5 + 0.4 * pulse))
		return
	# Nelle catacombe ai lati della scala che scende ardono due bracieri di
	# fiamma verde che tremola in modo irregolare.
	var width := radius * 1.1
	var height := radius * 2.0
	var t := Time.get_ticks_msec() / 1000.0
	for side: float in [-1.0, 1.0]:
		var base := _edge * side * (width + 16.0) + Vector2(0, -height * 0.55)
		var flicker := 0.75 + 0.25 * sin(t * (11.0 + side * 2.3)) * sin(t * 7.1 + side)
		_glow.draw_line(base, base + Vector2(0, 14), Color(0.25, 0.22, 0.2), 3.0)
		_glow.draw_colored_polygon(PackedVector2Array([base + Vector2(-6, 0), base + Vector2(6, 0), base + Vector2(3, 5), base + Vector2(-3, 5)]), Color(0.3, 0.27, 0.24))
		_glow.draw_circle(base + Vector2(0, -6), 18.0, Color(0.35, 1.0, 0.45, 0.16 * flicker))
		_glow.draw_colored_polygon(PackedVector2Array([base + Vector2(-4, 0), base + Vector2(0, -14.0 * flicker), base + Vector2(4, 0)]), Color(0.45, 1.0, 0.5, 0.9))


## Mausoleo in rovina: basamento e cella di pietra con due colonne, il
## frontone crepato e la porta buia con i gradini che scendono nelle
## catacombe; dal buio sale un alito verde (_draw_glow). Ripulite le
## catacombe, la porta è chiusa da una lastra.
func _draw_mausoleum() -> void:
	_draw_shadow(radius * 1.2)
	var dark := _color(0)
	var stone := _color(1)
	var w := radius * 0.95
	var depth := radius * 0.5
	var wall_h := radius * 1.25
	# Basamento a gradino.
	_ink_polygon(PackedVector2Array([Vector2(-w - 8, 4), Vector2(w + 8, 4), Vector2(w + 8, -6), Vector2(-w - 8, -6)]))
	draw_colored_polygon(PackedVector2Array([Vector2(-w - 8, 4), Vector2(w + 8, 4), Vector2(w + 8, -6), Vector2(-w - 8, -6)]), stone.darkened(0.25))
	# Cella: fianco in ombra e facciata.
	_ink_polygon(PackedVector2Array([Vector2(w, -6), Vector2(w + depth * 0.6, -6 - depth * 0.5), Vector2(w + depth * 0.6, -6 - depth * 0.5 - wall_h), Vector2(w, -6 - wall_h)]))
	draw_colored_polygon(PackedVector2Array([Vector2(w, -6), Vector2(w + depth * 0.6, -6 - depth * 0.5), Vector2(w + depth * 0.6, -6 - depth * 0.5 - wall_h), Vector2(w, -6 - wall_h)]), stone.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([Vector2(-w, -6), Vector2(w, -6), Vector2(w, -6 - wall_h), Vector2(-w, -6 - wall_h)]), stone)
	# Frontone triangolare con una crepa.
	var roof := -6 - wall_h
	_ink_polygon(PackedVector2Array([Vector2(-w - 6, roof), Vector2(w + 6, roof), Vector2(0, roof - radius * 0.6)]))
	draw_colored_polygon(PackedVector2Array([Vector2(-w - 6, roof), Vector2(w + 6, roof), Vector2(0, roof - radius * 0.6)]), stone.lightened(0.1))
	draw_colored_polygon(PackedVector2Array([Vector2(w + 6, roof), Vector2(w + 6 + depth * 0.6, roof - depth * 0.5), Vector2(depth * 0.6, roof - radius * 0.6 - depth * 0.5), Vector2(0, roof - radius * 0.6)]), stone.darkened(0.15))
	draw_polyline(PackedVector2Array([Vector2(-w * 0.3, roof - 4), Vector2(-w * 0.15, roof - 12), Vector2(-w * 0.25, roof - 20)]), stone.darkened(0.45), 1.5)
	# Colonne ai lati della porta.
	for side: float in [-1.0, 1.0]:
		draw_rect(Rect2(side * w * 0.72 - 5, roof, 10, wall_h), stone.lightened(0.15))
		draw_rect(Rect2(side * w * 0.72 - 7, roof, 14, 5), stone.lightened(0.25))
	# Porta ad arco.
	var door := PackedVector2Array()
	var door_w := w * 0.42
	var door_h := wall_h * 0.82
	for k in 9:
		var angle := PI * k / 8.0
		door.append(Vector2(cos(angle) * door_w, -6 - door_h + door_w - sin(angle) * door_w))
	door.append(Vector2(-door_w, -6))
	door.append(Vector2(door_w, -6))
	var cleared := World.current != null and World.current.is_cave_cleared(position)
	if cleared:
		draw_colored_polygon(door, _type_color("cleared"))
		draw_polyline(PackedVector2Array([Vector2(-door_w * 0.6, -door_h * 0.4), Vector2(door_w * 0.5, -door_h * 0.7)]), stone.darkened(0.4), 2.0)
		return
	draw_colored_polygon(door, dark)
	for k in 3:
		var y := -9.0 - k * 6.0
		draw_line(Vector2(-door_w * (0.8 - k * 0.18), y), Vector2(door_w * (0.8 - k * 0.18), y), stone.darkened(0.5 + k * 0.12), 3.0)
	# L'alito verde e la runa sono su _glow (vedi _draw_glow).


## Sarcofago basso di pietra sulla navata, in diagonale come le navate:
## cassa con il coperchio più chiaro, a volte spostato di traverso.
func _draw_sarcophagus(rng: RandomNumberGenerator) -> void:
	_draw_shadow(radius * 0.95)
	var stone := _color(0)
	var along := Vector2(1.0, 0.5).normalized() * radius
	var across := Vector2(-1.0, 0.5).normalized() * radius * 0.4
	var lift := Vector2(0, -14)
	var base := PackedVector2Array([-along - across, along - across, along + across, -along + across])
	# Fianchi visibili (verso il basso dello schermo).
	draw_colored_polygon(PackedVector2Array([base[1], base[2], base[2] + lift, base[1] + lift]), stone.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([base[2], base[3], base[3] + lift, base[2] + lift]), stone.darkened(0.15))
	var shift := Vector2.ZERO
	if rng.randf() < 0.3:
		# Coperchio spostato: si vede il buio dentro.
		shift = along * 0.25
		draw_colored_polygon(PackedVector2Array([base[0] + lift, base[1] + lift, base[2] + lift, base[3] + lift]), Color(0.05, 0.04, 0.05))
	var lid := PackedVector2Array()
	for point in base:
		lid.append(point * 1.05 + lift + Vector2(0, -3) + shift)
	draw_colored_polygon(lid, _color(1).lightened(0.2))
	lid.append(lid[0])
	draw_polyline(lid, stone.darkened(0.45), 1.5)


## Scheletro a terra in una pozza di sangue, avvolto in un sudario
## strappato: rallenta un poco.
func _draw_skeleton(rng: RandomNumberGenerator) -> void:
	var blood := _type_color("blood")
	draw_set_transform(Vector2(0, -_lift), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2(rng.randf_range(-6, 6), 4), radius * 1.3, Color(blood, 0.7))
	draw_set_transform(Vector2(0, -_lift))
	var cloth := _color(rng.randi())
	var angle := rng.randf_range(-0.4, 0.4)
	var axis := Vector2.from_angle(angle) * radius
	var shroud := PackedVector2Array()
	for k in 10:
		var a := TAU * k / 10.0
		shroud.append(Vector2(cos(a), sin(a) * 0.38).rotated(angle) * radius * rng.randf_range(0.85, 1.05))
	draw_colored_polygon(shroud, cloth.darkened(0.25))
	var bone := Color(0.88, 0.85, 0.75)
	# Costole lungo il corpo.
	for k in 4:
		var at := axis * (0.45 - k * 0.22)
		var rib := axis.orthogonal().normalized() * radius * 0.28
		draw_line(at - rib, at + rib, bone, 2.0)
	draw_line(axis * 0.55, -axis * 0.4, bone, 2.0)
	draw_circle(axis * 1.1 + Vector2(0, -2), radius * 0.3, bone)
	for side: float in [-1.0, 1.0]:
		draw_circle(axis * 1.15 + axis.orthogonal().normalized() * radius * 0.1 * side + Vector2(0, -2), 1.6, Color(0.08, 0.06, 0.06))
	draw_line(-axis * 0.4, -axis * 0.9 + Vector2(-radius * 0.2, radius * 0.25), bone, 2.0)
	draw_line(-axis * 0.4, -axis * 0.95 + Vector2(radius * 0.15, -radius * 0.1), bone, 2.0)
