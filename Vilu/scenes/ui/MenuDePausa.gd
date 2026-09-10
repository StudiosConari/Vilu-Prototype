extends CanvasLayer

## El menú de pausa: [ESC] para y muestra qué se puede hacer.
##
## Continuar, Opciones, Reiniciar y Volver al título. Es lo que faltaba para
## poder probar el prototipo sin cerrar la ventana: hasta ahora, empezada una
## zona, la única salida era Alt+F4.
##
## PARA DE VERDAD: `get_tree().paused` congela el mundo, los enemigos y los
## temporizadores. El menú sigue vivo porque es lo único con
## `PROCESS_MODE_ALWAYS`; sin eso se pausaría a sí mismo y no habría manera de
## reanudar.

const PLACA := preload("res://scenes/ui/Placa.gd")
const OPCIONES := preload("res://scenes/ui/PanelOpciones.gd")
const TITULO := "res://scenes/TitleScreen.tscn"

## Ancho del panel, en píxeles de interfaz.
const ANCHO := 520.0

## Las hojas de movimientos a los lados: Emilia a la izquierda, Benjamín a la
## derecha. Cada fila es lo que se hace y con qué acciones del mapa; la tecla o
## el botón se leen del mapa de entrada al abrir la pausa, así que respetan lo
## que se haya cambiado en opciones y salen en botones si se juega con mando.
const CONTROLES := preload("res://scenes/ui/PanelDeControles.gd")
const ANCHO_HOJA := 340.0
const MOVIMIENTOS := {
	"Emilia": [
		{"que": "Combo de 4 golpes",          "acciones": ["attack"]},
		{"que": "Golpe cargado (mantener)",   "acciones": ["attack"]},
		{"que": "Doble salto",                "acciones": ["jump"]},
		{"que": "Planear (mantener)",         "acciones": ["jump"]},
	],
	"Benjamín": [
		{"que": "Disparo rápido",             "acciones": ["attack"]},
		{"que": "Disparo cargado (mantener)", "acciones": ["attack"]},
		{"que": "Flecha triple",              "acciones": ["triple_arrow"]},
		{"que": "Guanaco: invocar",           "acciones": ["guanaco"]},
		{"que": "Guanaco: montar",            "acciones": ["guanaco_montar"]},
		{"que": "Guanaco: embestir",          "acciones": ["guanaco_charge"]},
	],
	# Lo que tienen en común va debajo del menú, una sola vez.
	"Los dos": [
		{"que": "Moverse / correr",  "acciones": ["move_forward", "move_left", "move_back", "move_right", "run"]},
		{"que": "Saltar",            "acciones": ["jump"]},
		{"que": "Rodar",             "acciones": ["rodar"]},
		{"que": "Hablar / usar",     "acciones": ["interact"]},
		{"que": "Cambiar (te sigue)", "acciones": ["swap_ai"]},
		{"que": "Cambiar (anclado)", "acciones": ["swap_hold"]},
	],
}
var _hojas := {}

var _panel: Control = null
var _opciones: Control = null
var _seguir: Button = null
var _opts: Button = null
## Verdadero mientras haya un diálogo en pantalla.
##
## El globo usa [ESC] para saltar la línea y se traga todas las teclas mientras
## habla. Abrir la pausa encima sería pausar el diálogo con el diálogo delante.
var _hablando := false


func _ready() -> void:
	# Lo único que sigue corriendo con el juego parado.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	add_to_group("menu_de_pausa")
	_construir()
	DialogueManager.dialogue_started.connect(func(_r: Resource) -> void:
		_hablando = true)
	DialogueManager.dialogue_ended.connect(func(_r: Resource) -> void:
		_hablando = false)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# Con las opciones abiertas, [ESC] —o la B del mando— cierra lo que esté más
	# encima y deja la pausa puesta: es lo que espera cualquiera que haya entrado
	# a mirar el volumen. Una hoja de controles abierta se cierra primero, y
	# mientras esté capturando un botón nuevo no se cierra nada: ese botón es la
	# respuesta.
	if _opciones.visible:
		if _capturando_un_control():
			return
		OPCIONES.cerrar_lo_de_encima(_opciones)
		get_viewport().set_input_as_handled()
		return
	if _panel.visible:
		_reanudar()
		get_viewport().set_input_as_handled()
		return
	if not _se_puede_pausar():
		return
	_pausar()
	get_viewport().set_input_as_handled()


## Cuándo NO se abre: mientras alguien habla y mientras haya otra pantalla
## encima, que ya usan [ESC] para lo suyo.
func _se_puede_pausar() -> bool:
	if _hablando:
		return false
	for n in get_tree().get_nodes_in_group("pantalla_modal"):
		if n is CanvasItem and (n as CanvasItem).visible:
			return false
	return true


func _capturando_un_control() -> bool:
	for h in get_tree().get_nodes_in_group("hoja_de_controles"):
		if h is CanvasItem and (h as CanvasItem).visible and String(h.get("_capturando")) != "":
			return true
	return false


