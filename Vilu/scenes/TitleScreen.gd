extends Control

# Menu de inicio: titulo + nueva partida + opciones + seleccion de zona + salir.

var _options: Control
var _zonas: Control
var _titulo: Label
var _primero: BaseButton = null
## La columna del menú entera, para esconderla detrás de la puerta.
var _columna: VBoxContainer = null

## La puerta: antes del menú sólo se ve «Presiona cualquier botón» en medio
## de la portada. Al pulsar algo se enciende un instante y da paso al menú.
## Volviendo del juego no hay puerta: ya se estaba jugando.
var _puerta: TextureRect = null
var _puerta_abierta := false
const PUERTA := "res://textures/ui/presiona.png"
const PUERTA_ACTIVA := "res://textures/ui/presiona_activo.png"
## Cuánto se ve encendida antes de que salga el menú, en segundos.
const DESTELLO_DE_LA_PUERTA := 0.45

## Los botones dibujados del menú: para cada entrada, `textures/ui/botones/
## <clave>.png` en reposo y `<clave>_activo.png` con el ratón encima, el foco
## del mando o pulsado. Si falta el par, la entrada sale con la placa de
## siempre, así que se pueden ir poniendo de a uno.
const CARPETA_DE_BOTONES := "res://textures/ui/botones/"

## «Cargar partida» todavía no existe: no se enseña hasta que haya qué cargar.
## Su dibujo, mientras tanto, lo lleva «Seleccionar zona».
const CON_CARGAR_PARTIDA := false

var _ancho_de_columna := 420.0

const MUNDO_ATACAMA := "res://scenes/core/WorldAtacama.tscn"
## El aspecto de las pantallas que van sobre la ilustración, compartido con el
## final: así las dos se ven iguales sin copiar los colores en cada una.
const PLACA := preload("res://scenes/ui/Placa.gd")
const OPCIONES := preload("res://scenes/ui/PanelOpciones.gd")
## Ancho de los paneles que se abren encima del menú, en píxeles de interfaz.
## Fijo a propósito: es lo que obliga a las descripciones largas a partirse en
## varias líneas en vez de estirar el bloque hasta salirse de la pantalla.
const ANCHO_DEL_PANEL := 860.0

