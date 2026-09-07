extends Node3D

## Raíz jugable del MVP. Contenedor persistente: entorno, luz, un holder de
## región y el PARTY de dos protagonistas (melee + arquero), intercambiables
## con R. Solo el activo recibe input y tiene cámara current. Ambos persisten
## entre regiones (se reubican en el spawn al viajar).

const PLAYER_SCENE := preload("res://scenes/actors/Player.tscn")
const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")
const GUIA_DE_OBJETIVOS := preload("res://scenes/core/GuiaDeObjetivos.gd")
## Mundo que se monta al empezar.
##
## Es @export y no const para poder cambiar de región desde el inspector del
## nodo Game, sin tocar código: `WorldAtacama.tscn` es la copia de Tarapacá que
## sirve de punto de partida para la segunda región.
##
## OJO con el terreno: cada mundo tiene que apuntar a SU carpeta de datos de
## Terrain3D (`data_directory` en el nodo Terrain3D). Si dos mundos comparten
## una, esculpir en uno deforma el otro.
@export var escena_del_mundo: PackedScene = preload("res://scenes/core/World.tscn")

## El otro mundo, al que lleva el bus. Los dos se intercambian al viajar, así
## que el viaje de vuelta sale gratis.
@export var mundo_alterno: PackedScene = preload("res://scenes/core/WorldAtacama.tscn")

## Cómo se llama cada mundo en el cartel del bus.
const NOMBRES_DE_MUNDO := {
	"res://scenes/core/World.tscn": "Tarapacá",
	"res://scenes/core/WorldAtacama.tscn": "Atacama",
}

## Metros que se camina hacia el poblado al bajarse del bus. Lo justo para
## quedar fuera del área de la parada y no volver a subirse sin querer.
const BAJADA_DEL_BUS := 8.0
const TOON_SKIN := preload("res://scenes/core/ToonSkin.gd")
const PANTALLA_LOGROS := preload("res://scenes/ui/PantallaLogros.gd")

## Segundos entre que cae el último logro y que aparece el cierre.
##
## No es adorno: el logro que cierra el prototipo es vencer al Chupacabras, y
## saltar a la pantalla en el mismo cuadro en que muere se come el momento. Con
## esta pausa se ve caer al bicho y leer su cartel antes del corte.
const ESPERA_CIERRE := 3.5
const ARCHER_MAT := preload("res://art_placeholders/mat_player_b.tres")

## Zonas que NO son parte del mundo continuo: se cargan aparte al entrar.
const INTERIORES := ["Mina", "Iglesia", "Isluga", "OjosDelSalado"]

## Interiores a los que se entra por una PUERTA que está dentro de una zona.
##
## Se distinguen del resto porque al salir hay que devolver al jugador al umbral
## por el que entró, no al punto de aparición de la zona. La Mina no está acá
## porque tiene su propio punto curado (`mine_mouth()`), unos metros delante del
## socavón, que queda mejor que el sitio exacto donde estabas parado.
const INTERIORES_DE_PUERTA := ["Iglesia", "Isluga", "OjosDelSalado"]

@onready var _region_holder: Node3D = $RegionHolder

## Para que el cierre no se abra dos veces si la señal llegara repetida.
var _cierre_mostrado := false
@onready var _camera: Camera3D = $Camera

@export_group("Estilo")
## Todos los mandos del sombreado toon: saturación, escalones de luz, tinte de
## sombra y los dos contornos. Se editan abriendo el archivo en el inspector, y
## con el juego corriendo se pueden mover desde el árbol Remoto para verlo en
## el acto.
@export var ajustes_toon: Resource = preload("res://scenes/core/toon.tres")

@export_group("Cámara")
## La cámara sigue al ratón: moverlo gira el plano, sin pulsar nada.
##
## Antes había que arrastrar con el botón derecho, que para mirar alrededor
## mientras se juega es un botón de más. Con esto el puntero se captura mientras
## se juega y se suelta solo en cuanto hay un menú o alguien habla.
@export var camara_sigue_al_raton := true

## La DISTANCIA no se toca: ni la rueda ni el arrastre la cambian.
##
## Alejarla dejaba el encuadre en manos del jugador: con la rueda se llegaba a
## 70 m y el personaje era un punto. Y las escenas guionadas, que colocan la
## cámara ellas mismas, salían distintas cada vez según dónde la hubieras
## dejado. Con la distancia fija el plano se puede componer.
##
## Girar sí se puede, con el ratón; lo que esta casilla apaga es el zoom y el
## orbitar con el botón derecho.
@export var camara_fija := true
## A qué distancia va del personaje, en metros.
##
## Estaba en 18: se veía media quebrada y a los protagonistas de lejos, como una
## partida de estrategia. Con 9 se les ve la ropa y la cara.
@export var cam_distance := 9.0
@export var cam_zoom_min := 4.0
@export var cam_zoom_max := 70.0
@export var cam_zoom_step := 3.0
@export var cam_rotate_speed := 0.006
@export var cam_follow_lerp := 0.18

var _cam_yaw := 0.0
var _cam_pitch := -0.6
var _cam_focus := Vector3.ZERO
var _cam_rotating := false
var _cam_override: Node3D = null   # si está seteado, la cámara sigue a este nodo
## Distancia pedida por un enfoque guionado. 0 = la de siempre.
var _cam_dist_deseada := 0.0
## Distancia REAL, que persigue a la pedida. Se interpola aparte porque saltar
## de 18 m a 2 en un cuadro se ve como un corte de plano, no como un acercamiento.
var _cam_dist_actual := -1.0
## Altura del punto al que mira la cámara, sobre el objetivo.
var _cam_alto := 1.5

## Altura por debajo de la cual se cuenta como caída al vacío, EN EL MUNDO
## ABIERTO. Ahí el suelo está siempre a la misma altura y un valor absoluto vale.
@export var fall_limit := -8.0
var _resetting := false

var player: CharacterBody3D          # personaje primario/activo de referencia
var hud: CanvasLayer
var world: Node3D                    # WorldRoot: todas las zonas al aire libre

## Avisa de que el party acaba de reaparecer, por caída o por reinicio. Las
## escenas que dejan cosas a medias —una plataforma parada a mitad de recorrido,
## por ejemplo— se enganchan acá para volver a dejarlas listas.
signal jugador_reaparecio

var _respawn_pos := Vector3.ZERO      # dónde reaparecer al caer al vacío
var _interior := ""                   # interior abierto ("" = estás en el mundo)
var _volviendo_de := ""               # interior del que se está saliendo
var _pos_antes_interior := Vector3.ZERO

