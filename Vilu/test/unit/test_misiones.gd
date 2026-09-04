extends "res://addons/gut/test.gd"

## La cadena de misiones del prototipo.
##
## Es una lista ordenada con una misión activa cada vez. Las escenas no saben
## por dónde va: sólo avisan de lo que pasó con `Misiones.hecho("id")`, y si eso
## no es lo que toca ahora no pasa nada. Eso es lo que permite entrar por la
## mitad del juego desde el menú de depuración, o repetir una zona, sin que la
## cadena se descuadre.


func before_each() -> void:
	GameManager.reset_progress()
	Misiones.sincronizar_con_los_logros()


func after_all() -> void:
	GameManager.reset_progress()
	Misiones.sincronizar_con_los_logros()


func test_arranca_mandando_a_hablar_con_carmen() -> void:
	assert_eq(String(Misiones.actual()["id"]), "carmen")
	assert_eq(String(Misiones.actual()["texto"]), "Habla con Carmen, la guía del museo")
	assert_eq(Misiones.hechos(), 0)
	assert_eq(int(Misiones.actual()["total"]), 1)


## Las de varios pasos cuentan de una en una.
func test_las_cuatro_pistas_se_cuentan_una_a_una() -> void:
	Misiones.hecho("carmen")
	await wait_seconds(Misiones.ESPERA + 0.2)
	assert_eq(String(Misiones.actual()["id"]), "pistas")
	assert_eq(int(Misiones.actual()["total"]), 4)

	for i in 3:
		Misiones.hecho("pistas")
		assert_eq(Misiones.hechos(), i + 1, "va contando")
		assert_eq(String(Misiones.actual()["id"]), "pistas", "y no pasa antes de tiempo")


## Al completarla se queda un momento en pantalla ANTES de cambiar: si no, el
## jugador ve saltar el texto y no se entera de que cumplió algo.
func test_la_cumplida_se_queda_un_momento_antes_de_pasar() -> void:
	Misiones.hecho("carmen")
	assert_eq(String(Misiones.actual()["id"]), "carmen",
		"recién cumplida sigue en pantalla")
	assert_eq(Misiones.hechos(), 1, "…y marcada como hecha")
	await wait_seconds(Misiones.ESPERA + 0.2)
	assert_eq(String(Misiones.actual()["id"]), "pistas", "después pasa a la siguiente")


## Avisar de algo que no es lo que toca no hace nada. Es lo que sostiene todo:
## las escenas avisan sin saber en qué punto va la partida.
func test_avisar_de_otra_cosa_no_altera_la_cadena() -> void:
	Misiones.hecho("chupacabras")
	Misiones.hecho("guanacos", 4)
	Misiones.hecho("pistas")
	assert_eq(String(Misiones.actual()["id"]), "carmen", "sigue en la primera")
	assert_eq(Misiones.hechos(), 0, "y sin contar nada")


## Nueve misiones las cierra un logro, y eso va enganchado de una vez en vez de
## repartido por nueve escenas.
func test_un_logro_cierra_su_mision() -> void:
	# Se salta hasta la de la Tirana.
	Misiones.hecho("carmen")
	await wait_seconds(Misiones.ESPERA + 0.2)
	Misiones.hecho("pistas", 4)
	await wait_seconds(Misiones.ESPERA + 0.2)
	assert_eq(String(Misiones.actual()["id"]), "tirana")

	GameManager.conceder("tirana")
	assert_eq(Misiones.hechos(), 1, "el logro la da por cumplida")
	await wait_seconds(Misiones.ESPERA + 0.2)
	assert_eq(String(Misiones.actual()["id"]), "mina", "y pasa a la siguiente")


## Entrando por una parada tardía del menú, la cadena tiene que aparecer donde
## corresponde y no en la primera misión.
func test_se_coloca_sola_segun_los_logros_que_ya_haya() -> void:
	GameManager.conceder("tirana")
	GameManager.conceder("mina")
	Misiones.sincronizar_con_los_logros()
	assert_eq(String(Misiones.actual()["id"]), "talisman_1",
		"con la Tirana y la mina hechas, toca el primer talismán")


## Llegar a un sitio cierra su misión, y la mina cierra dos distintas según por
## dónde vaya la partida.
func test_llegar_a_la_mina_sirve_las_dos_veces() -> void:
	Misiones.hecho("carmen")
	await wait_seconds(Misiones.ESPERA + 0.2)
	Misiones.hecho("pistas", 4)
	await wait_seconds(Misiones.ESPERA + 0.2)
	GameManager.conceder("tirana")
	await wait_seconds(Misiones.ESPERA + 0.2)
	assert_eq(String(Misiones.actual()["id"]), "mina")

	Misiones.llegue_a("Mina")
	assert_eq(Misiones.hechos(), 1, "llegar a la mina cumple la de buscarla")


## El camino del Alicanto se puede fallar: el texto cambia y se vuelve a pedir.
func test_el_camino_se_puede_reintentar_con_otro_texto() -> void:
	while not Misiones.terminada() and String(Misiones.actual()["id"]) != "camino":
		var m: Dictionary = Misiones.actual()
		Misiones.hecho(String(m["id"]), int(m["total"]))
		await wait_seconds(Misiones.ESPERA + 0.15)
	assert_eq(String(Misiones.actual()["id"]), "camino")
	assert_eq(String(Misiones.actual()["texto"]), "Elige tu camino")

	Misiones.reintentar("camino")
	assert_eq(String(Misiones.actual()["texto"]), "Elige BIEN tu camino")
	assert_eq(Misiones.hechos(), 0, "y vuelve a empezar")


## Un aviso que llega DURANTE la celebración no se pierde: se guarda y se
## atiende al pasar a la siguiente. La cima del Ojos del Salado cierra dos
## misiones seguidas de un solo golpe, y sin esto la segunda se quedaba colgada.
func test_los_avisos_de_la_celebracion_no_se_pierden() -> void:
	Misiones.hecho("carmen")
	# Sin esperar: la cadena está celebrando la de Carmen.
	Misiones.hecho("pistas")
	Misiones.hecho("pistas")
	assert_eq(String(Misiones.actual()["id"]), "carmen", "todavía celebrando")

	await wait_seconds(Misiones.ESPERA + 0.3)
	assert_eq(String(Misiones.actual()["id"]), "pistas")
	assert_eq(Misiones.hechos(), 2, "las dos pistas que llegaron a destiempo cuentan")


## Los nueve logros llevan los títulos del guion, con su ordinal.
func test_los_titulares_de_los_logros() -> void:
	var esperados := {
		"tirana": "Primer logro: Investigador Cultural",
		"mina": "Segundo logro: El Correcaminos",
		"talisman_1": "Tercer logro: Investigador del Misterio",
		"isluga": "Cuarto logro: Activador de Volcanes",
		"alicanto": "Quinto logro: El Primer Humano Volador",
		"yastay": "Sexto logro: El Sanador",
		"talisman_2": "Séptimo logro: Ocultistas",
		"ojos_salado": "Octavo logro: Viajero Volcánico",
		"chupacabras": "Noveno logro: Adiestrador de Chupacabras",
	}
	for id in esperados:
		assert_eq(GameManager.titular_de_logro(id), esperados[id])


## Cada misión con logro apunta a uno que exista de verdad.
func test_los_logros_de_la_cadena_existen() -> void:
	var ids := {}
	for l in GameManager.LOGROS:
		ids[l["id"]] = true
	for m in Misiones.CADENA:
		var id: String = String(m.get("logro", ""))
		if id == "":
			continue
		assert_true(ids.has(id), "'%s' apunta a un logro que existe" % m["id"])
