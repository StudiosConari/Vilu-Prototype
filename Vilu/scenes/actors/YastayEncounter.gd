@tool
extends Node3D

## Beat 6 — Encuentro con el Yastay (guanaco gigante sagrado).
##
## FLUJO:
##   1. Se ve al Yastay luchando contra cazadores que atacaban a sus guanacos.
##      Uno de los guanacos queda herido en el suelo.
##   2. El Yastay derrota a todos los cazadores (automático).
##   3. El Yastay nos ve y nos ataca. Emilia esquiva. Benjamín cura al herido.
##   4. Al curar al guanaco, el Yastay se calma y da la Bendición del Guanaco
##      a Benjamín (Q = montar, G = embestir).

const POSE := preload("res://scenes/core/PoseAnimada.gd")
const INTERACT_SCR := preload("res://scenes/actors/Interactable.gd")
const BALLOON      := "res://scenes/ui/GloboDeDialogo.tscn"

const TALK_BLESSING := "~ start
Yastay: Alto. Bajad las armas.
Yastay: Has demostrado que no eras como esos cazadores.
Yastay: Recuperaste a un guanaco de mi rebaño, y al parecer quiere ser tu amigo.
Yastay: Puedes llevarlo contigo, arquero. Que te guarde el camino.
Benjamín: Gracias, Yastay.
=> END
"

const TALK_FRAG2 := "~ start
Benjamín: Esperá... este cazador llevaba algo escondido.
Benjamín: Acá está la segunda pieza, la que necesita la Bruja.
Emilia: Es igual a la que sacamos de la mina. Deberíamos llevársela.
=> END
"

enum Phase { INTRO, HUNTING, AGGRESSIVE, RESOLVED }
var _phase := Phase.INTRO

var _yastay: Node3D = null
var _yastay_label: Label3D = null
var _hunters: Array = []
var _inspected: Array = []
var _wounded: Node3D = null
## Los guanacos que hay que sanar, y los que ya se sanaron.
var _heridos: Array = []
var _sanados: Array = []
var _wound_healed := false
var _yastay_stomp_cd := 0.0
var _brujo: Node3D = null
var _iniciado := false   # la secuencia ya arrancó (no se repite al volver)
var _en_zona := false    # el jugador está dentro de la quebrada

## Dónde estaba el Yastay antes de perseguir a nadie. Al calmarse vuelve ahí,
## junto a su rebaño, en vez de quedarse plantado encima del jugador.
var _yastay_origen := Transform3D.IDENTITY
## Lo mismo pero en coordenadas de MUNDO, para la correa: quien mueve al Yastay
## trabaja en global, y mezclar los dos espacios lo mandaba a otra región.
var _yastay_casa := Vector3.ZERO

## Cuánto se corrió la arena respecto de las coordenadas con que se escribió
## esta escena. Sale de dónde está el modelo del Yastay puesto a mano, y se le
## suma al resto del reparto para que no queden todos en el sitio viejo.
var _desplazamiento := Vector3.ZERO


## Apoya en el suelo a los actores que genera este script.
##
## Sus posiciones están escritas con y=0, que era la altura del greybox. Sobre
## el terreno esculpido de la arena eso los deja ENTERRADOS —casi un metro— y no
## se corrige solo: son Node3D con una malla, sin cuerpo físico, así que no caen.
##
## Sólo se tocan las cápsulas. Los modelos adoptados los colocaste vos a mano y
## ya están a su altura; bajarlos sería estropear tu trabajo.
func _apoyar_en_el_suelo() -> void:
	var esp := get_world_3d().direct_space_state
	if esp == null:
		return
	for c in get_children():
		if not (c is Node3D) or not _es_capsula(c):
			continue
		var p: Vector3 = (c as Node3D).global_position
		var q := PhysicsRayQueryParameters3D.create(
			p + Vector3.UP * 40.0, p + Vector3.DOWN * 40.0)
		q.collision_mask = 1          # el terreno
		var r := esp.intersect_ray(q)
		if not r.is_empty():
			(c as Node3D).global_position = r["position"]


func _es_capsula(n: Node) -> bool:
	for h in n.get_children():
		if h is MeshInstance3D and (h as MeshInstance3D).mesh is CapsuleMesh:
			return true
	return false


## TODOS los modelos colocados a mano cuyo nombre empieza así.
func _modelos_con_prefijo(prefijo: String) -> Array:
	var out: Array = []
	for c in get_children():
		if not (c is Node3D) or not c.name.begins_with(prefijo):
			continue
		var es_capsula := false
		for h in c.get_children():
			if h is MeshInstance3D and (h as MeshInstance3D).mesh is CapsuleMesh:
				es_capsula = true
		if not es_capsula:
			out.append(c)
	return out


## Primer hijo de la zona cuyo nombre empieza así y que NO es una cápsula de
## greybox: o sea, un modelo colocado a mano.
func _modelo_con_prefijo(prefijo: String) -> Node3D:
	for c in get_children():
		if not (c is Node3D) or not c.name.begins_with(prefijo):
			continue
		var es_capsula := false
		for h in c.get_children():
			if h is MeshInstance3D and (h as MeshInstance3D).mesh is CapsuleMesh:
				es_capsula = true
		if not es_capsula:
			return c
	return null


## Le cuelga un cartel a un modelo adoptado, igual al que _npc le pone a las
## cápsulas. Hace falta porque el resto del guion busca ese Label3D por nombre
## para ir cambiándole el texto ("¡Intruso!", "¡El brujo huye!"...).
func _cartel_para(nodo: Node3D, texto: String, escala: float) -> Label3D:
	var existente := nodo.get_node_or_null("Label3D") as Label3D
	if existente != null:
		return existente
	var lbl := Label3D.new()
	lbl.name = "Label3D"
	lbl.text = texto
	lbl.font_size = 22
	lbl.position.y = 1.9 * escala
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nodo.add_child(lbl)
	return lbl



## Deja de generar el decorado por código: ya está guardado como nodos.
##
## Se tilda DESPUÉS de correr tools/fijar_geometria.gd, que adopta los nodos
## generados dándoles `owner`. Con la bandera puesta el script no vuelve a
## construir encima, y el decorado pasa a editarse a mano en el editor.
##
## El orden importa: tildarla antes de correr la herramienta deja la zona sin
## geometría que adoptar.
@export var geometria_fijada: bool = false


func _ready() -> void:
	# Sólo el DECORADO se salta cuando ya está fijado. Los personajes tienen que
	# nacer igual: son actores, no escenografía, y quedaron fuera del horneado.
	if not geometria_fijada:
		_build_arena()
	_spawn_characters()
	# Recién ahora: _spawn_characters es quien adopta el modelo del Yastay, que
	# es el respaldo si esta quebrada no tuviera anillo de monolitos.
	centro_de_zona = _centro_de_la_arena()
	radio_de_zona = radio_de_activacion
	# Diferido: en _ready() el espacio físico todavía no acepta consultas.
	if not Engine.is_editor_hint():
		_apoyar_en_el_suelo.call_deferred()
	# En el editor queda ahí quieto: la secuencia arranca sólo con activate(),
	# que llama WorldRoot cuando el jugador entra a la quebrada.


