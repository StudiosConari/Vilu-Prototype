extends StaticBody3D

## Cubo que se activa tras recibir 'hits_needed' golpes (melee de Emilia o flechas
## de Benjamín). La ALTURA del cubo debería reflejar los golpes (1 = bajo … 4 =
## alto). Grupo "hittable" + capa 4 para que lo alcancen melee y flechas.

signal activated

@export var hits_needed := 1

var _hits := 0
var _done := false
var _mat: StandardMaterial3D

@onready var _mesh: MeshInstance3D = get_node_or_null("Mesh")


func _ready() -> void:
	add_to_group("hittable")
	collision_layer = 4
	collision_mask = 0
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.85, 0.25, 0.25)
	if _mesh:
		_mesh.material_override = _mat


# Firma compatible con lo que llaman melee/flecha: take_damage(dmg, from, force, burn).
func take_damage(_dmg := 0.0, _from := Vector3.ZERO, _force := 0.0, _burn := false) -> void:
	if _done:
		return
	_hits += 1
	if _hits >= hits_needed:
		_done = true
		if _mat:
			_mat.albedo_color = Color(0.2, 0.9, 0.3)
			_mat.emission_enabled = true
			_mat.emission = Color(0.1, 0.55, 0.15)
		activated.emit()
	elif _mat:
		var t := float(_hits) / float(maxi(1, hits_needed))
		_mat.albedo_color = Color(0.85, 0.25, 0.25).lerp(Color(0.9, 0.85, 0.2), t)


func is_done() -> bool:
	return _done
