extends Node3D

## Zona Mina Corrupta — 4 secciones + persecución del Chupacabras.
##
## S1 (Z=0→-15): entrada, viga baja + pilar
## S2 (Z=-15→-38): sala de combate, 5 mineros normales
## S3 (Z=-38→-56): pasillo de garras, diálogo y sonido inquietante
## S4 (Z=-59→-76): cámara del nido, Chupacabras a 8.5 m/s
##
## Durante la huida: 8 mineros normales + 4 bloques de derrumbe del techo.

## Ambiente propio de la cueva. Game lo aplica al entrar y apaga el sol; al
## salir devuelve el de afuera. Ver Game._aplicar_ambiente_interior.
##
## Sin esto la mina se iluminaba con el ambiente del mundo abierto y parecía un
## exterior: las 23 antorchas y linternas no se notaban porque no había
## oscuridad que llenar. Dejalo vacío y vuelve a verse como antes.
@export var ambiente: Environment = preload("res://scenes/core/ambiente_mina.tres")

## Los mineros corruptos: el enemigo común de la mina, en el combate y en la
## huida. Antes salían de EnemyNormal, la cápsula de greybox, que ya no existe.
const MINERO          := preload("res://scenes/enemies/MineroCorrupto.tscn")
const CHUPACABRAS     := preload("res://models/personaje/chupacabras.glb")
## El Chupacabras COMO ENEMIGO, para el duelo final. Distinto del glb de arriba,
## que en la huida es sólo un cuerpo con movimiento propio: en el duelo hace
## falta vida, telegrafiado y muerte, o sea Enemy.gd.
const CHUPACABRAS_JEFE := preload("res://scenes/enemies/Chupacabras.tscn")
const ENCAJAR         := preload("res://scenes/core/EncajarModelo.gd")
const TOON_SKIN       := preload("res://scenes/core/ToonSkin.gd")
const BALLOON         := "res://scenes/ui/GloboDeDialogo.tscn"
const TALISMAN_SCR    := preload("res://scenes/actors/TalismanFragment.gd")

const DIALOGUE_GARRAS := "~ start
Emilia: ¿Escuchaste eso?
Benjamín: Sí... ¿Y esas marcas en las paredes? Son garras.
Emilia: Sea lo que sea, está muy cerca.
=> END
"

@export var miner_color := Color(0.80, 0.15, 0.10)
@export var chupa_color := Color(0.07, 0.02, 0.14)

var _combat_cleared := false
## Ya se soltó la tanda de mineros. Distinto de `_combat_cleared`, que es "ya
## los mataste": entre una cosa y la otra pasa todo el combate.
var _combat_started := false
var _claw_fired     := false
var _chase_active   := false
var _chupacabras: CharacterBody3D = null
var _duelo_activo := false
var _chupa_jefe: CharacterBody3D = null
var _chupa_pausa := 0.0
## Cuántas veces mordió en esta huida. Para el HUD y para los tests.
var _mordidas := 0
var _chupa_vel      := Vector3.ZERO
var _stall_pos      := Vector2.ZERO
var _stall_frames   := 0
## Desvío en grados que viene usando para rodear un obstáculo, 0 si va directo.
var _desvio         := 0.0

## Cada cuantos cuadros de fisica se vuelve a abrir el abanico de rayos.
const CUADROS_ENTRE_RUMBOS := 5
var _cuadros_rumbo  := 0
var _rumbo_ultimo   := Vector3.ZERO
var _forced_players: Array = []
var _alive          := 0
var _chupa_hit_cd   := 0.0


# La cueva se construía por código con cajas CSG, y en el editor se dibujaba
# como previsualización para poder colocar props a ojo. Ese andamiaje ya no hace
# falta: la mina está montada a mano en Mina.tscn con los assets de verdad.
# Aquí solo queda la lógica de juego -combate, garras, persecución-.

func _ready() -> void:
	_setup_triggers()
	_spawn_talisman()
	# El que dispara la huida es el TALISMÁN, no llegar al nido.
	#
	# Se escucha la habilidad y no el prop porque el fragmento se puede conseguir
	# por dos caminos —rompiendo la barricada de tablones o recogiendo el panel
	# flotante, según cómo esté puesta la mina— y así los dos sirven sin repetir
	# el enganche en cada uno.
	if not GameManager.ability_unlocked.is_connected(_al_conseguir_habilidad):
		GameManager.ability_unlocked.connect(_al_conseguir_habilidad)
	# Volvés a buscar al Chupacabras: la mina tiene que estar como la dejaste.
	# Diferido para que los obeliscos y las barreras hayan corrido su _ready y
	# haya a quién encender y qué derribar.
	if _toca_el_duelo():
		_dejar_como_tras_la_huida.call_deferred()
	_montar_al_ocultista.call_deferred()
	_precalentar_shaders()


## Al descargarse la mina se apaga la huida forzada.
##
## `_stop_chase` corre cuando el jugador cruza la boca, pero salir de un interior
## no pasa por `TravelManager.load_region`, así que la señal `region_changed`
## —la que le limpia `forced_run_dir` al PlayerController— nunca se emite. Si la
## salida se cruzaba en el mismo cuadro en que arrancaba el viaje, el personaje
## se llevaba la carrera automática puesta al poblado y seguía corriendo solo
## para siempre. Los jugadores sobreviven a esta escena, así que hay que
## devolverles el control desde acá.
func _exit_tree() -> void:
	for p in _forced_players:
		if is_instance_valid(p) and "forced_run_dir" in p:
			p.forced_run_dir = Vector3.ZERO
	_forced_players.clear()


## Dibuja una vez, a escondidas, cada material que aparecerá de golpe más tarde.
##
## El proyecto usa Forward+, que compila el shader la primera vez que un
## material se dibuja. Al entrar los cinco mineros —o los ocho de la huida, más
## el Chupacabras— aparecían a la vez varias combinaciones nuevas: transparencia
## sin sombreado y sin descarte de caras para el disco de telegrafiado, y texto
## en cartelera para la etiqueta. Compilarlas en mitad del combate congelaba el
## cuadro.
##
## Esto corre dentro del fundido de TravelManager, con la pantalla tapada, así
## que la compilación ocurre ahí y el jugador no la ve.
func _precalentar_shaders() -> void:
	var punto := get_node_or_null("PlayerSpawn") as Node3D
	var pos := punto.global_position if punto else Vector3.ZERO

	var e: CharacterBody3D = MINERO.instantiate()
	e.base_color = miner_color
	add_child(e)
	e.global_position = pos
	e.remove_from_group("enemies")     # que nadie lo tome por un objetivo real
	e.process_mode = Node.PROCESS_MODE_DISABLED
	# Sin colision: aparece en el punto de entrada y solaparia con el suelo,
	# justo lo que este arreglo trata de evitar.
	e.collision_layer = 0
	e.collision_mask = 0
	for hijo in e.get_children():
		if hijo is MeshInstance3D:
			(hijo as MeshInstance3D).visible = true   # incluido el telegrafiado

	# La etiqueta en cartelera del Chupacabras es otra variante distinta.
	var lbl := Label3D.new()
	lbl.text = "."
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.outline_size = 8
	add_child(lbl)
	lbl.global_position = pos

	# Dos cuadros: uno para que entren en la cola de dibujado y otro para que se
	# complete la compilación antes de retirarlos.
	await get_tree().process_frame
	await get_tree().process_frame
	e.queue_free()
	lbl.queue_free()


