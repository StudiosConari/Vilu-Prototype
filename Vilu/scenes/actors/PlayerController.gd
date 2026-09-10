extends CharacterBody3D

## Protagonista de VILU. Hay dos en el party: Emilia (melee) y Benjamín (arquero).
##
## MODO DE CONTROL:
##  - PLAYER: lo controlás con teclado/mouse (activo, con cámara).
##  - IA COMBAT: pelea solo (persigue, ataca básico, esquiva telegrafiados).
##  - FROZEN: se queda quieto (para puzzles).
## Game cambia el activo con R (deja al otro en IA) o T (deja al otro QUIETO).
##
## HABILIDADES (por personaje, algunas las entrega La Tirana / Carmen = has_bow):
##  - Emilia: base 1 golpe -> tras la Tirana, COMBO de 4 golpes. Alas: doble
##    salto + planeo.
##  - Benjamín: base flecha normal + flecha CARGADA (mantener clic). Tras la
##    Tirana: FLECHA TRIPLE (activable con clic der, gasta energía). Guanaco:
##    montura (Q).
##
## Controles (activo): WASD mover, Shift correr, Espacio saltar (doble con alas),
## clic izq atacar (melee o flecha, mantener = cargada), clic der flecha triple,
## Q montar (Benjamín), E interactuar.

signal health_changed(current: int, maximum: int)
signal energy_changed(current: int, maximum: int)
signal died
signal melee_hit(step: int)
signal arrow_fired

const ARROW_SCRIPT := preload("res://scenes/Arrow.gd")
const GUANACO_COMP_SCR := preload("res://scenes/actors/GuanacoCompanion.gd")
const ANIMADOR_SCR := preload("res://scenes/actors/AnimadorPersonaje.gd")
const MODELO_EMILIA := preload("res://models/personaje/emilia.glb")
const MODELO_BENJAMIN := preload("res://models/personaje/benjamin.glb")
const ALAS_SCR := preload("res://scenes/actors/AlasEspirituales.gd")
const ARMA_SCR := preload("res://scenes/actors/ArmaDeBenjamin.gd")
## Cuánto miden Emilia y Benjamín, en metros.
##
## Los modelos vienen de fábrica midiendo 1,00 m, así que este número es a la vez
## su escala y su estatura.
##
## Es SÓLO lo que se ve. El cuerpo con el que chocan sigue siendo la cápsula de
## `Player.tscn` —1,6 m de alto y 0,35 de radio—, y eso es a propósito: de esa
## cápsula dependen los saltos medidos de las plataformas del Isluga y la viga
## baja de la entrada de la mina, que hay que pasar agachándose. Agrandar el
## cuerpo cambiaría el plataformeo entero; agrandar el modelo, no.
const ALTO_PERSONAJE := 2.2

## SIGUIENDO: acompaña al activo, un paso atrás y al costado. QUIETO: se queda
## en su sitio. En ninguno de los dos pelea ni recibe daño: las batallas son del
## personaje que estás llevando.
## SENUELO: se aleja de `senuelo_de` para que la persiga, sin salirse de la
## arena. Es lo que hace Emilia con el Yastay mientras Benjamín sana.
enum AiMode { SIGUIENDO, FROZEN, SENUELO }

@export_group("Rol")
@export var is_archer := false

@export_group("Movimiento")
@export var walk_speed := 4.0
@export var run_speed := 7.5
@export var acceleration := 12.0
@export var jump_velocity := 6.0
@export var gravity := 18.0
@export var turn_speed := 14.0
@export var updraft_speed := 6.0    # velocidad de ascenso en una corriente (Emilia planeando)

## A qué velocidad te arrastra hacia abajo una corriente DESCENDENTE.
##
## Muy por encima de la de subida a propósito: la ascendente es una ayuda que se
## usa a voluntad, ésta es una trampa que hay que esquivar. A 6 m/s se salía
## caminando y no daba miedo ninguno.
@export var downdraft_speed := 24.0

@export_group("Vida y energía")
@export var max_health := 100
@export var max_energy := 100
@export var energy_regen := 18.0
@export var triple_cost := 35

@export_group("Combate")
@export var combo_window := 0.6
@export var attack_cooldown := 0.28
@export var melee_damage: Array[float] = [8.0, 8.0, 12.0, 18.0]   # combo de 4 (Emilia, tras la Tirana)
@export var melee_range := 1.1
@export var arrow_speed := 26.0
@export var arrow_damage := 10.0
@export var charge_time := 0.4      # mantener el clic este tiempo = flecha cargada
## Cuánto dura el agarre del golpe cargado, y con qué lo remata.
@export_group("Agarre")
@export var AGARRE_DURACION := 0.9
@export var AGARRE_ALCANCE := 1.6
@export var AGARRE_GOLPES := 4
@export var AGARRE_MULTIPLICADOR := 2.4

@export_group("Rodada")
## Cuánto dura la rodada, en segundos, PARA LOS DOS. El clip de cada personaje
## se acelera lo que haga falta para caber en este tiempo: el de Emilia dura
## 0,9 s y el de Benjamín 1,1, y con un ritmo fijo cada uno rodaba distinto y
## llegaba a distinta distancia. 0,57 es lo que duraba la de Emilia con el
## ritmo de antes (0,91 s de clip a 1,6), así que ella no cambia.
@export var rodada_duracion := 0.57
## Con 4.5 recorría 3.14 m y quedaba corta; a 6.75 son la mitad más.
@export var rodada_velocidad := 6.75
@export var rodada_espera := 0.8

@export_group("Patada corriendo")
## A qué velocidad se queda mientras patea en carrera. Sin esto seguía a 7.5 m/s
## durante todo el clip: 7.7 metros deslizándose en pose de patada.
@export var patada_velocidad := 3.0
## Impulso hacia arriba al patear DESDE EL SUELO. En el aire no se aplica: ahí ya
## venís volando y sumarle empuje alargaría el salto.
@export var patada_impulso := 3.0

@export_group("Arco")
## El clip del disparo rápido dura 2.47 s: a ritmo 1 Benjamín tiraría una flecha
## cada dos segundos y medio. A 4x queda en 0.62 s.
@export var ritmo_flecha := 4.0
## Cuánto se acelera el tramo de soltar y volver a reposo. Suelto dura 1.69 s.
@export var ritmo_soltar := 2.5

@export_group("Combate")

var health: int
var energy: float
var input_locked := false
var active := true
var ai_mode: int = AiMode.SIGUIENDO

# Estados de habilidad
var can_glide := false
var glide_gravity_scale := 0.35
var mounted := false
## Cuánto sube el jinete al montar, en metros desde sus pies. Es la altura del
## lomo del guanaco: por encima se ve flotando y por debajo se le hunden las
## piernas. Está expuesto porque el número depende del modelo, y el modelo
## cambia.
@export var alto_de_montura := 0.39
## Cuánto se hunde la cadera en el pelo del lomo al sentarse, en metros. En 0
## queda apoyada justo encima; un poco más y se lee como peso de verdad.
@export var hundimiento_en_el_lomo := 0.10
## Cuánto se adelanta el guanaco respecto del jinete, en metros. Sube este
## número y Benjamín se sienta más ATRÁS, hacia la grupa; bájalo y se va hacia
## el cuello. En 0 quedan en el mismo punto, que es como iba antes.
@export var avance_de_montura := 0.55
var in_updraft := false             # dentro de una corriente ascendente (lo setea Updraft.gd)
## Dentro de una corriente DESCENDENTE. Lo pone el mismo Updraft.gd.
var in_downdraft := false

# Interacción
var hud: CanvasLayer
var _interactable: Node = null

@onready var _visual: Node3D = $Visual
## El animador del personaje. Se llama `_emilia` por historia: al principio sólo
## ella tenía modelo. Ahora lo usan los dos.
var _emilia: Node3D = null
@onready var _wings_vis: Node3D = get_node_or_null("Visual/Wings")
var _alas: Node3D = null
var _arma: Node3D = null
@onready var _guanaco_vis: Node3D = get_node_or_null("Visual/Guanaco")

var _jumps_done := 0
var _jump_held_prev := false
var _e_held_prev := false
var _q_held_prev := false
var _c_held_prev := false
var _combo_step := 0
var _combo_timer := 0.0
var _attack_cd := 0.0
## Si hay un globo de diálogo abierto ahora mismo.
var _globo_abierto := false

var _charging := false
var _charge_t := 0.0
var _carga_usada := false
var _rodando := 0.0
var _rodada_cd := 0.0
var _rodada_dir := Vector3.ZERO
var _pateando := 0.0
var _energy_shown := -1
var forced_run_dir := Vector3.ZERO  # cuando no es ZERO, el personaje corre en esa dirección sin input (huida)
var _hold_pos := Vector3.ZERO      # puesto a defender en modo QUIETO


