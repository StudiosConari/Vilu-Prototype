extends GutTest

## La ocultista sentada en el bar.
##
## Sigue en su taburete mientras el segundo talismán no se entregue. Al
## entregarlo se levanta con `sentada_a_de_pie` y se va caminando.

const POBLADO := preload("res://scenes/actors/PobladoHub.gd")
const MUJER := preload("res://models/personaje/ocultista_mujer.glb")


func before_each() -> void:
	GameManager.reset_progress()


func after_all() -> void:
	GameManager.reset_progress()


func _poblado() -> Node3D:
	var p := Node3D.new()
	p.set_script(POBLADO)
	# El _ready de verdad construye el pueblo entero; acá sólo se le piden los
	# métodos de la ocultista, así que NO se mete en el árbol por su cuenta.
	p.set("geometria_fijada", true)
	add_child_autofree(p)
	return p


func _animador(n: Node) -> AnimationPlayer:
	for h in n.get_children():
		if h is AnimationPlayer:
			return h
		var x := _animador(h)
		if x != null:
			return x
	return null


func _montar(p: Node3D) -> Node3D:
	var m: Node3D = MUJER.instantiate()
	m.name = "ocultista_mujer2"
	p.add_child(m)
	m.global_position = Vector3(10, 0, -4)      # el taburete, junto a la barra
	var meta := Marker3D.new()
	meta.name = "PorAlla"
	p.add_child(meta)
	meta.global_position = Vector3(24, 0, -4)
	p.set("destino_de_la_ocultista", NodePath("PorAlla"))
	return m


# ─── El modelo ───────────────────────────────────────────────────────────────

func test_trae_sus_cuatro_clips() -> void:
	var n: Node = MUJER.instantiate()
	add_child_autofree(n)
	var ap := _animador(n)
	for c in ["sentada_hablando", "sentada_a_de_pie", "caminando", "corriendo"]:
		assert_true(ap.has_animation(c), "trae '%s'" % c)


func test_esta_de_pie_y_mide_lo_que_debe() -> void:
	# Dos cosas que salieron mal al convertirla y no se ven en un número suelto:
	# venía TUMBADA —su altura corría por Z— y medía 2,28 m.
	var n: Node3D = MUJER.instantiate()
	add_child_autofree(n)
	await wait_frames(3)
	assert_almost_eq(_estatura(n), 1.68, 0.06, "la estatura del modelo del pipeline")


## La estatura se mide por el ESQUELETO, no por la caja de la malla: la caja que
## calcula Godot para una malla con huesos se infla con las animaciones —la suya
## daba 5,44 m— y no sirve para saber cuánto ocupa en pantalla.
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


# ─── Sentada hasta que entregues ─────────────────────────────────────────────

func test_arranca_sentada() -> void:
	var p := _poblado()
	var m := _montar(p)
	p.call("_montar_a_la_ocultista")
	assert_eq(_animador(m).assigned_animation, "sentada_hablando",
		"en su taburete, hablando")
	assert_almost_eq(m.global_position.x, 10.0, 0.01, "sin moverse del sitio")


func test_al_entregar_los_talismanes_se_levanta_y_se_va() -> void:
	var p := _poblado()
	var m := _montar(p)
	p.call("_montar_a_la_ocultista")

	GameManager.conceder("talisman_2")
	await wait_frames(2)
	assert_eq(_animador(m).assigned_animation, "sentada_a_de_pie", "se levanta")

	# Se espera A QUE PASE, con margen, en vez de justo lo que dura el clip: el
	# largo que reporta Godot y el que da Blender no coinciden, y clavar el
	# tiempo hace que el test falle por un cuarto de segundo.
	var ap := _animador(m)
	var esperado := ap.get_animation("sentada_a_de_pie").length + 3.0
	var t := 0.0
	while t < esperado and ap.assigned_animation != "caminando":
		await wait_seconds(0.2)
		t += 0.2
	assert_eq(ap.assigned_animation, "caminando", "y se va andando")
	assert_gt(m.global_transform.basis.z.x, 0.9, "mirando adonde camina")


func test_otro_logro_no_la_levanta() -> void:
	var p := _poblado()
	var m := _montar(p)
	p.call("_montar_a_la_ocultista")
	GameManager.conceder("mina")
	await wait_frames(2)
	assert_eq(_animador(m).assigned_animation, "sentada_hablando",
		"sigue sentada: no es su señal")


# ─── Si volvés después ───────────────────────────────────────────────────────

func test_si_ya_lo_entregaste_esta_de_pie_en_su_destino() -> void:
	# El bar y la bruja pueden estar en regiones distintas, así que lo normal es
	# que la entrega pase con este mundo descargado.
	GameManager.conceder("talisman_2")
	var p := _poblado()
	var m := _montar(p)
	p.call("_montar_a_la_ocultista")
	assert_almost_eq(m.global_position.x, 24.0, 0.1, "ya se fue adonde iba")
	var ap := _animador(m)
	assert_false(ap.is_playing(), "quieta")
	assert_almost_eq(ap.current_animation_position,
		ap.get_animation("sentada_a_de_pie").length, 0.05,
		"de pie: el último fotograma de levantarse, no a media zancada")


# ─── Puesta de verdad en el mundo ────────────────────────────────────────────
#
# Todo lo de arriba la monta a mano, y por eso nadie se dio cuenta de que en el
# juego no estaba: el código la buscaba y no la encontraba nunca. Esto mira el
# archivo del mundo, que es donde tiene que estar.

const ATACAMA := "res://scenes/core/WorldAtacama.tscn"
const PATAGONIA := "res://scenes/core/World.tscn"


func _nombres(ruta: String) -> Array:
	var st := (load(ruta) as PackedScene).get_state()
	var xs: Array = []
	for i in st.get_node_count():
		xs.append(String(st.get_node_name(i)))
	return xs


func _propiedad(ruta: String, nodo: String, prop: String) -> Variant:
	var st := (load(ruta) as PackedScene).get_state()
	for i in st.get_node_count():
		if String(st.get_node_name(i)) != nodo:
			continue
		for j in st.get_node_property_count(i):
			if String(st.get_node_property_name(i, j)) == prop:
				return st.get_node_property_value(i, j)
	return null


func test_esta_puesta_en_el_bar_de_atacama() -> void:
	var hay := _nombres(ATACAMA).any(func(n: String) -> bool:
		return n.begins_with("ocultista_mujer"))
	assert_true(hay, "el modelo colocado en WorldAtacama")


func test_tiene_adonde_ir() -> void:
	var meta: Variant = _propiedad(ATACAMA, "Poblado", "destino_de_la_ocultista")
	assert_not_null(meta, "el Poblado sabe adónde camina")
	var nombre := String(meta).get_file()
	assert_true(_nombres(ATACAMA).has(nombre), "y ese destino existe: '%s'" % nombre)


func test_solo_en_atacama() -> void:
	var hay := _nombres(PATAGONIA).any(func(n: String) -> bool:
		return n.begins_with("ocultista_mujer"))
	assert_false(hay, "en el otro mundo no pinta nada")


func test_sin_ocultista_en_la_escena_no_pasa_nada() -> void:
	var p := _poblado()
	p.call("_montar_a_la_ocultista")
	assert_null(p.get("_ocultista_mujer"), "no se inventa una")
