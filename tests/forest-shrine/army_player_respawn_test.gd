extends "res://tests/forest-shrine/player_respawn_test.gd"
func _initialize():
 set_meta("forest_army_backend","native")
 super._initialize()
func finish():
 print("ARMY_PLAYER_RESPAWN_RESULT checks=",checks," failures=",failures)
 await super.finish()
