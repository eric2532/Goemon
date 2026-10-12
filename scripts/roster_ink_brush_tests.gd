extends "res://scripts/rogue_equipment_combat_tests.gd"
## Real inputs and real authored blade bindings, not a cosmetic-only mock.
func ribbons(fx) -> Array:
 return fx.items.filter(func(item):return item.kind=="magic-brush")

func run():
 Input.use_accumulated_input=false;game.smoke_test=true;game.settings.volume=0.0
 game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.freeze_ai=true;game.tuning.invincible=true
 ProjectSettings.set_setting("goemon/experimental_crosshair",true)
 game.player.smoke_mode=true;game.start_mode("defense");pause_fixture_director();await frames(3)
 if "--feedback-only" not in OS.get_cmdline_user_args():await blade_rules()
 await rogue_feedback_rules()
 game.show_main_menu();game.sound_library.cancel();game.music.stop();stop_audio(game)
 var shared=game.get_node_or_null("RogueSharedClassAudio")
 if is_instance_valid(shared):shared.cache.clear()
 await frames(20)
 print("ROSTER_INK_BRUSH_RESULT checks=",checks," failures=",failures)
 get_tree().quit(1 if failures else 0)

func blade_rules():
 for index in [0,2,4,8,9]:
  for quality in [0,1,2]:
   for speed_case in [0,2,4,5]:
    if "--blade-probe" in OS.get_cmdline_user_args() and (index!=0 or quality!=0 or speed_case!=5):continue
    await fresh_class(index)
    var p=game.player;var a=p.active_ability;a.fx.apply_quality(quality);a.fx.reduced_flashes=true
    for i in range(mini(speed_case,4)):p.collect_powerup("attack_speed")
    if speed_case==5:
     for i in range(11):p.attack_chain.confirm(p.attack_chain.begin("pipe"))
    check(ribbons(a.fx).is_empty(),"%s idle emits no trail" % a.class_id)
    var seen=false;var area_ok=false;var bounded=true;var follows=true;var dual_ok=index!=8;var pigment=false
    tap("light_attack")
    for frame in range(40):
     await frames(1)
     bounded=bounded and ribbons(a.fx).size()<=[2,3,4][quality]
     for item in ribbons(a.fx):
      var node=item.node
      if not is_instance_valid(node) or node.mesh.get_surface_count()==0:continue
      seen=true;var total=0
      for surface in range(node.mesh.get_surface_count()):
       var arr=node.mesh.surface_get_arrays(surface);var v=arr[Mesh.ARRAY_VERTEX];var ids=arr[Mesh.ARRAY_INDEX]
       total+=v.size();var area=0.0
       for tri in range(0,ids.size(),3):area+=(v[ids[tri+1]]-v[ids[tri]]).cross(v[ids[tri+2]]-v[ids[tri]]).length()*.5
       area_ok=area_ok or area>.01
       if p.active_ability.player.attack!=null and p.active_ability.player.attack.get("magicBrush",{}).get("node") == node and is_equal_approx(item.get("sampleTime",-1),p.active_ability.player.attack.time):
        var binding=a.visual_actor.joints.Weapon_Pistol.node if surface==1 else a.visual_actor.joints.Weapon_Cutlass.node
        var axis=a.visual_actor.LEFT_BLADE if surface==1 else a.visual_actor.WEAPON_AXES[a.class_id]
        follows=follows and node.to_global(v[-1]).distance_to(binding.to_global(axis))<.015
      bounded=bounded and total<=(208 if index==8 else 104)
      pigment=node.material_override is ShaderMaterial and node.material_override.get_shader_parameter("custom_palette")==true
      if index==8 and node.mesh.get_surface_count()==2:
       var left=node.mesh.surface_get_arrays(1)[Mesh.ARRAY_VERTEX]
       var right=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
       dual_ok=dual_ok or left[-1].distance_to(right[-1])>.1
    check(seen and area_ok,"%s speed %s quality %s has visible brush geometry" % [a.class_id,speed_case,quality])
    check(follows and dual_ok,"%s trails follow real blade(s)" % a.class_id)
    check(bounded and pigment,"%s bounded palette ribbons" % a.class_id)
    check(ribbons(a.fx).is_empty(),"%s tails expire" % a.class_id)
 for mode in ["cancel","swap","reset","pause","death"]:
  await fresh_class(4);var a=game.player.active_ability;tap("light_attack");await frames(8)
  check(not ribbons(a.fx).is_empty(),"%s starts with brush" % mode)
  match mode:
   "cancel":a.cancel()
   "swap":game.player.select_character(9)
   "reset":a.reset_run()
   "pause":game.show_pause()
   "death":game.player.hp=0;a.cancel()
  await frames(3);check(ribbons(a.fx).is_empty(),"%s clears brush" % mode)