func _ready() -> void:
	health = max_health
	energy = float(max_energy)
	health_changed.emit(health, max_health)
	energy_changed.emit(int(energy), max_energy)
	DialogueManager.dialogue_started.connect(func(_r: Resource) -> void:
		_globo_abierto = true
		input_locked = true
		_bajarse_para_hablar()
		if _emilia != null: _emilia.hablar(true))
	DialogueManager.dialogue_ended.connect(func(_r: Resource) -> void:
		_globo_abierto = false
		if _emilia != null: _emilia.hablar(false)
		_volver_a_subirse()
		_devolver_el_control.call_deferred())
	can_glide = (not is_archer) and GameManager.has_ability("wings")
	_montar_emilia()
	_montar_alas()
	_montar_arma()
	GameManager.ability_unlocked.connect(_on_ability_unlocked)
	TravelManager.region_changed.connect(func(_r: String) -> void: forced_run_dir = Vector3.ZERO)


## Devuelve el control al cerrarse un diálogo, pero UN CUADRO DESPUÉS.
##
## El globo se cierra mientras se está repartiendo el clic de esa misma
## pulsación, y `dialogue_ended` llega antes de que el evento acabe de bajar
## hasta el jugador. Devolviendo el control ahí mismo, ese clic entraba como
## ataque: Benjamín empezaba a tensar y al soltar salía la flecha. Diferido, el
## desbloqueo cae al final del cuadro, cuando ese evento ya no existe.
func _devolver_el_control() -> void:
	if _globo_abierto:
		return   # encadenó con otro diálogo: sigue sin control
	input_locked = false


func _on_ability_unlocked(ability: String) -> void:
	if ability == "wings" and not is_archer:
		can_glide = true


# La Tirana (Carmen) mejora el combate: Emilia combo x4, Benjamín flecha triple.
func _upgraded() -> bool:
	return GameManager.has_ability("bow")


func _physics_process(delta: float) -> void:
	_combo_timer = max(0.0, _combo_timer - delta)
	_attack_cd = max(0.0, _attack_cd - delta)
	_rodada_cd = maxf(0.0, _rodada_cd - delta)
	_rodando = maxf(0.0, _rodando - delta)
	_pateando = maxf(0.0, _pateando - delta)
	if _charging:
		_charge_t += delta
		# Emilia: mantener el clic saca el golpe cargado, una sola vez por pulsación.
		if not is_archer and not _carga_usada and _charge_t >= charge_time:
			_carga_usada = true
			_golpe_cargado()
	energy = min(float(max_energy), energy + energy_regen * delta)
	if int(energy) != _energy_shown:
		_energy_shown = int(energy)
		energy_changed.emit(_energy_shown, max_energy)
	# Derrotado no se hace nada más que caer al suelo: ni moverse, ni saltar,
	# ni pegar. Game lo levanta al rato en el inicio de la zona.
	if _derrotado:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * delta
		move_and_slide()
		return

	# --- Gravedad / planeo / corriente ascendente + reset de saltos ---
	# La corriente que EMPUJA HACIA ABAJO manda sobre todo lo demás.
	#
	# Va primero a propósito: dentro de una de éstas no valen ni las alas ni el
	# planeo. Es lo contrario de la ascendente —que es una ayuda y por eso pide
	# alas y mantener el salto—: ésta es una trampa, y una trampa de la que se
	# puede salir planeando no es una trampa.
	if in_downdraft:
		velocity.y = move_toward(velocity.y, -downdraft_speed, 60.0 * delta)
		_jumps_done = 2          # ni salto ni doble salto mientras te arrastra
	elif active and in_updraft and can_glide and Input.is_action_pressed("jump"):
		velocity.y = move_toward(velocity.y, updraft_speed, 40.0 * delta)   # Emilia sube en la corriente
		_jumps_done = 0
	elif is_on_floor():
		_jumps_done = 0
	else:
		var g := gravity
		if active and can_glide and Input.is_action_pressed("jump") and velocity.y < 0.0:
			g *= glide_gravity_scale
		velocity.y -= g * delta

	# --- Dirección según el modo ---
	var dir := Vector3.ZERO
	if _dormido > 0.0:
		# Dormido: ni input ni IA. La rama va PRIMERO para que ni siquiera se
		# llame a `_player_input`, que es donde vive el salto: con sólo anular
		# la dirección seguirías saltando dormido. Los ataques NO pasan por
		# aquí —viven en `_unhandled_input`— y se cortan con su propia guarda.
		_dormido -= delta
		if _dormido <= 0.0:
			_despertar()
		dir = Vector3.ZERO
	elif input_locked:
		dir = Vector3.ZERO
	elif active:
		dir = _player_input()
		# Strafe durante auto-run: el activo controla izquierda/derecha.
		if forced_run_dir != Vector3.ZERO:
			var ix := 0.0
			if Input.is_action_pressed("move_right"): ix += 1.0
			if Input.is_action_pressed("move_left"): ix -= 1.0
			var right := forced_run_dir.cross(Vector3.UP).normalized()
			dir = (forced_run_dir + right * ix * 0.5).normalized()
	elif forced_run_dir != Vector3.ZERO:
		# Huida forzada: corre sin pasar por el seguimiento.
		# Pero sí por la esquiva: la mina está llena de pilares y correr a ciegas
		# en línea recta es justamente lo que lo dejaba clavado contra uno.
		dir = _rumbo_esquivando(forced_run_dir)
	elif ai_mode == AiMode.SIGUIENDO:
		dir = _rumbo_esquivando(_ai_behavior())
	elif ai_mode == AiMode.SENUELO:
		dir = _rumbo_esquivando(_senuelo_behavior())
	else:
		dir = _hold_behavior()   # QUIETO: se queda en su puesto

	# La IA/guardia no se tira a los vacíos... salvo que enfrente haya donde caer.
	#
	# Frenarse en seco en cada borde deja al compañero plantado al filo de una
	# plataforma con la siguiente a dos metros y a la misma altura, que es lo que
	# pasaba en el volcán. Antes de rendirse se mira si el suelo vuelve a
	# aparecer dentro de lo que alcanza un salto.
	var saltar_hueco := false
	if not active and forced_run_dir == Vector3.ZERO and dir != Vector3.ZERO \
			and not _has_ground_ahead(dir):
		if _hay_donde_caer(dir):
			saltar_hueco = true
		else:
			dir = Vector3.ZERO

	# El personaje inactivo salta los estorbos bajos (huida forzada o follow).
	#
	# Sólo si por encima hay hueco. Antes saltaba ante cualquier cosa que tuviera
	# delante, muros y barreras incluidos: se quedaba dando botes contra ellos
	# indefinidamente, sin tocar el suelo y sin avanzar. Si lo de delante llega a
	# la altura del pecho no es un escalón, es una pared, y de eso se encarga la
	# esquiva.
	if not active and is_on_floor():
		_cruzando_hueco = false        # tocó suelo: el cruce terminó
		var check_dir := forced_run_dir if forced_run_dir != Vector3.ZERO else dir
		var estorbo: bool = check_dir != Vector3.ZERO and _estorbo_bajo(check_dir) \
			and _paso_libre(check_dir, 1.4)
		if saltar_hueco or estorbo:
			velocity.y = jump_velocity
			_jumps_done = 1
			_cruzando_hueco = saltar_hueco

	# Rodando manda la rodada: dirección fija desde que arrancó y a su velocidad,
	# sin que el WASD la desvíe. Es lo que la hace servir para esquivar; si se
	# pudiera girar a mitad, sería sólo correr más rápido.
	if _rodando > 0.0:
		dir = _rodada_dir

	var speed := walk_speed
	if _rodando > 0.0:
		speed = rodada_velocidad
	elif _pateando > 0.0:
		# En plena patada de carrera se frena: es un golpe, no un desplazamiento.
		speed = patada_velocidad
	elif forced_run_dir != Vector3.ZERO:
		speed = run_speed
	elif active and not input_locked and Input.is_action_pressed("run"):
		speed = run_speed
	elif not active and ai_mode == AiMode.SIGUIENDO:
		speed = _velocidad_de_escolta()
	elif not active and ai_mode == AiMode.SENUELO:
		speed = run_speed
	# Cruzando un hueco hace falta carrerilla: el salto dura ~0.67 s, y a paso de
	# caminar eso son 2.7 m de alcance. Con la velocidad de correr pasan de 5 m,
	# que es lo que hay entre las plataformas del volcán.
	if not active and _cruzando_hueco:
		speed = maxf(speed, run_speed)
	if mounted:
		speed *= 1.5

	velocity.x = move_toward(velocity.x, dir.x * speed, acceleration * speed * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, acceleration * speed * delta)
	var antes := global_position
	move_and_slide()
	_vigilar_encajado(antes, dir, delta)

	# El rescate SÓLO mientras sigue al líder.
	#
	# En modo QUIETO —la [T], para resolver puzzles cada uno por su lado— el
	# compañero está lejos a propósito, y teletransportarlo de vuelta hacía
	# imposibles esos puzzles. Tampoco se le rescata en el aire: cruzando un
	# hueco está lejos y sin avanzar en horizontal, que es exactamente lo que el
	# detector confunde con estar atascado.
	if not active and ai_mode == AiMode.SIGUIENDO and forced_run_dir == Vector3.ZERO \
			and not _cruzando_hueco:
		_vigilar_atasco(delta)

	# --- Encarar el movimiento (solo el Visual rota; -Z adelante) ---
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	if hv.length() > 0.15:
		var target_yaw := atan2(-hv.x, -hv.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, turn_speed * delta)

	# Las alas del Alicanto sólo se ven cuando se están USANDO: desde el segundo
	# salto hasta tocar suelo, y mientras planeás. Antes aparecían en cuanto
	# desbloqueabas la habilidad y ya no se guardaban nunca, ni caminando.
	var planeando := _planeando()
	var alas_fuera: bool = can_glide and (_jumps_done >= 2 or planeando)
	if _alas != null:
		_alas.mostrar(alas_fuera, planeando)

	# El arco cambia de agarre al tensar. El `_attack_cd` mantiene el agarre de
	# tiro un momento más, mientras dura la animación de soltar: si no, el arco
	# se recoloca en mitad del disparo.
	if _arma != null:
		_arma.apuntar(_charging or _attack_cd > 0.0)
	elif _wings_vis:
		_wings_vis.visible = alas_fuera
	# El cubo café placeholder ya no se usa: la montura es el guanaco compañero real.
	if _guanaco_vis:
		_guanaco_vis.visible = false

	# Si el guanaco desapareció (cambio de zona, etc.) dejamos de estar montados.
	if mounted and guanaco_companion() == null:
		mounted = false
		_pose_de_montado(false)
	# Montado: el jinete se eleva para quedar sentado sobre el lomo del guanaco.
	_visual.position.y = lerp(_visual.position.y,
		_alto_para_sentarse() if mounted else 0.0, 12.0 * delta)


