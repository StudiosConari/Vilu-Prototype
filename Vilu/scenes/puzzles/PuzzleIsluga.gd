extends Node3D

## Beat 4 — Isluga: puzzle colaborativo en "C espejo".
## Cada personaje sube por SU plataforma (RoleMovingPlatform: la de Emilia solo se
## mueve con Emilia, la de Benjamín solo con Benjamín) a su repisa.
##  - Emilia: 4 cubos de distinta ALTURA en su repisa; se activan con 1/2/3/4
##    golpes (melee) según altura. Completarlos abre la salida de BENJAMÍN.
##  - Benjamín: 4 cubos FUERA de su repisa; se activan con 1/2/3/4 FLECHAS. Abren
##    la salida de EMILIA.
## Cada uno cruza SU salida hacia la cima central; cuando LOS DOS llegan, superan
## el desafío (Beat 4).
##
## (Primer pase de la mecánica; enemigos/palancas intermedias quedan para iterar.)

signal solved

@export var advance_to_beat := 4

var _solved := false
var _emilia_done := 0
var _benja_done := 0
var _emilia_total := 0
var _benja_total := 0
var _on_top := 0

@onready var _emilia_cubes: Node = get_node_or_null("EmiliaCubes")
@onready var _benja_cubes: Node = get_node_or_null("BenjaminCubes")
@onready var _emilia_exit: Node = get_node_or_null("EmiliaExit")
@onready var _benja_exit: Node = get_node_or_null("BenjaminExit")
@onready var _final_trigger: Area3D = get_node_or_null("FinalTrigger")


func _ready() -> void:
	if _emilia_cubes:
		for c in _emilia_cubes.get_children():
			if c.has_signal("activated"):
				c.activated.connect(_on_emilia_cube)
				_emilia_total += 1
	if _benja_cubes:
		for c in _benja_cubes.get_children():
			if c.has_signal("activated"):
				c.activated.connect(_on_benja_cube)
				_benja_total += 1
	if _final_trigger:
		_final_trigger.body_entered.connect(_on_top_enter)
		_final_trigger.body_exited.connect(_on_top_exit)
	_hint("Isluga (colaborativo): cada uno sube por SU plataforma. Emilia golpea sus 4 cubos (1/2/3/4 golpes según altura) para abrir la salida de Benjamín; Benjamín acierta con flechas sus 4 cubos (1/2/3/4) para abrir la de Emilia. Júntense arriba.")


func _on_emilia_cube() -> void:
	_emilia_done += 1
	if _emilia_done >= _emilia_total:
		_open(_benja_exit)
		_hint("¡Emilia completó sus cubos! Se abrió la salida de Benjamín.")


func _on_benja_cube() -> void:
	_benja_done += 1
	if _benja_done >= _benja_total:
		_open(_emilia_exit)
		_hint("¡Benjamín acertó sus cubos! Se abrió la salida de Emilia.")


func _open(door: Node) -> void:
	if door and is_instance_valid(door):
		door.queue_free()


func _on_top_enter(body: Node3D) -> void:
	if body.is_in_group("player"):
		_on_top += 1
		if _on_top >= 2:
			_solve()


func _on_top_exit(body: Node3D) -> void:
	if body.is_in_group("player"):
		_on_top = max(0, _on_top - 1)


func _solve() -> void:
	if _solved:
		return
	_solved = true
	_hint("¡Desafío de Isluga superado! El paso al norte se abre.")
	if GameManager.get_beat() < advance_to_beat:
		GameManager.set_beat(advance_to_beat)
	solved.emit()


func is_solved() -> bool:
	return _solved


# --- Helpers para tests ---
func emilia_progress() -> int:
	return _emilia_done

func benja_progress() -> int:
	return _benja_done


func _hint(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_hint"):
		hud.show_hint(text)
