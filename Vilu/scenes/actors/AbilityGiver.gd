extends CharacterBody3D

## Criatura que otorga una habilidad al interactuar (Beat 6):
##  alicanto -> "wings" (alas/planeo),  yastay -> "guanaco" (montura).
## Reusa Interactable + GameManager.unlock. La habilidad es un ESTADO del Player.

@export var ability := "wings"          # "wings" | "guanaco"
@export var creature_name := "Alicanto"


func _ready() -> void:
	var inter := get_node_or_null("Interact")
	if inter and inter.has_signal("interacted"):
		inter.interacted.connect(_on_interacted)


func _on_interacted(_player: Node) -> void:
	if GameManager.has_ability(ability):
		_banner("%s: ya llevas este don." % creature_name)
		return
	GameManager.unlock(ability)
	_banner("%s te otorga %s" % [creature_name, _label()])


func _label() -> String:
	if ability == "wings":
		return "ALAS — planea manteniendo Espacio al caer"
	return "GUANACO — monta/desmonta con Q"


func _banner(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_banner"):
		hud.show_banner(text)
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			if is_instance_valid(hud) and hud.has_method("clear_banner"):
				hud.clear_banner())
