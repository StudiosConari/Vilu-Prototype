extends RefCounted

## El panel de Opciones, uno solo para las dos pantallas que lo abren.
##
## Está en el menú de inicio y en el de pausa, y son EL MISMO panel: los mismos
## deslizadores, el mismo aspecto y el mismo botón de volver. Escrito dos veces
## acabarían separándose sin que nadie se diera cuenta —uno con la música y el
## otro sin ella, o con otro tamaño de letra—, que es lo que ya pasó con la
## placa antes de sacarla a su archivo.
##
## CÓMO ESTÁ HECHO. El panel es un DIBUJO —`textures/ui/opciones_es.png`, con
## su gemelo en inglés— que trae el marco, el título, los iconos y los nombres
## de cada fila. Los controles de verdad van encima, colocados por fracciones
## del dibujo: al dibujo se le borraron los deslizadores y las cajas pintadas,
## y en su sitio hay un HSlider o un selector de flechas que se ven igual. Así
## el arte manda en cómo se ve y el código en qué hace, y cambiar de idioma es
## cambiar el dibujo.
##
## Se usa sin instanciar:
##   const OPCIONES := preload("res://scenes/ui/PanelOpciones.gd")
##   var panel := OPCIONES.construir()
##   add_child(panel)
##   ...   panel.visible = true

const PLACA := preload("res://scenes/ui/Placa.gd")
const CONTROLES := preload("res://scenes/ui/PanelDeControles.gd")

## Los dibujos del panel, uno por idioma.
const DIBUJOS := {
	"es": "res://textures/ui/opciones_es.png",
	"en": "res://textures/ui/opciones_en.png",
}

## Ancho del panel, en píxeles de interfaz. El alto sale de la proporción del
## dibujo, para que nada se deforme.
const ANCHO := 900.0
const PROPORCION := 0.6021

## Dónde cae cada control, en fracciones del dibujo (izquierda, arriba,
## derecha, abajo). Medidas sobre el original de 4096 px.
const SITIOS := {
	"AudioGeneral": Rect2(0.4917, 0.2527, 0.3951, 0.0362),
	"Musica":       Rect2(0.4917, 0.3587, 0.3951, 0.0362),
	"Efectos":      Rect2(0.4917, 0.4647, 0.3951, 0.0362),
	"Pantalla":     Rect2(0.4917, 0.5521, 0.3951, 0.0743),
	"Idioma":       Rect2(0.4917, 0.6553, 0.3951, 0.0743),
	"Controles":    Rect2(0.4917, 0.7613, 0.3951, 0.0729),
	"Guardar":      Rect2(0.2160, 0.8727, 0.2457, 0.0902),
	"Volver":       Rect2(0.5383, 0.8727, 0.2329, 0.0902),
}

const NAVY := Color(0.02, 0.11, 0.24)
const NAVY_FONDO := Color(0.004, 0.106, 0.231)

## Lo que dice cada selector, por posición y por idioma: los nombres de las
## filas vienen en el dibujo, y lo que va dentro de las cajas tiene que
## cambiar con él.
const PANTALLAS := {"es": ["Pantalla completa", "Ventana"], "en": ["Fullscreen", "Windowed"]}
const IDIOMAS := ["Español", "English"]
const CLAVES_DE_IDIOMA := ["es", "en"]
const DISPOSITIVOS := {"es": ["Teclado y ratón", "Mando"], "en": ["Keyboard & mouse", "Gamepad"]}


