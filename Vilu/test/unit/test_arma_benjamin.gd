extends "res://addons/gut/test.gd"

## El arco y el carcaj de Benjamín.
##
## Vinieron del artista en UNA sola malla con arco, flecha y carcaj puestos de
## lado. Se partieron por los dos huecos limpios que dejan en el eje X y salen
## en el mismo `.glb` —una sola textura para las tres, que en archivos sueltos
## se incrustaba tres veces—.

const PLAYER := preload("res://scenes/actors/Player.tscn")
const ARMA := preload("res://models/personaje/benjamin_arma.glb")
const FLECHA := preload("res://scenes/Arrow.gd")


func before_each() -> void:
	GameManager.reset_progress()


func after_all() -> void:
	GameManager.reset_progress()


func _buscar(n: Node, clase: String) -> Node:
	if n.is_class(clase):
		return n
	for h in n.get_children():
		var x := _buscar(h, clase)
		if x != null:
			return x
	return null


func _benjamin() -> CharacterBody3D:
	var p: CharacterBody3D = PLAYER.instantiate()
	p.is_archer = true
	add_child_autofree(p)
	for i in 20:
		await get_tree().process_frame
	await wait_physics_frames(3)
	return p


func test_el_glb_trae_las_tres_piezas() -> void:
	var m: Node3D = ARMA.instantiate()
	add_child_autofree(m)
	for nombre in ["arco", "flecha", "carcaj"]:
		var mi: MeshInstance3D = m.get_node_or_null(nombre)
		assert_not_null(mi, "el .glb trae '%s'" % nombre)
		if mi == null or mi.mesh == null:
			continue
		var mat := mi.mesh.surface_get_material(0) as BaseMaterial3D
		assert_not_null(mat, "%s lleva material" % nombre)
		if mat != null:
			assert_not_null(mat.albedo_texture, "%s lleva su textura" % nombre)
		# El eje largo de las tres es su Z: de ahí sale la escala al montarlas.
		var c: AABB = mi.mesh.get_aabb()
		assert_gt(c.size.z, c.size.x, "%s: su eje largo es Z" % nombre)
		assert_gt(c.size.z, c.size.y, "%s: su eje largo es Z" % nombre)


## Benjamín lleva el arco y el carcaj; Emilia no, que pelea a puñetazos.
func test_solo_el_arquero_lleva_arma() -> void:
	var b := await _benjamin()
	assert_not_null(b.get_node_or_null("Arma"), "Benjamín monta su arma")

	var e: CharacterBody3D = PLAYER.instantiate()
	e.is_archer = false
	add_child_autofree(e)
	await wait_physics_frames(3)
	assert_null(e.get_node_or_null("Arma"), "Emilia no")


## El arco va colgado del HUESO de la mano, no de un nodo suelto: así acompaña a
## la mano mientras apunta, dispara o corre.
func test_el_arco_cuelga_de_la_mano_izquierda() -> void:
	var b := await _benjamin()
	var esq: Skeleton3D = _buscar(b.get_node("Visual/Animador"), "Skeleton3D")
	assert_not_null(esq)
	if esq == null:
		return
	var enganche: BoneAttachment3D = esq.get_node_or_null("Enganche_arco")
	assert_not_null(enganche, "hay un enganche para el arco en el esqueleto")
	if enganche == null:
		return
	assert_eq(enganche.bone_name, "mixamorig_LeftHand",
		"y cuelga de la izquierda, que es la que se adelanta al tensar")
	assert_not_null(enganche.get_node_or_null("arco"), "con el arco colgando")


