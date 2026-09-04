extends "res://addons/gut/test.gd"

## Carmen, que es La Tirana, y su cambio de traje.
##
## Empieza de guía del museo, de calle. Al hablarle se mete a la iglesia con la
## cámara detrás y vuelve a aparecer bailando entre los bailarines, ya con el
## vestido de la fiesta. Es el MISMO nodo con otro modelo: el diálogo de la
## revelación —el que entrega el arco y abre el beat 2— sigue colgando de quien
## siempre colgó, y eso es justo lo que estos tests vigilan.

const CARMEN := preload("res://scenes/actors/Carmen.tscn")

## Lo que mide de verdad el traje de fiesta, con el esqueleto en reposo: el
## modelo entero ocupa 12,93 m y el gorro de diablada se lleva 2,4 de ésos.
const ALTO_DEL_ARCHIVO := 12.93
const ALTO_DEL_GORRO := 2.4


## Un doble de Game: sólo apunta qué se le pidió a la cámara.
class CamaraFalsa:
	extends Node
	var enfocados: Array = []
	var soltadas := 0

	func focus_camera_on(n: Node3D, _dur := 0.0, _dist := 0.0, _alto := 1.5) -> void:
		enfocados.append(n)

	func clear_camera_focus() -> void:
		soltadas += 1


class JugadorFalso:
	extends Node
	var input_locked := false


func after_all() -> void:
	GameManager.reset_progress()


func _carmen() -> Node3D:
	GameManager.reset_progress()
	var c: Node3D = CARMEN.instantiate()
	add_child_autofree(c)
	await wait_physics_frames(3)
	return c


func _mallas_de(c: Node3D) -> Array:
	var m: Node3D = c.get_node_or_null("Visual/Modelo")
	return c._mallas(m) if m != null else []


func test_lleva_su_modelo_y_esconde_la_capsula() -> void:
	var c := await _carmen()
	var m: Node3D = c.get_node_or_null("Visual/Modelo")
	assert_not_null(m, "Carmen monta su modelo")
	var capsula: MeshInstance3D = c.get_node_or_null("Visual/Placeholder")
	assert_not_null(capsula, "la cápsula sigue en la escena, por si hay que volver")
	if capsula != null:
		assert_false(capsula.visible, "…pero no se ve")


## Arranca de guía, no de bailarina: ése es el punto del cambio.
func test_arranca_vestida_de_guia_del_museo() -> void:
	var c := await _carmen()
	assert_eq(c._traje, "museo", "empieza con el traje de calle")
	assert_eq(c._clip_actual, "MUSEO_idle_movido", "y con su idle, quieta")
	assert_false(c._bailando, "la guía del museo no baila")
	assert_eq(c.clip_de("bailar"), "",
		"y no tiene con qué: su casilla de baile va vacía a propósito")


## Es `@tool` para poder colocarla en el editor viendo el modelo y no una
## cápsula verde. Eso obliga a que ponerle el traje NO le toque el transform:
## en el editor su posición sí se guarda en World.tscn, y moverla sola sería
## corromper la escena cada vez que se abre.
func test_ponerle_el_traje_no_la_mueve() -> void:
	var c := await _carmen()
	c.global_position = Vector3(3, 1, -7)
	var antes: Vector3 = c.global_position
	c._montar(c.modelo_tirana, "tirana")
	c._montar(c.modelo, "museo")
	assert_eq(c.global_position, antes, "cambiarse de ropa no la cambia de sitio")


