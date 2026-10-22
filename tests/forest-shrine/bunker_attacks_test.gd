extends SceneTree
var game
var checks=0
var failures=0
var cfg="user://bunker-attacks-%d.cfg"%OS.get_process_id()
var bunker:Dictionary
func _initialize():
 set_meta("forest_army_backend","legacy")
 if "--visual" in OS.get_cmdline_user_args():
  set_meta("forest_painterly_preview",true);root.set_flag(Window.FLAG_NO_FOCUS,true);root.size=Vector2i(1280,800)
 create_timer(100).timeout.connect(func():printerr("FAIL: bunker attacks timeout");quit(1))
 run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func frames(n:int=3):
 for i in n:await process_frame
func step(u,n:int):
 for i in n:
  u._physics_process(1.0/60)
  if i%6==0:await process_frame
func fighter(slot:int,clear:bool=true):
 var m=game.model;var h=game.explorer_helpers
 if clear:h.clear()
 m.phase="preparing";m.gold=5000;m.starting_food=40
 h.purchase(slot,m.point(Vector2i(5,10+h.active_units().size()*2)))
 var u=h.active_units().back();u.set_physics_process(false);u.state="acting";u.hp=20
 m.phase="wave";game.paused=false;paused=false
 u.shelter.tick(.1);u.global_position=m.point(m.entry(bunker));u.shelter.tick(.1)
 return u
func enemy_at(offset:Vector3):
 for e in game.actors.values():e.queue_free()
 game.actors.clear();game.enemies.clear();game.model.enemies.clear()
 var point=game.model.center(bunker)+offset
 var data=game.model.waves.spawn_enemy(0,point);data.hp=10000;data.max_hp=10000
 game.model.visible_cells[game.model.cell_of(point)]=true;game.sync_enemies();await frames()
 for e in game.actors.values():e.set_physics_process(false);e._sync_fitted_pose()
 return data
func capture(label_:String):
 if "--visual" not in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless":return
 game.camera_rig.set_process(false);game.pan=game.model.center(bunker);game.preparation_size=50;game.update_preparation_camera()
 await frames();await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Menu Assets/bunker-"+label_+".png")