func _spawn_talisman() -> void:
	# Sólo si la escena lo pide con un marcador.
	#
	# Antes se creaba siempre, en coordenadas fijas heredadas de la cueva que se
	# generaba por código. La mina de ahora trae el talismán como modelo puesto a
	# mano sobre la barricada de tablones, y es esa barricada la que concede la
	# habilidad al romperse: el panel flotante sobraba, brillando en mitad del
	# pasillo. Con un Marker3D llamado TalismanSpawn vuelve, donde se lo ponga.
	var marca := get_node_or_null("TalismanSpawn") as Node3D
	if marca == null:
		return
	if GameManager.has_ability("talisman_frag_1"):
		return   # ya fue recogido en una sesión anterior
	var t := Area3D.new()
	t.set_script(TALISMAN_SCR)
	add_child(t)
	t.global_position = marca.global_position


# La persecución lanza rayos, así que va en _physics_process y no en _process.
# En _process corría una vez por cuadro renderizado: cuanto mejor el equipo, más
# rayos por segundo, y en la mina hay 230 cuerpos de colisión contra los que
# chocar. Aquí corre a la frecuencia fija de física y el coste deja de depender
# de los fps.
func _physics_process(delta: float) -> void:
	_vigilar_al_ocultista()
	if not _chase_active:
		return
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.get("active") == true:
			# El umbral sale de la salida real, no de un numero fijo: al escalar la
			# mina un -2.0 escrito a mano deja de significar "llegaste a la boca".
			var salida := get_node_or_null("ExitToPoblado") as Node3D
			var meta := (salida.global_position.z - 1.0) if salida else -1.0
			if p.global_position.z > meta:
				_stop_chase()
				return
	if is_instance_valid(_chupacabras):
		_move_chupacabras(delta)
		_check_chupa_hit(delta)


# ─── Triggers dinámicos ───────────────────────────────────────────────────────

## Disparadores del nivel.
##
## Se prefieren los Area3D que traiga la escena. Las coordenadas de más abajo
## venían de la cueva que se construía por código, y ya fallaron dos veces: al
## rehacer la mina a mano y otra vez al reescalarla. Con el disparador puesto en
## la escena, mover o escalar el nivel lo arrastra consigo y no hay nada que
## sincronizar.
func _setup_triggers() -> void:
	_trigger("CombatTrigger", Vector3(0.0, 1.4, -11.9), Vector3(9.8, 3.5, 2.8), _on_combat_enter)
	_trigger("ClawTrigger",   Vector3(0.0, 1.5, -30.0), Vector3(6.3, 3.5, 2.8), _on_claw_enter)
	_trigger("NestTrigger",   Vector3(0.0, 1.05, -42.0), Vector3(11.9, 5.6, 2.8), _on_nest_enter)


func _trigger(nombre: String, pos: Vector3, size: Vector3, callback: Callable) -> void:
	var area := get_node_or_null(nombre) as Area3D
	if area != null:
		area.collision_mask = 2
		area.body_entered.connect(callback)
		return
	_make_trigger(pos, size, callback)


func _make_trigger(pos: Vector3, size: Vector3, callback: Callable) -> void:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask  = 2
	area.body_entered.connect(callback)
	add_child(area)
	area.global_position = pos
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	area.add_child(cs)


# ─── Combate (S2) ─────────────────────────────────────────────────────────────

func _on_combat_enter(body: Node3D) -> void:
	if body.is_in_group("player"):
		_start_combat()


## Puntos de aparición tomados de la escena, si el nivel los trae puestos.
##
## Las coordenadas fijas de más abajo venían de la cueva que se construía por
## código. Al rehacer la mina a mano dejaron de corresponder: siete de las trece
## caían dentro de un muro. Un CharacterBody3D solapado con geometría estática
## intenta despenetrarse en cada cuadro de física, y con cinco u ocho a la vez
## eso hunde los fps y deja todo pegado.
##
## Basta con crear un Node3D con el nombre indicado y colgarle Marker3D dentro.
func _puntos_de(contenedor: String, respaldo: Array[Vector3]) -> Array[Vector3]:
	var nodo := get_node_or_null(contenedor)
	if nodo == null:
		return respaldo
	var out: Array[Vector3] = []
	for m in nodo.get_children():
		if m is Node3D:
			out.append((m as Node3D).global_position)
	return out if not out.is_empty() else respaldo


## Baja el punto hasta el suelo y lo aparta si está dentro de algo.
##
## Segunda red de seguridad: aunque los puntos vengan de marcadores, es fácil
## dejar uno rozando un muro al colocarlo a ojo. Aquí se comprueba y se corrige,
## así que colocar los marcadores no exige precisión.
func _sitio_libre(pos: Vector3) -> Vector3:
	var espacio := get_world_3d().direct_space_state
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.45
	capsula.height = 1.5

	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = capsula
	consulta.collision_mask = 1

	# En orden: el sitio pedido, luego anillos cada vez más abiertos alrededor.
	var candidatos: Array[Vector3] = [pos]
	for radio in [1.0, 2.0, 3.5, 5.0, 7.0]:
		for grados in [0, 45, 90, 135, 180, 225, 270, 315]:
			var a := deg_to_rad(float(grados))
			candidatos.append(pos + Vector3(cos(a), 0.0, sin(a)) * radio)

	for c in candidatos:
		var rayo := PhysicsRayQueryParameters3D.create(c + Vector3(0, 4, 0), c - Vector3(0, 60, 0))
		rayo.collision_mask = 1
		var golpe := espacio.intersect_ray(rayo)
		if golpe.is_empty():
			continue                      # ahí no hay suelo: caería al vacío
		var apoyado: Vector3 = golpe["position"] + Vector3(0, 0.1, 0)
		consulta.transform = Transform3D(Basis(), apoyado + Vector3(0, 0.8, 0))
		if espacio.intersect_shape(consulta, 1).is_empty():
			return apoyado
	push_warning("MinaCueva: no encontré sitio libre cerca de %s" % pos)
	return pos


