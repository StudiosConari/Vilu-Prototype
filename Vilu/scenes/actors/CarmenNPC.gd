@tool
extends CharacterBody3D

## NPC Carmen — en realidad La Tirana.
##
## Flujo:
##  1. Primera charla: está de guía del museo, dice que hablen con la gente y
##     SE METE A LA IGLESIA. La cámara la acompaña hasta la puerta.
##  2. Sale entre los bailarines, ya vestida de La Tirana, bailando. Es el mismo
##     NPC: se le cambia el traje, no se cambia de personaje.
##  3. Mientras clues < 4: diálogo corto de espera.
##  4. clues >= 4: Revelación → desbloquea bow + beat 2.
##  5. Habilidad ya dada: despedida corta.

const BALLOON := "res://addons/dialogue_manager/example_balloon/example_balloon.tscn"

## Con el que empieza: la guía del museo, de calle.
@export var modelo: PackedScene = preload("res://models/personaje/carmen_museo.glb")

## Con el que sale de la iglesia: el vestido de la fiesta, con el gorro de
## diablada y el baile de La Tirana.
@export var modelo_tirana: PackedScene = preload("res://models/personaje/carmen.glb")

## Alto del CUERPO en metros, sin contar el gorro.
@export var altura_visual := 1.75

## Los modelos de este proyecto miran a +Z y el juego avanza hacia -Z.
@export var giro_modelo := 180.0

## A dónde camina al terminar la primera charla. Vacío: se aleja hacia el altar,
## como hacía antes de que la iglesia existiera.
@export var puerta_iglesia: NodePath

## Dónde reaparece bailando. El nodo marca el sitio Y hacia dónde mira, así que
## para reubicarla basta con mover ese marcador en el editor.
@export var sitio_de_baile: NodePath

## Multiplica las esperas de la escena de la iglesia. Los tests lo bajan para no
## quedarse los cinco segundos que dura en pantalla.
@export var ritmo_escena := 1.0

## Qué animación va en cada momento, para cada traje.
##
## Los dos modelos traen los mismos papeles con distinto nombre, así que el
## guion pide "idle" o "bailar" y aquí se traduce. La guía del museo NO baila:
## su casilla de baile va vacía a propósito y cae en el idle.
const CLIPS := {
	"museo": {
		"idle": "MUSEO_idle_movido",
		"caminar": "MUSEO_caminar",
		"hablando": "MUSEO_idle_hablando",
		"bailar": "",
	},
	"tirana": {
		"idle": "TIRANA3_idle",
		"caminar": "TIRANA3_caminar",
		"hablando": "TIRANA3_idle_hablando",
		"bailar": "TIRANA3_bailar",
	},
}

var _anim: AnimationPlayer = null
var _hablando := false
var _clip_actual := ""
var _traje := "museo"
var _bailando := false
var _en_escena := false

const DIALOGUE_FASE1 := "~ start
Carmen: ¡Bienvenidos a la Fiesta de La Tirana! Una celebración sagrada del norte.
Carmen: Hablen con la gente del pueblo, guardan secretos de la fiesta.
Carmen: Yo tengo algo que hacer en la iglesia. Después los busco.
=> END
"

const DIALOGUE_WAIT := "~ start
Carmen: Sigan explorando la fiesta. Aún hay más que descubrir.
=> END
"

const DIALOGUE_REVELACION := "~ start
Carmen: Veo que ya saben quién soy. Está bien... Soy La Tirana.
Carmen: Aquí está tu don, guerrera. Emilia: COMBO de cuatro golpes. Benjamín: FLECHA TRIPLE (tecla F, gasta energía).
Carmen: Cambien de héroe con R (el otro pelea solo) o con T (se queda quieto, para puzzles).
Carmen: El paso del norte los espera. La mina guarda algo oscuro...
=> END
"

const DIALOGUE_AGAIN := "~ start
Carmen: Ya tienen su don. La mina los espera al norte.
=> END
"

var _has_walked     := false
var _pending_walk   := false
var _pending_unlock := false
var _walking        := false


