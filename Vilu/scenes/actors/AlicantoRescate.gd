@tool
extends Node3D

## Secuencia 6 — La prueba del Alicanto.
##
## Un corredor se BIFURCA en dos caminos:
##   · IZQUIERDA — sembrado de oro. Es la trampa: al avanzar, el piso se
##     desvanece bajo tus pies y caés al vacío (Game reinicia la zona).
##   · DERECHA  — una persona herida tirada en el camino. Si la ayudás,
##     superás la prueba y al fondo aparece el Alicanto, que le entrega
##     las ALAS a Emilia.
##
## El Alicanto guía al minero honrado y despeña al codicioso: la geometría
## del nivel ES la moraleja.

const INTERACT_SCR := preload("res://scenes/actors/Interactable.gd")
const MODELO_ALICANTO := preload("res://models/personaje/alicanto.glb")
const POSE := preload("res://scenes/core/PoseAnimada.gd")

## Cómo queda tendida.
##
## Se pide por prefijo: los clips traen el nombre del fichero y cada personaje
## tiene el suyo ("derrotado_de_costado", "derrotada_de_espalda"…).
##
## Para levantarse no hay clip: los cazadores traen dos —caer y sentarse— y
## ninguno es estar de pie. Se le quita el animado y vuelve su modelo rígido,
## que de fábrica ya está de pie.
const CLIP_CAIDA := "derrotad"

## A qué altura vuela el ave sobre el suelo, y a qué distancia de la persona
## rescatada baja si no colocaste un modelo.
const ALTO_VUELO := 3.0
const DISTANCIA_AL_RESCATE := 7.0

## La cámara cuando mira al Alicanto: lo bastante lejos y alto para que se le
## vean las alas enteras estando el ave a tres metros del suelo.
const DISTANCIA_CAMARA := 10.0
const ALTO_CAMARA := 2.5
## Cuánto se queda mirándolo al bajar, antes de devolverle la cámara a Emilia.
const SEGUNDOS_MIRANDO_AL_AVE := 4.5
## Y cuánto acompaña su subida al final.
const SEGUNDOS_DE_LA_SUBIDA := 3.4
const BALLOON      := "res://scenes/ui/GloboDeDialogo.tscn"

const TALK_FORK := "~ start
Benjamín: El camino se parte en dos.
Emilia: Por la izquierda hay algo brillando. Mucho algo.
Benjamín: Por la derecha hay alguien tirado en el suelo. Se está quejando.
Emilia: ...
Benjamín: Vos elegís.
=> END
"

const TALK_HURT := "~ start
Herida: No... no se acerquen al oro. Por favor.
Herida: Vine con mi hermano. Él agarró un puñado y el suelo... el suelo no estaba.
Emilia: Quedate quieta. Te vamos a sacar de acá.
Herida: Hay algo mirando desde el fondo del barranco. Nos estuvo mirando todo el tiempo.
=> END
"

const TALK_WINGS := "~ start
Alicanto: Tres bajaron hoy a mi quebrada.
Alicanto: El primero corrió al oro y el oro se lo tragó.
Alicanto: El segundo corrió al oro y todavía está cayendo.
Alicanto: Ustedes se agacharon a levantar a una desconocida.
Alicanto: Guío al minero honrado y despeño al codicioso. Ese es todo mi oficio.
Alicanto: Toma mis alas, Emilia. Que te sostengan donde la roca se acabe.
Emilia: ...Puedo sentirlo. Como si el aire pesara menos.
=> END
"

enum Phase { APPROACH, CHOOSING, SAVED, DONE }
var _phase := Phase.APPROACH

var _gold_tiles: Array = []      # losas del camino izquierdo (se desvanecen)
var _hurt: Node3D = null
var _alicanto: Node3D = null
## La herida es un modelo puesto a mano, no la cápsula: no se la mueve ni se la
## tumba, y al rescatarla no se le anima el "incorporarse" del greybox.
var _hurt_es_modelo := false
## Altura a la que flota el ave. Sale de donde la hayas colocado.
var _alicanto_y := 6.0
var _fork_seen := false
var _t := 0.0



