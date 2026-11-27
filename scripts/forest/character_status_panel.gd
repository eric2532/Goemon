extends Control
const Icons=preload("res://scripts/forest/forest_hud_icons.gd")
const PANEL_SIZE=Vector2(600,432)
const FONT=preload("res://assets/ui/fonts/oxanium.ttf")
const INTERFACE_FONT=preload("res://assets/ui/fonts/interface.tres")
const Progression=preload("res://scripts/forest/team_progression.gd")
const Skills=preload("res://scripts/spells/skill_balance.gd")
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const BEE_MIRAGE=preload("res://assets/ui/crossgate/skills/bee-mirage.png")
const FAMILY_PASSIVE_ICONS={
 "regeneration":preload("res://assets/ui/crossgate/skills/water-dragon-regeneration.png"),
 "critical_chance":preload("res://assets/ui/crossgate/skills/mantis-critical.png"),
}
const BEE_MIRAGE_NAME="Bee Mirage"
const BEE_MIRAGE_HINT="Each bee in your party grants the player +%d percentage points of dodge chance, up to 100%%."
const PAPER=Color("e5d9a7")
const GOLD=Color("d8bd80")
const INK=Color("181d23")
const CURRENT_STATS=["vitality","regeneration","attack","magic_power","attack_speed","defense","reduction","critical_chance","dodge_chance","counter_chance","magic_defense","accuracy"]
const CURRENT_TITLES=["Maximum health","Health regeneration","Physical damage multiplier","Magic damage multiplier","Attack speed multiplier","Defense","Damage reduction","Critical chance","Dodge chance","Counter chance","Magic defense","Accuracy"]
const CURRENT_FORMATS=["%d","%.1f / sec","x%.2f","x%.2f","x%.2f","%d","%.1f%%","%.1f%%","%.1f%%","%.1f%%","%d","%+.0f"]
const OVERVIEW_FORMATS=["%d","%d / sec","","%d","%d%%","%d","%d%%","%d%%","%d%%","%d%%","%d","%+d"]
const NOTES=["+100 HP / +1 HP per sec","+15% physical damage","+15% base magic damage","+10% attack speed","+10 defense","+10 magic defense","+1% crit (max 100%)","+1% dodge (max 100%)","+1% counter (max 100%)","+1 Accuracy · cancels 1% dodge"]
var game
var embedded=false
var wearer_key=""
var heading_label:Label
var overview_content:Control
var overview_values:Dictionary={}
var attack_damage:Label
var overview_selected=true
var character_stats_content:Control
var pet_stats_content:Control
var pet_health:Label
var pet_health_bar:ProgressBar
var pet_mana:Label
var pet_mana_bar:ProgressBar
var pet_state:Label
var pet_values:Dictionary={}
var pet_summary_icons:Array[TextureRect]=[]
var pet_summary_names:Array[Label]=[]
var pet_summary_levels:Array[Label]=[]
var pet_passive:Control
var pet_passive_icon:TextureRect
var pet_passive_heading:Label
var pet_passive_name:Label
var pet_passive_value:Label
var pet_profile:Dictionary={}
var panel:Control
var font:Font
var point_label:Label
var point_header:Control
var pet_growth_note:Label
var name_label:Label
var level_label:Label
var values:Array[Label]=[]
var ranks:Array[Label]=[]
var stat_icons:Array[TextureRect]=[]
var buttons:Dictionary={}
var tabs:Array[Button]=[]
var content:Control
var stats_content:Control
var skills_content:Control
var skill_ids:Array[String]=[]
var skill_icons:Array[TextureRect]=[]
var skill_names:Array[Label]=[]
var skill_levels:Array[Label]=[]
var skill_buttons:Array[Button]=[]
var pets_content:Control
var pet_choices:Array[String]=[]
var pet_index=0
var pet_name:Label
var pet_selectors:Array[Button]=[]
var pet_skill_ids:Array=[]
var pet_skill_icons:Array[TextureRect]=[]
var pet_skill_names:Array[Label]=[]
var pet_skill_levels:Array[Label]=[]
var pet_skill_buttons:Array[Button]=[]

func text(value:String,x:float,y:float,w:float=64,right:bool=false,color:Color=PAPER,font_size:int=10)->Label:
 var label=Label.new();label.add_theme_font_override("font",font);label.add_theme_font_size_override("font_size",font_size)
 label.add_theme_color_override("font_color",color);label.add_theme_constant_override("outline_size",0)
 label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
 label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.clip_text=true;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 (content if content!=null else panel).add_child(label);label.text=value;label.position=Vector2(x,y);label.size=Vector2(w,font_size+6)
 return label

