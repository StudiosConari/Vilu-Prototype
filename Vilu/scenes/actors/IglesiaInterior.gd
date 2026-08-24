extends Node3D

## Interior del Santuario de La Tirana.
##
## Es un INTERIOR, igual que la Mina: no vive en el mundo abierto. Al cruzar la
## puerta, Game.gd esconde el mundo y carga esta escena en su lugar. Por eso las
## coordenadas de acá no tienen nada que ver con las de La Tirana: es un espacio
## propio, con su origen en el centro de la nave.
##
## TRAZA, sacada de las fotos del santuario real
##   La planta es una basílica de tres naves. La central es ancha y alta; las
##   laterales son más angostas y de techo bajo, separadas por PILARES CUADRADOS
##   macizos de madera, que son el elemento que más define el espacio.
##
##   Sobre la nave central la bóveda se pliega en gablete y va pintada de AZUL
##   CON ESTRELLAS DORADAS: es la seña de identidad del lugar y lo primero que
##   se ve al entrar. Bajo el arranque de la bóveda corre un friso azul con
##   letras doradas (el Magníficat).
##
##   El presbiterio está al fondo, elevado tres escalones, cerrado por un
##   comulgatorio de reja, con el retablo contra el testero.
##
##   Se entra por un nártex separado de la nave por un tabique, con el coro
##   alto encima.
##
## LO QUE NO ESTÁ, Y NO DEBERÍA ESTAR ACÁ
##   Las estrellas van como geometría porque son la firma del espacio y sin
##   ellas el techo es una plancha azul. Todo lo demás que en realidad es
##   TEXTURA —las letras del friso, la veta de la madera, los vitrales— no se
##   greybloquea: eso entra después con materiales o con modelos a mano.
##
## No es @tool a propósito: los interiores no se previsualizan en World.tscn.

# ── Medidas de la planta, en metros ──────────────────────────────────────────
## Semiancho de la nave central: los pilares se plantan a esta distancia del eje.
const MEDIA_NAVE := 5.5
## Ancho de cada nave lateral, del pilar al muro.
const ANCHO_LATERAL := 5.0
## Mitad del largo interior, de la fachada al testero.
const MEDIO_LARGO := 22.0
const ESPESOR := 1.0

# ── Alturas ──────────────────────────────────────────────────────────────────
## Techo de las naves laterales: bajo, para que la central se sienta alta.
const ALTO_LATERAL := 7.5
## Arranque del gablete, sobre la nave central.
##
## Tiene que dejar sitio para el clerestorio POR ENCIMA de la losa del techo
## lateral, que ocupa de ALTO_LATERAL a ALTO_LATERAL + ESPESOR. Si el arranque
## queda muy bajo, el paño del clerestorio se mete dentro de esa losa y las dos
## caras paralelas parpadean.
const ALTO_ARRANQUE := 11.0
## Cumbrera de la bóveda.
const ALTO_CUMBRE := 13.5

# ── Piezas ───────────────────────────────────────────────────────────────────
## Lado de los pilares cuadrados.
const PILAR := 1.8
## Separación entre pilares a lo largo de la nave.
const PASO_PILAR := 7.0
## Profundidad del presbiterio, desde el testero.
const FONDO_PRESBITERIO := 9.0
## Altura total del presbiterio: tres escalones.
const ALTO_PRESBITERIO := 0.9
## Profundidad del nártex, desde la fachada.
const FONDO_NARTEX := 4.0
## Altura del piso del coro sobre el nártex.
const ALTO_CORO := 5.0
## Hueco de la puerta de la fachada.
const PUERTA_ANCHO := 3.2
const PUERTA_ALTO := 4.5

## Semiancho interior total, de eje a muro.
var _media_total := MEDIA_NAVE + ANCHO_LATERAL


func _ready() -> void:
	_construir()
	_hint("Santuario de La Tirana.")


func _construir() -> void:
	var muro   := _mat(Color(0.46, 0.26, 0.16))   # tabla horizontal, cedro oscuro
	var clara  := _mat(Color(0.72, 0.52, 0.30))   # madera clara: pilares, bancos
	var boveda := _mat(Color(0.09, 0.40, 0.66))   # azul de la bóveda
	var friso  := _mat(Color(0.07, 0.30, 0.52))   # banda del Magníficat
	var piso   := _mat(Color(0.83, 0.78, 0.67))   # baldosa crema
	var marmol := _mat(Color(0.92, 0.90, 0.86))   # presbiterio
	var oro    := _mat(Color(0.84, 0.68, 0.24))

	_casco(muro, piso, boveda, friso)
	_pilares(clara)
	_bancos(clara)
	_presbiterio(marmol, clara, oro)
	_nartex_y_coro(muro, clara)
	_estrellas(oro)
	_luces()


