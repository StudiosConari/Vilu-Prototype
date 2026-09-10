extends GutTest

## El menú del título: qué entradas tiene y cuándo.

const TITULO := preload("res://scenes/TitleScreen.gd")


func after_each() -> void:
	GameManager.se_puede_continuar = false


func _titulo() -> Control:
	var t: Control = TITULO.new()
	add_child_autofree(t)
	await wait_frames(2)
	return t


func _botones(n: Node) -> Array:
	var r: Array = []
	if n is BaseButton:
		r.append(n)
	for h in n.get_children():
		r.append_array(_botones(h))
	return r


## Qué dice cada entrada, se dibuje como se dibuje.
func _texto(b: BaseButton) -> String:
	if b.has_meta("texto"):
		return String(b.get_meta("texto"))
	return (b as Button).text if b is Button else ""


func _textos(n: Node) -> Array:
	var r: Array = []
	for b in _botones(n):
		r.append(_texto(b))
	return r


## Al abrir el juego no hay partida a la que volver: sin «Continuar». Y
## «Cargar partida» todavía no existe.
func test_al_abrir_no_hay_continuar_ni_cargar() -> void:
	var t := await _titulo()
	var textos := _textos(t)
	assert_false(textos.has("Continuar"), "no hay a qué volver")
	assert_false(textos.has("Cargar partida"), "todavía no hay qué cargar")
	for que in ["Nueva partida", "Opciones", "Créditos", "Salir"]:
		assert_true(textos.has(que), "está " + que)


## Saliendo al título desde la pausa, la partida sigue viva: «Continuar» sale
## primero y es donde arranca el foco.
func test_desde_la_pausa_aparece_continuar() -> void:
	GameManager.se_puede_continuar = true
	var t := await _titulo()
	var textos := _textos(t)
	assert_true(textos.has("Continuar"), "hay partida a la que volver")
	assert_lt(textos.find("Continuar"), textos.find("Nueva partida"), "y va primero")
	assert_eq(_texto(t.get("_primero")), "Continuar", "con el foco")


func test_empezar_de_nuevo_borra_el_continuar() -> void:
	GameManager.se_puede_continuar = true
	GameManager.reset_progress()
	assert_false(GameManager.se_puede_continuar, "una partida nueva no tiene a qué volver")


## La pausa deja la partida lista para «Continuar» al salir al título.
func test_salir_al_titulo_deja_la_partida_viva() -> void:
	var src := (load("res://scenes/ui/MenuDePausa.gd") as GDScript).source_code
	assert_true(src.contains("GameManager.se_puede_continuar = true"),
		"volver al menú desde la pausa marca que se puede continuar")


## Créditos: una placa que se abre y se cierra con «Volver».
func test_creditos_se_abren_y_se_cierran() -> void:
	var t := await _titulo()
	var creditos: Control = t.get("_creditos")
	assert_not_null(creditos)
	assert_false(creditos.visible, "cerrados al empezar")
	for b in _botones(t):
		if _texto(b) == "Créditos":
			b.pressed.emit()
	assert_true(creditos.visible, "se abren con el botón")
	for b in _botones(creditos):
		if b is Button and (b as Button).text == "Volver":
			b.pressed.emit()
	assert_false(creditos.visible, "y se cierran con Volver")


