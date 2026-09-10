extends Control

## La hoja de controles de una clase —teclado y ratón, o mando—, y donde se
## cambian.
##
## Cada fila que se puede cambiar es un botón: se pulsa, la fila dice «Pulsa…»,
## y lo siguiente que se toque queda asignado. Si ese botón ya lo usaba otra
## acción, se intercambian. Todo se guarda y vuelve al arrancar.
##
## Las filas de moverse y mirar no se tocan: son el stick y el ratón, y
## reasignar cuatro direcciones de a una no es una opción, es una trampa.
##
## CÓMO ESTÁ HECHA. La hoja es un DIBUJO —`textures/ui/controles_teclado.png`
## y `controles_mando.png`— con el marco, el título, el teclado o el mando de
## adorno y dieciséis filas con su icono y una caja vacía. Encima de cada caja
## va el botón de verdad, colocado por fracciones del dibujo, con la tecla o el
## botón que haya puesto AHORA; el nombre de cada fila lo escribe el juego,
## para que salga en el idioma puesto. El dibujo traía cuatro filas de cosas
## que el juego no tiene —agacharse, inventario, habilidades, emociones—: la
## primera es ahora «Montar guanaco» y las otras tres se quitaron subiendo las
## cuatro últimas filas. La cámara es fija, así que no hay filas de mirar.
##
## Con mando: se navega con la cruceta o el stick, A cambia, B vuelve.

const PLACA := preload("res://scenes/ui/Placa.gd")
const REMAPEO := preload("res://scenes/core/Remapeo.gd")
## Con `load` y no `preload`: PanelDeControles precarga esta hoja, y dos
## guiones que se precargan el uno al otro no compilan.
var CONTROLES: GDScript = load("res://scenes/ui/PanelDeControles.gd")

## Los dibujos, por clase.
const DIBUJOS := {
	false: "res://textures/ui/controles_teclado.png",
	true: "res://textures/ui/controles_mando.png",
}

## Ancho de la hoja, en píxeles de interfaz; el alto sale del dibujo.
const ANCHO := 1240.0
const PROPORCION := 1168.0 / 2048.0

## Dónde caen las cajas de cada fila, en fracciones del dibujo. Medidas sobre
## el original de 4096 × 2336. Las dos hojas no coinciden al píxel.
const CAJA_X := Vector2(0.8118, 0.9419)
const ROTULO_X := Vector2(0.5884, 0.8032)
const FILAS_Y := {
	false: [[0.1742, 0.2008], [0.2145, 0.2410], [0.2543, 0.2812], [0.2945, 0.3206],
		[0.3343, 0.3609], [0.3737, 0.4003], [0.4131, 0.4401], [0.4533, 0.4803],
		[0.4936, 0.5201], [0.5334, 0.5599], [0.5736, 0.6002], [0.6134, 0.6391],
		[0.6524, 0.6789], [0.6926, 0.7188], [0.7329, 0.7590], [0.7727, 0.7992]],
	true: [[0.1734, 0.2021], [0.2136, 0.2419], [0.2534, 0.2821], [0.2937, 0.3223],
		[0.3335, 0.3617], [0.3720, 0.4007], [0.4118, 0.4405], [0.4516, 0.4807],
		[0.4914, 0.5205], [0.5317, 0.5604], [0.5719, 0.6006], [0.6117, 0.6400],
		[0.6503, 0.6794], [0.6901, 0.7192], [0.7299, 0.7590], [0.7701, 0.7988]],
}

## Qué va en cada fila del dibujo, en su orden. Los rótulos se borraron del
## dibujo —quedan los iconos— y los escribe el juego, que así los traduce.
## `fija`: se enseña pero no se cambia.
const FILAS := [
	{"que": "Arriba", "acciones": ["move_forward"], "fija": true},
	{"que": "Abajo", "acciones": ["move_back"], "fija": true},
	{"que": "Izquierda", "acciones": ["move_left"], "fija": true},
	{"que": "Derecha", "acciones": ["move_right"], "fija": true},
	{"que": "Correr", "acciones": ["run"]},
	{"que": "Saltar", "acciones": ["jump"]},
	{"que": "Atacar", "acciones": ["attack"]},
	{"que": "Interactuar", "acciones": ["interact"]},
	{"que": "Invocar", "acciones": ["guanaco"]},
	{"que": "Triple Flecha", "acciones": ["triple_arrow"]},
	{"que": "Rodar", "acciones": ["rodar"]},
	{"que": "Montar guanaco", "acciones": ["guanaco_montar"]},
	{"que": "Cambiar Personaje (Seguir)", "acciones": ["swap_ai"]},
	{"que": "Cambiar Personaje (Anclar)", "acciones": ["swap_hold"]},
	{"que": "Menú de Pausa", "acciones": ["ui_cancel"]},
	{"que": "Carga (Ataque de Invocación)", "acciones": ["guanaco_charge"]},
]

