extends Area3D

# Flecha de Benja: viaja recto y dana al enemigo al tocarlo.

var _vel := Vector3.ZERO
var _life := 3.0
var damage := 10.0
var pierce := false          # atraviesa enemigos (disparo cargado)
var _hit: Array = []


const ARMA := preload("res://models/personaje/benjamin_arma.glb")

## Lo que mide la flecha en el juego, en metros.
const LARGO := 0.7


## La flecha del artista, la misma que va en el carcaj de Benjamin.
##
## Era una caja amarilla que brillaba. El brillo NO se quita del todo a
## proposito: en la mina no hay luz y una flecha de madera se perderia contra el
## fondo. Se deja suave, y la cargada sigue tirando a azul para que se distinga
## de un vistazo, que es para lo que estaba el color.
func _hacer_flecha() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var col: Color = Color(0.5, 0.85, 1.0) if pierce else Color(1.0, 0.9, 0.6)
	var piezas := ARMA.instantiate() as Node3D
	var f := piezas.get_node_or_null("flecha") as MeshInstance3D if piezas != null else null
	if f == null or f.mesh == null:
		# Sin modelo, la caja de siempre: mejor una flecha fea que ninguna.
		var box := BoxMesh.new()
		box.size = Vector3(0.08, 0.08, LARGO)
		mi.mesh = box
		var basico := StandardMaterial3D.new()
		basico.albedo_color = col
		basico.emission_enabled = true
		basico.emission = col
		basico.emission_energy_multiplier = 2.5 if pierce else 1.5
		mi.material_override = basico
		if piezas != null:
			piezas.queue_free()
		return mi

	mi.mesh = f.mesh
	var caja: AABB = f.mesh.get_aabb()
	mi.scale = Vector3.ONE * (LARGO / maxf(caja.size.z, 0.001))
	# La punta del modelo mira a +Z, y una flecha viaja hacia el -Z de su nodo,
	# que es lo que deja `look_at_from_position`. Va del revés.
	mi.rotation_degrees.y = 180.0

	var viejo := f.mesh.surface_get_material(0) as BaseMaterial3D
	var mat: BaseMaterial3D = viejo.duplicate() if viejo != null else StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.6 if pierce else 0.45
	mi.material_override = mat
	piezas.queue_free()
	return mi


func setup(dir: Vector3, speed: float, dmg: float, is_pierce: bool = false) -> void:
	_vel = dir.normalized() * speed
	damage = dmg
	pierce = is_pierce
	look_at_from_position(global_position, global_position + _vel, Vector3.UP)


func _ready() -> void:
	collision_mask = 1 | 4  # entorno + enemigos
	monitoring = true
	add_child(_hacer_flecha())
	var cshape := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.25
	cshape.shape = sh
	add_child(cshape)
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	global_position += _vel * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body(body: Node3D) -> void:
	if body.is_in_group("enemies") or body.is_in_group("hittable"):
		if body in _hit:
			return
		_hit.append(body)
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position, 4.0)
		if not pierce:
			queue_free()  # cargada = perforante, no se destruye
	elif (body is StaticBody3D or body is AnimatableBody3D) and not pierce:
		queue_free()
