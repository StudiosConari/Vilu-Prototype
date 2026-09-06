extends GutTest

## El Yastay y los guanacos, que eran estatuas del pipeline, ahora traen
## esqueleto y clips desde el .glb. Falta que alguien les dé al play: eso lo
## hace WorldRoot al montar el mundo.

const MUNDO := preload("res://scenes/core/WorldRoot.gd")
const YASTAY := preload("res://models/personaje/yastay.glb")
const GUANACO := preload("res://models/personaje/guanaco.glb")


func _mundo() -> Node3D:
	var m := Node3D.new()
	m.set_script(MUNDO)
	# Sin construir nada: sólo se le piden los recorridos.
	autofree(m)
	return m


func _animador(n: Node) -> AnimationPlayer:
	for h in n.get_children():
		if h is AnimationPlayer:
			return h
		var x := _animador(h)
		if x != null:
			return x
	return null


# ─── Lo que traen los modelos ────────────────────────────────────────────────

func test_el_yastay_ya_no_es_una_estatua() -> void:
	var n: Node = YASTAY.instantiate()
	add_child_autofree(n)
	var ap := _animador(n)
	assert_not_null(ap, "trae reproductor de animación")
	if ap == null:
		return
	for clip in ["Idle", "Walk", "Trot", "Rear", "Head_But"]:
		assert_true(ap.has_animation(clip), "trae el clip '%s'" % clip)


func test_el_guanaco_ya_no_es_una_estatua() -> void:
	var n: Node = GUANACO.instantiate()
	add_child_autofree(n)
	var ap := _animador(n)
	assert_not_null(ap, "trae reproductor de animación")
	if ap == null:
		return
	for clip in ["Idle", "Walk", "Run", "Kick", "Death", "lay_to_idle"]:
		assert_true(ap.has_animation(clip), "trae el clip '%s'" % clip)


func test_conservan_su_estatura() -> void:
	# El riggeado cambia el desdoblado de vértices, y si de paso cambiara la
	# escala tendríamos un Yastay de tres metros en mitad de la quebrada.
	for par in [[YASTAY, 2.20], [GUANACO, 1.60]]:
		var n: Node3D = (par[0] as PackedScene).instantiate()
		add_child_autofree(n)
		var caja := AABB()
		for mi: MeshInstance3D in _mallas(n):
			caja = caja.merge(mi.get_aabb()) if caja.size != Vector3.ZERO else mi.get_aabb()
		assert_almost_eq(caja.size.y, float(par[1]), 0.05,
			"mide lo que medía de estatua")


func test_no_arrastran_la_esfera_de_accurig() -> void:
	# AccuRig cuela un 'Icosphere' que en Godot desplaza la caja de colisión.
	for esc in [YASTAY, GUANACO]:
		var n: Node = (esc as PackedScene).instantiate()
		add_child_autofree(n)
		for mi: MeshInstance3D in _mallas(n):
			assert_false(mi.name.to_lower().contains("icosphere"),
				"'%s' no debería estar" % mi.name)


func _mallas(n: Node) -> Array:
	var r: Array = []
	if n is MeshInstance3D:
		r.append(n)
	for h in n.get_children():
		r.append_array(_mallas(h))
	return r


# ─── Que WorldRoot los ponga en marcha ───────────────────────────────────────

func test_les_pone_el_bucle_de_reposo() -> void:
	var m := _mundo()
	add_child_autofree(m)
	var y: Node3D = YASTAY.instantiate()
	y.name = "yastay2"
	m.add_child(y)
	var g: Node3D = GUANACO.instantiate()
	g.name = "guanaco7"
	m.add_child(g)

	m.call("_animar_el_paisaje")

	for n in [y, g]:
		var ap := _animador(n)
		assert_eq(ap.assigned_animation, "Idle", "'%s' respira" % n.name)
		assert_eq(ap.get_animation("Idle").loop_mode, Animation.LOOP_LINEAR,
			"y en bucle, no una vez y se queda tieso")


func test_no_toca_lo_que_no_tiene_ese_clip() -> void:
	var m := _mundo()
	add_child_autofree(m)
	# El guanaco espiritual empieza igual por "guanaco" pero su único clip se
	# llama de otra forma: tiene que saltárselo sin romperse.
	var otro: Node3D = load("res://models/personaje/guanaco_espiritual.glb").instantiate()
	otro.name = "guanaco_espiritual1"
	m.add_child(otro)
	m.call("_animar_el_paisaje")
	var ap := _animador(otro)
	assert_ne(ap.assigned_animation, "Idle", "ni lo intenta")
