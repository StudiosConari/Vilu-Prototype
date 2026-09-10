extends CanvasLayer

## HUD mínimo del núcleo jugable: barra de vida, indicador de habilidades
## activas (lee GameManager) y prompt de interacción (oculto por defecto).
## Sin arte: Labels y ProgressBar. El HUD real/estilizado llega con el arte.

@onready var _hp_label: Label = $Stats/HPLabel
@onready var _hp: ProgressBar = $Stats/HP
@onready var _energy_label: Label = $Stats/EnergyLabel
@onready var _energy: ProgressBar = $Stats/Energy
@onready var _abilities: Label = $Stats/Abilities
@onready var _debug: Label = $Stats/Debug
@onready var _prompt: Label = $Prompt
@onready var _banner: Label = $Banner
@onready var _swap: Label = $Swap
@onready var _hint: Control = $Hint
@onready var _hint_label: Label = $Hint/HintLabel


func _ready() -> void:
	_montar_misiones()
	_montar_nota()
	_montar_aviso_de_logro()
	_montar_cartel()
	_montar_marcos()
	GameManager.ability_unlocked.connect(func(_a: String) -> void: _refresh_abilities())
	GameManager.beat_changed.connect(func(_i: int) -> void: _refresh_debug())
	TravelManager.region_changed.connect(func(_r: String) -> void: _refresh_debug())
	_refresh_abilities()
	_refresh_debug()
	hide_prompt()
	clear_banner()
	show_swap_hint(false)
	clear_hint()


# --- Misiones y logros -----------------------------------------------------

## El recuadro de misiones, arriba a la derecha.
##
## Se monta por código y no en la escena para que el HUD siga siendo un archivo
## que se puede leer de un vistazo, como el resto: aquí no hay arte todavía, es
## un panel translúcido con una línea de texto.
var _mis_panel: PanelContainer = null
var _mis_titulo: Label = null
var _mis_texto: Label = null
var _aviso: Label = null

## Lo que dura en pantalla el cartel de un logro.
const AVISO_SEGUNDOS := 3.5


func _montar_misiones() -> void:
	_mis_panel = PanelContainer.new()
	_mis_panel.name = "Misiones"
	_mis_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_mis_panel.position = Vector2(-430, 18)
	_mis_panel.custom_minimum_size = Vector2(412, 0)
	_mis_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mis_panel.add_theme_stylebox_override("panel", _placa())
	add_child(_mis_panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 4)
	_mis_panel.add_child(caja)

	_mis_titulo = Label.new()
	_mis_titulo.text = "Misiones"
	_mis_titulo.add_theme_font_size_override("font_size", 15)
	_mis_titulo.add_theme_color_override("font_color", Color(0.85, 0.80, 0.55))
	caja.add_child(_mis_titulo)

	_mis_texto = Label.new()
	_mis_texto.add_theme_font_size_override("font_size", 19)
	_mis_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mis_texto.custom_minimum_size = Vector2(388, 0)
	caja.add_child(_mis_texto)

	Misiones.cambio.connect(_al_cambiar_mision)
	Misiones.avance.connect(_al_avanzar_mision)
	_al_cambiar_mision(Misiones.actual())
	_al_avanzar_mision(Misiones.hechos(), int(Misiones.actual().get("total", 1)))


func _al_cambiar_mision(m: Dictionary) -> void:
	if _mis_panel == null:
		return
	# Sin misión —cadena terminada— el recuadro desaparece en vez de quedarse
	# vacío ocupando sitio.
	_mis_panel.visible = not m.is_empty()
	if not m.is_empty():
		_pintar_mision(m, 0)


func _al_avanzar_mision(hechos: int, _total: int) -> void:
	var m: Dictionary = Misiones.actual()
	if not m.is_empty():
		_pintar_mision(m, hechos)


