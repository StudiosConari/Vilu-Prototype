@tool
extends EditorScript

## Deja el terreno en un bloque de 2x2 regiones y borra el resto.
##
## CÓMO USARLO
##   1. Abrí scenes/core/World.tscn (tiene que ser la escena activa).
##   2. Abrí este archivo en el editor de Script.
##   3. Archivo → Ejecutar  (Ctrl+Shift+X).
##   4. Guardá la escena (Ctrl+S) para escribirlo a disco.
##
## POR QUÉ 2x2
##   Con regiones de 256 m, cuatro cubren 512x512 m centrados en el origen.
##   Medido sobre el mapa: el contenido del juego ocupa X -187..104 y
##   Z -247..139, así que entra entero. Y de las 13 regiones que había, esas
##   cuatro concentran el 91% del terreno esculpido y TODO el relieve alto
##   (el cráter de 20 m). Las otras nueve tienen bultos de menos de 3 m, y
##   cinco están completamente vacías.
##
## ARMADO PARA APLICAR: SIMULAR está en false, o sea que BORRA de verdad.
## Hay un respaldo en _terrain_antes_recorte/ por si hace falta volver atrás.
## Poné SIMULAR = true si sólo querés ver el informe.

## Sólo informa, no borra.
const SIMULAR := false

## Regiones que se conservan (índices de región, no metros).
const CONSERVAR := [
	Vector2i(-1, -1), Vector2i(-1, 0),
	Vector2i(0, -1),  Vector2i(0, 0),
]


func _run() -> void:
	var raiz := get_scene()
	if raiz == null:
		push_error("Abrí scenes/core/World.tscn primero.")
		return
	var t := raiz.get_node_or_null("Terrain3D")
	if t == null:
		push_error("La escena no tiene un nodo Terrain3D.")
		return
	var d = t.data
	if d == null or not d.has_method("get_region_locations"):
		push_error("Terrain3D sin datos o sin get_region_locations().")
		return

	var tam: float = float(t.region_size) * float(t.vertex_spacing)
	var locs: Array = d.get_region_locations().duplicate()
	print("[recorte] regiones actuales: %d  (%.0f x %.0f m cada una)"
		% [locs.size(), tam, tam])

	var sobran: Array = []
	var perdido := 0
	var perdido_alto := 0.0

	for l in locs:
		if CONSERVAR.has(Vector2i(l.x, l.y)):
			continue
		sobran.append(l)
		# Cuánto esculpido se perdería en esta región
		var x0: float = float(l.x) * tam
		var z0: float = float(l.y) * tam
		var x := x0
		while x < x0 + tam:
			var z := z0
			while z < z0 + tam:
				var h: float = d.get_height(Vector3(x, 0.0, z))
				if not is_nan(h) and absf(h) > 1.0:
					perdido += 1
					perdido_alto = maxf(perdido_alto, absf(h))
				z += 4.0
			x += 4.0

	if sobran.is_empty():
		print("[recorte] ya está en el bloque pedido. Nada que hacer.")
		return

	print("[recorte] a borrar: %d regiones" % sobran.size())
	for l in sobran:
		print("     %s   X %6.0f..%-6.0f Z %6.0f..%.0f"
			% [str(l), float(l.x) * tam, float(l.x) * tam + tam,
				float(l.y) * tam, float(l.y) * tam + tam])
	print("[recorte] esculpido que se pierde: %d muestras, la más alta %.1f m"
		% [perdido, perdido_alto])

	if SIMULAR:
		print("")
		print("[recorte] SIMULACIÓN: no se borró nada.")
		print("[recorte] Si el resumen te convence, poné SIMULAR = false y volvé a ejecutar.")
		return

	var borradas := 0
	for l in sobran:
		var centro := Vector3(float(l.x) * tam + tam * 0.5, 0.0,
			float(l.y) * tam + tam * 0.5)
		if d.has_method("remove_regionp"):
			d.remove_regionp(centro, true)
			borradas += 1
		elif d.has_method("remove_region"):
			d.remove_region(l, true)
			borradas += 1

	print("")
	print("[recorte] borradas %d, quedan %d." % [borradas, locs.size() - borradas])
	print("[recorte] GUARDÁ LA ESCENA (Ctrl+S) para escribirlo a disco.")