## Suelta la tanda de mineros. Una sola vez por visita.
##
## El pestillo va acá y no en el disparador porque hay DOS formas de entrar más
## de una vez. La obvia es volver sobre tus pasos: `body_entered` se emite en
## cada entrada al área, y mirar `_combat_cleared` no alcanza porque eso no es
## true hasta que muere el quinto. La otra es que Emilia y Benjamín están los
## dos en el grupo "player", así que una única pasada del par ya disparaba el
## área dos veces y salían diez mineros.
func _start_combat() -> void:
	if _combat_started:
		return
	_combat_started = true
	_banner("¡Mineros corruptos en la mina!")
	var spawns: Array[Vector3] = [
		Vector3(-2.8,  0.35, -13.3),
		Vector3( 3.5,  0.35, -16.1),
		Vector3(-2.1,  0.35, -19.6),
		Vector3( 3.15, 0.35, -22.4),
		Vector3( 0.0,  0.35, -25.2),
	]
	spawns = _puntos_de("SpawnsCombate", spawns)
	_alive = spawns.size()
	var nacidos: Array[CharacterBody3D] = []
	for pos in spawns:
		var e: CharacterBody3D = MINERO.instantiate()
		e.base_color = miner_color
		e.died.connect(_on_miner_died)
		add_child(e)
		TOON_SKIN.new().aplicar(e)
		e.global_position = _sitio_libre(pos)
		nacidos.append(e)
	_presentar(nacidos)


## Plano de presentación: la cámara deja a los personajes, se va con los mineros
## que están brotando y se acerca a la cara del más cercano. Al terminar vuelve
## y recién ahí se recupera el control.
##
## Mientras dura, los dos personajes quedan con el input bloqueado. No es sólo
## para que no ataquen: con la cámara en otro sitio, moverse a ciegas es peor que
## no poder moverse.
func _presentar(mineros: Array[CharacterBody3D]) -> void:
	var juego := get_tree().get_first_node_in_group("game")
	if juego == null or not juego.has_method("focus_camera_on") or mineros.is_empty():
		return

	var quietos: Array = []
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and "input_locked" in p:
			p.input_locked = true
			quietos.append(p)

	# El más cercano al que mira el jugador: es el que se lleva el primer plano.
	var ojo := _presa_mas_cercana(mineros[0].global_position)
	var desde: Vector3 = ojo.global_position if ojo else mineros[0].global_position
	var elegido: CharacterBody3D = mineros[0]
	var mejor := INF
	for m in mineros:
		var d: float = desde.distance_to(m.global_position)
		if d < mejor:
			mejor = d
			elegido = m

	# Lo que dura la presentación sale de la propia animación de brotar, no de un
	# número escrito a mano: si mañana cambia el modelo, esto se ajusta solo.
	var duracion := 1.0
	for m in mineros:
		duracion = maxf(duracion, float(m.get("_apareciendo")))
	duracion += 0.5     # un respiro antes de devolver el control

	juego.focus_camera_on(elegido, duracion, 2.6, 1.7)
	await get_tree().create_timer(duracion).timeout
	for p in quietos:
		if is_instance_valid(p) and "input_locked" in p:
			p.input_locked = false


func _on_miner_died(_pos: Vector3, _xp: int) -> void:
	_alive -= 1
	if _alive <= 0:
		_combat_cleared = true
		_banner("Sector despejado… hay algo más abajo.", 3.0)
		if GameManager.get_beat() < 3:
			GameManager.set_beat(3)
		# El logro "El Correcaminos" NO se da aquí. Despejar el sector es el
		# principio de la mina —antes de los obeliscos, antes del talismán y
		# antes de que el Chupacabras aparezca—, y el logro es por escapar. Se
		# concede al cruzar la boca huyendo, en `_stop_chase`.


# ─── Pasillo de Garras (S3) ───────────────────────────────────────────────────

func _on_claw_enter(body: Node3D) -> void:
	if body.is_in_group("player") and _combat_cleared and not _claw_fired:
		_trigger_claw_dialogue()


func _trigger_claw_dialogue() -> void:
	if _claw_fired:
		return
	_claw_fired = true
	Sfx.play("boss", -4.0, 0.30)
	var res := DialogueManager.create_resource_from_text(DIALOGUE_GARRAS)
	DialogueManager.show_dialogue_balloon_scene(BALLOON, res, "start")


# ─── Nido / Persecución (S4) ──────────────────────────────────────────────────

