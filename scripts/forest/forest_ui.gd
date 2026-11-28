extends Control
signal loadout_slot_selected(index: int)
var game
var reticle: Control
var attack_pointer_active=false
var patrol_target:Label
var pet_focus_marker:TextureRect
var primary_target_marker:TextureRect
var shin_combo_row:Control
var shin_combo_number:Control
var shin_combo_word:Control
var shin_combo_shown=0
var shin_combo_glyphs:Array[int]=[]
var master_chief_hud:Control
var hint: Label
var health: Label
var hero_name: Label
var hero_dock: Panel
var food_effects:GridContainer
var double_edge_debuff:Panel
var double_edge_amount:Label
var double_edge_time:Label
var enemy_minimap
var wave_countdown:Label
var view_settings_preview=false
var applied_hud_scale=-1.0
var hero_portrait: TextureRect
var legacy_portrait_material:ShaderMaterial
const PaintedHeads=preload("res://scripts/forest/painted_heads.gd")
const Gear=preload("res://scripts/forest/equipment.gd")
const HIT_COMBO_ATLAS=preload("res://assets/characters/crossgate/hit_feedback/joint-attack.png")
const HIT_COMBO_SPLIT_DIGITS=preload("res://assets/characters/crossgate/hit_feedback/hitcombo-01.png")
const HIT_COMBO_NUMBER_REGIONS=[
	Rect2(18,1,21,29), Rect2(1,1,15,29),
	Rect2(36,16,24,29), Rect2(134,16,20,29), Rect2(228,16,24,29), Rect2(324,16,24,29),
	Rect2(420,16,24,29), Rect2(518,16,24,29), Rect2(612,16,24,29), Rect2(708,16,24,29),
	Rect2(799,16,36,29),
]
var loadout_slots: HBoxContainer
const AIM_POINTER=preload("res://assets/ui/maroon/blue_cross_gate_cursor.png")
const ATTACK_POINTER=preload("res://assets/ui/maroon/blue_cross_gate_attack_cursor.png")
const POINTER_HOTSPOT=Vector2(1.5,1.5)
# The HUD can load while the equipment/skill catalog is still initializing.
const FIST_ICON=preload("res://assets/ui/crossgate/weapons/defaults/boxing-gloves-red.png")
const SHIN_STANCE_ICONS={
	"unarmed":FIST_ICON,
	"axe":preload("res://assets/ui/crossgate/weapons/defaults/axe.png"),
	"bow":preload("res://assets/ui/crossgate/weapons/defaults/bow.png"),
	"sword":preload("res://assets/ui/crossgate/weapons/defaults/sword.png"),
	"polearm":preload("res://assets/ui/crossgate/weapons/defaults/polearm.png"),
}
const SHIN_SPECIAL_STANCE_ICONS={
	"sword":preload("res://assets/ui/crossgate/weapons/red-sword.png"),
	"polearm":preload("res://assets/ui/crossgate/weapons/red-polearm.png"),
}
const MOUNTAIN_ICONS={"mountain-king/storm-bolt":preload("res://assets/characters/warcraft/mountain-king/icons/StormBolt.png"),"mountain-king/thunder-clap":preload("res://assets/characters/warcraft/mountain-king/icons/ThunderClap.png"),"mountain-king/avatar":preload("res://assets/characters/warcraft/mountain-king/icons/Avatar.png")}
const TAUNT_ICON_MATERIAL=preload("res://assets/materials/mountain_taunt_icon.tres")
var loadout_buttons: Array[Button]=[]
var loadout_cooldowns: Array[Label]=[]
var spell_chain:Label
var selected_loadout_slot=-1
var guard_shop:Control
var preparation_mode=""
var build_menu_expanded=false
var preparation_tools_open=false
var preparation_header:HBoxContainer
var map_size_controls:HBoxContainer
var map_size_label:Label
var smaller_map_button:Button
var bigger_map_button:Button
var start_wave_button:Button
var build_buttons:Dictionary={}
const PreparationSkin=preload("res://scripts/forest/preparation_skin.gd")
const MERCENARY_SHORTCUTS=[2,0,1,4,3] # Ninja, Dragoon, Ranger, Explorer, Knight.
var helper_portraits: Array[TextureRect]=[]
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const Status=preload("res://scripts/forest/character_status_panel.gd")
var hound_dock:Panel
var pet_passives:HBoxContainer
var pet_passive_counts:Dictionary={}
var shown_pet_passive_counts:Dictionary={}
var shown_pet_passive_bonuses:Dictionary={}
const PET_PASSIVE_BONUS_LABELS={
	"regeneration":"+%d HP per second",
	"critical_chance":"+%d percentage points of critical chance (total capped at 100%%)",
	"dodge_chance":"+%d percentage points of dodge chance (total capped at 100%%)",
}
var hound_heads:Array[TextureRect]=[]
var hound_health_bars:Array[ProgressBar]=[]
const PET_STANCES=[
 [preload("res://assets/ui/crossgate/pet_stances/attack-normal.png"),preload("res://assets/ui/crossgate/pet_stances/attack-selected.png")],
 [preload("res://assets/ui/crossgate/pet_stances/defend-normal.png"),preload("res://assets/ui/crossgate/pet_stances/defend-selected.png")],
 [preload("res://assets/ui/crossgate/pet_stances/return-normal.png"),preload("res://assets/ui/crossgate/pet_stances/return-selected.png")],
 [preload("res://assets/ui/crossgate/pet_stances/return-normal.png"),preload("res://assets/ui/crossgate/pet_stances/return-selected.png")],
]
const PET_STANCE_LABELS=["RMB","F Defend","Z Back","R Power"]
var hound_stance_icons:Array[TextureRect]=[]
var hound_stance_labels:Array[Label]=[]
var hound_stance:int=-1
var player_health_bar: ProgressBar
var player_mana_bar: ProgressBar
var mana: Label
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
var utility_key:Label
var leader_utility_icon: TextureRect
var musashi_charge_label:Label
var attack_cooldowns: Array[Label]=[]
var portrait_id=-1
var portrait_skin=0
var hud_icons=preload("res://scripts/forest/forest_hud_icons.gd").new()
const Roster=preload("res://scripts/rogue_roster.gd")
const KazSkins=preload("res://scripts/kaz_skins.gd")
static var MAZE_DAGGER=Gear.ITEMS["weapon:kunai"].icon
const MAZE_ASSASSINATION=preload("res://assets/ui/crossgate/skills/assassination.png")
static var MAZE_KATANA=Gear.ITEMS["weapon:sword"].icon
static var MAZE_WEAPON_ICONS=[MAZE_KATANA,MAZE_DAGGER,FIST_ICON]
var shrine_health_dock: PanelContainer
var shrine_health_label: Label
var shrine_health_bar: ProgressBar
var team_level_label:Label
var team_xp_bar:TextureProgressBar
var painterly_button: Button
var preparation_actions: HFlowContainer
var build_bar: GridContainer
var build_frame: PanelContainer
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
const INK=Color("f3eed8")
const PAPER=Color("f3eed8")
const LABELS={"mine":"Gold mine","tower":"Guard Tower","cannon_tower":"Cannon Tower","wall":"Stone wall","gate":"Gate","barracks":"Farm","enemy_castle":"Enemy castle · Free"}
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
	var background=StyleBoxFlat.new();background.bg_color=Color("241f1a");background.set_corner_radius_all(3)
	var fill=StyleBoxFlat.new();fill.bg_color=color;fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background",background);bar.add_theme_stylebox_override("fill",fill);parent.add_child(bar);return bar
func make_status_hubs():
	make_hero_dock()
	double_edge_debuff=panel("DoubleEdgeDebuff",Control.PRESET_TOP_LEFT,Rect2(0,0,180,34))
	dock_icon(double_edge_debuff,preload("res://assets/characters/crossgate/shin/double-edge-icon.png"),Vector2(5,5),Vector2(24,24)).texture_filter=Control.TEXTURE_FILTER_NEAREST
	double_edge_amount=dock_label(double_edge_debuff,"",Vector2(35,6),14)
	double_edge_amount.add_theme_color_override("font_color",Color("ffb3a1"))
	double_edge_time=dock_label(double_edge_debuff,"",Vector2(127,6),14)
	double_edge_debuff.hide()
	wave_countdown=label_at("",Vector2.ZERO,18);wave_countdown.name="WaveCountdown"
	wave_countdown.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	wave_countdown.offset_left=-140;wave_countdown.offset_right=140;wave_countdown.offset_top=16;wave_countdown.offset_bottom=104
	wave_countdown.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;wave_countdown.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	wave_countdown.mouse_filter=Control.MOUSE_FILTER_IGNORE;wave_countdown.add_theme_stylebox_override("normal",skin.lacquer())
