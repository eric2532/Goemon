extends Control
signal loadout_slot_selected(index: int)
var game
var reticle: Control
var status: Label
var hint: Label
var health: Label
var hero_name: Label
var hero_dock: Panel
var enemy_hub: Panel
var resource_hub: Panel
var view_settings_preview=false
var applied_hud_scale=-1.0
var hero_portrait: TextureRect
var loadout_slots: HBoxContainer
var loadout_buttons: Array[Button]=[]
var selected_loadout_slot=-1
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
const ENEMY_CYCLE=[0,1,3]
var primary_icon: TextureRect
var secondary_icon: TextureRect
var attack_cooldowns: Array[Label]=[]
var gold_count: Label
var worker_count: Label
var enemy_counts: Array=[0,0,0,0]
var enemy_count_labels: Array[Label]=[]
var enemy_cards: Array[Control]=[]
var portrait_id=-1
var hud_icons=preload("res://scripts/forest/forest_hud_icons.gd").new()
const Roster=preload("res://scripts/rogue_roster.gd")
var shrine_health_dock: PanelContainer
var shrine_health_label: Label
var shrine_health_bar: ProgressBar
var preparation_actions: HBoxContainer
var build_bar: HBoxContainer
var bar_paper: Panel
var inspection: PanelContainer
var inspect_text: Label
var overlay: PanelContainer
var selected_id=-1
var message=""
var message_left=0.0
var preview_clock=0.0
var job_preview={"mine":0,"tower":0,"repair":0,"idle":0}
const INK=Color("263c35")
const PAPER=Color("e7d9b4")
const LABELS={"mine":"Gold mine","tower":"Watchtower","wall":"Palisade","gate":"Gate"}
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
	var background=StyleBoxFlat.new();background.bg_color=Color("33483e");background.set_corner_radius_all(3)
	var fill=StyleBoxFlat.new();fill.bg_color=color;fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background",background);bar.add_theme_stylebox_override("fill",fill);parent.add_child(bar);return bar
func make_status_hubs():
	var enemies=panel("EnemyHub",Control.PRESET_TOP_LEFT,Rect2(22,20,330,108))
	enemy_hub=enemies
	status=dock_label(enemies,"",Vector2(16,11),13)
	for i in range(4):
		var card=Control.new();card.position=Vector2(16+i*76,40);card.size=Vector2(70,56);card.mouse_filter=Control.MOUSE_FILTER_IGNORE;enemies.add_child(card);enemy_cards.append(card)
		dock_icon(card,hud_icons.get_icon(["raider","archer","giant","runner"][i]),Vector2(0,0),Vector2(31,31))
		var count=dock_label(card,"0",Vector2(35,0),25);count.name="EnemyCount_%d"%i;count.size.x=34;count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;enemy_count_labels.append(count)
		if i==2:count.add_theme_color_override("font_color",Color("f1a58f"))
		var caption=dock_label(card,["Raider","Archer","Giant","Runner"][i],Vector2(0,36),11);caption.size.x=69;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var supplies=panel("ResourceHub",Control.PRESET_TOP_RIGHT,Rect2(-362,20,340,68))
	resource_hub=supplies
	supplies.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	for i in range(2):
		var badge=Panel.new();badge.name="GoldBadge" if i==0 else "WorkerBadge";badge.mouse_filter=Control.MOUSE_FILTER_IGNORE;badge.position=Vector2(0 if i==0 else 232,0);badge.size=Vector2(224 if i==0 else 108,68)
		badge.add_theme_stylebox_override("panel",skin.lacquer());supplies.add_child(badge)
		dock_icon(badge,hud_icons.get_icon("gold" if i==0 else "worker"),Vector2(13,14),Vector2(39,39))
		var count=dock_label(badge,"",Vector2(61,20),24)
		if i==0:gold_count=count;count.name="GoldCount";count.add_theme_color_override("font_color",Color("efd393"))
		else:worker_count=count;count.name="WorkerCount"
	gold_count.tooltip_text="Gold";worker_count.tooltip_text="Available workers"
	make_hero_dock()