func _pausar() -> void:
	_refrescar_hojas()
	_panel.visible = true
	get_tree().paused = true
	# El foco al primer botón: sin él, el mando no tiene por dónde empezar.
	if _seguir != null:
		_seguir.call_deferred("grab_focus")


func _reanudar() -> void:
	_opciones.visible = false
	_panel.visible = false
	get_tree().paused = false


## Reinicia la partida: al principio del todo y con la cadena en su primera
## misión.
##
## Antes sólo recargaba la escena dejando el progreso: los logros y las
## habilidades viven en GameManager, que es autoload y no se recarga, así que
## volvías a la primera zona con la misión de la última —«Revisa a los 4
## cazadores» en el poblado—. Reiniciar es empezar de cero, como «Nueva
## partida».
func _reiniciar() -> void:
	get_tree().paused = false
	GameManager.reset_progress()
	_recargar.call()


## Lo que vuelve a cargar la escena. Va aparte para que un test pueda pulsar
## «Reiniciar» sin recargar la escena de las pruebas.
var _recargar: Callable = func() -> void:
	get_tree().reload_current_scene()


func _al_titulo() -> void:
	get_tree().paused = false
	# La partida sigue viva en los autoloads: el título ofrece «Continuar».
	GameManager.se_puede_continuar = true
	get_tree().change_scene_to_file(TITULO)


## Una hoja de movimientos, vacía: las filas se escriben al abrir la pausa.
func _hoja(quien: String) -> Control:
	var placa := PanelContainer.new()
	placa.name = "Hoja" + quien.replace(" ", "")
	placa.custom_minimum_size = Vector2(ANCHO_HOJA, 0)
	placa.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	placa.add_theme_stylebox_override("panel", PLACA.estilo(0.0, 0.88, 18))
	var aire := MarginContainer.new()
	aire.add_theme_constant_override("margin_top", 18)
	aire.add_theme_constant_override("margin_bottom", 18)
	placa.add_child(aire)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	aire.add_child(vb)
	vb.add_child(PLACA.lema(quien.to_upper(), 22))
	vb.add_child(PLACA.filete())
	var filas := VBoxContainer.new()
	filas.name = "Filas"
	filas.add_theme_constant_override("separation", 6)
	vb.add_child(filas)
	_hojas[quien] = filas
	return placa


## Escribe las filas con las teclas de AHORA.
func _refrescar_hojas() -> void:
	var con_mando := Botones.usando_mando()
	for quien: String in _hojas:
		var filas: VBoxContainer = _hojas[quien]
		for h in filas.get_children():
			h.free()
		for mov: Dictionary in MOVIMIENTOS[quien]:
			filas.add_child(_fila(String(mov["que"]), CONTROLES.describir(mov, con_mando)))


func _fila(que: String, con: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var a := Label.new()
	a.text = que
	a.add_theme_font_size_override("font_size", 15)
	a.add_theme_color_override("font_color", PLACA.LETRA)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	var b := Label.new()
	b.text = con
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", PLACA.ORO_VIVO)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(b)
	return h


func _construir() -> void:
	_panel = Control.new()
	_panel.name = "Pausa"
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	add_child(_panel)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.06, 0.78)
	_panel.add_child(dim)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(cc)

	# Tres placas en fila: Emilia, el menú, Benjamín.
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 22)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(fila)
	fila.add_child(_hoja("Emilia"))

	# En el medio, el menú y debajo lo que comparten los dos.
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 22)
	columna.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(columna)

	var marco := PanelContainer.new()
	marco.custom_minimum_size = Vector2(ANCHO, 0)
	marco.add_theme_stylebox_override("panel", PLACA.estilo(0.0, 0.92, 26))
	columna.add_child(marco)

	var aire := MarginContainer.new()
	aire.add_theme_constant_override("margin_top", 26)
	aire.add_theme_constant_override("margin_bottom", 26)
	marco.add_child(aire)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	aire.add_child(vb)
	vb.add_child(PLACA.lema("PAUSA", 34))
	vb.add_child(PLACA.filete())

	var seguir := PLACA.boton("Continuar")
	seguir.pressed.connect(_reanudar)
	vb.add_child(seguir)
	_seguir = seguir

	var opts := PLACA.boton("Opciones")
	opts.pressed.connect(func() -> void: _opciones.visible = true)
	vb.add_child(opts)
	_opts = opts

	var otra := PLACA.boton("Reiniciar")
	otra.pressed.connect(_reiniciar)
	vb.add_child(otra)

	var salir := PLACA.boton("Volver al menú")
	salir.pressed.connect(_al_titulo)
	vb.add_child(salir)

	columna.add_child(_hoja("Los dos"))
	fila.add_child(_hoja("Benjamín"))
	_refrescar_hojas()

	# Las opciones van ENCIMA de la pausa y cuelgan de la capa, no del panel:
	# así siguen visibles aunque la pausa se esconda por lo que sea.
	_opciones = OPCIONES.construir()
	add_child(_opciones)
	# Al cerrarlas, el foco vuelve al botón que las abrió.
	_opciones.visibility_changed.connect(func() -> void:
		if not _opciones.visible and _panel.visible and _opts != null:
			_opts.call_deferred("grab_focus"))