## Cuánto hay que subir el muñeco para que la cadera toque el lomo.
##
## Se calcula con lo que hay delante: el lomo lo mide el guanaco de su propia
## malla y la cadera se lee del esqueleto en la pose de jinete. Restando una de
## otra sale el número, y no envejece: cambió el modelo del guanaco y Benjamín
## quedó flotando porque `alto_de_montura` seguía siendo el del modelo viejo.
## Ese export queda como respaldo para cuando no hay de dónde medir.
func _alto_para_sentarse() -> float:
	if not is_inside_tree():
		return alto_de_montura
	var g := guanaco_companion()
	if g == null or not g.has_method("altura_del_lomo"):
		return alto_de_montura
	var cadera := _altura_de_la_cadera()
	if cadera <= 0.0:
		return alto_de_montura
	return maxf(float(g.call("altura_del_lomo")) - cadera + hundimiento_en_el_lomo, 0.0)


## La cadera del muñeco, en metros sobre el origen del Visual, con la pose que
## tenga puesta ahora. -1 si no hay esqueleto que mirar.
func _altura_de_la_cadera() -> float:
	var esq := _esqueleto_de(_emilia)
	if esq == null or _visual == null:
		return -1.0
	var i := esq.find_bone("mixamorig_Hips")
	if i < 0:
		return -1.0
	var cadera: Vector3 = (esq.global_transform * esq.get_bone_global_pose(i)).origin
	return cadera.y - _visual.global_position.y


## Cuánto queda dormido, en segundos. 0 = despierto.
var _dormido := 0.0
var _zzz: Label3D = null


## Lo deja fuera de combate un rato. Lo llama el golpe de área de Lola.
##
## Se queda con el sueño MÁS LARGO en vez de sumarlos: dos golpes seguidos no
## deberían encadenar veinte segundos de no poder jugar.
func dormir(segundos: float) -> void:
	if segundos <= 0.0:
		return
	_dormido = maxf(_dormido, segundos)
	_charging = false
	if _zzz == null:
		_zzz = Label3D.new()
		_zzz.text = "Zzz"
		_zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_zzz.modulate = Color(0.75, 0.85, 1.0)
		_zzz.outline_size = 8
		_zzz.font_size = 28
		_zzz.position = Vector3(0.0, 2.0, 0.0)
		add_child(_zzz)
	_zzz.visible = true
	# Se desploma de lado: el cartel solo se lee raro si el personaje sigue
	# tieso y mirando al frente.
	create_tween().tween_property(_visual, "rotation:z", deg_to_rad(-70.0), 0.35)


func _despertar() -> void:
	_dormido = 0.0
	if _zzz:
		_zzz.visible = false
	create_tween().tween_property(_visual, "rotation:z", 0.0, 0.3)


## true mientras esté dormido. Lo consulta el HUD y la IA del compañero.
func esta_dormido() -> bool:
	return _dormido > 0.0


# --- Control del jugador (WASD/salto/mount/interact) ---
func _player_input() -> Vector3:
	# Por FUERZA y no por pulsado, para que el stick module.
	#
	# Una tecla vale 0 o 1, así que con teclado esto es exactamente lo de antes.
	# Un stick vale lo que esté inclinado, y así medio empujado se camina y al
	# tope se corre — que es lo que espera cualquiera que agarre un mando; con
	# `is_action_pressed` el stick era un teclado con forma rara.
	#
	# `_camera_relative` sólo normaliza lo que pase de 1, así que el valor
	# intermedio sobrevive hasta la velocidad.
	var iz: float = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var ix: float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var dir := _camera_relative(ix, iz)

	# Salto (doble con alas)
	var jump_held := Input.is_action_pressed("jump")
	if jump_held and not _jump_held_prev:
		if is_on_floor():
			velocity.y = jump_velocity * (1.15 if mounted else 1.0)
			_jumps_done = 1
			_animar_salto(dir)
			# Montado, el que brinca es el jinete: el guanaco no despega solo.
			# Pateando a la vez, el salto se lee como suyo.
			if mounted:
				var g := guanaco_companion()
				if g != null and g.has_method("saltar"):
					g.saltar()
		elif can_glide and _jumps_done < 2:
			velocity.y = jump_velocity
			_jumps_done = 2
			_animar_salto(dir)
	_jump_held_prev = jump_held

	# Interacción (E)
	var e_held := Input.is_action_pressed("interact")
	if e_held and not _e_held_prev and _interactable != null and _interactable.has_method("interact"):
		_interactable.interact(self)
	_e_held_prev = e_held

	# Guanaco — solo Benjamín. Q lo invoca o lo guarda; C sube y baja.
	if is_archer and GameManager.has_ability("guanaco"):
		var q_held := Input.is_action_pressed("guanaco")
		if q_held and not _q_held_prev:
			_alternar_guanaco()
		_q_held_prev = q_held
		var c_held := Input.is_action_pressed("guanaco_montar")
		if c_held and not _c_held_prev:
			_alternar_montura()
		_c_held_prev = c_held

	return dir


# --- Guanaco compañero (Benjamín, tras la bendición del Yastay) ---
## Q: sin guanaco lo invoca; con guanaco lo guarda (bajándose antes si iba
## montado).
##
## Antes Q hacía las tres cosas en ciclo —invocar, montar, guardar— y no había
## forma de bajarse sin que el guanaco desapareciera. Ahora montar y bajarse
## son cosa de C, y el guanaco se queda esperando al lado.
func _alternar_guanaco() -> void:
	var g := guanaco_companion()
	if g == null:
		_summon_guanaco()
		return
	if mounted:
		_bajarse()
	g.queue_free()


## C: sube al guanaco, y otra vez, se baja sin guardarlo. Sin guanaco no hace
## nada: invocarlo es cosa de Q.
func _alternar_montura() -> void:
	var g := guanaco_companion()
	if g == null:
		return
	if mounted:
		_bajarse()
	else:
		_subirse()


func _subirse() -> void:
	var g := guanaco_companion()
	if g == null or mounted:
		return
	mounted = true
	if g.has_method("set_mounted"):
		g.set_mounted(true)
	_pose_de_montado(true)


func _bajarse() -> void:
	if not mounted:
		return
	mounted = false
	var g := guanaco_companion()
	if g != null and g.has_method("set_mounted"):
		g.set_mounted(false)
	_pose_de_montado(false)


## Lo que hacía Q antes, para lo que todavía lo llame por ese nombre.
func _cycle_guanaco() -> void:
	if guanaco_companion() == null:
		_summon_guanaco()
	elif not mounted:
		_subirse()
	else:
		_alternar_guanaco()


## Se baja del guanaco para hablar y vuelve a subirse al terminar.
##
## Hablar montado dejaba al guanaco parado debajo de Benjamín, con él sentado
## en el aire y el clip de hablar peleando con la pose de jinete. Al abrirse un
## diálogo se desmonta —el guanaco se queda invocado y se pone a su lado, como
## cuando lo sigue— y al cerrarse vuelve a montarlo solo, sin pulsar nada.
var _remontar_al_terminar := false


func _bajarse_para_hablar() -> void:
	if not mounted:
		return
	_bajarse()
	_remontar_al_terminar = true


func _volver_a_subirse() -> void:
	if not _remontar_al_terminar:
		return
	_remontar_al_terminar = false
	_subirse()


func _summon_guanaco() -> void:
	var g := Node3D.new()
	g.set_script(GUANACO_COMP_SCR)
	_al_mundo(g)
	# Aparece donde después va a seguirte: a un lado, a la misma distancia.
	g.global_position = global_position + _visual.global_transform.basis.x * GUANACO_COMP_SCR.FOLLOW_DIST


func guanaco_companion() -> Node3D:
	for g in get_tree().get_nodes_in_group("guanaco_companion"):
		if is_instance_valid(g):
			return g
	return null


