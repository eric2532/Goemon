extends "res://tests/forest-shrine/crossgate_blast_coverage_test.gd"

const Catalog=preload("res://scripts/spells/spell_catalog.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
const SPELLS=["kazi/qigong","maze/qigong","kazi/moon","kazi/fire","kazi/ice","kazi/wind","kazi/meteor","uru/spirit"]
var shots:Array=[]
var cast_starts=0
var last_ticket:Dictionary={}

func cast_steps(count_:int):
 for i in count_:
  var current=game.player.spell_loadout.current
  if current!=null and not is_same(last_ticket,current.controller.ticket):
   cast_starts+=1;last_ticket=current.controller.ticket
  game.player.spell_loadout.tick(DT)
  for shot in shots:
   if shot.pool_live:shot._physics_process(DT)

func number(number_:int,pressed:bool,echo:bool=false):
 var event=InputEventKey.new();event.physical_keycode=KEY_1+number_-1;event.pressed=pressed;event.echo=echo
 if pressed:game.player._unhandled_input(event)
 else:game.player._input(event)

func run():
 create_timer(180).timeout.connect(func():printerr("SKILL_NO_QUEUE_TIMEOUT");quit(1))
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 var p=game.player;var army=game.army_runtime
 game.settings.disable_character_cooldowns=false
 game.set_process(false);army.set_process(false);army.set_physics_process(false)
 for node in [game,p,game.camera_rig,game.forest_ui]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 game.training_dummy.home=home+Vector3.DOWN*1000;game.training_dummy.position=game.training_dummy.home
 Pool.service(game).launched.connect(func(shot):shots.append(shot);shot.set_physics_process(false))
 for fighter in p.RogueRoster.CROSSGATE:
  p.select_character(fighter);fresh();p.position=home;p.velocity=Vector3.ZERO;p.combat_hold_left=0
  for i in 20:p._physics_process(DT)
  check(p.is_on_floor(),"Fighter %d is grounded"%fighter)
  var bar=p.spell_loadout
  for id in SPELLS:
   check(bar.equip(fighter,"equip",id) and bar.equip(fighter,"surge","kazi/ice"),"Equip input fixture: %d %s"%[fighter,id])
   bar.clear_cooldowns();shots.clear();cast_starts=0;last_ticket={}
   number(1,true)
   check(bar.current!=null and bar.current.spec.id==id,"Fresh press starts %d %s"%[fighter,id])
   var instance=bar.current
   var ticket:Dictionary=instance.controller.ticket
   for i in 8:
    number(1,true,true);tap("equip");tap("surge")
    number(2,true);number(2,false)
   number(1,false)
   check(bar.current==instance and is_same(ticket,instance.controller.ticket),"Busy presses preserve the active cast")
   # Wait beyond every cooldown and projectile lifetime without more input.
   cast_steps(1200)
   check(bar.current==null and cast_starts==1,"Busy taps and echoes leave no delayed cast: %d %s"%[fighter,id])
   check(bar.held_numbers.is_empty(),"Number releases clear held input")
   bar.clear_cooldowns();tap("equip")
   check(bar.current==instance and not is_same(ticket,instance.controller.ticket),"A fresh ready press casts again")
   while bar.current!=null:cast_steps(1)
   var starts=cast_starts
   tap("equip")
   cast_steps(1200)
   check(bar.current==null and cast_starts==starts,"A cooldown press never fires later")
   bar.cancel();bar.clear_cooldowns();tap("equip");tap("dodge")
   check(bar.current==null,"Dodge still cancels the active cast")
   p.dodge_time=0;p.dodge_cooldown=0;bar.cancel()
 game.queue_free();paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("SKILL_NO_QUEUE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
