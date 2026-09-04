extends "res://addons/gut/test.gd"

## El viaje en bus cumple la misión "Viaja a Atacama".
##
## El bus cambia el MUNDO entero, no una región: no pasa por TravelManager y su
## señal `region_changed` nunca se emite, así que la cadena de misiones no se
## enteraba. Aquí se comprueba el dato del que depende el arreglo —que la escena
## de Atacama se llame así— y que el aviso cumple la misión.

func before_each() -> void:
	GameManager.reset_progress()


func after_all() -> void:
	GameManager.reset_progress()


func test_la_escena_de_atacama_se_reconoce_por_su_nombre() -> void:
	var mundo: PackedScene = load("res://scenes/core/WorldAtacama.tscn")
	assert_not_null(mundo)
	if mundo == null:
		return
	assert_true(mundo.resource_path.contains("Atacama"),
		"el viaje en bus reconoce el destino por el nombre de la escena")


func test_avisar_del_viaje_cumple_la_mision() -> void:
	# Se salta hasta "Viaja a Atacama".
	while not Misiones.terminada() and String(Misiones.actual()["id"]) != "viajar":
		var m: Dictionary = Misiones.actual()
		Misiones.hecho(String(m["id"]), int(m["total"]))
		await wait_seconds(Misiones.ESPERA + 0.15)
	assert_eq(String(Misiones.actual()["texto"]), "Viaja a Atacama")

	Misiones.hecho("viajar")
	assert_eq(Misiones.hechos(), 1, "el aviso del bus la cumple")