func _ready() -> void:
	_montar(modelo, "museo")
	if Engine.is_editor_hint():
		# En el editor se monta el traje y nada más, para poder colocarla
		# viéndola en vez de mover una cápsula a ciegas. Ni diálogo —el
		# DialogueManager no existe fuera del juego— ni apoyarla en el suelo:
		# eso le movería el transform de verdad, y ése SÍ se guarda en la escena.
		return
	$Interact.interacted.connect(_on_interacted)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	# Diferido: en _ready() el espacio físico todavía no acepta consultas.
	_apoyar_en_el_suelo.call_deferred()


## La deja apoyada en el terreno.
##
## Carmen sólo corre física MIENTRAS camina —su `_physics_process` sale antes de
## la gravedad si está quieta—, así que se queda a la altura a la que la
## dejaron en la escena. Con la cápsula gris no se notaba; con el modelo, si el
## terreno subió por debajo, se la traga hasta las rodillas.
## `alcance` es cuánto se busca arriba y abajo. Al colocarla de entrada se mira
## lejos, pero caminando conviene mirar cerca: con un rayo largo, al pisar el
## atrio de la iglesia encontraría antes el techo del pórtico que el suelo.
func _apoyar_en_el_suelo(alcance := 30.0) -> void:
	var esp := get_world_3d().direct_space_state
	if esp == null:
		return
	var p := global_position
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * alcance, p + Vector3.DOWN * alcance)
	q.collision_mask = 1          # el terreno
	q.exclude = [get_rid()]       # que no se encuentre a sí misma
	var r := esp.intersect_ray(q)
	if not r.is_empty():
		global_position = r["position"]


## Le pone un traje.
##
## La cápsula de greybox NO se borra, se oculta: si algún día falta el .glb o
## hay que volver atrás, el NPC sigue teniendo cuerpo y sitio.
func _montar(escena: PackedScene, traje: String) -> void:
	var visual := get_node_or_null("Visual") as Node3D
	if visual == null or escena == null:
		return
	# Fuera el traje anterior. `remove_child` antes de liberarlo: si no, el
	# nombre "Modelo" sigue ocupado hasta el final del cuadro y el nuevo entra
	# como "Modelo2".
	var viejo := visual.get_node_or_null("Modelo")
	if viejo != null:
		visual.remove_child(viejo)
		viejo.queue_free()

	var m := escena.instantiate() as Node3D
	if m == null:
		return
	m.name = "Modelo"
	visual.add_child(m)

	var alto := _alto_del_cuerpo(m)
	if alto > 0.01:
		m.scale = Vector3.ONE * (altura_visual / alto)
	m.rotation_degrees.y = giro_modelo

	var capsula := visual.get_node_or_null("Placeholder") as MeshInstance3D
	if capsula != null:
		capsula.visible = false

	_arreglar_transparencias(m)
	_hundir_la_piel(m)
	_traje = traje
	_anim = _buscar_anim(m)
	_clip_actual = ""          # el clip de antes ya no existe en este modelo
	_refrescar_animacion()
	if Engine.is_editor_hint() and _anim != null:
		# En el editor la animación no avanza sola: se fuerza el primer cuadro
		# para que aparezca de pie y no en la pose cruda del esqueleto.
		_anim.seek(0.0, true)


## Ordena las capas de la cara a mano.
##
## Ojos, pestañas y cejas son planos con alfa APILADOS a medio milímetro unos de
## otros. A esa distancia la profundidad no es un criterio fiable, y de hecho la
## esclera queda geométricamente DELANTE del iris: comprobado escondiéndola en
## una foto del motor, con lo que el iris aparece entero y bien puesto. Por eso
## Carmen salía con los ojos en blanco — no era el modelo, que en Blender se ve
## perfecto, sino quién tapaba a quién.
##
## La solución no es pelear con la profundidad sino quitarla de la ecuación: los
## planos no escriben profundidad entre ellos y el orden lo fija
## `render_priority`, de atrás hacia delante. Siguen probándose contra el resto
## de la cabeza, así que no se ven a través del pelo ni del gorro.
const CAPAS_DE_LA_CARA := [
	["escler", 0],    # el fondo blanco del ojo
	["iris", 1],
	["pupila", 2],
	["brillo", 3],    # los reflejos, encima del iris
	["pestana", 4],
	["ceja", 5],
]