func _pintar_mision(m: Dictionary, hechos: int) -> void:
	var total: int = int(m.get("total", 1))
	_mis_texto.text = "%s   %d/%d" % [tr(String(m.get("texto", ""))), hechos, total]
	# Cumplida se pone en verde el rato que se queda en pantalla, para que se
	# vea que se hizo y no sólo que el número llegó al tope.
	var hecha := hechos >= total
	_mis_texto.add_theme_color_override("font_color",
		Color(0.60, 0.95, 0.60) if hecha else Color(0.95, 0.95, 0.95))


## El estilo de los recuadros del HUD: el de misiones, y los que lo copian.
func _placa() -> StyleBoxFlat:
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.06, 0.07, 0.10, 0.55)
	fondo.border_color = Color(0.85, 0.80, 0.55, 0.55)
	fondo.set_border_width_all(2)
	fondo.set_corner_radius_all(6)
	fondo.set_content_margin_all(12)
	return fondo


## La placa de los avisos —«¡La lava quema!», «Sin energía para la flecha
## triple», los mineros corruptos—: arriba, centrada y chica, con el mismo
## formato que el aviso de logro, para que no corte la pantalla. Iban en una
## placa grande en el centro y tapaban lo que estaba pasando. Si justo hay un
## logro sonando, el aviso se pone debajo de él.
var _cartel: PanelContainer = null
const AVISO_SEPARACION := 50.0


func _montar_cartel() -> void:
	_cartel = PanelContainer.new()
	_cartel.name = "Cartel"
	_cartel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_cartel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cartel.offset_top = AVISO_ALTO
	_cartel.offset_bottom = AVISO_ALTO
	_cartel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cartel.add_theme_stylebox_override("panel", _placa_chica())
	_cartel.visible = false
	add_child(_cartel)
	if _banner.get_parent() != null:
		_banner.get_parent().remove_child(_banner)
	_cartel.add_child(_banner)
	_banner.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.custom_minimum_size = Vector2.ZERO
	_banner.add_theme_font_size_override("font_size", 18)
	_banner.add_theme_color_override("font_color", Color(0.96, 0.93, 0.85))
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_banner.add_theme_constant_override("outline_size", 4)
	_refrescar_cartel()


## La placa chica de arriba: la del logro y la de los avisos.
func _placa_chica() -> StyleBoxFlat:
	var fondo := _placa()
	fondo.set_content_margin_all(8)
	fondo.content_margin_left = 16
	fondo.content_margin_right = 16
	return fondo


## Al cambiar el idioma en Opciones, el recuadro de misiones se vuelve a
## escribir: su texto se arma con `tr()` al cambiar de misión, y si no se
## quedaba en el idioma anterior hasta la siguiente.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _mis_panel != null and _mis_texto != null:
		_al_avanzar_mision(Misiones.hechos(), 0)


## Cada cuadro, y no por la señal `visibility_changed`: dentro de una placa
## oculta, mostrar el cartel no la dispara —la visibilidad efectiva no cambia—
## y la placa se quedaba escondida con el aviso dentro.
func _process(_delta: float) -> void:
	_refrescar_cartel()
	_refrescar_marcos()


func _refrescar_cartel() -> void:
	if _cartel == null:
		return
	_cartel.visible = _banner.visible
	# Debajo del aviso de logro mientras ése se vea.
	var y := AVISO_ALTO
	if _placa_de_logro != null and _placa_de_logro.visible:
		y += AVISO_SEPARACION
	_cartel.offset_top = y
	_cartel.offset_bottom = y


## Un recuadro bajo el de misiones, para un recordatorio que dura un rato.
##
## Lo pidió el volcán: quien entra tiene que acordarse de que con [T] cada uno
## resuelve el puzzle por separado, y el cartel de abajo ya no se muestra.
var _nota_panel: PanelContainer = null
var _nota_texto: Label = null
var _nota_vence := 0


