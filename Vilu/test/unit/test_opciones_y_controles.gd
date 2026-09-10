extends GutTest

## Opciones: pantalla completa o ventana, y la chuleta de controles.
##
## La chuleta se genera DESDE EL InputMap. Escrita a mano se desincroniza en
## cuanto alguien mueve una tecla, y entonces engaña: el jugador prueba lo que
## dice la pantalla, no le responde, y da por hecho que el juego está roto.

const OPCIONES := preload("res://scenes/ui/PanelOpciones.gd")
const CONTROLES := preload("res://scenes/ui/PanelDeControles.gd")


func _textos(n: Node, r: Array = []) -> Array:
	if n is Label:
		r.append((n as Label).text)
	elif n is Button:
		r.append((n as Button).text)
	for h in n.get_children():
		_textos(h, r)
	return r


# ─── pantalla ─────────────────────────────────────────────────────────────────

func test_hay_un_ajuste_de_pantalla() -> void:
	var p := OPCIONES.construir()
	add_child_autofree(p)
	var sel: Control = p.find_child("Pantalla", true, false)
	assert_not_null(sel, "las opciones traen el ajuste de pantalla")
	assert_true(_textos(sel).has(OPCIONES._texto_de_pantalla()), "y dice en qué está")


## El panel es un dibujo con los controles de verdad encima, cada uno en el
## hueco que le toca.
func test_el_panel_es_el_dibujo_con_los_controles_encima() -> void:
	var p := OPCIONES.construir()
	add_child_autofree(p)
	var dibujo: TextureRect = p.find_child("Dibujo", true, false)
	assert_not_null(dibujo, "está el dibujo")
	assert_not_null(dibujo.texture, "con la imagen de opciones cargada")
	for nombre in ["AudioGeneral", "Musica", "Efectos", "Pantalla", "Idioma", "Controles", "Guardar", "Volver"]:
		var c: Control = p.find_child(nombre, true, false)
		assert_not_null(c, nombre + " está")
		if c != null:
			assert_true(c.anchor_left > 0.0 and c.anchor_right < 1.0, nombre + " anclado dentro del dibujo")
	for nombre in ["AudioGeneral", "Musica", "Efectos"]:
		assert_true(p.find_child(nombre, true, false) is HSlider, nombre + " es un deslizador")


## «Volver» deja todo como estaba al abrir; «Guardar» se queda con lo tocado.
func test_volver_deshace_y_guardar_conserva() -> void:
	var musica_antes := Save.music_vol
	var p := OPCIONES.construir()
	add_child_autofree(p)
	p.visible = true
	await wait_frames(1)
	var s: HSlider = p.find_child("Musica", true, false)
	s.value = 0.15
	assert_almost_eq(Save.music_vol, 0.15, 0.001, "moverlo aplica en el acto")
	(p.find_child("Volver", true, false) as Button).pressed.emit()
	assert_almost_eq(Save.music_vol, musica_antes, 0.001, "Volver lo deja como estaba")
	assert_false(p.visible, "y cierra")

	p.visible = true
	await wait_frames(1)
	s.value = 0.35
	(p.find_child("Guardar", true, false) as Button).pressed.emit()
	assert_almost_eq(Save.music_vol, 0.35, 0.001, "Guardar se queda con lo nuevo")
	assert_false(p.visible, "y cierra")
	Save.set_music_vol(musica_antes)


## El selector: las flechas dan la vuelta, y la cruceta del mando también.
func test_el_selector_da_la_vuelta() -> void:
	var p := OPCIONES.construir()
	add_child_autofree(p)
	var idioma_antes := Save.idioma
	var sel: Control = p.find_child("Idioma", true, false)
	assert_eq(OPCIONES.indice_de(sel), 0, "arranca en español")
	var centro: Button = sel.find_child("Centro", true, false)
	var der := InputEventAction.new()
	der.action = "ui_right"
	der.pressed = true
	centro.gui_input.emit(der)
	assert_eq(OPCIONES.indice_de(sel), 1, "la cruceta a la derecha pasa al inglés")
	assert_eq(Save.idioma, "en", "y se guarda")
	centro.gui_input.emit(der)
	assert_eq(OPCIONES.indice_de(sel), 0, "y da la vuelta")
	Save.set_idioma(idioma_antes)


