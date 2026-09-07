extends Area3D

## Cubo-interruptor que se activa al recibir una FLECHA (grupo "arrow"). Emite
## 'activated' una vez. Detecta la flecha (un Area3D en capa 1) vía area_entered.
## La dificultad la pone una muralla móvil (MovingWall) que lo tapa: hay que
## calcular el disparo.

signal activated

## A qué misión pertenece, para que la guía le ponga marcador.
##
## Vacío = sin marcador. Puesto, se señala MIENTRAS siga sin activar y se apaga
## al recibir la flecha. Acá importa más que en ningún otro sitio: el cubo está
## TAPADO por una muralla móvil a propósito, así que sin marcador hay que
## adivinar además dónde está.
@export var mision := ""

var _done := false
var _mat: StandardMaterial3D

@onready var _mesh: MeshInstance3D = get_node_or_null("Mesh")


func _ready() -> void:
	collision_mask = 1
	monitoring = true
	area_entered.connect(_on_area_entered)
	if mision != "":
		add_to_group("objetivo_" + mision)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.9, 0.3, 0.2)   # rojo = sin activar
	if _mesh:
		_mesh.material_override = _mat


func _on_area_entered(area: Area3D) -> void:
	if _done:
		return
	if area.is_in_group("arrow"):
		_done = true
		if mision != "":
			remove_from_group("objetivo_" + mision)
		if _mat:
			_mat.albedo_color = Color(0.2, 0.9, 0.3)
			_mat.emission_enabled = true
			_mat.emission = Color(0.1, 0.55, 0.15)
		activated.emit()


func is_done() -> bool:
	return _done
