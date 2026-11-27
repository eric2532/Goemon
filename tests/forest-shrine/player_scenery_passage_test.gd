extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const Art=preload("res://scripts/forest/forest_art.gd")
const Document=preload("res://scripts/forest/forest_map_document.gd")
const Driver=preload("res://tests/forest-shrine/physics_step_driver.gd")
const TREE=Vector2i(-16,17)
const ROCK=Vector2i(-19,17)
const SHRUB=Vector2i(-19,20)
const WALL=Vector2i(-16,20)
const GATE=Vector2i(-13,20)

func collider_at(anchor:Vector2i)->StaticBody3D:
 for body:StaticBody3D in game.world.forest_root.find_children("*","StaticBody3D",true,false):
  if body.has_meta("map_scenery_cell") and body.get_meta("map_scenery_cell")==anchor:return body
 return null

func verify_passage(anchor:Vector2i,label_:String):
 var body=collider_at(anchor)
 check(is_instance_valid(body) and body.is_in_group(Art.PLAYER_PASSABLE_SCENERY),label_+" has a tagged world collider")
 if not is_instance_valid(body):return
 var box:AABB=game.model.scenery_obstacles[anchor]
 var at:Vector3=box.get_center()
 var from=at-Vector3.RIGHT*(box.size.x*.5+2.0)
 from.y=game.world.height_at(from.x,from.z)+.04
 var move=Vector3.RIGHT*(box.size.x+4.0)
 var player:CharacterBody3D=game.player
 check(body in player.get_collision_exceptions() and not player.test_move(Transform3D(Basis.IDENTITY,from),move),label_+" does not stop player movement")
 var lane=Vector3(from.x,at.y,at.z)
 check(body.collision_layer==1 and not AttackChain.clear_line(player,lane,lane+move),label_+" still provides solid combat cover")

func run():
 cfg="/tmp/player-scenery-passage-%d.cfg"%OS.get_process_id()
 create_timer(120).timeout.connect(func():printerr("PLAYER_SCENERY_PASSAGE_TIMEOUT");quit(1))
 var map=Document.new()
 map.load_wind_meadow()
 map.data.trees=[{"x":TREE.x,"z":TREE.y,"scale":1.0}]
 map.data.rocks=[{"x":ROCK.x,"z":ROCK.y,"scale":1.0,"rotation":0}]
 map.data.props=[{"kind":"shrub","x":SHRUB.x,"z":SHRUB.y,"scale":1.0,"rotation":0},
  {"kind":"wall_piece","x":WALL.x,"z":WALL.y,"scale":1.0,"rotation":0}]
 map.data.buildings=[{"kind":"gate","x":GATE.x,"z":GATE.y,"rotation":0}]
 await setup_fixture(map.data)
 game.set_process(false);game.army_runtime.set_process(false)
 game.player.select_character(game.player.RogueRoster.KAZI_ID)
 await physics_frame
 verify_passage(TREE,"Tree")
 verify_passage(ROCK,"Rock")
 verify_passage(SHRUB,"Decorative prop")
 var wall=collider_at(WALL)
 var player:CharacterBody3D=game.player
 check(is_instance_valid(wall) and wall not in player.get_collision_exceptions(),"Structural wall remains solid even as a placed object")
 var wall_bounds:AABB=game.model.scenery_obstacles[WALL]
 var wall_start=wall_bounds.get_center()-Vector3.RIGHT*(wall_bounds.size.x*.5+2.0)
 wall_start.y=game.world.height_at(wall_start.x,wall_start.z)+.05
 check(player.test_move(Transform3D(Basis.IDENTITY,wall_start),Vector3.RIGHT*(wall_bounds.size.x+4.0)),"Player movement hits the structural wall")
 check(player.test_move(Transform3D(Basis.IDENTITY,wall_start+Vector3.UP*3),Vector3.DOWN*5),"Player movement still lands on terrain")
 var gate:Node3D=game.world.structure_nodes.get(game.model.occupancy.get(GATE,-1))
 check(is_instance_valid(gate),"An authored gate remains present")
 if is_instance_valid(gate):
  var door:StaticBody3D=gate.get_node("GateDoor/GateDoorCollider")
  check(door.collision_layer==32 and door not in player.get_collision_exceptions(),"The closed gate keeps its existing collision layer")
  var profile=game.world.Profile
  var gate_start=gate.to_global(Vector3(profile.GATE_PILLAR_X,0,profile.GATE_FRAME_DEPTH*.5+2.0))
  gate_start.y=game.world.height_at(gate_start.x,gate_start.z)+.05
  check(player.test_move(Transform3D(Basis.IDENTITY,gate_start),Vector3.FORWARD*(profile.GATE_FRAME_DEPTH+4.0)),"Player movement still hits the gate frame")

 var tree_bounds:AABB=game.model.scenery_obstacles[TREE]
 var start=tree_bounds.get_center()-Vector3.RIGHT*(tree_bounds.size.x*.5+2.0)
 start.y=game.world.height_at(start.x,start.z)+.05
 player.global_position=start
 var driver=Driver.new();root.add_child(driver)
 await driver.advance(30,func(_dt):
  player.velocity=Vector3(20,-3,0)
  player.move_and_slide())
 check(player.global_position.x>tree_bounds.end.x and player.position.y>start.y-2,"Actual player physics crosses the tree and stays supported")
 driver.queue_free()

 game.army_runtime.static_collision_data(game.world)
 var tree=collider_at(TREE)
 check(game.army_runtime.static_collision_cache.has(tree.get_child(0).get_instance_id()),"Native collision still exports the scenery body")
 for cycle in 2:
  var previous=collider_at(TREE)
  game.model.trees[TREE]=1.25+cycle*.25
  game.model.rebuild_scenery()
  game.world.reload_scenery()
  await physics_frame
  check(collider_at(TREE)!=previous,"Scenery edit rebuilds the tagged tree body")
  verify_passage(TREE,"Rebuilt tree %d"%(cycle+1))
 var previous=collider_at(TREE)
 game.world.reload_map(map.data)
 await physics_frame
 check(collider_at(TREE)!=previous,"Reloading the map replaces the old body")
 verify_passage(TREE,"Reloaded tree")
 check(player.get_collision_exceptions().size()==3,"Only the current scenery bodies have exceptions after repeated rebuilds")
 game.queue_free();current_scene=null;paused=false
 await frames(4)
 DirAccess.remove_absolute(cfg)
 print("PLAYER_SCENERY_PASSAGE_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
