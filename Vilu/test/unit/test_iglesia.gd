extends "res://addons/gut/test.gd"

## Interior del Santuario de La Tirana.
##
## La traza puede seguir cambiando, así que lo que se comprueba acá son
## invariantes que sobreviven al rediseño: que esté registrada, que las dos
## puertas estén despejadas, que el pasillo central se pueda recorrer, que haya
## suelo bajo el punto de aparición, que ese punto no caiga dentro del trigger
## de salida (si cayera, entrar te escupiría afuera de inmediato) y que no haya
## cajas solapadas produciendo z-fighting.
##
## Las posiciones se derivan de las constantes del script, no van a mano: así
## cambiar el largo de la nave no rompe el test.
##
## La escena se monta en CADA test y no en before_all(): add_child_autofree()
## libera después de cada uno, así que una caché compartida queda con nodos
## muertos y todo revienta con "previously freed".

const IGLESIA := preload("res://scenes/regions/Iglesia.tscn")
const SCR := preload("res://scenes/actors/IglesiaInterior.gd")


func _montar() -> Node3D:
	var g := IGLESIA.instantiate()
	add_child_autofree(g)
	await wait_physics_frames(4)
	return g


func _cajas(g: Node3D) -> Array:
	var out: Array = []
	for c in g.get_children():
		if c is CSGBox3D:
			out.append(c)
	return out


## Los faldones de la bóveda están rotados; su caja real es la caja girada.
func _caja_de(b: CSGBox3D) -> AABB:
	return b.transform * AABB(-b.size * 0.5, b.size)


func _ocupado(cajas: Array, p: Vector3) -> bool:
	for b in cajas:
		if _caja_de(b).has_point(p):
			return true
	return false


func test_registrada_en_travelmanager() -> void:
	assert_true(TravelManager.is_valid_region("Iglesia"),
		"la Iglesia tiene que estar en REGIONS o la puerta no carga nada")


func test_se_construyo() -> void:
	var g := await _montar()
	var cajas := _cajas(g)
	gut.p("  cajas construidas: %d" % cajas.size())
	assert_gt(cajas.size(), 40, "el interior se construyó")


## Solape entre cajas SIN ROTAR, que es donde puede haber z-fighting.
##
## Se saltan las rotadas a propósito. Los dos faldones del gablete se cruzan en
## la cumbrera, que es exactamente como se arma un gablete, y sus caras se
## encuentran a casi 50 grados: no son coplanares y no parpadean. Medirlas con
## cajas envolventes alineadas a los ejes da un solape enorme que es puro
## artefacto de la medición, no un defecto de la geometría.
func test_sin_solapes() -> void:
	var g := await _montar()
	var rectas: Array = []
	for b in _cajas(g):
		if is_zero_approx((b as CSGBox3D).rotation.length()):
			rectas.append(b)
	gut.p("  cajas sin rotar revisadas: %d" % rectas.size())

	var malos := 0
	for i in rectas.size():
		for j in range(i + 1, rectas.size()):
			var a: CSGBox3D = rectas[i]
			var b: CSGBox3D = rectas[j]
			var ca := AABB(a.position - a.size * 0.5, a.size)
			var cb := AABB(b.position - b.size * 0.5, b.size)
			var inter: AABB = ca.intersection(cb)
			var vol: float = inter.size.x * inter.size.y * inter.size.z
			if vol <= 0.01:
				continue
			if not _parpadea(ca, cb):
				continue
			malos += 1
			gut.p("  caras coplanares con %.1f m3 de solape: %s tam %s  x  %s tam %s"
				% [vol, str(a.position), str(a.size), str(b.position), str(b.size)])
	assert_eq(malos, 0, "z-fighting entre cajas")


## ¿Estas dos cajas van a parpadear?
##
## Hacen falta DOS condiciones, y hay que exigir las dos o el test se llena de
## falsos positivos:
##
##   1. Comparten el plano de alguna cara. Es lo que produce el parpadeo: dos
##      superficies a la misma profundidad, donde la precisión del buffer no
##      alcanza para decidir cuál va delante. Dos cajas que sólo se atraviesan
##      en ángulo recto —un pilar subiendo a través de una losa— no comparten
##      ningún plano y se ven perfectas.
##
##   2. Sobre ese plano, ninguna tapa por completo a la otra. Si una es más
##      grande y se traga la cara de la otra, esa cara no se ve y no puede
##      parpadear. Es el caso del fuste de un pilar con su basa y su capitel:
##      comparten el plano de apoyo, pero la basa es más ancha.
func _parpadea(a: AABB, b: AABB) -> bool:
	const EPS := 0.005
	var fin_a := a.position + a.size
	var fin_b := b.position + b.size

	for eje in 3:
		var comparten: bool = absf(a.position[eje] - b.position[eje]) < EPS \
			or absf(fin_a[eje] - fin_b[eje]) < EPS
		if not comparten:
			continue
		# Contención mirada SOBRE ese plano, o sea en los otros dos ejes.
		var a_en_b := true
		var b_en_a := true
		for otro in 3:
			if otro == eje:
				continue
			if a.position[otro] < b.position[otro] - EPS or fin_a[otro] > fin_b[otro] + EPS:
				a_en_b = false
			if b.position[otro] < a.position[otro] - EPS or fin_b[otro] > fin_a[otro] + EPS:
				b_en_a = false
		if not (a_en_b or b_en_a):
			return true
	return false


