extends Node3D

## Beat 7 — Progresión de cumbre. Encadena las tres habilidades (reusa mecánicas
## de los Beats 4/5):
##  1) GUANACO: montar (Q) y sostener MountPlate levanta Bridge1 para cruzar.
##  2) ARCO: acertar el TimedTarget libera Barrier2.
##  3) ALAS: planear sobre el GlideGap hasta la cima (SummitTrigger).
## Llegar a la cima entra al Beat 7.
##
## NOTA: el salto/planeo del GlideGap es la única parte dependiente de "feel";
## el hueco es generoso a propósito y quedará para afinar en el playtest.

signal reached_summit

@export var advance_to_beat := 7

var _solved := false

@onready var _mount_plate: Area3D = get_node_or_null("MountPlate")
@onready var _bridge_mesh: Node3D = get_node_or_null("Bridge1/Mesh")
@onready var _bridge_shape: CollisionShape3D = get_node_or_null("Bridge1/Shape")
@onready var _target: Node = get_node_or_null("TimedTarget")
@onready var _barrier: Node = get_node_or_null("Barrier2")
@onready var _summit: Area3D = get_node_or_null("SummitTrigger")


func _ready() -> void:
	if _target and _target.has_signal("hit_while_active"):
		_target.hit_while_active.connect(_on_target_hit)
	if _summit:
		_summit.body_entered.connect(_on_summit)
	_set_bridge(false)
	_banner("Cumbre — encadena tus dones: Q monta para el puente, arco al objetivo, alas para cruzar")


func _process(_delta: float) -> void:
	# El puente sube mientras un personaje MONTADO (guanaco) sostiene la placa.
	if _mount_plate:
		var held := false
		for b in _mount_plate.get_overlapping_bodies():
			if b.is_in_group("player") and "mounted" in b and b.mounted:
				held = true
				break
		_set_bridge(held)


func _set_bridge(up: bool) -> void:
	if _bridge_mesh:
		_bridge_mesh.visible = up
	if _bridge_shape:
		_bridge_shape.set_deferred("disabled", not up)


func _on_target_hit() -> void:
	if _barrier and is_instance_valid(_barrier):
		_barrier.queue_free()
		_barrier = null
	_banner("¡Objetivo acertado! El paso a la cima se abre.", 2.5)


func _on_summit(body: Node3D) -> void:
	if body.is_in_group("player"):
		_solve()


func _solve() -> void:
	if _solved:
		return
	_solved = true
	_banner("¡Cima de VILU alcanzada!", 3.0)
	if GameManager.get_beat() < advance_to_beat:
		GameManager.set_beat(advance_to_beat)
	reached_summit.emit()


func is_solved() -> bool:
	return _solved


func _banner(text: String, auto_clear := 0.0) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_banner"):
		hud.show_banner(text)
		if auto_clear > 0.0:
			get_tree().create_timer(auto_clear).timeout.connect(func() -> void:
				if is_instance_valid(hud) and hud.has_method("clear_banner"):
					hud.clear_banner())
