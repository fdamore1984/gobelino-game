class_name Hud
extends CanvasLayer
## Interfaccia del livello di test: pannello di stato in alto a sinistra
## (HudStatus), ciclo del giorno accanto alla minimappa (DayClock), bordi
## rossi con poca vita (LowHealthVignette), barra delle azioni in basso a sinistra (HudActions), comandi, sfida del totem in corso, potenziamenti attivi (riga di icone in basso a destra),
## scelta del potenziamento salendo di livello (tre schede con icone, prese
## a caso) e messaggio di fine partita.

## Il giocatore ha scelto un potenziamento (vedi Player.apply_upgrade).
signal upgrade_chosen(upgrade: String)
## Il suggerimento "Interact" è stato toccato (o cliccato).
signal interact_pressed

## Appena compare il pannello i pulsanti restano disattivati per un
## attimo, così chi sta premendo i tasti di attacco non sceglie per sbaglio.
const LEVEL_UP_INPUT_DELAY := 0.5
const POWER_UP_ICON_SIZE := 28.0
const CARD_ICON_SIZE := 64.0
const POWER_UPS_FONT_SIZE := 14
const POWER_UPS_MARGIN := 16.0
## Con i controlli touch la riga sta sotto la minimappa.
const POWER_UPS_TOUCH_TOP := 234.0
const COLOR_POWER_UPS_PANEL := Color(0.05, 0.07, 0.05, 0.8)
## Per quanto resta il messaggio di fine sfida.
const CHALLENGE_FLASH_TIME := 3.5
## A ogni livello si sceglie tra questi potenziamenti, presi a caso; ogni
## potenziamento "choice" ne aggiunge uno dal livello successivo. Le schede
## stanno su righe di al massimo UPGRADE_COLUMNS.
const UPGRADE_CHOICES := 3
const UPGRADE_COLUMNS := 5

## Nome di ogni potenziamento (chiave di traduzione), nell'ordine della griglia.
const UPGRADE_NAMES := {
	"combo": "UPGRADE_COMBO",
	"heavy": "UPGRADE_HEAVY",
	"dodge": "UPGRADE_DODGE",
	"jump": "UPGRADE_JUMP",
	"health": "UPGRADE_HEALTH",
	"shield": "UPGRADE_SHIELD",
	"run": "UPGRADE_RUN",
	"mana": "UPGRADE_MANA",
	"spell": "UPGRADE_SPELL",
	"stamina": "UPGRADE_STAMINA",
	"potion_slots": "UPGRADE_POTION_SLOTS",
	"potion_heal": "UPGRADE_POTION_HEAL",
	"mana_restore": "UPGRADE_MANA_RESTORE",
	"choice": "UPGRADE_CHOICE",
}

@onready var _deck_hint: Label = %DeckHint
@onready var _power_ups: HBoxContainer = %PowerUps
@onready var _challenge: Label = %Challenge
var _inventory_panel := InventoryPanel.new()
var _shop_panel := ShopPanel.new()
var _status := HudStatus.new()
var _actions := HudActions.new()
var _boss_bar := BossBar.new()
var _loading := LoadingOverlay.new()
var _clock := DayClock.new()
var _vignette := LowHealthVignette.new()
var _interact := InteractPrompt.new()
var _world_map := WorldMap.new()
## Menù di pausa: Game si collega ai suoi segnali (salva, esci).
var pause_menu := PauseMenu.new()
@onready var _message: Label = %Message
@onready var _level_up: Control = %LevelUp
@onready var _level_up_title: Label = %LevelUpTitle
@onready var _level_up_damage: Label = %LevelUpDamage
@onready var _upgrade_buttons := {
	"combo": %UpgradeCombo as Button,
	"heavy": %UpgradeHeavy as Button,
	"dodge": %UpgradeDodge as Button,
	"jump": %UpgradeJump as Button,
	"health": %UpgradeHealth as Button,
	"shield": %UpgradeShield as Button,
	"run": %UpgradeRun as Button,
	"mana": %UpgradeMana as Button,
	"spell": %UpgradeSpell as Button,
	"stamina": %UpgradeStamina as Button,
	"potion_slots": %UpgradePotionSlots as Button,
	"potion_heal": %UpgradePotionHeal as Button,
	"mana_restore": %UpgradeManaRestore as Button,
	"choice": %UpgradeChoice as Button,
}
## Potenziamenti proposti in questo passaggio di livello.
var _offered: Array[String] = []