func _arreglar_transparencias(raiz: Node3D) -> void:
	var tocados := 0
	for mi: MeshInstance3D in _mallas(raiz):
		var n := mi.name.to_lower()
		var orden := -1
		for capa in CAPAS_DE_LA_CARA:
			if n.contains(String(capa[0])):
				orden = int(capa[1])
		if orden < 0 or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if mat == null:
				continue
			# Duplicado: el material del .glb lo comparten todas las instancias.
			var propio := mat.duplicate() as BaseMaterial3D
			propio.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			propio.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
			propio.render_priority = orden
			mi.set_surface_override_material(s, propio)
			tocados += 1
	if tocados > 0 and not Engine.is_editor_hint():
		print("[carmen] %d capas de la cara ordenadas a mano" % tocados)


## Las mallas que van POR DEBAJO de otras y no deben asomar: la piel bajo la
## ropa, y el interior de la boca dentro de la cabeza.
const POR_DEBAJO := ["cuerpo", "boca", "epiglotis"]

## Cuánto se hunden, en metros.
@export var hundir_la_piel := 0.0025


## Mete la piel un pelo hacia dentro para que no atraviese la ropa.
##
## El cuerpo y la ropa son mallas SEPARADAS y en algunos sitios ocupan el mismo
## sitio: por el hombro y el costado asomaban manchas de piel a través de la
## polera, y el interior de la boca se salía por la mejilla. No es un problema
## de transparencia —todas esas mallas son opacas—, son dos superficies pegadas
## y gana la que el motor dibuje más cerca.
##
## `grow_amount` mueve los vértices a lo largo de su normal, pero va en unidades
## de la MALLA y no en metros: este modelo llega diez veces más grande que el
## personaje, así que hay que dividir por la escala a la que se montó.
func _hundir_la_piel(raiz: Node3D) -> void:
	var escala: float = maxf(raiz.scale.x, 0.0001)
	for mi: MeshInstance3D in _mallas(raiz):
		var n := mi.name.to_lower()
		var toca := false
		for clave in POR_DEBAJO:
			if n.contains(clave):
				toca = true
		if not toca or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if mat == null:
				continue
			# Duplicado: el material del .glb lo comparten todas las instancias.
			var propio := mat.duplicate() as BaseMaterial3D
			propio.grow = true
			propio.grow_amount = -hundir_la_piel / escala
			mi.set_surface_override_material(s, propio)


## Alto del cuerpo, SIN el gorro.
##
## El tocado de diablada mide 2,4 m de los 12,9 que ocupa el modelo entero:
## escalando por el total, Carmen quedaría con el cuerpo a 1,4 m y el gorro
## comiéndose el resto. Se mide lo que mide ella y el gorro sube en proporción,
## que es como se lleva.
func _alto_del_cuerpo(raiz: Node3D) -> float:
	var lo := INF
	var hi := -INF
	for mi: MeshInstance3D in _mallas(raiz):
		if mi.name.to_lower().contains("gorro"):
			continue
		var caja: AABB = mi.get_aabb()
		lo = minf(lo, caja.position.y)
		hi = maxf(hi, caja.position.y + caja.size.y)
	return maxf(hi - lo, 0.0) if lo < INF else 0.0


func _mallas(n: Node) -> Array:
	var r: Array = []
	for h in n.get_children():
		if h is MeshInstance3D:
			r.append(h)
		r.append_array(_mallas(h))
	return r


func _buscar_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for h in n.get_children():
		var x := _buscar_anim(h)
		if x != null:
			return x
	return null


## El nombre del clip que hace ese papel en el traje que lleva puesto.
func clip_de(papel: String) -> String:
	var t: Dictionary = CLIPS.get(_traje, {})
	return String(t.get(papel, ""))