func make_hero_dock():
	hero_dock=panel("HeroDock",Control.PRESET_TOP_LEFT,Rect2(22,28,250,128))
	dock_icon(hero_dock,skin.texture("portrait_frame"),Vector2.ZERO,Vector2(112,112))
	hero_portrait=dock_icon(hero_dock,null,Vector2(8,8),Vector2(96,96));hero_portrait.name="HeroPortrait"
	hero_portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	legacy_portrait_material=ShaderMaterial.new();legacy_portrait_material.shader=preload("res://scripts/forest/forest_hud_portrait.gdshader");hero_portrait.material=legacy_portrait_material
	hero_name=dock_label(hero_dock,"",Vector2(108,12),16);hero_name.size.x=128;hero_name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	for color in [Color("62c477"),Color("d8a54f"),Color("f15745")]:
		var fill=StyleBoxFlat.new();fill.bg_color=color;fill.set_corner_radius_all(2);health_styles.append(fill)
	health_trail=meter(hero_dock,"HealthTrail",Color("e8d9ab"));health_trail.position=Vector2(114,43);health_trail.size=Vector2(125,22)
	player_health_bar=meter(hero_dock,"PlayerHealthBar",health_styles[0].bg_color);player_health_bar.position=health_trail.position;player_health_bar.size=health_trail.size
	player_health_bar.add_theme_stylebox_override("background",StyleBoxEmpty.new())
	health_gloss=ColorRect.new();health_gloss.color=Color(1,1,1,.17);health_gloss.position=health_trail.position+Vector2(3,2);health_gloss.size=Vector2(119,3);health_gloss.mouse_filter=Control.MOUSE_FILTER_IGNORE;hero_dock.add_child(health_gloss)
	health=dock_label(player_health_bar,"",Vector2.ZERO,12);health.size=player_health_bar.size
	health.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;health.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	health.add_theme_color_override("font_shadow_color",Color.BLACK);health.add_theme_constant_override("shadow_outline_size",3)
	player_mana_bar=meter(hero_dock,"PlayerManaBar",Color("278fdb"));player_mana_bar.step=0.0
	player_mana_bar.mouse_filter=Control.MOUSE_FILTER_PASS
	player_mana_bar.tooltip_text="Mana · Regenerates 2 per second"
	player_mana_bar.accessibility_name="Mana"
	var mana_gloss=ColorRect.new();mana_gloss.color=Color(1,1,1,.14);mana_gloss.mouse_filter=Control.MOUSE_FILTER_IGNORE
	player_mana_bar.add_child(mana_gloss);mana_gloss.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);mana_gloss.offset_top=1;mana_gloss.offset_bottom=3
	mana=dock_label(player_mana_bar,"",Vector2.ZERO,11)
	mana.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;mana.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	mana.add_theme_color_override("font_shadow_color",Color.BLACK);mana.add_theme_constant_override("shadow_outline_size",3)
	team_xp_bar=TextureProgressBar.new();team_xp_bar.name="TeamXP";team_xp_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	team_xp_bar.texture_under=skin.texture("xp_track");team_xp_bar.texture_progress=skin.texture("xp_fill")
	team_xp_bar.fill_mode=TextureProgressBar.FILL_COUNTER_CLOCKWISE;team_xp_bar.radial_initial_angle=180;team_xp_bar.radial_fill_degrees=180
	team_xp_bar.step=0.0;hero_dock.add_child(team_xp_bar)
	team_level_label=dock_label(hero_dock,"",Vector2(80,80),14);team_level_label.name="TeamLevel"
	team_level_label.mouse_filter=Control.MOUSE_FILTER_PASS
	team_level_label.size=Vector2(30,30);team_level_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;team_level_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	var level_badge=StyleBoxFlat.new();level_badge.bg_color=Color("191c1b");level_badge.border_color=Color("aa9160");level_badge.set_border_width_all(2);level_badge.set_corner_radius_all(15)
	team_level_label.add_theme_stylebox_override("normal",level_badge);team_level_label.add_theme_color_override("font_color",Color("f3eed8"))
	food_effects=GridContainer.new();food_effects.name="FoodEffects";food_effects.columns=6;food_effects.mouse_filter=Control.MOUSE_FILTER_IGNORE
	food_effects.add_theme_constant_override("h_separation",4);food_effects.add_theme_constant_override("v_separation",4)
	add_child(food_effects);food_effects.hide()
	hound_dock=Panel.new();hound_dock.name="GuardHoundHealth";hound_dock.size=Vector2(214,80)
	hound_dock.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hound_dock.add_theme_stylebox_override("panel",skin.attack_style())
	hero_dock.add_child(hound_dock);hound_dock.hide()
	var pet_health_track=StyleBoxFlat.new()
	pet_health_track.bg_color=Color("191713")
	pet_health_track.border_color=Color("8f7a58")
	pet_health_track.set_border_width_all(1)
	pet_health_track.set_corner_radius_all(3)
	for i in Pets.MAX_ACTIVE:
		hound_heads.append(dock_icon(hound_dock,null,Vector2(10+i*42,2),Vector2(25,25)))
		var bar=ProgressBar.new()
		bar.name="PetHealth%d"%i;bar.show_percentage=false;bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
		bar.max_value=1.0;bar.step=0.0;bar.value=1.0
		bar.add_theme_stylebox_override("background",pet_health_track)
		bar.add_theme_stylebox_override("fill",health_styles[0])
		bar.position=Vector2(4+i*42,29);bar.size=Vector2(38,10)
		hound_dock.add_child(bar);hound_health_bars.append(bar)
	for i in PET_STANCES.size():
		var icon=dock_icon(hound_dock,PET_STANCES[i][0],Vector2(4+i*54,44),Vector2(50,20))
		icon.texture_filter=Control.TEXTURE_FILTER_NEAREST;hound_stance_icons.append(icon)
		var caption=dock_label(hound_dock,PET_STANCE_LABELS[i],Vector2(2+i*54,64),11)
		caption.size=Vector2(54,16);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_color_override("font_shadow_color",Color.BLACK);caption.add_theme_constant_override("shadow_outline_size",2)
		hound_stance_labels.append(caption)
	make_pet_passives()
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
	ben_utility_tile=Panel.new();ben_utility_tile.name="BenShurikenAction";ben_utility_tile.position=Vector2(254,10);ben_utility_tile.size=Vector2(52,56)
	ben_utility_tile.add_theme_stylebox_override("panel",skin.attack_style());hero_dock.add_child(ben_utility_tile)
	ben_utility_tile.tooltip_text="Tap E · Star fan / Hold E · Axes"
	leader_utility_icon=dock_icon(ben_utility_tile,load(Roster.icon_path("shuriken")),Vector2(9,5),Vector2(34,34))
	utility_key=dock_label(ben_utility_tile,"E",Vector2(0,39),12);utility_key.size.x=52;utility_key.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	musashi_charge_label=dock_label(ben_utility_tile,"",Vector2(0,13),14);musashi_charge_label.size.x=52;musashi_charge_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	musashi_charge_label.add_theme_color_override("font_shadow_color",Color.BLACK);musashi_charge_label.add_theme_constant_override("shadow_outline_size",5)
	ben_utility_tile.hide()
	loadout_slots=HBoxContainer.new();loadout_slots.name="LoadoutSlots";loadout_slots.position=Vector2(114,26);loadout_slots.add_theme_constant_override("separation",5);hero_dock.add_child(loadout_slots)
	for i in range(6):
		var button=Button.new();button.name="LoadoutSlot%d"%(i+1);button.custom_minimum_size=Vector2(44,56)
		button.toggle_mode=true;button.focus_mode=Control.FOCUS_NONE;button.mouse_filter=Control.MOUSE_FILTER_STOP
		button.tooltip_text="Loadout slot %d · Empty"%(i+1)
		PreparationSkin.apply_button(button);button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size",13)
		for state in ["normal","hover","pressed","hover_pressed","disabled"]:
			var box=skin.attack_style();box.set_corner_radius_all(1);box.shadow_size=0;box.bg_color=Color("191c1b")
			if state in ["pressed","hover_pressed"]:box.border_color=Color("ffe3a3");box.set_border_width_all(2)
			elif state=="hover":box.border_color=Color("fff5d1")
			elif state=="disabled":box.border_color=Color("544d41");box.bg_color=Color("191c1ba0")
			button.add_theme_stylebox_override(state,box)
		for key in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:button.add_theme_color_override(key,PAPER)
		button.add_theme_color_override("font_disabled_color",Color("929b9b"))
		button.button_down.connect(func():select_loadout_slot(i,true))
		button.button_up.connect(func():game.player.spell_loadout.number_input(i+1,false))
		loadout_slots.add_child(button);loadout_buttons.append(button)
		var portrait=dock_icon(button,null,Vector2(1,1),Vector2(42,42));portrait.name="HelperPortrait";portrait.material=legacy_portrait_material;portrait.hide();helper_portraits.append(portrait)
		var shortcut=dock_label(button,str(i+1),Vector2(1,41),11);shortcut.name="Shortcut"
		shortcut.add_theme_color_override("font_shadow_color",Color.BLACK);shortcut.add_theme_constant_override("shadow_outline_size",4)
		var cooldown=dock_label(button,"",Vector2(0,41),10);cooldown.size=Vector2(44,14);cooldown.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		cooldown.add_theme_font_override("font",PreparationSkin.FONT)
		cooldown.add_theme_color_override("font_shadow_color",Color.BLACK);cooldown.add_theme_constant_override("shadow_outline_size",4)
		cooldown.add_theme_color_override("font_color",Color("f3ddb0"));loadout_cooldowns.append(cooldown)
	spell_chain=dock_label(hero_dock,"",Vector2(250,8),11);spell_chain.name="SpellChain";spell_chain.hide()
	spell_chain.add_theme_color_override("font_shadow_color",Color.BLACK);spell_chain.add_theme_constant_override("shadow_outline_size",4)
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
	if kind=="cannon_tower":game.placement_audio.play_cannon("select")
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
	if code>=KEY_1 and code<=KEY_9 and not preparation_mode.is_empty():
		if event.pressed and not event.echo:
			var index=code-KEY_1
			if preparation_mode=="build":
				if index<2:choose_preparation_build(["tower","barracks"][index])
				elif index==2:game.recruit_worker()
				elif index==3 and game.model.has_enemy_castles():choose_preparation_build("enemy_castle")
				elif index==4:choose_preparation_build("cannon_tower")
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