## El marco dibujado del selector de zonas es el de Placa.marco_dibujado.
const PROPORCION_DEL_MARCO := PLACA.PROPORCION_DEL_MARCO

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
	var con_arte := _montar_portadas()
	if not con_arte:
		con_arte = PLACA.fondo(self, 0.45)

	# Título, subtítulo y botones en UNA columna, no cada cosa por su cuenta.
	#
	# Antes el título y el subtítulo iban a una altura fija y los botones se
	# centraban en toda la pantalla: al añadir un botón la columna creció, subió,
	# y el primer botón se montó encima del subtítulo. En una sola columna eso no puede
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
		vb.anchor_top = 0.28
		vb.anchor_bottom = 0.93
		vb.offset_left = 0.0
		vb.offset_right = 0.0
		vb.offset_top = 0.0
		vb.offset_bottom = 0.0
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14 if not con_arte else 6)
	add_child(vb)
	_columna = vb
	# Lo ancho de la columna, en unidades de diseño: de ahí sale el alto de
	# los botones dibujados, que guardan la proporción del dibujo.
	_ancho_de_columna = get_viewport_rect().size.x * (vb.anchor_right - vb.anchor_left)

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

	# Sin «JUGAR»: la única entrada al juego es «Nueva partida».
	#
	# Los dos hacían casi lo mismo —cargar Game— y la diferencia no se veía por
	# ningún lado: «JUGAR» continuaba con el progreso que hubiera y «Nueva
	# partida» lo borraba. Con dos botones seguidos que llevan al mismo sitio,
	# quien llega al menú por primera vez no tiene forma de saber cuál le toca.
	# «Continuar» sólo cuando hay partida en marcha: cuando se salió al título
	# desde la pausa. Al abrir el juego no hay a qué volver, y ofrecerlo igual
	# obligaría a adivinar qué hace.
	var seguir: BaseButton = null
	if GameManager.se_puede_continuar:
		seguir = _entrada(con_arte, "Continuar", 26, 54, "continuar")
		seguir.pressed.connect(_continuar)
		vb.add_child(seguir)

	var newgame := _entrada(con_arte, "Nueva partida", 40, 80, "nueva_partida")
	newgame.pressed.connect(_on_new_game)
	vb.add_child(newgame)

	if CON_CARGAR_PARTIDA:
		var cargar := _entrada(con_arte, "Cargar partida", 26, 54, "cargar_partida")
		vb.add_child(cargar)

	var opts := _entrada(con_arte, "Opciones", 26, 54, "opciones")
	opts.pressed.connect(func() -> void: _options.visible = true)
	vb.add_child(opts)

	var creditos := _entrada(con_arte, "Créditos", 26, 54, "creditos")
	creditos.pressed.connect(func() -> void: _creditos.visible = true)
	vb.add_child(creditos)

	var zonas := _entrada(con_arte, "Seleccionar zona", 26, 54, "seleccionar_zona")
	zonas.pressed.connect(func() -> void: _zonas.visible = true)
	vb.add_child(zonas)

	var quit := _entrada(con_arte, "Salir", 26, 54, "salir")
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
	_build_creditos()
	_montar_puerta()

	# Con mando: el foco arranca en la primera entrada y vuelve al botón que
	# abrió cada panel cuando ese panel se cierra. Sin foco, el mando no tiene
	# por dónde empezar y el menú de inicio era inalcanzable.
	# El foco que pone el CÓDIGO no enciende el botón: al abrir el menú, «Nueva
	# partida» se veía como si tuviera el ratón encima sin que nadie lo hubiera
	# tocado. El que llega moviendo la cruceta o el ratón, sí.
	_primero = seguir if seguir != null else newgame
	_enfocar_sin_encender(_primero)
	_options.visibility_changed.connect(func() -> void:
		# Con Opciones abiertas, la portada en la que cada uno va por su lado, y
		# el menú escondido: con el velo ligero se transparentaba debajo.
		_cambiar_portada("opciones" if _options.visible else "menu")
		if _puerta_abierta:
			_columna.visible = not _options.visible
		if not _options.visible:
			_enfocar_sin_encender(opts))
	_zonas.visibility_changed.connect(func() -> void:
		if not _zonas.visible:
			_enfocar_sin_encender(zonas))
	_creditos.visibility_changed.connect(func() -> void:
		if not _creditos.visible:
			_enfocar_sin_encender(creditos))


func _enfocar_sin_encender(b: BaseButton) -> void:
	b.set_meta("foco_silencioso", true)
	b.call_deferred("grab_focus")


# ─── Las portadas ─────────────────────────────────────────────────────────────
#
# Tres cuadros del mismo lugar: la pareja de pie mirando el horizonte mientras
# dice «Presiona cualquier botón», sentada cuando ya está el menú, y cada uno
# por su lado al abrir Opciones. Se cambia de uno a otro con un fundido corto
# y suave: hay dos cuadros superpuestos y el que entra aparece encima.

const PORTADAS := {
	"inicio": "res://textures/ui/portada_inicio.png",
	"menu": "res://textures/ui/portada_menu.png",
	"opciones": "res://textures/ui/portada_opciones.png",
}
## Cuánto dura el fundido entre portadas, en segundos.
const FUNDIDO_DE_PORTADA := 0.6
## Un velo ligero encima, para que se lean los textos sin apagar el cuadro.
const VELO_DE_PORTADA := 0.18

var _portada_de_abajo: TextureRect = null
var _portada_de_arriba: TextureRect = null
var _portada_actual := ""
var _fundido_de_portada: Tween = null


## Cuelga los dos cuadros y pone el primero. Devuelve si había portadas.
func _montar_portadas() -> bool:
	for clave: String in PORTADAS:
		if not ResourceLoader.exists(String(PORTADAS[clave])):
			return false
	_portada_de_abajo = _cuadro_de_portada("PortadaDeAbajo")
	_portada_de_arriba = _cuadro_de_portada("PortadaDeArriba")
	_portada_de_arriba.modulate.a = 0.0
	var velo := ColorRect.new()
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.color = Color(0.04, 0.05, 0.09, VELO_DE_PORTADA)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(velo)
	# Volviendo del juego no hay puerta: se arranca ya con la del menú.
	_portada_actual = "menu" if GameManager.se_puede_continuar else "inicio"
	_portada_de_abajo.texture = load(String(PORTADAS[_portada_actual]))
	return true


