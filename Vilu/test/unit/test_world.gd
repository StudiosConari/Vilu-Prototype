extends "res://addons/gut/test.gd"

## Mundo abierto: party persistente, layout de zonas y viaje.
## (Antes era test_ascenso_spawn.gd, nombrado por una escena que ya no existe.)

const GAME := preload("res://scenes/core/Game.tscn")

## Los errores del motor no cuentan como fallo EN ESTE ARCHIVO.
##
## Cargar Game.tscn levanta el mundo entero, y con él el nodo Terrain3D, que al
## crear sus instancias llama a `instance_reset_physics_interpolation()`. Godot
## 4.7 la marcó obsoleta y avisa por consola. GUT toma cualquier error del motor
## como fallo, así que ese aviso tumbaba `test_spawns_two_distinct_characters`
## aunque todos sus asserts pasaran.
##
## No se puede arreglar en el proyecto: Terrain3D es una GDExtension y la llamada
## está en su binario. Se apaga sólo acá, y sólo el CONTEO: los errores se siguen
## imprimiendo en la salida, así que si aparece uno nuevo se ve igual.
var _errores_antes = null


func before_all() -> void:
	_errores_antes = gut.error_tracker.treat_engine_errors_as
	gut.error_tracker.treat_engine_errors_as = GutUtils.TREAT_AS.NOTHING


func after_all() -> void:
	if _errores_antes != null:
		gut.error_tracker.treat_engine_errors_as = _errores_antes
	GameManager.reset_progress()


func _nuevo_juego() -> Node:
	GameManager.reset_progress()
	var game := GAME.instantiate()
	add_child_autofree(game)
	await get_tree().process_frame
	await get_tree().process_frame
	return game


# ─── Party ───────────────────────────────────────────────────────────────────

func test_spawns_two_distinct_characters() -> void:
	var game := await _nuevo_juego()

	assert_eq(game.party.size(), 2, "arranca con 2 personajes")
	assert_false(game.party[0].is_archer, "el 1º es melee")
	assert_true(game.party[1].is_archer, "el 2º es arquero")

	assert_true(game.party[0].active, "el melee arranca activo")
	assert_false(game.party[1].active, "el arquero arranca inactivo")

	game.swap_character()
	assert_false(game.party[0].active, "tras R, el melee deja de ser activo")
	assert_true(game.party[1].active, "tras R, el arquero pasa a activo")
	assert_eq(game.active_index, 1)


func test_fall_returns_to_safe_point() -> void:
	var game := await _nuevo_juego()
	game.party[0].global_position = Vector3(0, -50, 0)   # cae al vacío
	game._check_fall()
	assert_gt(game.party[0].global_position.y, game.fall_limit,
		"tras caer vuelve arriba del límite")


# ─── Mundo abierto ──────────────────────────────────────────────────────────

func test_world_loads_every_outdoor_zone() -> void:
	var game := await _nuevo_juego()
	assert_not_null(game.world, "Game monta el mundo abierto")
	for z in game.world.ZONAS:
		assert_true(game.world.has_zone(z["id"]), "zona instanciada: %s" % z["id"])


## Cada zona tiene que caer en su propio lugar del mapa: si dos se superponen,
## el jugador vería una encima de la otra.
func test_zones_do_not_overlap() -> void:
	var game := await _nuevo_juego()
	var zonas: Array = game.world.ZONAS
	for i in zonas.size():
		for j in range(i + 1, zonas.size()):
			var a: Dictionary = zonas[i]
			var b: Dictionary = zonas[j]
			var pa: Vector3 = a["pos"]
			var pb: Vector3 = b["pos"]
			var d := Vector2(pa.x - pb.x, pa.z - pb.z).length()
			var minimo: float = float(a["radio"]) + float(b["radio"])
			assert_gt(d, minimo * 0.75,
				"%s y %s están demasiado cerca (%.0f m)" % [a["id"], b["id"], d])


## El spawn de cada zona tiene que resolver a coordenadas MUNDIALES, no locales.
func test_spawn_points_are_world_coordinates() -> void:
	var game := await _nuevo_juego()
	var sp: Vector3 = game.world.spawn_point("Cumbre")
	var centro: Vector3 = game.world.zone_node("Cumbre").global_position
	assert_ne(sp, Vector3.INF, "Cumbre tiene spawn")
	assert_lt(sp.distance_to(centro), 60.0,
		"el spawn cae dentro de su zona, no en el origen del mundo")
	assert_gt(centro.length(), 50.0, "Cumbre está desplazada del origen")


func test_debug_start_zone() -> void:
	GameManager.reset_progress()
	GameManager.debug_start_zone = "Cumbre"
	var game := GAME.instantiate()
	add_child_autofree(game)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(GameManager.debug_start_zone, "", "se limpia tras usarla")
	var destino: Vector3 = game.world.spawn_point("Cumbre")
	assert_lt(game.party[0].global_position.distance_to(destino), 6.0,
		"arranca junto al spawn mundial de la zona de debug")


## Viajar dentro del mundo es teletransporte, no carga de escena: el party
## sobrevive y aparece en el spawn del destino.
func test_party_persists_through_travel() -> void:
	var game := await _nuevo_juego()
	GameManager.set_beat(4)
	await game.go_to("Poblado")
	await get_tree().process_frame
	assert_eq(game.party.size(), 2, "los 2 personajes persisten al viajar")
	var destino: Vector3 = game.world.spawn_point("Poblado")
	assert_lt(game.party[0].global_position.distance_to(destino), 6.0,
		"el teletransporte deja al party en el spawn del Poblado")


## Los interiores NO son parte del mundo continuo: se cargan aparte.
func test_interiors_are_not_world_zones() -> void:
	var game := await _nuevo_juego()
	for id in game.INTERIORES:
		assert_false(game.world.has_zone(id),
			"%s es interior: no debe estar en el mundo abierto" % id)
		assert_true(TravelManager.is_valid_region(id),
			"%s sigue siendo cargable con TravelManager" % id)


## Ida y vuelta a un interior: entrar apaga el mundo, salir lo devuelve y
## deja al party en la zona pedida. Es el camino que mezcla carga de escena
## con mundo persistente, así que es el más fácil de romper.
func test_interior_round_trip() -> void:
	var game := await _nuevo_juego()

	await game.go_to("Mina")
	await get_tree().process_frame
	assert_eq(TravelManager.current_region, "Mina", "la Mina se carga como interior")
	assert_false(game.world.visible, "el mundo se apaga mientras estás adentro")

	await game.go_to("Poblado")
	await get_tree().process_frame
	assert_true(game.world.visible, "al salir el mundo vuelve")
	assert_eq(TravelManager.current_region, "", "el holder de interiores queda vacío")
	# Se sale por donde se entró: frente a la boca, no en el centro del pueblo.
	var boca: Vector3 = game.world.mine_mouth()
	assert_lt(game.party[0].global_position.distance_to(boca), 6.0,
		"salís de la Mina frente a su boca")
	assert_eq(game.party.size(), 2, "el party sobrevive la ida y vuelta")
