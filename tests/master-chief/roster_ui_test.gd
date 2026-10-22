extends SceneTree
## Exercise the real picker, session restoration, and exclusive FPS HUD.
const Roster=preload("res://scripts/rogue_roster.gd")
const Balance=preload("res://scripts/character_balance.gd")
var game
var failures=0
var checks=0
func _initialize():
	create_timer(90).timeout.connect(func():printerr("FAIL: Chief roster timeout");quit(1))
	run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func settle():
	for frame in range(6):await process_frame
func new_game():
	var scene=load("res://scenes/forest_shrine.tscn").instantiate()
	scene.settings_path="user://master-chief-roster-test.cfg"
	root.add_child(scene);current_scene=scene
	return scene
func run():
	root.size=Vector2i(1280,800)
	set_meta("forest_fighter",1)
	game=new_game();await settle()
	AudioServer.set_bus_mute(0,true)
	game.show_rogue_roster();await settle()
	var card=game.menu.find_child("RogueFighter_master-chief",true,false)
	check(card is Button,"Q gallery offers a named Master Chief card")
	if card==null:
		await finish()
		return
	check(card.find_child("SelectionPortrait",true,false).texture!=null,"Chief card contains his selection portrait")
	card.pressed.emit();await settle()
	check(game.player.character_id==18 and game.selected_rogue_id==18,"Chief card selects the playable fighter")
	check(not game.rogue_roster_open and game.model.phase=="preparing","Selection returns to preparation")
	check(game.forest_ui.hero_name.text=="Master Chief","Preparation HUD names the selected Chief")
	check(game.forest_ui.hero_portrait.texture!=null,"Chief has an HUD portrait")
	check(Balance.load_profiles({"master-chief":{"max_hp":240}}).get("master-chief",{}).get("max_hp")==240.0,"Chief balance overrides load independently")
	check(SoundLibrary.slots_for(18).has("chief_rifle"),"Sound studio exposes the Assault Rifle sound")
	check(SoundLibrary.moves_for(18).has("rifle"),"Rifle uses the shared editable move audio")
	for slot in [1,2,3,4,5]:
		var spec=preload("res://scripts/master_chief_weapons.gd").data(slot)
		check(SoundLibrary.slots_for(18).has("chief_"+preload("res://scripts/master_chief_weapons.gd").audio_key(slot)) and SoundLibrary.original_for(18,"chief_"+preload("res://scripts/master_chief_weapons.gd").audio_key(slot))!=null,"Sound studio exposes recovered "+spec.label+" audio")
		game.forest_ui.select_loadout_slot(slot-1)
		check(game.player.master_chief_combat.weapon_slot==slot,"Preparation row selects Chief weapon %d"%slot)
	game.forest_ui.select_loadout_slot(3)
	var assignments=game.gate_defenders.assignments.duplicate(true)
	for gate in game.gate_defenders.gates():
		game.gate_defenders.assign(gate.id,18)
		break
	check(game.gate_defenders.assignments==assignments,"Unsupported Chief AI cannot replace a gate defender")
	game.start_wave();game.model.waves.spawn_clock=10000;await settle()
	var chief_hud=game.forest_ui.get_node_or_null("MasterChiefHUD")
	check(chief_hud!=null and chief_hud.visible,"Chief receives the dedicated live FPS HUD")
	if chief_hud!=null:
		var ammo=chief_hud.find_child("ChiefAmmo",true,false)
		check(ammo!=null and "∞" in ammo.text,"Chief HUD communicates unlimited ammunition")
	check(chief_hud.title.text=="ASSAULT RIFLE","Chief HUD names the selected weapon")
	check(not game.forest_ui.crosshair_visible(),"Chief owns one crosshair instead of overlapping the generic reticle")
	game.show_rogue_roster();await settle()
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Chief Q menu releases the cursor")
	check(chief_hud==null or not chief_hud.is_visible_in_tree(),"Chief HUD hides behind the gallery")
	var selected_card=game.menu.find_child("RogueFighter_master-chief",true,false)
	var gallery_scroll=game.menu.find_child("RosterScroll",true,false)
	var card_labels=selected_card.get_child(0).get_children().filter(func(child):return child is Label)
	check(card_labels.all(func(label):return gallery_scroll.get_global_rect().encloses(label.get_global_rect())),"Opening Q reveals the selected Chief name and controls")
	game.choose_rogue_character(17);await settle()
	check(game.player.character_id==17 and game.forest_ui.hero_name.text=="Yae","Choosing an existing fighter restores their normal HUD")
	check(game.forest_ui.crosshair_visible(),"Existing fighters retain the normal crosshair")
	check(chief_hud==null or not chief_hud.visible,"Chief ammo does not leak into other fighters")
	game.show_rogue_roster();game.choose_rogue_character(18);await settle()
	game.show_pause();await settle()
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Chief pause releases the cursor")
	check(chief_hud==null or not chief_hud.visible,"Chief HUD hides while paused")
	game.resume();await settle()
	check(chief_hud!=null and chief_hud.visible,"Resume restores Chief's HUD")
	check(DisplayServer.get_name()=="headless" or Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Resume captures the FPS cursor")
	game.queue_free();paused=false;await settle()
	game=new_game();await settle()
	check(game.player.character_id==18 and game.selected_rogue_id==18,"Scene restart restores Chief selection from the session")
	check(game.model.phase=="preparing" and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Restart restores preparation controls")
	await finish()
func finish():
	if is_instance_valid(game):game.queue_free()
	paused=false;await settle()
	remove_meta("forest_fighter")
	print("MASTER_CHIEF_ROSTER_UI checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