func fill(rect:Rect2,color:Color):
 var layer=ColorRect.new();layer.position=rect.position;layer.size=rect.size;layer.color=color
 layer.mouse_filter=Control.MOUSE_FILTER_IGNORE;(content if content!=null else panel).add_child(layer)

func icon(id:String,rect:Rect2,title:String)->TextureRect:
 var view=TextureRect.new();view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 view.texture=Icons.STATS["defense" if id=="magic_defense" else id]
 if id=="magic_defense":view.self_modulate=Color("dc9aff")
 view.position=rect.position;view.size=rect.size;view.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 view.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;view.mouse_filter=Control.MOUSE_FILTER_PASS;view.tooltip_text=title
 view.accessibility_name=title
 (content if content!=null else panel).add_child(view);return view

func card(rect:Rect2):
 var control=Panel.new();control.position=rect.position;control.size=rect.size;control.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var style=StyleBoxFlat.new();style.bg_color=Color("202830");style.border_color=Color("485055");style.set_border_width_all(1);style.set_corner_radius_all(3)
 control.add_theme_stylebox_override("panel",style);(content if content!=null else panel).add_child(control)

func button(value:String,rect:Rect2,action:Callable)->Button:
 var control=Button.new();style_button(control)
 control.pressed.connect(action);(content if content!=null else panel).add_child(control)
 control.text=value;control.position=rect.position;control.size=rect.size;return control

func style_button(control:Button):
 control.add_theme_font_override("font",font);control.add_theme_font_size_override("font_size",14)
 for state in ["normal","hover","pressed","disabled"]:
  var style=StyleBoxFlat.new();style.bg_color=Color("1b2229") if state=="disabled" else Color("46515a") if state=="pressed" else Color("37404a") if state=="hover" else Color("25313a")
  style.border_color=Color("475057") if state=="disabled" else GOLD;style.set_border_width_all(1);style.set_corner_radius_all(3)
  control.add_theme_stylebox_override(state,style)
 control.add_theme_stylebox_override("hover_pressed",control.get_theme_stylebox("pressed"))
 for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:control.add_theme_color_override(state,PAPER)
 control.add_theme_color_override("font_disabled_color",Color("69747c"))
 var focus=StyleBoxFlat.new();focus.bg_color=Color.TRANSPARENT;focus.border_color=Color("f8e8bb");focus.set_border_width_all(2);focus.set_corner_radius_all(3)
 control.add_theme_stylebox_override("focus",focus)

