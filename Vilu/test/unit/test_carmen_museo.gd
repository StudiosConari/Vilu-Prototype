extends GutTest

## Los dos defectos del modelo del museo: la boca que no seguía a la cabeza y
## la piel que atravesaba la ropa.

const CARMEN := preload("res://scenes/actors/CarmenNPC.gd")
const MODELO := preload("res://models/personaje/carmen_museo.glb")


## Carmen sólo como caja de herramientas: NO se mete en el árbol, porque su
## _ready monta la escena entera —zona de interacción incluida— y aquí sólo se
## le piden los arreglos que le hace al modelo.
func _carmen() -> Node3D:
	var c: Node3D = CARMEN.new()
	autofree(c)
	return c


func _modelo() -> Node3D:
	var m: Node3D = MODELO.instantiate()
	add_child_autofree(m)
	return m


func _esqueleto(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for h in n.get_children():
		var x := _esqueleto(h)
		if x != null:
			return x
	return null


func _mallas(n: Node) -> Array:
	var r: Array = []
	if n is MeshInstance3D:
		r.append(n)
	for h in n.get_children():
		r.append_array(_mallas(h))
	return r


func _malla(n: Node, clave: String) -> MeshInstance3D:
	for mi: MeshInstance3D in _mallas(n):
		if mi.name.to_lower().contains(clave):
			return mi
	return null


# ─── La boca ─────────────────────────────────────────────────────────────────

func test_el_modelo_trae_la_boca_colgada_de_un_hueso_suelto() -> void:
	# Si esto deja de fallar es que arreglaron el .glb y el parche sobra.
	var m := _modelo()
	var esq := _esqueleto(m)
	var i := esq.find_bone("neutral_bone")
	assert_gt(i, -1, "el .glb trae el hueso huérfano del exportador")
	assert_eq(esq.get_bone_parent(i), -1, "y viene sin padre")


func test_el_hueso_suelto_pasa_a_colgar_de_la_cabeza() -> void:
	var m := _modelo()
	var esq := _esqueleto(m)
	_carmen().call("_enganchar_los_huesos_sueltos", m)
	var i := esq.find_bone("neutral_bone")
	assert_eq(esq.get_bone_parent(i), esq.find_bone("cabeza"),
		"la boca ya sigue a la cara")


func test_la_raiz_de_verdad_no_se_toca() -> void:
	var m := _modelo()
	var esq := _esqueleto(m)
	_carmen().call("_enganchar_los_huesos_sueltos", m)
	assert_eq(esq.get_bone_parent(esq.find_bone("raiz")), -1,
		"del esqueleto entero cuelga: no es un huérfano suelto")


func test_adoptarlo_no_lo_mueve_de_sitio() -> void:
	var m := _modelo()
	var esq := _esqueleto(m)
	var i := esq.find_bone("neutral_bone")
	var antes := esq.get_bone_global_rest(i)
	_carmen().call("_enganchar_los_huesos_sueltos", m)
	assert_almost_eq(esq.get_bone_global_rest(i).origin.distance_to(antes.origin),
		0.0, 0.001, "el descanso se recalcula para que quede donde estaba")


func test_al_girar_la_cabeza_la_boca_la_acompana() -> void:
	var m := _modelo()
	var esq := _esqueleto(m)
	_carmen().call("_enganchar_los_huesos_sueltos", m)
	var i := esq.find_bone("neutral_bone")
	var cabeza := esq.find_bone("cabeza")
	var antes := esq.get_bone_global_pose(i).origin
	esq.set_bone_pose_rotation(cabeza,
		Quaternion(Vector3.UP, deg_to_rad(45.0)))
	var despues := esq.get_bone_global_pose(i).origin
	assert_gt(antes.distance_to(despues), 0.01,
		"girando el cuello, la boca se mueve con él en vez de quedarse atrás")


# ─── La piel bajo la ropa ────────────────────────────────────────────────────

func test_la_ropa_se_separa_mas_que_lo_que_hunde_la_piel() -> void:
	var c := _carmen()
	# El hombro no se tapa sólo hundiendo: hundir lo suficiente adelgaza la cara
	# y vuelve a sacar la boca. El grueso del trabajo lo hace inflar la tela.
	assert_gt(c.inflar_la_ropa, c.hundir_la_piel,
		"la tela se aparta más de lo que se hunde la piel")
	assert_gt(c.inflar_los_adornos, c.inflar_la_ropa,
		"y el logo y la credencial, más que la tela, o se los traga")


func test_la_piel_y_la_ropa_quedan_separadas_de_verdad() -> void:
	var m := _modelo()
	var c := _carmen()
	c.call("_hundir_la_piel", m)
	var piel := _malla(m, "cuerpo")
	var ropa := _malla(m, "polera")
	var logo := _malla(m, "logo")
	for par in [[piel, -c.hundir_la_piel], [ropa, c.inflar_la_ropa],
			[logo, c.inflar_los_adornos]]:
		var mi: MeshInstance3D = par[0]
		var mat := mi.mesh.surface_get_material(0) as BaseMaterial3D
		assert_not_null(mat, "%s lleva material propio" % mi.name)
		assert_true(mat.grow, "%s crece" % mi.name)
		# En metros: `grow_amount` va en unidades de la malla.
		assert_almost_eq(mat.grow_amount * maxf(m.scale.x, 0.0001),
			float(par[1]), 0.0001, "%s se aparta lo pedido" % mi.name)


func test_la_boca_no_se_hunde() -> void:
	var m := _modelo()
	_carmen().call("_hundir_la_piel", m)
	for clave in ["boca", "epiglotis"]:
		var mi := _malla(m, clave)
		var mat := mi.mesh.surface_get_material(0) as BaseMaterial3D
		# Es una lámina fina: moverla a lo largo de sus normales la invierte y
		# aparecen manchas rosas en la mejilla. Lo suyo se arregla en el hueso.
		assert_false(mat != null and mat.grow,
			"'%s' se queda como está" % mi.name)
