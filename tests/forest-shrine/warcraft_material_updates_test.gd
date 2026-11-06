extends SceneTree
const Model=preload("res://scripts/warcraft_model.gd")
class ReferenceModel extends "res://scripts/warcraft_model.gd":
 func pose(name_:String,time:float,loop:bool=false):
  name_=native_clip(name_)
  body.transform=Transform3D.IDENTITY
  if character==32 and name_=="Stand Ready" and is_instance_valid(combat) and combat.hero.jumps_used==2 and not combat.hero.flying and combat.hero.dodge_time<=0 and locomotion.reference_jump_flip>=0:
   # Reuse Hero's torso-pivot somersault and second-jump clock at Musashi's pace.
   var turn=Basis(Vector3.RIGHT,-TAU*clampf(locomotion.reference_jump_flip*.42/FLIP_DURATION,0,1))
   var pivot=Vector3(0,1.4,0)
   body.transform=Transform3D(turn,pivot-turn*pivot)
  if clip!=name_:animation_player.play(name_);clip=name_;frame=-1
  var length=animation_player.get_animation(name_).length
  var at=fposmod(time,length) if loop and length>0 else clampf(time,0,maxf(0,length-.00001))
  skeleton.clear_bones_global_pose_override()
  animation_player.seek(at,true)
  face_glows()
  var next=mini(floori(at*30),motion.clips[name_].size()-1)
  if next==frame:return
  frame=next
  var sample:Dictionary=motion.clips[name_][frame]
  for i in meshes.size():
   var alpha=float(sample.opacity[i]);meshes[i].visible=alpha>.001
   if alpha>.001:meshes[i].material_override.albedo_color.a=alpha
  for i in skin_textures:meshes[i].material_override.albedo_texture=skin_textures[i][1 if sample.get("avatar",0)>.5 else 0]
  for i in live_particles:particles[i].hide()
  live_particles.clear()
  for p in sample.particles:
   var i=int(p[0]);var sprite:Sprite3D=particles[i]
   sprite.position=Vector3(p[1],p[3],-p[2]);sprite.scale=Vector3.ONE*maxf(.001,p[4])
   sprite.modulate=Color(p[6],p[7],p[8],p[5])
   if motion.particles[i].texture=="energy.png":sprite.modulate=Effects.energy_tint(character,sprite.modulate)
   sprite.frame=clampi(roundi(p[9]*sprite.hframes)+(sprite.vframes-1-roundi(p[10]*sprite.vframes))*sprite.hframes,0,sprite.hframes*sprite.vframes-1)
   sprite.show();live_particles.append(i)
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var world=Node3D.new();root.add_child(world)
 var camera=Camera3D.new();world.add_child(camera);camera.position=Vector3(7,5,12);camera.look_at(Vector3.UP);camera.current=true
 var costs=[]
 for character in [31,32,33]:
  var before=ReferenceModel.new();before.character=character;world.add_child(before);before.set_process(false)
  var after=Model.new();after.character=character;world.add_child(after);after.set_process(false)
  for clip in before.motion.clips:
   for frame in before.motion.clips[clip].size():
    var time=(frame+.25)/30.0;before.pose(clip,time);after.pose(clip,time)
    for i in before.meshes.size():
     check(before.meshes[i].visible==after.meshes[i].visible,"Original mesh visibility")
     check(before.meshes[i].material_override.albedo_color==after.meshes[i].material_override.albedo_color,"Original material color/opacity")
     check(before.meshes[i].material_override.albedo_texture==after.meshes[i].material_override.albedo_texture,"Original avatar pages")
  for round in 6:
   for optimized in ([false,true] if round%2==0 else [true,false]):
    var node=after if optimized else before;var clip="Stand - 1" if character==33 else "Stand"
    var started=Time.get_ticks_usec()
    for frame in 300:node.pose(clip,(frame%node.motion.clips[clip].size()+.25)/30.0)
    costs.append({"character":character,"optimized":optimized,"us_per_pose":(Time.get_ticks_usec()-started)/300.0})
  before.free();after.free()
 world.free()
 FileAccess.open("res://build/Other Files/Asset Toolkit/24 Hero Smoothness/warcraft-material-cost.json",FileAccess.WRITE).store_string(JSON.stringify(costs,"  "))
 print("WARCRAFT_MATERIAL_UPDATES_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
