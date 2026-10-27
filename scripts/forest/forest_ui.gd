extends Control
signal loadout_slot_selected(index: int)
var game
var reticle: Control
var master_chief_hud:Control
var hint: Label
var health: Label
var hero_name: Label
var hero_dock: Panel
var enemy_minimap
var resource_hub: Panel
var view_settings_preview=false
var applied_hud_scale=-1.0
var hero_portrait: TextureRect
var loadout_slots: HBoxContainer
var loadout_buttons: Array[Button]=[]
var cape_buttons:Array[Button]=[]
var spell_summary:Label
var spell_dock:PanelContainer
var selected_loadout_slot=-1
var guard_shop:Control
var guard_shop_button:Button
var preparation_mode=""
var build_menu_expanded=false
var preparation_tools_open=false
var preparation_header:HBoxContainer
var map_size_controls:HBoxContainer
var map_size_label:Label
var smaller_map_button:Button
var bigger_map_button:Button
var start_wave_button:Button
var build_menu_button:Button
var build_buttons:Dictionary={}
const PreparationSkin=preload("res://scripts/forest/preparation_skin.gd")
const MERCENARY_SHORTCUTS=[2,0,1,4,3] # Ninja, Dragoon, Ranger, Explorer, Knight.
var helper_portraits: Array[TextureRect]=[]
var player_health_bar: ProgressBar
var health_trail: ProgressBar
var health_gloss: ColorRect
var health_styles: Array[StyleBoxFlat]=[]
var last_health=-1.0
var last_health_max=-1.0
var last_health_fighter=-1
var health_level=-1
var health_trail_hold=0.0
var cooldown_masks: Array[TextureProgressBar]=[]
var cooldown_peaks=[0.0,0.0]
var attack_colors: Array[Color]=[Color.WHITE,Color.WHITE]
var class_cooldowns: Dictionary={}
var skin=preload("res://scripts/forest/forest_hud_skin.gd").new()
var primary_icon: TextureRect
var secondary_icon: TextureRect
var ben_utility_tile: Panel
var leader_utility_icon: TextureRect
var musashi_charge_label:Label
var attack_cooldowns: Array[Label]=[]
var ryo_caption: Label
var gold_count: Label
var worker_count: Label
var portrait_id=-1
var hud_icons=preload("res://scripts/forest/forest_hud_icons.gd").new()
const Roster=preload("res://scripts/rogue_roster.gd")
var shrine_health_dock: PanelContainer
var shrine_health_label: Label
var shrine_health_bar: ProgressBar
var team_level_label:Label
var team_xp_bar:ProgressBar
var painterly_button: Button
var preparation_actions: HFlowContainer
var build_bar: HBoxContainer
var bar_paper: Panel
var inspection: PanelContainer
var inspect_text: Label
var overlay: PanelContainer
var respawn_notice:Label
var selected_id=-1
var message=""
var message_left=0.0
var preview_clock=0.0
var job_preview={"mine":0,"tower":0,"repair":0,"idle":0}
const INK=Color("f0edf4")
const PAPER=Color("f0edf4")
const LABELS={"mine":"Gold mine","tower":"Stone watchtower","wall":"Stone wall","gate":"Gate","barracks":"Barracks","enemy_castle":"Enemy castle · Free"}
func style(color: Color,border: Color=Color("827859"))->StyleBoxFlat:
	var s=StyleBoxFlat.new();s.bg_color=color;s.border_color=border
	s.set_border_width_all(2);s.set_corner_radius_all(3);s.content_margin_left=14;s.content_margin_right=14;s.content_margin_top=10;s.content_margin_bottom=10
	return s
func label_at(text_: String,pos: Vector2,size_: int)->Label:
	var l=Label.new();l.text=text_;l.position=pos;l.add_theme_font_size_override("font_size",size_);l.add_theme_color_override("font_color",PAPER);add_child(l);return l
func dock_label(parent: Node,text_: String,pos: Vector2,font_size: int)->Label:
	var l=label_at(text_,pos,font_size);remove_child(l);parent.add_child(l);l.mouse_filter=Control.MOUSE_FILTER_IGNORE;return l
func dock_icon(parent: Node,texture: Texture2D,pos: Vector2,dimensions: Vector2)->TextureRect:
	var view=TextureRect.new();view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;view.texture=texture;view.position=pos;view.size=dimensions
	view.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;view.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(view);return view
func panel(name_: String,preset: int,rect: Rect2)->Panel:
	var p=Panel.new();p.name=name_;p.mouse_filter=Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel",skin.lacquer());add_child(p)
	p.set_anchors_and_offsets_preset(preset);p.offset_left=rect.position.x;p.offset_top=rect.position.y;p.offset_right=rect.end.x;p.offset_bottom=rect.end.y;return p
func meter(parent: Node,name_: String,color: Color)->ProgressBar:
	var bar=ProgressBar.new();bar.name=name_;bar.show_percentage=false;bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var background=StyleBoxFlat.new();background.bg_color=Color("210c1b");background.set_corner_radius_all(3)
	var fill=StyleBoxFlat.new();fill.bg_color=color;fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background",background);bar.add_theme_stylebox_override("fill",fill);parent.add_child(bar);return bar
func make_status_hubs():
	var supplies=panel("ResourceHub",Control.PRESET_TOP_RIGHT,Rect2(-370,20,348,68))
	resource_hub=supplies
	supplies.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	for i in range(2):
		var badge=Panel.new();badge.name="GoldBadge" if i==0 else "WorkerBadge";badge.mouse_filter=Control.MOUSE_FILTER_IGNORE;badge.position=Vector2(0 if i==0 else 232,0);badge.size=Vector2(224 if i==0 else 116,68)
		badge.add_theme_stylebox_override("panel",skin.lacquer());supplies.add_child(badge)
		var portrait=dock_icon(badge,preload("res://assets/ui/rom_weapons/goemon_ryo.png") if i==0 else hud_icons.get_icon("worker"),Vector2(13,14) if i==0 else Vector2(4,10),Vector2(39,39) if i==0 else Vector2(57,48))
		if i==0:portrait.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		if i==1:portrait.name="WorkerPortrait";portrait.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		var count=dock_label(badge,"",Vector2(61,20),24)
		if i==0:
			gold_count=count;count.name="GoldCount";count.position.y=19;count.add_theme_color_override("font_color",PAPER)
			ryo_caption=dock_label(badge,"",Vector2(61,45),10)
		else:
			worker_count=count;count.name="WorkerCount";count.position.y=19
	gold_count.tooltip_text="Ryo · Enemy kills pay automatically · Workers spend 1 ryo per 10 HP repaired";worker_count.tooltip_text="Workers"
	make_hero_dock()
