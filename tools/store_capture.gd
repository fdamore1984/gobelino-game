extends Node
## Genera copertina e screenshot per la pagina itch.io (store/itch/), in
## inglese (l'unica lingua del gioco per ora), componendo scene di gioco reali. Va rilanciato a
## ogni modifica visibile del gioco. Serve una finestra (non --headless):
##
##   godot --path . --resolution 1280x720 res://tools/store_capture.tscn -- screenshots
##   godot --path . --resolution 1260x1000 res://tools/store_capture.tscn -- cover
##
## Non fa parte del gioco: la cartella tools/ è esclusa dagli export.

const OUTPUT := "res://store/itch/"
const LANGUAGES := ["en"]
const SUBTITLE := {"en": "Action RPG · prototype"}
const COVER_SIZE := Vector2i(630, 500)
## Seme del mondo usato per le immagini, così il terreno è sempre lo stesso.
const WORLD_SEED := 1234

var _game: Node2D
var _player: Player


func _ready() -> void:
	var mode := "screenshots"
	if not OS.get_cmdline_user_args().is_empty():
		mode = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for language: String in LANGUAGES:
		TranslationServer.set_locale(language)
		if mode == "cover":
			await _capture_cover(language)
		else:
			await _capture_menu(language)
			await _capture_combat(language)
			await _capture_parry(language)
			await _capture_level_up(language)
			await _capture_challenge(language)
			await _capture_inventory(language)
			await _capture_merchant(language)
			await _capture_slam(language)
			await _capture_cave(language)
			await _capture_dungeon(language)
	get_tree().quit()