# ── Casco: suelo, muros, techos y bóveda ─────────────────────────────────────

func _casco(muro: Material, piso: Material, boveda: Material, friso: Material) -> void:
	var ancho_total := _media_total * 2.0
	var largo := MEDIO_LARGO * 2.0

	# Suelo
	_box(Vector3(0, -ESPESOR * 0.5, 0),
		Vector3(ancho_total + ESPESOR * 2.0, ESPESOR, largo), piso)

	# Muros laterales y testero
	for lado: float in [-1.0, 1.0]:
		_box(Vector3(lado * (_media_total + ESPESOR * 0.5), ALTO_LATERAL * 0.5, 0),
			Vector3(ESPESOR, ALTO_LATERAL, largo), muro)
	_box(Vector3(0, ALTO_ARRANQUE * 0.5, -(MEDIO_LARGO + ESPESOR * 0.5)),
		Vector3(ancho_total + ESPESOR * 2.0, ALTO_ARRANQUE, ESPESOR), muro)

	# Fachada con el hueco de la puerta
	var pano := (ancho_total - PUERTA_ANCHO) * 0.5
	for lado: float in [-1.0, 1.0]:
		_box(Vector3(lado * (PUERTA_ANCHO * 0.5 + pano * 0.5), ALTO_LATERAL * 0.5,
				MEDIO_LARGO + ESPESOR * 0.5),
			Vector3(pano, ALTO_LATERAL, ESPESOR), muro)
	_box(Vector3(0, PUERTA_ALTO + (ALTO_LATERAL - PUERTA_ALTO) * 0.5,
			MEDIO_LARGO + ESPESOR * 0.5),
		Vector3(PUERTA_ANCHO, ALTO_LATERAL - PUERTA_ALTO, ESPESOR), muro)

	# Techo plano de las naves laterales
	for lado: float in [-1.0, 1.0]:
		_box(Vector3(lado * (MEDIA_NAVE + ANCHO_LATERAL * 0.5),
				ALTO_LATERAL + ESPESOR * 0.5, 0),
			Vector3(ANCHO_LATERAL, ESPESOR, largo), boveda)

	# Clerestorio: el paño entre el techo lateral y el arranque del gablete.
	# Es lo que deja entrar la luz alta sobre la nave central.
	#
	# Arranca en el TOPE de la losa del techo lateral, no en su base: si empieza
	# antes se solapa con ella y las dos caras paralelas parpadean.
	# El paño sigue medio metro POR ENCIMA del arranque, por detrás de la
	# bóveda. Si terminara justo en ALTO_ARRANQUE compartiría cara superior con
	# los pilares, que llegan a esa misma altura, y ahí sí parpadearía.
	var base_clere := ALTO_LATERAL + ESPESOR
	var tope_clere := ALTO_ARRANQUE + 0.5
	var h_clere := tope_clere - base_clere
	for lado: float in [-1.0, 1.0]:
		_box(Vector3(lado * MEDIA_NAVE, base_clere + h_clere * 0.5, 0),
			Vector3(0.4, h_clere, largo), muro)

	# Friso del Magníficat: banda azul justo bajo el arranque
	for lado: float in [-1.0, 1.0]:
		_box(Vector3(lado * (MEDIA_NAVE - 0.35), ALTO_LATERAL - 0.6, 0),
			Vector3(0.3, 1.2, largo), friso)

	# Bóveda en gablete sobre la nave central
	for lado: float in [-1.0, 1.0]:
		var faldon := _box(Vector3(lado * MEDIA_NAVE * 0.5,
				(ALTO_ARRANQUE + ALTO_CUMBRE) * 0.5, 0),
			Vector3(_largo_faldon(), 0.4, largo), boveda)
		faldon.rotation.z = -lado * _angulo_faldon()


## Largo del faldón medido sobre la pendiente, no en planta.
func _largo_faldon() -> float:
	var subida := ALTO_CUMBRE - ALTO_ARRANQUE
	return sqrt(MEDIA_NAVE * MEDIA_NAVE + subida * subida)


func _angulo_faldon() -> float:
	return atan2(ALTO_CUMBRE - ALTO_ARRANQUE, MEDIA_NAVE)


# ── Pilares ──────────────────────────────────────────────────────────────────

