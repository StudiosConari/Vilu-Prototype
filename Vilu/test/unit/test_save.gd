extends "res://addons/gut/test.gd"

## Persistencia del progreso (sección "g") con un único escritor.

func after_all() -> void:
	GameManager.reset_progress()

func test_progress_roundtrip() -> void:
	Save.beat_index = 3
	Save.has_wings = true
	Save.has_guanaco = true
	Save.save_progress()

	var c := ConfigFile.new()
	assert_eq(c.load(Save.PATH), OK)
	assert_eq(int(c.get_value("g", "beat_index", -1)), 3)
	assert_true(bool(c.get_value("g", "has_wings", false)))
	assert_true(bool(c.get_value("g", "has_guanaco", false)))

func test_progress_does_not_wipe_volume_section() -> void:
	Save.music_vol = 0.42
	Save.set_music_vol(0.42)  # escribe sección "d"
	Save.beat_index = 5
	Save.save_progress()      # escribe "g" sin borrar "d"
	var c := ConfigFile.new()
	assert_eq(c.load(Save.PATH), OK)
	assert_almost_eq(float(c.get_value("d", "music_vol", -1.0)), 0.42, 0.001)
	assert_eq(int(c.get_value("g", "beat_index", -1)), 5)
