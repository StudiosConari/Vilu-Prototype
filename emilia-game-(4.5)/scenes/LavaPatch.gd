extends Area3D

# Charco de magma que deja la embestida de lava de Emilia. Quema (aplica burn)
# a los enemigos que pasan por encima y se apaga tras unos segundos.

const RADIUS := 1.1
var _t := 4.0
var _tick := 0.0
var _mat: StandardMaterial3D


func _ready() -> void:
	collision_mask = 4  # enemigos
	monitoring = true
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(1.0, 0.35, 0.05, 0.85)
	_mat.emission_enabled = true
	_mat.emission = Color(1.0, 0.45, 0.1)
	_mat.emission_energy_multiplier = 2.2
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS
	disc.bottom_radius = RADIUS
	disc.height = 0.08
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.material_override = _mat
	mi.position = Vector3(0, 0.05, 0)
	add_child(mi)
	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = RADIUS
	cs.height = 2.0
	col.shape = cs
	col.position = Vector3(0, 0.8, 0)
	add_child(col)


func _physics_process(delta: float) -> void:
	_t -= delta
	# Se apaga gradualmente al final.
	var a: float = clampf(_t / 1.0, 0.0, 1.0)
	_mat.albedo_color = Color(1.0, 0.35, 0.05, 0.85 * a + 0.1)
	_tick += delta
	if _tick >= 0.5:
		_tick -= 0.5
		for b in get_overlapping_bodies():
			if b.is_in_group("enemies") and b.has_method("take_damage"):
				b.take_damage(6.0, global_position + Vector3(0, 0.5, 0), 0.0, true)
	if _t <= 0.0:
		queue_free()
