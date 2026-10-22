extends "res://scripts/player.gd"
## Mortal persistent mercenary; its native player kit hunts across the map.
var director:Node
var kit_id=5
var slot=0
var state="idle"
const LIVE_STATES=["prepared","appearing","acting","retreating","sheltered","bunker_leaping","returning"]
var shelter=preload("res://scripts/forest/forest_ally_shelter.gd").new(self)
var age=0.0
var delay_left=0.0
var think_left=0.0
var cast_started=false
var opening=false
var pending_thrust=false
var leap_left=0.0
var gate_id=-1
var guard_post=Vector3.INF
var route:Array=[]
var route_goal=Vector2i(-999,-999)
var route_revision=-1
var health_display:Node3D
var health_fill:MeshInstance3D
var health_text:Label3D
static var health_meshes:Dictionary={}
static var health_materials:Dictionary={}
func _setup_initial_model():
 # A summon only uses its assigned kit. Avoid constructing and immediately
 # freeing the native Goemon body, equipment and animations for every ally.
 ensure_character(kit_id)
 model=character_models[kit_id]
func ensure_character(id:int):
 if id!=kit_id or character_models.has(id):return
 var visual=preload("res://scripts/rogue_hero_model.gd").new()
 visual.class_id=RogueRoster.class_id(id);add_child(visual);character_models[id]=visual
 var ability=preload("res://scripts/forest/summoned_ally_combat.gd").new()
 ability.hero=self;ability.game=game;add_child(ability);character_abilities[id]=ability;visual.combat=ability
 ability.configure(self,visual.class_id);ability.sync_actor(visual.actor);visual.hide();visual.set_process(false)
func refresh_max_health(_heal_growth:bool=false):
 max_hp=float(director.HEALTH[slot]);hp=minf(hp,max_hp)
func _ready():
 ai_controlled=true
 super._ready()
 select_character(kit_id)
 for mesh in model.find_children("*","MeshInstance3D",true,false):mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 active_ability.fx.apply_quality(0);active_ability.fx.effect_budget=16;active_ability.fx.army_trails=true
 _create_health_display()
 park()
func _create_health_display():
 health_display=Node3D.new();health_display.name="AllyHealthDisplay";health_display.position.y=3.3;add_child(health_display)
 var back=_health_box(Vector3(0,0,-.02),Vector3(1.85,.22,.04),Color("142b2b"))
 back.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 health_fill=_health_box(Vector3.ZERO,Vector3(1.7,.12,.04),Color("8ae1ac"))
 health_fill.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 health_text=Label3D.new();health_text.position.y=.22;health_text.font_size=22;health_text.pixel_size=.006;health_text.outline_size=5;health_text.modulate=Color("c8f5d7");health_text.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;health_display.add_child(health_text)
func _health_box(position_:Vector3,size_:Vector3,color:Color)->MeshInstance3D:
 # Health changes only each node's transform/text. Shared immutable resources
 # let Forward+ automatically instance the two surfaces across the whole army.
 if not health_meshes.has(size_):
  var mesh=BoxMesh.new();mesh.size=size_;health_meshes[size_]=mesh
 return Geo.mesh(health_display,health_meshes[size_],position_,health_material(color))
func health_material(color:Color)->StandardMaterial3D:
 if not health_materials.has(color):
  var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=color;health_materials[color]=material
 return health_materials[color]
func update_health_display():
 health_display.visible=state in LIVE_STATES and state!="sheltered" and hp>0 and game.model.phase in ["wave","preparing"]
 if not health_display.visible:return
 health_display.global_basis=game.camera_rig.camera.global_basis.orthonormalized()
 var fraction=clampf(hp/maxf(1,max_hp),0,1)
 health_fill.scale.x=maxf(.001,fraction);health_fill.position.x=-.85*(1-fraction)
 var label_="%d / %d"%[ceili(hp),ceili(max_hp)]
 if health_text.text!=label_:health_text.text=label_
func take_hit(amount:float,direction:Vector3,projectile:bool=false):
 if state not in LIVE_STATES or state=="sheltered" or hp<=0 or invuln>0:return
 var damage=active_ability.filter_damage(amount,direction,projectile)
 if damage<=0:return
 hp=maxf(0,hp-damage*game.tuning.enemy_damage);invuln=.35;active_ability.hit()
 if hp<=0:disappear()
 update_health_display();director.sync_targets()
func park():
 shelter.reset()
 director.remove_taunt(self)
 guard_post=Vector3.INF
 state="idle";hide();set_physics_process(false);collision_layer=0
 auto_attack_enabled=false;ai_target=null;ai_move=Vector3.ZERO;pending_thrust=false
 active_ability.cancel();active_ability.active=false
func summon(target:Ninja,point:Vector3,wait:float):
 active_ability.active=true;active_ability.reset_run();attack_chain.reset()
 refresh_max_health();hp=max_hp;invuln=0;velocity=Vector3.ZERO;ai_move=Vector3.ZERO;ai_target=target;collision_layer=2
 route.clear();route_goal=Vector2i(-999,-999);route_revision=-1
 guard_post=point
 global_position=point;ai_aim=AttackChain.aim_point(target,point+Vector3.UP) if target!=null else point+game.player.facing*4
 active_ability.player.pos=point;facing=combat_attack_direction();active_ability.player.angle=atan2(facing.x,facing.z)
 age=0;think_left=.035*absi(gate_id%5);delay_left=wait;cast_started=false;opening=true;pending_thrust=false;leap_left=5;state="appearing"
 show();set_physics_process(true);director.smoke_at(point);update_health_display()
 if game.model.phase=="preparing":state="prepared";set_physics_process(false);update_health_display()