func _unhandled_input(event: InputEvent) -> void:
	# El sueno se comprueba aqui tambien: esta funcion NO pasa por el bloque de
	# direccion de _physics_process, corre por su cuenta al llegar el evento.
	# Sin esta guarda se sigue pegando y disparando tirado en el suelo.
	if not active or input_locked or _dormido > 0.0:
		return
	# Ataque (melee, o flecha normal/cargada del arquero).
	if event.is_action_pressed("rodar") and not event.is_echo():
		_rodar()
		return
	if event.is_action_pressed("attack"):
		_charging = true
		_charge_t = 0.0
		_carga_usada = false
		if is_archer:
			Sfx.play("tensar_arco", -5.0)
		if is_archer and _emilia != null:
			# Empieza a tensar y se queda en la máxima extensión hasta que sueltes.
			_emilia.call("tensar")
		# Emilia NO pega al pulsar: pegaba un jab y encima salía el cargado, dos
		# golpes por una sola pulsación. Ahora el toque corto saca el golpe de la
		# cadena al SOLTAR, y mantener saca sólo el cargado (ver _physics_process).
	elif event.is_action_released("attack"):
		if not is_archer:
			# `_charging` dice que la PULSACIÓN se aceptó. Sin comprobarlo, soltar
			# el botón sin haberlo pulsado sacaba un golpe de la nada: es lo que
			# pasaba con el clic que cierra un globo de diálogo, porque para
			# entonces el control ya estaba devuelto. El arquero ya lo miraba.
			var hubo_pulsacion := _charging
			var fue_cargado := _carga_usada
			_charging = false
			_carga_usada = false
			if hubo_pulsacion and not fue_cargado:
				_melee_attack()   # fue un toque: golpe normal de la cadena
		elif is_archer and _charging:
			var charged := _charge_t >= charge_time
			_charging = false
			if _emilia != null:
				# Cargada: termina la animación desde donde quedó tensando.
				# Rápida: es otro clip, y acelerado.
				if charged:
					_emilia.call("soltar", ritmo_soltar)
				else:
					_emilia.call("flecha", ritmo_flecha)
			_shoot_arrow(charged)
		else:
			_charging = false
	# Flecha triple (Benjamín). El clic derecho quedó para rotar la cámara.
	elif event.is_action_pressed("triple_arrow") and not event.is_echo():
		if is_archer:
			_triple_arrow()


## Convierte input WASD (ix derecha, iz adelante) a dirección en el mundo relativa
## a hacia dónde mira la cámara (para que W sea "hacia adentro de la pantalla").
func _camera_relative(ix: float, iz: float) -> Vector3:
	if ix == 0.0 and iz == 0.0:
		return Vector3.ZERO
	var cam := get_viewport().get_camera_3d()
	var fwd := Vector3(0, 0, -1)
	var right := Vector3(1, 0, 0)
	if cam:
		fwd = -cam.global_transform.basis.z
		fwd.y = 0.0
		right = cam.global_transform.basis.x
		right.y = 0.0
		fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3(0, 0, -1)
		right = right.normalized() if right.length() > 0.01 else Vector3(1, 0, 0)
	var d := fwd * iz + right * ix
	return d.normalized() if d.length() > 1.0 else d


func _facing() -> Vector3:
	return (-_visual.global_transform.basis.z).normalized()


func _face(to: Vector3) -> void:
	to.y = 0.0
	if to.length() > 0.05:
		_visual.rotation.y = atan2(-to.x, -to.z)


## Dirección de apuntado del jugador: del personaje hacia el punto del mundo bajo
## el MOUSE (proyección de la cámara sobre el plano del pecho). Si no se puede,
## cae al encare actual.
func _aim_direction() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return _facing()
	var mouse := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse)
	var ray := cam.project_ray_normal(mouse)
	var plane_y := global_position.y + 1.0
	if absf(ray.y) < 0.0001:
		return _facing()
	var t := (plane_y - from.y) / ray.y
	if t <= 0.0:
		return _facing()
	var point := from + ray * t
	var dir := point - (global_position + Vector3(0.0, 1.0, 0.0))
	dir.y = 0.0
	if dir.length() < 0.15:
		return _facing()
	return dir.normalized()


func _face_aim() -> Vector3:
	var d := _aim_direction()
	_visual.rotation.y = atan2(-d.x, -d.z)
	return d


## Un sonido por eslabón de la cadena, en el orden en que salen.
##
## Antes eran dos sonidos generados —"punch" para los dos primeros y "kick" para
## los dos últimos— con el tono subiendo a cada paso para disimular. Ahora son
## cuatro grabados distintos: el combo se OYE avanzar, y el cuarto suena a
## remate en vez de a la misma patada un poco más aguda.
##
## El tono ya no se toca: estos vienen grabados con su propio carácter y
## acelerarlos les quitaba el golpe.
const SONIDO_DEL_GOLPE := [
	"golpe_puno", "golpe_cruzado", "golpe_patada", "golpe_patada_final",
]


# --- Melee (Emilia): combo de 4 golpes tras la Tirana; 1 golpe antes ---
func _melee_attack() -> void:
	if _attack_cd > 0.0:
		return
	var max_step := (melee_damage.size() - 1) if _upgraded() else 0
	if _combo_timer > 0.0 and _combo_step < max_step:
		_combo_step += 1
	else:
		_combo_step = 0
	_combo_timer = combo_window
	_attack_cd = attack_cooldown

	var dmg: float = melee_damage[_combo_step]
	Sfx.play(SONIDO_DEL_GOLPE[_combo_step], -3.0)
	_face_aim()                # encara hacia el mouse antes de golpear
	_squash()
	_spawn_melee_hit(dmg)
	melee_hit.emit(_combo_step)

	# La espera hasta el golpe siguiente la marca la ANIMACIÓN: se puede encadenar
	# EN EL IMPACTO, cuando el brazo o la pierna llegan a su máxima extensión, que
	# es donde el golpe conecta. Antes eran 0.28 s fijos y el clip se cortaba mucho
	# antes de la mitad.
	#
	# El remate de la cadena es la excepción: ése se ve entero.
	if _emilia != null:
		var corte: float = _emilia.call("golpe", _combo_step)
		if corte > 0.0:
			_attack_cd = corte
		if String(_emilia.call("ultimo_clip")) == "patada_corriendo":
			_pateando = corte
			# Un saltito, sólo si sale del suelo. El arco lo pone la gravedad, no la
			# animación: al clip se le aplanó la altura porque despegaba 1.89 m.
			if is_on_floor() and patada_impulso > 0.0:
				velocity.y = patada_impulso
			# La ventana tiene que seguir abierta cuando termine la espera, o la
			# cadena se reiniciaría sola antes de poder encadenar.
			_combo_timer = _attack_cd + combo_window


func _spawn_melee_hit(dmg: float) -> void:
	var hit := Area3D.new()
	hit.collision_mask = 4
	hit.monitoring = true
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = melee_range
	cs.shape = sh
	hit.add_child(cs)
	_al_mundo(hit)
	hit.global_position = global_position + Vector3(0.0, 0.9, 0.0) + _facing() * 1.0
	var hit_pos := hit.global_position
	hit.body_entered.connect(func(b: Node3D) -> void:
		if (b.is_in_group("enemies") or b.is_in_group("hittable")) and b.has_method("take_damage"):
			b.take_damage(dmg, hit_pos, 5.0))
	get_tree().create_timer(0.12).timeout.connect(hit.queue_free)


# --- Arco (Benjamín) ---
func _shoot_arrow(charged: bool) -> void:
	if _attack_cd > 0.0:
		return
	_attack_cd = 0.4 if charged else 0.22
	_spawn_arrow(_face_aim(), charged)   # apunta hacia el mouse
	# La cargada suena un punto más grave, que es lo que la distingue de oído.
	Sfx.play("flecha", -3.0, 0.92 if charged else 1.0)
	arrow_fired.emit()


func _triple_arrow() -> void:
	if not _upgraded():
		_banner("Flecha triple: habla con La Tirana")
		return
	if energy < float(triple_cost):
		_banner("Sin energía para la flecha triple")
		return
	if _attack_cd > 0.0:
		return
	_attack_cd = 0.3
	# La habilidad se ve entera: la espera la marca su propio clip.
	if _emilia != null:
		var dura: float = _emilia.call("flecha_triple", ritmo_flecha)
		if dura > 0.0:
			_attack_cd = dura
	energy -= float(triple_cost)
	var fwd := _face_aim()      # apunta el abanico hacia el mouse
	for ang in [-0.22, 0.0, 0.22]:
		_spawn_arrow(fwd.rotated(Vector3.UP, ang), false)
	Sfx.play("flecha", -2.0, 1.06)   # las tres a la vez, un poco más agudo
	arrow_fired.emit()


func _spawn_arrow(dir: Vector3, pierce: bool) -> void:
	var arrow := Area3D.new()
	arrow.set_script(ARROW_SCRIPT)
	_al_mundo(arrow)
	arrow.add_to_group("arrow")
	arrow.global_position = global_position + Vector3(0.0, 1.2, 0.0) + dir * 0.6
	arrow.setup(dir, arrow_speed * (1.3 if pierce else 1.0), arrow_damage * (1.8 if pierce else 1.0), pierce)


