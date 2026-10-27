extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Finale=preload("res://scripts/forest/dark_lumina_3_kit.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
const OUT="res://build/Other Files/Asset Toolkit/Dark Lumina 3/"
func run():
 await setup_fixture()
 var p=game.player;p.select_character(30);fresh()
 verify_scale_and_media(p,game.crowd.army.presentation)
 check(p.active_ability.role==18 and p.character_id==30,"Final form uses shared fighter ownership")
 var pool=Pool.service(game);var created=pool.created;
 for nodes in pool.all.values():
  for shot in nodes:
   if shot.get_script()==preload("res://scripts/dark_lumina_3_projectile.gd"):assert(shot.visual.multimesh.get_instance_transform(0)==Transform3D.IDENTITY,"Prepared projectiles must have visible geometry")
 var expected=[3,22,6,32,1,10]
 for repeat in 2:
  for move in 6:
   fresh();p.active_ability.start_move(move)
   check(p.active_ability.is_attacking(),"Move %d starts"%move)
   var count=0
   for f in Finale.moves[move]:count+=1 if f.event else 0
   check(count==expected[move],"Move %d keeps every release marker"%move)
   for tick in Finale.moves[move].size()+40:
    game.crowd.army.presentation.tick(1.0/30)
    if move==4:p._physics_process(1.0/30)
    else:p.active_ability.tick(1.0/30);p.model.animate(1.0/30,0,true,0,0,false,0,false)
    for nodes in pool.all.values():
     for shot in nodes:
      if shot.pool_live:shot._physics_process(1.0/30)
    if tick%30==0:await process_frame
   check(not p.active_ability.is_attacking() and p.model.body.visible,"Move %d finishes and restores the body"%move)
 check(pool.created==created,"Six move families reuse prepared projectiles")
 var presentation=game.crowd.army.presentation
 p.active_ability.start_move(5);p.active_ability.tick(2.8/p.active_ability.CAST_RATE)
 check(presentation.effects.filter(func(f):return f.kind=="finale-sky_copy").size()==5,"Sky creates all five enlarged copies before cancellation")
 p.active_ability.interrupt_for_dodge()
 check(not p.active_ability.is_attacking() and p.model.body.visible,"Sky cancellation restores visibility")
 check(not presentation.effects.any(func(f):return f.get("owner_id",0)==p.active_ability.get_instance_id()),"Sky cancellation removes every owned copy")
 for voice in presentation.voices:voice.stop()
 presentation.next_sound=0
 p.active_ability.start_move(1)
 p.active_ability.tick(2.1/p.active_ability.CAST_RATE)
 check(presentation.voices.any(func(v):return v.playing and v.get_meta("loop_owner",0)==p.active_ability.get_instance_id() and v.stream==Finale.loops.wind_loop),"Wind plays its prepared sustained blowing audio")
 check(presentation.effects.any(func(f):return f.get("owner_id",0)==p.active_ability.get_instance_id()),"Wind cosmetics belong to their caster")
 p.active_ability.interrupt_for_dodge()
 check(not presentation.effects.any(func(f):return f.get("owner_id",0)==p.active_ability.get_instance_id()),"Cancellation removes only this caster's persistent effects")
 check(not presentation.voices.any(func(v):return v.playing and v.get_meta("loop_owner",0)==p.active_ability.get_instance_id()),"Wind cancellation stops the held sound")
 p.select_character(1)
 for name in ["sword","wind","water","fire","earth","sky"]:
  check(p.spell_loadout.equip(1,"equip","dark-lumina-3/"+name),"Finale spell is transferable: "+name)
  tap("equip");await frames(2)
  check(p.spell_loadout.instances.values()[0].controller.is_attacking(),"Transferred spell starts: "+name)
  p.cancel_charge();p.spell_loadout.equip(1,"equip","")
 FileAccess.open(OUT+"gameplay-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"pool_created":created,"pool_after":pool.created},"  "))
 game.queue_free();await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("DARK_LUMINA_3_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

func verify_scale_and_media(p:Node,presentation:Node):
 check(is_equal_approx(Finale.SCALE,3.0),"Final form uses one three-times multiplier")
 check(p.model.bounds().size.is_equal_approx(Vector3(3.3,7.5,3)),"Player hurt body matches the enlarged model")
 check(is_equal_approx(p.body_shape.shape.height,7.5),"Player terrain collision matches the enlarged body")
 check(is_equal_approx(p.model.crowd.multimesh.mesh.surface_get_material(0).get_shader_parameter("role_size"),3),"Playable and native mesh use the enlarged shader pose")
 check(is_equal_approx(Finale.meshes.sky_copy.surface_get_material(0).get_shader_parameter("role_size"),3),"Sky copies grow with their owner")
 var sprites:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Finale.FX_DIR+"sources.json")).sprites
 for key in sprites:
  var mesh:Mesh=Finale.meshes[key]
  var expected=Vector2(sprites[key].width,sprites[key].height)*.018*sprites[key].get("display_scale",1)*3*float(Finale.EFFECT_SCALE.get(key,1))
  if key=="fire":expected.x*=1.5
  check(mesh is ArrayMesh if key=="sword_cross" else mesh.size.is_equal_approx(expected),"Recovered sprite has its shared effect size: "+key)
  check(mesh.surface_get_material(0).get_shader_parameter("atlas")!=null,"Recovered sprite texture is installed: "+key)
 for key in Finale.sounds:
  check(Finale.sounds[key]!=null and Finale.sounds[key].get_length()>0,"Recovered sound is installed: "+key)
  for voice in presentation.voices:voice.stop()
  presentation.next_sound=0
  var voice=presentation.play_sound(p.position+Vector3(75,0,0),Finale.sounds[key],1,Finale.SOUND_RANGE)
  check(voice!=null and voice.playing and is_equal_approx(voice.max_distance,195),"Recovered sound plays across enlarged skill range: "+key)
 for key in Finale.loops:
  check(Finale.loops[key].loop_mode==AudioStreamWAV.LOOP_FORWARD and Finale.loops[key].loop_end>0,"Held sound is prepared to loop: "+key)
 for heavy in [false,true]:
  for voice in presentation.voices:voice.stop()
  presentation.next_sound=0
  presentation.present([{"kind":"damage","unit_kind":18,"target_id":999,"position":p.position,"amount":1,"heavy":heavy}])
  var expected=Finale.sounds.hit_strong if heavy else Finale.sounds.hit
  check(presentation.voices.any(func(v):return v.playing and v.stream==expected),"Native enemy hit routes its recovered sound: "+str(heavy))
 for voice in presentation.voices:voice.stop()
 presentation.next_sound=0
 var ordinary=presentation.play_sound(p.position,Finale.sounds.cast)
 check(ordinary!=null and is_equal_approx(ordinary.max_distance,65),"Shared voice reuse restores the ordinary sound range")
 for voice in presentation.voices:voice.stop()
 presentation.next_sound=0
