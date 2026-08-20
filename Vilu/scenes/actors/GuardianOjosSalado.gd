extends Node3D

## Guardián Ojos del Salado — aparece en la cima de Cumbre (Beat 7).
## CumbreCima.gd lo instancia dinámicamente en _ready().

const BALLOON      := "res://addons/dialogue_manager/example_balloon/example_balloon.tscn"
const INTERACT_SCR := preload("res://scenes/actors/Interactable.gd")
const MAP_SCR      := preload("res://scenes/ui/ChileMapUI.gd")

const FIRST_TALK := "~ start
Guardián: Han alcanzado la cima del Ojos del Salado. Soy su guardián.
Guardián: El volcán Isluga al norte los conoce. Ya pueden viajar entre ambos.
Guardián: El camino entre los volcanes sagrados está abierto para ustedes.
=> END
"
const RETURN_TALK := "~ start
Guardián: El vínculo entre los volcanes permanece. Viajen cuando lo necesiten.
=> END
"

var _met := false


func _ready() -> void:
	_build()


func _build() -> void:
	# Material azul hielo con emisión
	var mat := StandardMaterial3D.new()
	mat.albedo_color           = Color(0.48, 0.76, 0.95)
	mat.emission_enabled       = true
	mat.emission               = Color(0.05, 0.18, 0.38)
	mat.emission_energy_multiplier = 1.6

	# Cuerpo visual
	var mi  := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.6
	mi.mesh = cap
	mi.position.y = 0.8
	mi.set_surface_override_material(0, mat)
	add_child(mi)

	# Texto flotante
	var lbl             := Label3D.new()
	lbl.text             = "Guardián Ojos del Salado"
	lbl.position.y       = 2.5
	lbl.pixel_size       = 0.007
	lbl.billboard        = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate         = Color(0.60, 0.88, 1.0)
	lbl.font_size        = 18
	lbl.outline_size     = 6
	lbl.outline_modulate = Color(0, 0, 0, 1)
	add_child(lbl)

	# Halo de luz azul
	var light          := OmniLight3D.new()
	light.position.y   = 1.0
	light.light_color  = Color(0.55, 0.80, 1.0)
	light.omni_range   = 4.5
	light.light_energy = 1.4
	add_child(light)

	# Zona de interacción
	var zone             := Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask  = 2
	zone.set_script(INTERACT_SCR)
	zone.prompt          = "[E] Hablar con el Guardián"
	add_child(zone)

	var cs  := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.5
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
	DialogueManager.dialogue_ended.connect(_open_map.unbind(1), CONNECT_ONE_SHOT)
	DialogueManager.show_dialogue_balloon_scene(BALLOON, res, "start")


func _open_map() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	get_tree().current_scene.add_child(layer)

	var map: Control = MAP_SCR.new()
	map.current_volcano_idx = 1    # Ojos del Salado = ubicación actual
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(map)
