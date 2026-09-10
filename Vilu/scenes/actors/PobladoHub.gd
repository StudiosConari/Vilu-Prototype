@tool
extends Node3D

const IDIOMA := preload("res://scenes/core/Idioma.gd")

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
##       caés en la cuenta de que la mujer sentada en el bar estuvo oyendo todo:
##       se levanta y se va caminando.

const WITCH_SCR    := preload("res://scenes/actors/WitchNPC.gd")
const ENCAJAR      := preload("res://scenes/core/EncajarModelo.gd")
const POSE         := preload("res://scenes/core/PoseAnimada.gd")
const INTERACT_SCR := preload("res://scenes/actors/Interactable.gd")
const PISO_BALDOSAS := preload("res://scenes/core/PisoBaldosas.gd")
const BALLOON      := "res://scenes/ui/GloboDeDialogo.tscn"

const TALK_BAR_1 := "~ start
Ciudadano: Salud. Acá no se habla de la mina, ¿estamos?
Ciudadano: Lo que sea que hayan visto abajo, déjenlo abajo.
Ciudadano: Desde hace unos dias estan pasando cosas muy raras.
Ciudadano: Me han dicho mis conocidos que estan viendo seres miticos.
Ciudadano: A mi Tambien me han dicho lo mismo, es muy extraño.
Ciudadano: Algo debio pasar.
=> END
"

const TALK_BAR_2 := "~ start
Ciudadano: ...y yo te digo que están locos. Nadie provoca al Yastay y vive para contarlo.
Emilia: Perdón. ¿Quién está provocando al Yastay?
Ciudadano: Cazadores. Bajaron de la cordillera hace una semana.
Ciudadano: Le están carneando los guanacos de a uno para sacarlo de la quebrada.
Ciudadano: Lo quieren en la pampa alta, donde no tenga dónde esconderse. Ahí lo atrapan.
Benjamín: ¿Y nadie hace nada?
Ciudadano: ¿Tu te atreverias? Si se animan, es camino al norte. Que la Virgen los acompañe.
=> END
"

const TALK_BAR_3 := "~ start
Ciudadano: Desde que volvieron de los volcanes la gente anda rara.
Ciudadano: Como si siempre hubiera alguien escuchando de más.
=> END
"

const TALK_OCULTISTA := "~ start
Benjamín: Emilia. La del bar.
Emilia: Estuvo ahí sentada todo el rato. Escuchando cada palabra.
Emilia: ¡Eh! ¡Vos!
Benjamín: Se va. Sin apurarse, como si nada.
Emilia: Entonces la bruja tiene razón. No estamos persiguiendo a un monstruo.
Emilia: Estamos persiguiendo a gente.
=> END
"


var _stage := 1
var _bar_done := false
var _exit: Node = null



## Deja de generar el decorado por código: ya está guardado como nodos.
##
## Se tilda DESPUÉS de correr tools/fijar_geometria.gd, que adopta los nodos
## generados dándoles `owner`. Con la bandera puesta el script no vuelve a
## construir encima, y el decorado pasa a editarse a mano en el editor.
##
## El orden importa: tildarla antes de correr la herramienta deja la zona sin
## geometría que adoptar.
@export var geometria_fijada: bool = false


func _ready() -> void:
	# EN EL EDITOR: sólo la geometría, para poder verla al trabajar el terreno.
	# Nada más: el resto toca autoloads (GameManager, DialogueManager) que en el
	# editor no están instanciados, y dispararía diálogos y señales.
	if Engine.is_editor_hint():
		if not geometria_fijada:
			_build_town()
		return

	_stage = _current_stage()
	if not geometria_fijada:
		_build_town()
	_spawn_witch()
	_montar_a_la_ocultista.call_deferred()
	_spawn_bar_folk()
	_setup_exit()
	# MUNDO ABIERTO: el pueblo ya no se recarga en cada visita, así que la etapa
	# tiene que recalcularse cuando cambia el progreso, no una sola vez.
	GameManager.ability_unlocked.connect(_on_progreso.unbind(1))


const CHARLA := preload("res://scenes/core/Charla.gd")