func _cuadro_de_portada(nombre: String) -> TextureRect:
	var img := TextureRect.new()
	img.name = nombre
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(img)
	return img


## Pasa a otra portada con un fundido: la nueva aparece encima de la vieja y,
## al terminar, se convierte en la de abajo para el siguiente cambio.
func _cambiar_portada(clave: String) -> void:
	if _portada_de_abajo == null or clave == _portada_actual or not PORTADAS.has(clave):
		return
	if _fundido_de_portada != null and _fundido_de_portada.is_valid():
		_fundido_de_portada.kill()
		# Un cambio a mitad de otro: lo que ya se veía arriba pasa abajo.
		if _portada_de_arriba.modulate.a > 0.5:
			_portada_de_abajo.texture = _portada_de_arriba.texture
	_portada_actual = clave
	_portada_de_arriba.texture = load(String(PORTADAS[clave]))
	_portada_de_arriba.modulate.a = 0.0
	_fundido_de_portada = create_tween()
	_fundido_de_portada.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fundido_de_portada.tween_property(_portada_de_arriba, "modulate:a", 1.0, FUNDIDO_DE_PORTADA)
	_fundido_de_portada.tween_callback(func() -> void:
		_portada_de_abajo.texture = _portada_de_arriba.texture
		_portada_de_arriba.modulate.a = 0.0)


func _montar_puerta() -> void:
	if GameManager.se_puede_continuar or not ResourceLoader.exists(PUERTA):
		_puerta_abierta = true
		return
	_puerta = TextureRect.new()
	_puerta.name = "Puerta"
	_puerta.texture = load(PUERTA)
	_puerta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_puerta.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_puerta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# En medio de la pantalla, debajo del logo de la portada.
	_puerta.anchor_left = 0.27
	_puerta.anchor_right = 0.73
	_puerta.anchor_top = 0.42
	_puerta.anchor_bottom = 0.66
	add_child(_puerta)
	_columna.visible = false


## Cualquier tecla, botón del ratón o botón del mando abre la puerta. Mover el
## ratón o el stick, no.
func _input(event: InputEvent) -> void:
	if _puerta_abierta:
		return
	var pulsado := (event is InputEventKey and event.is_pressed() and not event.is_echo()) \
		or (event is InputEventMouseButton and event.is_pressed()) \
		or (event is InputEventJoypadButton and event.is_pressed())
	if not pulsado:
		return
	_abrir_la_puerta()
	get_viewport().set_input_as_handled()


func _abrir_la_puerta() -> void:
	if _puerta_abierta:
		return
	_puerta_abierta = true
	if _puerta != null and ResourceLoader.exists(PUERTA_ACTIVA):
		_puerta.texture = load(PUERTA_ACTIVA)
	get_tree().create_timer(DESTELLO_DE_LA_PUERTA).timeout.connect(_entrar_al_menu)


func _entrar_al_menu() -> void:
	_puerta_abierta = true
	if _puerta != null:
		_puerta.visible = false
	_columna.visible = true
	_cambiar_portada("menu")
	if _primero != null:
		_enfocar_sin_encender(_primero)


## Vuelve a la partida que se dejó al salir a este menú desde la pausa. El
## progreso vive en los autoloads y no se tocó: basta con cargar el juego.
func _continuar() -> void:
	get_tree().change_scene_to_file("res://scenes/core/Game.tscn")


## Los créditos: el dibujo de la pantalla entera —el marco, y Emilia y
## Benjamín señalando hacia arriba— y el texto subiendo despacio por el hueco
## del medio, como en el cine. Se cierra con «Volver», con Escape o con la B.
var _creditos: Control = null
## El texto que sube, y dónde está.
var _rollo: VBoxContainer = null
var _ventana_del_rollo: Control = null

const DIBUJO_DE_CREDITOS := "res://textures/ui/fondo_creditos.png"
## A cuánto sube, en píxeles de interfaz por segundo.
const VELOCIDAD_DEL_ROLLO := 28.0
## Por dónde sube: el hueco entre el marco de arriba y las manos de los dos.
const HUECO_DEL_ROLLO := Rect2(0.18, 0.10, 0.64, 0.56)