func make_hero_dock():
	hero_dock=panel("HeroDock",Control.PRESET_TOP_LEFT,Rect2(22,28,250,84))
	dock_icon(hero_dock,skin.texture("ring"),Vector2(140,-8),Vector2(100,100))
	hero_portrait=dock_icon(hero_dock,null,Vector2(149,1),Vector2(82,82));hero_portrait.name="HeroPortrait"
	hero_portrait.stretch_mode=TextureRect.STRETCH_SCALE
	var portrait_material=ShaderMaterial.new();portrait_material.shader=preload("res://scripts/forest/forest_hud_portrait.gdshader");hero_portrait.material=portrait_material
	hero_name=dock_label(hero_dock,"",Vector2(14,12),16);hero_name.size.x=125;hero_name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	for color in [Color("81c7a0"),Color("e2b564"),Color("ed8778")]:
		var fill=StyleBoxFlat.new();fill.bg_color=color;fill.set_corner_radius_all(6);health_styles.append(fill)
	health_trail=meter(hero_dock,"HealthTrail",Color("e8d9ab"));health_trail.position=Vector2(14,39);health_trail.size=Vector2(125,13)
	player_health_bar=meter(hero_dock,"PlayerHealthBar",health_styles[0].bg_color);player_health_bar.position=health_trail.position;player_health_bar.size=health_trail.size
	player_health_bar.add_theme_stylebox_override("background",StyleBoxEmpty.new())
	health_gloss=ColorRect.new();health_gloss.color=Color(1,1,1,.17);health_gloss.position=Vector2(17,41);health_gloss.size=Vector2(119,2);health_gloss.mouse_filter=Control.MOUSE_FILTER_IGNORE;hero_dock.add_child(health_gloss)
	health=dock_label(hero_dock,"",Vector2(14,58),12);health.add_theme_color_override("font_color",Color("d2ddc7"))
	for i in range(2):
		var tile=Panel.new();tile.position=Vector2(256+i*58,10);tile.size=Vector2(52,64);tile.mouse_filter=Control.MOUSE_FILTER_IGNORE
		tile.add_theme_stylebox_override("panel",skin.attack_style());hero_dock.add_child(tile)
		var attack=dock_icon(tile,null,Vector2(9,5),Vector2(34,34))
		if i==0:primary_icon=attack
		else:secondary_icon=attack
		var mask=TextureProgressBar.new();mask.mouse_filter=Control.MOUSE_FILTER_IGNORE;mask.position=Vector2(2,-2);mask.texture_progress=skin.texture("cooldown");mask.scale=Vector2.ONE*(2.0/3.0)
		mask.fill_mode=TextureProgressBar.FILL_CLOCKWISE;tile.add_child(mask);cooldown_masks.append(mask)
		var timer=dock_label(tile,"",Vector2(0,13),14);timer.size.x=52;timer.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		timer.add_theme_color_override("font_shadow_color",Color.BLACK);timer.add_theme_constant_override("shadow_outline_size",4);attack_cooldowns.append(timer)
		tile.hide()
	ben_utility_tile=Panel.new();ben_utility_tile.name="BenShurikenAction";ben_utility_tile.position=Vector2(254,10);ben_utility_tile.size=Vector2(52,64)
	ben_utility_tile.add_theme_stylebox_override("panel",skin.attack_style());hero_dock.add_child(ben_utility_tile)
	ben_utility_tile.tooltip_text="Tap E · Star fan / Hold E · Axes"
	leader_utility_icon=dock_icon(ben_utility_tile,load(Roster.icon_path("shuriken")),Vector2(9,5),Vector2(34,34))
	var ben_key=dock_label(ben_utility_tile,"E",Vector2(0,42),16);ben_key.size.x=52;ben_key.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	musashi_charge_label=dock_label(ben_utility_tile,"",Vector2(0,13),14);musashi_charge_label.size.x=52;musashi_charge_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	musashi_charge_label.add_theme_color_override("font_shadow_color",Color.BLACK);musashi_charge_label.add_theme_constant_override("shadow_outline_size",5)
	ben_utility_tile.hide()
	loadout_slots=HBoxContainer.new();loadout_slots.name="LoadoutSlots";loadout_slots.position=Vector2(49,98);loadout_slots.add_theme_constant_override("separation",8);hero_dock.add_child(loadout_slots)
	for i in range(5):
		var button=Button.new();button.name="LoadoutSlot%d"%(i+1);button.text=str(i+1);button.custom_minimum_size=Vector2(50,46)
		button.toggle_mode=true;button.focus_mode=Control.FOCUS_NONE;button.mouse_filter=Control.MOUSE_FILTER_STOP
		button.tooltip_text="Loadout slot %d · Empty"%(i+1);button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		PreparationSkin.apply_button(button);button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.add_theme_font_size_override("font_size",12)
		for state in ["normal","hover","pressed","hover_pressed"]:
			var box=StyleBoxFlat.new();box.set_corner_radius_all(6);box.set_border_width_all(2 if state in ["pressed","hover_pressed"] else 1)
			box.bg_color=Color("d8b7c8") if state in ["pressed","hover_pressed"] else Color("d2d5df")
			box.border_color=Color("fff1f9") if state!="normal" else Color("8d8290")
			box.content_margin_left=7;box.content_margin_right=7;box.content_margin_top=5;box.content_margin_bottom=23
			button.add_theme_stylebox_override(state,box)
			button.add_theme_color_override("font_"+state+"_color" if state!="normal" else "font_color",PreparationSkin.INK)
		button.button_down.connect(func():select_loadout_slot(i,true))
		button.button_up.connect(func():game.player.spell_loadout.number_input(i+1,false))
		loadout_slots.add_child(button);loadout_buttons.append(button)
		var portrait=TextureRect.new();portrait.name="HelperPortrait";portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;portrait.position=Vector2(17,11);portrait.size=Vector2(28,28);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_SCALE;portrait.material=hero_portrait.material;portrait.hide();button.add_child(portrait);helper_portraits.append(portrait)
	spell_dock=PanelContainer.new();spell_dock.name="SpellDock";spell_dock.position=Vector2(0,153);spell_dock.size.x=380
	spell_dock.add_theme_stylebox_override("panel",skin.lacquer());hero_dock.add_child(spell_dock)
	spell_summary=Label.new();spell_summary.name="EquippedSpells";spell_summary.add_theme_font_size_override("font_size",13);spell_summary.add_theme_color_override("font_color",PAPER);spell_dock.add_child(spell_summary)
	for gold in [false,true]:
		var button=Button.new();button.name="CapeGold" if gold else "CapeRed";button.text="X\nGOLD" if gold else "Z\nRED"
		button.position=Vector2(336 if gold else 0,98);button.size=Vector2(44,46);button.toggle_mode=true;button.focus_mode=Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size",10)
		PreparationSkin.apply_button(button);button.add_theme_font_size_override("font_size",10)
		button.tooltip_text="X · Gold cape · Hold Space to ascend, release to descend · Shift boosts · Press X again to remove" if gold else "Z · Red cape · 3× movement and four jumps · Press Z again to remove"
		button.pressed.connect(func():game.toggle_player_cape(gold));hero_dock.add_child(button);cape_buttons.append(button)
func goemon_weapon_icon(slot:int)->Texture2D:
	const icons = [preload("res://assets/ui/rom_weapons/goemon_gold_pipe.png"), preload("res://assets/ui/rom_weapons/goemon_ryo.png"), preload("res://assets/ui/rom_weapons/goemon_chain_pipe.png")]
	if slot==2 and game.player.surge_left>0:return preload("res://assets/ui/rom_weapons/goemon_flaming_ryo.png")
	return icons[clampi(slot-1,0,2)]