## Giocatore di cui mostrare pozioni e scudo, che cambiano di continuo.
var player: Player
## Ciclo del giorno, per l'indicatore accanto alla minimappa.
var day_night: DayNight:
	set(value):
		day_night = value
		_clock.day_night = value
## Etichette dei valori nelle schede dei potenziamenti.
var _card_values := {}
## Ultimo contenuto della lista dei potenziamenti attivi, per ricostruirla
## solo quando cambia.
var _power_ups_shown := []
## Pannello scuro dietro la lista dei potenziamenti, perché si legga su ogni terreno.
var _power_ups_panel := PanelContainer.new()
var _power_ups_preset := -1
## Tempo rimasto del messaggio di fine sfida: intanto gli altri testi della sfida aspettano.
var _challenge_flash := 0.0


func _ready() -> void:
	_deck_hint.text = tr("DECK_HINT")
	_message.visible = false
	_challenge.visible = false
	add_child(_inventory_panel)
	add_child(_world_map)
	add_child(_shop_panel)
	add_child(pause_menu)
	add_child(_loading)
	add_child(_boss_bar)
	move_child(_boss_bar, 0)
	add_child(_clock)
	move_child(_clock, 0)
	add_child(_vignette)
	# Il suggerimento "Interact" sta sopra il gioco, sotto i pannelli.
	add_child(_interact)
	move_child(_interact, 1)
	_interact.activated.connect(interact_pressed.emit)
	# Pannelli sotto tutto il resto (potenziamenti, inventario, messaggi).
	add_child(_status)
	move_child(_status, 0)
	_build_power_ups_panel()
	add_child(_actions)
	move_child(_actions, 1)
	# Vita bassa e modalità focus: il primo figlio di tutti, così legge lo
	# schermo col solo mondo disegnato e l'interfaccia resta sopra, intatta.
	move_child(_vignette, 0)
	_actions.visible = not Platform.use_touch_controls()
	_level_up.visible = false
	(_upgrade_buttons["combo"].get_parent() as GridContainer).columns = UPGRADE_CHOICES
	for upgrade: String in _upgrade_buttons:
		var button: Button = _upgrade_buttons[upgrade]
		button.pressed.connect(_on_upgrade_pressed.bind(upgrade))
		button.focus_entered.connect(Sfx.play_ui.bind("ui_move"))
		_build_card(button, upgrade)


func _process(delta: float) -> void:
	if _challenge_flash > 0.0:
		_challenge_flash -= delta
		if _challenge_flash <= 0.0:
			_challenge.visible = false
	# Sparisce appena il gioco vede un controller (per esempio dopo aver
	# tenuto premuto Menu sullo Steam Deck).
	_deck_hint.visible = Platform.needs_deck_controller_hint()
	_actions.visible = not Platform.use_touch_controls()
	if player == null:
		return
	_inventory_panel.player = player
	_world_map.player = player
	_shop_panel.player = player
	_status.player = player
	_actions.player = player
	_vignette.player = player
	_update_power_ups()


