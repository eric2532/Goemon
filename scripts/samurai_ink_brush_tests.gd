extends "res://scripts/rogue_equipment_combat_tests.gd"
## Real authored katana poses, including cuts shorter than three physics frames.
func ribbons(fx) -> Array:
 return fx.items.filter(func(item):return item.kind=="magic-brush")

func run():
 Input.use_accumulated_input=false;game.smoke_test=true
 game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.freeze_ai=true;game.tuning.invincible=true
 ProjectSettings.set_setting("goemon/experimental_crosshair",true)
 game.player.smoke_mode=true;game.start_mode("defense");pause_fixture_director();await frames(3)
 await fresh_class(1)
 var p=game.player;var a=p.active_ability
 check(ribbons(a.fx).is_empty(),"Idle Samurai does not emit a sword trail")
 for stage in range(5):
  # Damage is tested inside every physical blade's reach, not the old sphere.
  var victim=fixture(Vector3(2,0,0));tap("light_attack")
  var tracked=0;var broad=false
  for frame in range(45):
   await frames(1)
   var cut=a.player.attack
   if cut==null:continue
   var item=cut.get("magicBrush",{})
   if item.is_empty() or not is_instance_valid(item.node) or item.node.mesh.get_surface_count()==0:continue
   var vertices=item.node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
   if cut.time>=cut.contact*.52 and cut.time<=cut.contact+.055:
    var tip=a.visual_actor.joints.Weapon_Cutlass.node.to_global(Vector3(-.44,1.08,.006))
    if item.node.to_global(vertices[-1]).distance_to(tip)<.015:tracked+=1
   for pair in range(0,vertices.size(),2):broad=broad or vertices[pair].distance_to(vertices[pair+1])>.45
  check(tracked>=3,"Samurai cut %s traces its actual katana tip" % stage)
  check(broad,"Samurai cut %s has a broad brush crescent" % stage)
  # Existing attack-chain bonuses rise by 5% per consecutive cut.
  check(is_equal_approx(10000-victim.hp,[34.0,35.7,37.4,39.1,58.8][stage]),"Samurai cut %s retains its original contact damage" % stage)
  victim.queue_free();await frames(1)
 check(ribbons(a.fx).is_empty(),"Normal Samurai brush tails finish cleanly")
 for quality in [0,1]:
  await fresh_class(1);a=p.active_ability;a.fx.apply_quality(quality)
  tap("surge");press("light_attack")
  var visible: Array = [false,false,false,false,false]
  var bounded=true
  for frame in range(100):
   await frames(1)
   bounded=bounded and ribbons(a.fx).size()<=(2 if quality==0 else 3)
   var cut=a.player.attack
   if cut==null:continue
   var item=cut.get("magicBrush",{})
   if item.is_empty() or not is_instance_valid(item.node) or item.node.mesh.get_surface_count()==0:continue
   var vertices=item.node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
   if cut.time>0 and cut.time<=cut.contact+.02:
    var tip=a.visual_actor.joints.Weapon_Cutlass.node.to_global(Vector3(-.44,1.08,.006))
    var indices=item.node.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
    var area=0.0
    for triangle in range(0,indices.size(),3):
     area+=(vertices[indices[triangle+1]]-vertices[indices[triangle]]).cross(vertices[indices[triangle+2]]-vertices[indices[triangle]]).length()*.5
    if area>.01 and item.node.to_global(vertices[-1]).distance_to(tip)<.015:visible[cut.index]=true
  press("light_attack",false)
  check(visible.all(func(value):return value),"All five ultimate-speed cuts leave a visible blade-following ribbon at quality %s" % quality)
  check(bounded,"Ultimate-speed trails stay within the live ribbon budget at quality %s" % quality)
  await frames(45)
  check(ribbons(a.fx).is_empty(),"Ultimate-speed brush tails expire at quality %s" % quality)
 # Legal speed pickups and confirmed-hit chain speed can skip an entire
 # authored cut in one physics step. Inspect the emitted geometry, even when
 # that combat attack has already retired or advanced to the next cut.
 for quality in [0,1]:
  for stacks in [2,4,5]:
   await fresh_class(1);a=p.active_ability;a.fx.apply_quality(quality)
   for i in range(mini(stacks,4)):p.collect_powerup("attack_speed")
   if stacks==5:
    for i in range(11):p.attack_chain.confirm(p.attack_chain.begin("pipe"))
   tap("surge");press("light_attack")
   var visible: Array = [false,false,false,false,false]
   var bounded=true
   for frame in range(100):
    await frames(1)
    bounded=bounded and ribbons(a.fx).size()<=(2 if quality==0 else 3)
    for item in ribbons(a.fx):
     if not is_instance_valid(item.node) or item.node.mesh.get_surface_count()==0:continue
     var arrays=item.node.mesh.surface_get_arrays(0)
     var vertices=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX]
     var area=0.0
     for triangle in range(0,indices.size(),3):
      area+=(vertices[indices[triangle+1]]-vertices[indices[triangle]]).cross(vertices[indices[triangle+2]]-vertices[indices[triangle]]).length()*.5
     if area>.01:visible[item.get("cut_index",-1)]=true
   press("light_attack",false)
   if not visible.all(func(value):return value):print("SAMURAI_BRUSH_MISSING quality=",quality," stacks=",stacks," visible=",visible)
   check(visible.all(func(value):return value),"All five ultimate cuts have brush geometry with speed case %s at quality %s" % [stacks,quality])
   check(bounded,"Stacked-speed ultimate respects quality %s ribbon cap" % quality)
   await frames(15)
   check(ribbons(a.fx).is_empty(),"Stacked-speed ultimate trails expire at quality %s" % quality)
 for mode in ["cancel","swap","reset","pause"]:
  await fresh_class(1);a=p.active_ability;tap("light_attack");await frames(6)
  check(not ribbons(a.fx).is_empty(),"%s fixture has a Samurai brush trail" % mode)
  match mode:
   "cancel":a.cancel()
   "swap":p.select_character(9)
   "reset":a.reset_run()
   "pause":game.show_pause()
  await frames(3);check(ribbons(a.fx).is_empty(),"%s clears Samurai's brush trail" % mode)
 await fresh_class(1);a=p.active_ability;a.fx.apply_quality(0);a.fx.reduced_flashes=true
 var crowd: Array = []
 for i in range(20):crowd.append(fixture(Vector3(1.8+(i%4)*.15,0,(floori(i/4.0)-2)*.2)))
 tap("light_attack");await frames(10)
 check(crowd.all(func(enemy):return is_equal_approx(10000-enemy.hp,34)),"New Samurai hit feedback preserves damage to all 20 enemies")
 var impacts=a.fx.items.filter(func(item):return item.kind=="impact")
 check(impacts.any(func(item):return item.node.name=="SamuraiInkImpact"),"Confirmed katana hits produce a dedicated red ink impact")
 check(impacts.size()<=3,"Samurai crowd impacts retain Low's per-frame admission cap")
 check(not ribbons(a.fx).is_empty(),"Low quality and reduced flashes preserve Samurai's core slash")
 a.fx.reduced_flashes=game.settings.get("reduced_flashes",false);a.fx.apply_quality(game.settings.quality)
 await fresh_class(1);a=p.active_ability;tap("heavy_attack");await frames(3)
 check(ribbons(a.fx).is_empty(),"The big energy arrow does not emit a melee trail")
 check(a.projectiles.size()==1 and a.projectiles[0].kind=="crimson-arrow" and a.projectiles[0].mesh.scale.x>=3,"Samurai retains his huge red energy arrow")
 await fresh_class(6);a=p.active_ability;tap("heavy_attack")
 # The wave is released by the actual sword contact, after its wind-up.
 await frames(8)
 var materials: Array = []
 if not a.projectiles.is_empty():
  for child in a.projectiles[0].mesh.get_children():
   if child is MeshInstance3D and child.material_override is ShaderMaterial:materials.append(child.material_override)
 check(materials.size()>=2,"Magic Swordsman's ranged crescent has layered ink-brush materials")
 await frames(10)
 check(materials.size()>=2 and materials.all(func(material):return float(material.get_shader_parameter("brush_clock"))>.05),"Travelling energy wave animates its brush texture on the projectile clock")
 check(not a.projectiles.is_empty() and a.projectiles[0].vel.length()>21.9,"Ink-brush wave retains its original projectile flight")
 game.show_main_menu();game.sound_library.cancel();game.music.stop();stop_audio(game);await frames(3)
 print("SAMURAI_INK_BRUSH_RESULT checks=",checks," failures=",failures)
 get_tree().quit(1 if failures else 0)
