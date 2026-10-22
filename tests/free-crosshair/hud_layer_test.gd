extends "res://tests/free-crosshair/free_aim_test.gd"
## Native pixel check: a free reticle must remain visible over the bottom HUD.
func shot(label: String):
	await super.shot(label)
	if label!="free-aim" or DisplayServer.get_name()=="headless":return
	var original=game.crosshair_screen_position()
	motion(root.get_visible_rect().size*Vector2(.65,.94))
	await super.shot("over-hud")
	var capture=root.get_texture().get_image()
	var pixel=Vector2i(game.crosshair_screen_position()/root.get_visible_rect().size*Vector2(capture.get_size()))
	var color=capture.get_pixelv(pixel)
	check(color.r>.8 and color.g>.8 and color.b>.8,"The free reticle remains visible on top of the character HUD")
	motion(original)
