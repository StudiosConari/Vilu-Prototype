extends GutTest

## Los carteles dicen el botón del mando cuando se juega con mando.
##
## EL PROBLEMA. Los textos llevan la tecla escrita —"[E] Hablar", "[G] embestir ·
## [Q] montar"— y son cincuenta y tantos por todo el proyecto. Con mando no
## sirven: mandan pulsar una tecla que no tenés delante.
##
## Se traducen AL SALIR, en el HUD y en los carteles del mundo, así que los
## textos siguen escritos con teclas —como el resto del código— y hay un solo
## sitio que arreglar en vez de cincuenta y cinco.


func before_each() -> void:
	Botones._con_mando = false


func after_each() -> void:
	# Que un test no le deje el mando puesto al siguiente.
	Botones._con_mando = false


func _con_mando() -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_A
	Botones._input(e)


func _con_teclado() -> void:
	var e := InputEventKey.new()
	e.physical_keycode = KEY_W
	Botones._input(e)


func test_con_teclado_el_cartel_no_se_toca() -> void:
	_con_teclado()
	assert_eq(Botones.traducir("[E] Hablar"), "[E] Hablar",
		"quien juega con teclado ve teclas")


func test_con_mando_la_tecla_pasa_a_boton() -> void:
	_con_mando()
	# La E es de `interact`, e `interact` está en la X del mando.
	assert_eq(Botones.traducir("[E] Hablar"), "[X] Hablar")


func test_traduce_todas_las_del_cartel() -> void:
	# El del guanaco lleva dos.
	_con_mando()
	var r := Botones.traducir("Guanaco\n[G] embestir · [Q] montar")
	assert_eq(r, "Guanaco\n[LB] embestir · [Y] montar")


func test_el_texto_de_alrededor_se_respeta() -> void:
	_con_mando()
	assert_eq(Botones.traducir("Pulsá [E] para hablar con Carmen"),
		"Pulsá [X] para hablar con Carmen")


func test_los_nombres_en_espanol_tambien() -> void:
	# Los carteles están en español y Godot llama "Space" a la barra.
	_con_mando()
	assert_eq(Botones.traducir("[Espacio] saltar"), "[A] saltar")
	assert_eq(Botones.traducir("[ESC] pausa"), "[Start] pausa")


func test_lo_que_no_se_sabe_se_deja_como_esta() -> void:
	# Un cartel con la tecla es menos malo que un cartel vacío o roto.
	_con_mando()
	assert_eq(Botones.traducir("[Ñ] hacer algo"), "[Ñ] hacer algo")


func test_un_texto_sin_corchetes_no_se_toca() -> void:
	_con_mando()
	assert_eq(Botones.traducir("Fragmento de talismán encontrado"),
		"Fragmento de talismán encontrado")


func test_un_corchete_sin_cerrar_no_rompe_nada() -> void:
	_con_mando()
	assert_eq(Botones.traducir("algo [E sin cerrar"), "algo [E sin cerrar")


func test_el_ultimo_que_se_toco_es_el_que_manda() -> void:
	# Se puede tener las dos cosas enchufadas: manda la que se acaba de usar.
	_con_mando()
	assert_true(Botones.usando_mando(), "tocó el mando")
	_con_teclado()
	assert_false(Botones.usando_mando(), "y ahora el teclado")


func test_mover_el_raton_cuenta_como_teclado() -> void:
	# Sin esto, soltar el mando y agarrar el ratón dejaba los carteles en
	# botones hasta que hicieras clic en algo.
	_con_mando()
	Botones._input(InputEventMouseMotion.new())
	assert_false(Botones.usando_mando(), "mover el ratón ya cuenta")


func test_la_tabla_sale_del_mapa_de_entrada() -> void:
	# EL PUNTO. No hay ninguna correspondencia escrita a mano que se pueda
	# quedar vieja: se cambia el control y el cartel cambia con él.
	_con_mando()
	assert_eq(Botones.boton_de("T"), "Cruceta →", "la T es swap_hold")
	assert_eq(Botones.boton_de("R"), "Cruceta ←", "y la R es swap_ai")