func ink_meshes(node: Node) -> Array:
 var found: Array=[]
 if node is MeshInstance3D and node.material_override is ShaderMaterial and node.material_override.shader==preload("res://assets/rogue/shaders/magic_ink_brush.gdshader"):found.append(node)
 for child in node.get_children():found.append_array(ink_meshes(child))
 return found

func rogue_feedback_rules():
 await fresh_class(3);var fx=game.player.active_ability.fx
 for kind in ["bullet","ranger-arrow","ranger-power-arrow","star","fireball","bolt","crimson-arrow","wave"]:
  var node=fx.create_projectile(kind,Color("65eac8"));game.add_child(node)
  var meshes=ink_meshes(node);check(not meshes.is_empty(),"%s has painted projectile body/wake" % kind)
  var valid_uv=true
  for mesh_ in meshes:
   if mesh_.mesh is ArrayMesh:
    for surface in range(mesh_.mesh.get_surface_count()):
     var arr=mesh_.mesh.surface_get_arrays(surface)
     valid_uv=valid_uv and arr[Mesh.ARRAY_TEX_UV]!=null and arr[Mesh.ARRAY_TEX_UV].size()==arr[Mesh.ARRAY_VERTEX].size()
  check(valid_uv,"%s pigment geometry has valid UVs" % kind)
  var pose=node.transform
  preload("res://assets/rogue/scripts/ink_brush_style.gd").animate(node,.15)
  check(node.transform==pose and meshes.any(func(mesh_):return float(mesh_.material_override.get_shader_parameter("brush_clock"))>.1),"%s paint animation leaves flight transform unchanged" % kind)
  node.queue_free()
 for quality in [0,1,2]:
  fx.clear();await frames(1);fx.apply_quality(quality);fx.reduced_flashes=true
  for contact in range(300):fx.weapon_impact(Vector3.ZERO,0,"arrow",Color("75fc8c"),true)
  var bursts=fx.items.filter(func(item):return item.kind=="impact")
  check(bursts.size()==[3,8,12][quality],"300 contacts share quality %s impact frame cap" % quality)
  check(bursts.all(func(item):return not ink_meshes(item.node).is_empty() and item.pieces.size()>=4),"Hits have a painted bright core and colored fragments")
  fx.tick(1);await frames(1);check(fx.items.is_empty(),"Crowd feedback expires at quality %s" % quality)
 for index in range(10):
  for action_ in ["light_attack","heavy_attack","equip","surge"]:
   await fresh_class(index);var a=game.player.active_ability;var shown=false
   tap(action_)
   for frame in range(65):
    await frames(1)
    shown=shown or not ink_meshes(a.fx).is_empty()
    for pr in a.projectiles:shown=shown or not ink_meshes(pr.mesh).is_empty()
   # Defensive skills can expose their new attack palette via their next attack.
   if not shown:
    tap("light_attack")
    for frame in range(35):
     await frames(1);shown=shown or not ink_meshes(a.fx).is_empty()
     for pr in a.projectiles:shown=shown or not ink_meshes(pr.mesh).is_empty()
   check(shown,"%s %s has brush appearance while retaining its action" % [a.class_id,action_])
   check(a.fx.items.all(func(item):return item.kind!="impact"),"%s missed %s emits no confirmed-hit burst" % [a.class_id,action_])