## Con sus dos imágenes, la entrada es un botón dibujado: reposo y encendido
## para el ratón encima, el foco del mando y el pulsado.
func test_con_imagenes_la_entrada_se_dibuja() -> void:
	var reposo := ImageTexture.create_from_image(Image.create(300, 60, false, Image.FORMAT_RGBA8))
	var activo := ImageTexture.create_from_image(Image.create(300, 60, false, Image.FORMAT_RGBA8))
	var b: TextureButton = TITULO.boton_con_imagenes(reposo, activo, 300.0, "Nueva partida")
	add_child_autofree(b)
	assert_eq(b.texture_normal, reposo)
	# Las palabras las pone el juego encima del dibujo, y se traducen solas.
	var l: Label = b.get_node("Texto")
	assert_eq(l.text, "Nueva partida", "la etiqueta lleva el texto")
	assert_ne(l.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED, "y se traduce con el idioma")
	assert_gt(l.anchor_left, 0.25, "a la derecha del icono")
	assert_almost_eq(b.custom_minimum_size.y, 60.0, 0.5, "alto según el ancho de la columna")
	# Con el ratón encima o el foco se aclara la de reposo, no se pasa a la de
	# oro: así la pantalla no se carga. La de oro es para el pulsado.
	assert_null(b.texture_hover, "con el ratón encima sigue la de reposo")
	assert_null(b.texture_focused, "y con el foco también")
	assert_eq(b.texture_pressed, activo, "la de oro es al pulsar")
	b.grab_focus()
	assert_ne(b.self_modulate, Color.WHITE, "con el foco se aclara")
	b.release_focus()
	assert_eq(b.self_modulate, Color.WHITE)
	assert_true(b.ignore_texture_size, "se escala a la columna")
	# El foco que pone el código al abrir el menú no lo enciende: «Nueva
	# partida» se veía como si tuviera el ratón encima sin tocarlo.
	b.set_meta("foco_silencioso", true)
	b.grab_focus()
	assert_eq(b.self_modulate, Color.WHITE, "el foco inicial no aclara")
	b.release_focus()
	b.grab_focus()
	assert_ne(b.self_modulate, Color.WHITE, "el siguiente, que llega por la cruceta, sí")


## Sin imágenes en la carpeta, la entrada sigue siendo la placa de siempre.
func test_sin_imagenes_sale_la_placa() -> void:
	var t := await _titulo()
	assert_null(t.call("_boton_dibujado", "no_existe"), "sin imagen de reposo, nada")
	assert_null(t.call("_boton_dibujado", ""), "sin clave, nada")


## Sin la imagen encendida, la de reposo se enciende a mano con el foco.
func test_sin_imagen_encendida_se_ilumina_con_el_foco() -> void:
	var reposo := ImageTexture.create_from_image(Image.create(300, 60, false, Image.FORMAT_RGBA8))
	var b: TextureButton = TITULO.boton_con_imagenes(reposo, null)
	add_child_autofree(b)
	assert_null(b.texture_focused, "no hay imagen encendida")
	b.grab_focus()
	assert_ne(b.self_modulate, Color.WHITE, "con el foco brilla")
	b.release_focus()
	assert_eq(b.self_modulate, Color.WHITE, "y sin foco vuelve a su color")


## Los dibujos de verdad están en el proyecto, del mismo tamaño el de reposo y
## el encendido para que la placa no cambie de escala al encenderse.
func test_los_dibujos_del_menu_estan_en_el_proyecto() -> void:
	for clave: String in ["continuar", "nueva_partida", "opciones", "creditos", "salir"]:
		var reposo := TITULO.CARPETA_DE_BOTONES + clave + ".png"
		var activo := TITULO.CARPETA_DE_BOTONES + clave + "_activo.png"
		assert_true(ResourceLoader.exists(reposo), reposo)
		assert_true(ResourceLoader.exists(activo), activo)
		if ResourceLoader.exists(reposo) and ResourceLoader.exists(activo):
			assert_eq((load(reposo) as Texture2D).get_size(), (load(activo) as Texture2D).get_size(),
				clave + ": mismo tamaño en reposo y encendido")
	assert_true(ResourceLoader.exists(TITULO.CARPETA_DE_BOTONES + "seleccionar_zona.png"),
		"Seleccionar zona usa el dibujo de Cargar partida")


## Los créditos son el dibujo de la pantalla entera con el texto subiendo por
## el hueco del medio.
func test_los_creditos_suben_por_el_dibujo() -> void:
	var t := await _titulo()
	var creditos: Control = t.get("_creditos")
	var dibujo: TextureRect = creditos.find_child("Dibujo", true, false)
	assert_not_null(dibujo, "está el dibujo")
	assert_not_null(dibujo.texture, "con la imagen de créditos")
	creditos.visible = true
	await wait_frames(2)
	var rollo: Control = t.get("_rollo")
	var textos := ""
	for h in rollo.get_children():
		if h is Label:
			textos += (h as Label).text + "\n"
	assert_true(textos.contains("Studios Conari"), "dice quién lo hace")
	for quien in ["María Inés Cisterna Escobar", "Catalina Verónica Valenzuela Vergara", "Kevin Alexis Del Rio Morgado"]:
		assert_true(textos.contains(quien), quien + " está en los créditos")
	assert_true(textos.contains("Lead Programmer"), "con sus cargos")
	var y0 := rollo.position.y
	t.call("_process", 1.0)
	assert_lt(rollo.position.y, y0, "y sube con el tiempo")
	creditos.visible = false