func make_hero_dock():
	hero_dock=panel("HeroDock",Control.PRESET_TOP_LEFT,Rect2(22,28,380,84))
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
		dock_icon(tile,skin.texture("mouse_left" if i==0 else "mouse_right"),Vector2(20,44),Vector2(12,16))
	loadout_slots=HBoxContainer.new();loadout_slots.name="LoadoutSlots";loadout_slots.position=Vector2(49,98);loadout_slots.add_theme_constant_override("separation",8);hero_dock.add_child(loadout_slots)
	for i in range(5):
		var button=Button.new();button.name="LoadoutSlot%d"%(i+1);button.text=str(i+1);button.custom_minimum_size=Vector2(50,46)
		button.toggle_mode=true;button.focus_mode=Control.FOCUS_NONE;button.mouse_filter=Control.MOUSE_FILTER_STOP
		button.tooltip_text="Loadout slot %d · Empty"%(i+1);button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size",12)
		for state in ["normal","hover","pressed","hover_pressed"]:
			var box=StyleBoxFlat.new();box.set_corner_radius_all(6);box.set_border_width_all(2 if state in ["pressed","hover_pressed"] else 1)
			box.bg_color=Color("3b4940") if state in ["pressed","hover_pressed"] else Color("172d28")
			box.border_color=Color("edcf87") if state!="normal" else Color("697763")
			box.content_margin_left=7;box.content_margin_right=7;box.content_margin_top=5;box.content_margin_bottom=23
			button.add_theme_stylebox_override(state,box)
			button.add_theme_color_override("font_"+state+"_color" if state!="normal" else "font_color",Color("edcf87"))
		button.pressed.connect(select_loadout_slot.bind(i));loadout_slots.add_child(button);loadout_buttons.append(button)
func select_loadout_slot(index: int):
	if index<0 or index>=loadout_buttons.size() or not is_visible_in_tree() or not game.playing or game.ordinary_pause or game.settings_open or game.rogue_roster_open or is_instance_valid(overlay) or game.model.phase not in ["preparing","wave"]:return
	selected_loadout_slot=index
	for i in range(loadout_buttons.size()):loadout_buttons[i].set_pressed_no_signal(i==index)
	loadout_slot_selected.emit(index)
func _input(event):
	if not is_instance_valid(game) or game.model==null or game.model.phase!="wave":return
	if is_instance_valid(game.map_editor) and game.map_editor.active:return
	if event is InputEventKey and event.pressed and not event.echo and not event.ctrl_pressed and not event.meta_pressed and not event.alt_pressed:
		var code=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		# Observe existing combat shortcuts so an empty loadout never steals an ability.
		if code>=KEY_1 and code<=KEY_5:select_loadout_slot(code-KEY_1)
func sync_character():
	var p=game.player
	if portrait_id!=p.character_id:
		portrait_id=p.character_id
		var primary="pipe";var secondary="wave";var accent=Color("edcf87");class_cooldowns={};cooldown_peaks=[0.0,0.0]
		if p.is_rogue_character():
			var data=Roster.data(p.character_id);hero_name.text=data.name;accent=Color(data.color);class_cooldowns=data.cooldowns
			hero_portrait.texture=Roster.portrait(p.character_id);primary=data.abilities.cutlass.icon;secondary=data.abilities.flintlock.icon
			primary_icon.tooltip_text=data.abilities.cutlass.name;secondary_icon.tooltip_text=data.abilities.flintlock.name
		else:
			hero_name.text="Edo" if p.character_id==2 else "Goemon"
			hero_portrait.texture=load("res://assets/models/characters/goemon_cosplay/portraits/%s.png"%hero_name.text.to_lower())
			if p.character_id==2:primary="fire";secondary="spark";accent=Color("ff956f")
			primary_icon.tooltip_text="Fireballs" if p.character_id==2 else "Pipe combo";secondary_icon.tooltip_text="Giant fireball" if p.character_id==2 else "Heavy strike"
		primary_icon.texture=load(Roster.icon_path(primary));secondary_icon.texture=load(Roster.icon_path(secondary))
		attack_colors=[Color("f2d39a").lerp(accent,.35),Color("a7d9cc").lerp(accent,.25)]
		hero_name.add_theme_color_override("font_color",Color("f6dfb1").lerp(accent,.2))
	if p.character_id==8:
		primary_icon.tooltip_text="Dragon Leap" if not p.is_on_floor() else "Lance Pierce"
		secondary_icon.tooltip_text="Dragon Leap" if not p.is_on_floor() else "Azure Lance Sweep"
	sync_health()
	var sustained=p.character_id==2 and p.active_ability.beam_held
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
func sync_enemies():
	var m=game.model;var waves=m.waves;enemy_counts=[0,0,0,0]
	for e in m.enemies.values():enemy_counts[e.variant]+=1
	var upcoming=[0,0,0,0]
	if m.phase=="preparing" and m.wave<m.balance.waves.size():upcoming=m.balance.waves[m.wave]
	elif waves.pending>0:upcoming=waves.remaining_counts
	for i in range(4):enemy_counts[i]+=upcoming[i]
	for i in range(4):
		enemy_count_labels[i].text=str(enemy_counts[i]);enemy_cards[i].modulate=Color.WHITE if enemy_counts[i]>0 else Color(1,1,1,.38)
	status.text="ENEMIES  ·  WAVE %d / %d%s"%[mini(m.balance.waves.size(),m.wave+1) if m.phase=="preparing" else m.wave,m.balance.waves.size(),"  ·  PREP" if m.phase=="preparing" else ""]