## Deja de generar el decorado por código: ya está guardado como nodos.
##
## Se tilda DESPUÉS de correr tools/fijar_geometria.gd, que adopta los nodos
## generados dándoles `owner`. Con la bandera puesta el script no vuelve a
## construir encima, y el decorado pasa a editarse a mano en el editor.
##
## El orden importa: tildarla antes de correr la herramienta deja la zona sin
## geometría que adoptar.
@export var geometria_fijada: bool = false

## Quién es la persona herida.
##
## Asignale el personaje que pusiste en la escena: se lo tumba con la animación
## de caída y se le cuelga el "[E] Ayudar". Vacío quiere decir "buscala como
## antes", por la cápsula gris del greybox.
@export var persona_herida: NodePath


func _ready() -> void:
	if not geometria_fijada:
		_build_canyon()
		_build_gold_path()
		_build_hurt_path()
	# En el editor sólo se construye la quebrada; el hint es para el jugador.
	if Engine.is_editor_hint():
		return
	if geometria_fijada:
		_reponer_logica()
	_hint("Quebrada del Alicanto. El camino se bifurca más adelante.")


## Metros de tolerancia al buscar por posición un nodo ya horneado.
const CERCA := 1.5


## Vuelve a enganchar la lógica sobre lo que quedó guardado en la escena.
##
## Al fijar la geometría se hornearon los disparadores, las losas del oro y la
## persona herida, pero sus señales se conectaban DENTRO de _build_canyon(),
## _build_gold_path() y _build_hurt_path(), que con el flag puesto ya no corren.
## La zona quedó siendo geometría sin lógica: la bifurcación no detectaba al
## jugador, pisar el oro no derrumbaba nada y a la herida no se la podía
## socorrer. Es el mismo agujero que tenían los NPC de la fiesta de La Tirana.
func _reponer_logica() -> void:
	var fork := _area_en(Vector3(0.0, 1.5, -3.5))
	if fork == null:
		push_warning("Alicanto: no encuentro el disparador de la bifurcación")
	elif not fork.body_entered.is_connected(_on_fork_entered):
		fork.body_entered.connect(_on_fork_entered)

	var trap := _area_en(Vector3(-11.0, 1.5, -13.0))
	if trap == null:
		push_warning("Alicanto: no encuentro el disparador del camino del oro")
	elif not trap.body_entered.is_connected(_on_gold_path_entered):
		trap.body_entered.connect(_on_gold_path_entered)

	# Las ocho losas de CSG del camino del oro ya no se buscan: la trampa dejó de
	# ser greybox y ahora la llevan tus modelos, con TrampaDelOro.gd. Buscarlas
	# sólo servía para avisar en cada arranque que no había ninguna.

	# El ave, si la colocaste, arranca escondida: aparece al superar la prueba.
	var ave := _hijo_que_empieza_con("alicanto")
	if ave != null:
		ave.visible = false

	_reponer_herida()


