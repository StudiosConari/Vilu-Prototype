extends Node3D

## El arco, la cuerda y el carcaj de Benjamín, colgados de sus huesos.
##
## El artista mandó arco, flecha y carcaj en UNA sola malla con las tres piezas
## puestas de lado. Se partieron por los dos huecos limpios que dejan en el eje
## X, y dentro del arco se separó además la CUERDA de la madera para poder
## tensarla por código: ahí no valía cortar por X —las puntas recurvadas llegan
## hasta la línea de la cuerda—, así que se separó por partes sueltas y se
## clasificó por delgadez.
##
## El arco va en la mano IZQUIERDA. No es una suposición: se midieron sus
## animaciones de tensar y es la que se adelanta 0,59 m mientras la derecha se
## queda atrás tirando de la cuerda. El carcaj va a la espalda.
##
## Van de `BoneAttachment3D`, que es quien sabe seguir un hueso cuadro a cuadro
## sin que haya que recalcular nada: así el arco acompaña a la mano mientras
## apunta, dispara o corre.
class_name ArmaDeBenjamin

const MODELO := preload("res://models/personaje/benjamin_arma.glb")

@export var hueso_mano := "mixamorig_LeftHand"
@export var hueso_espalda := "mixamorig_Spine2"

## De dónde tira la cuerda al tensar.
@export var hueso_de_tirar := "mixamorig_RightHand"

## Lo que miden en el juego, en metros. El archivo trae el arco a 1,0 de largo.
@export var largo_arco := 1.15
@export var largo_carcaj := 0.62

## El arco tiene DOS agarres y cambia de uno a otro.
##
## Sus animaciones de estar quieto y de correr se hicieron sin arco —son de
## Mixamo—, así que ahí la mano cuelga en una postura neutra; las de tensar sí
## sujetan uno. Medido: el eje del arco queda vertical al tensar (0,88 a 1,00 de
## componente hacia arriba) y casi horizontal en reposo (0,30). Pegado rígido no
## puede quedar bien en las dos.
##
## Así que se calculan las dos orientaciones al montarlo y se pasa de una a otra
## según esté apuntando o no. En pantalla se lee como acomodar el agarre, que es
## lo que uno hace de verdad antes de tirar.
@export var clip_apuntando := "flecha_cargada"
@export var momento_apuntando := 1.5
@export var clip_quieto := "reposo"
@export var momento_quieto := 0.5

## Lo que tarda en cambiar de agarre, en segundos.
@export var cambio_de_agarre := 0.18

## Cuánto puede separarse la cuerda de su sitio, en metros.
##
## Es una red de seguridad, no un ajuste: medido a lo largo de sus dos clips de
## tiro, la mano llega como mucho a 0,65 m de la cuerda. Con el tope por debajo
## de eso la cuerda se quedaba corta y la mano se salía de ella —y de paso el
## punto acortado caía dentro de la cabeza, que era el otro problema—.
@export var tension_maxima := 0.75

## Cuánto tiene que despejar la cuerda la cabeza, en metros.
##
## Otra red de seguridad, y pequeña a propósito. Su mano de tirar ya va sola
## entre 9 y 20 cm a la derecha del cráneo —medido en sus dos clips de tiro—,
## así que la cuerda tirada hasta la mano pasa por fuera sin ayuda. Empujarla
## más la separaba de la mano, que es peor: una cuerda que roza la cara es lo
## normal, una que va suelta al lado de la mano no.
@export var hueso_cabeza := "mixamorig_Head"
@export var despeje_de_la_cabeza := 0.03

## Retoque fino, después de orientarlas. La posición va en metros y en el
## sistema del CUERPO —no en el del hueso, que en un rig de Mixamo viene girado
## y haría que "un poco hacia atrás" apuntara a cualquier sitio—. La rotación,
## en grados sobre los ejes de la propia pieza.
## Retoque encima del sitio que ya se calcula solo (ver `_centro_del_puno`).
## Cero es "en el hueco de los dedos".
@export var arco_posicion := Vector3.ZERO

