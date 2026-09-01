extends "res://addons/gut/test.gd"

## Interior del Santuario de La Tirana.
##
## Hasta ahora esto era un greybox de cajas CSG (lo construía IglesiaInterior.gd,
## script ya borrado) y los tests medían esas cajas. Ahora monta un mapa a mano
## (models/edificio/interior_iglesia.glb, 929 piezas), así que lo que se
## comprueba pasó a ser lo que de verdad decide si el interior se puede jugar:
## que el modelo esté, que tenga colisión de malla exacta, que haya suelo bajo
## el punto de aparición, que ahí quepa el jugador, que ese punto no caiga
## dentro del trigger de salida —si cayera, entrar te escupiría afuera— y que
## desde ahí se pueda llegar a la nave.
##
## Se mide con la física real, no con las cajas de la geometría: en un modelo
## hecho a mano lo que importa es por dónde se puede caminar, y eso sólo lo
## sabe el motor.
##
## La escena se monta en CADA test y no en before_all(): add_child_autofree()
## libera después de cada uno, así que una caché compartida queda con nodos
## muertos y todo revienta con "previously freed".

const IGLESIA := preload("res://scenes/regions/Iglesia.tscn")
const WORLD_ROOT := preload("res://scenes/core/WorldRoot.gd")

## Medidas del jugador, para las consultas de forma.
const RADIO := 0.4
const ALTO := 1.8


func _montar() -> Node3D:
	var g := IGLESIA.instantiate()
	add_child_autofree(g)
	await wait_physics_frames(4)
	return g


func _espacio() -> PhysicsDirectSpaceState3D:
	return get_tree().root.world_3d.direct_space_state


## Altura del suelo bajo un punto, o INF si ahí no hay piso.
func _suelo(x: float, z: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 6, z), Vector3(x, -3, z))
	q.collision_mask = 1
	var r := _espacio().intersect_ray(q)
	return INF if r.is_empty() else float(r["position"].y)


## ¿Cabe el jugador parado en (x, z), sobre el suelo que haya ahí?
func _cabe(x: float, z: float) -> bool:
	var y := _suelo(x, z)
	if y == INF:
		return false
	var cap := CapsuleShape3D.new()
	cap.radius = RADIO
	cap.height = ALTO
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = 1
	q.transform = Transform3D(Basis(), Vector3(x, y + ALTO * 0.5 + 0.05, z))
	return _espacio().intersect_shape(q, 1).is_empty()


func _formas_de(n: Node, fuera: Array) -> void:
	if n is CollisionShape3D:
		fuera.append((n as CollisionShape3D).shape)
	for c in n.get_children():
		_formas_de(c, fuera)


func test_registrada_en_travelmanager() -> void:
	assert_true(TravelManager.is_valid_region("Iglesia"),
		"la Iglesia tiene que estar en REGIONS o la puerta no carga nada")


func test_el_modelo_esta_montado() -> void:
	var g := await _montar()
	var mallas := _mallas_de(g)
	gut.p("  piezas del modelo: %d" % mallas.size())
	assert_gt(mallas.size(), 500, "el mapa del interior está en la escena")


## La colisión TIENE que ser de malla exacta.
##
## Es el invariante más importante del interior y el más fácil de romper sin
## darse cuenta: la envolvente convexa de una iglesia la sella entera —la puerta
## incluida— y quedaría un bloque macizo en el que no se puede entrar. Por eso
## el nodo Cuerpo lleva `trimesh_por_defecto`.
func test_la_colision_es_de_malla_exacta() -> void:
	var g := await _montar()
	var formas: Array = []
	_formas_de(g, formas)
	var concavas := 0
	var convexas := 0
	for s in formas:
		if s is ConcavePolygonShape3D:
			concavas += 1
		elif s is ConvexPolygonShape3D:
			convexas += 1
	gut.p("  formas: %d cóncavas, %d convexas" % [concavas, convexas])
	assert_gt(concavas, 500, "cada pieza recibió colisión de malla exacta")
	assert_eq(convexas, 0, "ninguna pieza quedó con envolvente convexa")


func test_aparecer_es_seguro() -> void:
	var g := await _montar()
	var spawn: Marker3D = g.get_node("PlayerSpawn")
	var salida: Area3D = g.get_node("SalidaALaTirana")
	var forma: BoxShape3D = (salida.get_child(0) as CollisionShape3D).shape
	var caja_salida := AABB(salida.position - forma.size * 0.5, forma.size)

	assert_false(caja_salida.has_point(spawn.position),
		"aparecés FUERA del trigger de salida")

	var y := _suelo(spawn.position.x, spawn.position.z)
	gut.p("  suelo bajo el spawn: y=%.2f  (el marcador está en y=%.2f)"
		% [y, spawn.position.y])
	assert_ne(y, INF, "hay suelo bajo el punto de aparición")
	assert_true(_cabe(spawn.position.x, spawn.position.z),
		"el jugador cabe de pie en el punto de aparición")


