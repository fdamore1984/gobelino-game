class_name Hud
extends CanvasLayer
## Interfaccia del livello di test: vita, livello ed esperienza, pozioni,
## scudo, nemici sconfitti, comandi, scelta del potenziamento salendo di
## livello e messaggio di fine partita.

## Il giocatore ha scelto un potenziamento (vedi Player.apply_upgrade).
signal upgrade_chosen(upgrade: String)

## Appena compare il pannello i pulsanti restano disattivati per un
## attimo, così chi sta premendo i tasti di attacco non sceglie per sbaglio.
const LEVEL_UP_INPUT_DELAY := 0.5

@onready var _health: Label = %Health
@onready var _level: Label = %Level
@onready var _experience: ProgressBar = %Experience
@onready var _experience_label: Label = %ExperienceLabel
@onready var _kills: Label = %Kills
@onready var _potions: Label = %Potions
@onready var _shield: Label = %Shield
@onready var _stats: Label = %Stats
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


func _ready() -> void:
	_hint.text = tr("HUD_HINT") + "\n" + tr("HUD_HINT_2")
	# Sui dispositivi touch i comandi sono già scritti sui pulsanti a schermo.
	_hint.visible = not Platform.use_touch_controls()
	_message.visible = false
	_level_up.visible = false
	for upgrade: String in _upgrade_buttons:
		var button: Button = _upgrade_buttons[upgrade]
		button.pressed.connect(_on_upgrade_pressed.bind(upgrade))
		button.focus_entered.connect(Sfx.play_ui.bind("ui_move"))


func _process(_delta: float) -> void:
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


func show_message(text: String) -> void:
	_message.text = text
	_message.visible = true


func show_level_up(level: int, damage_before: int, damage_after: int) -> void:
	_level_up_title.text = tr("LEVELUP_TITLE") % level
	_level_up_damage.text = tr("LEVELUP_DAMAGE") % [damage_before, damage_after]
	_upgrade_buttons["combo"].text = tr("UPGRADE_COMBO") % [player.max_combo_hits, player.max_combo_hits + 1]
	_upgrade_buttons["heavy"].text = tr("UPGRADE_HEAVY") % [player.max_heavy_chain, player.max_heavy_chain + 1]
	_upgrade_buttons["dodge"].text = tr("UPGRADE_DODGE") % [player.max_chained_dodges, player.max_chained_dodges + 1]
	_upgrade_buttons["health"].text = tr("UPGRADE_HEALTH") % [player.max_health, player.max_health + 1]
	_upgrade_buttons["potion"].text = tr("UPGRADE_POTION") % [player.max_potions, player.max_potions + 1]
	var cooldown_after := player.shield_cooldown_max * Player.SHIELD_COOLDOWN_UPGRADE
	_upgrade_buttons["shield"].text = tr("UPGRADE_SHIELD") % [player.shield_cooldown_max, cooldown_after]
	_upgrade_buttons["jump"].text = tr("UPGRADE_JUMP") % [player.max_jumps, player.max_jumps + 1]
	var run_now := roundi(100.0 * (1.0 + player.run_speed_bonus))
	_upgrade_buttons["run"].text = tr("UPGRADE_RUN") % [run_now, run_now + roundi(100.0 * Player.RUN_SPEED_UPGRADE)]
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