## MUNDO ABIERTO: la escena existe desde que arranca la partida, así que la
## secuencia NO puede dispararse en _ready() — el Yastay derrotaría a los
## cazadores mientras el jugador todavía está en La Tirana.
## WorldRoot llama a esto cuando el jugador entra a la quebrada.
func activate() -> void:
	_en_zona = true
	if _iniciado:
		return
	_iniciado = true
	_hint("Los cazadores atacan al Yastay y sus guanacos…")
	get_tree().create_timer(1.5).timeout.connect(_begin_hunt)


## El jugador se fue de la zona: el Yastay deja de perseguirlo.
func deactivate() -> void:
	_en_zona = false


# ─── Fases ────────────────────────────────────────────────────────────────────

func _begin_hunt() -> void:
	_phase = Phase.HUNTING
	await _escena_de_presentacion()
	_begin_aggressive()


## La presentación del Yastay, contada con la cámara.
##
## Antes todo esto pasaba a espaldas del jugador: los cazadores caían por
## temporizador mientras la cámara seguía al personaje, y cuando llegabas a la
## quebrada ya estaba todo tirado en el suelo y el brujo se había ido. Lo que se
## ve ahora es la pelea: la cámara va al Yastay, acompaña a cada cazador que
## cae, sigue al brujo que escapa, se planta en el Yastay, y RECIÉN entonces
## vuelve al jugador y empieza el ataque.
##
## Durante la escena se le quita el control al jugador. Si no, se puede caminar
## fuera del cuadro —o meterse en la pelea— mientras la cámara mira para otro
## lado, y al devolverla el personaje no está donde la escena lo dejó.
func _escena_de_presentacion() -> void:
	var juego := get_tree().get_first_node_in_group("game")
	var con_camara: bool = juego != null and juego.has_method("focus_camera_on")
	_trabar_a_los_jugadores(true)

	# Plano general de la quebrada, y el Yastay se alza: es su presentación.
	if con_camara and is_instance_valid(_yastay):
		juego.focus_camera_on(_yastay, 0.0, 16.0, 3.0)
	var sitio_del_yastay := _yastay.global_position if is_instance_valid(_yastay) else Vector3.ZERO
	await get_tree().create_timer(_yastay_hace("Rear", false, 1.2)).timeout

	# Uno por uno: TROTA hasta el cazador, le da un cabezazo y ése cae. La cámara
	# se acerca antes del golpe, para que se vea la caída entera y no el cuerpo
	# ya en el suelo.
	for i in _hunters.size():
		var h: Node3D = _hunters[i]
		if not is_instance_valid(h):
			continue
		if con_camara:
			juego.focus_camera_on(h, 0.0, 9.0, 1.6)
		await _yastay_trota_hasta(h.global_position)
		# El cabezazo primero, y el cazador cae CUANDO le llega: si cayera antes,
		# el Yastay embestiría a un cuerpo que ya está en el suelo.
		var golpe := _yastay_hace("Head_But", false, 1.0)
		await get_tree().create_timer(golpe * MOMENTO_DEL_CABEZAZO).timeout
		_defeat_hunter(i)
		await get_tree().create_timer(golpe * (1.0 - MOMENTO_DEL_CABEZAZO)).timeout

		await get_tree().create_timer(0.8).timeout

	# El brujo, que los dirigía desde atrás, arranca.
	if is_instance_valid(_brujo):
		if con_camara:
			juego.focus_camera_on(_brujo, 0.0, 11.0, 2.0)
		await get_tree().create_timer(0.6).timeout
	# La cámara lo acompaña hasta el PUENTE, no hasta el final.
	#
	# El camino del brujo tiene varios tramos y el último es un tirón largo por
	# el otro lado de la quebrada, con él ya de espaldas y cada vez más chico:
	# ahí la escena ya contó lo que tenía que contar y se hacía eterna. Se le
	# suelta la cámara al llegar al puente y el resto lo hace por su cuenta,
	# fuera de plano.
	_brujo_escapes()
	await _esperar_al_puente()

	# Vuelve CAMINANDO a su sitio: ya no hay prisa, la quebrada es suya otra vez.
	if con_camara and is_instance_valid(_yastay):
		juego.focus_camera_on(_yastay, 0.0, 13.0, 3.0)
	await _yastay_camina_hasta(sitio_del_yastay)
	# Y mirando al puente, que es por donde se fue el brujo y por donde se
	# entra a la quebrada. Caminar hasta un punto lo deja mirando el rumbo que
	# traía, que no tiene por qué ser ése.
	_mirar_al_puente()

	# Y se alza una segunda vez: ahora el intruso sos vos.
	await get_tree().create_timer(_yastay_hace("Rear", false, 1.2)).timeout

	if con_camara:
		juego.clear_camera_focus()
	# La cámara vuelve sola, pero interpolando: se le da el viaje antes de
	# devolver el control y antes de que el Yastay ataque, o el primer golpe cae
	# con la imagen todavía en camino.
	await get_tree().create_timer(1.2).timeout
	_trabar_a_los_jugadores(false)


## Cuánto se le sigue al brujo antes de soltarle la cámara, como fracción de su
## camino. 0.5 = hasta la mitad, que es donde está el puente.
@export_range(0.1, 1.0, 0.05) var brujo_seguido_hasta := 0.5

## Lo más que se le espera aunque no llegue, en segundos. Es una red: sin esto,
## un camino mal puesto dejaría la escena colgada para siempre.
const ESPERA_MAXIMA_DEL_BRUJO := 9.0


## Espera a que el brujo llegue al puente —la mitad de su camino— y devuelve.
##
## Él sigue huyendo por su cuenta después: la escena continúa sin esperarlo.
func _esperar_al_puente() -> void:
	var camino := _camino_del_brujo()
	if camino.is_empty() or not is_instance_valid(_brujo):
		await get_tree().create_timer(2.0).timeout
		return
	var puente: Vector3 = camino[mini(int(camino.size() * brujo_seguido_hasta), camino.size() - 1)]
	var reloj := 0.0
	while is_instance_valid(_brujo) and reloj < ESPERA_MAXIMA_DEL_BRUJO:
		if _brujo.global_position.distance_to(puente) < 1.5:
			return
		await get_tree().process_frame
		reloj += get_process_delta_time()


## Lo deja mirando hacia el puente por el que se entra a la quebrada.
func _mirar_al_puente() -> void:
	if not is_instance_valid(_yastay):
		return
	var camino := _camino_del_brujo()
	if camino.is_empty():
		return
	_orientar(_yastay, camino[0] - _yastay.global_position)


## En qué punto del cabezazo cae el cazador. El clip dura un segundo y el
## impacto está a media embestida: si el cazador cayera al empezar, el Yastay
## acabaría embistiendo a un cuerpo que ya está en el suelo.
const MOMENTO_DEL_CABEZAZO := 0.55

## A qué velocidad trota y camina, en metros por segundo.
@export var yastay_trote := 7.0
@export var yastay_paso := 2.6
## Cuántos metros se queda del cazador al llegar: lo justo para cabecearlo sin
## metérsele dentro.
@export var yastay_distancia_de_golpe := 2.4


## Le pone un clip al Yastay y devuelve lo que dura, o `minimo` si no lo tiene.
func _yastay_hace(clip: String, en_bucle: bool, minimo := 0.0) -> float:
	if not is_instance_valid(_yastay):
		return minimo
	var t := _clip(_yastay, clip, en_bucle)
	return t if t > 0.0 else minimo