func _pilares(mat: Material) -> void:
	# Se replantean DESDE el presbiterio hacia el nártex, no al revés.
	#
	# Al revés, el paso de 7 m hacía que la última fila cayera donde le tocara,
	# y con estas medidas caía justo encima de los escalones del presbiterio.
	# Anclando la primera fila un par de metros delante del comulgatorio, la
	# separación sobra por el lado del nártex, que es donde no molesta.
	# +2.5 y no menos: los escalones del presbiterio se comen hasta z_frente+1.2,
	# y la basa del pilar sobresale 0.2 del fuste.
	var z := -MEDIO_LARGO + FONDO_PRESBITERIO + 2.5
	var z_fin := MEDIO_LARGO - FONDO_NARTEX - 2.0
	while z <= z_fin:
		for lado: float in [-1.0, 1.0]:
			var x := lado * MEDIA_NAVE
			# Fuste
			_box(Vector3(x, ALTO_ARRANQUE * 0.5, z),
				Vector3(PILAR, ALTO_ARRANQUE, PILAR), mat)
			# Basa y capitel: es lo que les da la silueta
			_box(Vector3(x, 0.35, z), Vector3(PILAR + 0.4, 0.7, PILAR + 0.4), mat)
			_box(Vector3(x, ALTO_ARRANQUE - 0.35, z),
				Vector3(PILAR + 0.4, 0.7, PILAR + 0.4), mat)
		z += PASO_PILAR


# ── Bancos ───────────────────────────────────────────────────────────────────

func _bancos(mat: Material) -> void:
	# Dos bloques con pasillo central, sólo en la nave central.
	const PASILLO := 2.4
	var ancho_banco: float = (MEDIA_NAVE * 2.0 - PASILLO - PILAR) * 0.5 - 0.6
	var centro: float = PASILLO * 0.5 + ancho_banco * 0.5
	var z := MEDIO_LARGO - FONDO_NARTEX - 2.5
	var z_fin := -MEDIO_LARGO + FONDO_PRESBITERIO + 2.0
	while z >= z_fin:
		for lado: float in [-1.0, 1.0]:
			_box(Vector3(lado * centro, 0.45, z),
				Vector3(ancho_banco, 0.12, 0.9), mat)
			# El respaldo va 10 cm más angosto que el asiento a propósito: a ras
			# sus costados quedan coplanares con los del asiento y parpadean en
			# los dos extremos de cada banco.
			_box(Vector3(lado * centro, 0.85, z - 0.4),
				Vector3(ancho_banco - 0.1, 0.9, 0.14), mat)
		z -= 2.2


# ── Presbiterio ──────────────────────────────────────────────────────────────

func _presbiterio(marmol: Material, madera: Material, oro: Material) -> void:
	var z_frente := -MEDIO_LARGO + FONDO_PRESBITERIO
	var ancho := _media_total * 2.0

	# Tres escalones hacia la tarima. Arrancan a 0.45 del frente y no a 0.3: a
	# 0.3 el primero rozaba el comulgatorio y compartía con él el plano del
	# suelo.
	for i in 3:
		var h: float = ALTO_PRESBITERIO * (float(i + 1) / 3.0)
		_box(Vector3(0, h * 0.5, z_frente + 0.45 + float(i) * 0.35),
			Vector3(MEDIA_NAVE * 2.0, h, 0.35), marmol)

	# Tarima
	_box(Vector3(0, ALTO_PRESBITERIO * 0.5, (z_frente - MEDIO_LARGO) * 0.5),
		Vector3(ancho, ALTO_PRESBITERIO, FONDO_PRESBITERIO), marmol)

	# Comulgatorio: murete con reja a ambos lados, abierto en el centro.
	#
	# Va ARRIBA de los escalones, apoyado sobre la tarima, no al pie: así es en
	# el santuario, y de paso deja de compartir el plano del suelo con la tarima
	# y con los escalones, que era de donde salía el parpadeo.
	var largo_reja: float = _media_total - MEDIA_NAVE * 0.35
	var z_reja := z_frente - 0.3
	for lado: float in [-1.0, 1.0]:
		var x: float = lado * (_media_total - largo_reja * 0.5)
		_box(Vector3(x, ALTO_PRESBITERIO + 0.25, z_reja),
			Vector3(largo_reja, 0.5, 0.3), madera)
		_box(Vector3(x, ALTO_PRESBITERIO + 0.85, z_reja),
			Vector3(largo_reja, 0.7, 0.1), oro)

	# Altar y retablo contra el testero. El remate dorado va por ENCIMA del
	# retablo, sin montarse: si se solapan comparten sus dos caras de canto.
	_box(Vector3(0, ALTO_PRESBITERIO + 0.55, -MEDIO_LARGO + 4.5),
		Vector3(3.4, 1.1, 1.3), marmol)
	_box(Vector3(0, ALTO_PRESBITERIO + 3.2, -MEDIO_LARGO + 1.2),
		Vector3(7.0, 6.4, 1.2), madera)
	_box(Vector3(0, ALTO_PRESBITERIO + 7.2, -MEDIO_LARGO + 1.2),
		Vector3(3.0, 1.6, 1.0), oro)


# ── Nártex y coro ────────────────────────────────────────────────────────────