func _montar_nota() -> void:
	_nota_panel = PanelContainer.new()
	_nota_panel.name = "Nota"
	_nota_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_nota_panel.custom_minimum_size = Vector2(412, 0)
	_nota_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nota_panel.add_theme_stylebox_override("panel", _placa())
	_nota_panel.visible = false
	add_child(_nota_panel)
	_nota_texto = Label.new()
	_nota_texto.add_theme_font_size_override("font_size", 17)
	_nota_texto.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62))
	_nota_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nota_texto.custom_minimum_size = Vector2(388, 0)
	_nota_panel.add_child(_nota_texto)


## Muestra un recordatorio bajo las misiones durante `segundos` (0 = hasta que
## se quite a mano).
func mostrar_nota(texto: String, segundos := 10.0) -> void:
	if _nota_panel == null:
		return
	_nota_texto.text = Botones.traducir(tr(texto))
	_nota_panel.visible = true
	_colocar_nota.call_deferred()
	_nota_vence += 1
	if segundos <= 0.0:
		return
	var esta := _nota_vence
	get_tree().create_timer(segundos).timeout.connect(func() -> void:
		var h := get_tree().get_first_node_in_group("hud")
		if h != null and h.get("_nota_vence") == esta and h.has_method("quitar_nota"):
			h.quitar_nota())


func quitar_nota() -> void:
	if _nota_panel != null:
		_nota_panel.visible = false


## Justo debajo del recuadro de misiones, mida lo que mida éste.
func _colocar_nota() -> void:
	if _nota_panel == null or _mis_panel == null:
		return
	var y := _mis_panel.position.y + _mis_panel.size.y + 10.0
	if not _mis_panel.visible:
		y = _mis_panel.position.y
	_nota_panel.position = Vector2(_mis_panel.position.x, y)


## El aviso de logro: una placa chica arriba, centrada, que no tapa la
## escena. Antes iba en la placa grande del centro con letra de 34 y se comía
## la pantalla en pleno diálogo.
var _placa_de_logro: PanelContainer = null
const AVISO_ALTO := 44.0


func _montar_aviso_de_logro() -> void:
	_placa_de_logro = PanelContainer.new()
	_placa_de_logro.name = "PlacaDeLogro"
	_placa_de_logro.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_placa_de_logro.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_placa_de_logro.offset_top = AVISO_ALTO
	_placa_de_logro.offset_bottom = AVISO_ALTO
	_placa_de_logro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placa_de_logro.add_theme_stylebox_override("panel", _placa_chica())
	_placa_de_logro.visible = false
	add_child(_placa_de_logro)
	_aviso = Label.new()
	_aviso.name = "AvisoDeLogro"
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.add_theme_font_size_override("font_size", 18)
	_aviso.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62))
	_aviso.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_aviso.add_theme_constant_override("outline_size", 4)
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placa_de_logro.add_child(_aviso)
	GameManager.logro_obtenido.connect(_al_conseguir_logro)


func _al_conseguir_logro(id: String) -> void:
	if _aviso == null:
		return
	_aviso.text = GameManager.titular_de_logro(id)
	_placa_de_logro.visible = true
	_placa_de_logro.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(AVISO_SEGUNDOS)
	t.tween_property(_placa_de_logro, "modulate:a", 0.0, 0.6)
	t.tween_callback(func() -> void: _placa_de_logro.visible = false)


# --- Consejos de zona ------------------------------------------------------

const PLACA := preload("res://scenes/ui/Placa.gd")

var _consejo: PanelContainer = null
var _consejo_texto: Label = null