## Antes del menú, la puerta: sólo «Presiona cualquier botón» en medio. Al
## pulsar algo se enciende y, pasado el destello, sale el menú con el foco.
func test_la_puerta_tapa_el_menu_hasta_pulsar_algo() -> void:
	var t := await _titulo()
	var puerta: TextureRect = t.get("_puerta")
	var columna: Control = t.get("_columna")
	assert_not_null(puerta, "hay puerta")
	assert_true(puerta.visible, "se ve")
	assert_false(columna.visible, "y el menú no")
	var reposo := puerta.texture
	var e := InputEventKey.new()
	e.pressed = true
	e.keycode = KEY_SPACE
	t.call("_input", e)
	assert_ne(puerta.texture, reposo, "al pulsar se enciende")
	assert_false(columna.visible, "el menú todavía no: dura el destello")
	await wait_seconds(t.DESTELLO_DE_LA_PUERTA + 0.1)
	assert_false(puerta.visible, "pasado el destello la puerta se va")
	assert_true(columna.visible, "y sale el menú")
	await wait_frames(2)
	assert_true((t.get("_primero") as Control).has_focus(), "con el foco en la primera entrada")


func test_mover_el_raton_no_abre_la_puerta() -> void:
	var t := await _titulo()
	var m := InputEventMouseMotion.new()
	t.call("_input", m)
	assert_false(bool(t.get("_puerta_abierta")), "mover el ratón no cuenta")


func test_volviendo_del_juego_no_hay_puerta() -> void:
	GameManager.se_puede_continuar = true
	var t := await _titulo()
	assert_null(t.get("_puerta"), "ya se estaba jugando: directo al menú")
	assert_true((t.get("_columna") as Control).visible)


## El selector de zonas («Cargar partida») va dentro del marco dibujado, con
## la lista de paradas y «Volver» en el hueco.
func test_el_selector_de_zonas_va_en_su_marco() -> void:
	var t := await _titulo()
	var zonas: Control = t.get("_zonas")
	var dibujo: TextureRect = zonas.find_child("Dibujo", true, false)
	assert_not_null(dibujo, "está el marco dibujado")
	assert_not_null(dibujo.texture, "con su imagen")
	var caja: AspectRatioContainer = dibujo.get_parent().get_parent()
	assert_almost_eq(caja.ratio, 1.0 / t.PROPORCION_DEL_MARCO, 0.001, "con la proporción del dibujo")
	var textos := _textos(zonas)
	assert_true(textos.has("Volver"), "con Volver dentro")
	assert_true(textos.has("1 La Tirana"), "y las paradas")


## Tres portadas: la de inicio con la puerta, la del menú al pasarla y la de
## Opciones mientras están abiertas, con fundido entre una y otra.
func test_la_portada_cambia_con_la_puerta_y_con_opciones() -> void:
	var t := await _titulo()
	assert_eq(t.get("_portada_actual"), "inicio", "con la puerta, la de inicio")
	var abajo: TextureRect = t.get("_portada_de_abajo")
	assert_not_null(abajo.texture, "y está puesta")
	t.call("_entrar_al_menu")
	assert_eq(t.get("_portada_actual"), "menu", "al pasar la puerta, la del menú")
	var arriba: TextureRect = t.get("_portada_de_arriba")
	assert_lt(arriba.modulate.a, 1.0, "entra con fundido, no de golpe")
	await wait_seconds(t.FUNDIDO_DE_PORTADA + 0.2)
	assert_eq(abajo.texture.resource_path, t.PORTADAS["menu"], "y al terminar queda abajo")
	(t.get("_options") as Control).visible = true
	assert_eq(t.get("_portada_actual"), "opciones", "con Opciones, la suya")
	assert_false((t.get("_columna") as Control).visible, "y el menú escondido debajo")
	(t.get("_options") as Control).visible = false
	assert_eq(t.get("_portada_actual"), "menu", "y al cerrarlas, la del menú")
	assert_true((t.get("_columna") as Control).visible, "con el menú de vuelta")


func test_volviendo_del_juego_arranca_en_la_del_menu() -> void:
	GameManager.se_puede_continuar = true
	var t := await _titulo()
	assert_eq(t.get("_portada_actual"), "menu")