func select_loadout_slot(index: int,hold:bool=false):
	if index<0 or index>=loadout_buttons.size() or not is_visible_in_tree() or not game.playing or game.ordinary_pause or game.settings_open or game.rogue_roster_open or is_instance_valid(overlay) or guard_shop_open() or game.model.phase not in ["preparing","wave"]:return
	if is_instance_valid(game.map_editor) and game.map_editor.active:return
	game.player.spell_loadout.number_input(index+1,true)
	if not hold:game.player.spell_loadout.number_input(index+1,false)
	sync_character()

func close_preparation_menu():
	preparation_mode="";build_menu_expanded=false;preparation_tools_open=false
	game.explorer_helpers.cancel_placement()
	game.build_kind="";game.wall_start=Vector2i(-999,-999);game.world.preview.hide()
	sync()
func open_build_menu():
	if not game.explorer_helpers.available():return
	if preparation_mode=="build" and build_menu_expanded:return
	game.explorer_helpers.cancel_placement()
	game.build_kind="";game.wall_start=Vector2i(-999,-999);game.world.preview.hide()
	preparation_mode="build";build_menu_expanded=true;preparation_tools_open=false;selected_id=-1;sync()
func choose_preparation_build(kind:String):
	game.select_build(kind);preparation_mode="build";build_menu_expanded=true;sync()
func preparation_menu_input(event:InputEvent)->bool:
	if not event is InputEventKey or event.shift_pressed or event.ctrl_pressed or event.alt_pressed or event.meta_pressed:return false
	if not is_instance_valid(game) or not is_instance_valid(game.explorer_helpers) or not is_visible_in_tree() or not game.explorer_helpers.available() or is_instance_valid(overlay):return false
	var focus=get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:return false
	var code=event.physical_keycode if event.physical_keycode!=0 else event.keycode
	if code==KEY_ESCAPE:
		if preparation_mode.is_empty() and not preparation_tools_open and game.build_kind.is_empty() and not game.explorer_helpers.placement_active() and not guard_shop_open():return false
		if event.pressed and not event.echo:close_preparation_menu()
		return true
	if code in [KEY_B,KEY_M]:
		if event.pressed and not event.echo:
			if code==KEY_B:open_build_menu()
			else:show_guard_shop()
		return true
	if code>=KEY_1 and code<=KEY_9 and not preparation_mode.is_empty():
		if event.pressed and not event.echo:
			var index=code-KEY_1
			if preparation_mode=="build":
				if index<2:choose_preparation_build(["tower","barracks"][index])
				elif index==2:game.recruit_worker()
				elif index==3 and game.model.has_enemy_castles():choose_preparation_build("enemy_castle")
			elif preparation_mode=="mercenaries" and index<MERCENARY_SHORTCUTS.size():game.explorer_helpers.request(MERCENARY_SHORTCUTS[index])
		return true
	return false
func _input(event):
	if preparation_menu_input(event):get_viewport().set_input_as_handled();return
	if not is_instance_valid(game) or game.model==null or game.model.phase not in ["preparing","wave"]:return
	if not is_visible_in_tree() or (game.paused and game.model.phase!="preparing") or game.ordinary_pause or game.settings_open or game.rogue_roster_open or is_instance_valid(overlay) or guard_shop_open():return
	if is_instance_valid(game.map_editor) and game.map_editor.active:return
	var focus=get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:return
	if game.player.spell_loadout.number_event(event):get_viewport().set_input_as_handled()

