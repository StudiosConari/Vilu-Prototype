extends CharacterBody3D

# Guanaco espectral (modelo 3D holograma) con COLISION: choca con murallas y
# suelo (no los atraviesa). Tres modos:
#   "beside"  se acerca a `beside_target` (a tu costado), esperando ordenes.
#   "charge"  embiste en linea recta; se detiene al chocar con una muralla.
#   "ride"    el jinete (Player) le pasa `ride_velocity`; el guanaco colisiona.
# Capa 0 (nadie choca contra el = espectral), mascara 1 (choca con el entorno).

const MODEL := "res://models/guanaco.fbx"
const MODEL_YAW := 0.0
const TARGET_SIZE := 2.1

var mode := "beside"
var _dir := Vector3(0, 0, 1)
var _speed := 16.0
var _t := 14.0
var rider: Node3D
var _hit: Array = []
var _mats: Array[StandardMaterial3D] = []
var _flicker := 0.0
var mount_offset := 1.3
var beside_target := Vector3.ZERO   # lo fija el Player (modo beside)
var ride_velocity := Vector3.ZERO   # lo fija el Player (modo ride)


func setup_beside(r: Node3D) -> void:
	mode = "beside"
	rider = r
	_t = 16.0
	_hit.clear()
	beside_target = global_position


func set_ride(r: Node3D) -> void:
	mode = "ride"
	rider = r
	_t = 999.0
	_hit.clear()


func start_charge(dir: Vector3) -> void:
	mode = "charge"
	rider = null
	_dir = dir.normalized() if dir.length() > 0.1 else Vector3(0, 0, 1)
	_speed = 16.0
	_t = 2.2
	_hit.clear()
	face_dir(_dir)


func face_dir(dir: Vector3) -> void:
	if dir.length() > 0.1:
		rotation.y = atan2(dir.x, dir.z)


func _ready() -> void:
	collision_layer = 0   # espectral: nadie choca contra el
	collision_mask = 1    # pero el SI choca con el entorno (murallas/suelo)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 1.5
	col.shape = cap
	col.position = Vector3(0, 0.8, 0)
	add_child(col)
	var ps := load(MODEL) as PackedScene
	if ps != null:
		var model := ps.instantiate()
		add_child(model)
		_fit_model(model)
		_apply_holo(model)
	else:
		_build_primitive()


func _fit_model(model: Node3D) -> void:
	var aabb := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var rel := _rel_xform(m, model)
		var mab: AABB = rel * m.mesh.get_aabb()
		if first:
			aabb = mab
			first = false
		else:
			aabb = aabb.merge(mab)
	if first:
		return
	var size := aabb.size
	var longest: float = maxf(size.y, maxf(size.x, size.z))
	var f: float = TARGET_SIZE / longest if longest > 0.0 else 1.0
	model.scale = Vector3(f, f, f)
	model.position = Vector3(
		-(aabb.position.x + size.x * 0.5) * f,
		-aabb.position.y * f,
		-(aabb.position.z + size.z * 0.5) * f)
	model.rotation.y = deg_to_rad(MODEL_YAW)
	mount_offset = size.y * f * 0.6


func _rel_xform(node: Node3D, top: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node3D = node
	while n != null and n != top:
		t = n.transform * t
		n = n.get_parent() as Node3D
	return t


func _apply_holo(model: Node3D) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.85, 1.0, 0.45)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.4, 0.85, 1.0)
		mat.emission_energy_multiplier = 1.7
		mat.rim_enabled = true
		mat.rim = 0.9
		mat.rim_tint = 0.7
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var cnt: int = m.mesh.get_surface_count()
		for s in maxi(cnt, 1):
			m.set_surface_override_material(s, mat)
		_mats.append(mat)


func _build_primitive() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.85, 1.0, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.8, 1.0)
	mat.emission_energy_multiplier = 1.6
	_mats.append(mat)
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.5
	cap.height = 1.7
	body.mesh = cap
	body.material_override = mat
	body.rotation.x = deg_to_rad(90)
	body.position = Vector3(0, 1.0, 0)
	add_child(body)
	var neck := MeshInstance3D.new()
	var nc := CylinderMesh.new()
	nc.top_radius = 0.16
	nc.bottom_radius = 0.22
	nc.height = 0.9
	neck.mesh = nc
	neck.material_override = mat
	neck.position = Vector3(0, 1.5, 0.6)
	neck.rotation.x = deg_to_rad(-35)
	add_child(neck)
	var head := MeshInstance3D.new()
	var hd := BoxMesh.new()
	hd.size = Vector3(0.28, 0.3, 0.5)
	head.mesh = hd
	head.material_override = mat
	head.position = Vector3(0, 2.0, 0.95)
	add_child(head)
	for lx in [-0.32, 0.32]:
		for lz in [-0.5, 0.5]:
			var leg := MeshInstance3D.new()
			var lc := CylinderMesh.new()
			lc.top_radius = 0.09
			lc.bottom_radius = 0.09
			lc.height = 1.0
			leg.mesh = lc
			leg.material_override = mat
			leg.position = Vector3(lx, 0.5, lz)
			add_child(leg)
	mount_offset = 1.3


func _physics_process(delta: float) -> void:
	_t -= delta
	_flicker += delta * 6.0
	var e: float = 1.5 + 0.35 * sin(_flicker)
	for mat in _mats:
		mat.emission_energy_multiplier = e

	# Gravedad (se apoya en el suelo, no lo traspasa).
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.5

	if mode == "charge":
		velocity.x = _dir.x * _speed
		velocity.z = _dir.z * _speed
		move_and_slide()
		var a: float = clampf(_t, 0.0, 0.5)
		for mat in _mats:
			var c := mat.albedo_color
			c.a = clampf(a + 0.15, 0.15, 0.65)
			mat.albedo_color = c
		_trample(2.2, 35.0, 12.0)
		if is_on_wall():
			_t = minf(_t, 0.12)  # se detiene al chocar con una muralla
		if _t <= 0.0:
			queue_free()
		return

	if mode == "ride":
		velocity.x = ride_velocity.x
		velocity.z = ride_velocity.z
		move_and_slide()
		_trample(2.0, 16.0, 7.0)
		return

	# beside: se acerca al punto objetivo del jinete (con colision).
	var to := beside_target - global_position
	to.y = 0.0
	velocity.x = to.x * 6.0
	velocity.z = to.z * 6.0
	move_and_slide()
	if _t <= 0.0:
		queue_free()


func _trample(radius: float, dmg: float, force: float) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e in _hit:
			continue
		if global_position.distance_to(e.global_position) < radius:
			_hit.append(e)
			if e.has_method("take_damage"):
				e.take_damage(dmg, global_position, force)
