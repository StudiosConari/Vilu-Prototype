extends Area3D

## Zona de interacción para los NPCs de la Fiesta de La Tirana.
## Funciona igual que Interactable.gd pero incluye lógica de pista propia
## para no depender de closures de captura entre escenas.

signal clue_triggered

const BALLOON := "res://addons/dialogue_manager/example_balloon/example_balloon.tscn"

@export var prompt  := "[E] Hablar"
@export var clue    := ""   # texto que se muestra al interactuar

var _spoken := false


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("set_interactable"):
		body.set_interactable(self)


func _on_exit(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("clear_interactable"):
		body.clear_interactable(self)


func interact(_player: Node) -> void:
	if _spoken or clue == "":
		return
	_spoken = true
	clue_triggered.emit()
	var text := "~ start\nNPC: %s\n=> END\n" % clue
	var res := DialogueManager.create_resource_from_text(text)
	DialogueManager.show_dialogue_balloon_scene(BALLOON, res, "start")