## Devuelve el panel ya montado y OCULTO. Quien lo pide decide cuándo se ve.
static func construir() -> Control:
	var raiz := Control.new()
	raiz.name = "PanelOpciones"
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.visible = false

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Un velo ligero: detrás tiene que verse la portada de Opciones.
	dim.color = Color(0.02, 0.03, 0.06, 0.35)
	raiz.add_child(dim)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(cc)

	# El lienzo: del tamaño del dibujo, y todo lo demás anclado a él.
	var lienzo := Control.new()
	lienzo.name = "Lienzo"
	lienzo.custom_minimum_size = Vector2(ANCHO, ANCHO * PROPORCION)
	cc.add_child(lienzo)

	var dibujo := TextureRect.new()
	dibujo.name = "Dibujo"
	dibujo.set_anchors_preset(Control.PRESET_FULL_RECT)
	dibujo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dibujo.stretch_mode = TextureRect.STRETCH_SCALE
	dibujo.texture = _dibujo_de(Save.idioma)
	dibujo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo.add_child(dibujo)

	# Lo que había al abrir, para que «Volver» lo deje como estaba.
	var antes := {}

	var audio := _deslizador("AudioGeneral", Save.master_vol, Save.set_master_vol, false)
	var musica := _deslizador("Musica", Save.music_vol, Save.set_music_vol, false)
	var efectos := _deslizador("Efectos", Save.sfx_vol, Save.set_sfx_vol, true)
	for s in [audio, musica, efectos]:
		_colocar(lienzo, s)

	var pantalla := _selector("Pantalla", PANTALLAS[Save.idioma], 0 if Save.pantalla_completa else 1)
	pantalla.set_meta("al_cambiar", func(i: int) -> void:
		Save.set_pantalla_completa(i == 0))
	_colocar(lienzo, pantalla)

	var idioma := _selector("Idioma", IDIOMAS, maxi(CLAVES_DE_IDIOMA.find(Save.idioma), 0))
	_colocar(lienzo, idioma)

	# Los controles se cambian en su propia hoja, una por clase: enseñar las dos
	# a la vez es el doble de texto para leer, y quien agarra un mando no quiere
	# saber qué tecla hace qué. El selector elige la clase y pulsarlo la abre.
	var hojas: Array = []
	for mando in [false, true]:
		var hoja: Control = CONTROLES.construir(mando)
		hoja.add_to_group("hoja_de_controles")
		raiz.add_child(hoja)
		hojas.append(hoja)
	var controles := _selector("Controles", DISPOSITIVOS[Save.idioma], 1 if Botones.usando_mando() else 0)
	# Cambiar de idioma cambia el dibujo y lo que dicen las cajas.
	idioma.set_meta("al_cambiar", func(i: int) -> void:
		Save.set_idioma(String(CLAVES_DE_IDIOMA[i]))
		_traducir(dibujo, pantalla, controles))
	controles.set_meta("al_pulsar", func(i: int) -> void:
		(hojas[i] as Control).visible = true)
	_colocar(lienzo, controles)
	for hoja: Control in hojas:
		hoja.visibility_changed.connect(func() -> void:
			if not hoja.visible and raiz.visible:
				_centro(controles).call_deferred("grab_focus"))

	var guardar := _boton_pintado("Guardar")
	guardar.pressed.connect(func() -> void: raiz.visible = false)
	_colocar(lienzo, guardar)

	var volver := _boton_pintado("Volver")
	volver.pressed.connect(func() -> void:
		_restaurar(antes, [audio, musica, efectos], pantalla, idioma)
		_traducir(dibujo, pantalla, controles)
		raiz.visible = false)
	_colocar(lienzo, volver)

	# Al abrirse se toma la foto de lo que hay, y el foco cae en el primer
	# deslizador (con mando, sin foco no hay por dónde empezar).
	raiz.visibility_changed.connect(func() -> void:
		if raiz.visible:
			antes["master"] = Save.master_vol
			antes["music"] = Save.music_vol
			antes["sfx"] = Save.sfx_vol
			antes["pantalla"] = Save.pantalla_completa
			antes["idioma"] = Save.idioma)
	PLACA.enfocar_al_mostrar(raiz, audio)
	return raiz


## Cierra lo que esté más ENCIMA: primero una hoja de controles si hay alguna
## abierta, y si no el panel entero. Devuelve si cerró algo.
##
## Es lo que hace [ESC] o la B del mando desde cualquiera de los dos menús que
## abren opciones: un paso atrás cada vez, no todo de golpe.
static func cerrar_lo_de_encima(raiz: Control) -> bool:
	if raiz == null or not raiz.visible:
		return false
	for h in raiz.get_children():
		if h is Control and h.is_in_group("hoja_de_controles") and (h as Control).visible:
			(h as Control).visible = false
			return true
	raiz.visible = false
	return true


## Lo que dice el selector de pantalla: EN QUÉ ESTÁ, no a dónde te lleva.
static func _texto_de_pantalla() -> String:
	var textos: Array = PANTALLAS[Save.idioma]
	return String(textos[0] if Save.pantalla_completa else textos[1])