## La persona herida: se adopta la que quedó horneada, se la lleva a la cama de
## aventurero si está puesta y se le devuelve su zona de "[E] Ayudar".
##
## Esa zona NUNCA llegó a guardarse: se creaba después del `return` del editor,
## así que en el momento del horneado no existía.
func _reponer_herida() -> void:
	# Lo primero, el personaje que hayas asignado en el inspector: es la forma
	# de decir "la herida es ÉSTA", viéndola en el editor. La cápsula gris del
	# greybox ya no hace falta, y por eso puede no existir.
	_hurt = get_node_or_null(persona_herida) as Node3D
	if _hurt != null:
		_hurt_es_modelo = true
		_cartel_de(_hurt, "¡Alguien herido!")
		_tumbar_a_la_herida()
		_zona_de_ayuda()
		return

	_hurt = _nodo_con_cartel("¡Alguien herido!")
	if _hurt == null:
		push_warning("Alicanto: no encuentro a la persona herida")
		return

	# Dentro de la cápsula quedaron reparentados varios modelos por deslices del
	# editor. Se los saca conservando su posición de mundo, y si alguno de ellos
	# es un PERSONAJE, ése pasa a ser la persona herida: ponerlo ahí es
	# justamente la forma de decir "reemplazá la píldora por esto".
	var reemplazo := _rescatar_colados(_hurt)
	# Ya no hace falta que esté ANIDADO en la cápsula: desde que los modelos se
	# reparentaron a la zona, el reemplazo es un hermano. Vale el personaje
	# puesto más cerca, medido en planta —la diferencia de altura no cuenta,
	# porque la cápsula quedó a ras de suelo y el modelo está sobre la roca.
	if reemplazo == null:
		reemplazo = _personaje_mas_cerca(_hurt.position, 6.0)

	if reemplazo != null:
		# El modelo puesto a mano manda: se queda donde lo dejaste. Colocarlo ES
		# la decisión.
		_cartel_de(reemplazo, "¡Alguien herido!")
		_hurt.queue_free()
		_hurt = reemplazo
		_hurt_es_modelo = true
		_tumbar_a_la_herida()
	else:
		var cama := _hijo_que_empieza_con("cama_aventurero")
		if cama != null:
			_hurt.position = cama.position + Vector3(0.0, 0.5, 0.0)
		_hurt.rotation.z = PI / 2.0   # tirada, no de pie

	_zona_de_ayuda()


## La deja tendida en el suelo, con la misma caída que los cazadores del Yastay.
##
## Los modelos del pipeline no tienen huesos: el clip vive en el `_anim` de al
## lado y `PoseAnimada` hace el cambio. Sin esto la herida se veía DE PIE, que
## es la pose en la que viene el modelo, y había que tumbarla girándola —lo que
## se hacía con la cápsula— con el resultado de siempre: medio cuerpo dentro
## del suelo.
func _tumbar_a_la_herida() -> void:
	if not is_instance_valid(_hurt):
		return
	if not POSE.poner(_hurt, CLIP_CAIDA, false):
		push_warning("Alicanto: la herida no tiene el clip '%s'" % CLIP_CAIDA)


func _zona_de_ayuda() -> void:
	if not is_instance_valid(_hurt) or _hurt.has_node("ZonaAyuda"):
		return
	var zone := Area3D.new()
	zone.name = "ZonaAyuda"
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.set_script(INTERACT_SCR)
	zone.prompt = "[E] Ayudar a la herida"
	_hurt.add_child(zone)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.4
	cs.shape = sph
	zone.add_child(cs)
	zone.interacted.connect(_on_hurt_help)


## Saca de `n` (y de sus áreas) los modelos que no le pertenecen y los cuelga de
## la zona, conservando su transformación de mundo.
##
## Es un parche de ejecución para un desliz de la escena, no la cura: mientras
## sigan mal colgados en el .tscn, en el editor se van a ver dentro de la herida
## y moverla a ella los moverá a ellos. Lo bueno es reparentarlos ahí.
## Devuelve el PERSONAJE que estuviera colgado ahí dentro, si lo hay.
func _rescatar_colados(n: Node3D) -> Node3D:
	var colados: Array = []
	_juntar_colados(n, colados)
	var personaje: Node3D = null
	for c: Node3D in colados:
		var t := c.global_transform
		c.get_parent().remove_child(c)
		add_child(c)
		c.global_transform = t
		if _es_personaje(c.name):
			personaje = c
			push_warning("Alicanto: '%s' pasa a ser la persona herida" % c.name)
		else:
			push_warning("Alicanto: '%s' colgaba de la persona herida; se devolvió a la zona"
				% c.name)
	return personaje


