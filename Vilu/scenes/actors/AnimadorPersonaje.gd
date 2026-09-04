extends Node3D

## Pone el modelo de un personaje encima del muñeco y decide qué animación toca.
##
## Sirve para los dos: Emilia y Benjamín comparten locomoción, saltos, rodada y
## diálogo, y cada uno suma lo suyo —ella la cadena de golpes, él el arco—. Un
## clip que el personaje no tenga simplemente no suena; no hace falta un guion
## por cabeza.
##
## Vive colgado del nodo `Visual` del jugador, que es el que gira con la cámara.
## Los modelos miran hacia +Z y el juego toma -Z como frente —la nariz del muñeco
## de cajas está en z=-0.4—, así que van girados media vuelta, igual que el
## guanaco.
##
## Se separa del PlayerController a propósito: aquél ya lleva mil cosas, y esto
## es sólo mirar en qué estado está el personaje y elegir un clip.

## Los modelos miden 1.00 m, así que la escala son directamente sus metros de
## alto. Se pasa al montar porque cada personaje puede tener la suya.
const GIRO := PI

# Los nombres son los del .glb, que salen de los ficheros que subiste.
const REPOSO := "reposo"
const CAMINAR := "caminar"
const CORRER := "correr"
const SALTO_QUIETO := "saltar_en_el_lugar"
const SALTO_MOVIENDO := "salto_moviendose"
const HABLAR := "hablar"
const CARGADO := "golpe_cargado"
const PATADA_CORRIENDO := "patada_corriendo"
const RODAR := "rodar"
## La cadena de cuatro, en orden: los pasos 0 a 3 del combo.
const CADENA := ["jab_izquierdo", "cruzado", "patada", "patada_final"]
## El remate NO se interrumpe: se ve entero.
const SIN_INTERRUMPIR := ["patada_final"]
## Los miembros que pueden golpear. Se prueban todos y gana el que más recorrido
## hace: así no hay que decirle a mano cuál pega en cada animación.
const MIEMBROS := ["mixamorig_LeftHand", "mixamorig_RightHand",
	"mixamorig_LeftFoot", "mixamorig_RightFoot"]
const HUESO_CADERA := "mixamorig_Hips"
## Puntas de los dedos, para saber si la mano está abierta o cerrada.
const PUNTAS_DE_DEDO := ["Index4", "Middle4", "Ring4", "Pinky4", "Thumb4"]
## Cuántos puntos se prueban a lo largo del clip al buscar el impacto.
const MUESTRAS := 60

## Por debajo de esto se considera quieto.
const QUIETO := 0.35
## A partir de esta fracción de `run_speed` se usa la de correr.
const UMBRAL_CORRER := 0.72

var _jugador: CharacterBody3D = null
var _escala := 1.9
var _anim: AnimationPlayer = null
var _unica := ""        ## clip de una sola pasada que está sonando ahora
## Yendo a lomos del guanaco. Manda sobre todo lo demás menos hablar.
var _montado := false
var _hablando := false
## En qué segundo de cada clip de salto el personaje deja el suelo. Se calcula
## al montar, no se escribe a mano: si mañana rebajás las animaciones, el número
## se recalcula solo en vez de quedarse viejo en silencio.
var _despegue := {}
## En qué segundo de cada golpe cae el impacto: cuando el miembro que pega llega
## a su máxima extensión. Se mide al montar sobre la pose real del esqueleto, así
## no hay números escritos a mano que envejezcan al cambiar una animación.
var _impacto := {}


