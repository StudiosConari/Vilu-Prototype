extends RefCounted

## El aspecto de las pantallas que van SOBRE la ilustración: menú y final.
##
## Oro sobre tinta de noche, como el título del cuadro. Encima de un dibujo tan
## cargado un texto claro no se lee —el fondo también es claro, y lleno de
## cosas—, así que todo lo que haya que leer va sobre una placa con su marco.
##
## Vive aquí y no en cada pantalla para que las dos se vean iguales: cuando el
## menú cambie de color, el final cambia con él.
##
## Se usa sin instanciar:
##   const PLACA := preload("res://scenes/ui/Placa.gd")
##   vb.add_child(PLACA.boton("JUGAR"))

const ORO := Color(0.80, 0.66, 0.28)
const ORO_VIVO := Color(0.96, 0.84, 0.46)
const TINTA := Color(0.05, 0.08, 0.16)
const LETRA := Color(0.96, 0.93, 0.85)


## El marco: tinta translúcida con filo de oro.
##
## `encendido` es lo que se le suma al pasarle el ratón o al pulsarlo.
static func estilo(encendido := 0.0, opacidad := 0.80,
		margen := 18) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	# El fondo es el mismo en todas. Aclarándolo un poco —como estaba en la
	# primera entrada— parecía pulsada o con el ratón encima: aclarar el relleno
	# es justo lo que significa "la estás tocando", y para eso está `encendido`.
	sb.bg_color = Color(TINTA.r, TINTA.g, TINTA.b, opacidad).lightened(encendido)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = ORO.lightened(encendido)
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 5
	sb.content_margin_left = margen
	sb.content_margin_right = margen
	return sb


## Un botón con placa, con su rombo pegado al filo izquierdo.
##
## TODOS iguales: mismo alto, misma letra y mismo oro. Hubo una versión con la
## primera entrada destacada —más grande y en oro vivo—, pero en pantalla no se
## leía como "ésta es la principal" sino como "ésta está pulsada", y una lista
## de menú en la que un botón parece en otro estado se lee mal aunque sea bonita.
static func boton(texto: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(0, 48)
	b.size_flags_horizontal = Control.SIZE_FILL
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", LETRA)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", ORO_VIVO)
	b.icon = rombo(ORO)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("h_separation", 16)
	b.add_theme_stylebox_override("normal", estilo())
	b.add_theme_stylebox_override("hover", estilo(0.18))
	b.add_theme_stylebox_override("pressed", estilo(0.30))
	b.add_theme_stylebox_override("focus", estilo(0.10))
	return b


## El rombo del margen.
##
## Se dibuja píxel a píxel en vez de escribir el carácter "◆": depender de que
## la fuente lo tenga es depender de la suerte.
static func rombo(color: Color) -> ImageTexture:
	var lado := 18
	var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var mitad := (lado - 1) / 2.0
	for y in lado:
		for x in lado:
			var d: float = absf(x - mitad) + absf(y - mitad)
			if d <= mitad:
				img.set_pixel(x, y, color)
			elif d <= mitad + 1.0:
				# Un pelo de borde suave: sin esto el rombo sale con escalera.
				img.set_pixel(x, y, Color(color.r, color.g, color.b,
					1.0 - (d - mitad)))
	return ImageTexture.create_from_image(img)


## Texto en blanco y en negrita, con las letras separadas.
##
## La negrita sale de engordar la fuente por defecto en vez de cargar un .ttf
## negrita: así no depende de añadir una fuente al proyecto. Y separar las
## letras es lo que hace que una línea en mayúsculas se lea como un lema y no
## como un aviso.
static func lema(txt: String, tamano := 22) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tamano)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	var f := FontVariation.new()
	f.base_font = ThemeDB.fallback_font
	f.variation_embolden = 0.55
	f.spacing_glyph = 4
	l.add_theme_font_override("font", f)
	return l


## El marco dibujado —el panel de «Cargar partida», con la estrella y las
## alas— para las pantallas que llevan una lista: el selector de zonas y el
## cierre de logros. Va alto como la ventana y con su proporción; devuelve el
## contenedor del HUECO de dentro, donde quien lo pide cuelga lo suyo. Sin el
## dibujo, una placa de las de siempre en su lugar.
const MARCO_DIBUJADO := "res://textures/ui/fondo_zonas.png"
const PROPORCION_DEL_MARCO := 0.9816
const HUECO_DEL_MARCO := Rect2(0.07, 0.13, 0.86, 0.80)