func sync_character():
	var p=game.player
	var spells=PackedStringArray()
	var equipped=p.spell_loadout.assignments(p.character_id)
	for i in p.spell_loadout.numbered_slots.size():
		var slot:Array=p.spell_loadout.numbered_slots[i]
		var action=p.spell_loadout.Catalog.SLOTS.keys()[i]
		var cooldown=p.spell_loadout.cooldown_for(action) if equipped.has(action) else 0.0
		spells.append("%d  %s%s"%[i+1,"Empty · Equip in Skills & Jump" if slot.is_empty() else slot[0]," (%.1fs)"%cooldown if cooldown>.05 else ""])
	if p.character_id==13:spells.append("E Hold charge · R Hold guard · More skills in Q")
	if p.character_id==30:spells.append("LMB Kojiro Wind → 2 piercing blades · Space Fly · Shift Boost")
	if p.character_id==32 and p.can_fly():spells.append("Hold Space Fly · Release Descend · Shift Boost")
	if p.is_meta_shooter():spells.append("Mouse Aim · Hold LMB Energy bolts · WASD Strafe")
	spell_summary.text="\n".join(spells);spell_dock.visible=true
	if portrait_id!=p.character_id:
		portrait_id=p.character_id
		ben_utility_tile.visible=p.character_id in [13,14,15,16,17];hero_dock.size.x=320 if p.character_id in [13,14,15,16,17] else 250
		ben_utility_tile.tooltip_text="Hold E · Sword Shield" if p.character_id==17 else "E · Ice kunai / Hold for Hail Beam · T / Shift+T Hair · R Super Jump" if p.character_id==16 else ("E · Smoke assault · R · Quick Burst" if p.character_id==14 else "Tap E · Star fan / Hold E · Axes")
		leader_utility_icon.texture=load(Roster.icon_path("ice" if p.character_id==16 else ("fire" if p.character_id==14 else "shuriken")))
		if p.character_id==13:
			ben_utility_tile.tooltip_text="1 Rotation · 2 Mighty Strike · 3 D-Kick · 4 Grenade · Hold 5 3-Way · More in Skills & Jump"
			leader_utility_icon.texture=load(Roster.icon_path("sword"))
		var primary="pipe";var secondary="wave";var accent=Color("edcf87");class_cooldowns={};cooldown_peaks=[0.0,0.0]
		if p.is_rogue_character():
			var data=Roster.data(p.character_id);hero_name.text=data.name;accent=Color(data.color);class_cooldowns=data.cooldowns
			hero_portrait.texture=Roster.portrait(p.character_id);primary=data.abilities.cutlass.icon;secondary=data.abilities.flintlock.icon
			primary_icon.tooltip_text=data.abilities.cutlass.name;secondary_icon.tooltip_text=data.abilities.flintlock.name
		else:
			hero_name.text="Edo" if p.character_id==2 else "Goemon"
			if (p.character_id in [13,14,15,16,17,18,19,28,31,32] or Roster.is_enemy(p.character_id)):hero_name.text=Roster.name_for(p.character_id)
			hero_portrait.texture=Roster.portrait(p.character_id) if (p.character_id in [13,14,15,16,17,18,19,28,31,32] or Roster.is_enemy(p.character_id)) else load("res://assets/models/characters/goemon_cosplay/portraits/%s.png"%hero_name.text.to_lower())
			if p.character_id==2:primary="fire";secondary="spark";accent=Color("ff956f")
			primary_icon.tooltip_text="Fireballs" if p.character_id==2 else "Pipe combo";secondary_icon.tooltip_text="Giant fireball" if p.character_id==2 else "Heavy strike"
			if p.character_id==13:
				primary="sword";secondary="sword";accent=Color("bba4f2")
				primary_icon.tooltip_text="LMB · Fusion · Click for each cut";secondary_icon.tooltip_text="RMB · Lumina · Standing / airborne strike"
			if p.character_id in [31,32]:
				primary="sword";secondary="spark";accent=Color(Roster.data(p.character_id).color)
				primary_icon.tooltip_text="Sword combo" if p.character_id==31 else "Glaive combo / Demon bolt"
				secondary_icon.tooltip_text="Critical strike" if p.character_id==31 else "Metamorphosis"
			if p.character_id==28:
				primary="sword";secondary="wave";accent=Color("d999e6")
				primary_icon.tooltip_text="LMB · Cut → Return cut / Aerial cuts";secondary_icon.tooltip_text="RMB / T · Sword wave"
			if p.character_id==30:
				primary="wave";secondary="wave";accent=Color("9680ed")
				primary_icon.tooltip_text="LMB · Kojiro’s Wind wave → Two flying energy blades · All pierce enemies · Click for each or buffer the next cut";secondary_icon.tooltip_text=""
			if p.character_id==17:
				primary="sword";secondary="fire";accent=Color("b4e4c3")
				primary_icon.tooltip_text="LMB · Tier 3 gold katana combo";secondary_icon.tooltip_text="RMB · Bazooka / Hold and release · Lock-on shot"
			if p.character_id==16:
				primary="sword";secondary="fire";accent=Color("d7d4ac")
				primary_icon.tooltip_text="LMB · Gold kunai combo";secondary_icon.tooltip_text="RMB · Firecracker bomb"
			if p.character_id in [14,15]:
				primary="fire" if p.character_id==14 else "sword";secondary="fire";accent=Color("ec947a" if p.character_id==14 else "bad17c")
				primary_icon.tooltip_text="Hold LMB · Sustained piercing beam" if p.character_id==14 else "LMB · Slash · Click again to lunge";secondary_icon.tooltip_text="Bouncing fireballs" if p.character_id==14 else "Hold RMB · Blue bomb barrage"
			if Roster.is_enemy(p.character_id) and p.character_id!=30:
				primary="flintlock" if p.character_id==21 else "sword";secondary=primary
				primary_icon.tooltip_text=Roster.data(p.character_id).description;secondary_icon.tooltip_text=primary_icon.tooltip_text
			if p.character_id==Roster.SONIC_ID:
				primary="spark";secondary="wave";accent=Color("559dff")
				primary_icon.tooltip_text="Space / LMB · Jump / Aerial Homing Attack";secondary_icon.tooltip_text="Hold RMB / E and release · Spin Dash"
			if p.character_id==Roster.MASTER_CHIEF_ID:
				primary="flintlock";secondary="flintlock";accent=Color("a6d9b4")
				primary_icon.tooltip_text="Hold LMB · Fire · 1 Rocket launcher · 2 Pistol · 3 Shotgun · 4 Assault rifle · Infinite ammunition";secondary_icon.tooltip_text="Mouse · Aim"
		primary_icon.texture=load(Roster.icon_path(primary));secondary_icon.texture=load(Roster.icon_path(secondary))
		secondary_icon.get_parent().hide()
		attack_colors=[Color("f2d39a").lerp(accent,.35),Color("a7d9cc").lerp(accent,.25)]
		hero_name.add_theme_color_override("font_color",PAPER)
	primary_icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST if p.character_id in [1,16,17] else CanvasItem.TEXTURE_FILTER_LINEAR
	secondary_icon.texture_filter=primary_icon.texture_filter
	leader_utility_icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST if p.character_id==16 else CanvasItem.TEXTURE_FILTER_LINEAR
	if p.character_id==16:
		primary_icon.texture=preload("res://assets/ui/rom_weapons/sasuke_kunai_iii.png")
		secondary_icon.texture=preload("res://assets/ui/rom_weapons/sasuke_cracker_bomb.png")
		leader_utility_icon.texture=preload("res://assets/ui/rom_weapons/sasuke_ice_kunai.png")
	if p.character_id==17:
		primary_icon.texture=preload("res://assets/ui/rom_weapons/yae_katana_iii.png")
		secondary_icon.texture=preload("res://assets/ui/rom_weapons/yae_bazooka.png")
		leader_utility_icon.texture=preload("res://assets/characters/recovered_yae/icons/shield_icon.png")
	if p.character_id==Roster.MASTER_CHIEF_ID:
		primary_icon.texture=load(preload("res://scripts/master_chief_weapons.gd").icon_path(p.master_chief_combat.weapon_slot))
	(hero_portrait.material as ShaderMaterial).set_shader_parameter("face_crop",Vector4(0,0,1,1) if (p.character_id in [16,17,18,19,28,31,32] or Roster.is_enemy(p.character_id)) else Vector4(.3375,.20,.325,.52))
	if p.character_id==1:
		primary_icon.texture=goemon_weapon_icon(p.weapon_slot);secondary_icon.texture=primary_icon.texture
		primary_icon.tooltip_text=["Gold pipe · Three-hit combo","Flaming ryo · Throw immediately" if p.surge_left>0 else "Ryo · Throw","Chain pipe · Throw, then move your aim to swing"][clampi(p.weapon_slot-1,0,2)]
		secondary_icon.tooltip_text=["Gold pipe · Heavy strike","Flaming ryo · Throw immediately" if p.surge_left>0 else "Ryo · Throw","Chain pipe · Swing while extended, then return"][clampi(p.weapon_slot-1,0,2)]
	if p.character_id==8:
		primary_icon.tooltip_text="Dragon Leap" if not p.is_on_floor() else "Lance Pierce"
		secondary_icon.tooltip_text="Dragon Leap" if not p.is_on_floor() else "Azure Lance Sweep"
	if p.is_meta_shooter():primary_icon.tooltip_text="Mouse · Aim · Hold LMB · Energy bolts · WASD · Strafe"
	if p.spell_loadout.assignments(p.character_id).has("equip"):
		var spec=p.spell_loadout.Catalog.all()[p.spell_loadout.spell_for(p.character_id,"equip")]
		ben_utility_tile.show();hero_dock.size.x=320
		ben_utility_tile.tooltip_text="E · "+spec.name
		leader_utility_icon.texture=load(Roster.icon_path(str(spec.get("icon","spark"))))
	ben_utility_tile.visible=p.character_id==13 and p.active_ability.guarding()
	sync_health()
	musashi_charge_label.text=""
	if p.character_id==13 and p.active_ability.guarding():
		musashi_charge_label.text="READY" if p.active_ability.charge_fraction()>=1 else "%d%%"%roundi(p.active_ability.charge_fraction()*100)
	var sustained=(p.character_id==2 and p.active_ability.beam_held) or (p.character_id==14 and p.active_ability.mode=="beam")
	for i in range(2):
		var remaining=0.0;var duration=0.0
		if p.is_rogue_character():
			var key="cutlass" if i==0 else "flintlock"
			remaining=p.active_ability.player.cooldowns.get(key,0.0);duration=class_cooldowns.get(key,0.0)
			if p.character_id==8 and not p.is_on_floor():remaining=0.0
		elif not sustained:
			# Both native main attacks share the current action's recovery timer.
			remaining=maxf(0,p.attack_left);duration=p.attack_duration
		cooldown_peaks[i]=maxf(cooldown_peaks[i],maxf(duration,remaining)) if remaining>.05 else 0.0
		cooldown_masks[i].visible=remaining>.05;cooldown_masks[i].value=100*remaining/maxf(.001,cooldown_peaks[i])
		attack_cooldowns[i].text="%.1f"%remaining if remaining>.05 else ""
		var tint=attack_colors[i];tint.a=.4 if remaining>.05 else 1.0
		if sustained and i==0:tint=Color("ffe4a5")
		(primary_icon if i==0 else secondary_icon).modulate=tint
	if p.character_id==1:
		var controls=p.get("weapon_controls")
		if controls!=null and controls.charging:
			attack_cooldowns[0].text="READY" if controls.fraction()>=1 else "%.1f"%maxf(0,controls.FULL_CHARGE_TIME-controls.elapsed)
			primary_icon.modulate=Color("ffe4a5")