## Riga compatta in basso a destra: un'icona per ogni effetto temporaneo
## (parata perfetta con i secondi rimasti, scudo, torcia accesa) e per ogni
## potenziamento scelto, con quante volte è stato preso.
func _update_power_ups() -> void:
	var rows := []
	if player.is_empowered():
		rows.append(["empowered", tr("POWERUP_EMPOWERED") % ceili(player.empowered_time())])
	if player.shield_active:
		rows.append(["bubble", ""])
	if player.torch_on:
		rows.append(["torch", ""])
	for upgrade: String in player.upgrades_taken:
		# I potenziamenti che non esistono più (per esempio +1 pozione) non si mostrano.
		if not UPGRADE_NAMES.has(upgrade):
			continue
		rows.append([upgrade, tr("POWERUP_UPGRADE") % player.upgrades_taken[upgrade]])
	_place_power_ups()
	if rows == _power_ups_shown:
		return
	_power_ups_shown = rows
	# Tolte subito, così la misura del pannello conta solo le icone nuove.
	for child in _power_ups.get_children():
		_power_ups.remove_child(child)
		child.queue_free()
	_power_ups_panel.visible = not rows.is_empty()
	for row: Array in rows:
		var tile := VBoxContainer.new()
		tile.add_theme_constant_override("separation", 0)
		var icon := UpgradeIcon.new()
		icon.kind = row[0]
		icon.custom_minimum_size = Vector2(POWER_UP_ICON_SIZE, POWER_UP_ICON_SIZE)
		tile.add_child(icon)
		var label := Label.new()
		label.text = row[1]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", POWER_UPS_FONT_SIZE)
		label.add_theme_color_override("font_color", UpgradeIcon.color_of(row[0]).lerp(Color.WHITE, 0.65))
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		tile.add_child(label)
		_power_ups.add_child(tile)
	_fit_power_ups.call_deferred()


## In basso a destra; con i controlli touch lì ci sono i pulsanti, quindi
## sotto la minimappa.
func _place_power_ups() -> void:
	var touch := Platform.use_touch_controls()
	var preset := Control.PRESET_TOP_RIGHT if touch else Control.PRESET_BOTTOM_RIGHT
	if _power_ups_preset == preset:
		return
	_power_ups_preset = preset
	_power_ups_panel.set_anchors_preset(preset)
	_power_ups_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_power_ups_panel.grow_vertical = Control.GROW_DIRECTION_END if touch else Control.GROW_DIRECTION_BEGIN
	_fit_power_ups()


## Il bordo destro (e quello in basso, o in alto con il touch) resta fermo:
## con più icone il pannello si allarga verso sinistra, con meno si stringe.
func _fit_power_ups() -> void:
	var touch := _power_ups_preset == Control.PRESET_TOP_RIGHT
	var needed := _power_ups_panel.get_combined_minimum_size()
	_power_ups_panel.offset_right = -POWER_UPS_MARGIN
	_power_ups_panel.offset_left = -POWER_UPS_MARGIN - needed.x
	if touch:
		_power_ups_panel.offset_top = POWER_UPS_TOUCH_TOP
		_power_ups_panel.offset_bottom = POWER_UPS_TOUCH_TOP + needed.y
	else:
		_power_ups_panel.offset_bottom = -POWER_UPS_MARGIN
		_power_ups_panel.offset_top = -POWER_UPS_MARGIN - needed.y


## Mette la riga dei potenziamenti attivi su un pannello scuro, perché si
## legga su ogni terreno.
func _build_power_ups_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_POWER_UPS_PANEL
	style.border_color = Color(1, 1, 1, 0.14)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(6)
	_power_ups_panel.add_theme_stylebox_override("panel", style)
	_power_ups_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_ups_panel.visible = false
	add_child(_power_ups_panel)
	move_child(_power_ups_panel, _power_ups.get_index())
	_power_ups.reparent(_power_ups_panel, false)
	_place_power_ups()


## Valore attuale dell'abilità migliorata da un potenziamento.
func _upgrade_value(upgrade: String) -> String:
	match upgrade:
		"combo":
			return str(player.max_combo_hits)
		"heavy":
			return str(player.max_heavy_chain)
		"dodge":
			return str(player.max_chained_dodges)
		"jump":
			return str(player.max_jumps)
		"health":
			return str(player.max_health)
		"shield":
			return "%.1f s" % player.shield_cooldown_max
		"run":
			return "%d%%" % roundi(100.0 * (1.0 + player.run_speed_bonus))
		"mana":
			return str(roundi(player.max_mana))
		"spell":
			return str(player.spell_damage())
		"stamina":
			return str(roundi(player.max_stamina))
		"potion_slots":
			return str(player.potion_capacity())
		"potion_heal":
			return str(player.potion_heal())
		"mana_restore":
			return str(roundi(player.mana_potion_restore()))
		"choice":
			return str(upgrade_choices())
	return ""


