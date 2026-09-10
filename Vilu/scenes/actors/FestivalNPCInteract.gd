extends Area3D

const IDIOMA := preload("res://scenes/core/Idioma.gd")

## Zona de interacción para los NPCs de la Fiesta de La Tirana.
## Funciona igual que Interactable.gd pero incluye lógica de pista propia
## para no depender de closures de captura entre escenas.

signal clue_triggered

const BALLOON := "res://scenes/ui/GloboDeDialogo.tscn"

@export var prompt  := "[E] Hablar"
## Lo que dice al hablarle: una frase, o una conversación entera con una
## réplica por línea («Quién: qué»). Las líneas sin quién las dice el NPC.
@export var clue    := ""

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
	var res := DialogueManager.create_resource_from_text(IDIOMA.guion(guion_de(clue)))
	DialogueManager.show_dialogue_balloon_scene(BALLOON, res, "start")


## El guion del Dialogue Manager para lo que dice: cada línea es una réplica.
static func guion_de(texto: String) -> String:
	var lineas: PackedStringArray = []
	for l in texto.split("\n"):
		var t := l.strip_edges()
		if t == "":
			continue
		# «Quién: qué» ya viene con quién habla; si no, habla el NPC.
		if not t.match("*: *"):
			t = "NPC: " + t
		lineas.append(t)
	return "~ start\n" + "\n".join(lineas) + "\n=> END\n"
