extends Area3D

## Corriente de viento ascendente. Mientras un personaje con ALAS (Emilia) esté
## dentro y esté planeando (mantiene Espacio), sube (lo aplica PlayerController
## leyendo in_updraft). Requiere collision_mask con la capa del jugador (2).

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node3D) -> void:
	if body.is_in_group("player") and "in_updraft" in body:
		body.in_updraft = true


func _on_exit(body: Node3D) -> void:
	if body.is_in_group("player") and "in_updraft" in body:
		body.in_updraft = false
