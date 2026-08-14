extends Area3D

# Proyectil del enemigo a distancia: viaja recto y dana al jugador al tocarlo.

var _vel := Vector3.ZERO
var _life := 3.5
var damage := 8.0


func setup(dir: Vector3, speed: float, dmg: float) -> void:
	_vel = dir.normalized() * speed
	damage = dmg


func _ready() -> void:
	collision_mask = 1 | 2  # jugador + entorno (para reventar en muros)
	monitoring = true
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.22
	s.height = 0.44
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.3, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.2, 1.0)
	mat.emission_energy_multiplier = 3.0
	mi.mesh = s
	mi.material_override = mat
	add_child(mi)
	var col := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.3
	col.shape = sh
	add_child(col)
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	global_position += _vel * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
		queue_free()
	elif body is StaticBody3D:
		queue_free()