## Lo que se dicen al salir corriendo de la mina la primera vez, ya a salvo.
const TALK_HUIDA := "~ start
Benjamín: ¡No lo puedo creer! Primero La Tirana en persona, ahora un fantasma… ¡y hasta un perro gigante demoníaco!
Emilia: Yo tampoco. Este viaje está cada vez más raro. ¿A ti qué se te ocurre salir a mochilear?
Benjamín: Esto nunca estuvo en el plan. ¡Aún tengo la piel de gallina!
=> END
"


## WorldRoot llama a esto cuando el jugador entra al pueblo.
func activate() -> void:
	_refrescar_etapa()
	_intro_hint()
	# Recién salidos de la mina con el Chupacabras detrás: un segundo para que
	# termine el fundido, y hablan.
	if GameManager.huyo_de_la_mina:
		GameManager.huyo_de_la_mina = false
		CHARLA.una_vez(get_tree(), "huida_de_la_mina", TALK_HUIDA, 1.0)


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


# ─── Salida ──────────────────────────────────────────────────────────────────

## Ya no hay ninguna.
##
## MUNDO ABIERTO: al Isluga y a la quebrada del Yastay se llega caminando. Y la
## que quedaba —una puerta al "Final", una escena aparte con su propio cartel de
## FIN— se fue con esa escena: el prototipo termina al vencer al Chupacabras, y
## lo que sale entonces es la pantalla de logros. Dos finales compitiendo eran
## uno de más.
func _setup_exit() -> void:
	if is_instance_valid(_exit):
		_exit.queue_free()
		_exit = null


func _open_exit() -> void:
	pass


# ─── Bruja ───────────────────────────────────────────────────────────────────

## Le cuelga la lógica de la Bruja al modelo que está puesto en el mundo.
##
## Si no lo encuentra vuelve a la cápsula del greybox, en su sitio de siempre.
func _spawn_witch() -> void:
	var w := _modelo_del_mundo("bruja")
	if w == null:
		w = Node3D.new()
		w.position = Vector3(-10.0, 0.0, -3.0)
		add_child(w)
		push_warning("Poblado: no hay modelo de bruja; se usa la cápsula")
	# Las dos entregas de talismán la tienen a ella como destino.
	w.add_to_group("objetivo_talisman_1")
	w.add_to_group("objetivo_talisman_2")
	w.set_script(WITCH_SCR)
	w.call("_ready")   # el nodo ya está en el árbol: no se dispara sola
	if w.has_signal("revealed_ocultists"):
		w.revealed_ocultists.connect(_on_ocultists_revealed)


## La bruja terminó de unir las dos piezas: sale el ocultista que espiaba.
func _on_ocultists_revealed() -> void:
	DialogueManager.dialogue_ended.connect(_reveal_ocultista.unbind(1), CONNECT_ONE_SHOT)


func _reveal_ocultista() -> void:
	if not is_instance_valid(_ocultista_mujer) or _ocultista_ya_se_fue:
		_after_flee()
		return
	# No hay nada que "revelar" ya: estuvo sentada en el bar todo el rato, oyendo.
	# Eso es lo que la delata, y por eso la cámara va a ella.
	_banner("La que estaba sentada en el bar lo oyó todo.", 4.0)
	var game := get_tree().get_first_node_in_group("game")
	if game and game.has_method("focus_camera_on"):
		game.focus_camera_on(_ocultista_mujer, 4.0)
	DialogueManager.dialogue_ended.connect(_ocultista_flees.unbind(1), CONNECT_ONE_SHOT)
	_show(TALK_OCULTISTA)


func _ocultista_flees() -> void:
	if not is_instance_valid(_ocultista_mujer) or _ocultista_ya_se_fue:
		_end_flee()
		return
	_ocultista_ya_se_fue = true

	var lbl := _ocultista_mujer.get_node_or_null("Label3D") as Label3D
	if lbl:
		lbl.text = "¡La ocultista se va!"

	# La cámara la sigue para que se vea la huida.
	var game := get_tree().get_first_node_in_group("game")
	if game and game.has_method("focus_camera_on"):
		game.focus_camera_on(_ocultista_mujer, 4.0)

	# Con await: llamar a una corrutina desde un manejador de señal y no
	# esperarla la deja colgada en su primer await y la escena no sigue.
	await _escena_de_la_ocultista()
	_end_flee()


