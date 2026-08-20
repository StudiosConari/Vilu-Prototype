extends Node3D

## Beat 6 — Encuentro con el Yastay (guanaco gigante sagrado).
##
## FLUJO:
##   1. Se ve al Yastay luchando contra cazadores que atacaban a sus guanacos.
##      Uno de los guanacos queda herido en el suelo.
##   2. El Yastay derrota a todos los cazadores (automático).
##   3. El Yastay nos ve y nos ataca. Emilia esquiva. Benjamín cura al herido.
##   4. Al curar al guanaco, el Yastay se calma y da la Bendición del Guanaco
##      a Benjamín (Q = montar, G = embestir).

const INTERACT_SCR := preload("res://scenes/actors/Interactable.gd")
const BALLOON      := "res://addons/dialogue_manager/example_balloon/example_balloon.tscn"

const TALK_BLESSING := "~ start
Yastay: Alto. Bajad las armas.
Yastay: Has demostrado que no eras como esos cazadores.
Yastay: Recuperaste a un guanaco de mi rebaño, y al parecer quiere ser tu amigo.
Yastay: Puedes llevarlo contigo, arquero. Que te guarde el camino.
Benjamín: Gracias, Yastay.
=> END
"

const TALK_FRAG2 := "~ start
Benjamín: Esperá... este cazador llevaba algo escondido.
Benjamín: Acá está la segunda pieza, la que necesita la Bruja.
Emilia: Es igual a la que sacamos de la mina. Deberíamos llevársela.
=> END
"

enum Phase { INTRO, HUNTING, AGGRESSIVE, RESOLVED }
var _phase := Phase.INTRO

var _yastay: Node3D = null
var _yastay_label: Label3D = null
var _hunters: Array = []
var _inspected: Array = []
var _wounded: Node3D = null
var _wound_healed := false
var _yastay_stomp_cd := 0.0
var _brujo: Node3D = null


func _ready() -> void:
	_build_arena()
	_spawn_characters()
	_hint("Los cazadores atacan al Yastay y sus guanacos…")
	get_tree().create_timer(1.5).timeout.connect(_begin_hunt)


# ─── Fases ────────────────────────────────────────────────────────────────────

func _begin_hunt() -> void:
	_phase = Phase.HUNTING
	for i in _hunters.size():
		get_tree().create_timer(0.6 + i * 0.65).timeout.connect(
			func() -> void: _defeat_hunter(i))
	var done := 0.6 + (_hunters.size() - 1) * 0.65 + 1.0
	# El brujo que los mandaba ve caer al último cazador y arranca.
	get_tree().create_timer(done - 0.4).timeout.connect(_brujo_escapes)
	get_tree().create_timer(done).timeout.connect(_begin_aggressive)


## El brujo dirigía a los cazadores desde atrás. Al ver que el Yastay los
## derrota, huye hacia el norte sin pelear.
func _brujo_escapes() -> void:
	if not is_instance_valid(_brujo):
		return
	_banner("¡Alguien los estaba dirigiendo desde atrás… y está huyendo!", 4.0)
	var lbl := _brujo.get_node_or_null("Label3D") as Label3D
	if lbl:
		lbl.text = "¡El brujo huye!"
	var tw := get_tree().create_tween()
	tw.tween_property(_brujo, "position",
		_brujo.position + Vector3(-9.0, 0.0, -9.0), 1.8)
	tw.parallel().tween_property(_brujo, "scale", Vector3.ZERO, 1.8)
	tw.tween_callback(_brujo.queue_free)


## El Yastay derriba al cazador: queda TENDIDO en el suelo y se puede revisar [E].
func _defeat_hunter(idx: int) -> void:
	if idx >= _hunters.size() or not is_instance_valid(_hunters[idx]):
		return
	var h: Node3D = _hunters[idx]

	var tw := get_tree().create_tween()
	tw.tween_property(h, "rotation:z", PI / 2.0, 0.35)
	tw.parallel().tween_property(h, "position:y", 0.30, 0.35)

	var lbl := h.get_node_or_null("Label3D") as Label3D
	if lbl:
		lbl.text     = "Cuerpo de cazador"
		lbl.modulate = Color(0.75, 0.70, 0.65)

	# Zona de interacción para registrar el cuerpo
	var zone             := Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask  = 2
	zone.set_script(INTERACT_SCR)
	zone.prompt          = "[E] Revisar cuerpo"
	h.add_child(zone)

	var cs  := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.0
	cs.shape   = sph
	zone.add_child(cs)

	zone.interacted.connect(_on_inspect.bind(h, zone))