func _ready():
 name="CharacterStatusPanel";process_mode=Node.PROCESS_MODE_ALWAYS;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 font=INTERFACE_FONT if embedded else FONT
 if embedded:
  make_equipment_stats();refresh();return
 var shade=ColorRect.new();shade.color=Color(0,0,0,.55);add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 panel=Panel.new();panel.size=PANEL_SIZE;panel.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;add_child(panel)
 var frame=StyleBoxFlat.new();frame.bg_color=INK;frame.border_color=GOLD;frame.set_border_width_all(2);frame.set_corner_radius_all(6)
 frame.shadow_color=Color(0,0,0,.45);frame.shadow_size=14;panel.add_theme_stylebox_override("panel",frame)
 var head=TextureRect.new();head.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;head.texture=game.forest_ui.PaintedHeads.portrait(game.player.character_id,game.settings)
 head.position=Vector2(20,14);head.size=Vector2(48,48);head.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 head.mouse_filter=Control.MOUSE_FILTER_IGNORE;head.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;panel.add_child(head)
 name_label=text("",80,14,300,false,PAPER,22)
 text("LEVEL",81,43,48,false,GOLD,10);level_label=text("",129,39,40,false,PAPER,15)
 icon("point",Rect2(410,20,24,24),"Shared upgrade points for stats, skills and pets")
 point_label=text("",441,14,80,false,GOLD,24);text("AVAILABLE",410,46,114,false,GOLD,10)
 button("×",Rect2(550,19,30,30),game.close_status_panel).tooltip_text="Close (Esc)"
 var pages=[["Stats",show_skills.bind(false)],["Skills",show_skills.bind(true)],["Pets",show_pets]]
 for i in pages.size():
  var tab=button(pages[i][0],Rect2(20+i*120,78,112,30),pages[i][1]);tab.name=pages[i][0]+"Tab";tab.toggle_mode=true;tabs.append(tab)
 tabs[0].set_pressed_no_signal(true)
 fill(Rect2(20,118,560,1),Color("485055"))
 stats_content=Control.new();panel.add_child(stats_content);content=stats_content
 var index=0
 for id in Progression.STAT_NAMES:
  var x=20+(index%2)*180;var y=134+(index/2)*48
  card(Rect2(x,y,172,44))
  stat_icons.append(icon(id,Rect2(x+10,y+6,32,32),Progression.STAT_NAMES[id]+"\n"+NOTES[index]))
  ranks.append(text("",x+52,y+2,63,false,PAPER,23));text("SPENT",x+53,y+27,62,false,GOLD,8)
  var plus=button("+",Rect2(x+132,y+7,30,30),spend.bind(id));plus.name="Spend_"+id
  plus.tooltip_text=Progression.STAT_NAMES[id]+"\nSpend 1 point · "+NOTES[index];buttons[id]=plus
  plus.accessibility_name="Upgrade "+Progression.STAT_NAMES[id];plus.accessibility_description=NOTES[index]
  index+=1
 text("CURRENT VALUES",400,133,180,false,GOLD,11)
 for i in CURRENT_STATS.size():
  var y=157+i*19
  icon(CURRENT_STATS[i],Rect2(400,y,18,18),CURRENT_TITLES[i])
  var value=text("",427,y-1,149,true,PAPER,13);value.mouse_filter=Control.MOUSE_FILTER_PASS;value.tooltip_text=CURRENT_TITLES[i];value.accessibility_name=CURRENT_TITLES[i];values.append(value)
 text("PER LEVEL",20,379,90,false,GOLD,10)
 var bonuses=[["vitality","+20"],["attack","+3%"],["magic_power","+3%"],["defense","+2"],["magic_defense","+2"],["point","+1"]]
 for i in bonuses.size():
  var x=116+i*78
  icon(bonuses[i][0],Rect2(x,377,20,20),"Automatic bonus per level")
  text(bonuses[i][1],x+27,378,60,false,PAPER,13)
 skills_content=Control.new();panel.add_child(skills_content);content=skills_content
 for i in 6:
  var x=20+(i%3)*190;var y=134+(i/3)*120
  card(Rect2(x,y,180,110));text(str(i+1),x+10,y+7,20,false,GOLD,12)
  var view=TextureRect.new();view.position=Vector2(x+66,y+9);view.size=Vector2(48,48)
  view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;view.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  view.mouse_filter=Control.MOUSE_FILTER_IGNORE;skills_content.add_child(view);skill_icons.append(view)
  var label=text("",x+8,y+59,164,false,PAPER,14)
  label.add_theme_font_override("font",INTERFACE_FONT);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;skill_names.append(label)
  skill_levels.append(text("",x+12,y+83,120,false,GOLD,12))
  var plus=button("+",Rect2(x+142,y+75,28,28),spend_skill.bind(i));plus.name="SpendSkill%d"%(i+1);skill_buttons.append(plus)
 text("1 shared point = +1 skill level",20,379,560,false,GOLD,12)
 pets_content=Control.new();panel.add_child(pets_content);content=pets_content
 for i in Pets.MAX_ACTIVE:
  var choice=button(str(i+1),Rect2(20+i*114,132,104,42),select_pet.bind(i));choice.name="PetChoice%d"%(i+1)
  choice.expand_icon=true;choice.add_theme_constant_override("icon_max_width",32);pet_selectors.append(choice)
 pet_name=text("",20,181,560,false,GOLD,15)
 for i in Pets.MAX_SKILLS:
  var y=213+i*52
  card(Rect2(20,y,560,46))
  var view=TextureRect.new();view.position=Vector2(30,y+5);view.size=Vector2(36,36)
  view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;view.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  view.mouse_filter=Control.MOUSE_FILTER_IGNORE;pets_content.add_child(view);pet_skill_icons.append(view)
  var label=text("",80,y+1,448,false,PAPER,14);label.add_theme_font_override("font",INTERFACE_FONT);pet_skill_names.append(label)
  pet_skill_levels.append(text("",80,y+23,448,false,GOLD,12))
  var plus=button("+",Rect2(540,y+8,30,30),spend_pet_skill.bind(i));plus.name="SpendPetSkill%d"%(i+1);pet_skill_buttons.append(plus)
 text("1 shared point = +1 pet skill level · Equip in Q Equipment",20,379,560,false,GOLD,12)
 content=null
 fill(Rect2(20,405,560,1),Color("485055"))
 text("THIS RUN ONLY",20,411,200,false,GOLD,9);text("Esc to close",400,409,180,true,PAPER,11)
 skills_content.hide();pets_content.hide()
 resized.connect(layout);layout();refresh();buttons.vitality.grab_focus()