## Cada línea: [texto, tamaño]. De 26 para arriba sale en oro: los títulos y
## los nombres; los cargos, en letra clara.
const CREDITOS := [
	["VILU — El despertar", 40],
	["", 12],
	["Un juego de", 20],
	["Studios Conari", 30],
	["", 30],
	["María Inés Cisterna Escobar", 26],
	["Game Director · Creative Director · Game Designer", 18],
	["", 20],
	["Catalina Verónica Valenzuela Vergara", 26],
	["Game Designer", 18],
	["", 20],
	["Kevin Alexis Del Rio Morgado", 26],
	["Lead Programmer · Narrative Director", 18],
	["", 30],
	["Basado en la novela VILU", 20],
	["", 30],
	["Gracias a quienes probaron el prototipo", 20],
	["y a las comunidades del norte de Chile", 20],
	["que cuidan estas historias.", 20],
	["", 40],
	["Nuestras raíces también son futuro.", 26],
]


func _build_creditos() -> void:
	_creditos = Control.new()
	_creditos.name = "Creditos"
	_creditos.set_anchors_preset(Control.PRESET_FULL_RECT)
	_creditos.visible = false
	add_child(_creditos)

	var fondo := TextureRect.new()
	fondo.name = "Dibujo"
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(DIBUJO_DE_CREDITOS):
		fondo.texture = load(DIBUJO_DE_CREDITOS)
	else:
		# Sin el dibujo, al menos que no se vea el menú detrás.
		var velo := ColorRect.new()
		velo.set_anchors_preset(Control.PRESET_FULL_RECT)
		velo.color = Color(0.02, 0.06, 0.16, 0.96)
		_creditos.add_child(velo)
	_creditos.add_child(fondo)

	# La ventana por la que se ve el rollo: lo que sale de ella se recorta.
	_ventana_del_rollo = Control.new()
	_ventana_del_rollo.name = "Ventana"
	_ventana_del_rollo.clip_contents = true
	_ventana_del_rollo.anchor_left = HUECO_DEL_ROLLO.position.x
	_ventana_del_rollo.anchor_top = HUECO_DEL_ROLLO.position.y
	_ventana_del_rollo.anchor_right = HUECO_DEL_ROLLO.end.x
	_ventana_del_rollo.anchor_bottom = HUECO_DEL_ROLLO.end.y
	_ventana_del_rollo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_creditos.add_child(_ventana_del_rollo)

	_rollo = VBoxContainer.new()
	_rollo.name = "Rollo"
	_rollo.add_theme_constant_override("separation", 4)
	_rollo.anchor_right = 1.0
	_rollo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ventana_del_rollo.add_child(_rollo)
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Times New Roman", "Liberation Serif", "DejaVu Serif"])
	for linea: Array in CREDITOS:
		var l := Label.new()
		l.text = String(linea[0])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", serif)
		l.add_theme_font_size_override("font_size", int(linea[1]))
		l.add_theme_color_override("font_color", PLACA.LETRA if int(linea[1]) < 26 else PLACA.ORO_VIVO)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		l.add_theme_constant_override("outline_size", 3)
		if l.text == "":
			l.custom_minimum_size = Vector2(0, int(linea[1]))
		_rollo.add_child(l)

	# «Volver», abajo a la derecha, dentro del marco.
	var volver := PLACA.boton("Volver")
	volver.custom_minimum_size = Vector2(160, 42)
	# Dentro del marco del dibujo nuevo, que es más estrecho que la pantalla.
	volver.anchor_left = 0.76
	volver.anchor_right = 0.88
	volver.anchor_top = 0.86
	volver.anchor_bottom = 0.92
	volver.pressed.connect(func() -> void: _creditos.visible = false)
	_creditos.add_child(volver)
	PLACA.enfocar_al_mostrar(_creditos, volver)
	# Cada vez que se abre, el rollo arranca desde abajo del todo.
	_creditos.visibility_changed.connect(func() -> void:
		if _creditos.visible:
			_rollo.position.y = _ventana_del_rollo.size.y)


func _process(delta: float) -> void:
	if _creditos == null or not _creditos.visible or _rollo == null:
		return
	_rollo.position.y -= VELOCIDAD_DEL_ROLLO * delta
	# Pasado del todo por arriba, vuelve a entrar por abajo.
	if _rollo.position.y + _rollo.size.y < 0.0:
		_rollo.position.y = _ventana_del_rollo.size.y


