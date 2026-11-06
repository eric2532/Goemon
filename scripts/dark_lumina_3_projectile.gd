extends "res://scripts/character_projectile.gd"
const Finale=preload("res://scripts/forest/dark_lumina_3_kit.gd")
var kind=0
var velocity=Vector3.ZERO
var damage=0.0
var lifetime=2.0
var age=0.0
var cross_slash=false
var slash_yaw=0.0
var piercing=false
var hit_targets={}
var secondary=false
var grounded=false
var pulse=0.0
var visual:MultiMeshInstance3D
func _ready():
 visual=MultiMeshInstance3D.new();visual.multimesh=MultiMesh.new()
 visual.multimesh.transform_format=MultiMesh.TRANSFORM_3D;visual.multimesh.use_custom_data=true
 visual.multimesh.mesh=Finale.shot_mesh(kind);visual.multimesh.instance_count=3 if kind==3 else 2 if kind==1 else 1;visual.multimesh.set_instance_transform(0,Transform3D.IDENTITY);add_child(visual)
 if kind==1:
  visual.scale=Vector3.ONE*Finale.WIND_VISUAL_SCALE
  visual.multimesh.set_instance_transform(1,Transform3D(Basis.from_scale(Vector3(-1,1,1)),Vector3.ZERO))
 if kind==3:
  for i in range(1,3):visual.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*(.7 if i==1 else .45)),Vector3(0,0,-i*2.5*Finale.SCALE)))
func restart_visual():
 age=0
 var mesh=Finale.meshes.sword_cross if kind==0 and cross_slash else Finale.shot_mesh(kind)
 if visual.multimesh.mesh!=mesh:visual.multimesh.mesh=mesh
 visual.rotation.y=slash_yaw
 visual.multimesh.visible_instance_count=visual.multimesh.instance_count
 if velocity.length_squared()>.001:basis=Basis(Vector3.UP,atan2(-velocity.x,-velocity.z)) if kind==5 else Basis(Quaternion(Vector3.BACK,velocity.normalized()))
 for i in visual.multimesh.instance_count:visual.multimesh.set_instance_custom_data(i,Color(0,1,0,0))
func _physics_process(delta:float):
 if not is_instance_valid(hero) or not game.playing:retire();return
 if game.paused or game.transitioning:return
 var before=age;age+=delta;lifetime-=delta
 if kind==3 and not grounded and before<8.0/30 and age>=8.0/30 and game.get("crowd")!=null:game.crowd.army.presentation.finale_cue(global_position,14,velocity.normalized(),get_instance_id(),0,1.0,skill_factor("size"),attack_ticket)
 for i in visual.multimesh.instance_count:visual.multimesh.set_instance_custom_data(i,Color(maxf(0,age-(i*.06 if kind==3 else 0.0)),1 if i==0 or kind==1 else .25/i,0,0))
 if grounded:
  pulse-=delta
  if pulse<=0:
   pulse+=.4
   for enemy in AttackChain.segment_enemy_candidates(game,global_position,global_position,2*Finale.SHOT_RADIUS[3]*skill_factor("hit_area")):
    if not is_instance_valid(enemy) or enemy.dead:continue
    var contact=AttackChain.segment_contact(enemy,global_position,global_position,2*Finale.SHOT_RADIUS[3]*skill_factor("hit_area"))
    if not contact.is_empty() and AttackChain.clear_line(hero,global_position+Vector3.UP,contact.point):enemy.take_hit(damage,Vector3.UP,false,attack_ticket)
  if lifetime<=0:retire()
  return
 var from=global_position;var next=from+velocity*delta
 var wall=AttackChain.world_ray(self,from,next)
 var end:Vector3=next if wall.is_empty() else wall.position
 if piercing:
  for enemy in AttackChain.segment_enemy_candidates(game,from,end,Finale.SHOT_RADIUS[kind]*skill_factor("hit_area")):
   if not is_instance_valid(enemy) or enemy.dead or hit_targets.has(enemy.get_instance_id()):continue
   if game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):continue
   var contact=AttackChain.segment_contact(enemy,from,end,Finale.SHOT_RADIUS[kind]*skill_factor("hit_area"))
   if contact.is_empty() or not AttackChain.clear_line(self,from,contact.point):continue
   hit_targets[enemy.get_instance_id()]=true
   enemy.take_hit(damage,velocity.normalized(),kind==0,attack_ticket)
   if hero.ai_controlled:game.confirm_ally_impact(enemy,contact.point,velocity.normalized(),1,true,30,false)
   else:game.confirm_impact(enemy,contact.point,velocity.normalized(),1,true,30,false)
 else:
  var contact=AttackChain.nearest_contact(game,self,from,end,Finale.SHOT_RADIUS[kind]*skill_factor("hit_area"))
  if not contact.is_empty():
   contact.enemy.take_hit(damage,velocity.normalized(),kind==0,attack_ticket)
   if hero.ai_controlled:game.confirm_ally_impact(contact.enemy,contact.point,velocity.normalized(),1,true,30,false)
   else:game.confirm_impact(contact.enemy,contact.point,velocity.normalized(),1,true,30,false)
   impact(contact.point);return
 if not wall.is_empty() or lifetime<=0:
  if kind==2 and wall.is_empty():retire();return
  impact(next if wall.is_empty() else wall.position);return
 global_position=next
func impact(point:Vector3):
 # Keep the low wave at its flight height instead of moving it onto the enemy's body.
 var effect_point=global_position if kind==0 else point
 if game.get("crowd")!=null:game.crowd.army.presentation.finale_cue(effect_point,43 if kind==0 and cross_slash else 42 if kind==2 and secondary else 20+kind,velocity.normalized(),get_instance_id(),0,1.0,skill_factor("size"),attack_ticket)
 if kind==2 and not secondary:
  for i in 5:
   var direction=Vector3(sin(i*TAU/5),0,cos(i*TAU/5))
   projectile_pool.launch(hero,get_script(),"finale2",{"kind":2,"secondary":true,"position":point+Vector3.UP*.4*Finale.SCALE,"velocity":direction*8*Finale.SCALE,"lifetime":Finale.WATER_BURST_LIFE,"damage":damage*.5,"attack_ticket":attack_ticket.duplicate()})
 if kind==3 and not grounded:
  var floor_hit=AttackChain.world_ray(self,point+Vector3.UP*.1,point-Vector3.UP*Finale.FALL_HEIGHT)
  if not floor_hit.is_empty() and floor_hit.normal.y>.5:point=floor_hit.position
  grounded=true;global_position=point+Vector3.UP*.25*Finale.SCALE;velocity=Vector3.ZERO;lifetime=2.7;pulse=0
  visual.multimesh.visible_instance_count=1
  return
 retire()

func retire():
 # Ground fire alone owns a sustained presentation lease; impacts outlive their shots.
 if kind==3 and game.get("crowd")!=null:game.crowd.army.presentation.cancel_finale(get_instance_id())
 super.retire()