func _on_nest_enter(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if _chase_active or _duelo_activo:
		return
	if _toca_el_duelo():
		# El duelo NO exige haber despejado a los mineros: se vuelve a la mina a
		# propósito, a buscarlo, y el camino hasta el nido está abierto.
		_iniciar_duelo()
	elif GameManager.tiene_logro("mina"):
		# Ya escapaste de acá una vez y volviste a buscarlo, pero todavía no
		# toca. Sin decir QUÉ falta, el viaje se hace a ciegas: llegás al nido,
		# no pasa nada y no hay forma de saber por qué.
		_avisar_lo_que_falta()
	elif _combat_cleared:
		_start_chase()


## ¿Toca el enfrentamiento en vez de la huida?
##
## Se entra en este modo cuando están TODOS los logros menos el suyo: es lo
## último que le queda al prototipo, así que la mina deja de ser una huida.
## Dice en pantalla qué logros faltan para que el Chupacabras plante cara.
func _avisar_lo_que_falta() -> void:
	var faltan: PackedStringArray = []
	for l in GameManager.LOGROS:
		if l["id"] != "chupacabras" and not GameManager.tiene_logro(l["id"]):
			faltan.append(str(l["titulo"]))
	if faltan.is_empty():
		return
	_banner("El Chupacabras todavía no da la cara. Te falta: %s"
		% ", ".join(faltan), 6.0)


func _toca_el_duelo() -> bool:
	if GameManager.tiene_logro("chupacabras"):
		return false
	for l in GameManager.LOGROS:
		if l["id"] != "chupacabras" and not GameManager.tiene_logro(l["id"]):
			return false
	return true


## El duelo: el Chupacabras deja de correr y planta cara.
##
## Acá no se fuerza la carrera de nadie ni se sueltan mineros: no hay de qué
## huir, y el derrumbe sobraría cuando lo que se quiere es un espacio en el que
## pelear.
func _iniciar_duelo() -> void:
	if _duelo_activo:
		return
	_duelo_activo = true
	await _ojos_en_la_oscuridad()
	_banner("El Chupacabras ya no huye. Esta vez te espera.", 3.5)
	Sfx.play("boss", 3.0, 0.55)

	var e: CharacterBody3D = CHUPACABRAS_JEFE.instantiate()
	e.base_color = chupa_color
	add_child(e)
	TOON_SKIN.new().aplicar(e)
	var marca := get_node_or_null("ChupacabrasSpawnPoint") as Node3D
	e.global_position = _sitio_libre(
		marca.global_position if marca else Vector3(0.0, -1.05, -49.0))
	# El tamaño también sale del marcador: lleva VistaPrevia, así que en el
	# editor se ve el bicho y se lo escala con el gizmo. Se toma la escala LOCAL
	# y no la global: los dos cuelgan de la mina, y la global le sumaría encima
	# el tamaño de la mina entera.
	if marca != null:
		e.scale = marca.scale
	e.died.connect(_al_vencer_al_chupacabras)
	_chupa_jefe = e


func _al_vencer_al_chupacabras(_pos: Vector3, _xp: int) -> void:
	_chupa_jefe = null
	_banner("El Chupacabras cae. Vilu vuelve a respirar.", 6.0)
	GameManager.conceder("chupacabras")


## Recoger el primer fragmento del talismán despierta al Chupacabras.
##
## Antes la huida esperaba a que llegaras al nido con los mineros despejados, y
## el talismán —que es el motivo por el que bajaste— no hacía nada. Ahora lo
## agarras y sale.
func _al_conseguir_habilidad(cual: String) -> void:
	if cual != "talisman_frag_1":
		return
	# La única visita en la que NO hay que salir corriendo es la del duelo. Lo
	# decide `_toca_el_duelo()`, que mira si están todos los logros menos el
	# suyo.
	#
	# Antes esto miraba el logro de la mina, y eso dejaba sin huida a quien
	# entrara por una parada del menú que ya lo concede: era su primera vez en la
	# mina, recogía el talismán y no pasaba nada.
	if _chase_active or _duelo_activo or _toca_el_duelo():
		return
	_start_chase()


func _start_chase() -> void:
	if _chase_active:
		return   # el pestillo vive acá, igual que en _start_combat
	_chase_active = true
	await _ojos_en_la_oscuridad()
	_banner("¡HUYE!")
	Sfx.play("boss", 3.0, 0.55)

	var c := CharacterBody3D.new()
	c.collision_layer = 4
	c.collision_mask  = 1

	# Modelo real. Se encaja midiendo su caja envolvente en vez de confiar en el
	# tamaño del archivo, y se le pasa el sombreado toon a mano: la mina entera
	# lo recibe al cargarse, pero el Chupacabras nace después, en plena huida.
	var visual: Node3D = CHUPACABRAS.instantiate()
	c.add_child(visual)
	ENCAJAR.encajar(visual, 2.4)
	TOON_SKIN.new().aplicar(visual)

	var lbl := Label3D.new()
	lbl.text = "CHUPACABRAS"
	lbl.position.y = 3.0
	lbl.pixel_size = 0.009
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = chupa_color.lightened(0.55)
	lbl.font_size = 22
	lbl.outline_size = 8
	c.add_child(lbl)

	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.62
	cap.height = 1.3
	cs.shape = cap
	cs.position.y = 1.2
	c.add_child(cs)

	add_child(c)
	# Tambien venia de la cueva generada: el nido estaba a Y=-2. Se busca sitio
	# igual que con los mineros, y si el nivel trae un ChupacabrasSpawnPoint se
	# usa ese.
	var marca := get_node_or_null("ChupacabrasSpawnPoint") as Node3D
	c.global_position = _sitio_libre(marca.global_position if marca else Vector3(0.0, -1.05, -49.0))
	_chupacabras = c
	# Y a correr. El modelo trae siete clips —Idle, Walk, Run, Sneak, Howl, Bite
	# y Death— y no usaba ninguno: perseguía deslizándose con las patas clavadas,
	# como una estatua sobre ruedas. Todos caminan en el sitio, así que el que
	# lo mueve sigue siendo el código.
	_clip_de(c, "Run", true)
	_chupa_vel   = Vector3.ZERO
	_stall_pos   = Vector2(c.global_position.x, c.global_position.z)
	_stall_frames = 0
	_desvio      = 0.0
	_rumbo_ultimo = Vector3.ZERO
	_cuadros_rumbo = 0

	_poblar_pasillo_central(false)

	# Bloques de derrumbe del techo (staggered)
	var debris_z  := [-45.0, -35.0, -24.0, -10.0]
	var delays    := [ 1.5,   3.5,   5.5,   7.0]
	for i in debris_z.size():
		get_tree().create_timer(delays[i]).timeout.connect(
			func() -> void: _spawn_debris(debris_z[i]))

	# Forzar huida en +Z — el activo arranca de inmediato, el compañero 0.6s después
	# para que el jugador lidere la salida y se vean correr juntos.
	for p in get_tree().get_nodes_in_group("player"):
		if "forced_run_dir" in p:
			_forced_players.append(p)
			if p.get("active") == true:
				p.forced_run_dir = Vector3(0.0, 0.0, 1.0)
			else:
				get_tree().create_timer(0.6).timeout.connect(
					func() -> void:
						if is_instance_valid(p) and "forced_run_dir" in p:
							p.forced_run_dir = Vector3(0.0, 0.0, 1.0))


func _spawn_debris(z: float) -> void:
	if not _chase_active:
		return
	var body := RigidBody3D.new()
	body.collision_layer = 1
	body.collision_mask  = 1
	body.contact_monitor = true
	body.max_contacts_reported = 2
	add_child(body)
	body.global_position = Vector3(0.0, 5.0, z)

	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 0.6, 1.4)
	cs.shape = box
	body.add_child(cs)

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.4, 0.6, 1.4)
	mi.mesh = bm
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.27, 0.20, 0.15)
	mi.set_surface_override_material(0, dmat)
	body.add_child(mi)

	# Zona de daño para jugadores
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask  = 2
	body.add_child(area)
	var acs := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(1.6, 0.8, 1.6)
	acs.shape = abox
	area.add_child(acs)
	area.body_entered.connect(func(hit: Node3D) -> void:
		if hit.is_in_group("player") and hit.has_method("take_damage"):
			hit.take_damage(20))


## Velocidad de persecución, en m/s.
## Qué fracción de la vida MÁXIMA se lleva cada mordida.
##
## Antes atraparte era muerte seca y recarga de escena: la huida no era una
## huida, era un pasillo donde un solo error volvía a empezar. Con 0.25 el bicho
## puede morderte dos veces y salís de la mina a media vida, que es peligro de
## verdad en vez de castigo.
const CHUPA_DANO := 0.25

## Segundos que tarda en volver a poder morder.
const CHUPA_ESPERA_MORDIDA := 3.0

## Segundos que se queda quieto tras morder. Sin esta pausa te alcanza otra vez
## en cuanto vence la espera, porque nunca dejó de estar encima tuyo.
const CHUPA_PAUSA_MORDIDA := 0.9

const CHUPA_VELOCIDAD := 8.0
## A menos de esto ya no hace falta acercarse más: lo agarra igual.
const CHUPA_DISTANCIA_MINIMA := 1.0


## ¿Hay paso libre en esta dirección? Mira a tres alturas, como el salto.
func _paso_libre(c: CharacterBody3D, dir: Vector3, largo: float) -> bool:
	var space := c.get_world_3d().direct_space_state
	for ry in [0.15, 0.7, 1.4]:
		var origin := c.global_position + Vector3(0.0, ry, 0.0)
		var params := PhysicsRayQueryParameters3D.create(origin, origin + dir * largo)
		params.collision_mask = 1
		params.exclude = [c.get_rid()]
		if not space.intersect_ray(params).is_empty():
			return false
	return true