## El carcaj va en diagonal por la espalda: el fondo junto a la cadera IZQUIERDA
## y la boca asomando por el hombro DERECHO, que es con el que tira.
##
## El ladeo es un giro sobre el eje X de la pieza. Sobre el Z —su eje largo—
## sólo la hace rodar sobre sí misma, que es como la tuve un rato: parecía
## puesta del revés y en realidad no estaba ladeada en absoluto.
##
## Y después SÍ estaba del revés, por otro motivo: se daba por hecho que la boca
## era el +Z. Es el -Z, y este test lo daba por bueno porque miraba el mismo
## extremo equivocado que el código.
##
## Ojo al leer las capturas de espaldas: mirando a alguien por detrás su derecha
## es TU derecha, no tu izquierda. Por ahí me equivoqué al nombrar los lados.
func test_el_carcaj_va_en_diagonal_por_la_espalda() -> void:
	var b := await _benjamin()
	var esq: Skeleton3D = _buscar(b.get_node("Visual/Animador"), "Skeleton3D")
	var carcaj: Node3D = esq.get_node_or_null("Enganche_carcaj/carcaj") if esq != null else null
	if carcaj == null:
		return
	# La boca es el -Z de la pieza, NO el +Z.
	#
	# Acá decía lo contrario, y por eso este test daba por bueno el carcaj
	# puesto del revés: el código orientaba el +Z hacia arriba y lo que asomaba
	# por el hombro era el fondo, con las flechas cabeza abajo. Se volvió a medir
	# poniéndole una bola de color a cada extremo de la malla y renderizándola: la
	# marca del extremo de z MÍNIMO es la que cae en el borde abierto.
	var boca: Vector3 = (-carcaj.global_transform.basis.z).normalized()
	var vis: Node3D = b.get_node("Visual")
	var arriba: Vector3 = vis.global_transform.basis.y.normalized()
	# Su derecha es el +X del Visual: medido en el esqueleto, el hueso
	# `mixamorig_RightShoulder` cae en x positivo y el izquierdo en negativo.
	var derecha: Vector3 = vis.global_transform.basis.x.normalized()
	assert_gt(boca.dot(arriba), 0.6, "la boca mira hacia arriba")
	assert_gt(boca.dot(derecha), 0.2,
		"y ladeada hacia su hombro derecho (%.2f)" % boca.dot(derecha))


func test_el_carcaj_cuelga_de_la_espalda() -> void:
	var b := await _benjamin()
	var esq: Skeleton3D = _buscar(b.get_node("Visual/Animador"), "Skeleton3D")
	if esq == null:
		return
	var enganche: BoneAttachment3D = esq.get_node_or_null("Enganche_carcaj")
	assert_not_null(enganche, "hay un enganche para el carcaj")
	if enganche != null:
		assert_eq(enganche.bone_name, "mixamorig_Spine2")


## El arco se mide en metros, no en las unidades del archivo.
func test_el_arco_tiene_el_tamano_de_un_arco() -> void:
	var b := await _benjamin()
	var esq: Skeleton3D = _buscar(b.get_node("Visual/Animador"), "Skeleton3D")
	if esq == null:
		return
	var arco: MeshInstance3D = esq.get_node_or_null("Enganche_arco/arco")
	assert_not_null(arco)
	if arco == null:
		return
	var caja: AABB = arco.global_transform * arco.get_aabb()
	var largo: float = maxf(caja.size.x, maxf(caja.size.y, caja.size.z))
	assert_between(largo, 0.9, 1.5,
		"mide como un arco para alguien de %.2f m (%.2f m)" % [b.ALTO_PERSONAJE, largo])


## Y va donde la mano, no a un metro de ella.
func test_el_arco_esta_en_la_mano() -> void:
	var b := await _benjamin()
	var esq: Skeleton3D = _buscar(b.get_node("Visual/Animador"), "Skeleton3D")
	if esq == null:
		return
	var arco: Node3D = esq.get_node_or_null("Enganche_arco/arco")
	var i := esq.find_bone("mixamorig_LeftHand")
	if arco == null or i < 0:
		return
	var mano: Vector3 = (esq.global_transform * esq.get_bone_global_pose(i)).origin
	assert_lt(arco.global_position.distance_to(mano), 0.15,
		"el puño del arco cae en la mano")