## Schede proposte a ogni passaggio di livello.
func upgrade_choices() -> int:
	return mini(UPGRADE_CHOICES + int(player.upgrades_taken.get("choice", 0)), UPGRADE_NAMES.size())


## Scheda di un potenziamento: icona, nome e valore prima → dopo.
func _build_card(button: Button, upgrade: String) -> void:
	button.text = ""
	var color := UpgradeIcon.color_of(upgrade)
	for style_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.1, 0.08, 0.9)
		style.set_corner_radius_all(10)
		style.set_border_width_all(2)
		style.border_color = Color(color, 0.25)
		if style_name in ["hover", "focus"]:
			style.bg_color = Color(0.14, 0.17, 0.13, 0.95)
			style.border_color = color
			style.set_border_width_all(4)
		button.add_theme_stylebox_override(style_name, style)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	var icon := UpgradeIcon.new()
	icon.kind = upgrade
	icon.custom_minimum_size = Vector2(CARD_ICON_SIZE, CARD_ICON_SIZE)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var name_label := Label.new()
	name_label.text = UPGRADE_NAMES[upgrade]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	var value := Label.new()
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 18)
	value.add_theme_color_override("font_color", UpgradeIcon.color_of(upgrade))
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(value)
	_card_values[upgrade] = value
	button.add_child(box)


func _unhandled_input(event: InputEvent) -> void:
	# Inventario: si apre durante il gioco (non in pausa né da morti).
	if event.is_action_pressed("inventory") and not get_tree().paused and player and not player.is_dead() \
			and not _inventory_panel.is_open():
		_inventory_panel.open()
		get_viewport().set_input_as_handled()
		return
	# Mappa completa: come l'inventario.
	if event.is_action_pressed("map") and not get_tree().paused and player and not player.is_dead() \
			and not _world_map.is_open():
		_world_map.open()
		get_viewport().set_input_as_handled()
		return
	if _level_up.visible and not _offered.is_empty() and UiNav.handle(event, get_viewport(), _upgrade_buttons[_offered[0]]) and is_inside_tree():
		get_viewport().set_input_as_handled()


## Vita ed esperienza il pannello di stato le legge dal giocatore (anche la
## soglia del livello, che segue la curva di Player.experience_for): qui
## basta ridisegnarlo subito.
func set_health(_current: int, _maximum: int) -> void:
	_status.queue_redraw()


func set_experience(_current: int, _needed: int, _level: int) -> void:
	_status.queue_redraw()


func set_kills(count: int) -> void:
	_status.kills = count


## Schermata d'attesa mentre si genera il territorio.
func show_loading(text: String, progress: float) -> void:
	_loading.show_progress(text, progress)


func hide_loading() -> void:
	_loading.visible = false


## Suggerimento "Interact" sopra il punto del mondo dato.
func show_interact(world_point: Vector2) -> void:
	_interact.show_at(world_point)


func hide_interact() -> void:
	_interact.visible = false


## Barra della vita del boss (null per toglierla).
func show_boss(boss: Enemy) -> void:
	_boss_bar.boss = boss


func is_menu_open() -> bool:
	return pause_menu.is_open() or _inventory_panel.is_open() or _shop_panel.is_open() or _world_map.is_open()


## Apre il negozio del mercante in quella posizione.
func open_shop(merchant: Vector2) -> void:
	hide_challenge()
	_shop_panel.open(merchant)


## Testo della sfida del totem: suggerimento, tempo e nemici rimasti.
func show_challenge(text: String) -> void:
	if _challenge_flash > 0.0:
		return
	_challenge.text = text
	_challenge.visible = true


func hide_challenge() -> void:
	if _challenge_flash <= 0.0:
		_challenge.visible = false


## Messaggio che resta qualche secondo (per esempio a sfida superata).
func flash_challenge(text: String) -> void:
	_challenge.text = text
	_challenge.visible = true
	_challenge_flash = CHALLENGE_FLASH_TIME


func show_message(text: String) -> void:
	_message.text = text
	_message.visible = true


