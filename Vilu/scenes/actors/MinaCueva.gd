extends Node3D

## Zona Mina Corrupta — 4 secciones + persecución del Chupacabras.
##
## S1 (Z=0→-15): entrada, viga baja + pilar
## S2 (Z=-15→-38): sala de combate, 5 mineros normales
## S3 (Z=-38→-56): pasillo de garras, diálogo y sonido inquietante
## S4 (Z=-59→-76): cámara del nido, Chupacabras a 8.5 m/s
##
## Durante la huida: 8 mineros normales + 4 bloques de derrumbe del techo.

const ENEMY_NORMAL    := preload("res://scenes/enemies/EnemyNormal.tscn")
const BALLOON         := "res://addons/dialogue_manager/example_balloon/example_balloon.tscn"
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
var _claw_fired     := false
var _chase_active   := false
var _chupacabras: CharacterBody3D = null
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
	_precalentar_shaders()


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

	var e: CharacterBody3D = ENEMY_NORMAL.instantiate()
	e.base_color = miner_color
	add_child(e)
	e.global_position = pos
	e.remove_from_group("enemies")     # que nadie lo tome por un objetivo real
	e.process_mode = Node.PROCESS_MODE_DISABLED
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
	if GameManager.has_ability("talisman_frag_1"):
		return   # ya fue recogido en una sesión anterior
	var t := Area3D.new()
	t.set_script(TALISMAN_SCR)
	t.position = Vector3(0.0, 1.2, -44.0)   # S3, centro del pasillo de garras
	add_child(t)


# La persecución lanza rayos, así que va en _physics_process y no en _process.
# En _process corría una vez por cuadro renderizado: cuanto mejor el equipo, más
# rayos por segundo, y en la mina hay 230 cuerpos de colisión contra los que
# chocar. Aquí corre a la frecuencia fija de física y el coste deja de depender
# de los fps.
func _physics_process(delta: float) -> void:
	if not _chase_active:
		return
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.get("active") == true:
			if p.global_position.z > -2.0:
				_stop_chase()
				return
	if is_instance_valid(_chupacabras):
		_move_chupacabras(delta)
		_check_chupa_hit(delta)


# ─── Triggers dinámicos ───────────────────────────────────────────────────────

func _setup_triggers() -> void:
	_make_trigger(Vector3(0.0, 2.0, -17.0), Vector3(14.0, 5.0,  4.0), _on_combat_enter)
	_make_trigger(Vector3(0.0, 2.0, -47.0), Vector3( 6.0, 4.0,  6.0), _on_claw_enter)
	_make_trigger(Vector3(0.0, 1.5, -60.0), Vector3(17.0, 8.0,  4.0), _on_nest_enter)


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
	if body.is_in_group("player") and not _combat_cleared:
		_start_combat()


func _start_combat() -> void:
	_banner("¡Mineros corruptos en la mina!")
	var spawns: Array[Vector3] = [
		Vector3(-4.0, 0.5, -19.0),
		Vector3( 5.0, 0.5, -23.0),
		Vector3(-3.0, 0.5, -28.0),
		Vector3( 4.5, 0.5, -32.0),
		Vector3( 0.0, 0.5, -36.0),
	]
	_alive = spawns.size()
	for pos in spawns:
		var e: CharacterBody3D = ENEMY_NORMAL.instantiate()
		e.base_color = miner_color
		e.died.connect(_on_miner_died)
		add_child(e)
		e.global_position = pos


func _on_miner_died(_pos: Vector3, _xp: int) -> void:
	_alive -= 1
	if _alive <= 0:
		_combat_cleared = true
		_banner("Sector despejado… hay algo más abajo.", 3.0)
		if GameManager.get_beat() < 3:
			GameManager.set_beat(3)


# ─── Pasillo de Garras (S3) ───────────────────────────────────────────────────

func _on_claw_enter(body: Node3D) -> void:
	if body.is_in_group("player") and _combat_cleared and not _claw_fired:
		_trigger_claw_dialogue()


func _trigger_claw_dialogue() -> void:
	_claw_fired = true
	Sfx.play("boss", -4.0, 0.30)
	var res := DialogueManager.create_resource_from_text(DIALOGUE_GARRAS)
	DialogueManager.show_dialogue_balloon_scene(BALLOON, res, "start")


# ─── Nido / Persecución (S4) ──────────────────────────────────────────────────

func _on_nest_enter(body: Node3D) -> void:
	if body.is_in_group("player") and _combat_cleared and not _chase_active:
		_start_chase()


func _start_chase() -> void:
	_chase_active = true
	_banner("¡HUYE!")
	Sfx.play("boss", 3.0, 0.55)

	var c := CharacterBody3D.new()
	c.collision_layer = 4
	c.collision_mask  = 1

	var mat := StandardMaterial3D.new()
	mat.albedo_color = chupa_color
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.65
	cm.height = 2.4
	mi.mesh = cm
	mi.position.y = 1.2
	mi.set_surface_override_material(0, mat)
	c.add_child(mi)

	var lbl := Label3D.new()
	lbl.text = "CHUPACABRAS"
	lbl.position.y = 3.0
	lbl.pixel_size = 0.009
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color(0.9, 0.3, 1.0, 1)
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
	c.global_position = Vector3(0.0, -1.5, -70.0)
	_chupacabras = c
	_chupa_vel   = Vector3.ZERO
	_stall_pos   = Vector2(c.global_position.x, c.global_position.z)
	_stall_frames = 0
	_desvio      = 0.0
	_rumbo_ultimo = Vector3.ZERO
	_cuadros_rumbo = 0

	# 8 mineros de escape (solo normales, unkillable)
	var escape_pos: Array[Vector3] = [
		Vector3( 2.5, 0.5, -52.0),
		Vector3(-2.0, 0.5, -46.0),
		Vector3( 3.0, 0.5, -39.0),
		Vector3(-3.5, 0.5, -31.0),
		Vector3( 2.0, 0.5, -24.0),
		Vector3(-2.5, 0.5, -17.0),
		Vector3( 1.5, 0.5, -10.0),
		Vector3(-1.5, 0.5,  -5.0),
	]
	for pos in escape_pos:
		var m: CharacterBody3D = ENEMY_NORMAL.instantiate()
		m.base_color = miner_color
		m.speed      = 1.5
		m.max_health = 999.0
		add_child(m)
		m.global_position = pos
		m.remove_from_group("enemies")  # el compañero no los ataca durante la huida

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
			_chupa_hit_cd = 999.0   # evitar múltiples triggers
			_banner("¡El Chupacabras te atrapó!")
			# Matar a ambos jugadores → game over
			for pp in get_tree().get_nodes_in_group("player"):
				if is_instance_valid(pp) and pp.has_method("take_damage"):
					pp.take_damage(9999.0)
			get_tree().create_timer(2.0).timeout.connect(
				func() -> void: get_tree().reload_current_scene())
			return


func _stop_chase() -> void:
	if not _chase_active:
		return
	_chase_active = false
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
			if is_instance_valid(hud) and hud.has_method("clear_banner"):
				hud.clear_banner())
