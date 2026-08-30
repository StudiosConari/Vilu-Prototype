extends CharacterBody3D

# Enemigo "blob": persigue al jugador, le pega al acercarse, recibe dano del
# combo (retroceso + parpadeo) y muere soltando a veces un objeto.

@export var max_health: float = 40.0
@export var speed: float = 2.6
@export var damage: float = 10.0
@export var attack_range: float = 1.7
@export var attack_cooldown: float = 1.1
@export var base_color: Color = Color(0.75, 0.25, 0.30)
@export var scale_factor: float = 1.0
@export var is_boss: bool = false
@export var boss_name: String = "JEFE"
@export var boss_kind: int = 0  # 0 = Embestidor (carga), 1 = Aplastador (AoE)
@export var ranged: bool = false     # dispara proyectiles a distancia
@export var shoot_range: float = 9.0
@export var proj_speed: float = 11.0
@export var burn_dps: float = 9.0

const PROJECTILE := preload("res://scenes/Projectile.gd")
const ENCAJAR := preload("res://scenes/core/EncajarModelo.gd")
@export var windup_time: float = 0.6  # aviso antes de golpear (para esquivar)

@export_group("Aspecto")
## Modelo real del enemigo. Vacío = la cápsula de siempre.
##
## Se mide su caja envolvente y se escala a `altura_visual`, en vez de confiar
## en el tamaño con el que viene el archivo: así cambiar de modelo no descoloca
## al enemigo ni obliga a recalcular nada a mano.
@export var modelo: PackedScene
## Altura del modelo en metros. En 0 se respeta su tamaño original.
@export var altura_visual := 0.0

@export_group("Sueño")
## Segundos que deja dormido al personaje alcanzado por el golpe de ÁREA.
## En 0 el golpe sólo hace daño.
@export var duerme := 0.0

## Segundos entre un ataque de área y el siguiente.
##
## En 0 se mantiene la regla vieja de los jefes: uno de cada tres golpes es el
## especial. Eso ata el ataque al número de veces que llegó a pegarte, o sea que
## no hay forma de preverlo. Con un valor manda el reloj: el área sale cada
## tantos segundos y entre medias pega normal, que es lo que la hace legible.
@export var cooldown_area := 0.0

## Color del círculo del ataque de área. Rojo para el sueño de Lola; el naranja
## de fábrica es el del aplastamiento corriente.
@export var color_area := Color(1.0, 0.4, 0.05)

@export_group("Estado inicial")
## Arranca inerte: ni se mueve, ni es objetivo, ni se le puede pegar.
##
## Para enemigos encerrados que un mecanismo libera después —Lola detrás de la
## barrera de cuerda—. Se despierta llamando a `despertar()`.
@export var dormido := false
@export var charge_windup: float = 0.9
@export var charge_speed: float = 15.0
@export var charge_dur: float = 0.5

var health: float
var _target: Node3D
var _cd := 0.0
var _stun := 0.0
var _slow_time := 0.0
var _slow_factor := 1.0
var _windup := 0.0
var _boss_atk := 0
var _cd_area := 0.0
var _burn_time := 0.0
var _burn_acc := 0.0
var _knockback := Vector3.ZERO
var _flash := 0.0
var _mat: StandardMaterial3D
## Nodo al que se le aplican los aplastamientos y estirones del telegrafiado.
## Con cápsula es la propia malla; con modelo es un envoltorio, para que la
## animación no pise la escala con la que el modelo se ajusta a su altura.
var _body: Node3D
## Capa transparente sobre el modelo, para el destello del golpe y la quemadura.
## La cápsula pinta su propio material; un modelo importado trae los suyos y no
## se le pueden tocar sin estropear su textura.
var _capa: StandardMaterial3D
var _telegraph: MeshInstance3D
var _tel_mat: StandardMaterial3D
# Embestida del jefe (no cancelable): 0 nada, 1 aviso, 2 embistiendo.
var _charge_state := 0
var _charge_dir := Vector3.ZERO
var _charge_t := 0.0
var _charge_hit := false
var _charge_tel: MeshInstance3D
var _charge_mat: StandardMaterial3D

signal died(pos, xp)

const DAMAGE_NUMBER := preload("res://scenes/DamageNumber.gd")


