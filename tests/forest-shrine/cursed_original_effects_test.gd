extends "res://tests/forest-shrine/cursed_maze_recovery_test.gd"
const Spells=preload("res://scripts/forest/crowd/cursed_guardian_spells.gd")
class StatusEvents:
 extends "res://scripts/forest/crowd/army_runtime.gd"
 var fixture:Array=[]
 func _take_scene_events()->Array:
  var events=fixture;fixture=[];return events

func run():
 root.size=Vector2i(1440,900)
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/cursed-original-effects.cfg";root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 set_meta(Winter.SLAIN,{})
 var id=Decree.GUARDIAN_FLOORS[5]
 var entry=Original.links(Decree.floor_id(59)).filter(func(l):return l.get("floor")==id)[0]
 Tour.travel(game,Original.layout(id),{"arrival":entry.arrival,"yaw":0.0,"velocity":Vector3.ZERO})
 for i in 8:await physics_frame
 game.paused=true;game.tuning.invincible=false
 game.army_runtime.flush_presentation()
 var p=game.crowd.army.presentation
 var hero=game.player
 var center=game.model.world_point(Decree.point(Decree.Encounters.SEALS[5],id),.15)
 var open=[]
 for cell in Decree.maze(id,game.model.seed_value).eligible:
  var point=game.model.world_point(Decree.point(cell,id),.15)
  if point.z<center.z+5 or point.distance_to(center)>13:continue
  if game.model.enemies.values().any(func(enemy):return enemy.pos.distance_to(point)<5):continue
  if game.army_runtime.native.can_reach(center,point,.5):open.append(point)
 check(not open.is_empty(),"Source chamber has unobstructed ground for visual review")
 open.sort_custom(func(a,b):return a.distance_squared_to(center+Vector3(0,0,8))<b.distance_squared_to(center+Vector3(0,0,8)))
 hero.position=open[0] if not open.is_empty() else center
 game.model.update_vision(hero.position/game.model.falan_scale)
 game.camera_rig.set_process(false)
 game.camera_rig.camera.global_position=hero.position+Vector3(10,13,14)
 game.camera_rig.camera.look_at(hero.position+Vector3.UP*2.5)
 var children=p.get_child_count()
 for status in 6:
  p.effects.clear();hero.clear_cursed_afflictions();hero.confusion_left=0;hero.invuln=0
  hero.apply_cursed_affliction(status,4.0,0)
  var event={"action_index":790+status,"position":hero.position,"target_id":0,"amount":4.0,"external_kind":0}
  p.guardian_affliction(event)
  var icons=p.effects.filter(func(e):return e.has("guardian_status"))
  check(icons.size()==1,"One original owner-slot status icon: "+Spells.STATUSES[status])
  if icons.is_empty():continue
  var icon:Dictionary=icons[0]
  check(icon.kind=="ruby-native-"+str(110075+status) and icon.loop,"Verified status resource repeats its original clock")
  icon.age=1.5
  p.guardian_affliction(event)
  check(p.effects.filter(func(e):return e.has("guardian_status")).size()==1,"Repeated affliction reuses its icon")
  p.draw_effects()
  var batch:MultiMeshInstance3D=p.batches[icon.kind]
  check(batch.multimesh.visible_instance_count==1,"Status reaches a visible pooled draw")
  var before=batch.multimesh.get_instance_transform(0).origin
  hero.position+=Vector3(1,0,0);p.draw_effects()
  if DisplayServer.get_name()!="headless":check(batch.multimesh.get_instance_transform(0).origin.is_equal_approx(before+Vector3.RIGHT),"Icon follows the actual moving 3D character")
  await capture_effect("status-"+str(status),hero.position+Vector3.UP*2.5)
  hero.position-=Vector3(1,0,0)
  hero.clear_cursed_afflictions();tick_effects(.01);p.draw_effects()
  check(not p.effects.has(icon) and batch.multimesh.visible_instance_count==0,"Cleared status immediately removes its icon")
 hero.confusion_left=0
 p.effects.clear()
 var victim:Dictionary=game.model.enemies.values()[0]
 p.guardian_affliction({"action_index":790,"position":victim.pos,"target_id":victim.id,"amount":4.0,"external_kind":-1})
 check(p.effects.size()==1 and p.effects[0].handle==game.army_runtime.handles[victim.id],"Army status uses its native generation handle")
 var clear={"kind":"status","unit_kind":7,"action_index":790,"position":victim.pos,"target_id":victim.id,"source_id":victim.id,"amount":0.0,"external_kind":-1,"ticket_id":game.army_runtime.handles[victim.id]+(1<<32)}
 p.present([clear],p.effect_snapshot)
 check(p.effects.size()==1,"Old-generation status clear cannot remove a current icon")
 clear.ticket_id=game.army_runtime.handles[victim.id]
 p.present([clear],p.effect_snapshot)
 check(p.effects.is_empty(),"Native ally expiry removes its icon through the shared event owner")
 p.guardian_affliction({"action_index":790,"position":victim.pos,"target_id":victim.id,"amount":4.0,"external_kind":-1})
 if not p.effects.is_empty():
  p.effects[0].handle+=1<<32
  tick_effects(.01)
 check(p.effects.is_empty(),"Recycled native actors cannot inherit an obsolete status icon")
 p.guardian_magic_seal({"amount":6.0})
 var rune:Dictionary=p.effects[0]
 rune.age=1.1;p.guardian_magic_seal({"amount":6.0});p.draw_effects()
 check(p.effects.size()==1 and rune.age==1.1 and rune.life>7,"Repeated Magic Seal reuses the arena slot without restarting its source clock")
 var batch:MultiMeshInstance3D=p.batches[rune.kind]
 check(batch.multimesh.visible_instance_count==1,"Original Magic Seal rune reaches the 3D chamber")
 if DisplayServer.get_name()!="headless":check(batch.multimesh.get_instance_transform(0).basis.z.normalized().is_equal_approx(Vector3.UP),"Rune is projected onto solid 3D ground")
 var fixed=batch.multimesh.get_instance_transform(0).origin
 hero.position+=Vector3(2,0,0);p.draw_effects()
 check(batch.multimesh.get_instance_transform(0).origin.is_equal_approx(fixed),"Arena rune stays fixed when characters move")
 await capture_effect("magic-seal",rune.position)
 tick_effects(8);p.draw_effects()
 check(p.effects.is_empty() and batch.multimesh.visible_instance_count==0,"Magic Seal expires without leaking its arena effect")
 for success in [false,true]:
  p.effects.clear()
  p.present([{"kind":"status","unit_kind":20,"action_index":774,"source_id":victim.id,"target_id":0,"external_kind":0,"position":hero.position,"amount":int(success)}],p.effect_snapshot)
  check(p.effects.size()==1 and p.effects[0].kind=="ruby-native-110156","Death attempt uses its verified original skull on success and failure")
  if p.effects.is_empty():continue
  var skull:Dictionary=p.effects[0]
  skull.age=.7;p.draw_effects()
  check(p.batches[skull.kind].multimesh.visible_instance_count==1,"Original Death animation is visible at the actual target")
  if not success:check(p.labels.any(func(l):return l.visible and l.text=="MISS" and l.font==ThemeDB.fallback_font),"Failed Death attempts keep readable MISS feedback")
  await capture_effect("death-"+str(success),hero.position+Vector3.UP*1.5)
  tick_effects(2)
  check(p.effects.is_empty(),"Death ends on its original one-shot clock")
 check(p.get_child_count()==children,"All repeated status/arena effects reuse prepared batches")
 var route=StatusEvents.new();route.game_ref=weakref(game)
 var copy_actions=[]
 route.mirror_action.connect(func(event):copy_actions.append(event.action_index))
 route.fixture=[{"serial":1,"kind":"status","unit_kind":101,"action_index":791,"target_id":777,"source_id":777,"ticket_id":42,"amount":0.0,"external_kind":-1},
  {"serial":2,"kind":"status","unit_kind":101,"action_index":400,"target_id":0,"source_id":777,"ticket_id":42,"amount":1.0}]
 route.dispatch_events()
 check(copy_actions==[400],"A copied ally waking from Sleep cannot start a borrowed action or interrupt its charge")
 check(route.presentation_events.size()==2,"Both status cleanup and genuine copied actions reach presentation")
 route.free()
 print("CURSED_ORIGINAL_EFFECTS_RESULT checks=",checks," failures=",failures)
 await finish()

func tick_effects(delta:float):
 game.paused=false
 game.crowd.army.presentation.tick(delta)
 game.paused=true

func capture_effect(label_:String,focus:Vector3):
 if DisplayServer.get_name()=="headless":return
 var ceilings=[]
 for node:MeshInstance3D in game.world.find_children("*Ceiling*","MeshInstance3D",true,false):
  if node.visible:node.hide();ceilings.append(node)
 game.camera_rig.set_process(false)
 game.camera_rig.camera.global_position=focus+Vector3(10,13,14)
 game.camera_rig.camera.look_at(focus)
 game.crowd.army.presentation.draw_effects()
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(REVIEW+"Effects Recovery/"+label_+".png")
 for node in ceilings:node.show()
