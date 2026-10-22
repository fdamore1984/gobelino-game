class_name Hud
extends CanvasLayer
## Interfaccia del livello di test: vita, livello ed esperienza, pozioni,
## scudo, nemici sconfitti, comandi, sfida del totem in corso, potenziamenti attivi (lista a destra),
## scelta del potenziamento salendo di livello (griglia con icone) e
## messaggio di fine partita.

## Il giocatore ha scelto un potenziamento (vedi Player.apply_upgrade).
signal upgrade_chosen(upgrade: String)

## Appena compare il pannello i pulsanti restano disattivati per un
## attimo, così chi sta premendo i tasti di attacco non sceglie per sbaglio.
const LEVEL_UP_INPUT_DELAY := 0.5
const POWER_UP_ICON_SIZE := 28.0
const CARD_ICON_SIZE := 64.0
const COLOR_POWER_UPS_TITLE := Color(1, 1, 1, 0.7)
## Per quanto resta il messaggio di fine sfida.
const CHALLENGE_FLASH_TIME := 3.5

## Nome di ogni potenziamento (chiave di traduzione), nell'ordine della griglia.
const UPGRADE_NAMES := {
	"combo": "UPGRADE_COMBO",
	"heavy": "UPGRADE_HEAVY",
	"dodge": "UPGRADE_DODGE",
	"jump": "UPGRADE_JUMP",
	"health": "UPGRADE_HEALTH",
	"potion": "UPGRADE_POTION",
	"shield": "UPGRADE_SHIELD",
	"run": "UPGRADE_RUN",
}

@onready var _health: Label = %Health
@onready var _level: Label = %Level
@onready var _experience: ProgressBar = %Experience
@onready var _experience_label: Label = %ExperienceLabel
@onready var _kills: Label = %Kills
@onready var _potions: Label = %Potions
@onready var _shield: Label = %Shield
@onready var _stats: Label = %Stats
@onready var _deck_hint: Label = %DeckHint
@onready var _power_ups: VBoxContainer = %PowerUps
@onready var _challenge: Label = %Challenge
@onready var _hint: Label = %Hint
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
	"potion": %UpgradePotion as Button,
	"shield": %UpgradeShield as Button,
	"run": %UpgradeRun as Button,
}

## Giocatore di cui mostrare pozioni e scudo, che cambiano di continuo.
var player: Player
## Etichette dei valori nelle schede dei potenziamenti.
var _card_values := {}
## Ultimo contenuto della lista dei potenziamenti attivi, per ricostruirla
## solo quando cambia.
var _power_ups_shown := []
## Tempo rimasto del messaggio di fine sfida: intanto gli altri testi della sfida aspettano.
var _challenge_flash := 0.0


func _ready() -> void:
	_hint.text = tr("HUD_HINT") + "\n" + tr("HUD_HINT_2")
	# Sui dispositivi touch i comandi sono già scritti sui pulsanti a schermo.
	_hint.visible = not Platform.use_touch_controls()
	_deck_hint.text = tr("DECK_HINT")
	_message.visible = false
	_challenge.visible = false
	_level_up.visible = false
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
	if player == null:
		return
	_potions.text = tr("HUD_POTIONS") % [player.potions, player.max_potions]
	if player.shield_active:
		_shield.text = tr("HUD_SHIELD_ACTIVE")
	elif player.shield_cooldown > 0.0:
		_shield.text = tr("HUD_SHIELD_COOLDOWN") % ceili(player.shield_cooldown)
	else:
		_shield.text = tr("HUD_SHIELD_READY")
	# Livelli delle abilità, che crescono con i potenziamenti.
	_stats.text = tr("HUD_STATS") % [
		player.max_combo_hits, player.max_heavy_chain, player.max_chained_dodges,
		player.max_jumps, roundi(100.0 * (1.0 + player.run_speed_bonus)),
	]
	_update_power_ups()


