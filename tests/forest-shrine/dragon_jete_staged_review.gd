extends "res://tests/forest-shrine/freyja_trial_review.gd"
## Private staged table/palette and source party; canonical bank and map flags stay unchanged.
const OUT_JETE="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Dragon Summit/Native bank/"
const STAGED=OUT_JETE+"Staged/"
const Hound=preload("res://scripts/forest/crowd/hound_sprites.gd")
var motion=[]
func _initialize():
 create_timer(900).timeout.connect(func():printerr("DRAGON_JETE_TIMEOUT");quit(1));run.call_deferred()
func take_view(label_:String,cell:Vector2i,yaw:float=0.,screen_offset:float=0.):
 await super.take_view(label_,cell,yaw,screen_offset)
 if DisplayServer.get_name()=="headless":return
 var target=OUT_JETE+"staged-"+label_+".png"
 check(DirAccess.rename_absolute(ProjectSettings.globalize_path(TRIAL_OUT+label_+".png"),ProjectSettings.globalize_path(target))==OK,"Saved staged source Jete view")
 server_report.captures[-1].image=target
 await capture_party_views(13022,"dragon:10029",cell)
 for view in trial_report.party_cameras:
  var path=OUT_JETE+view.image.get_file()
  check(DirAccess.rename_absolute(ProjectSettings.globalize_path(view.image),ProjectSettings.globalize_path(path))==OK,"Saved complementary legal Jete camera")
  view.image=path
 var selected:Dictionary=trial_report.party_cameras[0].selection
 game.camera_rig.yaw=selected.yaw;game.camera_rig.pitch=selected.pitch
 game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance();game.camera_rig.update_camera(0.,true)
 game.camera_rig.reset_physics_interpolation();game.camera_rig.camera.reset_physics_interpolation()
 for i in 4:await process_frame
 for frame in 24:
  for tick in 8:game.army_runtime.integration_tick(1./60.)
  game.army_runtime.sync_compatibility();game.crowd.present_army(game.army_runtime.render_snapshot(),[])
  await process_frame;RenderingServer.force_draw()
  var path=OUT_JETE+"motion-%02d.png"%frame
  check(root.get_texture().get_image().save_png(path)==OK,"Saved fixed native Jete motion sample "+str(frame))
  var enemy=game.model.enemies.values()[0];var handle=int(game.army_runtime.handles[enemy.id])
  motion.append({"image":path,"time":(frame+1)*8./60.,"state":game.army_runtime.unit_state(handle)})
func run():
 root.size=Vector2i(1280,800);review_hp=1000000000.
 East.manifest=JSON.parse_string(FileAccess.get_file_as_string(STAGED+"motions.json"))
 var mesh=Hound.make_mesh(East.ROOT,East.manifest,1.,1.)
 var bytes=FileAccess.get_file_as_bytes(STAGED+"frames.bin");var width=int(East.manifest.table_width)
 mesh.set_meta("source_table",bytes)
 mesh.material.set_shader_parameter("frames",ImageTexture.create_from_image(Image.create_from_data(width,bytes.size()/(width*16),false,Image.FORMAT_RGBAF,bytes)))
 mesh.material.set_shader_parameter("palette",ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(STAGED+"palette.png"))))
 var data=East.data();var staged:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT_JETE+"../Staged/encounters.json"))
 var member:Dictionary=staged.species[256].duplicate(true);member.bank="east_region";member.skin=166
 var original_species_size:int=data.species.size();var added:bool=original_species_size==256
 check((added or original_species_size==258)and int(member.id)==100452 and not member.key.is_empty(),"Exact staged Jete identity preserves established species")
 if added:data.species.append(member)
 else:check(data.species[256]==member,"Published Jete contract matches the reviewed stage")
 var old_group:Dictionary=data.groups.get("dragon:10029",{})
 data.groups["dragon:10029"]=staged.groups["dragon:10029"]
 var pool:Dictionary=staged.pools["10029"].duplicate(true);pool.map=13022;pool.bounds=[0,0,19,19];pool.priority=100
 East.zone_rows[13022].append(pool)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-jete-staged-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=20261127;game.tuning.invincible=true;game.player.set_auto_attack(false);freeze()
 var saved=JSON.stringify(get_meta("falan_venture"));var items=JSON.stringify(get_meta(Events.ITEMS,{}))
 Original.Art.load_sokia_desert_temple();var row:Dictionary=Original.Art.data().maps[Original.path_for(13022)];var gated:bool=row.sokia_visual_only;row.sokia_visual_only=false
 await visit(13022);await direct_group(13022,clear_cell(13022,candidate_cells(13022)),"dragon:10029",pool)
 East.zone_rows[13022].erase(pool)
 if old_group.is_empty():data.groups.erase("dragon:10029")
 else:data.groups["dragon:10029"]=old_group
 if added:data.species.pop_back()
 row.sokia_visual_only=gated
 check(data.species.size()==original_species_size and not Original.owns(13022),"Private staged source overlay and production map gate restored")
 check(JSON.stringify(get_meta("falan_venture"))==saved and JSON.stringify(get_meta(Events.ITEMS,{}))==items,"Adventure/items preserved")
 var mode="headless"if DisplayServer.get_name()=="headless"else"rendered"
 var f=FileAccess.open(OUT_JETE+"live-staged-"+mode+".json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"checks":checks,"failures":errors,"groups":trial_report.groups,"captures":server_report.captures,"party_cameras":trial_report.get("party_cameras",[]),"motion":motion,"goal_complete":false,"bank_published":false,"source_floor":13022,"original_dragon_map_verified":false,"qualification":"Actual native source party on a temporary fixed-map fixture with the staged exact table/palette; no original quest trigger, Dragon terrain, probability or performance certification."},"  "));f.close()
 print("DRAGON_JETE_RESULT checks=",checks," failures=",errors)
 game.army_runtime.finish_integration();game.queue_free()
 for i in 4:await process_frame
 quit(1 if errors else 0)
