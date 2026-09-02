@tool
extends EditorScript

## Generador de terreno para VILU — se corre A MANO desde el editor.
##
## CÓMO USARLO
##   1. Abrí scenes/core/World.tscn (tiene que ser la escena activa).
##   2. Abrí este archivo en el editor de Script.
##   3. Archivo → Ejecutar  (o Ctrl+Shift+X).
##   4. Guardá la escena para que Terrain3D escriba las regiones a disco.
##
## QUÉ HACE
##   · Crea las regiones que falten para cubrir todo el mapa.
##   · Ondula suavemente el terreno base (para que no sea una mesa de billar).
##   · Levanta un CRÁTER en Isluga y otro en Ojos del Salado: anillo de montaña
##     con el centro hueco y plano, donde viven las plataformas del puzzle.
##   · APLANA la huella de cada zona y el ancho de los caminos, para que no se
##     entierren las construcciones ni queden lomas cortando las rutas.
##
## Sólo toca el mapa de ALTURAS. Lo que hayas pintado con texturas no se toca.
##
## Es reejecutable: recalcula todo desde cero, no acumula.

# ─── Parámetros — tocá estos y volvé a ejecutar ────────────────────────────

## Margen extra alrededor de cada zona que queda aplanado, en metros.
const MARGEN_ZONA := 8.0
## Ancho aplanado a los lados de cada camino.
const ANCHO_CAMINO := 9.0

## Ondulación general del terreno
const ONDA_ALTURA := 3.5      # cuánto sube y baja el terreno base
const ONDA_ESCALA := 0.006    # más chico = colinas más anchas

## Volcanes: [id_zona, radio_interior, radio_pico, radio_base, altura]
##   interior = hueco plano del cráter (tiene que cubrir el puzzle)
##   pico     = dónde está la cresta del anillo
##   base     = dónde vuelve a nivel del suelo
const VOLCANES := [
	["Isluga", 34.0, 58.0, 95.0, 26.0],
	["Ojos del Salado", 46.0, 74.0, 118.0, 38.0],
]

## Paso de muestreo en metros. 1.0 = máxima fidelidad y más lento.
const PASO := 1.0
## Margen de terreno generado más allá de la zona más lejana.
const BORDE := 90.0


var _terreno: Node = null
var _datos = null
var _zonas: Array = []
var _caminos: Array = []
var _boca_mina := Vector3.ZERO
var _ruido: FastNoiseLite


func _run() -> void:
	var raiz := get_scene()
	if raiz == null:
		push_error("No hay escena abierta. Abrí scenes/core/World.tscn primero.")
		return

	_terreno = raiz.get_node_or_null("Terrain3D")
	if _terreno == null:
		push_error("La escena abierta no tiene un nodo Terrain3D. ¿Es World.tscn?")
		return

	_datos = _terreno.data
	if _datos == null:
		push_error("Terrain3D todavía no tiene datos. Poné el Data Directory primero.")
		return

	if not ("ZONAS" in raiz):
		push_error("La raíz de la escena no tiene el script WorldRoot.gd.")
		return
	_zonas = raiz.ZONAS
	_caminos = raiz.CAMINOS
	_boca_mina = raiz.BOCA_MINA

	_ruido = FastNoiseLite.new()
	_ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_ruido.frequency = ONDA_ESCALA
	_ruido.seed = 20260820

	var caja := _extension()
	print("[terreno] generando de (%.0f, %.0f) a (%.0f, %.0f)..." % [
		caja.position.x, caja.position.y,
		caja.position.x + caja.size.x, caja.position.y + caja.size.y])

	_crear_regiones(caja)
	var puntos := _esculpir(caja)

	# Refrescar mapas y rango de alturas (necesario para LOD y colisión)
	if _datos.has_method("force_update_maps"):
		_datos.force_update_maps()
	elif _datos.has_method("update_maps"):
		_datos.update_maps()
	if _datos.has_method("calc_height_range"):
		_datos.calc_height_range()

	print("[terreno] listo: %d puntos escritos." % puntos)
	print("[terreno] GUARDÁ LA ESCENA (Ctrl+S) para que las regiones vayan a disco.")


# ─── Extensión del mapa ────────────────────────────────────────────────────