## Party controlable (2 protagonistas). Solo el activo recibe input.
var party: Array = []
var active_index := 0

var _r_prev := false
var _t_prev := false

## Alguien está hablando: el globo se traga las teclas y el ratón vuelve a ser
## un puntero para poder pulsar en él.
var _hablando := false


func _ready() -> void:
	# La historia abre en la fiesta de La Tirana, con Carmen: es la secuencia 1
	# del relato. El Poblado es el centro geográfico del mapa, pero empezar ahí
	# dejaba al jugador parado en mitad de la trama, con la Bruja pidiéndole un
	# talismán que todavía no fue a buscar.
	var start := "Tarapaca"
	if GameManager.debug_start_zone != "":
		start = GameManager.debug_start_zone
		GameManager.debug_start_zone = ""

	# Hay entradas del selector que están en el OTRO mundo: el Bar es el del
	# poblado de Atacama, no el de Tarapacá. Se intercambian los dos antes de
	# instanciar nada, y así el bus sigue llevando al de siempre sin tocar nada
	# más — el viaje ya funciona intercambiándolos.
	if GameManager.debug_start_world != "":
		var pedido: String = GameManager.debug_start_world
		GameManager.debug_start_world = ""
		if pedido != escena_del_mundo.resource_path:
			mundo_alterno = escena_del_mundo
			escena_del_mundo = load(pedido) as PackedScene

	# El mundo abierto (todas las zonas al aire libre) vive siempre.
	world = escena_del_mundo.instantiate()
	add_child(world)

	hud = HUD_SCENE.instantiate()
	add_child(hud)
	# La guía de objetivos va DESPUÉS del HUD: es donde cuelga su flecha de borde.
	var guia := Node.new()
	guia.name = "GuiaDeObjetivos"
	guia.set_script(GUIA_DE_OBJETIVOS)
	add_child(guia)
	# El cierre se engancha una sola vez y vive lo que viva la partida: el último
	# logro puede caer en cualquier zona, no sólo en la mina.
	if not GameManager.prototipo_superado.is_connected(_al_superar_el_prototipo):
		GameManager.prototipo_superado.connect(_al_superar_el_prototipo)
	# El ratón vuelve a ser puntero mientras alguien habla: el globo tiene texto
	# que se pulsa.
	DialogueManager.dialogue_started.connect(func(_r: Resource) -> void:
		_hablando = true)
	DialogueManager.dialogue_ended.connect(func(_r: Resource) -> void:
		_hablando = false)
	_spawn_party_open(start)

	# Arrancar en un interior (la Mina) desde el selector de debug.
	if not world.has_zone(start):
		enter_interior(start)

	_aplicar_estilo()
	if ajustes_toon != null and not ajustes_toon.changed.is_connected(_aplicar_estilo):
		ajustes_toon.changed.connect(_aplicar_estilo)

	var act := active_character()
	if act != null:
		_cam_focus = act.global_position + Vector3(0.0, 1.5, 0.0)
	_update_camera()


## Empuja los ajustes de estilo a lo que ya está en pantalla.
##
## Corre al arrancar y otra vez cada vez que el recurso avisa de un cambio. Eso
## último es lo que permite afinar el toon con el juego andando —desde el árbol
## Remoto, nodo Game— en vez de reiniciar por cada valor que se prueba.
##
## Son dos destinos distintos: los materiales de los objetos, que los repinta
## ToonSkin, y el contorno de post-proceso, que es un material suelto colgado
## de la cámara.
func _aplicar_estilo() -> void:
	if ajustes_toon == null:
		return
	TOON_SKIN.refrescar(ajustes_toon)

	# El suelo lo pone Terrain3D con su propio shader, así que no pasa por
	# ToonSkin y hay que empujarle los valores aparte.
	if world:
		var terreno := world.get_node_or_null("Terrain3D")
		if terreno:
			ajustes_toon.aplicar_a_terreno(terreno.get("material"))

	var borde := get_node_or_null("Camera/ContornoToon") as MeshInstance3D
	if borde == null:
		return
	var m := borde.get_surface_override_material(0) as ShaderMaterial
	if m != null:
		ajustes_toon.aplicar_a_pantalla(m)


func _spawn_party_open(zona: String) -> void:
	var a := _make_character(false, null)
	var b := _make_character(true, ARCHER_MAT)
	party = [a, b]
	player = a
	active_index = 0
	for c in party:
		c.hud = hud
	_apply_active()
	_colocar_en(world.spawn_point(zona if world.has_zone(zona) else "Tarapaca"))
	hud.show_swap_hint(party.size() > 1)


## Reubica al party alrededor de una posición mundial.
func _colocar_en(pos: Vector3) -> void:
	if pos == Vector3.INF:
		return
	var offsets := [Vector3.ZERO, Vector3(2.5, 0, 0), Vector3(-2.5, 0, 0)]
	for i in party.size():
		var off: Vector3 = offsets[i] if i < offsets.size() else Vector3(0, 0, i * 2.0)
		party[i].global_position = pos + _si_hay_suelo(pos, off, party[i])
		party[i].velocity = Vector3.ZERO
	_respawn_pos = pos
	_pegar_la_camara(pos)


## Cuánto se puede apartar del punto sin quedarse en el aire.
##
## El party no aparece amontonado: al segundo y al tercero se los corre dos
## metros y medio a cada lado. Eso da por sentado que hay cinco metros de suelo,
## y en el cráter del Isluga no los hay: la plataforma del punto de aparición es
## más angosta, así que al reaparecer los de los lados salían sobre el vacío y
## caían a la lava — SIEMPRE, cada vez que reaparecías.
##
## Se comprueba con un rayo si bajo el sitio apartado hay algo donde pisar. Si
## no lo hay, ese personaje aparece en el punto sin apartar; se empujan solos al
## primer cuadro, que es mucho mejor que caerse.
const SUELO_BAJO_EL_PARTY := 6.0


## `quien` es el personaje que se va a colocar: el espacio de física se le pide
## a él y no a este nodo porque él siempre está en el árbol.
func _si_hay_suelo(pos: Vector3, off: Vector3, quien: Node3D) -> Vector3:
	if off == Vector3.ZERO or quien == null or not quien.is_inside_tree():
		return off
	var esp := quien.get_world_3d().direct_space_state
	if esp == null:
		return off
	var desde: Vector3 = pos + off + Vector3.UP * 2.0
	var q := PhysicsRayQueryParameters3D.create(
		desde, desde + Vector3.DOWN * (SUELO_BAJO_EL_PARTY + 2.0))
	q.collision_mask = 1
	return off if not esp.intersect_ray(q).is_empty() else Vector3.ZERO


