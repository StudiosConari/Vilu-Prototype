extends "res://addons/gut/test.gd"

## La huida de la mina la dispara el TALISMÁN.
##
## Antes esperaba a que llegaras al nido con los mineros despejados, y el
## fragmento —que es el motivo por el que bajaste— no hacía nada: lo recogías y
## seguías paseando. Ahora lo agarras y el Chupacabras sale.
##
## Se escucha la habilidad y no el prop porque el fragmento se consigue por dos
## caminos —rompiendo la barricada de tablones o recogiendo el panel flotante—,
## así los dos valen sin repetir el enganche en cada uno.

const MINA := preload("res://scenes/actors/MinaCueva.gd")


func before_each() -> void:
	GameManager.reset_progress()


func after_all() -> void:
	GameManager.reset_progress()


## La cueva suelta, sin la escena entera: lo que se prueba es de qué se entera,
## no cómo está construida.
func _cueva() -> Node3D:
	var m := Node3D.new()
	m.set_script(MINA)
	add_child_autofree(m)
	await wait_physics_frames(2)
	return m


func test_el_talisman_dispara_la_huida() -> void:
	var m := await _cueva()
	assert_false(m._chase_active, "de entrada no hay nadie persiguiendo")
	GameManager.unlock("talisman_frag_1")
	await wait_physics_frames(2)
	assert_true(m._chase_active, "al recoger el fragmento, a correr")


## Otra habilidad cualquiera no despierta nada.
func test_otra_habilidad_no_dispara_nada() -> void:
	var m := await _cueva()
	GameManager.unlock("bow")
	GameManager.unlock("wings")
	await wait_physics_frames(2)
	assert_false(m._chase_active)


## La ÚNICA visita sin huida es la del duelo: cuando están todos los logros
## menos el del Chupacabras.
func test_en_la_visita_del_duelo_no_hay_huida() -> void:
	for l in GameManager.LOGROS:
		if String(l["id"]) != "chupacabras":
			GameManager.conceder(String(l["id"]))
	var m := await _cueva()
	GameManager.unlock("talisman_frag_1")
	await wait_physics_frames(2)
	assert_false(m._chase_active, "se vuelve a buscarlo, no a huir")


## Pero tener SÓLO el logro de la mina no basta para bloquearla: entrando por
## una parada del menú que ya lo concede, era tu primera vez en la mina y te
## quedabas sin huida. Ése fue el error.
func test_tener_el_logro_de_la_mina_no_bloquea_la_huida() -> void:
	GameManager.conceder("tirana")
	GameManager.conceder("mina")
	var m := await _cueva()
	GameManager.unlock("talisman_frag_1")
	await wait_physics_frames(2)
	assert_true(m._chase_active, "sigue habiendo huida: no es la visita del duelo")


## "El Correcaminos" es por ESCAPAR, no por despejar el sector.
##
## Se concedía al morir el último minero corrupto, que es el principio de la
## mina: antes de los obeliscos, antes del talismán y antes de que el
## Chupacabras aparezca. Saltaba con la mina entera por delante.
func test_el_correcaminos_no_se_da_al_despejar_el_sector() -> void:
	var m := await _cueva()
	m._alive = 1
	m._on_miner_died(Vector3.ZERO, 0)
	assert_true(m._combat_cleared, "el sector sí queda despejado")
	assert_false(GameManager.tiene_logro("mina"),
		"pero el logro no: todavía no escapaste de nada")


## Se concede al cruzar la boca con el Chupacabras detrás.
func test_el_correcaminos_se_da_al_salir_huyendo() -> void:
	var m := await _cueva()
	GameManager.unlock("talisman_frag_1")
	await wait_physics_frames(2)
	assert_true(m._chase_active, "el talismán arrancó la huida")
	assert_false(GameManager.tiene_logro("mina"), "corriendo todavía no")

	m._stop_chase()
	assert_true(GameManager.tiene_logro("mina"), "al cruzar la boca, sí")


## Y no se puede colar sin haber corrido: sin persecución activa, salir no
## concede nada.
func test_sin_huida_cruzar_la_boca_no_concede_nada() -> void:
	var m := await _cueva()
	m._stop_chase()
	assert_false(GameManager.tiene_logro("mina"))


## La cueva con su salida puesta, como en Mina.tscn: un Area3D llamada
## ExitToPoblado que es la que pide el viaje al pisarla.
func _cueva_con_boca() -> Array:
	var m := Node3D.new()
	m.set_script(MINA)
	var boca := Area3D.new()
	boca.name = "ExitToPoblado"
	m.add_child(boca)
	add_child_autofree(m)
	await wait_physics_frames(2)
	return [m, boca]


## Pisar la boca cierra la huida y concede el logro, CRUCE QUIEN CRUCE.
##
## La salida descarga la mina entera a los 0,4 s de que cualquier personaje la
## toque. Si el compañero iba adelante —dejado con [T] cerca de la entrada, o
## más cerca cuando arrancó la huida— la pisaba él, la mina se iba con el
## activo a mitad del pasillo y el logro no llegaba nunca: «Investiga el final
## de la mina» quedaba colgada para siempre.
func test_pisar_la_boca_cierra_la_huida_aunque_cruce_el_companero() -> void:
	var par: Array = await _cueva_con_boca()
	var m: Node3D = par[0]
	var boca: Area3D = par[1]
	GameManager.unlock("talisman_frag_1")
	await wait_physics_frames(2)
	assert_true(m._chase_active, "la huida arrancó")

	var companero := Node3D.new()
	companero.add_to_group("player")
	companero.set("active", false)
	add_child_autofree(companero)
	boca.body_entered.emit(companero)
	assert_false(m._chase_active, "pisar la boca termina la huida")
	assert_true(GameManager.tiene_logro("mina"), "y concede El Correcaminos")


## Pisarla sin huida no hace nada: volver a la mina por la puerta y salir de
## nuevo no regala el logro.
func test_pisar_la_boca_sin_huida_no_concede_nada() -> void:
	var par: Array = await _cueva_con_boca()
	var boca: Area3D = par[1]
	var p := Node3D.new()
	p.add_to_group("player")
	add_child_autofree(p)
	boca.body_entered.emit(p)
	assert_false(GameManager.tiene_logro("mina"))