## Cuánto se ladea el arco al APUNTAR, en grados.
##
## Idea de Kevin, y es la buena: con el arco perfectamente vertical la cuerda le
## pasa pegada a la cara y hay que andar apartándola. Ladeándolo, el plano del
## arco se abre y la cuerda encuentra sitio ella sola —y de paso cae donde está
## la mano—. Es el mismo gesto que hace un arquero de verdad.
@export var arco_inclinacion := -22.0
@export var arco_rotacion := Vector3.ZERO
## El carcaj va en diagonal por la espalda: el fondo junto a la cadera IZQUIERDA
## y la boca asomando por el hombro DERECHO, que es con el que tira de la cuerda
## y por tanto con el que saca las flechas.
##
## El ladeo es un giro sobre el eje X de la pieza; el Z es su eje LARGO. Estaba
## en -32 y salía JUSTO AL REVÉS —el fondo asomando por el hombro y la boca
## apuntando a la cadera— porque la boca del modelo está en el -Z, no en el +Z:
## orientando el +Z hacia arriba se ponía arriba el culo del carcaj. Los 180
## grados de más son eso, y el 32 de siempre es la diagonal.
##
## Medido, no supuesto: se marcaron los dos extremos de la malla con una bola de
## color y se miró al personaje por detrás. La boca resultó ser la del extremo
## que este código estaba mandando hacia abajo.
@export var carcaj_posicion := Vector3(0.06, -0.07, 0.15)
@export var carcaj_rotacion := Vector3(148.0, 0.0, 0.0)

var _arco: Node3D = null
var _carcaj: Node3D = null
var _agarre_quieto := Quaternion.IDENTITY
var _agarre_apuntando := Quaternion.IDENTITY
var _apuntando := false

var _esq: Skeleton3D = null
var _cuerpo: Node3D = null
var _mano_que_tira := -1
var _cabeza := -1
var _punta_alta := Vector3.ZERO
var _punta_baja := Vector3.ZERO
var _hebras: Array = []
var _tirado := Vector3.ZERO      # dónde está AHORA el punto de tensión


## Cuelga las piezas del esqueleto. `referencia` es el nodo cuyo sistema define
## el "adelante" y el "arriba" del personaje: su `Visual`.
func montar(esq: Skeleton3D, referencia: Node3D, anim: AnimationPlayer = null) -> void:
	if esq == null or referencia == null:
		return
	var piezas := MODELO.instantiate() as Node3D
	if piezas == null:
		return
	_esq = esq
	_cuerpo = referencia
	_mano_que_tira = esq.find_bone(hueso_de_tirar)
	_cabeza = esq.find_bone(hueso_cabeza)

	var b: Basis = referencia.global_transform.basis
	# El carcaj cuelga de la espalda de pie y no se mueve de ahí.
	_carcaj = _colgar(piezas, "carcaj", esq, hueso_espalda, b, _de_pie(b),
		largo_carcaj, carcaj_posicion, carcaj_rotacion, false)

	# El arco se cuelga UNA vez y se orienta DOS: apuntando va derecho, y en
	# reposo cruzado delante del cuerpo, que es como se lleva un arco andando.
	var apuntando := _posar(anim, clip_apuntando, momento_apuntando)
	var ladeado: Vector3 = arco_rotacion + Vector3(arco_inclinacion, 0.0, 0.0)
	_arco = _colgar(piezas, "arco", esq, hueso_mano, b, _de_pie(b),
		largo_arco, arco_posicion, ladeado, apuntando)
	if _arco != null:
		_meter_en_el_puno(esq, b)
		_agarre_apuntando = _arco.quaternion
		_agarre_quieto = _agarre_apuntando
		if _posar(anim, clip_quieto, momento_quieto):
			_orientar(_arco, esq, hueso_mano, _cruzado(b), arco_rotacion, true)
			_agarre_quieto = _arco.quaternion
		_arco.quaternion = _agarre_quieto
		_montar_cuerda(piezas)
	if anim != null:
		anim.stop()      # el Animador vuelve a mandar en el cuadro siguiente

	piezas.queue_free()      # ya se sacaron las piezas que hacían falta


## Los cuatro dedos que rodean el mango. El pulgar no: cierra por el otro lado y
## metido en la media desplazaría el centro fuera del hueco.
const DEDOS := ["Index", "Middle", "Ring", "Pinky"]