## El personaje puesto a mano más cercano a la píldora, en planta.
##
## Colocar un modelo junto a ella es la forma de decir "reemplazá esto por
## aquello", sin tocar código ni nombres especiales.
func _personaje_mas_cerca(pos: Vector3, radio: float) -> Node3D:
	var mejor: Node3D = null
	var d := radio
	for c in get_children():
		if not (c is Node3D) or (c as Node3D).scene_file_path == "":
			continue
		if not _es_personaje(c.name):
			continue
		var p: Vector3 = (c as Node3D).position
		var dd := Vector2(p.x - pos.x, p.z - pos.z).length()
		if dd < d:
			d = dd
			mejor = c
	if mejor != null:
		print("[alicanto] '%s' pasa a ser la persona herida (a %.1f m)" % [mejor.name, d])
	return mejor


## Nombres de modelos que valen como actor. El decorado y las piezas de la
## trampa quedan fuera: se sacan igual de ahí dentro, pero no reemplazan a nadie.
func _es_personaje(nombre: String) -> bool:
	for p in ["cazador", "cazadora", "ocultista", "brujo", "bruja",
			"nativo", "chica_", "nino_", "guardian"]:
		if nombre.begins_with(p):
			return true
	return false


## Junta TODO lo que hayas arrastrado dentro, sea lo que sea.
##
## Antes esto era una lista de nombres —la trampa y los personajes— y fue un
## error grave: los siete cristales de oro no estaban en la lista, se quedaban
## dentro de la cápsula y el queue_free() posterior SE LOS LLEVABA. Por eso
## desaparecían del camino del oro.
##
## La regla buena no es por nombre sino estructural: un nodo con
## `scene_file_path` es una escena instanciada, o sea un modelo que pusiste vos.
## Todo lo demás son piezas del greybox que sí pertenecen a la cápsula.
func _juntar_colados(n: Node, fuera: Array) -> void:
	for c in n.get_children():
		if c is Node3D and (c as Node3D).scene_file_path != "":
			fuera.append(c)
		else:
			_juntar_colados(c, fuera)


## Le pone (o reusa) el cartel flotante a un modelo adoptado. El guion le cambia
## el texto a "Sobreviviente" al rescatarlo, así que tiene que existir.
func _cartel_de(nodo: Node3D, texto: String) -> Label3D:
	var existente := nodo.get_node_or_null("Label3D") as Label3D
	if existente != null:
		return existente
	var lbl := Label3D.new()
	lbl.name = "Label3D"
	lbl.text = texto
	lbl.font_size = 22
	lbl.position.y = 2.0
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nodo.add_child(lbl)
	return lbl


func _area_en(pos: Vector3) -> Area3D:
	for c in get_children():
		if c is Area3D and (c as Area3D).position.distance_to(pos) <= CERCA:
			return c
	return null


func _nodo_en(pos: Vector3) -> Node3D:
	for c in get_children():
		if c is Node3D and not (c is Area3D) and (c as Node3D).position.distance_to(pos) <= CERCA:
			return c
	return null


func _nodo_con_cartel(texto: String) -> Node3D:
	for c in get_children():
		if not (c is Node3D):
			continue
		for h in c.get_children():
			if h is Label3D and (h as Label3D).text == texto:
				return c
	return null


func _hijo_que_empieza_con(prefijo: String) -> Node3D:
	for c in get_children():
		if c is Node3D and c.name.begins_with(prefijo):
			return c
	return null


## Cuánto sube y baja el ave al aletear, en metros, y a qué ritmo.
const ALETEO_ALTO := 0.5
const ALETEO_RITMO := 2.2


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(_alicanto):
		# Sólo sube y baja, aleteando en el sitio. Antes giraba sobre su eje
		# (rotation.y += delta * 0.4): eso servía para una esfera de greybox sin
		# frente ni espalda, pero con el modelo puesto el ave se ve dando
		# vueltas sobre sí misma en vez de sostenerse en el aire.
		_alicanto.position.y = _alicanto_y + sin(_t * ALETEO_RITMO) * ALETEO_ALTO