func _xp_worth() -> int:
	# XP alta (para probar/subir habilidades rapido). Bajar para equilibrio final.
	if is_boss:
		return 400
	return int(round(70.0 + max_health * 0.6))


func setup(target: Node3D) -> void:
	_target = target


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	if dormido:
		# Ni objetivo ni golpeable mientras siga encerrado: sin esto el
		# compañero la elige de blanco y dispara flechas a través de la barrera.
		remove_from_group("enemies")
		collision_layer = 0
	health = max_health
	# Arranca en cuenta atrás para que el primer golpe sea el básico. La cuenta
	# sólo corre cuando está activa, así que un enemigo encerrado no llega ya
	# cargado el día que lo sueltan.
	_cd_area = cooldown_area
	_build_visual()
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4 * scale_factor
	cap.height = 1.4 * scale_factor
	col.shape = cap
	col.position = Vector3(0, 0.7 * scale_factor, 0)
	add_child(col)
	# Telegrafiado: disco rojo en el suelo que avisa el area del golpe.
	_tel_mat = StandardMaterial3D.new()
	_tel_mat.albedo_color = Color(1.0, 0.1, 0.1, 0.25)
	_tel_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tel_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tel_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var disc := CylinderMesh.new()
	disc.top_radius = attack_range
	disc.bottom_radius = attack_range
	disc.height = 0.06
	_telegraph = MeshInstance3D.new()
	_telegraph.mesh = disc
	_telegraph.material_override = _tel_mat
	_telegraph.position = Vector3(0, 0.05, 0)
	_telegraph.visible = false
	add_child(_telegraph)
	if is_boss:
		# Telegrafo direccional de la embestida (caja larga en el suelo).
		_charge_mat = StandardMaterial3D.new()
		_charge_mat.albedo_color = Color(1.0, 0.35, 0.05, 0.3)
		_charge_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_charge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_charge_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var cbox := BoxMesh.new()
		cbox.size = Vector3(charge_speed * charge_dur + attack_range, 0.08, attack_range * 1.5)
		_charge_tel = MeshInstance3D.new()
		_charge_tel.mesh = cbox
		_charge_tel.material_override = _charge_mat
		_charge_tel.visible = false
		add_child(_charge_tel)
		var lbl := Label3D.new()
		lbl.text = boss_name
		lbl.position = Vector3(0, 1.9 * scale_factor, 0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.fixed_size = true  # tamaño constante en pantalla (no crece cerca)
		lbl.no_depth_test = true
		lbl.font_size = 40
		lbl.outline_size = 10
		lbl.modulate = Color(1.0, 0.4, 0.3)
		lbl.pixel_size = 0.0016
		add_child(lbl)


func _build_visual() -> void:
	var sf := scale_factor
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = base_color
	if modelo != null:
		_montar_modelo(sf)
		return
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.4 * sf
	cap.height = 1.4 * sf
	body.mesh = cap
	body.material_override = _mat
	body.position = Vector3(0, 0.7 * sf, 0)
	add_child(body)
	_body = body
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.05, 0.05, 0.05)
	for sx in [-0.15, 0.15]:
		var eye := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.08 * sf
		sph.height = 0.16 * sf
		eye.mesh = sph
		eye.material_override = eye_mat
		eye.position = Vector3(sx * sf, 1.15 * sf, 0.33 * sf)
		add_child(eye)


## Cuelga el modelo importado, ajustado a su altura y apoyado en el suelo.
##
## El envoltorio intermedio no es capricho: el telegrafiado aplasta y estira a
## `_body`, y si eso cayera sobre el modelo pisaría la escala con la que se
## ajusta su altura. Separando las dos cosas cada una manda sobre lo suyo.
func _montar_modelo(sf: float) -> void:
	_body = Node3D.new()
	add_child(_body)

	var raiz: Node3D = modelo.instantiate()
	_body.add_child(raiz)
	ENCAJAR.encajar(raiz, altura_visual * sf if altura_visual > 0.0 else 0.0)

	# Capa para el destello y la quemadura. Va como material_overlay: dibuja el
	# modelo una segunda vez encima sin tocar sus materiales, así que la textura
	# no se pierde y al apagarla no queda rastro.
	_capa = StandardMaterial3D.new()
	_capa.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_capa.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_capa.albedo_color = Color(1, 1, 1, 0)
	for m in ENCAJAR.mallas(raiz):
		m.material_overlay = _capa


