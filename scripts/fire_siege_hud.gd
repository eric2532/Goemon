extends RefCounted
## Compact Fire Siege presentation, kept separate from legacy mode HUDs.
const Roster=preload("res://scripts/rogue_roster.gd")
var textures: Dictionary={}
var portrait_id=-1
var portrait_view: SubViewport
var original_portrait: Texture2D

func icon(key: String)->Texture2D:
 var path=Roster.icon_path(key)
 if not textures.has(path):textures[path]=load(path)
 return textures[path]

func hero_info(player)->Dictionary:
 if player.is_rogue_character():
  var data=Roster.data(player.character_id)
  var primary="Aerial Fan" if data.id=="ranger" and player.jumps_used>=2 and not player.is_on_floor() else data.abilities.cutlass.name
  if data.id=="ranger" and (player.active_ability.player.buffTime>0 or int(player.active_ability.player.get("rangerShots",0))%3==2):primary="Green Fan" if player.jumps_used>=2 and not player.is_on_floor() else "Green Power"
  return {"name":data.name,"portrait":Roster.portrait(player.character_id),"primary":primary,"secondary":data.abilities.flintlock.name,"primary_icon":data.abilities.cutlass.icon,"secondary_icon":data.abilities.flintlock.icon,"utility":data.abilities.roll.name,"skill":data.abilities.drink.name,"color":Color(data.color)}
 if player.character_id==2:
  return {"name":"Edo","portrait":original_portrait,"primary":"Fireballs","secondary":"Giant fireball","primary_icon":"fire","secondary_icon":"spark","utility":"Fire dodge","skill":"Blue surge","color":Color("ff956f")}
 return {"name":"Goemon","portrait":original_portrait,"primary":"Pipe combo","secondary":"Heavy strike","primary_icon":"pipe","secondary_icon":"wave","utility":"Dash","skill":"Golden surge","color":Color("edcf87")}

func strip_scripts(node: Node):
 node.set_script(null)
 for child in node.get_children():strip_scripts(child)

func update_portrait(hud):
 var p=hud.game.player
 if portrait_id==p.character_id:return
 portrait_id=p.character_id
 if is_instance_valid(portrait_view):portrait_view.queue_free()
 original_portrait=null
 if p.is_rogue_character():return
 portrait_view=SubViewport.new();portrait_view.size=Vector2i(256,256)
 portrait_view.transparent_bg=true;portrait_view.own_world_3d=true
 portrait_view.render_target_update_mode=SubViewport.UPDATE_ONCE
 hud.add_child(portrait_view)
 var copy=p.model.duplicate()
 strip_scripts(copy);copy.position=Vector3.ZERO;copy.rotation=Vector3.ZERO;copy.scale=Vector3.ONE
 portrait_view.add_child(copy);copy.show()
 var camera=Camera3D.new();portrait_view.add_child(camera)
 camera.position=Vector3(.12,1.95,-4.2);camera.look_at(Vector3(0,1.55,0));camera.fov=31
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-25,0);light.light_energy=1.8;portrait_view.add_child(light)
 var environment=WorldEnvironment.new();environment.environment=Environment.new()
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color=Color("d5e3eb");environment.environment.ambient_light_energy=.65
 portrait_view.add_child(environment)
 original_portrait=portrait_view.get_texture()

func centered(hud,y: float,label: String,size: int,color: Color=Color("edf4e9")):
 var width=hud.font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
 hud.text(Vector2((hud.size.x-width)*.5,y),label,size,color)

