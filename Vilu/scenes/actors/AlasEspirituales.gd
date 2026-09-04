extends Node3D

## Las alas del Alicanto: la malla del artista con su shader de disolución.
##
## Vienen dentro del esqueleto de EMILIA_COMPLETA, que NO es el rig de la Emilia
## jugable —son dos esqueletos distintos, 46 huesos contra 65—, así que no se
## pueden injertar. Se sacaron a un `.glb` propio con sus huesos `Ala_*` y sus
## tres animaciones, y se cuelgan de la espalda animándose solas.
##
## Sustituyen a la malla plana que se encendía y apagaba de golpe: ahora
## aparecen y se van disolviéndose, que es para lo que el artista mandó el
## shader.

const MODELO := preload("res://models/personaje/alas_espirituales.glb")
const SHADER := preload("res://art_placeholders/alas_espirituales.gdshader")

## Los dos extremos del parámetro `disolucion`, tal como los da el artista:
## -0,35 = invisibles, 1,45 = completas.
const OCULTAS := -0.35
const COMPLETAS := 1.45

const CLIP_APARECER := "ALAS_salto_doble"
const CLIP_SOSTENER := "ALAS_salto_sostenido"
const CLIP_PLANEO := "ALAS_planeo"

## Alto del modelo del que salieron, en sus propias unidades.
##
## El `.glb` de la entrega viene a escala grande: el cuerpo de esa Emilia mide
## 10,345 y las alas están colocadas en ese sistema. Se usa para bajarlas al
## tamaño del personaje del juego conservando dónde le quedan en la espalda.
@export var alto_del_modelo := 10.345

## Segundos que tarda en aparecer o en irse.
@export var fundido := 0.22

## Los modelos de este proyecto miran a +Z y el juego avanza hacia -Z. Sin darles
## la vuelta, las alas barren hacia el pecho en vez de hacia la espalda.
@export var giro_modelo := 180.0

## Retoque fino del enganche, en metros. En Y positivo las sube por la espalda.
@export var ajuste := Vector3.ZERO

## De dónde cuelgan: se ancla el punto medio de los dos hombros de las alas al
## origen de este nodo.
const HOMBROS := ["Ala_Hombro.L", "Ala_Hombro.R"]

## El hueso de Emilia del que se cuelgan.
##
## `Visual/Wings` no sirve: está QUIETO, y en el salto doble Emilia se dobla
## hacia adelante, con lo que las alas se quedaban donde habría estado su
## espalda de pie. Y encima ese nodo está en z = +0,28 mientras su columna está
## en z = -0,08: medido, las alas colgaban a 36 cm por detrás de la columna, o
## sea un palmo separadas del cuerpo. Ese hueco lo pedía la malla plana del
## greybox, no las alas de verdad.
@export var hueso_espalda := "mixamorig_Spine2"

## Dónde se pegan respecto a ese hueso, en metros y en el sistema del cuerpo.
## Por defecto, un palmo más arriba —a la altura de los omóplatos— y lo justo
## por detrás para que no se metan dentro de la espalda.
@export var desplazamiento := Vector3(0.0, 0.09, 0.10)

var _esq: Skeleton3D = null
var _hueso := -1
var _respecto_al_hueso := Transform3D()

var _mat: ShaderMaterial = null
var _anim: AnimationPlayer = null
var _puestas := false
var _valor := OCULTAS
var _objetivo := OCULTAS
var _clip := ""


## Cuelga las alas y las deja invisibles. `alto_personaje` en metros.
func montar(alto_personaje: float) -> void:
	var m := MODELO.instantiate() as Node3D
	if m == null:
		return
	add_child(m)
	m.scale = Vector3.ONE * (alto_personaje / maxf(alto_del_modelo, 0.001))
	m.rotation_degrees.y = giro_modelo
	_anclar(m)

	var malla := _buscar_malla(m)
	if malla == null:
		push_warning("Alas: el modelo no trae malla")
		return
	_vestir(malla)
	_anim = _buscar_anim(m)
	_puestas = true
	_aplicar()


## Las engancha a la columna de Emilia para que sigan al cuerpo.
##
## `referencia` es el nodo cuyo sistema define el "detrás" —el `Visual` del
## jugador—: el desplazamiento se mide en él, no en el del hueso, que en un rig
## de Mixamo viene girado y haría que un simple "10 cm hacia atrás" apuntara a
## cualquier sitio.
func enganchar_a(esq: Skeleton3D, referencia: Node3D) -> void:
	if esq == null or referencia == null:
		return
	var i := esq.find_bone(hueso_espalda)
	if i < 0:
		push_warning("Alas: el esqueleto no tiene el hueso '%s'" % hueso_espalda)
		return
	# En reposo, que es como está el esqueleto mientras se monta todo.
	var hueso_mundo: Transform3D = esq.global_transform * esq.get_bone_global_rest(i)
	var base: Basis = referencia.global_transform.basis
	var donde := Transform3D(base, hueso_mundo.origin + base * desplazamiento)
	_respecto_al_hueso = hueso_mundo.affine_inverse() * donde
	_esq = esq
	_hueso = i
	_seguir_la_espalda()


