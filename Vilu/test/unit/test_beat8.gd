extends "res://addons/gut/test.gd"

## Beat 8 — la escena Final está registrada y carga con su spawn.

func test_final_registered_and_loads() -> void:
	assert_true(TravelManager.is_valid_region("Final"))
	var holder := Node3D.new()
	add_child_autofree(holder)
	var region := TravelManager.load_region(holder, "Final")
	assert_not_null(region)
	assert_not_null(region.get_node_or_null("PlayerSpawn"), "Final tiene PlayerSpawn")


const WORLD_ROOT := preload("res://scenes/core/WorldRoot.gd")


## Todos los destinos de los beats siguen existiendo, cada uno en SU registro.
##
## Hay dos, y confundirlos es el error fácil: los interiores y los puzzles son
## escenas que TravelManager carga aparte, mientras que las zonas del mundo
## abierto están construidas dentro de World.tscn y sólo figuran en la tabla
## ZONAS de WorldRoot. Preguntarle a TravelManager por una zona del mundo da
## false, y eso es correcto.
func test_all_beat_zones_registered() -> void:
	for zone in ["Mina", "Isluga", "Cumbre", "Final"]:
		assert_true(TravelManager.is_valid_region(zone),
			"escena registrada en TravelManager: %s" % zone)

	var ids := []
	for z in WORLD_ROOT.ZONAS:
		ids.append(z["id"])
	for zone in ["Tarapaca", "Poblado", "Alicanto", "Yastay"]:
		assert_true(zone in ids, "zona registrada en WorldRoot.ZONAS: %s" % zone)
