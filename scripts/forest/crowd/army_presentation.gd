extends Node3D
## Bounded cosmetics only. Simulation never reads these pools or their capacity.
const DragonFX=preload("res://assets/rogue/scripts/effects.gd")
const Soldier=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
const Finale=preload("res://scripts/forest/dark_lumina_3_kit.gd")
const Dark=preload("res://scripts/forest/dark_lumina_kit.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const MoveAudio=preload("res://scripts/move_audio.gd")
const MONSTER_SOUNDS={6:{"melee":preload("res://assets/characters/recovered_monsters/audio/vambee/bite_column2.wav"),"damage":preload("res://assets/characters/recovered_monsters/audio/vambee/hit_column2.wav")},9:{"melee":preload("res://assets/characters/recovered_monsters/audio/karate_wolf/kick.wav"),"damage":preload("res://assets/characters/recovered_monsters/audio/karate_wolf/hit_column1.wav"),"death":preload("res://assets/characters/recovered_monsters/audio/karate_wolf/death.wav")},14:{"melee":preload("res://assets/characters/recovered_monsters/audio/vambee/bite_column2.wav"),"death":preload("res://assets/characters/recovered_monsters/audio/vambee/vanish_column2.wav")},16:{"melee":preload("res://assets/characters/recovered_monsters/audio/haya_wolf/kick.wav"),"damage":preload("res://assets/characters/recovered_monsters/audio/haya_wolf/hit_column1.wav"),"death":preload("res://assets/characters/recovered_monsters/audio/haya_wolf/death.wav")}}
const MAX_EFFECTS=384
const MAX_CORPSES=128
const MAX_LABELS=32
const MAX_PROJECTILES=16384
var enemy_size=1.0
var dragon_scale=1.0
var effect_capacity=MAX_EFFECTS
var corpse_capacity=MAX_CORPSES
var label_capacity=MAX_LABELS
var native_packer:Object
var game:Node
var meshes:Dictionary={}
var effects:Array[Dictionary]=[]
var corpses:Array[Dictionary]=[]
var labels:Array[Label3D]=[]
var label_ages=PackedFloat32Array()
var voices:Array[AudioStreamPlayer3D]=[]
var batches:Dictionary={}
var corpse_batches:Dictionary={}
var projectile_batches:Dictionary={}
var last_serial=0
var projectile_count=0
var shield_count=0
var clock=0.0
var next_sound=0.0
func configure(owner_:Node,shared_meshes:Dictionary={}):
 Dark.prepare();Finale.prepare()
 game=owner_;meshes=load("res://assets/characters/ally_crowd/visuals.res").get_meta("meshes")
 for key in ["ring","shield","spark","smoke"]:batches[key]=make_batch(meshes[key],"ArmyFX_"+key)
 for kind in preload("res://scripts/forest/forest_enemy_roles.gd").RIGID_TYPES:corpse_batches[kind]=make_batch(shared_meshes[kind] if shared_meshes.has(kind) else Soldier.make_mesh(kind),"ArmyCorpse_%d"%kind)
 corpse_batches[Roles.VAMBEE_LEGS]=make_batch(Soldier.make_mesh(Roles.VAMBEE_LEGS),"ArmyDetachedLegs")
 for key in meshes:
  if key not in batches:projectile_batches[key]=make_batch(meshes[key],"ArmyProjectile_"+key)
 var ball=QuadMesh.new();ball.size=Vector2.ONE*2.304
 var ball_mat=ShaderMaterial.new();ball_mat.shader=preload("res://assets/characters/recovered_skullpion/effects/volley.gdshader");ball_mat.set_shader_parameter("atlas",preload("res://assets/characters/recovered_skullpion/effects/volley.png"));ball_mat.set_shader_parameter("frames",12.0);ball_mat.set_shader_parameter("billboard",true);ball_mat.set_shader_parameter("instanced",true);ball.material=ball_mat
 projectile_batches["skullpion-ball"]=make_batch(ball,"ArmySkullpionVolley")
 for key in ["dragon-descent","dragon-eruption"]:
  var node=make_batch(preload("res://assets/rogue/effects/dragoon_energy_dragon.res"),"ArmyFX_"+key)
  var material=ShaderMaterial.new();material.shader=preload("res://assets/rogue/shaders/dragoon_energy.gdshader")
  material.set_shader_parameter("instanced",true);material.set_shader_parameter("descending",key=="dragon-descent");material.set_shader_parameter("intensity",.75)
  node.material_override=material;batches[key]=node
 var dragon=make_batch(preload("res://assets/rogue/effects/dragoon_energy_dragon.res"),"ArmyHuntingDragons")
 var dragon_material=ShaderMaterial.new();dragon_material.shader=preload("res://assets/rogue/shaders/dragoon_energy.gdshader")
 dragon_material.set_shader_parameter("hunting",true);dragon_material.set_shader_parameter("instanced",true)
 dragon.material_override=dragon_material;projectile_batches["dragon"]=dragon
 projectile_batches["dark-lumina-ball"]=make_batch(Dark.meshes.fire,"ArmyDarkLuminaFire")
 for key in ["impact","ember","shock_dome","shock_ring","fragment","stomp_wave"]:batches["dark-"+key]=make_batch(Dark.meshes[key],"ArmyDarkLumina_"+key)
 batches["dark-spin_dust"]=make_batch(meshes.smoke,"ArmyDarkLuminaSpinDust")
 batches["dark-spin_debris"]=make_batch(Dark.meshes.spin_debris,"ArmyDarkLuminaSpinDebris")
 for key in Finale.meshes:batches["finale-"+key]=make_batch(Finale.meshes[key],"ArmyFinale_"+key)
 for i in 6:projectile_batches["finale-shot%d"%i]=make_batch(Finale.shot_mesh(i),"ArmyFinaleShot%d"%i)
 projectile_batches["finale-shot6"]=make_batch(Finale.meshes.sword_cross,"ArmyFinaleCross")
 label_ages.resize(MAX_LABELS)
 for i in MAX_LABELS:
  var label=Label3D.new();label.font_size=36;label.pixel_size=.00065;label.fixed_size=true;label.outline_size=10;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;label.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;label.hide();add_child(label);labels.append(label)
 for i in 8:
  var voice=AudioStreamPlayer3D.new();voice.stream=preload("res://assets/characters/thirstquencher/projectiles/gunshot_43a.wav");voice.max_distance=65;voice.unit_size=12;voice.bus="SFX" if AudioServer.get_bus_index("SFX")>=0 else "Master";add_child(voice);voices.append(voice)
func make_batch(mesh:Mesh,label_:String)->MultiMeshInstance3D:
 var node=MultiMeshInstance3D.new();node.name=label_;node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.use_custom_data=true;node.multimesh.mesh=mesh;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);return node