func test_las_dos_puertas_estan_abiertas() -> void:
	var g := await _montar()
	var cajas := _cajas(g)
	var z_fachada: float = SCR.MEDIO_LARGO + SCR.ESPESOR * 0.5
	var z_tabique: float = SCR.MEDIO_LARGO - SCR.FONDO_NARTEX
	assert_false(_ocupado(cajas, Vector3(0.0, 2.0, z_fachada)),
		"el hueco de la fachada está despejado")
	assert_false(_ocupado(cajas, Vector3(0.0, 2.0, z_tabique)),
		"el hueco del tabique del nártex está despejado")


func test_el_pasillo_central_esta_libre() -> void:
	var g := await _montar()
	var cajas := _cajas(g)
	var z: float = SCR.MEDIO_LARGO - SCR.FONDO_NARTEX - 1.0
	var tope: float = -SCR.MEDIO_LARGO + SCR.FONDO_PRESBITERIO
	var bloqueos := 0
	while z > tope:
		if _ocupado(cajas, Vector3(0.0, 1.0, z)):
			bloqueos += 1
			gut.p("  pasillo bloqueado en z=%.1f" % z)
		z -= 1.0
	assert_eq(bloqueos, 0, "el pasillo central se puede recorrer")


func test_aparecer_es_seguro() -> void:
	var g := await _montar()
	var cajas := _cajas(g)
	var spawn: Marker3D = g.get_node("PlayerSpawn")
	var salida: Area3D = g.get_node("SalidaALaTirana")
	var forma: BoxShape3D = (salida.get_child(0) as CollisionShape3D).shape
	var caja_salida := AABB(salida.position - forma.size * 0.5, forma.size)

	assert_false(caja_salida.has_point(spawn.position),
		"aparecés FUERA del trigger de salida")
	assert_true(_ocupado(cajas, Vector3(spawn.position.x, -0.4, spawn.position.z)),
		"hay suelo bajo el punto de aparición")


func test_las_estrellas_estan() -> void:
	var g := await _montar()
	var total := 0
	for c in g.get_children():
		if c is MultiMeshInstance3D:
			total += (c as MultiMeshInstance3D).multimesh.instance_count
	gut.p("  estrellas en la bóveda: %d" % total)
	assert_gt(total, 200, "la bóveda estrellada es la firma del lugar")


# ── La puerta desde La Tirana ────────────────────────────────────────────────

const TARAPACA := preload("res://scenes/regions/Region1_Tarapaca.tscn")


func _tarapaca() -> Node3D:
	var r := TARAPACA.instantiate()
	add_child_autofree(r)
	await wait_physics_frames(8)
	return r


func test_la_puerta_de_la_tirana_lleva_aca() -> void:
	var r := await _tarapaca()
	var puerta: Area3D = r.get_node_or_null("Iglesia/PuertaIglesia")
	assert_not_null(puerta, "hay una puerta en la iglesia de La Tirana")
	assert_eq(puerta.target_region, "Iglesia", "apunta al interior")
	assert_true(TravelManager.is_valid_region(puerta.target_region),
		"el destino está registrado en TravelManager")

	# El ZoneExit trae una caja de 24 m de ancho, pensada para cruzar el borde
	# de una zona. Como puerta de un edificio de 9 m eso dispararía desde media
	# plaza, así que esta instancia lleva su propia forma.
	var forma: BoxShape3D = (puerta.get_child(0) as CollisionShape3D).shape
	gut.p("  trigger de la puerta: %s" % str(forma.size))
	assert_lt(forma.size.x, 10.0, "el trigger es una puerta, no un muro")


## La iglesia tiene que dejar libre el punto de aparición de la zona.
##
## DÓNDE se coloca es decisión de arte y se mueve a mano, así que el test no
## opina de eso. Lo que sí no puede pasar es que tape el sitio donde aparece la
## party, ni que su colisión sea convexa: la envolvente convexa de una iglesia
## le sella la puerta y no se podría entrar nunca.
func test_la_iglesia_deja_libre_el_spawn() -> void:
	var r := await _tarapaca()
	var cuerpo: Node3D = r.get_node_or_null("Iglesia/Cuerpo")
	assert_not_null(cuerpo, "el contenedor con colisión existe")

	var caja := AABB()
	var primero := true
	var caras := 0
	for m in _mallas_de(cuerpo):
		var a: AABB = m.global_transform * m.mesh.get_aabb()
		if primero:
			caja = a
			primero = false
		else:
			caja = caja.merge(a)
		var col = m.get_node_or_null("Colision")
		if col != null:
			var s = (col.get_child(0) as CollisionShape3D).shape
			if s is ConcavePolygonShape3D:
				caras += (s as ConcavePolygonShape3D).get_faces().size() / 3

	var spawn: Marker3D = r.get_node("PlayerSpawn")
	gut.p("  la iglesia ocupa z %.1f a %.1f;  el spawn está en z %.1f"
		% [caja.position.z, caja.end.z, spawn.position.z])
	# Margen de 3 m: la party aparece con dos compañeros a los costados.
	assert_false(caja.grow(3.0).has_point(spawn.global_position),
		"la iglesia no puede tapar el punto de aparición")

	gut.p("  caras de colisión exacta: %d" % caras)
	assert_gt(caras, 0, "la iglesia tiene colisión de malla exacta")


func _mallas_de(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for c in n.get_children():
		out.append_array(_mallas_de(c))
	return out
