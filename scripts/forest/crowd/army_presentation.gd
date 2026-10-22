extends Node3D
## Bounded cosmetics only. Simulation never reads these pools or their capacity.
const Soldier=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
const MAX_EFFECTS=384
const MAX_CORPSES=128
const MAX_LABELS=32
const MAX_PROJECTILES=16384
var effect_capacity=MAX_EFFECTS
var corpse_capacity=MAX_CORPSES
var label_capacity=MAX_LABELS
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
 game=owner_;meshes=load("res://assets/characters/ally_crowd/visuals.res").get_meta("meshes")
 for key in ["ring","shield","spark","smoke"]:batches[key]=make_batch(meshes[key],"ArmyFX_"+key)
 for kind in [0,1,3]:corpse_batches[kind]=make_batch(shared_meshes[kind] if shared_meshes.has(kind) else Soldier.make_mesh(kind),"ArmyCorpse_%d"%kind)
 for key in meshes:
  if key not in batches:projectile_batches[key]=make_batch(meshes[key],"ArmyProjectile_"+key)
 label_ages.resize(MAX_LABELS)
 for i in MAX_LABELS:
  var label=Label3D.new();label.font_size=24;label.pixel_size=.008;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=false;label.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;label.hide();add_child(label);labels.append(label)
 for i in 8:
  var voice=AudioStreamPlayer3D.new();voice.stream=preload("res://assets/characters/thirstquencher/projectiles/gunshot_43a.wav");voice.max_distance=65;voice.unit_size=12;voice.bus="SFX" if AudioServer.get_bus_index("SFX")>=0 else "Master";add_child(voice);voices.append(voice)
func make_batch(mesh:Mesh,label_:String)->MultiMeshInstance3D:
 var node=MultiMeshInstance3D.new();node.name=label_;node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.use_custom_data=true;node.multimesh.mesh=mesh;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);return node
func present(events:Array):
 for event in events:
  var serial=int(event.get("serial",0))
  if serial>0 and serial<=last_serial:continue
  last_serial=maxi(last_serial,serial)
  var kind=str(event.get("kind",""));var point:Vector3=event.get("position",Vector3.ZERO)
  if kind=="death":
   if int(event.get("team",0))==0 and Soldier.supports(int(event.get("unit_kind",0))) and corpses.size()<corpse_capacity:
    var direction:Vector3=event.get("direction",Vector3.BACK);var yaw=atan2(direction.x,direction.z)
    corpses.append({"age":0.0,"kind":int(event.unit_kind),"position":point+Vector3.UP*1.944,"velocity":(Vector3.UP*4.8+Vector3(sin(yaw),0,cos(yaw))*2.4)*5.4,"yaw":yaw,"pitch":deg_to_rad(67.5)})
   add_effect("smoke",point+Vector3.UP,.45,1.5)
  elif kind=="damage":
   add_effect("spark",point,.18,1.0);label_damage(point,event.amount)
  elif kind=="landing_pulse":add_effect("ring",point,.38,[12.6,16.2,19.8][clampi(int(event.get("action_index",0)),0,2)])
  elif kind=="status" and int(event.get("action_index",0))==14:add_effect("ring",point,.7,9)
  elif kind=="muzzle":add_effect("spark",point,.12,.6)
  elif kind=="bullet" and int(event.get("team",0))==0:gunshot(point)
  elif kind=="projectile_impact":add_effect("spark",point,.16,.55)
func add_effect(kind:String,at:Vector3,life:float,scale_:float):
 if effects.size()>=effect_capacity:return
 if kind=="ring":at+=Vector3.UP*.065
 effects.append({"kind":kind,"position":at,"age":0.0,"life":life,"scale":scale_})
func label_damage(at:Vector3,amount:float):
 for i in mini(label_capacity,labels.size()):
  if label_ages[i]>0:continue
  label_ages[i]=.65;labels[i].position=at;labels[i].text=str(roundi(amount));labels[i].modulate=Color("fff0c7");labels[i].show();return
func gunshot(point:Vector3):
 if not is_instance_valid(game) or not game.playing or game.paused or game.transitioning or game.sound_library.recording or clock<next_sound:return
 var volume=float(game.settings.get("volume",.65))
 if volume<=0 or point.distance_squared_to(game.player.position)>65*65:return
 for voice in voices:
  if voice.playing:continue
  voice.position=point;voice.volume_db=linear_to_db(maxf(.0001,volume*.55));voice.play();next_sound=clock+.035;return
