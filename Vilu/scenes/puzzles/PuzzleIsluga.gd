extends Node3D

## Beat 4 — Isluga: ascenso cooperativo en "C espejo".
##  1) Cada uno sube por SU plataforma horizontal (RoleMovingPlatform) al piso 1.
##  2) En el piso 1 golpea su cubo -> ACTIVA el ASCENSOR VERTICAL del OTRO (que
##     empieza a subir y bajar en un hueco despejado). Con el ascensor activo cada
##     uno sube al piso final.
##  3) Piso final: los 4 CUBOS DE ALTURA (se activan con 1/2/3/4 golpes según
##     altura). Emilia los golpea (melee); Benjamín los suyos con flechas (fuera
##     de la plataforma). Cuando LOS DOS terminan sus 4 cubos, superan el desafío.

signal solved

@export var advance_to_beat := 4

var _solved := false
var _emilia_done := 0
var _benja_done := 0
var _emilia_total := 0
var _benja_total := 0


func _ready() -> void:
	# Cubo del piso 1 de cada uno -> ascensor del OTRO.
	_wire_elevator("EmiliaCube", "BenjaminVert")
	_wire_elevator("BenjaminCube", "EmiliaVert")
	# 4 cubos de altura en el piso final de cada uno.
	_emilia_total = _wire_cubes("EmiliaTopCubes", _on_emilia_top)
	_benja_total = _wire_cubes("BenjaminTopCubes", _on_benja_top)
	_hint("Isluga (cooperativo): subí por TU plataforma. Golpeá tu cubo para ACTIVAR el ascensor del OTRO. Arriba, cada uno abre sus 4 cubos de altura (1/2/3/4 golpes). Cuando los dos terminen, listo.")


func _wire_elevator(cube_name: String, vert_name: String) -> void:
	var cube := get_node_or_null(cube_name)
	var vert := get_node_or_null(vert_name)
	if cube and vert and cube.has_signal("activated") and vert.has_method("set_active"):
		cube.activated.connect(func() -> void:
			vert.set_active(true)
			_hint("¡Ascensor activado para tu compañero!"))


func _wire_cubes(container_name: String, cb: Callable) -> int:
	var n := get_node_or_null(container_name)
	var total := 0
	if n:
		for c in n.get_children():
			if c.has_signal("activated"):
				c.activated.connect(cb)
				total += 1
	return total


func _on_emilia_top() -> void:
	_emilia_done += 1
	_check()


func _on_benja_top() -> void:
	_benja_done += 1
	_check()


func _check() -> void:
	if _solved:
		return
	if _emilia_total > 0 and _benja_total > 0 and _emilia_done >= _emilia_total and _benja_done >= _benja_total:
		_solve()


func _solve() -> void:
	_solved = true
	_hint("¡Desafío de Isluga superado! El paso al norte se abre.")
	if GameManager.get_beat() < advance_to_beat:
		GameManager.set_beat(advance_to_beat)
	solved.emit()


func is_solved() -> bool:
	return _solved


# --- Helpers para tests ---
func vert_active(vert_name: String) -> bool:
	var v := get_node_or_null(vert_name)
	return v != null and v.has_method("is_active") and v.is_active()

func emilia_progress() -> int:
	return _emilia_done

func benja_progress() -> int:
	return _benja_done


func _hint(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_hint"):
		hud.show_hint(text)