## Escalar por el modelo ENTERO la dejaría a 1,4 m de cuerpo, porque el gorro de
## diablada se lleva casi la quinta parte del alto. Se mide el cuerpo y el gorro
## sube aparte. Se prueba sobre el traje de FIESTA, que es el que lleva gorro.
func test_se_escala_por_el_cuerpo_y_no_por_el_gorro() -> void:
	var c := await _carmen()
	c._montar(c.modelo_tirana, "tirana")
	var m: Node3D = c.get_node_or_null("Visual/Modelo")
	assert_not_null(m)
	if m == null:
		return
	var esperada: float = c.altura_visual / (ALTO_DEL_ARCHIVO - ALTO_DEL_GORRO)
	assert_almost_eq(m.scale.x, esperada, 0.02,
		"la escala sale del cuerpo (%.1f m), no de los %.1f del archivo"
		% [ALTO_DEL_ARCHIVO - ALTO_DEL_GORRO, ALTO_DEL_ARCHIVO])

	var por_el_total: float = c.altura_visual / ALTO_DEL_ARCHIVO
	assert_gt(m.scale.x, por_el_total * 1.1,
		"y es MAYOR que escalando por el total: si no, este test no probaría nada")


## Los clips que pide el guion tienen que existir en los DOS modelos. Si el
## artista renombra uno, esto lo dice antes de verlo en pantalla.
func test_estan_los_clips_de_los_dos_trajes() -> void:
	var c := await _carmen()
	for traje in ["museo", "tirana"]:
		c._montar(c.modelo if traje == "museo" else c.modelo_tirana, traje)
		assert_not_null(c._anim, "%s: encuentra el AnimationPlayer" % traje)
		if c._anim == null:
			continue
		for papel in ["idle", "caminar", "hablando", "bailar"]:
			var clip: String = c.clip_de(papel)
			if clip == "":
				continue   # la guía no baila: hueco a propósito
			assert_true(c._anim.has_animation(clip),
				"%s trae '%s' para '%s'" % [traje, clip, papel])


func test_cambia_de_animacion_segun_lo_que_hace() -> void:
	var c := await _carmen()
	c._montar(c.modelo_tirana, "tirana")
	c._bailando = true
	c._refrescar_animacion()
	assert_eq(c._clip_actual, "TIRANA3_bailar", "entre los bailarines, baila")

	c._walking = true
	c._refrescar_animacion()
	assert_eq(c._clip_actual, "TIRANA3_caminar", "yendo de un sitio a otro, camina")

	c._walking = false
	c._hablando = true
	c._refrescar_animacion()
	assert_eq(c._clip_actual, "TIRANA3_idle_hablando",
		"hablando para el baile: el idle con boca")


## El corazón del cambio: se va a la iglesia y vuelve de Tirana.
func test_al_hablarle_se_mete_a_la_iglesia_y_sale_bailando() -> void:
	var suelo := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(60, 1, 60)
	cs.shape = caja
	suelo.add_child(cs)
	add_child_autofree(suelo)
	suelo.global_position = Vector3(0, -0.5, 0)
	await wait_physics_frames(2)

	var camara := CamaraFalsa.new()
	add_child_autofree(camara)
	camara.add_to_group("game")
	var jugador := JugadorFalso.new()
	add_child_autofree(jugador)
	jugador.add_to_group("player")

	var puerta := Marker3D.new()
	add_child_autofree(puerta)
	puerta.global_position = Vector3(0, 0, -2.5)
	var pista := Marker3D.new()
	add_child_autofree(pista)
	pista.global_position = Vector3(8, 0, 4)

	var c := await _carmen()
	c.global_position = Vector3(0, 0.1, 0)
	c.puerta_iglesia = c.get_path_to(puerta)
	c.sitio_de_baile = c.get_path_to(pista)
	c.ritmo_escena = 0.05          # sin esto la escena dura sus cinco segundos
	await wait_physics_frames(2)

	assert_false(jugador.input_locked, "antes de la escena el jugador manda")
	await c._entrar_a_la_iglesia()

	assert_gt(camara.enfocados.size(), 1,
		"la cámara la enfoca al menos dos veces: yendo, y ya bailando")
	assert_eq(camara.soltadas, 1, "y al final se suelta y vuelve al jugador")
	assert_false(jugador.input_locked, "que recupera el control")

	assert_almost_eq(c.global_position.x, 8.0, 0.5, "acaba en la pista de baile")
	assert_almost_eq(c.global_position.z, 4.0, 0.5)
	assert_true(c.visible, "y se la ve: entró a la iglesia, no se borró")
	assert_eq(c._traje, "tirana", "sale con el vestido de la fiesta")
	assert_true(c._bailando)
	assert_eq(c._clip_actual, "TIRANA3_bailar", "bailando")