func present(events:Array,snapshot:Dictionary={}):
 var camera=get_viewport().get_camera_3d()
 for event in events:
  var serial=int(event.get("serial",0))
  if serial>0 and serial<=last_serial:continue
  last_serial=maxi(last_serial,serial)
  var kind=str(event.get("kind",""));var point:Vector3=event.get("position",Vector3.ZERO)
  var type:int=event.get("unit_kind",-1)
  if type==31 and int(event.get("team",0))==1:
   var slot="wc_spin" if kind=="status" and int(event.get("action_index",0))==9 else "wc_mirror_end" if kind=="death" else "wc_slam" if int(event.get("action_index",0))==2 else "wc_attack_%d"%(int(event.get("action_index",0))%2+1)
   if kind in ["melee","death","status"]:
    var playback=game.sound_library.playback_for(31,slot,null)
    if not playback.muted and MoveAudio.ally_nearby(game,point):play_sound(point,playback.stream,playback.gain*.65)
  if type==Finale.ROLE:
   if kind=="status" and int(event.get("action_index",0))>=300:finale_cue(point,int(event.action_index)-300,event.get("direction",Vector3.FORWARD),-int(event.source_id),int(event.get("source_tick",0)))
   elif kind=="projectile_impact":
    var impact=int(event.get("action_index",0))
    finale_cue(point,43 if impact==0 and event.get("source_tick",0)>0 else 42 if impact==2 and event.get("source_tick",0)>0 else 20+impact,event.get("direction",Vector3.FORWARD),-int(event.source_id))
   elif kind=="damage":cancel_finale(-int(event.target_id));finale_sound(point,"hit_strong" if event.get("heavy",false) else "hit")
   elif kind=="death":cancel_finale(-int(event.target_id));finale_cue(point,30)
  if type==Dark.ROLE:
   if kind=="status" and int(event.get("action_index",0))>=200:
    var direction:Vector3=event.get("direction",Vector3.FORWARD)
    dark_cue(point,int(event.action_index)-200,atan2(-direction.x,-direction.z),-int(event.source_id),1.0,float(event.get("amount",1)))
   elif kind=="projectile_impact":dark_sound(point,"fire_impact");add_effect("dark-impact",point,.53,1)
   elif kind=="damage":cancel_dark_spin(-int(event.target_id));dark_sound(point,"hurt")
   elif kind=="death":cancel_dark_spin(-int(event.target_id));dark_sound(point,"death");dark_cue(point,15)
  if MONSTER_SOUNDS.has(type) and MONSTER_SOUNDS[type].has(kind):play_sound(point,MONSTER_SOUNDS[type][kind])
  if kind=="status" and int(event.get("action_index",0))==18 and is_instance_valid(game):
   var playback=game.sound_library.playback_for(7,"knight_finisher_hit",null)
   if not playback.muted and MoveAudio.ally_nearby(game,point):play_sound(point,playback.stream,playback.gain)
  if kind=="status" and int(event.get("action_index",0))==17 and int(event.get("amount",-1))==Roles.VAMBEE and corpses.size()<corpse_capacity:
   var direction:Vector3=event.get("direction",Vector3.BACK)
   corpses.append({"age":0.0,"life":1.0,"kind":Roles.VAMBEE_LEGS,"position":point,"velocity":Vector3.ZERO,"yaw":atan2(direction.x,direction.z),"pitch":0.0,"tumble":false})
  if kind=="death":
   if int(event.get("team",0))==0 and Soldier.supports(int(event.get("unit_kind",0))) and corpses.size()<corpse_capacity:
    var direction:Vector3=event.get("direction",Vector3.BACK);var yaw=atan2(direction.x,direction.z)
    var tumble=not Roles.RECOVERED.has(type)
    var source:Resource=Soldier.data(type);var clips:Dictionary=source.get_meta("clips");var semantic:Dictionary=source.get_meta("semantics")
    corpses.append({"age":0.0,"life":.8 if tumble else float(clips[semantic.death].ticks)/30+(80.0/30 if type==Dark.ROLE else .2),"kind":type,"position":point+Vector3.UP*.36*Soldier.SCALE*enemy_size if tumble else point,"velocity":(Vector3.UP*4.8+Vector3(sin(yaw),0,cos(yaw))*2.4)*Soldier.SCALE*enemy_size if tumble else Vector3.ZERO,"yaw":yaw,"pitch":deg_to_rad(67.5) if tumble else 0.0,"tumble":tumble})
   add_effect("smoke",point+Vector3.UP,.45,1.5)
  elif kind=="damage":
   var emphasis=4.6 if event.get("critical",false) else 3.8 if event.get("heavy",false) else 3.0
   var impact_point=point
   var target=game.actors.get(int(event.get("target_id",0))) if is_instance_valid(game) and int(event.get("team",0))==0 else null
   if is_instance_valid(target) and camera!=null:
    impact_point=target.combat_contact_point(Vector3(camera.global_position.x,point.y,camera.global_position.z))
    impact_point+=(camera.global_position-impact_point).normalized()*.04
   var contact=add_effect("spark",impact_point,.18,emphasis)
   if not contact.is_empty():contact.contact=true
   label_damage(point,event.amount,event.get("heavy",false),event.get("critical",false))
  elif kind=="landing_pulse":
   var pulse=clampi(int(event.get("action_index",0)),0,2)
   add_effect("ring",point,.38,[12.6,16.2,19.8][pulse]*dragon_scale)
   if pulse<2 and is_instance_valid(game):
    var playback=game.sound_library.playback_for(8,"move_secondary_voice" if pulse==0 else "dragoon_hunt",null)
    if not playback.muted and MoveAudio.ally_nearby(game,point):play_sound(point,playback.stream,playback.gain)
  elif kind=="status" and int(event.get("action_index",0))==14:add_effect("ring",point,.7,9)
  elif kind=="muzzle":add_effect("spark",point,.12,.6)
  elif kind=="bullet" and int(event.get("team",0))==0 and type not in [Dark.ROLE,Finale.ROLE]:gunshot(point)
  elif kind=="projectile_impact" and type not in [Dark.ROLE,Finale.ROLE]:add_effect("spark",point,.16,.55)
