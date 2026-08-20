extends Node3D

## Poblado del altiplano — HUB narrativo. Se visita TRES veces y cambia según
## el progreso:
##
##   ETAPA 1 (traés el 1er talismán, aún sin alas)
##     · La Bruja lee el símbolo y te manda al Isluga.
##   ETAPA 2 (ya tenés las ALAS del Alicanto)
##     · En el bar hablan del Yastay: unos cazadores lo están provocando para
##       atraparlo en la pampa alta. Al escucharlos se abre el camino al rebaño.
##   ETAPA 3 (traés el 2do talismán)
##     · La Bruja une las piezas y revela a los ocultistas. Al salir del diálogo
##       descubrís que uno estaba escuchando junto al bar, y se escapa.

const WITCH_SCR    := preload("res://scenes/actors/WitchNPC.gd")
const INTERACT_SCR := preload("res://scenes/actors/Interactable.gd")
const EXIT_SCENE   := preload("res://scenes/actors/ZoneExit.tscn")
const BALLOON      := "res://addons/dialogue_manager/example_balloon/example_balloon.tscn"

const TALK_BAR_1 := "~ start
Parroquiano: Salud. Acá no se habla de la mina, ¿estamos?
Parroquiano: Lo que sea que hayan visto abajo, déjenlo abajo.
=> END
"

const TALK_BAR_2 := "~ start
Parroquiano: ...y yo te digo que están locos. Nadie provoca al Yastay y vive para contarlo.
Emilia: Perdón. ¿Quién está provocando al Yastay?
Parroquiano: Cazadores. Bajaron de la cordillera hace una semana.
Parroquiano: Le están carneando los guanacos de a uno para sacarlo de la quebrada.
Parroquiano: Lo quieren en la pampa alta, donde no tenga dónde esconderse. Ahí lo atrapan.
Benjamín: ¿Y nadie hace nada?
Parroquiano: ¿Vos irías? Si se animan, es camino al norte. Que la Tirana los acompañe.
=> END
"

const TALK_BAR_3 := "~ start
Parroquiano: Desde que volvieron de los volcanes la gente anda rara.
Parroquiano: Como si siempre hubiera alguien escuchando de más.
=> END
"

const TALK_OCULTISTA := "~ start
Benjamín: Emilia. Junto al bar.
Emilia: Ese estuvo ahí todo el rato. Escuchando cada palabra.
Emilia: ¡Eh! ¡Vos!
Benjamín: Se fue. Corre como si conociera cada callejón del pueblo.
Emilia: Entonces la bruja tiene razón. No estamos persiguiendo a un monstruo.
Emilia: Estamos persiguiendo a gente.
=> END
"

var _stage := 1
var _bar_done := false
var _ocultista: Node3D = null
var _exit: Node = null


func _ready() -> void:
	_stage = _current_stage()
	_build_town()
	_spawn_witch()
	_spawn_bar_folk()
	_setup_exit()
	# MUNDO ABIERTO: el pueblo ya no se recarga en cada visita, así que la etapa
	# tiene que recalcularse cuando cambia el progreso, no una sola vez.
	GameManager.ability_unlocked.connect(_on_progreso.unbind(1))


## WorldRoot llama a esto cuando el jugador entra al pueblo.
func activate() -> void:
	_refrescar_etapa()
	_intro_hint()


func deactivate() -> void:
	pass


func _on_progreso() -> void:
	_refrescar_etapa()


## Recalcula la etapa y actualiza lo que depende de ella (destino de la salida
## y visibilidad del espía). No re-construye el pueblo: la geometría es fija.
func _refrescar_etapa() -> void:
	var nueva := _current_stage()
	if nueva == _stage:
		return
	_stage = nueva
	_bar_done = false
	_setup_exit()


## 1 = primera visita (bruja lee el símbolo), 2 = bar habla del Yastay,
## 3 = regreso con las dos piezas.
func _current_stage() -> int:
	if GameManager.has_ability("talisman_frag_2"):
		return 3
	if GameManager.has_ability("wings"):
		return 2
	return 1


func _intro_hint() -> void:
	match _stage:
		1: _hint("Poblado. Mostrale el talismán a la Bruja (casa del oeste). El camino al norte sube al Isluga.")
		2: _hint("Poblado. En el bar están hablando de algo. Acercate a escuchar.")
		3: _hint("Poblado. Llevale la segunda pieza a la Bruja.")


# ─── Salida (cambia de destino según la etapa) ───────────────────────────────

## MUNDO ABIERTO: al Isluga y a la quebrada del Yastay se llega CAMINANDO por
## los caminos, así que esas salidas ya no existen. La única que queda es la del
## Final, que sí es un interior y sólo se abre cuando el ocultista huye.
func _setup_exit() -> void:
	if is_instance_valid(_exit):
		_exit.queue_free()
		_exit = null
	if _stage != 3:
		return
	_exit = EXIT_SCENE.instantiate()
	add_child(_exit)
	_exit.position = Vector3(0, 2, -21)
	_exit.target_region = "Final"
	_exit.prompt = "[E] Seguir al ocultista"
	_exit.monitoring = false   # se abre en _ocultista_flees()


