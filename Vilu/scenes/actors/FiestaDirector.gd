@tool
extends Node3D

## Directora de la Fiesta de La Tirana (Region1_Tarapaca).
## Construye la escena de la fiesta proceduralmente: decorados, NPCs con burbujas,
## pistas y contador de clues para que CarmenNPC decida si revelar su identidad.

const INTERACT_SCRIPT := preload("res://scenes/actors/FestivalNPCInteract.gd")
const PISO_BALDOSAS := preload("res://scenes/core/PisoBaldosas.gd")

# [pos_x, pos_z, burbuja flotante, pista al hablar]
const NPC_DATA: Array = [
	[7.0,  -3.0,
	 "¡Viva La Tirana!",
	 "Vi a una mujer con los ojos brillantes junto al altar. Sonreía como si supiera algo que nosotros no..."],
	[-7.0, -5.0,
	 "¡La danza es sagrada! ♪",
	 "Se dice que La Tirana camina entre nosotros disfrazada en las fiestas. Mira bien a quien te rodea."],
	[5.0, -12.0,
	 "¡Este año vendrá!",
	 "La Tirana lleva poderes que transfiere solo a quienes la reconocen. ¿Ya hablaste con la señora del norte?"],
	[-5.0, -9.0,
	 "¡Aymaraes y fiesta!",
	 "No te fíes de las apariencias en la fiesta. La Tirana es maestra del disfraz y camina entre nosotros."],
	[3.5, -15.0,
	 "¡Que viva el norte! 🎉",
	 ""],
]

## Tildalo después de correr tools/fijar_geometria.gd: el decorado ya quedó
## guardado como nodos dentro del .tscn, así que el script NO debe volver a
## generarlo encima. A partir de ahí lo editás a mano en el editor.
@export var geometria_fijada: bool = false

var clues_given := 0


func _ready() -> void:
	# EN EL EDITOR: sólo la geometría de la fiesta, para verla al trabajar el
	# terreno. No se registra en el grupo ni corre nada más.
	if Engine.is_editor_hint():
		if not geometria_fijada:
			_build_festival()
		return

	add_to_group("fiesta_director")
	if not geometria_fijada:
		_build_festival()


func _build_festival() -> void:
	var gold := _mat(Color(0.85, 0.65, 0.15, 1))
	var red  := _mat(Color(0.72, 0.08, 0.08, 1))

	# ── Suelo de la plaza (reemplaza el terreno plano con un área más visual) ──
	# La plaza de la fiesta es empedrado de baldosas; el suelo base lo pone
	# Terrain3D. Antes era una caja de CSG que se peleaba con el terreno.
	var piso := Node3D.new()
	piso.name = "PisoFiesta"
	piso.set_script(PISO_BALDOSAS)
	add_child(piso)
	piso.plaza(Vector3.ZERO, 40.0, 40.0)
	piso.construir()

	# ── Postes de estandartes ────────────────────────────────────────────────
	for sx in [-5.0, 5.0]:
		_box(Vector3(sx, 3.5, -3.0), Vector3(0.25, 7, 0.25), red)
		_box(Vector3(sx, 7.2, -3.0), Vector3(3.0, 0.3, 0.25), gold)

	# ── Toldos de puestos (izq y der) ────────────────────────────────────────
	_box(Vector3(-11, 1.2, -6), Vector3(4, 0.3, 6), gold)
	_box(Vector3(-11, 0.0, -6), Vector3(0.3, 2.5, 6), red)
	_box(Vector3( 11, 1.2, -6), Vector3(4, 0.3, 6), gold)
	_box(Vector3( 11, 0.0, -6), Vector3(0.3, 2.5, 6), red)

	# ── Altar central (fondo de la plaza) ────────────────────────────────────
	_box(Vector3(0, 0.4, -19), Vector3(6, 0.8, 4), red)
	_box(Vector3(0, 1.3, -19), Vector3(4, 1.8, 0.4), gold)
	_box(Vector3(-2.5, 1.3, -19), Vector3(0.3, 3, 0.3), red)
	_box(Vector3( 2.5, 1.3, -19), Vector3(0.3, 3, 0.3), red)

	# ── NPCs festivos ─────────────────────────────────────────────────────────
	var colors: Array[Color] = [
		Color(0.9, 0.6, 0.2, 1),
		Color(0.5, 0.25, 0.7, 1),
		Color(0.2, 0.55, 0.85, 1),
		Color(0.8, 0.25, 0.2, 1),
		Color(0.3, 0.7, 0.3, 1),
	]
	for i in NPC_DATA.size():
		var d: Array = NPC_DATA[i]
		_spawn_npc(Vector3(d[0], 0.0, d[1]), d[2], d[3], colors[i % colors.size()])


func _spawn_npc(pos: Vector3, bubble: String, clue: String, color: Color) -> void:
	var npc := StaticBody3D.new()
	npc.collision_layer = 1
	npc.collision_mask = 0
	add_child(npc)
	npc.global_position = pos

	# Visual: cápsula de color
	var mat := _mat(color)
	var mesh_i := MeshInstance3D.new()
	var cmesh := CapsuleMesh.new()
	cmesh.radius = 0.35
	cmesh.height = 1.6
	mesh_i.mesh = cmesh
	mesh_i.position.y = 0.8
	mesh_i.set_surface_override_material(0, mat)
	npc.add_child(mesh_i)

	# Colisión del cuerpo
	var cshape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.6
	cshape.shape = cap
	cshape.position.y = 0.8
	npc.add_child(cshape)

	# Burbuja flotante
	var lbl := Label3D.new()
	lbl.text = bubble
	lbl.position = Vector3(0, 2.3, 0)
	lbl.pixel_size = 0.007
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color(1.0, 0.95, 0.55, 1)
	lbl.font_size = 18
	lbl.outline_size = 6
	lbl.outline_modulate = Color(0, 0, 0, 1)
	npc.add_child(lbl)

	if clue == "":
		return  # NPC decorativo sin pista

	# En el EDITOR se previsualiza el paisaje, no la lógica.
	#
	# Este director es @tool para poder ver la fiesta al esculpir el terreno,
	# pero FestivalNPCInteract.gd NO lo es: dentro del editor su script no
	# corre, así que la instancia no expone `clue_triggered` y conectarse a esa
	# señal reventaba con "Invalid access to property or key" una vez por NPC
	# con pista. Un NPC sin su burbuja de diálogo se ve exactamente igual.
	if Engine.is_editor_hint():
		return

	# Zona de interacción con pista
	var area := Area3D.new()
	area.set_script(INTERACT_SCRIPT)
	area.collision_layer = 0
	area.collision_mask = 2
	area.prompt = "[E] Hablar"
	area.clue = clue
	area.clue_triggered.connect(func() -> void: clues_given += 1)
	npc.add_child(area)
	var sshape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.2
	sshape.shape = sphere
	sshape.position.y = 1.0
	area.add_child(sshape)


# ── Helpers de geometría ─────────────────────────────────────────────────────

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var b := CSGBox3D.new()
	b.size = size
	b.position = pos
	b.material_override = mat
	b.use_collision = true
	add_child(b)