func montar(jugador: CharacterBody3D, escena: PackedScene, escala: float) -> void:
	_jugador = jugador
	_escala = escala

	var modelo := escena.instantiate() as Node3D
	modelo.scale = Vector3.ONE * escala
	add_child(modelo)
	rotation.y = GIRO

	_anim = _buscar_anim(modelo)
	if _anim == null:
		push_warning("El modelo de %s vino sin AnimationPlayer" % name)
		return

	# Las de moverse y la de hablar se repiten; las de golpear NO, o el
	# personaje se quedaría pegando para siempre.
	for n in [REPOSO, CAMINAR, CORRER, HABLAR]:
		var a := _anim.get_animation(n)
		if a != null:
			a.loop_mode = Animation.LOOP_LINEAR
	_anim.animation_finished.connect(_al_terminar)
	for n in [SALTO_QUIETO, SALTO_MOVIENDO]:
		_despegue[n] = _cuando_despega(n)
	for n in CADENA:
		if not SIN_INTERRUMPIR.has(n):
			_impacto[n] = _cuando_impacta(n)
	if _anim.has_animation(FLECHA_CARGADA):
		_tension = _cuando_abre_la_mano(FLECHA_CARGADA)
	_anim.play(REPOSO)   # medir dejó la pose donde fuera; se la devuelve

	# El muñeco de cajas se apaga, pero NO se borra: sigue sirviendo de
	# referencia de tamaño y de frente si hay que volver a mirarlo.
	var vis := get_parent() as Node3D
	if vis != null:
		for n in ["Placeholder", "Nose"]:
			var x := vis.get_node_or_null(n) as Node3D
			if x != null:
				x.visible = false


func _process(_delta: float) -> void:
	if _anim == null or _jugador == null:
		return
	_vigilar_tension()
	if _hablando:
		return
	# Yendo montado no se decide nada: ni correr, ni caer, ni saltar. El salto
	# pisaba la pose y, al terminar su clip, volvía a elegir "reposo": Benjamín
	# se quedaba DE PIE sobre el lomo del guanaco el resto del viaje.
	if _montado:
		if _anim.assigned_animation != MONTADO:
			_poner_pose_de_montado()
		return
	if _unica != "":
		return          # tensando o en pleno golpe: nada que decidir
	var quiere := _clip_de_movimiento()
	if quiere != "" and _anim.current_animation != quiere:
		_anim.play(quiere)


## Qué toca según cómo se esté moviendo.
func _clip_de_movimiento() -> String:
	var v := _jugador.velocity
	var plano := Vector2(v.x, v.z).length()
	if not _jugador.is_on_floor():
		# En el aire no se elige nada: manda el clip de salto, que se lanza en el
		# momento de saltar y no mientras ya se está cayendo.
		return ""
	if plano <= QUIETO:
		return REPOSO
	var tope: float = _jugador.get("run_speed") if "run_speed" in _jugador else 7.5
	return CORRER if plano >= tope * UMBRAL_CORRER else CAMINAR


# ─── Golpes ───────────────────────────────────────────────────────────────────

## La rodada de esquiva. Va aparte de los golpes porque no encadena con nada:
## empieza, se hace entera y se sale.
##
## `ritmo` acelera la reproducción: devuelve lo que va a durar DE VERDAD, que es
## lo que necesita quien la lanza para saber cuánto tiempo moverse.
func rodar(ritmo: float = 1.0) -> float:
	var largo := _una_pasada(RODAR)
	if largo <= 0.0:
		return 0.0
	var r: float = maxf(ritmo, 0.1)
	_anim.speed_scale = r          # _una_pasada lo deja en 1.0; se ajusta después
	return largo / r


## Un paso de la cadena de cuatro, o la patada de carrera si viene corriendo o
## por el aire, que es un golpe aparte y no encadena.
##
## Devuelve lo que DURA el clip: quien golpea lo necesita para saber cuánto
## esperar antes del siguiente y no cortarlo por la mitad.
func golpe(paso: int) -> float:
	if _corriendo_o_en_el_aire():
		_una_pasada(PATADA_CORRIENDO)
		return _corte_de(PATADA_CORRIENDO)
	var i: int = clampi(paso, 0, CADENA.size() - 1)
	_una_pasada(CADENA[i])
	return _corte_de(CADENA[i])


## Cuándo se puede encadenar el golpe siguiente: en el impacto, salvo el remate,
## que se ve entero.
func _corte_de(clip: String) -> float:
	if _anim == null or not _anim.has_animation(clip):
		return 0.0
	var largo: float = _anim.get_animation(clip).length
	if SIN_INTERRUMPIR.has(clip):
		return largo
	return _impacto.get(clip, largo * 0.85)


## El último clip que se lanzó. Lo consulta quien necesite saber si el golpe que
## salió fue la patada de carrera.
func ultimo_clip() -> String:
	return _unica


func golpe_cargado() -> float:
	return _una_pasada(CARGADO)


func _corriendo_o_en_el_aire() -> bool:
	if not _jugador.is_on_floor():
		return true
	var v := _jugador.velocity
	var plano := Vector2(v.x, v.z).length()
	var tope: float = _jugador.get("run_speed") if "run_speed" in _jugador else 7.5
	return plano >= tope * UMBRAL_CORRER


