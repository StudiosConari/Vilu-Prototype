extends RefCounted

## El panel de Opciones, uno solo para las dos pantallas que lo abren.
##
## Está en el menú de inicio y en el de pausa, y son EL MISMO panel: los mismos
## deslizadores, el mismo aspecto y el mismo botón de volver. Escrito dos veces
## acabarían separándose sin que nadie se diera cuenta —uno con la música y el
## otro sin ella, o con otro tamaño de letra—, que es lo que ya pasó con la
## placa antes de sacarla a su archivo.
##
## Se usa sin instanciar:
##   const OPCIONES := preload("res://scenes/ui/PanelOpciones.gd")
##   var panel := OPCIONES.construir()
##   add_child(panel)
##   ...   panel.visible = true

const PLACA := preload("res://scenes/ui/Placa.gd")

## Ancho del panel, en píxeles de interfaz.
const ANCHO := 620.0


## Devuelve el panel ya montado y OCULTO. Quien lo pide decide cuándo se ve.
static func construir() -> Control:
	var raiz := Control.new()
	raiz.name = "PanelOpciones"
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.visible = false

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.06, 0.86)
	raiz.add_child(dim)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(cc)

	var marco := PanelContainer.new()
	marco.custom_minimum_size = Vector2(ANCHO, 0)
	marco.add_theme_stylebox_override("panel", PLACA.estilo(0.0, 0.92, 26))
	cc.add_child(marco)

	var aire := MarginContainer.new()
	aire.add_theme_constant_override("margin_top", 26)
	aire.add_theme_constant_override("margin_bottom", 26)
	marco.add_child(aire)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 20)
	aire.add_child(vb)
	vb.add_child(PLACA.lema("OPCIONES", 34))
	vb.add_child(_fila("Música", Save.music_vol, Save.set_music_vol, false))
	vb.add_child(_fila("Efectos", Save.sfx_vol, Save.set_sfx_vol, true))
	vb.add_child(PLACA.filete())

	var volver := PLACA.boton("Volver")
	volver.pressed.connect(func() -> void: raiz.visible = false)
	vb.add_child(volver)
	return raiz


## Un deslizador con su nombre encima.
##
## `con_prueba` hace sonar un golpe al moverlo: en los efectos hace falta oír lo
## que estás ajustando, y en la música no —la música ya está sonando—.
static func _fila(titulo: String, valor: float, guardar: Callable,
		con_prueba: bool) -> Control:
	var fila := VBoxContainer.new()
	var lbl := Label.new()
	lbl.text = titulo
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	fila.add_child(lbl)

	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = valor
	s.custom_minimum_size = Vector2(0, 34)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(v: float) -> void:
		guardar.call(v)
		if con_prueba:
			Sfx.play("hit", -4.0))
	fila.add_child(s)
	return fila