func show_level_up(level: int, damage_before: int, damage_after: int) -> void:
	_level_up_title.text = tr("LEVELUP_TITLE") % level
	_level_up_damage.text = tr("LEVELUP_DAMAGE") % [damage_before, damage_after]
	_card_values["combo"].text = tr("UPGRADE_VALUE") % [player.max_combo_hits, player.max_combo_hits + 1]
	_card_values["heavy"].text = tr("UPGRADE_VALUE") % [player.max_heavy_chain, player.max_heavy_chain + 1]
	_card_values["dodge"].text = tr("UPGRADE_VALUE") % [player.max_chained_dodges, player.max_chained_dodges + 1]
	_card_values["health"].text = tr("UPGRADE_VALUE") % [player.max_health, player.max_health + 1]
	var cooldown_after := player.shield_cooldown_max * Player.SHIELD_COOLDOWN_UPGRADE
	_card_values["shield"].text = tr("UPGRADE_VALUE_SECONDS") % [player.shield_cooldown_max, cooldown_after]
	_card_values["jump"].text = tr("UPGRADE_VALUE") % [player.max_jumps, player.max_jumps + 1]
	var run_now := roundi(100.0 * (1.0 + player.run_speed_bonus))
	_card_values["run"].text = tr("UPGRADE_VALUE_PERCENT") % [run_now, run_now + roundi(100.0 * Player.RUN_SPEED_UPGRADE)]
	_card_values["mana"].text = tr("UPGRADE_VALUE") % [roundi(player.max_mana), roundi(player.max_mana + Player.MANA_UPGRADE)]
	var spell_bonus := player.spell_bonus + player.inventory.bonus("spell")
	_card_values["spell"].text = tr("UPGRADE_VALUE") % [player.spell_damage(), roundi(player.spell_damage() * (1.0 + spell_bonus + Player.SPELL_UPGRADE) / (1.0 + spell_bonus))]
	_card_values["stamina"].text = tr("UPGRADE_VALUE") % [roundi(player.max_stamina), roundi(player.max_stamina + Player.MAX_STAMINA * Player.STAMINA_UPGRADE)]
	_card_values["potion_slots"].text = tr("UPGRADE_VALUE") % [player.potion_capacity(), player.potion_capacity() + 1]
	_card_values["potion_heal"].text = tr("UPGRADE_VALUE") % [player.potion_heal(), player.potion_heal() + Player.POTION_HEAL_UPGRADE]
	_card_values["mana_restore"].text = tr("UPGRADE_VALUE") % [roundi(player.mana_potion_restore()), roundi(player.mana_potion_restore() + Player.MANA_POTION_RESTORE * Player.MANA_RESTORE_UPGRADE)]
	_card_values["choice"].text = tr("UPGRADE_VALUE") % [upgrade_choices(), mini(upgrade_choices() + 1, UPGRADE_NAMES.size())]
	# Solo alcuni potenziamenti, presi a caso, nell'ordine della griglia.
	var choices := upgrade_choices()
	var picks: Array = _upgrade_buttons.keys()
	# Con tutte le schede già proposte, "una scheda in più" non serve più.
	if choices >= UPGRADE_NAMES.size() - 1:
		picks.erase("choice")
	picks.shuffle()
	picks = picks.slice(0, choices)
	(_upgrade_buttons["combo"].get_parent() as GridContainer).columns = mini(picks.size(), UPGRADE_COLUMNS)
	_offered.clear()
	for upgrade: String in _upgrade_buttons:
		_upgrade_buttons[upgrade].visible = upgrade in picks
		if upgrade in picks:
			_offered.append(upgrade)
	_level_up.visible = true
	for button: Button in _upgrade_buttons.values():
		button.disabled = true
	await get_tree().create_timer(LEVEL_UP_INPUT_DELAY, true).timeout
	if not is_inside_tree() or not _level_up.visible:
		return
	for button: Button in _upgrade_buttons.values():
		button.disabled = false
	_upgrade_buttons[_offered[0]].grab_focus()


func _on_upgrade_pressed(upgrade: String) -> void:
	Sfx.play_ui("ui_confirm")
	_level_up.visible = false
	upgrade_chosen.emit(upgrade)