## Lleva el destello y la quemadura a la capa del modelo.
##
## El resto del script escribe esos estados en `_mat`, que es el material de la
## cápsula. Con modelo esa cápsula no existe, así que en vez de repartir
## condicionales por todo el bucle se leen de ahí una vez por cuadro.
func _pintar() -> void:
	if _capa == null:
		return
	var c := Color(1, 1, 1, 0)
	if _flash > 0.0:
		c = Color(1, 1, 1, 0.7)
	elif _mat.emission_enabled:
		c = Color(_mat.emission.r, _mat.emission.g, _mat.emission.b,
			clampf(_mat.emission_energy_multiplier * 0.22, 0.0, 0.55))
	_capa.albedo_color = c


## Golpe de ÁREA: alcanza a todo el que esté dentro, no sólo al objetivo.
##
## `_hit_target` sigue existiendo para el ataque normal, que es de uno contra
## uno; si el aplastamiento usara aquel, con los dos personajes dentro del
## círculo sólo se llevaría el golpe uno.
func _golpe_de_area(radio: float, dmg: float) -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p) or not (p is Node3D):
			continue
		var to_p: Vector3 = (p as Node3D).global_position - global_position
		if Vector2(to_p.x, to_p.z).length() > radio or absf(to_p.y) > 1.8:
			continue
		if p.has_method("take_damage"):
			p.take_damage(dmg, global_position)
		if duerme > 0.0 and p.has_method("dormir"):
			p.dormir(duerme)


## Lo llama el mecanismo que la libera (el obelisco, en la mina).
func despertar() -> void:
	if not dormido:
		return
	dormido = false
	collision_layer = 4
	add_to_group("enemies")
	Sfx.play_at("boss", global_position, 2.0, 0.7)


func set_slowed(t: float, factor: float) -> void:
	# Enredaderas: ralentizan (no inmovilizan). Toma la ralentizacion mas fuerte.
	_slow_time = maxf(_slow_time, t)
	_slow_factor = minf(_slow_factor, factor)


func is_telegraphing() -> bool:
	# Esta avisando un ataque (para que la IA aliada lo esquive).
	return _windup > 0.0 or _charge_state > 0


func danger_radius() -> float:
	if _charge_state > 0:
		return charge_speed * charge_dur + attack_range
	return attack_range * (1.8 if is_boss else 1.25)


func _nearest_player() -> Node3D:
	var best: Node3D = null
	var bd := 1e9
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p):
			continue
		if p.has_method("is_dead") and p.is_dead():
			continue
		var d := global_position.distance_to(p.global_position)
		if d < bd:
			bd = d
			best = p
	return best


func _hit_target(radius: float, dmg: float) -> void:
	if not is_instance_valid(_target):
		return
	var to_p: Vector3 = _target.global_position - global_position
	if Vector2(to_p.x, to_p.z).length() <= radius and absf(to_p.y) <= 1.8:
		if _target.has_method("take_damage"):
			_target.take_damage(dmg, global_position)


func _start_charge() -> void:
	_charge_state = 1
	_charge_t = charge_windup
	_charge_hit = false
	if is_instance_valid(_target):
		var d: Vector3 = _target.global_position - global_position
		d.y = 0.0
		_charge_dir = d.normalized() if d.length() > 0.1 else Vector3(0, 0, 1)
	var length: float = charge_speed * charge_dur + attack_range
	_charge_tel.rotation.y = atan2(-_charge_dir.z, _charge_dir.x)
	_charge_tel.position = _charge_dir * (length * 0.5) + Vector3(0, 0.06, 0)
	_charge_tel.visible = true
	Sfx.play_at("boss", global_position, 2.0)


func _shoot() -> void:
	if not is_instance_valid(_target):
		return
	var origin := global_position + Vector3(0, 0.9 * scale_factor, 0)
	var dir := (_target.global_position + Vector3(0, 0.9, 0)) - origin
	var host := get_parent()
	if host == null:
		return
	var p := Area3D.new()
	p.set_script(PROJECTILE)
	host.add_child(p)
	p.global_position = origin
	p.setup(dir, proj_speed, damage)
	Sfx.play_at("fire", global_position, -5.0)


