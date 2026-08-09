extends Node3D

## Arena de combate por oleadas (Beat 3). Al entrar el Player al Trigger,
## spawnea mineros corruptos (reusa Enemy.gd, recoloreados a rojo) en los
## markers de Spawns. Al despejar todas las oleadas libera la Barrier (abre la
## salida) y avanza el beat. Enemigos: EnemyNormal/EnemyBig existentes.

signal cleared

@export var enemy_a: PackedScene = preload("res://scenes/enemies/EnemyNormal.tscn")
@export var enemy_b: PackedScene = preload("res://scenes/enemies/EnemyBig.tscn")
@export var enemy_color: Color = Color(0.85, 0.15, 0.15)   # rojo minero por defecto
@export var waves: Array = [3, 4]   # cantidad de enemigos por oleada
@export var b_every := 3            # cada N enemigos, uno del tipo B
@export var auto_start := false
@export var advance_to_beat := 3

var _wave := 0
var _alive := 0
var _started := false
var _is_cleared := false
var _spawns: Array[Node3D] = []
var _enemies: Array = []

@onready var _trigger: Area3D = get_node_or_null("Trigger")
@onready var _spawns_root: Node = get_node_or_null("Spawns")
@onready var _barrier: Node = get_node_or_null("Barrier")


func _ready() -> void:
	if _spawns_root:
		for c in _spawns_root.get_children():
			if c is Node3D:
				_spawns.append(c)
	if _trigger:
		_trigger.body_entered.connect(_on_trigger)
	if auto_start:
		start()


func _on_trigger(body: Node3D) -> void:
	if body.is_in_group("player"):
		start()


func start() -> void:
	if _started:
		return
	_started = true
	_wave = 0
	_spawn_wave()


func _spawn_wave() -> void:
	_enemies.clear()
	var count: int = waves[_wave] if _wave < waves.size() else 0
	_alive = 0
	for i in count:
		var use_b := b_every > 0 and (i + 1) % b_every == 0
		var scene: PackedScene = enemy_b if use_b else enemy_a
		var e := scene.instantiate()
		e.base_color = enemy_color       # se lee en _ready (antes de add_child)
		e.died.connect(_on_enemy_died)
		add_child(e)
		e.global_position = _spawn_point(i)
		_enemies.append(e)
		_alive += 1
	_banner("Mineros corruptos — Oleada %d/%d" % [_wave + 1, waves.size()])


func _spawn_point(i: int) -> Vector3:
	if _spawns.is_empty():
		return global_position
	return _spawns[i % _spawns.size()].global_position


func _on_enemy_died(_pos: Vector3, _xp: int) -> void:
	_alive -= 1
	if _alive <= 0:
		_next_wave()


func _next_wave() -> void:
	_wave += 1
	if _wave < waves.size():
		_spawn_wave()
	else:
		_complete()


func _complete() -> void:
	if _is_cleared:
		return
	_is_cleared = true
	if _barrier and is_instance_valid(_barrier):
		_barrier.queue_free()
	_banner("¡Zona despejada!", 2.5)
	if GameManager.get_beat() < advance_to_beat:
		GameManager.set_beat(advance_to_beat)
	cleared.emit()


# --- Helpers para tests ---
func get_current_enemies() -> Array:
	return _enemies.duplicate()

func alive_count() -> int:
	return _alive

func is_cleared() -> bool:
	return _is_cleared


func _banner(text: String, auto_clear := 0.0) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_banner"):
		hud.show_banner(text)
		if auto_clear > 0.0:
			get_tree().create_timer(auto_clear).timeout.connect(func() -> void:
				if is_instance_valid(hud) and hud.has_method("clear_banner"):
					hud.clear_banner())
