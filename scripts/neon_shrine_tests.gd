extends SceneTree
## The live spawner must deliver distinct new opponents through the crowd batches.
var game
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures+=1;push_error("FAIL: "+label)
 else:print("PASS: ",label)
func frames(count: int):
 for i in range(count):await physics_frame
func run():
 game=load("res://scenes/main.tscn").instantiate();game.smoke_test=true;root.add_child(game)
 game.tuning.freeze_ai=true;game.tuning.invincible=true;game.start_mode("defense");await frames(5)
 game.encounters.set_physics_process(false)
 var environment=game.world.find_children("*","WorldEnvironment",true,false)[0].environment
 check(environment.sky.sky_material.sky_top_color.get_luminance()<.15,"Standard siege uses the dusk sky")
 var details=game.world.get_node_or_null("NeonShrineDetails")
 check(details!=null,"Standard siege includes the illuminated Japanese shrine details")
 if details:
  check(details.find_children("*","CollisionObject3D",true,false).is_empty(),"Neon decoration leaves navigation and construction unobstructed")
  check(details.find_children("*","GeometryInstance3D",true,false).all(func(n):return n.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),"Neon trim adds no shadow casters")
 game.encounters.update_start_input(0,false);game.encounters.update_start_input(3.1,true)
 game.encounters._spawn_due(300);await frames(3)
 check(game.enemies.size()==300 and game.encounters.pending==0,"Expanded roster still spawns exactly 300 actors per wave")
 var ronin=game.enemies.filter(func(e):return e.get_meta("siege_archetype","")=="cyber_ronin")
 var oni=game.enemies.filter(func(e):return e.get_meta("siege_archetype","")=="armored_oni")
 check(ronin.size()==30 and oni.size()==30,"Actual waves include both new enemy types")
 if not ronin.is_empty() and not oni.is_empty():
  check(ronin[0].hp==80 and oni[0].hp==180,"Ronin and oni have distinct health roles")
  check(game.encounters.defense_speed(ronin[0])>game.encounters.defense_speed(oni[0]),"Ronin reaches defenses faster than the heavy oni")
  check(game.crowd.visual_species(ronin[0])==4 and game.crowd.visual_species(oni[0])==5,"New combat types select their own batched models")
  ronin[0].position=Vector3(0,.15,195);oni[0].position=Vector3(3,.15,195)
  game.crowd._process(.016)
  check(game.crowd.batches.size()==6 and game.crowd.batches[4].multimesh.visible_instance_count>0 and game.crowd.batches[5].multimesh.visible_instance_count>0,"Both new models reach the rendered crowd")
  ronin[0].hp=80;ronin[0].take_hit(10000,Vector3.FORWARD,true)
  check(ronin[0].dead and game.encounters.alive_count==299,"A new enemy death resolves through normal wave accounting")
 game.settings.quality=0;game.apply_quality()
 check(details!=null and details.visible and not environment.glow_enabled,"Low quality retains readable neon geometry with bloom disabled")
 game.custom_map_data={};game.start_mode("descent");await frames(3)
 check(game.world.get_node_or_null("NeonShrineDetails")==null,"Other game modes retain their existing scenery")
 print("NEON_SHRINE_RESULT checks=",checks," failures=",failures)
 game.sound_library.cancel();game.music.stop();game.queue_free();await frames(3);quit(1 if failures else 0)
