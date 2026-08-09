extends Area3D

## Objetivo temporizado (Beat 4 / Isluga). Alterna activo/inactivo en ciclos.
## Solo cuenta si una flecha (grupo "arrow") lo golpea durante la ventana activa.
## Detecta la flecha vía area_entered (la flecha es un Area3D en capa 1).

signal hit_while_active

@export var active_time := 1.2
@export var cycle := 3.0

var _t := 0.0
var _active := false
var _done := false
var _mat: StandardMaterial3D

@onready var _mesh: MeshInstance3D = get_node_or_null("Mesh")


func _ready() -> void:
	collision_mask = 1   # capa de la flecha
	monitoring = true
	area_entered.connect(_on_area_entered)
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if _mesh:
		_mesh.material_override = _mat
	_set_active(false)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_set_active(fmod(_t, cycle) < active_time)


func _set_active(active: bool) -> void:
	_active = active
	if _mat:
		_mat.albedo_color = Color(1.0, 0.8, 0.2) if active else Color(0.1, 0.7, 0.8)


func _on_area_entered(area: Area3D) -> void:
	if _done:
		return
	if area.is_in_group("arrow") and _active:
		mark_hit()


## Marca el objetivo como acertado (llamable desde tests).
func mark_hit() -> void:
	if _done:
		return
	_done = true
	_active = true
	if _mat:
		_mat.albedo_color = Color(0.2, 1.0, 0.3)
		_mat.emission_enabled = true
		_mat.emission = Color(0.1, 0.6, 0.15)
	hit_while_active.emit()


func is_done() -> bool:
	return _done
