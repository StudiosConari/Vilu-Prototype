extends "res://addons/gut/test.gd"

## Máquina de estados de viaje: validación y carga de regiones en un holder.
##
## Sólo se registran acá los interiores y las escenas de puzzle. Las zonas del
## mundo abierto viven dentro de World.tscn y no se cargan: ver test_world.

func test_valid_regions() -> void:
	assert_true(TravelManager.is_valid_region("Mina"))
	assert_true(TravelManager.is_valid_region("Iglesia"))
	assert_false(TravelManager.is_valid_region("NoExiste"))

## Las zonas del mundo NO son regiones cargables: si alguna vuelve al registro,
## Game dejaría de teletransportar y cargaría una copia encima del mundo vivo.
func test_world_zones_are_not_loadable_regions() -> void:
	for zona in ["Tarapaca", "Poblado", "Alicanto", "Yastay"]:
		assert_false(TravelManager.is_valid_region(zona),
			"%s vive en World.tscn, no se carga aparte" % zona)

func test_load_region_into_holder() -> void:
	var holder := Node3D.new()
	add_child_autofree(holder)
	watch_signals(TravelManager)
	var region := TravelManager.load_region(holder, "Iglesia")
	assert_not_null(region)
	assert_eq(TravelManager.current_region, "Iglesia")
	assert_eq(holder.get_child_count(), 1)
	assert_signal_emitted(TravelManager, "region_changed")

func test_load_invalid_region_returns_null() -> void:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var region := TravelManager.load_region(holder, "NoExiste")
	assert_null(region)
