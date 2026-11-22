extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const Roster=preload("res://scripts/rogue_roster.gd")
const OUT="res://build/Other Files/Asset Toolkit/Cross Gate Jumps/"
var home=Vector3(-150,0,150)

func jump_key(down:bool=true,echo_:bool=false,shift_:bool=true):
 var event=InputEventKey.new();event.physical_keycode=KEY_SPACE;event.shift_pressed=shift_;event.pressed=down;event.echo=echo_
 root.push_input(event,true)

func tap(action:String):
 if action!="jump":super.tap(action);return
 jump_key();jump_key(false)

func verify_controls():
 var p=game.player
 p.select_character(Roster.KAZI_ID);p.position=home;p.velocity=Vector3.DOWN;p.move_and_slide()
 p.smoke_mode=true;p.smoke_move=Vector2.ZERO
 root.gui_release_focus()
 for i in 4:await advance()
 jump_key(true,false,false);jump_key(false,false,false)
 for i in 5:await advance()
 check(p.is_on_floor() and p.jump_buffer==0 and p.jump_windup==0,"Plain Space remains dodge without jumping")
 game.paused=true;tap("jump");game.paused=false
 check(p.jump_buffer==0,"Paused Shift + Space cannot queue a jump")
 var hp:float=p.hp;p.hp=0;tap("jump");p.hp=hp
 check(p.jump_buffer==0,"Defeated Shift + Space cannot queue a jump")
 p.defend_held=true;tap("jump")
 check(p.jump_buffer>0 and not p.defend_held,"Shift + Space releases guard and buffers the existing jump")
 for i in 5:await advance()
 check(p.jumps_used==1 and p.velocity.y>0 and not p.timed_dodge.reacting,"Shift + Space launches without a dodge")
 jump_key(true,true)
 check(p.jump_buffer==0,"Holding Shift + Space cannot repeat from key echo")
 jump_key(false);tap("jump");await advance()
 check(p.jumps_used==2 and p.velocity.y>0,"A second Shift + Space uses the existing air jump")
 tap("jump");await advance()
 check(p.jumps_used==2 and p.jump_buffer==0,"A third chord cannot exceed the existing jump budget")
 for i in 150:
  await advance()
  if p.is_on_floor():break
 check(p.is_on_floor(),"The existing jump lands normally")

func advance():
 await physics_frame
 game.player._physics_process(1.0/60)

func capture(label_:String):
 if DisplayServer.get_name()=="headless":return
 await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+label_+".png")==OK,"Captured "+label_)

func draws(model,action:int,frame:int)->bool:
 if not model.current_clip.begins_with("%d:"%action) or model.current_frame!=frame:return false
 var key="dagger:"+model.current_clip if model.daggers else model.current_clip
 var clip:Dictionary=(model.motions if Roster.is_shin(model.character) else model.appearance).clips[key]
 var data:Array=clip.frames[frame]
 return model.sprite.texture==model.atlases[int(data[0])] and model.sprite.region_rect==Rect2(data[1],data[2],data[3],data[4])