## Una explicación que aparece un rato y se va sola, abajo en el centro.
##
## No es el cartel de `show_banner` —ése lo pone y lo quita quien lo llama, y se
## usa para el estado de un puzzle—: esto es para enseñar algo UNA vez, al
## llegar a un sitio. La primera es la [T] en los volcanes, que es donde hace
## falta separar a los dos personajes y no hay nada que lo diga.
func consejo(texto: String, segundos := 7.0) -> void:
	if _consejo == null:
		_consejo = PanelContainer.new()
		_consejo.name = "Consejo"
		_consejo.add_theme_stylebox_override("panel", PLACA.estilo(0.0, 0.86, 20))
		_consejo.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_consejo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_consejo_texto = Label.new()
		_consejo_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_consejo_texto.add_theme_font_size_override("font_size", 22)
		_consejo_texto.add_theme_color_override("font_color", PLACA.LETRA)
		_consejo.add_child(_consejo_texto)
		add_child(_consejo)
	_consejo_texto.text = Botones.traducir(tr(texto))
	# Anclado abajo al centro, hay que descontar la mitad de lo que mide para
	# que quede centrado de verdad, y su alto para que no se salga por abajo.
	await get_tree().process_frame
	_consejo.position = Vector2(-_consejo.size.x * 0.5, -_consejo.size.y - 110.0)
	_consejo.visible = true
	_consejo.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(segundos)
	t.tween_property(_consejo, "modulate:a", 0.0, 0.8)
	t.tween_callback(func() -> void:
		if is_instance_valid(_consejo):
			_consejo.visible = false)


var _bound: Node = null


## Conecta el HUD al personaje activo (rebindable en cada swap, sin duplicar).
func bind_player(player: Node) -> void:
	if _bound and is_instance_valid(_bound):
		if _bound.health_changed.is_connected(_on_health):
			_bound.health_changed.disconnect(_on_health)
		if _bound.energy_changed.is_connected(_on_energy):
			_bound.energy_changed.disconnect(_on_energy)
	_bound = player
	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_health)
		_on_health(player.health, player.max_health)
	if player.has_signal("energy_changed"):
		player.energy_changed.connect(_on_energy)
		_on_energy(int(player.energy), player.max_energy)
	_refrescar_marcos()


## El que espera: su retrato chico va debajo del activo. Con null no se ve.
func bind_companero(otro: Node) -> void:
	_companero = otro
	_refrescar_marcos()


func _on_health(current: int, maximum: int) -> void:
	_hp.max_value = maximum
	_hp.value = current
	_hp_label.text = tr("Vida %d/%d") % [current, maximum]
	_barra("vida", current, maximum)


func _on_energy(current: int, maximum: int) -> void:
	_energy.max_value = maximum
	_energy.value = current
	_energy_label.text = tr("Energía %d/%d") % [current, maximum]
	_barra("energia", current, maximum)


func _refresh_abilities() -> void:
	if _swap:
		_swap.text = texto_del_letrero_de_controles()
	_abilities.text = "%s %s   %s %s   %s %s" % [tr("Arco"),
		_tick(GameManager.has_ability("bow")), tr("Alas"),
		_tick(GameManager.has_ability("wings")), tr("Guanaco"),
		_tick(GameManager.has_ability("guanaco")),
	]


func _tick(v: bool) -> String:
	return "✓" if v else "✗"


func _refresh_debug() -> void:
	_debug.text = "Beat %d/%d · %s" % [
		GameManager.get_beat() + 1,
		GameManager.BEAT_COUNT,
		TravelManager.current_region,
	]


## Los carteles pasan por Botones: "[E] Hablar" se convierte en "[X] Hablar"
## cuando lo último que se tocó fue un mando. Se traduce ACÁ y no en los
## cincuenta y tantos sitios que escriben el texto.
func show_prompt(text: String) -> void:
	_prompt.text = Botones.traducir(tr(text))
	_prompt.visible = true


func hide_prompt() -> void:
	_prompt.visible = false


## Un aviso en la placa del centro. Se va solo a los `segundos`; con 0 se
## queda hasta que alguien llame a `clear_banner`.
##
## Antes se quedaba siempre: «El camino se abre» del Isluga, o el de la
## embestida del guanaco, no se iban nunca porque quien los ponía no los
## quitaba. Ahora el que quiera uno fijo lo pide con 0.
const BANNER_SEGUNDOS := 4.0
var _banner_vence := 0


