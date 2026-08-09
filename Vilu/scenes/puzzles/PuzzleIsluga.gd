extends Node3D

## Beat 4 — Prueba de Isluga. Dos partes:
##  1) "combo exacto": landear el combo completo (paso final) cerca del tótem.
##  2) "flecha sincronizada": acertar el TimedTarget durante su ventana activa.
## Al completar ambas, se abre el Gate (guardián de Isluga) y se entra al Beat 4,
## abriendo el paso al viaje del volcán.

signal solved

@export var required_combo_step := 2   # 3er golpe = combo completo (índices 0..2)
@export var totem_range := 3.5
@export var advance_to_beat := 4

var _combo_done := false
var _target_done := false
var _is_solved := false
var _player: Node = null

@onready var _totem: Node3D = get_node_or_null("ComboTotem")
@onready var _target: Node = get_node_or_null("TimedTarget")
@onready var _gate: Node = get_node_or_null("Gate")


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player and _player.has_signal("melee_hit"):
		_player.melee_hit.connect(_on_melee)
	if _target and _target.has_signal("hit_while_active"):
		_target.hit_while_active.connect(_on_target_hit)
	_banner("Prueba de Isluga — sella el combo en el tótem y sincroniza la flecha")


func _on_melee(step: int) -> void:
	if _combo_done or step < required_combo_step:
		return
	if _totem and is_instance_valid(_player):
		if _player.global_position.distance_to(_totem.global_position) <= totem_range:
			_mark_combo_done()


func _mark_combo_done() -> void:
	if _combo_done:
		return
	_combo_done = true
	_tint_totem_done()
	_banner("Combo sellado (1/2)")
	_check_solved()


func _on_target_hit() -> void:
	if _target_done:
		return
	_target_done = true
	_banner("Flecha sincronizada (2/2)")
	_check_solved()


func _check_solved() -> void:
	if not _is_solved and _combo_done and _target_done:
		_solve()


func _solve() -> void:
	_is_solved = true
	if _gate and is_instance_valid(_gate):
		_gate.queue_free()
	_banner("¡Prueba de Isluga superada! El paso al volcán se abre.", 3.0)
	if GameManager.get_beat() < advance_to_beat:
		GameManager.set_beat(advance_to_beat)
	solved.emit()


func _tint_totem_done() -> void:
	if _totem and _totem is CSGShape3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.2, 0.8, 0.3)
		_totem.material = m


func is_solved() -> bool:
	return _is_solved


func _banner(text: String, auto_clear := 0.0) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_banner"):
		hud.show_banner(text)
		if auto_clear > 0.0:
			get_tree().create_timer(auto_clear).timeout.connect(func() -> void:
				if is_instance_valid(hud) and hud.has_method("clear_banner"):
					hud.clear_banner())
