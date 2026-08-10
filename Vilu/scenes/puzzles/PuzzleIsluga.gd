extends Node3D

## Beat 4 — Isluga: ascenso cooperativo en "C espejo". Cada personaje sube por SU
## plataforma (RoleMovingPlatform) al primer piso. Ahí, al golpear su cubo, activa
## el ASCENSOR VERTICAL del OTRO (que empieza a subir y bajar en el lado del otro).
## Con el ascensor activo cada uno sube al 2º piso; su cubo activa el ascensor del
## otro hacia la última plataforma. Cuando LOS DOS llegan arriba, superan el
## desafío (Beat 4).
##
## Cableo: el cubo de cada uno activa el ascensor del OTRO (dependencia cruzada).

signal solved

@export var advance_to_beat := 4

var _solved := false
var _on_top := 0


func _ready() -> void:
	# cubo de Emilia -> ascensor de Benjamín (y viceversa), en cada piso.
	_wire("EmiliaCube1", "BenjaminVert1")
	_wire("BenjaminCube1", "EmiliaVert1")
	_wire("EmiliaCube2", "BenjaminVert2")
	_wire("BenjaminCube2", "EmiliaVert2")
	var ft := get_node_or_null("FinalTrigger")
	if ft:
		ft.body_entered.connect(_on_top_enter)
		ft.body_exited.connect(_on_top_exit)
	_hint("Isluga (cooperativo): cada uno sube por SU plataforma. Golpeá tu cubo para ACTIVAR el ascensor del OTRO. Suban piso a piso ayudándose y júntense en la cima.")


func _wire(cube_name: String, vert_name: String) -> void:
	var cube := get_node_or_null(cube_name)
	var vert := get_node_or_null(vert_name)
	if cube and vert and cube.has_signal("activated") and vert.has_method("set_active"):
		cube.activated.connect(func() -> void:
			vert.set_active(true)
			_hint("¡Ascensor activado para tu compañero!"))


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


# --- Helper para tests ---
func vert_active(vert_name: String) -> bool:
	var v := get_node_or_null(vert_name)
	return v != null and v.has_method("is_active") and v.is_active()


func _hint(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_hint"):
		hud.show_hint(text)