func make_button(text_: String,action: Callable,width: float=150)->Button:
	var button=Button.new();button.text=text_;button.custom_minimum_size=Vector2(width,72)
	button.add_theme_stylebox_override("normal",style(PAPER));button.add_theme_stylebox_override("hover",style(Color("f7edcf")))
	button.add_theme_stylebox_override("pressed",style(Color("b5c4a2"),INK));button.add_theme_stylebox_override("focus",style(Color(0,0,0,0),Color("c39341")))
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:button.add_theme_color_override(state,INK)
	button.add_theme_font_size_override("font_size",18);button.pressed.connect(action);return button
func icon(kind: String)->Texture2D:
	var drawing={
	"mine":"<path d='M12 60 L23 28 43 13 64 29 76 59Z' fill='#818677'/><path d='M25 63V39H58V63M19 35H65M35 61V45H49V61' fill='none'/><path d='M25 27L31 16 39 25 32 34Z M61 43L68 31 75 39 69 48Z' fill='#d3a452'/>",
	"tower":"<path d='M23 71V28M60 71V28M20 49H64M24 68L60 50M27 30L60 46' fill='none'/><path d='M17 29L42 10 69 29Z' fill='#618488'/><path d='M18 31H66V45H18Z' fill='#ac8759'/>",
	"wall":"<path d='M12 68V26L20 15 28 26V68M28 68V24L36 13 44 24V68M44 68V25L52 14 60 25V68M60 68V27L68 16 76 27V68' fill='#aa8455'/><path d='M10 38H77M10 58H77' fill='none'/>",
	"gate":"<path d='M14 69V24H25V69M61 69V24H72V69' fill='#a97d4d'/><path d='M10 18H76V29H10Z' fill='#ad8656'/><path d='M27 35H59V64H27Z M43 35V64M29 38L56 59' fill='none'/>"}[kind]
	var svg="<svg xmlns='http://www.w3.org/2000/svg' width='88' height='80' viewBox='0 0 88 80'><g stroke='#384438' stroke-width='2.3' stroke-linecap='round' stroke-linejoin='round'>"+drawing+"</g></svg>"
	var image=Image.new();image.load_svg_from_string(svg);return ImageTexture.create_from_image(image)
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS;mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	make_status_hubs()
	preparation_actions=HBoxContainer.new();preparation_actions.name="PreparationActions";preparation_actions.position=Vector2(22,140);preparation_actions.add_theme_constant_override("separation",10);add_child(preparation_actions)
	var balance=make_button("Balance",game.show_building_balance,150);balance.name="PreparationBalance";balance.custom_minimum_size.y=46;preparation_actions.add_child(balance)
	var restart=make_button("Instant Restart",game.restart_area,190);restart.name="PreparationRestart";restart.custom_minimum_size.y=46;restart.tooltip_text="Start a fresh run now using your saved balance and selected fighter";preparation_actions.add_child(restart)
	var editor=make_button("Map Editor",game.open_map_editor,150);editor.name="PreparationMapEditor";editor.custom_minimum_size.y=46;preparation_actions.add_child(editor)
	shrine_health_dock=PanelContainer.new();shrine_health_dock.name="ShrineHealthDock";shrine_health_dock.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var health_style=skin.lacquer();health_style.content_margin_top=8;health_style.content_margin_bottom=8
	shrine_health_dock.add_theme_stylebox_override("panel",health_style);add_child(shrine_health_dock)
	shrine_health_dock.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	shrine_health_dock.offset_left=-306;shrine_health_dock.offset_right=-22;shrine_health_dock.offset_top=100;shrine_health_dock.offset_bottom=147
	var health_column=VBoxContainer.new();health_column.add_theme_constant_override("separation",4);shrine_health_dock.add_child(health_column)
	shrine_health_label=dock_label(health_column,"",Vector2.ZERO,12);shrine_health_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	shrine_health_bar=meter(health_column,"ShrineHealthBar",Color("d7b65f"));shrine_health_bar.custom_minimum_size.y=5
	bar_paper=Panel.new();bar_paper.name="BuildPaper";bar_paper.add_theme_stylebox_override("panel",style(Color("243c34"),Color("8d8967")));add_child(bar_paper)
	bar_paper.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);bar_paper.offset_left=16;bar_paper.offset_right=-16;bar_paper.offset_top=-130;bar_paper.offset_bottom=-16
	build_bar=HBoxContainer.new();build_bar.name="BuildBar";build_bar.add_theme_constant_override("separation",9);add_child(build_bar)
	build_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);build_bar.offset_left=30;build_bar.offset_right=-30;build_bar.offset_top=-117;build_bar.offset_bottom=-29
	for kind in ["mine","tower","wall","gate"]:
		var key=["mine","tower","wall","gate"].find(kind)+1
		var b=make_button("%d · %s\n%d gold"%[key,LABELS[kind],game.model.COSTS[kind]],game.select_build.bind(kind),190)
		b.name=kind.capitalize();b.icon=icon(kind);b.expand_icon=true;b.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT;b.add_theme_constant_override("icon_max_width",50);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		build_bar.add_child(b)
	var recruit=make_button("5 · Recruit worker\n50 gold",game.recruit_worker,175)
	recruit.name="Recruit";build_bar.add_child(recruit)
	var start=make_button("START WAVE  →",game.start_wave,205);start.name="StartWave";start.add_theme_stylebox_override("normal",style(Color("d2b66e"),Color("cfa555")));build_bar.add_child(start)
	hint=label_at("",Vector2.ZERO,18);hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);hint.offset_left=30;hint.offset_right=-30;hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.add_theme_color_override("font_shadow_color",Color.BLACK);hint.add_theme_constant_override("shadow_outline_size",3)
	inspection=PanelContainer.new();inspection.name="Inspection";inspection.add_theme_stylebox_override("panel",style(PAPER));add_child(inspection)
	inspection.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);inspection.offset_left=-300;inspection.offset_right=-24;inspection.offset_top=136
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",9);inspection.add_child(column)
	inspect_text=Label.new();inspect_text.add_theme_color_override("font_color",INK);inspect_text.add_theme_font_size_override("font_size",18);column.add_child(inspect_text)
	for data in [["Assign workers here",func():game.model.workforce.assign_workers(selected_id)],["Release to automatic work",func():
		for w in game.model.workers.values():
			if w.job==selected_id:game.model.workforce.leave_tower(w);w.job=-1;w.state="idle";w.path=[]],["Repair building",func():
		if not game.model.repair(selected_id):notify("Nothing to repair, or not enough gold")],["Remove · 50% refund",func():
		if game.model.demolish(selected_id):selected_id=-1;game.world.sync(0)]]:
		var b=make_button(data[0],data[1],240);b.custom_minimum_size.y=42;column.add_child(b)
	inspection.hide();sync()
	reticle=Control.new();reticle.name="FreeReticle";reticle.mouse_filter=Control.MOUSE_FILTER_IGNORE;reticle.z_index=100
	add_child(reticle);reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reticle.draw.connect(_draw_crosshair)