## Lo lleva hasta un punto con el clip que toque, y espera a que llegue.
##
## Se queda a `yastay_distancia_de_golpe` del destino y encara hacia allá: es un
## ave de dos metros, y plantarla EN la coordenada del cazador la deja
## atravesándolo.
func _yastay_va_a(destino: Vector3, clip: String, velocidad: float, margen := 0.0) -> void:
	if not is_instance_valid(_yastay):
		return
	var d := destino - _yastay.global_position
	d.y = 0.0
	var lejos := d.length()
	if lejos > 0.05:
		_encarar(d.normalized())
	var meta := destino
	if margen > 0.0 and lejos > margen:
		meta = _yastay.global_position + d.normalized() * (lejos - margen)
	meta.y = _yastay.global_position.y
	var recorrido := (meta - _yastay.global_position).length()
	if recorrido < 0.05:
		return
	_yastay_hace(clip, true)
	var tw := get_tree().create_tween()
	tw.tween_property(_yastay, "global_position", meta,
		recorrido / maxf(velocidad, 0.1))
	await tw.finished
	_yastay_hace("Idle", true)


func _yastay_trota_hasta(destino: Vector3) -> void:
	# Se para a un cuerpo de distancia: va a cabecearlo, no a atropellarlo.
	await _yastay_va_a(destino, "Trot", yastay_trote, yastay_distancia_de_golpe)


func _yastay_camina_hasta(destino: Vector3) -> void:
	# Sin margen: a su sitio vuelve exactamente, que es de donde salió.
	await _yastay_va_a(destino, "Walk", yastay_paso)


## Quita o devuelve el control a los dos protagonistas.
func _trabar_a_los_jugadores(trabado: bool) -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if "input_locked" in p:
			p.input_locked = trabado


## Cuánto se queda en el suelo antes de levantarse a huir, en segundos.
##
## El clip de derrota dura seis segundos y los últimos cuatro es él tendido sin
## moverse: se corta en cuanto termina la caída.
@export var brujo_tiempo_caido := 2.6
## A qué velocidad se va, en metros por segundo.
##
## Va HERIDO: 6,5 era una carrera de atleta con la animación de alguien que
## apenas puede andar, y los pies patinaban por el suelo.
@export var brujo_velocidad := 2.2
## Cuántos metros se aleja si NO le pusiste un camino. Con camino manda el
## camino y este número no se usa.
@export var brujo_distancia := 30.0
## Grados que se le suman al orientarlo.
##
## Cero porque su frente es +Z, y eso está MEDIDO sobre el propio esqueleto: del
## talón a los dedos, el rig apunta a (0.14, 0.99). No es el 180 que llevan
## Emilia o Carmen: aquél gira el modelo DENTRO de un cuerpo que ya mira a -Z,
## y aquí se orienta el nodo directamente hacia un rumbo del mundo.
##
## Si algún día se reexporta el modelo del revés, este es el número a cambiar.
@export var brujo_giro := 0.0
## Por dónde se va.
##
## Apuntá acá a un nodo con Marker3D adentro y los recorre EN ORDEN; si el nodo
## no tiene hijos, va derecho hasta él. Vacío quiere decir que tira hacia la
## entrada de la quebrada, que es por donde se llega.
@export var salida_del_brujo: NodePath


## El brujo dirigía a los cazadores desde atrás. Al ver que el Yastay los
## derrota: apunta al jugador furioso, cae derrotado y sale corriendo herido.
##
## Antes se deslizaba en diagonal encogiéndose hasta desaparecer, que era el
## apaño de cuando era una cápsula sin esqueleto. Ahora el modelo trae sus tres
## clips y la escena son esos tres momentos, en ese orden.
func _brujo_escapes() -> void:
	if not is_instance_valid(_brujo):
		return
	_banner("¡Alguien los estaba dirigiendo desde atrás… y está huyendo!", 4.0)
	var lbl := _brujo.get_node_or_null("Label3D") as Label3D
	if lbl:
		lbl.text = "¡El brujo huye!"

	if _animador_de(_brujo) == null:
		# Cápsula de greybox: sin esqueleto no hay escena que representar.
		_huir_sin_animacion()
		return

	# 1. Cae, de cara al jugador.
	#
	# Antes, antes de caer, apuntaba furioso al jugador durante todo su clip. Eran
	# tres animaciones seguidas para decir una sola cosa —que perdió y se va— y se
	# hacía largo: el jugador ya está mirando al Yastay, no a él. Se queda el
	# giro, que es lo que hace que la caída se lea, pero no la espera.
	var p := _jugador_mas_cercano(_brujo.global_position)
	if p != null:
		_orientar(_brujo, p.global_position - _brujo.global_position)
	_clip(_brujo, "derrotado", false)
	await get_tree().create_timer(brujo_tiempo_caido).timeout

	# 3. Se levanta y se va herido, tramo por tramo.
	_clip(_brujo, "correr_herido", true)
	var camino := _camino_del_brujo()
	if camino.is_empty():
		# Sin camino puesto: tira en línea recta hacia la salida, como antes.
		var rumbo := _rumbo_de_huida()
		_orientar(_brujo, rumbo)
		camino.append(_brujo.global_position + rumbo * brujo_distancia)
	for meta in camino:
		if not is_instance_valid(_brujo):
			return
		await _brujo_va_hasta(meta)
	# Se esconde antes de liberarlo: la cámara todavía lo está mirando y soltarle
	# el nodo de golpe la haría saltar al jugador.
	if is_instance_valid(_brujo):
		_brujo.visible = false
		_brujo.queue_free()


## Los puntos por los que se va, en orden.
##
## Si el nodo que asignaste tiene hijos, ésos son el camino; si no, el nodo es
## el único destino. Vacío quiere decir "no hay camino puesto".
##
## Hace falta un camino y no un rumbo porque la salida de la quebrada es un
## puente: en línea recta el brujo se iba por encima de las rocas y del vacío,
## que es lo que hacía antes.
func _camino_del_brujo() -> Array[Vector3]:
	var pasos: Array[Vector3] = []
	var n := get_node_or_null(salida_del_brujo) as Node3D
	if n == null:
		return pasos
	for h in n.get_children():
		if h is Node3D:
			pasos.append((h as Node3D).global_position)
	if pasos.is_empty():
		pasos.append(n.global_position)
	return pasos


## Un tramo: lo gira hacia donde va y lo lleva pisando el suelo.
##
## Se mueve con `tween_method` y no con `tween_property` para poder apoyarlo en
## el terreno en cada paso: yendo en línea recta de un punto a otro se metía por
## dentro del puente y salía por encima de las piedras.
func _brujo_va_hasta(meta: Vector3) -> void:
	var desde: Vector3 = _brujo.global_position
	var d := meta - desde
	d.y = 0.0
	if d.length() < 0.2:
		return
	_orientar(_brujo, d)
	var tw := get_tree().create_tween()
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(_brujo):
			return
		_brujo.global_position = _apoyar(desde.lerp(meta, t)),
		0.0, 1.0, d.length() / maxf(brujo_velocidad, 0.1))
	await tw.finished


## El mismo punto, pero a ras de suelo.
##
## El rayo sale de DOS METROS Y MEDIO por encima y baja seis: desde más arriba
## engancharía el arco del puente en vez del tablero, y desde más abajo se
## perdería el escalón al subir a él.
func _apoyar(p: Vector3) -> Vector3:
	var esp := get_world_3d().direct_space_state
	if esp == null:
		return p
	var q := PhysicsRayQueryParameters3D.create(
		p + Vector3.UP * 2.5, p + Vector3.DOWN * 3.5)
	q.collision_mask = 1
	var r := esp.intersect_ray(q)
	return r["position"] if not r.is_empty() else p


