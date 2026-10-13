extends Control
var game
var title: Label
var resources: Label
var status: Label
var hint: Label
var health: Label
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
	title=label_at("FOREST SHRINE",Vector2(28,20),28)
	status=label_at("",Vector2(30,58),17)
	resources=label_at("",Vector2.ZERO,23);resources.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);resources.offset_left=-420;resources.offset_right=-30;resources.offset_top=24;resources.offset_bottom=64;resources.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	health=label_at("",Vector2(30,88),16)
	bar_paper=Panel.new();bar_paper.name="BuildPaper";bar_paper.add_theme_stylebox_override("panel",style(Color("243c34"),Color("8d8967")));add_child(bar_paper)
	bar_paper.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);bar_paper.offset_left=16;bar_paper.offset_right=-16;bar_paper.offset_top=-130;bar_paper.offset_bottom=-16
	build_bar=HBoxContainer.new();build_bar.name="BuildBar";build_bar.add_theme_constant_override("separation",9);add_child(build_bar)
	build_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);build_bar.offset_left=30;build_bar.offset_right=-30;build_bar.offset_top=-117;build_bar.offset_bottom=-29
	for kind in ["mine","tower","wall","gate"]:
		var b=make_button("%s\n%d gold"%[LABELS[kind],game.model.COSTS[kind]],game.select_build.bind(kind),190)
		b.name=kind.capitalize();b.icon=icon(kind);b.expand_icon=true;b.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT;b.add_theme_constant_override("icon_max_width",50);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		build_bar.add_child(b)
	var recruit=make_button("Recruit worker\n50 gold",func():
		if game.model.workforce.recruit():game.world.sync(0)
		else:notify("Need 50 gold and room in the 24-worker roster"),160)
	recruit.name="Recruit";build_bar.add_child(recruit)
	var start=make_button("START WAVE  →",game.start_wave,205);start.name="StartWave";start.add_theme_stylebox_override("normal",style(Color("d2b66e"),Color("cfa555")));build_bar.add_child(start)
	hint=label_at("",Vector2.ZERO,18);hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);hint.offset_left=30;hint.offset_right=-30;hint.offset_top=-169;hint.offset_bottom=-139
	inspection=PanelContainer.new();inspection.name="Inspection";inspection.add_theme_stylebox_override("panel",style(PAPER));add_child(inspection)
	inspection.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);inspection.offset_left=-300;inspection.offset_right=-24;inspection.offset_top=136
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",9);inspection.add_child(column)
	inspect_text=Label.new();inspect_text.add_theme_color_override("font_color",INK);inspect_text.add_theme_font_size_override("font_size",18);column.add_child(inspect_text)
	for data in [["Assign idle workers",func():game.model.workforce.assign_idle(selected_id)],["Recall assigned workers",func():
		for w in game.model.workers.values():
			if w.job==selected_id:game.model.workforce.leave_tower(w);w.job=-1;w.state="idle";w.path=[]],["Repair building",func():
		if not game.model.repair(selected_id):notify("Nothing to repair, or not enough gold")],["Remove · 50% refund",func():
		if game.model.demolish(selected_id):selected_id=-1;game.world.sync(0)]]:
		var b=make_button(data[0],data[1],240);b.custom_minimum_size.y=42;column.add_child(b)
	inspection.hide();sync()
func notify(text_: String):message=text_;message_left=4.0
func sync():
	if not is_instance_valid(game) or game.model==null:return
	var m=game.model;var prep=m.phase=="preparing"
	build_bar.visible=prep and not is_instance_valid(overlay);bar_paper.visible=build_bar.visible
	var wounded=0
	for w in m.workers.values():
		if w.state=="wounded":wounded+=1
	resources.text="%d GOLD    ·    %d WORKERS"%[m.gold,m.workers.size()-wounded]
	status.text="PREPARATION %02d / 05  ·  Plan, build, then begin"%mini(5,m.wave+1) if prep else "WAVE %02d / 05  ·  %d enemies remaining"%[m.wave,m.enemies.size()+m.waves.pending]
	health.text="Shrine %d / 1000    ·    Goemon %d / %d"%[m.shrine().get("hp",0),game.player.hp,game.player.max_hp]
	if wounded:health.text+="    ·    %d wounded until preparation"%wounded
	var text_="Choose a building below  ·  WASD / middle drag to pan  ·  Wheel to zoom" if prep else "WASD move  ·  LMB attack  ·  RMB heavy  ·  C evade  ·  Hold V to gather workers, release near a job"
	if prep and not game.build_kind.is_empty():text_="%s  ·  %s  ·  R rotate  ·  Right-click cancel"%[LABELS[game.build_kind],game.placement_hint]
	if not prep and m.workforce.held:
		var count=0
		for w in m.workers.values():
			if w.follow:count+=1
		text_="%d following · Release V: %d mine / %d tower / %d repair / %d wait"%[count,job_preview.mine,job_preview.tower,job_preview.repair,job_preview.idle]
	hint.text=message if message_left>0 and not m.workforce.held else text_
	hint.offset_top=-169 if prep else -48;hint.offset_bottom=-139 if prep else -16
	inspection.visible=prep and m.buildings.has(selected_id) and game.build_kind.is_empty() and not is_instance_valid(overlay)
	if inspection.visible:
		var b: Dictionary=m.buildings[selected_id]
		inspect_text.text="%s\n\nHealth  %d / %d\nWorkers assigned  %d"%["Forest Shrine" if b.kind=="shrine" else LABELS[b.kind],b.hp,b.max_hp,m.workforce.count_job(b.id)]
		if b.kind=="mine":inspect_text.text+="\nGold remaining  %d"%m.deposits.get(b.cell,0)
func show_overlay(title_: String,subtitle: String,resume_: bool):
	if is_instance_valid(overlay):overlay.queue_free()
	overlay=PanelContainer.new();overlay.name="PausePanel";overlay.add_theme_stylebox_override("panel",style(PAPER));add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER);overlay.offset_left=-255;overlay.offset_right=255;overlay.offset_top=-195;overlay.offset_bottom=195
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",12);overlay.add_child(column)
	var heading=Label.new();heading.text=title_;heading.add_theme_color_override("font_color",INK);heading.add_theme_font_size_override("font_size",30);column.add_child(heading)
	var sub=Label.new();sub.text=subtitle;sub.add_theme_color_override("font_color",INK);sub.add_theme_font_size_override("font_size",17);column.add_child(sub)
	if resume_:column.add_child(make_button("Resume",game.resume,440))
	column.add_child(make_button("Restart Forest Shrine",game.restart_area,440));column.add_child(make_button("Main menu",game.show_main_menu,440))
func close_overlay():
	if is_instance_valid(overlay):overlay.queue_free()
	overlay=null
func _process(delta):
	message_left=maxf(0,message_left-delta);preview_clock-=delta
	if game.model.workforce.held and preview_clock<=0:
		job_preview=game.model.workforce.preview_jobs(game.player.position);preview_clock=.2
	sync()