## El arco tiene DOS agarres.
##
## Sus animaciones de estar quieto y de correr se hicieron sin arco —son de
## Mixamo— y ahí la mano cuelga neutra; las de tensar sí sujetan uno. Medido: el
## eje del arco sale vertical al tensar y casi horizontal en reposo. Pegado
## rígido no puede quedar bien en las dos, así que cambia de agarre.
func test_el_arco_cambia_de_agarre_al_apuntar() -> void:
	var b := await _benjamin()
	var arma: Node = b.get_node_or_null("Arma")
	assert_not_null(arma)
	if arma == null:
		return
	assert_false(arma._agarre_quieto.is_equal_approx(arma._agarre_apuntando),
		"los dos agarres son distintos: si no, sobra todo esto")

	var esq: Skeleton3D = _buscar(b.get_node("Visual/Animador"), "Skeleton3D")
	var arco: Node3D = esq.get_node_or_null("Enganche_arco/arco")
	if arco == null:
		return
	# Se tensa de verdad en vez de llamar a `apuntar`: el jugador se lo dice al
	# arma en CADA cuadro de física, así que ponerlo a mano no dura nada.
	#
	# Y se compara por ÁNGULO y no por componentes: un cuaternión y su negado
	# son el mismo giro, y el slerp puede llegar por cualquiera de los dos lados.
	# El cambio se corre a mano con un delta fijo: sin ventana, los cuadros duran
	# microsegundos y el fundido no llegaría nunca.
	b._charging = true
	await wait_physics_frames(2)
	for i in 30:
		arma._process(0.05)
	assert_lt(arco.quaternion.angle_to(arma._agarre_apuntando), 0.05,
		"tensando llega al agarre de tiro")

	b._charging = false
	b._attack_cd = 0.0
	await wait_physics_frames(2)
	for i in 30:
		arma._process(0.05)
	assert_lt(arco.quaternion.angle_to(arma._agarre_quieto), 0.05,
		"y al bajar el arco vuelve al otro")


## Con el agarre de tiro el arco va DERECHO, que es lo que se ve al disparar.
func test_apuntando_el_arco_esta_derecho() -> void:
	var b := await _benjamin()
	var arma: Node = b.get_node_or_null("Arma")
	var esq: Skeleton3D = _buscar(b.get_node("Visual/Animador"), "Skeleton3D")
	var ap: AnimationPlayer = _buscar(b.get_node("Visual/Animador"), "AnimationPlayer")
	var arco: Node3D = esq.get_node_or_null("Enganche_arco/arco") if esq != null else null
	if arma == null or arco == null or ap == null:
		return
	arma.apuntar(true)
	arco.quaternion = arma._agarre_apuntando
	ap.play(arma.clip_apuntando)
	ap.seek(arma.momento_apuntando, true)
	await get_tree().process_frame

	# El eje largo del arco es su Z local: tensando tiene que mirar ARRIBA.
	var eje: Vector3 = arco.global_transform.basis.z.normalized()
	assert_gt(absf(eje.y), 0.75,
		"el arco va de pie al tensar, no cruzado (eje %s)" % eje)


## La cuerda va del lado del arquero y la madera hacia el objetivo.
##
## Iba al revés: la cuerda le quedaba en la mano izquierda y las palas por
## delante, así que al tensar la uve de la cuerda salía por donde no era.
##
## En el modelo la cuerda está del lado +X de la pieza. Eso se comprobó
## FOTOGRAFIANDO el arco con el motor, que es lo único que distingue de verdad
## la cuerda de las palas: contar vértices engaña —el lado de la cuerda tiene
## más (2.275 contra 698), porque ahí viven las puntas recurvadas y las
## muescas—, y el grosor tampoco separa (0,062 contra 0,055).
##
## Si alguien voltea la base al orientar el arco, esto se cae.
func test_la_cuerda_queda_del_lado_de_benjamin() -> void:
	var b := await _benjamin()
	var arma: Node = b.get_node_or_null("Arma")
	var esq: Skeleton3D = _buscar(b.get_node("Visual/Animador"), "Skeleton3D")
	var ap: AnimationPlayer = _buscar(b.get_node("Visual/Animador"), "AnimationPlayer")
	var arco: MeshInstance3D = esq.get_node_or_null("Enganche_arco/arco") if esq != null else null
	if arma == null or arco == null or ap == null:
		return

	arma.apuntar(true)
	arco.quaternion = arma._agarre_apuntando
	ap.play(arma.clip_apuntando)
	ap.seek(arma.momento_apuntando, true)
	await get_tree().process_frame

	var hacia_la_cuerda: Vector3 = arco.global_transform.basis.x.normalized()
	var frente: Vector3 = -(b.get_node("Visual") as Node3D).global_transform.basis.z
	var cara: float = hacia_la_cuerda.dot(frente)
	assert_lt(cara, -0.4,
		"la cuerda le queda a él y la madera mira a donde tira (%.2f)" % cara)


