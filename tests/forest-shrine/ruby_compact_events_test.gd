extends SceneTree
const Ruby=preload("res://scripts/forest/crowd/ruby_boss_sprites.gd")
const Kit=preload("res://scripts/forest/crowd/army_kit_data.gd")
var checks=0
var failures=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("RUBY_COMPACT_FAIL ",message)
func _initialize():run.call_deferred()
func run():
 var native=ClassDB.instantiate("GoemonCrowdRuntime")
 native.configure(32,32)
 var timeline=PackedFloat32Array();timeline.resize(29*8*32)
 for i in range(0,timeline.size(),32):
  timeline[i]=30;timeline[i+1]=1;timeline[i+2]=20;timeline[i+3]=135
 var data={"ruby_boss":true,"soldier_kinds":PackedInt32Array([20]),"soldier_profiles":PackedFloat32Array([60000,3.6,10,4.3,5,1.65]),
  "actions":PackedInt32Array(range(17)),"status_bits":PackedInt32Array([1,2,4,8,16,32,64]),
  "phase_ticks":PackedFloat32Array([36,10,36,30,30]),"contact_ticks":PackedFloat32Array([18,18,18,18]),
  "melee_from":Vector3(0,1,0),"melee_to":Vector3(0,1,-3),"muzzle":Vector3(0,1,0),
  "bullet_speed":12.0,"bullet_life":2.0,"bullet_tail":.1,"bullet_radius":.5,
  "slime_attacks":Kit.expanded_timelines(timeline,32)}
 check(native.configure_kits(data),"The minimal Ruby kit is valid")
 native.set_navigation({})
 var boss:int=native.spawn(1,0,20,Vector3.ZERO,60000,1)
 native.apply_hit(boss,{"amount":10000.0})
 var blades=[]
 for i in 5:
  var handle:int=native.spawn(10+i,0,20,Vector3(15+i*3,0,0),12000,1)
  native.set_pet_skin(handle,1);native.apply_hit(handle,{"element":"ice","status_seconds":300.0});blades.append(handle)
 native.set_targets({"ids":PackedInt64Array([0]),"kinds":PackedInt32Array([0]),"positions":PackedVector3Array([Vector3(0,0,10)]),"hp":PackedFloat32Array([100000])})
 var seen={};var wards=0;var confusion=0;var holy_contacts=0
 for tick in 7200:
  if tick==3600:
   for handle in blades.slice(0,3):native.despawn(handle)
  native.step(1.0/60)
  for event in native.take_scene_events():
   if event.kind!="status" or int(event.get("action_index",0))<750:continue
   for key in ["source_id","target_id","hp","amount","source_tick","external_kind"]:check(event.has(key),"Compact spell events preserve "+key)
   var action:int=event.action_index
   if Ruby.spell_action(action):seen[action]=true
   if action==Ruby.WARD_ACTIVE:
    wards+=1
    check(int(event.get("amount",0)) in Ruby.SPELL_NAMES and event.get("source_tick",0)>=3,"Ward type and lifetime survive marshalling")
    if int(event.get("amount",0))==Ruby.HOLY_SHIELD:
     native.apply_hit(boss,{"amount":1.0,"magical":false,"provoke":false})
     native.apply_hit(boss,{"amount":1.0,"magical":true,"provoke":false})
   if action==Ruby.WARD_BLOCK and int(event.get("amount",0))==Ruby.HOLY_SHIELD:
    holy_contacts+=1
    check(event.get("source_id",0)==1 and event.get("source_tick",0)>0,"Holy Shield contact identity and lifetime survive the production drain")
   if action==Ruby.CONFUSED and event.get("external_kind",-1)==0:
    confusion+=1;check(event.get("target_id",-1)==0 and event.get("amount",0)==4,"Player identity and duration survive marshalling")
 check(holy_contacts>0,"Original Holy Shield contacts reach production presentation")
 check(seen.size()==12 and wards>0 and confusion>0,"Production events deliver every new spell, wards and Confusion")
 print("RUBY_COMPACT_RESULT spells=",seen.size()," checks=",checks," failures=",failures)
 native.clear()
 for frame in 2:await process_frame
 quit(1 if failures else 0)