## Entre la plaza (0,23 m) y el atrio de la iglesia (1,00) hay un escalón de casi
## un metro. Con `move_and_slide` Carmen no lo subía: se quedaba raspando el
## borde hasta que saltaba el tope de la escena, y en pantalla parecía que
## entraba por una esquina cualquiera en vez de por la puerta.
func test_sube_el_escalon_de_la_iglesia() -> void:
	var suelo := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(40, 1, 40)
	cs.shape = caja
	suelo.add_child(cs)
	add_child_autofree(suelo)
	suelo.global_position = Vector3(0, -0.5, 0)      # cara de arriba en y = 0

	var atrio := StaticBody3D.new()
	var cs2 := CollisionShape3D.new()
	var caja2 := BoxShape3D.new()
	caja2.size = Vector3(8, 1, 8)
	cs2.shape = caja2
	atrio.add_child(cs2)
	add_child_autofree(atrio)
	atrio.global_position = Vector3(0, 0.5, -6)      # cara de arriba en y = 1
	await wait_physics_frames(2)

	var c := await _carmen()
	c.global_position = Vector3(0, 0.05, 0)
	await wait_physics_frames(2)
	await c._caminar_hasta(Vector3(0, 0, -6), 6.0)

	assert_almost_eq(c.global_position.z, -6.0, 0.4, "llega al destino")
	assert_almost_eq(c.global_position.y, 1.0, 0.2,
		"y encima del escalón, no atascada abajo")


## Caminaba de espaldas: `Visual` gira en coordenadas de Carmen y la dirección
## venía en las de mundo, y ella está media vuelta girada en la plaza.
func test_camina_mirando_hacia_donde_va() -> void:
	var c := await _carmen()
	c.global_rotation.y = PI            # como en World.tscn
	var dir := Vector3(1, 0, 0)
	for i in 80:
		c._mirar_hacia(dir, 0.2)        # deltas grandes: que converja
	var vis: Node3D = c.get_node("Visual")
	# El modelo mira hacia el -Z de Visual: `giro_modelo` ya lo dio la vuelta.
	var mira: Vector3 = -vis.global_transform.basis.z.normalized()
	assert_almost_eq(mira.dot(dir), 1.0, 0.05,
		"mira hacia donde camina (va hacia %s y mira a %s)" % [dir, mira])


## Volver a pulsar E mientras el globo está abierto encadenaba otra charla, y al
## cerrarse cada una lanzaba su propia ida a la iglesia: se veía entrar tres
## veces seguidas.
func test_no_se_le_puede_hablar_encima() -> void:
	var c := await _carmen()
	c._hablando = true
	c._on_interacted(null)
	assert_false(c._pending_walk, "hablando, otro [E] no encadena una charla más")

	c._hablando = false
	c._en_escena = true
	c._on_interacted(null)
	assert_false(c._pending_walk, "y durante la escena, tampoco")


func test_la_escena_no_se_solapa_consigo_misma() -> void:
	var camara := CamaraFalsa.new()
	add_child_autofree(camara)
	camara.add_to_group("game")
	var c := await _carmen()
	c._en_escena = true                 # como si ya estuviera corriendo
	c._entrar_a_la_iglesia()
	assert_eq(camara.enfocados.size(), 0,
		"una segunda llamada no vuelve a arrancar la escena")


## Un director de fiesta de mentira, sólo para contar pistas.
class DirectorFalso:
	extends Node
	var clues_given := 0