func sync_character()->Dictionary:
	var p=game.player
	var prep=game.model.phase=="preparing"
	hero_name.visible=true
	var shin=Roster.is_shin(p.character_id)
	var shin_skills=Roster.is_crossgate_fighter(p.character_id) and p.model.shin_has_skills()
	loadout_slots.visible=not prep and (Roster.is_crossgate_fighter(p.character_id) or not shin or shin_skills or p.spell_loadout.numbered_slots.any(func(slot):return not slot.is_empty()))
	for i in 5:loadout_buttons[i].visible=Roster.is_crossgate_fighter(p.character_id) or not shin_skills or not p.spell_loadout.numbered_slots[i].is_empty()
	loadout_buttons[5].visible=p.spell_loadout.numbered_slots.size()>5
	spell_chain.visible=not prep and not p.spell_loadout.beast_master_equipped() and Roster.uses_crossgate_spells(p.character_id)
	if spell_chain.visible:spell_chain.text="Spell chain  ×%.1f"%p.spell_loadout.magic_cast_speed()
	var variant=Roster.has_variant_skins(p.character_id)
	var selected_skin:int=Roster.selected_skin(p.character_id,game.settings)
	if portrait_id!=p.character_id or ((shin or variant or p.character_id==Roster.KAZI_ID) and portrait_skin!=selected_skin):
		portrait_id=p.character_id
		portrait_skin=selected_skin
		ben_utility_tile.tooltip_text="Hold E · Sword Shield" if p.character_id==17 else "E · Ice kunai / Hold for Hail Beam · T / Shift+T Hair · R Super Jump" if p.character_id==16 else ("E · Smoke assault · R · Quick Burst" if p.character_id==14 else "Tap E · Star fan / Hold E · Axes")
		leader_utility_icon.texture=load(Roster.icon_path("ice" if p.character_id==16 else ("fire" if p.character_id==14 else "shuriken")))
		if p.character_id==13:
			ben_utility_tile.tooltip_text="1 X Slash · 2 Tenderize · 3 Desperado · 4 Rotation · 5 Mighty Strike · More in Loadout"
			leader_utility_icon.texture=load(Roster.icon_path("sword"))
		var primary="pipe";var secondary="wave";var accent=Color("edcf87");class_cooldowns={};cooldown_peaks=[0.0,0.0]
		if p.is_rogue_character():
			var data=Roster.data(p.character_id);hero_name.text=data.name;accent=Color(data.color);class_cooldowns=data.cooldowns
			hero_portrait.texture=Roster.portrait(p.character_id);primary=data.abilities.cutlass.icon;secondary=data.abilities.flintlock.icon
			primary_icon.tooltip_text=data.abilities.cutlass.name;secondary_icon.tooltip_text=data.abilities.flintlock.name
		else:
			var named=shin or p.character_id in [13,14,15,16,17,18,19,28,31,32,33] or Roster.is_crossgate_fighter(p.character_id) or Roster.is_enemy(p.character_id)
			hero_name.text=Roster.name_for(Roster.gallery_id(p.character_id)) if named else ("Edo" if p.character_id==2 else "Goemon")
			if shin:hero_portrait.texture=Roster.ShinSkins.portrait(portrait_skin)
			elif p.character_id==Roster.KAZI_ID:hero_portrait.texture=KazSkins.CATALOG[portrait_skin][1]
			elif variant:hero_portrait.texture=Roster.skin_portrait(p.character_id,portrait_skin)
			elif named:hero_portrait.texture=Roster.portrait(p.character_id)
			else:hero_portrait.texture=load("res://assets/models/characters/goemon_cosplay/portraits/%s.png"%hero_name.text.to_lower())
			if p.character_id==2:primary="fire";secondary="spark";accent=Color("ff956f")
			primary_icon.tooltip_text="Fireballs" if p.character_id==2 else "Pipe combo";secondary_icon.tooltip_text="Giant fireball" if p.character_id==2 else "Heavy strike"
			if Roster.is_crossgate_fighter(p.character_id):
				primary="staff" if p.model.fighter.strike=="staff" else "sword";secondary=primary;accent=Color(Roster.data(p.character_id).color)
				primary_icon.tooltip_text=hero_name.text+(" · Axe attack" if p.model.motions.get("weapon","")=="axe" else " · Basic strike" if shin else " · Staff combo" if p.model.fighter.strike=="staff" else " · Sword attack");secondary_icon.tooltip_text=primary_icon.tooltip_text
				if Roster.is_crossgate_archer(p.character_id):primary_icon.tooltip_text=hero_name.text+" · LMB · Bow attack"
				primary_icon.tooltip_text+=" · Tab target"
				secondary_icon.tooltip_text="Right-click an enemy to focus pets · Right-click ground to attack move in that direction"
			if p.character_id==13:
				primary="sword";secondary="sword";accent=Color("bba4f2")
				primary_icon.tooltip_text="LMB · Fusion · LMB, LMB, RMB: Tenderize";secondary_icon.tooltip_text="RMB · Lumina · After a Fusion hit: X Slash · Then LMB, RMB: Desperado"
			if p.character_id in [31,32]:
				primary="sword";secondary="spark";accent=Color(Roster.data(p.character_id).color)
				primary_icon.tooltip_text="Sword combo" if p.character_id==31 else "Glaive combo / Demon bolt"
				secondary_icon.tooltip_text="Critical strike" if p.character_id==31 else "Metamorphosis"
			if p.character_id==33:
				primary="sword";secondary="spark";accent=Color("278dff")
				primary_icon.tooltip_text="Hammer / Axe combo · Passive Bash";secondary_icon.tooltip_text="Storm Bolt"
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
		var fixed_weapon:String=Roster.crossgate_profile(p.character_id).get("weapon","")
		if fixed_weapon in ["axe","bow"]:
			primary_icon.texture=SHIN_STANCE_ICONS[fixed_weapon];secondary_icon.texture=primary_icon.texture
		secondary_icon.get_parent().hide()
		attack_colors=[Color("f2d39a").lerp(accent,.35),Color("a7d9cc").lerp(accent,.25)]
		hero_name.add_theme_color_override("font_color",PAPER)
		var crop=Vector4(0,0,1,1) if (p.character_id in [16,17,18,19,28,31,32,33] or Roster.is_crossgate_fighter(p.character_id) or Roster.is_enemy(p.character_id)) else Vector4(.3375,.20,.325,.52)
		if shin or variant:
			var origin:Vector2=Roster.CROSSGATE[p.character_id].portrait_origin if variant else Roster.ShinSkins.catalog(p.character_id==Roster.SHIN_SPECIAL_ID)[portrait_skin][1]
			var dimensions=hero_portrait.texture.get_size()
			var extent=Vector2.ONE*minf(44.0,dimensions.x)
			var offset=(Vector2(0,-61)-origin-extent*.5).clamp(Vector2.ZERO,dimensions-extent)
			crop=Vector4(offset.x/dimensions.x,offset.y/dimensions.y,extent.x/dimensions.x,extent.y/dimensions.y)
		legacy_portrait_material.set_shader_parameter("face_crop",crop)
		hero_portrait.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST if Roster.is_crossgate_fighter(p.character_id) else CanvasItem.TEXTURE_FILTER_LINEAR
		var painted_head=PaintedHeads.portrait(p.character_id,game.settings)
		if painted_head!=null:
			hero_portrait.texture=painted_head;hero_portrait.material=null
			hero_portrait.size=Vector2(96,96);hero_portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		else:
			hero_portrait.material=legacy_portrait_material;hero_portrait.size=Vector2(82,82);hero_portrait.stretch_mode=TextureRect.STRETCH_SCALE
	primary_icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST if p.character_id in [1,16,17] else CanvasItem.TEXTURE_FILTER_LINEAR
	secondary_icon.texture_filter=primary_icon.texture_filter
	leader_utility_icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST if shin or p.character_id==16 or Roster.has_crossgate_throws(p.character_id) else CanvasItem.TEXTURE_FILTER_LINEAR
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
	if p.character_id==1:
		primary_icon.texture=goemon_weapon_icon(p.weapon_slot);secondary_icon.texture=primary_icon.texture
		primary_icon.tooltip_text=["Gold pipe · Three-hit combo","Flaming ryo · Throw immediately" if p.surge_left>0 else "Ryo · Throw","Chain pipe · Throw, then move your aim to swing"][clampi(p.weapon_slot-1,0,2)]
		secondary_icon.tooltip_text=["Gold pipe · Heavy strike","Flaming ryo · Throw immediately" if p.surge_left>0 else "Ryo · Throw","Chain pipe · Swing while extended, then return"][clampi(p.weapon_slot-1,0,2)]
	if p.character_id==8:
		primary_icon.tooltip_text="Dragon Leap" if not p.is_on_floor() else "Lance Pierce"
		secondary_icon.tooltip_text="Dragon Leap" if not p.is_on_floor() else "Azure Lance Sweep"
	if p.is_meta_shooter():primary_icon.tooltip_text="Mouse · Aim · Hold LMB · Energy bolts · WASD · Strafe"
	var equipped=p.spell_loadout.assignments(p.character_id)
	var maze=Roster.has_crossgate_throws(p.character_id) and not p.model.gear_external
	var shin_swap=Roster.is_crossgate_fighter(p.character_id) and p.model.can_swap_stance()
	var gear_item:Dictionary=Gear.ITEMS.get("weapon:"+p.model.gear_weapon,{}) if Roster.is_crossgate_fighter(p.character_id) else {}
	if not gear_item.is_empty():
		var item=Gear.item_data(Gear.equipped(game.settings.gear_loadouts,p.character_id),game.settings)
		if not item.is_empty():gear_item=item
	utility_key.visible=not (maze or shin_swap or not gear_item.is_empty())
	leader_utility_icon.position.y=5 if utility_key.visible else 11
	if not gear_item.is_empty():
		primary_icon.texture=gear_item.icon;secondary_icon.texture=gear_item.icon;leader_utility_icon.texture=gear_item.icon
		primary_icon.tooltip_text=gear_item.name+" · LMB · Tab target"
		if p.spell_loadout.beast_master_equipped():primary_icon.tooltip_text="Beast Master · LMB throws a dagger for base damage · Tab target"
		ben_utility_tile.tooltip_text=gear_item.name
	elif maze:
		leader_utility_icon.texture=MAZE_WEAPON_ICONS[p.model.maze_weapon]
		ben_utility_tile.tooltip_text=["Katana","Dagger","Boxing Gloves"][p.model.maze_weapon]
	elif shin_swap:
		var stance:String=p.model.motions.weapon
		var icons=SHIN_SPECIAL_STANCE_ICONS if p.model.fighter.get("weapon_effects",false) else SHIN_STANCE_ICONS
		leader_utility_icon.texture=icons.get(stance,SHIN_STANCE_ICONS.sword)
		ben_utility_tile.tooltip_text=stance.capitalize()
	elif equipped.has("equip"):
		var spec=p.spell_loadout.Catalog.all()[equipped.equip]
		ben_utility_tile.tooltip_text="E · "+spec.name
		leader_utility_icon.texture=load(Roster.icon_path(str(spec.get("icon","spark"))))
	ben_utility_tile.visible=not prep and (maze or shin_swap or not gear_item.is_empty() or (p.character_id==13 and p.active_ability.guarding()))
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
	return equipped
