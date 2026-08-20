extends Area3D

## Fragmento de talisman — panel blanco flotante, se recoge al acercarse.
## Guarda "talisman_frag_1" en GameManager.

@export var fragment_id  := "talisman_frag_1"
@export var pickup_label := "Fragmento de talisman encontrado"

var _t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask  = 2
	monitoring      = true
	body_entered.connect(_on_body_entered)
	_build_visual()


func _process(delta: float) -> void:
	_t += delta
	# Levita suavemente (solo offset local en Y, relativo al nodo)
	position.y = _start_y + sin(_t * 1.8) * 0.12
	# Gira sobre su eje
	rotation.y += delta * 0.75


var _start_y := 0.0

func _build_visual() -> void:
	_start_y = position.y

	# Panel blanco-crema — misma orientación que los cuadros rojos de la pared
	# pero flotando en el centro: fino en X, tamaño reducido
	var mat := StandardMaterial3D.new()
	mat.albedo_color           = Color(0.95, 0.91, 0.78)
	mat.emission_enabled       = true
	mat.emission               = Color(0.22, 0.18, 0.08)
	mat.emission_energy_multiplier = 1.6

	var mi  := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.06, 0.42, 0.30)   # panel plano, mismo estilo que paneles rojos
	mi.mesh  = box
	mi.set_surface_override_material(0, mat)
	add_child(mi)

	# Halo blanco suave
	var light          := OmniLight3D.new()
	light.light_color  = Color(1.0, 0.95, 0.75)
	light.omni_range   = 2.2
	light.light_energy = 0.85
	add_child(light)

	# Collider de pickup
	var cs  := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.2
	cs.shape   = sph
	add_child(cs)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if GameManager.has_ability(fragment_id):
		return
	GameManager.unlock(fragment_id)
	_banner(pickup_label)
	queue_free()


func _banner(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_banner"):
		hud.show_banner(text)