## Dónde van «Restablecer» y «Volver», en el hueco que deja cada dibujo: bajo
## el mando en una, a la izquierda del ratón en la otra.
const ABAJO := {
	false: [Rect2(0.045, 0.60, 0.16, 0.06), Rect2(0.045, 0.68, 0.16, 0.06)],
	true: [Rect2(0.10, 0.845, 0.19, 0.06), Rect2(0.31, 0.845, 0.19, 0.06)],
}
## La ayuda va al pie de la lista, en el hueco que dejaron las filas quitadas:
## arriba se montaba sobre el título.
const AYUDA := Rect2(0.545, 0.83, 0.40, 0.09)

const ORO := Color(0.96, 0.84, 0.46)
const LETRA := Color(0.96, 0.93, 0.85)
const ESPERANDO := Color(1.0, 1.0, 1.0)

## Cuánto se espera a que pulses algo antes de dejarlo como estaba.
const ESPERA := 5.0

var con_mando := false
## La acción que espera un botón, o "" si ninguna.
var _capturando := ""
var _restante := 0.0
## Acción -> botón que enseña con qué se hace.
var _botones: Dictionary = {}
var _primero: Control = null
var _volver: Button = null
var _lienzo: Control = null
## La letra del dibujo es una serif: se pide la del sistema que más se le
## parece, y si no está, la de siempre.
var _fuente: Font = null


func montar(mando: bool) -> void:
	con_mando = mando
	name = "PanelDeControles"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	# Con el juego en pausa esto sigue vivo: la hoja también se abre desde el
	# menú de pausa, y ahí todo lo demás está congelado.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fuente = _serif()

	# Un velo ligero: detrás tiene que seguir viéndose la portada, no negro.
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.06, 0.45)
	add_child(dim)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)

	_lienzo = Control.new()
	_lienzo.name = "Lienzo"
	_lienzo.custom_minimum_size = Vector2(ANCHO, ANCHO * PROPORCION)
	cc.add_child(_lienzo)

	var dibujo := TextureRect.new()
	dibujo.name = "Dibujo"
	dibujo.set_anchors_preset(Control.PRESET_FULL_RECT)
	dibujo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dibujo.stretch_mode = TextureRect.STRETCH_SCALE
	var ruta := String(DIBUJOS[con_mando])
	if ResourceLoader.exists(ruta):
		dibujo.texture = load(ruta)
	dibujo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lienzo.add_child(dibujo)

	var ayuda := Label.new()
	ayuda.name = "Ayuda"
	ayuda.text = "Pulsa una caja y luego el botón nuevo. Si ya estaba en uso, se intercambian."
	ayuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ayuda.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ayuda.add_theme_font_size_override("font_size", 13)
	ayuda.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	_colocar(ayuda, AYUDA)

	var filas: Array = FILAS_Y[con_mando]
	for i in FILAS.size():
		var f: Dictionary = FILAS[i]
		var y: Array = filas[i]
		if f.has("que"):
			var rotulo := Label.new()
			rotulo.name = "Rotulo%d" % i
			rotulo.text = String(f["que"])
			rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			rotulo.add_theme_font_override("font", _fuente)
			rotulo.add_theme_font_size_override("font_size", 15)
			rotulo.add_theme_color_override("font_color", LETRA)
			_colocar(rotulo, Rect2(ROTULO_X.x, y[0], ROTULO_X.y - ROTULO_X.x, y[1] - y[0]))
		var caja := Rect2(CAJA_X.x, y[0], CAJA_X.y - CAJA_X.x, y[1] - y[0])
		_colocar(_control_de(f), caja)

	var abajo: Array = ABAJO[con_mando]
	var reset := _boton_de_abajo("Restablecer")
	reset.pressed.connect(_restablecer)
	_colocar(reset, abajo[0])
	_volver = _boton_de_abajo("Volver")
	_volver.pressed.connect(func() -> void: visible = false)
	_colocar(_volver, abajo[1])

	if _primero == null:
		_primero = _volver
	PLACA.enfocar_al_mostrar(self, _primero)


## Ancla un control al hueco que le toca en el dibujo.
func _colocar(c: Control, r: Rect2) -> void:
	c.anchor_left = r.position.x
	c.anchor_top = r.position.y
	c.anchor_right = r.end.x
	c.anchor_bottom = r.end.y
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = 0.0
	c.offset_bottom = 0.0
	_lienzo.add_child(c)


