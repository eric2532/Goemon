extends "res://tests/forest-shrine/east_market_goods_preview.gd"
## Same two-angle gallery; these fifteen source-matched forms remain private.
const Misc=preload("res://scripts/forest/forest_east_misc_furniture.gd")
func fixture_owner():return Misc
func output_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Misc Furniture/"
func capture_prefix()->String:return "misc"
