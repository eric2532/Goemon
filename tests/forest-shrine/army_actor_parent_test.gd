extends SceneTree
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var doc=load("res://tests/forest-shrine/reference/map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 var game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://army-actor-parent-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 for i in 3:await process_frame
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.explorer_helpers.set_process(false)
 var army=game.army_runtime;army.set_process(false);var parent:Node3D=army.actor_root;var siblings=game.get_child_count();var reserves=parent.get_children().duplicate()
 check(parent.get_parent()==game and parent.transform==Transform3D.IDENTITY,"NPC parent preserves the original game transform and pause inheritance")
 var actors=[]
 for i in 300:
  var p=Vector3(i%20-10,0,i/20-8);var row:Dictionary=game.model.waves.spawn_enemy([0,1,3][i%3],p)
  var h:int=army.spawn(row.id,0,row.variant,p,row.hp,1.3);var actor=army.enemy_target(row.id);actors.append(actor)
  check(actor.handle==h and actor.get_parent()==parent and actor.global_position==p and actor.get_collision_layer()==4,"Enemy keeps its generation, world pose and player-query collider under the dedicated parent")
 for slot in 5:
  var unit=game.explorer_helpers.make_unit(slot);var p=Vector3(slot*2,0,30);unit.summon(null,p,0)
  check(unit.get_parent()==parent and unit.position==p and army.valid(unit.handle),"Every autonomous helper uses the same scene parent and original local pose")
 var ally:int=army.spawn(-90000,1,11,Vector3(5,0,5),200,.4);var facade=army.ally_target(-90000)
 check(facade.handle==ally and facade.get_parent()==parent,"Non-pool ally facades share the same parent")
 army.despawn(ally);army.allies.erase(-90000);facade.queue_free()
 check(game.get_child_count()==siblings,"Hundreds of NPC arrivals leave HUD siblings and their child order unchanged")
 for i in 100:
  army.despawn(actors[i].handle);actors[i].queue_free()
 await process_frame
 check(game.get_child_count()==siblings and is_instance_valid(parent),"NPC retirement does not rebuild the game/HUD sibling list")
 reserves=game.explorer_helpers.pool.duplicate();army.clear();await process_frame
 check(parent.get_child_count()==reserves.size() and parent.get_children().all(func(n):return n in reserves) and game.get_child_count()==siblings,"Clearing an army retires its combatants while retaining the original idle helper reserves and stable parent")
 army.configure(game)
 check(army.actor_root==parent and game.get_child_count()==siblings,"Reconfiguring the same game reuses its parent without duplicate scene nodes")
 var h:int=army.spawn(90000,0,0,Vector3(3,0,9),192,1.3);var replacement=army.enemy_target(90000)
 check(replacement.handle==h and replacement.get_parent()==parent,"A new army can immediately reuse the stable parent")
 game.sound_library.cancel();game.music.stop();game.queue_free()
 for i in 3:await process_frame
 check(not is_instance_valid(parent),"The parent and remaining NPCs retire with their owning game")
 print("ARMY_ACTOR_PARENT_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