func layout():
 var factor=minf(1.65,minf((size.x-32)/PANEL_SIZE.x,(size.y-32)/PANEL_SIZE.y))
 panel.scale=Vector2.ONE*factor;panel.position=(size-panel.size*factor)*.5

func make_equipment_stats():
 panel=Panel.new();panel.size=Vector2(340,470);panel.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;add_child(panel)
 var frame=StyleBoxFlat.new();frame.bg_color=INK;frame.border_color=GOLD;frame.set_border_width_all(2);frame.set_corner_radius_all(5)
 panel.add_theme_stylebox_override("panel",frame)
 heading_label=text("PET STATS",16,15,300,false,GOLD,15)
 for i in 2:
  var title="Stats" if i==0 else "Upgrades"
  var tab=button(title,Rect2(16+i*160,10,148,30),show_equipment_tab.bind(i==0))
  tab.name=title+"Tab";tab.toggle_mode=true;tabs.append(tab)
 name_label=text("",16,46,240,false,PAPER,17);level_label=text("",266,46,58,true,GOLD,17)
 name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 point_header=Control.new();panel.add_child(point_header);content=point_header
 icon("point",Rect2(16,73,24,24),"Points for character stat upgrades")
 point_label=text("",49,69,74,false,GOLD,23);text("AVAILABLE STAT POINTS",122,77,202,false,GOLD,11)
 content=null
 pet_growth_note=text("HP, MP and attack grow with each level.",16,77,308,false,GOLD,12);pet_growth_note.hide()
 fill(Rect2(16,106,308,1),Color("485055"))
 overview_content=Control.new();overview_content.name="CombatStats";panel.add_child(overview_content);content=overview_content
 var order=[0,2,3,5,10,1,4,6,7,8,9,11]
 for row in order.size():
  var i:int=order[row]
  var id:String=CURRENT_STATS[i]
  var y=122+row*29
  var title=CURRENT_TITLES[i].trim_suffix(" multiplier")
  if id=="attack":title="Attack damage"
  if id=="magic_power":title="Magic damage"
  var hint=title
  if id=="magic_power":hint+="\nAdded to each magic spell's damage per target."
  if id=="defense":hint+="\nReduces incoming physical damage."
  if id=="magic_defense":hint+="\nReduces incoming magic damage."
  if id=="accuracy":hint+="\nEach point cancels 1 percentage point of enemy dodge. Axes subtract 10. Physical hits only."
  if id=="reduction":hint+="\nPhysical damage reduction from Defense, shown as a percentage."
  icon(id,Rect2(18,y+2,17,17),hint)
  text(title,43,y,199,false,PAPER,14)
  var value=text("",243,y,79,true,PAPER,15)
  value.accessibility_name=title
  if id=="attack":
   attack_damage=value;attack_damage.mouse_filter=Control.MOUSE_FILTER_PASS
  else:overview_values[i]=value
 character_stats_content=Control.new();panel.add_child(character_stats_content);content=character_stats_content
 values.resize(CURRENT_STATS.size())
 var index=0
 for id in Progression.STAT_NAMES:
  var x=16+(index%2)*160;var y=118+(index/2)*57
  card(Rect2(x,y,148,52))
  stat_icons.append(icon(id,Rect2(x+8,y+12,28,28),Progression.STAT_NAMES[id]+"\n"+NOTES[index]))
  values[CURRENT_STATS.find(id)]=text("",x+44,y+3,72,false,PAPER,16)
  ranks.append(text("",x+44,y+28,27,false,GOLD,10));text("SPENT",x+70,y+30,43,false,GOLD,8)
  var plus=button("+",Rect2(x+118,y+14,24,24),spend.bind(id));plus.name="Spend_"+id
  plus.tooltip_text=Progression.STAT_NAMES[id]+"\nSpend 1 point · "+NOTES[index]
  plus.accessibility_name="Upgrade "+Progression.STAT_NAMES[id];plus.accessibility_description=NOTES[index];buttons[id]=plus
  index+=1
 for i in 2:
  var stat_index=1 if i==0 else 6;var y=402+i*28
  icon(CURRENT_STATS[stat_index],Rect2(16,y,24,24),CURRENT_TITLES[stat_index])
  values[stat_index]=text("",55,y,269,false,PAPER,15)
 for i in values.size():
  values[i].mouse_filter=Control.MOUSE_FILTER_PASS;values[i].tooltip_text=CURRENT_TITLES[i];values[i].accessibility_name=CURRENT_TITLES[i]
 pet_stats_content=Control.new();panel.add_child(pet_stats_content);content=pet_stats_content
 icon("vitality",Rect2(16,114,28,28),"Selected pet health")
 pet_health=text("",48,115,94,false,PAPER,16)
 pet_health_bar=game.forest_ui.meter(pet_stats_content,"SelectedPetHealth",Color("62c477"));pet_health_bar.step=0.0;pet_health_bar.position=Vector2(16,148);pet_health_bar.size=Vector2(148,12)
 var mana_icon=icon("mana",Rect2(176,114,28,28),"Selected pet mana")
 pet_mana=text("",208,115,94,false,PAPER,16)
 pet_mana_bar=game.forest_ui.meter(pet_stats_content,"SelectedPetMana",Color("278fdb"));pet_mana_bar.step=0.0;pet_mana_bar.position=Vector2(176,148);pet_mana_bar.size=Vector2(148,12)
 pet_mana_bar.accessibility_name=mana_icon.accessibility_name
 mana_icon.tooltip_text="Mana · Regenerates 1 per second while summoned"
 pet_state=text("",16,166,308,false,GOLD,12)
 var rows=[
  ["damage","attack","Attack","Normal attack damage per contact, before target defenses"],
  ["attack_speed","attack_speed","Atk speed","Attack speed multiplier"],
  ["dodge_chance","dodge_chance","Dodge","Chance to dodge an eligible hit"],
  ["counter_chance","counter_chance","Counter","Chance to counter an eligible hit"],
  ["speed","dodge_chance","Move","Base move speed before escort/catch-up adjustments"],
  ["contacts","attack","Hits","Contacts in the recovered attack sequence"],
  ["duration","attack_speed","Duration","Recovered attack animation duration in seconds"],
 ]
 for i in rows.size():
  var x=16+(i%2)*160;var y=191+(i/2)*34;var row=rows[i]
  card(Rect2(x,y,148,30));icon(row[1],Rect2(x+6,y+5,20,20),row[3])
  text(row[2],x+29,y+6,56,false,GOLD,10)
  var value=text("",x+85,y+5,40,true,PAPER,12);value.mouse_filter=Control.MOUSE_FILTER_PASS;value.tooltip_text=row[3];value.accessibility_name=row[3];pet_values[row[0]]=value
 text("EQUIPPED SKILLS",16,339,170,false,GOLD,11)
 for i in Pets.MAX_SKILLS:
  var y=365+i*31
  var view=TextureRect.new();view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;view.position=Vector2(16,y);view.size=Vector2(24,24);view.mouse_filter=Control.MOUSE_FILTER_IGNORE;pet_stats_content.add_child(view);pet_summary_icons.append(view)
  pet_summary_names.append(text("",50,y,106,false,PAPER,13))
  pet_summary_levels.append(text("",157,y,34,true,GOLD,11))
 pet_passive=Control.new();pet_passive.name="PetPassive";pet_stats_content.add_child(pet_passive);content=pet_passive
 fill(Rect2(201,339,1,110),Color("485055"))
 pet_passive_heading=text("PASSIVE",206,339,118,false,GOLD,11)
 pet_passive_heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var passive_icon=TextureRect.new();passive_icon.name="BeeMirageIcon";passive_icon.texture=BEE_MIRAGE
 passive_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;passive_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 passive_icon.position=Vector2(231,357);passive_icon.size=Vector2(68,56);passive_icon.mouse_filter=Control.MOUSE_FILTER_PASS
 passive_icon.tooltip_text=BEE_MIRAGE_HINT%Pets.BEE_DODGE_BONUS
 passive_icon.accessibility_name=BEE_MIRAGE_NAME;passive_icon.accessibility_description=passive_icon.tooltip_text;pet_passive.add_child(passive_icon)
 pet_passive_icon=passive_icon
 pet_passive_name=text("",206,413,118,false,PAPER,13)
 pet_passive_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 pet_passive_value=text("",206,432,118,false,GOLD,11)
 pet_passive_value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 content=pet_stats_content
 content=null;pet_stats_content.hide()

