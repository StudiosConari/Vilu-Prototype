extends GutTest

## Dónde queda el Yastay y hacia dónde mira en cada tramo de su encuentro.
##
## Tres cosas que se veían mal y son la misma clase de descuido: mover un nodo
## sin decidir hacia dónde mira, y escribir coordenadas de mundo a mano en una
## zona que está desplazada y girada.

const YASTAY := preload("res://scenes/actors/YastayEncounter.gd")


func test_ya_no_hay_coordenadas_escritas_a_mano() -> void:
	# Al terminar el diálogo se le mandaba a `global_position` (-11, 0, -15).
	# Ese número es de cuando la arena se generaba por código y la zona estaba en
	# el origen; la quebrada de ahora está desplazada Y GIRADA, así que como
	# coordenada de MUNDO apunta a cualquier parte: el Yastay salía disparado
	# lejísimos y se quedaba ahí.
	var texto := FileAccess.get_file_as_string("res://scenes/actors/YastayEncounter.gd")
	assert_false(texto.contains("Vector3(-11, 0, -15)"),
		"nadie le manda ya una posición de mundo escrita a mano")


func test_al_terminar_vuelve_con_su_rebano() -> void:
	var texto := FileAccess.get_file_as_string("res://scenes/actors/YastayEncounter.gd")
	var i := texto.find("func _give_blessing")
	assert_gt(i, 0, "existe el cierre de la bendición")
	var cuerpo := texto.substr(i, 1400)
	assert_true(cuerpo.contains("_volver_a_su_sitio()"),
		"vuelve al sitio que se guardó al empezar, donde están los guanacos")


func test_se_acerca_a_hablar_de_frente_y_caminando() -> void:
	# Antes sólo se le movía la posición: llegaba de espaldas o de lado, con la
	# orientación que le hubiera quedado, y deslizándose sin animación.
	var texto := FileAccess.get_file_as_string("res://scenes/actors/YastayEncounter.gd")
	var i := texto.find("func _yastay_speaks")
	assert_gt(i, 0, "existe el acercamiento")
	var cuerpo := texto.substr(i, 1400)
	assert_true(cuerpo.contains("_orientar(_yastay"), "se gira hacia el jugador")
	assert_true(cuerpo.contains('_yastay_hace("Walk"'), "y viene caminando")
	assert_true(cuerpo.contains('_yastay_hace("Idle"'), "al llegar se queda quieto")


func test_tras_los_cazadores_mira_al_puente() -> void:
	var texto := FileAccess.get_file_as_string("res://scenes/actors/YastayEncounter.gd")
	var i := texto.find("func _escena_de_presentacion")
	var cuerpo := texto.substr(i, 3000)
	assert_true(cuerpo.contains("_mirar_al_puente()"),
		"al volver a su sitio se gira hacia el puente")


func test_la_camara_suelta_al_brujo_en_el_puente() -> void:
	# El último tramo de su huida es un tirón largo por el otro lado de la
	# quebrada, con él de espaldas y cada vez más chico: ahí la escena ya contó
	# lo que tenía que contar.
	var y: Node = YASTAY.new()
	var hasta: float = y.get("brujo_seguido_hasta")
	assert_lt(hasta, 1.0, "no se le sigue hasta el final del camino")
	assert_gt(hasta, 0.0, "pero algo se le sigue")
	y.free()


func test_la_espera_del_brujo_tiene_tope() -> void:
	# Es una red: sin tope, un camino mal puesto dejaría la escena colgada para
	# siempre, con el jugador sin control.
	assert_lt(YASTAY.ESPERA_MAXIMA_DEL_BRUJO, 20.0, "la escena no se puede colgar")
	assert_gt(YASTAY.ESPERA_MAXIMA_DEL_BRUJO, 3.0, "pero le da tiempo a llegar")