## Reproduce un clip de una sola pasada y devuelve lo que dura. Mientras suene,
## _process no toca nada.
func _una_pasada(nombre: String) -> float:
	if _anim == null or not _anim.has_animation(nombre):
		return 0.0
	_unica = nombre
	_anim.speed_scale = 1.0
	_anim.play(nombre)
	return _anim.get_animation(nombre).length


func _al_terminar(nombre: StringName) -> void:
	if String(nombre) == _unica:
		_unica = ""
		_anim.speed_scale = 1.0   # el salto lo cambia; se devuelve al terminar


# ─── Diálogo ──────────────────────────────────────────────────────────────────

## Mientras hable con alguien se repite el clip de hablar; al salir vuelve sola
## a lo que estuviera haciendo.
func hablar(activo: bool) -> void:
	if _anim == null:
		return
	_hablando = activo
	if activo:
		_unica = ""
		if _anim.has_animation(HABLAR):
			_anim.play(HABLAR)


func _buscar_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for h in n.get_children():
		var x := _buscar_anim(h)
		if x != null:
			return x
	return null


# ─── Salto ────────────────────────────────────────────────────────────────────

## Lanza el clip de salto, salteándose el impulso.
##
## `saltar_en_el_lugar` dura 1.93 s y el personaje no deja el suelo hasta el
## segundo 1.07: el primer segundo entero es agacharse a tomar impulso. Como el
## salto del juego es instantáneo, reproducirlo desde el principio dejaba a
## Emilia agachándose EN EL AIRE y cortaba justo al aterrizar. Por eso se empieza
## en el fotograma en que despega.
##
## Y se le ajusta el ritmo al vuelo real —0.67 s con la gravedad de ahora— para
## que la caída del clip coincida con tocar el suelo en vez de quedarse a medias.
func saltar(en_movimiento: bool, vuelo: float) -> void:
	if _anim == null:
		return
	# El que salta es el guanaco: el jinete sigue sentado. Sin esto el clip de
	# salto pisaba la pose de montar y ya no volvía.
	if _montado:
		return
	var clip: String = SALTO_MOVIENDO if en_movimiento else SALTO_QUIETO
	if not _anim.has_animation(clip):
		return
	var desde: float = _despegue.get(clip, 0.0)
	var restante: float = _anim.get_animation(clip).length - desde
	if restante <= 0.01:
		return
	_unica = clip
	_anim.play(clip)
	_anim.seek(desde, true)
	_anim.speed_scale = restante / maxf(vuelo, 0.05)


## En qué segundo del clip el personaje deja el suelo.
##
## Se busca en la altura de la cadera: primero baja al agacharse y luego sube; el
## despegue es cuando vuelve a pasar por la altura de reposo subiendo. Medirlo
## evita tener que escribir a mano un número que se rompería en silencio si
## cambiaras la animación.
func _cuando_despega(clip: String) -> float:
	if _anim == null or not _anim.has_animation(clip):
		return 0.0
	var a := _anim.get_animation(clip)
	var pista := -1
	for i in a.get_track_count():
		if a.track_get_type(i) == Animation.TYPE_POSITION_3D \
				and str(a.track_get_path(i)).contains("Hips"):
			pista = i
			break
	if pista < 0:
		return 0.0

	var n_keys := a.track_get_key_count(pista)
	if n_keys < 2:
		return 0.0
	var y0: float = (a.track_get_key_value(pista, 0) as Vector3).y
	var t_bajo := 0.0
	var mas_bajo := 1e9
	for k in n_keys:
		var v: Vector3 = a.track_get_key_value(pista, k)
		if v.y < mas_bajo:
			mas_bajo = v.y
			t_bajo = a.track_get_key_time(pista, k)
	for k in n_keys:
		var t: float = a.track_get_key_time(pista, k)
		if t > t_bajo and (a.track_get_key_value(pista, k) as Vector3).y >= y0:
			return t
	return 0.0


