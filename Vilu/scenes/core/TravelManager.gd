extends Node

## Autoload. Maquina de estados del viaje entre regiones. Carga una region
## dentro de un "holder" (Node3D contenedor de la escena de juego), preservando
## el estado del jugador via GameManager/Save. La transicion es un fundido a
## negro + swap de escena; sin cinematica (greybox).
##
## Uso desde la escena de juego (Game.gd):
##   await TravelManager.load_region(region_holder, "Iglesia")
##   await TravelManager.travel_to(region_holder, "Mina")

signal region_changed(region_name: String)

enum State { IDLE, TRAVELING }

## Escenas que se cargan APARTE del mundo abierto: los interiores con puerta y
## las escenas de puzzle.
##
## Las zonas del mundo (Tarapacá, Poblado, Alicanto, Yastay) YA NO están acá:
## viven construidas dentro de World.tscn y las registra WorldRoot en su tabla
## ZONAS. Ir a una de ellas no carga ninguna escena — es un teletransporte
## dentro del mundo que ya está vivo (Game.teleport_to). Sus viejas escenas de
## `scenes/regions/` se borraron para que nadie edite por error una copia que el
## juego no usa.
const REGIONS := {
	"Mina": "res://scenes/regions/Mina.tscn",
	"Iglesia": "res://scenes/regions/Iglesia.tscn",
	"Isluga": "res://scenes/puzzles/Isluga.tscn",
	"Cumbre": "res://scenes/puzzles/Cumbre.tscn",
	"Final": "res://scenes/puzzles/Final.tscn",
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
		push_warning("TravelManager: region desconocida '%s' (no-op)" % region_name)
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
		push_warning("TravelManager: region desconocida '%s' (no-op)" % region_name)
		return null
	state = State.TRAVELING
	await _fade_to(1.0)
	var region := load_region(holder, region_name)
	state = State.TRAVELING  # load_region lo pone IDLE; mantener hasta aclarar
	await _fade_to(0.0)
	state = State.IDLE
	return region


## Igual que travel_to pero ejecuta on_loaded(region) mientras la pantalla está
## negra, antes del fundido de vuelta — así el jugador ya está en posición correcta
## cuando la imagen vuelve y no se ve el salto.
func travel_to_then(holder: Node, region_name: String, on_loaded: Callable) -> Node:
	if not is_valid_region(region_name):
		push_warning("TravelManager: region desconocida '%s' (no-op)" % region_name)
		return null
	state = State.TRAVELING
	await _fade_to(1.0)
	var region := load_region(holder, region_name)
	on_loaded.call(region)
	state = State.TRAVELING
	await _fade_to(0.0)
	state = State.IDLE
	return region


## Fundido a negro -> ejecuta `accion` con la pantalla tapada -> aclara.
## No carga ni libera escenas: sirve para el teletransporte dentro del mundo
## abierto, donde no hay nada que cargar porque todo ya está vivo.
func fade_then(accion: Callable) -> void:
	state = State.TRAVELING
	await _fade_to(1.0)
	accion.call()
	await _fade_to(0.0)
	state = State.IDLE


## Vacía el holder de interiores (al volver de la Mina/Final al mundo abierto).
func clear_region(holder: Node) -> void:
	for child in holder.get_children():
		child.queue_free()
	current_region = ""


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
