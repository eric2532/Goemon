extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
const Target=preload("res://scripts/forest/crowd/army_enemy_target.gd")
class CameraState extends RefCounted:
 var pitch=0.0
class State extends RefCounted:
 var enemies={}
class Arena extends Node3D:
 var enemies=[]
 var army_runtime
 var training_dummy
 var enemy_objectives=[]
 var enemy_objective_targets=[]
 var model=State.new()
 var camera_rig=CameraState.new()
 func forest_enemy_visible(enemy)->bool:return enemy.get_meta("shown",true)
class Caster extends CharacterBody3D:
 var game:Node
 func _ready():set_physics_process(false)
class CountingAssist extends "res://scripts/melee_assist.gd":
 var visited=0
 func _available(_hero)->bool:return true
 func _breaking(_hero,_point:Vector3)->bool:return false
 func manual_angle(_hero)->float:return 0.0
 func point(hero,enemy,angle:float,max_distance:float,max_angle:float=ACQUIRE_ANGLE)->Vector3:
  visited+=1;return super.point(hero,enemy,angle,max_distance,max_angle)
class ReferenceAssist extends CountingAssist:
 func begin(hero,angle: float,weapon_reach: float):
  released_to_manual=false
  if not _available(hero):reset();return
  reach=minf(weapon_reach,5.5)
  var candidate=target()
  # A known enemy may drift slightly farther than a new acquisition.
  var contact=point(hero,candidate,angle,reach+.75,RETAIN_ANGLE)
  if remaining<=0 or contact==Vector3.INF:
   candidate=null;var best=INF
   for enemy in hero.game.enemies:
    var p=point(hero,enemy,angle,reach+.35)
    if p==Vector3.INF:continue
    var offset=p-hero.global_position
    var score=absf(wrapf(atan2(offset.x,offset.z)-angle,-PI,PI))+Vector2(offset.x,offset.z).length()*.12
    if score<best:best=score;candidate=enemy;contact=p
  if candidate==null:reset();return
  camera_aim=manual_angle(hero)
  camera_pitch=hero.game.camera_rig.pitch
  if _breaking(hero,contact):reset();return
  reference=weakref(candidate);remaining=MEMORY;active=true;step_left=STEP_DISTANCE
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var game=Arena.new();root.add_child(game)
 var army=Runtime.new();army.configure(null);army.game_ref=weakref(game);game.army_runtime=army
 var hero=Caster.new();hero.game=game;game.add_child(hero);seed(71028)
 for i in 240:
  var position=Vector3((i%4-1.5)*2,0,3+float(i/4)*2) if i<12 else Vector3(50+(i%20)*8,0,40+float(i/20)*8)
  var kind=[0,1,3,6,9,16][i%6]
  var handle=army.spawn(i+1,0,kind,position,100,3.9)
  var actor=Target.new();actor.runtime=army;actor.handle=handle;actor.variant=kind;actor.forest_id=i+1;game.add_child(actor);actor.sync(army.unit_state(handle))
  army.enemies[i+1]=actor;army.register_actor_facade(actor);game.enemies.append(actor)
 var reference=ReferenceAssist.new();var current=CountingAssist.new()
 for iteration in 100:
  if iteration%8==0:game.enemies.shuffle()
  hero.position=Vector3(float(iteration%7)-3,0,float(iteration%5)-2)
  var angle=[0.0,PI/4,-PI/4,PI][iteration%4];var reach=[1.0,3.0,5.5,12.0][iteration%4]
  reference.reset();current.reset();reference.begin(hero,angle,reach);current.begin(hero,angle,reach)
  check(reference.target()==current.target() and reference.active==current.active,"Local acquisition keeps the original target and order")
  reference.begin(hero,angle,reach);current.begin(hero,angle,reach)
  check(reference.target()==current.target(),"Combo memory keeps the original retained target")
 check(current.visited<reference.visited/4,"Acquisition stays local among all 240 enemies")
 var counts={"reference_points":reference.visited,"local_points":current.visited}
 # A custom population keeps the existing conservative fallback.
 var extra=Caster.new();game.add_child(extra);game.enemies.append(extra)
 reference.reset();current.reset();reference.begin(hero,0,5.5);current.begin(hero,0,5.5)
 check(reference.target()==current.target(),"Unknown actors retain original acquisition behavior")
 reference=null;current=null;army.clear();army.queue_free();game.queue_free()
 for i in 3:await process_frame
 FileAccess.open("res://build/Other Files/Asset Toolkit/24 Hero Smoothness/melee-assist-cost.json",FileAccess.WRITE).store_string(JSON.stringify(counts,"  "))
 print("MELEE_ASSIST_LOCAL_RESULT checks=",checks," failures=",failures," visits=",counts);quit(1 if failures else 0)