func tick(delta:float):
 if is_instance_valid(game) and (game.paused or game.transitioning):
  for voice in voices:voice.stop()
  return
 var dt=maxf(0,delta);clock+=dt
 for i in range(effects.size()-1,-1,-1):
  effects[i].age+=dt
  if effects[i].age>=effects[i].life:effects.remove_at(i)
 for i in range(corpses.size()-1,-1,-1):
  var row=corpses[i];row.age+=dt
  if row.age>=.8:corpses.remove_at(i);continue
  var before:Vector3=row.position;var next:Vector3=before+Vector3(row.velocity)*dt
  row.velocity.y-=13.5*5.4*dt;row.pitch-=deg_to_rad(22.5)*30*dt
  var floor_=0.0
  if is_instance_valid(game):
   floor_=game.model.surface_height(next.x,next.z)
   if not game.model.waves.navigation.move_clear(Vector3(next.x,floor_,next.z),preload("res://scripts/forest/forest_enemy_roles.gd").footprint_radius(row.kind)):
    next.x=before.x;next.z=before.z;row.velocity.x=0;row.velocity.z=0
  if next.y<floor_:next.y=floor_;row.velocity=Vector3.ZERO
  row.position=next
 for i in labels.size():
  if label_ages[i]<=0:continue
  label_ages[i]=maxf(0,label_ages[i]-dt)
  if label_ages[i]<=0:labels[i].hide()
  else:labels[i].position.y+=dt*.65;labels[i].modulate.a=minf(1,label_ages[i]*5)
 draw_effects();draw_corpses()
func show_rows(node:MultiMeshInstance3D,poses:Array,custom:Array):
 var mm=node.multimesh
 node.visible=not poses.is_empty()
 if poses.size()>mm.instance_count:mm.instance_count=nearest_po2(poses.size())
 for i in poses.size():mm.set_instance_transform(i,poses[i]);mm.set_instance_custom_data(i,custom[i])
 mm.visible_instance_count=poses.size();mm.custom_aabb=AABB(Vector3(-1000,-1000,-1000),Vector3.ONE*2000)
func draw_effects():
 for key in batches:
  if key=="shield":continue
  var poses=[];var colors=[]
  for record in effects:
   if record.kind!=key:continue
   var t=float(record.age)/record.life;var scale_=float(record.scale);var basis=Basis.IDENTITY
   if key=="ring":scale_*=.25+t*.85;basis=Basis(Vector3.RIGHT,-PI/2)
   elif key=="smoke":scale_*=.3+t*.7
   else:scale_*=1-t
   poses.append(Transform3D(basis.scaled(Vector3.ONE*maxf(.001,scale_)),record.position));colors.append(Color(record.age,1-t,0,0))
  show_rows(batches[key],poses,colors)
func draw_corpses():
 for kind in corpse_batches:
  var poses=[];var custom=[]
  for row in corpses:
   if row.kind!=kind:continue
   var shrink=maxf(.01,1-clampf((row.age-.6)/.2,0,1))
   var basis=Basis(Vector3.UP,row.yaw)*Basis(Vector3.RIGHT,-row.pitch)
   poses.append(Transform3D(basis.scaled(Vector3.ONE*shrink),row.position));custom.append(Color(Soldier.frame_state({"variant":kind},maxf(.00001,row.age)).row,0,0,0))
  show_rows(corpse_batches[kind],poses,custom)
func present_snapshot(s:Dictionary):
 var shields=[];var fades=[];shield_count=mini(128,mini(effect_capacity,s.shield_positions.size()))
 for i in shield_count:
  shields.append(Transform3D(Basis(Vector3.UP,s.shield_yaw[i]).scaled(Vector3.ONE*s.shield_scales[i]),s.shield_positions[i]));fades.append(Color(s.shield_age[i],minf(1,(1-s.shield_age[i]/.22)*3),0,0))
 show_rows(batches.shield,shields,fades)
 var poses={};var custom={};projectile_count=mini(MAX_PROJECTILES,s.projectile_ids.size())
 for i in projectile_count:
  var kind:int=s.projectile_kinds[i];var key="star" if kind==5 else ("ranger-power-arrow" if s.projectile_power[i] else "ranger-arrow")
  if s.projectile_teams[i]==0:key="bullet%d"%posmod(floori(s.projectile_age[i]*30),16)
  if not poses.has(key):poses[key]=[];custom[key]=[]
  var direction:Vector3=s.projectile_directions[i];var basis=Basis(Quaternion(Vector3.BACK,direction.normalized())) if direction.length_squared()>.00001 else Basis.IDENTITY
  if kind==5:basis=basis*Basis(Vector3.UP,s.projectile_age[i]*30)
  poses[key].append(Transform3D(basis.scaled(Vector3.ONE*s.projectile_scales[i]),s.projectile_positions[i]));custom[key].append(Color(s.projectile_age[i],1,0,0))
 for key in projectile_batches:show_rows(projectile_batches[key],poses.get(key,[]),custom.get(key,[]))
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
