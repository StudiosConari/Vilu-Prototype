extends "res://addons/gut/test.gd"

## Beat 8 — la escena Final está registrada y carga con su spawn.

func test_final_registered_and_loads() -> void:
	assert_true(TravelManager.is_valid_region("Final"))
	var holder := Node3D.new()
	add_child_autofree(holder)
	var region := TravelManager.load_region(holder, "Final")
	assert_not_null(region)
	assert_not_null(region.get_node_or_null("PlayerSpawn"), "Final tiene PlayerSpawn")


func test_all_beat_zones_registered() -> void:
	for zone in ["Region1_Tarapaca", "Mina", "Poblado", "Isluga", "Region2_Alicanto",
			"Region2_Yastay", "Region2_Volcan", "Cumbre", "Final"]:
		assert_true(TravelManager.is_valid_region(zone), "zona registrada: %s" % zone)