func _squash() -> void:
	_visual.scale = Vector3(1.2, 0.8, 1.2)
	var t := create_tween()
	t.tween_property(_visual, "scale", Vector3.ONE, 0.15)


# --- IA de combate del compañero (ataques básicos + esquiva) ---
## A partir de esta distancia del líder el compañero deja de caminar y trota.
const ESCOLTA_TROTE := 3.0
## Y a partir de ésta corre más rápido que nadie, para recuperar terreno.
const ESCOLTA_SPRINT := 8.0
## Cuánto se le permite pasarse de run_speed mientras recupera.
const ESCOLTA_SOBREPASO := 1.3


## Velocidad del compañero, acompasada a la del líder.
##
## Iba siempre a walk_speed (4.0) mientras el activo corre a run_speed (7.5) con
## Shift: bastaba con mantener la tecla apretada para dejarlo atrás y perderlo de
## vista, y en la huida de la mina se quedaba con el Chupacabras.
##
## Tres tramos. Al lado camina, para que no vaya dando tirones cuando el líder
## se para. Descolgado corre. Y ya lejos corre un poco MÁS rápido que el
## máximo del jugador, que es la única forma de recortar distancia en vez de
## conservar la que quedó; el sobrepaso se apaga solo a los 8 m, así que nunca
## se le echa encima.
func _velocidad_de_escolta() -> float:
	var lider := _leader()
	if lider == null:
		return walk_speed
	var d := Vector2(lider.global_position.x - global_position.x,
		lider.global_position.z - global_position.z).length()
	if d >= ESCOLTA_SPRINT:
		return run_speed * ESCOLTA_SOBREPASO
	if d >= ESCOLTA_TROTE:
		return run_speed
	# Pegado, pero el líder viene lanzado: igualarle el paso antes de descolgarse,
	# en vez de esperar a estar a tres metros para reaccionar.
	var vl := Vector2(lider.velocity.x, lider.velocity.z).length()
	return clampf(vl, walk_speed, run_speed)


# ─── Esquiva del compañero ────────────────────────────────────────────────────

## Desvíos que prueba cuando tiene algo delante, en grados. De menor a mayor
## para apartarse lo justo, y en pares para no tener manía a un lado.
const ESQUIVA_DESVIOS := [30.0, -30.0, 55.0, -55.0, 85.0, -85.0, 120.0, -120.0, 150.0, -150.0]
## Sonda de "¿puedo seguir de frente?", en metros.
const ESQUIVA_SONDA := 1.3
## Sonda al elegir desvío. Más larga a propósito: un hueco de un metro puede ser
## un rincón sin salida, y meterse ahí es cambiar un atasco por otro.
const ESQUIVA_SONDA_LARGA := 3.0
## Alturas a las que mira, en metros sobre los pies.
##
## Deliberadamente por ENCIMA de lo que puede saltar. El salto sube 6²/(2·18) =
## 1.0 m, así que las vías y las cajas bajas ya las supera solo y mirarlas aquí
## sólo conseguiría que las rodease dando un absurdo rodeo. A 1.1 y 1.6 sólo
## aparece lo que de verdad no puede pasar: pilares, vagonetas, muros.
const ESQUIVA_ALTURAS := [1.1, 1.6]
## Cada cuántos cuadros de física se vuelve a abrir el abanico. Entre medias se
## reutiliza el último rumbo: son hasta 36 rayos y decidir 15 veces por segundo
## sobra para alguien que camina a 4 m/s.
const ESQUIVA_CUADROS := 4
## Segundos sin acercarse tras los que se le devuelve junto al líder.
const ESQUIVA_RESCATE := 3.0
## Y sólo si está al menos a esta distancia: teletransportarlo a dos pasos se
## vería como un fallo. A cuatro metros y medio ya está fuera del hombro del
## jugador, que es donde se le busca con la vista.
const ESQUIVA_RESCATE_DIST := 4.5

## Desvío que viene usando, en grados. 0 = va de frente.
var _desvio := 0.0
var _cuadros_rumbo := 0
var _rumbo_ultimo := Vector3.ZERO
var _atasco := 0.0
var _pos_previa := Vector3.ZERO
## Lo más cerca que ha llegado del líder en este tramo.
var _mejor_dist := INF


## Rumbo del compañero, rodeando lo que tenga delante.
##
## `_ai_behavior` devuelve la dirección DESEADA, en línea recta hacia el líder o
## hacia el enemigo. En campo abierto basta, pero la mina está llena de pilares,
## vagonetas y vigas: el compañero se clavaba contra uno y se quedaba ahí
## empujando para siempre.
##
## Esto es dirección asistida, no búsqueda de camino. Rodea un obstáculo suelto,
## que es lo que pasa el 95% de las veces. Para un laberinto de verdad haría
## falta un NavigationAgent3D con su navmesh; de los callejones sin salida se
## encarga el rescate de más abajo.
func _rumbo_esquivando(deseado: Vector3) -> Vector3:
	if deseado == Vector3.ZERO:
		_desvio = 0.0
		_rumbo_ultimo = Vector3.ZERO
		return deseado

	_cuadros_rumbo -= 1
	if _cuadros_rumbo > 0 and _rumbo_ultimo != Vector3.ZERO:
		# Entre recálculos se reutiliza el rumbo, girado hacia donde quiere ir,
		# para que curve en vez de avanzar a trompicones.
		_rumbo_ultimo = _rumbo_ultimo.lerp(deseado, 0.4).normalized()
		return _rumbo_ultimo
	_cuadros_rumbo = ESQUIVA_CUADROS
	_rumbo_ultimo = _elegir_rumbo(deseado)
	return _rumbo_ultimo


func _elegir_rumbo(deseado: Vector3) -> Vector3:
	if _paso_libre(deseado, ESQUIVA_SONDA):
		_desvio = 0.0
		return deseado
	# Mantener el desvío que ya venía usando mientras siga despejado. Sin esta
	# memoria, delante de un pilar centrado elige +30° y -30° alternándose y se
	# queda vibrando en el sitio en vez de rodearlo.
	if _desvio != 0.0:
		var seguir := deseado.rotated(Vector3.UP, deg_to_rad(_desvio))
		if _paso_libre(seguir, ESQUIVA_SONDA_LARGA):
			return seguir
	for grados: float in ESQUIVA_DESVIOS:
		var alt := deseado.rotated(Vector3.UP, deg_to_rad(grados))
		if _paso_libre(alt, ESQUIVA_SONDA_LARGA):
			_desvio = grados
			return alt
	# Ninguna salida aguanta la sonda larga: con que haya hueco inmediato vale.
	for grados: float in ESQUIVA_DESVIOS:
		var alt := deseado.rotated(Vector3.UP, deg_to_rad(grados))
		if _paso_libre(alt, ESQUIVA_SONDA):
			_desvio = grados
			return alt
	# Encerrado por todos lados: insistir de frente y que lo saque el rescate.
	_desvio = 0.0
	return deseado


func _paso_libre(dir: Vector3, largo: float) -> bool:
	var espacio := get_world_3d().direct_space_state
	var d := dir.normalized()
	for ry: float in ESQUIVA_ALTURAS:
		var o := global_position + Vector3(0.0, ry, 0.0)
		var q := PhysicsRayQueryParameters3D.create(o, o + d * largo)
		q.collision_mask = 1
		q.exclude = [get_rid()]
		if not espacio.intersect_ray(q).is_empty():
			return false
	return true


## Alcance del salto en horizontal, en metros.
##
## El salto sale a 6 m/s con gravedad 18: sube 6²/(2·18) = 1.0 m y está 2·6/18 =
## 0.67 s en el aire. A la velocidad de correr (7.5) eso son 5 m de alcance
## teórico; se comprueba hasta 4.2 para dejar margen al aterrizaje.
const HUECO_ALCANCE := 4.2
## Cuánto puede SUBIR el otro lado y seguir siendo alcanzable de un salto.
const HUECO_DESNIVEL := 0.9
## Y cuánto puede BAJAR.
##
## Este límite es el que evita los suicidios. Antes admitía cualquier cosa hasta
## 2.5 m por debajo, con el argumento de que caerse tampoco es grave. En el
## volcán sí lo es: bajo la lava hay terreno sólido, así que el rayo encontraba
## "sitio donde aterrizar" al otro lado del borde y el compañero se tiraba a la
## lava tan contento. Un escalón de 1.2 m se baja; más abajo, no es un escalón.
const HUECO_CAIDA := 1.2


## ¿Hay suelo al otro lado del hueco, dentro de lo que alcanza el salto?
##
## Se muestrea a distancias crecientes y se busca el PRIMER punto con suelo a una
## altura alcanzable. Además el aire de en medio tiene que estar despejado: si lo
## que hay delante es un muro con suelo detrás, saltar sólo sirve para chocar.
func _hay_donde_caer(dir: Vector3) -> bool:
	if not _paso_libre(dir, HUECO_ALCANCE * 0.6):
		return false
	var espacio := get_world_3d().direct_space_state
	var d := dir.normalized()
	var y0 := global_position.y
	var dist := 1.4
	while dist <= HUECO_ALCANCE:
		var p := global_position + d * dist
		# El rayo no baja más de lo que se admite como aterrizaje: si bajara
		# más, encontraría el fondo del cráter y lo daría por bueno.
		var q := PhysicsRayQueryParameters3D.create(
			p + Vector3(0.0, HUECO_DESNIVEL, 0.0), p - Vector3(0.0, HUECO_CAIDA, 0.0))
		q.collision_mask = 1
		q.exclude = [get_rid()]
		var h := espacio.intersect_ray(q)
		if not h.is_empty():
			var salto: float = (h["position"] as Vector3).y - y0
			if salto <= HUECO_DESNIVEL and salto >= -HUECO_CAIDA:
				return true
		dist += 0.6
	return false