func draw(hud):
 var game=hud.game;var run=game.encounters;var p=game.player
 var w=hud.size.x;var h=hud.size.y
 var ink=Color(.025,.055,.075,.92);var gold=Color("f5d58c");var muted=Color("b6cbc8")
 var red=Color("ff9985");var teal=Color("91dfbe")
 var left=Vector2(26,25)
 hud.draw_style_box(hud.panel_style(ink),Rect2(left,Vector2(340,180)))
 hud.text(left+Vector2(18,27),"FIRE SIEGE  /  "+("HARD" if run.hard_mode else "BETA"),15,gold)
 hud.text(left+Vector2(18,64),"%.2f GOLD" % run.money,28,gold)
 var shown_wave=mini(10,run.wave+1) if run.phase=="setup" else run.wave
 hud.text(left+Vector2(216,63),"%02d / 10" % shown_wave,22)
 var phase_text="PREPARE · No time limit"
 if run.phase=="spawning":phase_text="INCOMING · %s remaining" % run.clock_text(60-run.wave_elapsed)
 elif run.phase=="clearance":phase_text="CLEAR THE FIELD · %d alive" % run.alive_count
 hud.text(left+Vector2(18,91),phase_text,16)
 hud.text(left+Vector2(18,116),"%d active   ·   %d defeated   ·   %d at shrine" % [run.alive_count,run.wave_kills,run.shrine_attacker_count()],12,muted)
 hud.draw_rect(Rect2(left+Vector2(18,133),Vector2(304,9)),Color("384448"))
 hud.draw_rect(Rect2(left+Vector2(18,133),Vector2(304*float(run.base_hp)/run.base_max_hp,9)),teal if run.base_hp>20 else red)
 hud.text(left+Vector2(18,164),"SHRINE HEALTH  %d / %d" % [run.base_hp,run.base_max_hp],14,red if run.shrine_attacker_count()>0 else teal)
 var right=Vector2(w-328,25)
 hud.draw_style_box(hud.panel_style(ink),Rect2(right,Vector2(302,170)))
 hud.text(right+Vector2(18,27),"BUILD YOUR DEFENSE",15,gold)
 var towers=run.tower_counts()
 hud.text(right+Vector2(18,55),"%d ARROW · %d ICE · %d / %d built" % [towers.arrow,towers.ice,run.cannons.size(),run.site_states.size()],14)
 hud.text(right+Vector2(18,81),"%d / %d mines · 10 gold each" % [run.mine_count(),run.mine_states.size()],15,teal if run.mine_count()>0 else muted)
 var income=2.0*run.mine_count() if run.phase=="spawning" else 0.0
 var upkeep=.1*run.cannons.size() if run.phase in ["spawning","clearance"] else 0.0
 hud.text(right+Vector2(18,107),"Income +%.1f/s   Upkeep −%.1f/s" % [income,upkeep],14,muted)
 hud.text(right+Vector2(18,132),"Auto build · F Ice: 10 gold · Slow only",12,gold)
 hud.text(right+Vector2(18,153),"Kills: no gold · Wave reward: 10 × wave",12,muted)
 if run.cannons.size()>0 and not run.powered and run.phase in ["spawning","clearance"]:
  centered(hud,236,"OUT OF GOLD · Towers need upkeep to fire",20,red)
 if run.phase=="setup":
  var x=w*.5-200
  hud.draw_style_box(hud.panel_style(ink),Rect2(x,30,400,84))
  centered(hud,58,"HOLD  Y  ·  START WAVE %d" % shown_wave,18,gold)
  hud.draw_rect(Rect2(x+20,74,360,12),Color("344547"))
  hud.draw_rect(Rect2(x+20,74,360*run.start_progress,12),gold)
  centered(hud,103,"Explore, return, then hold for 3 seconds",12,muted)
 var guide=run.shrine_guidance()
 var compass=Vector2(w*.5-190,132);var direction: Vector2=guide.screen_direction
 if direction.length_squared()>.01:
  hud.draw_line(compass-direction*10,compass+direction*10,teal,2,true)
  hud.draw_colored_polygon(PackedVector2Array([compass+direction*14,compass+direction*5+direction.orthogonal()*5,compass+direction*5-direction.orthogonal()*5]),teal)
 else:hud.draw_circle(compass,4,teal)
 centered(hud,139,"SHRINE · %dm   |   SUPPLIES %d/%d · FINDS %d/%d" % [roundi(guide.distance),run.exploration.collected_count(),game.world.exploration_caches.size(),run.exploration.discovery_count(),game.world.exploration_discoveries.size()] if run.phase=="setup" else "SHRINE · %dm%s" % [roundi(guide.distance)," · UNDER ATTACK" if guide.under_attack else ""],13,teal if not guide.under_attack else red)
 # Bottom-center hero panel; every field reads the active hero.
 var info=hero_info(p);var panel=Vector2(w*.5-365,h-151)
 hud.draw_style_box(hud.panel_style(ink),Rect2(panel,Vector2(730,129)))
 hud.draw_style_box(hud.panel_style(Color("19323c")),Rect2(panel+Vector2(12,12),Vector2(100,104)))
 if info.portrait!=null:hud.draw_texture_rect(info.portrait,Rect2(panel+Vector2(13,13),Vector2(98,102)),false)
 var hero_name=String(info.name).to_upper();var name_size=19
 while name_size>11 and hud.font.get_string_size(hero_name,HORIZONTAL_ALIGNMENT_LEFT,-1,name_size).x>168:name_size-=1
 hud.text(panel+Vector2(126,27),hero_name,name_size,info.color)
 hud.text(panel+Vector2(300,26),"LV %02d" % p.progression.level,13,gold)
 hud.draw_rect(Rect2(panel+Vector2(126,41),Vector2(221,10)),Color("3f3d41"))
 hud.draw_rect(Rect2(panel+Vector2(126,41),Vector2(221*clampf(p.hp/p.max_hp,0,1),10)),teal)
 hud.text(panel+Vector2(126,73),"%d / %d HP" % [ceili(p.hp),ceili(p.max_hp)],14)
 var ranger=p.is_rogue_character() and p.active_ability.class_id=="ranger"
 hud.text(panel+Vector2(126,96),"Q Heroes · C Fast Roll" if ranger else "Q Heroes · C Evade",13,muted)
 hud.text(panel+Vector2(126,114),"R Rain · FIRE ×%.2f" % p.active_ability.ranger_fire_rate_multiplier() if ranger else "E %s · R %s" % [info.utility,info.skill],11,muted)
 var energy_hero=p.is_rogue_character() and p.active_ability.uses_energy()
 var energy=int(p.active_ability.player.get("energy",0)) if energy_hero else 0
 if energy_hero:
  var bar=panel+Vector2(366,94)
  hud.draw_rect(Rect2(bar,Vector2(160,5)),Color("394849"))
  hud.draw_rect(Rect2(bar,Vector2(160*energy/100.0,5)),gold if energy>=100 else info.color)
  hud.text(bar+Vector2(175,5),"FREE HEAVY · RMB / 3" if energy>=100 else "ENERGY %d / 100 · +20 per light" % energy,10,gold if energy>=100 else muted)
 var cooldowns=p.active_ability.player.get("cooldowns",{}) if p.is_rogue_character() else {}
 for i in range(2):
  var pos=panel+Vector2(366+i*177,13)
  hud.draw_style_box(hud.panel_style(Color("17333a")),Rect2(pos,Vector2(165,76)))
  hud.draw_texture_rect(icon(info.primary_icon if i==0 else info.secondary_icon),Rect2(pos+Vector2(9,12),Vector2(39,39)),false)
  hud.text(pos+Vector2(58,23),("AUTO" if p.auto_attack_enabled else "LMB") if i==0 else ("RMB / 3" if p.is_rogue_character() else "RMB"),15,gold)
  var label=String(info.primary if i==0 else info.secondary)
  hud.text(pos+Vector2(58,43),label.left(15),11)
  var remaining=float(cooldowns.get("cutlass" if i==0 else "flintlock",0))
  hud.text(pos+Vector2(58,62),"FREE READY" if i==1 and energy_hero and energy>=100 else ("%.1fs" % remaining if remaining>.05 else "READY"),11,gold if i==1 and energy_hero and energy>=100 else muted)
 hud.text(panel+Vector2(366,121 if energy_hero else 110),"WASD Move · Shift Sprint · Space Jump · Esc Pause",12,muted)
 hud.text(Vector2(30,h-82),"J AUTO LOCK: "+("ON" if p.auto_attack_running() else "PAUSED") if p.auto_attack_enabled else "J AUTO LOCK: OFF",13,teal if p.auto_attack_enabled else muted)
 hud.text(Vector2(30,h-58),"G Dogs   H Allies",13,muted)
 hud.text(Vector2(30,h-35),("Space ×2: Auto Fan · Hold Space: Slow fall" if p.auto_attack_enabled else "Space ×2 + LMB: Fan · Hold Space: Slow fall") if p.is_rogue_character() and p.active_ability.class_id=="ranger" else "1–5 / T  Hero abilities",12,muted)
 if not game.portal_hint.is_empty():centered(hud,h-177,game.portal_hint,16,gold)
 if p.attack_chain.count>0:
  hud.text(Vector2(32,235),"%d LINKS · DMG ×%.2f" % [p.attack_chain.count,p.attack_chain.damage_multiplier()],18,Color("ffbe85"))
 if run.hero_dead:
  centered(hud,h*.43,"HERO DOWN · THE SIEGE CONTINUES",26,red)
  centered(hud,h*.43+36,"Reviving in %.1fs · Enemies move 35%% faster" % run.revive_left,18)
  centered(hud,h*.43+116,"Right-drag to look around",14,muted)
 elif hud.banner_time>0 and run.phase!="setup":
  centered(hud,h*.25,hud.banner,22,gold)
 if hud.toast_time>0:centered(hud,h-210,hud.toast_text,15,gold)