## Revisar un cuerpo. Al revisar TODOS aparece el 2º fragmento del talismán.
func _on_inspect(player: Node, body: Node3D, zone: Area3D) -> void:
	if body in _inspected:
		return
	_inspected.append(body)

	var lbl := body.get_node_or_null("Label3D") as Label3D
	if lbl:
		lbl.text     = "Revisado"
		lbl.modulate = Color(0.45, 0.45, 0.45)

	# Desactivar la zona: ya fue revisada
	zone.set_deferred("monitoring", false)
	if player and player.has_method("clear_interactable"):
		player.clear_interactable(zone)

	var total := _hunters.size()
	if _inspected.size() < total:
		_banner("Cuerpos revisados: %d/%d" % [_inspected.size(), total], 2.5)
		return

	# Todos revisados -> segundo fragmento
	if not GameManager.has_ability("talisman_frag_2"):
		GameManager.unlock("talisman_frag_2")
	_hint("Llevá el talismán a la Bruja en el poblado.")
	var res := DialogueManager.create_resource_from_text(TALK_FRAG2)
	DialogueManager.show_dialogue_balloon_scene(BALLOON, res, "start")


func _begin_aggressive() -> void:
	_phase = Phase.AGGRESSIVE
	if is_instance_valid(_yastay_label):
		_yastay_label.text = "Yastay\n¡Intruso!"
	_banner("¡El Yastay os ve! Emilia: esquiva sus cargas. Benjamín: sana al guanaco herido.", 6.0)
	_hint("Emilia esquiva. Benjamín acércate al guanaco herido.")


func _process(delta: float) -> void:
	if _phase == Phase.AGGRESSIVE:
		_yastay_think(delta)


func _yastay_think(delta: float) -> void:
	if not is_instance_valid(_yastay):
		return
	var target := _active_player()
	if target == null:
		return
	var to_t := target.global_position - _yastay.global_position
	to_t.y = 0.0
	var dist := to_t.length()

	# Persecución lenta pero amenazante
	if dist > 2.0:
		_yastay.global_position += to_t.normalized() * 3.8 * delta
	if dist > 0.5:
		_yastay.look_at(_yastay.global_position + to_t.normalized(), Vector3.UP)

	# Golpe al alcanzar al jugador
	_yastay_stomp_cd = max(0.0, _yastay_stomp_cd - delta)
	if dist < 2.5 and _yastay_stomp_cd <= 0.0:
		_yastay_stomp_cd = 2.2
		if target.has_method("take_damage"):
			target.take_damage(25.0)
		_banner("¡Golpe del Yastay! ¡Esquiva!", 1.8)


# ─── Curación ─────────────────────────────────────────────────────────────────

func _on_heal_entered(body: Node3D) -> void:
	if _wound_healed or _phase != Phase.AGGRESSIVE:
		return
	if not body.is_in_group("player"):
		return
	if body.get("is_archer") != true:
		_banner("Sólo Benjamín puede sanar al guanaco.", 2.5)
		return
	_heal()


func _heal() -> void:
	_wound_healed = true
	_phase = Phase.RESOLVED
	_hint("El guanaco herido se recupera. El Yastay asiente…")

	# El guanaco herido se levanta
	if is_instance_valid(_wounded):
		var tw := get_tree().create_tween()
		tw.tween_property(_wounded, "rotation:z", 0.0, 0.9)
		# Quitar el cartel de herido
		var lbl := _wounded.get_node_or_null("Label3D")
		if lbl:
			tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.5)

	# Yastay se calma
	if is_instance_valid(_yastay_label):
		_yastay_label.text = "Yastay"
	get_tree().create_timer(2.2).timeout.connect(_yastay_speaks)


