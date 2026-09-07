extends RefCounted

## La lista de controles, en dos versiones: teclado y ratón, o mando.
##
## LOS NOMBRES SE LEEN DEL `InputMap`, no están escritos aquí. Una chuleta
## escrita a mano se desincroniza en cuanto alguien mueve una tecla, y entonces
## engaña más de lo que ayuda: el jugador prueba lo que dice la pantalla, no le
## responde, y da por hecho que el juego está roto. Leyéndolo del mapa real,
## cambiar un control cambia la ayuda sola.
##
## Se usa sin instanciar:
##   const CONTROLES := preload("res://scenes/ui/PanelDeControles.gd")
##   add_child(CONTROLES.construir(true))    # true = mando

const PLACA := preload("res://scenes/ui/Placa.gd")

const ANCHO := 660.0
const ORO := Color(0.96, 0.84, 0.46)

## Qué se enseña y con qué acciones se hace.
##
## Varias acciones en una fila es a propósito: al que juega no le importa que
## moverse sean cuatro acciones distintas, le importa que se mueve con WASD o
## con el stick. Los nombres repetidos se juntan en uno.
##
## `sin_mando` y `sin_teclado` son para lo que no está en el mapa de ninguna de
## las dos formas: mirar alrededor con el ratón no es una acción, es el
## movimiento del puntero, y no hay nada en el `InputMap` que enseñar.
const FILAS := [
	{"que": "Moverse",            "acciones": ["move_forward", "move_left", "move_back", "move_right"]},
	{"que": "Mirar alrededor",    "acciones": ["cam_izquierda", "cam_derecha", "cam_arriba", "cam_abajo"],
	 "sin_teclado": "Mover el ratón"},
	{"que": "Correr",             "acciones": ["run"]},
	{"que": "Saltar / planear",   "acciones": ["jump"]},
	{"que": "Rodar",              "acciones": ["rodar"]},
	{"que": "Atacar / tensar",    "acciones": ["attack"]},
	{"que": "Flecha triple",      "acciones": ["triple_arrow"]},
	{"que": "Hablar / usar",      "acciones": ["interact"]},
	{"que": "Guanaco",            "acciones": ["guanaco"]},
	{"que": "Embestida",          "acciones": ["guanaco_charge"]},
	{"que": "Cambiar (te sigue)", "acciones": ["swap_ai"]},
	{"que": "Cambiar (se queda)", "acciones": ["swap_hold"]},
	{"que": "Pausa",              "acciones": ["ui_cancel"]},
]

## Cómo se llaman los botones del mando. Se usan los nombres de Xbox porque son
## los que trae escritos la mayoría de los mandos que se enchufan a un PC; en uno
## de PlayStation cae en el mismo sitio con otra letra.
const BOTONES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Atrás", JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "Cruceta ↑", JOY_BUTTON_DPAD_DOWN: "Cruceta ↓",
	JOY_BUTTON_DPAD_LEFT: "Cruceta ←", JOY_BUTTON_DPAD_RIGHT: "Cruceta →",
}

const EJES := {
	JOY_AXIS_LEFT_X: "Stick izquierdo", JOY_AXIS_LEFT_Y: "Stick izquierdo",
	JOY_AXIS_RIGHT_X: "Stick derecho", JOY_AXIS_RIGHT_Y: "Stick derecho",
	JOY_AXIS_TRIGGER_LEFT: "Gatillo izquierdo", JOY_AXIS_TRIGGER_RIGHT: "Gatillo derecho",
}

const RATON := {
	MOUSE_BUTTON_LEFT: "Clic izquierdo", MOUSE_BUTTON_RIGHT: "Clic derecho",
	MOUSE_BUTTON_MIDDLE: "Clic central",
	MOUSE_BUTTON_WHEEL_UP: "Rueda arriba", MOUSE_BUTTON_WHEEL_DOWN: "Rueda abajo",
}


