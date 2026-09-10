extends GutTest

## El menú de pausa: [ESC] para el juego y ofrece qué hacer.
##
## Es lo que faltaba para poder probar el prototipo sin cerrar la ventana:
## empezada una zona, la única salida era Alt+F4.

const PAUSA := preload("res://scenes/ui/MenuDePausa.gd")


func after_each() -> void:
	# Un test que deje el árbol pausado deja colgados a los que vienen después.
	get_tree().paused = false


func _menu() -> CanvasLayer:
	var m := CanvasLayer.new()
	m.set_script(PAUSA)
	add_child_autofree(m)
	await wait_frames(2)
	return m


func _esc() -> InputEventAction:
	var e := InputEventAction.new()
	e.action = "ui_cancel"
	e.pressed = true
	return e


func test_arranca_escondido_y_sin_pausar() -> void:
	var m := await _menu()
	assert_false((m.get("_panel") as Control).visible, "no se ve hasta que lo pidas")
	assert_false(get_tree().paused, "y el juego sigue corriendo")


func test_esc_pausa_y_esc_reanuda() -> void:
	var m := await _menu()
	m._unhandled_input(_esc())
	assert_true((m.get("_panel") as Control).visible, "aparece")
	assert_true(get_tree().paused, "y el juego se para de verdad")

	m._unhandled_input(_esc())
	assert_false((m.get("_panel") as Control).visible, "se va")
	assert_false(get_tree().paused, "y el juego sigue")


func test_sigue_vivo_con_el_juego_parado() -> void:
	# Si se pausara a sí mismo no habría forma de reanudar.
	var m := await _menu()
	assert_eq(m.process_mode, Node.PROCESS_MODE_ALWAYS)


func test_con_las_opciones_abiertas_esc_cierra_las_opciones() -> void:
	var m := await _menu()
	m._unhandled_input(_esc())
	var opciones: Control = m.get("_opciones")
	opciones.visible = true

	m._unhandled_input(_esc())
	assert_false(opciones.visible, "se cierran las opciones")
	assert_true((m.get("_panel") as Control).visible, "y la pausa se queda")
	assert_true(get_tree().paused, "el juego sigue parado")


func test_mientras_alguien_habla_no_se_abre() -> void:
	# El globo de diálogo usa [ESC] para saltar la línea y se traga las teclas.
	var m := await _menu()
	m.set("_hablando", true)
	m._unhandled_input(_esc())
	assert_false((m.get("_panel") as Control).visible, "no interrumpe el diálogo")
	assert_false(get_tree().paused)


func test_con_otra_pantalla_encima_tampoco() -> void:
	# El mapa del Guardián también se cierra con [ESC].
	var m := await _menu()
	var mapa := Control.new()
	mapa.add_to_group("pantalla_modal")
	add_child_autofree(mapa)

	m._unhandled_input(_esc())
	assert_false((m.get("_panel") as Control).visible, "el mapa manda")

	mapa.visible = false
	m._unhandled_input(_esc())
	assert_true((m.get("_panel") as Control).visible, "cerrado el mapa, sí se abre")


func test_tiene_las_cuatro_salidas() -> void:
	var m := await _menu()
	var textos: Array = []
	for b in _botones(m.get("_panel")):
		textos.append(b.text)
	for t in ["Continuar", "Opciones", "Reiniciar", "Volver al menú"]:
		assert_true(t in textos, "está '%s'" % t)


## «Reiniciar» te devolvía a la primera zona pero con la misión de la última:
## recargaba la escena y dejaba el progreso, que vive en un autoload.
func test_reiniciar_empieza_de_cero() -> void:
	var m := await _menu()
	GameManager.set_beat(7)
	GameManager.conceder("tirana")
	Misiones.sincronizar_con_los_logros()
	assert_ne(String(Misiones.actual()["id"]), "carmen", "la cadena estaba avanzada")

	var recargas := [0]
	m.set("_recargar", func() -> void: recargas[0] += 1)
	for b in _botones(m.get("_panel")):
		if b.text == "Reiniciar":
			b.pressed.emit()
	assert_eq(recargas[0], 1, "vuelve a cargar la escena")
	assert_eq(Save.beat_index, 0, "desde el primer beat")
	assert_false(GameManager.tiene_logro("tirana"), "sin los logros de antes")
	assert_eq(String(Misiones.actual()["id"]), "carmen", "y con la primera misión")


func _botones(n: Node) -> Array:
	var r: Array = []
	if n is Button:
		r.append(n)
	for h in n.get_children():
		r.append_array(_botones(h))
	return r


func test_esta_puesto_en_la_escena_del_juego() -> void:
	# Montado a mano en un test no sirve de nada si en el juego no está.
	var st := (load("res://scenes/core/Game.tscn") as PackedScene).get_state()
	var hay := false
	for i in st.get_node_count():
		if String(st.get_node_name(i)) == "MenuDePausa":
			hay = true
	assert_true(hay, "el menú de pausa, colgado de Game")


## A los lados del menú van los movimientos de cada uno: Emilia a la izquierda
## y Benjamín a la derecha, con la tecla que tengan puesta ahora.
func _textos(n: Node) -> String:
	var r := ""
	if n is Label:
		r += (n as Label).text + "\n"
	for h in n.get_children():
		r += _textos(h)
	return r


func test_las_hojas_de_movimientos_flanquean_el_menu() -> void:
	var m := await _menu()
	var panel: Control = m.get("_panel")
	var emilia: Control = panel.find_child("HojaEmilia", true, false)
	var benja: Control = panel.find_child("HojaBenjamín", true, false)
	var comun: Control = panel.find_child("HojaLosdos", true, false)
	assert_not_null(emilia, "la hoja de Emilia")
	assert_not_null(benja, "y la de Benjamín")
	assert_not_null(comun, "y la de lo que comparten")
	var fila := emilia.get_parent()
	assert_eq(fila, benja.get_parent(), "en la misma fila")
	assert_lt(emilia.get_index(), benja.get_index(), "Emilia a la izquierda, Benjamín a la derecha")
	# La común va debajo del menú: en la columna del medio, después del marco.
	var columna := comun.get_parent()
	assert_eq(columna.get_parent(), fila, "la común cuelga de la columna del medio")
	assert_eq(comun.get_index(), columna.get_child_count() - 1, "y es lo último, debajo del menú")

	m.call("_pausar")
	var te := _textos(emilia)
	var tb := _textos(benja)
	var tc := _textos(comun)
	for que in ["Combo de 4 golpes", "Golpe cargado", "Doble salto", "Planear"]:
		assert_true(te.contains(que), "Emilia: " + que)
	for que in ["Disparo rápido", "Disparo cargado", "Flecha triple", "Guanaco: invocar", "Guanaco: montar", "Guanaco: embestir"]:
		assert_true(tb.contains(que), "Benjamín: " + que)
	for que in ["Moverse / correr", "Saltar", "Rodar", "Hablar / usar", "Cambiar (te sigue)", "Cambiar (anclado)"]:
		assert_true(tc.contains(que), "los dos: " + que)
	assert_false(te.contains("Cambiar") or tb.contains("Rodar"), "lo común no se repite en las suyas")
	assert_true(tb.contains("C") and tc.contains("Shift"), "con las teclas que tienen puestas ahora")
	get_tree().paused = false

