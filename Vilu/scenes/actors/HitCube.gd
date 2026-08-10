extends StaticBody3D

## Cubo que se activa tras recibir 'hits_needed' golpes (melee de Emilia o flechas
## de Benjamín). La ALTURA del cubo debería reflejar los golpes (1 = bajo … 4 =
## alto). Grupo "hittable" + capa 4 para que lo alcancen melee y flechas.
##
## Dos modos:
##  · latch (por defecto): al alcanzar hits_needed queda activado y los golpes
##    extra se ignoran. Sirve para cubos que disparan un mecanismo (ascensores).
##  · reset_on_overhit: hay que golpearlo EXACTAMENTE hits_needed veces. Si te
##    pasás (un golpe de más), se reinicia a cero y hay que empezar de nuevo. Así
##    el jugador debe acertar la cantidad justa en cada cubo.

signal activated      # pasó a estado "satisfecho" (justo hits_needed)
signal deactivated    # estaba satisfecho y se reinició (solo en reset_on_overhit)

@export var hits_needed := 1
@export var reset_on_overhit := false

var _hits := 0
var _satisfied := false
var _mat: StandardMaterial3D

@onready var _mesh: MeshInstance3D = get_node_or_null("Mesh")


func _ready() -> void:
	add_to_group("hittable")
	collision_layer = 4
	collision_mask = 0
	_mat = StandardMaterial3D.new()
	if _mesh:
		_mesh.material_override = _mat
	_refresh_color()


# Firma compatible con lo que llaman melee/flecha: take_damage(dmg, from, force, burn).
func take_damage(_dmg := 0.0, _from := Vector3.ZERO, _force := 0.0, _burn := false) -> void:
	if _satisfied and not reset_on_overhit:
		return   # latch: ya activado, ignora golpes extra
	_hits += 1
	if reset_on_overhit and _hits > hits_needed:
		_hits = 0   # te pasaste -> reinicia
	_apply_state()


func _apply_state() -> void:
	var was := _satisfied
	if reset_on_overhit:
		_satisfied = (_hits == hits_needed)
	else:
		_satisfied = (_hits >= hits_needed)
	_refresh_color()
	if _satisfied and not was:
		activated.emit()
	elif was and not _satisfied:
		deactivated.emit()


func _refresh_color() -> void:
	if _mat == null:
		return
	if _satisfied:
		_mat.albedo_color = Color(0.2, 0.9, 0.3)
		_mat.emission_enabled = true
		_mat.emission = Color(0.1, 0.55, 0.15)
	else:
		_mat.emission_enabled = false
		var t := float(_hits) / float(maxi(1, hits_needed))
		_mat.albedo_color = Color(0.85, 0.25, 0.25).lerp(Color(0.9, 0.85, 0.2), t)


func is_done() -> bool:
	return _satisfied


func is_satisfied() -> bool:
	return _satisfied