# ─── Bifurcación ─────────────────────────────────────────────────────────────

func _on_fork_entered(body: Node3D) -> void:
	if _fork_seen or not body.is_in_group("player"):
		return
	_fork_seen = true
	_phase = Phase.CHOOSING
	_hint("Izquierda: el oro. Derecha: la persona herida.")
	_show(TALK_FORK)


# ─── Camino del oro (la trampa) ──────────────────────────────────────────────

func _on_gold_path_entered(body: Node3D) -> void:
	if _phase == Phase.DONE or not body.is_in_group("player"):
		return
	_banner("El oro brilla... y el suelo empieza a ceder.", 3.0)
	# La misión se vuelve a pedir AL REAPARECER, no acá: mientras caes no estás
	# mirando el recuadro. Lo hace TrampaDelOro al devolverte al poblado.
	# Las losas caen una tras otra: no da tiempo a volver
	for i in _gold_tiles.size():
		get_tree().create_timer(0.18 * float(i)).timeout.connect(
			_drop_tile.bind(i))


func _drop_tile(idx: int) -> void:
	if idx >= _gold_tiles.size():
		return
	var tile = _gold_tiles[idx]
	if not is_instance_valid(tile):
		return
	# use_collision=false primero: el jugador cae de inmediato aunque la losa
	# todavía se esté viendo desvanecer.
	tile.use_collision = false
	var tw := get_tree().create_tween()
	tw.tween_property(tile, "position:y", tile.position.y - 14.0, 0.9)
	tw.tween_callback(tile.queue_free)


# ─── Camino de la herida (la prueba) ─────────────────────────────────────────

func _on_hurt_help(_player: Node) -> void:
	if _phase == Phase.SAVED or _phase == Phase.DONE:
		return
	_phase = Phase.SAVED

	# Se incorpora
	if is_instance_valid(_hurt):
		# El "se incorpora" es del greybox: la cápsula estaba tumbada en y=0. A un
		# modelo puesto a mano llevarlo a y=0 lo hundiría en el suelo; ése se
		# incorpora con su propia animación, sin tocarle el transform.
		if _hurt_es_modelo:
			# De pie y quieto: se le quita el modelo animado y vuelve el suyo,
			# que es un cuerpo rígido y su pose de fábrica es estar de pie.
			# Antes se le ponía `sentado_victoria` y quedaba SENTADO EN EL AIRE:
			# ese clip está hecho para una silla, y ahí no hay ninguna.
			POSE.quitar(_hurt)
		else:
			var tw := get_tree().create_tween()
			tw.tween_property(_hurt, "rotation:z", 0.0, 0.8)
			tw.parallel().tween_property(_hurt, "position:y", 0.0, 0.8)
		var lbl := _hurt.get_node_or_null("Label3D") as Label3D
		if lbl:
			lbl.text = "Sobreviviente"

	DialogueManager.dialogue_ended.connect(_summon_alicanto.unbind(1), CONNECT_ONE_SHOT)
	_show(TALK_HURT)


func _summon_alicanto() -> void:
	_banner("Al fondo de la quebrada se enciende una luz.", 4.0)
	_hint("Algo bajó al final del camino de la derecha.")
	_build_alicanto()
	# La cámara se va al ave en cuanto baja. El Alicanto aparece al fondo de la
	# quebrada, a espaldas del jugador y por encima de su cabeza: hasta ahora
	# sólo se enteraba por un cartel que decía que algo había bajado.
	_mirar_al_alicanto(SEGUNDOS_MIRANDO_AL_AVE)


## Manda la cámara al Alicanto. Con `segundos` en 0 se queda ahí hasta que
## alguien la suelte.
func _mirar_al_alicanto(segundos := 0.0) -> void:
	var juego := get_tree().get_first_node_in_group("game")
	if juego == null or not juego.has_method("focus_camera_on"):
		return
	if not is_instance_valid(_alicanto):
		juego.clear_camera_focus()
		return
	juego.focus_camera_on(_alicanto, segundos, DISTANCIA_CAMARA, ALTO_CAMARA)


