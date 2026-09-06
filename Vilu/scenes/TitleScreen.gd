extends Control

# Menu de inicio: titulo + JUGAR + opciones (volumen) + record + controles.

var _options: Control
var _zonas: Control
var _titulo: Label

const MUNDO_ATACAMA := "res://scenes/core/WorldAtacama.tscn"
## El aspecto de las pantallas que van sobre la ilustración, compartido con el
## final: así las dos se ven iguales sin copiar los colores en cada una.
const PLACA := preload("res://scenes/ui/Placa.gd")
const OPCIONES := preload("res://scenes/ui/PanelOpciones.gd")
## Ancho de los paneles que se abren encima del menú, en píxeles de interfaz.
## Fijo a propósito: es lo que obliga a las descripciones largas a partirse en
## varias líneas en vez de estirar el bloque hasta salirse de la pantalla.
const ANCHO_DEL_PANEL := 860.0

## El recorrido del prototipo, en orden, para el selector de debug.
##
## Cada entrada dice qué LOGRO cierra ahí (`otorga`) y qué HABILIDAD se consigue
## (`desbloquea`). Entrar por una parada da por hecho todo lo de las anteriores,
## que es lo que hace falta para probar el tramo de verdad: el duelo con el
## Chupacabras, por ejemplo, exige los ocho logros previos, así que sin esto se
## llegaba al nido de la mina y no pasaba nada.
##
## Ninguna de las dos cosas se escribe entrada por entrada acumulada: se
## calculan de la propia lista, de modo que reordenar o meter una parada nueva
## no puede desincronizarlas. Cada parada declara sólo lo SUYO.
##
## `mundo` sólo se pone cuando la escena NO está en Tarapacá: los dos mundos son
## copias del mismo poblado, así que "Poblado" a secas es ambiguo. De Alicanto
## al Ojos del Salado se juega en Atacama; después se vuelve a Tarapacá, que es
## adonde te lleva el mapa del Guardián al bajar de la cima.
##
## `otorga` vacío = esa parada no cierra ningún logro: el Bar es una escena de
## paso. La última parada es el Chupacabras: vencerlo cierra el noveno logro y
## con eso salta la pantalla de logros, que es el final del prototipo.
const DEBUG_ZONES := [
	{"nombre": "1 La Tirana", "zona": "Tarapaca", "beat": 0,
	 "otorga": "tirana", "desbloquea": ["bow"], "mundo": ""},
	{"nombre": "2 Mina", "zona": "Mina", "beat": 3,
	 "otorga": "mina", "desbloquea": ["talisman_frag_1"], "mundo": ""},
	{"nombre": "3 Bruja/talismán 1", "zona": "Poblado", "beat": 3,
	 "otorga": "talisman_1", "desbloquea": [], "mundo": ""},
	{"nombre": "4 Isluga", "zona": "Isluga", "beat": 4,
	 "otorga": "isluga", "desbloquea": [], "mundo": ""},
	{"nombre": "5 Alicanto", "zona": "Alicanto", "beat": 5,
	 "otorga": "alicanto", "desbloquea": ["wings"], "mundo": MUNDO_ATACAMA},
	{"nombre": "6 Poblado/Bar", "zona": "Poblado", "beat": 5,
	 "otorga": "", "desbloquea": [], "mundo": MUNDO_ATACAMA},
	{"nombre": "7 Yastay", "zona": "Yastay", "beat": 5,
	 "otorga": "yastay", "desbloquea": ["guanaco", "talisman_frag_2"], "mundo": MUNDO_ATACAMA},
	{"nombre": "8 Bruja/talismán 2", "zona": "Poblado", "beat": 6,
	 "otorga": "talisman_2", "desbloquea": [], "mundo": MUNDO_ATACAMA},
	# Desde la cima se vuelve a Tarapacá con el mapa del Guardián: es la parada
	# que prueba el viaje entre regiones, así que lo de después ya es Tarapacá.
	{"nombre": "9 Ojos del Salado", "zona": "OjosDelSalado", "beat": 6,
	 "otorga": "ojos_salado", "desbloquea": [], "mundo": MUNDO_ATACAMA},
	# Acá había una parada "Poblado/Ocultista" aparte. No era ninguna parada: la
	# ocultista es la que está sentada en el bar del MISMO pueblo de la 8, y su
	# escena la dispara la bruja al unir las piezas. O sea que entrar por ahí te
	# dejaba en el mismo sitio que la 8 pero con el talismán ya entregado, con lo
	# cual ella ya se había ido y no había nada que ver.
	# La última: vencerlo concede el noveno logro y con eso salta la pantalla de
	# logros, que ES el final del prototipo. Antes había además una parada "Final"
	# a una escena aparte con su propio cartel de FIN: dos finales compitiendo.
	{"nombre": "10 Chupacabras", "zona": "Mina", "beat": 6,
	 "otorga": "chupacabras", "desbloquea": [], "mundo": ""},
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.10, 0.12, 0.17)
	add_child(bg)
	var con_arte := PLACA.fondo(self, 0.45)

	# Título, subtítulo y botones en UNA columna, no cada cosa por su cuenta.
	#
	# Antes el título y el subtítulo iban a una altura fija y los botones se
	# centraban en toda la pantalla: al añadir un botón la columna creció, subió,
	# y "JUGAR" se montó encima del subtítulo. En una sola columna eso no puede
	# pasar por mucho que se añadan o quiten botones, ni en una ventana pequeña.
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_top = 40.0
	vb.offset_bottom = -140.0   # el hueco de abajo es para los controles
	if con_arte:
		# Con el arte, la columna se va a la izquierda y debajo del título: ahí
		# el dibujo es cielo y mar, y los dos protagonistas —que están a la
		# derecha— quedan a la vista en vez de tapados por los botones.
		#
		# Todo en anclas y no en píxeles: la ilustración se recorta según la
		# ventana, y una columna en píxeles se despegaría del cuadro.
		# Centrada BAJO EL TÍTULO, que en la ilustración no está en el medio de
		# la imagen sino un poco a la izquierda: puesta en el centro geométrico
		# la columna quedaba descolgada del logo.
		vb.anchor_left = 0.32
		vb.anchor_right = 0.56
		vb.anchor_top = 0.30
		vb.anchor_bottom = 0.88
		vb.offset_left = 0.0
		vb.offset_right = 0.0
		vb.offset_top = 0.0
		vb.offset_bottom = 0.0
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14 if not con_arte else 9)
	add_child(vb)

	# El título va dibujado EN el arte, así que sólo se escribe cuando el arte no
	# está: escribirlo encima daba dos "VILU", uno sobre otro.
	_titulo = _label("VILU", 100, Color(1.0, 0.85, 0.4), 12)
	_titulo.visible = not con_arte
	vb.add_child(_titulo)
	var sub := _label("Prototipo — greybox", 30, Color(0.9, 0.9, 0.95), 6)
	sub.visible = not con_arte
	vb.add_child(sub)

	var aire := Control.new()
	aire.custom_minimum_size = Vector2(0, 26)
	vb.add_child(aire)

	# El título manda en el alto de la columna: 100 px de letra son 137 de alto, y
	# en una ventana baja eso empuja los botones encima de los controles. Se
	# ajusta al arrancar y cada vez que cambia el tamaño.
	_ajustar_titulo()
	get_viewport().size_changed.connect(_ajustar_titulo)

	var play := _entrada(con_arte, "JUGAR", 40, 80)
	play.pressed.connect(_on_play)
	vb.add_child(play)

	var newgame := _entrada(con_arte, "Nueva partida", 26, 54)
	newgame.pressed.connect(_on_new_game)
	vb.add_child(newgame)

	var opts := _entrada(con_arte, "Opciones", 26, 54)
	opts.pressed.connect(func() -> void: _options.visible = true)
	vb.add_child(opts)

	var zonas := _entrada(con_arte, "Seleccionar zona", 26, 54)
	zonas.pressed.connect(func() -> void: _zonas.visible = true)
	vb.add_child(zonas)

	var quit := _entrada(con_arte, "Salir", 26, 54)
	quit.pressed.connect(func() -> void: get_tree().quit())
	vb.add_child(quit)

	if con_arte:
		vb.add_child(PLACA.filete())
		vb.add_child(PLACA.lema("NUESTRAS RAÍCES"))
		vb.add_child(PLACA.lema("TAMBIÉN SON FUTURO"))

	_build_options()
	# La parrilla de controles ya no va en el título: eran dos líneas de texto
	# pequeño cruzadas sobre la ilustración, justo por delante del hielo y los
	# pingüinos. Lo que hay que ver al abrir el juego es el cuadro y el menú.
	_build_debug_zones()


