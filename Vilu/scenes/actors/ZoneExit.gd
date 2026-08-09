extends Area3D

## Salida de zona reutilizable. Al entrar el Player, pide a Game viajar a la
## región destino (con fundido). Opcionalmente requiere un beat mínimo.
## Requiere collision_mask que incluya la capa del jugador (2).

@export var target_region := ""
@export var require_beat := -1   # si >=0, solo activa cuando GameManager.get_beat() >= este
@export var require_abilities: Array = []   # exige tener estas habilidades ("wings","guanaco")
@export var prompt := ""          # si no está vacío, requiere pulsar [T] en vez de auto

var _used := false


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _has_abilities() -> bool:
	for a in require_abilities:
		if not GameManager.has_ability(a):
			return false
	return true


func _can_use() -> bool:
	if _used or target_region == "":
		return false
	if require_beat >= 0 and GameManager.get_beat() < require_beat:
		return false
	return _has_abilities()


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if not _has_abilities():
		_hint_missing()
		return
	if prompt != "":
		if body.has_method("set_interactable"):
			body.set_interactable(self)  # el Player mostrará el prompt y llamará interact()
	else:
		_travel()


func _hint_missing() -> void:
	var falta := []
	for a in require_abilities:
		if not GameManager.has_ability(a):
			falta.append("ALAS" if a == "wings" else ("GUANACO" if a == "guanaco" else a))
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_banner"):
		hud.show_banner("Te falta: %s — consíguelo antes de seguir" % ", ".join(falta))
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			if is_instance_valid(hud) and hud.has_method("clear_banner"):
				hud.clear_banner())


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("clear_interactable"):
		body.clear_interactable(self)


# Llamado por el Player al pulsar [T] (cuando hay prompt).
func interact(_player: Node) -> void:
	_travel()


func _travel() -> void:
	if not _can_use():
		return
	_used = true
	var game := get_tree().get_first_node_in_group("game")
	if game and game.has_method("go_to"):
		game.go_to(target_region)
