extends SceneTree
## Exercise the shipped scene with no benchmark or backend setup.
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_kai_highway()
 set_meta("forest_custom_layout",doc.data)
 # An obsolete setting must not be able to select the removed engine.
 set_meta("forest_army_backend","legacy")
 var game=load("res://scenes/forest_shrine.tscn").instantiate()
 game.settings_path="user://army-cutover-%d.cfg"%OS.get_process_id();root.add_child(game)
 for i in 3:await process_frame
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.explorer_helpers.set_process(false)
 var army=game.army_runtime
 check(is_instance_valid(army),"The normal game always constructs the native army owner, ignoring obsolete settings")
 if not is_instance_valid(army):await cleanup(game);return
 check(game.model.army_runtime==army,"World and game share exactly one army owner")
 check(game.explorer_helpers.pool.size()==5 and game.explorer_helpers.pool.all(func(u):return not u is Hero and u.runtime==army),"All five summon kits use lightweight native actors")
 check(game.explorer_helpers.get("rigid_renderer")==null,"No retired per-controller ally renderer is created")
 check(game.pursuit==null,"No retired enemy pursuit node is created")
 check(game.model.terrain_source=="kai_highway" and game.model.portals.size()==doc.data.portals.size(),"The live map retains the hills, bridges and all authored portals")
 check(game.crowd.get("primitive_batches")==null or game.crowd.primitive_batches.is_empty(),"The normal scene does not initialize retired crowd batches")
 var guards=game.explorer_helpers
 for slot in 5:guards.pool[slot].summon(null,Vector3(-18+slot*9,.12,18),0)
 check(guards.active_units().size()==5,"All five native kits can prepare independently")
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=10000
 var rows=[]
 for kind in [0,1,3]:rows.append(game.model.waves.spawn_enemy(kind,Vector3(55+kind*12,0,70)))
 game._physics_process(1.0/60)
 check(rows.all(func(row):return army.handles.has(row.id) and game.actors[row.id] is Ninja),"Ordinary wave spawns enter native combat through the normal physics loop")
 check(guards.active_units().all(func(u):return army.valid(u.handle)),"Every summoned ally retains its native health owner in combat")
 var victim=rows[0];var handle:int=army.handles[victim.id];var gold:int=game.model.gold
 game.model.damage_enemy(victim.id,1000000)
 check(not army.valid(handle) and game.model.gold>gold,"Normal model damage kills native enemies and awards the bounty immediately")
 var steps:int=army.simulation_steps;game.ordinary_pause=true;game._physics_process(1.0/60);game.ordinary_pause=false
 check(army.simulation_steps==steps,"Pause does not advance native combat")
 game.model.phase="preparing";game.set_phase_view()
 check(guards.active_units().size()==5 and guards.active_units().all(func(u):return army.valid(u.handle)),"Wave completion retains surviving native allies")
 game.preview_forest_map(doc.data)
 check(game.model.army_runtime==army and army.configured_model==game.model and army.snapshot().handles.is_empty(),"Map replacement binds and clears the native owner during preparation")
 guards.pool[0].summon(null,Vector3(0,.12,18),0)
 check(army.valid(guards.pool[0].handle),"Summoning after map replacement uses the current native world")
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=10000
 var after_reload=game.model.waves.spawn_enemy(1,Vector3(65,0,70));game._physics_process(1.0/60)
 check(army.handles.has(after_reload.id),"A wave after map replacement imports into the same sole engine")
 game.show_title();game.begin_forest()
 check(army.snapshot().handles.is_empty() and guards.active_units().is_empty(),"Restart clears native state and paid allies without a second engine")
 await cleanup(game)
func cleanup(game):
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
 for i in 4:await process_frame
 print("ARMY_CUTOVER_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
