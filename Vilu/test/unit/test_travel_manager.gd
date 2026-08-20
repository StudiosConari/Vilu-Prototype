extends "res://addons/gut/test.gd"

## Máquina de estados de viaje: validación y carga de regiones en un holder.

func test_valid_regions() -> void:
	assert_true(TravelManager.is_valid_region("Region1_Tarapaca"))
	assert_true(TravelManager.is_valid_region("Region2_Yastay"))
	assert_false(TravelManager.is_valid_region("NoExiste"))

func test_load_region_into_holder() -> void:
	var holder := Node3D.new()
	add_child_autofree(holder)
	watch_signals(TravelManager)
	var region := TravelManager.load_region(holder, "Region1_Tarapaca")
	assert_not_null(region)
	assert_eq(TravelManager.current_region, "Region1_Tarapaca")
	assert_eq(holder.get_child_count(), 1)
	assert_signal_emitted(TravelManager, "region_changed")

func test_load_invalid_region_returns_null() -> void:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var region := TravelManager.load_region(holder, "NoExiste")
	assert_null(region)