## El Yastay se acerca y habla. La bendición sólo llega al terminar el diálogo.
func _yastay_speaks() -> void:
	if is_instance_valid(_yastay):
		var target := _active_player()
		if target != null:
			var to_p := target.global_position - _yastay.global_position
			to_p.y = 0.0
			var stop := _yastay.global_position + to_p.normalized() * maxf(0.0, to_p.length() - 4.0)
			var tw := get_tree().create_tween()
			tw.tween_property(_yastay, "global_position", stop, 1.2)

	DialogueManager.dialogue_ended.connect(
		_give_blessing.unbind(1), CONNECT_ONE_SHOT)
	var res := DialogueManager.create_resource_from_text(TALK_BLESSING)
	DialogueManager.show_dialogue_balloon_scene(BALLOON, res, "start")


func _give_blessing() -> void:
	GameManager.unlock("guanaco")
	if GameManager.get_beat() < 6:
		GameManager.set_beat(6)

	_banner("Bendición del Guanaco obtenida. El paso al volcán está abierto.", 7.0)
	_hint("[Q] invocar/montar/guardar guanaco · [G] embestir · [E] revisar los cuerpos · portal al norte")

	# El Yastay se queda: se aparta a un costado para no tapar el portal.
	if is_instance_valid(_yastay):
		if is_instance_valid(_yastay_label):
			_yastay_label.text = "Yastay\nguardián de los guanacos"
		var tw := get_tree().create_tween()
		tw.tween_property(_yastay, "global_position", Vector3(-11, 0, -15), 2.5)


# ─── Construcción ─────────────────────────────────────────────────────────────

func _build_arena() -> void:
	var grass  := _mat(Color(0.38, 0.50, 0.28))
	var rock   := _mat(Color(0.32, 0.28, 0.24))
	var lava   := _mat(Color(0.62, 0.14, 0.04))
	var border := _mat(Color(0.22, 0.20, 0.18))

	# Suelo
	_box(Vector3(0, -0.5, 0), Vector3(38, 1, 40), grass)

	# Paredes invisibles
	_box(Vector3(-19.5, 3, 0), Vector3(1, 6, 40), border)
	_box(Vector3( 19.5, 3, 0), Vector3(1, 6, 40), border)
	_box(Vector3(0, 3, -20.5), Vector3(38, 6, 1), border)
	_box(Vector3(0, 3,  20.5), Vector3(38, 6, 1), border)

	# Rocas volcánicas como cobertura para esquivar
	for rx: float in [-9.0, -4.0, 4.0, 9.0]:
		for rz: float in [-4.0, 3.0]:
			_box(Vector3(rx, 0.7, rz), Vector3(1.6, 1.4, 1.6), rock)

	# Portal de salida al norte (hueco en la pared + marco luminoso)
	var gate := _mat_emit(Color(0.85, 0.45, 0.12), Color(0.50, 0.20, 0.02))
	_box(Vector3(-4.5, 3, -19.4), Vector3(1.0, 5.0, 0.6), gate)
	_box(Vector3( 4.5, 3, -19.4), Vector3(1.0, 5.0, 0.6), gate)
	_box(Vector3( 0.0, 5.2, -19.4), Vector3(10.0, 0.6, 0.6), gate)

	# Grietas de lava (decorativas)
	_box(Vector3(-5, -0.35, -9),  Vector3(2.5, 0.2, 12), lava)
	_box(Vector3( 6, -0.35,  5),  Vector3(10,  0.2,  2), lava)
	_box(Vector3(-2, -0.35,  12), Vector3(4,   0.2,  3), lava)