## En qué segundo del clip cae el impacto.
##
## Se busca el momento en que el miembro que golpea llega a su máxima extensión:
## el brazo estirado del jab, el pie de la patada. Ése es el instante en que el
## golpe conecta y, por tanto, donde tiene sentido dejar encadenar el siguiente.
##
## Se mide cuánto se ALEJA cada miembro de donde arrancó, no su posición ni su
## distancia a la cadera. Probé las dos cosas antes y ninguna sirve: los brazos
## siempre están lejos de la cadera —así las patadas salían "pegando con la
## mano"— y el eje de "adelante" en el espacio del esqueleto no es el mismo que
## el del modelo. El recorrido no depende de ninguna orientación.
##
## Se prueban los cuatro miembros y gana el que más se mueve, así no hay que
## decirle a mano cuál pega en cada animación.
func _cuando_impacta(clip: String) -> float:
	if _anim == null or not _anim.has_animation(clip):
		return 0.0
	var esq := _buscar_esqueleto(get_parent())
	if esq == null:
		esq = _buscar_esqueleto(self)
	if esq == null:
		return 0.0
	var cadera := esq.find_bone(HUESO_CADERA)
	if cadera < 0:
		return 0.0

	var a := _anim.get_animation(clip)
	# Pausado y buscando a mano: si se deja sonando, cada frame que pasa la
	# adelanta por su cuenta y las muestras dejan de ser del instante pedido.
	_anim.play(clip)
	_anim.pause()

	var mejor_rec := -1.0
	var mejor_t := 0.0
	for nombre in MIEMBROS:
		var idx := esq.find_bone(nombre)
		if idx < 0:
			continue
		_anim.seek(0.0, true)
		var p0: Vector3 = esq.get_bone_global_pose(idx).origin \
			- esq.get_bone_global_pose(cadera).origin
		for i in MUESTRAS + 1:
			var t: float = a.length * float(i) / float(MUESTRAS)
			_anim.seek(t, true)
			var p: Vector3 = esq.get_bone_global_pose(idx).origin \
				- esq.get_bone_global_pose(cadera).origin
			var rec := p.distance_to(p0)
			if rec > mejor_rec:
				mejor_rec = rec
				mejor_t = t
	_anim.stop()
	return mejor_t


