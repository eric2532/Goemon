extends SceneTree
const Art=preload("res://scripts/forest/forest_art.gd")
const Profile=preload("res://scripts/forest/forest_structure_profile.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func run():
	for kind in ["wall","gate"]:
		for rotation in [0,1]:
			var building=Art.building({"id":12+rotation,"kind":kind,"rotation":rotation,"span":6,"wall_extensions":Vector2(0,3)})
			root.add_child(building)
			var fx=building.get_node_or_null("WallDamage")
			check(fx!=null,"%s rotation%d has visible damage feedback"%[kind,rotation])
			if fx==null:building.queue_free();continue
			var bodies=building.find_children("*","StaticBody3D",true,false).size()
			fx.sync_health(7500,7500,0)
			check(fx.stage==0 and not fx.visible,"Healthy %s has no cracks"%kind)
			fx.sync_health(7499,7500,.016)
			check(fx.stage==1 and fx.visible and fx.impact_left>0,"The first hit produces visible cracks and impact feedback")
			var nodes=fx.get_child_count()
			fx.sync_health(1000,7500,.016)
			check(fx.stage==4,"Severely damaged %s has spreading fractures"%kind)
			fx.sync_health(6000,7500,.3)
			check(fx.stage==1 and fx.impact_left==0,"Repairs reduce cracks without replaying a hit")
			fx.sync_health(7500,7500,.3)
			check(fx.stage==0 and not fx.visible,"Full repair clears cracks")
			for i in range(50):fx.sync_health(7000-i*10,7500,.016)
			check(fx.get_child_count()==nodes,"Repeated attacks reuse bounded visual nodes")
			check(building.find_children("*","StaticBody3D",true,false).size()==bodies,"Cracks never alter the wall collision")
			if kind=="gate":
				building.get_node("GateDoor").position.y=Profile.GATE_OPEN_Y;fx.sync_health(3000,7500,0)
				check(is_equal_approx(fx.position.y,Profile.GATE_OPENING_HEIGHT),"Gate cracks move with the raised door")
			building.queue_free()
	await process_frame
	print("WALL_DAMAGE_VISUAL_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