func _capture_menu(language: String) -> void:
	var menu := (load("res://scenes/menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	# Nella pagina dello store non serve la riga diagnostica sul controller.
	var info: Label = menu.get_node("%Info")
	info.text = "\n".join(info.text.split("\n").slice(0, 2))
	await _save("%s_4_menu.png" % language)
	menu._on_controls_pressed()
	await _frames(3)
	await _save("%s_10_controls.png" % language)
	menu.queue_free()
	await _frames(2)


## Colpo potente in fondo alla combo, un bruto che carica, un evocatore
## che evoca, nemici attorno; scudo attivo.
func _capture_combat(language: String) -> void:
	await _start_game(Vector2(0, 20), 1.15)
	_player.level = 3
	_player.experience = 170
	_player.facing = Vector2(1, -0.2).normalized()
	_player._combo_step = 3
	_player._heavy_step = 1
	_player._attack_heavy = true
	_player._state = Player.State.ATTACK
	_player._state_time = Player.HEAVY_WINDUP + 0.03
	_player.shield_active = true
	_player.shield_cooldown = 21.0
	_player.potions = 1
	_player.apply_upgrade("combo")
	_player.apply_upgrade("dodge")
	_hud_stats()
	var warrior := _enemy("warrior", Vector2(95, -25), Enemy.State.CHASE, 0.0)
	warrior.health = 15
	warrior._hit_flash = 0.1
	_enemy("brute", Vector2(-170, 90), Enemy.State.WINDUP, 0.6)
	var summoner := _enemy("summoner", Vector2(330, 150), Enemy.State.SUMMON, 0.8)
	summoner._summon_positions = [Vector2(-70, 0), Vector2(70, 0)]
	_enemy("caster", Vector2(-330, -140), Enemy.State.WINDUP, 0.6)
	_enemy("lancer", Vector2(250, -190), Enemy.State.CHASE, 0.0)
	_enemy("whirler", Vector2(-420, 200), Enemy.State.WINDUP, 0.7)
	_enemy("golem", Vector2(470, -40), Enemy.State.CHASE, 0.0)
	await _save("%s_1_combat.png" % language)
	_end_game()


## Parata perfetta: aura del potenziamento e nemico stordito.
func _capture_parry(language: String) -> void:
	await _start_game(Vector2(0, 0), 1.3)
	_player.level = 2
	_player.experience = 60
	_player.facing = Vector2.RIGHT
	_player._state = Player.State.PARRY
	_player._state_time = 0.05
	_player._empowered_time = Player.EMPOWER_TIME
	_hud_stats()
	_enemy("brute", Vector2(95, 10), Enemy.State.STUNNED, 0.4)
	_enemy("warrior", Vector2(-160, -60), Enemy.State.WINDUP, 0.5)
	_enemy("scout", Vector2(-260, 150), Enemy.State.CHASE, 0.0)
	_enemy("summoner", Vector2(330, -170), Enemy.State.CHASE, 0.0)
	await _save("%s_2_parry.png" % language)
	_end_game()


func _capture_level_up(language: String) -> void:
	await _start_game(Vector2(0, 0), 1.0)
	_player.level = 3
	_hud_stats()
	_enemy("warrior", Vector2(200, 60), Enemy.State.CHASE, 0.0)
	_enemy("scout", Vector2(-220, -90), Enemy.State.CHASE, 0.0)
	_enemy("brute", Vector2(-300, 160), Enemy.State.CHASE, 0.0)
	var hud: Hud = _game.get_node("HUD")
	hud.show_level_up(3, Player.BASE_DAMAGE + Player.DAMAGE_PER_LEVEL, Player.BASE_DAMAGE + 2 * Player.DAMAGE_PER_LEVEL)
	await get_tree().create_timer(Hud.LEVEL_UP_INPUT_DELAY + 0.1).timeout
	await _save("%s_3_level_up.png" % language)
	_end_game()


## Sfida del totem: il giocatore al centro dell'arena, l'ondata in arrivo.
func _capture_challenge(language: String) -> void:
	await _start_game(Vector2(0, 30), 1.0)
	var world: World = _game.get_node("World")
	# L'arena più vicina alla partenza, cercata regione per regione.
	var arena := Vector2.INF
	for distance in range(1, 6):
		for angle in 8:
			var candidate := world.arena_near(Vector2.from_angle(TAU * angle / 8.0) * distance * 2000.0)
			if candidate != Vector2.INF and (arena == Vector2.INF or candidate.length() < arena.length()):
				arena = candidate
		if arena != Vector2.INF:
			break
	_player.position = arena + Vector2(-40, 70)
	_player._ready()
	_player.reset_physics_interpolation()
	_player.level = 4
	_player.facing = Vector2(-1, 0.3).normalized()
	_player._swing_sign = 1.0
	_player._attack_heavy = false
	_player._combo_step = 2
	_player._state = Player.State.ATTACK
	_player._state_time = Player.ATTACK_WINDUP + 0.05
	_player.ground_elevation = world.elevation_at(_player.position)
	_hud_stats()
	world.set_totem_state(arena, "active")
	var hud: Hud = _game.get_node("HUD")
	hud.show_challenge(tr("CHALLENGE_STATUS") % [21, 5])
	_enemy("warrior", _player.position + Vector2(-110, 20), Enemy.State.STRIKE, 0.15)
	_enemy("scout", _player.position + Vector2(170, -120), Enemy.State.CHASE, 0.0)
	_enemy("brute", _player.position + Vector2(230, 90), Enemy.State.WINDUP, 0.9)
	_enemy("scout", _player.position + Vector2(-300, -150), Enemy.State.CHASE, 0.0)
	_enemy("warrior", _player.position + Vector2(-260, 190), Enemy.State.WINDUP, 0.4)
	# Di notte, con la torcia accesa e una palla di fuoco in volo.
	(_game.get_node("DayNight") as DayNight).time = 0.7
	_player.torch_on = true
	_player._torch.enabled = true
	_player._torch.position = Vector2(0, -_player.ground_elevation + Player.RADIUS * 0.6)
	var fireball := Fireball.new()
	fireball.position = _player.position + Vector2(120, -70)
	fireball.direction = Vector2(1, -0.4).normalized()
	fireball.altitude = _player.ground_elevation
	_entities().add_child(fireball)
	fireball.set_physics_process(false)
	fireball._light.position.y = -fireball.altitude
	# Il mondo attorno alla nuova posizione va generato prima della foto.
	var camera: Camera2D = _player.get_node("Camera")
	camera.position_smoothing_enabled = false
	camera.reset_physics_interpolation()
	camera.reset_smoothing()
	await _frames(2)
	camera.reset_smoothing()
	camera.force_update_scroll()
	world.refresh_now()
	await _frames(20)
	await _save("%s_5_challenge.png" % language)
	_end_game()


## Inventario con qualche oggetto trovato nelle casse.
func _capture_inventory(language: String) -> void:
	await _start_game(Vector2(0, 0), 1.0)
	_player.level = 4
	_hud_stats()
	for id in ["sword_steel", "armor_leather", "boots_swift", "amulet_mana", "ring_fire", "book_fire", "potion_health", "potion_mana", "sword_iron"]:
		_player.inventory.add(id)
	_player.inventory.gold = 137
	_player.inventory.equipped = {"weapon": 0, "armor": 1, "boots": 2}
	_player._refresh_stats()
	var hud: Hud = _game.get_node("HUD")
	hud._inventory_panel.player = _player
	hud._inventory_panel.open()
	await _frames(4)
	await _save("%s_6_inventory.png" % language)
	hud._inventory_panel.close()
	_end_game()


## Il banco di un mercante nel mondo e il suo negozio aperto.
func _capture_merchant(language: String) -> void:
	await _start_game(Vector2(0, -40), 1.25)
	_player.level = 5
	_hud_stats()
	var site := _nearest_merchant()
	_player.position = site + Vector2(-40, 105)
	_player.ground_elevation = (_game.get_node("World") as World).elevation_at(_player.position)
	_player.facing = Vector2(0.3, -1).normalized()
	_player.reset_physics_interpolation()
	var hud: Hud = _game.get_node("HUD")
	hud.show_challenge(tr("MERCHANT_HINT"))
	var camera: Camera2D = _player.get_node("Camera")
	camera.reset_physics_interpolation()
	camera.reset_smoothing()
	await _frames(2)
	camera.reset_smoothing()
	camera.force_update_scroll()
	(_game.get_node("World") as World).refresh_now()
	await _frames(20)
	await _save("%s_7_merchant.png" % language)
	for id in ["sword_iron", "armor_chain", "book_mana", "ring_fire", "potion_mana", "boots_swift"]:
		_player.inventory.add(id)
	_player.inventory.gold = 312
	_player.inventory.equipped = {"armor": 1}
	_player._refresh_stats()
	hud._shop_panel.player = _player
	hud.open_shop(site)
	await _frames(4)
	await _save("%s_8_shop.png" % language)
	hud._shop_panel.close()
	_end_game()


## Colpo a terra dopo la combo: onda d'urto, nemici colpiti che perdono
## sangue e nemici abbattuti stesi a terra.
func _capture_slam(language: String) -> void:
	await _start_game(Vector2(0, -10), 1.2)
	_player.level = 6
	_hud_stats()
	var origin := _player.position
	# Nemici abbattuti poco prima, con le pozze di sangue.
	for spot: Array in [["warrior", Vector2(-230, 60)], ["scout", Vector2(210, 120)], ["lancer", Vector2(-120, -170)]]:
		var dead := _enemy(spot[0], origin + spot[1], Enemy.State.WANDER, 0.0)
		dead._fall_side = 1.0 if spot[1].x > 0.0 else -1.0
		GroundFx.pool(dead.position, dead.radius * 0.9)
		for k in 3:
			GroundFx.bleed(dead.position, dead.ground_elevation + dead.radius, Vector2.from_angle(randf() * TAU), 6)
		GroundFx.corpse(dead.position, dead.ground_elevation, dead._corpse_points(1.0), dead._corpse_color())
		dead.queue_free()
	# Nemici colpiti dall'onda d'urto, spinti via.
	var hit: Array[Enemy] = []
	for spot: Array in [["brute", Vector2(110, -40)], ["warrior", Vector2(-100, 30)], ["scout", Vector2(30, 105)]]:
		var enemy := _enemy(spot[0], origin + spot[1], Enemy.State.STUNNED, 0.2)
		enemy.health = int(enemy.max_health * 0.4)
		hit.append(enemy)
	await _frames(50)
	_player._state = Player.State.SLAM
	_player._slam_kind = "leap"
	_player._slam_landed = true
	_player._squash = 0.7
	_player.facing = Vector2(1, 0.2).normalized()
	_player.queue_redraw()
	GroundFx.shockwave(origin, _player.ground_elevation, Player.SLAM_RADIUS["leap"])
	for enemy in hit:
		var direction := (enemy.position - origin).normalized()
		GroundFx.bleed(enemy.position, enemy.ground_elevation + enemy.radius, direction, 10)
		enemy._hit_flash = 0.1
		enemy.queue_redraw()
	# L'onda d'urto ferma a metà, qualunque sia la durata dei frame.
	var fx := GroundFx.current
	fx.set_process(false)
	fx._waves[-1]["age"] = 0.15
	fx.queue_redraw()
	await _frames(2)
	await _save("%s_9_slam.png" % language)
	_end_game()


## Ingresso di una caverna nella parete di una montagna.
func _capture_cave(language: String) -> void:
	await _start_game(Vector2(0, -60), 1.0)
	_player.level = 5
	_hud_stats()
	var cave := _nearest("cave")
	var into: Vector2 = World.cell_center(World.cell_at(cave["position"])) - cave["position"]
	await _place_player(cave["position"] + into.normalized() * 110.0)
	_player.facing = -into.normalized()
	var hud: Hud = _game.get_node("HUD")
	hud.show_challenge(tr("CAVE_HINT"))
	var world: World = _game.get_node("World")
	await _frames(20)
	# Il suggerimento "Interact" sopra l'ingresso (il gioco qui è fermo).
	hud.show_interact(cave["position"] - Vector2(0, world.elevation_at(cave["position"]) + 96.0))
	await _frames(2)
	await _save("%s_11_cave.png" % language)
	# Mappa completa aperta lì: montagne, caverne, casse, mercanti.
	hud.hide_interact()
	hud._world_map.open()
	await _frames(20)
	await _save("%s_13_map.png" % language)
	hud._world_map.close()
	_end_game()


## Ultimo piano del sotterraneo: al buio con la torcia, davanti al boss.
func _capture_dungeon(language: String) -> void:
	await _start_game(Vector2(0, -40), 1.0)
	_player.level = 6
	_hud_stats()
	var cave := _nearest("cave")
	_game._cave = cave["position"]
	_game._cave_levels = 3
	await _game._go_to_depth(3, Vector2.INF)
	var world: World = _game.get_node("World")
	var arena := World.cell_center(world.dungeon.arena)
	await _place_player(arena + Vector2(-150, 140))
	_player.facing = (arena - _player.position).normalized()
	_player.torch_on = true
	_player._torch.enabled = true
	_player._torch.position = Vector2(0, -_player.ground_elevation + Player.RADIUS * 0.6)
	var boss: Enemy = _game._boss
	boss.position = arena
	boss._change_state(Enemy.State.WINDUP)
	boss._windup_time = 1.0
	boss._state_time = 0.6
	boss._attack_direction = (_player.position - arena).normalized()
	boss._facing = boss._attack_direction
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		enemy.queue_redraw()
	await _frames(20)
	await _save("%s_12_dungeon.png" % language)
	_end_game()


## Il punto d'interesse di quel tipo più vicino al giocatore.
func _nearest(type_id: String) -> Dictionary:
	var world: World = _game.get_node("World")
	var best := {}
	for point: Dictionary in world.points_of_interest(_player.position, 9000.0):
		if point["type"] == type_id and (best.is_empty() or _player.position.distance_to(point["position"]) < _player.position.distance_to(best["position"])):
			best = point
	return best


## Sposta il giocatore e mostra subito il terreno attorno. Con la fisica
## del giocatore ferma la telecamera va rimessa a posto a mano.
func _place_player(at: Vector2) -> void:
	_player.teleport(at)
	var camera: Camera2D = _player.get_node("Camera")
	camera.position_smoothing_enabled = false
	camera.reset_physics_interpolation()
	await _frames(2)
	camera.reset_smoothing()
	camera.force_update_scroll()
	(_game.get_node("World") as World).refresh_now()


## Mercante più vicino alla partenza nel mondo delle immagini.
func _nearest_merchant() -> Vector2:
	var world: World = _game.get_node("World")
	var best := Vector2.INF
	for x in range(-4, 5):
		for y in range(-4, 5):
			var site := world.merchant_near(Vector2(x, y) * 1000.0)
			if site != Vector2.INF and (best == Vector2.INF or site.length() < best.length()):
				best = site
	return best


func _capture_cover(language: String) -> void:
	await _start_game(Vector2(0, -60), 1.7)
	_game.get_node("HUD").visible = false
	_player.facing = Vector2(1, 0.15).normalized()
	_player._state = Player.State.PARRY
	_player._state_time = 0.05
	_enemy("warrior", Vector2(140, 25), Enemy.State.WINDUP, 0.75)
	_enemy("brute", Vector2(-160, 70), Enemy.State.STUNNED, 0.3).health = 40
	_enemy("scout", Vector2(-300, -120), Enemy.State.CHASE, 0.0)
	_enemy("summoner", Vector2(300, -110), Enemy.State.CHASE, 0.0)
	_enemy("scout", Vector2(250, 175), Enemy.State.CHASE, 0.0)

	var layer := CanvasLayer.new()
	_game.add_child(layer)
	var band := ColorRect.new()
	band.color = Color(0.07, 0.09, 0.06, 0.55)
	band.size = Vector2(2000, 300)
	layer.add_child(band)
	var width := get_viewport().get_visible_rect().size.x
	var title := _label("Gobelino", 150, Color(0.85, 0.75, 0.4), width, 30.0)
	title.add_theme_constant_override("outline_size", 18)
	title.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.03))
	layer.add_child(title)
	layer.add_child(_label(SUBTITLE[language], 44, Color(1, 1, 1, 0.85), width, 205.0))

	await _frames(6)
	var image := get_viewport().get_texture().get_image()
	image.resize(COVER_SIZE.x, COVER_SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(OUTPUT + "cover_%s.png" % language)
	_end_game()


func _start_game(camera_offset: Vector2, zoom: float) -> void:
	_game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	(_game.get_node("World") as World).seed_value = WORLD_SEED
	add_child(_game)
	# Si aspetta che il territorio sia pronto (schermata d'attesa chiusa).
	await get_tree().process_frame
	while _game.loading:
		await get_tree().process_frame
	_game.set_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	_player = _game.get_node("Entities/Player")
	(_game.get_node("DayNight") as DayNight).time = 0.2
	_player.set_physics_process(false)
	var camera: Camera2D = _player.get_node("Camera")
	# Per le foto la telecamera deve stare subito al suo posto, senza inseguire.
	camera.position_smoothing_enabled = false
	camera.offset = camera_offset
	camera.zoom = Vector2(zoom, zoom)


func _end_game() -> void:
	_game.queue_free()
	await _frames(2)


func _entities() -> Node2D:
	return _game.get_node("Entities")


func _hud_stats() -> void:
	var hud: Hud = _game.get_node("HUD")
	hud.set_health(_player.health, _player.max_health)
	hud.set_experience(_player.experience, _player.experience_needed(), _player.level)
	hud.set_kills(_player.level * 4 + 3)


## Nemico fermo in uno stato preciso, rivolto verso il giocatore.
func _enemy(type_id: String, at: Vector2, state: Enemy.State, state_time: float) -> Enemy:
	var enemy := Enemy.new()
	enemy.setup(type_id)
	enemy.player = _player
	enemy.position = at
	_entities().add_child(enemy)
	enemy._windup_time = 1.0
	enemy._change_state(state)
	enemy._state_time = state_time
	enemy._attack_direction = (_player.position - at).normalized()
	enemy._facing = enemy._attack_direction
	if World.current:
		enemy.ground_elevation = World.current.elevation_at(at)
	enemy.set_physics_process(false)
	enemy.queue_redraw()
	enemy._telegraph.queue_redraw()
	return enemy


func _label(text: String, size: int, color: Color, width: float, y: float) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, y)
	label.size = Vector2(width, size * 1.2)
	return label


func _save(file: String) -> void:
	await _frames(6)
	get_viewport().get_texture().get_image().save_png(OUTPUT + file)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
