extends SceneTree
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var r=ClassDB.instantiate("GoemonCrowdRuntime")
 var s={"projectile_ids":PackedInt64Array(),"projectile_kinds":PackedInt32Array(),"projectile_power":PackedByteArray(),"projectile_teams":PackedByteArray(),"projectile_age":PackedFloat32Array(),"projectile_directions":PackedVector3Array(),"projectile_scales":PackedFloat32Array(),"projectile_positions":PackedVector3Array(),"shield_positions":PackedVector3Array(),"shield_yaw":PackedFloat32Array(),"shield_age":PackedFloat32Array(),"shield_scales":PackedFloat32Array()}
 for i in 2400:
  s.projectile_ids.append(i+1);s.projectile_kinds.append(5 if i%3==0 else 10);s.projectile_power.append(i%2);s.projectile_teams.append(0 if i%4==0 else 1)
  s.projectile_age.append(i*.013-.1);s.projectile_scales.append(.25+(i%17)*.1);s.projectile_positions.append(Vector3(i%30,i%7,i/30))
  s.projectile_directions.append([Vector3.ZERO,Vector3.BACK,Vector3.FORWARD,Vector3.UP,Vector3.DOWN,Vector3(.3,.2,-.7),Vector3(.0001,0,0)][i%7])
 for i in 150:s.shield_positions.append(Vector3(i,7,-i));s.shield_yaw.append(i*.27);s.shield_age.append(i*.002);s.shield_scales.append(.5+i*.01)
 var result:Dictionary=r.projectile_buffers(s,1.0/3.0,Vector2i(2000,128));check(result.valid,"Mixed projectile and shield snapshot packs in one native call")
 var offsets={}
 for i in 2000:
  var kind:int=s.projectile_kinds[i];var key="star" if kind==5 else ("ranger-power-arrow" if s.projectile_power[i] else "ranger-arrow")
  if s.projectile_teams[i]==0:key="bullet%d"%posmod(floori(s.projectile_age[i]*30),16)
  var direction:Vector3=s.projectile_directions[i];var basis=Basis(Quaternion(Vector3.BACK,direction.normalized())) if direction.length_squared()>.00001 else Basis.IDENTITY
  if kind==5:basis=basis*Basis(Vector3.UP,s.projectile_age[i]*30)
  if s.projectile_teams[i]==0:basis=basis.scaled(Vector3.ONE/3.0)
  var pose=Transform3D(basis.scaled(Vector3.ONE*s.projectile_scales[i]),s.projectile_positions[i]);var at:int=offsets.get(key,0);offsets[key]=at+16
  check(matches(result.projectiles[key],at,pose,Color(s.projectile_age[i],1,0,0)),"Projectile%d keeps direction, spin, frame, scale, origin and clock"%i)
 for key in result.projectiles:check(result.projectiles[key].size()==offsets.get(key,0),"Capacity trims only excluded projectile rows: "+key)
 for i in 128:
  var pose=Transform3D(Basis(Vector3.UP,s.shield_yaw[i]).scaled(Vector3.ONE*s.shield_scales[i]),s.shield_positions[i])
  check(matches(result.shields,i*16,pose,Color(s.shield_age[i],minf(1,(1-s.shield_age[i]/.22)*3),0,0)),"Shield%d keeps tuned transform and fade"%i)
 check(result.shields.size()==128*16,"Shield capacity is retained")
 var retained:PackedFloat32Array=result.shields
 check(r.projectile_buffers(s,1.0/3.0,Vector2i.ZERO).shields.is_empty() and retained.size()==128*16,"Empty uploads cannot mutate retained packed buffers")
 check(not r.projectile_buffers(s,1.0/3.0,Vector2i(2401,128)).valid,"Oversized counts fail validation")
 var bad=s.duplicate(true);bad.projectile_directions.resize(1)
 check(not r.projectile_buffers(bad,1.0/3.0,Vector2i(1,0)).valid,"Mismatched arrays fail before exposing memory")
 bad=s.duplicate(true);bad.projectile_positions[0]=Vector3(NAN,0,0)
 check(not r.projectile_buffers(bad,1.0/3.0,Vector2i(1,0)).valid,"Nonfinite transforms fail validation")
 bad=s.duplicate(true);bad.projectile_age[0]=3.4e38
 check(not r.projectile_buffers(bad,1.0/3.0,Vector2i(1,0)).valid,"Finite clocks that overflow engine rotation math fail validation")
 var boss=s.duplicate(true);boss.projectile_kinds[0]=4;boss.projectile_teams[0]=0;boss.projectile_scales[0]=5.0;boss.projectile_directions[0]=Vector3.BACK
 var boss_packed:Dictionary=r.projectile_buffers(boss,1.0/3.0,Vector2i(1,0))
 check(boss_packed.valid and boss_packed.projectiles["skullpion-ball"].size()==16,"Native boss balls use their own recovered sprite batch")
 check(matches(boss_packed.projectiles["skullpion-ball"],0,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*5),boss.projectile_positions[0]),Color(boss.projectile_age[0],1,0,0)),"Boss balls retain native position, clock and full boss scale")
 var dragon=s.duplicate(true);dragon.projectile_kinds[0]=8;dragon.projectile_teams[0]=1;dragon.projectile_scales[0]=.7;dragon.projectile_directions[0]=Vector3.BACK;dragon.projectile_age[0]=2.8
 var dragon_packed:Dictionary=r.projectile_buffers(dragon,1.0/3.0,Vector2i(1,0))
 check(dragon_packed.valid and dragon_packed.projectiles.dragon.size()==16,"Hunting dragons have their own shared native projectile batch")
 check(matches(dragon_packed.projectiles.dragon,0,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.7),dragon.projectile_positions[0]),Color(2.8,1,0,0)),"Native dragon packing preserves position, size and the three-second fade clock")
 var finale=s.duplicate(true);finale.projectile_effects=PackedInt32Array();finale.projectile_effects.resize(finale.projectile_ids.size());finale.projectile_kinds[0]=18;finale.projectile_teams[0]=0
 for effect in 6:
  finale.projectile_effects[0]=effect;finale.projectile_power[0]=0
  var packed:Dictionary=r.projectile_buffers(finale,1.0/3,Vector2i(1,0))
  check(packed.valid and packed.projectiles["finale-shot%d"%effect].size()==(48 if effect==3 else 32 if effect==1 else 16),"Finale effect %d keeps its native batch and prepared trails"%effect)
 finale.projectile_effects[0]=1;finale.projectile_directions[0]=Vector3(.7,.1,-.4)
 var wind:Dictionary=r.projectile_buffers(finale,1.0/3,Vector2i(1,0))
 var wind_basis=Basis(Quaternion(Vector3.BACK,finale.projectile_directions[0].normalized()));wind_basis.x=-wind_basis.x
 check(matches(wind.projectiles["finale-shot1"],16,Transform3D(wind_basis.scaled(Vector3.ONE*finale.projectile_scales[0]),finale.projectile_positions[0]),Color(finale.projectile_age[0],1,0,0)),"The second travelling wing mirrors locally at arbitrary flight angles")
 finale.projectile_effects[0]=3;finale.projectile_power[0]=1
 check(r.projectile_buffers(finale,1.0/3,Vector2i(1,0)).projectiles["finale-shot3"].size()==16,"Ground flames stop drawing their falling trails")
 finale.projectile_effects[0]=5;finale.projectile_directions[0]=Vector3(.2,-.7,.3)
 var copy:Dictionary=r.projectile_buffers(finale,1.0/3,Vector2i(1,0))
 var copy_basis=Basis(Vector3.UP,atan2(-.2,-.3)).scaled(Vector3.ONE*finale.projectile_scales[0])
 check(matches(copy.projectiles["finale-shot5"],0,Transform3D(copy_basis,finale.projectile_positions[0]),Color(finale.projectile_age[0],1,0,0)),"Flying Sky copies stay upright on a sloped path")
 finale.projectile_effects[0]=0;finale.projectile_power[0]=1
 check(r.projectile_buffers(finale,1.0/3,Vector2i(1,0)).projectiles["finale-shot6"].size()==16,"Sword cross slash uses the original sprite")
 finale.projectile_yaw_offset=PackedFloat32Array();finale.projectile_yaw_offset.resize(finale.projectile_ids.size())
 for sign_ in [-1,1]:
  finale.projectile_yaw_offset[0]=sign_*PI*3/16
  var cross_basis=Basis(Quaternion(Vector3.BACK,finale.projectile_directions[0].normalized()))*Basis(Vector3.UP,finale.projectile_yaw_offset[0])
  for age in [0.0,.2,.8,1.9]:
   finale.projectile_age[0]=age
   var cross:Dictionary=r.projectile_buffers(finale,1.0/3,Vector2i(1,0))
   check(matches(cross.projectiles["finale-shot6"],0,Transform3D(cross_basis.scaled(Vector3.ONE*finale.projectile_scales[0]),finale.projectile_positions[0]),Color(age,1,0,0)),"Native flying crescent keeps its opposing launch angle without spinning (sign=%s age=%s)"%[sign_,age])
 finale.projectile_yaw_offset[0]=NAN;check(not r.projectile_buffers(finale,1.0/3,Vector2i(1,0)).valid,"Nonfinite projectile yaw is rejected")
 finale.projectile_yaw_offset.resize(1);check(not r.projectile_buffers(finale,1.0/3,Vector2i(1,0)).valid,"Mismatched projectile yaw data is rejected")
 finale.erase("projectile_yaw_offset")
 finale.projectile_effects[0]=6;check(not r.projectile_buffers(finale,1.0/3,Vector2i(1,0)).valid,"Invalid finale effect is rejected")
 var renderer=load("res://scripts/forest/crowd/army_renderer.gd").new();root.add_child(renderer);renderer.configure(null);renderer.presentation.present_snapshot(s)
 check(renderer.presentation.projectile_count==2400 and renderer.presentation.shield_count==128,"Production presenter uses the packed path with unchanged capacities")
 renderer.queue_free();r=null;await process_frame
 print("ARMY_PROJECTILE_BUFFERS_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
func matches(buffer:PackedFloat32Array,at:int,pose:Transform3D,color:Color)->bool:
 if buffer.size()<at+16:return false
 for row in 3:
  for col in 3:
   if absf(buffer[at+row*4+col]-pose.basis[col][row])>.00001:return false
  if absf(buffer[at+row*4+3]-pose.origin[row])>.00001:return false
 for i in 4:
  if absf(buffer[at+12+i]-color[i])>.00001:return false
 return true
