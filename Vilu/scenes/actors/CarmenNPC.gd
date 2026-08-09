extends CharacterBody3D

## NPC Carmen (La Tirana). Al interactuar abre un diálogo (dialogue_manager,
## recurso creado en runtime — sin dependencia de import). Al terminarlo la
## primera vez, desbloquea el combate (has_bow) vía GameManager y entra al Beat 2.
## Se fuerza el balloon GDScript para no depender del assembly .NET.

const BALLOON := "res://addons/dialogue_manager/example_balloon/example_balloon.tscn"

const DIALOGUE_INTRO := "~ start
Carmen: Bienvenida, VILU. El norte te necesita.
Carmen: Toma este arco. Con él dispararás flechas y encadenarás golpes.
Carmen: Clic izquierdo encadena el combo; clic derecho dispara. Ve al paso del norte.
=> END
"

const DIALOGUE_AGAIN := "~ start
Carmen: Ya llevas el arco. El paso del norte te espera.
=> END
"

var _pending_unlock := false


func _ready() -> void:
	$Interact.interacted.connect(_on_interacted)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)


func _on_interacted(_player: Node) -> void:
	var already := GameManager.has_ability("bow")
	_pending_unlock = not already
	var text := DIALOGUE_AGAIN if already else DIALOGUE_INTRO
	var res: Resource = DialogueManager.create_resource_from_text(text)
	DialogueManager.show_dialogue_balloon_scene(BALLOON, res, "start")


func _on_dialogue_ended(_res: Resource) -> void:
	if _pending_unlock:
		_pending_unlock = false
		GameManager.unlock("bow")
		if GameManager.get_beat() < 1:
			GameManager.set_beat(1)
