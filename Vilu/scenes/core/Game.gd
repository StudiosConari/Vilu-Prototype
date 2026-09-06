extends Node3D

## Raíz jugable del MVP. Contenedor persistente: entorno, luz, un holder de
## región y el PARTY de dos protagonistas (melee + arquero), intercambiables
## con R. Solo el activo recibe input y tiene cámara current. Ambos persisten
## entre regiones (se reubican en el spawn al viajar).

const PLAYER_SCENE := preload("res://scenes/actors/Player.tscn")
const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")
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
const INTERIORES := ["Mina", "Final", "Iglesia", "Isluga", "OjosDelSalado"]

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
@export var cam_distance := 18.0
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
	# El cierre se engancha una sola vez y vive lo que viva la partida: el último
	# logro puede caer en cualquier zona, no sólo en la mina.
	if not GameManager.prototipo_superado.is_connected(_al_superar_el_prototipo):
		GameManager.prototipo_superado.connect(_al_superar_el_prototipo)
	_spawn_party_open(start)

	# Arrancar en un interior (Mina/Final) desde el selector de debug.
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
		party[i].global_position = pos + off
		party[i].velocity = Vector3.ZERO
	_respawn_pos = pos
	_pegar_la_camara(pos)


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


func _process(_delta: float) -> void:
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
	if _resetting:
		return
	_respawn(motivo)
	if dano <= 0.0:
		return
	for c in party:
		if is_instance_valid(c) and c.has_method("take_damage"):
			c.take_damage(dano)


func _respawn(motivo := "Caíste — volvés al último punto seguro") -> void:
	_resetting = true
	jugador_reaparecio.emit()
	if hud and hud.has_method("show_banner"):
		hud.show_banner(motivo)

	var destino := _respawn_pos
	if _interior == "":
		# Preferir el spawn de la zona en la que estaba parado
		var z: String = world.current_zone() if world else ""
		if z != "":
			var sp: Vector3 = world.spawn_point(z)
			if sp != Vector3.INF:
				destino = sp
	_colocar_en(destino)

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
	# Cámara: rueda = zoom, clic derecho (arrastrar) = orbitar alrededor del activo.
	if event.is_action_pressed("cam_zoom_in"):
		cam_distance = clampf(cam_distance - cam_zoom_step, cam_zoom_min, cam_zoom_max)
	elif event.is_action_pressed("cam_zoom_out"):
		cam_distance = clampf(cam_distance + cam_zoom_step, cam_zoom_min, cam_zoom_max)
	elif event.is_action_pressed("cam_orbit"):
		_cam_rotating = true
	elif event.is_action_released("cam_orbit"):
		_cam_rotating = false
	elif event is InputEventMouseMotion and _cam_rotating:
		_cam_yaw -= event.relative.x * cam_rotate_speed
		_cam_pitch = clampf(_cam_pitch - event.relative.y * cam_rotate_speed, -1.4, -0.15)


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
##   · INTERIOR (Mina, Final)  -> carga la escena aparte, con fundido.
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
		_move_to_spawn(r, use_travel_spawn))


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

		var destino := Vector3.INF
		if world:
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


func _buscar_puerta(n: Node, id: String) -> Node3D:
	if n is Node3D and "target_region" in n and String(n.get("target_region")) == id:
		return n as Node3D
	for h in n.get_children():
		var x := _buscar_puerta(h, id)
		if x != null:
			return x
	return null


## El pie de una puerta: su origen está en el CENTRO del disparador, que en las
## subidas a los volcanes queda cuatro metros en el aire. Se baja media altura
## para dejar al party en el suelo en vez de caído desde el techo del área.
func _al_pie_de(puerta: Node3D) -> Vector3:
	if puerta == null:
		return Vector3.INF
	var alto := 0.0
	if "tamano" in puerta:
		alto = float((puerta.get("tamano") as Vector3).y)
	return puerta.global_position - Vector3(0.0, alto * 0.5, 0.0)


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