func show_banner(text: String, segundos := BANNER_SEGUNDOS) -> void:
	_banner.text = Botones.traducir(tr(text))
	_banner.visible = true
	_banner_vence += 1
	if segundos <= 0.0:
		return
	var este := _banner_vence
	get_tree().create_timer(segundos).timeout.connect(func() -> void:
		# Se vuelve a buscar en vez de capturar `self`: si el HUD se liberó,
		# la lambda no debe tocarlo. Y sólo se quita si nadie puso otro después.
		var h := get_tree().get_first_node_in_group("hud")
		if h != null and h.get("_banner_vence") == este and h.has_method("clear_banner"):
			h.clear_banner())


func clear_banner() -> void:
	_banner.visible = false


func show_swap_hint(on: bool) -> void:
	if _swap:
		_swap.visible = on
		_swap.text = texto_del_letrero_de_controles()


## Lo que dice el letrero de abajo a la derecha: cómo cambiar de personaje y,
## en cuanto Benjamín tiene al guanaco, cómo usarlo. Crece hacia arriba para
## que la segunda línea no se salga por abajo.
const LETRERO_CAMBIAR := "[R] cambiar (IA) · [T] cambiar (queda quieto)"
const LETRERO_GUANACO := "[Q] invocar · [C] montar · [G] embestir"
const LETRERO_MARCOS := "[P] marcos y logros"


func texto_del_letrero_de_controles() -> String:
	# La [P] en su propia línea: en la misma que las de cambiar no cabía y se
	# salía por la izquierda.
	var t := tr(LETRERO_CAMBIAR) + "
" + tr(LETRERO_MARCOS)
	if GameManager.has_ability("guanaco"):
		t = tr(LETRERO_GUANACO) + "\n" + t
	return Botones.traducir(t)


## Panel de instrucción persistente (transparente) para puzzles.
## El cartel de abajo ya no se muestra: lo reemplazó el recuadro de misiones.
##
## La función se queda —vacía a propósito— porque medio juego la llama para
## contar qué toca hacer ahora, y eso es justo lo que dice el recuadro. Borrarla
## obligaría a tocar una docena de escenas para no ganar nada; así el texto se
## sigue escribiendo en el nodo, por si alguna vez hace falta volver, pero no
## tapa la pantalla.
func show_hint(text: String) -> void:
	if _hint_label:
		_hint_label.text = Botones.traducir(tr(text))
	if _hint:
		_hint.visible = false


func clear_hint() -> void:
	if _hint:
		_hint.visible = false


# --- Los marcos de los personajes -------------------------------------------

