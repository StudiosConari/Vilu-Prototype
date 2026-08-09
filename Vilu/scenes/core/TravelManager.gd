extends Node

## Autoload. Maquina de estados del viaje entre regiones. Carga una region
## dentro de un "holder" (Node3D contenedor de la escena de juego), preservando
## el estado del jugador via GameManager/Save. La transicion es un fundido a
## negro + swap de escena; sin cinematica (greybox).
##
## Uso desde la escena de juego (Game.gd):
##   await TravelManager.load_region(region_holder, "Region1_Tarapaca")
##   await TravelManager.travel_to(region_holder, "Region2_Volcan")

signal region_changed(region_name: String)

enum State { IDLE, TRAVELING }

const REGIONS := {
	"Region1_Tarapaca": "res://scenes/regions/Region1_Tarapaca.tscn",
	"Region2_Volcan": "res://scenes/regions/Region2_Volcan.tscn",
}

var state: State = State.IDLE
var current_region: String = ""

var _fade: ColorRect
var _layer: CanvasLayer


func is_valid_region(region_name: String) -> bool:
	return REGIONS.has(region_name)


## Carga una region en el holder al instante (sin fundido). Libera lo previo.
## Devuelve el nodo raiz de la region instanciada, o null si el nombre no existe.
func load_region(holder: Node, region_name: String) -> Node:
	if not is_valid_region(region_name):
		push_error("TravelManager: region desconocida '%s'" % region_name)
		return null
	for child in holder.get_children():
		child.queue_free()
	var packed: PackedScene = load(REGIONS[region_name])
	var region := packed.instantiate()
	holder.add_child(region)
	current_region = region_name
	state = State.IDLE
	region_changed.emit(region_name)
	return region


## Viaje con fundido: negro -> swap de region -> aclarar. Async.
func travel_to(holder: Node, region_name: String) -> Node:
	if not is_valid_region(region_name):
		push_error("TravelManager: region desconocida '%s'" % region_name)
		return null
	state = State.TRAVELING
	await _fade_to(1.0)
	var region := load_region(holder, region_name)
	state = State.TRAVELING  # load_region lo pone IDLE; mantener hasta aclarar
	await _fade_to(0.0)
	state = State.IDLE
	return region


func _ensure_fade() -> void:
	if is_instance_valid(_fade):
		return
	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)


func _fade_to(alpha: float, duration := 0.4) -> void:
	_ensure_fade()
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, duration)
	await tw.finished
