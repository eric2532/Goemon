extends SceneTree
var checks=0
var failures=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func key(code:int,pressed:bool=true,echo:bool=false)->InputEventKey:
 var event=InputEventKey.new();event.physical_keycode=code;event.pressed=pressed;event.echo=echo;return event
func _initialize():run.call_deferred()
func run():
 var fixture=load('res://tests/forest-shrine/large_army_fixture.gd').new();root.add_child(fixture)
 var game=await fixture.make_game('original');fixture.clear_targets()
 var p=fixture.reset_player(13);p.set_physics_process(false)
 p.position=Vector3(0,.05,60)
 for i in 3:p.velocity=Vector3.DOWN*20;p.move_and_slide()
 p.velocity=Vector3.ZERO
 var c=p.active_ability
 game.forest_ui._input(key(KEY_1))
 check(c.mode=='rotation' and c.charge==0,'Forest UI routes physical1 directly to uncharged Lumina Rotation')
 c.tick(.2);var elapsed=c.elapsed
 game.forest_ui._input(key(KEY_1,true,true));game.forest_ui._input(key(KEY_1,false))
 check(c.elapsed==elapsed,'echo and key release do not restart spin')
 c.cancel();p._unhandled_input(key(KEY_1))
 check(c.mode=='rotation','General Hero controls also route1')
 c.cancel();game.paused=true;game.forest_ui._input(key(KEY_1));p._unhandled_input(key(KEY_1))
 check(not c.is_attacking(),'paused menus block number attacks');game.paused=false
 c.cancel();game.forest_ui._input(key(KEY_2))
 check(c.mode=='counter','Physical2 directly triggers Mighty Strike')
 check(c.clip!='Extra__800d4f14','Counter uses recovered counter motion, not ordinary Lumina')
 c.cancel();game.forest_ui.preparation_mode='build';game.model.phase='preparing'
 game.forest_ui._input(key(KEY_1))
 check(not c.is_attacking(),'Building menu keeps its numbered building shortcuts')
 game.forest_ui.preparation_mode='';game.model.phase='wave'
 p.select_character(1);game.forest_ui._input(key(KEY_1))
 check(p.character_id==1 and p.weapon_slot==1,'Goemon numbered weapons retain their meaning')
 await fixture.close();fixture.queue_free();await process_frame
 print('MUSASHI_NUMBER_KEYS_TEST checks=',checks,' failures=',failures);quit(1 if failures else 0)
