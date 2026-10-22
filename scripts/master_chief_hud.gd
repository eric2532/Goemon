extends Control
## Chief's visor information is active only during his first-person combat.
const Roster=preload("res://scripts/rogue_roster.gd")
const CYAN=Color("b5e7f1")
var game
var title:Label
var ammo:Label
var instructions:Label
var health:ProgressBar
var health_value:Label
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var weapon=Control.new();weapon.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(weapon)
	weapon.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon.offset_left=-425;weapon.offset_right=-34;weapon.offset_top=-136;weapon.offset_bottom=-28
	title=make_label(weapon,"ROCKET LAUNCHER",17,Vector2.ZERO)
	title.add_theme_color_override("font_color",CYAN)
	ammo=make_label(weapon,"∞  AMMO",31,Vector2(0,23));ammo.name="ChiefAmmo"
	instructions=make_label(weapon,"HOLD LMB · FIRE",13,Vector2(0,67))
	make_label(weapon,"1 ROCKET · 2 PISTOL · 3 SHOTGUN · 4 RIFLE · 5 SWORD",12,Vector2(0,87))
	var vital=Control.new();vital.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(vital)
	vital.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	vital.offset_left=-150;vital.offset_right=150;vital.offset_top=26;vital.offset_bottom=72
	var name_label=make_label(vital,"SPARTAN-117",12,Vector2.ZERO)
	name_label.add_theme_color_override("font_color",CYAN)
	health_value=make_label(vital,"",12,Vector2(198,0));health_value.size.x=102;health_value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	health=ProgressBar.new();health.name="ChiefHealth";health.show_percentage=false;health.position=Vector2(0,23);health.size=Vector2(300,9);health.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var background=StyleBoxFlat.new();background.bg_color=Color(.02,.09,.13,.65);background.border_color=Color(.5,.8,.9,.3);background.set_border_width_all(1)
	var fill=StyleBoxFlat.new();fill.bg_color=Color(.55,.85,.94,.85)
	health.add_theme_stylebox_override("background",background);health.add_theme_stylebox_override("fill",fill);vital.add_child(health)
	sync()
func make_label(parent:Node,words:String,point_size:int,position_:Vector2)->Label:
	var label=Label.new();label.text=words;label.position=position_;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",point_size);label.add_theme_color_override("font_color",Color("deeff0"))
	label.add_theme_color_override("font_shadow_color",Color(.01,.04,.06,.9));label.add_theme_constant_override("shadow_outline_size",3)
	parent.add_child(label);return label
func active()->bool:
	return is_instance_valid(game) and is_instance_valid(game.player) and game.player.character_id==Roster.MASTER_CHIEF_ID and game.playing and game.model.phase=="wave" and not game.paused and not game.ordinary_pause and not game.settings_open and not game.rogue_roster_open and not game.transitioning and not game.won and game.player.hp>0
func sync():
	visible=active()
	if not visible:return
	title.text=preload("res://scripts/master_chief_weapons.gd").data(game.player.master_chief_combat.weapon_slot).label
	var melee=game.player.master_chief_combat.weapon_slot==5
	ammo.text="PLASMA BLADE" if melee else "∞  AMMO"
	instructions.text="LMB · SWING" if melee else "HOLD LMB · FIRE"
	health.max_value=game.player.max_hp;health.value=game.player.hp
	health_value.text="%d / %d"%[ceili(game.player.hp),ceili(game.player.max_hp)]
	queue_redraw()
func _draw():
	if not active():return
	var center=size*.5
	var tint=Color(.56,.84,.94,.22)
	# Short visor edges frame the view without covering the battlefield.
	for side in [-1.0,1.0]:
		var edge=center+Vector2(side*(size.x*.5-22),0)
		draw_line(edge+Vector2(0,-size.y*.21),edge+Vector2(0,size.y*.23),tint,1.0,true)
	var combat=game.player.get("master_chief_combat")
	var firing=combat!=null and bool(combat.get("is_firing"))
	var gap=(24.0 if combat!=null and combat.weapon_slot==3 else 8.0)+(3.0 if firing else 0.0)
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		draw_line(center+direction*gap,center+direction*(gap+7),Color(.01,.03,.05,.9),4,true)
		draw_line(center+direction*gap,center+direction*(gap+7),CYAN,1.5,true)
	draw_circle(center,1.4,CYAN)
	if combat!=null and float(combat.get("hit_marker_timer"))>0:
		for direction in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
			draw_line(center+direction*12,center+direction*18,Color("ff9d68") if combat.headshot_marker_timer>0 else Color(1,.92,.62),2.0,true)