## [ESC] o la B del mando: un paso atrás. Cierra lo que esté más encima.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _options != null and _options.visible:
		if _capturando_un_control():
			return
		OPCIONES.cerrar_lo_de_encima(_options)
		get_viewport().set_input_as_handled()
	elif _zonas != null and _zonas.visible:
		_zonas.visible = false
		get_viewport().set_input_as_handled()
	elif _creditos != null and _creditos.visible:
		_creditos.visible = false
		get_viewport().set_input_as_handled()


func _capturando_un_control() -> bool:
	for h in get_tree().get_nodes_in_group("hoja_de_controles"):
		if h is CanvasItem and (h as CanvasItem).visible and String(h.get("_capturando")) != "":
			return true
	return false


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

	# Un velo ligero: detrás se sigue viendo la portada.
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.06, 0.45)
	_zonas.add_child(dim)

	# El marco es un DIBUJO —el panel de «Cargar partida», con la estrella y
	# las alas arriba— y la lista va dentro, en su hueco. Ver Placa.marco_dibujado.
	var aire := PLACA.marco_dibujado(_zonas)

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
	var par: Array = PLACA.lista_con_scroll()
	var scroll: ScrollContainer = par[0]
	vb.add_child(scroll)
	var lista: VBoxContainer = par[1]
	lista.add_theme_constant_override("separation", 9)

	for i in DEBUG_ZONES.size():
		var b := PLACA.boton(_etiqueta(DEBUG_ZONES[i]))
		# Sin tooltip: el resumen de lo que trae cada parada se montaba encima
		# de la lista al pasar el ratón y estorbaba más de lo que ayudaba.
		b.pressed.connect(_on_debug_zone.bind(i))
		lista.add_child(b)

	var volver := PLACA.boton("Volver")
	volver.pressed.connect(func() -> void: _zonas.visible = false)
	vb.add_child(volver)
	# Con mando: al abrirse la lista, el foco va a la primera parada.
	if lista.get_child_count() > 0:
		PLACA.enfocar_al_mostrar(_zonas, lista.get_child(0) as Control)


## El texto del botón, con el mundo cuando hace falta decirlo.
##
## Hay TRES paradas de "Poblado" y los dos mundos son copias del mismo pueblo:
## por el nombre no hay manera de saber a cuál lleva cada una, y ya pasó que se
## probara una creyendo que era la otra. El sufijo sale del propio dato, así que
## no puede quedar desfasado.
func _etiqueta(z: Dictionary) -> String:
	if String(z["zona"]) != "Poblado":
		return tr(str(z["nombre"]))
	return "%s (%s)" % [tr(str(z["nombre"])),
		tr("Atacama" if String(z["mundo"]) == MUNDO_ATACAMA else "Tarapacá")]


## Qué te vas a encontrar hecho al entrar por esa parada.
func _resumen(indice: int) -> String:
	var hechos := _logros_previos(indice)
	if hechos.is_empty():
		return tr("Empieza de cero.")
	var titulos: PackedStringArray = []
	for id in hechos:
		titulos.append(tr(str(GameManager.logro(id).get("titulo", id))))
	var texto := tr("Logros hechos: ") + ", ".join(titulos)
	var hab := _habilidades_previas(indice)
	if not hab.is_empty():
		texto += tr("\nCon: ") + ", ".join(hab)
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


func _on_new_game() -> void:
	GameManager.reset_progress()
	get_tree().change_scene_to_file("res://scenes/core/Game.tscn")


## Una entrada del menú: dibujada si están sus dos imágenes, con placa si hay
## arte de fondo, y pelada si no hay nada.
##
## El menú es el mismo en todos los casos —los mismos botones y en el mismo
## orden—; lo que cambia es cómo se ven sobre lo que hay debajo.
func _entrada(con_arte: bool, texto: String, tamano: int, alto: int, clave := "") -> BaseButton:
	var b: BaseButton = _boton_dibujado(clave, texto)
	if b == null:
		b = PLACA.boton(texto) if con_arte else _boton_menu(texto, tamano, alto)
	# Qué entrada es, se dibuje como se dibuje: un botón de imagen no tiene
	# texto, y hay quien lo busca por lo que dice.
	b.name = texto
	b.set_meta("texto", texto)
	return b


