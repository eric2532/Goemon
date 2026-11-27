extends "res://tests/forest-shrine/east_field_crag_angles.gd"
## Actual existing map/layout with private meshes injected only in this process.
const PRIVATE_FOLDER="res://build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Volume Candidates/"
var private_active=false
func run():
 var material_only="--material-only" in OS.get_cmdline_user_args()
 root.size=Vector2i(1440,900);phase="PrivateCliffMaterial" if material_only else "PrivateCliffVolumes"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+phase))
 var candidate_sha=FileAccess.get_sha256(PRIVATE_FOLDER+"data.json")
 var candidate:Dictionary=FieldCliffs.StoneRelief.data(PRIVATE_FOLDER);var stale=[]
 for path in candidate.source_inputs:
  if FileAccess.get_sha256("res://"+path)!=String(candidate.source_inputs[path]):stale.append(path)
 if not stale.is_empty():push_error("Private cliff candidate is stale; regenerate before map review: "+str(stale));quit(2);return
 # Initialize the unchanged sparse/substrate materials before replacing full-family cache entries.
 FieldCliffs.mesh(12539)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east-private-cliffs-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 game.model.team_progression.cards_enabled=false;game.tuning.invincible=true;game.player.set_auto_attack(false)
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 review_area="east_gate";await open_area("east_gate")
 var original_owners={}
 if not material_only:
  await field_view("east-baseline-normal",Vector2(542,220),Vector2(536,218))
  original_owners=cliff_performance.back().source_owners.duplicate(true)
 var before_memory={"buffer":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED),"video":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)};var started=Time.get_ticks_usec()
 for id in [12536,12537,12538,12542,12543,12546]:FieldCliffs.meshes[id]=FieldCliffs.StoneRelief.mesh(id,null,PRIVATE_FOLDER)
 for node:MultiMeshInstance3D in game.world.find_children("EastNativeCliff_*","MultiMeshInstance3D",true,false):
  var id=int(node.get_meta("source_graphic",0))
  if id in [12536,12537,12538,12542,12543,12546]:node.multimesh.mesh=FieldCliffs.meshes[id]
 private_active=true
 for i in 8:await process_frame
 var setup={"cpu_and_upload_settle_ms":(Time.get_ticks_usec()-started)*.001,"before":before_memory,"after":{"buffer":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED),"video":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)},"scope":"Whole-process change during six-family candidate preparation and eight settling frames. Canonical baseline meshes remain cached for this comparison; normal game activity continues."}
 await field_view("east-crag-normal",Vector2(542,220),Vector2(536,218))
 if not original_owners.is_empty():check(original_owners==cliff_performance.back().source_owners,"Process-only mesh swap preserves every mounted East source placement/anchor")
 else:check(cliff_performance.back().source_owners.east_gate.mounted_instances==985,"All985prepared East rows remain mounted;34entrance handoffs are separately accounted")
 await field_view("east-crag-second",Vector2(538,222),Vector2(536,218))
 await field_view("east-crag-source-face",Vector2(530,222),Vector2(536,218))
 if not material_only:
  await field_view("habaru-mouth-normal",Vector2(669,225),Vector2(672,223))
  await field_view("habaru-mouth-second",Vector2(676,222),Vector2(672,223))
 review_area="alyut";await open_area("north_coast");await site(2400,"alyut")
 await prop_views("alyut-cliff-context",Vector2i(51,44),Vector2i(63,35),Vector2i(60,60))
 var alyut=0
 for node in game.world.find_children("*","Node3D",true,false):
  if node.get_meta("east_native_cliff_source_map",0)==2400:alyut+=node.get_meta("east_native_cliff_source_placements",[]).size()
 check(alyut==125,"All125source-confirmed Alyut placements remain mounted once")
 check(candidate_sha==FileAccess.get_sha256(PRIVATE_FOLDER+"data.json"),"Private candidate stayed unchanged throughout the actual map review")
 var file=FileAccess.open(PROP_OUT+"Cliff Audit/"+("private-volume-material-review.json" if material_only else "private-volume-live-review.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"observations":observations,"captures":captures,"candidate_sha256":candidate_sha,"source_alyut_placements":alyut,"candidate_setup":setup,"camera_performance":cliff_performance,"scope":"Actual launcher cameras and unchanged map/navigation with private mesh cache injection only for this process. One paired canonical/candidate East camera preserves the same world and mounted anchors. No canonical runtime asset publication. Frustum estimates and global GPU/frame measurements remain separate from visual acceptance."},"  "));file.close()
 print("EAST_PRIVATE_CLIFF_VOLUME_REVIEW checks=",checks," failures=",errors," captures=",captures.size());await finish()

func fixed_capture(label:String,eye:Vector3,target:Vector3,method:String):
 if DisplayServer.get_name()=="headless":return
 game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
 game.ui.hide();game.set_process(false)
 var camera:Camera3D=game.camera_rig.camera
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.global_position=eye;camera.look_at(target);camera.reset_physics_interpolation()
 var screen:Image;var usable=false;var attempts=0;var lit_pixels=0
 for retry in 3:
  attempts+=1
  for i in 8:await process_frame
  await RenderingServer.frame_post_draw
  screen=root.get_texture().get_image()
  var probe=screen.duplicate();probe.resize(32,20,Image.INTERPOLATE_NEAREST);lit_pixels=0
  for y in 20:
   for x in 32:
    var pixel=probe.get_pixel(x,y)
    if maxf(pixel.r,maxf(pixel.g,pixel.b))>.02:lit_pixels+=1
  usable=lit_pixels>160
  if usable:break
 check(usable,"Outdoor capture contains a rendered scene rather than a black fence-timeout buffer: "+label)
 check(screen.save_png(REVIEW+phase+"/"+label+".png")==OK,"Capture "+label)
 captures.append({"name":label,"area":Tour.area(game.model),"floor":game.model.falan_floor,"map_position":var_to_str(map_position()),"camera":var_to_str(camera.global_transform),"fov":camera.fov,"method":method,"render_readback_attempts":attempts,"nonblack_probe_pixels":lit_pixels,"usable_image":usable})
 game.set_process(true);game.ui.show()

func rendered_cliff_artifact()->Dictionary:
 if not private_active:return super.rendered_cliff_artifact()
 return {"folder":PRIVATE_FOLDER,"sha256":FileAccess.get_sha256(PRIVATE_FOLDER+"data.json"),"canonical_runtime_sha256":FileAccess.get_sha256(FieldCliffs.StoneRelief.ROOT+"data.json"),"private_injection":true}
