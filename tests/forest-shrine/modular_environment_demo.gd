extends Node
## Isolated development map; normal Play and saved maps retain their current layout.
const FIXTURE="res://tests/forest-shrine/reference/maps/forest_modular_kit.json"
var game
func _ready():
 get_tree().set_meta("forest_custom_layout",JSON.parse_string(FileAccess.get_file_as_string(FIXTURE)))
 game=load("res://scenes/forest_shrine.tscn").instantiate()
 game.settings_path="user://modular-kit-%d.cfg"%OS.get_process_id()
 add_child(game)
 game.pan=Vector3(99,4,0);game.preparation_size=180;game.update_preparation_camera()
func _exit_tree():
 DirAccess.remove_absolute(ProjectSettings.globalize_path("user://modular-kit-%d.cfg"%OS.get_process_id()))
