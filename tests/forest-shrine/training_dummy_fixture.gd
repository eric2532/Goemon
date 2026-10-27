extends RefCounted
## Combat tests opt into a practice target; normal gameplay has none.
static func install(game)->Ninja:
	if is_instance_valid(game.training_dummy):return game.training_dummy
	var dummy=preload("res://scripts/forest/forest_training_dummy.gd").new()
	dummy.name="TrainingDummy";dummy.game=game;dummy.position=game.model.point(Vector2i(2,2))
	dummy.process_mode=Node.PROCESS_MODE_PAUSABLE;game.add_child(dummy)
	game.training_dummy=dummy;game.sync_training_dummy()
	return dummy
