extends Node
## Genera copertina e screenshot per la pagina itch.io (store/itch/), in
## italiano e in inglese, componendo scene di gioco reali. Va rilanciato a
## ogni modifica visibile del gioco. Serve una finestra (non --headless):
##
##   godot --path . --resolution 1280x720 res://tools/store_capture.tscn -- screenshots
##   godot --path . --resolution 1260x1000 res://tools/store_capture.tscn -- cover
##
## Non fa parte del gioco: la cartella tools/ è esclusa dagli export.

const OUTPUT := "res://store/itch/"
const LANGUAGES := ["en", "it"]
const SUBTITLE := {"it": "RPG d'azione · prototipo", "en": "Action RPG · prototype"}
const COVER_SIZE := Vector2i(630, 500)

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
	get_tree().quit()


func _capture_menu(language: String) -> void:
	var menu := (load("res://scenes/menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	# Nella pagina dello store non serve la riga diagnostica sul controller.
	var info: Label = menu.get_node("%Info")
	info.text = "\n".join(info.text.split("\n").slice(0, 2))
	await _save("%s_4_menu.png" % language)
	menu.queue_free()
	await _frames(2)


## Colpo potente in fondo alla combo, un bruto che carica, un evocatore
## che evoca, nemici attorno; scudo attivo.
func _capture_combat(language: String) -> void:
	_start_game(Vector2(0, 20), 1.15)
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
	_hud_stats()
	var warrior := _enemy("warrior", Vector2(95, -25), Enemy.State.CHASE, 0.0)
	warrior.health = 15
	warrior._hit_flash = 0.1
	FloatingText.spawn(_entities(), warrior.global_position + Vector2(0, 4), str(_player._attack_damage()), Color.WHITE)
	FloatingText.spawn(_entities(), _player.global_position, tr("FX_HEAVY"), Player.COLOR_HEAVY, 12.0)
	_enemy("brute", Vector2(-170, 90), Enemy.State.WINDUP, 0.6)
	var summoner := _enemy("summoner", Vector2(330, 150), Enemy.State.SUMMON, 0.8)
	summoner._summon_positions = [Vector2(-70, 0), Vector2(70, 0)]
	_enemy("scout", Vector2(-330, -140), Enemy.State.CHASE, 0.0)
	_enemy("scout", Vector2(250, -190), Enemy.State.DASH, 0.0)
	_enemy("warrior", Vector2(-420, 200), Enemy.State.CHASE, 0.0)
	await _save("%s_1_combat.png" % language)
	_end_game()


## Parata perfetta: aura del potenziamento e nemico stordito.
func _capture_parry(language: String) -> void:
	_start_game(Vector2(0, 0), 1.3)
	_player.level = 2
	_player.experience = 60
	_player.facing = Vector2.RIGHT
	_player._state = Player.State.PARRY
	_player._state_time = 0.05
	_player._empowered_time = Player.EMPOWER_TIME
	_hud_stats()
	_enemy("brute", Vector2(95, 10), Enemy.State.STUNNED, 0.4)
	FloatingText.spawn(_entities(), _player.global_position, tr("FX_PERFECT_PARRY"), Player.COLOR_SHIELD)
	FloatingText.spawn(_entities(), _player.global_position, tr("FX_EMPOWERED"), Player.COLOR_EMPOWERED, 28.0)
	_enemy("warrior", Vector2(-160, -60), Enemy.State.WINDUP, 0.5)
	_enemy("scout", Vector2(-260, 150), Enemy.State.CHASE, 0.0)
	_enemy("summoner", Vector2(330, -170), Enemy.State.CHASE, 0.0)
	await _save("%s_2_parry.png" % language)
	_end_game()


func _capture_level_up(language: String) -> void:
	_start_game(Vector2(0, 0), 1.0)
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


func _capture_cover(language: String) -> void:
	_start_game(Vector2(0, -60), 1.7)
	_game.get_node("HUD").visible = false
	_player.facing = Vector2(1, 0.15).normalized()
	_player._state = Player.State.PARRY
	_player._state_time = 0.05
	_enemy("warrior", Vector2(140, 25), Enemy.State.WINDUP, 0.75)
	_enemy("brute", Vector2(-160, 70), Enemy.State.STUNNED, 0.3).health = 40
	_enemy("scout", Vector2(-300, -120), Enemy.State.CHASE, 0.0)
	_enemy("summoner", Vector2(300, -110), Enemy.State.CHASE, 0.0)
	_enemy("scout", Vector2(250, 175), Enemy.State.CHASE, 0.0)
	FloatingText.spawn(_entities(), _player.global_position + Vector2(0, -20), tr("FX_PERFECT_PARRY"), Player.COLOR_SHIELD)

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
	add_child(_game)
	_game.set_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	_player = _game.get_node("Entities/Player")
	_player.set_physics_process(false)
	var camera: Camera2D = _player.get_node("Camera")
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
