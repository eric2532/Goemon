extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const OUT="res://build/Other Files/Asset Toolkit/Kaz Combo/Cast Streak/"
const STEP=1.0/60
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
var struck:Array[Ninja]=[]
var samples:Array[int]=[]

func key_two():
 var event=InputEventKey.new();event.physical_keycode=KEY_2;event.pressed=true
 game.player._unhandled_input(event)
 event.pressed=false;game.player._input(event)

func settle(at:Vector3):
 var p=game.player
 p.global_position=at;p.velocity=Vector3.ZERO
 for i in 20:p._physics_process(STEP)

func sample_step():
 var before=Time.get_ticks_usec()
 game.player._physics_process(STEP)
 samples.append(Time.get_ticks_usec()-before)
 game.crowd.army.presentation.tick(STEP)

func capture(filename:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync()
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+filename)==OK,"Captured "+filename)

func run():
 create_timer(120).timeout.connect(func():quit(1))
 DirAccess.make_dir_recursive_absolute(OUT)
 root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_physics_process(false);game.army_runtime.set_process(false)
 var p=game.player
 for node in [game,p,game.camera_rig,game.forest_ui]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 p.select_character(34);fresh()
 for entry in [["equip",p.spell_loadout.Catalog.MOON],["surge",p.spell_loadout.Catalog.COMBO],["special_6",p.spell_loadout.Catalog.KAGEROU]]:p.spell_loadout.equip(34,entry[0],entry[1])
 game.settings.disable_character_cooldowns=false
 var home=Vector3(-150,0,127)
 home.y=game.model.surface_height(home.x,home.z)+.05
 game.model.update_vision(home)
 game.training_dummy.position=home+Vector3.DOWN*100
 game.camera_rig.camera.global_position=home+Vector3(7,7,13)
 game.camera_rig.camera.look_at(home+Vector3(0,1,-2))
 var kit=p.active_ability
 var ui=game.forest_ui
 settle(home)
 check(p.is_on_floor(),"Kaz starts on playable ground")
 ui.sync()
 check(p.spell_loadout.numbered_slots[1][0]=="連擊" and ui.helper_portraits[1].texture==p.spell_loadout.Catalog.KAZ_COMBO_ICON,"Key 2 displays the native 連擊 icon")
 check(p.spell_loadout.spell_for(35,"surge").is_empty(),"Equipping Kaz does not give Uru an automatic skill")
 key_two()
 check(not kit.is_attacking() and kit.combo_cooldown==0,"Empty ground leaves the skill ready")
 var army=game.army_runtime
 var variant=Roles.SLIME if "--crossgate-pet-test" in OS.get_cmdline_user_args() else 0
 var targets:Array[Ninja]=[]
 var health={}
 var offsets=[Vector2(0,-4),Vector2(-3,-4),Vector2(3,-4),Vector2(-4,-1),Vector2(4,-1),Vector2(-3,3),Vector2(3,3),Vector2(0,5),Vector2(0,-8),Vector2(0,-25)]
 if variant==Roles.SLIME:
  offsets=[Vector2(0,-7),Vector2(-5.7,-5.7),Vector2(5.7,-5.7),Vector2(-8,0),Vector2(8,0),Vector2(-5.7,5.7),Vector2(5.7,5.7),Vector2(0,8),Vector2(8,5.7),Vector2(0,-30)]
 for offset in offsets:
  var point=home+Vector3(offset.x,0,offset.y)
  point.y=game.model.surface_height(point.x,point.z)
  var row=game.model.waves.spawn_enemy(variant,point,-1,targets.size())
  row.hp=20000.0;row.max_hp=row.hp
  army.import_arrivals()
  var enemy=game.actors[row.id]
  targets.append(enemy)
  health[enemy]=float(army.unit_state(enemy.handle).hp)
 army.integration_tick(STEP)
 game.crowd.present_army(army.render_snapshot(),[])
 game.impact_confirmed.connect(func(victim,_strength,_duration):struck.append(victim))
 var wall=StaticBody3D.new()
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(24,8,.35)
 shape.shape=box;wall.add_child(shape);game.add_child(wall)
 wall.position=home+Vector3(0,2,-2)
 await physics_frame;await physics_frame
 var blocked=kit.next_combo_hop({})
 check(not blocked.is_empty() and not blocked.enemy in targets.slice(0,3),"Targeting skips nearer enemies behind solid cover")
 wall.free()
 await physics_frame;await physics_frame
 var launch:Vector3=p.global_position
 key_two()
 var glow:Sprite3D=p.model.combo_glow
 check(glow.visible and glow.frame==0 and glow.texture==preload("res://assets/characters/crossgate/qigong/charge.png"),"Key 2 starts the original charge glow")
 for frame in 9:sample_step()
 check(glow.visible and glow.frame>0 and p.global_position.distance_to(launch)<.1 and struck.is_empty(),"The charge animates before movement or damage")
 await capture("charge.png")
 for frame in 18:sample_step()
 check(kit.is_attacking() and not glow.visible and kit.combo_cooldown>0 and p.global_position.distance_to(launch)>1,"The charge ends with the first blink and starts its cooldown")
 check(not kit.kagerou_enabled and p.model.kagerou_shadows.filter(func(s):return s.visible).size()==3,"The blink uses the existing afterimages with key 6 off")
 await capture("afterimages.png")
 for i in 180:
  sample_step()
  if struck.size()==1 and not captured:
   captured=true
   var fx=game.crowd.army.presentation
   check(fx.effects.any(func(row):return row.kind=="kazi_combo") and fx.batches.kazi_combo.multimesh.visible_instance_count>0,"A confirmed contact draws the recovered Combo sheet")
   var batch:MultiMesh=fx.batches.kazi_combo.multimesh
   if DisplayServer.get_name()!="headless" and batch.visible_instance_count>0:
    var size_:float=batch.mesh.size.x*batch.get_instance_transform(0).basis.x.length()
    check(is_equal_approx(size_,Roles.SLIME_HEIGHT),"The visible burst starts one normal slime across")
   var bursts=fx.effects.filter(func(row):return row.kind=="kazi_combo")
   check(not bursts.is_empty() and is_equal_approx(bursts.front().life,7.0*4.0/60.0/.9),"The recovered frames play at 90% speed")
   for frame in 18:sample_step()
   await capture("contact.png")
  if not kit.is_attacking():break
 check(struck.size()==8 and struck.all(func(enemy):return struck.count(enemy)==1),"One activation strikes eight different native enemies exactly once (got %s)"%[struck.map(func(enemy):return targets.find(enemy))])
 for target in targets:
  var damage=float(health[target])-float(army.unit_state(target.handle).hp)
  check(is_equal_approx(damage,375.0 if struck.has(target) else 0.0),"Native damage matches the target's single 1.5× cut or exclusion")
 check(not struck.has(targets.back()),"The distant target stays outside the chain")
 key_two()
 check(not kit.is_attacking(),"A repeat tap during cooldown cannot start another chain")
 var presentation=game.crowd.army.presentation
 var node_count=get_node_count()
 var resource_count=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var shadow_ids=p.model.kagerou_shadows.map(func(s):return s.get_instance_id())
 for i in 310:sample_step()
 for multiplier in [1.5,2.0,2.5]:
  settle(home);struck.clear()
  var before=targets.map(func(enemy):return float(army.unit_state(enemy.handle).hp))
  key_two()
  for i in 330:sample_step()
  check(not kit.is_attacking() and not presentation.effects.any(func(row):return row.kind=="kazi_combo"),"Repeated casts retire all strikes and contact effects")
  var hits_match=struck.size()==8
  for i in targets.size():
   var damage=before[i]-float(army.unit_state(targets[i].handle).hp)
   hits_match=hits_match and is_equal_approx(damage,375.0*multiplier if targets[i] in struck else 0.0)
  check(hits_match,"The %s× cast deals that multiplier on every strike"%multiplier)
 check(p.model.kagerou_shadows.map(func(s):return s.get_instance_id())==shadow_ids,"Repeat casts keep the same afterimage sprites")
 check(get_node_count()==node_count and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resource_count,"Repeat casts retain no new nodes or resources")
 settle(home)
 p.spell_loadout.number_input(1,true);p.spell_loadout.number_input(1,false)
 check(p.spell_loadout.current!=null and p.attack_chain.kazi_combo_streak==0,"Casting 追月 breaks the 連擊 streak as soon as it starts")
 p.interrupt_attack_for_movement()
 struck.clear()
 var before_reset=targets.map(func(enemy):return float(army.unit_state(enemy.handle).hp))
 key_two()
 for i in 330:sample_step()
 check(struck.size()==8 and struck.all(func(enemy):return is_equal_approx(before_reset[targets.find(enemy)]-float(army.unit_state(enemy.handle).hp),375.0)),"The first 連擊 after another skill returns to 375 base damage per hit")
 p.spell_loadout.number_input(6,true);p.spell_loadout.number_input(6,false)
 check(kit.kagerou_enabled and p.attack_chain.kazi_combo_streak==0,"Toggling 陽炎 also clears the streak")
 settle(home);kit.clear_cooldowns();key_two()
 var hits_before=struck.size()
 tap("dodge")
 for i in 15:sample_step()
 check(struck.size()==hits_before and not kit.is_attacking() and not glow.visible,"Evade clears the charge glow and pending strikes")
 var distant=targets.back()
 var outside_start=distant.global_position+Vector3.FORWARD*34
 outside_start.y=game.model.surface_height(outside_start.x,outside_start.z)+.05
 p.dodge_time=0;settle(outside_start);kit.clear_cooldowns()
 key_two()
 check(not kit.is_attacking() and kit.combo_cooldown==0,"An enemy beyond 32 m leaves the skill ready")
 var extended_start=distant.global_position+Vector3.FORWARD*30
 extended_start.y=game.model.surface_height(extended_start.x,extended_start.z)+.05
 settle(extended_start)
 check(not kit.next_combo_hop({}).is_empty(),"Follow-up targeting also reaches an enemy about 30 m away")
 key_two()
 for frame in 27:sample_step()
 check(kit.combo_target==distant and kit.combo_cooldown>0,"The wider starting range reaches an enemy about 30 m away")
 samples.sort()
 print("KAZ_COMBO_PLAYER_STEP_US p95=",samples[floori(samples.size()*.95)]," max=",samples.back())
 print("CROSSGATE_COMBO ",checks," checks ",failures," failures")
 quit(int(failures>0))