func sync_health():
	var p=game.player
	if last_health_fighter!=p.character_id or not is_equal_approx(last_health_max,p.max_hp) or p.hp>last_health:
		health_trail.max_value=p.max_hp;health_trail.value=p.hp;health_trail_hold=0
	elif p.hp<last_health:
		health_trail.value=maxf(health_trail.value,last_health);health_trail_hold=.22
	last_health=p.hp;last_health_max=p.max_hp;last_health_fighter=p.character_id
	player_health_bar.max_value=p.max_hp;player_health_bar.value=p.hp
	var fraction=clampf(p.hp/maxf(1,p.max_hp),0,1)
	var level=2 if fraction<=.25 else (1 if fraction<=.5 else 0)
	if level!=health_level:
		health_level=level;player_health_bar.add_theme_stylebox_override("fill",health_styles[level])
	health_gloss.size.x=maxf(0,(player_health_bar.size.x-6)*fraction);health_gloss.visible=fraction>.02
	health.text="%d / %d HP"%[ceili(p.hp),ceili(p.max_hp)]
func animate_health(delta: float):
	if game.ordinary_pause or game.rogue_roster_open or is_instance_valid(overlay):return
	var step=maxf(0,delta-health_trail_hold);health_trail_hold=maxf(0,health_trail_hold-delta)
	if step>0:health_trail.value=move_toward(health_trail.value,player_health_bar.value,maxf(1,player_health_bar.max_value)*3.5*step)
func make_button(text_: String,action: Callable,width: float=150)->Button:
	var button=Button.new();button.text=text_;button.custom_minimum_size=Vector2(width,72)
	button.add_theme_stylebox_override("normal",style(PAPER));button.add_theme_stylebox_override("hover",style(Color("f7edcf")))
	button.add_theme_stylebox_override("pressed",style(Color("b5c4a2"),INK));button.add_theme_stylebox_override("focus",style(Color(0,0,0,0),Color("c39341")))
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:button.add_theme_color_override(state,INK)
	button.add_theme_font_size_override("font_size",18);button.pressed.connect(action);return button
func make_preparation_button(text_:String,action:Callable,width:float=150,primary:bool=false)->Button:
	var button=make_button(text_,action,width);PreparationSkin.apply_button(button,primary);return button
func icon(kind: String)->Texture2D:
	var drawing={
	"mine":"<path d='M12 60 L23 28 43 13 64 29 76 59Z' fill='#818677'/><path d='M25 63V39H58V63M19 35H65M35 61V45H49V61' fill='none'/><path d='M25 27L31 16 39 25 32 34Z M61 43L68 31 75 39 69 48Z' fill='#d3a452'/>",
	"tower":"<path d='M23 71V28M60 71V28M20 49H64M24 68L60 50M27 30L60 46' fill='none'/><path d='M17 29L42 10 69 29Z' fill='#618488'/><path d='M18 31H66V45H18Z' fill='#ac8759'/>",
	"barracks":"<path d='M13 31h62v39H13Z' fill='#92998c'/><path d='M12 35V17h12v10h12V17h12v10h12V17h12v18Z' fill='#adb29f'/><path d='M34 70V44h20v26' fill='#35433c'/><path d='M23 43v14m40-14v14M14 61h17m26 0h17' fill='none'/><path d='M43 12V3h22v12H43' fill='#b75543'/>",
	"wall":"<path d='M12 68V26L20 15 28 26V68M28 68V24L36 13 44 24V68M44 68V25L52 14 60 25V68M60 68V27L68 16 76 27V68' fill='#aa8455'/><path d='M10 38H77M10 58H77' fill='none'/>",
	"gate":"<path d='M14 69V24H25V69M61 69V24H72V69' fill='#a97d4d'/><path d='M10 18H76V29H10Z' fill='#ad8656'/><path d='M27 35H59V64H27Z M43 35V64M29 38L56 59' fill='none'/>"}[kind]
	var svg="<svg xmlns='http://www.w3.org/2000/svg' width='88' height='80' viewBox='0 0 88 80'><g stroke='#384438' stroke-width='2.3' stroke-linecap='round' stroke-linejoin='round'>"+drawing+"</g></svg>"
	var image=Image.new();image.load_svg_from_string(svg);return ImageTexture.create_from_image(image)
