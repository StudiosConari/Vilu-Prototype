extends Node3D

## Raiz jugable del MVP. Contenedor persistente: camara, luz, un holder de
## region y un HUD de depuracion. Delega la carga de region en TravelManager y
## lee el progreso de GameManager. El Player y el HUD real se anclan en fases
## posteriores; por ahora prueba el pipeline TitleScreen -> Game -> Region.

@onready var _region_holder: Node3D = $RegionHolder
@onready var _beat_label: Label = $DebugHUD/BeatLabel


func _ready() -> void:
	TravelManager.load_region(_region_holder, "Region1_Tarapaca")
	GameManager.beat_changed.connect(_on_beat_changed)
	_update_label()


func _on_beat_changed(_index: int) -> void:
	_update_label()


func _update_label() -> void:
	_beat_label.text = "VILU — greybox · Beat %d/%d · %s" % [
		GameManager.get_beat() + 1,
		GameManager.BEAT_COUNT,
		TravelManager.current_region,
	]