## Panel de selección de zona: una lista VERTICAL, no una fila.
##
## En fila las doce paradas no caben: se salían de la pantalla por la derecha y
## de la mitad en adelante no se podían ni leer ni pulsar. Además cada botón
## lleva debajo, en pequeño, con qué llegás — que en fila tampoco cabía y quedaba
## sólo en el tooltip.
func _build_debug_zones() -> void:
	_zonas = Control.new()
	_zonas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_zonas.visible = false
	add_child(_zonas)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.06, 0.86)
	_zonas.add_child(dim)

	# Una placa de ANCHO FIJO, centrada y alta como la ventana.
	#
	# Antes la lista se centraba con un CenterContainer y cada descripción era
	# una línea suelta: la de "Poblado/Bar" mide más de mil píxeles, así que el
	# bloque entero crecía con ella y se salía de la pantalla por los dos lados.
	# Con el ancho fijo aquí, las descripciones no tienen más remedio que partir
	# en varias líneas.
	var marco := PanelContainer.new()
	marco.anchor_left = 0.5
	marco.anchor_right = 0.5
	marco.anchor_top = 0.04
	marco.anchor_bottom = 0.96
	marco.offset_left = -ANCHO_DEL_PANEL * 0.5
	marco.offset_right = ANCHO_DEL_PANEL * 0.5
	marco.offset_top = 0.0
	marco.offset_bottom = 0.0
	marco.add_theme_stylebox_override("panel", PLACA.estilo(0.0, 0.92, 26))
	_zonas.add_child(marco)

	var aire := MarginContainer.new()
	aire.add_theme_constant_override("margin_top", 22)
	aire.add_theme_constant_override("margin_bottom", 22)
	marco.add_child(aire)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	aire.add_child(vb)
	vb.add_child(PLACA.lema("SELECCIONAR ZONA", 30))
	var sub := _label(
		"Cada zona te deja el progreso anterior ya hecho: logros y habilidades.",
		17, Color(0.78, 0.82, 0.88), 3)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(sub)

	# El scroll se come el alto que sobre: doce paradas con su descripción no
	# entran en cualquier ventana.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 9)
	scroll.add_child(lista)

	for i in DEBUG_ZONES.size():
		var b := PLACA.boton(_etiqueta(DEBUG_ZONES[i]))
		# El detalle de lo que te vas a encontrar hecho va en el tooltip y no
		# debajo del botón: escrito eran dos renglones de letra pequeña por
		# parada, once veces, y la lista se leía como una parrilla de datos en
		# vez de como un menú. Quien lo necesite lo tiene pasando el ratón.
		b.tooltip_text = _resumen(i)
		b.pressed.connect(_on_debug_zone.bind(i))
		lista.add_child(b)

	var volver := PLACA.boton("Volver")
	volver.pressed.connect(func() -> void: _zonas.visible = false)
	vb.add_child(volver)