func _ready():
	theme=PreparationSkin.theme()
	process_mode=Node.PROCESS_MODE_ALWAYS;mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	make_status_hubs()
	respawn_notice=label_at("",Vector2.ZERO,26);respawn_notice.name="RespawnNotice"
	respawn_notice.mouse_filter=Control.MOUSE_FILTER_IGNORE;respawn_notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	respawn_notice.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	respawn_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	respawn_notice.offset_left=-340;respawn_notice.offset_right=340;respawn_notice.offset_top=-48;respawn_notice.offset_bottom=48
	respawn_notice.add_theme_color_override("font_outline_color",Color("12241f"))
	respawn_notice.add_theme_constant_override("outline_size",8);respawn_notice.hide()
	respawn_notice.add_theme_stylebox_override("normal",skin.lacquer())
	enemy_minimap=preload("res://scripts/forest/forest_enemy_minimap.gd").new();enemy_minimap.name="EnemyMinimap";enemy_minimap.game=game;add_child(enemy_minimap)
	preparation_actions=HFlowContainer.new();preparation_actions.name="PreparationActions";add_child(preparation_actions)
	preparation_actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);preparation_actions.offset_left=22;preparation_actions.offset_right=1100;preparation_actions.offset_top=-114;preparation_actions.offset_bottom=-70
	preparation_actions.add_theme_constant_override("h_separation",10);preparation_actions.add_theme_constant_override("v_separation",10)
	var balance=make_preparation_button("Balance",game.show_building_balance,110);balance.name="PreparationBalance";balance.custom_minimum_size.y=40;preparation_actions.add_child(balance)
	var restart=make_preparation_button("Restart",game.restart_area,110);restart.name="PreparationRestart";restart.custom_minimum_size.y=40;restart.tooltip_text="Start a fresh run now using your saved balance and selected fighter";preparation_actions.add_child(restart)
	var editor=make_preparation_button("Map Editor",game.open_map_editor,130);editor.name="PreparationMapEditor";editor.custom_minimum_size.y=40;preparation_actions.add_child(editor)
	painterly_button=make_preparation_button("Painterly: Off",game.toggle_painterly_preview,150);painterly_button.name="PreparationPainterly";painterly_button.custom_minimum_size.y=40;painterly_button.tooltip_text="Compare the painted forest, ground, walls and buildings with the original look";preparation_actions.add_child(painterly_button)
	shrine_health_dock=PanelContainer.new();shrine_health_dock.name="ShrineHealthDock";shrine_health_dock.mouse_filter=Control.MOUSE_FILTER_IGNORE
	shrine_health_dock.add_theme_stylebox_override("panel",skin.statue_frame());add_child(shrine_health_dock)
	shrine_health_dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	shrine_health_dock.anchor_left=.5;shrine_health_dock.anchor_right=.5
	var health_column=VBoxContainer.new();health_column.add_theme_constant_override("separation",3);shrine_health_dock.add_child(health_column)
	shrine_health_label=dock_label(health_column,"",Vector2.ZERO,13);shrine_health_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	shrine_health_bar=meter(health_column,"ShrineHealthBar",Color("dedee9"));shrine_health_bar.custom_minimum_size.y=28
	shrine_health_bar.add_theme_stylebox_override("fill",PreparationSkin.button_style("normal"))
	team_xp_bar=meter(health_column,"TeamXP",Color("edc35c"));team_xp_bar.custom_minimum_size.y=10
	var xp_track=team_xp_bar.get_theme_stylebox("background");xp_track.bg_color=Color("302315");xp_track.border_color=Color("96773d");xp_track.set_border_width_all(1)
	team_level_label=dock_label(health_column,"",Vector2.ZERO,13);team_level_label.name="TeamLevel";team_level_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	bar_paper=Panel.new();bar_paper.name="BuildPaper";bar_paper.theme=PreparationSkin.theme();bar_paper.add_theme_stylebox_override("panel",PreparationSkin.panel());add_child(bar_paper)
	bar_paper.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);bar_paper.offset_left=16;bar_paper.offset_right=-16;bar_paper.offset_top=-130;bar_paper.offset_bottom=-16
	build_bar=HBoxContainer.new();build_bar.name="BuildBar";build_bar.add_theme_constant_override("separation",7);add_child(build_bar)
	build_bar.alignment=BoxContainer.ALIGNMENT_CENTER
	build_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);build_bar.offset_left=30;build_bar.offset_right=-30;build_bar.offset_top=-117;build_bar.offset_bottom=-29
	for kind in ["tower","barracks"]:
		var caption={"tower":"1 · Tower","barracks":"2 · Barracks"}[kind]
		var b=make_preparation_button("%s\n%d ryo"%[caption,game.model.COSTS[kind]],choose_preparation_build.bind(kind),150)
		b.name=kind.capitalize();PreparationSkin.apply_card(b,icon(kind))
		build_bar.add_child(b);build_buttons[kind]=b
	var recruit=make_preparation_button("3 · Worker\n50 ryo",game.recruit_worker,150)
	PreparationSkin.apply_card(recruit,hud_icons.get_icon("worker"))
	recruit.name="Recruit";build_bar.add_child(recruit)
	build_bar.move_child(recruit,2)
	var castle=make_preparation_button("4 · Enemy castle\nFree · Testing",choose_preparation_build.bind("enemy_castle"),190)
	castle.name="EnemyCastle";castle.tooltip_text="Wind Meadow Valley · Place on level ground; clears trees · R rotates · Free for balance testing. Restart removes unsaved placements."
	PreparationSkin.apply_card(castle,icon("barracks"));build_bar.add_child(castle);build_buttons.enemy_castle=castle
	start_wave_button=make_preparation_button("START",game.start_wave,110,true);start_wave_button.name="StartWave";start_wave_button.custom_minimum_size.y=44;add_child(start_wave_button)
	start_wave_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	start_wave_button.offset_left=-132;start_wave_button.offset_right=-22;start_wave_button.offset_top=-60;start_wave_button.offset_bottom=-16
	preparation_header=HBoxContainer.new();preparation_header.name="PreparationHeader";preparation_header.add_theme_constant_override("separation",10);add_child(preparation_header)
	build_menu_button=make_preparation_button("Build",open_build_menu,0)
	build_menu_button.name="PreparationBuilds";build_menu_button.toggle_mode=true;build_menu_button.custom_minimum_size.y=32;preparation_header.add_child(build_menu_button)
	guard_shop_button=make_preparation_button("Mercenaries",show_guard_shop,0);guard_shop_button.name="PreparationHireGuards";guard_shop_button.toggle_mode=true;guard_shop_button.custom_minimum_size.y=32;preparation_header.add_child(guard_shop_button)
	var tools=make_preparation_button("Tools",func():preparation_tools_open=not preparation_tools_open;sync(),0);tools.name="PreparationTools";tools.custom_minimum_size.y=32;preparation_header.add_child(tools)
	map_size_controls=HBoxContainer.new();map_size_controls.name="PreparationMapSize";map_size_controls.add_theme_constant_override("separation",8);preparation_header.add_child(map_size_controls)
	smaller_map_button=make_preparation_button("Smaller ÷1.5",game.request_map_resize.bind(-1),0);smaller_map_button.name="PreparationSmallerMap";smaller_map_button.custom_minimum_size.y=32;smaller_map_button.add_theme_font_size_override("font_size",14);map_size_controls.add_child(smaller_map_button)
	map_size_label=Label.new();map_size_label.name="PreparationMapSizeLabel";map_size_label.add_theme_font_size_override("font_size",14);map_size_controls.add_child(map_size_label)
	bigger_map_button=make_preparation_button("Bigger ×1.5",game.request_map_resize.bind(1),0);bigger_map_button.name="PreparationBiggerMap";bigger_map_button.custom_minimum_size.y=32;bigger_map_button.add_theme_font_size_override("font_size",14);map_size_controls.add_child(bigger_map_button)
	smaller_map_button.tooltip_text="Divide map width and length by 1.5. Keeps all placements; blocked if anything would be cut off."
	bigger_map_button.tooltip_text="Multiply map width and length by 1.5 (2.25× area). Adds land around your current map and keeps placements."
	hint=label_at("",Vector2.ZERO,18);hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);hint.offset_left=30;hint.offset_right=-30;hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.add_theme_color_override("font_shadow_color",Color.BLACK);hint.add_theme_constant_override("shadow_outline_size",3)
	hint.name="ContextHint";hint.mouse_filter=Control.MOUSE_FILTER_IGNORE;hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_stylebox_override("normal",skin.lacquer());hint.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	inspection=PanelContainer.new();inspection.name="Inspection";inspection.theme=PreparationSkin.theme();inspection.add_theme_stylebox_override("panel",PreparationSkin.panel());add_child(inspection)
	inspection.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);inspection.offset_left=-300;inspection.offset_right=-24;inspection.offset_top=136
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",9);inspection.add_child(column)
	inspect_text=Label.new();inspect_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;inspect_text.add_theme_color_override("font_color",INK);inspect_text.add_theme_font_size_override("font_size",18);column.add_child(inspect_text)
	for data in [["Assign workers",func():game.model.workforce.assign_workers(selected_id)],["Auto assign",func():
		for w in game.model.workers.values():
			if w.job==selected_id:game.model.workforce.leave_shelter(w);game.model.workforce.leave_tower(w);w.job=-1;w.state="idle";w.path=[]],["Repair building",func():
		if not game.model.repair(selected_id):notify("Nothing to repair, or not enough ryo")],["Remove · 50% refund",func():
		if game.model.demolish(selected_id):selected_id=-1;game.world.sync(0)]]:
		var b=make_preparation_button(data[0],data[1],240);b.custom_minimum_size.y=42;column.add_child(b)
	inspection.hide();sync()
	reticle=Control.new();reticle.name="FreeReticle";reticle.mouse_filter=Control.MOUSE_FILTER_IGNORE;reticle.z_index=100
	add_child(reticle);reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reticle.draw.connect(_draw_crosshair)
	master_chief_hud=preload("res://scripts/master_chief_hud.gd").new();master_chief_hud.name="MasterChiefHUD";master_chief_hud.game=game;add_child(master_chief_hud)