## Planta la cámara en el sitio nuevo en vez de dejar que viaje hasta él.
##
## `_update_camera` acerca el foco por interpolación, que es lo que se quiere
## caminando. Pero un teletransporte mueve al party cientos de metros de golpe, y
## el foco se quedaba atrás: al abrirse el fundido veías a los personajes como
## dos puntitos en el horizonte mientras la cámara cruzaba el mapa. Aparecías
## sin saber dónde estabas justo en el momento en que más falta hace.
func _pegar_la_camara(pos: Vector3) -> void:
	_cam_focus = pos + Vector3(0.0, _cam_alto, 0.0)
	_cam_dist_actual = _cam_dist_deseada if _cam_dist_deseada > 0.0 else cam_distance


func _make_character(is_archer: bool, mat: Material) -> CharacterBody3D:
	var c := PLAYER_SCENE.instantiate()
	c.is_archer = is_archer
	add_child(c)
	if mat != null:
		var ph := c.get_node_or_null("Visual/Placeholder")
		if ph and ph.has_method("set_surface_override_material"):
			ph.set_surface_override_material(0, mat)
	# Mismo sombreado escalonado que el mundo: si no, los protagonistas quedan
	# con luz PBR suave sobre un fondo cel-shaded y se ven pegoteados encima.
	TOON_SKIN.new().aplicar(c, ajustes_toon)
	return c


func _process(delta: float) -> void:
	_gracia = maxf(0.0, _gracia - delta)
	_espera_de_rescate = maxf(0.0, _espera_de_rescate - delta)
	_mandar_el_raton()
	# R = cambiar dejando al otro en IA de combate; T = dejándolo QUIETO (puzzles).
	var r := Input.is_action_pressed("swap_ai")
	if r and not _r_prev:
		_swap(true)
	_r_prev = r
	var t := Input.is_action_pressed("swap_hold")
	if t and not _t_prev:
		_swap(false)
	_t_prev = t
	_update_camera()
	_check_fall()


## Si algún personaje cae al vacío, reaparece el party en el último punto seguro.
func _check_fall() -> void:
	if _resetting:
		return
	var limite := _limite_de_caida()
	for c in party:
		if is_instance_valid(c) and c.global_position.y < limite:
			_respawn()
			return


## El umbral de caída de la zona en la que se está.
##
## Un interior puede vivir a cualquier altura: el cráter del Isluga está a y≈300
## y su suelo tiene 80 m de desnivel, así que ni un valor absoluto ni un margen
## desde el punto de aparición sirven. Cada región puede declarar el suyo con una
## propiedad `limite_de_caida` en su nodo raíz; el que no la trae usa el del
## mundo abierto.
##
## Sin esto, caer a la lava del Isluga no rescataba a nadie: se atravesaba y se
## quedaba de pie sobre la cáscara del volcán, con el cráter de techo.
func _limite_de_caida() -> float:
	if _interior == "":
		return fall_limit
	for r in _region_holder.get_children():
		if "limite_de_caida" in r:
			return float(r.get("limite_de_caida"))
	return fall_limit


## MUNDO ABIERTO: ya no existe "recargar la zona actual" — el mundo entero está
## siempre cargado y recargarlo reiniciaría guiones de zonas lejanas. En su
## lugar se devuelve al party al último spawn pisado.
## Devuelve al party al punto seguro por algo que no es caerse: la lava, por
## ahora. El daño se aplica DESPUÉS de reubicar porque el rescate cura al party
## entero; sin esto tocar la lava no costaría nada.
func volver_al_punto_seguro(motivo: String, dano := 0.0) -> void:
	var que_hacer := decidir_rescate()
	if not que_hacer[0]:
		return
	_espera_de_rescate = RESCATE_MINIMO
	_respawn(motivo)
	if dano <= 0.0 or not que_hacer[1]:
		return
	for c in party:
		if is_instance_valid(c) and c.has_method("take_damage"):
			c.take_damage(dano)


## Qué hacer con un rescate que se acaba de pedir: `[rescatar, cobrar_el_daño]`.
##
## La gracia quita el DAÑO, no el rescate. Es una distinción que costó cara:
## saltándose el rescate entero, quien tocaba la lava dentro de la ventana de
## gracia no volvía a ningún sitio —seguía hundiéndose— y terminaba de pie sobre
## la cáscara del volcán, bajo el cráter, sin lava que lo alcanzara ni altura
## suficiente para contar como caída. De ahí no se sale salvo cerrando el juego,
## que es peor que el bucle de muertes que la gracia venía a evitar. Un rescate
## nunca puede dejarte tirado; el daño repetido sí.
##
## Vive aparte del rescate en sí para poder probar la regla sin montar el mundo,
## la cámara y el HUD, que es lo que hace falta para ejecutar `_respawn`.
func decidir_rescate() -> Array:
	if _resetting or _espera_de_rescate > 0.0:
		return [false, false]
	return [true, _gracia <= 0.0]


## Lo mínimo entre dos rescates seguidos.
##
## Sin esto, algo que comprueba cada cuadro —la lava— dispararía un rescate por
## cuadro mientras dure el contacto. Es corto a propósito: sólo evita la ráfaga,
## no deja a nadie sin rescatar.
const RESCATE_MINIMO := 0.4
var _espera_de_rescate := 0.0


## Lo más que puede haber entre un punto seguro y el suelo, en metros.
##
## Cuatro metros es una caída que se aguanta. Más que eso no es un sitio donde
## reaparecer, es un sitio desde donde caerse.
const SUELO_BAJO_EL_PUNTO_SEGURO := 4.0


