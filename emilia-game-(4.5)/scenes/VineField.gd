extends Area3D

# Enredaderas con flores: ralentizan a los enemigos que caminan sobre ellas.

const RADIUS := 3.2
const SLOW_FACTOR := 0.5   # los enemigos dentro van al 50% de su velocidad
var _t := 5.5


func _ready() -> void:
	collision_mask = 4  # enemigos
	monitoring = true
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.6, 0.2, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS
	disc.bottom_radius = RADIUS
	disc.height = 0.08
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.material_override = mat
	mi.position = Vector3(0, 0.06, 0)
	add_child(mi)
	# Flores de colores.
	var cols := [Color(1, 0.5, 0.7), Color(1, 0.85, 0.3), Color(0.8, 0.4, 1.0), Color(1, 0.4, 0.4)]
	for i in 14:
		var f := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.16
		s.height = 0.32
		var fm := StandardMaterial3D.new()
		fm.albedo_color = cols[i % cols.size()]
		fm.emission_enabled = true
		fm.emission = cols[i % cols.size()]
		fm.emission_energy_multiplier = 0.8
		f.mesh = s
		f.material_override = fm
		var ang := randf() * TAU
		var rad := randf() * RADIUS * 0.9
		f.position = Vector3(cos(ang) * rad, 0.22, sin(ang) * rad)
		add_child(f)
	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = RADIUS
	cs.height = 2.5
	col.shape = cs
	col.position = Vector3(0, 1.0, 0)
	add_child(col)


func _physics_process(delta: float) -> void:
	_t -= delta
	for b in get_overlapping_bodies():
		if b.is_in_group("enemies") and b.has_method("set_slowed"):
			b.set_slowed(0.3, SLOW_FACTOR)
	if _t <= 0.0:
		queue_free()
