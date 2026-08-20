extends Node3D

## Guanaco compañero de Benjamín (tras la Bendición del Yastay).
##   Q (procesado en PlayerController) — montar / desmontar (speed x1.5)
##   G — lanzar al guanaco a embestir (carga en línea recta, daña enemigos)
##
## Este nodo sigue a Benjamín en todo momento.
## Al embestir sale disparado y vuelve luego de frenar.

const CHARGE_SPEED  := 18.0
const CHARGE_DAMAGE := 60.0
const CHARGE_CD     := 5.0
const FOLLOW_SPEED  := 6.0
const FOLLOW_DIST   := 2.5    # distancia objetivo al lado de Benjamín

var _charging    := false
var _charge_vel  := Vector3.ZERO
var _charge_cd   := 0.0
var _t           := 0.0
var _base_y      := 0.0
var _ready_done  := false
var _mounted     := false

var _g_prev      := false
var _label: Label3D = null


func _ready() -> void:
	add_to_group("guanaco_companion")
	_build_visual()


## Llamado por PlayerController al montar/desmontar (tecla Q).
func set_mounted(v: bool) -> void:
	_mounted = v
	if is_instance_valid(_label):
		_label.visible = not v


func _process(delta: float) -> void:
	# Capturar _base_y en el primer frame (cuando la posición global ya es correcta)
	if not _ready_done:
		_ready_done = true
		_base_y = global_position.y
		return

	_t += delta
	_charge_cd = max(0.0, _charge_cd - delta)

	if _mounted:
		_ride_benja()
	elif _charging:
		_do_charge(delta)
	else:
		_follow_benja(delta)
		# Suave levitación en idle
		global_position.y = _base_y + sin(_t * 1.4) * 0.10

	# G = lanzar a embestir (no disponible mientras se lo monta)
	var g := Input.is_action_pressed("guanaco_charge")
	if g and not _g_prev and not _mounted and not _charging and _charge_cd <= 0.0:
		_launch()
	_g_prev = g


## Montado: el guanaco va bajo Benjamín y copia su orientación.
func _ride_benja() -> void:
	var benja := _find_benja()
	if benja == null:
		return
	global_position = benja.global_position
	_base_y = benja.global_position.y
	var vis := benja.get_node_or_null("Visual") as Node3D
	if vis:
		rotation.y = vis.global_rotation.y


func _follow_benja(delta: float) -> void:
	var benja := _find_benja()
	if benja == null:
		return
	var offset := benja.global_transform.basis.x * FOLLOW_DIST
	var target  := benja.global_position + offset + Vector3(0, 0.4, 0)
	var diff    := target - global_position
	diff.y      = 0.0
	if diff.length() > 0.1:
		global_position += diff.normalized() * min(diff.length(), FOLLOW_SPEED * delta)


func _launch() -> void:
	var benja := _find_benja()
	if benja == null:
		return
	_charging    = true
	# Carga en la dirección que mira Benjamín
	var vis  := benja.get_node_or_null("Visual")
	var fwd  := Vector3(0, 0, -1)
	if vis:
		fwd = -vis.global_transform.basis.z
	_charge_vel = fwd.normalized() * CHARGE_SPEED
	_charge_vel.y = 0.0
	_charge_cd  = CHARGE_CD
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_banner"):
		hud.show_banner("¡Guanaco embiste! [" + str(int(CHARGE_CD)) + "s de recarga]")


func _do_charge(delta: float) -> void:
	global_position += _charge_vel * delta
	_charge_vel = _charge_vel.lerp(Vector3.ZERO, delta * 3.8)

	# Daño a enemigos cercanos
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) < 1.6:
			if enemy.has_method("take_damage"):
				enemy.take_damage(CHARGE_DAMAGE, global_position, 8.0)

	if _charge_vel.length() < 0.6:
		_charging = false


func _find_benja() -> Node3D:
	for p in get_tree().get_nodes_in_group("player"):
		if p.get("is_archer") == true:
			return p
	return null


func _build_visual() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color           = Color(0.88, 0.79, 0.56)
	mat.emission_enabled       = true
	mat.emission               = Color(0.22, 0.16, 0.03)
	mat.emission_energy_multiplier = 0.9

	# Cuerpo (horizontal, como guanaco real)
	var body_mi   := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.28
	body_mesh.height = 1.0
	body_mi.mesh   = body_mesh
	body_mi.rotation.z = PI / 2.0
	body_mi.position.y = 0.5
	body_mi.set_surface_override_material(0, mat)
	add_child(body_mi)

	# Cabeza
	var head_mi   := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.20
	head_mi.mesh   = head_mesh
	head_mi.set_surface_override_material(0, mat)
	head_mi.position = Vector3(0.0, 0.8, -0.52)
	add_child(head_mi)

	# Patas (4 cilindros simples)
	var leg_mat := StandardMaterial3D.new()
	leg_mat.albedo_color = Color(0.75, 0.65, 0.45)
	var leg_positions: Array[Vector3] = [
		Vector3( 0.35, 0.18, -0.28),
		Vector3(-0.35, 0.18, -0.28),
		Vector3( 0.35, 0.18,  0.28),
		Vector3(-0.35, 0.18,  0.28),
	]
	for lp: Vector3 in leg_positions:
		var leg_mi   := MeshInstance3D.new()
		var leg_mesh := CapsuleMesh.new()
		leg_mesh.radius = 0.07
		leg_mesh.height = 0.38
		leg_mi.mesh   = leg_mesh
		leg_mi.position = lp
		leg_mi.set_surface_override_material(0, leg_mat)
		add_child(leg_mi)

	# Halo dorado suave
	var light          := OmniLight3D.new()
	light.light_color  = Color(1.0, 0.90, 0.60)
	light.omni_range   = 2.8
	light.light_energy = 0.7
	light.position.y   = 0.5
	add_child(light)

	# Etiqueta
	_label           = Label3D.new()
	_label.text      = "Guanaco\n[G] embestir · [Q] montar"
	_label.font_size = 18
	_label.position  = Vector3(0, 1.4, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)
