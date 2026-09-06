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

var _panel: Control = null
var _opciones: Control = null
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
	# Con las opciones abiertas, [ESC] las cierra y deja la pausa puesta: es lo
	# que espera cualquiera que haya entrado a mirar el volumen.
	if _opciones.visible:
		_opciones.visible = false
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


func _pausar() -> void:
	_panel.visible = true
	get_tree().paused = true


func _reanudar() -> void:
	_opciones.visible = false
	_panel.visible = false
	get_tree().paused = false


## Reinicia la zona: vuelve a cargar la escena de juego dejando el progreso.
##
## Los logros y las habilidades viven en GameManager, que es autoload y no se
## recarga: reiniciar te devuelve al principio de la partida con lo que ya
## tenías hecho, no te lo quita.
func _reiniciar() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _al_titulo() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITULO)


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

	var marco := PanelContainer.new()
	marco.custom_minimum_size = Vector2(ANCHO, 0)
	marco.add_theme_stylebox_override("panel", PLACA.estilo(0.0, 0.92, 26))
	cc.add_child(marco)

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

	var opts := PLACA.boton("Opciones")
	opts.pressed.connect(func() -> void: _opciones.visible = true)
	vb.add_child(opts)

	var otra := PLACA.boton("Reiniciar")
	otra.pressed.connect(_reiniciar)
	vb.add_child(otra)

	var salir := PLACA.boton("Volver al menú")
	salir.pressed.connect(_al_titulo)
	vb.add_child(salir)

	# Las opciones van ENCIMA de la pausa y cuelgan de la capa, no del panel:
	# así siguen visibles aunque la pausa se esconda por lo que sea.
	_opciones = OPCIONES.construir()
	add_child(_opciones)