## Va cruzando un hueco de un salto: mientras dure necesita velocidad de carrera
## y no se le puede dar por atascado.
var _cruzando_hueco := false


## ¿Hay algo a la altura de los pies o las rodillas en esa dirección?
func _estorbo_bajo(dir: Vector3) -> bool:
	var espacio := get_world_3d().direct_space_state
	var d := dir.normalized()
	for ry: float in [0.3, 0.7]:
		var o := global_position + Vector3(0.0, ry, 0.0)
		var q := PhysicsRayQueryParameters3D.create(o, o + d * 1.2)
		q.collision_mask = 1
		q.exclude = [get_rid()]
		if not espacio.intersect_ray(q).is_empty():
			return true
	return false


## ¿Choca, contando también estar YA metido dentro de algo?
##
## `test_move` a secas ignora el solape inicial: preguntado desde dentro de una
## pared responde que el camino está libre. Eso abrió un agujero grave en la
## subida de escalón —la comprobación «a la altura del escalón hay hueco» daba
## que sí estando la cápsula dentro del muro—, y el personaje se alzaba y quedaba
## empotrado en la puerta de la iglesia: `test_move` seguía diciendo que las ocho
## direcciones estaban libres y `move_and_slide` no lo movía ni un centímetro,
## porque todo el desplazamiento se lo comía la despenetración.
##
## Medido: con esta comprobación floja, caminar contra esa puerta dejaba al
## jugador clavado en 4 de 16 acercamientos.
## Se pregunta con margen MÍNIMO, no con el del cuerpo.
##
## El del cuerpo son 4 cm, y contando el solape inicial eso hace que estar de
## pie sobre el suelo ya cuente como choque: el margen es una piel, y apoyarse
## en algo la toca siempre. Con un milímetro sólo salta lo que de verdad está
## metido dentro de la geometría, que es lo único que se quiere detectar.
const MARGEN_DE_SOLAPE := 0.001


func _estorbado(desde: Transform3D, movimiento: Vector3) -> bool:
	return test_move(desde, movimiento, null, MARGEN_DE_SOLAPE, true)


# ─── Quedarse encajado ────────────────────────────────────────────────────────
#
# Pasa de verdad y no tiene salida: metido en el hueco de la puerta de la
# iglesia, la cápsula queda dentro del trimesh del edificio y `move_and_slide`
# recibe normales que se contradicen, así que anula TODO el movimiento. Medido
# con una sonda que camina contra esa puerta desde dieciséis sitios: en tres se
# quedaba a cero metros, empujando en cualquier dirección, para siempre.
#
# No se arregla con el margen de colisión —se probó con el de fábrica y con el
# holgado, y se atasca con los dos— porque el problema no es rozar una costura,
# es haber entrado donde no se cabe.

## Cuánto tiene que llevar sin moverse para darlo por encajado.
const PACIENCIA_ENCAJADO := 0.4

## Lo que hay que desplazarse en un cuadro para contar como que se avanza.
const AVANCE_MINIMO := 0.004

## Cada cuánto se anota por dónde se pasó estando libre.
const MIGA_CADA := 0.35

var _encajado := 0.0
var _miga := Vector3.ZERO
var _reloj_de_miga := 0.0


## Comprueba si el personaje se quedó clavado y, si es así, lo saca.
func _vigilar_encajado(antes: Vector3, dir: Vector3, delta: float) -> void:
	var avanzo := antes.distance_to(global_position) > AVANCE_MINIMO
	# La miga de pan: el último sitio por el que se pasó pudiendo moverse. Es
	# adonde se vuelve, y por eso sólo se anota estando suelto.
	if avanzo and is_on_floor():
		_reloj_de_miga += delta
		if _reloj_de_miga >= MIGA_CADA:
			_reloj_de_miga = 0.0
			_miga = global_position
	if avanzo or dir == Vector3.ZERO:
		_encajado = 0.0
		return
	_encajado += delta
	if _encajado < PACIENCIA_ENCAJADO or not _sin_salida():
		return
	_encajado = 0.0
	if _miga != Vector3.ZERO:
		global_position = _miga
		velocity = Vector3.ZERO


## ¿Está encajado de verdad, o sólo empujando contra una pared?
##
## La diferencia importa: contra una pared no se avanza de frente, pero de
## costado sí, y ahí no hay nada que rescatar —devolver a alguien un metro atrás
## cada vez que se apoya en un muro sería mucho peor que el fallo—.
##
## Hay DOS formas de estar sin salida, y las dos hacen falta:
##
##   - **Encajado en un hueco**: ninguna dirección libre. Es el caso obvio.
##   - **Metido DENTRO de la geometría**: y éste es el traicionero, porque se
##     ve al revés. `test_move` ignora el solape inicial, así que desde dentro
##     de una pared informa las ocho direcciones libres mientras
##     `move_and_slide` no mueve nada —el desplazamiento se lo come la
##     despenetración—. Preguntando con el solape contado, se distingue.
func _sin_salida() -> bool:
	# HACIA ARRIBA, no hacia abajo: de pie sobre el suelo, un movimiento hacia
	# abajo choca siempre con el propio suelo, y entonces cualquiera apoyado en
	# una pared se daría por encajado. Hacia arriba sólo choca lo que de verdad
	# esté solapando.
	if _estorbado(global_transform, Vector3.UP * 0.001):
		return true          # está dentro de algo: eso no se arregla caminando
	for i in 8:
		var a := TAU * float(i) / 8.0
		var salida := Vector3(cos(a), 0.0, sin(a)) * 0.25
		if not test_move(global_transform, salida):
			return false
	return true


## Cuenta el tiempo que lleva sin acercarse al líder.
##
## Lo que importa no es si se MUEVE, sino si ACERCA. Un compañero rebotando
## contra una barrera se mueve todo el rato —salta, cae, se desplaza de lado— y
## un detector basado en desplazamiento nunca lo daría por atascado, que es
## justo lo que pasaba. Midiendo la mejor distancia alcanzada no hay escapatoria:
## si en dos segundos y medio no ha recortado ni treinta centímetros, no va a
## llegar por sí solo.
func _vigilar_atasco(delta: float) -> void:
	_pos_previa = global_position
	var lider := _leader()
	if lider == null:
		_atasco = 0.0
		_mejor_dist = INF
		return
	var d := Vector2(lider.global_position.x - global_position.x,
		lider.global_position.z - global_position.z).length()
	if d < ESCOLTA_TROTE:
		_atasco = 0.0
		_mejor_dist = INF     # ya llegó: la marca se reinicia para el próximo tramo
		return
	if d < _mejor_dist - 0.3:
		_mejor_dist = d
		_atasco = 0.0
		return
	_atasco += delta
	if _atasco >= ESQUIVA_RESCATE and d >= ESQUIVA_RESCATE_DIST:
		_atasco = 0.0
		_mejor_dist = INF
		_rescatar(lider)


## Lo devuelve junto al líder cuando ya no hay salida.
##
## Es la red de abajo, no el mecanismo principal: la esquiva rodea lo que se
## puede rodear y esto sólo entra cuando de verdad quedó encerrado —encajado
## entre una vagoneta y el muro, o al otro lado de una barrera que cayó—. Se le
## deja a la espalda del líder y sólo estando a más de seis metros, para que no
## se le vea aparecer de la nada.
func _rescatar(lider: Node3D) -> void:
	var espacio := get_world_3d().direct_space_state
	var atras := -Vector3(lider.velocity.x, 0.0, lider.velocity.z)
	if atras.length() < 0.5:
		atras = Vector3(0.0, 0.0, 1.0)
	atras = atras.normalized()

	var forma := CapsuleShape3D.new()
	forma.radius = 0.45
	forma.height = 1.5
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.collision_mask = 1
	consulta.exclude = [get_rid()]

	for grados: int in [0, 40, -40, 80, -80, 140, -140, 180]:
		var a := atras.rotated(Vector3.UP, deg_to_rad(float(grados)))
		for radio: float in [1.6, 2.6]:
			var p: Vector3 = lider.global_position + a * radio
			var rayo := PhysicsRayQueryParameters3D.create(
				p + Vector3(0, 3, 0), p - Vector3(0, 12, 0))
			rayo.collision_mask = 1
			var suelo := espacio.intersect_ray(rayo)
			if suelo.is_empty():
				continue                      # ahí no hay piso: caería al vacío
			var apoyo: Vector3 = (suelo["position"] as Vector3) + Vector3(0, 0.1, 0)
			consulta.transform = Transform3D(Basis(), apoyo + Vector3(0, 0.8, 0))
			if not espacio.intersect_shape(consulta, 1).is_empty():
				continue                      # ocupado
			global_position = apoyo
			velocity = Vector3.ZERO
			_desvio = 0.0
			_rumbo_ultimo = Vector3.ZERO
			return