## Con el idioma cambia el dibujo entero, que es donde están los nombres.
func test_el_idioma_cambia_el_dibujo() -> void:
	var idioma_antes := Save.idioma
	var p := OPCIONES.construir()
	add_child_autofree(p)
	var dibujo: TextureRect = p.find_child("Dibujo", true, false)
	var es: Texture2D = dibujo.texture
	var sel: Control = p.find_child("Idioma", true, false)
	sel.find_child("Centro", true, false).pressed.emit()
	assert_ne(dibujo.texture, es, "en inglés es otro dibujo")
	assert_eq(dibujo.texture.resource_path, OPCIONES.DIBUJOS["en"])
	# Y lo que dicen las cajas cambia con él.
	var todo := " ".join(PackedStringArray(_textos(p.find_child("Pantalla", true, false))))
	assert_true("Fullscreen" in todo or "Windowed" in todo, "la pantalla en inglés: " + todo)
	todo = " ".join(PackedStringArray(_textos(p.find_child("Controles", true, false))))
	assert_true("Keyboard" in todo or "Gamepad" in todo, "los controles en inglés: " + todo)
	Save.set_idioma(idioma_antes)


## El volumen general manda sobre el bus Master.
func test_el_audio_general_va_al_bus_master() -> void:
	var antes := Save.master_vol
	Save.set_master_vol(0.5)
	var bus := AudioServer.get_bus_index("Master")
	assert_almost_eq(AudioServer.get_bus_volume_db(bus), linear_to_db(0.5), 0.01)
	Save.set_master_vol(antes)


func test_el_boton_dice_en_que_esta() -> void:
	# El texto dice el estado ACTUAL, no a dónde te lleva: si dijera "Pantalla
	# completa" estando ya en completa, nadie sabría si es un estado o un botón.
	var antes := Save.pantalla_completa
	Save.pantalla_completa = true
	assert_true("completa" in OPCIONES._texto_de_pantalla().to_lower(),
		"en completa lo dice")
	Save.pantalla_completa = false
	assert_true("ventana" in OPCIONES._texto_de_pantalla().to_lower(),
		"y en ventana también")
	Save.pantalla_completa = antes


func test_la_eleccion_se_guarda() -> void:
	# Un ajuste que sólo vale para la sesión en que se tocó no es un ajuste.
	var antes := Save.pantalla_completa
	Save.set_pantalla_completa(not antes)
	var c := ConfigFile.new()
	assert_eq(c.load(Save.PATH), OK, "el archivo existe")
	assert_eq(bool(c.get_value("d", "pantalla_completa", antes)), not antes,
		"queda escrito en disco")
	Save.set_pantalla_completa(antes)


func test_en_headless_no_se_toca_la_ventana() -> void:
	# Los tests corren sin servidor de pantalla: pedir ahí un cambio de modo es
	# pedirle algo a algo que no existe.
	Save.aplicar_pantalla()
	pass_test("no revienta sin ventana")


# ─── la chuleta de controles ──────────────────────────────────────────────────

func test_hay_una_chuleta_para_cada_cosa() -> void:
	var p := OPCIONES.construir()
	add_child_autofree(p)
	var sel: Control = p.find_child("Controles", true, false)
	assert_not_null(sel, "el selector de controles")
	var ts := _textos(sel)
	assert_true(ts.has("Teclado y ratón") or ts.has("Mando"), "elige la clase")
	var hojas := 0
	for h in p.get_children():
		if h.is_in_group("hoja_de_controles"):
			hojas += 1
	assert_eq(hojas, 2, "y hay una hoja por clase")
	# Pulsar el centro abre la hoja de la clase elegida.
	OPCIONES._poner_indice(sel, 1, false)
	sel.find_child("Centro", true, false).pressed.emit()
	var abierta: Control = null
	for h in p.get_children():
		if h.is_in_group("hoja_de_controles") and (h as Control).visible:
			abierta = h
	assert_not_null(abierta, "se abre una hoja")
	assert_true(bool(abierta.get("con_mando")), "la del mando")


func test_la_chuleta_del_mando_dice_botones_de_mando() -> void:
	var p: Control = CONTROLES.construir(true)
	add_child_autofree(p)
	var ts := _textos(p)
	assert_true(bool(p.get("con_mando")), "es la del mando")
	# Los nombres salen del InputMap: si el mapa cambia, esto cambia con él.
	var todo := " ".join(PackedStringArray(ts))
	assert_true("Stick izquierdo" in todo, "moverse es el stick izquierdo")
	# Mirar ya no está: la cámara es fija.
	assert_false("Stick derecho" in todo, "sin fila de mirar")
	assert_false("W" in todo.split(" "), "no se cuelan teclas")