func _spawn_characters() -> void:
	var yastay_mat  := _mat_emit(Color(0.92, 0.72, 0.20), Color(0.45, 0.28, 0.02))
	var hunter_mat  := _mat(Color(0.22, 0.16, 0.08))
	var guanaco_mat := _mat(Color(0.86, 0.76, 0.56))

	# — Yastay (enorme, dorado) —
	_yastay = _npc(Vector3(0, 0, -14), yastay_mat, 2.6, "Yastay")
	_yastay_label = _yastay.get_node_or_null("Label3D")
	# Luz dorada del Yastay
	var light := OmniLight3D.new()
	light.light_color  = Color(1.0, 0.82, 0.35)
	light.omni_range   = 10.0
	light.light_energy = 1.2
	light.position.y   = 2.0
	_yastay.add_child(light)

	# — Cazadores (4, marrón oscuro) —
	var hunt_pos: Array[Vector3] = [
		Vector3(-6, 0, -11),
		Vector3( 6, 0, -11),
		Vector3(-3, 0, -12),
		Vector3( 3, 0, -12),
	]
	for hp: Vector3 in hunt_pos:
		_hunters.append(_npc(hp, hunter_mat, 1.0, "Cazador"))

	# — Brujo: los dirige desde atrás, encapuchado. Escapa al verlos caer —
	_brujo = _npc(Vector3(-2, 0, -17), _mat(Color(0.10, 0.06, 0.16)), 1.05, "???")
	var hood_mi   := MeshInstance3D.new()
	var hood_mesh := CylinderMesh.new()
	hood_mesh.top_radius    = 0.0
	hood_mesh.bottom_radius = 0.40
	hood_mesh.height        = 0.55
	hood_mi.mesh       = hood_mesh
	hood_mi.position.y = 1.75
	hood_mi.set_surface_override_material(0, _mat(Color(0.07, 0.04, 0.11)))
	_brujo.add_child(hood_mi)

	# — Guanacos pequeños (3, dispersos) —
	var guana_pos: Array[Vector3] = [
		Vector3(-12, 0, -7),
		Vector3( 11, 0, -9),
		Vector3(-9,  0, -14),
	]
	for gp: Vector3 in guana_pos:
		_npc(gp, guanaco_mat, 0.75, "")

	# — Guanaco herido (tumbado) —
	_wounded = _npc(Vector3(8, 0, -6), guanaco_mat, 0.80, "¡Sana al guanaco!")
	_wounded.rotation.z = PI / 2.0   # tumbado de lado

	# Área de curación (solo Benjamín puede usarla)
	var heal_area := Area3D.new()
	heal_area.collision_layer = 0
	heal_area.collision_mask  = 2
	heal_area.monitoring      = true
	var cs  := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.2
	cs.shape   = sph
	heal_area.add_child(cs)
	heal_area.body_entered.connect(_on_heal_entered)
	_wounded.add_child(heal_area)


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _npc(pos: Vector3, mat: Material, scale_f: float, label_text: String) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	add_child(root)

	var mi  := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.34 * scale_f
	cap.height = 1.55 * scale_f
	mi.mesh = cap
	mi.set_surface_override_material(0, mat)
	mi.position.y = 0.78 * scale_f
	root.add_child(mi)

	if label_text != "":
		var lbl    := Label3D.new()
		lbl.name   = "Label3D"
		lbl.text   = label_text
		lbl.font_size  = 22
		lbl.position.y = 1.9 * scale_f
		lbl.billboard  = BaseMaterial3D.BILLBOARD_ENABLED
		root.add_child(lbl)

	return root


func _box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var b := CSGBox3D.new()
	b.size = size
	b.position = pos
	b.use_collision = true
	b.material_override = mat
	add_child(b)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _mat_emit(c: Color, emit: Color) -> StandardMaterial3D:
	var m := _mat(c)
	m.emission_enabled = true
	m.emission = emit
	m.emission_energy_multiplier = 1.0
	return m


func _active_player() -> Node3D:
	for p in get_tree().get_nodes_in_group("player"):
		if "active" in p and p.active:
			return p
	var arr := get_tree().get_nodes_in_group("player")
	return arr[0] if not arr.is_empty() else null


func _hint(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_hint"):
		hud.show_hint(text)


func _banner(text: String, dur := 0.0) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if not hud or not hud.has_method("show_banner"):
		return
	hud.show_banner(text)
	if dur > 0.0:
		get_tree().create_timer(dur).timeout.connect(func() -> void:
			if is_instance_valid(hud) and hud.has_method("clear_banner"):
				hud.clear_banner())