## El MANGO del arco cae dentro del puño.
##
## Aquí hubo dos errores encadenados y los dos venían de colocar el arco por
## sitios que no son:
##
##  1. El hueso de la mano está en la MUÑECA, y el hueco que forman los dedos le
##     queda a unos 10 cm. Colgando el arco del hueso, la madera se comía la
##     mano; corriéndolo a ojo, o seguía tapando los dedos o se despegaba.
##  2. Y el origen de la malla del arco está a medio camino entre la madera y la
##     cuerda —otros 13 cm—, así que aun acertando con el puño, el mango se iba
##     igual de largo.
##
## Ahora se calculan las dos cosas: el centro del puño desde los propios dedos y
## el mango desde la malla. Este test compara justo eso.
func test_el_mango_del_arco_cae_en_el_puno() -> void:
	var b := await _benjamin()
	var arma: Node = b.get_node_or_null("Arma")
	var esq: Skeleton3D = _buscar(b.get_node("Visual/Animador"), "Skeleton3D")
	var ap: AnimationPlayer = _buscar(b.get_node("Visual/Animador"), "AnimationPlayer")
	var arco: Node3D = esq.get_node_or_null("Enganche_arco/arco") if esq != null else null
	var i := esq.find_bone("mixamorig_LeftHand") if esq != null else -1
	if arma == null or arco == null or ap == null or i < 0:
		return

	arma.apuntar(true)
	arco.quaternion = arma._agarre_apuntando
	ap.play(arma.clip_apuntando)
	ap.seek(arma.momento_apuntando, true)
	await get_tree().process_frame

	# El centro del puño: a mitad de camino entre los nudillos y las puntas de
	# los cuatro dedos. El pulgar no cuenta, cierra por el otro lado.
	var nudillos := Vector3.ZERO
	var puntas := Vector3.ZERO
	var cuantos := 0
	for dedo in ["Index", "Middle", "Ring", "Pinky"]:
		var a := esq.find_bone("mixamorig_LeftHand%s1" % dedo)
		var z := esq.find_bone("mixamorig_LeftHand%s4" % dedo)
		if a < 0 or z < 0:
			continue
		nudillos += (esq.global_transform * esq.get_bone_global_pose(a)).origin
		puntas += (esq.global_transform * esq.get_bone_global_pose(z)).origin
		cuantos += 1
	assert_gt(cuantos, 0, "encuentra los dedos de la mano del arco")
	if cuantos == 0:
		return
	var puno: Vector3 = (nudillos + puntas) / (2.0 * float(cuantos))

	var mango: Vector3 = arco.global_transform * arma._mango_local(arco)
	assert_lt(mango.distance_to(puno), 0.05,
		"el mango del arco cae dentro del puño (%.3f m)" % mango.distance_to(puno))

	# Y el mango NO está donde el origen de la malla: si lo estuviera, este test
	# pasaría por casualidad y no probaría nada.
	assert_gt(arco.global_position.distance_to(mango), 0.05,
		"el mango está lejos del origen de la malla, que es de lo que se trata")


## En reposo el arco va TUMBADO, no de pie: es como se lleva un arco andando, y
## además es la postura en la que la mano de sus animaciones de Mixamo queda
## natural.
func test_en_reposo_el_arco_va_tumbado() -> void:
	var b := await _benjamin()
	var arma: Node = b.get_node_or_null("Arma")
	var esq: Skeleton3D = _buscar(b.get_node("Visual/Animador"), "Skeleton3D")
	var ap: AnimationPlayer = _buscar(b.get_node("Visual/Animador"), "AnimationPlayer")
	var arco: Node3D = esq.get_node_or_null("Enganche_arco/arco") if esq != null else null
	if arma == null or arco == null or ap == null:
		return
	arco.quaternion = arma._agarre_quieto
	ap.play(arma.clip_quieto)
	ap.seek(arma.momento_quieto, true)
	await get_tree().process_frame
	var eje: Vector3 = arco.global_transform.basis.z.normalized()
	assert_lt(absf(eje.y), 0.45, "quieto va tumbado, no de pie (eje %s)" % eje)