func verify_jump(label_:String,guard_row:int,swap_row:int=-1):
 var p=game.player
 var model=p.model
 p.position=home;p.velocity=Vector3.DOWN;p.move_and_slide()
 p.was_floor=p.is_on_floor();p.invuln=0;p.smoke_mode=true;p.smoke_move=Vector2.ZERO
 p.facing=Vector3(1,0,1).normalized()
 for i in 4:await advance()
 game.camera_rig.camera.global_position=home+Vector3(0,4,13)
 game.camera_rig.camera.look_at(home+Vector3.UP*2.8)
 var sprite:Sprite3D=model.sprite
 var nodes:int=model.body.get_child_count()
 var voice_start:int=game.voice_idx
 tap("jump");await advance()
 check(not p.timed_dodge.reacting and p.invuln<=0,label_+" Shift + Space grants no timed-dodge protection")
 var guard_ok=p.is_on_floor() and model.current_clip.begins_with("9:")
 if model.jump_guard_atlas==null:
  guard_ok=guard_ok and draws(model,9,0)
 else:
  var cell:Vector2=model.GUARD_CELL if p.character_id==Roster.KAZI_ID else model.WEAPON_GUARD_CELL
  guard_ok=guard_ok and sprite.texture==model.jump_guard_atlas and sprite.region_rect==Rect2(Vector2(model.direction(),guard_row)*cell,cell)
 check(guard_ok,label_+" guards with the selected outfit and weapon")
 await capture(label_+" guard")
 for i in 2:await advance()
 var launched_in_guard=not p.is_on_floor() and p.velocity.y>0 and model.current_clip.begins_with("9:")
 for i in 3:
  await advance()
  launched_in_guard=launched_in_guard and model.current_clip.begins_with("9:")
 check(launched_in_guard,label_+" launches on tick three and holds the guard through early rise")
 await advance()
 check(draws(model,8,0),label_+" briefly flinches after the guard")
 if swap_row>=0:
  p.swap_weapon()
  var row:int=int(model.daggers) if p.character_id==Roster.MAZE_ID else model.shin_weapon_index
  check(row==swap_row and draws(model,8,0),label_+" keeps the flinch while swapping weapons")
 var run_key="3:%d"%model.direction()
 var fall_key="10:%d"%model.direction()
 if model.daggers:
  run_key="dagger:"+run_key;fall_key="dagger:"+fall_key
 var clips:Dictionary=(model.motions if Roster.is_shin(p.character_id) else model.appearance).clips
 var run_end:int=clips[run_key].frames.size()-1
 var fall_end:int=clips[fall_key].frames.size()-1
 var tucked=false
 var descended=false
 var landed=false
 for i in 150:
  await advance()
  if not tucked and p.velocity.y>0 and draws(model,3,roundi(3*run_end/17.0)):
   tucked=true
   await capture(label_+" tuck")
  if not descended and p.velocity.y<0 and draws(model,3,roundi(15*run_end/17.0)):
   descended=true
   await capture(label_+" descent")
  if p.is_on_floor():
   landed=draws(model,10,2 if p.character_id==Roster.RUBY_ID else roundi(5*fall_end/11.0))
   await capture(label_+" landing")
   break
 check(tucked and descended and landed,label_+" tucks, descends and lands using its own frames")
 for i in 16:await advance()
 var landings=game.voices.filter(func(voice):return int(voice.get_meta("order",0))>voice_start and voice.get_meta("kind","")=="land")
 check(landings.size()==1 and landings[0].stream==SoundLibrary.HUMANOID_LANDING,label_+" plays the prepared landing once")
 check(model.current_clip.begins_with("0:") and model.sprite==sprite and model.body.get_child_count()==nodes,label_+" returns to idle on the same sprite")

func verify_air_hit(label_:String,jump:int):
 var p=game.player
 var model=p.model
 p.position=home;p.velocity=Vector3.DOWN;p.move_and_slide()
 p.was_floor=p.is_on_floor();p.hp=p.max_hp;p.invuln=0
 for i in 4:await advance()
 tap("jump")
 for i in 5:await advance()
 if jump==2:
  tap("jump");await advance()
 var health:float=p.hp
 check(not p.is_on_floor() and p.jumps_used==jump,label_+" is airborne before the hit")
 p.take_hit(5,Vector3.RIGHT)
 await advance()
 check(p.hp<health and p.active_ability.mode=="hurt" and model.current_clip.begins_with("8:"),label_+" takes damage and shows the hurt pose")
 var visible_at_body=true
 var landed=false
 for i in 150:
  visible_at_body=visible_at_body and model.sprite.is_visible_in_tree() and model.body.position.is_zero_approx() and model.body.rotation.is_zero_approx()
  if i==10:await capture(label_)
  if p.is_on_floor() and p.invuln<=0:
   landed=true
   break
  await advance()
 check(visible_at_body and landed,label_+" stays visible at the player body through landing and recovery")

func run():
 create_timer(150).timeout.connect(func():printerr("CROSS_GATE_JUMP_TIMEOUT");quit(1))
 root.set_flag(Window.FLAG_NO_FOCUS,true)
 DirAccess.make_dir_recursive_absolute(OUT)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 home.y=game.model.surface_height(home.x,home.z)+.1
 game.model.update_vision(home)
 var p=game.player
 await verify_controls()
 for id in Roster.selection_ids():
  p.select_character(id)
  await verify_jump(Roster.name_for(id),1 if id==Roster.SHIN_ID else 0,2 if id==Roster.SHIN_ID else 1 if id==Roster.MAZE_ID else -1)
 p.select_character(Roster.MAZE_ID)
 p.active_ability.set_weapon(Roster.MazeWeapon.KUNAI)
 await verify_jump("Maze Kunai",1)
 p.select_character(Roster.SHIN_ID)
 await verify_jump("Shin Polearm",2,0)
 await verify_jump("Shin Unarmed",0)
 p.select_character(Roster.SHIN_SPECIAL_ID)
 game.select_shin_skin(Roster.SHIN_SPECIAL_ID,120440)
 await verify_jump("Shin Special Red Sword",0,1)
 await verify_jump("Shin Special Red Polearm",1)
 game.select_shin_skin(Roster.SHIN_SPECIAL_ID,118993)
 await verify_jump("Shin Special Red Lightning",0)
 for id in [Roster.SHIN_ID,Roster.SHIN_SPECIAL_ID]:
  p.select_character(id)
  await verify_air_hit(Roster.name_for(id)+" first-jump hit",1)
  await verify_air_hit(Roster.name_for(id)+" second-jump hit",2)
 game.queue_free()
 await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("CROSS_GATE_JUMP_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
