extends "res://scripts/recovered_goemon_gameplay_tests.gd"
class SasukeSampler extends "res://scripts/recovered_sasuke_pose.gd":
 var conversions=0
 func _transform(values:Array)->Transform3D:
  conversions+=1;return super._transform(values)
class YaeSampler extends "res://scripts/recovered_yae_pose.gd":
 var conversions=0
 func _transform(values:Array)->Transform3D:
  conversions+=1;return super._transform(values)
class ExtraTarget extends Ninja:
 func _ready():set_physics_process(false)
func hit_ids(candidates:Array,from:Vector3,to:Vector3,radius:float)->Array:
 var hits=[]
 for enemy in candidates:
  if is_instance_valid(enemy) and not enemy.dead and not AttackChain.segment_contact(enemy,from,to,radius).is_empty():hits.append(enemy.get_instance_id())
 return hits
func source_reference(c,source:Dictionary,time_:float,root_:Transform3D)->Array:
 var model=c.cast_model();var reach:float=c.reach_scale()
 var frame_=clampf(time_*30*c.Profile.rate(c.action_id),0,float(source.frame_count)-1)
 var low=floori(frame_);var high=mini(low+1,int(source.frame_count)-1);var t=frame_-low
 var pose:Dictionary=model.sampler.sample_source(c.action_id,time_)
 var spheres=[]
 for i in int(source.count):
  var a:Dictionary=source.frames[low][i];var b:Dictionary=source.frames[high][i]
  var center=Vector3(a.center[0],a.center[1],a.center[2]).lerp(Vector3(b.center[0],b.center[1],b.center[2]),t)
  var pointer="0x9007478" if game.player.character_id==17 else ("0x90063d8" if c.mode in ["hair_up","hair_forward"] else ("0x9002aa8" if i<3 else "0x9002bc8"))
  if pose.has(pointer):
   var anchor:Vector3=pose[pointer]*Vector3(0,15,0) if game.player.character_id==17 else pose[pointer].origin
   center=anchor+(center-anchor)*reach
  var radius=lerpf(float(a.radius),float(b.radius),t)*model.source_scale*root_.basis.get_scale().length()/sqrt(3.0)*reach
  spheres.append({"center":root_*(model.rig_visual.transform*(center*model.source_scale+model.source_offset)),"radius":maxf(0,radius)})
 return spheres
func run():
 create_timer(90).timeout.connect(func():printerr("FAIL: native weapon queries timed out");quit(1))
 await setup_fixture()
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 for id in [16,17]:
  game.player.select_character(id)
  var c=game.player.active_ability
  var model=c.cast_model();var old_sampler=model.sampler
  model.sampler=SasukeSampler.new() if id==16 else YaeSampler.new()
  for action_ in c.Profile.data().collision_spheres:
   c.action_id=int(action_)
   c.mode=("hair_forward" if c.action_id==0x6f else "hair_up") if id==16 and c.action_id in [0x6f,0x9a] else "primary"
   var source:Dictionary=c.Profile.data().collision_spheres[action_]
   for reach in [.5,1.0,1.05,3.0,10.0]:
    game.update_character_tuning(id,"melee_reach",reach)
    for t in [0.0,.137,.293]:
     var root_=Transform3D(Basis(Vector3.UP,.73).scaled(Vector3.ONE*1.8),Vector3(4,40,60))
     var expected=source_reference(c,source,t,root_)
     model.sampler.conversions=0
     var actual:Array=c._source_spheres(source,t,root_)
     check(model.sampler.conversions<=4 if id==16 else model.sampler.conversions<=2,"Enlarged collision samples only the needed weapon anchors")
     var same=expected.size()==actual.size()
     for i in expected.size():same=same and expected[i].center.distance_to(actual[i].center)<.00005 and absf(expected[i].radius-actual[i].radius)<.00005
     check(same,"Weapon spheres retain full-pose centres and radii (%d/%X/%.2f)"%[id,c.action_id,reach])
  model.sampler=old_sampler
 for i in 144:
  var point=Vector3((i%4-1.5)*8,0,45+int(i/4)*8) if i<16 else Vector3(140+(i%16)*4,0,140+int(i/16)*4)
  var data=game.model.waves.spawn_enemy([0,1,4,3][i%4],point);data.hp=1000000;data.max_hp=1000000
 game.sync_enemies()
 var army=game.army_runtime
 for actor in game.actors.values():
  army.set_pose(actor.handle,actor.global_position,float(actor.forest_id%8)*PI/4);actor.sync(army.unit_state(actor.handle))
 game.enemies.reverse()
 var queries=0
 for from in [Vector3(-20,1,60),Vector3(0,8,60),Vector3(0,40,60),Vector3(160,2,170)]:
  for offset in [Vector3.ZERO,Vector3(40,0,0),Vector3(0,-20,40),Vector3(80,0,-20)]:
   for radius in [0.0,.2,3.6,36.0]:
    var to=from+offset
    var expected=hit_ids(game.enemies,from,to,radius)
    var candidates=AttackChain.segment_enemy_candidates(game,from,to,radius)
    check(candidates==game.enemies.filter(func(enemy):return candidates.has(enemy)),"Local and wide candidate queries preserve arbitrary source ordering")
    check(hit_ids(candidates,from,to,radius)==expected,"Native candidates retain exact contacts and order for long, stationary, wide and rotated sweeps")
    queries+=1
 var local=AttackChain.segment_enemy_candidates(game,Vector3(0,1,60),Vector3(0,1,61),.2)
 check(local.size()<game.enemies.size()/4,"A local weapon sweep excludes the distant army before fitting contacts")
 var extra=ExtraTarget.new();game.add_child(extra);extra.position=Vector3(500,0,500);game.enemies.append(extra)
 check(AttackChain.segment_enemy_candidates(game,Vector3.ZERO,Vector3.ONE,.2)==game.enemies,"Custom targets retain the complete compatibility scan")
 game.enemies.erase(extra);extra.queue_free()
 game.queue_free();paused=false;await frames();await create_timer(.15).timeout
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("NATIVE_WEAPON_QUERIES_RESULT checks=%d queries=%d failures=%d"%[checks,queries,failures]);quit(1 if failures else 0)
