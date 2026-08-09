extends Control

# Menu de inicio: titulo + JUGAR + opciones (volumen) + record + controles.

var _options: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.10, 0.12, 0.17)
	add_child(bg)

	var title := _label("VILU", 100, Color(1.0, 0.85, 0.4), 12)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.position.y = 70
	add_child(title)

	var sub := _label("Prototipo — greybox", 30, Color(0.9, 0.9, 0.95), 6)
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.position.y = 190
	add_child(sub)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 24)
	center.add_child(vb)

	var play := Button.new()
	play.text = "JUGAR"
	play.custom_minimum_size = Vector2(300, 80)
	play.add_theme_font_size_override("font_size", 40)
	play.pressed.connect(_on_play)
	vb.add_child(play)

	var opts := Button.new()
	opts.text = "Opciones"
	opts.custom_minimum_size = Vector2(300, 54)
	opts.add_theme_font_size_override("font_size", 26)
	opts.pressed.connect(func(): _options.visible = true)
	vb.add_child(opts)

	var quit := Button.new()
	quit.text = "Salir"
	quit.custom_minimum_size = Vector2(300, 54)
	quit.add_theme_font_size_override("font_size", 26)
	quit.pressed.connect(func(): get_tree().quit())
	vb.add_child(quit)

	_build_options()

	var help := _label(
		"WASD mover  ·  Shift correr  ·  Clic izq atacar  ·  Espacio saltar\n"
		+ "T hablar  ·  Clic der rotar camara",
		22, Color(0.8, 0.85, 0.9), 5)
	help.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	help.position.y = -110
	add_child(help)


func _build_options() -> void:
	_options = Control.new()
	_options.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options.visible = false
	add_child(_options)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.75)
	_options.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options.add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 20)
	cc.add_child(vb)
	vb.add_child(_label("OPCIONES", 46, Color(1.0, 0.85, 0.4), 8))
	vb.add_child(_slider_row("Musica", Save.music_vol, Save.set_music_vol, false))
	vb.add_child(_slider_row("Efectos", Save.sfx_vol, Save.set_sfx_vol, true))
	var back := Button.new()
	back.text = "Volver"
	back.custom_minimum_size = Vector2(480, 58)
	back.add_theme_font_size_override("font_size", 30)
	back.pressed.connect(func(): _options.visible = false)
	vb.add_child(back)


func _slider_row(row_name: String, value: float, cb: Callable, preview: bool) -> Control:
	var row := VBoxContainer.new()
	var lbl := _label(row_name, 26, Color.WHITE, 4)
	row.add_child(lbl)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(480, 34)
	s.value_changed.connect(func(v):
		cb.call(v)
		if preview:
			Sfx.play("hit", -4.0))
	row.add_child(s)
	return row


func _label(txt: String, fsize: int, col: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", outline)
	return l


func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/core/Game.tscn")
