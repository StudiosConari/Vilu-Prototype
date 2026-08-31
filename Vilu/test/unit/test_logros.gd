extends "res://addons/gut/test.gd"

## Los logros del prototipo: uno por zona, y tenerlos todos es superarlo.

func before_each() -> void:
	GameManager.reset_progress()

func after_all() -> void:
	GameManager.reset_progress()


func test_arranca_sin_ninguno() -> void:
	assert_eq(GameManager.logros_obtenidos(), 0)
	assert_false(GameManager.prototipo_completo())


func test_son_nueve_y_con_id_unico() -> void:
	var vistos := {}
	for l in GameManager.LOGROS:
		assert_false(vistos.has(l["id"]), "id repetido: %s" % l["id"])
		vistos[l["id"]] = true
		assert_ne(str(l["titulo"]), "", "todos llevan título")
		assert_ne(str(l["pista"]), "", "todos llevan pista")
	assert_eq(GameManager.LOGROS.size(), 9)


func test_conceder_uno_no_completa_el_prototipo() -> void:
	watch_signals(GameManager)
	GameManager.conceder("mina")
	assert_true(GameManager.tiene_logro("mina"))
	assert_eq(GameManager.logros_obtenidos(), 1)
	assert_false(GameManager.prototipo_completo())
	assert_signal_emitted(GameManager, "logro_obtenido")
	assert_signal_not_emitted(GameManager, "prototipo_superado")


func test_repetir_el_mismo_no_suma() -> void:
	GameManager.conceder("mina")
	watch_signals(GameManager)
	GameManager.conceder("mina")
	assert_eq(GameManager.logros_obtenidos(), 1, "no se cuenta dos veces")
	assert_signal_not_emitted(GameManager, "logro_obtenido", "ni vuelve a avisar")


func test_con_todos_se_supera_el_prototipo() -> void:
	watch_signals(GameManager)
	for l in GameManager.LOGROS:
		GameManager.conceder(l["id"])
	assert_eq(GameManager.logros_obtenidos(), GameManager.LOGROS.size())
	assert_true(GameManager.prototipo_completo())
	assert_signal_emitted(GameManager, "prototipo_superado")


func test_el_ultimo_es_el_que_lo_cierra() -> void:
	# Todos menos el del Chupacabras, que es el que termina el prototipo.
	for l in GameManager.LOGROS:
		if l["id"] != "chupacabras":
			GameManager.conceder(l["id"])
	assert_false(GameManager.prototipo_completo(), "falta uno")
	watch_signals(GameManager)
	GameManager.conceder("chupacabras")
	assert_true(GameManager.prototipo_completo())
	assert_signal_emitted(GameManager, "prototipo_superado")


func test_se_guardan_y_el_reinicio_los_borra() -> void:
	GameManager.conceder("tirana")
	GameManager.conceder("isluga")
	assert_true(Save.logros.has("tirana"), "quedan en el guardado")
	assert_true(Save.logros.has("isluga"))
	GameManager.reset_progress()
	assert_eq(GameManager.logros_obtenidos(), 0, "nueva partida los limpia")
	assert_false(GameManager.tiene_logro("tirana"))
