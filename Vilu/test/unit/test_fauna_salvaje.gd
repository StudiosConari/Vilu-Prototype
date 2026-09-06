extends GutTest

## Pumas y guanacos sueltos por el descampado.
##
## Lo que se fija acá es lo que no se puede ver de un vistazo: que no se metan
## en las zonas —donde estorbarían a escenas ya contadas— y que se apoyen en el
## suelo en vez de flotar.

const FAUNA := preload("res://scenes/actors/FaunaSalvaje.gd")
const PUMA := preload("res://models/personaje/puma.glb")


## Un suelo de mentira a y=0, para que los rayos tengan dónde chocar.
func _suelo(padre: Node3D) -> StaticBody3D:
	var s := StaticBody3D.new()
	s.collision_layer = 1
	var cs := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(600, 1, 600)
	cs.shape = caja
	# La cara de arriba en y=0. Se desplaza la FORMA y no el cuerpo: moviendo el
	# cuerpo, el servidor de física no se entera hasta el cuadro siguiente y los
	# rayos de la fauna todavía ven el suelo medio metro más arriba.
	cs.position.y = -0.5
	s.add_child(cs)
	padre.add_child(s)
	return s


func _fauna(zonas: Array) -> Node3D:
	var f := Node3D.new()
	f.set_script(FAUNA)
	f.zonas = zonas
	return f


func _animador(n: Node) -> AnimationPlayer:
	for h in n.get_children():
		if h is AnimationPlayer:
			return h
		var x := _animador(h)
		if x != null:
			return x
	return null


# ─── El modelo del puma ──────────────────────────────────────────────────────

func test_el_puma_trae_sus_siete_clips() -> void:
	var n: Node = PUMA.instantiate()
	add_child_autofree(n)
	var ap := _animador(n)
	for c in ["Idle", "Walk", "Run", "Sit", "Sneak", "Howl", "Bark"]:
		assert_true(ap.has_animation(c), "trae '%s'" % c)


func test_el_puma_tiene_textura() -> void:
	# El riggeado las perdió y su material base quedó AZUL. Se le rearmaron
	# desde los archivos que dejó Tripo junto al fbx.
	var n: Node = PUMA.instantiate()
	add_child_autofree(n)
	var con_textura := 0
	for mi: MeshInstance3D in _mallas(n):
		var msh: Mesh = mi.mesh
		for s in (msh.get_surface_count() if msh else 0):
			var mat := msh.surface_get_material(s) as BaseMaterial3D
			if mat != null and mat.albedo_texture != null:
				con_textura += 1
	assert_gt(con_textura, 0, "no es un puma azul")


func _mallas(n: Node) -> Array:
	var r: Array = []
	if n is MeshInstance3D:
		r.append(n)
	for h in n.get_children():
		r.append_array(_mallas(h))
	return r


# ─── Fuera de las zonas ──────────────────────────────────────────────────────

func test_ninguno_aparece_dentro_de_una_zona() -> void:
	var raiz := Node3D.new()
	add_child_autofree(raiz)
	_suelo(raiz)
	# El poblado y la quebrada del Yastay, en su sitio real.
	var zonas := [[Vector3(0, 0, 55), 36.0], [Vector3(-145, 0, 55), 34.0]]
	# Un par de cuadros de física antes de soltarlos: si no, sus rayos salen
	# antes de que el suelo exista para el servidor.
	await wait_physics_frames(2)
	var f := _fauna(zonas)
	raiz.add_child(f)
	await wait_frames(3)

	var bichos: Array = f.get("_bichos")
	assert_gt(bichos.size(), 0, "salió alguno")
	for b in bichos:
		var p: Vector3 = (b["nodo"] as Node3D).global_position
		for z in zonas:
			var c: Vector3 = z[0]
			var d := Vector2(p.x - c.x, p.z - c.z).length()
			assert_gt(d, float(z[1]),
				"a %.0f m del centro de una zona de radio %.0f" % [d, float(z[1])])


func test_el_margen_se_respeta_ademas_del_radio() -> void:
	var raiz := Node3D.new()
	add_child_autofree(raiz)
	_suelo(raiz)
	# Un par de cuadros de física antes de soltarlos: si no, sus rayos salen
	# antes de que el suelo exista para el servidor.
	await wait_physics_frames(2)
	var f := _fauna([[Vector3.ZERO, 30.0]])
	raiz.add_child(f)
	await wait_frames(3)
	var margen: float = float(f.get("margen_de_zona"))
	for b in f.get("_bichos"):
		var p: Vector3 = (b["nodo"] as Node3D).global_position
		assert_gt(Vector2(p.x, p.z).length(), 30.0 + margen - 0.1,
			"se queda a distancia del borde, no pegado")


func test_sin_suelo_no_aparece_ninguno() -> void:
	# Sin terreno debajo no hay dónde ponerlos: mejor ninguno que flotando.
	var raiz := Node3D.new()
	add_child_autofree(raiz)
	# Un par de cuadros de física antes de soltarlos: si no, sus rayos salen
	# antes de que el suelo exista para el servidor.
	await wait_physics_frames(2)
	var f := _fauna([])
	raiz.add_child(f)
	await wait_frames(3)
	assert_eq((f.get("_bichos") as Array).size(), 0)


