extends Control

# Menu de inicio: titulo + JUGAR + opciones (volumen) + record + controles.

var _options: Control
var _zonas: Control
var _titulo: Label

const MUNDO_ATACAMA := "res://scenes/core/WorldAtacama.tscn"

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
## al Ojos del Salado se juega en Atacama; desde el Ocultista se vuelve a
## Tarapacá, que es adonde te lleva el mapa del Guardián al bajar de la cima.
##
## `otorga` vacío = esa parada no cierra ningún logro: el Bar y el Ocultista son
## escenas de paso, y el Final va después del último.
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
	{"nombre": "10 Poblado/Ocultista", "zona": "Poblado", "beat": 6,
	 "otorga": "", "desbloquea": [], "mundo": ""},
	{"nombre": "11 Chupacabras", "zona": "Mina", "beat": 6,
	 "otorga": "chupacabras", "desbloquea": [], "mundo": ""},
	{"nombre": "12 Final", "zona": "Final", "beat": 7,
	 "otorga": "", "desbloquea": [], "mundo": ""},
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.10, 0.12, 0.17)
	add_child(bg)

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
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	add_child(vb)

	_titulo = _label("VILU", 100, Color(1.0, 0.85, 0.4), 12)
	vb.add_child(_titulo)
	vb.add_child(_label("Prototipo — greybox", 30, Color(0.9, 0.9, 0.95), 6))

	var aire := Control.new()
	aire.custom_minimum_size = Vector2(0, 26)
	vb.add_child(aire)

	# El título manda en el alto de la columna: 100 px de letra son 137 de alto, y
	# en una ventana baja eso empuja los botones encima de los controles. Se
	# ajusta al arrancar y cada vez que cambia el tamaño.
	_ajustar_titulo()
	get_viewport().size_changed.connect(_ajustar_titulo)

	var play := _boton_menu("JUGAR", 40, 80)
	play.pressed.connect(_on_play)
	vb.add_child(play)

	var newgame := _boton_menu("Nueva partida", 26, 54)
	newgame.pressed.connect(_on_new_game)
	vb.add_child(newgame)

	var opts := _boton_menu("Opciones", 26, 54)
	opts.pressed.connect(func() -> void: _options.visible = true)
	vb.add_child(opts)

	var zonas := _boton_menu("Seleccionar zona", 26, 54)
	zonas.pressed.connect(func() -> void: _zonas.visible = true)
	vb.add_child(zonas)

	var quit := _boton_menu("Salir", 26, 54)
	quit.pressed.connect(func() -> void: get_tree().quit())
	vb.add_child(quit)

	_build_options()

	var help := _label(
		"WASD mover · Shift correr · Espacio saltar (doble con alas) · Clic izq atacar (mantener = flecha cargada) · F flecha triple\n"
		+ "Q montar guanaco · E interactuar · R cambiar (IA) · T cambiar (queda quieto) · Rueda: zoom · Clic der: rotar cámara",
		20, Color(0.8, 0.85, 0.9), 4)
	help.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	help.position.y = -110
	add_child(help)

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
	dim.color = Color(0, 0, 0, 0.80)
	_zonas.add_child(dim)

	# Con scroll: doce paradas con su descripción no entran en cualquier alto de
	# ventana, y sin esto las últimas quedarían fuera igual que antes.
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 90
	scroll.offset_bottom = -90
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_zonas.add_child(scroll)

	var centro := CenterContainer.new()
	centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(centro)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	centro.add_child(vb)
	vb.add_child(_label("SELECCIONAR ZONA", 40, Color(1.0, 0.85, 0.4), 8))
	vb.add_child(_label(
		"Cada zona te deja el progreso anterior ya hecho: logros y habilidades.",
		18, Color(0.75, 0.8, 0.88), 3))

	for i in DEBUG_ZONES.size():
		var b := Button.new()
		b.text = _etiqueta(DEBUG_ZONES[i])
		b.custom_minimum_size = Vector2(560, 44)
		b.add_theme_font_size_override("font_size", 22)
		b.tooltip_text = _resumen(i)
		b.pressed.connect(_on_debug_zone.bind(i))
		vb.add_child(b)
		var det := _label(_resumen(i).replace("\n", " · "), 14,
			Color(0.62, 0.68, 0.76), 2)
		det.custom_minimum_size = Vector2(560, 0)
		vb.add_child(det)

	var volver := Button.new()
	volver.text = "Volver"
	volver.custom_minimum_size = Vector2(560, 48)
	volver.add_theme_font_size_override("font_size", 24)
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
	_options = Control.new()
	_options.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options.visible = false
	add_child(_options)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.75)
	_options.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options.add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 20)
	cc.add_child(vb)
	vb.add_child(_label("OPCIONES", 46, Color(1.0, 0.85, 0.4), 8))
	vb.add_child(_slider_row("Musica", Save.music_vol, Save.set_music_vol, false))
	vb.add_child(_slider_row("Efectos", Save.sfx_vol, Save.set_sfx_vol, true))
	var back := Button.new()
	back.text = "Volver"
	back.custom_minimum_size = Vector2(480, 58)
	back.add_theme_font_size_override("font_size", 30)
	back.pressed.connect(func(): _options.visible = false)
	vb.add_child(back)


func _slider_row(row_name: String, value: float, cb: Callable, preview: bool) -> Control:
	var row := VBoxContainer.new()
	var lbl := _label(row_name, 26, Color.WHITE, 4)
	row.add_child(lbl)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(480, 34)
	s.value_changed.connect(func(v):
		cb.call(v)
		if preview:
			Sfx.play("hit", -4.0))
	row.add_child(s)
	return row


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


## Un botón del menú principal.
##
## `SHRINK_CENTER` es lo que impide que se estiren a lo ancho de la pantalla:
## en un VBoxContainer los hijos ocupan todo el ancho salvo que se diga que no.
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
