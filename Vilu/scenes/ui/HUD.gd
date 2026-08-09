extends CanvasLayer

## HUD mínimo del núcleo jugable: barra de vida, indicador de habilidades
## activas (lee GameManager) y prompt de interacción (oculto por defecto).
## Sin arte: Labels y ProgressBar. El HUD real/estilizado llega con el arte.

@onready var _hp_label: Label = $Stats/HPLabel
@onready var _hp: ProgressBar = $Stats/HP
@onready var _abilities: Label = $Stats/Abilities
@onready var _debug: Label = $Stats/Debug
@onready var _prompt: Label = $Prompt
@onready var _banner: Label = $Banner


func _ready() -> void:
	GameManager.ability_unlocked.connect(func(_a: String) -> void: _refresh_abilities())
	GameManager.beat_changed.connect(func(_i: int) -> void: _refresh_debug())
	_refresh_abilities()
	_refresh_debug()
	hide_prompt()
	clear_banner()


var _bound: Node = null


## Conecta el HUD al personaje activo (rebindable en cada swap, sin duplicar).
func bind_player(player: Node) -> void:
	if _bound and is_instance_valid(_bound) and _bound.health_changed.is_connected(_on_health):
		_bound.health_changed.disconnect(_on_health)
	_bound = player
	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_health)
		_on_health(player.health, player.max_health)


func _on_health(current: int, maximum: int) -> void:
	_hp.max_value = maximum
	_hp.value = current
	_hp_label.text = "Vida %d/%d" % [current, maximum]


func _refresh_abilities() -> void:
	_abilities.text = "Arco %s   Alas %s   Guanaco %s" % [
		_tick(GameManager.has_ability("bow")),
		_tick(GameManager.has_ability("wings")),
		_tick(GameManager.has_ability("guanaco")),
	]


func _tick(v: bool) -> String:
	return "✓" if v else "✗"


func _refresh_debug() -> void:
	_debug.text = "Beat %d/%d · %s" % [
		GameManager.get_beat() + 1,
		GameManager.BEAT_COUNT,
		TravelManager.current_region,
	]


func show_prompt(text: String) -> void:
	_prompt.text = text
	_prompt.visible = true


func hide_prompt() -> void:
	_prompt.visible = false


func show_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = true


func clear_banner() -> void:
	_banner.visible = false
