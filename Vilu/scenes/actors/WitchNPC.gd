extends Node3D

## Bruja del talisman — NPC del Poblado.
## Sin fragmento: diálogo genérico.
## Con talisman_frag_1: reconoce el símbolo y pide buscar el resto.
## PobladoHub.gd la instancia dinámicamente en _ready().

const BALLOON      := "res://scenes/ui/GloboDeDialogo.tscn"
const INTERACT_SCR := preload("res://scenes/actors/Interactable.gd")

const TALK_NONE := "~ start
Bruja: Siento una energía oscura por aquí... ¿qué buscan?
=> END
"
## Las preguntas que se le pueden hacer sobre lo que se vio en la mina. Van
## después de entregar el primer fragmento, y también en las visitas de
## después mientras falte el segundo: es cuando esas dudas están frescas.
const PREGUNTAS := "~ preguntas
Bruja: ¿Tienen alguna otra pregunta?
- Vimos a un fantasma en la mina. ¿Tienes alguna información de ella?
	Bruja: ¿Un fantasma en la mina? ¿Cómo era?
	Emilia: Era una mujer muy alta y volaba. Nos gritó cuando nos vio.
	Bruja: Creo que pudo ser La Lola… Es una leyenda minera del norte. Dicen que fue una mujer marcada por una tragedia amorosa y que, después de morir, su espíritu quedó vagando cerca de minas y caminos del desierto.
	Bruja: Algunos aseguran que aparece de noche para atraer o desorientar a los viajeros.
	=> preguntas
- Hay un perro gigante negro en la mina. ¿Qué crees que sea?
	Bruja: Creo que pudo ser el Chupacabras. Es una criatura de la que se cuentan historias en distintos lugares de Chile.
	Bruja: Dicen que aparece de noche cerca de zonas rurales y corrales, atacando animales y dejándolos sin sangre.
	Bruja: Nadie sabe realmente cómo es, porque cada persona que asegura haberlo visto lo describe de manera distinta. Pero muchos dicen que es un canino negro, con cola larga y patas gigantes.
	=> preguntas
- Vimos a unos mineros con los ojos blancos que nos atacaron. ¿Sabes algo de eso?
	Bruja: Esos mineros no siempre fueron así. Desde que aparecieron esos símbolos extraños en las galerías comenzaron a ponerse violentos, desconfiados y obsesionados con el mineral.
	Bruja: Algunos creen que algo los está contaminando. Si logran derrotarlos sin destruir aquello que queda de ellos… puede que vuelvan en sí.
	=> preguntas
- No, gracias.
	=> END
"

const TALK_FRAG := "~ start
Bruja: ¡Ese símbolo... lo conozco!
Bruja: Pero está incompleto. Si encuentran otra parte más, tráiganmela.
Bruja: Quizas este conectado con todo lo que esta pasando.
=> preguntas
" + PREGUNTAS

const TALK_WAIT := "~ start
Bruja: El símbolo aún está incompleto. Busquen el otro fragmento.
=> preguntas
" + PREGUNTAS
const TALK_BOTH := "~ start
Bruja: ¡Las dos piezas! Déjenmelas, déjenmelas...
Bruja: Calzan. Es un sello muy raro, Mezcla muchas cosas, sin duda.
Bruja: Esto es obra de los ocultistas. Ellos corrompieron a los mineros.
Bruja: Ellos soltaron al chupacabras. Ellos mandaron a los cazadores tras el Yastay.
Bruja: Todo lo que vieron hasta ahora, lleva su firma.
Emilia: ¿Y qué es lo que quieren?
Bruja: Creo que estan aqui por los avistamientos de seres miticos. Y les llevan varios pasos de ventaja.
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


## Si el nodo YA trae un modelo —porque el guion se le colgó a la bruja que está
## puesta en la escena— no se le dibuja la cápsula ni el sombrero cónico encima.
##
## Lo que se le cuelga se divide por su escala: la bruja del mundo está a 1.33, y
## sin descontarla el cartel y la zona de conversación se irían de tamaño.
func _build() -> void:
	var f := global_transform.basis.get_scale()
	var k: float = 1.0 / maxf(f.y, 0.001)
	var tiene_modelo := _primera_malla(self) != null

	var mat := StandardMaterial3D.new()
	mat.albedo_color           = Color(0.32, 0.08, 0.50)
	mat.emission_enabled       = true
	mat.emission               = Color(0.12, 0.02, 0.24)
	mat.emission_energy_multiplier = 1.4

	if not tiene_modelo:
		var mi  := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.35
		cap.height = 1.7
		mi.mesh    = cap
		mi.position.y = 0.85
		mi.set_surface_override_material(0, mat)
		add_child(mi)

	# Sombrero cónico del greybox: sólo si no hay modelo, que ya trae el suyo.
	if not tiene_modelo:
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
	lbl.position.y       = 2.7 * k
	lbl.pixel_size       = 0.007
	lbl.billboard        = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate         = Color(0.75, 0.45, 1.0)
	lbl.font_size        = 18
	lbl.outline_size     = 6
	lbl.outline_modulate = Color(0, 0, 0, 1)
	add_child(lbl)

	var light          := OmniLight3D.new()
	light.position.y   = 1.0 * k
	light.light_color  = Color(0.65, 0.30, 1.0)
	light.omni_range   = 4.0 * k
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
	sph.radius = 2.5 * k
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


func _primera_malla(n: Node) -> MeshInstance3D:
	for h in n.get_children():
		if h is MeshInstance3D:
			return h
		var hondo := _primera_malla(h)
		if hondo != null:
			return hondo
	return null
