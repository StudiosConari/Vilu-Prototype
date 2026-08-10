extends Node3D

## Beat 7 — Cumbre multinivel cooperativa:
##  0) Puente con GUANACO (Benjamín montado en la placa lo fija) para cruzar a MidLedge.
##  1) CORRIENTE ascendente: Emilia planea (mantiene Espacio) y sube a Platform_1.
##     Al llegar arma la CUERDA (Rope1); Benjamín pulsa E en la base y sube.
##  2) PLATAFORMA MÓVIL: Benjamín MONTADO (guanaco) se para sobre ella y lo lleva
##     a Platform_2.
##  3) CORRIENTE 2: Emilia sube a la plataforma FINAL y arma la CUERDA (Rope2);
##     Benjamín sube con E. Cuando LOS DOS están en la cima → Beat 7.

signal reached_summit

@export var advance_to_beat := 7

var _solved := false
var _bridge_latched := false
var _bridge_state := -1
var _on_final := 0

@onready var _mount_plate: Area3D = get_node_or_null("MountPlate")
@onready var _bridge_mesh: Node3D = get_node_or_null("Bridge/Mesh")
@onready var _bridge_shape: CollisionShape3D = get_node_or_null("Bridge/Shape")
@onready var _p1_trigger: Area3D = get_node_or_null("Platform1Trigger")
@onready var _rope1: Area3D = get_node_or_null("Rope1")
@onready var _final_trigger: Area3D = get_node_or_null("FinalTrigger")
@onready var _rope2: Area3D = get_node_or_null("Rope2")


func _ready() -> void:
	_set_bridge(false)
	if _p1_trigger:
		_p1_trigger.body_entered.connect(_on_platform1_reached)
	if _final_trigger:
		_final_trigger.body_entered.connect(_on_final_enter)
		_final_trigger.body_exited.connect(_on_final_exit)
	_hint("Cumbre: cruza el puente con el GUANACO. Con Emilia entra a la corriente y mantené Espacio para SUBIR; al llegar arriba, Benjamín sube por la CUERDA con E. Con el guanaco, Benjamín viaja en la plataforma móvil.")


func _process(_delta: float) -> void:
	# Etapa 0: el puente se fija al pisarlo un personaje MONTADO (guanaco).
	if _bridge_latched:
		return
	if _mount_plate:
		for b in _mount_plate.get_overlapping_bodies():
			if b.is_in_group("player") and "mounted" in b and b.mounted:
				_bridge_latched = true
				_set_bridge(true)
				break


func _set_bridge(up: bool) -> void:
	var s := 1 if up else 0
	if s == _bridge_state:
		return
	_bridge_state = s
	if _bridge_mesh:
		_bridge_mesh.visible = up
	if _bridge_shape:
		_bridge_shape.set_deferred("disabled", not up)


func _on_platform1_reached(body: Node3D) -> void:
	if body.is_in_group("player") and _rope1 and _rope1.has_method("arm"):
		_rope1.arm(true)


func _on_final_enter(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if _rope2 and _rope2.has_method("arm"):
		_rope2.arm(true)
	_on_final += 1
	if _on_final >= 2:
		_solve()


func _on_final_exit(body: Node3D) -> void:
	if body.is_in_group("player"):
		_on_final = max(0, _on_final - 1)


func _solve() -> void:
	if _solved:
		return
	_solved = true
	_hint("¡Cima de VILU alcanzada por los dos!")
	if GameManager.get_beat() < advance_to_beat:
		GameManager.set_beat(advance_to_beat)
	reached_summit.emit()


func is_solved() -> bool:
	return _solved


func _hint(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_hint"):
		hud.show_hint(text)
