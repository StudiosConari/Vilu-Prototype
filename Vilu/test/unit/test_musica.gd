extends GutTest

## La música de fondo.
##
## Era generada por código —cuatro acordes hechos con senos— porque el prototipo
## no tenía ni un archivo de audio. Ahora suena la canción de verdad.

const CANCION := "res://audio/musica/map_of_embers.mp3"


func test_la_cancion_esta_en_el_proyecto() -> void:
	assert_true(ResourceLoader.exists(CANCION), "el archivo está importado")
	var s := load(CANCION)
	assert_true(s is AudioStreamMP3, "y Godot lo lee como audio")


func test_suena_en_bucle() -> void:
	# Sin bucle la partida se queda en silencio a los tres minutos.
	var s := load(CANCION) as AudioStreamMP3
	assert_true(s.loop, "vuelve a empezar sola")
	assert_gt(s.get_length(), 30.0, "y dura lo que dura una canción")


## La mina tiene su propia música: se pone al entrar y al salir vuelve la del
## juego.
const MINA_MP3 := "res://audio/musica/mina.mp3"


func test_la_mina_trae_su_cancion() -> void:
	assert_true(ResourceLoader.exists(MINA_MP3), "el archivo está importado")
	var s := load(MINA_MP3) as AudioStreamMP3
	assert_not_null(s)
	assert_true(s.loop, "y se repite: la mina dura más que la pista")
	var m := Node3D.new()
	m.set_script(load("res://scenes/actors/MinaCueva.gd"))
	assert_eq(m.get("musica"), s, "la mina la declara como suya")
	m.free()


## Cada volcán tiene la suya, y no es la misma.
func test_cada_volcan_trae_su_ascenso() -> void:
	var pares := {
		"res://scenes/puzzles/PuzzleIsluga.gd": "res://audio/musica/ascenso_isluga.mp3",
		"res://scenes/puzzles/CumbreCima.gd": "res://audio/musica/ascenso_ojos_del_salado.mp3",
	}
	var vistas: Array = []
	for guion: String in pares:
		var ruta: String = pares[guion]
		assert_true(ResourceLoader.exists(ruta), "%s está importado" % ruta)
		var s := load(ruta) as AudioStreamMP3
		assert_true(s.loop, "%s se repite" % ruta)
		var n := Node3D.new()
		n.set_script(load(guion))
		assert_eq(n.get("musica"), s, "%s la declara como suya" % guion)
		assert_false(vistas.has(s), "y no es la misma que la del otro volcán")
		vistas.append(s)
		n.free()


func test_poner_y_devolver_la_musica() -> void:
	# Otra prueba pudo dejar puesta la de un volcán: se parte de la del juego.
	Sfx.volver_a_la_musica_del_juego()
	var base: AudioStream = Sfx.musica_actual()
	assert_true(base is AudioStreamMP3 and not (base as AudioStreamMP3).resource_path.contains("ascenso"),
		"la del juego es la canción principal")
	var mina := load(MINA_MP3) as AudioStream
	Sfx.poner_musica(mina)
	assert_eq(Sfx.musica_actual(), mina, "al entrar suena la de la mina")
	Sfx.volver_a_la_musica_del_juego()
	assert_eq(Sfx.musica_actual(), base, "al salir vuelve la del juego")
	Sfx.poner_musica(null)
	assert_eq(Sfx.musica_actual(), base, "un interior sin música deja la del juego")


func test_es_la_que_suena() -> void:
	var reproductor: AudioStreamPlayer = Sfx.get("_music")
	assert_not_null(reproductor, "hay reproductor de música")
	assert_true(reproductor.stream is AudioStreamMP3,
		"y lo que tiene puesto es la canción, no la generada")