# ─── Alicanto ────────────────────────────────────────────────────────────────

## Hace bajar al Alicanto y le pone su zona de encuentro.
##
## TRES cosas cambiaron respecto del greybox, y las tres se veían en el juego:
##
##  · Ya no es una esfera con dos cajas por alas: usa el modelo de verdad. Si
##    colocaste un nodo que empiece por "alicanto" baja AHÍ; si no, se instancia
##    el .glb junto a la persona que acabás de rescatar.
##
##  · Nace RELATIVO al rescate, no en (11, 6, -34) fijo. Esa coordenada era del
##    greybox y con la zona rehecha cae sobre el vacío: el ave aparecía flotando
##    fuera del mapa.
##
##  · Sin la luz dorada. Un OmniLight de energía 2.4 y radio 14 pegado al ave es
##    el resplandor raro que se veía; sobre un modelo con textura no aporta.
func _build_alicanto() -> void:
	var puesto := _hijo_que_empieza_con("alicanto")
	if puesto != null:
		_alicanto = puesto
		puesto.visible = true
	else:
		_alicanto = MODELO_ALICANTO.instantiate()
		_alicanto.name = "AlicantoInvocado"
		add_child(_alicanto)
		# Si hay un marcador puesto en la escena manda él, CON SU ESCALA: así el
		# ave se coloca y se agranda viéndola en el editor (el marcador lleva
		# VistaPrevia y la dibuja) en vez de a ciegas desde estas cuentas.
		var marca := get_node_or_null("AveSpawn") as Node3D
		if marca != null:
			_alicanto.transform = marca.transform
		else:
			_alicanto.position = _sitio_del_ave()
	_alicanto_y = _alicanto.position.y
	_cartel_de(_alicanto, "Alicanto")

	# Zona de encuentro PEGADA AL AVE y bajando hasta el suelo. Antes era una
	# caja suelta a 1.5 m de altura en una coordenada fija: no coincidía con
	# donde estaba el ave y había que saltar para alcanzarla.
	var zone := Area3D.new()
	zone.name = "ZonaDelAlicanto"
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.monitoring = true
	add_child(zone)
	zone.position = _alicanto.position - Vector3(0.0, ALTO_VUELO * 0.5, 0.0)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 6.0
	cs.shape = sph
	zone.add_child(cs)
	zone.body_entered.connect(_on_alicanto_reached)


## Dónde baja el ave si no colocaste un modelo: al lado de quien rescataste,
## hacia el fondo de la quebrada y a la altura del vuelo.
func _sitio_del_ave() -> Vector3:
	if is_instance_valid(_hurt):
		return _hurt.position + Vector3(0.0, ALTO_VUELO, -DISTANCIA_AL_RESCATE)
	return Vector3(11.0, 6.0, -34.0)   # el sitio del greybox, como último recurso


func _on_alicanto_reached(body: Node3D) -> void:
	if _phase != Phase.SAVED or not body.is_in_group("player"):
		return
	_phase = Phase.DONE
	# Mientras habla, la cámara se queda en él: es quien tiene la palabra.
	_mirar_al_alicanto()
	DialogueManager.dialogue_ended.connect(_give_wings.unbind(1), CONNECT_ONE_SHOT)
	_show(TALK_WINGS)


func _give_wings() -> void:
	GameManager.unlock("wings")
	if GameManager.get_beat() < 5:
		GameManager.set_beat(5)
	GameManager.conceder("alicanto")
	_banner("Emilia recibe las ALAS: doble salto y planeo (mantené Espacio al caer).", 7.0)
	_hint("Emilia: [Espacio] doble salto · mantené [Espacio] al caer para planear · volvé al poblado")

	if is_instance_valid(_alicanto):
		var tw := get_tree().create_tween()
		tw.tween_property(_alicanto, "position",
			_alicanto.position + Vector3(0, 9.0, 0), 3.0)
	# Acompaña la subida y devuelve la cámara a Emilia al terminar.
	_mirar_al_alicanto(SEGUNDOS_DE_LA_SUBIDA)