func _end_flee() -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game and game.has_method("clear_camera_focus"):
		game.clear_camera_focus()
	# NO se la borra: se queda de pie donde acabó el camino. Antes desaparecía a
	# mitad de la plaza, que es lo que hace un fantasma, no alguien que se va.
	_after_flee()


func _after_flee() -> void:
	# Lo que queda por hacer es el Chupacabras: la bruja ya unió las piezas y la
	# ocultista se fue, así que el prototipo se cierra bajando a la mina.
	_hint("La ocultista se fue del bar. En la mina te espera lo que empezó todo.")


# ─── Bar ─────────────────────────────────────────────────────────────────────

## Los parroquianos del bar.
##
## Ya no se dibujan: son los modelos que están puestos en la escena. El que lleva
## la conversación es el más cercano al bar; si no hubiera ninguno se vuelve a
## las cápsulas, en sus sitios de siempre.
func _spawn_bar_folk() -> void:
	var folk_mat := _mat(Color(0.38, 0.30, 0.24))
	var gente := _gente_del_bar()
	var talker: Node3D = null
	if gente.is_empty():
		push_warning("Poblado: no hay modelos de parroquianos; se usan cápsulas")
		_npc(Vector3( 8.5, 0, -5.0), folk_mat, 1.0, "")
		_npc(Vector3(11.5, 0, -5.0), folk_mat, 1.0, "")
		talker = _npc(Vector3(10.0, 0, -3.0), _mat(Color(0.46, 0.34, 0.22)), 1.0,
			"Parroquiano")
	else:
		talker = gente[0]
		# Todos los del bar están sentados: cada uno con la suya, que se llama
		# distinto según el personaje ("sentado_victoria", "sentada_riendo"…).
		var sentados := 0
		for p in gente:
			if POSE.poner(p, "sentad", true):
				sentados += 1
		print("[poblado] sentados en el bar: %d de %d" % [sentados, gente.size()])
	var zone             := Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask  = 2
	zone.set_script(INTERACT_SCR)
	zone.prompt          = "[E] Escuchar la conversación"
	# «Escucha los rumores en el bar»: el marcador va sobre quien habla.
	talker.add_to_group("objetivo_bar")
	talker.add_child(zone)

	var cs  := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	# La escala del modelo se descuenta: los que pusiste están a ~1.28, y sin esto
	# la zona para escuchar tendría casi cuatro metros de radio.
	sph.radius = 2.8 / maxf(talker.global_transform.basis.get_scale().y, 0.001)
	cs.shape   = sph
	zone.add_child(cs)
	zone.interacted.connect(_on_bar_talk)

	# El que espía en el bar YA está en el bar: es la ocultista sentada, que
	# `_montar_a_la_ocultista` monta aparte. Acá había además un ocultista
	# hombre oculto junto a la puerta que salía corriendo al revelarlos; eran
	# dos personas para un solo papel y en pantalla se notaba.


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
	get_tree().call_group("objetivo_bar", "remove_from_group", "objetivo_bar")
	Misiones.hecho("bar")
	_banner("Los cazadores quieren atrapar al Yastay en la pampa alta.", 6.0)
	_hint("Tomá el camino del ESTE, hacia la quebrada del Yastay.")
	_open_exit()


# ─── Construcción del pueblo ────────────────────────────────────────────────

