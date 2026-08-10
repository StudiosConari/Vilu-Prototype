extends Node3D

## Beat 5 — Ascenso del Ojos del Salado. Cooperativo por turnos con los DOS
## protagonistas del party (swap con R): uno SOSTIENE la placa (PlateA) para que
## aparezca el Bridge sobre el vacío; el otro CRUZA hasta la cima. Llegar a la
## cima entra al Beat 5. Ambos personajes ya existen (los crea Game), aquí no se
## instancia nada.

signal solved

@export var advance_to_beat := 5

var _is_solved := false
var _on_plate := 0
var _bridge_state := -1   # -1 sin fijar, 0 abajo, 1 arriba (evita re-togglear)

@onready var _plate_a: Area3D = get_node_or_null("PlateA")
@onready var _plate_b: Area3D = get_node_or_null("PlateB")
@onready var _bridge_mesh: Node3D = get_node_or_null("Bridge/Mesh")
@onready var _bridge_shape: CollisionShape3D = get_node_or_null("Bridge/Shape")
@onready var _summit: Area3D = get_node_or_null("SummitTrigger")


func _ready() -> void:
	# Dos placas (una a cada lado del vacío): el puente sube si CUALQUIERA está
	# ocupada. Así el que cruza puede pisar la de enfrente y ayudar al otro a cruzar.
	for pl in [_plate_a, _plate_b]:
		if pl:
			pl.body_entered.connect(_on_plate_enter)
			pl.body_exited.connect(_on_plate_exit)
	if _summit:
		_summit.body_entered.connect(_on_summit)
	_set_bridge(false)
	_hint("Ascenso: parate en una placa cian y pulsá T (queda quieto sosteniendo el puente). Cruzá con el otro, pisá la placa de enfrente (T) y cruza el primero.")


func _on_plate_enter(body: Node3D) -> void:
	if body.is_in_group("player"):
		_on_plate += 1
		_set_bridge(_on_plate > 0)


func _on_plate_exit(body: Node3D) -> void:
	if body.is_in_group("player"):
		_on_plate = max(0, _on_plate - 1)
		_set_bridge(_on_plate > 0)


func _set_bridge(up: bool) -> void:
	var s := 1 if up else 0
	if s == _bridge_state:
		return   # sin cambios: no re-togglear (evita el "vibrado")
	_bridge_state = s
	if _bridge_mesh:
		_bridge_mesh.visible = up
	if _bridge_shape:
		_bridge_shape.set_deferred("disabled", not up)


func _on_summit(body: Node3D) -> void:
	if body.is_in_group("player"):
		_solve()


func _solve() -> void:
	if _is_solved:
		return
	_is_solved = true
	_hint("¡Cima alcanzada! Ascenso superado.")
	if GameManager.get_beat() < advance_to_beat:
		GameManager.set_beat(advance_to_beat)
	solved.emit()


func is_solved() -> bool:
	return _is_solved


func _hint(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_hint"):
		hud.show_hint(text)
