extends Node3D

## Guanaco compañero de Benjamín (tras la Bendición del Yastay).
##   Q (procesado en PlayerController) — montar / desmontar (speed x1.5)
##   G — lanzar al guanaco a embestir (carga en línea recta, daña enemigos)
##
## Este nodo sigue a Benjamín en todo momento.
## Al embestir sale disparado y vuelve luego de frenar.

## El MISMO guanaco que puebla la quebrada del Yastay, no el espiritual.
##
## El espiritual traía un solo clip y un esqueleto de 24 huesos que no admitía
## los de éste: son rigs distintos. Cambiando de modelo el compañero se lleva
## los seis —quieto, caminar, correr, coz, desplomarse y levantarse— y pasa a
## moverse como los de su especie.
const MODELO := preload("res://models/personaje/guanaco.glb")

## El modelo mira hacia +Z y el resto del juego toma -Z como frente, así que el
## visual entero va girado media vuelta. Es la misma corrección que llevan los
## enemigos, y se confirma con el guanaco de cajas al que reemplaza: aquél tenía
## la cabeza en -Z.
const GIRO_MODELO := PI
## Cuánto mide montado, en metros. Es lo que hace que se lea como una montura y
## no como un perro; el número lo pediste vos y no ha cambiado.
const ALTO := 1.96
## Lo que mide el modelo a escala 1. El espiritual medía 0.98 y por eso llevaba
## escala 2; éste mide 1.60, así que el factor es otro. Escalar por el número
## viejo lo dejaría midiendo tres metros y veinte.
const ALTO_DEL_MODELO := 1.60
const ESCALA := ALTO / ALTO_DEL_MODELO

## Los clips del modelo. El que falte simplemente no se usa.
const CLIP_QUIETO := "Idle"
const CLIP_CAMINAR := "Walk"
const CLIP_CORRER := "Run"
## La coz, que hace de salto: montado, Benjamín brinca y el guanaco patea.
const CLIP_SALTO := "Kick"

## Por debajo de esta velocidad se considera quieto y no camina.
const VELOCIDAD_MINIMA := 0.15
## A partir de esta velocidad corre en vez de caminar.
const VELOCIDAD_DE_CARRERA := 6.0
## La velocidad a la que el clip de caminar va a su ritmo natural.
const VELOCIDAD_DE_PASO := 3.0

## Margen de histéresis: hay que pasarse de estos factores para salir del clip
## en el que se está. Sin margen, una velocidad que ronda el umbral cambia el
## clip ida y vuelta cada pocos cuadros, y cada cambio reinicia el ciclo.
const SALIR_DE_QUIETO := 1.6
const SALIR_DE_CARRERA := 0.85

## Lo más que se acelera un clip. Por encima de esto deja de leerse como andar
## rápido y se lee como una animación apurada.
const RITMO_MAXIMO := 1.3

## Con qué prisa la velocidad medida alcanza a la real, por segundo.
const SUAVIZADO := 8.0

## A qué ritmo va la coz del salto. Por debajo de 1 se ve entera y con peso; a
## su velocidad de fábrica pasa tan rápido que apenas se registra.
const RITMO_DEL_SALTO := 0.85
## Qué tan rápido acompaña el giro de Benjamín. Se suaviza en vez de copiarlo
## de golpe: pegado a su ángulo exacto daba tirones al mover la cámara.
const GIRO_SUAVE := 8.0

const CHARGE_SPEED  := 18.0
const CHARGE_DAMAGE := 60.0
## Recarga de la embestida. Bajó de 5 s: con tantos botones que golpear en la
## cumbre, esperar cinco segundos entre uno y otro cortaba el ritmo.
const CHARGE_CD     := 2.0
const FOLLOW_SPEED  := 6.0
## Lo que sube o baja por segundo al perseguir la altura de Benjamín. Más rápido
## que cualquier plataforma del juego, para que no se quede atrás en el viaje.
const VELOCIDAD_VERTICAL := 8.0
## Desnivel a partir del cual se planta de una vez en vez de subir despacio.
const SALTO_DE_ALTURA := 6.0
## Distancia a la que se pone a la DERECHA de Benjamín. A 1.3 se le montaba
## encima ahora que el modelo mide el doble; a 2.5 quedaba lejísimos.
const FOLLOW_DIST   := 1.8

