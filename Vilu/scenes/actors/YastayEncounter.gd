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
const BALLOON      := "res://addons/dialogue_manager/example_balloon/example_balloon.tscn"

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

	# Plano general de la quebrada: se ve al Yastay y a los cazadores alrededor.
	if con_camara and is_instance_valid(_yastay):
		juego.focus_camera_on(_yastay, 0.0, 16.0, 3.0)
	await get_tree().create_timer(1.2).timeout

	# Uno por uno: la cámara se acerca al cazador ANTES de que caiga, para que se
	# vea la caída entera y no el cuerpo ya en el suelo.
	for i in _hunters.size():
		var h: Node3D = _hunters[i]
		if con_camara and is_instance_valid(h):
			juego.focus_camera_on(h, 0.0, 9.0, 1.6)
		await get_tree().create_timer(0.5).timeout
		_defeat_hunter(i)
		await get_tree().create_timer(0.8).timeout

	# El brujo, que los dirigía desde atrás, arranca.
	if is_instance_valid(_brujo):
		if con_camara:
			juego.focus_camera_on(_brujo, 0.0, 11.0, 2.0)
		await get_tree().create_timer(0.6).timeout
	_brujo_escapes()
	# Menos de lo que dura su huida a propósito: al terminarla se libera, y una
	# cámara apuntando a un nodo liberado salta de golpe al jugador.
	await get_tree().create_timer(1.5).timeout

	# Paneo de vuelta al Yastay, que queda solo en medio de la quebrada.
	if con_camara and is_instance_valid(_yastay):
		juego.focus_camera_on(_yastay, 0.0, 12.0, 3.0)
	await get_tree().create_timer(1.8).timeout

	if con_camara:
		juego.clear_camera_focus()
	# La cámara vuelve sola, pero interpolando: se le da el viaje antes de
	# devolver el control y antes de que el Yastay ataque, o el primer golpe cae
	# con la imagen todavía en camino.
	await get_tree().create_timer(1.2).timeout
	_trabar_a_los_jugadores(false)


## Quita o devuelve el control a los dos protagonistas.
func _trabar_a_los_jugadores(trabado: bool) -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if "input_locked" in p:
			p.input_locked = trabado


## El brujo dirigía a los cazadores desde atrás. Al ver que el Yastay los
## derrota, huye hacia el norte sin pelear.
func _brujo_escapes() -> void:
	if not is_instance_valid(_brujo):
		return
	_banner("¡Alguien los estaba dirigiendo desde atrás… y está huyendo!", 4.0)
	var lbl := _brujo.get_node_or_null("Label3D") as Label3D
	if lbl:
		lbl.text = "¡El brujo huye!"
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

	var lbl := body.get_node_or_null("Label3D") as Label3D
	if lbl:
		lbl.text     = "Revisado"
		lbl.modulate = Color(0.45, 0.45, 0.45)

	# Desactivar la zona: ya fue revisada
	zone.set_deferred("monitoring", false)
	if player and player.has_method("clear_interactable"):
		player.clear_interactable(zone)

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

	# Persecución lenta pero amenazante
	if dist > 2.0:
		_yastay.global_position += to_t.normalized() * 3.8 * delta

	# La correa: es un guardián de SU quebrada, no un perseguidor. Sin esto
	# bastaba con salir corriendo para arrastrarlo hasta el poblado, porque el
	# guardia de `_en_zona` sólo lo frena cuando el mundo avisa de que saliste
	# de la zona, y eso llega tarde o no llega. El tope es geométrico y no
	# depende de que nadie avise.
	_atar_a_su_sitio()

	if dist > 0.5:
		_encarar(to_t.normalized())

	# Golpe al alcanzar al jugador
	_yastay_stomp_cd = max(0.0, _yastay_stomp_cd - delta)
	if dist < 2.5 and _yastay_stomp_cd <= 0.0:
		_yastay_stomp_cd = 2.2
		if target.has_method("take_damage"):
			target.take_damage(25.0)
		_banner("¡Golpe del Yastay! ¡Esquiva!", 1.8)


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
func _zona_de_cura(g: Node3D) -> void:
	if g.has_node("ZonaCura"):
		return
	var area := Area3D.new()
	area.name = "ZonaCura"
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	g.add_child(area)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.2
	cs.shape = sph
	area.add_child(cs)
	area.body_entered.connect(_on_heal_entered.bind(g))


func _on_heal_entered(body: Node3D, guanaco: Node3D = null) -> void:
	if _wound_healed or _phase != Phase.AGGRESSIVE:
		return
	if not body.is_in_group("player"):
		return
	if body.get("is_archer") != true:
		_banner("Sólo Benjamín puede sanar al guanaco.", 2.5)
		return
	if guanaco == null:
		guanaco = _heridos[0] if not _heridos.is_empty() else null
	if guanaco == null or guanaco in _sanados:
		return

	_sanados.append(guanaco)
	_levantar(guanaco)
	if _sanados.size() < _heridos.size():
		_banner("Guanacos sanados: %d/%d" % [_sanados.size(), _heridos.size()], 2.5)
		return
	_heal()


## Un guanaco sanado: se incorpora y pierde el cartel de herido.
func _levantar(g: Node3D) -> void:
	if not is_instance_valid(g):
		return
	var tw := get_tree().create_tween()
	# La altura y el giro sólo se tocan en las cápsulas: los modelos los pusiste
	# vos de pie y en su sitio, y "incorporarlos" los movería sin motivo.
	if _es_capsula(g):
		tw.tween_property(g, "rotation:z", 0.0, 0.9)
	var lbl := g.get_node_or_null("Label3D")
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
	var tw := get_tree().create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_yastay, "position", _yastay_origen.origin, REGRESO)
	tw.parallel().tween_property(_yastay, "quaternion",
		_yastay_origen.basis.get_rotation_quaternion(), REGRESO)


## El Yastay se acerca y habla. La bendición sólo llega al terminar el diálogo.
func _yastay_speaks() -> void:
	if is_instance_valid(_yastay):
		var target := _active_player()
		if target != null:
			var to_p := target.global_position - _yastay.global_position
			to_p.y = 0.0
			var stop := _yastay.global_position + to_p.normalized() * maxf(0.0, to_p.length() - 4.0)
			var tw := get_tree().create_tween()
			tw.tween_property(_yastay, "global_position", stop, 1.2)

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

	# El Yastay se queda: se aparta a un costado para no tapar el portal.
	if is_instance_valid(_yastay):
		if is_instance_valid(_yastay_label):
			_yastay_label.text = "Yastay\nguardián de los guanacos"
		var tw := get_tree().create_tween()
		tw.tween_property(_yastay, "global_position", Vector3(-11, 0, -15), 2.5)


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

	for h: Node3D in _heridos:
		_cartel_para(h, "¡Sana al guanaco!", 0.80)
		_zona_de_cura(h)


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