func notify(text_: String):message=text_;message_left=4.0
func sync_preparation_dock():
	var expanded=build_menu_expanded or guard_shop_open()
	PreparationSkin.layout_cards(bar_paper,0)
	bar_paper.offset_top=-152 if expanded else -62;bar_paper.offset_bottom=-8
	if not expanded:bar_paper.offset_right=preparation_header.get_combined_minimum_size().x+54
	PreparationSkin.layout_cards(preparation_header)
	preparation_header.offset_right=preparation_header.get_combined_minimum_size().x+38
	preparation_header.offset_top=-50;preparation_header.offset_bottom=-16
	build_menu_button.set_pressed_no_signal(preparation_mode=="build");guard_shop_button.set_pressed_no_signal(preparation_mode=="mercenaries")
	PreparationSkin.layout_cards(build_bar)
	for kind in build_buttons:
		var button:Button=build_buttons[kind];button.toggle_mode=true;button.set_pressed_no_signal(game.build_kind==kind)
		button.disabled=not game.model.has_enemy_castles() if kind=="enemy_castle" else game.model.gold<game.model.COSTS[kind]
	build_bar.get_node("Recruit").disabled=game.model.gold<50 or not game.model.can_recruit(1)
func sync_hud_layout(prep: bool):
	var factor: float=game.settings.forest_hud_scale
	if factor!=applied_hud_scale:
		applied_hud_scale=factor
		resource_hub.pivot_offset=Vector2(348,0);hero_dock.pivot_offset=Vector2.ZERO
		for hub in [resource_hub,shrine_health_dock,hero_dock]:hub.scale=Vector2.ONE*factor
	var left_hud_bottom=loadout_slots.get_global_rect().end.y
	if spell_dock.visible:left_hud_bottom=maxf(left_hud_bottom,spell_dock.get_global_rect().end.y)
	inspection.position.y=20+68*factor+12
	enemy_minimap.set_layout(factor,size.y-left_hud_bottom-40.0)
	sync_preparation_dock()
	preparation_actions.offset_right=minf(920,size.x-208)
	var tools_height=maxf(44,preparation_actions.get_combined_minimum_size().y)
	preparation_actions.offset_top=-70-tools_height
	var expanded=prep and (build_menu_expanded or guard_shop_open())
	var raised=expanded or (prep and preparation_tools_open) or size.x<=1280*factor or preparation_header.get_global_rect().end.x+20>(size.x-560*factor)*.5
	var bottom=164.0 if expanded else (86.0+tools_height if prep and preparation_tools_open else (76.0 if raised and prep else 16.0))
	var width=minf(560,(size.x-64)/factor)
	shrine_health_dock.offset_left=-width*.5;shrine_health_dock.offset_right=width*.5
	shrine_health_dock.offset_top=-bottom-140;shrine_health_dock.offset_bottom=-bottom
	shrine_health_dock.pivot_offset=Vector2(width*.5,140)
	painterly_button.text="PAINTERLY: ON" if game.painterly_preview else "PAINTERLY: OFF"
	hint.anchor_left=.5;hint.anchor_right=.5
	var hint_width=minf(760,size.x-2*(22+348*factor+24))
	var hint_top=0.0
	if hint_width<320:
		hint_width=minf(760,size.x-44);hint_top=left_hud_bottom+8
	hint.offset_left=-hint_width*.5;hint.offset_right=hint_width*.5
	hint.offset_top=hint_top
	hint.offset_bottom=hint.offset_top+maxf(48,hint.get_combined_minimum_size().y)
