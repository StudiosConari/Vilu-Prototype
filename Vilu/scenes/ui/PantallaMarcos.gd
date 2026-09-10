extends CanvasLayer

## La pantalla de la [P]: el marco de cada personaje y los logros conseguidos.
##
## Lleva el mismo marco dibujado que el selector de zonas y el cierre de logros.
## Arriba, una columna por personaje con su retrato tal como se ve en el HUD
## —sólo el marco, sin el panel— y un selector para cambiar el marco: el clásico o el alternativo,
## que se gana en la cima del Ojos del Salado y hasta entonces sale bloqueado.
## Abajo, la lista de logros con lo que falta.
##
## Para el juego, deja el tiempo parado mientras está abierta —como la pausa—
## y se cierra con [P], [ESC] o el botón.

const PLACA := preload("res://scenes/ui/Placa.gd")
const HUD := preload("res://scenes/ui/HUD.gd")

const PERSONAJES := [["emilia", "Emilia"], ["benjamin", "Benjamín"]]
const OPCIONES := [["clasico", "Clásico"], ["alterno", "Especial"]]
## Lo que dice el selector si se intenta elegir el alterno sin tenerlo. Corto
## a propósito: un texto largo estiraba la columna y deformaba la pantalla.
const BLOQUEADO := "Bloqueado"

const COLOR_TEXTO := Color(0.90, 0.90, 0.95)
const COLOR_HECHO := Color(0.55, 0.90, 0.60)
const COLOR_PENDIENTE := Color(0.55, 0.55, 0.62)
## Sólo el marco —el círculo con la cara—, sin el panel de vida, energía y
## carga: aquí lo que se elige es el marco. Lo que mide se eligió para que las
## dos muestras quepan de sobra en el hueco del marco dibujado: si el
## contenido es más ancho que el hueco, se sale por la derecha y todo queda
## descentrado.
const ALTO_DEL_RETRATO := 130.0

var _retratos := {}
var _etiquetas := {}
var _volver: Button = null
var _estaba_pausado := false


## Levanta la pantalla dentro de `padre`. Devuelve el nodo, por si hay que
## quitarlo a mano.
static func mostrar(padre: Node) -> CanvasLayer:
	var p := new()
	p.layer = 115
	padre.add_child(p)
	return p


func _ready() -> void:
	add_to_group("pantalla_modal")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_estaba_pausado = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var velo := ColorRect.new()
	velo.color = Color(0.02, 0.03, 0.06, 0.55)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(velo)

	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(raiz)
	var aire := PLACA.marco_dibujado(raiz)
	aire.add_theme_constant_override("margin_left", 26)
	aire.add_theme_constant_override("margin_right", 26)
	# Si algo se pasara de ancho, que crezca hacia los dos lados y no sólo
	# hacia la derecha.
	aire.grow_horizontal = Control.GROW_DIRECTION_BOTH

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	aire.add_child(caja)
	caja.add_child(PLACA.lema("MARCOS", 26))

	var columnas := HBoxContainer.new()
	columnas.add_theme_constant_override("separation", 20)
	caja.add_child(columnas)
	for par: Array in PERSONAJES:
		columnas.add_child(_columna(String(par[0]), String(par[1])))

	caja.add_child(PLACA.filete())
	var hechos := GameManager.logros_obtenidos()
	caja.add_child(PLACA.lema(tr("%d de %d logros") % [hechos, GameManager.LOGROS.size()], 18))
	var lista: Array = PLACA.lista_con_scroll()
	caja.add_child(lista[0])
	for l in GameManager.LOGROS:
		(lista[1] as VBoxContainer).add_child(_linea_de_logro(l))

	_volver = PLACA.boton("Volver")
	_volver.pressed.connect(cerrar)
	caja.add_child(_volver)
	_volver.call_deferred("grab_focus")
	_refrescar()


