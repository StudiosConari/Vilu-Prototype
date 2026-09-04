extends "res://addons/gut/test.gd"

## La gente de la plaza de La Tirana, ya con esqueleto.
##
## Eran estatuas: seis modelos sueltos plantados en la plaza. Volvieron
## riggeados desde AccuRig con un clip cada uno; AccuRig, eso sí, se comió las
## texturas al exportar, así que el material se repuso desde el .glb original —
## la topología es la misma y las UV siguen valiendo. Estos tests vigilan las
## tres cosas que se pueden perder al rehacer un .glb: el esqueleto, el clip y
## la textura.

const BAILARIN := preload("res://scenes/actors/BailarinFiesta.gd")

## Cada modelo y el clip que le tocó.
const GENTE := {
	"chica_demonio": "idle",
	"chica_disfrazada": "bailar",
	"mascara_de_demonio": "bailar",
	"mascara_de_dragon": "bailar",
	"nativo_americano": "ritual",
	"nino_diablo_rojo": "descansar",
}

## Los cuatro que llevan encima un cuerpo de interacción: con ésos se habla, así
## que se quedan de pie en vez de bailar.
##
## La primera vuelta se hizo prestándoles el idle de chica_demonio, el único que
## había vuelto de AccuRig con uno, y retargeteándolo. Salió mal: copiar la
## orientación de MUNDO de cada hueso transfiere la POSTURA del origen y no su
## movimiento, así que los cuatro heredaban la columna del otro y quedaban
## encorvados. De frente no se notaba; de perfil, que es como se los ve en la
## plaza, saltaba a la vista. Ahora cada uno trae su propio idle, sacado por
## AccuRig sobre su propio rig, y no hay nada que retargetear.
const QUIETOS := ["chica_disfrazada8", "mascara_de_demonio3",
	"mascara_de_dragon3", "nativo_americano3"]

## Y los modelos que llevan ese idle.
const CON_IDLE := ["chica_disfrazada", "mascara_de_demonio",
	"mascara_de_dragon", "nativo_americano"]

## Lo que mide cada uno dentro del archivo. Se conservó a propósito el alto del
## modelo viejo: las escalas de la plaza están puestas a mano en World.tscn y si
## el modelo cambia de tamaño hay que recolocarlos a todos.
const ALTO := {
	"chica_demonio": 1.70, "chica_disfrazada": 1.65,
	"mascara_de_demonio": 1.70, "mascara_de_dragon": 1.70,
	"nativo_americano": 1.70, "nino_diablo_rojo": 1.30,
}


func _modelo(n: String) -> Node3D:
	var esc: PackedScene = load("res://models/focal/%s.glb" % n)
	assert_not_null(esc, "carga %s.glb" % n)
	if esc == null:
		return null
	var r: Node3D = esc.instantiate()
	add_child_autofree(r)
	return r


func _buscar(n: Node, clase: String) -> Node:
	if n.is_class(clase):
		return n
	for h in n.get_children():
		var x := _buscar(h, clase)
		if x != null:
			return x
	return null


func test_todos_traen_esqueleto_y_su_clip() -> void:
	for n in GENTE:
		var r := _modelo(n)
		if r == null:
			continue
		var esq: Skeleton3D = _buscar(r, "Skeleton3D")
		assert_not_null(esq, "%s viene riggeado" % n)
		if esq != null:
			assert_gt(esq.get_bone_count(), 50, "%s: el esqueleto está entero" % n)
		var ap: AnimationPlayer = _buscar(r, "AnimationPlayer")
		assert_not_null(ap, "%s trae AnimationPlayer" % n)
		if ap != null:
			assert_true(ap.has_animation(GENTE[n]),
				"%s trae el clip '%s' (tiene %s)" % [n, GENTE[n], ap.get_animation_list()])


## AccuRig devolvió las mallas SIN textura: las carpetas que crea quedaron
## vacías. Si alguien rehace un .glb y se salta el paso de reponer el material,
## la plaza se llena de gente gris y esto lo dice antes.
func test_no_perdieron_la_textura() -> void:
	for n in GENTE:
		var r := _modelo(n)
		if r == null:
			continue
		var mi: MeshInstance3D = _buscar(r, "MeshInstance3D")
		assert_not_null(mi, "%s tiene malla visible" % n)
		if mi == null or mi.mesh == null:
			continue
		var mat := mi.mesh.surface_get_material(0) as BaseMaterial3D
		assert_not_null(mat, "%s: la malla lleva material" % n)
		if mat != null:
			assert_not_null(mat.albedo_texture, "%s: y el material lleva su textura" % n)


func test_conservan_el_alto_de_antes() -> void:
	for n in GENTE:
		var r := _modelo(n)
		if r == null:
			continue
		var mi: MeshInstance3D = _buscar(r, "MeshInstance3D")
		if mi == null:
			continue
		# El AABB de una malla con huesos se infla un poco para dar sitio a la
		# pose, así que se compara con holgura.
		assert_almost_eq(mi.get_aabb().size.y, float(ALTO[n]), 0.12,
			"%s sigue midiendo lo que medía" % n)