static func passive_texture(skin:int)->Texture2D:
 var passive=Pets.passive(skin)
 if passive.is_empty():return null
 return BEE_MIRAGE if Pets.has_bee_dodge(skin) else FAMILY_PASSIVE_ICONS[passive.stat]

func show_equipment_tab(show_stats:bool):
 if wearer_key.begins_with("pet:"):return
 overview_selected=show_stats
 overview_content.visible=show_stats;character_stats_content.visible=not show_stats
 tabs[0].set_pressed_no_signal(show_stats);tabs[1].set_pressed_no_signal(not show_stats)

func refresh_attack_damage(p:Hero):
 var amount=0.0
 var unit="Per hit"
 var defense_note="before crits and enemy defense"
 var primary:String=p.accessory_bonuses.get("primary","")
 if p.RogueRoster.is_crossgate_fighter(p.character_id):
  if p.model.beast_master:
   amount=Skills.BASIC_ATTACK_DAMAGE*p.base_character_attack_multiplier()
   unit="Dagger";defense_note="before enemy defense"
  elif primary=="fire":
   var id="kazi/fire"
   amount=p.magic_spell_damage(float(Skills.Levels.stats(id,1).base_damage))*Skills.effective(p,id,"damage","",0,1)
   unit="Fire · per target per cast"
  elif primary=="random-shot" and p.model.current_weapon()=="bow":
   var id=Skills.identify(p,"lancelot_random_shot")
   amount=Skills.damage(p,{"skill_rules":Skills.Levels.stats(id,1)},Skills.normal_damage(p))*p.damage_multiplier()*Skills.effective(p,id,"damage","",0,1)
   unit="Random Shot · per arrow"
  else:
   amount=Skills.basic_damage(p.model.normal_attack_pattern(),p)*p.damage_multiplier()
  var chain_scale=1.0 if p.model.beast_master else p.attack_chain.damage_multiplier()
  attack_damage.text=str(roundi(amount*chain_scale))
 else:attack_damage.text="—"
 attack_damage.tooltip_text=unit+" · "+defense_note
 attack_damage.accessibility_description=attack_damage.text+" · "+attack_damage.tooltip_text