var _charging    := false
var _charge_vel  := Vector3.ZERO
var _charge_cd   := 0.0
var _t           := 0.0
var _base_y      := 0.0
var _ready_done  := false
var _mounted     := false

var _g_prev      := false
var _label: Label3D = null
var _anim: AnimationPlayer = null
## Lo que le queda de coz al saltar. Mientras corre, manda sobre el paso.
var _salto_restante := 0.0
## Velocidad medida, ya suavizada. La cruda tiembla demasiado para decidir clip.
var _vel_suave := 0.0
var _pos_previa := Vector3.ZERO


func _ready() -> void:
	add_to_group("guanaco_companion")
	_build_visual()


## Si está en plena embestida. Lo consultan los botones que sólo ceden al
## golpe del guanaco, que no pueden mirar colisiones porque este nodo no es un
## cuerpo físico: se mueve desplazando su posición a mano.
func esta_embistiendo() -> bool:
	return _charging


## Llamado por PlayerController al montar/desmontar (tecla Q).
func set_mounted(v: bool) -> void:
	_mounted = v
	if is_instance_valid(_label):
		_label.visible = not v


func _process(delta: float) -> void:
	# Capturar _base_y en el primer frame (cuando la posición global ya es correcta)
	if not _ready_done:
		_ready_done = true
		_base_y = global_position.y
		return

	_t += delta
	_charge_cd = max(0.0, _charge_cd - delta)
	_animar(delta)

	if _mounted:
		_ride_benja()
	elif _charging:
		_do_charge(delta)
	else:
		_follow_benja(delta)
		# Suave levitación en idle
		global_position.y = _base_y + sin(_t * 1.4) * 0.10

	# G = lanzar a embestir (no disponible mientras se lo monta)
	var g := Input.is_action_pressed("guanaco_charge")
	if g and not _g_prev and not _mounted and not _charging and _charge_cd <= 0.0:
		_launch()
	_g_prev = g


## Montado: el guanaco va bajo Benjamín y copia su orientación.
func _ride_benja() -> void:
	var benja := _find_benja()
	if benja == null:
		return
	var vis := benja.get_node_or_null("Visual") as Node3D
	# El guanaco se adelanta un poco respecto de Benjamín, que es lo mismo que
	# sentarlo más ATRÁS sobre el animal: puestos en el mismo punto, el jinete
	# quedaba sobre el arranque del cuello en vez de en mitad del lomo.
	#
	# El cuánto vive en el jugador, no acá: este nodo lo crea el código al
	# invocar al guanaco y no sale en el editor, así que un @export suyo no se
	# podría tocar. El del Player sí.
	var adelante := 0.0
	if "avance_de_montura" in benja:
		adelante = float(benja.get("avance_de_montura"))
	var frente := Vector3.ZERO
	if vis != null and adelante != 0.0:
		frente = -vis.global_transform.basis.z
		frente.y = 0.0
		frente = frente.normalized() if frente.length() > 0.01 else Vector3.ZERO
	global_position = benja.global_position + frente * adelante
	_base_y = benja.global_position.y
	if vis:
		rotation.y = vis.global_rotation.y


func _follow_benja(delta: float) -> void:
	var benja := _find_benja()
	if benja == null:
		return
	# La derecha se toma del nodo Visual, que es el que gira con la cámara. El
	# CUERPO de Benjamín no rota, así que su eje X apuntaba siempre a la misma
	# dirección del mundo y el guanaco terminaba delante o encima según hacia
	# dónde estuvieras mirando.
	var vis := benja.get_node_or_null("Visual") as Node3D
	var derecha: Vector3 = benja.global_transform.basis.x
	if vis != null:
		derecha = vis.global_transform.basis.x
	derecha.y = 0.0
	if derecha.length() < 0.01:
		derecha = Vector3.RIGHT
	var target := benja.global_position + derecha.normalized() * FOLLOW_DIST + Vector3(0, 0.4, 0)
	var diff    := target - global_position
	diff.y      = 0.0
	if diff.length() > 0.1:
		global_position += diff.normalized() * min(diff.length(), FOLLOW_SPEED * delta)

	_seguir_la_altura(benja, delta)

	# Y mira hacia donde mirás vos. Antes esto sólo pasaba estando MONTADO, así
	# que el guanaco invocado te seguía de lado o de espaldas según hubiera
	# quedado al aparecer, y no giraba nunca.
	if vis != null:
		rotation.y = lerp_angle(rotation.y, vis.global_rotation.y, minf(delta * GIRO_SUAVE, 1.0))