func add_effect(kind:String,at:Vector3,life:float,scale_:float,yaw:float=0.0,owner_id:int=0):
 if effects.size()>=effect_capacity:return {}
 if kind=="ring":at+=Vector3.UP*.065
 var record={"kind":kind,"position":at,"age":0.0,"life":life,"scale":scale_,"yaw":yaw,"owner_id":owner_id}
 effects.append(record);return record
func label_damage(at:Vector3,amount:float,heavy:bool=false,critical:bool=false):
 if is_instance_valid(game) and not game.model.visible_at(at):return
 at+=Vector3.UP*1.6
 var camera=get_viewport().get_camera_3d()
 if camera!=null and not camera.is_position_in_frustum(at):return
 for i in mini(label_capacity,labels.size()):
  if label_ages[i]>0:continue
  var label=labels[i]
  label_ages[i]=.65;label.position=at
  label.text=("CRIT " if critical else "")+str(roundi(amount))
  label.font_size=52 if critical else (48 if heavy else 36)
  label.modulate=Color("ffad62") if critical else (Color("ffe49a") if heavy else Color.WHITE)
  label.show();return
func gunshot(point:Vector3):
 play_sound(point,preload("res://assets/characters/thirstquencher/projectiles/gunshot_43a.wav"))
func play_sound(point:Vector3,stream:AudioStream,gain:float=1.0,audible_range:float=65.0,priority:bool=false):
 if stream==null or not is_instance_valid(game) or not game.playing or game.paused or game.transitioning or game.sound_library.recording or (clock<next_sound and not priority):return
 var volume=float(game.settings.get("volume",.65))
 if volume<=0 or point.distance_squared_to(game.player.position)>audible_range*audible_range:return
 var selected:AudioStreamPlayer3D
 for voice in voices:
  if not voice.playing:selected=voice;break
  if priority and voice.get_meta("loop_until",0)==0 and (selected==null or voice.get_meta("started",0)<selected.get_meta("started",0)):selected=voice
 # Foreground cues can reclaim a native loop when all ordinary voices are busy.
 if selected==null and priority:
  for voice in voices:
   if voice.get_meta("loop_owner",0)<0 and (selected==null or voice.get_meta("started",0)<selected.get_meta("started",0)):selected=voice
 if selected==null:return null
 selected.stop();selected.set_meta("loop_until",0);selected.set_meta("loop_owner",0);selected.set_meta("finale_loop","");selected.set_meta("audio_ticket",{});selected.set_meta("started",clock)
 selected.max_distance=audible_range;selected.unit_size=12*audible_range/65
 # The Master bus already applies the user's game volume.
 selected.stream=stream;selected.position=point;selected.pitch_scale=1.0;selected.volume_db=linear_to_db(maxf(.0001,.55*gain));selected.play();next_sound=clock+.035;return selected