func health_band(fraction:float)->int:
	return 2 if fraction<=.25 else (1 if fraction<=.5 else 0)

func sync_health():
	var p=game.player
	if last_health_fighter!=p.character_id or not is_equal_approx(last_health_max,p.max_hp) or p.hp>last_health:
		health_trail.max_value=p.max_hp;health_trail.value=p.hp;health_trail_hold=0
	elif p.hp<last_health:
		health_trail.value=maxf(health_trail.value,last_health);health_trail_hold=.22
	last_health=p.hp;last_health_max=p.max_hp;last_health_fighter=p.character_id
	player_health_bar.max_value=p.max_hp;player_health_bar.value=p.hp
	var fraction=clampf(p.hp/maxf(1,p.max_hp),0,1)
	var level=health_band(fraction)
	if level!=health_level:
		health_level=level;player_health_bar.add_theme_stylebox_override("fill",health_styles[level])
	health_gloss.size.x=maxf(0,(player_health_bar.size.x-6)*fraction);health_gloss.visible=fraction>.02
	health.text="%d / %d"%[ceili(p.hp),ceili(p.max_hp)]
	player_mana_bar.max_value=maxf(1,p.max_mana);player_mana_bar.value=clampf(p.mana,0,p.max_mana)
	mana.text="%d / %d"%[ceili(player_mana_bar.value),ceili(p.max_mana)]
func make_pet_passives():
	pet_passives=HBoxContainer.new()
	pet_passives.name="PetPassives"
	pet_passives.mouse_filter=Control.MOUSE_FILTER_IGNORE
	pet_passives.add_theme_constant_override("separation",4)
	hero_dock.add_child(pet_passives)
	pet_passives.hide()
	var tile_style=skin.attack_style()
	for passive in Pets.PASSIVES.values():
		var tile=Panel.new()
		tile.name=passive.stat
		tile.custom_minimum_size=Vector2(58,34)
		tile.mouse_filter=Control.MOUSE_FILTER_PASS
		tile.add_theme_stylebox_override("panel",tile_style)
		tile.accessibility_name=passive.name
		pet_passives.add_child(tile)
		dock_icon(tile,Status.passive_texture_for_stat(passive.stat),Vector2(3,2),Vector2(30,30))
		var count=dock_label(tile,"",Vector2(32,0),14)
		count.size=Vector2(24,34)
		count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		count.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		pet_passive_counts[passive.stat]=count

func sync_pet_passives():
	var player=game.player
	if not player.uses_pet_passives():
		pet_passives.hide()
		return
	var selected:Array=game.settings.forest_pet_loadout
	var counts={}
	var bonuses={}
	for key in selected:
		var pet_skin=Pets.skin(key)
		var passive=Pets.passive(pet_skin)
		if passive.is_empty():continue
		var stat:String=passive.stat
		counts[stat]=counts.get(stat,0)+1
		bonuses[stat]=bonuses.get(stat,0.0)+Pets.passive_value(pet_skin,player.team_progression.pet_passive_level(key))
	pet_passives.visible=not counts.is_empty()
	if counts==shown_pet_passive_counts and bonuses==shown_pet_passive_bonuses:return
	shown_pet_passive_counts=counts
	shown_pet_passive_bonuses=bonuses
	for stat in pet_passive_counts:
		var count:Label=pet_passive_counts[stat]
		var tile:Panel=count.get_parent()
		var stacks:int=counts.get(stat,0)
		tile.visible=stacks>0
		if stacks==0:continue
		count.text="×%d"%stacks
		var bonus:String=PET_PASSIVE_BONUS_LABELS[stat]%bonuses[stat]
		tile.tooltip_text="%s · %d %s\n%s"%[tile.accessibility_name,stacks,"pet" if stacks==1 else "pets",bonus]
		tile.accessibility_description=tile.tooltip_text