## Al entrar a cualquiera de los dos volcanes, un recordatorio bajo las
## misiones: con [T] cada uno resuelve el puzzle por separado.
func test_los_volcanes_recuerdan_el_cambio_de_personaje() -> void:
	for guion in ["res://scenes/puzzles/PuzzleIsluga.gd", "res://scenes/puzzles/CumbreCima.gd"]:
		var n := Node3D.new()
		n.set_script(load(guion))
		assert_true(n.has_method("_recordar_el_cambio"), "%s lo recuerda" % guion)
		assert_true(String(n.get("RECORDATORIO")).contains("[T]"),
			"y nombra la tecla, traducible al mando")
		n.free()


## Los avisos —«¡La lava quema!», los logros— salen en el centro y con placa,
## como el recuadro de misiones. Arriba, chica y centrada como el aviso de
## logro: en el centro tapaban lo que pasaba.
func test_los_avisos_van_en_placa_chica_arriba() -> void:
	var hud: CanvasLayer = (load("res://scenes/ui/HUD.tscn") as PackedScene).instantiate()
	add_child_autofree(hud)
	await wait_frames(2)
	var cartel: PanelContainer = hud.get("_cartel")
	assert_not_null(cartel, "hay una placa para los avisos")
	assert_false(cartel.visible, "que no se ve sin nada que decir")
	var banner: Label = hud.get("_banner")
	assert_true(cartel.is_ancestor_of(banner), "el cartel vive dentro de ella")
	hud.show_banner("¡La lava quema!")
	hud.call("_process", 0.016)
	assert_true(cartel.visible, "y se ve al avisar")
	assert_almost_eq(cartel.anchor_left, 0.5, 0.01, "centrada")
	assert_almost_eq(cartel.anchor_top, 0.0, 0.01, "arriba")
	await wait_frames(1)
	assert_gt(cartel.global_position.x, 0.0, "y dentro de la pantalla, no a la izquierda de todo")
	var pantalla := cartel.get_viewport().get_visible_rect().size
	var centro := cartel.global_position + cartel.size * 0.5
	assert_almost_eq(centro.x, pantalla.x * 0.5, 2.0, "centrado de lado a lado")
	assert_lt(centro.y, pantalla.y * 0.2, "arriba, como el aviso de logro")
	var logro: Label = hud.get("_aviso")
	assert_eq(logro.get_theme_font_size("font_size"), banner.get_theme_font_size("font_size"),
		"con la misma letra que el logro")
	# Con un logro sonando, el aviso baja para no taparlo.
	var placa_logro: PanelContainer = hud.get("_placa_de_logro")
	placa_logro.visible = true
	hud.call("_process", 0.016)
	assert_gt(cartel.offset_top, placa_logro.offset_top, "debajo del logro")
	placa_logro.visible = false
	hud.call("_process", 0.016)
	assert_almost_eq(cartel.offset_top, placa_logro.offset_top, 0.01, "y en su sitio sin logro")
	hud.clear_banner()
	hud.call("_process", 0.016)
	assert_false(cartel.visible, "y se esconde al quitarlo")


## El aviso del centro se va solo: «El camino se abre» se quedaba para siempre.
func test_el_aviso_se_va_solo() -> void:
	var hud: CanvasLayer = (load("res://scenes/ui/HUD.tscn") as PackedScene).instantiate()
	add_child_autofree(hud)
	await wait_frames(1)
	var banner: Label = hud.get("_banner")
	hud.show_banner("El camino se abre", 0.2)
	assert_true(banner.visible, "se ve")
	await wait_seconds(0.4)
	assert_false(banner.visible, "y a los 0,2 s se fue solo")
	hud.show_banner("Fijo", 0.0)
	await wait_seconds(0.3)
	assert_true(banner.visible, "con 0 se queda hasta que alguien lo quite")
	# Uno nuevo no lo quita el vencimiento del anterior.
	hud.show_banner("Primero", 0.2)
	hud.show_banner("Segundo", 0.0)
	await wait_seconds(0.4)
	assert_true(banner.visible and banner.text == "Segundo", "el segundo no se va por culpa del primero")
	hud.clear_banner()