func run():
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
 AudioServer.set_bus_mute(0,true)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.explorer_helpers.set_process(false)
 for u in game.gate_defenders.units.values():u.set_physics_process(false)
 game.model.gold=5000;bunker=game.model.build("barracks",Vector2i(12,10),0);game.world.sync(0);await physics_frame
 for slot in [1,2]:
  var u=await fighter(slot);var e=await enemy_at(Vector3(0,0,20))
  await step(u,8)
  await capture("arrows" if slot==1 else "stars")
  var kind="arrow" if slot==1 else "star"
  check(u.active_ability.projectiles.any(func(p):return p.kind==kind and p.life>0),"Sheltered %s emits its native projectile outside the bunker"%kind)
  await step(u,60)
  check(e.hp<10000,"Bunker %s damages a real enemy"%kind)
  check(not u.visible and u.state=="sheltered" and u.hp>20,"Ranged occupant stays hidden and heals while attacking")
  var hp=e.hp;game.ordinary_pause=true;await step(u,30);game.ordinary_pause=false
  check(e.hp==hp,"Pause freezes bunker attacks")
  game.model.phase="preparing";game.paused=true;game.explorer_helpers.rest();game.explorer_helpers._process(.1)
  hp=e.hp;await step(u,30)
  check(u.active_ability.projectiles.is_empty() and e.hp==hp,"Preparation cancels outgoing weapons and starts no attacks")
  game.model.phase="wave";game.paused=false;u.set_physics_process(false)
  u.hp=u.max_hp-.5;u.shelter.tick(.1)
  check(u.state=="returning" and u.visible,"Full health releases the ranged fighter to resume hunting")
 var first=await fighter(1);var second=await fighter(1,false);var ranged_target=await enemy_at(Vector3(0,0,20))
 await step(first,8);await step(second,8)
 check(first.active_ability.projectiles.size()>0 and second.active_ability.projectiles.size()>0 and game.model.fighter_count==2,"Two occupants each fire their own weapon and keep both population slots")
 await step(first,45)
 check(first.attack_chain.count>0,"Bunker hits earn their fighter's native chain credit")
 first.active_ability.cancel();second.active_ability.cancel()
 var blocker=StaticBody3D.new();blocker.collision_layer=1;var collision=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(24,12,1);collision.shape=box;blocker.add_child(collision);game.add_child(blocker);blocker.global_position=game.model.center(bunker)+Vector3(0,6,14)
 await physics_frame
 var before=ranged_target.hp
 await step(first,120);await step(second,120)
 check(ranged_target.hp==before and first.active_ability.projectiles.is_empty() and second.active_ability.projectiles.is_empty(),"Bunker shots respect intervening solid cover")
 check(first.attack_chain.count==0,"Interrupted bunker fire expires its native combo grace period")
 blocker.queue_free();await physics_frame;await physics_frame
 await step(first,90)
 check(ranged_target.hp<before,"Bunker resumes firing when cover is removed")
 var explorer=await fighter(4);var attacker=await enemy_at(Vector3(0,0,11))
 await step(explorer,30)
 check(attacker.hp==10000,"Explorer waits for the bunker to be attacked")
 game.model.damage_building(bunker.id,20);bunker.hp=bunker.max_hp
 await step(explorer,45)
 check(attacker.hp<10000,"Explorer counter-slashes a close attacker even if repairs restore the hit immediately")
 check(explorer.state=="sheltered" and not explorer.visible,"Counter-slashing Explorer remains sheltered")
 var dragoon=await fighter(0);var target=await enemy_at(Vector3(0,0,20))
 check(dragoon.visible and dragoon.global_position.y>game.model.center(bunker).y+5.9,"Sheltered Dragoon stands visibly on the stone deck")
 await capture("dragoon-deck")
 dragoon.set_physics_process(true)
 var leaped=false
 for i in 360:
  await physics_frame
  var travel=dragoon.active_ability.player.get("travel")
  if travel is Dictionary and travel.get("kind")=="lance-leap":leaped=true
  if target.hp<10000:break
 dragoon.set_physics_process(false)
 await capture("dragon-leap")
 check(leaped,"Deck Dragoon uses its native Dragon Leap")
 check(target.hp<10000,"Dragon Leap deals its native landing damage outside the bunker")
 check(dragoon.state=="bunker_leaping" and game.explorer_helpers.target_actor(dragoon.gate_id)==dragoon,"Leaping Dragoon is exposed and targetable outside the bunker")
 var frozen_position=dragoon.global_position
 game.ordinary_pause=true;await step(dragoon,12);game.ordinary_pause=false
 check(dragoon.global_position==frozen_position,"Pause freezes a Dragoon during Dragon Leap")
 var leap_hp=dragoon.hp
 dragoon.invuln=0;dragoon.active_ability.player.invuln=0;dragoon.take_hit(1,Vector3.FORWARD)
 check(dragoon.hp<leap_hp,"Exposed Dragoon can be damaged")
 dragoon.set_physics_process(true)
 for i in 720:
  await physics_frame
  if dragoon.state=="sheltered":break
 dragoon.set_physics_process(false)
 check(dragoon.state=="sheltered" and dragoon.visible,"Dragoon returns through the entrance to recover on the deck after landing")
 dragoon.hp=dragoon.max_hp-.5;dragoon.shelter.tick(.1)
 check(dragoon.state=="returning" and dragoon.collision_layer==2,"Fully healed Dragoon leaves for its original guard post")
 dragoon=await fighter(0);target=await enemy_at(Vector3(0,0,20))
 var ceiling=StaticBody3D.new();ceiling.collision_layer=1;var ceiling_shape=CollisionShape3D.new();var ceiling_box=BoxShape3D.new();ceiling_box.size=Vector3(20,.5,20);ceiling_shape.shape=ceiling_box;ceiling.add_child(ceiling_shape);game.add_child(ceiling);ceiling.global_position=game.model.center(bunker)+Vector3.UP*9.3
 await physics_frame;dragoon.set_physics_process(true)
 for i in 390:await physics_frame
 dragoon.set_physics_process(false)
 check(dragoon.state=="sheltered" and dragoon.hp>20,"A blocked leap returns the Dragoon to recovery without trapping him on the deck")
 ceiling.queue_free();await physics_frame
 dragoon=await fighter(0);target=await enemy_at(Vector3(0,0,20));dragoon.set_physics_process(true)
 for i in 360:
  await physics_frame
  if dragoon.active_ability.player.travel!=null:break
 check(dragoon.active_ability.player.travel!=null,"Second Dragoon starts a leap for destruction coverage")
 game.model.damage_building(bunker.id,100000);game.world.sync(0)
 for i in 360:
  await physics_frame
  if dragoon.state in ["returning","acting"]:break
 dragoon.set_physics_process(false)
 check(dragoon.visible and dragoon.state in ["returning","acting"] and dragoon.active_ability.player.travel==null,"Destroyed bunker does not strand a leaping survivor")
 game.model.phase="preparing";game.explorer_helpers.rest()
 check(dragoon.state=="prepared" and dragoon.active_ability.player.pulses.is_empty() and dragoon.global_position==dragoon.guard_post,"Wave end clears Dragoon combat and restores his guard post")
 game.model.gold=5000;bunker=game.model.build("barracks",Vector2i(12,10),0);game.world.sync(0)
 dragoon=await fighter(0);target=await enemy_at(Vector3(0,0,20));dragoon.set_physics_process(true)
 for i in 360:
  await physics_frame
  if dragoon.active_ability.player.travel!=null:break
 check(dragoon.active_ability.player.travel!=null,"Wave transition fixture reaches an active leap")
 game.model.phase="preparing";game.explorer_helpers.rest()
 check(dragoon.state=="prepared" and dragoon.active_ability.player.travel==null and dragoon.active_ability.player.pulses.is_empty() and dragoon.visible and dragoon.global_position==dragoon.guard_post,"Ending a wave during a leap cancels it and restores the fighter")
 await finish()
func finish():
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames();await create_timer(.25).timeout
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("BUNKER_ATTACKS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
