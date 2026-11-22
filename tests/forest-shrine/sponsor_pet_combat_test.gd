extends "res://tests/forest-shrine/dragon_lizard_test.gd"
func skins()->Array:return range(Pets.COUNT).filter(func(skin):return Pets.category(skin)=="贊助")
