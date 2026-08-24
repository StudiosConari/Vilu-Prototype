extends "res://addons/gut/test.gd"

## El contorno toon tiene que medir lo mismo EN METROS DE MUNDO sin importar a
## qué escala esté puesto el modelo.
##
## Regresión de un fallo real: el contorno es un casco invertido y su
## `grow_amount` infla la malla en espacio LOCAL, antes de aplicar la
## transformación. Un modelo de iglesia puesto a escala 22 se llevaba un borde
## de 22 x 0.018 = 0.4 m, un manchón negro en vez de una línea. ToonSkin ahora
## mide la escala del nodo y divide.

const TOON := preload("res://scenes/core/ToonSkin.gd")


func _prop(escala: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3.ONE
	mi.mesh = caja
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.4, 0.2)
	mi.set_surface_override_material(0, mat)
	mi.scale = Vector3.ONE * escala
	add_child_autofree(mi)
	return mi


func _grosor_de_mundo(mi: MeshInstance3D) -> float:
	var mat := mi.get_surface_override_material(0)
	assert_not_null(mat, "el material se convirtió")
	var casco := (mat as ShaderMaterial).next_pass as StandardMaterial3D
	assert_not_null(casco, "lleva contorno de casco invertido")
	var e: Vector3 = mi.global_transform.basis.get_scale()
	var esc: float = maxf(maxf(absf(e.x), absf(e.y)), absf(e.z))
	return casco.grow_amount * esc


func test_el_grosor_no_depende_de_la_escala() -> void:
	var chico := _prop(1.0)
	var mediano := _prop(9.0)
	var enorme := _prop(22.0)
	await wait_physics_frames(2)

	var piel = autofree(TOON.new())
	piel.aplicar(chico)
	piel.aplicar(mediano)
	piel.aplicar(enorme)

	for par in [["escala 1", chico], ["escala 9", mediano], ["escala 22", enorme]]:
		var g: float = _grosor_de_mundo(par[1])
		gut.p("  %-10s grosor de mundo %.4f m" % [par[0], g])
		assert_almost_eq(g, TOON.CONTORNO_GROSOR, 0.002,
			"el contorno mide lo mismo a %s" % par[0])


func test_la_cache_no_mezcla_escalas() -> void:
	# Mismo material de origen a dos escalas: tienen que salir materiales
	# distintos, o el grande hereda el contorno del chico.
	var a := _prop(1.0)
	var b := _prop(20.0)
	await wait_physics_frames(2)
	var piel = autofree(TOON.new())
	piel.aplicar(a)
	piel.aplicar(b)
	var ca := (a.get_surface_override_material(0) as ShaderMaterial).next_pass
	var cb := (b.get_surface_override_material(0) as ShaderMaterial).next_pass
	assert_ne(ca.get_instance_id(), cb.get_instance_id(),
		"cada escala necesita su propio material de contorno")
