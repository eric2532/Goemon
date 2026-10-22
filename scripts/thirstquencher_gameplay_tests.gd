extends SceneTree
const ProjectileView=preload("res://scripts/forest/forest_enemy_arrows.gd")
# Existing VFX manager loads the complete hero combat graph and retains its
# shared resources at standalone-test shutdown. This fixture exercises the real
# bullet GLB/audio/casing methods without initializing that unrelated manager.
class SourceView extends "res://scripts/forest/forest_enemy_arrows.gd":
 func _ready():pass
class ViewGame extends Node3D:
 var settings={"quality":0,"volume":0.0}
 var model
 func forest_point_visible(_point:Vector3)->bool:return true
const Model=preload("res://scripts/forest/forest_model.gd")
var failures=0
var checks=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func fresh():
 var m=Model.new();m.reset(41,{}, {"trees":[],"deposits":[],"buildings":[]})
 m.workers.clear();m.defenders.clear();m.events.clear();m.phase="wave";m.waves.pending=0
 return m
func hits(m,kind:String)->Array:return m.events.filter(func(e):return e.kind==kind)
func attack(m,role:int,hero:Vector3,seconds:float)->Dictionary:
 var e=m.waves.spawn_enemy(role,Vector3(60,0,60));e.facing=0
 m.waves.start_attack(e,"hero",0,hero)
 for frame in ceili(seconds*20):m.waves.attack_tick(e,.05,hero)
 return e
