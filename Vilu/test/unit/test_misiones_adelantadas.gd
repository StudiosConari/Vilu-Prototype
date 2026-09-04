extends GutTest

## Avisos que llegan ANTES de que su misión esté activa.
##
## El fallo real: los cuerpos de los cazadores se pueden revisar mientras la
## misión que corre todavía es la de los guanacos. Esos avisos se tiraban, así
## que al llegarle el turno a "cazadores" ya sólo quedaban tres cuerpos por
## revisar y el recuadro se quedaba en 3/4 sin forma de avanzar.

const CAZADORES := "cazadores"
const GUANACOS := "guanacos"


func _ir_a(id: String) -> void:
	# Se planta la cadena en la misión pedida sin depender de logros.
	var i := 0
	for m in Misiones.CADENA:
		if String(m["id"]) == id:
			break
		i += 1
	Misiones.set("_indice", i)
	Misiones.set("_hechos", 0)
	Misiones.set("_celebrando", false)
	Misiones.get("_pendientes").clear()
	Misiones.get("_adelantados").clear()


func before_each() -> void:
	_ir_a(GUANACOS)


func after_all() -> void:
	Misiones.sincronizar_con_los_logros()


func test_un_aviso_adelantado_no_se_pierde() -> void:
	Misiones.hecho(CAZADORES)
	assert_eq(Misiones.hechos(), 0, "no toca todavía: no cuenta ahora")
	assert_eq(int(Misiones.get("_adelantados").get(CAZADORES, 0)), 1,
		"pero queda anotado para cuando le toque")


func test_los_avisos_de_misiones_ya_pasadas_se_ignoran() -> void:
	Misiones.hecho("carmen")
	assert_false(Misiones.get("_adelantados").has("carmen"),
		"lo de atrás no se guarda: ya está hecho")


func test_contar_dice_cuantos_van_en_total() -> void:
	Misiones.contar(GUANACOS, 3)
	assert_eq(Misiones.hechos(), 3)
	# Repetir el mismo total no suma de nuevo.
	Misiones.contar(GUANACOS, 3)
	assert_eq(Misiones.hechos(), 3, "es un total, no un incremento")


func test_contar_no_retrocede() -> void:
	Misiones.contar(GUANACOS, 3)
	Misiones.contar(GUANACOS, 1)
	assert_eq(Misiones.hechos(), 3)


func test_lo_adelantado_aparece_al_activarse_la_mision() -> void:
	# Se revisa un cuerpo mientras todavía corren los guanacos…
	Misiones.contar(CAZADORES, 1)
	# …y se cierran los cuatro guanacos.
	Misiones.contar(GUANACOS, 4)
	await wait_seconds(Misiones.ESPERA + 0.4)
	assert_eq(String(Misiones.actual()["id"]), CAZADORES, "pasó a los cazadores")
	assert_eq(Misiones.hechos(), 1, "el cuerpo revisado antes de tiempo sí cuenta")


func test_revisarlos_todos_antes_de_tiempo_cierra_la_mision() -> void:
	Misiones.contar(CAZADORES, 4)
	Misiones.contar(GUANACOS, 4)
	await wait_seconds(Misiones.ESPERA + 0.4)
	# Entra ya completa: se celebra y pasa a la siguiente.
	await wait_seconds(Misiones.ESPERA + 0.4)
	assert_eq(String(Misiones.actual()["id"]), "talisman_2",
		"no se queda colgada en 4/4")