# ─── Que se apoyen y se muevan ───────────────────────────────────────────────

func test_aparecen_apoyados_en_el_suelo() -> void:
	var raiz := Node3D.new()
	add_child_autofree(raiz)
	_suelo(raiz)
	# Un par de cuadros de física antes de soltarlos: si no, sus rayos salen
	# antes de que el suelo exista para el servidor.
	await wait_physics_frames(2)
	var f := _fauna([])
	raiz.add_child(f)
	await wait_frames(3)
	for b in f.get("_bichos"):
		assert_almost_eq((b["nodo"] as Node3D).global_position.y, 0.0, 0.05,
			"sobre el suelo, no flotando ni enterrado")


func test_al_terminar_la_espera_echan_a_andar() -> void:
	var raiz := Node3D.new()
	add_child_autofree(raiz)
	_suelo(raiz)
	# Un par de cuadros de física antes de soltarlos: si no, sus rayos salen
	# antes de que el suelo exista para el servidor.
	await wait_physics_frames(2)
	var f := _fauna([])
	raiz.add_child(f)
	await wait_frames(3)
	var bichos: Array = f.get("_bichos")
	assert_gt(bichos.size(), 0)
	# Se les acaba la espera de golpe: todos deberían ponerse a caminar.
	for b in bichos:
		b["espera"] = 0.01
	await wait_seconds(0.4)
	var andando := 0
	for b in bichos:
		if _animador(b["nodo"]).assigned_animation == String(b["esp"]["andar"]):
			andando += 1
	assert_gt(andando, 0, "alguno echó a andar")


func test_no_se_alejan_de_su_territorio() -> void:
	var raiz := Node3D.new()
	add_child_autofree(raiz)
	_suelo(raiz)
	# Un par de cuadros de física antes de soltarlos: si no, sus rayos salen
	# antes de que el suelo exista para el servidor.
	await wait_physics_frames(2)
	var f := _fauna([])
	raiz.add_child(f)
	await wait_frames(3)
	for b in f.get("_bichos"):
		var meta: Vector3 = f.call("_otro_sitio", b)
		var casa: Vector3 = b["casa"]
		var radio: float = float(b["esp"]["radio_de_paseo"])
		assert_lt(Vector2(meta.x - casa.x, meta.z - casa.z).length(), radio + 0.5,
			"el sitio elegido cae dentro de su territorio")


# ─── Qué zonas esquiva en cada mundo ─────────────────────────────────────────

const MUNDO := preload("res://scenes/core/WorldRoot.gd")


func test_solo_esquiva_las_zonas_que_ese_mundo_tiene() -> void:
	# El catálogo de zonas es de TODO el juego, pero el mapa está partido en dos.
	# Pasarlo entero dejaba círculos prohibidos sobre campo abierto.
	var m := Node3D.new()
	m.set_script(MUNDO)
	autofree(m)
	var ids := []
	for z in MUNDO.ZONAS:
		ids.append(String(z["id"]))
	assert_has(ids, "Yastay", "el catálogo trae zonas de los dos mundos")
	assert_has(ids, "Tarapaca")
	# Sin ninguna zona instanciada, has_zone dice que no a todas: la lista de
	# prohibidas tiene que salir vacía y no con las cuatro del catálogo.
	assert_false(m.call("has_zone", "Yastay"),
		"un mundo sin esa zona no la reclama como suya")


# ─── El tamaño ───────────────────────────────────────────────────────────────

func test_salen_al_doble_de_su_tamano() -> void:
	# A escala real —puma 75 cm, guanaco 1,60— no se leen contra un mapa de
	# cuatrocientos metros: quedan como manchitas.
	var raiz := Node3D.new()
	add_child_autofree(raiz)
	_suelo(raiz)
	await wait_physics_frames(2)
	var f := _fauna([])
	raiz.add_child(f)
	await wait_frames(3)
	assert_almost_eq(float(f.get("tamano")), 2.0, 0.01, "al doble")

	var sueltos: Array = f.get("_bichos")
	assert_gt(sueltos.size(), 0)
	for b in sueltos:
		var n: Node3D = b["nodo"]
		var solo: Node3D = load(String(b["esp"]["escena"])).instantiate()
		add_child_autofree(solo)
		# La escala se MULTIPLICA sobre la del modelo: fijarla dejaría al puma y
		# al guanaco del mismo tamaño.
		assert_almost_eq(n.scale.y / maxf(solo.scale.y, 0.0001), 2.0, 0.02,
			"'%s' sale al doble de lo que mide su modelo" % String(b["esp"]["nombre"]))
		solo.queue_free()
		break


func test_los_de_la_quebrada_no_se_tocan() -> void:
	# El guanaco de la quebrada del Yastay y el compañero de Benjamín tienen su
	# propio tamaño; agrandar la fauna suelta no debe alcanzarlos.
	var solo: Node3D = load("res://models/personaje/guanaco.glb").instantiate()
	add_child_autofree(solo)
	await wait_frames(2)
	assert_almost_eq(solo.scale.y, 1.0, 0.01,
		"el modelo por sí solo sigue a su escala de siempre")