## La altura también se persigue, no sólo el plano.
##
## `_base_y` se tomaba UNA sola vez, en el primer frame, y no se volvía a tocar:
## el guanaco quedaba flotando para siempre a la altura donde lo invocaste. Al
## subir en una plataforma te ibas vos solo y él se quedaba abajo; al bajar,
## colgado en el aire.
##
## Sólo copia la altura cuando Benjamín está PISANDO algo. Si no, cada salto se
## llevaría al guanaco de paseo por el aire, y una caída lo haría desplomarse
## con él.
func _seguir_la_altura(benja: Node3D, delta: float) -> void:
	if benja.has_method("is_on_floor") and not benja.is_on_floor():
		return
	var desnivel: float = benja.global_position.y - _base_y
	if absf(desnivel) > SALTO_DE_ALTURA:
		# Un teletransporte o una caída larga no se persiguen a paso de guanaco.
		_base_y = benja.global_position.y
	else:
		_base_y = move_toward(_base_y, benja.global_position.y,
			VELOCIDAD_VERTICAL * delta)


func _launch() -> void:
	var benja := _find_benja()
	if benja == null:
		return
	_charging    = true
	# Carga en la dirección que mira Benjamín
	var vis  := benja.get_node_or_null("Visual")
	var fwd  := Vector3(0, 0, -1)
	if vis:
		fwd = -vis.global_transform.basis.z
	_charge_vel = fwd.normalized() * CHARGE_SPEED
	_charge_vel.y = 0.0
	_charge_cd  = CHARGE_CD
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_banner"):
		hud.show_banner("¡Guanaco embiste! [" + str(int(CHARGE_CD)) + "s de recarga]")


func _do_charge(delta: float) -> void:
	global_position += _charge_vel * delta
	_charge_vel = _charge_vel.lerp(Vector3.ZERO, delta * 3.8)

	# Daño a enemigos cercanos
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) < 1.6:
			if enemy.has_method("take_damage"):
				enemy.take_damage(CHARGE_DAMAGE, global_position, 8.0)

	if _charge_vel.length() < 0.6:
		_charging = false


func _find_benja() -> Node3D:
	for p in get_tree().get_nodes_in_group("player"):
		if p.get("is_archer") == true:
			return p
	return null


## Monta el guanaco de verdad en lugar de las cápsulas del greybox.
func _build_visual() -> void:
	# El modelo cuelga de un nodo girado, no del guanaco mismo: así la media
	# vuelta no se pierde cada vez que el código toca `rotation.y` para
	# encararlo hacia donde mira Benjamín.
	var vis := Node3D.new()
	vis.name = "Visual"
	vis.rotation.y = GIRO_MODELO
	add_child(vis)

	var modelo := MODELO.instantiate() as Node3D
	modelo.scale = Vector3.ONE * ESCALA
	vis.add_child(modelo)

	_anim = _buscar_anim(modelo)
	if _anim == null:
		push_warning("Guanaco: el modelo vino sin AnimationPlayer; no va a caminar")
	else:
		# Vienen sin bucle: los de andar tienen que repetirse solos o darían un
		# paso y se quedarían clavados en el último fotograma.
		for c in [CLIP_QUIETO, CLIP_CAMINAR, CLIP_CORRER]:
			if _anim.has_animation(c):
				_anim.get_animation(c).loop_mode = Animation.LOOP_LINEAR
		_poner(CLIP_QUIETO, 1.0)

	# Etiqueta: va colgada del guanaco y NO del visual girado, para que el texto
	# no salga del revés.
	_label           = Label3D.new()
	_label.text      = "Guanaco\n[G] embestir · [Q] montar"
	_label.font_size = 18
	# Por encima de la cabeza: con el modelo al doble, a 1.4 quedaba dentro suyo.
	_label.position  = Vector3(0, 0.6 + ALTO, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)

	_pos_previa = global_position


func _buscar_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for h in n.get_children():
		var x := _buscar_anim(h)
		if x != null:
			return x
	return null



