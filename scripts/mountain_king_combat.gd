extends "res://scripts/warcraft_combat.gd"
## Mountain King extends the shared Warcraft controller and native contact/status owner.
const MountainShot=preload("res://scripts/mountain_king_projectile.gd")
const Visual=preload("res://scripts/mountain_king_visual.gd")
const TAUNT_TIME=8.0
const CLAP_SCALE=3.0
const BOLT_HEIGHT=1.6
var bolt_cooldown=0.0
var clap_cooldown=0.0
var avatar_cooldown=0.0
var avatar_left=0.0
var taunt_left=0.0
var bashing=false
var target:Node3D
var body_fx:MeshInstance3D
var clap_fx:MeshInstance3D
var avatar_fx:MeshInstance3D
var clap_age=100.0
var avatar_age=100.0
func prepare_projectiles():
 if body_fx==null:
  body_fx=Visual.new();cast_model().rig_visual.add_child(body_fx);body_fx.setup("body");body_fx.hide()
  clap_fx=Visual.new();hero.add_child(clap_fx);clap_fx.setup("clap");clap_fx.hide()
  avatar_fx=Visual.new();hero.add_child(avatar_fx);avatar_fx.setup("avatar");avatar_fx.hide()
 for key in ["bolt","stun","bash","slow"]:Pool.service(game).warm(hero,MountainShot,key,{"kind":key},12 if key=="bolt" else 32)
 if spell_owner==null and not hero.ai_controlled:sound("wc_ready")
func rank()->int:
 var level=hero.team_progression.level if hero.team_progression!=null else hero.progression.level
 return clampi(1+(level-1)/2,1,3)
func form_clip(name_:String)->String:
 if not demon:return name_
 return "Attack Slam Alternate" if name_=="Attack Slam" else "Alternate "+name_
func input(event:InputEvent):
 if not active or event.is_echo() or hero.dodge_time>0:return
 if event.is_action_pressed("light_attack"):
  if mode=="attack":queued=true
  else:start_attack()
 elif event.is_action_pressed("heavy_attack") or event.is_action_pressed("equip"):start_bolt()
 elif event.is_action_pressed("surge"):start_clap()
 elif event.is_action_pressed("sky_strike"):start_avatar()
 elif event.is_action_pressed("special_4"):start_taunt()
func start_attack(_heavy:bool=false):
 if is_attacking() or hero.hp<=0:return
 combo=0 if combo_timer<=0 else (combo+1)%2
 bashing=randf()<[.2,.3,.4][rank()-1]
 begin("attack",form_clip("Attack Slam" if bashing else "Attack -%d"%(combo+1)))
 contact=.35;hero.combo=combo+1;sound("wc_attack_1")
func attack_damage(_radial:bool)->float:return 31.0+(25.0 if bashing else 0.0)+(20.0 if demon else 0.0)
func after_strike(enemy:Node3D,_radial:bool):
 if bashing and not enemy.dead:
  var seconds=1.0 if enemy.variant in [4,17,18] else 2.0
  if enemy.has_method("apply_stun"):enemy.apply_stun(seconds)
  else:enemy.combat_knockback(Vector3.ZERO,0,seconds)
  MountainShot.status(hero,MountainShot,"bash",enemy,seconds,ticket)
func start_bolt():
 if is_attacking() or bolt_cooldown>0 or hero.hp<=0:return
 target=null
 var origin=hero.global_position+Vector3.UP*BOLT_HEIGHT
 var nearest=INF
 for enemy in AttackChain.enemy_candidates(game,origin,36):
  if not is_instance_valid(enemy) or enemy.dead:continue
  if game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):continue
  var point=AttackChain.aim_point(enemy,origin);var offset=point-origin
  if offset.length()>36 or not AttackChain.clear_line(hero,origin,point):continue
  var score=offset.length_squared()
  if score<nearest:nearest=score;target=enemy
 begin("bolt",form_clip("Spell Throw"));contact=.4;bolt_cooldown=9
 if is_instance_valid(target):
  var facing=target.global_position-hero.global_position;facing.y=0
  if not facing.is_zero_approx():
   hero.facing=facing.normalized();cast_model().rotation.y=atan2(-hero.facing.x,-hero.facing.z)
func start_clap():
 if clap_cooldown>0 or hero.hp<=0 or not hero.is_on_floor():return
 cancel(true)
 begin("clap",form_clip("Spell Slam"));contact=.4;elapsed=contact;clap_cooldown=6
 hero.attack_left=duration-elapsed;cast_model().pose(clip,elapsed)
 released=true;clap()
func start_taunt():
 if mode=="taunt" or hero.hp<=0 or not hero.is_on_floor():return
 cancel(true)
 begin("taunt",form_clip("Stand - 3"));sound("wc_warcry");taunt_left=TAUNT_TIME
 if hero.ai_controlled and hero.get("native_handle")!=null and hero.native_handle!=0:
  game.army_runtime.apply_hit(hero.native_handle,{"element":"taunt","status_seconds":TAUNT_TIME})