## ¿Toca el ataque especial —embestida o aplastamiento— en vez del básico?
func _toca_especial() -> bool:
	if cooldown_area <= 0.0:
		return _boss_atk % 3 == 0
	if _cd_area > 0.0:
		return false
	_cd_area = cooldown_area
	return true


func _start_slam() -> void:
	_charge_state = 3
	_charge_t = charge_windup * 1.15
	_telegraph.scale = Vector3(2.4, 1.0, 2.4)  # area grande
	_telegraph.visible = true
	Sfx.play_at("boss", global_position, 2.0)


func _process_charge(delta: float) -> Vector3:
	if _charge_state == 3:  # APLASTAMIENTO de area (super armadura)
		_charge_t -= delta
		var st: float = clampf(1.0 - _charge_t / (charge_windup * 1.15), 0.0, 1.0)
		_tel_mat.albedo_color = Color(color_area.r, color_area.g, color_area.b,
			lerpf(0.2, 0.65, st))
		_body.scale = Vector3.ONE.lerp(Vector3(1.35, 0.6, 1.35), st)
		if _charge_t <= 0.0:
			_telegraph.visible = false
			_telegraph.scale = Vector3.ONE
			_body.scale = Vector3.ONE
			_charge_state = 0
			_cd = attack_cooldown
			_golpe_de_area(attack_range * 2.4 * 1.05, damage * 2.2)
		return Vector3.ZERO
	if _charge_state == 1:  # aviso: quieto, super armadura (no cancelable)
		_charge_t -= delta
		var tt: float = clampf(1.0 - _charge_t / charge_windup, 0.0, 1.0)
		_charge_mat.albedo_color = Color(1.0, 0.35, 0.05, lerpf(0.22, 0.7, tt))
		# Se AGACHA (squash) cargando el impulso.
		_body.scale = Vector3.ONE.lerp(Vector3(1.32, 0.62, 1.32), tt)
		if _charge_t <= 0.0:
			_charge_state = 2
			_charge_t = charge_dur
			_charge_tel.visible = false
		return Vector3.ZERO
	# embistiendo: se estira hacia adelante (stretch).
	_body.scale = _body.scale.lerp(Vector3(0.85, 1.18, 0.85), 10.0 * delta)
	_charge_t -= delta
	if not _charge_hit and is_instance_valid(_target):
		var to_p: Vector3 = _target.global_position - global_position
		if Vector2(to_p.x, to_p.z).length() <= attack_range * 1.15 and absf(to_p.y) <= 1.8:
			_charge_hit = true
			if _target.has_method("take_damage"):
				_target.take_damage(damage * 1.8, global_position)
	if _charge_t <= 0.0:
		_charge_state = 0
		_cd = attack_cooldown
		_body.scale = Vector3.ONE
		return Vector3.ZERO
	return _charge_dir * charge_speed


func take_damage(dmg: float, from_pos: Vector3, force: float = 4.5, burn: bool = false) -> void:
	health -= dmg
	_flash = 0.12
	# Los jefes NO se aturden: sus ataques no se pueden interrumpir.
	_stun = 0.0 if is_boss else 0.4
	_spawn_damage_number(dmg, force >= 8.0)
	Sfx.play_at("hit", global_position, -8.0, randf_range(0.9, 1.1))
	if burn:
		_burn_time = 3.0  # queda ardiendo
	var dir := global_position - from_pos
	dir.y = 0.0
	if dir.length() > 0.01:
		_knockback = dir.normalized() * (force / maxf(scale_factor, 0.6))
	if health <= 0.0:
		died.emit(global_position, _xp_worth())
		queue_free()


func _spawn_damage_number(amount: float, big: bool) -> void:
	var dn := Label3D.new()
	dn.set_script(DAMAGE_NUMBER)
	var host := get_parent()
	if host == null:
		return
	host.add_child(dn)
	dn.global_position = global_position + Vector3(randf_range(-0.25, 0.25), 1.5 * scale_factor, 0.0)
	dn.setup(amount, big)


