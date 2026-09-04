extends "res://addons/gut/test.gd"

## "Nueva partida" tiene que empezar de cero DE VERDAD.
##
## Había dos cosas que sobrevivían: la zona de arranque del selector de zonas y
## la cadena de misiones. Las dos viven en autoloads, que no se recrean al
## cambiar de escena, así que después de usar "Seleccionar zona" una vez el
## "Nueva partida" de después te devolvía a esa zona y con la misión a medias.
## Parecía que el botón no hacía nada.


func after_all() -> void:
	GameManager.reset_progress()


func test_olvida_la_zona_del_selector() -> void:
	GameManager.debug_start_zone = "Yastay"
	GameManager.debug_start_world = "res://scenes/core/WorldAtacama.tscn"
	GameManager.reset_progress()
	assert_eq(GameManager.debug_start_zone, "", "no arranca en la zona de antes")
	assert_eq(GameManager.debug_start_world, "", "ni en el mundo de antes")


func test_la_cadena_de_misiones_vuelve_al_principio() -> void:
	GameManager.reset_progress()
	Misiones.hecho("carmen")
	await wait_seconds(Misiones.ESPERA + 0.2)
	Misiones.hecho("pistas", 2)
	assert_eq(String(Misiones.actual()["id"]), "pistas", "va por la segunda")

	GameManager.reset_progress()
	assert_eq(String(Misiones.actual()["id"]), "carmen", "vuelve a la primera")
	assert_eq(Misiones.hechos(), 0, "y con el contador a cero")


## El selector sigue funcionando: pone la zona DESPUÉS de resetear, así que
## limpiarla dentro del reset no le estorba.
func test_el_selector_de_zonas_sigue_pudiendo_elegir() -> void:
	GameManager.reset_progress()
	GameManager.debug_start_zone = "Mina"
	assert_eq(GameManager.debug_start_zone, "Mina")
