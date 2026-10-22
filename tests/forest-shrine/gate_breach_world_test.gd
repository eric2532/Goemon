extends SceneTree
var checks=0
var failures=0
var cfg="user://gate-breach-world-%d.cfg"%OS.get_process_id()
func _initialize():
 set_meta("forest_army_backend","legacy")
 run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func run():
 var game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 var gates=game.model.buildings.values().filter(func(b):return b.kind=="gate")
 check(gates.size()==4,"The current castle retains all four gate entrances")
 for b in gates:
  var node=game.world.structure_nodes[b.id];var instance=node.get_instance_id()
  var door=node.get_node("GateDoor");var collider=door.get_node("GateDoorCollider")
  b.hp=0;b.breached=true;game.world.sync(.1)
  check(not door.visible and collider.collision_layer==0,"A breached gate hides only its door and disables only the leaf collider")
  check(game.world.structure_nodes[b.id].get_instance_id()==instance and node.visible,"The permanent gate frame remains the same visible world structure")
  check(not node.get_node("WallDamage").visible,"A missing door cannot leave floating fractures across the passage")
  b.hp=b.max_hp;b.breached=false;game.world.sync(.1)
  check(door.visible and collider.collision_layer==32,"Restoring a gate shows the leaf and reenables its existing friendly-passage collider")
  check(game.world.structure_nodes[b.id].get_instance_id()==instance,"Repair does not rebuild or replace permanent gate geometry")
 # A repairer stands behind the door; that is not a request to open it.
 var repairing=gates[0];var gate_center=game.model.center(repairing)
 var normal=game.model.waves.navigation.gate_outward(repairing)
 game.model.hero_position=Vector3(0,0,200);game.model.defenders.clear()
 for w in game.model.workers.values():w.pos=Vector3(0,0,200)
 var repairer=game.model.workers.values()[0]
 repairer.pos=gate_center-normal*6;repairer.state="repair";repairer.job=repairing.id
 repairing.hp=1500;game.world.sync(1)
 var repairing_door=game.world.structure_nodes[repairing.id].get_node("GateDoor")
 check(is_equal_approx(repairing_door.position.y,game.world.Profile.GATE_CLOSED_Y),"A worker repairing behind an intact door does not hold it open")
 var wall=game.model.buildings.values().filter(func(b):return b.kind=="wall")[0]
 wall.hp-=100;game.world.sync(.1)
 var wall_node=game.world.structure_nodes[wall.id]
 check(not wall_node.get_node("Health").visible and not wall_node.get_node("WallDamage").visible,"Indestructible walls show no damage state or repair bar")
 game.forest_ui.selected_id=wall.id;game.forest_ui.sync()
 check("Indestructible" in game.forest_ui.inspect_text.text and "Auto repair" not in game.forest_ui.inspect_text.text,"Wall inspection explains that this barrier cannot be damaged or repaired")
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
 for i in 3:await process_frame
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("GATE_BREACH_WORLD_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
