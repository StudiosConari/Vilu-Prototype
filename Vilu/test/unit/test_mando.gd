extends GutTest

## Se puede jugar entero con mando.
##
## Todo lo que hace falta para terminar el prototipo tiene que estar en el
## mando: moverse, saltar, correr, pegar, hablar, el guanaco, la flecha triple,
## cambiar de personaje, rodar, mirar y pausar. Si una sola de esas acciones se
## quedara sólo en el teclado, el juego con mando se atasca ahí.
##
## Se comprueba contra el InputMap DE VERDAD, no contra lo que uno crea haber
## escrito en project.godot.

## Lo que se puede hacer, y con qué se hace.
const ACCIONES := [
	"move_forward", "move_back", "move_left", "move_right",
	"jump", "run", "interact", "guanaco", "guanaco_charge",
	"attack", "triple_arrow", "swap_ai", "swap_hold", "rodar",
]

## Mirar alrededor: el stick derecho.
const CAMARA := ["cam_izquierda", "cam_derecha", "cam_arriba", "cam_abajo"]


func _tiene_mando(accion: String) -> bool:
	for e in InputMap.action_get_events(accion):
		if e is InputEventJoypadButton or e is InputEventJoypadMotion:
			return true
	return false


func _tiene_teclado(accion: String) -> bool:
	for e in InputMap.action_get_events(accion):
		if e is InputEventKey or e is InputEventMouseButton:
			return true
	return false


func test_todo_lo_jugable_esta_en_el_mando() -> void:
	for a: String in ACCIONES:
		assert_true(InputMap.has_action(a), "existe la acción %s" % a)
		assert_true(_tiene_mando(a), "%s se puede hacer con mando" % a)


func test_el_teclado_no_se_pierde() -> void:
	# Añadir el mando no puede quitarle nada a quien juega con teclado y ratón.
	for a: String in ACCIONES:
		assert_true(_tiene_teclado(a), "%s sigue estando en el teclado" % a)


func test_la_camara_se_mueve_con_el_stick_derecho() -> void:
	# Con ratón la cámara sigue al puntero; con mando hace falta un eje, y no
	# había ninguno declarado.
	for a: String in CAMARA:
		assert_true(InputMap.has_action(a), "existe %s" % a)
		assert_true(_tiene_mando(a), "%s es del mando" % a)


func test_la_camara_usa_el_stick_derecho_y_no_el_izquierdo() -> void:
	# El izquierdo mueve al personaje. Si la cámara compartiera eje, andar
	# giraría la cámara.
	for a: String in CAMARA:
		for e in InputMap.action_get_events(a):
			if e is InputEventJoypadMotion:
				assert_true((e as InputEventJoypadMotion).axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y],
					"%s va en el stick derecho" % a)
	for a: String in ["move_forward", "move_back", "move_left", "move_right"]:
		for e in InputMap.action_get_events(a):
			if e is InputEventJoypadMotion:
				assert_true((e as InputEventJoypadMotion).axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y],
					"%s va en el stick izquierdo" % a)


func test_se_puede_pausar_con_el_mando() -> void:
	# La pausa es `ui_cancel`. Declararla en project.godot REEMPLAZA los valores
	# de fábrica de Godot, así que hay que devolverle también la tecla.
	var hay_boton := false
	var hay_tecla := false
	for e in InputMap.action_get_events("ui_cancel"):
		if e is InputEventJoypadButton:
			hay_boton = true
		if e is InputEventKey:
			hay_tecla = true
	assert_true(hay_boton, "se pausa con el mando")
	assert_true(hay_tecla, "y Escape sigue funcionando")


func test_ninguna_accion_de_juego_pisa_a_otra() -> void:
	# Dos cosas en el mismo botón es un botón que hace dos cosas a la vez, no un
	# atajo. Se compara el mando de cada acción con el de todas las demás.
	var de := {}
	for a: String in ACCIONES + CAMARA:
		for e in InputMap.action_get_events(a):
			var clave := ""
			if e is InputEventJoypadButton:
				clave = "boton:%d" % (e as InputEventJoypadButton).button_index
			elif e is InputEventJoypadMotion:
				var m := e as InputEventJoypadMotion
				clave = "eje:%d:%s" % [m.axis, "+" if m.axis_value > 0.0 else "-"]
			if clave == "":
				continue
			assert_false(de.has(clave),
				"%s no comparte %s con %s" % [a, clave, de.get(clave, "")])
			de[clave] = a