func _build_town() -> void:
	# Paleta aclarada para el sombreado toon: con la rampa de luz escalonada,
	# los tonos oscuros colapsan a manchas negras sin forma legible.
	var adobe := _mat(Color(0.86, 0.74, 0.56))
	var roof  := _mat(Color(0.66, 0.34, 0.24))
	var wood  := _mat(Color(0.58, 0.42, 0.28))
	var wall  := _mat(Color(0.60, 0.50, 0.40))

	# Plaza. MUNDO ABIERTO: el poblado es el centro del mapa y sale un camino
	# por cada lado (sur a La Tirana, este a la Mina, norte al Alicanto, oeste
	# al Yastay). Un muro con cuatro huecos ya no es un muro, así que en vez de
	# cerrar el perímetro quedan sólo pilares en las esquinas: marcan el límite
	# del pueblo sin cortar el paso.
	# El piso ya no es una caja de CSG: era coplanar con el terreno de Terrain3D
	# y los dos se peleaban por el mismo plano (z-fighting). Ahora es empedrado
	# de baldosas apoyado unos centímetros por encima.
	var piso := Node3D.new()
	piso.name = "PisoPlaza"
	piso.set_script(PISO_BALDOSAS)
	add_child(piso)
	piso.plaza(Vector3.ZERO, 44.0, 44.0)
	piso.construir()

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

	# Luz cálida del bar.
	#
	# El radio era 12 m, y eso la sacaba del pueblo: su borde exterior caía sobre
	# el desierto abierto y dibujaba ahí una mancha pálida de bordes duros. Se
	# veía como un fallo del terreno, pero era esta lámpara.
	#
	# Dos cosas la delataban. La arena tiene el canal rojo saturado al tope, así
	# que una luz cálida no puede aclararla: sólo puede subirle el verde, y el
	# dorado vira a blanco de golpe en vez de iluminarse. Y el renderizador
	# agrupa las luces por celdas de pantalla, así que en la cola tenue del
	# alcance la frontera entre celdas se ve como un recorte recto que se
	# desplaza al caminar.
	#
	# Con 5 m el charco de luz se queda en la plaza, que es donde tiene sentido,
	# y la atenuación más seca apaga esa cola. Medido: la diferencia entre arena
	# dentro y fuera del borde pasa de 0.051 a 0.000.
	var bar_light             := OmniLight3D.new()
	bar_light.position        = Vector3(12, 2.8, -4.0)
	bar_light.light_color     = Color(1.0, 0.78, 0.42)
	bar_light.omni_range      = 5.0
	bar_light.omni_attenuation = 2.5
	bar_light.light_energy    = 1.3
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
	var res := DialogueManager.create_resource_from_text(IDIOMA.guion(text))
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
			# El HUD se vuelve a buscar acá dentro en vez de capturarlo: una lambda que
			# captura un nodo y sobrevive a que lo liberen da "Lambda capture at index 0
			# was freed", aunque se compruebe is_instance_valid antes de usarlo.
			var h := get_tree().get_first_node_in_group("hud")
			if h != null and h.has_method("clear_banner"):
				h.clear_banner())


## Busca por nombre un modelo ya colocado a mano en el mundo.
##
## Los personajes del pueblo dejaron de ser cápsulas: están puestos en la escena
## y lo que hace el código es colgarles la lógica encima, no dibujar otro encima
## del que ya está. Se busca desde la RAÍZ y no desde el Poblado porque los
## pusiste colgando del mundo, no del hub.
func _modelo_del_mundo(prefijo: String) -> Node3D:
	var raiz := get_tree().current_scene
	if raiz == null:
		raiz = get_parent()
	if raiz == null:
		return null
	for n in raiz.find_children("%s*" % prefijo, "", true, false):
		if n is Node3D and (n as Node).scene_file_path != "":
			return n
	return null


# ─── La ocultista del bar ────────────────────────────────────────────────────
#
# Es LA ocultista del pueblo: la que está sentada en el bar escuchando y la que
# se va cuando la bruja une las dos piezas. Antes eran dos —ella sentada y un
# ocultista hombre de pie junto a la puerta que salía corriendo—, y en pantalla
# se veía lo que era: dos personas haciendo el mismo papel.

## Prefijo del nodo que colocás en la escena.
const OCULTISTA_MUJER := "ocultista_mujer"
## El logro que se concede al entregarle los dos talismanes a la bruja.
const LOGRO_QUE_LA_LEVANTA := "talisman_2"

## Por dónde se va al levantarse.
##
## Apuntá acá a un nodo con Marker3D adentro y los recorre EN ORDEN, que es lo
## que hace falta para bordear la plaza en vez de atravesar los puestos. Si el
## nodo no tiene hijos, camina derecho hasta él. Vacío = se levanta y se queda.
@export var destino_de_la_ocultista: NodePath
## A qué velocidad se va, en metros por segundo.
@export var paso_de_la_ocultista := 1.6

