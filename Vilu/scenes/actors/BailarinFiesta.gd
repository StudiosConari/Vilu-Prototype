extends Node3D

## Deja bailando a la gente de la plaza de La Tirana.
##
## Los modelos de la fiesta volvieron riggeados con un clip cada uno. Godot los
## importa con su AnimationPlayer, pero ni lo arranca ni marca el clip como
## bucle: sin esto la plaza se queda congelada en el primer cuadro.
##
## Tres de ellos comparten el MISMO baile. Arrancando todos del cuadro cero la
## plaza se movería como un espejo, así que cada uno entra por un punto distinto
## del clip. El desfase sale del nombre del nodo —único dentro de la escena— y
## no de un azar: así la fiesta se ve igual en cada partida y en los tests.
class_name BailarinFiesta

## Cuánto puede tardar en incorporarse, como fracción del clip. En 0 todos
## arrancan a la vez.
@export_range(0.0, 1.0) var desfase := 1.0

## Los que llevan encima un cuerpo de interacción: con ésos se habla, y hablarle
## a alguien que está bailando queda mal. Se quedan de pie.
@export var quieto := false

## El idle lleva el mismo nombre en los cuatro que lo tienen, mientras que el
## clip propio de cada personaje lleva el suyo. Así se pueden distinguir sin
## saber de antemano a quién se le está poniendo el script.
const CLIP_QUIETO := "idle"

## Una cápsula estrecha en vez de la silueta entera.
##
## El .glb trae una malla `-convcolonly` con el contorno del personaje: falda,
## cuernos y todo. Medida, la de chica_disfrazada ocupa 1,02 m de ancho, y con
## la escala que lleva en la plaza se va a 1,35: entre dos bailarines separados
## 1,4 m no queda por dónde pasar. Encima es una malla FIJA, así que se queda
## plantada en la pose de reposo mientras el personaje baila fuera de ella.
##
## Van en metros del MODELO, o sea antes de la escala que lleve el nodo.
@export var radio_colision := 0.22
@export var alto_colision := 1.6

## De qué hueso cuelga la colisión. Los seis salieron del mismo rig de AccuRig.
const HUESO_CADERA := "CC_Base_Hip"

var _anim: AnimationPlayer = null
var _clip := ""
var _cuerpo: StaticBody3D = null
var _esq: Skeleton3D = null
var _cadera := -1


func _ready() -> void:
	_afinar_colision()
	_anim = _buscar_anim(self)
	if _anim == null:
		push_warning("%s: el modelo no trae AnimationPlayer" % name)
		return
	var lista := _anim.get_animation_list()
	if lista.is_empty():
		push_warning("%s: el modelo no trae animaciones" % name)
		return
	_clip = elegir_clip(lista)
	var a := _anim.get_animation(_clip)
	a.loop_mode = Animation.LOOP_LINEAR
	_anim.play(_clip)
	if desfase > 0.0:
		_anim.seek(_entrada(a.length), true)


## Cambia la silueta de colisión por una cápsula estrecha.
func _afinar_colision() -> void:
	_cuerpo = _buscar(self, "StaticBody3D") as StaticBody3D
	if _cuerpo == null:
		return
	var cs := _buscar(_cuerpo, "CollisionShape3D") as CollisionShape3D
	if cs != null:
		var capsula := CapsuleShape3D.new()
		capsula.radius = radio_colision
		capsula.height = maxf(alto_colision, radio_colision * 2.0 + 0.01)
		cs.shape = capsula
		cs.position = Vector3(0.0, capsula.height * 0.5, 0.0)

	# El nodo puede traer escala NO uniforme desde la escena —a algunos se les
	# estiró un eje a mano—, y una cápsula así Godot no la sabe representar: la
	# aproxima y avisa por consola. Se le devuelve al cuerpo una escala uniforme
	# dividiéndola por la del padre.
	var e := global_transform.basis.get_scale()
	if e.x > 0.0001 and e.y > 0.0001 and e.z > 0.0001:
		var menor: float = minf(e.x, minf(e.y, e.z))
		_cuerpo.scale = Vector3(menor / e.x, menor / e.y, menor / e.z)

	_esq = _buscar(self, "Skeleton3D") as Skeleton3D
	if _esq != null:
		_cadera = _esq.find_bone(HUESO_CADERA)
	if _cadera < 0:
		push_warning("%s: sin hueso '%s', la colisión no seguirá el baile"
			% [name, HUESO_CADERA])


## La colisión acompaña al baile.
##
## Con la malla del .glb, que es fija, el bailarín se sale de su propia colisión
## en cuanto se mueve: quedan sitios donde se ve a alguien y se puede atravesar,
## y sitios vacíos donde se choca. La cápsula se lleva cada cuadro a la vertical
## de la cadera.
func _process(_delta: float) -> void:
	if _cuerpo == null or _esq == null or _cadera < 0:
		return
	var mundo: Vector3 = (_esq.global_transform * _esq.get_bone_global_pose(_cadera)).origin
	var local: Vector3 = global_transform.affine_inverse() * mundo
	_cuerpo.position = Vector3(local.x, _cuerpo.position.y, local.z)


## Cuál de los clips del modelo toca.
##
## No vale quedarse con el primero de la lista: llega ordenada alfabéticamente,
## y en nativo_americano el "idle" prestado se cuela por delante de su "ritual".
## El clip propio es, justamente, el que NO se llama como el prestado.
func elegir_clip(lista: PackedStringArray) -> String:
	if quieto:
		if lista.has(CLIP_QUIETO):
			return CLIP_QUIETO
		push_warning("%s: se le pide estar quieto pero no trae '%s'" % [name, CLIP_QUIETO])
		return lista[0]
	for c in lista:
		if c != CLIP_QUIETO:
			return c
	return lista[0]


## El punto del clip por el que entra este bailarín.
func _entrada(largo: float) -> float:
	# abs() sobre el hash: en GDScript puede venir negativo.
	var s := float(abs(hash(name)) % 1000) / 1000.0
	return largo * s * desfase


func _buscar(n: Node, clase: String) -> Node:
	if n.is_class(clase):
		return n
	for h in n.get_children():
		var x := _buscar(h, clase)
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
