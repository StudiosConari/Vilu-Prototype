extends GutTest

## Cada golpe de la cadena tiene que verse.
##
## La espera entre golpes era fija en 0.28 s mientras los clips duran de 0.67 a
## 1.30 s, así que cada golpe cortaba al anterior antes de la mitad. Ahora la
## marca la animación.

const PLAYER := preload("res://scenes/actors/Player.tscn")


## Con SUELO: sin él `is_on_floor()` es falso, el animador cree que está en el
## aire y saca la patada de carrera en vez del golpe de la cadena.
func _emilia() -> CharacterBody3D:
	var suelo := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(40, 1, 40)
	cs.shape = caja
	suelo.add_child(cs)
	add_child_autofree(suelo)
	suelo.global_position = Vector3(0, -0.5, 0)

	var p: CharacterBody3D = PLAYER.instantiate()
	p.is_archer = false
	add_child_autofree(p)
	p.global_position = Vector3(0, 0.05, 0)
	for i in 10:
		await get_tree().physics_frame
	GameManager.unlock("bow")     # la Tirana: habilita la cadena de cuatro
	return p


func _animador(p: Node) -> AnimationPlayer:
	var em := p.get_node_or_null("Visual/Animador")
	if em == null:
		return null
	return _buscar(em)


func _buscar(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for h in n.get_children():
		var x := _buscar(h)
		if x != null:
			return x
	return null


func test_cada_golpe_de_la_cadena_suena_su_clip() -> void:
	var p: CharacterBody3D = await _emilia()
	var ap := _animador(p)
	assert_not_null(ap, "Emilia tiene que traer su animador")
	var esperados := ["jab_izquierdo", "cruzado", "patada", "patada_final"]
	for paso in 4:
		p._attack_cd = 0.0
		p._combo_timer = 1.0
		p._combo_step = paso - 1
		if paso == 0:
			p._combo_timer = 0.0
		p._melee_attack()
		assert_eq(p._combo_step, paso, "avanza al paso %d" % paso)
		assert_eq(ap.current_animation, esperados[paso],
			"el paso %d suena %s" % [paso, esperados[paso]])


## Los tres primeros se pueden cortar en el impacto; el remate se ve entero.
func test_los_tres_primeros_se_cortan_en_el_impacto() -> void:
	var p: CharacterBody3D = await _emilia()
	var ap := _animador(p)
	for paso in 3:
		p._attack_cd = 0.0
		p._combo_timer = 1.0 if paso > 0 else 0.0
		p._combo_step = paso - 1
		p._melee_attack()
		var dura: float = ap.get_animation(ap.current_animation).length
		assert_lt(p._attack_cd, dura,
			"el paso %d (%s) se puede cortar antes de terminar" % [paso, ap.current_animation])
		assert_gt(p._attack_cd, 0.05,
			"pero no al instante: el corte cae en el impacto, no al empezar")


func test_el_remate_no_se_interrumpe() -> void:
	var p: CharacterBody3D = await _emilia()
	var ap := _animador(p)
	p._attack_cd = 0.0
	p._combo_timer = 1.0
	p._combo_step = 2
	p._melee_attack()
	assert_eq(ap.current_animation, "patada_final", "el cuarto es el remate")
	var dura: float = ap.get_animation("patada_final").length
	assert_almost_eq(p._attack_cd, dura, 0.01,
		"el remate se ve entero: la espera es todo el clip")


func test_la_ventana_sigue_abierta_cuando_termina_la_espera() -> void:
	var p: CharacterBody3D = await _emilia()
	p._attack_cd = 0.0
	p._combo_timer = 0.0
	p._melee_attack()
	assert_gt(p._combo_timer, p._attack_cd,
		"si la ventana cerrara antes que la espera, la cadena se reiniciaría sola")


func test_benjamin_conserva_su_cadencia() -> void:
	var b: CharacterBody3D = PLAYER.instantiate()
	b.is_archer = true
	add_child_autofree(b)
	b._attack_cd = 0.0
	b._combo_timer = 0.0
	b._melee_attack()
	assert_almost_eq(b._attack_cd, b.attack_cooldown, 0.001,
		"el arquero no tiene animador: se queda con la espera fija")