func _open_exit() -> void:
	if _exit and is_instance_valid(_exit):
		_exit.set_deferred("monitoring", true)


# ─── Bruja ───────────────────────────────────────────────────────────────────

func _spawn_witch() -> void:
	var w := Node3D.new()
	w.set_script(WITCH_SCR)
	w.position = Vector3(-10.0, 0.0, -3.0)
	add_child(w)
	if w.has_signal("revealed_ocultists"):
		w.revealed_ocultists.connect(_on_ocultists_revealed)


## La bruja terminó de unir las dos piezas: sale el ocultista que espiaba.
func _on_ocultists_revealed() -> void:
	DialogueManager.dialogue_ended.connect(_reveal_ocultista.unbind(1), CONNECT_ONE_SHOT)


func _reveal_ocultista() -> void:
	if not is_instance_valid(_ocultista):
		return
	_ocultista.visible = true
	_banner("Alguien estaba escuchando junto al bar.", 4.0)
	DialogueManager.dialogue_ended.connect(_ocultista_flees.unbind(1), CONNECT_ONE_SHOT)
	_show(TALK_OCULTISTA)


func _ocultista_flees() -> void:
	if not is_instance_valid(_ocultista):
		_after_flee()
		return

	var lbl := _ocultista.get_node_or_null("Label3D") as Label3D
	if lbl:
		lbl.text = "¡El ocultista huye!"

	# La cámara lo sigue para que se vea la huida
	var game := get_tree().get_first_node_in_group("game")
	if game and game.has_method("focus_camera_on"):
		game.focus_camera_on(_ocultista, 4.0)

	# Corre en dos tramos: rodea el bar y sale por el portón norte
	var tw := get_tree().create_tween()
	tw.tween_property(_ocultista, "position", Vector3(9.0, 0.0, -12.0), 1.1)
	tw.tween_property(_ocultista, "position", Vector3(1.5, 0.0, -26.0), 1.5)
	tw.tween_callback(_end_flee)


func _end_flee() -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game and game.has_method("clear_camera_focus"):
		game.clear_camera_focus()
	if is_instance_valid(_ocultista):
		_ocultista.queue_free()
	_after_flee()


func _after_flee() -> void:
	_hint("El ocultista huyó hacia el norte. Seguilo.")
	_open_exit()


# ─── Bar ─────────────────────────────────────────────────────────────────────

func _spawn_bar_folk() -> void:
	var folk_mat := _mat(Color(0.38, 0.30, 0.24))
	# Tres parroquianos en la barra
	_npc(Vector3( 8.5, 0, -5.0), folk_mat, 1.0, "")
	_npc(Vector3(11.5, 0, -5.0), folk_mat, 1.0, "")

	var talker := _npc(Vector3(10.0, 0, -3.0), _mat(Color(0.46, 0.34, 0.22)), 1.0,
		"Parroquiano")
	var zone             := Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask  = 2
	zone.set_script(INTERACT_SCR)
	zone.prompt          = "[E] Escuchar la conversación"
	talker.add_child(zone)

	var cs  := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.8
	cs.shape   = sph
	zone.add_child(cs)
	zone.interacted.connect(_on_bar_talk)

	# El ocultista espía junto al bar. Se crea SIEMPRE (oculto) porque el pueblo
	# ya no se reconstruye al llegar a la etapa 3: si dependiera de _stage en
	# _ready(), empezando la partida en la etapa 1 no existiría nunca.
	_ocultista = _npc(Vector3(15.0, 0, -1.0), _mat(Color(0.09, 0.07, 0.13)), 1.05, "???")
	_ocultista.visible = false


func _on_bar_talk(_player: Node) -> void:
	match _stage:
		2:
			if _bar_done:
				_hint("Camino al norte, hacia la quebrada del Yastay.")
				_show(TALK_BAR_2)
				return
			_bar_done = true
			DialogueManager.dialogue_ended.connect(_bar_objective_done.unbind(1),
				CONNECT_ONE_SHOT)
			_show(TALK_BAR_2)
		3:
			_show(TALK_BAR_3)
		_:
			_show(TALK_BAR_1)


func _bar_objective_done() -> void:
	_banner("Los cazadores quieren atrapar al Yastay en la pampa alta.", 6.0)
	_hint("Tomá el camino del ESTE, hacia la quebrada del Yastay.")
	_open_exit()


# ─── Construcción del pueblo ────────────────────────────────────────────────