## Comprueba que se pueda reaparecer ahí, y si no, devuelve el principio de la
## zona.
##
## PASA DE VERDAD: el `CheckpointBifurcacion` del Ojos del Salado está a 110 m y
## el suelo más cercano queda 23 m por debajo. Reaparecías ahí, caías a la lava,
## la lava te devolvía al mismo punto y vuelta a empezar: una caída infinita de
## la que no se sale.
##
## Se comprueba acá y no moviendo el marcador porque el fallo es de una clase
## que se repite —un punto de reaparición mal colocado— y en un nivel que se
## sigue editando a mano va a volver a pasar. Un marcador en el aire ahora sólo
## cuesta reaparecer más atrás, no la partida.
func _con_suelo_debajo(pos: Vector3) -> Vector3:
	var quien := active_character()
	if quien == null or not quien.is_inside_tree():
		return pos
	var esp: PhysicsDirectSpaceState3D = quien.get_world_3d().direct_space_state
	if esp == null:
		return pos
	var q := PhysicsRayQueryParameters3D.create(
		pos + Vector3.UP, pos + Vector3.DOWN * SUELO_BAJO_EL_PUNTO_SEGURO)
	q.collision_mask = 1
	if not esp.intersect_ray(q).is_empty():
		return pos
	var respaldo := _principio_de_la_zona()
	if respaldo == Vector3.INF:
		return pos                # sin alternativa, mejor eso que nada
	push_warning("Game: el punto seguro %s está en el aire; se usa el principio de la zona" % str(pos))
	return respaldo


## Dónde reaparecer al morir en la región cargada, si la escena lo declara.
##
## Es un `Marker3D` llamado `PuntoDeRescate`, puesto donde se quiera dentro de
## la escena del interior. Se busca en profundidad, así que da igual de qué nodo
## cuelgue: se puede arrastrar a donde haga falta.
##
## Devuelve INF si esa escena no lo tiene, y entonces manda el punto de siempre.
const MARCADOR_DE_RESCATE := "PuntoDeRescate"


func _punto_de_rescate() -> Vector3:
	if _region_holder == null:
		return Vector3.INF
	for r in _region_holder.get_children():
		var m := r.find_child(MARCADOR_DE_RESCATE, true, false) as Node3D
		if m != null:
			return m.global_position
	return Vector3.INF


## El PlayerSpawn de la región cargada, o INF si no hay.
func _principio_de_la_zona() -> Vector3:
	if _region_holder != null:
		for r in _region_holder.get_children():
			var sp := r.find_child("PlayerSpawn", true, false) as Node3D
			if sp != null:
				return sp.global_position
	if world != null and _interior == "":
		var z: String = world.current_zone()
		if z != "":
			var p: Vector3 = world.spawn_point(z)
			if p != Vector3.INF:
				return p
	return Vector3.INF


## Segundos de invulnerabilidad justo después de reaparecer.
##
## Es el corta-bucles. Reaparecer y volver a morir en el acto encadenaba muertes
## sin fin: pasó en el cráter del Isluga, donde a los personajes de los lados se
## los colocaba sobre el vacío y caían a la lava, que los devolvía al mismo
## punto, que los volvía a tirar. Aquello ya está arreglado en `_si_hay_suelo`,
## pero una muerte en bucle es lo peor que le puede pasar a quien está probando
## el juego —no hay forma de salir salvo cerrar la ventana—, así que además hay
## una red: durante este rato, nada te vuelve a matar.
const GRACIA_TRAS_REAPARECER := 1.5

## Lo que queda de esa gracia.
var _gracia := 0.0


func _respawn(motivo := "Caíste — volvés al último punto seguro") -> void:
	_resetting = true
	_gracia = GRACIA_TRAS_REAPARECER
	jugador_reaparecio.emit()
	if hud and hud.has_method("show_banner"):
		hud.show_banner(motivo)

	var destino := _respawn_pos
	# Un interior puede declarar DÓNDE se reaparece al morir, aparte de por
	# dónde se entra.
	#
	# No son lo mismo: al Isluga se llega por la boca del cráter, pero caerse a
	# la lava y volver a la entrada obliga a rehacer la subida entera. Con el
	# marcador se reaparece donde tenga sentido —al pie del tramo en el que
	# estabas—, y se coloca arrastrándolo en el editor, sin tocar código.
	var rescate := _punto_de_rescate()
	if rescate != Vector3.INF:
		destino = rescate
	elif _interior == "":
		# Preferir el spawn de la zona en la que estaba parado
		var z: String = world.current_zone() if world else ""
		if z != "":
			var sp: Vector3 = world.spawn_point(z)
			if sp != Vector3.INF:
				destino = sp
	_colocar_en(_con_suelo_debajo(destino))

	for c in party:
		if c.has_method("set_ai_mode"):
			c.set_ai_mode(true)
		if c.has_method("heal"):
			c.heal(c.max_health)
	_apply_active()
	if hud and hud.has_method("clear_banner"):
		get_tree().create_timer(1.5).timeout.connect(func() -> void:
			# Se busca de nuevo en vez de capturarlo: una lambda que captura un nodo
			# y sobrevive a que lo liberen da "Lambda capture was freed", aunque se
			# compruebe is_instance_valid antes de usarlo.
			var h := get_tree().get_first_node_in_group("hud")
			if h != null and h.has_method("clear_banner"):
				h.clear_banner())
	_resetting = false


func _unhandled_input(event: InputEvent) -> void:
	# Mirar con el ratón: sin botones, moverlo gira la cámara.
	#
	# Sólo cuando el puntero está capturado. Ésa es la comprobación que hace
	# falta: con la pausa abierta o alguien hablando el puntero vuelve a ser un
	# puntero, y entonces mover el ratón para pulsar «Reanudar» no puede estar
	# girando la cámara por detrás.
	if camara_sigue_al_raton and event is InputEventMouseMotion \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mirar_con_el_raton((event as InputEventMouseMotion).relative)
		return
	# Rueda = zoom, clic derecho (arrastrar) = orbitar. Con `camara_fija` no
	# responde a ninguna de las dos: la distancia la pone el juego.
	if camara_fija:
		return
	if event.is_action_pressed("cam_zoom_in"):
		cam_distance = clampf(cam_distance - cam_zoom_step, cam_zoom_min, cam_zoom_max)
	elif event.is_action_pressed("cam_zoom_out"):
		cam_distance = clampf(cam_distance + cam_zoom_step, cam_zoom_min, cam_zoom_max)
	elif event.is_action_pressed("cam_orbit"):
		_cam_rotating = true
	elif event.is_action_released("cam_orbit"):
		_cam_rotating = false
	elif event is InputEventMouseMotion and _cam_rotating:
		_mirar_con_el_raton((event as InputEventMouseMotion).relative)


## Hasta dónde se puede subir y bajar el plano.
##
## Nunca por encima de la horizontal: pasado ese punto la cámara se mete por
## debajo del personaje y se ve el interior del suelo.
const PICADO_MAX := -0.05
const PICADO_MIN := -1.40