func sync_hound_health():
	var any_alive=false
	var selection:Array=game.settings.forest_pet_loadout
	for i in hound_heads.size():
		var skin:int=Pets.skin(selection[i]) if i<selection.size() else -1
		var fraction:float=game.army_runtime.hound_health_fraction(skin) if skin>=0 and is_instance_valid(game.army_runtime) else 0.0
		var head=hound_heads[i]
		var bar=hound_health_bars[i]
		head.texture=Pets.portrait(skin) if skin>=0 else null
		head.visible=fraction>0.0
		var level=health_band(fraction)
		if level!=health_band(bar.value):
			bar.add_theme_stylebox_override("fill",health_styles[level])
		bar.value=fraction
		bar.visible=head.visible
		any_alive=any_alive or head.visible
	hound_dock.visible=any_alive
	if any_alive:
		var order:int=game.army_runtime.hound_order
		var stance=3 if order==game.army_runtime.HoundOrder.COMBINED else 0 if order==game.army_runtime.HoundOrder.ATTACK else 1 if order==game.army_runtime.HoundOrder.HOLD else 2
		if stance!=hound_stance:
			hound_stance=stance
			for i in hound_stance_icons.size():
				var active=i==stance
				hound_stance_icons[i].texture=PET_STANCES[i][1 if active else 0]
				hound_stance_icons[i].modulate.a=1.0 if active else .55
				hound_stance_labels[i].text=("› " if active else "")+PET_STANCE_LABELS[i]
				hound_stance_labels[i].modulate.a=1.0 if active else .65
		hound_stance_labels[3].text="› Combo" if game.army_runtime.combined_committed else "› R Power" if stance==3 else "R Power"
	var visor=not hero_dock.visible and is_instance_valid(master_chief_hud) and master_chief_hud.visible and not is_instance_valid(overlay)
	var parent:Control=master_chief_hud.health if visor else hero_dock
	if hound_dock.get_parent()!=parent:hound_dock.reparent(parent,false)
	var factor:float=game.settings.forest_hud_scale if visor else 1.0
	hound_dock.scale=Vector2.ONE*factor
	hound_dock.position=Vector2((parent.size.x-hound_dock.size.x*factor)*.5,16) if visor else Vector2(12,128)
	hound_dock.self_modulate.a=1.0 if visor else 0.0
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
func _ready():
	theme=PreparationSkin.theme()
	process_mode=Node.PROCESS_MODE_ALWAYS;mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	make_status_hubs()
	respawn_notice=label_at("",Vector2.ZERO,26);respawn_notice.name="RespawnNotice"
	respawn_notice.mouse_filter=Control.MOUSE_FILTER_IGNORE;respawn_notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	respawn_notice.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	respawn_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	respawn_notice.offset_left=-340;respawn_notice.offset_right=340;respawn_notice.offset_top=-48;respawn_notice.offset_bottom=48
	respawn_notice.add_theme_color_override("font_outline_color",Color("1d1712"))
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
	shrine_health_dock.add_theme_stylebox_override("panel",skin.lacquer() if game.model.survival_run else skin.statue_frame());add_child(shrine_health_dock)
	shrine_health_dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	shrine_health_dock.anchor_left=.5;shrine_health_dock.anchor_right=.5
	var health_column=VBoxContainer.new();health_column.add_theme_constant_override("separation",3);shrine_health_dock.add_child(health_column)
	shrine_health_label=dock_label(health_column,"",Vector2.ZERO,13);shrine_health_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	shrine_health_bar=meter(health_column,"ShrineHealthBar",Color("dedee9"));shrine_health_bar.custom_minimum_size.y=28
	shrine_health_bar.add_theme_stylebox_override("fill",PreparationSkin.button_style("normal"))
	bar_paper=Panel.new();bar_paper.name="BuildPaper";bar_paper.theme=PreparationSkin.theme();bar_paper.add_theme_stylebox_override("panel",PreparationSkin.panel());add_child(bar_paper)
	bar_paper.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);bar_paper.offset_left=16;bar_paper.offset_right=-16;bar_paper.offset_top=-130;bar_paper.offset_bottom=-16
	build_frame=PanelContainer.new();build_frame.name="BuildGridFrame";build_frame.add_theme_stylebox_override("panel",PreparationSkin.panel());add_child(build_frame)
	build_frame.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	build_bar=GridContainer.new();build_bar.name="BuildBar";build_bar.columns=4;build_frame.add_child(build_bar)
	build_bar.add_theme_constant_override("h_separation",8);build_bar.add_theme_constant_override("v_separation",8)
	for kind in ["tower","barracks"]:
		var b=make_preparation_button("",choose_preparation_build.bind(kind),104)
		b.name=kind.capitalize();PreparationSkin.apply_card(b,hud_icons.get_icon(kind))
		build_bar.add_child(b);build_buttons[kind]=b
	var recruit=make_preparation_button("",game.recruit_worker,104)
	PreparationSkin.apply_card(recruit,hud_icons.get_icon("worker"))
	recruit.name="Recruit";build_bar.add_child(recruit)
	build_bar.move_child(recruit,2)
	var castle=make_preparation_button("",choose_preparation_build.bind("enemy_castle"),104);castle.name="EnemyCastle"
	PreparationSkin.apply_card(castle,hud_icons.get_icon("enemy_castle"));build_bar.add_child(castle);build_buttons.enemy_castle=castle
	var cannon=make_preparation_button("",choose_preparation_build.bind("cannon_tower"),104);cannon.name="CannonTower"
	PreparationSkin.apply_card(cannon,hud_icons.get_icon("cannon_tower"));build_bar.add_child(cannon);build_buttons.cannon_tower=cannon
	for i in build_bar.get_child_count():
		var button:Button=build_bar.get_child(i);button.text="";button.custom_minimum_size=Vector2(104,104)
		button.vertical_icon_alignment=VERTICAL_ALIGNMENT_CENTER;button.add_theme_constant_override("icon_max_width",80)
		var shortcut=dock_label(button,str(i+1),Vector2(5,5),28);shortcut.name="Shortcut";shortcut.size=Vector2(36,36)
		shortcut.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;shortcut.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		var keycap=skin.attack_style();keycap.set_corner_radius_all(4);keycap.set_border_width_all(2)
		shortcut.add_theme_stylebox_override("normal",keycap)
	recruit.tooltip_text="Worker\n50 ryo\nShortcut: 3"
	castle.tooltip_text="Enemy castle · Skullpion statue\nFree · Testing\nShortcut: 4 · T rotates\nDestroy the statue to stop reinforcements.\nPlace on level ground; clears trees.\nRestart removes unsaved placements."
	for i in range(5,12):
		var slot=Button.new();slot.name="EmptySlot%d"%(i+1);slot.custom_minimum_size=Vector2(104,104);slot.disabled=true
		slot.add_theme_stylebox_override("disabled",skin.attack_style());slot.self_modulate.a=.45;build_bar.add_child(slot)
	start_wave_button=make_preparation_button("START",game.start_wave,110,true);start_wave_button.name="StartWave";start_wave_button.custom_minimum_size.y=44;add_child(start_wave_button)
	start_wave_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	start_wave_button.offset_left=-132;start_wave_button.offset_right=-22;start_wave_button.offset_top=-60;start_wave_button.offset_bottom=-16
	preparation_header=HBoxContainer.new();preparation_header.name="PreparationHeader";preparation_header.add_theme_constant_override("separation",10);add_child(preparation_header)
	var tools=make_preparation_button("Tools",func():
		var show_tools=not preparation_tools_open;close_preparation_menu();preparation_tools_open=show_tools;sync(),0)
	tools.name="PreparationTools";tools.custom_minimum_size.y=32;preparation_header.add_child(tools)
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
	for data in [["Repair building",func():
		if not game.model.repair(selected_id):notify("Nothing to repair, or not enough ryo")],["Remove · 50% refund",func():
		var removed_cannon=game.model.buildings.get(selected_id,{}).get("kind","")=="cannon_tower"
		if game.model.demolish(selected_id):
			if removed_cannon:game.placement_audio.play_cannon("cancel")
			selected_id=-1;game.world.sync(0)]]:
		var b=make_preparation_button(data[0],data[1],240);b.custom_minimum_size.y=42;column.add_child(b)
	inspection.hide();sync()
	reticle=Control.new();reticle.name="FreeReticle";reticle.mouse_filter=Control.MOUSE_FILTER_IGNORE;reticle.z_index=100
	patrol_target=dock_label(reticle,"",Vector2.ZERO,16);patrol_target.name="PatrolTarget";patrol_target.hide()
	patrol_target.add_theme_color_override("font_outline_color",Color("182827"));patrol_target.add_theme_constant_override("outline_size",6)
	pet_focus_marker=dock_icon(reticle,preload("res://assets/ui/crossgate/pet_target/pointer.png"),Vector2.ZERO,Vector2(40,24));pet_focus_marker.name="PetFocusMarker"
	var focus_material=ShaderMaterial.new();focus_material.shader=preload("res://assets/ui/crossgate/equipment/tint.gdshader")
	focus_material.set_shader_parameter("tint",Color("ff3434"));pet_focus_marker.material=focus_material
	pet_focus_marker.hide()
	primary_target_marker=dock_icon(reticle,pet_focus_marker.texture,Vector2.ZERO,pet_focus_marker.size);primary_target_marker.name="PrimaryTargetMarker"
	var primary_target_material:ShaderMaterial=focus_material.duplicate()
	primary_target_material.set_shader_parameter("tint",Color("57b7ff"));primary_target_marker.material=primary_target_material
	primary_target_marker.hide()
	shin_combo_row=Control.new();shin_combo_row.name="ShinCombo";shin_combo_row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	reticle.add_child(shin_combo_row)
	shin_combo_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	shin_combo_row.offset_left=-24;shin_combo_row.offset_right=-24
	shin_combo_row.offset_top=24;shin_combo_row.offset_bottom=53
	shin_combo_number=Control.new();shin_combo_number.name="ShinComboCount"
	shin_combo_number.mouse_filter=Control.MOUSE_FILTER_IGNORE
	shin_combo_row.add_child(shin_combo_number)
	shin_combo_number.draw.connect(draw_shin_combo_number)
	shin_combo_word=make_hit_combo_word(shin_combo_row)
	shin_combo_word.position.y=4
	shin_combo_row.hide()
	reticle.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(reticle);reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reticle.draw.connect(_draw_crosshair)
	master_chief_hud=preload("res://scripts/master_chief_hud.gd").new();master_chief_hud.name="MasterChiefHUD";master_chief_hud.game=game;add_child(master_chief_hud)

func make_hit_combo_word(parent:Control)->Control:
	# Atlas regions and native letter offsets from joint-attack.json, at 1:1 scale.
	var glyphs=[
		[Rect2(898,20,28,25),Vector2(0,0)], [Rect2(1003,20,12,25),Vector2(29,0)],
		[Rect2(1098,21,16,24),Vector2(40,1)], [Rect2(1188,20,24,25),Vector2(56,0)],
		[Rect2(1288,26,20,19),Vector2(80,6)], [Rect2(1379,26,28,19),Vector2(98,6)],
		[Rect2(1480,20,20,25),Vector2(124,0)], [Rect2(1288,26,20,19),Vector2(143,6)],
	]
	var word=Control.new();word.name="HitComboWord";word.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(word)
	for glyph in glyphs:
		var texture=AtlasTexture.new();texture.atlas=HIT_COMBO_ATLAS;texture.filter_clip=true
		texture.region=glyph[0]
		dock_icon(word,texture,glyph[1],texture.region.size)
	word.size=Vector2(163,25)
	return word

func notify(text_: String):message=text_;message_left=4.0
func sync_preparation_dock():
	var expanded=guard_shop_open()
	PreparationSkin.layout_cards(bar_paper,0)
	bar_paper.offset_top=-152 if expanded else -62;bar_paper.offset_bottom=-8
	if not expanded:bar_paper.offset_right=preparation_header.get_combined_minimum_size().x+54
	PreparationSkin.layout_cards(preparation_header)
	preparation_header.offset_right=preparation_header.get_combined_minimum_size().x+38
	preparation_header.offset_top=-50;preparation_header.offset_bottom=-16
	for kind in build_buttons:
		var button:Button=build_buttons[kind];button.toggle_mode=true;button.set_pressed_no_signal(game.build_kind==kind)
		button.disabled=not game.model.has_enemy_castles() if kind=="enemy_castle" else game.model.gold<game.model.COSTS[kind]
		if kind!="enemy_castle":button.tooltip_text="%s\n%d ryo\nShortcut: %s"%[LABELS[kind],game.model.COSTS[kind],button.get_node("Shortcut").text]
	build_buttons.tower.tooltip_text+="\nFires automatically · No workers needed"
	build_buttons.cannon_tower.tooltip_text+="\nGround splash · 100% / 50% / 10%\nSlower shells · No workers needed"
	build_bar.get_node("Recruit").disabled=game.model.gold<50 or not game.model.can_recruit(1)
