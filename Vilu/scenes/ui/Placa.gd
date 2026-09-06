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
