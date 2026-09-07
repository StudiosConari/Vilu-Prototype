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
	var hay := false
	for t: String in _textos(p):
		if t.begins_with("Pantalla:"):
			hay = true
	assert_true(hay, "las opciones traen el ajuste de pantalla")


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
	var ts := _textos(p)
	assert_has(ts, "Controles: teclado y ratón")
	assert_has(ts, "Controles: gamepad")


func test_la_chuleta_del_mando_dice_botones_de_mando() -> void:
	var p: Control = CONTROLES.construir(true)
	add_child_autofree(p)
	var ts := _textos(p)
	assert_has(ts, "GAMEPAD")
	# Los nombres salen del InputMap: si el mapa cambia, esto cambia con él.
	var todo := " ".join(PackedStringArray(ts))
	assert_true("Stick izquierdo" in todo, "moverse es el stick izquierdo")
	assert_true("Stick derecho" in todo, "mirar es el stick derecho")
	assert_false("W" in todo.split(" "), "no se cuelan teclas")


func test_la_chuleta_del_teclado_dice_teclas() -> void:
	var p: Control = CONTROLES.construir(false)
	add_child_autofree(p)
	var todo := " ".join(PackedStringArray(_textos(p)))
	assert_true("TECLADO" in todo, "es la del teclado")
	assert_true("W" in todo, "sale la W de avanzar")
	assert_false("Stick" in todo, "y ningún stick")


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
