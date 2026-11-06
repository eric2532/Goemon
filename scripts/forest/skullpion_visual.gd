extends Node3D
## Presentation only; the native army owns this boss's HP, movement and attacks.
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const SIZE=Roles.BOSS_SCALE
const MODEL=preload("res://assets/models/enemies/skullpion.glb")
const SOUND_NAMES={0x55b:"sand_windup",0x55c:"sand_blast",0x55d:"tail_slam",0x55e:"tail_sweep",0x55f:"drill_windup",0x560:"ground_impact",0x561:"drill_release",0x562:"drill_emerge",0x564:"breakup",0x565:"defeat",0x566:"core_recover",0x627:"volley_release",0x628:"volley_bounce",0x629:"volley_expire",0xb08:"core_hit"}
const CUES={101:[[.65,0x627]],102:[[.5,0x55d],[1.17,0x55d],[1.5,0x55e]],103:[[.67,0x55b],[2.33,0x55c]],104:[[1.65,0x560]],105:[[1.33,0x55f],[1.9,0x562],[2.8,0x562],[3.6,0x561],[3.7,0x562]],107:[[0.0,0x564]],108:[[.67,0x55b],[2.33,0x627]]}
const CLIPS={100:"801adc24",101:"801adcec",102:"801add34",103:"801ade54",104:"801ae824",105:"801ae08c",106:"801ae6dc",107:"801ae2c4",108:"801ade54"}
const NAMES={100:"",101:"CHARGE",102:"TAIL SWEEP",103:"SAND BLAST",104:"JUMP STOMP",105:"POISON DRILL",106:"WALL CLIMB",107:"CORE EXPOSED · ATTACK!",108:"BOUNCING VOLLEY"}
var game:Node
var body:Node3D
var animations:AnimationPlayer
var title:Label3D
var ring:MeshInstance3D
var sand:MeshInstance3D
var drill:Node3D
var cue_point=Vector3.ZERO
var cue_until=0.0
var cue_duration=.6
var dead_left=-1.0
var clock=0.0
var last_action=-1
var last_time=-1.0
var last_air_phase=0
var effects:Node3D
var voices:Array[AudioStreamPlayer3D]=[]
var sounds:Dictionary={}
var voice_cursor=0
var audio_started=0
var last_hit=-1.0
var grounded_pose=[]
func _ready():
 body=MODEL.instantiate();body.scale*=2.4*SIZE;body.position.y=.17*SIZE;add_child(body)
 animations=body.find_child("AnimationPlayer",true,false)
 if animations!=null:animations.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 title=Label3D.new();title.font_size=64;title.pixel_size=.015;title.outline_size=10;title.billboard=BaseMaterial3D.BILLBOARD_ENABLED;title.position.y=6.5*SIZE;add_child(title)
 var circle=CylinderMesh.new();circle.top_radius=1;circle.bottom_radius=1;circle.height=.04;circle.radial_segments=48
 ring=MeshInstance3D.new();ring.mesh=circle;ring.material_override=material(Color(1,.25,.06,.32));ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;ring.hide();add_child(ring)
 effects=preload("res://scripts/forest/skullpion_effects.gd").new();add_child(effects)
 sand=effects.sand;drill=effects.drill
 for sid in SOUND_NAMES:sounds[sid]=SoundLibrary.original_for(27,"land") if sid==0x560 else load("res://assets/characters/recovered_skullpion/audio/"+SOUND_NAMES[sid]+".wav")
 # Reuse the original blast stream for held casts without loading audio in combat.
 sounds[0x55c]=sounds[0x55c].duplicate()
 sounds[0x55c].loop_mode=AudioStreamWAV.LOOP_FORWARD
 sounds[0x55c].loop_end=roundi(sounds[0x55c].get_length()*sounds[0x55c].mix_rate)
 for i in 4:
  var voice=AudioStreamPlayer3D.new();voice.bus=&"SFX";voice.max_distance=200;voice.unit_size=30;voice.volume_db=-3;add_child(voice);voices.append(voice)
func material(color:Color)->StandardMaterial3D:
 var result=StandardMaterial3D.new();result.albedo_color=color;result.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;result.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;result.cull_mode=BaseMaterial3D.CULL_DISABLED
 return result
func pose(address:String,time:float,loop:bool=true):
 if animations==null:return
 var clip=address if address.begins_with("Castle_") else "Source__"+address
 if not animations.has_animation(clip):return
 var animation=animations.get_animation(clip)
 body.position.y=0 if address.begins_with("Castle_") else .17*SIZE
 if animations.assigned_animation!=clip:animations.play(clip);animations.pause()
 animations.seek(fposmod(time,animation.length) if loop else minf(time,animation.length),true)
func cue(point:Vector3,duration:float):
 cue_point=point;cue_duration=maxf(.1,duration);cue_until=clock+cue_duration