func tick(delta:float):
 if is_instance_valid(game) and (game.paused or game.transitioning):
  for voice in voices:voice.stop()
  return
 var dt=maxf(0,delta);clock+=dt
 for voice in voices:
  if voice.playing and not MoveAudio.ticket_audible(game,voice.get_meta("audio_ticket",{})):voice.stop()
  if voice.playing and float(voice.get_meta("loop_until",0))>0 and clock>=float(voice.get_meta("loop_until")):voice.stop()
 for i in range(effects.size()-1,-1,-1):
  var before:float=effects[i].age
  effects[i].age+=dt
  if effects[i].kind=="finale-core":
   var audio_ticket:Dictionary=effects[i].get("audio_ticket",{})
   if before<.7 and effects[i].age>=.7:add_effect("finale-burst",effects[i].position,24.0/30,3.0/16,effects[i].yaw)
   if before<.1 and effects[i].age>=.1:finale_loop(effects[i].position,"core_loop",1.1,effects[i].owner_id if audio_ticket.get("allied",false) else 0,audio_ticket)
   for cue in [[.3,"core_hit"],[.7,"core_burst"],[1.2,"defeat"],[1.8,"ending"]]:
    if before<cue[0] and effects[i].age>=cue[0]:finale_sound(effects[i].position,cue[1],effects[i].get("foreground",false),audio_ticket)
  if effects[i].age>=effects[i].life:effects.remove_at(i)
 for i in range(corpses.size()-1,-1,-1):
  var row=corpses[i];var before:float=row.age;row.age+=dt
  if row.kind==Dark.ROLE:
   if before<2.1 and row.age>=2.1:dark_sound(row.position,"death_final")
   if before<140.0/30 and row.age>=140.0/30:dark_sound(row.position,"breakup")
  if row.age>=row.life:corpses.remove_at(i)
 var moving:Array[Dictionary]=[];var points=PackedVector3Array();var radii=PackedFloat64Array()
 for i in range(corpses.size()-1,-1,-1):
  var row=corpses[i]
  if not row.tumble:continue
  var before:Vector3=row.position;var next:Vector3=before+Vector3(row.velocity)*dt
  row.velocity.y-=13.5*Soldier.SCALE*enemy_size*dt;row.pitch-=deg_to_rad(22.5)*30*dt
  moving.append(row);points.append(next);radii.append(preload("res://scripts/forest/forest_enemy_roles.gd").footprint_radius(row.kind,enemy_size))
 var terrain:PackedFloat64Array=game.model.waves.navigation.terrain_corridors.probe(points,radii) if is_instance_valid(game) and not points.is_empty() else PackedFloat64Array()
 for i in moving.size():
  var row=moving[i];var before:Vector3=row.position;var next:Vector3=points[i];var floor_=terrain[i*2] if not terrain.is_empty() else 0.0
  if not terrain.is_empty():
   if terrain[i*2+1]==0:
    next.x=before.x;next.z=before.z;row.velocity.x=0;row.velocity.z=0
  if next.y<floor_:next.y=floor_;row.velocity=Vector3.ZERO
  row.position=next
 for i in labels.size():
  if label_ages[i]<=0:continue
  label_ages[i]=maxf(0,label_ages[i]-dt)
  if label_ages[i]<=0:labels[i].hide()
  else:labels[i].position.y+=dt*1.4/.65;labels[i].modulate.a=minf(1,label_ages[i]*5)
 draw_effects();draw_corpses()