## Hacia dónde huye: al marcador si lo pusiste, y si no hacia la entrada de la
## quebrada, que es por donde se llega y la única salida que hay.
func _rumbo_de_huida() -> Vector3:
	var meta: Node3D = get_node_or_null(salida_del_brujo) as Node3D
	if meta == null:
		meta = get_node_or_null("PlayerSpawn") as Node3D
	var d := Vector3.ZERO
	if meta != null and is_instance_valid(_brujo):
		d = meta.global_position - _brujo.global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else -global_transform.basis.z


## Lo gira para que MIRE hacia ahí, con la media vuelta de los modelos.
##
## El rumbo viene en coordenadas del MUNDO y `rotation.y` se mide respecto del
## PADRE. La quebrada está girada 90° en la escena, así que escribir el ángulo
## del mundo tal cual dejaba al brujo caminando de lado, mirando a noventa
## grados de por donde iba. Se pasa el rumbo al sistema del padre antes.
func _orientar(nodo: Node3D, hacia: Vector3) -> void:
	hacia.y = 0.0
	if hacia.length() < 0.01:
		return
	var padre := nodo.get_parent() as Node3D
	var rumbo := hacia
	if padre != null:
		rumbo = padre.global_transform.basis.inverse() * hacia
	rumbo.y = 0.0
	if rumbo.length() < 0.001:
		return
	nodo.rotation.y = atan2(rumbo.x, rumbo.z) + deg_to_rad(brujo_giro)


## Reproduce un clip suyo y devuelve lo que dura. 0 si no lo tiene.
func _clip(nodo: Node3D, nombre: String, en_bucle: bool) -> float:
	var ap := _animador_de(nodo)
	if ap == null or not ap.has_animation(nombre):
		return 0.0
	var a := ap.get_animation(nombre)
	a.loop_mode = Animation.LOOP_LINEAR if en_bucle else Animation.LOOP_NONE
	# Si ya lo está haciendo, no se vuelve a lanzar: la persecución pide "Trot"
	# en cada cuadro, y relanzarlo lo dejaría congelado en el primer fotograma.
	if ap.assigned_animation != nombre or not ap.is_playing():
		ap.play(nombre)
	return a.length


## El héroe que tenga más cerca. Se apunta al que está delante, no al que lleve
## el mando: si vas con Emilia y Benjamín se quedó atrás, el brujo señala a
## quien tiene enfrente.
func _jugador_mas_cercano(desde: Vector3) -> Node3D:
	var mejor: Node3D = null
	var mejor_d := INF
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p) or not (p is Node3D):
			continue
		var d: float = desde.distance_squared_to((p as Node3D).global_position)
		if d < mejor_d:
			mejor_d = d
			mejor = p
	return mejor


func _animador_de(n: Node) -> AnimationPlayer:
	for h in n.get_children():
		if h is AnimationPlayer:
			return h
		var x := _animador_de(h)
		if x != null:
			return x
	return null


## Lo de antes, para cuando el brujo es una cápsula sin esqueleto.
func _huir_sin_animacion() -> void:
	var tw := get_tree().create_tween()
	tw.tween_property(_brujo, "position",
		_brujo.position + Vector3(-9.0, 0.0, -9.0), 1.8)
	tw.parallel().tween_property(_brujo, "scale", Vector3.ZERO, 1.8)
	tw.tween_callback(_brujo.queue_free)


## El Yastay derriba al cazador: queda TENDIDO en el suelo y se puede revisar [E].
func _defeat_hunter(idx: int) -> void:
	if idx >= _hunters.size() or not is_instance_valid(_hunters[idx]):
		return
	var h: Node3D = _hunters[idx]

	# Si el cazador tiene su animación de derrota, cae con ella. Girarlo 90° era
	# el apaño de las cápsulas: sobre un modelo de verdad se ve como un muñeco
	# volcado, no como alguien que cae.
	if not POSE.poner(h, "derrotad", false):
		var tw := get_tree().create_tween()
		tw.tween_property(h, "rotation:z", PI / 2.0, 0.35)
		# La altura sólo se toca en las cápsulas. El 0.30 de siempre es absoluto y
		# suponía el suelo en y=0; sobre el terreno esculpido hundiría a un modelo
		# puesto a mano. Al girar 90° el cuerpo ya queda tendido sin bajarlo.
		if _es_capsula(h):
			tw.parallel().tween_property(h, "position:y", 0.30, 0.35)

	var lbl := h.get_node_or_null("Label3D") as Label3D
	if lbl:
		lbl.text     = "Cuerpo de cazador"
		lbl.modulate = Color(0.75, 0.70, 0.65)

	# Zona de interacción para registrar el cuerpo
	var zone             := Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask  = 2
	zone.set_script(INTERACT_SCR)
	zone.prompt          = "[E] Revisar cuerpo"
	h.add_to_group("objetivo_cazadores")
	h.add_child(zone)

	var cs  := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.0
	cs.shape   = sph
	zone.add_child(cs)

	zone.interacted.connect(_on_inspect.bind(h, zone))


## Revisar un cuerpo. Al revisar TODOS aparece el 2º fragmento del talismán.
func _on_inspect(player: Node, body: Node3D, zone: Area3D) -> void:
	if body in _inspected:
		return
	_inspected.append(body)
	body.remove_from_group("objetivo_cazadores")

	var lbl := body.get_node_or_null("Label3D") as Label3D
	if lbl:
		lbl.text     = "Revisado"
		lbl.modulate = Color(0.45, 0.45, 0.45)

	# Desactivar la zona: ya fue revisada
	zone.set_deferred("monitoring", false)
	if player and player.has_method("clear_interactable"):
		player.clear_interactable(zone)

	# Se avisa de cuántos van EN TOTAL, no de "uno más". Sumando de a uno, un
	# aviso que llegue antes de que la misión esté activa —los cuerpos se pueden
	# revisar mientras todavía corre la de los guanacos— descuadra el contador
	# para siempre y deja la cadena colgada en 3/4.
	Misiones.contar("cazadores", _inspected.size())
	var total := _hunters.size()
	if _inspected.size() < total:
		_banner("Cuerpos revisados: %d/%d" % [_inspected.size(), total], 2.5)
		return

	# Todos revisados -> segundo fragmento
	if not GameManager.has_ability("talisman_frag_2"):
		GameManager.unlock("talisman_frag_2")
	_hint("Llevá el talismán a la Bruja en el poblado.")
	var res := DialogueManager.create_resource_from_text(TALK_FRAG2)
	DialogueManager.show_dialogue_balloon_scene(BALLOON, res, "start")


func _begin_aggressive() -> void:
	_phase = Phase.AGGRESSIVE
	# Se anota AQUÍ, justo antes de la primera persecución, y no al nacer: si se
	# tomara antes, el apoyo en el suelo todavía no habría corrido y el sitio
	# guardado sería el de la cápsula enterrada.
	if is_instance_valid(_yastay):
		_yastay_origen = _yastay.transform
		_yastay_casa = _yastay.global_position
	if is_instance_valid(_yastay_label):
		_yastay_label.text = "Yastay\n¡Intruso!"
	_banner("¡El Yastay os ve! Emilia: esquiva sus cargas. Benjamín: sana al guanaco herido.", 6.0)
	_hint("Emilia esquiva. Benjamín acércate al guanaco herido.")


