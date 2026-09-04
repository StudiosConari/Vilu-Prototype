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
	_montar_aviso_de_logro()
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

	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.06, 0.07, 0.10, 0.55)
	fondo.border_color = Color(0.85, 0.80, 0.55, 0.55)
	fondo.set_border_width_all(2)
	fondo.set_corner_radius_all(6)
	fondo.set_content_margin_all(12)
	_mis_panel.add_theme_stylebox_override("panel", fondo)
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


func show_prompt(text: String) -> void:
	_prompt.text = text
	_prompt.visible = true


func hide_prompt() -> void:
	_prompt.visible = false


func show_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = true


func clear_banner() -> void:
	_banner.visible = false


func show_swap_hint(on: bool) -> void:
	if _swap:
		_swap.visible = on


## Panel de instrucción persistente (transparente) para puzzles.
func show_hint(text: String) -> void:
	if _hint_label:
		_hint_label.text = text
	if _hint:
		_hint.visible = true


func clear_hint() -> void:
	if _hint:
		_hint.visible = false