var _ocultista_mujer: Node3D = null
var _ocultista_ya_se_fue := false


func _montar_a_la_ocultista() -> void:
	# Una sola vez. `_ready` la difiere y la escena puede volver a pedirla; sin
	# esto la segunda pasada la teletransportaba a su destino en mitad de la
	# animación de levantarse, y ya no le quedaba camino que hacer.
	if _ocultista_mujer != null:
		return
	_ocultista_mujer = _buscar_con_prefijo(self, OCULTISTA_MUJER)
	if _ocultista_mujer == null:
		var raiz := get_tree().current_scene
		if raiz != null:
			_ocultista_mujer = _buscar_con_prefijo(raiz, OCULTISTA_MUJER)
	if _ocultista_mujer == null:
		return

	if GameManager.tiene_logro(LOGRO_QUE_LA_LEVANTA):
		# Volviste después de entregarlo: ya se levantó y ya se fue. La escena no
		# se repite, y como el bar y la bruja pueden estar en regiones distintas,
		# lo más probable es que pasara con este mundo descargado.
		_ocultista_ya_se_fue = true
		var meta := _final_del_camino()
		if meta != Vector3.INF:
			_ocultista_mujer.global_position = meta
		_de_pie_quieta()
		return

	_clip_ocultista("sentada_hablando", true)


func _escena_de_la_ocultista() -> void:
	# 1. Se levanta del taburete.
	await get_tree().create_timer(
		_clip_ocultista("sentada_a_de_pie", false)).timeout
	if not is_instance_valid(_ocultista_mujer):
		return

	# 2. Y se va caminando, tramo por tramo. En cada esquina se gira antes de
	#    seguir: yendo en línea recta al último punto atravesaría los puestos.
	var pasos := _camino_de_la_ocultista()
	if not pasos.is_empty():
		_clip_ocultista("caminando", true)
		for meta in pasos:
			if not is_instance_valid(_ocultista_mujer):
				return
			var d: Vector3 = meta - _ocultista_mujer.global_position
			d.y = 0.0
			if d.length() < 0.2:
				continue
			# El frente de estos modelos es +Z, medido del talón a los dedos.
			_ocultista_mujer.rotation.y = atan2(d.x, d.z)
			var tw := get_tree().create_tween()
			tw.tween_property(_ocultista_mujer, "global_position", meta,
				d.length() / maxf(paso_de_la_ocultista, 0.1))
			await tw.finished
	_de_pie_quieta()


## De pie y quieta: el último fotograma de levantarse, que es exactamente eso.
##
## No tiene clip de reposo de pie —sus cuatro son sentada, levantarse, caminar y
## correr— y congelarla caminando la dejaría a media zancada.
func _de_pie_quieta() -> void:
	var ap := _animador_de(_ocultista_mujer)
	if ap == null or not ap.has_animation("sentada_a_de_pie"):
		return
	var a := ap.get_animation("sentada_a_de_pie")
	a.loop_mode = Animation.LOOP_NONE
	ap.play("sentada_a_de_pie")
	ap.advance(a.length)
	ap.pause()


## Los puntos por los que pasa, en orden.
##
## Si el nodo que asignaste tiene hijos, ésos son el camino; si no, el nodo es
## el único destino. Así una esquina se pone arrastrando un marcador más, sin
## tocar nada de esto.
func _camino_de_la_ocultista() -> Array[Vector3]:
	var pasos: Array[Vector3] = []
	var n := get_node_or_null(destino_de_la_ocultista) as Node3D
	if n == null:
		return pasos
	for h in n.get_children():
		if h is Node3D:
			pasos.append((h as Node3D).global_position)
	if pasos.is_empty():
		pasos.append(n.global_position)
	return pasos


## Dónde acaba. Es adonde se la teletransporta si volvés con todo hecho.
func _final_del_camino() -> Vector3:
	var pasos := _camino_de_la_ocultista()
	return pasos[pasos.size() - 1] if not pasos.is_empty() else Vector3.INF