## Una columna: el retrato con su marco, el selector y el nombre.
func _columna(quien: String, nombre: String) -> Control:
	var col := VBoxContainer.new()
	col.name = quien.capitalize()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_theme_constant_override("separation", 4)

	var retrato := TextureRect.new()
	retrato.name = "Retrato"
	retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	retrato.custom_minimum_size = Vector2(ALTO_DEL_RETRATO * HUD.PROPORCION_DEL_RETRATO, ALTO_DEL_RETRATO)
	retrato.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(retrato)
	_retratos[quien] = retrato

	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 8)
	col.add_child(fila)
	var izq := _flecha("<", quien, -1)
	fila.add_child(izq)
	var etiqueta := Label.new()
	etiqueta.name = "Marco"
	etiqueta.custom_minimum_size = Vector2(150, 0)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.add_theme_font_size_override("font_size", 19)
	etiqueta.add_theme_color_override("font_color", PLACA.LETRA)
	fila.add_child(etiqueta)
	_etiquetas[quien] = etiqueta
	fila.add_child(_flecha(">", quien, 1))

	var pie := Label.new()
	pie.name = "Pie"
	pie.text = nombre
	pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pie.add_theme_font_size_override("font_size", 15)
	pie.add_theme_color_override("font_color", COLOR_PENDIENTE)
	col.add_child(pie)
	return col


func _flecha(txt: String, quien: String, paso: int) -> Button:
	var b := Button.new()
	b.name = "Antes" if paso < 0 else "Despues"
	b.text = txt
	b.custom_minimum_size = Vector2(40, 34)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", PLACA.ORO_VIVO)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", PLACA.estilo())
	b.add_theme_stylebox_override("hover", PLACA.estilo(0.18))
	b.add_theme_stylebox_override("pressed", PLACA.estilo(0.30))
	b.add_theme_stylebox_override("focus", PLACA.estilo(0.10))
	b.pressed.connect(func() -> void: cambiar(quien, paso))
	return b


## Pasa al marco siguiente (o anterior) de `quien` y lo guarda.
##
## Con el alterno bloqueado, se queda en el clásico: el selector avisa
## «Bloqueado» y no cambia nada.
func cambiar(quien: String, paso: int) -> void:
	var i := _indice(Save.marco_elegido(quien))
	i = wrapi(i + paso, 0, OPCIONES.size())
	if String(OPCIONES[i][0]) == "alterno" and not GameManager.marco_alterno_disponible():
		_etiquetas[quien].text = tr(BLOQUEADO)
		_etiquetas[quien].add_theme_color_override("font_color", COLOR_PENDIENTE)
		return
	Save.set_marco(quien, String(OPCIONES[i][0]))
	_refrescar()


static func _indice(cual: String) -> int:
	for i in OPCIONES.size():
		if OPCIONES[i][0] == cual:
			return i
	return 0


func _refrescar() -> void:
	for par: Array in PERSONAJES:
		var quien := String(par[0])
		var elegido := GameManager.marco_de(quien)
		var retrato: TextureRect = _retratos[quien]
		retrato.texture = load(HUD.ruta_del_retrato(quien))
		var etiqueta: Label = _etiquetas[quien]
		etiqueta.text = tr(String(OPCIONES[_indice(elegido)][1]))
		etiqueta.add_theme_color_override("font_color", PLACA.LETRA)


## Una fila: marca, título y, si falta, la pista de cómo conseguirlo.
func _linea_de_logro(l: Dictionary) -> Control:
	var tiene: bool = GameManager.tiene_logro(l["id"])
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	fila.add_child(_texto("✓" if tiene else "·", 16, COLOR_HECHO if tiene else COLOR_PENDIENTE))
	var nombre := _texto(str(l["titulo"]) if tiene else str(l["pista"]), 16,
		COLOR_TEXTO if tiene else COLOR_PENDIENTE)
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(nombre)
	return fila


func _texto(txt: String, tam: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", col)
	return l


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") \
			or (InputMap.has_action("marcos") and event.is_action_pressed("marcos")):
		cerrar()
		get_viewport().set_input_as_handled()


func cerrar() -> void:
	if not is_inside_tree():
		return
	get_tree().paused = _estaba_pausado
	queue_free()
