extends Area3D

## Corriente de viento ascendente. Mientras esté ACTIVA y un personaje con ALAS
## (Emilia) esté dentro planeando (mantiene Espacio), sube (lo aplica
## PlayerController leyendo in_updraft). Puede arrancar inactiva y activarse
## (p.ej. al acertarle una flecha a un switch). Requiere collision_mask 2.

@export var active := true

@onready var _mesh: Node3D = get_node_or_null("Mesh")


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	_refresh_visual()


func _on_enter(body: Node3D) -> void:
	if active and body.is_in_group("player") and "in_updraft" in body:
		body.in_updraft = true


func _on_exit(body: Node3D) -> void:
	if body.is_in_group("player") and "in_updraft" in body:
		body.in_updraft = false


func set_active(on: bool) -> void:
	active = on
	_refresh_visual()
	# Refrescar a quien ya esté dentro.
	for b in get_overlapping_bodies():
		if b.is_in_group("player") and "in_updraft" in b:
			b.in_updraft = active


func _refresh_visual() -> void:
	if _mesh:
		_mesh.visible = active