func notify(text_: String):message=text_;message_left=4.0
func sync_hud_layout(prep: bool):
	var factor: float=game.settings.forest_hud_scale
	if factor!=applied_hud_scale:
		applied_hud_scale=factor
		enemy_hub.pivot_offset=Vector2.ZERO;resource_hub.pivot_offset=Vector2(340,0)
		shrine_health_dock.pivot_offset=Vector2(284,0);hero_dock.pivot_offset=Vector2.ZERO
		for hub in [enemy_hub,resource_hub,shrine_health_dock,hero_dock]:hub.scale=Vector2.ONE*factor
	enemy_hub.position.y=28+144*factor+12
	shrine_health_dock.position.y=20+68*factor+12
	inspection.position.y=shrine_health_dock.position.y+47*factor+12
	var bottom=146.0 if prep and not view_settings_preview else 34.0
	preparation_actions.position.y=enemy_hub.position.y+108*factor+12
	hint.offset_bottom=-bottom-10;hint.offset_top=hint.offset_bottom-30
func sync():
	if not is_instance_valid(game) or game.model==null:return
	var m=game.model;var prep=m.phase=="preparing"
	build_bar.visible=prep and not view_settings_preview and not is_instance_valid(overlay);bar_paper.visible=build_bar.visible
	preparation_actions.visible=build_bar.visible and game.playing and not game.ordinary_pause and not game.settings_open and not game.rogue_roster_open
	var wounded=0
	for w in m.workers.values():
		if w.state=="wounded":wounded+=1
	gold_count.text=skin.format_gold(m.gold);worker_count.text=str(m.workers.size()-wounded)
	gold_count.add_theme_font_size_override("font_size",24 if gold_count.text.length()<=10 else 18)
	worker_count.tooltip_text="Available workers"+(" · %d wounded"%wounded if wounded else "")
	sync_character();sync_enemies()
	sync_hud_layout(prep)
	hero_dock.visible=not is_instance_valid(overlay)
	# Combat captures the cursor for aiming; mouse selection belongs to the building map.
	for i in range(loadout_buttons.size()):
		loadout_buttons[i].mouse_filter=Control.MOUSE_FILTER_STOP if prep else Control.MOUSE_FILTER_IGNORE
		loadout_buttons[i].tooltip_text="Loadout slot %d · Empty · %s"%[i+1,"Click to select" if prep else "Press %d"%(i+1)]
	var shrine=m.shrine()
	shrine_health_bar.max_value=shrine.get("max_hp",1);shrine_health_bar.value=shrine.get("hp",0)
	shrine_health_label.text="SHRINE   %d / %d"%[shrine.get("hp",0),shrine.get("max_hp",0)]
	shrine_health_dock.visible=not is_instance_valid(overlay)
	var text_=""
	if prep and not game.build_kind.is_empty():text_="%s  ·  %s  ·  R rotate  ·  Right-click cancel"%[LABELS[game.build_kind],game.placement_hint]
	if not prep and m.workforce.held:
		var count=0
		for w in m.workers.values():
			if w.follow:count+=1
		text_="%d following · Release V: %d mine / %d tower / %d repair / %d wait"%[count,job_preview.mine,job_preview.tower,job_preview.repair,job_preview.idle]
	hint.text=message if message_left>0 and not m.workforce.held else text_
	hint.visible=not view_settings_preview and not hint.text.is_empty() and not is_instance_valid(overlay)
	inspection.visible=prep and not view_settings_preview and m.buildings.has(selected_id) and game.build_kind.is_empty() and not is_instance_valid(overlay)
	if inspection.visible:
		var b: Dictionary=m.buildings[selected_id]
		inspect_text.text="%s\n\nHealth  %d / %d\nWorkers assigned  %d / %d"%["Forest Shrine" if b.kind=="shrine" else LABELS[b.kind],b.hp,b.max_hp,m.workforce.count_job(b.id),m.workforce.capacity(b)]
		if b.kind=="mine":inspect_text.text+="\nGold remaining  %d"%m.deposits.get(b.cell,0)