func show_rows(node:MultiMeshInstance3D,poses:Array,custom:Array):
 var mm=node.multimesh
 if poses.is_empty():
  if node.visible:node.hide();mm.visible_instance_count=0
  return
 node.visible=not poses.is_empty()
 if poses.size()>mm.instance_count:mm.instance_count=nearest_po2(poses.size())
 for i in poses.size():mm.set_instance_transform(i,poses[i]);mm.set_instance_custom_data(i,custom[i])
 mm.visible_instance_count=poses.size();mm.custom_aabb=AABB(Vector3(-1000,-1000,-1000),Vector3.ONE*2000)
func draw_effects():
 var grouped={}
 var camera=get_viewport().get_camera_3d()
 var contact_basis=camera.global_basis.orthonormalized() if camera!=null else Basis.IDENTITY
 var contact_fade=.35 if is_instance_valid(game) and game.settings.get("reduced_flashes",false) else 1.0
 for record in effects:
  var key:String=record.kind
  if record.age<0:continue
  if not grouped.has(key):grouped[key]=[[],[]]
  var poses:Array=grouped[key][0];var colors:Array=grouped[key][1]
  if key in ["dark-spin_dust","dark-spin_debris"]:
   dark_spin_poses(record,poses,colors);continue
  var t=float(record.age)/record.life;var scale_=float(record.scale);var basis=Basis.IDENTITY
  if key=="spark" and record.get("contact",false):
   # Reuse the small painted spark as a readable, camera-facing contact star.
   for ray in 3:
    var pose=(contact_basis*Basis(Vector3.FORWARD,ray*PI/3)).scaled(Vector3.ONE*scale_*(.95+.15*sin(t*PI)))
    poses.append(Transform3D(pose,record.position));colors.append(Color(record.age,(1-t)*contact_fade,0,0))
   continue
  if key.begins_with("finale-"):
   basis=Basis(Vector3.UP,float(record.yaw))
   if key in ["finale-sword_wave","finale-sword_cross"]:basis=Basis(Vector3.UP,float(record.yaw)+PI)
   if record.get("mirrored",false):basis.x=-basis.x
   if key=="finale-blast":scale_*=Finale.SHOT_RADIUS[4]/Finale.blast_radius
   elif key=="finale-core_rays":basis=basis.scaled(Vector3(1,1.5,1))
   elif key=="finale-burst":
    # Source 801AD700 emits eight 0x200-spaced rolls at scale 0x300/0x1000.
    for i in 8:
     poses.append(Transform3D((basis*Basis(Vector3.FORWARD,(i+.5)*TAU/8)).scaled(Vector3.ONE*scale_),record.position));colors.append(Color(record.age,1-t,0,0))
    continue
  elif key=="ring":scale_*=.25+t*.85;basis=Basis(Vector3.RIGHT,-PI/2)
  elif key in ["dark-shock_dome","dark-shock_ring"]:
   scale_*=.018*(1+record.age*30/16.0);basis=Basis(Vector3.UP,record.age*30*TAU/16*(1 if key=="dark-shock_dome" else -1))
  elif key=="dark-fragment":scale_*=.018;basis=Basis(Vector3.UP,t*TAU)
  elif key in ["dark-impact","dark-ember","dark-stomp_wave"]:pass
  elif key=="smoke":scale_*=.3+t*.7
  elif key=="dragon-eruption":basis=Basis(Vector3.UP,float(record.yaw)+sin(t*PI)*.4)
  else:scale_*=1-t
  var position_:Vector3=record.position
  if record.has("anchor"):
   var anchor=record.anchor.get_ref()
   if is_instance_valid(anchor):
    basis=Basis(Vector3.UP,atan2(-anchor.facing.x,-anchor.facing.z))
    position_=anchor.global_position+basis*Vector3(record.get("anchor_offset",Vector3.UP*1.2*Finale.SCALE))
    if record.get("mirrored",false):basis.x=-basis.x
  if record.has("rise"):position_+=Vector3.UP*record.rise*t
  if key=="finale-sky_copy" and record.has("center"):
   var turn=minf(record.age,record.orbit_left)*TAU*30/31*float(record.get("playback_rate",1.0))
   position_=record.center+(position_-Vector3(record.center)).rotated(Vector3.UP,turn);basis=Basis(Vector3.UP,record.yaw+turn)
  poses.append(Transform3D(basis.scaled(Vector3.ONE*maxf(.001,scale_)),position_));colors.append(Color(t,record.age,0,0) if key=="dragon-eruption" else Color(record.age*float(record.get("playback_rate",1.0)),1-t,0,0))
 for key in batches:
  if key in ["shield","dragon-descent"]:continue
  var rows:Array=grouped.get(key,[[],[]])
  show_rows(batches[key],rows[0],rows[1])