func sync():
	if not is_instance_valid(game) or game.model==null:return
	var m=game.model;var prep=m.phase=="preparing"
	if not prep or game.ordinary_pause or game.settings_open or game.rogue_roster_open:
		preparation_mode="";build_menu_expanded=false;preparation_tools_open=false
	respawn_notice.visible=game.respawn_left>0 and game.playing and m.phase=="wave" and not game.ordinary_pause and not game.settings_open and not is_instance_valid(overlay)
	if respawn_notice.visible:respawn_notice.text="Respawning in %d"%ceili(game.respawn_left)
	bar_paper.visible=prep and not view_settings_preview and not is_instance_valid(overlay)
	preparation_header.visible=bar_paper.visible and game.playing and not game.ordinary_pause and not game.settings_open and not game.rogue_roster_open
	build_bar.visible=preparation_header.visible and build_menu_expanded
	start_wave_button.text="START"
	start_wave_button.visible=preparation_header.visible
	preparation_actions.visible=preparation_header.visible and preparation_tools_open
	guard_shop_button.visible=preparation_header.visible and prep
	map_size_controls.visible=m.terrain_source=="wind_meadow"
	map_size_label.text="Resizing…" if game.map_resize_pending else "Map %s×"%str(m.map_expansion)
	map_size_label.tooltip_text="Width and length relative to this map's original size · %.2f× area"%(m.map_expansion*m.map_expansion)
	smaller_map_button.disabled=game.map_resize_pending or m.map_expansion==1.0
	bigger_map_button.disabled=game.map_resize_pending or m.map_expansion==m.WindMeadowTerrain.EXPANSIONS.back()
	guard_shop_button.disabled=not is_instance_valid(game.explorer_helpers) or not game.explorer_helpers.available()
	gold_count.text=skin.format_gold(m.gold);worker_count.text=str(m.workers.size())
	gold_count.add_theme_font_size_override("font_size",24 if gold_count.text.length()<=10 else 18)
	ryo_caption.text=""
	sync_character()
	sync_hud_layout(prep)
	enemy_minimap.set_active(game.playing and m.phase=="wave" and (not game.paused or view_settings_preview) and not game.transitioning and not game.won and game.player.hp>0 and not is_instance_valid(overlay) and not game.rogue_roster_open and (not game.settings_open or view_settings_preview))
	if is_instance_valid(master_chief_hud):master_chief_hud.sync()
	hero_dock.visible=not is_instance_valid(overlay) and not (is_instance_valid(master_chief_hud) and master_chief_hud.visible and game.player.spell_loadout.assignments(18).is_empty())
	for i in cape_buttons.size():
		if i==1:cape_buttons[i].position.x=336
		cape_buttons[i].set_pressed_no_signal(game.player.scarf_equipped and (game.player.gold_cloak if i==1 else not game.player.gold_cloak))
		cape_buttons[i].mouse_filter=Control.MOUSE_FILTER_STOP if prep else Control.MOUSE_FILTER_IGNORE
	# Combat captures the cursor for aiming; mouse selection belongs to the building map.
	for i in range(loadout_buttons.size()):
		var slot:Array=game.player.spell_loadout.numbered_slots[i]
		var button=loadout_buttons[i]
		button.text=str(i+1);button.disabled=slot.is_empty()
		button.mouse_filter=Control.MOUSE_FILTER_STOP if prep else Control.MOUSE_FILTER_IGNORE
		button.set_pressed_no_signal(game.player.spell_loadout.held_numbers.has(i+1))
		helper_portraits[i].hide()
		button.tooltip_text="%d · %s"%[i+1,"Empty · Equip in Q → Skills & Jump" if slot.is_empty() else slot[0]]

	var shrine=m.shrine()
	shrine_health_bar.max_value=shrine.get("max_hp",1);shrine_health_bar.value=shrine.get("hp",0)
	shrine_health_label.text="Statue  ·  %d / %d"%[shrine.get("hp",0),shrine.get("max_hp",0)]
	var progression=m.team_progression
	team_level_label.text="TEAM LV %d  ·  %s"%[progression.level,"MAX LEVEL" if progression.level==progression.MAX_LEVEL else "%s / %d XP"%[String.num(progression.experience(),1),progression.kills_required()]]
	team_level_label.tooltip_text="Shared team XP: enemies start at 1 XP. Each later reinforcement group has +20% base health, +10% base damage and +0.2 XP per enemy. Choose a team upgrade each level."
	team_xp_bar.max_value=1.0;team_xp_bar.value=progression.progress()
	shrine_health_dock.visible=not is_instance_valid(overlay)
	var text_=""
	if prep and is_instance_valid(game.explorer_helpers) and game.explorer_helpers.placement_active():text_=game.explorer_helpers.placement_hint
	if prep and not game.build_kind.is_empty():text_="%s  ·  %s  ·  R rotate  ·  Esc exit"%[LABELS[game.build_kind],game.placement_hint]
	if not prep and m.workforce.held:
		var count=0
		for w in m.workers.values():
			if w.follow:count+=1
		text_="%d following · Release V: %d tower / %d repair / %d wait"%[count,job_preview.tower,job_preview.repair,job_preview.idle]
	hint.text=message if message_left>0 and not m.workforce.held else ("" if prep and game.build_kind.is_empty() and (build_menu_expanded or guard_shop_open()) else text_)
	hint.visible=not view_settings_preview and not hint.text.is_empty() and not is_instance_valid(overlay)
	inspection.visible=prep and not view_settings_preview and m.buildings.has(selected_id) and game.build_kind.is_empty() and not is_instance_valid(overlay)
	if inspection.visible:
		var b: Dictionary=m.buildings[selected_id]
		inspect_text.text="%s\nHP  %d / %d\nCrew  %d / %d"%["Goemon statue" if b.kind=="shrine" else LABELS[b.kind],b.hp,b.max_hp,m.workforce.count_job(b.id),m.workforce.capacity(b)]
		if b.kind=="wall":inspect_text.text+="\nIndestructible · No repairs needed"
		elif b.kind in ["gate","shrine","barracks"]:
			inspect_text.text+="\nAuto repair · 1 ryo / 10 HP"
			if b.get("breached",false):inspect_text.text+="\nDoor rebuilt · Waiting for a clear passage" if b.hp>=b.max_hp else "\nDoor destroyed · Workers rebuild this entrance"
func guard_shop_open()->bool:return is_instance_valid(guard_shop)
func show_guard_shop():
	if not is_instance_valid(game.explorer_helpers) or not game.explorer_helpers.available():return
	if guard_shop_open():return
	game.explorer_helpers.cancel_placement();game.build_kind="";game.world.preview.hide();selected_id=-1
	game.wall_start=Vector2i(-999,-999);preparation_mode="mercenaries";build_menu_expanded=false;preparation_tools_open=false
	guard_shop=preload("res://scripts/forest/guard_shop.gd").new();guard_shop.director=game.explorer_helpers;add_child(guard_shop)
	sync()
func close_guard_shop():
	var was_open=is_instance_valid(guard_shop)
	if was_open:remove_child(guard_shop);guard_shop.queue_free()
	guard_shop=null
	if was_open and is_instance_valid(preparation_header):sync()
func show_overlay(title_: String,subtitle: String,resume_: bool):
	if is_instance_valid(overlay):overlay.queue_free()
	overlay=PanelContainer.new();overlay.name="PausePanel";overlay.add_theme_stylebox_override("panel",PreparationSkin.panel());add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER);overlay.offset_left=-255;overlay.offset_right=255;overlay.offset_top=-230;overlay.offset_bottom=230
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",12);overlay.add_child(column)
	var heading=Label.new();heading.text=title_;heading.add_theme_color_override("font_color",INK);heading.add_theme_font_size_override("font_size",30);column.add_child(heading)
	var sub=Label.new();sub.text=subtitle;sub.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;sub.add_theme_color_override("font_color",INK);sub.add_theme_font_size_override("font_size",17);column.add_child(sub)
	if resume_:column.add_child(make_preparation_button("Resume",game.resume,440,true))
	if resume_:
		var settings=make_preparation_button("Settings",func():game.show_settings(true),440);settings.name="ForestPauseSettings";column.add_child(settings)
	column.add_child(make_preparation_button("Restart",game.restart_area,440));column.add_child(make_preparation_button("Main menu",game.show_main_menu,440))
func close_overlay():
	if is_instance_valid(overlay):overlay.queue_free()
	overlay=null
func _process(delta):
	message_left=maxf(0,message_left-delta);preview_clock-=delta
	if game.model.workforce.held and preview_clock<=0:
		job_preview=game.model.workforce.preview_jobs(game.player.position);preview_clock=.2
	sync();animate_health(delta);reticle.queue_redraw()


func crosshair_visible()->bool:
	return game!=null and game.player.character_id!=Roster.MASTER_CHIEF_ID and game.settings.forest_show_crosshair and game.playing and game.model.phase=="wave" and (not game.paused or view_settings_preview) and not game.transitioning and not game.won and game.player.hp>0
func _draw_crosshair():
	if not crosshair_visible():return
	var center: Vector2=game.crosshair_screen_position()
	for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
		reticle.draw_line(center+direction*5,center+direction*12,Color(0,.04,.08,.9),4,true)
		reticle.draw_line(center+direction*5,center+direction*12,Color("ffdb87"),1.5,true)
	reticle.draw_circle(center,2.5,Color(0,.04,.08,.9))
	reticle.draw_circle(center,1.1,Color("ffdb87"))