func _mirar_con_el_raton(rel: Vector2) -> void:
	# Durante una escena guionada manda el guion. Girar acá dejaría el giro
	# guardado y la cámara daría un salto al devolverte el control.
	if _cam_override != null:
		return
	_cam_yaw -= rel.x * cam_rotate_speed
	_cam_pitch = clampf(_cam_pitch - rel.y * cam_rotate_speed, PICADO_MIN, PICADO_MAX)


## Capturar o soltar el puntero, según haya algo con lo que haga falta apuntar.
##
## Se decide cada cuadro en vez de al abrir y cerrar cada pantalla. Es más
## barato de razonar y se corrige solo: cualquier menú que alguien añada mañana
## y olvide avisar queda cubierto igual, y quedarse con el ratón capturado
## delante de un menú es de las cosas más molestas que le pueden pasar a quien
## está jugando —no hay forma de pulsar nada—.
func _mandar_el_raton() -> void:
	if not camara_sigue_al_raton:
		return
	var quiero := Input.MOUSE_MODE_CAPTURED
	if get_tree().paused or _hablando or _hay_pantalla_encima():
		quiero = Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != quiero:
		Input.mouse_mode = quiero


## Al salir de la partida el puntero vuelve, siempre.
##
## `Input.mouse_mode` es global y sobrevive al cambio de escena: sin esto, volver
## al menú desde la pausa dejaba el título con el ratón capturado y no había
## forma de pulsar «JUGAR». Va en `_exit_tree` y no en el botón de volver porque
## de la partida se sale por más de una puerta —el menú, el cierre del
## prototipo, reiniciar— y todas pasan por acá.
func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _hay_pantalla_encima() -> bool:
	return alguna_visible(get_tree().get_nodes_in_group("pantalla_modal"))


## Si alguna de esas pantallas está a la vista.
##
## Se mira la PROPIEDAD `visible`, no la clase. Una pantalla puede ser un
## Control o un CanvasLayer, y CanvasLayer tiene `visible` pero NO es un
## CanvasItem: con `is CanvasItem` la de logros no contaba y el cierre del
## prototipo salía con el ratón capturado, sin puntero para pulsar «Volver al
## título».
##
## Estática y con la lista por parámetro para poder probarla: montar un Game
## entero en un test arrastra el mundo, el HUD y el party.
static func alguna_visible(nodos: Array) -> bool:
	for n in nodos:
		if "visible" in n and bool(n.get("visible")):
			return true
	return false


## Hace que la cámara siga a otro nodo (un NPC en una escena guionada) en vez
## del personaje activo. Con duration > 0 vuelve sola al jugador al terminar.
## `distancia` en 0 deja la de siempre; con un valor menor la cámara se acerca,
## y `altura` sube el punto al que mira —1.5 es el pecho, 1.7 la cara—.
func focus_camera_on(node: Node3D, duration := 0.0, distancia := 0.0, altura := 1.5) -> void:
	_cam_override = node
	_cam_dist_deseada = distancia
	_cam_alto = altura
	if duration > 0.0:
		get_tree().create_timer(duration).timeout.connect(func() -> void:
			if _cam_override == node:
				clear_camera_focus())


func clear_camera_focus() -> void:
	_cam_override = null
	_cam_dist_deseada = 0.0
	_cam_alto = 1.5


func _update_camera() -> void:
	var target := active_character()
	if is_instance_valid(_cam_override):
		target = _cam_override
	if target == null or _camera == null:
		return
	_cam_focus = _cam_focus.lerp(target.global_position + Vector3(0.0, _cam_alto, 0.0), cam_follow_lerp)
	var quiero: float = _cam_dist_deseada if _cam_dist_deseada > 0.0 else cam_distance
	if _cam_dist_actual < 0.0:
		_cam_dist_actual = quiero
	_cam_dist_actual = lerpf(_cam_dist_actual, quiero, cam_follow_lerp)
	var offset := Vector3(0.0, 0.0, _cam_dist_actual)
	offset = offset.rotated(Vector3.RIGHT, _cam_pitch)
	offset = offset.rotated(Vector3.UP, _cam_yaw)
	_camera.global_position = _cam_wall_check(_cam_focus + offset)
	_camera.look_at(_cam_focus, Vector3.UP)