## Altura, medida sobre el origen del cuerpo, a la que se decide si un
## obstáculo se salta o se rodea.
##
## El salto sale a 9.5 m/s con gravedad 22, así que sube 9.5²/(2·22) = 2.05 m.
## Los pies de la cápsula están 0.55 sobre el origen. Un rayo a 2.6 pasa
## justo por encima de lo más alto que puede coronar.
const CHUPA_ALTURA_SALTO := 2.6


## ¿Queda aire libre por encima del obstáculo, o sea que se puede saltar?
func _hay_aire_arriba(c: CharacterBody3D, dir: Vector3, largo: float) -> bool:
	var origin := c.global_position + Vector3(0.0, CHUPA_ALTURA_SALTO, 0.0)
	var params := PhysicsRayQueryParameters3D.create(origin, origin + dir * largo)
	params.collision_mask = 1
	params.exclude = [c.get_rid()]
	return c.get_world_3d().direct_space_state.intersect_ray(params).is_empty()


## Desvíos que se prueban cuando el rumbo directo está tapado, en grados.
## Van de menor a mayor para que sólo se aparte lo justo, y en pares para no
## tener preferencia por un lado.
const CHUPA_DESVIOS := [25.0, -25.0, 50.0, -50.0, 80.0, -80.0, 110.0, -110.0]
## Largo de la sonda al elegir un desvío. Más larga que la de "¿puedo seguir
## de frente?" a propósito: un hueco de 1.6 m puede ser un rincón sin salida.
const CHUPA_SONDA_LARGA := 4.0


## Rumbo a seguir: el directo si hay paso, y si no el desvío más chico que lo
## haya.
##
## Apuntar en línea recta al jugador funciona en campo abierto, pero la mina es
## un pasillo con estrechamientos: los bloques de z=-15.5 dejan libre sólo de
## x=-3 a x=3. Persiguiendo a alguien parado en x=5, el chupacabras derivaba
## hasta x=5 y se clavaba de frente contra el bloque, saltando eternamente
## contra una pared de 6 m que no podía superar. Probar desvíos le permite
## rodear el bloque hasta la boca del pasillo y seguir.
##
## No es pathfinding y no pretende serlo — para un túnel sin ramificaciones
## alcanza. Si la mina llegara a tener bifurcaciones o callejones sin salida,
## esto habría que cambiarlo por un NavigationAgent3D con su navmesh, porque un
## abanico de rumbos se mete en cualquier cul-de-sac y no sabe salir.
func _rumbo(c: CharacterBody3D, directo: Vector3) -> Vector3:
	if _paso_libre(c, directo, 1.6):
		return directo
	# Antes de rodear: ¿es un escalón que puede saltar? Si por encima hay aire,
	# sí, y hay que mantener el rumbo para que el detector de salto lo vea.
	# Sin esto el abanico lo desviaba del escalón de salida del nido, que sí
	# sabía superar, y se quedaba dando vueltas al pie.
	if _hay_aire_arriba(c, directo, 1.6):
		return directo
	# Mantener el desvío que ya venía usando mientras siga despejado. Sin esta
	# memoria el abanico decidía de cero cada cuadro y, delante de un pilar
	# centrado, elegía +110° y -110° alternándose: se quedaba vibrando en el
	# sitio en vez de rodearlo.
	if _desvio != 0.0:
		var seguir := directo.rotated(Vector3.UP, deg_to_rad(_desvio))
		if _paso_libre(c, seguir, CHUPA_SONDA_LARGA):
			return seguir

	# Primero con sonda larga: así descarta las salidas que dan a una pared a
	# dos metros. Elegir "la primera libre" a corta distancia lo metía en el
	# lado angosto del pasillo, donde volvía a atascarse.
	for grados: float in CHUPA_DESVIOS:
		var alt := directo.rotated(Vector3.UP, deg_to_rad(grados))
		if _paso_libre(c, alt, CHUPA_SONDA_LARGA):
			_desvio = grados
			return alt
	# Si ninguna sirve a lo largo, con que haya hueco inmediato alcanza.
	for grados: float in CHUPA_DESVIOS:
		var alt := directo.rotated(Vector3.UP, deg_to_rad(grados))
		if _paso_libre(c, alt, 1.6):
			_desvio = grados
			return alt
	# Encerrado por todos lados: insistir de frente y dejar que salte.
	_desvio = 0.0
	return directo


## Jugador más cercano al chupacabras, o null si no queda ninguno.
func _presa_mas_cercana(desde: Vector3) -> Node3D:
	var mejor: Node3D = null
	var mejor_d := INF
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p) or not (p is Node3D):
			continue
		var d: float = desde.distance_squared_to((p as Node3D).global_position)
		if d < mejor_d:
			mejor_d = d
			mejor = p
	return mejor


func _move_chupacabras(delta: float) -> void:
	var c := _chupacabras
	if not is_instance_valid(c):
		return

	# PERSIGUE al jugador en vez de correr recto por +Z.
	#
	# Antes era `x = 0, z = 8` fijo: cruzaba el túnel entero en línea recta sin
	# mirar dónde estabas, y al llegar al muro del fondo de la cámara de entrada
	# se incrustaba y se quedaba ahí. Con dirección real deja de ser un tren en
	# un riel y no hay muro contra el que encajarse, porque nunca insiste contra
	# algo que no está en su camino hacia vos.
	var presa := _presa_mas_cercana(c.global_position)
	if presa != null:
		var d := presa.global_position - c.global_position
		d.y = 0.0
		if d.length() > CHUPA_DISTANCIA_MINIMA:
			# El rumbo no se recalcula cada cuadro. _rumbo llega a lanzar 55
			# rayos cuando tiene que abrir el abanico entero, y decidir doce
			# veces por segundo es de sobra para una bestia que corre a 8 m/s:
			# en el intervalo avanza medio metro. Entre recálculos se reutiliza
			# la última dirección, girada hacia la presa, para que siga curvando
			# tras ella y no vaya a trompicones.
			_cuadros_rumbo -= 1
			if _cuadros_rumbo <= 0 or _rumbo_ultimo == Vector3.ZERO:
				_rumbo_ultimo = _rumbo(c, d.normalized())
				_cuadros_rumbo = CUADROS_ENTRE_RUMBOS
			else:
				_rumbo_ultimo = _rumbo_ultimo.lerp(d.normalized(), 0.35).normalized()
			var dir := _rumbo_ultimo * CHUPA_VELOCIDAD
			_chupa_vel.x = dir.x
			_chupa_vel.z = dir.z
		else:
			_chupa_vel.x = 0.0
			_chupa_vel.z = 0.0
	else:
		# Sin nadie a quien seguir, se queda quieto en vez de empujar una pared.
		_chupa_vel.x = 0.0
		_chupa_vel.z = 0.0

	if c.is_on_floor():
		if _chupa_vel.y < 0.0:
			_chupa_vel.y = 0.0
	else:
		_chupa_vel.y -= 22.0 * delta

	# El atasco se MIDE siempre, aunque esté en el aire: quedarse trabado contra
	# una pared a media altura era justamente el caso que no se detectaba, porque
	# toda esta lógica vivía dentro del `is_on_floor()`. Saltar, en cambio, sólo
	# se puede desde el piso.
	var avance := Vector2(c.global_position.x, c.global_position.z)
	var atascado := false
	if avance.distance_to(_stall_pos) < 0.06:
		_stall_frames += 1
		if _stall_frames >= 8:
			atascado = true
			_stall_frames = 0
	else:
		_stall_pos = avance
		_stall_frames = 0

	if c.is_on_floor():
		var should_jump := atascado
		if not should_jump:
			# Rayos en la dirección REAL de avance, no en +Z fijo.
			var dir := Vector3(_chupa_vel.x, 0.0, _chupa_vel.z)
			if dir.length() > 0.01:
				dir = dir.normalized() * 1.4
				var space := c.get_world_3d().direct_space_state
				for ry in [0.15, 0.5, 0.9]:
					var origin := c.global_position + Vector3(0.0, ry, 0.0)
					var params := PhysicsRayQueryParameters3D.create(origin, origin + dir)
					params.collision_mask = 1
					params.exclude = [c.get_rid()]
					if not space.intersect_ray(params).is_empty():
						should_jump = true
						break
		if should_jump:
			_chupa_vel.y = 9.5

	if _chupa_pausa > 0.0:
		_chupa_pausa = maxf(0.0, _chupa_pausa - delta)
		_chupa_vel.x = 0.0
		_chupa_vel.z = 0.0
	else:
		# Parado muerde y quieto no; corriendo, corre. Se pide en cada cuadro
		# porque `_clip_de` no relanza lo que ya está sonando.
		_clip_de(c, "Run", true)
	c.velocity = _chupa_vel
	c.move_and_slide()