## La cuerda del modelo es geometría fija; la que se ve son dos hebras que sí se
## pueden tensar.
func test_la_cuerda_horneada_se_cambia_por_dos_hebras() -> void:
	var b := await _benjamin()
	var esq: Skeleton3D = _buscar(b.get_node("Visual/Animador"), "Skeleton3D")
	var arco: Node3D = esq.get_node_or_null("Enganche_arco/arco") if esq != null else null
	if arco == null:
		return
	var original: MeshInstance3D = arco.get_node_or_null("cuerda")
	assert_not_null(original, "la cuerda del .glb sigue ahí, de repuesto")
	if original != null:
		assert_false(original.visible, "…pero escondida")
	for n in ["Hebra1", "Hebra2"]:
		var h: MeshInstance3D = arco.get_node_or_null(n)
		assert_not_null(h, "está %s" % n)
		if h != null:
			assert_true(h.visible, "%s se ve" % n)


## Quieta la cuerda va recta de punta a punta; tensando se va a la mano derecha.
func test_la_cuerda_se_tensa_hacia_la_mano_derecha() -> void:
	var b := await _benjamin()
	var arma: Node = b.get_node_or_null("Arma")
	if arma == null or arma._arco == null:
		return
	var recto: Vector3 = (arma._punta_alta + arma._punta_baja) * 0.5
	for i in 40:
		arma._process(0.05)
	assert_almost_eq(arma._tirado.distance_to(recto), 0.0, 0.01,
		"sin tensar, la cuerda va recta")

	b._charging = true
	await wait_physics_frames(2)
	for i in 40:
		arma._process(0.05)
	var estirado: float = arma._tirado.distance_to(recto)
	assert_gt(estirado, 0.05, "tensando se separa de su sitio (%.3f)" % estirado)

	# Con tope: la mano derecha se va muy atrás en algunos cuadros y sin límite
	# la cuerda se estiraría hasta el hombro.
	var tope: float = arma.tension_maxima / maxf(arma._arco.scale.x, 0.0001)
	assert_lte(estirado, tope + 0.001, "y no se pasa del tope")


## La cuerda acaba en los DEDOS de la mano que tira, no en la muñeca.
##
## Entre una cosa y la otra hay un palmo: el hueso de la mano está en la muñeca
## y el hueco donde se engancharía la cuerda le queda a unos 10 cm. Tirando a la
## muñeca, la cuerda le pasaba por el dorso de la mano.
func test_la_cuerda_acaba_en_los_dedos() -> void:
	var b := await _benjamin()
	var arma: Node = b.get_node_or_null("Arma")
	var esq: Skeleton3D = _buscar(b.get_node("Visual/Animador"), "Skeleton3D")
	var ap: AnimationPlayer = _buscar(b.get_node("Visual/Animador"), "AnimationPlayer")
	if arma == null or esq == null or ap == null or arma._arco == null:
		return
	b._charging = true
	ap.play(arma.clip_apuntando)
	ap.seek(arma.momento_apuntando, true)
	await wait_physics_frames(2)
	for i in 40:
		arma._process(0.05)

	var dedos: Vector3 = arma._centro_del_puno(esq, arma.hueso_de_tirar)
	var punta: Vector3 = arma._arco.global_transform * arma._tirado
	assert_lt(punta.distance_to(dedos), 0.05,
		"la cuerda acaba en los dedos (%.3f m)" % punta.distance_to(dedos))

	# Y NO en la muñeca: si estuvieran en el mismo sitio, esto no probaría nada.
	var i := esq.find_bone(arma.hueso_de_tirar)
	var muneca: Vector3 = (esq.global_transform * esq.get_bone_global_pose(i)).origin
	assert_gt(muneca.distance_to(dedos), 0.05,
		"los dedos están lejos de la muñeca, que es de lo que se trata")