## El retrato del personaje activo con su panel de vida, energía y carga y,
## debajo y más chico, el del que espera. Es el arte de `textures/ui/hud/`.
##
## El panel viene SIN barras ni rótulos: se borraron del dibujo y se ponen aquí,
## así los rótulos salen en el idioma que toque y las barras se rellenan de
## verdad. Las barras son las mismas pintadas, recortadas, que se usan como
## textura de progreso: lo que falta de vida se ve como la barra apagada.
##
## El que espera se ve de dos maneras: tras [R] sigue al otro y sale con su
## marco chico; tras [T] se queda plantado, y sale «amurrado». Y desde la cima
## del Ojos del Salado hay un marco alternativo para cada uno, que se elige en
## la pantalla de la [P].
const ARTE_HUD := "res://textures/ui/hud/"
## Alto del retrato grande, en la pantalla de diseño (1280x720). Se probó a
## 210 y tapaba media esquina; a 140 se amontonaba: quedó en medio.
const ALTO_DEL_RETRATO := 175.0
const PROPORCION_DEL_RETRATO := 492.0 / 505.0   # ancho/alto de retrato_*.png
const PROPORCION_DEL_PANEL := 0.4715            # alto/ancho de panel_*.png
## El panel respecto del retrato —dónde empieza y cuánto mide, en fracciones
## del retrato—, medido en la composición de referencia de la artista: el
## retrato se monta sobre la punta izquierda del panel.
const PANEL_DESDE := Vector2(0.845, 0.16)
const PANEL_ANCHO := 1.36
## El retrato chico del compañero: cuánto mide respecto del grande y dónde va.
const CHICO_ESCALA := 0.6
const CHICO_DESDE := Vector2(0.55, 0.80)
## Barras y rótulos dentro del panel, en fracciones del panel.
const BARRAS := {
	"vida":    Rect2(0.3598, 0.3339, 0.4179, 0.0993),
	"energia": Rect2(0.3598, 0.5246, 0.4179, 0.0994),
	"carga":   Rect2(0.3561, 0.7075, 0.4273, 0.1590),
}
const ROTULOS := {
	"vida":    Rect2(0.150, 0.3219, 0.205, 0.1153),
	"energia": Rect2(0.150, 0.5207, 0.205, 0.1192),
	"carga":   Rect2(0.150, 0.7353, 0.205, 0.1312),
}
const NOMBRE_DE_BARRA := {"vida": "Vida", "energia": "Energía", "carga": "Carga"}
## Cómo se ve la parte vacía de una barra.
const BARRA_APAGADA := Color(0.28, 0.28, 0.34, 1.0)
const LETRA_DE_ROTULO := 12

var _marcos: Control = null
var _retrato: TextureRect = null
var _panel: TextureRect = null
var _chico: TextureRect = null
var _barras := {}
var _companero: Node = null


func _montar_marcos() -> void:
	if not ResourceLoader.exists(ARTE_HUD + "panel_emilia.png"):
		return
	_marcos = Control.new()
	_marcos.name = "Marcos"
	_marcos.position = Vector2(14, 8)
	_marcos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marcos)

	var alto := ALTO_DEL_RETRATO
	var ancho := alto * PROPORCION_DEL_RETRATO
	var panel_ancho := ancho * PANEL_ANCHO
	var panel := Rect2(PANEL_DESDE.x * ancho, PANEL_DESDE.y * alto,
		panel_ancho, panel_ancho * PROPORCION_DEL_PANEL)
	# El panel primero y el retrato encima: las plumas del retrato tapan la
	# punta del panel, como en la referencia.
	_panel = _dibujo("Panel", panel)
	_retrato = _dibujo("Retrato", Rect2(0, 0, ancho, alto))
	for k: String in BARRAS:
		var b := TextureProgressBar.new()
		b.name = "Barra" + k.capitalize()
		var arte := load(ARTE_HUD + "barra_%s.png" % k) as Texture2D
		b.texture_progress = arte
		b.texture_under = arte
		b.tint_under = BARRA_APAGADA
		b.nine_patch_stretch = true
		b.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
		b.min_value = 0.0
		b.max_value = 1.0
		# El paso por defecto de un Range es 1: con él la barra sólo sabe
		# estar llena o vacía.
		b.step = 0.0
		b.value = 1.0 if k != "carga" else 0.0
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_colocar(b, _dentro(panel, BARRAS[k]))
		_marcos.add_child(b)
		_barras[k] = b
	for k: String in ROTULOS:
		var l := Label.new()
		l.name = "Rotulo" + k.capitalize()
		l.text = NOMBRE_DE_BARRA[k]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", _serif())
		l.add_theme_font_size_override("font_size", LETRA_DE_ROTULO)
		l.add_theme_color_override("font_color", PLACA.LETRA)
		l.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.10, 0.9))
		l.add_theme_constant_override("outline_size", 2)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_colocar(l, _dentro(panel, ROTULOS[k]))
		_marcos.add_child(l)
	_chico = _dibujo("Companero", Rect2(CHICO_DESDE.x * ancho, CHICO_DESDE.y * alto,
		ancho * CHICO_ESCALA, alto * CHICO_ESCALA))
	_marcos.size = Vector2(panel.end.x, alto * (CHICO_DESDE.y + CHICO_ESCALA))
	_marcos.visible = false