## ¿Hay piso ~1.1m adelante en `dir`? Evita que el compañero se tire a un vacío.
func _has_ground_ahead(dir: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + dir.normalized() * 1.1 + Vector3(0.0, 0.5, 0.0)
	var to := from + Vector3(0.0, -2.0, 0.0)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1        # entorno
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	return not hit.is_empty()


func _leader() -> Node3D:
	for p in get_tree().get_nodes_in_group("player"):
		if p != self and p.get("active"):
			return p
	return null


# --- Interacción (llamado por Interactable.gd) ---
func set_interactable(node: Node) -> void:
	_interactable = node
	if hud and hud.has_method("show_prompt"):
		var text: String = node.prompt if "prompt" in node else "[E] Interactuar"
		hud.show_prompt(text)


func clear_interactable(node: Node) -> void:
	if _interactable == node:
		_interactable = null
		if hud and hud.has_method("hide_prompt"):
			hud.hide_prompt()


# --- Control (party/swap) ---
func set_active(a: bool) -> void:
	active = a
	var cam := get_node_or_null("Camera") as Camera3D
	if cam:
		cam.current = a
	if not a:
		velocity.x = 0.0
		velocity.z = 0.0
		_charging = false
		if hud and hud.has_method("hide_prompt"):
			hud.hide_prompt()
		_interactable = null


## true = IA de combate (pelea solo); false = QUIETO/guardia (defiende su puesto).
func set_ai_mode(combat: bool) -> void:
	ai_mode = AiMode.SIGUIENDO if combat else AiMode.FROZEN
	if not combat:
		_hold_pos = global_position   # fija el puesto a defender
		velocity.x = 0.0
		velocity.z = 0.0


# --- Vida ---
## Sólo el personaje ACTIVO recibe daño.
##
## El compañero es intocable a propósito: si pudiera morir mientras lo llevás de
## la mano, la pelea volvería a ser de los dos y volveríamos a lo de antes. Lo
## que estás peleando es tuyo y de nadie más.
func take_damage(amount: float, _from: Vector3 = Vector3.ZERO) -> void:
	if not active or _derrotado:
		return
	if health <= 0:
		return
	health = max(0, health - int(round(amount)))
	health_changed.emit(health, max_health)
	if health == 0:
		died.emit()


func heal(amount: int) -> void:
	health = min(max_health, health + amount)
	health_changed.emit(health, max_health)


func is_dead() -> bool:
	return health <= 0


# ─── Derrota ──────────────────────────────────────────────────────────────────

## Con la vida a cero el personaje cae y deja de responder: Game lo escucha
## por `died`, espera un momento y devuelve al party al inicio de la zona.
## Sin esto, llegar a cero no cambiaba nada: se seguía jugando con la barra
## vacía.
var _derrotado := false
## Lo que tarda en irse al suelo.
const CAIDA_DE_DERROTA := 0.5


func derrotar() -> void:
	if _derrotado:
		return
	_derrotado = true
	_charging = false
	velocity = Vector3.ZERO
	# No hay clip de derrota para los protagonistas: se tumba el modelo entero,
	# que se lee igual de bien y no depende de que Mixamo tenga la pose.
	if _visual != null:
		var t := create_tween()
		t.tween_property(_visual, "rotation:x", -PI * 0.5, CAIDA_DE_DERROTA) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


## Vuelve a estar de pie y entero.
func revivir() -> void:
	_derrotado = false
	if _visual != null:
		_visual.rotation.x = 0.0
	health = max_health
	health_changed.emit(health, max_health)


func esta_derrotado() -> bool:
	return _derrotado


func _banner(text: String) -> void:
	if hud and hud.has_method("show_banner"):
		hud.show_banner(text)


## Orienta al personaje hacia un rumbo, en radianes.
##
## Sigue la convención de Godot y la del resto de este script: yaw 0 mira a -Z.
## Lo usa Game al colocar la party en un punto de aparición, para que el rumbo
## del Marker3D se respete en vez de arrastrar el que traía de la zona anterior.
func orientar_hacia(yaw: float) -> void:
	if _visual != null:
		_visual.rotation.y = yaw


## Le pone al personaje su modelo con animaciones, en lugar del muñeco de cajas.
func _montar_emilia() -> void:
	if _visual == null:
		return
	_emilia = Node3D.new()
	_emilia.name = "Animador"
	_emilia.set_script(ANIMADOR_SCR)
	_visual.add_child(_emilia)
	_emilia.call("montar", self,
		MODELO_BENJAMIN if is_archer else MODELO_EMILIA, ALTO_PERSONAJE)


## Golpe cargado de Emilia: más daño, corta la cadena y tiene su propia espera.
##
## FALTA la mecánica de agarre que describiste —inmovilizar al rival mientras lo
## golpea, sólo con los jefes aturdidos y normal con los enemigos chicos—. Eso
## necesita un estado de aturdimiento en los jefes y uno de agarrado en los
## enemigos, que hoy no existen; esto por ahora es un golpe fuerte.
func _golpe_cargado() -> void:
	_attack_cd = AGARRE_DURACION + 0.2
	_combo_step = 0
	_combo_timer = 0.0
	_face_aim()
	_squash()
	if _emilia != null:
		_emilia.call("golpe_cargado")

	var presa := _presa_de_agarre()
	if presa != null and presa.call("agarrar", AGARRE_DURACION):
		_agarrar(presa)
		return

	# Sin presa agarrable —o jefe con la guardia alta— queda un golpe fuerte.
	Sfx.play("kick", -2.0, 0.85)
	_attack_cd = 0.6
	_spawn_melee_hit(melee_damage[melee_damage.size() - 1] * 1.6)


## El enemigo al alcance que SÍ se deja agarrar.
##
## Se pregunta al enemigo en vez de mirar si es jefe desde acá: la regla —los
## chicos siempre, los jefes sólo aturdidos— vive en él, que es quien sabe en
## qué estado está.
func _presa_de_agarre() -> Node3D:
	var mejor: Node3D = null
	var mas_cerca := AGARRE_ALCANCE
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not (e is Node3D):
			continue
		if not e.has_method("puede_ser_agarrado") or not e.call("puede_ser_agarrado"):
			continue
		var d: float = global_position.distance_to((e as Node3D).global_position)
		if d < mas_cerca:
			mas_cerca = d
			mejor = e
	return mejor


## Lo sujeta y le mete la tanda de golpes.
##
## El daño se reparte en varios impactos en vez de darlo de una: así se ve y se
## oye que lo está machacando, y el número que sale en pantalla acompaña.
func _agarrar(presa: Node3D) -> void:
	var por_golpe: float = melee_damage[melee_damage.size() - 1] * AGARRE_MULTIPLICADOR \
		/ float(AGARRE_GOLPES)
	for i in AGARRE_GOLPES:
		var cuando: float = AGARRE_DURACION * float(i) / float(AGARRE_GOLPES)
		get_tree().create_timer(cuando).timeout.connect(
			_golpe_de_agarre.bind(presa, por_golpe))


## `presa` va SIN tipo a propósito.
##
## La tanda de golpes son varios temporizadores, y el agarre suele MATAR a la
## presa antes de que salten todos: los que quedan llegan con un objeto ya
## liberado. GDScript convierte los argumentos ANTES de entrar en la función,
## así que declarándola `Node3D` la llamada reventaba en la conversión —"Cannot
## convert argument 1 from Object to Object"— sin llegar nunca al
## `is_instance_valid` de acá abajo, que es justo lo que estaba para eso.
func _golpe_de_agarre(presa, dmg: float) -> void:
	if not is_instance_valid(presa) or not presa.has_method("take_damage"):
		return
	# Sin empuje: mientras dura el agarre está sujeta, no sale despedida.
	presa.call("take_damage", dmg, global_position, 0.0)
	Sfx.play("punch", -4.0, randf_range(1.05, 1.25))


## Rodada de esquiva (Ctrl).
##
## Sólo en el suelo, y ahora para LOS DOS. Al principio la tenía prohibida al
## arquero porque no existía su animación; desde que Benjamín la trae, ese
## cerrojo era lo único que le impedía rodar.
##
## La dirección se congela al arrancar: hacia donde te movés, o hacia donde mira
## el personaje si estabas quieto. Corta lo que estuviera haciendo —la cadena de
## golpes y el cargado— porque rodar es justamente salir de ahí.
func _rodar() -> void:
	if not is_on_floor() or _rodando > 0.0 or _rodada_cd > 0.0:
		return
	if not active or input_locked or _dormido > 0.0 or mounted:
		return

	var d := _player_input()
	if d.length() < 0.05:
		d = -_visual.global_transform.basis.z   # quieto: rueda hacia adelante
	d.y = 0.0
	if d.length() < 0.05:
		return
	_rodada_dir = d.normalized()

	# La duración manda y el clip se le ajusta. Sin clip se rueda igual, el
	# mismo tiempo, sólo que sin animación.
	var dura := rodada_duracion
	if _emilia != null:
		var del_clip: float = _emilia.call("rodar_en", rodada_duracion)
		if del_clip > 0.0:
			dura = del_clip
	_rodando = dura
	_rodada_cd = dura + rodada_espera
	# Se cancela el golpe en curso: no se rueda a media patada.
	_charging = false
	_combo_timer = 0.0
	_attack_cd = maxf(_attack_cd, dura)
	Sfx.play("punch", -10.0, 0.7)


## Si está en plena rodada. Lo consulta quien necesite saberlo.
func esta_rodando() -> bool:
	return _rodando > 0.0


# ─── El compañero ─────────────────────────────────────────────────────────────
#
# El que no llevás NO pelea y NO recibe daño. Antes tenía una IA de combate que
# perseguía, esquivaba telegrafiados y remataba por su cuenta, y eso volvía las
# peleas asistidas: la mitad del trabajo lo hacía él. Ahora sólo acompaña, y el
# combate es del personaje que tenés en la mano.

## Cuánto se queda atrás y a un lado del que llevás, en metros.
@export_group("Compañero")
@export var seguir_atras := 1.4
@export var seguir_costado := 1.0
## Por debajo de esto ya está bastante cerca y se queda quieto, para que no
## tiemble pegado al líder.
@export var seguir_holgura := 0.5


## Acompaña al activo: un paso atrás y al costado, siempre.
##
## El sitio se calcula respecto de HACIA DÓNDE MIRA el líder, no de su velocidad:
## así se queda en el mismo lugar relativo aunque el líder esté parado, y no
## salta de un lado a otro cada vez que arranca o frena.
func _ai_behavior() -> Vector3:
	var lider := _leader()
	if lider == null:
		return Vector3.ZERO

	var frente := -lider.global_transform.basis.z
	var vis := lider.get_node_or_null("Visual") as Node3D
	if vis != null:
		frente = -vis.global_transform.basis.z
	frente.y = 0.0
	if frente.length() < 0.01:
		frente = Vector3.FORWARD
	frente = frente.normalized()
	var derecha := Vector3.UP.cross(frente).normalized()

	var sitio: Vector3 = lider.global_position - frente * seguir_atras \
		+ derecha * seguir_costado
	var hacia := sitio - global_position
	hacia.y = 0.0
	if hacia.length() <= seguir_holgura:
		return Vector3.ZERO
	return hacia.normalized()


# ─── Señuelo ─────────────────────────────────────────────────────────────────

## A quién hay que mantener entretenido, y dentro de qué ruedo.
var senuelo_de: Node3D = null
var senuelo_centro := Vector3.ZERO
var senuelo_radio := 10.0
## Más cerca que esto, se aleja; más lejos que esto, se acerca para que no la
## pierda de vista. En medio, da vueltas a su alrededor.
const SENUELO_CERCA := 6.0
const SENUELO_LEJOS := 9.5


## Hace de señuelo de `objetivo` sin salirse de un círculo de `radio` metros
## alrededor de `centro`. Se corta con `set_ai_mode`, o sea al cambiar de
## personaje.
func hacer_de_senuelo(objetivo: Node3D, centro: Vector3, radio: float) -> void:
	senuelo_de = objetivo
	senuelo_centro = centro
	senuelo_radio = maxf(radio, 3.0)
	ai_mode = AiMode.SENUELO


func es_senuelo() -> bool:
	return ai_mode == AiMode.SENUELO and is_instance_valid(senuelo_de)


## Alejarse en diagonal, no en línea recta: huyendo derecho se termina contra
## el borde del ruedo con el bicho encima. Girando a su alrededor siempre queda
## sitio, y si se sale del ruedo, tira de vuelta al centro.
func _senuelo_behavior() -> Vector3:
	if not is_instance_valid(senuelo_de):
		return Vector3.ZERO
	var desde := global_position - senuelo_de.global_position
	desde.y = 0.0
	var d := desde.length()
	var lejos := desde.normalized() if d > 0.01 else Vector3.RIGHT
	var tangente := Vector3.UP.cross(lejos)
	var al_centro := senuelo_centro - global_position
	al_centro.y = 0.0
	var rumbo := Vector3.ZERO
	if d < SENUELO_CERCA:
		rumbo = lejos * 0.6 + tangente * 0.8
	elif d > SENUELO_LEJOS:
		rumbo = -lejos
	else:
		rumbo = tangente
	if al_centro.length() > senuelo_radio:
		rumbo += al_centro.normalized() * 1.5
	return rumbo.normalized() if rumbo.length() > 0.01 else Vector3.ZERO


## Modo QUIETO (T): se queda en su puesto. Tampoco pelea.
##
## Antes defendía el puesto: agarraba objetivos dentro de `defense_radius` y los
## perseguía hasta `guard_leash`. Se fue con el resto del combate automático.
func _hold_behavior() -> Vector3:
	var back := _hold_pos - global_position
	back.y = 0.0
	if back.length() > 0.4:
		return back.normalized()
	return Vector3.ZERO


## Lanza la animación de salto EN EL MOMENTO de saltar.
##
## Antes se elegía mirando si estaba en el aire, y eso llegaba tarde: la
## animación arrancaba con el personaje ya volando y se cortaba al aterrizar. El
## animador además se saltea el impulso del clip y le ajusta el ritmo al vuelo,
## que se calcula acá porque depende de la gravedad y del impulso de este
## personaje, no de la animación.
func _animar_salto(dir: Vector3) -> void:
	if _emilia == null:
		return
	var vuelo: float = 2.0 * velocity.y / maxf(gravity, 0.01)
	_emilia.call("saltar", dir.length() > 0.1, vuelo)


## Cuelga un nodo del mundo, no del personaje.
##
## Las cajas de golpe, las flechas y el guanaco tienen que quedarse donde
## nacieron y no seguir al que los creó. Iban a `current_scene` a secas, pero eso
## es null fuera de una partida —en los tests, por ejemplo— y reventaba con un
## "add_child sobre un valor nulo" en medio del combate.
func _al_mundo(n: Node) -> void:
	var destino: Node = get_tree().current_scene
	if destino == null:
		destino = get_parent()
	if destino == null:
		destino = get_tree().root
	destino.add_child(n)


## Si está planeando ahora mismo.
##
## Son los dos casos en que las alas trabajan: cayendo despacio con Espacio
## mantenido, y subiendo por una corriente ascendente. En la corriente la
## velocidad es POSITIVA, así que mirar sólo "va cayendo" dejaba las alas
## guardadas justo cuando más se están usando.
func _planeando() -> bool:
	if not can_glide or is_on_floor() or not active:
		return false
	if not Input.is_action_pressed("jump"):
		return false
	return (in_updraft or velocity.y < 0.0) and not in_downdraft


## Pone o quita la pose de ir a caballo del guanaco.
##
## El clip son dos fotogramas: no es una animación, es una postura que se
## mantiene mientras dure el paseo.
func _pose_de_montado(activo: bool) -> void:
	if _emilia != null:
		_emilia.call("montado", activo)


## Cuelga las alas del Alicanto de la espalda.
##
## Sólo las lleva Emilia: son su habilidad. La malla plana que había en
## El arco en la mano y el carcaj a la espalda. Sólo Benjamín: Emilia pelea a
## puñetazos y lo suyo son las alas.
## El nodo `Arma` viene EN LA ESCENA, no se crea aquí: creándolo por código no
## había dónde tocarle los ajustes —posición del carcaj, largo del arco, tensión
## de la cuerda—, porque en el editor no existía. Ahora sale en el inspector.
func _montar_arma() -> void:
	_arma = get_node_or_null("Arma")
	if _arma == null:
		return
	if not is_archer:
		_arma.queue_free()       # Emilia pelea a puñetazos
		_arma = null
		return
	_arma.montar(_esqueleto_de(_emilia), _visual, _animador_de(_emilia))


func _animador_de(n: Node) -> AnimationPlayer:
	if n == null:
		return null
	if n is AnimationPlayer:
		return n
	for h in n.get_children():
		var x := _animador_de(h)
		if x != null:
			return x
	return null


func _esqueleto_de(n: Node) -> Skeleton3D:
	if n == null:
		return null
	if n is Skeleton3D:
		return n
	for h in n.get_children():
		var x := _esqueleto_de(h)
		if x != null:
			return x
	return null


## `Visual/Wings` se apaga —no se borra, por si hay que volver atrás— y el nodo
## pasa a ser el soporte del modelo de verdad.
## El nodo `AlasEspirituales` viene EN LA ESCENA, igual que el arma: creándolo
## por código no había dónde tocarle el `ajuste` del enganche.
func _montar_alas() -> void:
	if _wings_vis == null:
		return
	_alas = _wings_vis.get_node_or_null("AlasEspirituales")
	if _alas == null:
		return
	if is_archer:
		_alas.queue_free()       # las alas son de Emilia
		_alas = null
		return
	_alas.montar(ALTO_PERSONAJE)
	# `Visual/Wings` sólo marca el sitio; de quien cuelgan de verdad es de la
	# columna de Emilia, para que acompañen al cuerpo cuando se dobla.
	_alas.enganchar_a(_esqueleto_de(_emilia), _visual)
	if _wings_vis is MeshInstance3D:
		(_wings_vis as MeshInstance3D).mesh = null   # fuera el placeholder
	_wings_vis.visible = true   # ahora quien esconde las alas es la disolución
