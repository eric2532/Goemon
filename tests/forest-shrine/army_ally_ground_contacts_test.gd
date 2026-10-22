extends SceneTree
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var fixture=load("res://tests/forest-shrine/large_army_fixture.gd").new();root.add_child(fixture)
 await fixture.make_game("original")
 fixture.clear_targets();fixture.reset_player(11)
 var enemy=fixture.add_target(Vector3(0,0,52))
 var h=fixture.game.explorer_helpers
 var unit=h.pool.filter(func(u):return u.kit_id==11)[0]
 unit.summon(enemy,Vector3(0,-.02,48.1),0);unit.set_physics_process(false)
 var combat=unit.active_ability;combat.player.pos=unit.position
 var rows=combat.living(unit.position,5)
 check(rows.size()==1,"Grounded ally finds the visible soldier at its fitted surface")
 var before=enemy.hp
 if not rows.is_empty():combat.hit(rows[0],19,"cutlass",false,Vector3.BACK)
 check(enemy.hp<before,"A sword contact on a soldier's lower body is not occluded by the floor endpoint")
 before=enemy.hp
 combat.resolve_area_pulse({"ticket":combat.current_ticket(),"pos":unit.position,"radius":4.2,"damage":64,"rangeScale":1.0,"index":0})
 check(enemy.hp<before,"A grounded landing pulse reaches visible body contacts above the floor")
 await fixture.close();fixture.queue_free();await process_frame
 print("ARMY_ALLY_GROUND_CONTACTS_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
