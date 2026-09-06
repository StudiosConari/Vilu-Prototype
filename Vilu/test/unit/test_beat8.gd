extends "res://addons/gut/test.gd"

## El cierre del prototipo.
##
## Antes había una escena "Final" aparte, con su propio cartel de FIN, a la que
## se llegaba siguiendo a la ocultista. Eran dos finales compitiendo: vencer al
## Chupacabras concede el noveno logro y con eso salta la pantalla de logros,
## que es el final de verdad. La escena y su parada del menú se fueron.

const WORLD_ROOT := preload("res://scenes/core/WorldRoot.gd")
const TITULO := preload("res://scenes/TitleScreen.gd")


func test_la_escena_final_ya_no_existe() -> void:
	assert_false(TravelManager.is_valid_region("Final"),
		"no queda registrada como región")
	assert_false(ResourceLoader.exists("res://scenes/puzzles/Final.tscn"),
		"ni el archivo")


func test_el_menu_no_ofrece_esa_parada() -> void:
	for z in TITULO.DEBUG_ZONES:
		assert_ne(String(z["zona"]), "Final",
			"ninguna parada lleva a una escena que ya no está")


func test_la_ultima_parada_es_el_chupacabras() -> void:
	var ultima: Dictionary = TITULO.DEBUG_ZONES[TITULO.DEBUG_ZONES.size() - 1]
	assert_eq(String(ultima["otorga"]), "chupacabras",
		"el prototipo se cierra venciéndolo")


func test_vencerlo_dispara_el_cierre() -> void:
	# El noveno logro es el suyo, y al caer se emite `prototipo_superado`, que es
	# lo que Game escucha para levantar la pantalla de logros.
	GameManager.reset_progress()
	for l in GameManager.LOGROS:
		if String(l["id"]) != "chupacabras":
			GameManager.conceder(str(l["id"]))
	watch_signals(GameManager)
	GameManager.conceder("chupacabras")
	assert_signal_emitted(GameManager, "prototipo_superado",
		"vencerlo cierra el prototipo")
	GameManager.reset_progress()


## Todos los destinos de los beats siguen existiendo, cada uno en SU registro.
##
## Hay dos, y confundirlos es el error fácil: los interiores y los puzzles son
## escenas que TravelManager carga aparte, mientras que las zonas del mundo
## abierto están construidas dentro de World.tscn y sólo figuran en la tabla
## ZONAS de WorldRoot. Preguntarle a TravelManager por una zona del mundo da
## false, y eso es correcto.
func test_all_beat_zones_registered() -> void:
	for zone in ["Mina", "Isluga", "OjosDelSalado"]:
		assert_true(TravelManager.is_valid_region(zone),
			"escena registrada en TravelManager: %s" % zone)

	var ids := []
	for z in WORLD_ROOT.ZONAS:
		ids.append(z["id"])
	for zone in ["Tarapaca", "Poblado", "Alicanto", "Yastay"]:
		assert_true(zone in ids, "zona registrada en WorldRoot.ZONAS: %s" % zone)
