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
	_mis_texto.text = "%s   %d/%d" % [m.get("texto", ""), hechos, total]
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


## El recuadro del centro de la pantalla: los avisos —«¡La lava quema!», «Nuevo
## logro»— iban sueltos arriba del todo, en letras blancas sobre lo que hubiera
## detrás, y sobre el cielo del volcán no se leían. Ahora salen en el centro,
## con la misma placa que el recuadro de misiones. Los dos carteles se meten
## dentro y la placa se ve mientras alguno tenga algo que decir.
var _cartel: PanelContainer = null


func _montar_cartel() -> void:
	_cartel = PanelContainer.new()
	_cartel.name = "Cartel"
	_cartel.set_anchors_preset(Control.PRESET_CENTER)
	_cartel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cartel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_cartel.custom_minimum_size = Vector2(640, 0)
	_cartel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cartel.add_theme_stylebox_override("panel", _placa())
	_cartel.visible = false
	add_child(_cartel)
	# En el centro justo: se probó un poco más arriba y se leía como «arriba»,
	# no como «en medio». Son desplazamientos desde el ancla, no una posición:
	# `position` es absoluta y con (-320, -180) la placa quedaba fuera de la
	# pantalla. Crece hacia los dos lados desde el centro.
	_cartel.offset_left = -320
	_cartel.offset_right = 320
	_cartel.offset_top = 0
	_cartel.offset_bottom = 0

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	_cartel.add_child(caja)
	for l: Label in [_aviso, _banner]:
		if l.get_parent() != null:
			l.get_parent().remove_child(l)
		caja.add_child(l)
		l.set_anchors_preset(Control.PRESET_TOP_LEFT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(616, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_refrescar_cartel()


## Cada cuadro, y no por la señal `visibility_changed`: dentro de una placa
## oculta, mostrar el cartel no la dispara —la visibilidad efectiva no cambia—
## y la placa se quedaba escondida con el aviso dentro.
func _process(_delta: float) -> void:
	_refrescar_cartel()


func _refrescar_cartel() -> void:
	if _cartel != null:
		_cartel.visible = _aviso.visible or _banner.visible


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
	_nota_texto.text = Botones.traducir(texto)
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


func _montar_aviso_de_logro() -> void:
	_aviso = Label.new()
	_aviso.name = "AvisoDeLogro"
	_aviso.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_aviso.position = Vector2(0, 96)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.add_theme_font_size_override("font_size", 34)
	_aviso.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62))
	_aviso.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_aviso.add_theme_constant_override("outline_size", 8)
	_aviso.visible = false
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_aviso)
	GameManager.logro_obtenido.connect(_al_conseguir_logro)


func _al_conseguir_logro(id: String) -> void:
	if _aviso == null:
		return
	_aviso.text = GameManager.titular_de_logro(id)
	_aviso.visible = true
	_aviso.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(AVISO_SEGUNDOS)
	t.tween_property(_aviso, "modulate:a", 0.0, 0.6)
	t.tween_callback(func() -> void: _aviso.visible = false)


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
	_consejo_texto.text = texto
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


func _on_health(current: int, maximum: int) -> void:
	_hp.max_value = maximum
	_hp.value = current
	_hp_label.text = "Vida %d/%d" % [current, maximum]


func _on_energy(current: int, maximum: int) -> void:
	_energy.max_value = maximum
	_energy.value = current
	_energy_label.text = "Energía %d/%d" % [current, maximum]


func _refresh_abilities() -> void:
	if _swap:
		_swap.text = texto_del_letrero_de_controles()
	_abilities.text = "Arco %s   Alas %s   Guanaco %s" % [
		_tick(GameManager.has_ability("bow")),
		_tick(GameManager.has_ability("wings")),
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
	_prompt.text = Botones.traducir(text)
	_prompt.visible = true


func hide_prompt() -> void:
	_prompt.visible = false


func show_banner(text: String) -> void:
	_banner.text = Botones.traducir(text)
	_banner.visible = true


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


func texto_del_letrero_de_controles() -> String:
	var t := LETRERO_CAMBIAR
	if GameManager.has_ability("guanaco"):
		t = LETRERO_GUANACO + "\n" + t
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
		_hint_label.text = Botones.traducir(text)
	if _hint:
		_hint.visible = false


func clear_hint() -> void:
	if _hint:
		_hint.visible = false
