extends GutTest

## La cámara gira moviendo el ratón, sin pulsar nada.
##
## Antes había que arrastrar con el botón derecho, que para mirar alrededor
## mientras se juega es un botón de más.

const JUEGO := preload("res://scenes/core/Game.gd")


## Game fuera del árbol: su `_ready` carga un mundo entero. Acá sólo se le
## mandan movimientos de ratón y se le miran los ángulos.
func _juego() -> Node3D:
	var g := Node3D.new()
	g.set_script(JUEGO)
	autofree(g)
	return g


func _mover(g: Node3D, dx: float, dy: float) -> void:
	g.call("_mirar_con_el_raton", Vector2(dx, dy))


func test_esta_activada_por_defecto() -> void:
	assert_true(bool(_juego().get("camara_sigue_al_raton")), "el ratón manda la cámara")


func test_mover_a_los_lados_gira() -> void:
	var g := _juego()
	var antes := float(g.get("_cam_yaw"))
	_mover(g, 100.0, 0.0)
	assert_ne(float(g.get("_cam_yaw")), antes, "moverlo de lado gira el plano")


func test_mover_arriba_y_abajo_sube_y_baja() -> void:
	var g := _juego()
	var antes := float(g.get("_cam_pitch"))
	_mover(g, 0.0, 50.0)
	assert_ne(float(g.get("_cam_pitch")), antes, "moverlo hacia arriba baja el plano")


func test_no_se_pasa_por_debajo_del_suelo() -> void:
	# Pasada la horizontal la cámara se mete debajo del personaje y se ve el
	# interior del suelo. Se prueban los dos topes a lo bruto.
	var g := _juego()
	_mover(g, 0.0, -100000.0)
	assert_lte(float(g.get("_cam_pitch")), JUEGO.PICADO_MAX, "no sube de la horizontal")
	_mover(g, 0.0, 100000.0)
	assert_gte(float(g.get("_cam_pitch")), JUEGO.PICADO_MIN, "ni se va al cenit")


func test_durante_una_escena_guionada_no_hace_nada() -> void:
	# Girar mientras manda el guion dejaría el giro guardado, y al devolverte el
	# control la cámara daría un salto.
	var g := _juego()
	var testigo := Node3D.new()
	autofree(testigo)
	g.set("_cam_override", testigo)
	var antes := float(g.get("_cam_yaw"))
	_mover(g, 200.0, 0.0)
	assert_almost_eq(float(g.get("_cam_yaw")), antes, 0.0001, "manda la cámara guionada")


func test_la_distancia_sigue_fija() -> void:
	# Girar sí; alejarse no. Con la rueda se llegaba a 70 m y el personaje era
	# un punto.
	var g := _juego()
	var antes := float(g.get("cam_distance"))
	var rueda := InputEventAction.new()
	rueda.action = "cam_zoom_out"
	rueda.pressed = true
	g.call("_unhandled_input", rueda)
	assert_almost_eq(float(g.get("cam_distance")), antes, 0.01, "la rueda no aleja")


func test_al_salir_de_la_partida_vuelve_el_puntero() -> void:
	# `Input.mouse_mode` es global y sobrevive al cambio de escena: sin esto,
	# volver al menú dejaba el título sin ratón y no se podía pulsar nada.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Se le llama el `_exit_tree` a mano: meterlo en el árbol de verdad
	# dispararía su `_ready`, que carga el mundo entero.
	_juego().call("_exit_tree")
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "el puntero vuelve al salir")