func disappear():
 if state in ["idle","draining"]:return
 director.smoke_at(global_position);director.remove_taunt(self)
 hide();collision_layer=0;auto_attack_enabled=false;ai_move=Vector3.ZERO;ai_target=null;pending_thrust=false
 active_ability.interrupt_attack_for_movement();state="draining";age=0
func assign_guard_post(point:Vector3):
 guard_post=point;global_position=point;active_ability.player.pos=point
 velocity=Vector3.ZERO;ai_move=Vector3.ZERO;ai_target=null;auto_attack_enabled=false
 route.clear();route_goal=Vector2i(-999,-999);route_revision=-1;update_health_display()
func rest_between_waves():
 shelter.reset()
 active_ability.cancel();auto_attack_enabled=false;ai_target=null;ai_move=Vector3.ZERO;velocity=Vector3.ZERO
 pending_thrust=false;opening=false;state="prepared";set_physics_process(false)
 if guard_post.is_finite():assign_guard_post(guard_post)
 update_health_display()
func think():
 var c=active_ability;var p=c.player
 ai_target=director.closest_guard_target(self);auto_attack_enabled=false;c.secondary_held=false
 if ai_target==null:
  game.gate_defenders.set_destination(self,guard_post)
  return
 ai_aim=AttackChain.aim_point(ai_target,global_position+Vector3.UP)
 var offset=ai_aim-global_position;offset.y=0
 var gap=offset.length();var reach=game.gate_defenders.primary_range(self)
 auto_attack_enabled=gap<=reach+.8 and absf(ai_aim.y-global_position.y-1.3)<(12 if kit_id==10 else 3.5)
 var goal=global_position
 if kit_id==10:
  if gap>19:goal+=offset.normalized()*(gap-17)
  elif gap<7:goal-=offset.normalized()*4
 else:goal+=offset.normalized()*maxf(0,gap-reach*.7)
 game.gate_defenders.set_destination(self,goal)
 if kit_id==11:return # Explorers are dedicated primary-combo fighters.
 if p.travel!=null or p.roll>0:return
 var threat=false
 if kit_id==7 and gap<8:
  for enemy in game.model.enemies.values():
   if enemy.action=="windup" and enemy.get("target_kind","")=="defender" and enemy.get("target_id",-1)==gate_id:threat=true;break
  if threat:
   # A defensive guard may interrupt this ally's swing immediately. Keep the
   # actual held native shield so confirmed blocks emit its three counter faces.
   if not p.blocking:c.interrupt_attack_for_movement()
   c.secondary_held=true;c.action("flintlock");auto_attack_enabled=false;return
 # Native auto-combo restarts in the tick that finishes a swing. Temporarily
 # release primary intent when a skill is due so the next decision can cast.
 var secondary_due=p.cooldowns.flintlock<=0 and ((kit_id==8 and gap<7) or (kit_id==5 and gap>4 and gap<12) or (kit_id==10 and gap<25))
 var utility_due=p.cooldowns.drink<=0 and p.buffTime<=0 and gap<22
 if secondary_due or utility_due:auto_attack_enabled=false
 if p.attack!=null:return
 if kit_id==8 and gap>7 and gap<24 and leap_left<=0 and is_on_floor() and p.cooldowns.flintlock<=0:
  jump_buffer=.15;pending_thrust=true;leap_left=5;auto_attack_enabled=false;return
 var buff_before=float(p.buffTime)
 game.gate_defenders.use_special(self,gap)
 if kit_id==7 and p.buffTime>buff_before:director.activate_taunt(self)
func _physics_process(delta):
 if state=="idle":return
 if not director.allies_can_remain():park();return
 if game.model.phase!="wave" or game.paused or game.transitioning or game.ordinary_pause or game.settings_open or game.rogue_roster_open:return
 if shelter.tick(delta):
  if state in ["retreating","returning","bunker_leaping"]:super._physics_process(delta)
  update_health_display();return
 var c=active_ability
 if state=="prepared":
  think_left-=delta
  if think_left<=0:
   think_left=.2;ai_target=director.closest_guard_target(self)
  if ai_target==null:
   # Distant projectiles can hit a waiting guard before it acquires a target.
   c.tick_timers(delta);return
  ai_aim=AttackChain.aim_point(ai_target,global_position+Vector3.UP)
  if kit_id==8:global_position+=Vector3.UP*12;c.player.pos=global_position
  state="appearing";delay_left=.08
 if state=="draining":
  c.tick(delta);age+=delta
  if c.projectiles.is_empty() and c.player.pulses.is_empty() and c.fx.items.is_empty():park()
  return
 age+=delta;leap_left=maxf(0,leap_left-delta)
 if state=="appearing":
  delay_left-=delta
  if delay_left>0:return
  if not director.guard_target_allowed(self,ai_target):ai_target=director.closest_guard_target(self)
  if ai_target!=null:ai_aim=AttackChain.aim_point(ai_target,global_position+Vector3.UP)
  move_and_slide()
  if kit_id in [8,5]:c.action("flintlock")
  elif kit_id==7:c.action("drink")
  cast_started=true;state="acting";age=0
  if kit_id==7:director.activate_taunt(self);c.fx.ring(global_position,Color("91cfff"),9,.7)
 if opening:
  opening=not ((kit_id==5 and c.player.roll<=0 and c.player.dashAttack==null and age>.15) or (kit_id==8 and c.player.travel==null and c.player.pulses.is_empty() and age>.85) or kit_id in [7,10,11])
 if not opening:
  think_left-=delta
  if think_left<=0:think_left=.2;think()
 if pending_thrust and not is_on_floor() and velocity.y>0:
  c.action("flintlock");pending_thrust=false
 if director.guard_target_allowed(self,ai_target):ai_aim=AttackChain.aim_point(ai_target,global_position+Vector3.UP)
 super._physics_process(delta);update_health_display()