## Lo que va dentro de la caja de una fila: un botón si se puede cambiar, y si
## no, el texto tal cual.
func _control_de(f: Dictionary) -> Control:
	var como: String = CONTROLES.describir(f, con_mando)
	if como == "":
		como = "—"
	var editable: bool = not bool(f.get("fija", false)) \
		and f["acciones"].size() == 1 and String(f["acciones"][0]) in REMAPEO.EDITABLES
	if not editable:
		var l := Label.new()
		l.text = como
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", _fuente)
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", ORO)
		return l
	var accion := String(f["acciones"][0])
	var boton := Button.new()
	boton.name = accion
	boton.text = como
	boton.add_theme_font_override("font", _fuente)
	boton.add_theme_font_size_override("font_size", 14)
	boton.add_theme_color_override("font_color", ORO)
	boton.add_theme_color_override("font_hover_color", Color.WHITE)
	boton.add_theme_color_override("font_focus_color", Color.WHITE)
	boton.add_theme_color_override("font_pressed_color", Color.WHITE)
	# La caja ya viene pintada: el botón es transparente y sólo se nota con el
	# ratón encima o el foco, con un relleno dorado suave.
	boton.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	boton.add_theme_stylebox_override("hover", _relleno(0.14))
	boton.add_theme_stylebox_override("pressed", _relleno(0.26))
	boton.add_theme_stylebox_override("focus", _relleno(0.18))
	boton.pressed.connect(_empezar_captura.bind(accion))
	_botones[accion] = boton
	if _primero == null:
		_primero = boton
	return boton


func _relleno(cuanto: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(ORO.r, ORO.g, ORO.b, cuanto)
	sb.set_corner_radius_all(4)
	return sb


func _boton_de_abajo(texto: String) -> Button:
	var b := PLACA.boton(texto)
	b.custom_minimum_size = Vector2.ZERO
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_constant_override("h_separation", 8)
	return b


## La letra serif del sistema, si la hay. En Windows, Georgia; si no, la que
## traiga el motor.
static func _serif() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Georgia", "Times New Roman", "Liberation Serif", "DejaVu Serif"])
	return f


func _empezar_captura(accion: String) -> void:
	if _capturando != "":
		_refrescar()
	_capturando = accion
	_restante = ESPERA
	var b: Button = _botones[accion]
	b.text = "Pulsa…"
	b.add_theme_color_override("font_color", ESPERANDO)
	# Que el botón que se acaba de pulsar no cuente como respuesta: el evento de
	# soltarlo ya pasó, pero con mando la A sigue abajo un cuadro más.
	set_process(true)


func _process(delta: float) -> void:
	if _capturando == "":
		set_process(false)
		return
	_restante -= delta
	if _restante <= 0.0:
		_capturando = ""
		_refrescar()


## Lo siguiente que se pulse va a la acción que espera. Va en `_input` y no en
## `_unhandled_input`: el botón enfocado se tragaría la A del mando antes.
func _input(e: InputEvent) -> void:
	if _capturando == "" or not visible:
		return
	# Esc suelta la captura sin cambiar nada.
	if e is InputEventKey and (e as InputEventKey).pressed and REMAPEO.es_escape(e as InputEventKey):
		_capturando = ""
		_refrescar()
		get_viewport().set_input_as_handled()
		return
	# Soltar el botón con el que se pulsó «cambiar» llega aquí primero; se deja pasar.
	if not REMAPEO.es_asignable(e, con_mando):
		if (e is InputEventKey or e is InputEventMouseButton or e is InputEventJoypadButton):
			get_viewport().set_input_as_handled()
		return
	var accion := _capturando
	_capturando = ""
	var mapa: Dictionary = REMAPEO.asignar(Save.controles, accion, e, con_mando)
	Save.set_controles(mapa)
	_refrescar()
	get_viewport().set_input_as_handled()
	# El foco vuelve al botón que se cambió, para seguir bajando con la cruceta.
	if _botones.has(accion):
		(_botones[accion] as Button).grab_focus()


func _restablecer() -> void:
	_capturando = ""
	Save.set_controles({})
	_refrescar()


## Vuelve a leer del InputMap qué hay en cada fila.
func _refrescar() -> void:
	for f: Dictionary in FILAS:
		if f["acciones"].size() != 1:
			continue
		var accion := String(f["acciones"][0])
		if not _botones.has(accion):
			continue
		var b: Button = _botones[accion]
		var como: String = CONTROLES.describir(f, con_mando)
		b.text = como if como != "" else "—"
		b.add_theme_color_override("font_color", ORO)
