extends SceneTree
func _initialize():run.call_deferred()
func run():
	var game=load("res://scenes/main.tscn").instantiate()
	game.smoke_test=true;root.add_child(game)
	var suite=load("res://scripts/crimson_combat_tests.gd").new()
	suite.game=game;game.add_child(suite)
	await suite.run()