func _physics_process(delta: float) -> void:
	if dormido:
		# Inerte, pero con gravedad: si no, quedaría flotando donde se la puso.
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -0.1 if is_on_floor() else velocity.y - 18.0 * delta
		move_and_slide()
		return
	_cd = maxf(0.0, _cd - delta)
	# El reloj del área corre sólo estando activa: así un enemigo encerrado no
	# llega ya cargado el día que lo sueltan.
	_cd_area = maxf(0.0, _cd_area - delta)
	_stun = maxf(0.0, _stun - delta)
	if _slow_time > 0.0:
		_slow_time = maxf(0.0, _slow_time - delta)
		if _slow_time <= 0.0:
			_slow_factor = 1.0  # se restablece al terminar

	# Quemadura: dano por tiempo + brillo naranja.
	if _burn_time > 0.0:
		_burn_time -= delta
		_mat.emission_enabled = true
		_mat.emission = Color(1.0, 0.35, 0.05)
		_mat.emission_energy_multiplier = 1.6
		_burn_acc += delta
		if _burn_acc >= 0.5:
			_burn_acc -= 0.5
			health -= burn_dps * 0.5
			_spawn_damage_number(burn_dps * 0.5, false)
			if health <= 0.0:
				died.emit(global_position, _xp_worth())
				queue_free()
				return
	else:
		_mat.emission_enabled = false

	if _flash > 0.0:
		_flash -= delta
		_mat.albedo_color = Color(1, 1, 1)
	else:
		_mat.albedo_color = base_color

	_target = _nearest_player()
	var to := Vector3.ZERO
	if is_instance_valid(_target):
		to = _target.global_position - global_position
		to.y = 0.0
	var dist := to.length()

	var desired := Vector3.ZERO
	if _charge_state > 0:
		# EMBESTIDA del jefe: no se cancela con golpes (super armadura).
		desired = _process_charge(delta)
	elif _stun > 0.0:
		if _windup > 0.0:  # aturdido: cancela el telegrafiado normal
			_windup = 0.0
			_telegraph.visible = false
	elif _windup > 0.0:
		# Telegrafiando (esquivable). Ranged: pulso emisivo; melee: disco rojo.
		_windup -= delta
		var t: float = clampf(1.0 - _windup / windup_time, 0.0, 1.0)
		if ranged:
			_mat.emission_enabled = true
			_mat.emission = Color(0.6, 0.25, 1.0)
			_mat.emission_energy_multiplier = lerpf(0.4, 2.6, t)
		else:
			_tel_mat.albedo_color = Color(1.0, 0.1, 0.1, lerpf(0.18, 0.6, t))
		if _windup <= 0.0:
			_telegraph.visible = false
			_cd = attack_cooldown
			if ranged:
				_shoot()
			else:
				_hit_target(attack_range * 1.05, damage)
	elif ranged:
		# A distancia: mantiene rango medio y dispara.
		if dist < shoot_range * 0.45:
			desired = -to.normalized() * speed  # alejarse
		elif dist > shoot_range:
			desired = to.normalized() * speed   # acercarse
		elif _cd <= 0.0 and is_instance_valid(_target):
			_windup = windup_time
	elif dist > attack_range * 0.9:
		desired = to.normalized() * speed
	elif _cd <= 0.0 and is_instance_valid(_target):
		_boss_atk += 1
		if is_boss and _toca_especial():
			if boss_kind == 1:
				_start_slam()
			else:
				_start_charge()
		else:
			_windup = windup_time
			_telegraph.visible = true

	# Enredaderas: ralentizan al enemigo (se mueve lento, no queda inmovil).
	if _slow_time > 0.0:
		desired *= _slow_factor
		_mat.emission_enabled = true
		_mat.emission = Color(0.25, 0.9, 0.35)
		_mat.emission_energy_multiplier = 1.0

	# La embestida ignora el knockback (no la desvia).
	if _charge_state > 0:
		velocity.x = desired.x
		velocity.z = desired.z
	else:
		velocity.x = desired.x + _knockback.x
		velocity.z = desired.z + _knockback.z
	_knockback = _knockback.move_toward(Vector3.ZERO, 22.0 * delta)

	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.1
	_pintar()
	move_and_slide()