func sync_hud_layout(prep: bool):
	var factor: float=game.settings.forest_hud_scale
	loadout_slots.size=loadout_slots.get_combined_minimum_size()
	var bar_width=loadout_slots.size.x if loadout_slots.visible else 125.0
	ben_utility_tile.position=Vector2(114+bar_width+8,26)
	if ben_utility_tile.visible:bar_width+=60
	spell_chain.position.x=114+bar_width-spell_chain.get_combined_minimum_size().x
	hero_dock.size.x=114+bar_width+11
	health_trail.position=Vector2(114,87 if loadout_slots.visible else 43);health_trail.size.x=bar_width
	player_health_bar.position=health_trail.position;player_health_bar.size=health_trail.size;health.size=player_health_bar.size
	player_mana_bar.position=health_trail.position+Vector2(0,25);player_mana_bar.size=Vector2(bar_width,15);mana.size=player_mana_bar.size
	health_gloss.position=health_trail.position+Vector2(3,2)
	health_gloss.size.x=maxf(0,(bar_width-6)*clampf(game.player.hp/maxf(1,game.player.max_hp),0,1))
	hero_name.position.y=4 if loadout_slots.visible else 12
	if factor!=applied_hud_scale:
		applied_hud_scale=factor
		for hub in [shrine_health_dock,hero_dock,wave_countdown]:hub.scale=Vector2.ONE*factor
	wave_countdown.pivot_offset=Vector2(140,0)
	var top_shift=112*factor if wave_countdown.visible and size.x-44<(2*hero_dock.size.x+312)*factor else 0.0
	var hound_space=hound_dock.size.y+8 if hound_dock.visible and hound_dock.get_parent()==hero_dock else 0.0
	pet_passives.position=Vector2(12,128+hound_space)
	pet_passives.size=pet_passives.get_combined_minimum_size()
	var passive_space=pet_passives.size.y+6 if pet_passives.visible else 0.0
	hero_dock.offset_top=28+top_shift
	hero_dock.offset_bottom=168+top_shift+hound_space+passive_space
	food_effects.size=food_effects.get_combined_minimum_size();food_effects.scale=Vector2.ONE*factor
	food_effects.position=Vector2((size.x-food_effects.size.x*factor)*.5,size.y-food_effects.size.y*factor-(76 if prep else 16))
	var left_hud_bottom=hero_dock.get_global_rect().end.y
	if loadout_slots.visible:left_hud_bottom=maxf(left_hud_bottom,loadout_slots.get_global_rect().end.y)
	if spell_chain.visible:left_hud_bottom=maxf(left_hud_bottom,spell_chain.get_global_rect().end.y)
	var grid_size=build_frame.get_combined_minimum_size()
	var grid_scale=clampf(minf((size.y-left_hud_bottom-140)/grid_size.y,(size.x-44)/grid_size.x),.5,1.0)
	build_frame.scale=Vector2.ONE*grid_scale;build_frame.pivot_offset=Vector2(0,grid_size.y)
	build_frame.offset_left=22;build_frame.offset_right=22+grid_size.x;build_frame.offset_top=-72-grid_size.y;build_frame.offset_bottom=-72
	inspection.position.y=wave_countdown.get_global_rect().end.y+12 if wave_countdown.visible else 28.0
	enemy_minimap.set_layout(factor,size.y-left_hud_bottom-40.0)
	sync_preparation_dock()
	preparation_actions.offset_right=minf(920,size.x-208)
	var tools_height=maxf(44,preparation_actions.get_combined_minimum_size().y)
	preparation_actions.offset_top=-70-tools_height
	var expanded=prep and (build_menu_expanded or guard_shop_open())
	var raised=expanded or (prep and preparation_tools_open) or size.x<=1280*factor or preparation_header.get_global_rect().end.x+20>(size.x-560*factor)*.5
	var grid_open=prep and build_menu_expanded
	var bottom=76.0 if grid_open else (164.0 if expanded else (86.0+tools_height if prep and preparation_tools_open else (76.0 if raised and prep else 16.0)))
	var width=minf(560,(size.x-64)/factor)
	var center_offset=0.0
	if grid_open:
		var left=build_frame.get_global_rect().end.x+16
		width=minf(width,(size.x-left-22)/factor);center_offset=(left-22)*.5
	shrine_health_dock.offset_left=center_offset-width*.5;shrine_health_dock.offset_right=center_offset+width*.5
	var dock_height=106.0
	shrine_health_dock.offset_top=-bottom-dock_height;shrine_health_dock.offset_bottom=-bottom
	shrine_health_dock.pivot_offset=Vector2(width*.5,dock_height)
	painterly_button.text="PAINTERLY: ON" if game.painterly_preview else "PAINTERLY: OFF"
	hint.anchor_left=.5;hint.anchor_right=.5
	var hint_width=minf(760,size.x-2*(22+hero_dock.size.x*factor+24))
	var hint_top=0.0
	if hint_width<320:
		hint_width=minf(760,size.x-44);hint_top=left_hud_bottom+8
	if wave_countdown.visible:hint_top=maxf(hint_top,wave_countdown.get_global_rect().end.y+8)
	if is_instance_valid(master_chief_hud) and master_chief_hud.visible:
		var vitals:Control=master_chief_hud.health.get_parent()
		var visor_hounds=hound_dock.visible and hound_dock.get_parent()==master_chief_hud.health
		vitals.position.y=wave_countdown.get_global_rect().end.y+8 if visor_hounds and wave_countdown.visible else 26.0
		if visor_hounds:hint_top=maxf(hint_top,hound_dock.get_global_rect().end.y+8)
	hint.offset_left=-hint_width*.5;hint.offset_right=hint_width*.5
	hint.offset_top=hint_top
	hint.offset_bottom=hint.offset_top+maxf(48,hint.get_combined_minimum_size().y)
func sync_double_edge_debuff():
	var p=game.player;var camera=get_viewport().get_camera_3d()
	double_edge_debuff.visible=game.playing and not game.transitioning and not view_settings_preview and p.hp>0 and p.double_edge_left>0 and camera!=null
	if not double_edge_debuff.visible:return
	if camera.is_position_behind(p.global_position):double_edge_debuff.hide();return
	var feet=get_global_transform_with_canvas().affine_inverse()*camera.unproject_position(p.global_position)
	var factor:float=game.settings.forest_hud_scale
	double_edge_debuff.scale=Vector2.ONE*factor
	double_edge_debuff.position=feet+Vector2(-double_edge_debuff.size.x*factor*.5,12*factor)
	if not Rect2(Vector2.ZERO,size).encloses(Rect2(double_edge_debuff.position,double_edge_debuff.size*factor)):
		double_edge_debuff.hide();return
	double_edge_amount.text="DEF −%d%%"%roundi(p.double_edge_penalty*100)
	double_edge_time.text="%.1fs"%(ceilf(p.double_edge_left*10)/10)

func sync_beast_master_slot(index:int,prep:bool):
	var selected:Array=game.settings.forest_pet_loadout
	var whole_party=index==Pets.MAX_ACTIVE
	var skin=Pets.skin(selected[index]) if index<selected.size() else -1
	var button=loadout_buttons[index]
	button.disabled=selected.is_empty() if whole_party else skin<0
	button.mouse_filter=Control.MOUSE_FILTER_STOP if prep else Control.MOUSE_FILTER_IGNORE
	var orders:Dictionary=game.army_runtime.beast_pet_orders
	button.set_pressed_no_signal(not orders.is_empty() if whole_party else orders.has(skin))
	var portrait=helper_portraits[index]
	portrait.material=null;portrait.modulate=Color.WHITE
	portrait.texture=Gear.ITEMS["weapon:beast-master"].icon if whole_party else Pets.portrait(skin)
	portrait.visible=not button.disabled
	loadout_cooldowns[index].text=""
	var name_="Attack with all pets" if whole_party else Pets.display_name(skin,game.settings.forest_pet_names) if skin>=0 else "Empty · Choose pets in Q Equipment"
	button.tooltip_text="%d · %s"%[index+1,name_]

