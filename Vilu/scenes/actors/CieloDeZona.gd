extends Node

## Cambia el cielo mientras esta zona está cargada, y lo devuelve al salir.
##
## Para la cima del Isluga. El cielo del juego tiene la mitad inferior en tonos
## de arena, pensada para el desierto de Tarapacá, y ahí nunca se ve porque el
## terreno la tapa. Desde 300 metros y con el mundo abierto escondido —que es lo
## que hace `Game` al entrar a un interior— esa mitad queda a la vista como una
## franja café con un corte recto.
##
## NO se hace con un segundo WorldEnvironment: Godot usa uno solo por escena y
## dos en el árbol se pisan entre sí de forma impredecible. En vez de eso se le
## cambia el recurso al que ya existe y se restaura al descargar la zona.

## El entorno que se pone mientras esta zona esté cargada.
@export var entorno: Environment

var _mundo: WorldEnvironment = null
var _anterior: Environment = null


func _ready() -> void:
	if entorno == null:
		push_warning("CieloDeZona en %s: no se le puso ningún entorno" % name)
		return
	_mundo = _buscar(get_tree().root)
	if _mundo == null:
		push_warning("CieloDeZona en %s: no encuentro el WorldEnvironment" % name)
		return
	_anterior = _mundo.environment
	_mundo.environment = entorno


## Al descargar la zona se devuelve el cielo de antes. Sin esto, salir del
## volcán dejaría el mar puesto sobre el desierto.
func _exit_tree() -> void:
	if _mundo != null and is_instance_valid(_mundo):
		_mundo.environment = _anterior


func _buscar(n: Node) -> WorldEnvironment:
	if n is WorldEnvironment:
		return n as WorldEnvironment
	for c in n.get_children():
		var e := _buscar(c)
		if e != null:
			return e
	return null
