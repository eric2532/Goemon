extends "res://scripts/forest/forest_map_document.gd"
## Retired layouts are fixtures for saved-map compatibility and combat regression tests.
const VALLEY_PATH="res://tests/forest-shrine/reference/maps/forest_wind_meadow_valley.json"
const VALLEY_LARGE_PATH="res://tests/forest-shrine/reference/maps/forest_wind_meadow_large_valley.json"
func load_valley()->String:return read_file(VALLEY_PATH)
func load_valley_large()->String:return read_file(VALLEY_LARGE_PATH)
const ORIGINAL_PATH="res://tests/forest-shrine/reference/maps/forest_shrine_original.json"
const RAMPARTS_PATH="res://tests/forest-shrine/reference/maps/forest_twin_ramparts.json"
const FOUR_GATES_PATH="res://tests/forest-shrine/reference/maps/forest_four_gates.json"
const BLOOD_GULCH_PATH="res://tests/forest-shrine/reference/maps/forest_blood_gulch.json"
const KAI_HIGHWAY_PATH="res://tests/forest-shrine/reference/maps/forest_kai_highway.json"
func load_original()->String:return read_file(ORIGINAL_PATH)
func load_ramparts()->String:return read_file(RAMPARTS_PATH)
func load_four_gates()->String:return read_file(FOUR_GATES_PATH)
func load_blood_gulch()->String:return read_file(BLOOD_GULCH_PATH)
func load_kai_highway()->String:return read_file(KAI_HIGHWAY_PATH)
static func load_editor(editor,file_path:String):
	editor.request_replace(func():
		var error=editor.document.read_file(file_path)
		assert(error.is_empty(),"Legacy map fixture failed to load")
		editor.name_field.text=editor.document.data.title;editor.choose_piece("");editor.refresh_document()
		var frame=editor.game.preparation_map_frame();editor.game.pan=frame.pan;editor.game.preparation_size=frame.size;editor.game.update_preparation_camera())