func test_la_chuleta_del_teclado_dice_teclas() -> void:
	var p: Control = CONTROLES.construir(false)
	add_child_autofree(p)
	var todo := " ".join(PackedStringArray(_textos(p)))
	assert_false(bool(p.get("con_mando")), "es la del teclado")
	assert_true("W" in todo, "sale la W de avanzar")
	assert_false("Stick" in todo, "y ningún stick")


## La hoja es el dibujo con un control por caja, dieciséis filas —sin cámara,
## que es fija— y en la que traía «agacharse» va montar el guanaco.
func test_la_hoja_es_el_dibujo_con_una_caja_por_fila() -> void:
	for mando in [false, true]:
		var p: Control = CONTROLES.construir(mando)
		add_child_autofree(p)
		var dibujo: TextureRect = p.find_child("Dibujo", true, false)
		assert_not_null(dibujo, "está el dibujo")
		assert_not_null(dibujo.texture, "con su imagen")
		assert_eq(p.FILAS.size(), 16, "una fila por caja del dibujo")
		assert_eq((p.FILAS_Y[mando] as Array).size(), 16, "y una caja por fila")
		var ts := _textos(p)
		assert_has(ts, "Montar guanaco", "escrito encima del rótulo borrado")
		for que in ["Mirar alrededor", "Acercar cámara", "Alejar cámara"]:
			assert_does_not_have(ts, que, que + " no: la cámara es fija")
		var ayuda: Label = p.find_child("Ayuda", true, false)
		assert_gt(ayuda.anchor_top, 0.8, "la ayuda va al pie, no sobre el título")
		var botones: Dictionary = p.get("_botones")
		assert_true(botones.has("guanaco_montar"), "montar se puede cambiar")
		assert_false(botones.has("move_forward"), "moverse no")
		if not mando:
			assert_eq((botones["guanaco_montar"] as Button).text, "C", "y dice la tecla que tiene")


func test_no_se_repite_el_stick_cuatro_veces() -> void:
	# Moverse son cuatro acciones, pero para quien juega es UN stick. Repetirlo
	# cuatro veces no dice nada.
	var fila := {"que": "Moverse",
		"acciones": ["move_forward", "move_left", "move_back", "move_right"]}
	assert_eq(CONTROLES.describir(fila, true), "Stick izquierdo",
		"un stick, dicho una vez")


func test_mirar_con_raton_no_es_una_accion_pero_se_explica() -> void:
	# No hay nada en el InputMap para mirar con el ratón: es el movimiento del
	# puntero. Si la fila se quedara vacía, parecería que no se puede mirar.
	var fila := {}
	for f: Dictionary in CONTROLES.FILAS:
		if String(f["que"]) == "Mirar alrededor":
			fila = f
	assert_false(fila.is_empty(), "está la fila de mirar")
	assert_eq(CONTROLES.describir(fila, false), "Mover el ratón",
		"se explica aunque no sea una acción")


func test_la_chuleta_sigue_al_mapa_de_verdad() -> void:
	# EL PUNTO DE TODO ESTO. Se cambia una tecla y la ayuda cambia con ella.
	var antes := InputMap.action_get_events("jump")
	InputMap.action_erase_events("jump")
	var e := InputEventKey.new()
	e.physical_keycode = KEY_J
	InputMap.action_add_event("jump", e)
	var como := CONTROLES.describir({"que": "Saltar", "acciones": ["jump"]}, false)
	# Se restaura antes de comprobar nada: si el assert fallara, el mapa tiene
	# que quedar sano igual o se llevaría por delante los tests que vengan.
	InputMap.action_erase_events("jump")
	for v in antes:
		InputMap.action_add_event("jump", v)
	assert_eq(como, "J", "la chuleta dice la tecla que hay puesta ahora")


func test_ninguna_fila_se_queda_muda() -> void:
	# Una fila sin nada al lado es peor que no ponerla: parece que esa acción no
	# se puede hacer.
	for con_mando: bool in [true, false]:
		for f: Dictionary in CONTROLES.FILAS:
			var como: String = CONTROLES.describir(f, con_mando)
			assert_ne(como, "", "%s (%s) dice con qué se hace" % [
				f["que"], "mando" if con_mando else "teclado"])