## El texto del botón, con el mundo cuando hace falta decirlo.
##
## Hay TRES paradas de "Poblado" y los dos mundos son copias del mismo pueblo:
## por el nombre no hay manera de saber a cuál lleva cada una, y ya pasó que se
## probara una creyendo que era la otra. El sufijo sale del propio dato, así que
## no puede quedar desfasado.
func _etiqueta(z: Dictionary) -> String:
	if String(z["zona"]) != "Poblado":
		return str(z["nombre"])
	return "%s (%s)" % [z["nombre"],
		"Atacama" if String(z["mundo"]) == MUNDO_ATACAMA else "Tarapacá"]


## Qué te vas a encontrar hecho al entrar por esa parada.
func _resumen(indice: int) -> String:
	var hechos := _logros_previos(indice)
	if hechos.is_empty():
		return "Empieza de cero."
	var titulos: PackedStringArray = []
	for id in hechos:
		titulos.append(str(GameManager.logro(id).get("titulo", id)))
	var texto := "Logros hechos: " + ", ".join(titulos)
	var hab := _habilidades_previas(indice)
	if not hab.is_empty():
		texto += "\nCon: " + ", ".join(hab)
	return texto


## Los logros de las paradas ANTERIORES a ésta.
##
## Se calculan de la propia lista en vez de escribirlos entrada por entrada: así
## no se pueden desincronizar al reordenar o meter una parada nueva.
func _logros_previos(indice: int) -> PackedStringArray:
	var ids: PackedStringArray = []
	for i in indice:
		var id: String = DEBUG_ZONES[i]["otorga"]
		if id != "":
			ids.append(id)
	return ids