## El arco se entrega DESPUÉS de hablar con la gente del pueblo, no por
## acercarse a Carmen. Ésta es la puerta del don y no se puede aflojar.
func test_no_entrega_el_don_hasta_las_cuatro_pistas() -> void:
	var c := await _carmen()
	c._has_walked = true                    # ya se metió a la iglesia y volvió
	assert_eq(c.pistas(), 0, "sin director de fiesta, cero pistas")
	assert_eq(c.que_dice(), c.DIALOGUE_WAIT, "de entrada, que sigan explorando")

	var director := DirectorFalso.new()
	add_child_autofree(director)
	director.add_to_group("fiesta_director")
	for cuantas in [1, 2, 3]:
		director.clues_given = cuantas
		assert_eq(c.que_dice(), c.DIALOGUE_WAIT,
			"con %d pistas todavía no entrega nada" % cuantas)

	director.clues_given = c.PISTAS_PARA_EL_DON
	assert_eq(c.que_dice(), c.DIALOGUE_REVELACION,
		"con las cuatro, la revelación")

	# Y una vez dado, no lo vuelve a dar.
	GameManager.unlock("bow")
	assert_eq(c.que_dice(), c.DIALOGUE_AGAIN, "ya entregado, sólo la despedida")


## La primera charla no depende de las pistas: siempre manda a la iglesia.
func test_la_primera_charla_siempre_la_manda_a_la_iglesia() -> void:
	var c := await _carmen()
	assert_eq(c.que_dice(), c.DIALOGUE_FASE1)
	# Incluso con el arco ya dado por el menú de depuración.
	GameManager.unlock("bow")
	assert_eq(c.que_dice(), c.DIALOGUE_FASE1,
		"entrando por una parada tardía, la escena de la iglesia se ve igual")


## Lo que no se puede romper: la revelación entrega el arco y abre el beat 2.
## Ahora cuelga de un NPC que se cambió de ropa a mitad de camino, así que vale
## la pena comprobarlo entero.
func test_la_revelacion_sigue_entregando_el_arco() -> void:
	var c := await _carmen()
	c._has_walked = true
	c._ponerse_a_bailar()
	await wait_physics_frames(2)
	assert_false(GameManager.has_ability("bow"), "todavía no")

	c._pending_unlock = true
	c._on_dialogue_ended(null)
	assert_true(GameManager.has_ability("bow"), "La Tirana entrega el arco")
	assert_gte(GameManager.get_beat(), 2, "y abre el beat 2")
	assert_true(GameManager.tiene_logro("tirana"), "y concede su logro")


## Las capas de la cara van ordenadas A MANO, de atrás hacia delante.
##
## Ojos, pestañas y cejas son planos apilados a medio milímetro. A esa distancia
## la profundidad no decide de forma fiable, y la esclera acababa dibujándose
## DELANTE del iris: Carmen salía con los ojos en blanco. Se comprobó
## fotografiando la cara con el propio motor y escondiendo la esclera — el iris
## aparecía entero, o sea que el modelo estaba bien y lo que fallaba era quién
## tapaba a quién. Vale para los dos trajes: el arreglo se rehace al cambiarse.
func test_las_capas_de_la_cara_van_ordenadas() -> void:
	var c := await _carmen()
	for traje in ["museo", "tirana"]:
		c._montar(c.modelo if traje == "museo" else c.modelo_tirana, traje)
		var prio := {}
		for mi: MeshInstance3D in _mallas_de(c):
			var n := mi.name.to_lower()
			var mat := mi.get_surface_override_material(0) as BaseMaterial3D
			if mat == null:
				continue
			for clave in ["escler", "iris", "pupila", "pestana"]:
				if n.contains(clave):
					prio[clave] = mat.render_priority
					assert_eq(mat.depth_draw_mode, BaseMaterial3D.DEPTH_DRAW_DISABLED,
						"%s '%s' no escribe profundidad" % [traje, mi.name])

		for clave in ["escler", "iris", "pupila", "pestana"]:
			assert_true(prio.has(clave), "%s: está la capa '%s'" % [traje, clave])
		if prio.size() < 4:
			continue
		assert_lt(prio["escler"], prio["iris"], "%s: la esclera va DETRÁS del iris" % traje)
		assert_lt(prio["iris"], prio["pupila"], "%s: y el iris detrás de la pupila" % traje)
		assert_lt(prio["pupila"], prio["pestana"], "%s: las pestañas, encima" % traje)


