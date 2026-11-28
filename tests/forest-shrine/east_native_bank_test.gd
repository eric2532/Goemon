extends SceneTree
## Validate the complete recovered bank through the actual published native bridge.
const East=preload("res://scripts/forest/crowd/east_region_sprites.gd")
const Kit=preload("res://scripts/forest/crowd/army_kit_data.gd")
const Dimensions=preload("res://scripts/forest/crowd/pet_dimensions.gd")
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Verification/native-bank-contracts.json"
var checks=0
var failures=[]
func _initialize():
 create_timer(180,true,false,true).timeout.connect(func():printerr("EAST_NATIVE_BANK_TIMEOUT");quit(1))
 run.call_deferred()
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures.append(message);printerr("EAST_NATIVE_BANK_FAIL "+message)
func run():
 var wind_staged="--wind-staged"in OS.get_cmdline_user_args()
 var dragon_staged="--dragon-staged"in OS.get_cmdline_user_args()
 assert(not(wind_staged and dragon_staged),"Select one staged source bank")
 if wind_staged:East.manifest=JSON.parse_string(FileAccess.get_file_as_string("res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Wind Tower/Native bank/Staged/motions.json"))
 if dragon_staged:East.manifest=JSON.parse_string(FileAccess.get_file_as_string("res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Dragon Summit/Native bank/Staged/motions.json"))
 var manifest=East.motions()
 var count_:int=manifest.variants.size()
 check(count_<=Dimensions.CAVE_SKINS,"Every recovered source appearance fits the shared bank")
 var attacks=Kit.expanded_timelines(East.timelines(),int(manifest.timeline_stride),Dimensions.CAVE_SKINS)
 var geometry=Dimensions.geometry(East,true,Roles.MAP_ENEMY_SCALE)
 if not wind_staged and not dragon_staged:
  var snow_skin=-1
  for skin in count_:
   if int(manifest.variants[skin].id)==101413:snow_skin=skin;break
  check(snow_skin>=0,"Recovered source bank includes the authenticated snow plant")
  if snow_skin>=0:check(Dimensions.body(East,snow_skin)==Dimensions.body(preload("res://scripts/forest/crowd/snow_region_sprites.gd"),19),"Copied snow frames retain their approved original body bounds")
 var data={"soldier_kinds":PackedInt32Array([Roles.SLIME]),"soldier_profiles":PackedFloat32Array([300,3.85,12,3.25,5,1.75]),"actions":PackedInt32Array(Kit.ACTION.values()),"status_bits":PackedInt32Array(Kit.STATUS.values()),"phase_ticks":PackedFloat32Array([36,10,36,30,30]),"contact_ticks":PackedFloat32Array([18,18,18,18]),"melee_from":Vector3(0,1,0),"melee_to":Vector3(0,1,-3),"slime_attacks":attacks,"pet_geometry":geometry,"map_enemy_scale":Roles.MAP_ENEMY_SCALE}
 data.merge({"bullet_speed":12.,"bullet_life":2.,"bullet_tail":.1,"bullet_radius":.5,"damage_taken_multiplier":1.})
 var runtime=Runtime.new()
 check(runtime.configure(null,256),"Published native bridge initializes")
 var accepted:bool=runtime.native.configure_kits(data)
 check(accepted,"Published native bridge accepts every original contact/audio cue and source body")
 var invalid=data.duplicate(true);invalid.slime_attacks[3]=20119
 check(not runtime.native.configure_kits(invalid),"An unauthenticated source sound cue is still rejected")
 check(runtime.native.configure_kits(data),"Original source kits remain usable after rejecting an unknown cue")
 check(geometry.size()==(Dimensions.COMPANION_SKINS+Dimensions.CAVE_SKINS+5)*7,"Geometry offsets agree with the native capacity")
 if accepted:
  for repetition in 2:
   for skin in count_:
    var handle=runtime.spawn(5000+skin,0,Roles.SLIME,Vector3(skin*4,0,0),300,.4)
    check(handle!=0 and runtime.native.set_pet_skin(handle,skin),"Recovered skin survives native slot reuse: %d/%d"%[repetition,skin])
    check(runtime.unit_state(handle).get("pose_row",-1)==skin,"Native pose keeps the exact source skin: %d/%d"%[repetition,skin])
    runtime.despawn(handle)
   check(runtime.handles.is_empty(),"Recovered native handles clear after a full bank pass")
  var last=runtime.spawn(9999,0,Roles.SLIME,Vector3.ZERO,300,.4)
  check(runtime.native.set_pet_skin(last,Dimensions.CAVE_SKINS-1),"The final reserved shared slot is valid")
  check(not runtime.native.set_pet_skin(last,Dimensions.CAVE_SKINS),"One-past-capacity source skin is rejected")
  runtime.clear()
 var file=FileAccess.open("res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Dragon Summit/Native bank/native-staged.json"if dragon_staged else"res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Wind Tower/Native bank/native-staged.json"if wind_staged else OUT,FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"source_variants":count_,"capacity":Dimensions.CAVE_SKINS,"timeline_bytes":attacks.size()*4,"geometry_bytes":geometry.size()*4,"scope":"Published Godot native bridge, complete source timeline/body validation, two full spawn/despawn bank passes, final-slot and invalid-slot checks. Does not certify visual appearance, gameplay FPS or long-session growth."},"  "));file.close()
 print("EAST_NATIVE_BANK_RESULT checks=",checks," failures=",failures.size()," variants=",count_)
 runtime.free();quit(1 if not failures.is_empty() else 0)
