extends SceneTree
const Shot=preload("res://scripts/kojiro_projectile.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
class ReferenceShot extends "res://scripts/kojiro_projectile.gd":
 func _ready():
  super._ready()
  var template=effect_material
  effect_material=ShaderMaterial.new();effect_material.shader=template.shader
  for field in ["atlas","frames","billboard"]:effect_material.set_shader_parameter(field,template.get_shader_parameter(field))
  visual.material_override=effect_material
 func update_visual():
  var growth=minf(4,1+age*30/16) if kind=="wave" else 1+age*30/32 if kind=="wind" else 2 if kind=="spark" else 3 if kind=="dust" else 1
  # Preserve hit growth while the phoenix opens more slowly from a smaller launch.
  contact_scale=unit*size_factor*growth*SPELL_SCALE
  if kind=="wave":
   growth=lerpf(.5,4,minf(age/2.0,1))
   visual.rotation.x=-PI/2-deg_to_rad(15)*minf(age/2.0,1)
   if velocity.length_squared()>.001:rotation=Vector3(-atan2(velocity.y,Vector2(velocity.x,velocity.z).length()),atan2(velocity.x,velocity.z),0)
  visual.scale=Vector3.ONE*unit*size_factor*growth*SPELL_SCALE*skill_factor("size")
  effect_material.set_shader_parameter("frame",posmod(floori(age*30),8 if kind=="wave" else 2 if kind=="wind" else 10 if kind=="dust" else 1))
 func _physics_process(delta:float):
  if not is_instance_valid(hero) or not game.playing:retire();return
  if game.paused or game.transitioning:return
  age+=delta
  if age>=lifetime:retire();return
  update_visual();global_position+=velocity*delta
class FixtureGame extends Node3D:
 var playing=true
 var paused=false
 var transitioning=false
class FixtureHero extends Hero:
 func _ready():set_physics_process(false)
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func displayed_frame(shot)->int:
 return int(shot.visual.get_instance_shader_parameter("playback_age")) if shot.effect_material.get_shader_parameter("instanced") else int(shot.effect_material.get_shader_parameter("frame"))
func _initialize():run.call_deferred()
func run():
 var game=FixtureGame.new();root.add_child(game)
 var hero=FixtureHero.new();hero.game=game;game.add_child(hero)
 var pool=Pool.service(game)
 for kind in ["spark","dust"]:
  for delta in [1.0/60,1.0/120,.017,.18]:
   var config={"kind":kind,"position":Vector3(20,3,-15),"unit":.04,"size_factor":1.7,"velocity":Vector3(3,.5,-4),"damage":0.0,"attack_ticket":{"skill_size":1.6}}
   for repeat in 4:
    var before=pool.launch(hero,ReferenceShot,kind,config)
    var after=pool.launch(hero,Shot,kind,config)
    before.set_physics_process(false);after.set_physics_process(false)
    check(before.visual.scale==after.visual.scale and displayed_frame(before)==displayed_frame(after),"Reused cosmetics start with the exact original scale and atlas cell")
    check(after.effect_material.get_shader_parameter("frames")==float(1 if kind=="spark" else 10),"Source material preserves the source atlas row count")
    for tick in ceili(1.1/delta):
     if before.pool_live:before._physics_process(delta)
     if after.pool_live:after._physics_process(delta)
     check(before.pool_live==after.pool_live,"Lifetime admission is unchanged")
     check(before.position==after.position and before.age==after.age,"Cosmetic motion and age match at every tick")
     check(before.visual.scale==after.visual.scale and before.contact_scale==after.contact_scale,"Original size and scale remain exact")
     check(displayed_frame(before)==displayed_frame(after),"The displayed atlas frame matches at every tick")
    check(not before.pool_live and not after.pool_live,"Both implementations retire each repeated cosmetic")
 var first=pool.launch(hero,Shot,"dust",{"kind":"dust","unit":.04})
 var second=pool.launch(hero,Shot,"dust",{"kind":"dust","unit":.04})
 first.set_physics_process(false);second.set_physics_process(false)
 first.age=.15;first.update_visual();second.age=.05;second.update_visual()
 check(first.effect_material==second.effect_material,"Repeated projectiles share an immutable material")
 check(displayed_frame(first)==4 and displayed_frame(second)==1,"Shared materials retain independent per-projectile frames")
 first.retire();second.retire()
 if DisplayServer.get_name()!="headless":await compare_render(game,hero,pool)
 game.free()
 print("KOJIRO_COSMETIC_UPDATES_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)

func compare_render(game,hero,pool):
 var camera=Camera3D.new();game.add_child(camera);camera.position=Vector3(6,6,12);camera.look_at(Vector3.ZERO);camera.current=true
 root.size=Vector2i(480,360)
 var output="res://build/Other Files/Asset Toolkit/24 Hero Optimization/Rendered Shared Materials/"
 DirAccess.make_dir_recursive_absolute(output)
 for kind in ["spark","dust","wave","wind","homing"]:
  for frame in ([0,3,6,9] if kind=="dust" else [0,2,5,7] if kind=="wave" else [0,1] if kind=="wind" else [0]):
   var source=pool.launch(hero,Shot,kind,{"kind":kind,"position":Vector3.ZERO,"unit":.04,"velocity":Vector3.ZERO,"damage":0.0})
   source.set_physics_process(false);source.age=(frame+.25)/30.0;source.update_visual()
   var reference=pool.launch(hero,ReferenceShot,kind,{"kind":kind,"position":Vector3.ZERO,"unit":.04,"velocity":Vector3.ZERO,"damage":0.0})
   reference.set_physics_process(false);reference.age=source.age;reference.update_visual()
   source.visual.layers=0;reference.visual.layers=1
   for i in 15:await process_frame
   await RenderingServer.frame_post_draw
   var before=root.get_texture().get_image();before.convert(Image.FORMAT_RGBA8)
   reference.visual.layers=0;source.visual.layers=1
   for i in 15:await process_frame
   await RenderingServer.frame_post_draw
   var after=root.get_texture().get_image();after.convert(Image.FORMAT_RGBA8)
   before.save_png(output+kind+str(frame)+"-original.png");after.save_png(output+kind+str(frame)+"-optimized.png")
   check(before.get_data()==after.get_data(),"Optimized cosmetic is pixel-identical to the original "+kind+" atlas frame "+str(frame))
   var background=before.get_pixel(0,0);var drawn=false
   for y in before.get_height():
    for x in before.get_width():
     if before.get_pixel(x,y)!=background:drawn=true;break
    if drawn:break
   check(drawn,"The comparison includes visible source pixels")
   source.retire();reference.retire()
 camera.queue_free()
