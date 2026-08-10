extends Area3D

## Zona de interacción reutilizable (NPC, palanca, trigger). Al entrar el Player
## le registra este nodo (muestra el prompt del HUD); al pulsar [T] el Player
## llama interact(), que emite `interacted` para que el dueño reaccione.
## Requiere collision_mask que incluya la capa del jugador (2).

signal interacted(player: Node)

@export var prompt := "[E] Hablar"


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("set_interactable"):
		body.set_interactable(self)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("clear_interactable"):
		body.clear_interactable(self)


func interact(player: Node) -> void:
	interacted.emit(player)