## La piel no atraviesa la ropa, ni la boca la cabeza.
##
## El cuerpo y la ropa son mallas SEPARADAS y en algunos sitios ocupan el mismo
## sitio: asomaban manchas de piel por el hombro y el costado, y el interior de
## la boca se salía por la mejilla. No era transparencia —todas son opacas—,
## eran dos superficies pegadas.
func test_la_piel_no_atraviesa_la_ropa() -> void:
	var c := await _carmen()
	var m: Node3D = c.get_node_or_null("Visual/Modelo")
	assert_not_null(m)
	if m == null:
		return
	var vistas := 0
	for mi: MeshInstance3D in c._mallas(m):
		var n := mi.name.to_lower()
		var debajo := false
		for clave in c.POR_DEBAJO:
			if n.contains(String(clave)):
				debajo = true
		if not debajo:
			continue
		vistas += 1
		var mat := mi.get_surface_override_material(0) as BaseMaterial3D
		assert_not_null(mat, "'%s' lleva su propio material" % mi.name)
		if mat == null:
			continue
		assert_true(mat.grow, "'%s' se hunde" % mi.name)
		# `grow_amount` va en unidades de la MALLA, no en metros: el modelo llega
		# diez veces más grande y hay que dividir por la escala a la que se montó.
		assert_almost_eq(mat.grow_amount * m.scale.x, -c.hundir_la_piel, 0.0005,
			"'%s' se hunde los milímetros pedidos, no las unidades del archivo"
			% mi.name)
	assert_gt(vistas, 1, "encuentra el cuerpo y el interior de la boca")


## Carmen sólo corre física mientras camina, así que si la dejan por encima o
## por debajo del terreno se queda ahí: con la cápsula no se veía, con el modelo
## la tragaba el suelo hasta las rodillas.
func test_se_apoya_en_el_suelo() -> void:
	var suelo := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(60, 1, 60)
	cs.shape = caja
	suelo.add_child(cs)
	add_child_autofree(suelo)
	suelo.global_position = Vector3(0, -0.5, 0)   # su cara de arriba en y = 0
	# Que la física se entere del suelo ANTES de que Carmen lance su rayo: si no,
	# lo encuentra en su posición vieja y aterriza medio metro más arriba.
	await wait_physics_frames(2)

	var c: Node3D = CARMEN.instantiate()
	add_child_autofree(c)
	c.global_position = Vector3(0, 6.0, 0)        # colgada en el aire
	await wait_physics_frames(4)

	assert_almost_eq(c.global_position.y, 0.0, 0.15,
		"baja hasta el suelo en vez de quedarse donde la dejaron")


## Y que en la plaza esté apuntada de verdad: sin la puerta y sin el sitio de
## baile la escena se ejecuta igual, pero Carmen se va andando a la nada.
func test_la_plaza_la_tiene_apuntada() -> void:
	var esc: PackedScene = load("res://scenes/core/World.tscn")
	assert_not_null(esc)
	if esc == null:
		return
	var st: SceneState = esc.get_state()
	var props := {}
	var hay_marcador := false
	for i in st.get_node_count():
		if String(st.get_node_name(i)) == "SitioDeLaTirana":
			hay_marcador = true
		if String(st.get_node_name(i)) != "Carmen":
			continue
		for p in st.get_node_property_count(i):
			props[String(st.get_node_property_name(i, p))] = st.get_node_property_value(i, p)
	assert_true(hay_marcador, "la plaza tiene el marcador del sitio de baile")
	assert_eq(props.get("puerta_iglesia"), NodePath("../Iglesia/PuertaIglesia"),
		"Carmen sabe a qué puerta ir")
	assert_eq(props.get("sitio_de_baile"), NodePath("../SitioDeLaTirana"),
		"y dónde ponerse a bailar")
