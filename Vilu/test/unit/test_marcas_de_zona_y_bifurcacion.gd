extends GutTest

## Dos agujeros de la guía que se veían jugando y no en los tests.

const GUIA := preload("res://scenes/core/GuiaDeObjetivos.gd")
const ALICANTO := preload("res://scenes/actors/AlicantoRescate.gd")


func test_las_zonas_sin_puerta_tambien_se_marcan() -> void:
	# «Busca al Alicanto» y «Busca al Yastay» no marcaban NADA. Yo sólo sabía
	# señalar puertas de interior, y esas dos son zonas del mundo abierto: se
	# llega caminando y no hay puerta que marcar. Ahora, si no hay puerta, se
	# planta un nodo propio en el sitio de la zona.
	var texto := FileAccess.get_file_as_string("res://scenes/core/GuiaDeObjetivos.gd")
	assert_true(texto.contains("sitio_de_zona"), "la guía sabe preguntar dónde está una zona")
	assert_true(texto.contains("_poste_en("), "y plantar algo ahí")
	# Y Game sabe responder.
	var juego := FileAccess.get_file_as_string("res://scenes/core/Game.gd")
	assert_true(juego.contains("func sitio_de_zona"), "Game responde dónde está una zona")


func test_ni_el_alicanto_ni_el_yastay_tienen_puerta() -> void:
	# Es la razón por la que fallaban. Si algún día se les pone una, este test
	# avisa de que la vía del poste ya no hace falta para ellas.
	for zona: String in ["Alicanto", "Yastay"]:
		assert_true(GUIA.DESTINOS.values().has(zona), "%s es un destino de misión" % zona)
		var con_puerta := false
		for mundo: String in ["res://scenes/core/World.tscn", "res://scenes/core/WorldAtacama.tscn"]:
			if FileAccess.get_file_as_string(mundo).contains('target_region = "%s"' % zona):
				con_puerta = true
		assert_false(con_puerta, "%s se alcanza caminando, sin puerta" % zona)


func test_la_bifurcacion_marca_los_dos_ramales() -> void:
	# Marcar la bifurcación misma no ayudaba: el jugador ya está parado ahí; lo
	# que no sabe es por dónde se va a cada lado.
	var texto := FileAccess.get_file_as_string("res://scenes/actors/AlicantoRescate.gd")
	var i := texto.find("func _marcar_los_dos_caminos")
	assert_gt(i, 0, "existe el reparto de marcas")
	var cuerpo := texto.substr(i, 700)
	assert_true(cuerpo.contains("trampa.add_to_group"), "se marca el ramal del oro")
	assert_true(cuerpo.contains("_hurt.add_to_group"), "y el de la persona herida")


func test_el_oro_pierde_la_marca_al_probarlo() -> void:
	# Volver a ofrecerlo después de que el suelo se te cayó encima sería tomarle
	# el pelo al jugador: a partir de ahí sólo queda el otro camino.
	var texto := FileAccess.get_file_as_string("res://scenes/actors/AlicantoRescate.gd")
	var i := texto.find("func _on_gold_path_entered")
	assert_gt(i, 0, "existe la entrada al camino del oro")
	assert_true(texto.substr(i, 600).contains('remove_from_group("objetivo_camino")'),
		"el ramal del oro deja de estar marcado")
