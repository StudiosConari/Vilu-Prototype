extends StaticBody3D

## Botón golpeable (melee de Emilia o flecha de Benjamín). Cada golpe emite
## 'struck(from_pos)' con la posición del impacto, para que el puzzle deduzca
## desde qué CARA se golpeó. Grupo "hittable" + capa 4 para que lo alcancen
## melee y flechas. Un pequeño debounce evita dobles disparos del mismo golpe.

signal struck(from_pos: Vector3)

@export var color := Color(0.9, 0.3, 0.2)

var _cool := 0.0
var _mat: StandardMaterial3D

@onready var _mesh: MeshInstance3D = get_node_or_null("Mesh")


func _ready() -> void:
	add_to_group("hittable")
	collision_layer = 4
	collision_mask = 0
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = color
	if _mesh:
		_mesh.material_override = _mat


func _process(delta: float) -> void:
	if _cool > 0.0:
		_cool = maxf(0.0, _cool - delta)


func take_damage(_dmg := 0.0, _from := Vector3.ZERO, _force := 0.0, _burn := false) -> void:
	if _cool > 0.0:
		return
	_cool = 0.18
	_flash()
	struck.emit(_from)


func _flash() -> void:
	if _mat == null:
		return
	_mat.emission_enabled = true
	_mat.emission = color * 0.8
	var tw := create_tween()
	tw.tween_property(_mat, "emission", Color.BLACK, 0.2)
	tw.tween_callback(func() -> void:
		if _mat:
			_mat.emission_enabled = false)