func refresh_pet_stats():
 overview_content.hide();character_stats_content.hide();pet_stats_content.show();heading_label.show()
 for tab in tabs:tab.hide()
 var key=wearer_key.trim_prefix("pet:");var skin=Pets.skin(key);var progression=game.model.team_progression
 var passive=Pets.passive(skin);var passive_level=progression.pet_passive_level(key)
 pet_passive.visible=not passive.is_empty()
 if pet_passive.visible:
  pet_passive_icon.texture=passive_texture(skin)
  pet_passive_icon.tooltip_text=Pets.passive_hint(skin,passive_level)
  pet_passive_icon.accessibility_name=passive.name;pet_passive_icon.accessibility_description=pet_passive_icon.tooltip_text
  pet_passive_name.text=passive.name
  pet_passive_heading.text="PASSIVE · Lv %d"%passive_level if passive.upgrade else "PASSIVE"
  var value=Pets.passive_value(skin,passive_level)
  pet_passive_value.text="+%d HP/sec"%value if passive.stat=="regeneration" else "+%d%% Crit"%value if passive.stat=="critical_chance" else "+%d%% Player Dodge"%value
 point_header.hide();pet_growth_note.show();level_label.text=""
 name_label.text=Pets.display_name(skin,game.settings.forest_pet_names) if skin>=0 else "Empty pet slot"
 pet_profile=game.army_runtime.pet_stats(skin)
 pet_health_bar.visible=not pet_profile.is_empty()
 pet_mana_bar.visible=pet_health_bar.visible
 if pet_profile.is_empty():
  pet_health.text="—";pet_mana.text="—";pet_state.text="Use Add pet to fill this slot."
  for value in pet_values.values():value.text="—"
 else:
  level_label.text="Lv %d"%pet_profile.level
  pet_health.text="%d / %d"%[ceili(pet_profile.hp),ceili(pet_profile.max_hp)] if pet_profile.summoned else "%d MAX"%ceili(pet_profile.max_hp)
  pet_health_bar.max_value=pet_profile.max_hp;pet_health_bar.value=pet_profile.hp
  pet_mana.text="%d / %d"%[ceili(pet_profile.mana),ceili(pet_profile.max_mana)] if pet_profile.summoned or pet_profile.mana<pet_profile.max_mana else "%d MAX"%ceili(pet_profile.max_mana)
  pet_mana_bar.max_value=pet_profile.max_mana;pet_mana_bar.value=pet_profile.mana
  pet_state.text="Summoned" if pet_profile.summoned else "Not summoned"
  pet_state.text+=" · %s / %d XP"%[String.num(pet_profile.xp,1),pet_profile.xp_required] if pet_profile.xp_required>0 else " · MAX LEVEL"
  pet_values.damage.text="%.1f"%pet_profile.damage;pet_values.contacts.text=str(pet_profile.contacts)
  pet_values.duration.text="%.2fs"%pet_profile.duration;pet_values.speed.text="%.1f"%pet_profile.speed
  pet_values.attack_speed.text="%.1f×"%pet_profile.attack_speed
  pet_values.dodge_chance.text="%.0f%%"%(100*pet_profile.dodge_chance)
  pet_values.counter_chance.text="%.0f%%"%(100*pet_profile.counter_chance)
 for value in pet_values.values():value.accessibility_description=value.text
 var slots=Pets.skill_slots(Pets.sanitized_skills(game.settings.forest_pet_skills),key)
 for i in Pets.MAX_SKILLS:
  var id:String=slots[i]
  pet_summary_icons[i].texture=Skills.Catalog.KAZI_ICONS.get(id)
  pet_summary_names[i].text=Pets.SKILLS.get(id,"Empty")
  pet_summary_levels[i].text="Lv %d"%Skills.pet_level_for(progression,key,id) if not id.is_empty() else "—"