func _dibujo(nombre: String, r: Rect2) -> TextureRect:
	var t := TextureRect.new()
	t.name = nombre
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colocar(t, r)
	_marcos.add_child(t)
	return t


static func _colocar(c: Control, r: Rect2) -> void:
	c.position = r.position
	c.size = r.size


static func _dentro(marco: Rect2, f: Rect2) -> Rect2:
	return Rect2(marco.position + f.position * marco.size, f.size * marco.size)


static func _serif() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Georgia", "Times New Roman", "Liberation Serif", "DejaVu Serif"])
	return f


func _barra(cual: String, valor: float, tope: float) -> void:
	if _barras.has(cual):
		(_barras[cual] as TextureProgressBar).value = clampf(valor / maxf(tope, 1.0), 0.0, 1.0)


## "emilia" o "benjamin", por el rol: el arquero es Benjamín.
static func quien_es(p: Node) -> String:
	return "benjamin" if bool(p.get("is_archer")) else "emilia"


## Plantado con [T]: el que espera sin seguir a nadie.
static func esta_amurrado(p: Node) -> bool:
	return "ai_mode" in p and int(p.get("ai_mode")) == int(p.AiMode.FROZEN)


## Qué dibujo le toca a `quien`: amurrado si se quedó plantado, y con el marco
## que eligió —si ya lo tiene— esté activo, siguiendo o plantado.
func retrato_de(quien: String, amurrado: bool) -> String:
	var alterno := GameManager.marco_de(quien) == "alterno"
	if amurrado:
		if quien == "emilia":
			return ARTE_HUD + ("amurrada_alterna_emilia.png" if alterno else "amurrada_emilia.png")
		return ARTE_HUD + ("amurrado_alterno_benjamin.png" if alterno else "amurrado_benjamin.png")
	if alterno:
		return ARTE_HUD + "alterno_%s.png" % quien
	return ARTE_HUD + "retrato_%s.png" % quien


func _refrescar_marcos() -> void:
	if _marcos == null:
		return
	var hay := _bound != null and is_instance_valid(_bound)
	_marcos.visible = hay
	if not hay:
		return
	var quien := quien_es(_bound)
	_poner(_retrato, retrato_de(quien, false))
	_poner(_panel, ARTE_HUD + "panel_%s.png" % quien)
	var con_companero := _companero != null and is_instance_valid(_companero) \
		and _companero != _bound
	_chico.visible = con_companero
	if con_companero:
		_poner(_chico, retrato_de(quien_es(_companero), esta_amurrado(_companero)))
	# La carga: lo que lleva tensado el arco, o el golpe de Emilia.
	var carga := 0.0
	if bool(_bound.get("_charging")):
		carga = clampf(float(_bound.get("_charge_t")) / maxf(float(_bound.get("charge_time")), 0.01), 0.0, 1.0)
	_barra("carga", carga, 1.0)


## El dibujo del retrato de `quien` con el marco que tenga elegido (y ganado).
static func ruta_del_retrato(quien: String) -> String:
	if GameManager.marco_de(quien) == "alterno":
		return ARTE_HUD + "alterno_%s.png" % quien
	return ARTE_HUD + "retrato_%s.png" % quien


## Cambia la textura sólo si es otra: se llama cada cuadro.
static func _poner(t: TextureRect, ruta: String) -> void:
	if String(t.get_meta("ruta", "")) == ruta:
		return
	t.set_meta("ruta", ruta)
	t.texture = load(ruta) if ResourceLoader.exists(ruta) else null
