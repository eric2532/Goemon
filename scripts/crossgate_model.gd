extends HeroModel
## Prepared illustrated sprites; shared Hero owns movement and collisions.
const ROOT="res://assets/characters/crossgate/kazi_hd/"
# The offline bake doubles the 83-pixel body / seven-pixel foot reference.
const BODY_HEIGHT_PIXELS=166.0
const FEET_OFFSET_PIXELS=14.0
# Measured from the illustrated side-view stance travel; keep turns on one stride.
const RUN_STRIDE_METERS=4.7
static var motions:Dictionary={}
static var atlases:Array[Texture2D]=[]
var combat:Node
var pressure_trail:MeshInstance3D
var sprite:Sprite3D
var clock=0.0
var cast_clock=0.0
var cast_owner:Node
var current_clip=""
var current_frame=-1

func _ready():
 if motions.is_empty():
  motions=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"motions.json"))
  for i in int(motions.pages):atlases.append(load(ROOT+"atlas-%d.png"%i))
 body=Node3D.new();add_child(body)
 head=driver("Head",Vector3(0,1.7,0))
 arms.assign([driver("Arm_L",Vector3(-.3,1.2,0)),driver("Arm_R",Vector3(.3,1.2,0))])
 legs.assign([driver("Leg_L",Vector3(-.2,.5,0)),driver("Leg_R",Vector3(.2,.5,0))])
 scarf=driver("Sash",Vector3.ZERO)
 hair_normal=Node3D.new();body.add_child(hair_normal)
 hair_gold=Node3D.new();body.add_child(hair_gold);hair_gold.hide()
 pipe=Node3D.new();body.add_child(pipe)
 coin=Node3D.new();body.add_child(coin);coin.hide()
 chain_pipe=ChainPipeVisual.new();body.add_child(chain_pipe);chain_pipe.hide()
 locomotion=preload("res://scripts/master_chief_locomotion.gd").new(self)
 sprite=Sprite3D.new();sprite.pixel_size=preload("res://scripts/character_proportions.gd").GOEMON_HEIGHT/BODY_HEIGHT_PIXELS;sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
 sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;sprite.region_enabled=true
 sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 body.add_child(sprite)
 show_pose(0,0,true)

func direction()->int:
 var camera=get_viewport().get_camera_3d()
 if camera==null:return 4
 var facing:Vector3=get_parent().facing
 var right=Vector3(camera.global_basis.x.x,0,camera.global_basis.x.z).normalized()
 var back=Vector3(camera.global_basis.z.x,0,camera.global_basis.z.z).normalized()
 # This sprite's order is NW, N, NE, E, SE, S, SW, W.
 return posmod(roundi(atan2(facing.dot(right),-facing.dot(back))*8/TAU)+1,8)

func show_pose(action:int,time:float,loop:bool):
 var key="%d:%d"%[action,direction()]
 var clip:Dictionary=motions.clips[key]
 var progress=time/maxf(.001,float(clip.duration))
 var frame=posmod(floori(progress*clip.frames.size()),clip.frames.size()) if loop else clampi(floori(progress*clip.frames.size()),0,clip.frames.size()-1)
 if key==current_clip and frame==current_frame:return
 current_clip=key;current_frame=frame
 var data:Array=clip.frames[frame]
 sprite.texture=atlases[int(data[0])]
 sprite.region_rect=Rect2(data[1],data[2],data[3],data[4])
 sprite.offset=Vector2(float(data[5])+float(data[3])*.5,FEET_OFFSET_PIXELS-float(data[6])-float(data[4])*.5)

func animate(delta:float,speed:float,grounded:bool,vertical:float,_attack:float,_heavy:bool,_combo:int,_dodge:bool):
 clock+=delta;cast_owner=null;cast_clock=0
 locomotion.grounded=grounded;locomotion.vertical=vertical
 locomotion.actual_speed=Vector2(locomotion_velocity.x,locomotion_velocity.z).length()
 var travel_speed=locomotion.actual_speed if grounded else speed
 if grounded and travel_speed>.1:
  var before=phase
  # Contact follows distance actually travelled, including slowing against obstacles.
  phase+=delta*travel_speed/(2.0 if travel_speed<=2.5 else RUN_STRIDE_METERS)
  if travel_speed>.25:locomotion.step_events+=floori(phase*2)-floori(before*2)
  phase=fposmod(phase,1.0)
 if is_instance_valid(combat) and combat.mode in ["attack","hurt","dead"]:
  show_pose(5 if combat.mode=="attack" else 8 if combat.mode=="hurt" else 10,combat.elapsed,false)
 elif travel_speed>.1:
  var action=1 if travel_speed<=2.5 else 3
  # One left/right stride survives direction and walk/run transitions.
  show_pose(action,phase*float(motions.clips["%d:0"%action].duration),true)
 else:show_pose(0,clock,true)

func animate_spell(delta:float,spell:Node):
 if cast_owner!=spell:cast_owner=spell;cast_clock=0
 cast_clock+=delta;show_pose(6,cast_clock,true)
func _process(delta:float):
 if is_instance_valid(combat) and combat.mode=="dead":
  combat.elapsed+=delta;show_pose(10,combat.elapsed,false)
func sync_skeleton():pass
func set_cloak(_equipped:bool,_gold:bool):pass
func combat_pose(_attack:float,_heavy:bool,_combo:int,_dodge:bool):pass
func set_surge(_active:bool):pass
func apply_skin(_id:String):pass