func _process(delta: float) -> void:
	# Sin el guardia de _en_zona el Yastay seguiría persiguiendo al jugador a
	# través de todo el mapa después de que se fue de la quebrada.
	if _en_zona and _phase == Phase.AGGRESSIVE:
		_yastay_think(delta)


func _yastay_think(delta: float) -> void:
	if not is_instance_valid(_yastay):
		return
	var target := _active_player()
	if target == null:
		return
	var to_t := target.global_position - _yastay.global_position
	to_t.y = 0.0
	var dist := to_t.length()

	# Persecución lenta pero amenazante. Trota mientras avanza y se queda quieto
	# al alcanzarte: sin esto perseguía deslizándose, con las patas clavadas.
	if dist > 2.0:
		_yastay.global_position += to_t.normalized() * 3.8 * delta
		_yastay_hace("Trot", true)
	else:
		_yastay_hace("Idle", true)

	# La correa: es un guardián de SU quebrada, no un perseguidor. Sin esto
	# bastaba con salir corriendo para arrastrarlo hasta el poblado, porque el
	# guardia de `_en_zona` sólo lo frena cuando el mundo avisa de que saliste
	# de la zona, y eso llega tarde o no llega. El tope es geométrico y no
	# depende de que nadie avise.
	_atar_a_su_sitio()

	if dist > 0.5:
		_encarar(to_t.normalized())

	# Golpe al alcanzar al jugador: primero se MARCA dónde va a caer, y recién
	# después cae.
	_yastay_stomp_cd = max(0.0, _yastay_stomp_cd - delta)
	if dist < distancia_del_golpe and _yastay_stomp_cd <= 0.0:
		_yastay_stomp_cd = aviso_del_golpe + descanso_del_golpe
		_golpear()


# ─── El golpe del Yastay ──────────────────────────────────────────────────────
#
# Antes el golpe era instantáneo: en cuanto te ponías a menos de dos metros y
# medio, 25 de daño, y el cartel decía "¡Esquiva!" cuando ya te había dado. No
# había nada que esquivar. Ahora marca en el suelo dónde va a pisar, te da un
# segundo largo para salir, y sólo entonces pega —y sólo a quien siga dentro.

## Cuánto tiempo tenés para salirte, en segundos.
@export var aviso_del_golpe := 1.2
## Radio de la zona que machaca, en metros.
@export var radio_del_golpe := 2.6
## Cuánto por delante de él cae, medido de su centro al centro de la zona.
@export var alcance_del_golpe := 2.2
## A qué distancia se decide a golpear.
@export var distancia_del_golpe := 4.5
## Lo que quita si te pilla dentro.
@export var dano_del_golpe := 25.0
## Lo que descansa entre un golpe y el siguiente, además del aviso.
@export var descanso_del_golpe := 1.6


## Marca la zona, espera, y pega a quien siga ahí.
func _golpear() -> void:
	if not is_instance_valid(_yastay):
		return
	# El frente de este modelo es +Z: `_encarar` lo deja mirando así.
	var frente: Vector3 = _yastay.global_transform.basis.z.normalized()
	frente.y = 0.0
	var centro: Vector3 = _yastay.global_position + frente.normalized() * alcance_del_golpe
	centro.y = _yastay.global_position.y

	_yastay_hace("Head_But", false)
	_banner("¡El Yastay va a pisar! ¡Salí de ahí!", aviso_del_golpe + 0.4)
	var marca := _marcar_el_suelo(centro, radio_del_golpe, aviso_del_golpe)

	await get_tree().create_timer(aviso_del_golpe).timeout
	if is_instance_valid(marca):
		marca.queue_free()
	if _phase != Phase.AGGRESSIVE:
		return

	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p) or not (p is Node3D):
			continue
		var d: Vector3 = (p as Node3D).global_position - centro
		d.y = 0.0
		if d.length() > radio_del_golpe:
			continue
		if p.has_method("take_damage"):
			p.take_damage(dano_del_golpe)


## El círculo rojo en el suelo. Crece durante el aviso: se ve cuánto queda.
func _marcar_el_suelo(centro: Vector3, radio: float, dura: float) -> Node3D:
	var mi := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = radio
	disco.bottom_radius = radio
	disco.height = 0.06
	mi.mesh = disco
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.15, 0.1, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	add_child(mi)
	mi.global_position = centro + Vector3(0.0, 0.05, 0.0)
	# De un punto a todo el círculo en lo que dura el aviso: el borde llegando
	# al filo ES la cuenta atrás, sin números en pantalla.
	mi.scale = Vector3(0.05, 1.0, 0.05)
	var tw := get_tree().create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, dura)
	return mi


## Radio, en metros, del territorio del Yastay: hasta dónde se aleja del sitio
## donde estaba cuando te vio. El anillo de monolitos mide 11 m de radio, así
## que con esto llega a cualquier rincón de la quebrada y a ninguno de fuera.
@export var correa := 22.0


## Radio, en metros, dentro del cual EMPIEZA el encuentro.
##
## Se mide desde el centro del anillo de monolitos, no desde este nodo: el nodo
## está plantado al oeste, al pie del puente, y el catálogo de ZONAS le daba 34
## metros desde ahí. Eso llegaba hasta el poblado, y por eso la escena arrancaba
## estando en el bar.
##
## Con 16 m el disparo cae a mitad del puente: el anillo mide 11 de radio y el
## puente se extiende hasta 18,6 desde ese centro.
@export var radio_de_activacion := 16.0

## Lo lee WorldRoot para saber DÓNDE y con qué radio activar esta zona, en vez
## del sitio del nodo y el radio del catálogo. Se rellenan en _ready().
var centro_de_zona := Vector3.ZERO
var radio_de_zona := 0.0


## El centro real de la quebrada: el del anillo de monolitos.
##
## Se toma el centro de su caja envolvente y no el promedio de los monolitos:
## el anillo no está repartido parejo y el promedio se corre hacia el lado que
## tiene más piedras.
func _centro_de_la_arena() -> Vector3:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c in get_children():
		if not (c is Node3D) or not String(c.name).begins_with("monolito"):
			continue
		var p: Vector3 = (c as Node3D).global_position
		lo = lo.min(Vector2(p.x, p.z))
		hi = hi.max(Vector2(p.x, p.z))
	if lo.x == INF:
		# Sin anillo, el mejor sitio que queda es el propio Yastay.
		if is_instance_valid(_yastay):
			return _yastay.global_position
		return global_position
	var m := (lo + hi) * 0.5
	return Vector3(m.x, global_position.y, m.y)