func _extension() -> Rect2:
	var min_x := _boca_mina.x
	var max_x := _boca_mina.x
	var min_z := _boca_mina.z
	var max_z := _boca_mina.z
	for z in _zonas:
		var p: Vector3 = z["pos"]
		var r: float = float(z["radio"])
		min_x = minf(min_x, p.x - r)
		max_x = maxf(max_x, p.x + r)
		min_z = minf(min_z, p.z - r)
		max_z = maxf(max_z, p.z + r)
	return Rect2(min_x - BORDE, min_z - BORDE,
		(max_x - min_x) + BORDE * 2.0, (max_z - min_z) + BORDE * 2.0)


func _crear_regiones(caja: Rect2) -> void:
	var creadas := 0
	var tam: float = 1024.0
	if "region_size" in _terreno:
		tam = float(_terreno.region_size)
	var x := caja.position.x
	while x <= caja.position.x + caja.size.x:
		var z := caja.position.y
		while z <= caja.position.y + caja.size.y:
			var pos := Vector3(x, 0.0, z)
			var tiene := false
			if _datos.has_method("has_regionp"):
				tiene = _datos.has_regionp(pos)
			if not tiene:
				if _datos.has_method("add_region_blankp"):
					_datos.add_region_blankp(pos, false)
					creadas += 1
			z += tam * 0.5
		x += tam * 0.5
	if creadas > 0:
		print("[terreno] regiones nuevas: %d" % creadas)


# ─── Escultura ─────────────────────────────────────────────────────────────

func _esculpir(caja: Rect2) -> int:
	var n := 0
	var x := caja.position.x
	while x <= caja.position.x + caja.size.x:
		var z := caja.position.y
		while z <= caja.position.y + caja.size.y:
			var h := _altura_en(x, z)
			_datos.set_height(Vector3(x, 0.0, z), h)
			n += 1
			z += PASO
		x += PASO
	return n


func _altura_en(x: float, z: float) -> float:
	var p := Vector2(x, z)

	# 1) Terreno base ondulado
	var h: float = _ruido.get_noise_2d(x, z) * ONDA_ALTURA

	# 2) Volcanes (se quedan con el más alto, por si dos se solapan)
	for v in VOLCANES:
		var centro := _centro_de(String(v[0]))
		if centro == Vector2.INF:
			continue
		var d := p.distance_to(centro)
		h = maxf(h, _crater(d, float(v[1]), float(v[2]), float(v[3]), float(v[4])))

	# 3) Aplanado de zonas y caminos. `libre` va de 0 (plano forzado) a 1.
	var libre := _factor_libre(p)
	return h * libre


## Perfil del cráter: sube desde el borde interior hasta la cresta y vuelve a
## bajar hasta la base. Adentro del radio interior es 0 = plano, que es donde
## se apoyan las plataformas del puzzle.
func _crater(d: float, interior: float, pico: float, base: float, altura: float) -> float:
	if d <= interior or d >= base:
		return 0.0
	if d < pico:
		return altura * smoothstep(0.0, 1.0, (d - interior) / maxf(pico - interior, 0.001))
	return altura * (1.0 - smoothstep(0.0, 1.0, (d - pico) / maxf(base - pico, 0.001)))


## 0 = tiene que quedar perfectamente plano, 1 = terreno libre.
func _factor_libre(p: Vector2) -> float:
	var f := 1.0

	for z in _zonas:
		var c := Vector2(z["pos"].x, z["pos"].z)
		var r: float = float(z["radio"]) + MARGEN_ZONA
		f = minf(f, _borde_suave(p.distance_to(c), r, r + 14.0))

	# Boca de la Mina
	f = minf(f, _borde_suave(p.distance_to(Vector2(_boca_mina.x, _boca_mina.z)), 16.0, 30.0))

	# Caminos
	for c in _caminos:
		var a := _centro_de(String(c[0]))
		var b := _centro_de(String(c[1]))
		if a == Vector2.INF or b == Vector2.INF:
			continue
		var d := _dist_a_segmento(p, a, b)
		f = minf(f, _borde_suave(d, ANCHO_CAMINO, ANCHO_CAMINO + 12.0))

	return f


## 0 dentro de `adentro`, 1 pasando `afuera`, con transición suave.
func _borde_suave(d: float, adentro: float, afuera: float) -> float:
	if d <= adentro:
		return 0.0
	if d >= afuera:
		return 1.0
	return smoothstep(0.0, 1.0, (d - adentro) / maxf(afuera - adentro, 0.001))


func _dist_a_segmento(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var largo2 := ab.length_squared()
	if largo2 < 0.001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / largo2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _centro_de(id: String) -> Vector2:
	for z in _zonas:
		if String(z["id"]) == id:
			return Vector2(z["pos"].x, z["pos"].z)
	return Vector2.INF
