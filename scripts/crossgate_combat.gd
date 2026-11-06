extends "res://scripts/recovered_enemy_combat.gd"
## Reuse exact local melee, cover checks, attack tickets and cancellation.
const DURATION=.6
const REACH=3.0
const RADIUS=.42
# shortcut: Cross Gate server hit timing is unverified; use frame 5 of 11 until traced.
const CONTACT=DURATION*5.0/11.0
var sound_cues:Array=[]

func start_attack(_heavy:bool=false):
 if is_attacking() or mode=="dead" or hero.hp<=0:return
 hero.facing=hero.combat_attack_direction()
 hero.model.rotation.y=atan2(-hero.facing.x,-hero.facing.z)
 elapsed=0;pose_tick=0;hits.clear();marker=0;mode="attack";reaction=0
 duration=DURATION;clip="5"
 sound_cues=hero.model.motions.clips["5:%d"%hero.model.direction()].sounds
 ticket=hero.attack_chain.begin("kazi_sword")
 hero.attack_duration=duration;hero.attack_left=duration

func tick(delta:float,after_pose:bool=false):
 if after_pose:return
 if not is_attacking() and mode!="dead" and hero.auto_attack_running():start_attack()
 if not is_attacking():return
 var before=elapsed
 elapsed+=delta*hero.attack_speed_multiplier();pose_tick=elapsed*30
 hero.attack_left=maxf(0,duration-elapsed)
 while marker<sound_cues.size() and elapsed>=float(sound_cues[marker].atMs)/1000:
  hero.play_sound("swing",.5,ticket);marker+=1
 if before<CONTACT and elapsed>=CONTACT:
  strike(Vector3(0,1,0),Vector3(0,1,-REACH),RADIUS,3.0)
 if elapsed>=duration:cancel(true)

func tick_timers(delta:float):
 if mode=="hurt":
  elapsed+=delta
  if elapsed>=.3:cancel(true)
func hit():
 cancel(true);mode="hurt";clip="8"
func die():
 cancel();mode="dead";clip="10"