func test_la_pausa_no_choca_con_ninguna_accion() -> void:
	# `ui_cancel` lleva la B de fábrica. Si una acción del juego cayera ahí,
	# usarla abriría el menú de pausa.
	var de_la_pausa := []
	for e in InputMap.action_get_events("ui_cancel"):
		if e is InputEventJoypadButton:
			de_la_pausa.append((e as InputEventJoypadButton).button_index)
	for a: String in ACCIONES:
		for e in InputMap.action_get_events(a):
			if e is InputEventJoypadButton:
				assert_false(de_la_pausa.has((e as InputEventJoypadButton).button_index),
					"%s no cae en un botón de pausa" % a)


# ─── que además funcione ──────────────────────────────────────────────────────

## La ESCENA y no el guion suelto: `_player_input` acaba en `_camera_relative`,
## que pregunta por la cámara del viewport, y un nodo creado a mano y fuera de la
## escena no tiene ni viewport ni el `Visual` que el jugador busca al entrar.
const JUGADOR := preload("res://scenes/actors/Player.tscn")


func after_each() -> void:
	# Las acciones se sueltan siempre: si una se quedara pulsada, contaminaría
	# los tests que vengan detrás y el fallo aparecería en otro archivo.
	for a: String in ACCIONES + CAMARA:
		if InputMap.has_action(a):
			Input.action_release(a)


func test_el_stick_medio_empujado_no_corre() -> void:
	# EL PUNTO DE LEER LA FUERZA. Con `is_action_pressed` el stick era un
	# teclado con forma rara: cualquier inclinación daba velocidad máxima.
	var p: CharacterBody3D = JUGADOR.instantiate()
	add_child_autofree(p)
	Input.action_press("move_forward", 0.4)
	var medio: Vector3 = p.call("_player_input")
	Input.action_press("move_forward", 1.0)
	var tope: Vector3 = p.call("_player_input")
	Input.action_release("move_forward")
	assert_gt(medio.length(), 0.0, "medio empujado sí se mueve")
	assert_lt(medio.length(), tope.length(),
		"pero menos que al tope (%.2f vs %.2f)" % [medio.length(), tope.length()])


func test_con_teclado_sigue_siendo_todo_o_nada() -> void:
	# Una tecla vale 1: el que juega con WASD no nota ningún cambio.
	var p: CharacterBody3D = JUGADOR.instantiate()
	add_child_autofree(p)
	Input.action_press("move_forward", 1.0)
	var d: Vector3 = p.call("_player_input")
	Input.action_release("move_forward")
	assert_almost_eq(d.length(), 1.0, 0.01, "a fondo, como siempre")


func test_el_stick_derecho_gira_la_camara() -> void:
	# No basta con declarar los ejes: hay que leerlos cada cuadro. Un stick
	# sostenido no genera eventos nuevos, así que por evento la cámara giraría
	# un pelín y se pararía.
	var g: Node3D = preload("res://scenes/core/Game.gd").new()
	g.set("_cam_yaw", 0.0)
	Input.action_press("cam_derecha", 1.0)
	g.call("_mirar_con_el_mando", 0.1)
	Input.action_release("cam_derecha")
	assert_ne(g.get("_cam_yaw"), 0.0, "el stick derecho movió la cámara")
	g.free()


func test_la_camara_no_se_va_sola_con_el_stick_quieto() -> void:
	var g: Node3D = preload("res://scenes/core/Game.gd").new()
	g.set("_cam_yaw", 1.23)
	g.call("_mirar_con_el_mando", 0.1)
	assert_almost_eq(g.get("_cam_yaw"), 1.23, 0.0001, "sin tocar el stick, no gira")
	g.free()


func test_la_camara_del_mando_respeta_las_escenas_guionadas() -> void:
	# Igual que el ratón: girar durante un enfoque guionado deja el giro
	# guardado y la cámara pega un salto al devolverte el control.
	var g: Node3D = preload("res://scenes/core/Game.gd").new()
	var otro := Node3D.new()
	g.set("_cam_override", otro)
	g.set("_cam_yaw", 0.5)
	Input.action_press("cam_derecha", 1.0)
	g.call("_mirar_con_el_mando", 0.1)
	Input.action_release("cam_derecha")
	assert_almost_eq(g.get("_cam_yaw"), 0.5, 0.0001, "manda el guion")
	otro.free()
	g.free()
