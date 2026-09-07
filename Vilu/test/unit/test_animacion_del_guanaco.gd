extends GutTest

## Que al guanaco le dé tiempo a hacer sus animaciones enteras.
##
## Se veían cortadas por dos motivos distintos, y hacían falta los dos arreglos:
## la velocidad se medía restando posiciones —una cifra que tiembla— y cruzaba
## los umbrales ida y vuelta cada pocos cuadros, reiniciando el ciclo; y la coz
## del salto se relanzaba desde cero en cada brinco encadenado.

const GUANACO := preload("res://scenes/actors/GuanacoCompanion.gd")


func _guanaco() -> Node3D:
	var g := Node3D.new()
	g.set_script(GUANACO)
	add_child_autofree(g)
	g.set("_ready_done", true)
	return g


func test_los_clips_no_se_aceleran_al_doble() -> void:
	# El paso llegaba a 2.4x. Un ciclo de caminar al doble de velocidad no se lee
	# como «va rápido», se lee como una animación apurada.
	assert_lte(GUANACO.RITMO_MAXIMO, 1.5, "el margen de aceleración es estrecho")
	assert_gt(GUANACO.RITMO_MAXIMO, 1.0, "pero acompaña algo a la velocidad")


func test_la_coz_del_salto_no_va_acelerada() -> void:
	assert_lte(GUANACO.RITMO_DEL_SALTO, 1.0, "la coz se ve entera, no apurada")


func test_hay_histeresis_entre_andar_y_correr() -> void:
	# Sin margen, una velocidad que ronda el umbral cambia el clip ida y vuelta
	# y cada cambio reinicia el ciclo desde el principio.
	assert_gt(GUANACO.SALIR_DE_QUIETO, 1.0, "cuesta más arrancar que pararse")
	assert_lt(GUANACO.SALIR_DE_CARRERA, 1.0, "y más pasar a correr que a andar")


func test_la_velocidad_se_suaviza() -> void:
	var g := _guanaco()
	g.set("_vel_suave", 0.0)
	g.call("_suavizar_la_velocidad", 10.0, 1.0 / 60.0)
	var v := float(g.get("_vel_suave"))
	assert_gt(v, 0.0, "se acerca a la medida")
	assert_lt(v, 10.0, "pero no la copia de golpe, que es lo que hacía temblar")


func test_una_velocidad_entre_umbrales_no_cambia_el_clip() -> void:
	# Es el caso que rompía la caminata: entre «ya no está quieto» y «todavía no
	# corre» hay que quedarse con lo que se estuviera haciendo.
	var g := _guanaco()
	var entre := GUANACO.VELOCIDAD_MINIMA * 1.2
	assert_gt(entre, GUANACO.VELOCIDAD_MINIMA, "pasa el umbral de quieto")
	assert_lt(entre, GUANACO.VELOCIDAD_MINIMA * GUANACO.SALIR_DE_QUIETO,
		"pero no el de empezar a andar: se queda como estaba")


func test_saltar_a_media_coz_no_la_reinicia() -> void:
	# Encadenando brincos —lo normal cruzando el cráter— la coz volvía a empezar
	# cada vez y no llegaba a verse nunca entera.
	var g := _guanaco()
	g.set("_salto_restante", 0.5)
	g.call("saltar")
	assert_almost_eq(float(g.get("_salto_restante")), 0.5, 0.001,
		"el salto en curso sigue su camino")
