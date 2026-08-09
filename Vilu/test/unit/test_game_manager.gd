extends "res://addons/gut/test.gd"

## Lógica de progreso: beat (set/advance/clamp) y desbloqueo de habilidades.

func before_each() -> void:
	GameManager.reset_progress()

func after_all() -> void:
	GameManager.reset_progress()


func test_starts_at_beat_zero() -> void:
	assert_eq(GameManager.get_beat(), 0)

func test_advance_beat() -> void:
	GameManager.advance_beat()
	assert_eq(GameManager.get_beat(), 1)

func test_set_beat_clamps_high() -> void:
	GameManager.set_beat(999)
	assert_eq(GameManager.get_beat(), GameManager.BEAT_COUNT - 1)

func test_set_beat_clamps_low() -> void:
	GameManager.set_beat(-5)
	assert_eq(GameManager.get_beat(), 0)

func test_unlock_ability_emits_signal() -> void:
	watch_signals(GameManager)
	assert_false(GameManager.has_ability("bow"))
	GameManager.unlock("bow")
	assert_true(GameManager.has_ability("bow"))
	assert_signal_emitted(GameManager, "ability_unlocked")

func test_unlock_persists_in_save() -> void:
	GameManager.unlock("wings")
	assert_true(Save.has_wings)

func test_unknown_ability_is_false() -> void:
	assert_false(GameManager.has_ability("teleport"))