## El botón con sus imágenes, o null si no está ni la de reposo.
##
## Sin la encendida —«Seleccionar zona» usa el dibujo de «Cargar partida», que
## vino sin su versión encendida— se usa la misma de reposo y se le sube el
## brillo con el ratón encima o el foco.
func _boton_dibujado(clave: String, texto := "") -> TextureButton:
	if clave == "":
		return null
	var reposo := CARPETA_DE_BOTONES + clave + ".png"
	var activo := CARPETA_DE_BOTONES + clave + "_activo.png"
	if not ResourceLoader.exists(reposo):
		return null
	if ResourceLoader.exists(activo):
		return boton_con_imagenes(load(reposo), load(activo), _ancho_de_columna, texto)
	return boton_con_imagenes(load(reposo), null, _ancho_de_columna, texto)


## Un botón hecho de dos imágenes: la de reposo y la encendida en oro.
##
## Con el ratón encima o el foco del mando NO se pasa a la de oro: se aclara la
## de reposo, que basta para ver cuál está elegido sin cargar la pantalla. La
## de oro es para el momento de pulsarlo. Se escala a lo ancho de la columna
## manteniendo la proporción, así el mismo dibujo vale para cualquier ventana.
## El color con el que se aclara un botón con el ratón encima o el foco.
const ENCENDIDO_A_MANO := Color(1.35, 1.25, 0.95)


## Las palabras las pone el juego, no el dibujo: los botones vienen sólo con
## el icono, y la etiqueta de encima se traduce sola al cambiar de idioma.
## Va a la derecha del icono, en la letra serif del sistema, crema en reposo
## y dorada al pulsar, como en el arte que tenía las palabras pintadas.
const TEXTO_DESDE := 0.33
const TEXTO_HASTA := 0.86
const LETRA_DE_BOTON := Color(0.96, 0.93, 0.85)
const LETRA_PULSADA := Color(0.99, 0.90, 0.60)


static func boton_con_imagenes(reposo: Texture2D, activo: Texture2D, ancho := 420.0, texto := "") -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = reposo
	if activo != null:
		b.texture_pressed = activo
	var encender := func(si: bool) -> void:
		b.self_modulate = ENCENDIDO_A_MANO if si else Color.WHITE
	b.mouse_entered.connect(encender.bind(true))
	b.mouse_exited.connect(func() -> void: encender.call(b.has_focus()))
	# El foco que pone el código (meta "foco_silencioso") no enciende: sólo el
	# que llega por la cruceta o el ratón.
	b.focus_entered.connect(func() -> void:
		if b.has_meta("foco_silencioso"):
			b.remove_meta("foco_silencioso")
			return
		encender.call(true))
	b.focus_exited.connect(encender.bind(false))
	# Pulsado se ve la de oro tal cual, sin aclarar encima.
	b.button_down.connect(encender.bind(false))
	b.button_up.connect(func() -> void: encender.call(b.has_focus() or b.is_hovered()))

	if texto != "":
		var l := Label.new()
		l.name = "Texto"
		l.text = texto
		l.anchor_left = TEXTO_DESDE
		l.anchor_right = TEXTO_HASTA
		l.anchor_top = 0.0
		l.anchor_bottom = 1.0
		l.offset_left = 0.0
		l.offset_right = 0.0
		l.offset_top = 0.0
		l.offset_bottom = 0.0
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var serif := SystemFont.new()
		serif.font_names = PackedStringArray(["Georgia", "Times New Roman", "Liberation Serif", "DejaVu Serif"])
		l.add_theme_font_override("font", serif)
		l.add_theme_font_size_override("font_size", maxi(12, roundi(ancho * reposo.get_height() / maxf(float(reposo.get_width()), 1.0) * 0.38)))
		l.add_theme_color_override("font_color", LETRA_DE_BOTON)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
		l.add_theme_constant_override("shadow_offset_y", 2)
		b.add_child(l)
		b.button_down.connect(func() -> void: l.add_theme_color_override("font_color", LETRA_PULSADA))
		b.button_up.connect(func() -> void: l.add_theme_color_override("font_color", LETRA_DE_BOTON))
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.size_flags_horizontal = Control.SIZE_FILL
	# El alto sale del ancho de la columna y la proporción del dibujo: con un
	# alto fijo el dibujo quedaba centrado en una caja más alta que él y los
	# botones salían separados de más.
	var prop: float = reposo.get_height() / maxf(float(reposo.get_width()), 1.0)
	b.custom_minimum_size = Vector2(0, ancho * prop)
	# Sin el rectángulo de foco por defecto encima del dibujo: la imagen
	# encendida ya dice cuál está elegido.
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


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