## Devuelve el panel ya montado y OCULTO. Quien lo pide decide cuándo se ve.
static func construir(con_mando: bool) -> Control:
	var raiz := Control.new()
	raiz.name = "PanelDeControles"
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.visible = false

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.06, 0.90)
	raiz.add_child(dim)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(cc)

	var marco := PanelContainer.new()
	marco.custom_minimum_size = Vector2(ANCHO, 0)
	marco.add_theme_stylebox_override("panel", PLACA.estilo(0.0, 0.94, 26))
	cc.add_child(marco)

	var aire := MarginContainer.new()
	for lado: String in ["top", "bottom"]:
		aire.add_theme_constant_override("margin_" + lado, 22)
	for lado: String in ["left", "right"]:
		aire.add_theme_constant_override("margin_" + lado, 34)
	marco.add_child(aire)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	aire.add_child(vb)
	vb.add_child(PLACA.lema("GAMEPAD" if con_mando else "TECLADO Y RATÓN", 30))
	vb.add_child(PLACA.filete())

	for f: Dictionary in FILAS:
		var como := describir(f, con_mando)
		if como == "":
			continue          # esa fila no se hace de esta manera
		vb.add_child(_fila(String(f["que"]), como))

	vb.add_child(PLACA.filete())
	var volver := PLACA.boton("Volver")
	volver.pressed.connect(func() -> void: raiz.visible = false)
	vb.add_child(volver)
	return raiz


## Con qué se hace esa fila, ya en palabras. "" si no se hace de esa manera.
static func describir(fila: Dictionary, con_mando: bool) -> String:
	var nombres: Array[String] = []
	for a: String in fila["acciones"]:
		if not InputMap.has_action(a):
			continue
		for e in InputMap.action_get_events(a):
			var n := nombre_de(e, con_mando)
			# Repetidos fuera: las cuatro direcciones del stick son un stick, y
			# repetir "Stick izquierdo" cuatro veces no dice nada.
			if n != "" and not nombres.has(n):
				nombres.append(n)
	if nombres.is_empty():
		return String(fila.get("sin_mando" if con_mando else "sin_teclado", ""))
	return "  ".join(nombres)


## Cómo se llama ese evento, o "" si no es de los que toca enseñar ahora.
static func nombre_de(e: InputEvent, con_mando: bool) -> String:
	if con_mando:
		if e is InputEventJoypadButton:
			return String(BOTONES.get((e as InputEventJoypadButton).button_index, ""))
		if e is InputEventJoypadMotion:
			return String(EJES.get((e as InputEventJoypadMotion).axis, ""))
		return ""
	if e is InputEventKey:
		var k := e as InputEventKey
		var c: int = k.physical_keycode if k.physical_keycode != 0 else k.keycode
		if c == 0:
			return ""
		# Se traduce la tecla FÍSICA al símbolo que tiene pintado ESTE teclado: el
		# mapa está hecho por posición, así que en un AZERTY la de avanzar es la
		# que aquí llamamos W pero allí está serigrafiada como Z. Enseñar "W" a
		# quien tiene una Z delante es la clase de ayuda que hace perder tiempo.
		#
		# Sin servidor de pantalla no hay distribución que consultar —los tests
		# corren así—, y entonces se enseña la tecla física tal cual.
		if DisplayServer.get_name() != "headless":
			c = DisplayServer.keyboard_get_keycode_from_physical(c)
		return OS.get_keycode_string(c)
	if e is InputEventMouseButton:
		return String(RATON.get((e as InputEventMouseButton).button_index, ""))
	return ""


static func _fila(que: String, como: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var a := Label.new()
	a.text = que
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.add_theme_font_size_override("font_size", 20)
	a.add_theme_color_override("font_color", Color(0.90, 0.90, 0.95))
	h.add_child(a)
	var b := Label.new()
	b.text = como
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", ORO)
	h.add_child(b)
	return h
