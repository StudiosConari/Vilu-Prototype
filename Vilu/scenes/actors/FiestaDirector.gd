@tool
extends Node3D

## Directora de la Fiesta de La Tirana (Tarapaca).
## Construye la escena de la fiesta proceduralmente: decorados, NPCs con burbujas,
## pistas y contador de clues para que CarmenNPC decida si revelar su identidad.

const INTERACT_SCRIPT := preload("res://scenes/actors/FestivalNPCInteract.gd")
const PISO_BALDOSAS := preload("res://scenes/core/PisoBaldosas.gd")

# [pos_x, pos_z, burbuja flotante, lo que dice al hablarle]
#
# Lo que dice puede ser una sola frase o una conversación entera: una réplica
# por línea, «Quién: qué», y el que no lleve quién habla es el NPC. Salen del
# documento de diálogos del estudio.
const NPC_DATA: Array = [
	[7.0,  -3.0,
	 "¡Viva La Tirana!",
	 "NPC: ¿Primera vez en La Tirana? Entonces fíjense bien en los bailes. Aquí no se viene solo a bailar por bailar. Muchas agrupaciones llevan años participando y cada danza es una forma de agradecer, cumplir una promesa o demostrar su devoción a la Virgen del Carmen.\nEmilia: Entonces todo ese esfuerzo… ¿también es parte de la ofrenda?\nNPC: Exactamente. Por eso verán trajes, máscaras y coreografías muy distintas entre una agrupación y otra.\nBenjamín: Se nota que algunos llevan muchísimo tiempo preparando esto.\nNPC: Y hablando de cosas que llaman la atención… corre un rumor bastante extraño este año. Dicen que La Tirana está caminando entre la gente.\nEmilia: ¿La Tirana? ¿La de la leyenda?\nNPC: Eso dicen. No sé si creerlo, pero escuché que quienes aseguran haberla visto coinciden en algo: tiene el pelo castaño."],
	[-7.0, -5.0,
	 "¡La danza es sagrada! ♪",
	 "NPC: Toda esta fiesta gira alrededor de la Virgen del Carmen. Hay personas que llegan desde muy lejos para agradecerle, pedir su protección o cumplir una manda que hicieron hace años.\nBenjamín: ¿Una manda?\nNPC: Una promesa. Algunos peregrinan, otros bailan durante años con una agrupación y otros vienen cada julio sin falta. Para muchas familias, regresar a La Tirana es una tradición que pasa de generación en generación.\nEmilia: Ahora entiendo por qué viene tanta gente.\nNPC: Sí… aunque este año todos hablan de algo más que de la fiesta.\nBenjamín: ¿También escuchó el rumor?\nNPC: Claro. Dicen que La Tirana apareció entre los peregrinos. Una conocida jura que la vio pasar esta mañana.\nEmilia: ¿Y cómo era?\nNPC: Solo alcanzó a decirme una cosa: era una mujer alta."],
	[5.0, -12.0,
	 "¡Este año vendrá!",
	 "NPC: Si quieren encontrar el corazón de la fiesta, sigan el sonido. Trompetas, trombones, bombos, cajas, platillos… las bandas acompañan a los bailes prácticamente durante toda la celebración.\nBenjamín: Debe ser agotador tocar durante tantas horas.\nNPC: Lo es. Pero cuando una agrupación entra bailando y toda la calle comienza a vibrar con los bombos, se te olvida el cansancio.\nEmilia: Con tanta música cuesta hasta saber de dónde viene cada cosa.\nNPC: Entonces quizás tampoco escucharon el comentario que está corriendo entre los músicos.\nBenjamín: Déjame adivinar… La Tirana.\nNPC: Así es. Hay quienes dicen que vino a su propia fiesta escondida entre los bailarines.\nEmilia: ¿Alguien logró reconocerla?\nNPC: No exactamente. Pero yo les digo algo: nunca había visto un traje tan bien hecho como el de la mujer que estaba bailando en el centro de la plaza. Si están buscando a alguien extraño… yo empezaría por ahí."],
	[-5.0, -9.0,
	 "¡Aymaraes y fiesta!",
	 "NPC: Este pueblo guarda historias mucho más antiguas que cualquiera de nosotros. Hasta su nombre está ligado a la leyenda de una mujer a la que llamaron La Tirana del Tamarugal.\nEmilia: La princesa que vivía escondida en estas tierras…\nNPC: Eso cuenta la tradición. Con los años, historia, religión y leyenda terminaron mezclándose aquí. Por eso durante estas fechas nunca faltan cuentos sobre cosas que aparecen en el desierto.\nBenjamín: Y este año parece que hay uno bastante específico.\nNPC: Je… así que también lo escucharon.\nEmilia: Dicen que La Tirana está aquí.\nNPC: Algunos incluso aseguran haber hablado con ella sin darse cuenta.\nBenjamín: ¿Hay alguna forma de reconocerla?\nNPC: Hay una última cosa que se repite en todas las historias. Dicen que La Tirana tiene los ojos de un color muy especial.\nEmilia: ¿Qué color?\nNPC: Eso tendrán que descubrirlo ustedes."],
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
	if geometria_fijada:
		# La geometría ya está en la escena, pero la interacción nunca se
		# guardó: hay que volver a colgarla. Ver _reponer_interaccion.
		_reponer_interaccion()
	else:
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

	_colgar_interaccion(npc, clue)


## Le cuelga a un NPC su zona de "[E] Hablar".
func _colgar_interaccion(npc: Node3D, clue: String) -> void:
	var area := Area3D.new()
	area.name = "Interaccion"
	area.set_script(INTERACT_SCRIPT)
	area.collision_layer = 0
	area.collision_mask = 2
	area.prompt = "[E] Hablar"
	area.clue = clue
	# La guía de objetivos le pone un marcador a cada vecino que falte por
	# hablar, y se lo quita en cuanto habló. Sin esto, «habla con las 4 personas
	# del pueblo» obliga a recorrer la fiesta preguntando a todo el mundo dos
	# veces para saber a quién ya le hablaste.
	npc.add_to_group("objetivo_pistas")
	area.clue_triggered.connect(func() -> void:
		clues_given += 1
		npc.remove_from_group("objetivo_pistas")
		Misiones.hecho("pistas"))
	npc.add_child(area)
	var sshape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.2
	sshape.shape = sphere
	sshape.position.y = 1.0
	area.add_child(sshape)


## Devuelve las zonas de "[E] Hablar" a los NPC ya guardados en World.tscn.
##
## Al fijar la geometría quedaron dentro de la escena los cuerpos, su colisión y
## su cartel, pero las zonas de interacción NO: se crean sólo en ejecución —el
## `return` de arriba las salta en el editor—, así que cuando se fijó no había
## ninguna que guardar. Los cuatro NPC con pista quedaron mudos y `clues_given`
## no subía nunca, que es justo lo que mira Carmen para decidir qué te cuenta.
##
## Se emparejan POR EL TEXTO DE SU CARTEL, no por posición ni por orden. Los
## nodos guardados llevan nombres autogenerados, y dos de ellos ya fueron
## movidos a mano varios metros respecto de NPC_DATA: emparejar por cercanía le
## habría dado la pista equivocada a alguno.
func _reponer_interaccion() -> void:
	for d in NPC_DATA:
		var clue: String = d[3]
		if clue == "":
			continue
		var cuerpo := _cuerpo_con_cartel(d[2])
		if cuerpo == null:
			push_warning("FiestaDirector: no hay NPC con el cartel '%s'" % d[2])
			continue
		if cuerpo.has_node("Interaccion"):
			continue
		_colgar_interaccion(cuerpo, clue)


func _cuerpo_con_cartel(texto: String) -> Node3D:
	for c in get_children():
		if not (c is StaticBody3D):
			continue
		for h in c.get_children():
			if h is Label3D and (h as Label3D).text == texto:
				return c
	return null


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