## Las lleva a donde esté ahora el hueso. Cada cuadro: es justo el movimiento
## del que no se enteraban.
func _seguir_la_espalda() -> void:
	if _esq == null or _hueso < 0:
		return
	global_transform = (_esq.global_transform * _esq.get_bone_global_pose(_hueso)) \
		* _respecto_al_hueso


## Las cuelga de la espalda por sus propios huesos.
##
## El `.glb` viene en el sistema del EMILIA_COMPLETA del artista: su raíz está a
## la altura de los pies y los hombros de las alas a 7,6 de los 10,345 que mide
## ese cuerpo. Soltando el modelo tal cual, esos 7,6 se convertían en 1,4 m POR
## ENCIMA del enganche: las alas salían flotando a dos metros y medio del suelo,
## sobre la cabeza de Emilia, que mide 1,9. Medido en el motor.
##
## En vez de restar una constante a ojo, se mide dónde caen los hombros ya con
## la escala y el giro puestos y se compensa. Así sigue valiendo aunque el
## artista mande el modelo a otra escala.
func _anclar(m: Node3D) -> void:
	if not is_inside_tree():
		return
	var esq := _buscar_esqueleto(m)
	if esq == null:
		return
	var suma := Vector3.ZERO
	var cuantos := 0
	for hueso in HOMBROS:
		var i := esq.find_bone(hueso)
		if i < 0:
			continue
		suma += esq.global_transform * esq.get_bone_global_rest(i).origin
		cuantos += 1
	if cuantos == 0:
		push_warning("Alas: no encuentro los huesos %s" % str(HOMBROS))
		return
	m.global_position -= (suma / float(cuantos)) - global_position
	m.position += ajuste


func _buscar_esqueleto(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for h in n.get_children():
		var x := _buscar_esqueleto(h)
		if x != null:
			return x
	return null


## Le pone el shader, heredando las texturas que ya traía el material del .glb.
func _vestir(malla: MeshInstance3D) -> void:
	var viejo := malla.mesh.surface_get_material(0) as BaseMaterial3D
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	if viejo != null:
		_mat.set_shader_parameter("tex_color", viejo.albedo_texture)
		_mat.set_shader_parameter("tex_normal", viejo.normal_texture)
		_mat.set_shader_parameter("tex_rough", viejo.roughness_texture)

	# La media envergadura, EN UNIDADES DE LA MALLA.
	#
	# El shader hace `abs(VERTEX.x) / semi_envergadura` para barrer de la base a
	# la punta, y `VERTEX` va en el sistema de la malla, no en metros de mundo:
	# no le afecta la escala del nodo. El valor que trae por defecto (0,489)
	# corresponde al archivo del artista a escala 1:1; el `.glb` que llega aquí
	# mide 8,8 de envergadura, y con 0,489 la división se satura enseguida y todo
	# el ala se disuelve a la vez en vez de barrerse. Se mide y se pone.
	var caja: AABB = malla.mesh.get_aabb()
	var media: float = maxf(caja.size.x * 0.5, 0.001)
	_mat.set_shader_parameter("semi_envergadura", media)

	malla.material_override = _mat


## Enciende o apaga las alas. `planeando` elige el clip.
func mostrar(visibles: bool, planeando: bool) -> void:
	_objetivo = COMPLETAS if visibles else OCULTAS
	if not visibles or _anim == null:
		return
	var quiero := CLIP_PLANEO if planeando else CLIP_APARECER
	if _clip == "" or (_clip == CLIP_APARECER and not _anim.is_playing()):
		# Al terminar el golpe de alas se pasa al sostenido, salvo planeando.
		quiero = CLIP_PLANEO if planeando else CLIP_SOSTENER
	if quiero == _clip:
		return
	if not _anim.has_animation(quiero):
		return
	if quiero != CLIP_APARECER:
		_anim.get_animation(quiero).loop_mode = Animation.LOOP_LINEAR
	_anim.play(quiero)
	_clip = quiero


func _process(delta: float) -> void:
	_seguir_la_espalda()          # antes del return: el cuerpo se mueve igual
	if not _puestas or is_equal_approx(_valor, _objetivo):
		return
	var paso: float = (COMPLETAS - OCULTAS) * delta / maxf(fundido, 0.01)
	_valor = move_toward(_valor, _objetivo, paso)
	_aplicar()
	if is_equal_approx(_valor, OCULTAS):
		_clip = ""   # la próxima vez vuelve a entrar por el golpe de alas


func _aplicar() -> void:
	if _mat != null:
		_mat.set_shader_parameter("disolucion", _valor)
	# Del todo apagadas no se dibujan: el shader es transparente y cuesta aunque
	# no se vea nada.
	visible = _valor > OCULTAS + 0.001


func _buscar_malla(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		return n
	for h in n.get_children():
		var x := _buscar_malla(h)
		if x != null:
			return x
	return null


func _buscar_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for h in n.get_children():
		var x := _buscar_anim(h)
		if x != null:
			return x
	return null