func _buscar_esqueleto(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for h in n.get_children():
		var x := _buscar_esqueleto(h)
		if x != null:
			return x
	return null


# ─── Arco (Benjamín) ──────────────────────────────────────────────────────────

const FLECHA := "flecha"
const FLECHA_CARGADA := "flecha_cargada"
const FLECHA_TRIPLE := "flecha_triple"
const MONTADO := "montado"

## En qué segundo de `flecha_cargada` el arco queda tensado del todo. Se mide al
## montar, igual que el impacto de los golpes.
var _tension := 0.0
var _tensando := false


## Disparo rápido. Se acelera con `ritmo` porque el clip dura 2.47 s y a esa
## cadencia Benjamín tiraría una flecha cada dos segundos y medio.
func flecha(ritmo: float = 1.0) -> float:
	var largo := _una_pasada(FLECHA)
	if largo <= 0.0:
		return 0.0
	var r: float = maxf(ritmo, 0.1)
	_anim.speed_scale = r
	return largo / r


## Empieza a tensar y SE QUEDA quieto en la máxima extensión hasta que sueltes.
##
## El punto donde congelar se mide, no se escribe: es el fotograma en que la mano
## que tira de la cuerda llega a su mayor recorrido.
func tensar() -> void:
	if _anim == null or not _anim.has_animation(FLECHA_CARGADA):
		return
	_una_pasada(FLECHA_CARGADA)
	_tensando = true


## Suelta: la animación termina desde donde haya quedado.
##
## `ritmo` acelera sólo ESE tramo, el de soltar y volver a reposo, que suelto es
## largo y deja al arquero clavado esperando.
func soltar(ritmo: float = 1.0) -> float:
	if _anim == null or not _tensando:
		return 0.0
	_tensando = false
	_anim.play(FLECHA_CARGADA)
	if _anim.current_animation_position < _tension:
		_anim.seek(_tension, true)
	var r: float = maxf(ritmo, 0.1)
	_anim.speed_scale = r
	return (_anim.get_animation(FLECHA_CARGADA).length - _tension) / r


## La habilidad usa la animación del disparo RÁPIDO.
##
## Tenía la suya, pero calzaba peor con el gesto: el clip de la rápida encaja
## mejor con soltar tres flechas de una. Si algún día vuelve a existir uno propio
## se usa ése.
func flecha_triple(ritmo: float = 1.0) -> float:
	if _anim != null and _anim.has_animation(FLECHA):
		return flecha(ritmo)
	return _una_pasada(FLECHA_TRIPLE)


## Pose de ir montado en el guanaco. Son dos fotogramas: se mantiene.
func montado(activo: bool) -> void:
	if _anim == null or not _anim.has_animation(MONTADO):
		return
	_montado = activo
	if activo:
		_poner_pose_de_montado()
	elif _unica == MONTADO:
		_unica = ""
		# La pose se sostiene con el reproductor EN PAUSA. Desmontando en el aire
		# nadie elige clip hasta tocar el suelo, y hasta entonces el personaje
		# bajaba congelado en postura de jinete. Se lo despierta a mano.
		if _anim.has_animation(REPOSO):
			_anim.play(REPOSO)


func _poner_pose_de_montado() -> void:
	_unica = MONTADO
	_anim.speed_scale = 1.0
	_anim.play(MONTADO)
	_anim.pause()
	# Al primer fotograma, no al último: buscar el final de un clip de dos
	# fotogramas lo da por terminado y lo descarta, y la pose se pierde.
	_anim.seek(0.0, true)


## Mientras tensa, el clip se detiene al llegar a la máxima extensión.
func _vigilar_tension() -> void:
	if not _tensando or _anim == null:
		return
	# `assigned_animation` y no `current_animation`: al pausar, la segunda queda
	# VACIA, y mirarla habria cancelado el tensado en el mismo frame en que se
	# congela el arco, dejando el soltar sin efecto.
	if _anim.assigned_animation != FLECHA_CARGADA:
		_tensando = false
		return
	if _anim.current_animation_position >= _tension:
		_anim.pause()


## El último instante en que el arquero TODAVÍA sujeta la cuerda.
##
## La señal son los dedos: se mide cuánto se separan las puntas del hueso de la
## mano. Puño cerrado da poco y mano abierta da mucho, y abrir la mano es, en un
## humano, soltar. El punto que se devuelve es la última muestra antes de ese
## salto.
##
## Es la tercera vara que pruebo y la primera que corresponde a lo que se ve. Con
## el recorrido de la mano el punto caía en 0.87 s, con el arco a medio abrir; con
## la apertura entre manos caía en 2.25 s, ya con la mano abierta o sea con la
## flecha ya soltada. Los dedos no dejan lugar a interpretación.
func _cuando_abre_la_mano(clip: String) -> float:
	if _anim == null or not _anim.has_animation(clip):
		return 0.0
	var esq := _buscar_esqueleto(get_parent())
	if esq == null:
		esq = _buscar_esqueleto(self)
	if esq == null:
		return 0.0
	var a := _anim.get_animation(clip)
	_anim.play(clip)
	_anim.pause()

	# Se mide la apertura de las DOS manos y gana la que más cambia: es la que
	# suelta, y así no hay que saber de antemano si el arquero es diestro o zurdo.
	var mejor_rango := -1.0
	var t_suelta := 0.0
	for lado in ["Left", "Right"]:
		var mano := esq.find_bone("mixamorig_%sHand" % lado)
		if mano < 0:
			continue
		var curva: Array = []
		for i in MUESTRAS + 1:
			_anim.seek(a.length * float(i) / float(MUESTRAS), true)
			var suma := 0.0
			var n := 0
			for p in PUNTAS_DE_DEDO:
				var idx := esq.find_bone("mixamorig_%sHand%s" % [lado, p])
				if idx < 0:
					continue
				suma += esq.get_bone_global_pose(idx).origin.distance_to(
					esq.get_bone_global_pose(mano).origin)
				n += 1
			curva.append(suma / maxf(n, 1))
		var bajo: float = curva.min()
		var alto: float = curva.max()
		if alto - bajo <= mejor_rango:
			continue
		mejor_rango = alto - bajo
		# A mitad de camino entre puño y mano abierta: ahí ya soltó.
		var umbral: float = bajo + (alto - bajo) * 0.5
		t_suelta = a.length
		for i in curva.size():
			if curva[i] >= umbral:
				# La muestra ANTERIOR es la última con la cuerda todavía sujeta.
				t_suelta = a.length * float(maxi(i - 1, 0)) / float(MUESTRAS)
				break
	_anim.stop()
	return t_suelta
