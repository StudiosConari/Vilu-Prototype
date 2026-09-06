extends GutTest

## La huida del brujo: apunta al jugador, cae derrotado y sale corriendo herido
## hacia la entrada de la quebrada, que es la única salida.

const ENCUENTRO := preload("res://scenes/actors/YastayEncounter.gd")
const BRUJO := preload("res://models/personaje/brujo.glb")


func _zona() -> Node3D:
	var z := Node3D.new()
	z.set_script(ENCUENTRO)
	add_child_autofree(z)
	return z


func _animador(n: Node) -> AnimationPlayer:
	for h in n.get_children():
		if h is AnimationPlayer:
			return h
		var x := _animador(h)
		if x != null:
			return x
	return null


# ─── El modelo ───────────────────────────────────────────────────────────────

func test_el_brujo_trae_sus_tres_momentos() -> void:
	var n: Node = BRUJO.instantiate()
	add_child_autofree(n)
	var ap := _animador(n)
	assert_not_null(ap, "ya no es una estatua")
	if ap == null:
		return
	for clip in ["apuntando", "derrotado", "correr_herido"]:
		assert_true(ap.has_animation(clip), "trae '%s'" % clip)


func test_esta_de_pie_y_conserva_su_estatura() -> void:
	# El riggeado de AccuRig lo devolvió TUMBADO —su altura corría por Z— y
	# midiendo 1,93 m. En la quebrada eso es un gigante acostado.
	var n: Node3D = BRUJO.instantiate()
	add_child_autofree(n)
	await wait_frames(3)
	assert_almost_eq(_estatura(n), 1.80, 0.06, "lo que medía de estatua")


## Se mide por el ESQUELETO: la caja que calcula Godot para una malla con huesos
## se infla con las animaciones —la del brujo daba 3,95 m— y no dice cuánto
## ocupa en pantalla.
func _estatura(n: Node) -> float:
	var e := _esqueleto(n)
	if e == null:
		return 0.0
	var top := -1e9
	var bajo := 1e9
	for i in e.get_bone_count():
		var y: float = e.get_bone_global_rest(i).origin.y
		top = maxf(top, y)
		bajo = minf(bajo, y)
	return (top - bajo) * e.global_transform.basis.get_scale().y


func _esqueleto(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for h in n.get_children():
		var x := _esqueleto(h)
		if x != null:
			return x
	return null


# ─── Hacia dónde huye ────────────────────────────────────────────────────────

func test_huye_hacia_la_entrada_de_la_quebrada() -> void:
	var z := _zona()
	var entrada := Marker3D.new()
	entrada.name = "PlayerSpawn"
	z.add_child(entrada)
	entrada.position = Vector3(0, 0, 11.4)      # como en la escena de verdad
	var b := Node3D.new()
	z.add_child(b)
	b.position = Vector3(7.6, 1.0, -25.5)       # el sitio del brujo
	z.set("_brujo", b)

	var rumbo: Vector3 = z.call("_rumbo_de_huida")
	assert_almost_eq(rumbo.length(), 1.0, 0.01, "es una dirección, no un vector cualquiera")
	assert_almost_eq(rumbo.y, 0.0, 0.001, "sin subir ni bajar")
	assert_gt(rumbo.z, 0.8, "sale hacia la entrada, que está en +Z")


func test_un_marcador_manda_sobre_la_entrada() -> void:
	var z := _zona()
	var entrada := Marker3D.new()
	entrada.name = "PlayerSpawn"
	z.add_child(entrada)
	entrada.position = Vector3(0, 0, 11.4)
	var meta := Marker3D.new()
	meta.name = "PorAqui"
	z.add_child(meta)
	meta.position = Vector3(-40, 0, -25.5)      # al oeste, no a la entrada
	var b := Node3D.new()
	z.add_child(b)
	b.position = Vector3(7.6, 1.0, -25.5)
	z.set("_brujo", b)
	z.set("salida_del_brujo", NodePath("PorAqui"))

	var rumbo: Vector3 = z.call("_rumbo_de_huida")
	assert_lt(rumbo.x, -0.9, "si pusiste marcador, va hacia el marcador")


# ─── Cómo queda mirando ──────────────────────────────────────────────────────

func test_corre_de_frente_no_de_espaldas() -> void:
	var z := _zona()
	var b := Node3D.new()
	z.add_child(b)
	# El frente del rig es +Z: medido del talón a los dedos sobre el esqueleto.
	z.call("_orientar", b, Vector3(0, 0, 1))
	var frente: Vector3 = b.global_transform.basis.z
	assert_gt(frente.dot(Vector3(0, 0, 1)), 0.9,
		"su frente apunta adonde corre")


func test_el_giro_es_ajustable() -> void:
	var z := _zona()
	assert_almost_eq(float(z.get("brujo_giro")), 0.0, 0.01,
		"sin giro extra: el frente del rig ya es +Z, medido del talón a los dedos")


func test_lo_que_dura_cada_clip() -> void:
	var z := _zona()
	var b: Node3D = BRUJO.instantiate()
	z.add_child(b)
	z.set("_brujo", b)
	var t: float = z.call("_clip", b, "apuntando", false)
	assert_gt(t, 0.5, "apuntando dura algo")
	var ap := _animador(b)
	assert_eq(ap.assigned_animation, "apuntando")
	assert_eq(ap.get_animation("apuntando").loop_mode, Animation.LOOP_NONE,
		"apuntar se hace una vez")
	z.call("_clip", b, "correr_herido", true)
	assert_eq(ap.get_animation("correr_herido").loop_mode, Animation.LOOP_LINEAR,
		"correr se repite mientras huye")


func test_un_clip_que_no_existe_no_rompe_nada() -> void:
	var z := _zona()
	var b: Node3D = BRUJO.instantiate()
	z.add_child(b)
	assert_eq(float(z.call("_clip", b, "bailar_cueca", false)), 0.0)