## Pone un clip en bucle, si no estaba ya puesto.
func _poner(clip: String) -> void:
	if _anim == null or clip == "" or clip == _clip_actual:
		return
	if not _anim.has_animation(clip):
		push_warning("Carmen: no tiene la animación '%s'" % clip)
		return
	_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_anim.play(clip)
	_clip_actual = clip


## La animación que toca según lo que esté haciendo.
func _refrescar_animacion() -> void:
	var quiero := ""
	if _walking:
		quiero = clip_de("caminar")
	elif _hablando:
		quiero = clip_de("hablando")
	elif _bailando:
		quiero = clip_de("bailar")
	if quiero == "":
		quiero = clip_de("idle")
	_poner(quiero)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return   # en el editor sólo se la muestra; no camina ni cambia de clip
	_refrescar_animacion()


## Camina hasta un punto SIN pelearse con la geometría.
##
## Con `move_and_slide` se quedaba trabada: entre la plaza (0,23 m) y el atrio
## de la iglesia (1,00) hay un escalón de casi un metro y ella no sabe subirlo.
## Se quedaba raspando el borde hasta que saltaba el tope, y en pantalla parecía
## que entraba por una esquina cualquiera en vez de por la puerta.
##
## En una escena en la que el jugador no tiene el control, la colisión no aporta
## nada: se la lleva a mano y se la apoya en el suelo cada cuadro, con lo que
## sube el escalón sola.
func _caminar_hasta(destino: Vector3, tope: float) -> void:
	_walking = true
	var t := 0.0
	while t < tope:
		await get_tree().physics_frame
		var d := get_physics_process_delta_time()
		t += d
		var falta := destino - global_position
		falta.y = 0.0
		if falta.length() < 0.25:
			break
		var dir := falta.normalized()
		global_position += dir * minf(VELOCIDAD * d, falta.length())
		_apoyar_en_el_suelo(2.5)
		_mirar_hacia(dir, d)
	_walking = false
	velocity = Vector3.ZERO


const VELOCIDAD := 3.0


## Gira el modelo hacia donde camina.
##
## `dir` viene en coordenadas de MUNDO y la rotación se aplica al hijo `Visual`,
## que va en las de Carmen: sin pasar por su base, y como ella está girada media
## vuelta en la plaza, caminaba de espaldas.
func _mirar_hacia(dir: Vector3, delta: float) -> void:
	var vis := get_node_or_null("Visual") as Node3D
	if vis == null:
		return
	var local: Vector3 = global_transform.basis.inverse() * dir
	vis.rotation.y = lerp_angle(vis.rotation.y, atan2(-local.x, -local.z), 8.0 * delta)


func _on_interacted(_player: Node) -> void:
	# `_hablando` es el importante: sin él, volver a pulsar E mientras el globo
	# está abierto encadena otra charla, y al cerrarse cada una lanzaba su propia
	# ida a la iglesia. En pantalla se veía entrar tres veces.
	if _walking or _en_escena or _hablando:
		return

	var texto := que_dice()
	_pending_walk = texto == DIALOGUE_FASE1
	_pending_unlock = texto == DIALOGUE_REVELACION
	_show(texto)


## Cuántas pistas hay que traer de la fiesta antes de que entregue el don.
const PISTAS_PARA_EL_DON := 4


## Qué le toca decir.
##
## Separado de `_on_interacted` para poder comprobarlo sin abrir un globo: lo
## que se prueba aquí es la puerta del don, y esa no se puede aflojar sin
## querer. El arco se entrega DESPUÉS de hablar con la gente del pueblo, no por
## acercarse a ella.
func que_dice() -> String:
	# La primera vez siempre se mete a la iglesia, aunque las habilidades ya
	# estén dadas por el menú de depuración.
	if not _has_walked:
		return DIALOGUE_FASE1
	if GameManager.has_ability("bow"):
		return DIALOGUE_AGAIN
	if pistas() >= PISTAS_PARA_EL_DON:
		return DIALOGUE_REVELACION
	return DIALOGUE_WAIT