func draw_corpses():
 for kind in corpse_batches:
  var poses=[];var custom=[]
  for row in corpses:
   if row.kind!=kind:continue
   var shrink=maxf(.01,1-clampf((row.age-(row.life-.2))/.2,0,1))
   var basis=Basis(Vector3.UP,row.yaw)*Basis(Vector3.RIGHT,-row.pitch)
   var frame:int=Soldier.frame_state({"variant":kind},maxf(.00001,row.age)).row
   poses.append(Transform3D(basis.scaled(Vector3.ONE*shrink),row.position));custom.append(Color(frame,0,0,0))
  show_rows(corpse_batches[kind],poses,custom)
func present_dragons(s:Dictionary):
 var poses=[];var custom=[]
 for i in s.handles.size():
  if poses.size()>=effect_capacity:break
  if s.teams[i]!=1 or s.kinds[i]!=8 or s.air_phase[i] not in [1,2]:continue
  poses.append(DragonFX.diving_dragon_transform(s.positions[i],s.velocities[i],s.yaw[i],clampf(dragon_scale,.25,4.0)*1.15))
  custom.append(Color(.35,s.action_time[i],0,0))
 show_rows(batches["dragon-descent"],poses,custom)
func present_snapshot(s:Dictionary):
 if s.has("handles"):present_dragons(s)
 shield_count=mini(128,mini(effect_capacity,s.shield_positions.size()));projectile_count=mini(MAX_PROJECTILES,s.projectile_ids.size())
 var packed:Dictionary=native_packer.projectile_buffers(s,Soldier.SCALE/5.4,Vector2i(projectile_count,shield_count))
 assert(packed.get("valid",false),"Invalid authoritative projectile snapshot")
 if not packed.get("valid",false):return
 var bounds=AABB(Vector3(-1000,-1000,-1000),Vector3.ONE*2000)
 preload("res://scripts/forest/crowd/army_renderer.gd").upload(batches.shield,packed.shields,bounds)
 for key in projectile_batches:
  preload("res://scripts/forest/crowd/army_renderer.gd").upload(projectile_batches[key],packed.projectiles.get(key,PackedFloat32Array()),bounds)
func clear():
 effects.clear();corpses.clear();projectile_count=0;shield_count=0;last_serial=0;clock=0;next_sound=0
 for i in labels.size():label_ages[i]=0;labels[i].hide()
 for voice in voices:voice.stop()
 for node in batches.values()+corpse_batches.values()+projectile_batches.values():node.multimesh.visible_instance_count=0
func counts()->Dictionary:
 var label_count=0;var playing=0
 for age in label_ages:
  if age>0:label_count+=1
 for voice in voices:
  if voice.playing:playing+=1
 return {"effects":effects.size(),"corpses":corpses.size(),"labels":label_count,"voices":playing,"projectiles":projectile_count,"shields":shield_count,"nodes":get_child_count()}

func suspend_audio():
 for voice in voices:voice.stop()

func dark_sound(point:Vector3,cue:String,foreground:bool=false,ticket:Dictionary={}):
 if not MoveAudio.ticket_audible(game,ticket):return
 if Dark.sounds.has(cue) and is_instance_valid(game):
  var playback=game.sound_library.playback_for(Dark.PLAYER,Dark.slot_for(cue),Dark.sounds[cue])
  if playback.muted:return
  if foreground:
   game.sound(Dark.slot_for(cue),1.0,false,ticket,Dark.PLAYER);return game.last_sound_voice
  return play_sound(point,playback.stream,playback.gain,Dark.SOUND_RANGE,cue=="slam")
func dark_cue(point:Vector3,cue:int,yaw:float=0.0,owner_id:int=0,playback_rate:float=1.0,spin_sign:float=1.0,play_audio:bool=true,foreground:bool=false,ticket:Dictionary={}):
 var names=["claw","fire_charge","step","","grab","throw_full","breath","fire_release","slam","","","spin","","","step"]
 if play_audio and cue>=0 and cue<names.size():dark_sound(point,names[cue],foreground,ticket)
 if cue==1:add_effect("dark-ember",point+Basis(Vector3.UP,yaw)*Dark.MOUTH,1.5,.8)
 if cue in [8,9]:add_effect("dark-stomp_wave",point+Vector3.UP*.08,56.0/30,Dark.SHOCK_RADIUS*(1.0 if cue==9 else .7)/1056.0)
 if cue==15:
  for key in ["shock_dome","shock_ring","fragment"]:
   var record=add_effect("dark-"+key,point+Vector3.UP*2,80.0/30 if key!="fragment" else .9,Dark.SCALE if key!="fragment" else 2)
   if not record.is_empty():record.age=-140.0/30
 if cue==11:
  for key in ["dark-spin_dust","dark-spin_debris"]:
   var record=add_effect(key,point,Dark.SPIN_END/30.0/playback_rate+2,1,yaw,owner_id)
   if not record.is_empty():record.rate=playback_rate;record.emit_until=Dark.SPIN_END;record.spin_sign=spin_sign

