@tool
extends Marker3D

## Marcador que MUESTRA en el editor lo que va a aparecer ahí en el juego.
##
## Los puntos de aparición son Marker3D: en el editor se ven como una crucecita,
## y colocar a ojo un guardián de cuatro metros con una crucecita es adivinar.
## Este marcador instancia el modelo sólo para mirarlo.
##
## Lo previsualizado NO existe en el juego: `Engine.is_editor_hint()` corta el
## montaje, y de todas formas se crea sin `owner`, así que no se guarda dentro
## del .tscn. Es el mismo trato que WorldRoot le da a las siluetas de zona.

const ENCAJAR := preload("res://scenes/core/EncajarModelo.gd")

## El modelo que se va a ver acá.
@export var modelo: PackedScene:
	set(v):
		modelo = v
		_rehacer()

## Alto en metros al que ajustarlo. En 0 se deja el tamaño del archivo.
@export var altura := 0.0:
	set(v):
		altura = v
		_rehacer()

var _vista: Node3D = null


func _ready() -> void:
	if Engine.is_editor_hint():
		_rehacer()


func _rehacer() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _vista != null and is_instance_valid(_vista):
		_vista.queue_free()
		_vista = null
	if modelo == null:
		return
	_vista = modelo.instantiate()
	add_child(_vista)
	# Sin owner: el editor lo dibuja pero no lo escribe en la escena.
	_vista.owner = null
	if altura > 0.0:
		ENCAJAR.encajar(_vista, altura)