## La colisión venía en una malla `-convcolonly`, que se había quitado para
## mandarlos a riggear. Sin ella se puede caminar a través de la gente.
func test_siguen_teniendo_cuerpo() -> void:
	for n in GENTE:
		var r := _modelo(n)
		if r == null:
			continue
		assert_not_null(_buscar(r, "StaticBody3D"), "%s conserva su colisión" % n)


func test_el_script_los_pone_a_bailar_en_bucle() -> void:
	var r := _modelo("chica_disfrazada")
	if r == null:
		return
	r.set_script(BAILARIN)
	r._ready()
	var ap: AnimationPlayer = _buscar(r, "AnimationPlayer")
	assert_true(ap.is_playing(), "arranca solo")
	assert_eq(ap.current_animation, "bailar")
	assert_eq(ap.get_animation("bailar").loop_mode, Animation.LOOP_LINEAR,
		"y en bucle: si no, se congela al terminar el clip")


## Tres de los seis comparten el mismo baile. Arrancando todos del cuadro cero
## la plaza se movería como un espejo.
func test_los_que_comparten_baile_no_van_sincronizados() -> void:
	var puntos := {}
	for n in ["chica_disfrazada", "mascara_de_demonio", "mascara_de_dragon"]:
		var r := _modelo(n)
		if r == null:
			continue
		r.name = n + "2"           # el nombre que llevan en World.tscn
		r.set_script(BAILARIN)
		r._ready()
		var ap: AnimationPlayer = _buscar(r, "AnimationPlayer")
		puntos[n] = ap.current_animation_position
	assert_eq(puntos.size(), 3)
	var vistos: Array = puntos.values()
	for i in vistos.size():
		for j in range(i + 1, vistos.size()):
			assert_gt(absf(float(vistos[i]) - float(vistos[j])), 0.5,
				"entran por puntos distintos del clip (%s)" % str(puntos))


## Y el desfase tiene que ser SIEMPRE el mismo: sale del nombre del nodo, no de
## un azar, para que la fiesta se vea igual en cada partida.
func test_el_desfase_es_estable() -> void:
	var pos := []
	for i in 2:
		# Cada copia bajo su propio padre: dos hermanos no pueden llamarse
		# igual, y Godot le cambiaría el nombre al segundo — que es justo de
		# donde sale el desfase.
		var sitio := Node3D.new()
		add_child_autofree(sitio)
		var esc: PackedScene = load("res://models/focal/mascara_de_dragon.glb")
		var r: Node3D = esc.instantiate()
		sitio.add_child(r)
		r.name = "mascara_de_dragon2"
		r.set_script(BAILARIN)
		r._ready()
		pos.append(_buscar(r, "AnimationPlayer").current_animation_position)
	assert_almost_eq(float(pos[0]), float(pos[1]), 0.001,
		"el mismo nodo entra siempre por el mismo sitio")


func test_los_que_dan_pistas_traen_su_idle() -> void:
	for n in CON_IDLE:
		var r := _modelo(n)
		if r == null:
			continue
		var ap: AnimationPlayer = _buscar(r, "AnimationPlayer")
		assert_not_null(ap)
		if ap == null:
			continue
		assert_true(ap.has_animation("idle"),
			"%s trae su idle (tiene %s)" % [n, ap.get_animation_list()])
		assert_gt(ap.get_animation("idle").length, 5.0,
			"%s: y es el clip entero, no un cuadro suelto" % n)
		assert_true(ap.has_animation(GENTE[n]),
			"%s: sin perder el suyo al añadirlo" % n)


func test_quieto_elige_el_idle_y_bailando_el_clip_propio() -> void:
	for n in CON_IDLE:
		var r := _modelo(n)
		if r == null:
			continue
		r.set_script(BAILARIN)
		r.quieto = true
		r._ready()
		var ap: AnimationPlayer = _buscar(r, "AnimationPlayer")
		assert_eq(ap.current_animation, "idle", "%s quieto: de pie" % n)

		var b := _modelo(n)
		b.name = n + "_bailando"
		b.set_script(BAILARIN)
		b._ready()
		var ap2: AnimationPlayer = _buscar(b, "AnimationPlayer")
		assert_eq(ap2.current_animation, GENTE[n],
			"%s sin quieto: su propio clip, no el idle prestado" % n)


## nativo_americano es el caso que se escapa solo: la lista de clips llega
## ordenada alfabéticamente y su "idle" prestado se cuela por delante de su
## "ritual". Quedarse con el primero de la lista lo dejaría quieto sin pedirlo.
func test_el_orden_alfabetico_no_le_roba_el_clip_al_nativo() -> void:
	var r := _modelo("nativo_americano")
	if r == null:
		return
	var ap: AnimationPlayer = _buscar(r, "AnimationPlayer")
	var lista := ap.get_animation_list()
	assert_eq(String(lista[0]), "idle",
		"el idle va primero en la lista: por eso hace falta elegir a mano")
	r.set_script(BAILARIN)
	r._ready()
	assert_eq(ap.current_animation, "ritual", "y aun así baila lo suyo")


