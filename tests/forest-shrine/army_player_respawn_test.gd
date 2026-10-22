extends "res://tests/forest-shrine/player_respawn_test.gd"
func _initialize():

 super._initialize()
func finish():
 print("ARMY_PLAYER_RESPAWN_RESULT checks=",checks," failures=",failures)
 await super.finish()