## Lista a destra: effetti temporanei (parata perfetta, scudo) e
## potenziamenti scelti, con quante volte sono stati presi.
func _update_power_ups() -> void:
	var rows := []
	if player.is_empowered():
		rows.append(["empowered", tr("POWERUP_EMPOWERED") % ceili(player.empowered_time())])
	if player.shield_active:
		rows.append(["bubble", tr("POWERUP_SHIELD_ACTIVE")])
	for upgrade: String in player.upgrades_taken:
		var name_key := "POWERUP_" + upgrade.to_upper()
		rows.append([upgrade, tr("POWERUP_UPGRADE") % [tr(name_key), _upgrade_value(upgrade), player.upgrades_taken[upgrade]]])
	if rows == _power_ups_shown:
		return
	_power_ups_shown = rows
	for child in _power_ups.get_children():
		child.queue_free()
	if rows.is_empty():
		return
	var title := Label.new()
	title.text = tr("POWERUPS_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", COLOR_POWER_UPS_TITLE)
	_power_ups.add_child(title)
	for row: Array in rows:
		var line := HBoxContainer.new()
		line.alignment = BoxContainer.ALIGNMENT_END
		var label := Label.new()
		label.text = row[1]
		label.add_theme_font_size_override("font_size", 17)
		label.add_theme_color_override("font_color", UpgradeIcon.color_of(row[0]).lerp(Color.WHITE, 0.5))
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		line.add_child(label)
		var icon := UpgradeIcon.new()
		icon.kind = row[0]
		icon.custom_minimum_size = Vector2(POWER_UP_ICON_SIZE, POWER_UP_ICON_SIZE)
		line.add_child(icon)
		_power_ups.add_child(line)


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
		"potion":
			return str(player.max_potions)
		"shield":
			return "%.1f s" % player.shield_cooldown_max
		"run":
			return "%d%%" % roundi(100.0 * (1.0 + player.run_speed_bonus))
	return ""


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
	if _level_up.visible and UiNav.handle(event, get_viewport(), _upgrade_buttons["combo"]) and is_inside_tree():
		get_viewport().set_input_as_handled()


func set_health(current: int, maximum: int) -> void:
	_health.text = tr("HUD_HEALTH") % [current, maximum]


func set_experience(current: int, needed: int, level: int) -> void:
	_level.text = tr("HUD_LEVEL") % level
	_experience.max_value = needed
	_experience.value = current
	_experience_label.text = tr("HUD_XP") % [current, needed]


func set_kills(count: int) -> void:
	_kills.text = tr("HUD_KILLS") % count


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
	_card_values["potion"].text = tr("UPGRADE_VALUE") % [player.max_potions, player.max_potions + 1]
	var cooldown_after := player.shield_cooldown_max * Player.SHIELD_COOLDOWN_UPGRADE
	_card_values["shield"].text = tr("UPGRADE_VALUE_SECONDS") % [player.shield_cooldown_max, cooldown_after]
	_card_values["jump"].text = tr("UPGRADE_VALUE") % [player.max_jumps, player.max_jumps + 1]
	var run_now := roundi(100.0 * (1.0 + player.run_speed_bonus))
	_card_values["run"].text = tr("UPGRADE_VALUE_PERCENT") % [run_now, run_now + roundi(100.0 * Player.RUN_SPEED_UPGRADE)]
	_level_up.visible = true
	for button: Button in _upgrade_buttons.values():
		button.disabled = true
	await get_tree().create_timer(LEVEL_UP_INPUT_DELAY, true).timeout
	if not is_inside_tree() or not _level_up.visible:
		return
	for button: Button in _upgrade_buttons.values():
		button.disabled = false
	_upgrade_buttons["combo"].grab_focus()


func _on_upgrade_pressed(upgrade: String) -> void:
	Sfx.play_ui("ui_confirm")
	_level_up.visible = false
	upgrade_chosen.emit(upgrade)
