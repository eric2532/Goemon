extends "res://scripts/rogue_equipment_combat_tests.gd"
## Real input and authored weapon transforms, rather than a simulated swing.

func brush_items(fx) -> Array:
 return fx.items.filter(func(item):return item.kind=="magic-brush")

func run():
 Input.use_accumulated_input=false;game.smoke_test=true
 game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.freeze_ai=true;game.tuning.invincible=true
 ProjectSettings.set_setting("goemon/experimental_crosshair",true)
 game.player.smoke_mode=true;game.start_mode("defense");pause_fixture_director();await frames(3)
 await fresh_class(6)
 var p=game.player;var a=p.active_ability
 check(brush_items(a.fx).is_empty(),"Idle sword does not leave a brush ribbon")
 var weapon_mesh=a.visual_actor.joints.Weapon_Cutlass.node.find_children("*","MeshInstance3D",true,false)
 for mesh in weapon_mesh:print("AUTHORED_BLADE_BOUNDS ",mesh.transform*mesh.get_aabb())
 for stage in range(3):
  tap("light_attack")
  var tracked=0;var broad=false;var start_tip=Vector3.ZERO;var end_tip=Vector3.ZERO
  for frame in range(17):
   await frames(1)
   var trails=brush_items(a.fx)
   if trails.is_empty():continue
   var ribbon=trails[-1].node
   if ribbon.mesh==null or ribbon.mesh.get_surface_count()==0:continue
   var vertices=ribbon.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
   if vertices.size()<4:continue
   var weapon=a.visual_actor.joints.Weapon_Cutlass.node
   var tip=weapon.to_global(Vector3(-.554,1.965,.029))
   var actual_tip=ribbon.to_global(vertices[-1])
   # Only compare during emission: the finished ribbon correctly stays in space.
   if a.player.attack!=null and a.player.attack.time<=a.player.attack.contact+.055:
    if actual_tip.distance_to(tip)<.015:tracked+=1
    if tracked==1:start_tip=tip
    end_tip=tip
   for pair in range(0,vertices.size(),2):broad=broad or vertices[pair].distance_to(vertices[pair+1])>.75
  check(tracked>=3,"Combo %s ribbon follows the authored blade tip over multiple poses" % stage)
  check(broad and start_tip.distance_to(end_tip)>.5,"Combo %s paints a broad moving crescent" % stage)
  check(a.fx.items.all(func(item):return item.kind!="slash"),"Combo %s avoids a detached generic slash" % stage)
  await frames(27)
 check(brush_items(a.fx).is_empty(),"Finished brush tails expire after the combo")
 check(a.fx.items.all(func(item):return item.kind!="impact"),"Whiffed swings do not produce hit bursts")
 await fresh_class(6);a=p.active_ability
 var enemy=fixture(Vector3(3,0,0));tap("light_attack");await frames(11)
 check(is_equal_approx(10000-enemy.hp,42),"New melee presentation retains its original contact damage")
 var impacts=a.fx.items.filter(func(item):return item.kind=="impact")
 check(impacts.any(func(item):return item.node.name=="MagicInkImpact"),"A confirmed sword hit produces the dedicated purple impact")
 await frames(45)
 check(brush_items(a.fx).is_empty() and a.fx.items.all(func(item):return item.kind!="impact"),"Sword and impact effects finish without lingering nodes")
 await fresh_class(6);a=p.active_ability;tap("light_attack");await frames(7)
 var moving_trails=brush_items(a.fx)
 if not moving_trails.is_empty():
  var ribbon=moving_trails[0].node
  var old_tip=ribbon.to_global(ribbon.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX][1])
  var origin=p.position;p.smoke_move=Vector2(1,0);await frames(3);p.smoke_move=Vector2.ZERO
  var vertices=ribbon.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  var weapon=a.visual_actor.joints.Weapon_Cutlass.node
  check(p.position.distance_to(origin)>.1 and ribbon.to_global(vertices[-1]).distance_to(weapon.to_global(Vector3(-.554,1.965,.029)))<.015,"Moving sword retains accurate world-space blade tracking")
  check(ribbon.to_global(vertices[1]).distance_to(old_tip)<.015,"Older paint stays at its original world position as the player moves")
 else:
  check(false,"Moving sword retains accurate world-space blade tracking")
  check(false,"Older paint stays at its original world position as the player moves")
 for mode in ["cancel","swap","reset","pause"]:
  await fresh_class(6);a=p.active_ability;tap("light_attack");await frames(6)
  check(not brush_items(a.fx).is_empty(),"%s fixture has an active brush ribbon" % mode)
  match mode:
   "cancel":a.cancel()
   "swap":p.select_character(3)
   "reset":a.reset_run()
   "pause":game.show_pause()
  await frames(3)
  check(brush_items(a.fx).is_empty(),"%s removes the active ribbon" % mode)
 await fresh_class(6);a=p.active_ability;tap("heavy_attack");await frames(10)
 check(brush_items(a.fx).is_empty(),"Ranged wave does not start a melee brush trail")
 check(not a.projectiles.is_empty() and a.projectiles[0].kind=="wave","RMB retains its independent long-range energy wave")
 await fresh_class(6);a=p.active_ability
 a.fx.apply_quality(0);a.fx.reduced_flashes=true;tap("light_attack");await frames(8)
 check(not brush_items(a.fx).is_empty(),"Low quality and reduced flashes retain the core brush slash")
 a.cancel();await frames(2)
 for i in range(100):a.fx.weapon_impact(p.position,0,"claymore",Color("985cff"),true)
 check(a.fx.items.filter(func(item):return item.kind=="impact").size()<=3,"Crowded Magic Swordsman hits respect the Low per-frame impact budget")
 check(a.fx.items.size()<=12,"Crowded hit feedback uses bounded bursts and rings")
 await fresh_class(6);a=p.active_ability;a.fx.apply_quality(0)
 var crowd: Array = []
 for i in range(20):crowd.append(fixture(Vector3(3+(i%4)*.2,0,(floori(i/4.0)-2)*.2)))
 tap("light_attack");await frames(11)
 check(crowd.all(func(enemy):return is_equal_approx(10000-enemy.hp,42)),"Impact admission limits do not suppress damage to any of 20 enemies")
 press("light_attack");await frames(120);press("light_attack",false)
 var held=brush_items(a.fx)
 check(held.size()<=2 and held.all(func(item):return item.node.mesh.get_surface_count()==0 or item.node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()<=128),"Held attacks retain bounded brush history and live ribbon count")
 a.fx.apply_quality(game.settings.quality);a.fx.reduced_flashes=game.settings.get("reduced_flashes",false)
 await fresh_class(7);a=p.active_ability;tap("light_attack");await frames(8)
 check(brush_items(a.fx).is_empty(),"Ranger attacks do not allocate Magic Swordsman ribbons")
 game.show_main_menu();game.sound_library.cancel();game.music.stop();stop_audio(game);await frames(3)
 print("MAGIC_INK_BRUSH_RESULT checks=",checks," failures=",failures)
 get_tree().quit(1 if failures else 0)
