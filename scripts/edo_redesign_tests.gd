extends Node
## Approved design, complete casts, emitted projectiles and VFX lifetimes in the real game.
var game
var checks=0
var failures=0
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures+=1
 print("PASS " if ok else "FAIL ",label)
func frames(count: int):
 for i in range(count):await get_tree().physics_frame
func run():
 await frames(3)
 game.smoke_test=true;game.tuning.freeze_ai=true;game.tuning.invincible=true;game.settings.volume=0.0
 ProjectSettings.set_setting("goemon/experimental_crosshair",true)
 game.player.smoke_mode=true;game.start_mode("defense");game.encounters.enabled=false
 game.player.select_character(2);game.reset_player_at(Vector3(0,.1,205));await frames(15)
 var p=game.player;var m=p.model;var c=p.musashi
 check(m.rig_visual.scene_file_path=="res://assets/models/characters/edo_approved.glb","Game selects the approved fuller-side-hair Edo")
 check(m.skeleton.get_bone_count()==16,"All 16 gameplay joints remain available")
 var hand_positions: Array[Vector3]=[];var chest_basis: Array[Basis]=[];var knee: Array[Basis]=[]
 p.set_physics_process(false)
 c.cast_fireball(false)
 for step in range(24):
  c.elapsed=float(step)/23*c.duration
  m.animate(1.0/60,0,true,0,0,false,0,false)
  hand_positions.append(m.hand_position("R"));chest_basis.append(m.skeleton.get_bone_global_pose(m.skeleton.find_bone("Chest")).basis)
  knee.append(m.skeleton.get_bone_global_pose(m.skeleton.find_bone("Shin_L")).basis)
 var distance=0.0
 for a in hand_positions:
  for b in hand_positions:distance=maxf(distance,a.distance_to(b))
 check(distance>.65,"Fireball hand follows a broad wind-up, release and follow-through arc")
 check(chest_basis[3].get_rotation_quaternion().angle_to(chest_basis[11].get_rotation_quaternion())>.30,"Casting rotates shoulders and chest")
 check(knee[3].get_rotation_quaternion().angle_to(knee[11].get_rotation_quaternion())>.12,"Casting shifts leg weight")
 c.cancel();c.cast_fireball(false);m.locomotion.reset();m.locomotion_velocity=Vector3(0,0,-8)
 var moving_hands=[];var moving_feet=[]
 for step in range(40):
  c.elapsed=float(step)/39*c.duration
  m.animate(1.0/60,8,true,0,0,false,0,false)
  moving_hands.append(m.hand_position("R"));moving_feet.append(m.skeleton.get_bone_global_pose(m.skeleton.find_bone("Foot_L")).origin.z)
 var hand_arc=0.0;var step_lo=INF;var step_hi=-INF
 for a in moving_hands:
  for b in moving_hands:hand_arc=maxf(hand_arc,a.distance_to(b))
 for z in moving_feet:step_lo=minf(step_lo,z);step_hi=maxf(step_hi,z)
 check(hand_arc>.65,"Moving fireball cast retains its throwing hand arc")
 check(step_hi-step_lo>.20,"Moving fireball cast keeps the walking legs active")
 m.locomotion_velocity=Vector3.ZERO
 c.cancel();p.set_physics_process(true);await frames(5)
 c.cast_fireball(false);await frames(9)
 var balls=get_tree().get_nodes_in_group("edo_fireballs")
 check(balls.size()==3 and balls.all(func(b):return b.damage==24 and not b.heavy),"Triple fireballs preserve count and base damage")
 if balls.size()==3:check(balls[0].velocity.normalized().dot(balls[2].velocity.normalized())<.99,"Volley retains its spread")
 c.cancel();await frames(4);c.cast_fireball(true);await frames(15);balls=get_tree().get_nodes_in_group("edo_fireballs")
 check(balls.size()==1 and balls[0].damage==96 and balls[0].heavy,"Giant fireball preserves its single 96-damage projectile")
 c.cancel();await frames(4)
 var fire=FireEnergy.new();fire.charged=true;game.add_child(fire)
 check(fire.energy_material.shader.resource_path=="res://assets/vfx/fireball/ember_energy.gdshader" and fire.energy_material.shader.code.contains("brush_noise"),"Fireballs and meteor cores use animated painted flame shading")
 var burst=EdoFireExplosion.new();burst.game=game;game.add_child(burst)
 check(burst.flames[0].get_child(0).material_override is ShaderMaterial,"Dodge and meteor explosions use flame shaders")
 var shield=FireShieldVisual.new();game.add_child(shield)
 check(shield.energy_material.shader.resource_path=="res://assets/vfx/fire_shield/surge_energy.gdshader","Blue surge uses the authored energy shader")
 var fire_age=fire.age;await frames(8)
 check(fire.age>fire_age and float(fire.energy_material.get_shader_parameter("clock"))>0,"Fire shader clock advances")
 check(fire.sparks.amount<=28,"New flame shading does not inflate spark count")
 fire.queue_free();shield.dissipate();await frames(110)
 check(get_tree().get_nodes_in_group("edo_explosions").is_empty(),"Explosion and smoke expire after their effect lifetime")
 var held=InputEventAction.new();held.action="light_attack";held.pressed=true;Input.parse_input_event(held);Input.flush_buffered_events()
 c.activate_shield();c.start_beam();await frames(5)
 check(is_instance_valid(c.beam) and c.beam.shells[0].material_override.shader.code.contains("brush_noise"),"Piercing beam has flowing ink-flame shading")
 game.show_pause();await frames(3)
 check(c.beam==null and not c.primary_held,"Pause cancels the beam safely")
 held.pressed=false;Input.parse_input_event(held);Input.flush_buffered_events()
 game.resume();p.select_character(3);await frames(4)
 check(c.beam==null and not c.empowered(),"Hero switching clears Edo's spell state")
 game.show_main_menu();game.sound_library.cancel();game.music.stop()
 for voice in game.voices:voice.stop()
 await frames(10)
 print("EDO_REDESIGN_RESULT checks=",checks," failures=",failures)
 get_tree().quit(1 if failures else 0)