func refresh():
 if embedded and wearer_key.begins_with("pet:"):
  refresh_pet_stats();game.forest_ui.sync();return
 if embedded:
  pet_stats_content.hide();heading_label.hide();point_header.show();pet_growth_note.hide()
  for tab in tabs:tab.show()
  show_equipment_tab(overview_selected)
 var p=game.player;var progression=game.model.team_progression
 name_label.text=p.RogueRoster.name_for(p.character_id)
 if name_label.text=="Unknown":name_label.text="Edo" if p.character_id==2 else "Goemon"
 level_label.text=("Lv " if embedded else "")+str(progression.level)
 point_label.text=str(progression.stat_points)
 var index=0
 for id in Progression.STAT_NAMES:
  ranks[index].text=str(progression.stat_ranks[id]);ranks[index].mouse_filter=Control.MOUSE_FILTER_PASS;ranks[index].tooltip_text="Points spent: %d\nFood boosts (this run): %d"%[progression.stat_ranks[id],progression.food_ranks.get(id,0)];buttons[id].disabled=progression.stat_points<=0 or (id in ["critical_chance","dodge_chance","counter_chance"] and p.combat_tuning(id)>=100);index+=1
 var totals=[p.max_hp,p.health_regeneration(),p.damage_multiplier(),p.magic_damage_multiplier(),p.attack_speed_multiplier(),progression.stat_defense()+p.extra_defense(),100*(1-progression.stat_incoming_multiplier(p.extra_defense())),p.combat_tuning("critical_chance"),p.effective_dodge_chance(),p.combat_tuning("counter_chance"),progression.stat_magic_defense()+p.extra_defense(true),p.combat_tuning("accuracy")]
 for i in values.size():
  values[i].text=CURRENT_FORMATS[i]%totals[i];values[i].accessibility_description=values[i].text
 game.forest_ui.sync()
 if embedded:
  refresh_attack_damage(p)
  totals[3]=p.base_magic_damage()
  totals[4]*=100.0
  for i in overview_values:
   overview_values[i].text=OVERVIEW_FORMATS[i]%roundi(totals[i]);overview_values[i].accessibility_description=overview_values[i].text
  return
 skill_ids=Skills.active_slots(p)
 var slots=p.spell_loadout.slots_for(p.character_id)
 for i in 6:
  var id=skill_ids[i];var occupied=i<slots.size() and not slots[i].is_empty()
  var title:String=Skills.all()[id].name if Skills.all().has(id) else (slots[i][0] if occupied else "Empty")
  skill_names[i].text=title.get_slice(" · ",0)
  var portrait=game.forest_ui.helper_portraits[i]
  skill_icons[i].texture=portrait.texture if occupied and portrait.visible else null
  var supported=not id.is_empty() and not Skills.rules_for(p,id).is_empty()
  var level_=Skills.level_for(p,id) if supported else 0
  skill_levels[i].text=("Lv 30 MAX" if level_==30 else "Lv %d → %d"%[level_,level_+1]) if supported else ("No upgrades" if occupied else "—")
  skill_buttons[i].disabled=not supported or progression.stat_points<=0 or level_>=30
  skill_buttons[i].tooltip_text=title+"\n"+("Level %d: %s"%[level_,Skills.level_preview(id,level_)] if supported else "No level upgrades defined." if occupied else "Equip a skill in Equipment.")
  if supported and level_<30:skill_buttons[i].tooltip_text+="\nNext: "+Skills.level_preview(id,level_+1)+"\nCosts 1 shared point. Base values before items and bonuses."
 refresh_pets()

