extends SceneTree
## Fan pose reuse must preserve native launch geometry and actual fitted damage.
const Actions=preload("res://assets/rogue/scripts/class_actions.gd")
class CountedCombat extends "res://scripts/rogue_roster_combat.gd":
 var pose_samples=0
 func _animate(delta:float,movement:float)->void:
  pose_samples+=1;super._animate(delta,movement)
var game
var combat
var target
var checks=0
var failures=0
var cfg="user://ranger-fan-pose-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func reference_fan(power:bool):
 # Previous release path deliberately asks for a fresh hand pose per arrow.
 var angle=combat.player.angle
 var downward=not game.crosshair_aim_enabled()
 var origin:Vector3=combat.player.pos+Vector3.UP*1.05*combat.hero.growth_multiplier()
 var direction:Vector3=combat.projectile_direction(angle,origin)
 var impact:Vector3=Vector3(0,1.1,70)
 var side:Vector3=combat.front(angle).cross(Vector3.UP).normalized()
 var distance=maxf(4*combat.hero.growth_multiplier(),Vector2(impact.x-origin.x,impact.z-origin.z).length())
 impact.y=minf(impact.y,origin.y-.6)
 for i in range(-2,3):
  var ray=(impact+side*distance*tan(i*Actions.RANGER_FAN_STEP)-origin).normalized() if downward else direction.rotated(Vector3.UP,i*Actions.RANGER_FAN_STEP)
  Actions.fire_projectile(combat,{"angle":angle+i*Actions.RANGER_FAN_STEP,"direction":ray,"damage":38 if power else 25,"speed":34,"kind":"arrow","weapon":"cutlass","primary":true,"feedback":i==0,"power":power})
 combat.player.shotDownward=downward
func setup_case(attack:bool,downward:bool):
 combat.reset_run();combat.hero.attack_chain.reset();combat.begin_cast("primary")
 combat._ticket.critical_chance=0
 combat.player.pos=combat.hero.global_position;combat.player.angle=PI;combat.aim=Vector3(0,1.1,70)
 if attack:
  var config=Actions.primary_config(combat,0)
  config.style="bow-fan";config.downward=true;config.aimPoint=Vector3(0,0,70)
  Actions.begin_attack(combat,config,0,"cutlass");combat.player.attack.time=combat.player.attack.contact
 combat.player.shotDownward=downward;combat.player.shot=.1
 target.hp=10000;game.model.enemies[target.forest_id].hp=10000
 combat.pose_samples=0;seed(9341)
func capture()->Dictionary:
 var arrows=[];var damage=[]
 for pr in combat.projectiles:
  var state=pr.duplicate(true);state.erase("mesh");state.erase("ticket")
  state.transform=pr.mesh.transform
  arrows.append(state)
  var hp=target.hp
  combat.resolve_projectile_segment(pr,pr.mesh.position,pr.mesh.position+pr.vel.normalized()*18)
  damage.append(hp-target.hp)
 return {"arrows":arrows,"damage":damage,"shot":combat.player.shot,"downward":combat.player.shotDownward,"serial":combat.player.rangerFlightSerial}
func run():
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
 for i in 3:await process_frame
 AudioServer.set_bus_mute(0,true);game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000
 game.set_physics_process(false);game.player.set_physics_process(false)
 game.player.select_character(10);game.player.position=Vector3(0,12,76);game.player.facing=Vector3.FORWARD
 game.player.ai_controlled=true;game.player.ai_aim=Vector3(0,1.1,70)
 combat=CountedCombat.new();game.add_child(combat);combat.configure(game.player,"ranger");combat.sync_actor(game.player.model.actor);combat.active=true
 combat.sound.shared.set_volume(0) # Real-time audio debouncing must not perturb the seeded launch RNG.
 game.player.active_ability=combat;combat.set_process(false)
 var data=game.model.waves.spawn_enemy(4,Vector3(0,0,70));data.hp=10000;data.max_hp=10000;game.sync_enemies()
 target=game.actors[data.id];target.set_physics_process(false);target._sync_fitted_pose();game.model.visible_cells[game.model.cell_of(target.position)]=true
 for active_attack in [true,false]:
  for power in [false,true]:
   setup_case(active_attack,true);reference_fan(power)
   check(combat.pose_samples==5,"Reference releases five fresh native hand poses")
   var expected=capture()
   setup_case(active_attack,true);Actions.fire_ranger_fan(combat,PI,true,"cutlass",Vector3(0,0,70),power)
   check(combat.pose_samples==(1 if active_attack else 2),"Fan shares one pose, retaining the no-attack downward transition")
   var actual=capture()
   check(actual==expected,"Fan retains every arrow transform, spread, power, serial, flight state and damage")
   check(actual.damage.size()==5 and actual.damage.all(func(amount):return amount>0),"All five native arrows damage the fitted target")
 setup_case(false,false);Actions.fire_projectile(combat,{"primary":true,"feedback":false})
 check(combat.pose_samples==1,"An ordinary primary arrow still forces its native hand pose")
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
 for i in 3:await process_frame
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("RANGER_FAN_POSE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
