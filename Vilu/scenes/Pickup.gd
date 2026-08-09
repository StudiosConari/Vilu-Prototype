extends Area3D

# Orbe que suelta un enemigo. Dos clases:
#   "health"  (verde)  cura al jugador.
#   "energy"  (azul)   recarga energia/SP.
# Flota y gira; al tocarlo el jugador, aplica su efecto y desaparece.

@export var heal: float = 25.0
@export var energy: float = 30.0
@export var kind: String = "health"   # "health" | "energy"

var _t := 0.0
var _mesh: MeshInstance3D


func setup(k: String) -> void:
	kind = k


func _ready() -> void:
	collision_mask = 2  # detectar al jugador (capa 2)
	monitoring = true
	var col_main := Color(0.3, 1.0, 0.45) if kind == "health" else Color(0.35, 0.65, 1.0)
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.25
	sph.height = 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col_main
	mat.emission_enabled = true
	mat.emission = col_main
	mat.emission_energy_multiplier = 2.5
	mi.mesh = sph
	mi.material_override = mat
	mi.position = Vector3(0, 0.6, 0)
	_mesh = mi
	add_child(mi)
	var col := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.7
	col.shape = s
	col.position = Vector3(0, 0.6, 0)
	add_child(col)
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	_t += delta
	if _mesh:
		_mesh.position.y = 0.6 + sin(_t * 3.0) * 0.12
		_mesh.rotate_y(delta * 2.0)


func _on_body(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if kind == "energy":
		if body.has_method("add_energy"):
			body.add_energy(energy)
			queue_free()
	else:
		if body.has_method("heal"):
			body.heal(heal)
			queue_free()