func cancel_dark_spin(owner_id:int):
 for record in effects:
  if record.owner_id==owner_id and record.kind in ["dark-spin_dust","dark-spin_debris"]:
   record.emit_until=minf(record.emit_until,record.age*record.rate*30)

func dark_spin_poses(record:Dictionary,poses:Array,colors:Array):
 # One pooled burst draws all 18 × 8 source dust puffs and 18 flying floor tiles.
 var debris:bool=record.kind=="dark-spin_debris"
 var life=2.0 if debris else .45
 for tick in range(Dark.SPIN_START,Dark.SPIN_END):
  var age:float=record.age-tick/30.0/record.rate
  if age<0 or age>=life or tick>record.emit_until:continue
  for i in (1 if debris else 8):
   var lane=posmod(tick*5,8) if debris else i
   var offset=Vector3(sin(tick*2.4+lane)*.55,0,(lane+1)*64*.018)*Dark.SCALE
   offset=offset.rotated(Vector3.UP,record.yaw+Dark.spin_turn(tick)*record.spin_sign)
   var at:Vector3=record.position+offset+Vector3.UP*(maxf(.05,.45+age*8-age*age*12) if debris else .25+age*2)*Dark.SCALE
   if debris:
    at+=Vector3(sin(tick*4.7),0,cos(tick*4.7))*age*4*Dark.SCALE
    poses.append(Transform3D(Basis.from_euler(Vector3(age*4,record.yaw+tick+age*7,age*2)).scaled(Vector3.ONE*(.25+.09*posmod(tick,4))),at));colors.append(Color(posmod(tick*7,32),0,0,0))
   else:
    var size=(.6+age*3)*Dark.SCALE*(1-age/life)
    poses.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),at));colors.append(Color(age,1-age/life,0,0))