static func marco_dibujado(padre: Node, alto_desde := 0.03, alto_hasta := 0.97) -> MarginContainer:
	var caja := AspectRatioContainer.new()
	caja.name = "Marco"
	caja.set_anchors_preset(Control.PRESET_FULL_RECT)
	caja.anchor_top = alto_desde
	caja.anchor_bottom = alto_hasta
	caja.offset_top = 0.0
	caja.offset_bottom = 0.0
	caja.ratio = 1.0 / PROPORCION_DEL_MARCO
	caja.stretch_mode = AspectRatioContainer.STRETCH_FIT
	padre.add_child(caja)

	var lienzo := Control.new()
	lienzo.name = "Lienzo"
	caja.add_child(lienzo)
	if ResourceLoader.exists(MARCO_DIBUJADO):
		var dibujo := TextureRect.new()
		dibujo.name = "Dibujo"
		dibujo.set_anchors_preset(Control.PRESET_FULL_RECT)
		dibujo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dibujo.stretch_mode = TextureRect.STRETCH_SCALE
		dibujo.texture = load(MARCO_DIBUJADO)
		dibujo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lienzo.add_child(dibujo)
	else:
		var placa := PanelContainer.new()
		placa.set_anchors_preset(Control.PRESET_FULL_RECT)
		placa.add_theme_stylebox_override("panel", estilo(0.0, 0.92, 26))
		lienzo.add_child(placa)

	var hueco := MarginContainer.new()
	hueco.name = "Hueco"
	hueco.anchor_left = HUECO_DEL_MARCO.position.x
	hueco.anchor_top = HUECO_DEL_MARCO.position.y
	hueco.anchor_right = HUECO_DEL_MARCO.end.x
	hueco.anchor_bottom = HUECO_DEL_MARCO.end.y
	hueco.offset_left = 0.0
	hueco.offset_top = 0.0
	hueco.offset_right = 0.0
	hueco.offset_bottom = 0.0
	lienzo.add_child(hueco)
	return hueco


## Que al mostrarse un panel el foco caiga en `primero`.
##
## Sin foco, un mando no puede hacer nada en un menú: la cruceta no tiene desde
## dónde moverse y la A no tiene qué pulsar. Con el ratón no se nota, porque el
## ratón no necesita foco, y por eso nadie lo echó de menos hasta que alguien
## probó el juego con mando y no pudo entrar a Opciones.
##
## Diferido: un Control recién mostrado todavía no está dispuesto, y pedirle el
## foco en el mismo cuadro no siempre prende.
static func enfocar_al_mostrar(panel: Control, primero: Control) -> void:
	panel.visibility_changed.connect(func() -> void:
		if panel.visible and is_instance_valid(primero):
			primero.call_deferred("grab_focus"))


## Una lista que se desplaza, con la barra a juego con la placa.
##
## La barra de fábrica era gris, fina y pegada a los botones: parecía el borde
## de la última entrada. Ésta va en el oro del marco, más ancha, y separada de
## la lista por un margen para que se lea como una pieza aparte.
##
## Devuelve [scroll, contenedor]: lo que se liste se cuelga del contenedor.
const ANCHO_DE_BARRA := 14
const AIRE_ANTES_DE_LA_BARRA := 16


static func lista_con_scroll() -> Array:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var barra := scroll.get_v_scroll_bar()
	barra.custom_minimum_size = Vector2(ANCHO_DE_BARRA, 0)
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(TINTA.r, TINTA.g, TINTA.b, 0.55)
	fondo.border_width_left = 1
	fondo.border_width_right = 1
	fondo.border_width_top = 1
	fondo.border_width_bottom = 1
	fondo.border_color = Color(ORO.r, ORO.g, ORO.b, 0.45)
	fondo.corner_radius_top_left = 6
	fondo.corner_radius_top_right = 6
	fondo.corner_radius_bottom_left = 6
	fondo.corner_radius_bottom_right = 6
	barra.add_theme_stylebox_override("scroll", fondo)
	for estado in [["grabber", ORO], ["grabber_highlight", ORO_VIVO], ["grabber_pressed", ORO_VIVO]]:
		var g := StyleBoxFlat.new()
		g.bg_color = estado[1]
		g.corner_radius_top_left = 6
		g.corner_radius_top_right = 6
		g.corner_radius_bottom_left = 6
		g.corner_radius_bottom_right = 6
		g.content_margin_left = 2
		g.content_margin_right = 2
		g.content_margin_top = 2
		g.content_margin_bottom = 2
		barra.add_theme_stylebox_override(String(estado[0]), g)

	# El aire entre la lista y la barra.
	var aire := MarginContainer.new()
	aire.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aire.add_theme_constant_override("margin_right", AIRE_ANTES_DE_LA_BARRA)
	scroll.add_child(aire)
	var contenedor := VBoxContainer.new()
	contenedor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aire.add_child(contenedor)
	return [scroll, contenedor]


## Una raya de oro, para cerrar una columna por abajo.
static func filete() -> Control:
	var caja := MarginContainer.new()
	caja.add_theme_constant_override("margin_top", 16)
	caja.add_theme_constant_override("margin_bottom", 8)
	caja.add_theme_constant_override("margin_left", 40)
	caja.add_theme_constant_override("margin_right", 40)
	var raya := Panel.new()
	raya.custom_minimum_size = Vector2(0, 3)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(ORO.r, ORO.g, ORO.b, 0.75)
	raya.add_theme_stylebox_override("panel", sb)
	caja.add_child(raya)
	return caja


## La ilustración de fondo con su velo, colgada de `padre`.
##
## Devuelve si pudo ponerla; si el archivo no estuviera, quien la pide se queda
## como estaba en vez de quedarse en blanco.
const ARTE := "res://textures/ui/menu.png"


static func fondo(padre: Node, opacidad_del_velo := 0.45) -> bool:
	if not ResourceLoader.exists(ARTE):
		return false
	var tex := load(ARTE) as Texture2D
	if tex == null:
		return false
	var img := TextureRect.new()
	img.texture = tex
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Cubre la pantalla sin deformarse: en una ventana apaisada recorta arriba y
	# abajo, y en una cuadrada por los lados.
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(img)

	var velo := ColorRect.new()
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.color = Color(0.04, 0.05, 0.09, opacidad_del_velo)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(velo)
	return true
