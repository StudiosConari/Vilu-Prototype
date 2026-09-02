extends Node3D

## Pone el modelo de Emilia sobre el personaje y decide qué animación toca.
##
## Vive colgado del nodo `Visual` del jugador, que es el que gira con la cámara.
## El modelo mira hacia +Z y el juego toma -Z como frente —la nariz del muñeco de
## cajas está en z=-0.4—, así que va girado media vuelta, igual que el guanaco.
##
## Se separa del PlayerController a propósito: aquél ya lleva mil cosas, y esto
## es sólo mirar en qué estado está el personaje y elegir un clip.

const MODELO := preload("res://models/personaje/emilia.glb")

## El modelo mide 1.00 m y la cápsula del personaje 1.60, así que va a 1.6.
const ESCALA := 1.6
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

## Por debajo de esto se considera quieto.
const QUIETO := 0.35
## A partir de esta fracción de `run_speed` se usa la de correr.
const UMBRAL_CORRER := 0.72

var _jugador: CharacterBody3D = null
var _anim: AnimationPlayer = null
var _unica := ""        ## clip de una sola pasada que está sonando ahora
var _hablando := false


func montar(jugador: CharacterBody3D) -> void:
	_jugador = jugador

	var modelo := MODELO.instantiate() as Node3D
	modelo.scale = Vector3.ONE * ESCALA
	add_child(modelo)
	rotation.y = GIRO

	_anim = _buscar_anim(modelo)
	if _anim == null:
		push_warning("Emilia: el modelo vino sin AnimationPlayer")
		return

	# Las de moverse y la de hablar se repiten; las de golpear NO, o el
	# personaje se quedaría pegando para siempre.
	for n in [REPOSO, CAMINAR, CORRER, HABLAR]:
		var a := _anim.get_animation(n)
		if a != null:
			a.loop_mode = Animation.LOOP_LINEAR
	_anim.animation_finished.connect(_al_terminar)

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
	if _hablando or _unica != "":
		return          # hablando o en pleno golpe: nada que decidir
	var quiere := _clip_de_movimiento()
	if _anim.current_animation != quiere:
		_anim.play(quiere)


## Qué toca según cómo se esté moviendo.
func _clip_de_movimiento() -> String:
	var v := _jugador.velocity
	var plano := Vector2(v.x, v.z).length()
	if not _jugador.is_on_floor():
		# En el aire hay dos saltos distintos: el de sitio y el de carrera.
		return SALTO_MOVIENDO if plano > QUIETO else SALTO_QUIETO
	if plano <= QUIETO:
		return REPOSO
	var tope: float = _jugador.get("run_speed") if "run_speed" in _jugador else 7.5
	return CORRER if plano >= tope * UMBRAL_CORRER else CAMINAR


# ─── Golpes ───────────────────────────────────────────────────────────────────

## La rodada de esquiva. Va aparte de los golpes porque no encadena con nada:
## empieza, se hace entera y se sale.
func rodar() -> void:
	_una_pasada(RODAR)


## Un paso de la cadena de cuatro, o la patada de carrera si viene corriendo o
## por el aire, que es un golpe aparte y no encadena.
func golpe(paso: int) -> void:
	if _corriendo_o_en_el_aire():
		_una_pasada(PATADA_CORRIENDO)
		return
	var i: int = clampi(paso, 0, CADENA.size() - 1)
	_una_pasada(CADENA[i])


func golpe_cargado() -> void:
	_una_pasada(CARGADO)


func _corriendo_o_en_el_aire() -> bool:
	if not _jugador.is_on_floor():
		return true
	var v := _jugador.velocity
	var plano := Vector2(v.x, v.z).length()
	var tope: float = _jugador.get("run_speed") if "run_speed" in _jugador else 7.5
	return plano >= tope * UMBRAL_CORRER


## Reproduce un clip de una sola pasada. Mientras dure, _process no toca nada.
func _una_pasada(nombre: String) -> void:
	if _anim == null or not _anim.has_animation(nombre):
		return
	_unica = nombre
	_anim.play(nombre)


func _al_terminar(nombre: StringName) -> void:
	if String(nombre) == _unica:
		_unica = ""


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