func start_avatar():
 if is_attacking() or avatar_cooldown>0 or demon or hero.hp<=0:return
 begin("avatar","Morph Alternate");contact=0;avatar_cooldown=180
 demon=true;avatar_left=60;avatar_age=0
 hero.refresh_max_health(true);sound("wc_avatar")
 if hero.ai_controlled and hero.get("native_handle")!=null and hero.native_handle!=0:
  game.army_runtime.apply_hit(hero.native_handle,{"element":"avatar","status_seconds":60})
func end_avatar():
 if not demon:return
 demon=false;avatar_left=0;hero.refresh_max_health(false)
 if mode=="":cast_model().pose("Stand",0)
func filter_damage(amount:float,_direction:Vector3,_projectile:bool)->float:return amount/1.3 if demon else amount
func spell_immune()->bool:return demon
func tick_timers(delta:float):
 super.tick_timers(delta)
 taunt_left=maxf(0,taunt_left-delta)
 bolt_cooldown=maxf(0,bolt_cooldown-delta);clap_cooldown=maxf(0,clap_cooldown-delta);avatar_cooldown=maxf(0,avatar_cooldown-delta)
 if avatar_left>0:
  avatar_left=maxf(0,avatar_left-delta)
  if avatar_left<=0:end_avatar()
func clear_cooldowns():super.clear_cooldowns();bolt_cooldown=0;clap_cooldown=0;avatar_cooldown=0
func tick(delta:float,after_pose:bool=false):
 if after_pose or not active or game.paused or game.transitioning or not game.playing:return
 clap_age+=delta;avatar_age+=delta
 clap_fx.pose("stand",clap_age)
 avatar_fx.scale=Vector3.ONE*.03*hero.model.scale.x;avatar_fx.pose("Spell",avatar_age)
 if mode=="dead":return
 if not is_attacking():
  body_fx.hide()
  if spell_owner==null and hero.auto_attack_running():start_attack()
  return
 elapsed+=delta*(hero.attack_speed_multiplier() if mode=="attack" else 1.0)
 hero.attack_left=maxf(0,duration-elapsed)
 body_fx.pose(clip,elapsed)
 if not released and elapsed>=contact:
  released=true
  if mode=="attack":strike(false)
  elif mode=="bolt":launch_bolt()
  elif mode=="clap":clap()
 if elapsed>=duration:
  var again=queued;finish();combo_timer=.85
  if again:start_attack()
func launch_bolt():
 var origin=hero.global_position+Vector3.UP*BOLT_HEIGHT
 var direction=(AttackChain.aim_point(target,origin)-origin).normalized() if is_instance_valid(target) and not target.dead else hero.facing
 ticket.projectile=true
 Pool.service(game).launch(hero,MountainShot,"bolt",{"position":origin,"target":target,"velocity":direction*30,"damage":[100.0,225.0,350.0][rank()-1]*hero.damage_multiplier(),"attack_ticket":ticket.duplicate(true)})
 target=null;sound("wc_bolt")
func clap():
 clap_age=0;sound("wc_clap")
 clap_fx.scale=Vector3.ONE*.03*CLAP_SCALE*skill_factor("size",ticket);clap_fx.pose("stand",0)
 var origin=hero.global_position+Vector3.UP*.2
 var reach=[7.5,9.0,10.5][rank()-1]*CLAP_SCALE*hero.contact_size_multiplier()*skill_factor("hit_area",ticket)
 for enemy in AttackChain.enemy_candidates(game,origin,reach+2):
  if not is_instance_valid(enemy) or enemy.dead:continue
  if game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):continue
  var ground=game.model.surface_height(enemy.global_position.x,enemy.global_position.z)
  if enemy.global_position.y-ground>2.0:continue
  var hit=AttackChain.segment_contact(enemy,origin,origin,reach)
  if hit.is_empty() or not AttackChain.clear_line(hero,origin,hit.point):continue
  enemy.take_hit([60.0,100.0,140.0][rank()-1]*hero.damage_multiplier(),(enemy.global_position-origin).normalized(),false,ticket)
  if enemy.dead:continue
  var seconds=3.0 if enemy.variant in [4,17,18] else 5.0
  if enemy.has_method("apply_thunder_clap"):enemy.apply_thunder_clap(.5,seconds)
  else:enemy.apply_defense_slow(.5,seconds)
  MountainShot.status(hero,MountainShot,"slow",enemy,seconds,ticket)
func is_attacking()->bool:return mode in ["attack","bolt","clap","avatar","taunt"]
func ground_attack_velocity()->Vector3:return Vector3.ZERO if mode in ["clap","avatar","taunt"] else Vector3.INF
func cancel(preserve_power:bool=false):
 super.cancel(true);target=null
 if is_instance_valid(body_fx):body_fx.hide()
 if not preserve_power:
  taunt_left=0
  end_avatar();clap_age=100;avatar_age=100
  if is_instance_valid(clap_fx):clap_fx.hide();avatar_fx.hide()
func die():
 taunt_left=0
 var death=form_clip("Death")
 cancel(true);mode="dead";clip=death;cast_model().pose(clip,0)
func _exit_tree():
 if is_instance_valid(body_fx):body_fx.queue_free()
 if is_instance_valid(clap_fx):clap_fx.queue_free();avatar_fx.queue_free()
 super._exit_tree()