func _nartex_y_coro(muro: Material, madera: Material) -> void:
	var z_tabique := MEDIO_LARGO - FONDO_NARTEX
	var ancho := _media_total * 2.0
	var pano := (ancho - PUERTA_ANCHO) * 0.5

	# Tabique entre el nártex y la nave, con su hueco
	for lado: float in [-1.0, 1.0]:
		_box(Vector3(lado * (PUERTA_ANCHO * 0.5 + pano * 0.5), ALTO_CORO * 0.5, z_tabique),
			Vector3(pano, ALTO_CORO, 0.4), muro)
	_box(Vector3(0, PUERTA_ALTO + (ALTO_CORO - PUERTA_ALTO) * 0.5, z_tabique),
		Vector3(PUERTA_ANCHO, ALTO_CORO - PUERTA_ALTO, 0.4), muro)

	# Piso del coro sobre el nártex, con su baranda.
	#
	# Arranca justo por detrás del tabique y no encima de él: montándose los dos
	# compartían el plano del muro lateral y parpadeaban en el canto.
	var fondo_coro := FONDO_NARTEX - 0.2
	_box(Vector3(0, ALTO_CORO, MEDIO_LARGO - fondo_coro * 0.5),
		Vector3(ancho, 0.4, fondo_coro), madera)
	_box(Vector3(0, ALTO_CORO + 0.75, z_tabique - 0.25),
		Vector3(ancho, 1.1, 0.15), madera)


# ── Estrellas de la bóveda ───────────────────────────────────────────────────

## Siembra las estrellas doradas sobre los dos faldones del gablete.
##
## Van en UN MultiMesh por faldón y no como nodos sueltos: son varios cientos, y
## como nodos serían varios cientos de objetos con su coste cada uno, para algo
## que ni se mueve ni necesita colisión. Mismo criterio que PisoBaldosas.
func _estrellas(mat: Material) -> void:
	const SEPARACION := 1.3

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260823

	var malla := BoxMesh.new()
	malla.size = Vector3(0.30, 0.06, 0.30)
	malla.material = mat

	var ang := _angulo_faldon()
	var pendiente := _largo_faldon()

	for lado: float in [-1.0, 1.0]:
		var lista: Array[Transform3D] = []
		var s := SEPARACION * 0.5
		while s < pendiente:
			var z := -MEDIO_LARGO + SEPARACION * 0.5
			while z < MEDIO_LARGO:
				# Punto sobre el faldón: se recorre la pendiente desde el
				# arranque hacia la cumbrera y se traduce a X e Y.
				var x: float = lado * (MEDIA_NAVE - s * cos(ang))
				var y: float = ALTO_ARRANQUE + s * sin(ang) - 0.30
				var pos := Vector3(x, y, z) + Vector3(
					rng.randf_range(-0.22, 0.22), 0.0, rng.randf_range(-0.3, 0.3))
				var base := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
				lista.append(Transform3D(base, pos))
				z += SEPARACION
			s += SEPARACION

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = malla
		mm.instance_count = lista.size()
		for i in lista.size():
			mm.set_instance_transform(i, lista[i])

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Estrellas_" + ("izq" if lado < 0.0 else "der")
		mmi.multimesh = mm
		add_child(mmi)


# ── Luz ──────────────────────────────────────────────────────────────────────

func _luces() -> void:
	# Cálida sobre el presbiterio, neutra a lo largo de la nave.
	var z_altar := -MEDIO_LARGO + 4.0
	for lado: float in [-1.0, 1.0]:
		_luz(Vector3(lado * 2.6, ALTO_PRESBITERIO + 2.2, z_altar + 1.5),
			Color(1.0, 0.80, 0.46), 12.0, 2.4)

	var z := MEDIO_LARGO - 6.0
	while z > -MEDIO_LARGO + 6.0:
		_luz(Vector3(0, ALTO_ARRANQUE - 1.5, z), Color(1.0, 0.94, 0.82), 16.0, 1.2)
		for lado: float in [-1.0, 1.0]:
			_luz(Vector3(lado * (MEDIA_NAVE + ANCHO_LATERAL * 0.5), ALTO_LATERAL - 1.0, z),
				Color(1.0, 0.92, 0.80), 11.0, 0.9)
		z -= 9.0


# ── Helpers ──────────────────────────────────────────────────────────────────

func _box(pos: Vector3, size: Vector3, mat: Material) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.size = size
	b.position = pos
	b.material_override = mat
	b.use_collision = true
	add_child(b)
	return b


func _luz(pos: Vector3, color: Color, alcance: float, energia: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.omni_range = alcance
	l.light_energy = energia
	add_child(l)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _hint(texto: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_hint"):
		hud.show_hint(texto)
