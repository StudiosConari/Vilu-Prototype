extends GutTest

## Que al llegar a un volcán se explique la [T].
##
## Los dos volcanes son los únicos sitios que obligan a separar al party —una
## palanca de un lado, la plataforma del otro— y el juego no lo decía en ningún
## lado: la tecla sale en los controles del menú y a los veinte minutos nadie se
## acuerda. Se cuenta donde hace falta y una sola vez por volcán.

const JUEGO := preload("res://scenes/core/Game.gd")
const HUD := preload("res://scenes/ui/HUD.gd")


## Un HUD que sólo apunta lo que le dijeron.
class HudFalso extends CanvasLayer:
	var dichos: Array[String] = []

	func consejo(texto: String, _seg := 7.0) -> void:
		dichos.append(texto)


## Un Game DE VERDAD, pero sin meter en el árbol.
##
## Fuera del árbol no corre `_ready`, así que no monta el mundo ni el party ni
## la cámara —eso tardaría segundos y cargaría medio juego— y sin embargo el
## método que se prueba es el auténtico, no una copia.
func _juego() -> Node:
	var g: Node = JUEGO.new()
	g.set("party", [1, 2])          # dos personajes: la [T] tiene sentido
	g.set("hud", HudFalso.new())
	return g


func test_los_dos_volcanes_tienen_consejo() -> void:
	assert_true(JUEGO.CONSEJOS_DE_ZONA.has("Isluga"), "el Isluga lo explica")
	assert_true(JUEGO.CONSEJOS_DE_ZONA.has("OjosDelSalado"), "y el Ojos del Salado")


func test_el_consejo_nombra_la_tecla() -> void:
	for zona: String in JUEGO.CONSEJOS_DE_ZONA:
		var texto := String(JUEGO.CONSEJOS_DE_ZONA[zona])
		assert_true(texto.contains("[T]"), "el consejo de %s dice qué tecla es" % zona)


func test_lo_dice_al_llegar_al_volcan() -> void:
	var g := _juego()
	g.call("_consejo_de_la_zona", "Isluga")
	var hud: HudFalso = g.get("hud")
	assert_eq(hud.dichos.size(), 1, "al pisar el Isluga se explica la [T]")
	hud.free()
	g.free()


func test_no_lo_repite_en_la_segunda_visita() -> void:
	# Al Isluga se entra dos veces: subiendo desde Tarapacá y otra por el portal
	# entre volcanes al final. La segunda ya no hace falta explicar nada.
	var g := _juego()
	for i in 3:
		g.call("_consejo_de_la_zona", "Isluga")
	var hud: HudFalso = g.get("hud")
	assert_eq(hud.dichos.size(), 1, "una sola vez por volcán")
	hud.free()
	g.free()


func test_cada_volcan_lleva_su_cuenta() -> void:
	var g := _juego()
	g.call("_consejo_de_la_zona", "Isluga")
	g.call("_consejo_de_la_zona", "OjosDelSalado")
	var hud: HudFalso = g.get("hud")
	assert_eq(hud.dichos.size(), 2, "el segundo volcán vuelve a explicarlo")
	hud.free()
	g.free()


func test_no_lo_dice_en_las_zonas_normales() -> void:
	var g := _juego()
	g.call("_consejo_de_la_zona", "Mina")
	var hud: HudFalso = g.get("hud")
	assert_eq(hud.dichos.size(), 0, "en la mina no se separa a nadie")
	hud.free()
	g.free()


func test_sin_companero_no_se_explica() -> void:
	# Con un solo personaje la [T] no hace nada: explicarla sería enseñar un
	# control que no existe todavía.
	var g := _juego()
	g.set("party", [1])
	g.call("_consejo_de_la_zona", "Isluga")
	var hud: HudFalso = g.get("hud")
	assert_eq(hud.dichos.size(), 0, "sin party de dos no hay nada que separar")
	hud.free()
	g.free()


func test_el_hud_sabe_dar_consejos() -> void:
	# Game lo llama con `has_method`, así que un cambio de nombre se tragaría el
	# aviso sin dar ningún error.
	var h: CanvasLayer = HUD.new()
	assert_true(h.has_method("consejo"), "el HUD tiene dónde mostrarlo")
	h.free()