func finale_cue(point:Vector3,cue:int,direction:Vector3=Vector3.FORWARD,owner_id:int=0,source_tick:int=0,playback_rate:float=1.0,visual_scale:float=1.0,ticket:Dictionary={}):
 var yaw=atan2(-direction.x,-direction.z)
 var sound=""
 if cue<6:
  if cue==1:
   var playback=game.sound_library.playback_for(30,"finale_wind_start",Finale.sounds.wind_start)
   if not playback.muted and MoveAudio.ticket_audible(game,ticket):
    var voice=play_sound(point,playback.stream,Finale.SOUND_GAIN.wind_start*playback.gain,Finale.SOUND_RANGE,owner_id>0)
    if voice!=null:voice.set_meta("loop_owner",owner_id);voice.set_meta("audio_ticket",ticket)
   for side in [-1,1]:
    for kind in ["finale-wind","finale-wind_outer"]:
     var wind=add_effect(kind,point+Vector3.UP*1.2*Finale.SCALE,316.0/30/playback_rate,visual_scale,yaw,owner_id)
     if not wind.is_empty():
      wind.playback_rate=playback_rate;wind.mirrored=side<0
      var controller=instance_from_id(owner_id) if owner_id>0 else null
      if is_instance_valid(controller) and is_instance_valid(controller.get("hero")):wind.anchor=weakref(controller.hero)
  elif cue in [2,3]:
   var offset=Vector3(0,64,-40)*.018*Finale.SCALE
   var aura=add_effect("finale-cast_aura",point+Basis(Vector3.UP,yaw)*offset,8.0/30/playback_rate,visual_scale,yaw,owner_id)
   if not aura.is_empty():
    aura.playback_rate=playback_rate
    var controller=instance_from_id(owner_id) if owner_id>0 else null
    if is_instance_valid(controller) and is_instance_valid(controller.get("hero")):aura.anchor=weakref(controller.hero);aura.anchor_offset=offset
  elif cue==5:add_effect("finale-sky_spark_2",point+Vector3.UP*Finale.SCALE,.8,visual_scale,yaw,owner_id)
  elif cue==4:sound="cast"
 elif cue==11:sound="sword_cross" if source_tick>88 else "sword_wave"
 elif cue==12:finale_loop(point,"wind_loop",(316-source_tick)/30.0/playback_rate,owner_id,ticket)
 elif cue==13:pass
 elif cue==14:sound="fire_fall"
 elif cue==15:
  sound="earth_impact";add_effect("finale-blast",point+Vector3.UP*.12,56.0/30,visual_scale,yaw)
  if source_tick<=40:
   for i in 16:
    var angle=i*TAU/16;var dust=add_effect("smoke",point+Vector3(sin(angle),0,cos(angle))*18*Finale.SCALE,1.25,3.5*Finale.SCALE*visual_scale,angle)
    if not dust.is_empty():dust.rise=3.0*Finale.SCALE
 elif cue==16:
  sound="sky_copy"
  var copy=add_effect("finale-sky_copy",point,(79+(source_tick-60))/30.0/playback_rate,visual_scale,yaw,owner_id)
  if not copy.is_empty():copy.center=point+direction*7*Finale.SCALE;copy.orbit_left=(91-source_tick)/30.0/playback_rate;copy.playback_rate=playback_rate
  add_effect("finale-sky_spark_0",point,.8,visual_scale,yaw)
 elif cue==17:sound="sky_launch";add_effect("finale-sky_spark_1",point,.8,visual_scale,yaw)
 elif cue==21:
  for side in [-1,1]:
   var wing=add_effect("finale-wind_gust",point,.4,Finale.WIND_VISUAL_SCALE*1.5*visual_scale,yaw)
   if not wing.is_empty():wing.mirrored=side<0
 elif cue==42:add_effect("finale-water_secondary",point,.5,visual_scale,yaw)
 elif cue in [20,22,23,25,43]:
  if cue==23:finale_loop(point,"fire_loop",2.7,owner_id,ticket)
  sound="water_burst" if cue==22 else "" if cue==23 else "impact"
  var effect="sword_wave" if cue==20 else "water" if cue==22 else "fire" if cue==23 else "sky_spark_1" if cue==25 else "sword_cross"
  add_effect("finale-"+effect,point+(Vector3.UP*.12 if cue==25 else Vector3.ZERO),1.0 if cue==22 else .8 if cue==25 else .16 if cue in [20,43] else .6,visual_scale,yaw)
 elif cue==30:
  sound="core_charge";var core=add_effect("finale-core",point+Vector3.UP*Finale.SCALE,2.2,visual_scale,yaw)
  if not core.is_empty():core.foreground=owner_id>0;core.audio_ticket=ticket
  add_effect("finale-core_open",point+Vector3.UP*Finale.SCALE,2,visual_scale,yaw);add_effect("finale-core_rays",point,2,.125,yaw);add_effect("finale-ending",point,2,.125,yaw)
 elif cue==31:cancel_finale(owner_id)
 elif cue==32:sound="cast"
 elif cue==33:sound="sword_swing"
 elif cue==34:sound="earth_rumble"
 elif cue==35:add_effect("finale-sky_spark_3",point+Vector3.UP*Finale.SCALE,.8,visual_scale,yaw)
 if not sound.is_empty():finale_sound(point,sound,owner_id>0,ticket)

func finale_sound(point:Vector3,cue:String,priority:bool=false,ticket:Dictionary={}):
 if not MoveAudio.ticket_audible(game,ticket):return
 var playback=game.sound_library.playback_for(30,"finale_"+cue,Finale.sounds[cue])
 if playback.muted:return
 var gain=float(Finale.SOUND_GAIN.get(cue,1.0))
 if priority:
  game.sound("finale_"+cue,gain,false,ticket,30);return game.last_sound_voice
 return play_sound(point,playback.stream,playback.gain*gain,Finale.SOUND_RANGE)

func cancel_finale(owner_id:int):
 if owner_id==0:return
 for i in range(effects.size()-1,-1,-1):
  if effects[i].get("owner_id",0)==owner_id:effects.remove_at(i)
 for voice in voices:
  if voice.get_meta("loop_owner",0)==owner_id:voice.stop()
func finale_loop(point:Vector3,cue:String,duration:float,owner_id:int,ticket:Dictionary={}):
 if not MoveAudio.ticket_audible(game,ticket):return
 if cue=="fire_loop" and not ticket.get("allied",false):owner_id=0
 for voice in voices:
  if voice.playing and voice.get_meta("loop_owner",0)==owner_id and voice.get_meta("finale_loop","")==cue:
   if cue=="wind_loop":voice.position=point
   voice.set_meta("loop_until",maxf(voice.get_meta("loop_until",0),clock+duration));return
 var playback=game.sound_library.playback_for(30,"finale_"+cue,Finale.sounds[cue])
 if playback.muted:return
 var stream=Finale.loops[cue] if playback.stream==Finale.sounds[cue] else game.sound_library.recorded_loop_for(30,"finale_"+cue,playback.stream)
 var voice=play_sound(point,stream,float(Finale.SOUND_GAIN.get(cue,.6))*playback.gain,Finale.SOUND_RANGE,owner_id>=0)
 if voice!=null:voice.set_meta("loop_until",clock+duration);voice.set_meta("loop_owner",owner_id);voice.set_meta("finale_loop",cue);voice.set_meta("audio_ticket",ticket)