func sync():
	if not is_instance_valid(game) or game.model==null:return
	sync_double_edge_debuff()
	var m=game.model;var prep=m.phase=="preparing"
	if not prep or game.ordinary_pause or game.settings_open or game.rogue_roster_open:
		preparation_mode="";build_menu_expanded=false;preparation_tools_open=false
	respawn_notice.visible=game.respawn_left>0 and game.playing and m.phase=="wave" and not game.ordinary_pause and not game.settings_open and not is_instance_valid(overlay)
	if respawn_notice.visible:respawn_notice.text="Respawning in %d"%ceili(game.respawn_left)
	bar_paper.visible=prep and not view_settings_preview and not is_instance_valid(overlay)
	preparation_header.visible=bar_paper.visible and game.playing and not game.ordinary_pause and not game.settings_open and not game.rogue_roster_open
	build_frame.visible=preparation_header.visible and build_menu_expanded
	build_bar.visible=build_frame.visible
	start_wave_button.text="START" if m.falan_area.is_empty() else "EXPLORE"
	start_wave_button.visible=preparation_header.visible
	preparation_actions.visible=preparation_header.visible and preparation_tools_open
	map_size_controls.visible=m.terrain_source=="wind_meadow" and m.terrain_detail!=m.Arena.ID
	map_size_label.text="Resizing…" if game.map_resize_pending else "Map %s×"%str(m.map_expansion)
	map_size_label.tooltip_text="Width and length relative to this map's original size · %.2f× area"%(m.map_expansion*m.map_expansion)
	smaller_map_button.disabled=game.map_resize_pending or m.map_expansion==1.0
	bigger_map_button.disabled=game.map_resize_pending or m.map_expansion==m.WindMeadowTerrain.EXPANSIONS.back()
	wave_countdown.visible=game.playing and game.FalanTour.area(m).is_empty() and m.phase in ["preparing","wave"] and not is_instance_valid(overlay) and not game.settings_open and not game.rogue_roster_open
	wave_countdown.text=m.waves.countdown_text()
	var icon_loadout=sync_character()
	if is_instance_valid(master_chief_hud):master_chief_hud.sync()
	hero_dock.visible=not is_instance_valid(overlay) and not (is_instance_valid(master_chief_hud) and master_chief_hud.visible and game.player.spell_loadout.assignments(18).is_empty())
	sync_hound_health()
	sync_pet_passives()
	sync_hud_layout(prep)
	enemy_minimap.set_active(game.playing and m.phase=="wave" and (not game.paused or view_settings_preview) and not game.transitioning and not game.won and game.player.hp>0 and not is_instance_valid(overlay) and not game.rogue_roster_open and (not game.settings_open or view_settings_preview))
	# Combat captures the cursor for aiming; mouse selection belongs to the building map.
	var icon_defaults=game.player.spell_loadout.Catalog.defaults(game.player.character_id)
	var beast_master:bool=game.player.spell_loadout.beast_master_equipped()
	for i in game.player.spell_loadout.numbered_slots.size():
		var slot:Array=game.player.spell_loadout.numbered_slots[i]
		var button=loadout_buttons[i]
		if beast_master:
			sync_beast_master_slot(i,prep)
			continue
		var recovery=i==5 and icon_loadout.get("special_6","")==game.player.spell_loadout.Catalog.RECOVERY
		var action=game.player.spell_loadout.Catalog.SLOTS.keys()[i]
		var spec:Dictionary=game.player.spell_loadout.Catalog.all().get(icon_loadout.get(action,""),{})
		var weapon_locked=not game.player.spell_loadout.Catalog.weapon_compatible(spec,game.player.model)
		button.disabled=slot.is_empty() or weapon_locked
		helper_portraits[i].modulate=Color(.35,.35,.35,.65) if weapon_locked else Color.WHITE
		button.mouse_filter=Control.MOUSE_FILTER_STOP if prep else Control.MOUSE_FILTER_IGNORE
		var kagerou=slot.size()==2 and slot[0]==game.player.spell_loadout.Catalog.KAGEROU_NAME
		var maze_slot=not slot.is_empty() and i==0 and Roster.has_crossgate_throws(game.player.character_id) and not game.player.model.gear_external and not icon_loadout.has("equip")
		var assassination=maze_slot and not game.player.model.daggers
		var shin_sure=slot.size()==2 and slot[0]==game.player.spell_loadout.Catalog.SHIN_SURE_STRIKE_NAME
		var shin_double_edge=slot.size()==2 and slot[0]==game.player.spell_loadout.Catalog.SHIN_DOUBLE_EDGE_NAME
		var shin_two_birds=slot.size()==2 and slot[0]==game.player.spell_loadout.Catalog.SHIN_TWO_BIRDS_NAME
		var shin_counter=slot.size()==2 and slot[0]==game.player.spell_loadout.Catalog.SHIN_COUNTER_NAME
		var shin_meditation=slot.size()==2 and slot[0]==game.player.spell_loadout.Catalog.SHIN_MEDITATION_NAME
		var combo=slot.size()==2 and slot[0]==game.player.spell_loadout.Catalog.KAZ_COMBO_NAME and not icon_loadout.has(game.player.spell_loadout.Catalog.SLOTS.keys()[i])
		var random_shot=slot.size()==2 and slot[0]==game.player.spell_loadout.Catalog.RANDOM_SHOT_NAME
		var barrage_shadows=slot.size()==2 and slot[0]==game.player.spell_loadout.Catalog.BARRAGE_SHADOWS_NAME
		var shin_combo=combo and game.player.model.fighter.get("weapon_skills",false)
		var enabled:bool=game.player.spell_loadout.held_numbers.has(i+1)
		if shin_counter:enabled=game.player.active_ability.shin_counter_armed
		if kagerou:enabled=game.player.active_ability.kagerou_enabled
		elif assassination:enabled=game.player.active_ability.assassinating()
		button.set_pressed_no_signal(enabled)
		helper_portraits[i].hide()
		var kazi_combo=combo and not shin_combo
		var blade_dance=maze_slot and not assassination
		var cooldown=game.player.spell_loadout.cooldown_for(action) if icon_loadout.has(action) else 0.0
		if kazi_combo or blade_dance or shin_combo:cooldown=game.player.active_ability.combo_cooldown
		elif random_shot:cooldown=game.player.active_ability.random_shot_cooldown
		elif barrage_shadows:cooldown=game.player.active_ability.shadow_mirror_cooldown()
		elif shin_sure:cooldown=game.player.active_ability.shin_sure_cooldown
		elif shin_double_edge:cooldown=game.player.active_ability.shin_double_edge_cooldown
		elif shin_two_birds:cooldown=game.player.active_ability.shin_two_birds_cooldown
		elif shin_meditation:cooldown=game.player.active_ability.shin_meditation_cooldown
		if game.player.character_id==33 and i<3 and not icon_loadout.has(action):
			var kit=game.player.active_ability
			cooldown=[kit.bolt_cooldown,kit.clap_cooldown,kit.avatar_cooldown][i]
		loadout_cooldowns[i].text=("ON" if enabled else "OFF") if kagerou else ("%.1fs"%cooldown if cooldown>.05 else "")
		if shin_counter:
			var rate:float=game.player.active_ability.shin_counter_rate()
			loadout_cooldowns[i].text="Spear" if not enabled else ("%.2f×"%rate if rate>1.0 else "Passive")
		var spell_id=icon_loadout.get(action,icon_defaults.get(action,""))
		if game.player.character_id==33 and i==2 and not icon_loadout.has(action):spell_id="mountain-king/avatar"
		var taunt_icon=game.player.character_id==33 and i==3 and not icon_loadout.has(action)
		if taunt_icon:spell_id="mountain-king/avatar"
		if kagerou:
			helper_portraits[i].material=null;helper_portraits[i].texture=game.player.spell_loadout.Catalog.KAGEROU_ICON;helper_portraits[i].show()
		elif barrage_shadows:
			helper_portraits[i].material=null;helper_portraits[i].texture=game.player.spell_loadout.Catalog.KAZI_ICONS[game.player.spell_loadout.Catalog.BARRAGE_SHADOWS];helper_portraits[i].show()
		elif random_shot:
			helper_portraits[i].material=null;helper_portraits[i].texture=SHIN_STANCE_ICONS.bow;helper_portraits[i].show()
		elif slot.size()==2 and slot[0]=="召喚穴熊":
			helper_portraits[i].material=null;helper_portraits[i].texture=game.player.spell_loadout.Catalog.KAZI_ICONS[game.player.spell_loadout.Catalog.BEARS];helper_portraits[i].show()
		elif kazi_combo or shin_combo:
			helper_portraits[i].material=null;helper_portraits[i].texture=game.player.spell_loadout.Catalog.KAZ_COMBO_ICON;helper_portraits[i].show()
		elif shin_sure or shin_double_edge or shin_two_birds or shin_counter or shin_meditation:
			helper_portraits[i].material=null
			if shin_sure:helper_portraits[i].texture=preload("res://assets/characters/crossgate/shin/sure-strike-icon.png")
			elif shin_double_edge:helper_portraits[i].texture=preload("res://assets/characters/crossgate/shin/double-edge-icon.png")
			elif shin_two_birds:helper_portraits[i].texture=preload("res://assets/characters/crossgate/shin/two-birds-icon.png")
			elif shin_meditation:helper_portraits[i].texture=preload("res://assets/characters/crossgate/shin/meditation-icon.png")
			else:helper_portraits[i].texture=preload("res://assets/characters/crossgate/shin/counter-icon.png")
			helper_portraits[i].show()
		elif maze_slot:
			helper_portraits[i].material=null;helper_portraits[i].texture=MAZE_ASSASSINATION if assassination else MAZE_DAGGER;helper_portraits[i].show()
		elif MOUNTAIN_ICONS.has(spell_id):
			helper_portraits[i].material=TAUNT_ICON_MATERIAL if taunt_icon else null;helper_portraits[i].texture=MOUNTAIN_ICONS[spell_id];helper_portraits[i].show()
		elif game.player.spell_loadout.Catalog.KAZI_ICONS.has(spell_id):
			helper_portraits[i].material=null;helper_portraits[i].texture=game.player.spell_loadout.Catalog.KAZI_ICONS[spell_id];helper_portraits[i].show()
		button.tooltip_text="%d · %s"%[i+1,"Empty · Equip in Equipment → Skills" if slot.is_empty() else slot[0]]
		if kagerou:button.tooltip_text+="\n"+game.player.spell_loadout.Catalog.KAGEROU_DESCRIPTION
		elif kazi_combo:button.tooltip_text+="\n"+game.player.spell_loadout.Catalog.KAZ_COMBO_DESCRIPTION+" Invulnerable while charging and striking."
		elif random_shot:button.tooltip_text+="\nRequires an active Bow. Original shine, then rapid arrows at visible targets. Solid cover blocks arrows. 5s cooldown."
		elif barrage_shadows:
			button.tooltip_text+="\nRequires an active Bow. Each cast adds stationary shadows for 30s that fire using your current 亂射 level. Solid cover blocks arrows."
			button.tooltip_text+=" No cooldown while BW033 is active." if game.player.accessory_bonuses.get("barrage_shadows_max",0)>0 else " 22s cooldown."
		elif shin_combo:button.tooltip_text+="\nBlink and strike nearby enemies. Invulnerable while charging and striking."
		elif shin_sure:button.tooltip_text+="\nEmpower the normal weapon or arrow contact. Explosions show confirmed hits and add no extra damage. 5s cooldown."
		elif shin_double_edge:button.tooltip_text+="\n"+game.player.spell_loadout.Catalog.all()[game.player.spell_loadout.Catalog.DOUBLE_EDGE].description
		elif shin_two_birds:button.tooltip_text+="\nStrike the front enemy, then deal heavier damage in a wide sweep behind it."
		elif shin_counter:button.tooltip_text+="\n"+game.player.spell_loadout.Catalog.all()[game.player.spell_loadout.Catalog.COUNTER].description
		elif shin_meditation:button.tooltip_text+="\n"+game.player.spell_loadout.Catalog.all()[game.player.spell_loadout.Catalog.MEDITATION].description
		elif spell_id==game.player.spell_loadout.Catalog.GUARD_BREAK:button.tooltip_text+="\n"+spec.description
		elif slot.size()==2 and slot[0]=="召喚穴熊":button.tooltip_text+="\n"+game.player.spell_loadout.Catalog.all()[game.player.spell_loadout.Catalog.BEARS].description
		elif assassination:button.tooltip_text="1 · "+game.player.spell_loadout.Catalog.ASSASSINATION_NAME+"\n"+game.player.spell_loadout.Catalog.ASSASSINATION_DESCRIPTION
		elif blade_dance:button.tooltip_text="1 · "+game.player.spell_loadout.Catalog.BLADE_DANCE_NAME+"\n"+game.player.spell_loadout.Catalog.BLADE_DANCE_DESCRIPTION
		elif recovery:button.tooltip_text=slot[0]+"\n"+game.player.spell_loadout.Catalog.all()[spell_id].description
		if Roster.is_crossgate_fighter(game.player.character_id) and not slot.is_empty():
			var native_id:String=Roster.crossgate_profile(game.player.character_id).id+"/"
			if random_shot:spell_id=native_id+"random-shot"
			elif barrage_shadows:spell_id="lancelot/barrage-shadows"
			elif combo:spell_id=native_id+"combo"
			elif shin_sure:spell_id="shin/sure-strike"
			elif shin_double_edge:spell_id=game.player.spell_loadout.Catalog.DOUBLE_EDGE
			elif shin_two_birds:spell_id=native_id+"two-birds"
			elif shin_counter:spell_id=game.player.spell_loadout.Catalog.COUNTER
			elif assassination:spell_id=native_id+"assassination"
			elif blade_dance:spell_id=native_id+"blade-dance"
			elif kagerou:spell_id="kazi/kagerou"
			var cost=game.player.spell_loadout.Catalog.mana_description(spell_id)
			if not cost.is_empty():button.tooltip_text+="\n"+cost
			var skills=preload("res://scripts/spells/skill_balance.gd")
			var detail=skills.summary(game.player,spell_id)
			if not detail.is_empty():
				button.tooltip_text+="\n"+detail
				if loadout_cooldowns[i].text.is_empty():loadout_cooldowns[i].text="Lv %d"%skills.level_for(game.player,spell_id)
		if taunt_icon:button.tooltip_text+=" · Attracts reachable enemies for 8 seconds"
		if weapon_locked:
			button.set_pressed_no_signal(false)
			loadout_cooldowns[i].text="Locked"
			button.tooltip_text+="\nLocked · Requires an active "+str(Gear.ITEMS.get("weapon:"+str(spec.required_weapon),{}).get("name",str(spec.required_weapon).capitalize()))
		loadout_cooldowns[i].position=Vector2(0,14) if cooldown>.05 else Vector2(1,0)
		loadout_cooldowns[i].horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER if cooldown>.05 else HORIZONTAL_ALIGNMENT_LEFT
		if cooldown>.05 and not weapon_locked:helper_portraits[i].modulate=Color(.5,.5,.5,1)

	var shrine=m.shrine()
	shrine_health_bar.visible=not shrine.is_empty();shrine_health_label.visible=shrine_health_bar.visible
	if not shrine.is_empty():
		shrine_health_bar.max_value=shrine.max_hp;shrine_health_bar.value=shrine.hp
		shrine_health_label.text="Statue  ·  %d / %d"%[shrine.hp,shrine.max_hp]
		if m.base_invulnerable:shrine_health_label.text+="  ·  INVULNERABLE"
	var progression=m.team_progression
	team_level_label.text=str(progression.level)
	if progression.level==progression.MAX_LEVEL:
		team_level_label.tooltip_text="LV %d · MAX LEVEL"%progression.level
	else:
		team_level_label.tooltip_text="LV %d · %s / %d XP"%[progression.level,String.num(progression.experience(),1),progression.kills_required()]
	team_level_label.tooltip_text+="\nEach level grants 20 maximum HP, 3% damage, 2 defense and 1 upgrade point. Press Q for Equipment and Upgrades."
	team_xp_bar.max_value=1.0;team_xp_bar.value=progression.progress()
	shrine_health_dock.visible=not shrine.is_empty() and not is_instance_valid(overlay)
	var text_=""
	if prep and is_instance_valid(game.explorer_helpers) and game.explorer_helpers.placement_active():text_=game.explorer_helpers.placement_hint
	if prep and not game.build_kind.is_empty():text_="%s  ·  %s  ·  T rotate  ·  Esc exit"%[LABELS[game.build_kind],game.placement_hint]
	if not prep and m.workforce.held:
		var count=0
		for w in m.workers.values():
			if w.follow:count+=1
		text_="%d following · Release V: %d mine / %d repair / %d wait"%[count,job_preview.mine,job_preview.repair,job_preview.idle]
	hint.text=message if message_left>0 and not m.workforce.held else ("" if prep and game.build_kind.is_empty() and (build_menu_expanded or guard_shop_open()) else text_)
	hint.visible=not view_settings_preview and not hint.text.is_empty() and not is_instance_valid(overlay)
	inspection.visible=prep and not view_settings_preview and m.buildings.has(selected_id) and game.build_kind.is_empty() and not is_instance_valid(overlay)
	if inspection.visible:
		var b: Dictionary=m.buildings[selected_id]
		inspect_text.text="%s\nHP  %d / %d"%["Goemon statue" if b.kind=="shrine" else LABELS[b.kind],b.hp,b.max_hp]
		if b.kind in ["tower","cannon_tower"]:inspect_text.text+="\nAutomatic · No workers needed\n%d shots per volley"%m.balance.tower_workers
		else:inspect_text.text+="\nCrew  %d / %d"%[m.workforce.count_job(b.id),m.workforce.capacity(b)]
		if b.kind=="wall":inspect_text.text+="\nIndestructible · No repairs needed"
		elif b.kind in ["gate","shrine","barracks"]:
			inspect_text.text+="\nAuto repair · 1 ryo / 10 HP"
			if b.get("breached",false) and not b.get("freyja_arch",false):inspect_text.text+="\nDoor rebuilt · Waiting for a clear passage" if b.hp>=b.max_hp else "\nDoor destroyed · Workers rebuild this entrance"
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
	if not subtitle.is_empty():
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