## Pone el dibujo y los textos de las cajas en el idioma guardado.
static func _traducir(dibujo: TextureRect, pantalla: Control, controles: Control) -> void:
	dibujo.texture = _dibujo_de(Save.idioma)
	pantalla.set_meta("opciones", PANTALLAS[Save.idioma])
	_poner_indice(pantalla, indice_de(pantalla), false)
	controles.set_meta("opciones", DISPOSITIVOS[Save.idioma])
	_poner_indice(controles, indice_de(controles), false)


static func _dibujo_de(idioma: String) -> Texture2D:
	var ruta := String(DIBUJOS.get(idioma, DIBUJOS["es"]))
	if ResourceLoader.exists(ruta):
		return load(ruta)
	return null


## Ancla un control al hueco que le toca en el dibujo.
static func _colocar(lienzo: Control, c: Control) -> void:
	var r: Rect2 = SITIOS[c.name]
	c.anchor_left = r.position.x
	c.anchor_top = r.position.y
	c.anchor_right = r.end.x
	c.anchor_bottom = r.end.y
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = 0.0
	c.offset_bottom = 0.0
	lienzo.add_child(c)


## «Volver» deja todo como estaba al abrir.
static func _restaurar(antes: Dictionary, deslizadores: Array, pantalla: Control, idioma: Control) -> void:
	if antes.is_empty():
		return
	Save.set_master_vol(float(antes["master"]))
	Save.set_music_vol(float(antes["music"]))
	Save.set_sfx_vol(float(antes["sfx"]))
	Save.set_pantalla_completa(bool(antes["pantalla"]))
	Save.set_idioma(String(antes["idioma"]))
	for par in [[deslizadores[0], "master"], [deslizadores[1], "music"], [deslizadores[2], "sfx"]]:
		(par[0] as HSlider).set_value_no_signal(float(antes[par[1]]))
	_poner_indice(pantalla, 0 if Save.pantalla_completa else 1, false)
	_poner_indice(idioma, maxi(CLAVES_DE_IDIOMA.find(Save.idioma), 0), false)


# ─── Deslizadores ─────────────────────────────────────────────────────────────

## Un deslizador dorado sobre la pista azul, como el pintado en el dibujo.
##
## `con_prueba` hace sonar un golpe al moverlo: en los efectos hace falta oír lo
## que estás ajustando, y en la música no —la música ya está sonando—.
static func _deslizador(nombre: String, valor: float, guardar: Callable,
		con_prueba: bool) -> HSlider:
	var s := HSlider.new()
	s.name = nombre
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = valor
	s.add_theme_stylebox_override("slider", _pista())
	s.add_theme_stylebox_override("grabber_area", _relleno())
	s.add_theme_stylebox_override("grabber_area_highlight", _relleno(true))
	s.add_theme_icon_override("grabber", _perilla(PLACA.ORO_VIVO))
	s.add_theme_icon_override("grabber_highlight", _perilla(Color(1.0, 0.93, 0.62)))
	s.add_theme_icon_override("grabber_disabled", _perilla(PLACA.ORO))
	s.add_theme_constant_override("grabber_offset", 0)
	s.value_changed.connect(func(v: float) -> void:
		guardar.call(v)
		if con_prueba:
			Sfx.play("hit", -4.0))
	return s


