extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Weapons=preload("res://scripts/recovered_goemon_weapons.gd")
var chain_hits=0
func ground_player():
 var p=game.player;p.position=Vector3(0,-.01,60);p.velocity=Vector3.DOWN*5;p.move_and_slide()
 check(p.is_on_floor(),"Chain fixture is physically grounded")
func chain_step(n:int):
 var p=game.player
 for i in n:
  p.chain_pipe_combat.tick(1.0/60)
  p.model.animate(0,0,p.is_on_floor(),p.velocity.y,p.attack_left/maxf(.001,p.attack_duration),false,1,false);p.model.sync_skeleton()
func run():
 await setup_fixture()
 var p=game.player;var c=p.chain_pipe_combat
 check(c.get_script().get_base_script().resource_path=="res://scripts/character_combat.gd" and c.get_parent()==p,"Chain uses shared character lifecycle and focus cancellation")
 for tick in range(12):
  var expected=maxf(0,(tick*41.2-tick*(tick+1)*6.8666666667*.5)/103.0)
  check(absf(RecoveredGoemonCombatProfile.chain_extension(tick/30.0)-expected)<.00001,"Chain motion matches original MIPS sample %d"%tick)
 fresh();ground_player();p.select_weapon(3);c.start("throw")
 check(c.pose().action==0x70,"Grounded chain starts original action70")
 chain_step(5)
 check(c.phase=="windup" and not p.model.chain_pipe.endpoint_override,"Chain head waits for the native release frame")
 chain_step(4)
 check(c.phase=="flight" and c.pose().action==0x71,"Release enters original ground flight71")
 chain_step(12)
 check(p.model.chain_pipe.endpoint_override and c.phase=="flight","Rendered head remains attached during flight")
 chain_step(110)
 check(not c.active and not p.model.chain_pipe.endpoint_override and c.attack_ticket.is_empty() and c.struck.is_empty(),"Return/catch clears all per-throw state")
 game.impact_confirmed.connect(func(victim,_strength,_duration):
  if victim==game.training_dummy:chain_hits+=1)
 game.training_dummy.position=ORIGIN+Vector3(0,0,-5);game.training_dummy.home=game.training_dummy.position
 fresh();ground_player();p.select_weapon(3);c.start("sweep");chain_step(130)
 check(chain_hits==1 and c.mode=="throw","RMB uses a forward chain throw and never hits a victim twice on return")
 chain_hits=0
 fresh();ground_player();p.select_weapon(3);c.start();c.tick(2.0)
 check(chain_hits==1 and not c.active,"One long update sweeps the complete throw and return without lost or duplicate hits")
 chain_hits=0;game.training_dummy.position=ORIGIN+Vector3(4,0,-3);game.training_dummy.home=game.training_dummy.position
 fresh();ground_player();p.select_weapon(3);c.start("sweep");chain_step(130)
 check(chain_hits==0,"The retired fan cannot hit a target beside the throw")
 var wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
 var collision=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(6,4,.2);collision.shape=box;wall.add_child(collision);game.add_child(wall);wall.position=Vector3(0,1.5,57)
 game.training_dummy.position=Vector3(0,0,54);game.training_dummy.home=game.training_dummy.position
 await physics_frame;await physics_frame
 fresh();ground_player();p.select_weapon(3);c.start();chain_step(90)
 check(chain_hits==0 and not c.active,"Cover turns the head back and protects the target behind it")
 wall.queue_free();await physics_frame
 fresh();p.select_weapon(3);p.position=ORIGIN+Vector3.UP*8;p.velocity=Vector3.UP;p.move_and_slide();c.start()
 check(c.pose().action==0x75,"Airborne chain uses action75, never prone action77")
 chain_step(5)
 check(c.pose().action==0x76 and p.model.locomotion.source_action==0x76,"Airborne release uses the proper flight pose on the rendered model")
 chain_step(110)
 check(not c.active and p.model.locomotion.source_action in [0x18,0x19],"Airborne return resumes jump/fall without a prone catch")
 fresh();p.select_weapon(3);p.position=ORIGIN+Vector3.UP*8;p.velocity=Vector3.UP;p.move_and_slide();c.start();ground_player();chain_step(5)
 check(c.pose().action==0x71,"Landing before airborne release selects the native ground hold")
 chain_step(83)
 check(c.phase=="catch" and c.pose().action==0x72,"A landed return plays ground catch72")
 c.cancel();fresh(true);ground_player();p.select_weapon(1);tap("weapon_pipe")
 check(p.weapon_slot==1 and p.attack_left>0 and not p.attack_charged,"Golden Goemon retains the ordinary pipe combo")
 fresh(true);ground_player();p.select_weapon(3);c.start()
 check(c.active and not p.model.chain_pipe.powered,"Golden Goemon retains chain attacks without an invented flame/explosion")
 check(is_equal_approx(c.damage,90*p.damage_multiplier()),"Golden chain keeps its existing tip damage bonus")
 c.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(not c.active and p.attack_left==0 and not p.model.chain_pipe.endpoint_override,"Shared focus loss safely cancels the chain")
 fresh(true);p.select_weapon(1);tap("weapon_coin")
 check(p.quick_attacks.active and p.weapon_slot==2 and p.attack_charged and not p.weapon_controls.charging,"Golden key2 immediately starts flaming ryo from another weapon")
 await step(10)
 var coins=get_nodes_in_group("projectiles").filter(func(coin):return coin.get_meta("original_goemon_charged_coin",false))
 check(coins.size()==1,"Golden ryo releases one original charged projectile without holding")
 if coins.size()==1:
  var material=coins[0].ornament.get_child(0).mesh.material
  check(material.albedo_texture.resource_path.ends_with("goemon_flaming_ryo.png"),"The actual projectile uses the recovered flaming ryo pixels")
  check(not coins[0].piercing,"Flaming ryo keeps the shared nearest-contact collision contract")
  var original=coins[0]
  check(is_instance_valid(original.projectile_pool) and original.pool_live,"Flaming ryo uses the shared character projectile cache")
  original.hit_enemies[123]=true;original.set_meta("original_goemon_charged_burst_played",true);original.retire()
  var ticket=p.attack_chain.make_ticket("coin");ticket["move_audio"]={"character_id":1,"move_key":"coin_charged","voiced":true}
  var reused=game.spawn_gold_coin(ORIGIN+Vector3(3,2,0),Vector3.RIGHT,true,true,1,false,0,ticket)
  check(reused==original and reused.pool_live and reused.hit_enemies.is_empty() and reused.attack_ticket==ticket and reused.global_position.distance_to(ORIGIN+Vector3(3,2,0))<.0001 and not reused.get_meta("original_goemon_charged_burst_played",false),"Reused flaming ryo resets hits, ticket, position and burst metadata")
  reused.retire();ticket=p.attack_chain.make_ticket("coin");ticket["move_audio"]={"character_id":1,"move_key":"coin","voiced":true}
  var normal=game.spawn_gold_coin(ORIGIN+Vector3.UP*2,Vector3.FORWARD,false,false,1,false,0,ticket)
  check(normal.ornament.get_child(0).mesh!=original.ornament.get_child(0).mesh,"Ordinary ryo keeps its own original artwork after a flaming cache reuse")
  normal.retire()

 await step(45)
 check(p.weapon_slot==1,"A flaming number-key throw restores the selected pipe")
 fresh(true);p.select_weapon(2);p.end_surge();tap("light_attack")
 check(not p.attack_charged,"Ryo returns to ordinary throws when golden form ends")
 for id in [1,16,17]:
  p.select_character(id);game.forest_ui.sync()
  check(game.forest_ui.primary_icon.texture.resource_path.begins_with("res://assets/ui/rom_weapons/"),"Character%d displays original ROM weapon artwork"%id)
 p.select_character(1);fresh(true);game.forest_ui.sync()
 check(game.forest_ui.goemon_weapon_icon(2).resource_path.ends_with("goemon_flaming_ryo.png"),"Golden hotbar shows the original flaming ryo icon")
 var first=Weapons.create_coin(true);var second=Weapons.create_coin(true)
 check(first.get_child(0).mesh==second.get_child(0).mesh,"Repeated flaming ryo shares its prepared mesh and material")
 first.free();second.free()
 fresh();ground_player();p.select_weapon(3)
 game.training_dummy.position=Vector3(500,0,500);game.training_dummy.home=game.training_dummy.position
 await create_timer(.5).timeout
 for i in 4:c.start();chain_step(135)
 await frames(4)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 16:c.start();chain_step(135)
 await frames(4)
 check(get_node_count()<=nodes+4 and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources+4,"Repeated empty-range throws retain no nodes/resources (%d/%d -> %d/%d)"%[nodes,resources,get_node_count(),Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)])
 game.queue_free();paused=false;await frames();await create_timer(.15).timeout
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("GOEMON_ROM_WEAPONS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