## Mete el puño del arco en el hueco que forman los dedos.
##
## El hueso de la mano está en la MUÑECA, y el hueco del puño le queda a unos
## 10 cm —medido en su propia pose de tensar—. Colgando el arco del hueso a
## secas, la madera se comía la mano; corriéndolo a ojo, o seguía tapando los
## dedos o se despegaba y la mano quedaba en el aire.
##
## Se calcula: el centro está a mitad de camino entre los nudillos y las puntas
## de los cuatro dedos. Eso es el eje por donde pasa el mango de verdad.
## El centro del hueco que forman los dedos de una mano, en el mundo.
##
## Sirve para las dos: en la del arco es por donde pasa el mango, y en la que
## tira es por donde se engancha la cuerda. El hueso de la mano está en la
## MUÑECA y ese hueco le queda a unos 10 cm, así que colgar las cosas del hueso
## a secas las deja siempre fuera de la mano.
func _centro_del_puno(esq: Skeleton3D, mano: String) -> Vector3:
	var nudillos := Vector3.ZERO
	var puntas := Vector3.ZERO
	var cuantos := 0
	for dedo in DEDOS:
		var a := esq.find_bone("%s%s1" % [mano, dedo])
		var z := esq.find_bone("%s%s4" % [mano, dedo])
		if a < 0 or z < 0:
			continue
		nudillos += (esq.global_transform * esq.get_bone_global_pose(a)).origin
		puntas += (esq.global_transform * esq.get_bone_global_pose(z)).origin
		cuantos += 1
	if cuantos == 0:
		return Vector3.INF          # sin dedos: que decida quien llama
	return (nudillos + puntas) / (2.0 * float(cuantos))


func _meter_en_el_puno(esq: Skeleton3D, cuerpo: Basis) -> void:
	var centro: Vector3 = _centro_del_puno(esq, hueso_mano)
	if centro == Vector3.INF:
		push_warning("Arma: no encuentro los dedos de '%s'" % hueso_mano)
		return
	# Y se cuelga por el MANGO, no por el origen de la malla.
	var mango: Vector3 = _arco.global_transform.basis * _mango_local(_arco)
	_arco.global_position = centro - mango + cuerpo * arco_posicion


## Por dónde se agarra el arco, en coordenadas de su malla.
##
## Su origen está a medio camino entre la madera y la cuerda —o sea a unos 13 cm
## del mango una vez escalado—, así que colgándolo por el origen el mango queda
## a un palmo de la mano por mucho que se afine dónde está el puño.
##
## El mango es la sección del medio del arco, y sólo su mitad de MADERA: la
## cuerda pasa por ahí también y promediarla devolvería el centro de antes.
func _mango_local(pieza: MeshInstance3D) -> Vector3:
	var malla := pieza.mesh as ArrayMesh
	if malla == null:
		return Vector3.ZERO
	var verts: PackedVector3Array = malla.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var caja: AABB = malla.get_aabb()
	var medio: Vector3 = caja.get_center()
	var banda: float = caja.size.z * 0.07
	var suma := Vector3.ZERO
	var cuantos := 0
	for v in verts:
		if absf(v.z - medio.z) < banda and v.x < medio.x:
			suma += v
			cuantos += 1
	return (suma / float(cuantos)) if cuantos > 0 else Vector3.ZERO


## Cómo va el arco al APUNTAR: de pie, con la madera hacia el objetivo y la
## cuerda del lado del arquero. La cuerda está en el +X de la pieza.
func _de_pie(b: Basis) -> Basis:
	return Basis(b.z.normalized(), b.x.normalized(), b.y.normalized())


## Y cómo va EN REPOSO: tumbado a lo largo del cuerpo, con la cuerda hacia
## arriba y la madera abajo, que es como se lleva un arco en la mano andando.
func _cruzado(b: Basis) -> Basis:
	var adelante: Vector3 = (-b.z).normalized()
	var arriba: Vector3 = b.y.normalized()
	return Basis(arriba, adelante.cross(arriba), adelante)


## Deja al personaje un instante en una pose concreta, para medirle la mano.
func _posar(anim: AnimationPlayer, clip: String, momento: float) -> bool:
	if anim == null or not anim.has_animation(clip):
		return false
	anim.play(clip)
	anim.seek(momento, true)
	return true


## Le dice al arma si está apuntando. Lo llama el jugador cada cuadro.
func apuntar(si: bool) -> void:
	_apuntando = si


func _process(delta: float) -> void:
	if _arco == null:
		return
	var quiero: Quaternion = _agarre_apuntando if _apuntando else _agarre_quieto
	if not _arco.quaternion.is_equal_approx(quiero):
		var q: Quaternion = _arco.quaternion.slerp(
			quiero, clampf(delta / maxf(cambio_de_agarre, 0.01), 0.0, 1.0))
		# El slerp se acerca sin llegar nunca: cerca del final se cierra a mano,
		# o el arco se pasa la vida corrigiéndose una milésima.
		_arco.quaternion = quiero if q.angle_to(quiero) < 0.002 else q
	_tensar(delta)