func show_overlay(title_: String,subtitle: String,resume_: bool):
	if is_instance_valid(overlay):overlay.queue_free()
	overlay=PanelContainer.new();overlay.name="PausePanel";overlay.add_theme_stylebox_override("panel",style(PAPER));add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER);overlay.offset_left=-255;overlay.offset_right=255;overlay.offset_top=-230;overlay.offset_bottom=230
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",12);overlay.add_child(column)
	var heading=Label.new();heading.text=title_;heading.add_theme_color_override("font_color",INK);heading.add_theme_font_size_override("font_size",30);column.add_child(heading)
	var sub=Label.new();sub.text=subtitle;sub.add_theme_color_override("font_color",INK);sub.add_theme_font_size_override("font_size",17);column.add_child(sub)
	if resume_:column.add_child(make_button("Resume",game.resume,440))
	if resume_:
		var settings=make_button("Settings · Camera, HUD & balance",func():game.show_settings(true),440);settings.name="ForestPauseSettings";column.add_child(settings)
	column.add_child(make_button("Restart Forest Shrine",game.restart_area,440));column.add_child(make_button("Main menu",game.show_main_menu,440))
func close_overlay():
	if is_instance_valid(overlay):overlay.queue_free()
	overlay=null
func _process(delta):
	message_left=maxf(0,message_left-delta);preview_clock-=delta
	if game.model.workforce.held and preview_clock<=0:
		job_preview=game.model.workforce.preview_jobs(game.player.position);preview_clock=.2
	sync();animate_health(delta);reticle.queue_redraw()


func crosshair_visible()->bool:
	return game!=null and game.settings.forest_show_crosshair and game.playing and game.model.phase=="wave" and (not game.paused or view_settings_preview) and not game.transitioning and not game.won and game.player.hp>0
func _draw_crosshair():
	if not crosshair_visible():return
	var center: Vector2=game.crosshair_screen_position()
	for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
		reticle.draw_line(center+direction*5,center+direction*12,Color(0,.04,.08,.9),4,true)
		reticle.draw_line(center+direction*5,center+direction*12,Color("ffdb87"),1.5,true)
	reticle.draw_circle(center,2.5,Color(0,.04,.08,.9))
	reticle.draw_circle(center,1.1,Color("ffdb87"))