## Las que lleva contadas el director de la fiesta. Sin director —en un test, o
## en un mapa sin fiesta— es cero: nunca de más.
func pistas() -> int:
	var director := get_tree().get_first_node_in_group("fiesta_director")
	return int(director.clues_given) if director != null else 0


func _on_dialogue_ended(_res: Resource) -> void:
	_hablando = false
	if _pending_walk:
		_pending_walk = false
		_has_walked = true
		Misiones.hecho("carmen")
		_entrar_a_la_iglesia()
	elif _pending_unlock:
		_pending_unlock = false
		GameManager.unlock("bow")
		if GameManager.get_beat() < 2:
			GameManager.set_beat(2)
		GameManager.conceder("tirana")


## Se mete a la iglesia y sale de La Tirana, contado con la cámara.
##
## El cambio de traje pasaba antes fuera de plano: Carmen se iba andando al
## altar y el jugador se enteraba de quién era leyendo un diálogo. Ahora la
## cámara la acompaña hasta la puerta, la ve entrar, y la vuelve a encontrar
## bailando entre los bailarines con el vestido de la fiesta.
##
## Es el MISMO nodo con otro traje, no dos personajes: así el diálogo de la
## revelación —que es el que entrega el arco y abre el beat 2— sigue colgando
## de quien siempre colgó.
func _entrar_a_la_iglesia() -> void:
	if _en_escena:
		return          # la escena no se solapa consigo misma
	_en_escena = true
	var juego := get_tree().get_first_node_in_group("game")
	var con_camara: bool = juego != null and juego.has_method("focus_camera_on")
	_trabar_a_los_jugadores(true)
	if con_camara:
		juego.focus_camera_on(self, 0.0, 7.0, 1.4)

	# Sin puerta —en un test, o en un mapa sin iglesia— se aleja como antes.
	await _caminar_hasta(
		_sitio(puerta_iglesia, global_position + Vector3(0.0, 0.0, -19.0)), 6.0)

	# Entra. La cámara se queda un momento en la puerta por la que desapareció.
	visible = false
	await _esperar(0.7)

	# Y reaparece bailando al otro lado de la plaza. La cámara sigue clavada en
	# ella, así que hace sola el viaje desde la iglesia hasta los bailarines: es
	# un paneo, no un corte.
	_ponerse_a_bailar()
	visible = true
	if con_camara:
		juego.focus_camera_on(self, 0.0, 6.0, 1.4)
	await _esperar(2.6)

	if con_camara:
		juego.clear_camera_focus()
	# La cámara vuelve interpolando: se le da el viaje antes de devolver el
	# control, o el jugador empieza a caminar con la imagen todavía a medio ir.
	await _esperar(1.2)
	_trabar_a_los_jugadores(false)
	_en_escena = false


## La planta entre los bailarines, ya vestida de fiesta.
func _ponerse_a_bailar() -> void:
	var marca := get_node_or_null(sitio_de_baile) as Node3D
	if marca != null:
		global_position = marca.global_position
		# El marcador manda también hacia dónde mira, y el giro del paseo hasta
		# la iglesia se descarta: si no, sale bailando de espaldas.
		global_rotation.y = marca.global_rotation.y
		var vis := get_node_or_null("Visual") as Node3D
		if vis != null:
			vis.rotation.y = 0.0
	_montar(modelo_tirana, "tirana")
	_bailando = true
	_apoyar_en_el_suelo()


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(maxf(segundos * ritmo_escena, 0.01)).timeout


## Quita o devuelve el control a los dos protagonistas, para que nadie se salga
## del cuadro mientras la cámara mira a Carmen.
func _trabar_a_los_jugadores(trabado: bool) -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if "input_locked" in p:
			p.input_locked = trabado


func _sitio(np: NodePath, por_defecto: Vector3) -> Vector3:
	if np.is_empty():
		return por_defecto
	var n := get_node_or_null(np) as Node3D
	return n.global_position if n != null else por_defecto


func _show(text: String) -> void:
	_hablando = true
	var res := DialogueManager.create_resource_from_text(text)
	DialogueManager.show_dialogue_balloon_scene(BALLOON, res, "start")
