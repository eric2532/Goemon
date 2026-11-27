extends "res://tests/forest-shrine/east_market_goods_preview.gd"
const Displays=preload("res://scripts/forest/forest_east_display_furniture.gd")
func fixture_owner():return Displays
func output_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Display Furniture/"
func capture_prefix()->String:return "display"
