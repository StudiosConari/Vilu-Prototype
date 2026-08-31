extends Node3D

## Beat 4 — Isluga: ascenso cooperativo en "C espejo".
##  1) Cada uno sube por SU plataforma horizontal (RoleMovingPlatform) al piso 1.
##  2) En el piso 1 golpea su cubo -> ACTIVA el ASCENSOR VERTICAL del OTRO (que
##     empieza a subir y bajar en un hueco despejado). Con el ascensor activo cada
##     uno sube al piso final.
##  3) Arriba está el guardián: hablar con él supera el desafío y abre el camino
##     de salida del cráter.
##
## Antes el remate eran cuatro CUBOS DE ALTURA por personaje, que se golpeaban
## una cantidad exacta de veces. Ese piso se quitó del nivel, pero la condición
## de superado había quedado atada a él: `_check` exigía que los contenedores
## tuvieran cubos y, al no existir, el desafío no se podía superar NUNCA y el
## beat 4 no avanzaba. Ahora lo cierra el guardián.

const GUARDIAN_SCR := preload("res://scenes/actors/GuardianIsluga.gd")

signal solved

@export var advance_to_beat := 4

var _solved := false


func _ready() -> void:
	# Cubo del piso 1 de cada uno -> ascensor del OTRO.
	_wire_elevator("EmiliaCube", "BenjaminVert")
	_wire_elevator("BenjaminCube", "EmiliaVert")
	_hint("Isluga (cooperativo): subí por TU plataforma. Activá tu obelisco con [E] para poner en marcha el ascensor del OTRO. Arriba los espera el guardián.")
	_spawn_guardian()


func _wire_elevator(cube_name: String, vert_name: String) -> void:
	var cube := get_node_or_null(cube_name)
	var vert := get_node_or_null(vert_name)
	if cube and vert and cube.has_signal("activated") and vert.has_method("set_active"):
		cube.activated.connect(func() -> void:
			vert.set_active(true)
			_hint("¡Ascensor activado para tu compañero!"))


## Lo llama el guardián al terminar la charla. Repetirla no hace nada.
func superar() -> void:
	if _solved:
		return
	_solve()


func _solve() -> void:
	_solved = true
	_hint("¡Desafío de Isluga superado! El paso al norte se abre.")
	if GameManager.get_beat() < advance_to_beat:
		GameManager.set_beat(advance_to_beat)
	GameManager.conceder("isluga")
	solved.emit()


func is_solved() -> bool:
	return _solved


# --- Helpers para tests ---
func vert_active(vert_name: String) -> bool:
	var v := get_node_or_null(vert_name)
	return v != null and v.has_method("is_active") and v.is_active()


func _spawn_guardian() -> void:
	var g := Node3D.new()
	g.set_script(GUARDIAN_SCR)
	# Donde estaba el modelo colocado a mano en la escena. La y coincide con la
	# de los props vecinos, que es el suelo real de la plataforma.
	# En coordenadas de MUNDO: este guion vive ahora en el Node3D Isluga de
	# World.tscn, que está en el origen. Antes iba en local de la zona, que se
	# instanciaba desplazada a (140, 0, -140).
	g.position = Vector3(139.669, 12.054, -157.409)
	add_child(g)


func _hint(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_hint"):
		hud.show_hint(text)
