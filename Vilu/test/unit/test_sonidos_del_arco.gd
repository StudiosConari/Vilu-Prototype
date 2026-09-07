extends GutTest

## Los dos sonidos del arco: tensar y disparar.
##
## Llegaron como `.m4a`, que Godot no lee —admite wav, ogg y mp3—, así que se
## convirtieron a wav mono de 44,1 kHz. Son cortos, y en wav no hay que
## descomprimir nada al dispararlos.

const SFX := preload("res://scenes/Sfx.gd")
const JUGADOR := preload("res://scenes/actors/PlayerController.gd")


func test_los_dos_archivos_estan_en_el_proyecto() -> void:
	for id: String in SFX.GRABADOS:
		var ruta := String(SFX.GRABADOS[id])
		assert_true(ResourceLoader.exists(ruta), "existe %s" % ruta)
		var s := load(ruta) as AudioStream
		assert_not_null(s, "%s carga como audio" % id)
		assert_gt(s.get_length(), 0.0, "%s tiene duración" % id)


## Sonidos que suenan UNA VEZ y no se encadenan, así que pueden durar.
##
## El grito de Lola es el despertar del jefe de la mina: lo dispara la caída de
## los tablones y la guarda de `dormido` impide que suene dos veces en toda la
## partida. La regla de abajo no le aplica porque no hay con qué solaparlo.
const DE_UNA_SOLA_VEZ := ["grito_lola"]


func test_son_cortos_como_un_efecto() -> void:
	# Los que se disparan seguidos —el arco, los cuatro golpes de la cadena— se
	# solapan consigo mismos si duran de más, y eso deja de sonar a golpes para
	# sonar a una sola papilla.
	for id: String in SFX.GRABADOS:
		if DE_UNA_SOLA_VEZ.has(id):
			continue
		var s := load(String(SFX.GRABADOS[id])) as AudioStream
		assert_lt(s.get_length(), 3.0, "%s dura lo que un efecto" % id)


func test_el_grito_del_jefe_no_se_encadena() -> void:
	# La excepción se gana: Lola despierta una sola vez porque `despertar()` sale
	# por arriba si ya está despierta. Si eso dejara de ser cierto, el grito de
	# 6,6 s se solaparía consigo mismo y habría que recortarlo.
	var l: CharacterBody3D = (load("res://scenes/enemies/Lola.tscn") as PackedScene).instantiate()
	add_child_autofree(l)
	assert_true(l.dormido, "arranca encerrada")
	l.call("despertar")
	assert_false(l.dormido, "el primer aviso la despierta")
	# El segundo tablón vuelve a avisar: no tiene que sonar otra vez.
	l.call("despertar")
	assert_false(l.dormido, "y el segundo aviso no hace nada")


func test_el_banco_los_carga() -> void:
	var s: Node = SFX.new()
	add_child_autofree(s)
	await wait_frames(2)
	var banco: Dictionary = s.get("_sounds")
	for id: String in SFX.GRABADOS:
		assert_true(banco.has(id), "el banco tiene '%s'" % id)
		assert_not_null(banco[id], "y no es nulo")


func test_el_disparo_ya_no_usa_el_tono_generado() -> void:
	# El arco sonaba con "fire", un tono sintético compartido con otras cosas.
	var texto := FileAccess.get_file_as_string("res://scenes/actors/PlayerController.gd")
	assert_false(texto.contains('Sfx.play("fire"'),
		"el arco ya no dispara el tono generado")
	assert_true(texto.contains('Sfx.play("flecha"'), "usa el sonido grabado")
	assert_true(texto.contains('Sfx.play("tensar_arco"'), "y el de tensar")


func test_tensar_suena_solo_con_el_arquero() -> void:
	# Emilia también mantiene el clic para el golpe cargado; ahí no hay arco que
	# tensar.
	var texto := FileAccess.get_file_as_string("res://scenes/actors/PlayerController.gd")
	var i := texto.find('Sfx.play("tensar_arco"')
	assert_gt(i, 0, "está en el código")
	var antes := texto.substr(maxi(0, i - 120), 120)
	assert_true(antes.contains("is_archer"), "va dentro de la rama del arquero")