func test_la_plaza_deja_quietos_a_los_que_dan_pistas() -> void:
	var esc: PackedScene = load("res://scenes/core/World.tscn")
	assert_not_null(esc)
	if esc == null:
		return
	var st: SceneState = esc.get_state()
	var vistos := {}
	for i in st.get_node_count():
		var nombre := String(st.get_node_name(i))
		for p in st.get_node_property_count(i):
			if String(st.get_node_property_name(i, p)) == "quieto":
				vistos[nombre] = bool(st.get_node_property_value(i, p))
	for n in QUIETOS:
		assert_true(vistos.get(n, false),
			"'%s' lleva un cuerpo de interacción encima: no puede estar bailando" % n)


## El casco del .glb es la silueta entera: falda, cuernos y todo. Medido, el de
## chica_disfrazada ocupa 1,02 m de ancho, y con la escala de la plaza se va a
## 1,35 — entre dos bailarines separados 1,4 m no queda por dónde pasar.
func test_la_colision_es_estrecha_y_se_puede_pasar_entre_ellos() -> void:
	const ANCHO_DEL_CASCO := 1.02      # lo que medía el casco del .glb
	const SEPARACION := 1.4            # lo que hay entre dos filas de la plaza
	const RADIO_JUGADOR := 0.35
	const ESCALA := 1.32               # la que llevan en World.tscn

	var r := _modelo("chica_disfrazada")
	if r == null:
		return
	r.set_script(BAILARIN)
	r._ready()
	var cs: CollisionShape3D = _buscar(_buscar(r, "StaticBody3D"), "CollisionShape3D")
	assert_not_null(cs, "conserva su cuerpo de colisión")
	if cs == null:
		return
	var cap := cs.shape as CapsuleShape3D
	assert_not_null(cap, "…pero con una cápsula, no con la silueta del modelo")
	if cap == null:
		return
	assert_lt(cap.radius * 2.0, ANCHO_DEL_CASCO * 0.5,
		"y es menos de la mitad de ancha que el casco de antes")

	var hueco: float = SEPARACION - cap.radius * 2.0 * ESCALA
	assert_gt(hueco, RADIO_JUGADOR * 2.0,
		"queda hueco para el jugador entre dos bailarines (%.2f m para %.2f)"
		% [hueco, RADIO_JUGADOR * 2.0])


## La malla del .glb es FIJA: el bailarín se sale de ella en cuanto se mueve.
func test_la_colision_sigue_el_baile() -> void:
	var r := _modelo("chica_disfrazada")
	if r == null:
		return
	r.set_script(BAILARIN)
	r._ready()
	var cuerpo: StaticBody3D = _buscar(r, "StaticBody3D")
	var ap: AnimationPlayer = _buscar(r, "AnimationPlayer")
	assert_not_null(cuerpo)
	assert_not_null(ap)
	if cuerpo == null or ap == null:
		return

	var donde := []
	for t in [0.0, 2.5]:
		ap.seek(float(t), true)
		await wait_frames(2)
		r._process(0.0)
		donde.append(cuerpo.position)
	assert_gt((donde[0] as Vector3).distance_to(donde[1]), 0.02,
		"la cápsula acompaña a la cadera (%s -> %s)" % [donde[0], donde[1]])


## Godot no sabe representar una cápsula con escala no uniforme: la aproxima y
## avisa. Tres de los de la plaza vienen con un eje estirado a mano.
func test_la_capsula_queda_con_escala_uniforme() -> void:
	var sitio := Node3D.new()
	add_child_autofree(sitio)
	sitio.scale = Vector3(1.34, 1.34, 1.58)      # la de mascara_de_demonio3

	var esc: PackedScene = load("res://models/focal/mascara_de_demonio.glb")
	var r: Node3D = esc.instantiate()
	sitio.add_child(r)
	r.set_script(BAILARIN)
	r._ready()

	var cuerpo: Node3D = _buscar(r, "StaticBody3D")
	assert_not_null(cuerpo)
	if cuerpo == null:
		return
	var e: Vector3 = cuerpo.global_transform.basis.get_scale()
	assert_almost_eq(e.x, e.y, 0.01, "la cápsula acaba con escala uniforme")
	assert_almost_eq(e.y, e.z, 0.01)


## Y que estén enganchados de verdad en la plaza, no sólo que el script exista.
func test_la_plaza_los_tiene_enganchados() -> void:
	var esc: PackedScene = load("res://scenes/core/World.tscn")
	assert_not_null(esc)
	if esc == null:
		return
	var st: SceneState = esc.get_state()
	var con_script := {}
	for i in st.get_node_count():
		var nombre := String(st.get_node_name(i))
		for prop in st.get_node_property_count(i):
			if String(st.get_node_property_name(i, prop)) != "script":
				continue
			var v = st.get_node_property_value(i, prop)
			if v is Script and (v as Script).resource_path.ends_with("BailarinFiesta.gd"):
				con_script[nombre] = true
	for n in GENTE:
		assert_true(con_script.has(n + "2"),
			"'%s2' lleva el script que lo anima" % n)