func _check_chupa_hit(delta: float) -> void:
	_chupa_hit_cd = max(0.0, _chupa_hit_cd - delta)
	if not is_instance_valid(_chupacabras) or _chupa_hit_cd > 0.0:
		return
	var cpos := _chupacabras.global_position
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p):
			continue
		if cpos.distance_to(p.global_position) < 2.0:
			_morder()
			return


## Una mordida: se lleva un cuarto de la vida de los DOS y frena al bicho un
## instante. No mata por sí sola —hacen falta cuatro— así que la huida se puede
## perder, pero perderla cuesta cuatro errores y no uno.
func _morder() -> void:
	_chupa_hit_cd = CHUPA_ESPERA_MORDIDA
	_mordidas += 1
	_clip_de(_chupacabras, "Bite", false)
	_banner("¡El Chupacabras te alcanzó!", 2.0)
	Sfx.play_at("hit", _chupacabras.global_position, -2.0, 0.7)
	for pp in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(pp) or not pp.has_method("take_damage"):
			continue
		var maxima: float = float(pp.get("max_health")) if "max_health" in pp else 100.0
		pp.take_damage(maxima * CHUPA_DANO)
	# Se detiene un momento: si siguiera encima, la siguiente mordida llegaría
	# apenas venza la espera y no habría forma de despegarse.
	_chupa_pausa = CHUPA_PAUSA_MORDIDA


func _stop_chase() -> void:
	if not _chase_active:
		return
	_chase_active = false
	# Aquí sí: se cruzó la boca de la mina con el Chupacabras detrás. Este
	# guardia de `_chase_active` es el que asegura que sólo cuente escapando —no
	# se llega a esta línea sin haber corrido.
	GameManager.conceder("mina")
	for p in _forced_players:
		if not is_instance_valid(p) or not ("forced_run_dir" in p):
			continue
		if p.get("active") == true:
			p.forced_run_dir = Vector3.ZERO
		else:
			# El compañero puede estar a pocos metros de la salida — lo dejamos correr
			# 2 s más para que salga antes de que su IA de combate tome el control.
			get_tree().create_timer(2.0).timeout.connect(
				func() -> void:
					if is_instance_valid(p) and "forced_run_dir" in p:
						p.forced_run_dir = Vector3.ZERO)
	_forced_players.clear()
	if is_instance_valid(_chupacabras):
		_chupacabras.queue_free()
		_chupacabras = null
	_banner("El Chupacabras se esconde en las sombras… La salida está cerca.", 4.0)


# ── HUD ──────────────────────────────────────────────────────────────────────

func _banner(text: String, auto_clear := 0.0) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if not hud or not hud.has_method("show_banner"):
		return
	hud.show_banner(text)
	if auto_clear > 0.0:
		get_tree().create_timer(auto_clear).timeout.connect(func() -> void:
			# El HUD se vuelve a buscar acá dentro en vez de capturarlo: una lambda que
			# captura un nodo y sobrevive a que lo liberen da "Lambda capture at index 0
			# was freed", aunque se compruebe is_instance_valid antes de usarlo.
			var h := get_tree().get_first_node_in_group("hud")
			if h != null and h.has_method("clear_banner"):
				h.clear_banner())


## Dónde se planta la fila de mineros del pasillo central.
##
## Se usa en las DOS visitas: en la huida son bulto que esquivar, y al volver al
## duelo tienen que estar igual —el jugador dejó la mina así—. Escribirlas dos
## veces era garantía de que una de las dos se quedara vieja.
const MINEROS_DEL_PASILLO: Array[Vector3] = [
	Vector3( 1.75, 0.35, -36.4),
	Vector3(-1.4,  0.35, -32.2),
	Vector3( 2.1,  0.35, -27.3),
	Vector3(-2.45, 0.35, -21.7),
	Vector3( 1.4,  0.35, -16.8),
	Vector3(-1.75, 0.35, -11.9),
	Vector3( 1.05, 0.35,  -7.0),
	Vector3(-1.05, 0.35,  -3.5),
]


## Llena el pasillo central de mineros.
##
## `peleables` decide qué son. En la HUIDA no: son invulnerables y fuera del
## grupo "enemies", porque ahí no hay que pelear con nadie —hay que correr— y un
## compañero parándose a atacarlos te deja atrás. En el DUELO sí: ya no huís, así
## que quedarte pegando a muñecos inmortales alrededor del jefe no tendría
## sentido.
func _poblar_pasillo_central(peleables: bool) -> void:
	for pos in _puntos_de("SpawnsHuida", MINEROS_DEL_PASILLO):
		var m: CharacterBody3D = MINERO.instantiate()
		m.base_color = miner_color
		m.speed = 1.5
		if not peleables:
			m.max_health = 999.0
		add_child(m)
		TOON_SKIN.new().aplicar(m)
		m.global_position = _sitio_libre(pos)
		if not peleables:
			m.remove_from_group("enemies")