## Las habilidades que se consiguieron en las paradas ANTERIORES a ésta.
##
## Igual que los logros: cada parada declara lo suyo y esto lo suma. Escritas a
## mano y acumuladas, la lista se desfasaba en cuanto se movía una parada — y
## llegar al Yastay sin alas, por ejemplo, deja el tramo sin poder jugarse.
func _habilidades_previas(indice: int) -> PackedStringArray:
	var ids: PackedStringArray = []
	for i in indice:
		for a in DEBUG_ZONES[i]["desbloquea"]:
			ids.append(str(a))
	return ids


func _on_debug_zone(indice: int) -> void:
	var z: Dictionary = DEBUG_ZONES[indice]
	GameManager.reset_progress()
	GameManager.set_beat(z["beat"])
	for a in _habilidades_previas(indice):
		GameManager.unlock(a)
	# Los logros de todo lo anterior. Sin esto, entrar por una parada tardía
	# dejaba el prototipo sin poder cerrarse: el duelo con el Chupacabras exige
	# los ocho previos y no había forma de tenerlos desde el menú.
	for id in _logros_previos(indice):
		GameManager.conceder(id)
	# Y la cadena de misiones, DESPUÉS de conceder: el reset de arriba la mandó
	# a la primera misión y hay que volver a colocarla donde deja esta parada.
	Misiones.sincronizar_con_los_logros()
	GameManager.debug_start_zone = z["zona"]
	GameManager.debug_start_world = z["mundo"]
	get_tree().change_scene_to_file("res://scenes/core/Game.tscn")


func _build_options() -> void:
	# El panel es el MISMO que abre el menú de pausa: vive en PanelOpciones para
	# que los dos no se separen con el tiempo.
	_options = OPCIONES.construir()
	add_child(_options)


func _label(txt: String, fsize: int, col: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", outline)
	return l


func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/core/Game.tscn")


func _on_new_game() -> void:
	GameManager.reset_progress()
	get_tree().change_scene_to_file("res://scenes/core/Game.tscn")


## Una entrada del menú: con placa si hay arte detrás, pelada si no.
##
## El menú es el mismo en los dos casos —los mismos botones y en el mismo
## orden—; lo que cambia es cómo se ven sobre lo que hay debajo.
func _entrada(con_arte: bool, texto: String, tamano: int, alto: int) -> Button:
	if con_arte:
		return PLACA.boton(texto)
	return _boton_menu(texto, tamano, alto)


func _boton_menu(texto: String, tamano_letra: int, alto: int) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(300, alto)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", tamano_letra)
	return b


## Encoge el título en ventanas bajas.
##
## Con 1080 de alto entra de sobra; con 720 la columna entera —título, subtítulo
## y cinco botones— se pasa del hueco y los botones acaban encima de la línea de
## controles. El título es lo que más ocupa y lo que menos se pierde al reducir.
func _ajustar_titulo() -> void:
	if _titulo == null:
		return
	var alto: float = get_viewport_rect().size.y
	_titulo.add_theme_font_size_override("font_size",
		int(clampf(alto * 0.093, 52.0, 100.0)))