# ─── Geometría ───────────────────────────────────────────────────────────────

func _build_canyon() -> void:
	var rock  := _mat(Color(0.34, 0.29, 0.24))
	var wall  := _mat(Color(0.22, 0.19, 0.16))
	var floor_mat := _mat(Color(0.44, 0.37, 0.29))

	# Corredor de entrada (sur), 10 de ancho
	_box(Vector3(0, -0.5, 8.0), Vector3(10, 1, 24), floor_mat)
	_box(Vector3(-5.5, 3, 8.0), Vector3(1, 6, 24), wall)
	_box(Vector3( 5.5, 3, 8.0), Vector3(1, 6, 24), wall)

	# Plataforma de la bifurcación
	_box(Vector3(0, -0.5, -6.0), Vector3(26, 1, 8), floor_mat)
	_box(Vector3(0, 3, -10.5), Vector3(8, 6, 1), wall)      # tabique central
	_box(Vector3(-13.5, 3, -6.0), Vector3(1, 6, 8), wall)
	_box(Vector3( 13.5, 3, -6.0), Vector3(1, 6, 8), wall)

	# Paredes exteriores de los dos ramales (el vacío queda entre medio)
	_box(Vector3(-15.5, 3, -24.0), Vector3(1, 6, 28), wall)
	_box(Vector3( 15.5, 3, -24.0), Vector3(1, 6, 28), wall)
	_box(Vector3(0, 3, -38.5), Vector3(32, 6, 1), wall)

	# Cartel de advertencia en la bifurcación
	var sign_lbl       := Label3D.new()
	sign_lbl.text      = "Quebrada del Alicanto"
	sign_lbl.font_size = 22
	sign_lbl.position  = Vector3(0, 3.2, -10.0)
	sign_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_lbl.modulate  = Color(0.85, 0.75, 0.55)
	add_child(sign_lbl)

	# Rocas sueltas de ambiente
	for rp: Vector3 in [Vector3(-3, 0.5, 4), Vector3(3.5, 0.5, 12), Vector3(-2, 0.5, 16)]:
		_box(rp, Vector3(1.2, 1.0, 1.2), rock)

	# Trigger de la bifurcación
	var fork             := Area3D.new()
	fork.collision_layer = 0
	fork.collision_mask  = 2
	fork.monitoring      = true
	fork.position        = Vector3(0, 1.5, -3.5)
	add_child(fork)
	var fcs  := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(10.0, 4.0, 3.0)
	fcs.shape = fbox
	fork.add_child(fcs)
	fork.body_entered.connect(_on_fork_entered)