func _build_town() -> void:
	var dirt  := _mat(Color(0.46, 0.38, 0.28))
	var adobe := _mat(Color(0.68, 0.56, 0.40))
	var roof  := _mat(Color(0.35, 0.20, 0.14))
	var wood  := _mat(Color(0.32, 0.22, 0.14))
	var wall  := _mat(Color(0.24, 0.20, 0.16))

	# Plaza. MUNDO ABIERTO: el poblado es el centro del mapa y sale un camino
	# por cada lado (sur a La Tirana, este a la Mina, norte al Alicanto, oeste
	# al Yastay). Un muro con cuatro huecos ya no es un muro, así que en vez de
	# cerrar el perímetro quedan sólo pilares en las esquinas: marcan el límite
	# del pueblo sin cortar el paso.
	_box(Vector3(0, -0.5, 0), Vector3(44, 1, 44), dirt)
	for px: float in [-21.0, 21.0]:
		for pz: float in [-21.0, 21.0]:
			_box(Vector3(px, 2.0, pz), Vector3(1.6, 5.0, 1.6), wall)

	# — Casa de la Bruja (oeste), frente abierto hacia la plaza —
	_box(Vector3(-13, 1.8, -7.0), Vector3(10, 3.6, 1.0), adobe)   # fondo
	_box(Vector3(-17.5, 1.8, -3.5), Vector3(1.0, 3.6, 8.0), adobe) # lateral
	_box(Vector3(-13, 3.8, -3.5), Vector3(10, 0.5, 8.0), roof)     # techo
	var w_sign := Label3D.new()
	w_sign.text      = "Casa de la Bruja"
	w_sign.font_size = 20
	w_sign.position  = Vector3(-13, 4.6, -3.5)
	w_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	w_sign.modulate  = Color(0.80, 0.55, 1.0)
	add_child(w_sign)

	# — Bar (este), frente abierto hacia la plaza —
	_box(Vector3(12, 2.0, -7.0), Vector3(12, 4.0, 1.0), adobe)     # fondo
	_box(Vector3(17.5, 2.0, -3.0), Vector3(1.0, 4.0, 9.0), adobe)  # lateral este
	_box(Vector3( 6.5, 2.0, -3.0), Vector3(1.0, 4.0, 9.0), adobe)  # lateral oeste
	_box(Vector3(12, 4.2, -3.0), Vector3(12, 0.5, 9.0), roof)      # techo
	_box(Vector3(12, 0.55, -6.0), Vector3(9, 1.1, 0.7), wood)      # barra
	var b_sign := Label3D.new()
	b_sign.text      = "Bar"
	b_sign.font_size = 26
	b_sign.position  = Vector3(12, 5.0, -3.0)
	b_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	b_sign.modulate  = Color(1.0, 0.82, 0.45)
	add_child(b_sign)

	# Luz cálida del bar
	var bar_light          := OmniLight3D.new()
	bar_light.position     = Vector3(12, 2.8, -4.0)
	bar_light.light_color  = Color(1.0, 0.78, 0.42)
	bar_light.omni_range   = 12.0
	bar_light.light_energy = 1.3
	add_child(bar_light)

	# — Casas de relleno —
	for hx: float in [-16.0, -6.0, 5.0, 15.0]:
		_box(Vector3(hx, 1.5, 12.0), Vector3(6, 3, 5), adobe)
		_box(Vector3(hx, 3.2, 12.0), Vector3(6.4, 0.4, 5.4), roof)

	# — Camino al norte (marca visual de la salida) —
	_box(Vector3(0, -0.42, -14.0), Vector3(5, 0.2, 18), _mat(Color(0.55, 0.47, 0.35)))


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _npc(pos: Vector3, mat: Material, scale_f: float, label_text: String) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	add_child(root)

	var mi  := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.34 * scale_f
	cap.height = 1.55 * scale_f
	mi.mesh = cap
	mi.set_surface_override_material(0, mat)
	mi.position.y = 0.78 * scale_f
	root.add_child(mi)

	if label_text != "":
		var lbl    := Label3D.new()
		lbl.name   = "Label3D"
		lbl.text   = label_text
		lbl.font_size  = 20
		lbl.position.y = 1.9 * scale_f
		lbl.billboard  = BaseMaterial3D.BILLBOARD_ENABLED
		root.add_child(lbl)

	return root


func _box(pos: Vector3, size: Vector3, mat: Material) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.size = size
	b.position = pos
	b.use_collision = true
	b.material_override = mat
	add_child(b)
	return b


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _show(text: String) -> void:
	var res := DialogueManager.create_resource_from_text(text)
	DialogueManager.show_dialogue_balloon_scene(BALLOON, res, "start")


func _hint(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_hint"):
		hud.show_hint(text)


func _banner(text: String, dur := 0.0) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if not hud or not hud.has_method("show_banner"):
		return
	hud.show_banner(text)
	if dur > 0.0:
		get_tree().create_timer(dur).timeout.connect(func() -> void:
			if is_instance_valid(hud) and hud.has_method("clear_banner"):
				hud.clear_banner())