## Deja la mina como la dejaste al salir corriendo.
##
## Se llama al entrar cuando toca el duelo con el Chupacabras: volvés a un sitio
## por el que ya pasaste, y encontrarlo de cero —las barreras otra vez de pie,
## los mineros del pasillo de la derecha resucitados— contradice lo que jugaste.
## Lo que queda es: obeliscos encendidos, sector derecho despejado y el pasillo
## central con su gente, que es la foto de cuando huiste.
func _dejar_como_tras_la_huida() -> void:
	_combat_started = true
	_combat_cleared = true
	_alive = 0
	# El diálogo de las garras es el de descubrirlas. Ya las viste: repetirlo al
	# volver sonaría a que nadie se acuerda de lo que pasó.
	_claw_fired = true

	var encendidos := 0
	for n in _todos_los_nodos(self):
		if n.has_method("activar") and n.get_script() != null \
				and String(n.get_script().resource_path).ends_with("Obelisco.gd"):
			n.call("activar", false)
			encendidos += 1

	_poblar_pasillo_central(true)
	print("[mina] vuelta para el duelo: %d obeliscos ya encendidos, sector"
		% encendidos + " derecho despejado y el pasillo central poblado")


# ─── Los ojos en la oscuridad ────────────────────────────────────────────────
#
# Antes el Chupacabras aparecía de golpe en su nido y salía corriendo: el bicho
# más importante de la mina entraba en escena sin entrar en escena. Ahora la
# cámara se va al fondo del túnel, donde no se ve nada, y ahí se encienden dos
# ojos rojos. Sólo entonces sale.
#
# Es la misma pausa que ya tiene el golpe del Yastay: primero se avisa, después
# se pega.

## Cuánto se queda la cámara en los ojos antes de que salga, en segundos.
@export var ojos_en_la_sombra := 2.2
## A qué altura del suelo están, y cuánto se separan entre sí.
@export var alto_de_los_ojos := 1.35
@export var separacion_de_los_ojos := 0.34
## Desde dónde los mira la cámara.
@export var camara_de_los_ojos := 5.0


## La entrada del Chupacabras. Se espera antes de crearlo.
func _ojos_en_la_oscuridad() -> void:
	var donde := _sitio_del_nido()
	var ojos := _encender_los_ojos(donde)
	var juego := get_tree().get_first_node_in_group("game")
	if juego != null and juego.has_method("focus_camera_on"):
		juego.focus_camera_on(ojos, 0.0, camara_de_los_ojos, alto_de_los_ojos)
	await get_tree().create_timer(ojos_en_la_sombra).timeout
	if is_instance_valid(ojos):
		ojos.queue_free()
	if juego != null and juego.has_method("clear_camera_focus"):
		juego.clear_camera_focus()


## Dónde está el nido: el mismo marcador por el que sale.
func _sitio_del_nido() -> Vector3:
	var marca := get_node_or_null("ChupacabrasSpawnPoint") as Node3D
	return marca.global_position if marca != null else Vector3(0.0, -1.05, -49.0)


## Dos puntos rojos que laten, sin sombreado, para que se vean en lo oscuro.
##
## Y una luz roja floja pegada a ellos: sin la luz son dos calcomanías; con
## ella, algo que está ahí y respira.
func _encender_los_ojos(donde: Vector3) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "OjosEnLaOscuridad"
	add_child(raiz)
	raiz.global_position = donde + Vector3(0.0, alto_de_los_ojos, 0.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.12, 0.08)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.15, 0.1)
	mat.emission_energy_multiplier = 6.0

	for lado in [-1.0, 1.0]:
		var ojo := MeshInstance3D.new()
		var esf := SphereMesh.new()
		esf.radius = 0.075
		esf.height = 0.15
		ojo.mesh = esf
		ojo.material_override = mat
		raiz.add_child(ojo)
		ojo.position = Vector3(separacion_de_los_ojos * 0.5 * lado, 0.0, 0.0)

	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.25, 0.18)
	luz.light_energy = 1.6
	luz.omni_range = 4.5
	raiz.add_child(luz)

	# Laten: dos puntos fijos parecen un cartel, y parpadeando parecen vivos.
	#
	# `bind_node` es lo que hace que el latido MUERA con los ojos. Sin eso el
	# bucle sigue vivo después de apagarlos, tocando un nodo liberado, y el
	# motor se queja en cada vuelta.
	var tw := get_tree().create_tween().bind_node(raiz).set_loops()
	tw.tween_property(luz, "light_energy", 0.5, 0.55)
	tw.tween_property(luz, "light_energy", 1.8, 0.45)
	return raiz


# ─── El ocultista del pasillo ────────────────────────────────────────────────
#
# Está en la mina desde que entrás por primera vez. A mitad del pasillo se da
# vuelta, camina hasta el tablón que esconde el talismán y se queda
# señalándolo. Sigue ahí con el primer obelisco encendido; al segundo, ya no.

## Prefijo del nodo puesto a mano en la escena.
const OCULTISTA := "ocultista"
## A cuántos metros de él salta la escena, vengas por donde vengas.
@export var ocultista_aviso := 12.0
## A qué distancia del tablón se planta a señalarlo, en metros.
@export var ocultista_margen := 1.6
## Lo que tarda en llegar, en metros por segundo.
@export var ocultista_paso := 1.7

var _ocultista: Node3D = null
var _ocultista_en_marcha := false
## Lo que el clip de darse vuelta se lleva al esqueleto por delante.
var _avance_de_la_vuelta := Vector3.ZERO


func _montar_al_ocultista() -> void:
	# Una sola vez, por lo mismo que en el bar.
	if _ocultista != null:
		return
	_ocultista = _buscar_con_prefijo(self, OCULTISTA)
	if _ocultista == null:
		return

	# Los obeliscos avisan cuándo se encienden: al segundo, desaparece.
	for n in _todos_los_nodos(self):
		if n.has_signal("activado") and not n.is_connected("activado", _al_encender_obelisco):
			n.connect("activado", _al_encender_obelisco)

	var encendidos := _obeliscos_encendidos()
	if encendidos >= 2:
		# Ya no pinta nada acá: para cuando volvés, se fue.
		_ocultista.queue_free()
		_ocultista = null
		return
	if encendidos >= 1:
		# Volviste con uno encendido: ya hizo su camino, está en el tablón.
		_ocultista_en_marcha = true
		_ocultista.global_position = _sitio_junto_al_tablon()
		_mirar_al_tablon()
		_clip_de(_ocultista, "marcando", true)
		return

	# Todavía no señala nada: está de espaldas, parado en el primer fotograma de
	# darse vuelta, que es exactamente eso. Señalar el tablón es lo que hace al
	# final, y verlo hacerlo desde la entrada arruinaba el momento.
	_de_espaldas()


## Se enciende a mitad del pasillo, cuando te acercás.
##
## Antes había una caja de disparo puesta ocho metros hacia +Z. Dependía de por
## dónde llegaras: entrando por el otro lado —o bordeándola pegado a la pared—
## nunca saltaba, y el ocultista se quedaba de espaldas para siempre. Una
## distancia no tiene lados.
func _vigilar_al_ocultista() -> void:
	if _ocultista_en_marcha or not is_instance_valid(_ocultista):
		return
	var cerca := false
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p) or not (p is Node3D):
			continue
		if (p as Node3D).global_position.distance_to(_ocultista.global_position) \
				<= ocultista_aviso:
			cerca = true
			break
	if not cerca:
		return
	_ocultista_en_marcha = true
	# Con await, por lo mismo que en el bar: sin esperarla, la corrutina se
	# queda en su primer await y el ocultista no llega a caminar.
	await _escena_del_ocultista()