## Lo devuelve al borde de su territorio si se pasó persiguiendo.
##
## Se corrige la posición en vez de frenar la persecución: frenarla lo dejaría
## plantado mirando el límite, y así sigue encarando y amenazando desde el borde
## —que es lo que hace un animal que defiende un sitio—.
func _atar_a_su_sitio() -> void:
	if not is_instance_valid(_yastay):
		return
	# En coordenadas de MUNDO, igual que `_yastay_think`, que es quien lo mueve.
	# `_yastay_origen` NO sirve acá: guarda la transformación LOCAL —la que
	# necesita `_volver_a_su_sitio` para el tween de "position"— y restarla de la
	# global daba un vector de 130 m, o sea "siempre fuera", y la correa mandaba
	# al bicho a 22 m del origen del mapa: desaparecía de la quebrada.
	var fuera := _yastay.global_position - _yastay_casa
	fuera.y = 0.0
	if fuera.length() <= correa:
		return
	var borde := _yastay_casa + fuera.normalized() * correa
	# La altura no se toca: la manda el terreno, no la correa.
	borde.y = _yastay.global_position.y
	_yastay.global_position = borde


## Gira el Yastay para que MIRE hacia `dir`.
##
## `look_at` apunta el -Z del nodo al objetivo, pero los modelos de este proyecto
## miran hacia +Z: usándolo a secas, el bicho persigue de espaldas y cocea con
## las patas traseras. Es el mismo motivo por el que Enemy.gd tiene su
## `giro_modelo = 180`.
func _encarar(dir: Vector3) -> void:
	if not is_instance_valid(_yastay) or dir.length() < 0.01:
		return
	_yastay.look_at(_yastay.global_position + dir, Vector3.UP)
	_yastay.rotate_object_local(Vector3.UP, PI)


# ─── Curación ─────────────────────────────────────────────────────────────────

## Cuántos guanacos heridos hay que sanar, si no los marcaste vos.
const HERIDOS_POR_DEFECTO := 4


## Qué guanacos hay que sanar.
##
## Manda el grupo "guanaco_herido": seleccionás los que quieras en el editor,
## los metés al grupo y son ésos. Es lo mismo que se hace con "boca_mina" o
## "salida_mina", y no depende de nombres ni de cuántos haya.
##
## Si no marcaste ninguno se toman los CUATRO MÁS LEJANOS del Yastay. Hoy eso da
## exactamente los de los costados —los que estaban siendo cazados— porque el
## rebaño está apiñado junto a él: los de la manada quedan a 2-5 m y los otros a
## 9-12 m. Es una suposición razonable, no una regla: por eso avisa por consola
## cuáles eligió, para que se pueda corregir metiéndolos al grupo.
func _elegir_heridos() -> Array:
	var marcados: Array = []
	for c in get_children():
		if c is Node3D and c.is_in_group("guanaco_herido"):
			marcados.append(c)
	if not marcados.is_empty():
		return marcados

	var manada := _modelos_con_prefijo("guanaco")
	if manada.size() <= HERIDOS_POR_DEFECTO:
		return manada
	var centro: Vector3 = _yastay.position if is_instance_valid(_yastay) else Vector3.ZERO
	manada.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return Vector2(a.position.x - centro.x, a.position.z - centro.z).length() \
			> Vector2(b.position.x - centro.x, b.position.z - centro.z).length())
	var elegidos := manada.slice(0, HERIDOS_POR_DEFECTO)
	var nombres := []
	for e in elegidos:
		nombres.append(e.name)
	print(("[yastay] sin guanacos en el grupo 'guanaco_herido'; se toman los %d "
		+ "más lejanos: %s. Metelos al grupo para fijarlo.")
		% [HERIDOS_POR_DEFECTO, ", ".join(nombres)])
	return elegidos


## Le cuelga a un guanaco su zona de curación.
## La zona de sanar: se activa con [E], no con acercarse.
##
## Antes bastaba con pasarle por al lado y el guanaco quedaba sanado sin que lo
## hubieras decidido; con el Yastay persiguiéndote alrededor se sanaban los tres
## de casualidad mientras corrías. Sanar es un acto, y los actos van con la E.
func _zona_de_cura(g: Node3D) -> void:
	if g.has_node("ZonaCura"):
		return
	var area := Area3D.new()
	area.name = "ZonaCura"
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	area.set_script(INTERACT_SCR)
	area.prompt = "[E] Sanar al guanaco"
	g.add_child(area)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	# El radio va en las unidades del guanaco: si lo escalaste en el editor, la
	# zona lo acompaña en vez de quedarse gigante o diminuta.
	sph.radius = 2.2 / maxf(g.global_transform.basis.get_scale().y, 0.001)
	cs.shape = sph
	area.add_child(cs)
	area.interacted.connect(_on_heal_entered.bind(g))


func _on_heal_entered(body: Node3D, guanaco: Node3D = null) -> void:
	if _wound_healed or _phase != Phase.AGGRESSIVE:
		return
	if body == null or not body.is_in_group("player"):
		return
	# Sanar es lo suyo: Benjamín es el que sabe de animales. Con Emilia el aviso
	# dice qué falta, en vez de no pasar nada y parecer que la E está rota.
	if body.get("is_archer") != true:
		_banner("Sólo Benjamín puede sanar al guanaco. Cambiá con [T].", 2.5)
		return
	if guanaco == null:
		guanaco = _heridos[0] if not _heridos.is_empty() else null
	if guanaco == null or guanaco in _sanados:
		return

	_sanados.append(guanaco)
	guanaco.remove_from_group("objetivo_guanacos")
	Misiones.contar("guanacos", _sanados.size())
	_levantar(guanaco)
	if _sanados.size() < _heridos.size():
		_banner("Guanacos sanados: %d/%d" % [_sanados.size(), _heridos.size()], 2.5)
		return
	_heal()


## Un guanaco sanado: se incorpora y pierde el cartel de herido.
func _levantar(g: Node3D) -> void:
	if not is_instance_valid(g):
		return
	# Se incorpora de verdad: `lay_to_idle` es literalmente el gesto de pasar de
	# tumbado a de pie. Al terminarlo se queda respirando como los demás.
	#
	# Si algún día el modelo no lo trajera, se levanta desandando su propia
	# caída: `Death` al revés desde el último fotograma, que es exactamente en el
	# que lo dejó `_tumbar`.
	var alzarse := _clip(g, "lay_to_idle", false)
	if alzarse <= 0.0:
		alzarse = _desandar_la_caida(g)
	if alzarse > 0.0:
		get_tree().create_timer(alzarse).timeout.connect(func() -> void:
			if is_instance_valid(g):
				_clip(g, "Idle", true))
	# El tween se crea SÓLO si hay algo que animar: sin cápsula que enderezar ni
	# cartel que desvanecer se quedaba vacío, y un tween sin órdenes hace que el
	# motor se queje al procesarlo.
	var capsula := _es_capsula(g)
	var lbl := g.get_node_or_null("Label3D")
	if capsula or lbl != null:
		var tw := get_tree().create_tween()
		# La altura y el giro sólo se tocan en las cápsulas: los modelos los
		# pusiste vos de pie y en su sitio, y "incorporarlos" los movería sin
		# motivo. Ahora además se levantan con su propia animación.
		if capsula:
			tw.tween_property(g, "rotation:z", 0.0, 0.9)
		if lbl != null:
			tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.5)
	var z := g.get_node_or_null("ZonaCura") as Area3D
	if z != null:
		z.set_deferred("monitoring", false)


func _heal() -> void:
	_wound_healed = true
	_phase = Phase.RESOLVED
	_hint("Los guanacos se recuperan. El Yastay asiente…")

	# Los guanacos ya se levantaron uno a uno en _levantar(); acá sólo queda
	# cerrar la secuencia.

	# Yastay se calma
	if is_instance_valid(_yastay_label):
		_yastay_label.text = "Yastay"
	_volver_a_su_sitio()
	get_tree().create_timer(2.2).timeout.connect(_yastay_speaks)