## Ramal IZQUIERDO: losas sueltas cubiertas de oro. Es la trampa.
func _build_gold_path() -> void:
	var tile_mat := _mat(Color(0.40, 0.34, 0.27))
	var gold_mat := _mat_emit(Color(0.95, 0.79, 0.24), Color(0.52, 0.40, 0.05), 1.8)

	# 8 losas de 4x4 bajando hacia el norte
	for i in 8:
		var z := -12.0 - float(i) * 3.4
		var tile := _box(Vector3(-11.0, -0.5, z), Vector3(4.6, 1.0, 3.2), tile_mat)
		_gold_tiles.append(tile)

		# Oro sembrado encima
		var g_mi   := MeshInstance3D.new()
		var g_mesh := BoxMesh.new()
		g_mesh.size = Vector3(0.5, 0.25, 0.5)
		g_mi.mesh   = g_mesh
		g_mi.position   = Vector3(-11.0 + (float(i % 3) - 1.0) * 0.9, 0.15, z)
		g_mi.rotation.y = float(i) * 0.5
		g_mi.set_surface_override_material(0, gold_mat)
		add_child(g_mi)

	# Montón grande al fondo, como cebo
	for i in 6:
		var b_mi   := MeshInstance3D.new()
		var b_mesh := BoxMesh.new()
		b_mesh.size = Vector3(0.7, 0.35, 0.7)
		b_mi.mesh   = b_mesh
		b_mi.position = Vector3(-11.0 + float(i % 3) * 0.75 - 0.75,
			0.2 + floorf(float(i) / 3.0) * 0.35, -36.0)
		b_mi.set_surface_override_material(0, gold_mat)
		add_child(b_mi)

	var g_lbl       := Label3D.new()
	g_lbl.text      = "Oro"
	g_lbl.font_size = 22
	g_lbl.position  = Vector3(-11.0, 2.0, -30.0)
	g_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	g_lbl.modulate  = Color(1.0, 0.85, 0.30)
	add_child(g_lbl)

	var glow          := OmniLight3D.new()
	glow.position     = Vector3(-11.0, 1.5, -30.0)
	glow.light_color  = Color(1.0, 0.82, 0.30)
	glow.omni_range   = 16.0
	glow.light_energy = 1.8
	add_child(glow)

	# Trigger: al pisar el ramal del oro empieza el derrumbe
	var trap             := Area3D.new()
	trap.collision_layer = 0
	trap.collision_mask  = 2
	trap.monitoring      = true
	trap.position        = Vector3(-11.0, 1.5, -13.0)
	add_child(trap)
	var tcs  := CollisionShape3D.new()
	var tbox := BoxShape3D.new()
	tbox.size = Vector3(4.6, 4.0, 3.0)
	tcs.shape = tbox
	trap.add_child(tcs)
	trap.body_entered.connect(_on_gold_path_entered)


## Ramal DERECHO: piso firme y una persona herida a mitad de camino.
func _build_hurt_path() -> void:
	var floor_mat := _mat(Color(0.44, 0.37, 0.29))
	_box(Vector3(11.0, -0.5, -25.0), Vector3(9, 1, 30), floor_mat)

	_hurt = _npc(Vector3(11.0, 0.30, -22.0), _mat(Color(0.62, 0.50, 0.42)), 0.95,
		"¡Alguien herido!")
	_hurt.rotation.z = PI / 2.0   # tirada en el suelo

	# En el EDITOR se previsualiza el paisaje, no la lógica: este script es
	# @tool pero Interactable.gd no, así que ahí dentro la instancia no expone
	# la señal `interacted` y conectarse a ella daba "Invalid access to property
	# or key". La herida se ve igual sin su zona de interacción.
	if Engine.is_editor_hint():
		return

	var zone             := Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask  = 2
	zone.set_script(INTERACT_SCR)
	zone.prompt          = "[E] Ayudar a la herida"
	_hurt.add_child(zone)

	var cs  := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.4
	cs.shape   = sph
	zone.add_child(cs)
	zone.interacted.connect(_on_hurt_help)


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
		lbl.font_size  = 20
		lbl.position.y = 1.9 * scale_f
		lbl.billboard  = BaseMaterial3D.BILLBOARD_ENABLED
		root.add_child(lbl)

	return root


func _box(pos: Vector3, size: Vector3, mat: Material) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.size = size
	b.position = pos
	b.use_collision = true
	b.material_override = mat
	add_child(b)
	return b


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _mat_emit(c: Color, emit: Color, energy := 1.0) -> StandardMaterial3D:
	var m := _mat(c)
	m.emission_enabled = true
	m.emission = emit
	m.emission_energy_multiplier = energy
	return m


func _show(text: String) -> void:
	var res := DialogueManager.create_resource_from_text(text)
	DialogueManager.show_dialogue_balloon_scene(BALLOON, res, "start")


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
