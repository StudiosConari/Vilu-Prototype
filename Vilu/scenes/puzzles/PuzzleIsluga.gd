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

## Por debajo de esta altura se cuenta como caído al vacío.
##
## El suelo jugable del cráter empieza en y≈297 y el manto de nubes está en 290.
## Con el umbral acá abajo, caer a la lava te hunde en las nubes y te devuelve,
## en vez de dejarte atravesar hasta la cáscara del volcán.
@export var limite_de_caida := 285.0

var _solved := false


func _ready() -> void:
	# Cubo del piso 1 de cada uno -> ascensor del OTRO.
	_wire_elevator("EmiliaCube", "BenjaminVert")
	_wire_elevator("BenjaminCube", "EmiliaVert")
	_hint("Isluga (cooperativo): subí por TU plataforma. Activá tu obelisco con [E] para poner en marcha el ascensor del OTRO. Arriba los espera el guardián.")
	_spawn_guardian()


func _wire_elevator(cube_name: String, vert_name: String) -> void:
	# Por NOMBRE en todo el árbol, no por hijo directo.
	#
	# El nivel se reorganizó agrupando el cráter bajo un nodo `Crater`, y con
	# `get_node_or_null` los seis nodos del puzzle dejaron de encontrarse: los
	# obeliscos no quedaban cableados a los ascensores y `vert_active` siempre
	# devolvía false. Buscando en profundidad, mover cosas en el editor deja de
	# romper el cableado.
	var cube := find_child(cube_name, true, false)
	var vert := find_child(vert_name, true, false)
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
	var v := find_child(vert_name, true, false)
	return v != null and v.has_method("is_active") and v.is_active()


## Coloca al guardián donde diga el marcador `GuardianSpawn` de la escena.
##
## Antes la posición estaba escrita en el código, y se pudrió dos veces: primero
## al mudar el Isluga de World.tscn a su propia escena, después al agrupar el
## cráter bajo un nodo `Crater` y darle transform a la raíz. La última vez
## apareció 127 metros por debajo de la plataforma, o sea invisible.
##
## Con un marcador se arrastra en el editor y nadie tiene que recalcular nada.
func _spawn_guardian() -> void:
	var marca := find_child("GuardianSpawn", true, false) as Node3D
	if marca == null:
		push_warning("PuzzleIsluga: falta el marcador GuardianSpawn; el guardián no aparece")
		return
	var g := Node3D.new()
	g.set_script(GUARDIAN_SCR)
	add_child(g)
	g.global_transform = marca.global_transform


func _hint(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_hint"):
		hud.show_hint(text)
