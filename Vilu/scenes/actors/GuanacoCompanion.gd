extends Node3D

## Guanaco compañero de Benjamín (tras la Bendición del Yastay).
##   Q (procesado en PlayerController) — montar / desmontar (speed x1.5)
##   G — lanzar al guanaco a embestir (carga en línea recta, daña enemigos)
##
## Este nodo sigue a Benjamín en todo momento.
## Al embestir sale disparado y vuelve luego de frenar.

const MODELO := preload("res://models/personaje/guanaco_espiritual.glb")

## El modelo mira hacia +Z y el resto del juego toma -Z como frente, así que el
## visual entero va girado media vuelta. Es la misma corrección que llevan los
## enemigos, y se confirma con el guanaco de cajas al que reemplaza: aquél tenía
## la cabeza en -Z.
const GIRO_MODELO := PI
## A escala 1 el modelo mide 0.98 m de alto. Al doble queda en 1.96 m, que es lo
## que pediste y lo que hace que se lea como una montura y no como un perro.
const ESCALA := 2.0
## Por debajo de esta velocidad se considera quieto y no camina.
const VELOCIDAD_MINIMA := 0.15
## Qué tan rápido acompaña el giro de Benjamín. Se suaviza en vez de copiarlo
## de golpe: pegado a su ángulo exacto daba tirones al mover la cámara.
const GIRO_SUAVE := 8.0

const CHARGE_SPEED  := 18.0
const CHARGE_DAMAGE := 60.0
## Recarga de la embestida. Bajó de 5 s: con tantos botones que golpear en la
## cumbre, esperar cinco segundos entre uno y otro cortaba el ritmo.
const CHARGE_CD     := 2.0
const FOLLOW_SPEED  := 6.0
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
var _caminar := ""
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
	global_position = benja.global_position
	_base_y = benja.global_position.y
	var vis := benja.get_node_or_null("Visual") as Node3D
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

	# Y mira hacia donde mirás vos. Antes esto sólo pasaba estando MONTADO, así
	# que el guanaco invocado te seguía de lado o de espaldas según hubiera
	# quedado al aparecer, y no giraba nunca.
	if vis != null:
		rotation.y = lerp_angle(rotation.y, vis.global_rotation.y, minf(delta * GIRO_SUAVE, 1.0))


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
		_caminar = _animacion_de_caminar()
		if _caminar == "":
			push_warning("Guanaco: no encuentro la animación de caminar")
		else:
			# Viene sin bucle: al caminar tiene que repetirse sola o daría un
			# paso y se quedaría clavada en el último frame.
			var a := _anim.get_animation(_caminar)
			if a != null:
				a.loop_mode = Animation.LOOP_LINEAR

	# Etiqueta: va colgada del guanaco y NO del visual girado, para que el texto
	# no salga del revés.
	_label           = Label3D.new()
	_label.text      = "Guanaco\n[G] embestir · [Q] montar"
	_label.font_size = 18
	# Por encima de la cabeza: con el modelo al doble, a 1.4 quedaba dentro suyo.
	_label.position  = Vector3(0, 0.6 + 0.98 * ESCALA, 0)
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


## Se busca por nombre en vez de dar por hecho que hay una sola: si mañana le
## sumás correr o saltar, esto sigue eligiendo la de caminar.
func _animacion_de_caminar() -> String:
	var lista := _anim.get_animation_list()
	for n in lista:
		var b := String(n).to_lower()
		if b.contains("walk") or b.contains("camin"):
			return n
	return lista[0] if lista.size() > 0 else ""


## Camina cuando se está moviendo de verdad, y se queda quieto cuando no.
##
## Se mide cuánto se desplazó desde el frame anterior en vez de mirar un estado
## interno: así vale igual siguiendo a Benjamín, montado o embistiendo, sin
## tener que acordarse de encender la animación en cada sitio.
func _animar(delta: float) -> void:
	if _anim == null or _caminar == "":
		return
	var d := global_position - _pos_previa
	d.y = 0.0
	_pos_previa = global_position
	var vel := d.length() / maxf(delta, 0.0001)

	if vel > VELOCIDAD_MINIMA:
		# El paso acompaña a la velocidad; si fuera fijo, patinaría.
		_anim.speed_scale = clamp(vel / 4.0, 0.7, 2.4)
		if not _anim.is_playing():
			_anim.play(_caminar)
	elif _anim.is_playing():
		_anim.pause()
