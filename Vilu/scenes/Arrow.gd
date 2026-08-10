extends Area3D

# Flecha de Benja: viaja recto y dana al enemigo al tocarlo.

var _vel := Vector3.ZERO
var _life := 3.0
var damage := 10.0
var pierce := false          # atraviesa enemigos (disparo cargado)
var _hit: Array = []


func setup(dir: Vector3, speed: float, dmg: float, is_pierce: bool = false) -> void:
	_vel = dir.normalized() * speed
	damage = dmg
	pierce = is_pierce
	look_at_from_position(global_position, global_position + _vel, Vector3.UP)


func _ready() -> void:
	collision_mask = 1 | 4  # entorno + enemigos
	monitoring = true
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.08, 0.08, 0.7)
	var mat := StandardMaterial3D.new()
	var col: Color = Color(0.5, 0.85, 1.0) if pierce else Color(0.9, 0.85, 0.4)
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.5 if pierce else 1.5
	mi.mesh = box
	mi.material_override = mat
	add_child(mi)
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