func _escena_del_ocultista() -> void:
	var juego := get_tree().get_first_node_in_group("game")
	var con_camara: bool = juego != null and juego.has_method("focus_camera_on")
	if con_camara:
		juego.focus_camera_on(_ocultista, 0.0, 7.0, 1.6)

	# 1. Se da vuelta: te vio.
	await get_tree().create_timer(
		_clip_de(_ocultista, "vuelta_y_caminar", false)).timeout
	if not is_instance_valid(_ocultista):
		return
	_absorber_el_avance()

	# 2. Camina hasta el tablón.
	var meta := _sitio_junto_al_tablon()
	var d := meta - _ocultista.global_position
	d.y = 0.0
	if d.length() > 0.1:
		_encarar_ocultista(d.normalized())
		_clip_de(_ocultista, "caminar", true)
		var tw := get_tree().create_tween()
		tw.tween_property(_ocultista, "global_position", meta,
			d.length() / maxf(ocultista_paso, 0.1))
		await tw.finished
	if not is_instance_valid(_ocultista):
		return

	# 3. Y se queda señalándolo.
	_mirar_al_tablon()
	_clip_de(_ocultista, "marcando", true)
	if con_camara:
		juego.clear_camera_focus()


## Dónde se planta: a un paso del tablón, del lado por el que se llega.
func _sitio_junto_al_tablon() -> Vector3:
	var t := _tablon_del_talisman()
	if t == null or not is_instance_valid(_ocultista):
		return _ocultista.global_position if is_instance_valid(_ocultista) else Vector3.ZERO
	var desde := _ocultista.global_position
	var d := t.global_position - desde
	d.y = 0.0
	if d.length() < 0.1:
		return desde
	var meta := desde + d.normalized() * maxf(d.length() - ocultista_margen, 0.0)
	meta.y = desde.y
	return meta


func _mirar_al_tablon() -> void:
	var t := _tablon_del_talisman()
	if t != null and is_instance_valid(_ocultista):
		_encarar_ocultista(t.global_position - _ocultista.global_position)


## Quieto y de espaldas: el primer fotograma de darse vuelta.
##
## Sus tres clips son darse vuelta, caminar y señalar; no tiene uno de reposo, y
## sin esto se quedaba en T, con los brazos en cruz.
func _de_espaldas() -> void:
	var ap := _animador_de(_ocultista)
	if ap == null or not ap.has_animation("vuelta_y_caminar"):
		return
	var a := ap.get_animation("vuelta_y_caminar")
	a.loop_mode = Animation.LOOP_NONE
	# Se mide ANTES de dejarlo quieto: hace falta recorrer el clip entero, y
	# esto pasa al montar la mina, cuando todavía no lo está mirando nadie.
	_avance_de_la_vuelta = _medir_el_avance(ap, "vuelta_y_caminar")
	ap.play("vuelta_y_caminar")
	ap.seek(0.0, true)
	ap.pause()


## Cuánto se lleva un clip al esqueleto por delante, en metros del modelo.
##
## `caminar` camina en el sitio y da cero. `vuelta_y_caminar` no: mueve el
## esqueleto casi un metro hacia delante. Eso no se ve mal mientras dura, pero
## al cambiar de clip el esqueleto vuelve a su origen y el personaje pega un
## salto atrás.
func _medir_el_avance(ap: AnimationPlayer, clip: String) -> Vector3:
	var esq := _esqueleto_de(_ocultista)
	if esq == null or not ap.has_animation(clip):
		return Vector3.ZERO
	var raiz := -1
	for i in esq.get_bone_count():
		if esq.get_bone_parent(i) == -1:
			raiz = i
			break
	if raiz < 0:
		return Vector3.ZERO
	ap.play(clip)
	ap.seek(0.0, true)
	var desde: Vector3 = esq.get_bone_global_pose(raiz).origin
	ap.seek(ap.get_animation(clip).length, true)
	var avance: Vector3 = esq.get_bone_global_pose(raiz).origin - desde
	avance.y = 0.0
	return avance


## Le pasa al NODO el avance que el clip se llevó por dentro, para que al
## cambiar de clip no dé el salto atrás. Con un clip que camine en el sitio esto
## no hace nada, que es como tiene que ser.
func _absorber_el_avance() -> void:
	if not is_instance_valid(_ocultista) or _avance_de_la_vuelta.length() < 0.01:
		return
	var esq := _esqueleto_de(_ocultista)
	if esq == null:
		return
	_ocultista.global_position += esq.global_transform.basis * _avance_de_la_vuelta


func _esqueleto_de(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for h in n.get_children():
		var x := _esqueleto_de(h)
		if x != null:
			return x
	return null


## El frente de estos modelos es +Z: medido del talón a los dedos sobre el rig.
func _encarar_ocultista(hacia: Vector3) -> void:
	hacia.y = 0.0
	if hacia.length() < 0.01 or not is_instance_valid(_ocultista):
		return
	_ocultista.rotation.y = atan2(hacia.x, hacia.z)


## El tablonado que esconde el primer fragmento. Se busca por lo que CONCEDE y
## no por su nombre: se llama "tablones_de_madera4" y hay cinco más iguales
## repartidos por la mina.
func _tablon_del_talisman() -> Node3D:
	for n in _todos_los_nodos(self):
		if n is Node3D and "otorga" in n and String(n.get("otorga")) == "talisman_frag_1":
			return n as Node3D
	return null


func _obeliscos_encendidos() -> int:
	var n := 0
	for x in _todos_los_nodos(self):
		if "_activado" in x and x.get("_activado") == true:
			n += 1
	return n


func _al_encender_obelisco() -> void:
	if _obeliscos_encendidos() < 2 or not is_instance_valid(_ocultista):
		return
	_ocultista.queue_free()
	_ocultista = null


## Reproduce un clip suyo y devuelve lo que dura. 0 si no lo tiene.
func _clip_de(nodo: Node3D, nombre: String, en_bucle: bool) -> float:
	if not is_instance_valid(nodo):
		return 0.0
	var ap := _animador_de(nodo)
	if ap == null or not ap.has_animation(nombre):
		return 0.0
	var a := ap.get_animation(nombre)
	a.loop_mode = Animation.LOOP_LINEAR if en_bucle else Animation.LOOP_NONE
	if ap.assigned_animation != nombre or not ap.is_playing():
		ap.play(nombre)
	return a.length


func _animador_de(n: Node) -> AnimationPlayer:
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


func _todos_los_nodos(n: Node) -> Array:
	var r: Array = []
	for h in n.get_children():
		r.append(h)
		r.append_array(_todos_los_nodos(h))
	return r