## Desde el vestíbulo se tiene que poder llegar a la nave.
##
## El eje central está cortado por un escalón de casi un metro, así que el paso
## son las naves LATERALES: basta con que exista alguna columna libre de punta a
## punta. Si un día se cierran las tres, el interior queda en un vestíbulo sin
## salida y este test lo caza.
func test_se_puede_pasar_del_vestibulo_a_la_nave() -> void:
	var g := await _montar()
	var spawn: Marker3D = g.get_node("PlayerSpawn")
	var libres: Array = []
	for x in [-10.0, -8.0, 0.0, 8.0, 10.0]:
		var pasa := true
		var z: float = spawn.position.z - 2.0
		while z > 23.0:
			if not _cabe(x, z):
				pasa = false
				break
			z -= 0.5
		if pasa:
			libres.append(x)
	gut.p("  columnas libres hasta la nave: %s" % str(libres))
	assert_false(libres.is_empty(),
		"hay al menos un camino del vestíbulo a la nave")


## La salida devuelve a La Tirana, que es una ZONA DEL MUNDO y no una región
## cargable: Game la resuelve teletransportando dentro de World, no cargando una
## escena. Preguntarle a TravelManager por ella da false, y así debe ser.
func test_la_salida_lleva_a_la_tirana() -> void:
	var g := await _montar()
	var salida: Area3D = g.get_node("SalidaALaTirana")
	assert_eq(salida.target_region, "Tarapaca", "la puerta devuelve a La Tirana")
	var ids := []
	for z in WORLD_ROOT.ZONAS:
		ids.append(z["id"])
	assert_true("Tarapaca" in ids, "La Tirana está registrada como zona del mundo")

# ── La puerta desde La Tirana ────────────────────────────────────────────────

const WORLD := preload("res://scenes/core/World.tscn")


## La Tirana dejó de ser una escena aparte: está construida DENTRO de World.tscn.
## Para mirar la iglesia de la plaza hay que montar el mundo y pedirle su nodo
## "Tarapaca" — que es el que se ve y se juega, no una copia guardada al lado.
func _tarapaca() -> Node3D:
	# Terrain3D llama al instanciarse a una API que Godot 4.7 marcó obsoleta, y
	# GUT cuenta cualquier error del motor como fallo. Se apaga sólo mientras se
	# monta el mundo y se reenciende enseguida, así los errores que provoque el
	# test en sí se siguen contando.
	var antes = gut.error_tracker.treat_engine_errors_as
	gut.error_tracker.treat_engine_errors_as = GutUtils.TREAT_AS.NOTHING

	# Terrain3D busca la cámara activa del viewport y, si no encuentra ninguna,
	# corta su _physics_process con un push_error. En el juego la cámara la trae
	# Game.tscn; acá, que montamos el mundo suelto, hay que dársela.
	var cam := Camera3D.new()
	add_child_autofree(cam)
	cam.current = true

	var w := WORLD.instantiate()
	add_child_autofree(w)
	await wait_physics_frames(8)
	gut.error_tracker.treat_engine_errors_as = antes
	return w.get_node("Tarapaca")


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
	var iglesia: Node3D = r.get_node_or_null("Iglesia")
	assert_not_null(iglesia, "la iglesia está en la plaza")

	var caja := AABB()
	var primero := true
	for m in _mallas_de(iglesia):
		var a: AABB = m.global_transform * m.mesh.get_aabb()
		if primero:
			caja = a
			primero = false
		else:
			caja = caja.merge(a)
	assert_false(primero, "la iglesia tiene mallas visibles")

	var caras := _caras_exactas(iglesia)

	var spawn: Marker3D = r.get_node("PlayerSpawn")
	gut.p("  la iglesia ocupa z %.1f a %.1f;  el spawn está en z %.1f"
		% [caja.position.z, caja.end.z, spawn.position.z])
	# Margen de 3 m: la party aparece con dos compañeros a los costados.
	assert_false(caja.grow(3.0).has_point(spawn.global_position),
		"la iglesia no puede tapar el punto de aparición")

	gut.p("  caras de colisión exacta: %d" % caras)
	assert_gt(caras, 0, "la iglesia tiene colisión de malla exacta")


## Caras de colisión de malla exacta que cuelgan de un nodo.
##
## La iglesia trae la suya DESDE EL MODELO: el .glb del pipeline exporta un
## `iglesia-colonly`, y Godot lo convierte al importar en un StaticBody3D con
## ConcavePolygonShape3D. Por eso no se busca un hijo llamado "Colision": ésa
## era la forma del greybox hecho a mano, y el edificio de ahora es el modelo.
func _caras_exactas(n: Node) -> int:
	var total := 0
	if n is CollisionShape3D:
		var s = (n as CollisionShape3D).shape
		if s is ConcavePolygonShape3D:
			total += (s as ConcavePolygonShape3D).get_faces().size() / 3
	for c in n.get_children():
		total += _caras_exactas(c)
	return total


func _mallas_de(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for c in n.get_children():
		out.append_array(_mallas_de(c))
	return out
