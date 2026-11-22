extends SceneTree
const Roster=preload("res://scripts/rogue_roster.gd")
const Skins=preload("res://scripts/kaz_skins.gd")
const Gear=preload("res://scripts/forest/equipment.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
const MazeCombat=preload("res://scripts/maze_combat.gd")
const OUT="res://build/Other Files/Asset Toolkit/Kaz Maze Skin/"
const INVENTORY_OUT="res://build/Other Files/Asset Toolkit/Kaz Complete Inventory/Gameplay/"
var game
var checks=0
var failures=0
var shots:Array=[]
var config_path="user://kaz-maze-skin-%d.cfg"%OS.get_process_id()

func _initialize():
	create_timer(180).timeout.connect(func():printerr("KAZ_MAZE_TIMEOUT");quit(1))
	run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	print("PASS: " if ok else "FAIL: ",message)
	if not ok:failures+=1
func frames(n:int=4):
	for i in n:await process_frame
func capture(label_:String):
	if DisplayServer.get_name()=="headless":return
	await frames();RenderingServer.force_draw();await process_frame
	check(root.get_texture().get_image().save_png(OUT+label_+".png")==OK,"Captured "+label_)

func run():
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.make_dir_recursive_absolute(INVENTORY_OUT)
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,800)
	check(Roster.KAZI_ID in Roster.selection_ids() and Roster.MAZE_ID not in Roster.selection_ids(),"One Kaz card replaces separate Kaz/Maze roster entries")
	check(Roster.MAZE_ID in Roster.PLAYABLE_IDS and Roster.valid_loadout_key("36"),"Legacy Maze identities and saved loadouts remain valid")
	game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=config_path
	root.add_child(game);current_scene=game;await frames()
	AudioServer.set_bus_mute(0,true)
	game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
	game.set_process_input(false);game.set_process_unhandled_input(false)
	game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
	game.settings.spell_loadouts={"36":{"special_5":"kazi/ice"},"34:102488":{"special_5":"kazi/fire"}}
	game.settings.skin_equipment={"36":{"weapon":1,"primary_kunai":true}}
	game.settings.gear_loadouts={"character:36":{"1":"weapon:kunai"}}
	game.settings.cosmetic_loadouts={"character:36":{"qi_color":"qi-gold"}}
	game.save_settings()
	var saved=game.settings.duplicate(true)
	game.begin_arena();await frames()
	check(game.menu.find_child("RogueFighter_maze",true,false)==null,"Roster has no separate Maze card")
	await capture("roster")
	game.choose_rogue_character(Roster.KAZI_ID);await frames()
	var hub=game.equipment_hub
	var original=game.player.model
	var original_kit=game.player.active_ability
	var saved_hash=FileAccess.get_sha256(config_path)
	hub.portrait_button.open_gallery();await frames()
	check(hub.portrait_button.choices.item_count==Skins.CATALOG.size(),"Kaz's skin gallery includes every recovered appearance and Maze")
	await capture("kaz-skins")
	hub.portrait_button.select_skin(Skins.MAZE);await frames()
	check(hub.wearer_key=="character:36" and hub.portrait_button.character==Roster.KAZI_ID and hub.portrait_button.selected_id==Skins.MAZE,"Maze previews within Kaz's skin gallery")
	check(hub.portrait.texture.atlas==Skins.CATALOG[Skins.MAZE][1] and hub.party[0].icon==hub.portrait.texture,"Maze's original portrait appears in both equipment previews")
	check(hub.available_items().has("weapon:kunai") and hub.draft["character:36"]==saved.gear_loadouts["character:36"],"Maze's weapon contract and existing gear are retained")
	check(game.player.model==original and game.player.active_ability==original_kit and FileAccess.get_sha256(config_path)==saved_hash,"Skin browsing changes neither live combat nor saved settings")
	await capture("maze-equipment")
	game.back_from_equipment();await frames()
	check(game.settings.kaz_skin==Skins.DEFAULT and game.player.character_id==Roster.KAZI_ID and FileAccess.get_sha256(config_path)==saved_hash,"Back discards Maze's unsaved preview")
	game.choose_rogue_character(Roster.KAZI_ID);await frames();hub=game.equipment_hub
	hub.select_skin(Skins.MAZE)
	check(game.save_equipment_loadouts(hub.draft,hub.skill_draft,hub.cosmetic_draft,hub.appearance_draft,hub.spell_draft,hub.pet_skill_draft),"Maze's skin draft saves through the existing equipment boundary")
	var p=game.player
	check(p.character_id==Roster.MAZE_ID and p.model.appearance.id==Skins.MAZE and p.active_ability is MazeCombat,"Saving selects the original prepared Maze model and combat owner")
	check(p.model.daggers and p.model.current_weapon()=="kunai" and p.spell_loadout.spell_for(Roster.MAZE_ID,"special_5")=="kazi/ice","Maze restores saved kunai and skills")
	check(game.settings.spell_loadouts==saved.spell_loadouts and game.settings.skin_equipment==saved.skin_equipment and game.settings.gear_loadouts==saved.gear_loadouts and game.settings.cosmetic_loadouts==saved.cosmetic_loadouts,"Consolidation preserves both identities' saved gear, skills and cosmetics")
	game.forest_ui.sync_character()
	check(game.forest_ui.hero_name.text=="Kaz" and game.forest_ui.hero_portrait.texture==preload("res://scripts/forest/painted_heads.gd").portrait(Roster.MAZE_ID,game.settings),"HUD shows Kaz with Maze's original painted portrait")
	check(get_meta("forest_fighter")==Roster.MAZE_ID,"Session restore remembers the Maze appearance")
	game.back_from_equipment();await frames()
	var card=game.menu.find_child("RogueFighter_kazi",true,false)
	check(card.has_focus() and card.find_child("SelectionPortrait",true,false).texture.atlas==Skins.CATALOG[Skins.MAZE][1],"Returning focuses Kaz and shows his selected Maze appearance")
	game.choose_rogue_character(Roster.KAZI_ID);await frames()
	check(p.character_id==Roster.MAZE_ID,"Choosing Kaz again retains his Maze skin")
	game.back_from_equipment();await frames();game.rogue_pick_start=false;game.close_rogue_roster();await frames()
	var pool=Pool.service(game)
	pool.launched.connect(func(shot):shots.append(shot);shot.set_physics_process(false))
	var kit=p.active_ability
	var misses=pool.misses
	for i in 8:
		kit.cancel(true);p.attack_chain.reset();shots.clear()
		kit.start_attack();kit.tick(kit.throw_release-.001)
		check(shots.is_empty(),"Kunai %d waits for its original release marker"%i)
		kit.tick(.002)
		check(shots.size()==2,"Kunai %d releases its original pair"%i)
		for shot in shots:shot.retire()
		kit.cancel(true)
	check(pool.misses==misses,"Repeated Maze attacks reuse existing projectile leases")
	var maze_model=p.model;var maze_kit=p.active_ability
	game.clear_menu();game.forest_ui.close_overlay();game.forest_ui.show()
	game.playing=true;game.ordinary_pause=false;game.paused=false;paused=false
	game.camera_rig.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	game.camera_rig.camera.fov=45
	var dummy=preload("res://tests/forest-shrine/training_dummy_fixture.gd").install(game)
	dummy.set_physics_process(false)
	var hits:Array=[]
	game.impact_confirmed.connect(func(victim,_strength,_duration):
		if victim==dummy:hits.append(victim))
	for id in Skins.CATALOG:
		if id==Skins.MAZE:continue
		game.select_kaz_skin(id)
		check(p.character_id==Roster.KAZI_ID and p.model==original and p.active_ability==original_kit and p.model.appearance.id==id,"Kaz appearance %d reuses his original model/controller"%id)
		check(is_equal_approx(p.model.normal_attack_pattern().duration,.6),"Kaz appearance %d keeps its attack duration"%id)
		var model=p.model
		check(model.GUARD_ROW.has(id) and model.jump_guard_atlas!=null,"Kaz appearance %d has its original directional guard poses"%id)
		var camera=game.camera_rig.camera
		var right=Vector3(camera.global_basis.x.x,0,camera.global_basis.x.z).normalized()
		var back=Vector3(camera.global_basis.z.x,0,camera.global_basis.z.z).normalized()
		for direction in 8:
			var angle=(direction-1)*TAU/8
			p.facing=right*sin(angle)-back*cos(angle)
			for action in [0,1,3,5,6,8,9,10]:
				var pose=model.appearance.clips.get("%d:%d"%[action,direction],{})
				var count:int=pose.get("frames",[0]).size()
				for frame in count:
					model.show_frame(action,"%d:%d"%[action,direction],frame)
					check(model.sprite.texture!=null and model.sprite.region_rect.has_area(),"Kaz %d action %d facing %d frame %d draws prepared art"%[id,action,direction,frame])
		p.position=Vector3(0,game.model.world_height(0,60)+.1,60)
		p.facing=Vector3.FORWARD;p.invuln=0;p.impact_pause=0
		dummy.position=p.position+Vector3.FORWARD*2;dummy.home=dummy.position
		dummy.show()
		for repeat in 3:
			p.active_ability.cancel(true);p.attack_chain.reset();hits.clear()
			p.active_ability.start_attack();p.active_ability.tick(1)
			check(hits.size()==2,"Kaz %d repeated attack %d keeps two exact shared contacts"%[id,repeat])
		var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p,0)
		for i in 5:
			check(mirrors.reinforce(Roster.KAZI_ID,dummy.position+Vector3.BACK.rotated(Vector3.UP,i*TAU/5)*2),"Kaz %d native copy %d allocates"%[id,i])
			var body=mirrors.bodies[i]
			check(body.model.kaz_skin==id and body.model.atlases[0]==model.atlases[0],"Kaz %d copy %d shares the selected atlas"%[id,i])
			body.perform(0,dummy.position)
		hits.clear()
		for tick in 50:
			for body in mirrors.bodies:body.step(1.0/60,{"position":body.position,"hp":body.max_hp,"yaw":0.0,"pose_velocity":Vector3.ZERO})
		check(hits.size()==10 and mirrors.bodies.all(func(body):return not body.has_offensive_action()),"Kaz %d five native copies finish both contacts (hits=%d, busy=%s)"%[id,hits.size(),str(mirrors.bodies.map(func(body):return body.has_offensive_action()))])
		mirrors.dispose();await frames()
		if DisplayServer.get_name()!="headless":
			dummy.hide();game.crowd.army.presentation.tick(2)
			camera.global_position=p.position+Vector3(0,4,13);camera.look_at(p.position+Vector3.UP*2.3)
			p.facing=Vector3.BACK
			for action in [0,3,5]:
				model.show_pose(action,.3,true)
				await frames();RenderingServer.force_draw();await process_frame
				check(root.get_texture().get_image().save_png(INVENTORY_OUT+"%d-%d.png"%[id,action])==OK,"Captured Kaz %d action %d"%[id,action])
	game.select_kaz_skin(Skins.MAZE)
	check(p.model==maze_model and p.active_ability==maze_kit and p.model.daggers,"Switching back reuses Maze's prepared model, controller and saved weapon")
	var loadout=preload("res://scripts/spells/spell_picker.gd").new();loadout.game=game;game.ui.add_child(loadout);await frames()
	check(loadout.fighter.get_selected_id()==Roster.KAZI_ID and loadout.fighter.get_item_index(Roster.MAZE_ID)==-1 and loadout.skin_picker.selected_id==Skins.MAZE,"Shared loadout has one Kaz entry and selects his Maze skin")
	check(loadout.selected_character()==Roster.MAZE_ID and loadout.active_weapon.item_count==3,"Shared loadout edits Maze's saved stance through the Kaz entry")
	loadout.queue_free();await frames()
	game.load_settings()
	check(game.settings.kaz_skin==Skins.MAZE and p.character_id==Roster.MAZE_ID and p.model.daggers,"Reload retains the selected skin and weapon")
	var path=game.settings_path
	current_scene=null;game.queue_free();paused=false;await frames()
	# An old in-session Maze ID must also remain restorable.
	set_meta("forest_fighter",Roster.MAZE_ID)
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=path
	root.add_child(game);current_scene=game;await frames()
	check(game.player.character_id==Roster.MAZE_ID and game.settings.kaz_skin==Skins.MAZE,"An existing Maze session restores under Kaz's skin choice")
	current_scene=null;game.queue_free();paused=false;await frames()
	remove_meta("forest_fighter");DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("KAZ_MAZE_SKIN_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