## Camina cuando se está moviendo de verdad, y se queda quieto cuando no.
##
## Se mide cuánto se desplazó desde el frame anterior en vez de mirar un estado
## interno: así vale igual siguiendo a Benjamín, montado o embistiendo, sin
## tener que acordarse de encender la animación en cada sitio.
func _animar(delta: float) -> void:
	if _anim == null:
		return
	# Mientras dura la coz del salto no se decide nada más: si no, al aterrizar
	# el paso la cortaría por la mitad.
	if _salto_restante > 0.0:
		_salto_restante -= delta
		# El sitio se sigue anotando aunque no se decida clip. Sin esto, al
		# acabar la coz se medía el desplazamiento de TODO el salto contra un
		# cuadro, salía una velocidad enorme y el guanaco arrancaba corriendo a
		# tope durante un instante.
		_pos_previa = global_position
		return
	var d := global_position - _pos_previa
	d.y = 0.0
	_pos_previa = global_position
	_suavizar_la_velocidad(d.length() / maxf(delta, 0.0001), delta)

	# Con histéresis: los umbrales de subir y bajar no son el mismo.
	#
	# Sin esto, una velocidad que ronda el umbral hace que el clip cambie ida y
	# vuelta cada pocos cuadros, y cada cambio reinicia el ciclo desde el
	# principio: es lo que se veía como una caminata cortada.
	var quiere := _clip_actual()
	if _vel_suave <= VELOCIDAD_MINIMA:
		quiere = CLIP_QUIETO
	elif _vel_suave >= VELOCIDAD_DE_CARRERA:
		quiere = CLIP_CORRER
	elif _vel_suave >= VELOCIDAD_MINIMA * SALIR_DE_QUIETO \
			and _vel_suave <= VELOCIDAD_DE_CARRERA * SALIR_DE_CARRERA:
		quiere = CLIP_CAMINAR

	_poner(quiere, _ritmo_de(quiere))


## Cuál está sonando, para poder dejarlo puesto si la velocidad quedó en tierra
## de nadie entre dos umbrales.
func _clip_actual() -> String:
	if _anim == null:
		return CLIP_QUIETO
	var a := String(_anim.assigned_animation)
	return a if a in [CLIP_QUIETO, CLIP_CAMINAR, CLIP_CORRER] else CLIP_QUIETO


## A qué ritmo va cada clip.
##
## El margen es estrecho a propósito. Estaba en 0.7–2.4 para el paso, y un ciclo
## de caminar a más del doble de velocidad no se lee como «va rápido»: se lee
## como una animación acelerada, que es justo lo que se sentía apurado. Ahora se
## acompaña la velocidad lo justo para que no patine.
func _ritmo_de(clip: String) -> float:
	match clip:
		CLIP_CORRER:
			return clampf(_vel_suave / VELOCIDAD_DE_CARRERA, 0.9, RITMO_MAXIMO)
		CLIP_CAMINAR:
			return clampf(_vel_suave / VELOCIDAD_DE_PASO, 0.85, RITMO_MAXIMO)
		_:
			return 1.0


## La velocidad, pero sin los saltos de un cuadro para otro.
##
## Se mide restando posiciones, y eso da una cifra que tiembla: un tirón de la
## física o un cuadro largo bastaban para cruzar un umbral y cambiar de clip.
func _suavizar_la_velocidad(cruda: float, delta: float) -> void:
	var t := clampf(delta * SUAVIZADO, 0.0, 1.0)
	_vel_suave = lerpf(_vel_suave, cruda, t)


## Le pone un clip, sin relanzarlo si ya es el que está sonando.
func _poner(clip: String, ritmo: float) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	_anim.speed_scale = ritmo
	if _anim.assigned_animation != clip or not _anim.is_playing():
		_anim.play(clip)


## Da la coz del salto. La llama Benjamín al brincar montado: el guanaco no
## despega de verdad —lo hace el cuerpo del jugador—, pero patear a la vez da
## la ilusión de que el salto es suyo.
func saltar() -> void:
	if _anim == null or not _anim.has_animation(CLIP_SALTO):
		return
	# Saltando otra vez a media coz NO se relanza. Encadenando brincos —que es lo
	# normal cruzando el cráter— la coz volvía a empezar cada vez y no llegaba a
	# verse nunca entera: sólo el arranque, una y otra vez.
	if _salto_restante > 0.0:
		return
	var a := _anim.get_animation(CLIP_SALTO)
	a.loop_mode = Animation.LOOP_NONE
	_anim.speed_scale = RITMO_DEL_SALTO
	_anim.play(CLIP_SALTO)
	_salto_restante = a.length / RITMO_DEL_SALTO
