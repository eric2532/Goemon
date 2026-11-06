extends SceneTree
const Effects=preload("res://assets/rogue/scripts/effects.gd")
const INK=preload("res://assets/rogue/shaders/magic_ink_brush.gdshader")
class QuietEffectParent extends Node3D:
 var settings={"reduced_flashes":true}
class TracedPresentation extends "res://scripts/forest/crowd/army_presentation.gd":
 var spark_poses=[]
 func show_rows(node:MultiMeshInstance3D,poses:Array,custom:Array):
  if node.name=="ArmyFX_spark":spark_poses=poses.duplicate()
  super.show_rows(node,poses,custom)
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func run():
 var fx=Effects.new();root.add_child(fx)
 for style in ["arrow","crimson-arrow","pierce","thrust","lance","pipe","gold-pipe","bash","staff","slam","sword","claymore","wave","samurai-cut"]:
  for heavy in [false,true]:
   fx.clear();await process_frame
   var node=fx.weapon_impact(Vector3(2,3,4),.7,style,Color("75fc8c"),heavy)
   var item=fx.items.filter(func(row):return row.kind=="impact")[0]
   var piercing=style in ["arrow","crimson-arrow","pierce","thrust","lance"]
   var blunt=style in ["pipe","gold-pipe","bash","staff","slam"]
   check(node.position==Vector3(2,4,4) and is_equal_approx(node.rotation.y,.7),"Contact position and direction are retained")
   check(node.scale==Vector3.ONE*1.6,"The foreground impact is visibly enlarged for every weapon family")
   check(item.pieces.all(func(piece):return piece.node.material_override is ShaderMaterial and piece.node.material_override.shader==INK),"Every weapon family keeps the painted material")
   if piercing:check(item.pieces.size()==5 and item.magicRing==null and item.pieces.all(func(piece):return piece.drive>0),"Piercing contact uses its dedicated five directional splinters")
   elif blunt:check(item.pieces.size()==5 and item.magicRing==null and fx.items.any(func(row):return row.kind=="ring"),"Blunt contact uses its existing broad burst and shock ring")
   else:check(item.magicRing!=null and item.pieces.size()==6,"Sword and recovered magic contacts keep their painted core and ring")
   if style in ["claymore","wave"]:check(node.name=="MagicInkImpact","Magic Swordsman keeps the dedicated purple effect")
   if style=="samurai-cut":check(node.name=="SamuraiInkImpact","Samurai keeps the dedicated red effect")
   check(is_equal_approx(item.strength,1.5 if heavy else 1.0),"Heavy emphasis changes cosmetic scale only")
   var ink=item.pieces[0].node.material_override
   var original_fade=float(ink.get_shader_parameter("fade"))
   fx.tick(item.max*.5)
   check(is_equal_approx(float(ink.get_shader_parameter("fade")),original_fade*.5),"Impact fades promptly without a lingering bright tail")
   fx.tick(1);await process_frame
   check(fx.items.is_empty() and fx.get_child_count()==0,"Every family expires without retained effect nodes")
 for quality in [0,1,2]:
  fx.clear();await process_frame;fx.apply_quality(quality);fx.reduced_flashes=true
  for i in 300:fx.weapon_impact(Vector3.ZERO,0,"arrow",Color.GREEN,true)
  check(fx.items.filter(func(row):return row.kind=="impact").size()==[3,8,12][quality],"Crowd contacts keep their displayed-frame budget")
  fx.tick(.02)
  check(fx.items.filter(func(row):return row.kind=="impact").all(func(row):return row.pieces[0].node.material_override.get_shader_parameter("energy")<=.42),"Reduced-flash preference remains effective")
  check(fx.items.filter(func(row):return row.kind=="impact").all(func(row):return row.node.scale==Vector3.ONE),"Reduced flashes retain the previous foreground impact size")
  fx.tick(1);await process_frame
 var original_parent=Node3D.new();root.add_child(original_parent)
 var original=preload("res://scripts/recovered_goemon_vfx.gd").hit(original_parent,Vector3(1,2,3))
 check(original.scale==Vector3.ONE*2 and original.global_position==Vector3(1,2,3),"Goemon's recovered contact burst is doubled at its actual hit position")
 check(is_equal_approx(original.lifetime,.24) and is_equal_approx(original.burst.pixel_size,.021),"Goemon retains his source pixels and effect timing")
 original_parent.queue_free();await process_frame
 var quiet=QuietEffectParent.new();root.add_child(quiet)
 var quiet_hit=preload("res://scripts/recovered_goemon_vfx.gd").hit(quiet,Vector3.ZERO)
 check(quiet_hit.scale==Vector3.ONE,"Reduced flashes retain Goemon's previous burst size")
 quiet.queue_free();await process_frame
 var view=Camera3D.new();root.add_child(view);view.position=Vector3(7,4,10);view.look_at(Vector3(0,1,0));view.current=true
 var army=TracedPresentation.new();root.add_child(army);army.configure(null)
 for repeat in 3:
  army.clear()
  var sizes=[]
  for tier in 3:
   army.present([{"kind":"damage","unit_kind":0,"position":Vector3(tier*3,1,0),"amount":10,"heavy":tier>0,"critical":tier==2}])
   sizes.append(army.effects[-1].scale)
  check(sizes==[3.0,3.8,4.6],"Normal, heavy and critical contacts are large enough to read beyond the enemy body")
  check(army.effects.size()==3 and army.effects.all(func(row):return row.kind=="spark" and row.life==.18),"Each victim retains one spark with the existing lifetime")
  army.tick(.04)
  check(army.spark_poses.size()==9,"Three contacts form three bounded six-point stars")
  check(army.spark_poses.all(func(pose):return pose.basis.z.normalized().dot(view.global_basis.z)>.999),"Contact stars face the actual gameplay camera")
  check(army.spark_poses[0].basis.x.length()>2.8 and army.spark_poses[3].basis.x.length()>army.spark_poses[0].basis.x.length() and army.spark_poses[6].basis.x.length()>army.spark_poses[3].basis.x.length(),"Visible emphasis reaches the submitted draw transforms")
  army.tick(1)
  check(army.effects.is_empty(),"Repeated native impacts expire")
 army.clear();army.present([{"kind":"muzzle","unit_kind":0,"position":Vector3.ZERO}]);army.tick(.02)
 check(army.spark_poses.size()==1 and army.spark_poses[0].basis.x.length()<.6,"Muzzles retain their original small single spark")
 var nodes=army.get_child_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for repeat in 10:
  army.clear()
  for i in 500:army.present([{"kind":"damage","unit_kind":0,"position":Vector3.ZERO,"amount":10,"heavy":true,"critical":true}])
  check(army.effects.size()==army.effect_capacity,"Simultaneous impacts retain the native effect capacity")
  army.tick(.01)
  check(army.spark_poses.size()==army.effect_capacity*3,"Contact geometry stays bounded within the existing shared draw batch")
  army.tick(1)
 check(army.get_child_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Five thousand native impacts reuse the prepared nodes and resources")
 if DisplayServer.get_name()!="headless":
  fx.clear();await process_frame;fx.apply_quality(2);fx.reduced_flashes=false
  var camera=Camera3D.new();root.add_child(camera);camera.position=Vector3(3,5,15);camera.look_at(Vector3(0,2,0));camera.current=true
  var environment=WorldEnvironment.new();environment.environment=Environment.new()
  environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("26323a");root.add_child(environment)
  for row in 2:
   for column in 3:
    var style=["sword","arrow","pipe"][column]
    var at=Vector3((column-1)*4.0,(1-row)*3.0,0)
    fx.weapon_impact(at,.7,style,Color("75dce8"),row==1)
    var caption=Label3D.new();caption.text=("Heavy " if row==1 else "Light ")+["blade","piercing","blunt"][column]
    caption.position=at+Vector3.DOWN*.35;caption.font_size=44;caption.pixel_size=.012;caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED;root.add_child(caption)
  fx.tick(.045);await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png("res://build/Other Files/Asset Toolkit/Shared Hit Feedback Trial/impact-families.png")==OK,"Capture the existing painted effect families at contact")
 fx.queue_free();army.queue_free();await process_frame
 print("SHARED_HIT_FEEDBACK_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