func _initialize():run.call_deferred()
func run():
 var plan=fresh();plan.phase="preparing";plan.balance.waves=[[2,3,7,4]];plan.balance.bosses_per_portal=8;plan.portals=[Vector2i(1,1),Vector2i(2,2)]
 check(plan.waves.begin(),"Soldier-only mixed wave begins with saved giant and boss settings")
 check(plan.waves.remaining_counts==[2,3,0,4] and plan.waves.pending==9,"Effective queue preserves all three ordinary counts and excludes giants")
 check(plan.waves.boss_pending.is_empty() and not plan.waves.giant_pending,"Normal planning queues neither portal bosses nor giants")
 check(plan.balance.waves[0]==[2,3,7,4] and plan.balance.bosses_per_portal==8,"Suppressed enemy settings and saved counts remain editable")
 plan=fresh();plan.phase="preparing";plan.balance.waves=[[0,0,5,0]];plan.balance.bosses_per_portal=8
 check(plan.waves.begin() and plan.waves.pending==0,"Giant-only saved wave has no unspawnable pending slots")
 plan.waves.tick(.05,Vector3(60,0,60))
 check(plan.phase=="victory","Suppressed-only wave completes without stalling")
 var hero=Vector3(60,0,58.6)
 var m=fresh();attack(m,0,hero,1.8)
 check(hits(m,"hero_hit").size()==2,"Red source combo applies two actual contacts")
 m=fresh();attack(m,3,hero,1.8)
 check(hits(m,"hero_hit").size()==1,"Green source thrust has one actual contact")
 m=fresh();attack(m,1,Vector3(60,0,45),4)
 var launches=hits(m,"enemy_arrow").filter(func(e):return e.get("soldier_bullet",false))
 check(launches.size()==3,"Blue source attack emits three source bullets and reloads")
 if launches.size()==3:check(launches[0].from.distance_to(Vector3(60,4.32,57.408))<.00001,"Three-times soldier uses enlarged source root muzzle")
 check(hits(m,"enemy_arrow_impact").filter(func(e):return e.get("muzzle",false)).size()==3,"Each shot displays its earlier original muzzle effect")
 # A source contact must revalidate target position at event time, not the start snapshot.
 m=fresh();var e=m.waves.spawn_enemy(0,Vector3(60,0,60));e.facing=0
 m.waves.start_attack(e,"hero",0,hero);m.waves.attack_tick(e,.4,hero)
 m.waves.attack_tick(e,1.4,Vector3(80,0,60))
 check(hits(m,"hero_hit").is_empty(),"Moving off the committed melee segment avoids delayed contacts")
 # Close flanks share the same grid cell. Proximity must permit native
 # turning before facing-dependent source contact is required at the hit tick.
 for role in [0,3]:
  for side in [-1.0,1.0]:
   m=fresh();e=m.waves.spawn_enemy(role,Vector3(60,0,60));e.facing=0.0
   e.retaliation=5.0
   var flank=Vector3(60+side*1.4,0,60)
   for frame in 80:m.waves.tick_enemy(e,.05,flank)
   check(hits(m,"hero_hit").size()>0,"Role%d turns and attacks a clear same-cell flank side%s"%[role,side])
   check(absf(e.facing)>.5,"Role%d does not stall before its native turn stage"%role)
 for role in [0,3]:
  m=fresh();e=m.waves.spawn_enemy(role,Vector3(60,0,60));e.facing=0.0;e.retaliation=5.0
  m.waves.tick_enemy(e,.05,hero)
  check(e.action=="source_attack","Role%d enters its native attack through real tick_enemy"%role)
  m.waves.tick_enemy(e,.8,Vector3(60,0,54))
  check(hits(m,"hero_hit").is_empty(),"Role%d still misses when the hero retreats off its committed source segment"%role)
 # Exact contact rejects native solid cover and preserves frozen hurt poses.
 m=fresh();e=m.waves.spawn_enemy(0,Vector3(60,0,60));e.facing=0
 m.waves.start_attack(e,"hero",0,hero);m.trees[Vector2i(10,10)]=1.0
 m.waves.attack_tick(e,2.0,hero)
 check(hits(m,"hero_hit").is_empty(),"A new solid native obstacle blocks source melee at actual contact")
 m=fresh();e=m.waves.spawn_enemy(0,Vector3(60,0,60));e.frozen=.2;e.stun=1.0;e.soldier_hurt_left=.5;e.soldier_hurt_tick=0.0
 m.waves.tick_enemy(e,.1,hero)
 check(e.soldier_hurt_tick==0.0 and e.soldier_hurt_left==.5,"Freeze overlap holds recovered hurt pose")
 m.waves.tick_enemy(e,.2,hero)
 check(absf(e.soldier_hurt_tick-3.0)<.00001 and absf(e.soldier_hurt_left-.4)<.00001,"Only unfrozen remainder advances hurt animation before stun return")
 check(absf(float(e.get("soldier_pose_tick",0))-3.0)<.00001,"Source pose clock advances only the unfrozen remainder")
 m.waves.tick_enemy(e,.1,hero)
 check(absf(float(e.get("soldier_pose_tick",0))-6.0)<.00001,"Normal nonfrozen source idle pose clock keeps advancing")
 e.frozen=.1;m.waves.tick_enemy(e,.05,hero)
 check(absf(float(e.get("soldier_pose_tick",0))-6.0)<.00001 and float(e.frozen_pose.get("soldier_pose_tick",0))==float(e.get("soldier_pose_tick",0)),"Frozen snapshot holds the prior source idle pose clock")
 e.facing=0.0;e.soldier_charge_tick=15.0
 m.waves.turn(e,Vector3(60.1,0,50),.05)
 check(e.facing==0.0,"Committed source charge retains heading in a clear straight native corridor")
 m.waves.turn(e,Vector3(70,0,60),.05)
 check(absf(e.facing)>.01 and e.soldier_charge_tick==0.0,"A native route corner releases heading commitment for safe steering")
 # Enlarged gun aims in 3D and may acquire clear elevated targets.
 m=fresh();m.hero_targetable=false
 m.workers[4]={"id":4,"pos":Vector3(60,0,56),"state":"garrison","job":9,"hp":100}
 m.workers[5]={"id":5,"pos":Vector3(60,0,36),"state":"idle","job":-1,"hp":100}
 e=m.waves.spawn_enemy(1,Vector3(60,0,60));m.waves.choose_target(e,Vector3.ZERO)
 check(e.target_kind=="worker" and e.target_id==4,"Three-dimensional gun may acquire a clear elevated garrison")
 # These fixtures exercise real native projectile flight and native map walls.
 m=fresh();e=m.waves.spawn_enemy(1,Vector3(60,0,60));e.facing=0
 check(m.waves.arrows.has_method("launch_soldier"),"Source bullet flight launcher exists")
 if m.waves.arrows.has_method("launch_soldier"):
  m.waves.arrows.launch_soldier(m.waves.projectiles,e,"hero",0,Vector3(60,1.3,30),25)
  var shot:Dictionary=m.waves.projectiles.values()[0];var before:Vector3=shot.pos
  m.waves.arrows.tick(m.waves.projectiles,.1,Vector3(60,0,30))
  check(shot.pos.distance_to(before)>0.8639 and shot.pos.distance_to(before)<.8641,"Source bullet advances8.64m/s independent of generic arrow speed")
  check(shot.pos.y<4.32 and shot.direction.is_equal_approx(before.direction_to(Vector3(60,1.3,30))),"Enlarged muzzle aims down to current ground target in three dimensions")
  var committed:Vector3=shot.direction
  m.waves.arrows.tick(m.waves.projectiles,.1,Vector3(80,0,30))
  check(shot.direction.is_equal_approx(committed),"Source shot keeps its launch direction after the target dodges")
  m.waves.arrows.tick(m.waves.projectiles,4,Vector3(60,0,-100))
  check(m.waves.projectiles.is_empty(),"Source bullet expires after100 source ticks")
  m=fresh();e=m.waves.spawn_enemy(1,Vector3(60,0,60));e.facing=0
  m._make_building("wall",Vector2i(10,8),0,1);m.navigation_revision+=1
  m.waves.arrows.launch_soldier(m.waves.projectiles,e,"hero",0,Vector3(60,1.3,30),25)
  m.waves.arrows.tick(m.waves.projectiles,2,Vector3(60,0,30))
  check(m.waves.projectiles.is_empty() and hits(m,"hero_hit").is_empty(),"Native swept wall contact destroys source bullet before target")
  m=fresh();e=m.waves.spawn_enemy(1,Vector3(60,0,60));e.facing=0
  m.waves.arrows.launch_soldier(m.waves.projectiles,e,"hero",0,Vector3(60,1.3,55),25)
  m.waves.arrows.tick(m.waves.projectiles,1,Vector3(60,0,55))
  check(hits(m,"hero_hit").size()==1 and hits(m,"hero_hit")[0].amount==25,"Source bullet deals original25 damage exactly once")
 # Explicitly preserve generic aimed-arrow fixture behavior.
 m=fresh();e=m.waves.spawn_enemy(1,Vector3(60,0,60))
 m.waves.arrows.launch(m.waves.projectiles,e,"hero",0,Vector3(60,3,30))
 var generic:Dictionary=m.waves.projectiles.values()[0];var old:Vector3=generic.pos
 m.waves.arrows.tick(m.waves.projectiles,.1,Vector3(60,0,30))
 check(absf(generic.pos.distance_to(old)-3.6)<.0001,"Existing generic projectiles retain36m/s aimed flight")
 m=fresh()
 m.waves.projectiles[888]={"id":888,"pos":Vector3(60,1.3,60),"from":Vector3(60,1.3,60),"direction":Vector3.FORWARD,"age":0.0,"life":100.0/30,"left":28.8,"soldier_bullet":true,"target_kind":"hero","target_id":0,"damage":25}
 m.waves.arrows.tick(m.waves.projectiles,0,Vector3(60,0,61.5))
 check(hits(m,"hero_hit").size()==1,"Enlarged32-unit source bullet tail reaches1.728 metres behind its root")
 m=fresh()
 m.waves.projectiles[888]={"id":888,"pos":Vector3(60,1.3,60),"from":Vector3(60,1.3,60),"direction":Vector3.FORWARD,"age":0.0,"life":100.0/30,"left":28.8,"soldier_bullet":true,"target_kind":"hero","target_id":0,"damage":25}
 m.waves.arrows.tick(m.waves.projectiles,0,Vector3(60.6,0,61.5))
 check(hits(m,"hero_hit").is_empty(),"Enlarged bullet tail retains actual .576 metre hero capsule radius")
 var fixture=ViewGame.new();fixture.model=m;root.add_child(fixture)
 var view=SourceView.new();view.game=fixture;fixture.add_child(view)
 var warm=view.has_method("load_source_resources")
 check(warm,"Projectile director exposes the same source-resource initialization used by ready")
 if warm:
  view.load_source_resources()
  check(view.bullet_scene!=null and view.casing_scene!=null and view.gunshot!=null,"Bullet casing and source audio are loaded before the first shot")
 view.launch({"id":999,"from":Vector3(60,4.32,57.408),"to":Vector3(60,1.44,30),"direction":Vector3.FORWARD,"facing":0.0,"soldier_bullet":true})
 check(view.visuals.has(999) and view.visuals[999].get_meta("soldier_bullet",false),"Source projectile event selects recovered bullet visual rather than reed arrow")
 check(view.visuals[999].get_child(0).scale.is_equal_approx(Vector3.ONE*5.4),"Source bullet visual follows enlarged soldier scale")
 check(view.has_method("play_gunshot"),"Source gunshot sound has an explicit original-audio playback path")
 check(view.casings.size()==1,"Visible source gunshot creates its original cosmetic casing")
 if view.casings.size()==1:
  check(view.casings[0].node.get_child(0).scale.is_equal_approx(Vector3.ONE*5.4),"Source casing visual follows enlarged soldier scale")
  check(view.casings[0].node.position.is_equal_approx(Vector3(60,4.32,58.272)),"Casing ejects from enlarged source gun origin")
 view._tick_casings(1.0/30.0)
 if view.casings.size()==1:
  var expected=Basis.from_euler(Vector3(PI/16.0,-PI/512.0,5.0*TAU/4096.0),EULER_ORDER_XYZ)
  check(view.casings[0].node.basis.is_equal_approx(expected),"Casing source Euler axes convert through glTF and controller half-turn")
 view.clear();check(view.visuals.is_empty(),"Wave retirement releases all source bullet visuals")
 view.bullet_scene=null;view.casing_scene=null;view.gunshot=null
 fixture.free()
 load("res://scripts/forest/forest_thirstquencher_visual.gd").resources.clear()
 var contact=load("res://scripts/forest/forest_enemy_contact.gd")
 contact.crowd_script=null;contact.cache.clear();contact.block_cache.clear();contact.soldier_cache.clear()
 await process_frame
 await process_frame
 print("THIRSTQUENCHER_GAMEPLAY_TESTS checks=",checks," failures=",failures)
 quit(1 if failures else 0)
