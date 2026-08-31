extends CharacterBody3D

## NPC Carmen — en realidad La Tirana.
##
## Flujo:
##  1. Primera charla (clues < 4, no caminó): Fase 1 → dice que espera junto al altar
##     → al terminar el diálogo CAMINA hasta Z≈-17 (frente al altar).
##  2. Mientras clues < 4: diálogo corto de espera.
##  3. clues >= 4: Revelación → desbloquea bow + beat 2.
##  4. Habilidad ya dada: despedida corta.

const BALLOON := "res://addons/dialogue_manager/example_balloon/example_balloon.tscn"

const DIALOGUE_FASE1 := "~ start
Carmen: ¡Bienvenidos a la Fiesta de La Tirana! Una celebración sagrada del norte.
Carmen: Hablen con la gente del pueblo, guardan secretos de la fiesta.
Carmen: Yo los espero junto al altar.
=> END
"

const DIALOGUE_WAIT := "~ start
Carmen: Sigan explorando la fiesta. Aún hay más que descubrir.
=> END
"

const DIALOGUE_REVELACION := "~ start
Carmen: Veo que ya saben quién soy. Está bien... Soy La Tirana.
Carmen: Aquí está tu don, guerrera. Emilia: COMBO de cuatro golpes. Benjamín: FLECHA TRIPLE (tecla F, gasta energía).
Carmen: Cambien de héroe con R (el otro pelea solo) o con T (se queda quieto, para puzzles).
Carmen: El paso del norte los espera. La mina guarda algo oscuro...
=> END
"

const DIALOGUE_AGAIN := "~ start
Carmen: Ya tienen su don. La mina los espera al norte.
=> END
"

var _has_walked     := false
var _pending_walk   := false
var _pending_unlock := false
var _walk_target    := Vector3.ZERO
var _walking        := false


func _ready() -> void:
	$Interact.interacted.connect(_on_interacted)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)


func _physics_process(delta: float) -> void:
	if not _walking:
		return  # estática: sin física necesaria

	# Gravedad solo mientras camina
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0

	var to := _walk_target - global_position
	to.y = 0.0
	if to.length() < 0.4:
		_walking = false
		velocity = Vector3.ZERO
		return

	var dir := to.normalized()
	velocity.x = dir.x * 3.5
	velocity.z = dir.z * 3.5
	move_and_slide()

	var vis := get_node_or_null("Visual")
	if vis:
		vis.rotation.y = lerp_angle(vis.rotation.y, atan2(-dir.x, -dir.z), 8.0 * delta)


func _on_interacted(_player: Node) -> void:
	if _walking:
		return  # no interrumpir mientras camina hacia el altar

	# Primera interacción: siempre caminará al altar tras el diálogo,
	# sin importar si las habilidades ya fueron dadas (por debug, etc.).
	if not _has_walked:
		_pending_walk = true
		_show(DIALOGUE_FASE1)
		return

	var director := get_tree().get_first_node_in_group("fiesta_director")
	var clues: int = director.clues_given if director else 0

	if GameManager.has_ability("bow"):
		_show(DIALOGUE_AGAIN)
	elif clues >= 4:
		_pending_unlock = true
		_show(DIALOGUE_REVELACION)
	else:
		_show(DIALOGUE_WAIT)


func _on_dialogue_ended(_res: Resource) -> void:
	if _pending_walk:
		_pending_walk = false
		_has_walked = true
		_walk_target = global_position + Vector3(0.0, 0.0, -19.0)
		_walking = true
	elif _pending_unlock:
		_pending_unlock = false
		GameManager.unlock("bow")
		if GameManager.get_beat() < 2:
			GameManager.set_beat(2)
		GameManager.conceder("tirana")


func _show(text: String) -> void:
	var res := DialogueManager.create_resource_from_text(text)
	DialogueManager.show_dialogue_balloon_scene(BALLOON, res, "start")