# --- La cuerda -------------------------------------------------------------

## Cambia la cuerda horneada por dos hebras que sí se pueden tensar.
##
## La del modelo es geometría fija: no hay forma de doblarla. Se queda de
## repuesto —escondida, por si algún día hace falta volver— y en su sitio van
## dos cilindros finos, uno de cada punta al punto donde tira la mano.
func _montar_cuerda(piezas: Node3D) -> void:
	var original := piezas.get_node_or_null("cuerda") as MeshInstance3D
	if original == null or original.mesh == null:
		push_warning("Arma: el .glb no trae la pieza 'cuerda'")
		return
	piezas.remove_child(original)
	original.owner = null
	_arco.add_child(original)
	original.visible = false

	# Las dos puntas, en el sistema del arco: las dos piezas salieron con el
	# mismo origen a propósito, así que la caja de la cuerda ya está en su sitio.
	var caja: AABB = original.mesh.get_aabb()
	var medio: Vector3 = caja.get_center()
	_punta_alta = Vector3(medio.x, medio.y, caja.position.z + caja.size.z)
	_punta_baja = Vector3(medio.x, medio.y, caja.position.z)
	_tirado = (_punta_alta + _punta_baja) * 0.5

	var grosor: float = maxf(caja.size.x, caja.size.y) * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.83, 0.74)
	mat.roughness = 0.9
	for i in 2:
		var hebra := MeshInstance3D.new()
		hebra.name = "Hebra%d" % (i + 1)
		var cil := CylinderMesh.new()
		cil.top_radius = grosor
		cil.bottom_radius = grosor
		cil.height = 1.0          # la longitud se pone con la escala
		cil.radial_segments = 5
		cil.rings = 0
		hebra.mesh = cil
		hebra.material_override = mat
		_arco.add_child(hebra)
		_hebras.append(hebra)
	_tensar(1.0)


## Lleva la cuerda hacia la mano que tira.
func _tensar(delta: float) -> void:
	if _hebras.size() < 2:
		return
	var quiero: Vector3 = (_punta_alta + _punta_baja) * 0.5
	if _apuntando and _esq != null and _mano_que_tira >= 0:
		quiero = _donde_tira()
	_tirado = _tirado.lerp(quiero, clampf(delta / maxf(cambio_de_agarre, 0.01), 0.0, 1.0))
	_tender(_hebras[0], _punta_alta, _tirado)
	_tender(_hebras[1], _punta_baja, _tirado)


## El punto al que se estira la cuerda, en el sistema del arco.
##
## Sale de la mano derecha de verdad, pero con tope: en algunos cuadros de la
## animación la mano se va muy atrás y sin límite la cuerda se estiraría hasta
## el hombro.
func _donde_tira() -> Vector3:
	# Los DEDOS, no la muñeca: la cuerda se engancha en ellos, y entre una cosa
	# y la otra hay un palmo.
	var mano: Vector3 = _centro_del_puno(_esq, hueso_de_tirar)
	if mano == Vector3.INF:
		mano = (_esq.global_transform
			* _esq.get_bone_global_pose(_mano_que_tira)).origin
	var local: Vector3 = _arco.global_transform.affine_inverse() * mano
	var reposo: Vector3 = (_punta_alta + _punta_baja) * 0.5
	var tope: float = tension_maxima / maxf(_arco.scale.x, 0.0001)
	var d: Vector3 = local - reposo
	if d.length() > tope:
		d = d.normalized() * tope
	return _por_fuera_de_la_cabeza(reposo + d)


## Corre el punto de tensión hasta que la cuerda pase POR FUERA de la cabeza.
##
## La mano de tirar acaba junto a la mejilla, así que la cuerda tirada recta a
## ella le atravesaba el cráneo. Se mide cuánto sobresale el punto respecto al
## centro de la cabeza hacia su derecha y, si no llega, se empuja lo justo.
func _por_fuera_de_la_cabeza(punto: Vector3) -> Vector3:
	if _cabeza < 0 or _cuerpo == null or _arco == null:
		return punto
	var del_arco: Transform3D = _arco.global_transform.affine_inverse()
	var cabeza: Vector3 = del_arco * (_esq.global_transform
		* _esq.get_bone_global_pose(_cabeza)).origin
	var derecha: Vector3 = (del_arco.basis
		* _cuerpo.global_transform.basis.x).normalized()
	var despeje: float = despeje_de_la_cabeza / maxf(_arco.scale.x, 0.0001)
	var fuera: float = (punto - cabeza).dot(derecha)
	if fuera < despeje:
		punto += derecha * (despeje - fuera)
	return punto