func _physics_process(_delta:float):
	attack_pointer_active=false
	patrol_target.hide()
	sync_pet_focus_marker()
	var locked=sync_primary_target_marker()
	sync_shin_combo()
	if not is_visible_in_tree() or not crosshair_visible() or game.paused or game.enemies.is_empty():return
	var hit:Dictionary=game.crosshair_ray_hit()
	attack_pointer_active=game.aimed_enemy_shows_attack_pointer(hit)
	var enemy=locked if locked!=null else hit.get("collider") as Ninja
	if enemy==null or enemy.dead or enemy.hp<=0 or not "forest_id" in enemy:return
	var row:Dictionary=game.model.enemies.get(enemy.forest_id,{})
	if not row.has("level"):return
	patrol_target.text="%s · Lv.%d"%[row.enemy_name,row.level]
	var position_=game.crosshair_screen_position()+Vector2(24,24)
	if locked!=null:
		var text_size=patrol_target.get_minimum_size()
		position_=primary_target_marker.position+Vector2((primary_target_marker.size.x-text_size.x)*.5,-text_size.y)
	patrol_target.position=position_.clamp(Vector2(8,8),size-Vector2(340,64))
	patrol_target.show()

func sync_pet_focus_marker():
	sync_target_marker(pet_focus_marker,game.army_runtime.focused_enemy())

func sync_primary_target_marker()->Ninja:
	var locked:Ninja
	var enemy:Ninja
	if combat_indicators_visible() and Roster.is_crossgate_fighter(game.player.character_id):
		locked=game.player.active_ability.locked_primary_enemy()
		enemy=locked if locked!=null else game.player.active_ability.selected_primary_enemy()
	var lift=primary_target_marker.size.y+4.0 if enemy!=null and pet_focus_marker.visible and game.army_runtime.focused_enemy()==enemy else 0.0
	sync_target_marker(primary_target_marker,enemy,lift)
	return locked if primary_target_marker.visible else null

func combat_indicators_visible()->bool:
	return is_visible_in_tree() and game.playing and game.model.phase=="wave" and not game.paused and not game.transitioning and game.player.hp>0

func sync_target_marker(marker:TextureRect,enemy,lift:float=0.0):
	marker.hide()
	if not combat_indicators_visible():return
	if not is_instance_valid(enemy) or enemy.dead or not game.forest_enemy_visible(enemy):return
	var bounds:AABB=enemy.combat_bounds()
	var point=Vector3(bounds.get_center().x,bounds.end.y+.5,bounds.get_center().z)
	var camera:Camera3D=game.camera_rig.camera
	if camera.is_position_behind(point):return
	var screen=camera.unproject_position(point)
	if not get_viewport_rect().has_point(screen):return
	marker.position=(screen-Vector2(marker.size.x*.5,marker.size.y+96+lift)).clamp(Vector2(4,4),size-marker.size-Vector2(4,4))
	marker.show()

func sync_shin_combo():
	var hero=game.player
	var count=0
	if combat_indicators_visible() and Roster.is_crossgate_fighter(hero.character_id):
		count=hero.active_ability.primary_combo_hits
	if count<=0:
		shin_combo_row.hide()
		return
	if shin_combo_shown!=count:
		shin_combo_shown=count
		shin_combo_glyphs.clear()
		if count==10:
			shin_combo_glyphs.append(10)
		else:
			for digit in str(count):shin_combo_glyphs.append(int(digit))
		var width=2*(shin_combo_glyphs.size()-1)
		for glyph in shin_combo_glyphs:width+=int(HIT_COMBO_NUMBER_REGIONS[glyph].size.x)
		shin_combo_number.size=Vector2(width,29)
		shin_combo_number.queue_redraw()
		shin_combo_word.position.x=width+8
		shin_combo_row.offset_left=-24-shin_combo_word.position.x-shin_combo_word.size.x
	shin_combo_row.show()

func draw_shin_combo_number():
	var x=0.0
	for glyph in shin_combo_glyphs:
		var region:Rect2=HIT_COMBO_NUMBER_REGIONS[glyph]
		var atlas=HIT_COMBO_SPLIT_DIGITS if glyph<2 else HIT_COMBO_ATLAS
		shin_combo_number.draw_texture_rect_region(atlas,Rect2(Vector2(x,0),region.size),region)
		x+=region.size.x+2

func crosshair_visible()->bool:
	return game!=null and game.player.character_id!=Roster.MASTER_CHIEF_ID and game.settings.forest_show_crosshair and game.playing and game.model.phase=="wave" and (not game.paused or view_settings_preview) and not game.transitioning and not game.won and game.player.hp>0
func _draw_crosshair():
	if not crosshair_visible():return
	# Both sprites put the bright tip at the centre of texel (1, 1).
	var aim=reticle.make_canvas_position_local(game.crosshair_screen_position())
	var pointer=ATTACK_POINTER if attack_pointer_active and not game.paused else AIM_POINTER
	reticle.draw_texture(pointer,aim-POINTER_HOTSPOT)
