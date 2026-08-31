extends Node3D

## Bruja del talisman — NPC del Poblado.
## Sin fragmento: diálogo genérico.
## Con talisman_frag_1: reconoce el símbolo y pide buscar el resto.
## PobladoHub.gd la instancia dinámicamente en _ready().

const BALLOON      := "res://addons/dialogue_manager/example_balloon/example_balloon.tscn"
const INTERACT_SCR := preload("res://scenes/actors/Interactable.gd")

const TALK_NONE := "~ start
Bruja: Siento una energía oscura por aquí... ¿qué buscan?
=> END
"
const TALK_FRAG := "~ start
Bruja: ¡Ese símbolo... lo conozco!
Bruja: Pero está incompleto. Si encuentran otra parte más, tráiganmela.
=> END
"
const TALK_WAIT := "~ start
Bruja: El símbolo aún está incompleto. Busquen el otro fragmento.
=> END
"
const TALK_BOTH := "~ start
Bruja: ¡Las dos piezas! Déjenmelas, déjenmelas...
Bruja: Calzan. Es el sello de Vilu, y no lo partió ningún animal.
Bruja: Esto es obra de los ocultistas. Ellos corrompieron a los mineros.
Bruja: Ellos soltaron al chupacabras. Ellos mandaron a los cazadores tras el Yastay.
Bruja: Todo lo que vieron desde La Tirana hasta la cumbre lleva su firma.
Emilia: ¿Y qué es lo que quieren?
Bruja: El poder de los volcanes. Y les llevan varios pasos de ventaja.
=> END
"
const TALK_DONE := "~ start
Bruja: El talismán ya está entero. La cumbre los espera.
=> END
"

## Se emite cuando une las dos piezas y nombra a los ocultistas.
## El Poblado lo usa para sacar al espía que estaba escuchando.
signal revealed_ocultists

var _met_with_frag := false
var _met_complete  := false


func _ready() -> void:
	_build()


func _build() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color           = Color(0.32, 0.08, 0.50)
	mat.emission_enabled       = true
	mat.emission               = Color(0.12, 0.02, 0.24)
	mat.emission_energy_multiplier = 1.4

	var mi  := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.7
	mi.mesh    = cap
	mi.position.y = 0.85
	mi.set_surface_override_material(0, mat)
	add_child(mi)

	# Sombrero cónico (cono invertido aplastado)
	var hat_mat := StandardMaterial3D.new()
	hat_mat.albedo_color = Color(0.10, 0.04, 0.18)
	var hat_mi  := MeshInstance3D.new()
	var cone    := CylinderMesh.new()
	cone.top_radius    = 0.0
	cone.bottom_radius = 0.38
	cone.height        = 0.60
	hat_mi.mesh        = cone
	hat_mi.position.y  = 2.05
	hat_mi.set_surface_override_material(0, hat_mat)
	add_child(hat_mi)

	var lbl             := Label3D.new()
	lbl.text             = "Bruja"
	lbl.position.y       = 2.7
	lbl.pixel_size       = 0.007
	lbl.billboard        = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate         = Color(0.75, 0.45, 1.0)
	lbl.font_size        = 18
	lbl.outline_size     = 6
	lbl.outline_modulate = Color(0, 0, 0, 1)
	add_child(lbl)

	var light          := OmniLight3D.new()
	light.position.y   = 1.0
	light.light_color  = Color(0.65, 0.30, 1.0)
	light.omni_range   = 4.0
	light.light_energy = 1.2
	add_child(light)

	var zone             := Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask  = 2
	zone.set_script(INTERACT_SCR)
	zone.prompt          = "[E] Hablar con la Bruja"
	add_child(zone)

	var cs  := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.5
	cs.shape   = sph
	zone.add_child(cs)

	zone.interacted.connect(_on_interacted)


func _on_interacted(_player: Node) -> void:
	var f1 := GameManager.has_ability("talisman_frag_1")
	var f2 := GameManager.has_ability("talisman_frag_2")
	if f1 and f2:
		if not _met_complete:
			_met_complete = true
			# Si llega con los dos de una, cuenta también la primera entrega:
			# el logro es "llevarle el fragmento", no "hacer dos viajes".
			GameManager.conceder("talisman_1")
			GameManager.conceder("talisman_2")
			_met_with_frag = true
			revealed_ocultists.emit()
			_show(TALK_BOTH)
		else:
			_show(TALK_DONE)
	elif not f1:
		_show(TALK_NONE)
	elif not _met_with_frag:
		_met_with_frag = true
		GameManager.conceder("talisman_1")
		_show(TALK_FRAG)
	else:
		_show(TALK_WAIT)


func _show(text: String) -> void:
	var res := DialogueManager.create_resource_from_text(text)
	DialogueManager.show_dialogue_balloon_scene(BALLOON, res, "start")