## Segundos que tarda el Yastay en volver caminando a su sitio.
const REGRESO := 2.6


## Devuelve al Yastay adonde estaba antes de perseguirte, con su rebaño.
##
## Sin esto se queda plantado encima del jugador, en mitad de la arena y
## mirándolo, que es exactamente la pose de amenaza de la que acaba de salir.
func _volver_a_su_sitio() -> void:
	if not is_instance_valid(_yastay) or _yastay_origen == Transform3D.IDENTITY:
		return
	# Caminando, y al llegar en reposo. Sin esto se quedaba con el último clip
	# que le tocó en la persecución —el cabezazo, encabritado— y hablaba en esa
	# pose: alzado sobre el jugador, que es justo la amenaza de la que acaba de
	# salir.
	_yastay_hace("Walk", true)
	var tw := get_tree().create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_yastay, "position", _yastay_origen.origin, REGRESO)
	tw.parallel().tween_property(_yastay, "quaternion",
		_yastay_origen.basis.get_rotation_quaternion(), REGRESO)
	tw.finished.connect(func() -> void:
		if is_instance_valid(_yastay):
			_yastay_hace("Idle", true))


## El Yastay se acerca y habla. La bendición sólo llega al terminar el diálogo.
func _yastay_speaks() -> void:
	if is_instance_valid(_yastay):
		var target := _active_player()
		if target != null:
			var to_p := target.global_position - _yastay.global_position
			to_p.y = 0.0
			var stop := _yastay.global_position + to_p.normalized() * maxf(0.0, to_p.length() - 4.0)
			# MIRANDO al jugador, y andando.
			#
			# Antes sólo se le movía la posición: llegaba de espaldas o de lado,
			# con la orientación que le hubiera quedado al volver a su sitio, y
			# encima deslizándose sin animación. Viene a hablarte: tiene que
			# venir de frente y caminando.
			_orientar(_yastay, to_p)
			_yastay_hace("Walk", true)
			var tw := get_tree().create_tween()
			tw.tween_property(_yastay, "global_position", stop, 1.2)
			tw.finished.connect(func() -> void:
				if is_instance_valid(_yastay):
					_yastay_hace("Idle", true))

	DialogueManager.dialogue_ended.connect(
		_give_blessing.unbind(1), CONNECT_ONE_SHOT)
	var res := DialogueManager.create_resource_from_text(TALK_BLESSING)
	DialogueManager.show_dialogue_balloon_scene(BALLOON, res, "start")


func _give_blessing() -> void:
	GameManager.unlock("guanaco")
	if GameManager.get_beat() < 6:
		GameManager.set_beat(6)
	GameManager.conceder("yastay")

	_banner("Bendición del Guanaco obtenida. El paso al volcán está abierto.", 7.0)
	_hint("[Q] invocar/montar/guardar guanaco · [G] embestir · [E] revisar los cuerpos · portal al norte")

	# El Yastay vuelve con su rebaño.
	#
	# Acá había un `global_position` a (-11, 0, -15) escrito a mano. Ese número
	# es de cuando la arena se generaba por código y la zona estaba en el origen;
	# la quebrada de ahora está desplazada Y GIRADA, así que como coordenada de
	# MUNDO apunta a cualquier parte: el Yastay salía disparado lejísimos y se
	# quedaba ahí. Se le manda a su sitio de siempre —el que se guardó al
	# empezar—, que además es donde están los guanacos.
	if is_instance_valid(_yastay):
		if is_instance_valid(_yastay_label):
			_yastay_label.text = "Yastay\nguardián de los guanacos"
		_volver_a_su_sitio()


# ─── Construcción ─────────────────────────────────────────────────────────────

func _build_arena() -> void:

	var rock   := _mat(Color(0.32, 0.28, 0.24))
	var lava   := _mat(Color(0.62, 0.14, 0.04))
	var border := _mat(Color(0.22, 0.20, 0.18))

	# Suelo
	# Sin piso de CSG: el suelo lo pone Terrain3D. La caja anterior era coplanar
	# con el terreno y producía z-fighting.

	# Paredes de la quebrada. El poblado queda al ESTE y el Ojos del Salado al
	# NORTE, así que esos dos lados llevan hueco de 14 m.
	_box(Vector3(-19.5, 3, 0), Vector3(1, 6, 40), border)     # oeste, cerrado
	_box(Vector3(0, 3,  20.5), Vector3(38, 6, 1), border)     # sur, cerrado
	# Este -> poblado
	_box(Vector3( 19.5, 3, -13), Vector3(1, 6, 14), border)
	_box(Vector3( 19.5, 3,  13), Vector3(1, 6, 14), border)
	# Norte -> Ojos del Salado (bajo el portal luminoso)
	_box(Vector3(-12, 3, -20.5), Vector3(14, 6, 1), border)
	_box(Vector3( 12, 3, -20.5), Vector3(14, 6, 1), border)

	# Rocas volcánicas como cobertura para esquivar
	for rx: float in [-9.0, -4.0, 4.0, 9.0]:
		for rz: float in [-4.0, 3.0]:
			_box(Vector3(rx, 0.7, rz), Vector3(1.6, 1.4, 1.6), rock)

	# Portal de salida al norte (hueco en la pared + marco luminoso)
	var gate := _mat_emit(Color(0.85, 0.45, 0.12), Color(0.50, 0.20, 0.02))
	_box(Vector3(-4.5, 3, -19.4), Vector3(1.0, 5.0, 0.6), gate)
	_box(Vector3( 4.5, 3, -19.4), Vector3(1.0, 5.0, 0.6), gate)
	_box(Vector3( 0.0, 5.2, -19.4), Vector3(10.0, 0.6, 0.6), gate)

	# Grietas de lava (decorativas)
	_box(Vector3(-5, -0.35, -9),  Vector3(2.5, 0.2, 12), lava)
	_box(Vector3( 6, -0.35,  5),  Vector3(10,  0.2,  2), lava)
	_box(Vector3(-2, -0.35,  12), Vector3(4,   0.2,  3), lava)