func refresh_pets():
 var progression=game.model.team_progression
 pet_choices=Pets.sanitized(game.settings.forest_pet_loadout)
 pet_index=clampi(pet_index,0,maxi(0,pet_choices.size()-1))
 for i in pet_selectors.size():
  var filled=i<pet_choices.size();var choice=pet_selectors[i]
  choice.disabled=not filled;choice.toggle_mode=true;choice.set_pressed_no_signal(filled and i==pet_index)
  choice.icon=Pets.portrait(Pets.skin(pet_choices[i])) if filled else null
  choice.tooltip_text=Pets.display_name(Pets.skin(pet_choices[i]),game.settings.forest_pet_names) if filled else "Empty pet slot · Choose a pet in Q Equipment"
 var key=pet_choices[pet_index] if not pet_choices.is_empty() else ""
 pet_name.text=Pets.display_name(Pets.skin(key),game.settings.forest_pet_names) if not key.is_empty() else "Choose your companions in Q Equipment"
 pet_skill_ids=Pets.skill_slots(Pets.sanitized_skills(game.settings.forest_pet_skills),key)
 for i in Pets.MAX_SKILLS:
  var id:String=pet_skill_ids[i];var supported=not Skills.Levels.stats(id,1).is_empty()
  var level_=Skills.pet_level_for(progression,key,id) if supported else 0
  pet_skill_names[i].text=Pets.SKILLS.get(id,"Empty skill slot")
  pet_skill_icons[i].texture=Skills.Catalog.KAZI_ICONS.get(id)
  pet_skill_levels[i].text=("Lv 30 MAX" if level_==30 else "Lv %d → %d"%[level_,level_+1]) if supported else ("No upgrades defined" if not id.is_empty() else "Equip a skill in Q Equipment")
  var plus=pet_skill_buttons[i];plus.disabled=not supported or progression.stat_points<=0 or level_>=30
  plus.tooltip_text=pet_skill_names[i].text+("\nLevel %d: %s"%[level_,Skills.level_preview(id,level_)] if supported else "")
  if supported and level_<30:plus.tooltip_text+="\nNext: "+Skills.level_preview(id,level_+1)+"\nCosts 1 shared point for this pet only."

func select_pet(index:int):
 pet_index=index;refresh_pets()

func show_pets():
 stats_content.hide();skills_content.hide();pets_content.show();refresh_pets()
 for i in tabs.size():tabs[i].set_pressed_no_signal(i==2)
 for plus in pet_skill_buttons:
  if not plus.disabled:plus.grab_focus();break

func spend_pet_skill(index:int):
 if game.status_panel==self and not pet_choices.is_empty():
  game.spend_pet_skill(pet_choices[pet_index],pet_skill_ids[index]);refresh()

func show_skills(show_:bool):
 pets_content.hide()
 stats_content.visible=not show_;skills_content.visible=show_
 for i in tabs.size():tabs[i].set_pressed_no_signal(i==(1 if show_ else 0))
 if show_:
  for plus in skill_buttons:
   if not plus.disabled:plus.grab_focus();break
 else:buttons.vitality.grab_focus()

func spend_skill(index:int):
 if game.status_panel==self:
  game.spend_level_skill(skill_ids[index]);refresh()

func spend(id:String):
 if embedded and wearer_key.begins_with("pet:"):return
 if (embedded or game.status_panel==self) and game.spend_level_stat(id):
  if embedded:game.equipment_hub.refresh()
  else:refresh()
