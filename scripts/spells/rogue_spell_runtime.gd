extends "res://scripts/rogue_roster_combat.gd"
## Reuse the real action/projectile runtime without borrowing the donor's body or weapons.
func configure(owner:Hero,id:String)->void:
 hero=owner;game=hero.game;class_id=id
 roster=JSON.parse_string(FileAccess.get_file_as_string("res://assets/rogue/data/classes.json"))
 fx=game.get_node_or_null("RogueSharedClassEffects")
 if not is_instance_valid(fx):
  fx=load("res://assets/rogue/scripts/effects.gd").new();fx.name="RogueSharedClassEffects";game.add_child(fx)
 fx.apply_quality(int(game.settings.quality))
 sound=game.get_node_or_null("RogueSharedClassAudio")
 if not is_instance_valid(sound):
  sound=load("res://assets/rogue/scripts/audio.gd").new();sound.name="RogueSharedClassAudio";game.add_child(sound)
 sound.game=game
 if is_instance_valid(sound.get("ambience")):sound.ambience.stop()
 player=_fresh_player();active=true

func _sync_hero()->void:
 if player.is_empty():return
 hero.invuln=maxf(hero.invuln,player.invuln)
 if player.attack!=null or player.roll>0 or player.blocking or player.charging:hero.facing=front(player.angle)

func _animate(_delta:float,_movement:float)->void:pass
func _uses_blade_brush(_attack:Variant)->bool:return false
func _process(delta:float)->void:
 if not active or not game.playing or game.paused or game.transitioning:return
 _present_projectiles()
 if fx.get_meta("tick_frame",-1)!=Engine.get_process_frames():
  fx.set_meta("tick_frame",Engine.get_process_frames());fx.tick(delta)
 sound.set_volume(float(game.settings.volume))

func step_spell(delta:float)->bool:
 player.pos=hero.global_position;player.hp=hero.hp;_update_aim()
 if player.blocking or player.charging:
  player.angle=atan2(aim.x-player.pos.x,aim.z-player.pos.z)
  if player.charging:player.chargeAngle=player.angle
 var was_moving=player.roll>0 or player.travel!=null or player.dive!=null
 var previous=hero.global_position
 if player.dive!=null:_step_dive(delta)
 elif player.travel!=null:step_travel(delta)
 elif player.roll>0:
  var portion=minf(delta,float(player.roll))
  var duration=maxf(.01,float(player.rollDuration))
  var start=1.0-float(player.roll)/duration
  var finish=start+portion/duration
  var travel_time=portion+.28*duration/PI*(sin(finish*PI)-sin(start*PI))
  var vertical=hero.velocity.y
  hero.velocity=player.rollDir*player.rollSpeed*travel_time/maxf(delta,.0001);hero.velocity.y=vertical
  if not hero.is_on_floor():hero.velocity.y-=30.0*delta
  hero.move_and_slide()
  player.roll=maxf(0,player.roll-delta)
  if player.roll<=0:
   use_ticket(player.rollTicket);Actions.finish_dash(self)
 player.pos=hero.global_position
 if player.dashAttack!=null:Actions.resolve_dash_segment(self,previous,player.pos)
 tick(delta)
 return was_moving

func filter_damage(amount:float,direction:Vector3,projectile:bool=false)->float:
 if protects_player():return 0
 if projectile and player.crouched:return 0
 if Actions.block_attack(self,direction,projectile):return 0
 return amount

func tick_timers(delta:float)->void:
 var jump_buffer=hero.jump_buffer;var coyote=hero.coyote;var invulnerability=hero.invuln
 super.tick_timers(delta)
 hero.jump_buffer=jump_buffer;hero.coyote=coyote;hero.invuln=invulnerability

func untargetable()->bool:
 return player.drink>0 or player.untargetable>0 or player.travel!=null