func sync(snapshot:Dictionary,index:int):
 global_position=snapshot.positions[index];rotation.y=snapshot.yaw[index]
 var action:int=snapshot.actions[index];var time:float=snapshot.action_time[index]
 var air_phase:int=snapshot.air_phase[index]
 var hp:float=snapshot.hp[index];var maximum:float=snapshot.max_hp[index]
 visible=game.model.visible_at(global_position)
 title.text="SKULLPION   %d%%\n%s"%[ceili(hp/maximum*100),NAMES.get(action,"")]
 if action==106:title.text="SKULLPION   %d%%\n%s"%[ceili(hp/maximum*100),{1:"APPROACHING CASTLE",2:"CLIMBING CASTLE",3:"ON CASTLE WALL",4:"FALLING",5:"JUMPING DOWN"}.get(air_phase,"WALL CLIMB")]
 title.modulate=Color("7fffd3") if action==107 else Color("ffd6b0")
 var clip:String="Castle_Idle" if action==100 else CLIPS.get(action,"801adc24")
 var sample_time=time
 if action==100 and snapshot.velocities[index].length()>0.1:clip="Castle_Walk";sample_time=snapshot.pose_time[index]*Roles.BOSS_MOVE_SPEED
 if action==102 and time>=1.5:clip="Castle_Idle";sample_time=0
 if action==106:
  clip="Castle_Walk" if air_phase==1 else ("Castle_Ascend" if air_phase==2 else ("Castle_Jump" if air_phase==5 else "Castle_Cling"))
  sample_time=snapshot.pose_time[index]*(-1 if air_phase==4 else 1)
 pose(clip,sample_time,action in [100,101,106,107] and not (action==106 and air_phase in [2,5]))
 ground_body(action)
 effects.sync(action,time,cue_point)
 presentation_events(action,time)
 if action==106 and air_phase==3 and (last_action!=106 or last_air_phase!=3):
  var contact=global_position+global_basis.z*12
  play_sound(0x560,contact);effects.burst(contact,1.5)
 if last_action==106 and last_air_phase==5 and air_phase==0:
  play_sound(0x560,global_position);effects.burst(global_position,1.5)
 ring.visible=clock<cue_until and action!=107 and (action!=106 or air_phase==5)
 if ring.visible:
  ring.global_position=cue_point+Vector3.UP*.07
  var radius=3.8 if action==105 else (8.0 if action==104 else 5.5)
  ring.scale=Vector3(radius*SIZE,1,radius*SIZE)
  ring.transparency=clampf((cue_until-clock)/cue_duration*.5,0,.5)
 last_action=action;last_time=time;last_air_phase=air_phase
func play_sound(sid:int,point:Vector3)->bool:
 if not sounds.has(sid) or game==null or not game.playing or game.transitioning or game.ordinary_pause or game.sound_library.recording:return false
 if float(game.settings.get("volume",.65))<=0 or not is_instance_valid(game.player) or point.distance_squared_to(game.player.global_position)>40000:return false
 var voice=voices[voice_cursor%voices.size()];voice_cursor+=1
 voice.stream=sounds[sid];voice.set_meta("sound_id",sid);voice.global_position=point+Vector3.UP*5;voice.pitch_scale=1;voice.play();audio_started+=1
 return true
func presentation_events(action:int,time:float,play_audio:bool=true,sustain_sand:bool=false):
 var previous=last_time if last_action==action and time>=last_time else -.001
 if last_action==107 and action!=107:play_sound(0x566,global_position)
 for mark in CUES.get(action,[]):
  if previous<float(mark[0]) and time>=float(mark[0]):
   var point=cue_point if int(mark[1])==0x562 else global_position
   if play_audio:play_sound(mark[1],point)
   if int(mark[1]) in [0x55d,0x560,0x562,0x564]:
    if int(mark[1])==0x55d:
     point=body.find_child("Part_16",true,false).global_position
     point.y=game.model.surface_height(point.x,point.z)
    effects.burst(point,1.5 if action==104 else 1.0,int(mark[1]) in [0x562,0x564])
 for voice in voices:
  if voice.get_meta("sound_id",0)==0x55c and (action!=103 or (time>=4.1 and not sustain_sand)):voice.stop()
func hit(event:Dictionary):
 if clock-last_hit<.18:return
 last_hit=clock
 if last_action==107:play_sound(0xb08,event.position)
func ground_body(action:int):
 var key=[global_position,rotation.y,action in [104,106,107],game.model.navigation_revision]
 if key==grounded_pose:return
 grounded_pose=key
 body.rotation=Vector3.ZERO
 if action in [104,106,107]:return
 # The retail arena is flat; follow the local slope so the long tail stays visible.
 var front=global_position+global_basis.z*3*SIZE
 var back=global_position-global_basis.z*10*SIZE
 var right=global_position+global_basis.x*3*SIZE
 var left=global_position-global_basis.x*3*SIZE
 var front_y:float=game.model.surface_height(front.x,front.z)
 var back_y:float=game.model.surface_height(back.x,back.z)
 body.rotation.x=-atan2(front_y-back_y,13*SIZE)
 body.rotation.z=atan2(game.model.surface_height(right.x,right.z)-game.model.surface_height(left.x,left.z),6*SIZE)
func retire():
 if dead_left>=0:return
 dead_left=2.8;title.text="SKULLPION DEFEATED";ring.hide();effects.stop()
 for voice in voices:voice.stop()
 play_sound(0x565,global_position);effects.burst(global_position,2,true)
func _process(delta:float):
 if game!=null and (game.transitioning or game.ordinary_pause or (game.paused and game.model.phase=="wave")):return
 clock+=delta;effects.tick(delta)
 if dead_left>=0:
  dead_left-=delta;pose("801ae594",2.8-dead_left,false)
  if dead_left<=0:queue_free()