## Raycast desde el foco hacia la posición deseada. Si hay geometría en el camino,
## mueve la cámara hasta el punto de impacto (con un pequeño margen) para que nunca
## atraviese paredes ni techo.
func _cam_wall_check(desired: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(_cam_focus, desired)
	params.collision_mask = 1   # solo entorno (layer 1); jugadores/enemigos ignorados
	var hit := space.intersect_ray(params)
	if hit.is_empty():
		return desired
	# Retroceder 0.25 m desde el punto de impacto para evitar z-fighting
	return hit["position"] - (desired - _cam_focus).normalized() * 0.25


## Compat: cambia dejando al otro en IA de combate.
func swap_character() -> void:
	_swap(true)


func _swap(combat: bool) -> void:
	if party.size() <= 1:
		return
	var leaving := active_character()
	active_index = (active_index + 1) % party.size()
	_apply_active()
	if leaving != null and leaving.has_method("set_ai_mode"):
		leaving.set_ai_mode(combat)


func add_party_member(character: Node) -> void:
	if character in party:
		return
	if "hud" in character:
		character.hud = hud
	party.append(character)
	_apply_active()
	if hud and hud.has_method("show_swap_hint"):
		hud.show_swap_hint(party.size() > 1)


func remove_party_member(character: Node) -> void:
	party.erase(character)
	if active_index >= party.size():
		active_index = 0
	_apply_active()
	if hud and hud.has_method("show_swap_hint"):
		hud.show_swap_hint(party.size() > 1)


func active_character() -> Node:
	return party[active_index] if active_index < party.size() else null


func _apply_active() -> void:
	for i in party.size():
		party[i].set_active(i == active_index)
	var act := active_character()
	if act != null and hud != null:
		hud.bind_player(act)


## Reubica a todo el party cerca del spawn de la región.
## use_travel_spawn=true: prefiere TravelSpawn (fast-travel desde el mapa).
## use_travel_spawn=false: usa siempre PlayerSpawn (salida normal de zona).
func _move_to_spawn(region: Node, use_travel_spawn: bool = false) -> void:
	if region == null:
		return
	# Se busca en TODO el árbol de la región, no sólo entre sus hijos directos.
	#
	# Antes era `get_node_or_null("PlayerSpawn")`, que exige que el marcador
	# cuelgue de la raíz. En cuanto el Isluga agrupó su contenido bajo un nodo
	# `Crater`, el marcador dejó de encontrarse: la función salía sin hacer nada
	# y la party se quedaba donde estuviera, que al entrar era el aire. Buscando
	# en profundidad el marcador se puede arrastrar a donde sea dentro de la
	# escena y sigue valiendo.
	var spawn: Node3D = null
	if use_travel_spawn:
		spawn = region.find_child("TravelSpawn", true, false) as Node3D
	if spawn == null:
		spawn = region.find_child("PlayerSpawn", true, false) as Node3D
	if spawn == null:
		push_warning("Game: la región %s no trae PlayerSpawn" % region.name)
		return
	# El RUMBO del marcador también cuenta, no sólo su posición.
	#
	# Sin esto la party conserva el rumbo que traía de antes, y al cruzar una
	# puerta quedás mirando justo hacia afuera: entrabas al santuario de espaldas
	# a la nave. Un Marker3D sin rotar mira a -Z, que es la convención de Godot.
	var yaw: float = spawn.global_rotation.y
	var offsets := [Vector3.ZERO, Vector3(2.5, 0, 0), Vector3(-2.5, 0, 0)]
	for i in party.size():
		var off: Vector3 = offsets[i] if i < offsets.size() else Vector3(0, 0, i * 2.0)
		party[i].global_position = spawn.global_position + off
		party[i].velocity = Vector3.ZERO
		if party[i].has_method("orientar_hacia"):
			party[i].orientar_hacia(yaw)

	# Y la cámara detrás, mirando lo mismo. Con _cam_yaw = 0 se pone en +Z y
	# mira hacia -Z, o sea que coincide con el marcador sin rotar.
	_cam_yaw = yaw

	# Acabar de llegar a una región la convierte en el último punto seguro.
	#
	# Faltaba: entrar a un interior colocaba al party pero dejaba `_respawn_pos`
	# con el valor del mundo abierto, así que caerse dentro del cráter del
	# Isluga te escupía al otro lado del mapa en vez de devolverte arriba.
	_respawn_pos = spawn.global_position


## Punto de entrada único para "ir a X". Enruta según el tipo de destino:
##   · INTERIOR (la Mina)      -> carga la escena aparte, con fundido.
##   · zona del mundo abierto  -> si venías de un interior, sale; si ya estabas
##     en el mundo, es un teletransporte (viaje rápido del mapa de Chile).
## use_travel_spawn elige el marcador TravelSpawn (junto al guardián).
func go_to(region_name: String, use_travel_spawn: bool = false) -> void:
	if hud:
		if hud.has_method("clear_hint"):
			hud.clear_hint()
		if hud.has_method("clear_banner"):
			hud.clear_banner()

	if region_name in INTERIORES:
		await enter_interior(region_name, use_travel_spawn)
	elif _interior != "":
		_volviendo_de = _interior
		await exit_interior(region_name, use_travel_spawn)
		_volviendo_de = ""
	else:
		await teleport_to(region_name, use_travel_spawn)

	for i in party.size():
		if i != active_index and party[i].has_method("set_ai_mode"):
			party[i].set_ai_mode(true)


## Entra a un interior: oculta el mundo y carga la escena en el holder.
## Cierre del prototipo. Lo dispara GameManager al caer el noveno logro.
func _al_superar_el_prototipo() -> void:
	if _cierre_mostrado:
		return
	_cierre_mostrado = true
	get_tree().create_timer(ESPERA_CIERRE).timeout.connect(
		func() -> void:
			if is_instance_valid(self):
				PANTALLA_LOGROS.mostrar(self))


func enter_interior(id: String, use_travel_spawn := false) -> void:
	# El sitio del mundo al que se vuelve SÓLO se anota viniendo de fuera.
	#
	# `_pos_antes_interior` quiere decir "dónde estaba en el mundo abierto antes
	# de meterme adentro". Viajando de un interior a OTRO —con el mapa del
	# Guardián, por ejemplo— se anotaba la posición dentro del interior anterior,
	# que son coordenadas de otra escena: el Ojos del Salado está a 110 m de
	# altura, así que al salir del Isluga te dejaba en la cima del volcán en vez
	# de en su entrada.
	if _interior == "":
		_pos_antes_interior = active_character().global_position if active_character() else _respawn_pos
	await TravelManager.travel_to_then(_region_holder, id, func(r: Node) -> void:
		_interior = id
		if world:
			world.visible = false
			world.process_mode = Node.PROCESS_MODE_DISABLED
		# El interior se construye recién ahora, así que se lo viste acá.
		if r != null:
			TOON_SKIN.new().aplicar(r, ajustes_toon)
		_aplicar_ambiente_interior(r)
		# El viaje rÃ¡pido entra por el TravelSpawn, junto al guardiÃ¡n. Antes este
		# argumento se perdÃ­a por el camino y el mapa te dejaba en el PlayerSpawn,
		# o sea al principio del puzle: habÃ­a que rehacerlo entero para volver a
		# hablar con Ã©l.
		_move_to_spawn(r, use_travel_spawn)
		_consejo_de_la_zona(id))


## Volcanes: se explica la [T] al llegar.
##
## Los dos volcanes son los únicos sitios donde hace falta SEPARAR al party —una
## palanca de un lado y la plataforma del otro—, y el juego no lo dice en ningún
## lado: la [T] aparece en los controles del menú y nadie se acuerda a los veinte
## minutos. Se cuenta donde se necesita, la primera vez que se pisa cada volcán.
const CONSEJOS_DE_ZONA := {
	"Isluga": "Pulsá [T] para dejar al otro quieto y que cada uno siga su camino. Volvé a pulsarla para que te siga.",
	"OjosDelSalado": "Pulsá [T] para dejar al otro quieto y que cada uno siga su camino. Volvé a pulsarla para que te siga.",
}

var _consejos_dados := {}


func _consejo_de_la_zona(id: String) -> void:
	if _consejos_dados.has(id) or not CONSEJOS_DE_ZONA.has(id):
		return
	if party.size() < 2:
		return                     # sin compañero la [T] no hace nada
	_consejos_dados[id] = true
	if hud != null and hud.has_method("consejo"):
		hud.consejo(String(CONSEJOS_DE_ZONA[id]), 9.0)


## Ambiente de afuera, guardado para devolverlo al salir de un interior.
var _env_exterior: Environment = null


## Un interior puede traer su propio ambiente y apagar el sol.
##
## Es OPCIONAL a propósito: el que no declare `ambiente` se queda con el de
## afuera. La Iglesia, por ejemplo, no tiene luces propias, así que a oscuras
## quedaría negra.
func _aplicar_ambiente_interior(r: Node) -> void:
	if r == null or not ("ambiente" in r):
		return
	var amb: Environment = r.ambiente
	if amb == null:
		return
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we == null:
		return
	if _env_exterior == null:
		_env_exterior = we.environment
	we.environment = amb

	# El sol también, o seguiría entrando luz direccional por todas partes: una
	# luz direccional no la para ninguna pared, sólo su sombra.
	var sol := get_node_or_null("Sun") as DirectionalLight3D
	if sol != null:
		sol.visible = false


func _restaurar_ambiente() -> void:
	var sol := get_node_or_null("Sun") as DirectionalLight3D
	if sol != null:
		sol.visible = true
	if _env_exterior == null:
		return
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null:
		we.environment = _env_exterior
	_env_exterior = null


## Sale del interior de vuelta al mundo, aterrizando en la zona indicada.
func exit_interior(zona: String, use_travel_spawn := false) -> void:
	await TravelManager.fade_then(func() -> void:
		TravelManager.clear_region(_region_holder)
		_interior = ""
		_restaurar_ambiente()
		if world:
			world.visible = true
			world.process_mode = Node.PROCESS_MODE_INHERIT
		# Al salir de la Mina se reaparece frente a su boca (al este del
		# poblado), no en el centro del pueblo: entrás y salís por el mismo lado.
		# Se sale por la puerta del interior que se ABANDONA, y si esa puerta es
		# de la otra región, se cambia de mundo antes de colocar a nadie.
		#
		# El portal del guardián te lleva de un volcán al otro, pero sólo cambia
		# la escena del interior: el mundo de debajo sigue siendo el que había.
		# Y `_pos_antes_interior` guarda por dónde entraste al PRIMER volcán, que
		# tras cruzar ya no es el que estás dejando. Saliendo del Isluga —que es
		# de Tarapacá— aparecías en Atacama, con la misión pidiéndote volver a la
		# mina, que WorldRoot sólo construye en Tarapacá.
		var cambie_de_mundo := false
		if _volviendo_de in INTERIORES_DE_PUERTA and _puerta_hacia(_volviendo_de) == null:
			_cambiar_de_mundo()
			cambie_de_mundo = true

		# Lo primero, el marcador que hayas puesto para esta salida. Manda sobre
		# todo lo demás: el "pie de la puerta" es una cuenta, y en una ladera la
		# cuenta se equivoca.
		var destino := _salida_puesta_a_mano(_volviendo_de)
		if destino == Vector3.INF and world:
			if _volviendo_de == "Mina" and world.has_method("mine_mouth"):
				destino = world.mine_mouth()
			elif cambie_de_mundo:
				# Cambiamos de región: `_pos_antes_interior` es una coordenada
				# del mundo que acabamos de descargar y no vale para nada acá.
				destino = _al_pie_de(_puerta_hacia(_volviendo_de))
			elif _volviendo_de in INTERIORES_DE_PUERTA:
				# Salís exactamente por donde entraste. Sin esto, cruzar la
				# puerta de la iglesia te escupiría en el PlayerSpawn de la
				# zona, o sea al otro lado de la plaza.
				destino = _pos_antes_interior
			else:
				var marcador := "TravelSpawn" if use_travel_spawn else "PlayerSpawn"
				destino = world.spawn_point(zona, marcador)
		_colocar_en(destino if destino != Vector3.INF else _pos_antes_interior))


## La puerta que lleva a ese interior en el mundo CARGADO, o null si no está.
##
## Null quiere decir "esa puerta es de la otra región": el catálogo de zonas es
## de todo el juego, pero el mapa está partido en dos mundos y cada puerta vive
## en el suyo —el Isluga en Tarapacá, el Ojos del Salado en Atacama—.
func _puerta_hacia(id: String) -> Node3D:
	return _buscar_puerta(world, id) if world != null else null


## Lo mismo, para quien no sea Game. Lo usa la guía de objetivos para saber a
## qué puerta ponerle el marcador cuando la misión es «ve a tal zona».
func puerta_hacia(id: String) -> Node3D:
	return _puerta_hacia(id)


## Dónde queda una zona del MUNDO ABIERTO, o INF si no existe.
##
## Las zonas al aire libre no tienen puerta: se llega caminando. Para señalarlas
## no hay un nodo al que colgarle el marcador, así que se devuelve el sitio y la
## guía se encarga de plantar algo ahí.
func sitio_de_zona(id: String) -> Vector3:
	if world == null or not world.has_zone(id):
		return Vector3.INF
	return world.spawn_point(id)


func _buscar_puerta(n: Node, id: String) -> Node3D:
	if n is Node3D and "target_region" in n and String(n.get("target_region")) == id:
		return n as Node3D
	for h in n.get_children():
		var x := _buscar_puerta(h, id)
		if x != null:
			return x
	return null


## Dónde aparecés al salir de un interior, si lo pusiste vos.
##
## Es un Marker3D llamado `SalidaDeIsluga`, `SalidaDeOjosDelSalado`… puesto en el
## mundo al que salís, donde te dé la gana. Existe porque calcular el sitio no
## alcanza: la puerta del Isluga está en una ladera y la cuenta la dejaba
## dieciséis metros por debajo del terreno, o sea dentro del cerro y bajo el
## agua. Un marcador se ve en el editor y se arrastra.
func _salida_puesta_a_mano(id: String) -> Vector3:
	if world == null:
		return Vector3.INF
	var n := _buscar_por_nombre(world, "SalidaDe" + id)
	return n.global_position if n != null else Vector3.INF


func _buscar_por_nombre(n: Node, nombre: String) -> Node3D:
	if n is Node3D and String(n.name) == nombre:
		return n as Node3D
	for h in n.get_children():
		var x := _buscar_por_nombre(h, nombre)
		if x != null:
			return x
	return null


## El pie de una puerta.
##
## Su origen está en el CENTRO del disparador, que en las subidas a los volcanes
## queda cuatro metros en el aire. Restar media altura era la cuenta de antes y
## sólo acierta en terreno plano: en la ladera del Isluga el suelo está a 15 m y
## la cuenta daba −1, con el party apareciendo dentro del cerro.
##
## Así que la altura se BUSCA con un rayo y sólo se cae a la cuenta si no
## encuentra suelo.
func _al_pie_de(puerta: Node3D) -> Vector3:
	if puerta == null:
		return Vector3.INF
	var alto := 0.0
	if "tamano" in puerta:
		alto = float((puerta.get("tamano") as Vector3).y)
	var pie: Vector3 = puerta.global_position - Vector3(0.0, alto * 0.5, 0.0)
	# El espacio se pide a la PUERTA y no a este nodo: en los tests la puerta
	# está en el árbol y el Game no, y pedírselo a un nodo suelto es un error de
	# motor, no un null.
	if not puerta.is_inside_tree():
		return pie
	var esp := puerta.get_world_3d().direct_space_state
	if esp == null:
		return pie
	var q := PhysicsRayQueryParameters3D.create(
		puerta.global_position + Vector3.UP * 40.0,
		puerta.global_position + Vector3.DOWN * 60.0)
	q.collision_mask = 1
	var r := esp.intersect_ray(q)
	return r["position"] if not r.is_empty() else pie


## Descarga el mundo actual y monta el otro, dejándolos intercambiados.
##
## Lo usan el bus y la salida de un volcán que pertenece a la otra región. No
## coloca a nadie: de eso se encarga quien llama, que es el único que sabe dónde
## corresponde aparecer.
func _cambiar_de_mundo() -> void:
	if mundo_alterno == null:
		return
	var destino: PackedScene = mundo_alterno
	mundo_alterno = escena_del_mundo
	escena_del_mundo = destino
	if is_instance_valid(world):
		# remove_child antes de liberar: queue_free es diferido, y si no se saca
		# del árbol quedan DOS mundos en el grupo "world" durante un cuadro. Todo
		# lo que busca el mundo por grupo elegiría cualquiera.
		remove_child(world)
		world.queue_free()
	world = escena_del_mundo.instantiate()
	add_child(world)


## Nombre de la región a la que lleva el bus. Lo usa WorldRoot para el cartel.
func nombre_del_otro_mundo() -> String:
	if mundo_alterno == null:
		return ""
	return NOMBRES_DE_MUNDO.get(mundo_alterno.resource_path, "la otra región")


## Viaje en bus: descarga este mundo entero y monta el otro.
##
## No se parece a nada de lo que ya había. `enter_interior` sólo ESCONDE el
## mundo y carga la escena chica en el holder; acá el mundo se va del todo,
## porque el destino es otra escena con su propio terreno.
##
## `bus` es el nombre del autobús al que te subiste. Del otro lado se busca el
## que se llama igual, así que subirse al bus3 te deja junto al bus3 de allá.
func viajar_en_bus(bus: String) -> void:
	if mundo_alterno == null:
		return
	await TravelManager.fade_then(func() -> void:
		# El prompt del bus que se está por liberar: si no se limpia, el cartel
		# queda pegado en el HUD apuntando a un nodo que ya no existe.
		for c in party:
			if c.has_method("clear_interactable"):
				c.clear_interactable(c.get("_interactable"))
		if hud and hud.has_method("hide_prompt"):
			hud.hide_prompt()

		# Intercambio: al que voy pasa a ser el actual, y el que dejo queda de
		# alterno. Con eso el viaje de vuelta funciona sin nada más.
		var destino: PackedScene = mundo_alterno
		_cambiar_de_mundo()

		# El bus cambia el MUNDO entero, no una región: no pasa por
		# TravelManager y su señal `region_changed` nunca se emite, así que la
		# cadena de misiones no se enteraba de que habías llegado a Atacama. El
		# nombre sale de la escena de destino, que es el dato que ya se maneja.
		if destino != null and destino.resource_path.contains("Atacama"):
			Misiones.hecho("viajar")

		_interior = ""
		_bajar_del_bus(bus))


## Deja al party junto al bus homólogo, un poco más allá y mirando al poblado.
func _bajar_del_bus(bus: String) -> void:
	var nodo := _buscar_bus(bus)
	if nodo == null:
		_colocar_en(world.spawn_point("Poblado"))
		return

	# Hacia dónde queda el pueblo. Se mide contra el nodo del Poblado en vez de
	# fijar un rumbo: los dos mundos van a divergir, y esto sigue valiendo.
	var hacia := Vector3.FORWARD
	var poblado := world.get_node_or_null("Poblado") as Node3D
	if poblado != null:
		var d: Vector3 = poblado.global_position - nodo.global_position
		d.y = 0.0
		if d.length() > 0.01:
			hacia = d.normalized()

	_colocar_en(nodo.global_position + hacia * BAJADA_DEL_BUS)
	_mirar_hacia(hacia)


## El autobús que se llama así en el mundo recién montado; si no está, cualquiera.
##
## Se busca en TODO el árbol y no entre los hijos de la raíz: en WorldAtacama los
## buses se agruparon dentro de "Terminal de Buses", y buscando arriba no
## aparecía ninguno. Sin bus, el viaje caía al respaldo y te dejaba plantado en
## medio del poblado en vez de bajarte en el terminal.
func _buscar_bus(nombre: String) -> Node3D:
	var buses := _buses_de(world)
	for b: Node3D in buses:
		if b.name == nombre:
			return b
	if buses.is_empty():
		return null
	return buses[0]


func _buses_de(desde: Node) -> Array:
	var encontrados: Array = []
	for hijo in desde.get_children():
		if hijo is Node3D and String(hijo.name).begins_with("bus"):
			encontrados.append(hijo)
			continue
		encontrados.append_array(_buses_de(hijo))
	return encontrados


## Gira la cámara para que mire en esa dirección.
##
## Con yaw 0 la cámara se planta en +Z del foco y mira hacia -Z (ver
## _update_camera), así que el ángulo que deja la vista en `dir` es
## atan2(-dir.x, -dir.z).
func _mirar_hacia(dir: Vector3) -> void:
	if dir.length() < 0.01:
		return
	_cam_yaw = atan2(-dir.x, -dir.z)
	var act := active_character()
	if act != null:
		_cam_focus = act.global_position + Vector3(0.0, _cam_alto, 0.0)
	_update_camera()


## Teletransporte dentro del mundo abierto (viaje rápido de los Guardianes).
## No hay carga de escena: sólo fundido y reubicación.
func teleport_to(zona: String, use_travel_spawn := false) -> void:
	if world == null or not world.has_zone(zona):
		push_warning("Game: zona desconocida para teletransporte '%s'" % zona)
		return
	var marcador := "TravelSpawn" if use_travel_spawn else "PlayerSpawn"
	var destino: Vector3 = world.spawn_point(zona, marcador)
	await TravelManager.fade_then(func() -> void: _colocar_en(destino))