## Estira una hebra entre dos puntos.
func _tender(hebra: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d: Vector3 = b - a
	var largo: float = d.length()
	if largo < 0.0001:
		hebra.visible = false
		return
	hebra.visible = true
	hebra.position = (a + b) * 0.5
	# El cilindro de Godot crece a lo largo de su Y.
	var arriba: Vector3 = d / largo
	var lado: Vector3 = arriba.cross(Vector3.RIGHT)
	if lado.length() < 0.01:
		lado = arriba.cross(Vector3.UP)
	lado = lado.normalized()
	hebra.basis = Basis(lado, arriba, lado.cross(arriba)).orthonormalized()
	hebra.scale = Vector3(1.0, largo, 1.0)


# --- Colgar y orientar -----------------------------------------------------

## Saca una pieza del .glb y la cuelga de un hueso.
func _colgar(piezas: Node3D, nombre: String, esq: Skeleton3D, hueso: String,
		cuerpo: Basis, quiero: Basis, largo: float, extra_pos: Vector3,
		extra_rot: Vector3, con_la_pose: bool) -> Node3D:
	var pieza := piezas.get_node_or_null(nombre) as MeshInstance3D
	if pieza == null:
		push_warning("Arma: el .glb no trae la pieza '%s'" % nombre)
		return null
	var i := esq.find_bone(hueso)
	if i < 0:
		push_warning("Arma: el esqueleto no tiene el hueso '%s'" % hueso)
		return null

	var enganche := BoneAttachment3D.new()
	enganche.name = "Enganche_" + nombre
	esq.add_child(enganche)
	enganche.bone_name = hueso

	piezas.remove_child(pieza)
	pieza.owner = null       # si no, se queja de que su dueño ya no la contiene
	enganche.add_child(pieza)

	# El esqueleto viene escalado para que el personaje mida sus 1,9 m, y todo lo
	# que cuelgue de un hueso hereda esa escala: sin dividirla, un arco pedido de
	# 1,15 m acababa midiendo 1,81. Vale también para el desplazamiento, que si
	# no iría en "metros por 1,9".
	var del_rig: float = maxf(absf(esq.global_transform.basis.get_scale().y), 0.0001)

	# Tamaño: el eje largo de las piezas es su Z.
	var caja: AABB = pieza.mesh.get_aabb()
	_orientar(pieza, esq, hueso, quiero, extra_rot, con_la_pose)
	# `basis` se lleva la escala por delante: se vuelve a poner.
	pieza.scale = Vector3.ONE * (largo / (maxf(caja.size.z, 0.001) * del_rig))
	# El desplazamiento va en los ejes del CUERPO, no del hueso ni del mundo: un
	# "hacia atrás" tiene que seguir siendo hacia su espalda mire a donde mire.
	pieza.position = (_sin_escala(esq, i, con_la_pose).inverse()
		* (cuerpo * extra_pos)) / del_rig
	return pieza


## Pone la pieza en la orientación `quiero`, sea cual sea el giro del hueso.
##
## `quiero` es cómo debe quedar en el MUNDO; de ahí se saca qué rotación local
## le toca dentro del hueso. Se calcula, no se escribe a mano: así vale aunque
## el rig cambie. `extra_rot` es el retoque fino.
func _orientar(pieza: Node3D, esq: Skeleton3D, hueso: String, quiero: Basis,
		extra_rot: Vector3, con_la_pose: bool) -> void:
	var i := esq.find_bone(hueso)
	if i < 0:
		return
	var escala := pieza.scale
	pieza.basis = _sin_escala(esq, i, con_la_pose).inverse() * quiero * Basis.from_euler(
		Vector3(deg_to_rad(extra_rot.x), deg_to_rad(extra_rot.y), deg_to_rad(extra_rot.z)))
	pieza.scale = escala


## La orientación del hueso en el mundo, sin su escala, tal como está AHORA
## (`con_la_pose`) o en reposo.
func _sin_escala(esq: Skeleton3D, i: int, con_la_pose: bool) -> Basis:
	var en_el_hueso: Transform3D = esq.get_bone_global_pose(i) if con_la_pose \
		else esq.get_bone_global_rest(i)
	var m: Basis = (esq.global_transform * en_el_hueso).basis
	return Basis(m.x.normalized(), m.y.normalized(), m.z.normalized())
