extends Node3D

## Guardián del Isluga — NPC en la plataforma superior que muestra el mapa de Chile.
## PuzzleIsluga.gd lo instancia dinámicamente en _ready().

const BALLOON       := "res://addons/dialogue_manager/example_balloon/example_balloon.tscn"
const INTERACT_SCR  := preload("res://scenes/actors/Interactable.gd")
const MAP_SCR       := preload("res://scenes/ui/ChileMapUI.gd")
const MODELO        := preload("res://models/personaje/guardian_del_isluga.glb")
const ENCAJAR       := preload("res://scenes/core/EncajarModelo.gd")

## Alto del guardián en metros. El glb mide 2.20 m de fábrica; 4.09 es el
## tamaño con el que ya estaba puesto a mano en la escena del Isluga.
const ALTO          := 4.09

const FIRST_TALK := "~ start
Guardián: Bienvenidos al volcán Isluga. Soy su guardián.
Guardián: Han cruzado el norte de Chile. El camino al sur les espera.
Guardián: Pueden consultar el mapa de los volcanes sagrados.
=> END
"
const RETURN_TALK := "~ start
Guardián: El mapa los guía. Viajen a donde el fuego los llame.
=> END
"

var _met := false


func _ready() -> void:
	_build()


func _build() -> void:
	# Cuerpo visual: el modelo, apoyado en el suelo y escalado al alto de arriba.
	var raiz: Node3D = MODELO.instantiate()
	add_child(raiz)
	ENCAJAR.encajar(raiz, ALTO)

	# Texto flotante
	var lbl          := Label3D.new()
	lbl.text          = "Guardián del Isluga"
	lbl.position.y    = ALTO + 0.5
	lbl.pixel_size    = 0.007
	lbl.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate      = Color(0.95, 0.83, 0.28)
	lbl.font_size     = 18
	lbl.outline_size  = 6
	lbl.outline_modulate = Color(0, 0, 0, 1)
	add_child(lbl)

	# Zona de interacción (Interactable.gd maneja body_entered/exited)
	var zone                  := Area3D.new()
	zone.collision_layer      = 0
	zone.collision_mask       = 2      # layer jugadores
	zone.set_script(INTERACT_SCR)
	zone.prompt               = "[E] Hablar con el Guardián"
	add_child(zone)

	var cs  := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 3.2
	cs.shape = sph
	zone.add_child(cs)

	zone.interacted.connect(_on_interacted)


func _on_interacted(_player: Node) -> void:
	if not _met:
		_met = true
		_show_dialogue(FIRST_TALK)
	else:
		_show_dialogue(RETURN_TALK)


func _show_dialogue(text: String) -> void:
	var res := DialogueManager.create_resource_from_text(text)
	# CONNECT_ONE_SHOT: abre el mapa solo cuando ESTE diálogo termina
	DialogueManager.dialogue_ended.connect(_open_map.unbind(1), CONNECT_ONE_SHOT)
	DialogueManager.dialogue_ended.connect(_abrir_salida.unbind(1), CONNECT_ONE_SHOT)
	DialogueManager.show_dialogue_balloon_scene(BALLOON, res, "start")


## Levanta el camino de salida del cráter al terminar la charla.
##
## Se busca por grupo y no por ruta: al guardián lo instancia PuzzleIsluga
## dentro de la escena del puzzle y el camino cuelga de World.tscn, así que no
## hay una ruta relativa estable entre los dos.
##
## Repetir la charla no hace nada: `activar()` sólo actúa la primera vez.
func _abrir_salida() -> void:
	# El propio guardián cierra el desafío: lo instancia PuzzleIsluga como hijo
	# suyo, así que el padre es el puzzle.
	var puzzle := get_parent()
	if puzzle and puzzle.has_method("superar"):
		puzzle.superar()
	var camino := get_tree().get_first_node_in_group("camino_salida")
	if camino == null:
		push_warning("Guardián del Isluga: no encuentro el camino de salida")
		return
	if camino.has_method("activar"):
		camino.activar()


func _open_map() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	get_tree().current_scene.add_child(layer)

	var map: Control = MAP_SCR.new()
	map.current_volcano_idx = 0    # Isluga = ubicación actual
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(map)