## El arco va LADEADO al apuntar, no perfectamente vertical.
##
## Idea de Kevin: con el arco a plomo la cuerda le pasa pegada a la cara y hay
## que andar apartándola a mano. Ladeándolo, el plano del arco se abre y la
## cuerda encuentra sitio sola. Es lo que hace un arquero de verdad.
func test_el_arco_va_ladeado_al_apuntar() -> void:
	var b := await _benjamin()
	var arma: Node = b.get_node_or_null("Arma")
	var esq: Skeleton3D = _buscar(b.get_node("Visual/Animador"), "Skeleton3D")
	var ap: AnimationPlayer = _buscar(b.get_node("Visual/Animador"), "AnimationPlayer")
	var arco: Node3D = esq.get_node_or_null("Enganche_arco/arco") if esq != null else null
	if arma == null or arco == null or ap == null:
		return
	arco.quaternion = arma._agarre_apuntando
	ap.play(arma.clip_apuntando)
	ap.seek(arma.momento_apuntando, true)
	await get_tree().process_frame
	var eje: Vector3 = arco.global_transform.basis.z.normalized()
	var vertical: float = absf(eje.y)
	assert_lt(vertical, 0.99, "no va a plomo: va ladeado")
	assert_gt(vertical, 0.75, "…pero sigue siendo un arco de pie, no tumbado")

	# Y hacia el lado BUENO. El signo importa: ladeado al revés la cuerda se le
	# va contra la cara en vez de abrirle sitio, y la primera vez lo puse así.
	var derecha: Vector3 = (b.get_node("Visual") as Node3D).global_transform.basis.x
	var lado: float = eje.dot(derecha.normalized())
	assert_gt(lado, 0.1, "la punta de arriba cae hacia su derecha (%.2f)" % lado)


## La cuerda pasa POR FUERA de la cabeza.
##
## La mano de tirar acaba junto a la mejilla, así que una cuerda tirada recta
## hasta ella le atravesaba el cráneo.
func test_la_cuerda_no_le_atraviesa_la_cabeza() -> void:
	var b := await _benjamin()
	var arma: Node = b.get_node_or_null("Arma")
	var esq: Skeleton3D = _buscar(b.get_node("Visual/Animador"), "Skeleton3D")
	var ap: AnimationPlayer = _buscar(b.get_node("Visual/Animador"), "AnimationPlayer")
	if arma == null or esq == null or ap == null or arma._arco == null:
		return
	var cabeza := esq.find_bone(arma.hueso_cabeza)
	assert_gt(cabeza, -1, "encuentra el hueso de la cabeza")
	if cabeza < 0:
		return

	b._charging = true
	ap.play(arma.clip_apuntando)
	ap.seek(arma.momento_apuntando, true)
	await wait_physics_frames(2)
	for i in 40:
		arma._process(0.05)

	var craneo: Vector3 = (esq.global_transform * esq.get_bone_global_pose(cabeza)).origin
	var t: Transform3D = arma._arco.global_transform
	for punta in [arma._punta_alta, arma._punta_baja]:
		var d: float = _a_segmento(craneo, t * punta, t * arma._tirado)
		assert_gt(d, 0.09,
			"la cuerda pasa a un lado de la cabeza, no por dentro (%.3f m)" % d)


## Distancia de un punto al segmento a-b.
func _a_segmento(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab: Vector3 = b - a
	var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## La flecha que sale disparada es la del carcaj, no una caja.
##
## La punta del modelo mira a +Z y una flecha viaja hacia el -Z de su nodo —es
## lo que deja `look_at_from_position`—, así que va montada del revés. Si
## alguien quita ese giro, las flechas vuelan de culo.
func test_la_flecha_vuela_de_punta() -> void:
	var f := Area3D.new()
	f.set_script(FLECHA)
	add_child_autofree(f)
	await wait_physics_frames(2)
	f.setup(Vector3(0, 0, -1), 10.0, 5.0, false)
	await wait_physics_frames(1)

	var mi: MeshInstance3D = _buscar(f, "MeshInstance3D")
	assert_not_null(mi, "la flecha lleva malla")
	if mi == null or mi.mesh == null:
		return
	assert_true(mi.mesh is ArrayMesh, "y es el modelo del artista, no una caja")

	# La punta del modelo está en su +Z: girada media vuelta, apunta al -Z del
	# nodo, que es hacia donde vuela.
	var caja: AABB = mi.mesh.get_aabb()
	var punta_local := Vector3(0, 0, caja.position.z + caja.size.z)
	var punta: Vector3 = mi.transform * punta_local
	assert_lt(punta.z, 0.0, "la punta mira hacia donde viaja")
