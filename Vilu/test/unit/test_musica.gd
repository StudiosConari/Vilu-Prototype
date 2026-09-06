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


func test_es_la_que_suena() -> void:
	var reproductor: AudioStreamPlayer = Sfx.get("_music")
	assert_not_null(reproductor, "hay reproductor de música")
	assert_true(reproductor.stream is AudioStreamMP3,
		"y lo que tiene puesto es la canción, no la generada")