func _spawn_characters() -> void:
	var yastay_mat  := _mat_emit(Color(0.92, 0.72, 0.20), Color(0.45, 0.28, 0.02))
	var hunter_mat  := _mat(Color(0.22, 0.16, 0.08))
	var guanaco_mat := _mat(Color(0.86, 0.76, 0.56))

	# — Yastay (enorme, dorado) —
	#
	# Si hay un modelo puesto a mano, ÉSE es el actor: nada de plantarle encima
	# una cápsula de greybox. Y como la arena se movió al recolocarlo, el resto
	# del reparto se corre con él: se guarda el desfase entre dónde está el
	# modelo y dónde estaba la cápsula, y se le suma a cada posición de abajo.
	# Sin eso los cazadores quedaban en el sitio viejo, a doce metros, sobre los
	# puentes de entrada.
	var modelo := _modelo_con_prefijo("yastay")
	if modelo != null:
		_yastay = modelo
		_desplazamiento = modelo.position - Vector3(0, 0, -14)
		_yastay_label = _cartel_para(_yastay, "Yastay", 2.6)
		# SIN la luz dorada. Esa luz existía para que una cápsula gris se leyera
		# como un ser sagrado; sobre el modelo de verdad no aporta nada y le
		# pega un halo encima —el mismo resplandor escalonado que sacamos del
		# guanaco— porque un foco puntual a dos metros de la cabeza recorre todo
		# el rango de luz sobre su lomo.
	else:
		_yastay = _npc(Vector3(0, 0, -14), yastay_mat, 2.6, "Yastay")
		_yastay_label = _yastay.get_node_or_null("Label3D")

		# Luz dorada: sólo para el greybox, por lo dicho arriba.
		var light := OmniLight3D.new()
		light.light_color  = Color(1.0, 0.82, 0.35)
		light.omni_range   = 10.0
		light.light_energy = 1.2
		light.position.y   = 2.0
		_yastay.add_child(light)

	# — Cazadores (4, marrón oscuro) —
	var hunt_pos: Array[Vector3] = [
		Vector3(-6, 0, -11),
		Vector3( 6, 0, -11),
		Vector3(-3, 0, -12),
		Vector3( 3, 0, -12),
	]
	# Si colocaste modelos de cazador, ésos son los cazadores. Si no, cápsulas en
	# las posiciones de siempre, corridas con la arena.
	var modelos_cazador := _modelos_con_prefijo("cazador")
	if modelos_cazador.is_empty():
		for hp: Vector3 in hunt_pos:
			_hunters.append(_npc(hp + _desplazamiento, hunter_mat, 1.0, "Cazador"))
	else:
		for m: Node3D in modelos_cazador:
			_cartel_para(m, "Cazador", 1.0)
			_hunters.append(m)

	# — Brujo: los dirige desde atrás, encapuchado. Escapa al verlos caer —
	# El brujo que los dirige: si hay un ocultista modelado, es él.
	# Sirve cualquiera de los dos nombres: el asset se llama "brujo" y el guion
	# lo llama ocultista.
	var modelo_brujo := _modelo_con_prefijo("brujo")
	if modelo_brujo == null:
		modelo_brujo = _modelo_con_prefijo("ocultista")
	if modelo_brujo != null:
		_brujo = modelo_brujo
		_cartel_para(_brujo, "???", 1.05)
	else:
		_brujo = _npc(Vector3(-2, 0, -17) + _desplazamiento, _mat(Color(0.10, 0.06, 0.16)), 1.05, "???")
		# Capucha de greybox: sobre un modelo de verdad sobra.
		var hood_mi   := MeshInstance3D.new()
		var hood_mesh := CylinderMesh.new()
		hood_mesh.top_radius    = 0.0
		hood_mesh.bottom_radius = 0.40
		hood_mesh.height        = 0.55
		hood_mi.mesh       = hood_mesh
		hood_mi.position.y = 1.75
		hood_mi.set_surface_override_material(0, _mat(Color(0.07, 0.04, 0.11)))
		_brujo.add_child(hood_mi)

	# — Guanacos pequeños (3, dispersos) —
	var guana_pos: Array[Vector3] = [
		Vector3(-12, 0, -7),
		Vector3( 11, 0, -9),
		Vector3(-9,  0, -14),
	]
	# Sólo si NO hay guanacos modelados: si los pusiste a mano, las cápsulas
	# serían un rebaño fantasma encima del tuyo.
	if _modelo_con_prefijo("guanaco") == null:
		for gp: Vector3 in guana_pos:
			_npc(gp + _desplazamiento, guanaco_mat, 0.75, "")

	# — Guanacos heridos —
	_heridos = _elegir_heridos()
	if _heridos.is_empty():
		# Ninguno modelado: se cae al greybox de siempre, uno solo y tumbado.
		var g := _npc(Vector3(8, 0, -6) + _desplazamiento, guanaco_mat, 0.80,
			"¡Sana al guanaco!")
		g.rotation.z = PI / 2.0   # tumbado de lado
		_heridos.append(g)
	_wounded = _heridos[0]   # el guion viejo mira esta variable en algún sitio

	# Marcador de misión sobre cada uno mientras siga herido.
	for h: Node3D in _heridos:
		_cartel_para(h, "¡Sana al guanaco!", 0.80)
		h.add_to_group("objetivo_guanacos")
		_zona_de_cura(h)
		_tumbar(h)


## Deja al guanaco herido TENDIDO desde el principio.
##
## Se reproduce su caída y se congela en el último fotograma: así la pose es la
## del final del desplome, que es como se ve un animal herido. Antes se les
## giraba el nodo 90° —el apaño de las cápsulas— y sobre un modelo de verdad
## queda como un juguete volcado, con las patas tiesas en el aire.
func _tumbar(g: Node3D) -> void:
	var ap := _animador_de(g)
	if ap == null or not ap.has_animation("Death"):
		return
	var a := ap.get_animation("Death")
	a.loop_mode = Animation.LOOP_NONE
	ap.play("Death")
	ap.advance(a.length)
	ap.pause()


## Desanda la caída: el gesto de levantarse, sin necesitar un clip para eso.
##
## Devuelve lo que tarda, o 0 si el modelo ni siquiera tiene la caída.
func _desandar_la_caida(g: Node3D) -> float:
	var ap := _animador_de(g)
	if ap == null or not ap.has_animation("Death"):
		return 0.0
	var a := ap.get_animation("Death")
	a.loop_mode = Animation.LOOP_NONE
	# Desde el último fotograma, que es donde lo dejó `_tumbar`.
	ap.play("Death")
	ap.seek(a.length, true)
	ap.play_backwards("Death")
	return a.length


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _npc(pos: Vector3, mat: Material, scale_f: float, label_text: String) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	add_child(root)

	var mi  := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.34 * scale_f
	cap.height = 1.55 * scale_f
	mi.mesh = cap
	mi.set_surface_override_material(0, mat)
	mi.position.y = 0.78 * scale_f
	root.add_child(mi)

	if label_text != "":
		var lbl    := Label3D.new()
		lbl.name   = "Label3D"
		lbl.text   = label_text
		lbl.font_size  = 22
		lbl.position.y = 1.9 * scale_f
		lbl.billboard  = BaseMaterial3D.BILLBOARD_ENABLED
		root.add_child(lbl)

	return root


func _box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var b := CSGBox3D.new()
	b.size = size
	b.position = pos
	b.use_collision = true
	b.material_override = mat
	add_child(b)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _mat_emit(c: Color, emit: Color) -> StandardMaterial3D:
	var m := _mat(c)
	m.emission_enabled = true
	m.emission = emit
	m.emission_energy_multiplier = 1.0
	return m


func _active_player() -> Node3D:
	for p in get_tree().get_nodes_in_group("player"):
		if "active" in p and p.active:
			return p
	var arr := get_tree().get_nodes_in_group("player")
	return arr[0] if not arr.is_empty() else null


func _hint(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_hint"):
		hud.show_hint(text)


func _banner(text: String, dur := 0.0) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if not hud or not hud.has_method("show_banner"):
		return
	hud.show_banner(text)
	if dur > 0.0:
		get_tree().create_timer(dur).timeout.connect(func() -> void:
			# El HUD se vuelve a buscar acá dentro en vez de capturarlo: una lambda que
			# captura un nodo y sobrevive a que lo liberen da "Lambda capture at index 0
			# was freed", aunque se compruebe is_instance_valid antes de usarlo.
			var h := get_tree().get_first_node_in_group("hud")
			if h != null and h.has_method("clear_banner"):
				h.clear_banner())