func _clip_ocultista(nombre: String, en_bucle: bool) -> float:
	var ap := _animador_de(_ocultista_mujer)
	if ap == null or not ap.has_animation(nombre):
		return 0.0
	var a := ap.get_animation(nombre)
	a.loop_mode = Animation.LOOP_LINEAR if en_bucle else Animation.LOOP_NONE
	if ap.assigned_animation != nombre or not ap.is_playing():
		ap.play(nombre)
	return a.length


func _animador_de(n: Node) -> AnimationPlayer:
	if not is_instance_valid(n):
		return null
	for h in n.get_children():
		if h is AnimationPlayer:
			return h
		var x := _animador_de(h)
		if x != null:
			return x
	return null


func _buscar_con_prefijo(n: Node, prefijo: String) -> Node3D:
	for h in n.get_children():
		if h is Node3D and String(h.name).begins_with(prefijo):
			return h as Node3D
		var x := _buscar_con_prefijo(h, prefijo)
		if x != null:
			return x
	return null


## Los modelos de parroquianos puestos en el mundo, del más cercano al bar al más
## lejano.
##
## El bar está en (10, 0, -4) del Poblado; se ordena por distancia para que el
## que lleva la conversación sea el que tenés más a mano al acercarte.
const GENTE_DEL_BAR := ["cazador_joven", "cazadora_joven", "cazador_adulto",
	"cazadora_adulta"]
const BARRA := Vector3(10.0, 0.0, -4.0)
## Hasta dónde se considera "gente del bar". Sin este límite la búsqueda barría
## el mundo entero y sentaba también a los cazadores de la quebrada del Yastay,
## que tienen que caer derrotados.
const RADIO_DEL_BAR := 30.0


func _gente_del_bar() -> Array:
	var raiz := get_tree().current_scene
	if raiz == null:
		raiz = get_parent()
	if raiz == null:
		return []
	var punto := to_global(BARRA)
	var todos: Array = []
	for prefijo in GENTE_DEL_BAR:
		for n in raiz.find_children("%s*" % prefijo, "", true, false):
			# Sólo los que están COLOCADOS en la escena: un modelo instanciado tiene
			# `scene_file_path`, y sus nodos internos no. Sin este filtro cada
			# persona aparecía dos veces —ella y su nodo de adentro— y la pose se
			# aplicaba encima de sí misma.
			if not (n is Node3D) or (n as Node).scene_file_path == "":
				continue
			if (n as Node3D).global_position.distance_to(punto) > RADIO_DEL_BAR:
				continue
			todos.append(n)
	todos.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_to(punto) < b.global_position.distance_to(punto))
	return todos


## Crea una persona con su modelo, ajustada a la altura pedida y apoyada en el
## suelo.
##
## Para los que NO están puestos a mano en la escena, como el ocultista que
## espía: era el único que seguía siendo una cápsula entre puros modelos.
func _persona(ruta: String, pos: Vector3, altura: float, etiqueta: String) -> Node3D:
	var raiz := Node3D.new()
	raiz.position = pos
	add_child(raiz)

	var escena := load(ruta) as PackedScene
	if escena == null:
		push_warning("Poblado: no encuentro el modelo %s" % ruta)
		return raiz
	var modelo := escena.instantiate() as Node3D
	raiz.add_child(modelo)
	# El .glb viene a su tamaño y con el origen donde sea: se encaja.
	ENCAJAR.encajar(modelo, altura)
	# Los modelos miran a +Z y el juego toma -Z como frente.
	modelo.rotation.y = PI

	_cartel_de(raiz, etiqueta, altura + 0.35)
	return raiz


## Le cuelga un cartel a alguien, a `alto` metros de su origen.
##
## El alto va en las unidades del nodo: si lo escalaste en el editor, el cartel
## se escala con él y sigue quedando sobre la cabeza.
func _cartel_de(quien: Node3D, texto: String, alto: float) -> void:
	if texto == "" or not is_instance_valid(quien):
		return
	if quien.has_node("Label3D"):
		return
	var lbl := Label3D.new()
	lbl.name = "Label3D"
	lbl.text = texto
	lbl.font_size = 20
	lbl.position.y = alto
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	quien.add_child(lbl)