static func _pista() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = NAVY
	sb.border_color = Color(0.96, 0.93, 0.85, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


static func _relleno(encendido := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PLACA.ORO_VIVO.lightened(0.12 if encendido else 0.0)
	sb.set_corner_radius_all(10)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


## La perilla: un círculo dorado con borde claro, dibujado píxel a píxel.
static func _perilla(color: Color) -> ImageTexture:
	var lado := 26
	var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (lado - 1) / 2.0
	for y in lado:
		for x in lado:
			var d := Vector2(x - c, y - c).length()
			if d <= c - 2.0:
				img.set_pixel(x, y, color)
			elif d <= c - 0.5:
				img.set_pixel(x, y, Color(0.98, 0.95, 0.85))
			elif d <= c + 0.5:
				img.set_pixel(x, y, Color(0.98, 0.95, 0.85, 1.0 - (d - (c - 0.5))))
	return ImageTexture.create_from_image(img)


# ─── Selectores de flechas ────────────────────────────────────────────────────

## Una caja con «<», el valor y «>». Con el mando: el centro tiene el foco, la
## cruceta a los lados cambia el valor y la A lo pulsa —lo que haga pulsarlo
## lo decide quien lo crea con el meta "al_pulsar"; sin él, pulsar pasa al
## siguiente valor—. Cada cambio avisa por el meta "al_cambiar".
static func _selector(nombre: String, opciones: Array, indice: int) -> PanelContainer:
	var caja := PanelContainer.new()
	caja.name = nombre
	caja.add_theme_stylebox_override("panel", _marco_de_caja())
	caja.set_meta("opciones", opciones)
	caja.set_meta("indice", clampi(indice, 0, opciones.size() - 1))

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 0)
	caja.add_child(fila)

	var izq := _flecha("<")
	izq.pressed.connect(func() -> void: _poner_indice(caja, int(caja.get_meta("indice")) - 1, true))
	fila.add_child(izq)

	var centro := Button.new()
	centro.name = "Centro"
	centro.text = String(opciones[int(caja.get_meta("indice"))])
	centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centro.add_theme_font_size_override("font_size", 22)
	centro.add_theme_color_override("font_color", PLACA.LETRA)
	centro.add_theme_color_override("font_hover_color", Color.WHITE)
	centro.add_theme_color_override("font_focus_color", Color.WHITE)
	centro.add_theme_color_override("font_pressed_color", PLACA.ORO_VIVO)
	centro.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	centro.add_theme_stylebox_override("hover", _fondo_encendido(0.10))
	centro.add_theme_stylebox_override("pressed", _fondo_encendido(0.18))
	centro.add_theme_stylebox_override("focus", _fondo_encendido(0.14))
	centro.pressed.connect(func() -> void:
		if caja.has_meta("al_pulsar"):
			(caja.get_meta("al_pulsar") as Callable).call(int(caja.get_meta("indice")))
		else:
			_poner_indice(caja, int(caja.get_meta("indice")) + 1, true))
	centro.gui_input.connect(func(e: InputEvent) -> void:
		if e.is_action_pressed("ui_left"):
			_poner_indice(caja, int(caja.get_meta("indice")) - 1, true)
			centro.accept_event()
		elif e.is_action_pressed("ui_right"):
			_poner_indice(caja, int(caja.get_meta("indice")) + 1, true)
			centro.accept_event())
	fila.add_child(centro)

	var der := _flecha(">")
	der.pressed.connect(func() -> void: _poner_indice(caja, int(caja.get_meta("indice")) + 1, true))
	fila.add_child(der)
	return caja


static func _centro(caja: Control) -> Button:
	return caja.get_child(0).get_node("Centro") as Button


## Cambia el valor del selector, dando la vuelta por los extremos.
static func _poner_indice(caja: Control, indice: int, avisar: bool) -> void:
	var opciones: Array = caja.get_meta("opciones")
	var i := posmod(indice, opciones.size())
	caja.set_meta("indice", i)
	_centro(caja).text = String(opciones[i])
	if avisar and caja.has_meta("al_cambiar"):
		(caja.get_meta("al_cambiar") as Callable).call(i)


static func indice_de(caja: Control) -> int:
	return int(caja.get_meta("indice"))


static func _flecha(texto: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(44, 0)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", PLACA.ORO_VIVO)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", _fondo_encendido(0.10))
	b.add_theme_stylebox_override("pressed", _fondo_encendido(0.18))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


static func _marco_de_caja() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = NAVY_FONDO
	sb.border_color = PLACA.ORO_VIVO
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(9)
	sb.set_content_margin_all(2)
	return sb


static func _fondo_encendido(cuanto: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PLACA.ORO_VIVO.r, PLACA.ORO_VIVO.g, PLACA.ORO_VIVO.b, cuanto)
	sb.set_corner_radius_all(7)
	return sb


# ─── Guardar y Volver ─────────────────────────────────────────────────────────

## Los dos botones de abajo vienen pintados en el dibujo, con su icono y su
## texto: encima va un botón transparente que sólo se nota al pasar el ratón o
## al tener el foco, con un halo dorado.
static func _boton_pintado(nombre: String) -> Button:
	var b := Button.new()
	b.name = nombre
	b.set_meta("texto", nombre)
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", _halo(0.14))
	b.add_theme_stylebox_override("pressed", _halo(0.26))
	b.add_theme_stylebox_override("focus", _halo(0.18))
	return b


static func _halo(cuanto: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PLACA.ORO_VIVO.r, PLACA.ORO_VIVO.g, PLACA.ORO_VIVO.b, cuanto)
	sb.border_color = PLACA.ORO_VIVO
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.set_expand_margin_all(4)
	return sb
