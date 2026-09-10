extends CanvasLayer

## Pantalla de cierre: se muestra al conseguir los nueve logros del prototipo.
##
## Lista los logros en el orden de juego, con el título de cada uno, para que el
## cierre resuma el recorrido en vez de ser un cartel suelto.
##
## Se construye por código, como el resto de la interfaz del proyecto, y se
## cuelga de un CanvasLayer alto para que quede por encima del HUD.

const PLACA := preload("res://scenes/ui/Placa.gd")

const COLOR_FONDO   := Color(0.05, 0.05, 0.09, 1.0)
const COLOR_TITULO  := Color(1.0, 0.85, 0.4)
const COLOR_TEXTO   := Color(0.90, 0.90, 0.95)
const COLOR_HECHO   := Color(0.55, 0.90, 0.60)
const COLOR_PENDIENTE := Color(0.55, 0.55, 0.62)


## Levanta la pantalla dentro de `padre`. Devuelve el nodo, por si hay que
## quitarlo a mano.
static func mostrar(padre: Node) -> CanvasLayer:
	var p := new()
	p.layer = 120
	padre.add_child(p)
	return p


func _ready() -> void:
	# Al grupo de pantallas modales: es lo que hace que Game suelte el ratón.
	# Sin esto el cierre salía con el puntero capturado y no se podía pulsar
	# «Volver al título» — no había cursor con el que apuntar.
	add_to_group("pantalla_modal")
	# El HUD se esconde: si no, la vida y la energía se transparentan detrás del
	# cierre y le quitan el aire.
	var hud := get_tree().get_first_node_in_group("hud")
	# Se comprueba la PROPIEDAD, no la clase: el HUD puede ser un Control o un
	# CanvasLayer, y CanvasLayer tiene `visible` pero NO es un CanvasItem, así
	# que un `is CanvasItem` lo dejaba encendido detrás del cierre.
	if hud != null and "visible" in hud:
		hud.set("visible", false)

	var fondo := ColorRect.new()
	fondo.color = COLOR_FONDO
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	# La misma ilustración y la misma placa que el menú, la pausa y el final:
	# ésta es la última pantalla del prototipo y era la única que seguía siendo
	# texto suelto sobre negro.
	var con_arte := PLACA.fondo(self, 0.6)

	# El mismo marco dibujado que el selector de zonas: la estrella y las alas
	# arriba, y la lista en el hueco. Sin el dibujo, la placa de siempre.
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(raiz)
	var aire := PLACA.marco_dibujado(raiz)
	aire.add_theme_constant_override("margin_left", 30)
	aire.add_theme_constant_override("margin_right", 30)

	var caja := VBoxContainer.new()
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 8)
	aire.add_child(caja)

	# El "VILU" escrito sólo si no está el arte: la ilustración ya lo trae.
	if not con_arte:
		caja.add_child(_texto("VILU", 64, COLOR_TITULO))
	caja.add_child(PLACA.lema("PROTOTIPO SUPERADO", 30))
	caja.add_child(PLACA.filete())

	for l in GameManager.LOGROS:
		caja.add_child(_linea_de_logro(l))

	caja.add_child(_espacio(8))
	var hechos := GameManager.logros_obtenidos()
	caja.add_child(_texto(tr("%d de %d logros") % [hechos, GameManager.LOGROS.size()],
		20, COLOR_TEXTO))
	caja.add_child(_espacio(4))

	var boton := PLACA.boton("Volver al título")
	boton.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn"))
	caja.add_child(boton)
	boton.grab_focus()


## Una fila: marca, título y, si falta, la pista de cómo conseguirlo.
##
## Normalmente estarán los nueve, pero la pantalla no lo da por hecho: si algún
## día se abre antes de tiempo se ve qué falta en vez de mentir.
func _linea_de_logro(l: Dictionary) -> Control:
	var tiene: bool = GameManager.tiene_logro(l["id"])
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	fila.add_child(_texto("✓" if tiene else "·", 20,
		COLOR_HECHO if tiene else COLOR_PENDIENTE))
	var nombre := _texto(str(l["titulo"]) if tiene else str(l["pista"]), 20,
		COLOR_TEXTO if tiene else COLOR_PENDIENTE)
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	fila.add_child(nombre)
	return fila


func _texto(txt: String, tam: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", col)
	return l


func _espacio(alto: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, alto)
	return c
