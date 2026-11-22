extends "res://tests/forest-shrine/freyja_villages_habaru_test.gd"
const Stones=preload("res://scripts/forest/forest_travel_stones.gd")
var checks=0
func check(ok:bool,message:String):
 checks+=1
 super.check(ok,message)

func check_east_il_road():
 var folder="res://build/Other Files/Asset Toolkit/Falan Travel Stones 3D/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 game.tuning.invincible=true
 check_ground_tiles()
 var venture:Dictionary=get_meta("falan_venture")
 check(game.world.find_children("FalanTravelStone_*","MeshInstance3D",true,false).size()==6,"All six travel crystals use solid imported 3D meshes")
 check(game.model.get_meta("falan_links").filter(func(link):return link.to=="city_stone" and not link.get("walk_in",false)).size()==6,"Stones appear on the chart without automatic travel")
 var encoded=JSON.stringify(venture)
 var originals=game.world.find_children("TravelOrnament_*","MeshInstance3D",true,false)
 check(originals.size()>40,"The carved shrine surroundings use solid 3D meshes")
 for node in originals:
  check(node.mesh.get_aabb().size.min_axis_index()>=0 and node.mesh.get_aabb().size[node.mesh.get_aabb().size.min_axis_index()]>.20,"Shrine ornaments have real depth on every axis")
 check(game.world.find_children("OriginalTravelOrnament_*","Sprite3D",true,false).is_empty(),"Retired flat ornament sprites are absent")
 var crystals=game.world.find_children("FalanTravelStone_*","MeshInstance3D",true,false)
 for node in crystals:
  check(node.mesh==crystals[0].mesh and node.material_override==crystals[0].material_override,"All crystals share their prepared mesh and rotating facet material")
  check(node.get_children().is_empty(),"The crystal has no hidden billboard or per-frame controller")
 var model=game.model
 var world=game.world
 var runtime=game.army_runtime
 check(not Stones.open(game),"Travel cannot open away from a stone")
 for i in Stones.Data.STONES.size():
  var row:Array=Stones.Data.STONES[i]
  check(row[2]==Vector2(row[1].y-134,153-row[1].x)*3,"Stone preserves the original map 1000 cell")
  await position_at(row[2])
  check(Stones.nearby(game)==i,"The original stone can be approached")
  for j in Stones.Data.STONES.size():
   if i==j:continue
   await position_at(row[2])
   check(Stones.open(game),"A nearby stone opens travel")
   if not is_instance_valid(game.travel_panel):continue
   check(paused and game.paused and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Travel pauses combat and releases the pointer")
   if i==0 and j==1 and DisplayServer.get_name()!="headless":
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(folder+"travel-menu.png")
   game.travel_panel.choose(j)
   check(not paused and not is_instance_valid(game.travel_panel),"Choosing a destination resumes exploration")
   check(map_position().distance_to(Stones.Data.STONES[j][2])<=4.6 and game.player.velocity==Vector3.ZERO,"Each route lands beside its destination without stale movement")
   check(game.model==model and game.world==world and game.army_runtime==runtime,"Local travel keeps the existing world and native army")
  if DisplayServer.get_name()!="headless":
   await position_at(row[2])
   var center=game.model.world_point(row[2])/game.model.falan_scale
   await shot("Gate Shortcuts/stone-"+str(i),(center+Vector3(5,5,9))*game.model.falan_scale,(center+Vector3.UP*2)*game.model.falan_scale,60)
 await position_at(Stones.Data.STONES[0][2])
 var open_key=InputEventKey.new();open_key.physical_keycode=KEY_E;open_key.pressed=true
 game._input(open_key)
 check(is_instance_valid(game.travel_panel),"E reopens travel after repeated use")
 var at=game.player.position
 game.travel_panel.choose(-1)
 check(is_instance_valid(game.travel_panel) and game.player.position==at,"Invalid destinations leave the menu and player intact")
 var blocked:Vector2=Stones.Data.STONES[1][2]
 var key=Vector2i(99999,99999)
 game.model.scenery_obstacles[key]=AABB(Vector3(blocked.x-10,0,blocked.y-10),Vector3(20,30,20))
 game.travel_panel.choose(1)
 check(is_instance_valid(game.travel_panel) and game.player.position==at,"A blocked destination cannot move the player into scenery")
 game.model.scenery_obstacles.erase(key)
 var event=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=true
 game._input(event)
 check(not paused and game.player.position==at,"Escape cancels without travel")
 check(JSON.stringify(venture)==encoded,"Travel never rewrites the saved map")
 for area in ["freyja","east_gate","south_gate"]:
  Tour.travel(game,Tour.outdoor_layout(venture,area),{"arrival":Vector2(3,174),"yaw":PI,"velocity":Vector3.ZERO})
  for i in 5:await physics_frame
  check(not Stones.open(game),"City stones are unavailable outside Falan")
  var scale_:float=game.model.falan_scale
  var label="baseline" if "--baseline" in OS.get_cmdline_user_args() else "after"
  if DisplayServer.get_name()!="headless":
   for z in [160,180,210]:
    await shot("Gate Shortcuts/"+label+"-"+area+"-"+str(z),Vector3(3,13,z)*scale_,Vector3(3,7,z+30)*scale_,65)
  # Exercise the actual movement and crossing code in both directions.
  await position_at(Vector2(3,174))
  game.camera_rig.yaw=PI
  Input.action_press("move_forward")
  for i in 60:await physics_frame
  Input.action_release("move_forward")
  check(map_position().y>175 and (area!="east_gate" or game.player.is_on_floor()),"The player walks out of %s on solid ground: %s floor=%s"%[area,map_position(),game.player.is_on_floor()])
  await position_at(Vector2(3,Tour.Frontier.INNER_EDGE[area]+1))
  await position_at(Vector2(3,Tour.Frontier.INNER_EDGE[area]-1))
  check(Tour.area(game.model)=="city","Every gate returns to the city on foot")
 print("GATE_SHORTCUTS_RESULT checks=",checks," failures=",errors)

func check_ground_tiles():
 var art=preload("res://scripts/forest/forest_freyja_art.gd")
 var source=Image.create_empty(32*36,36,false,Image.FORMAT_RGB8)
 source.fill(Color.BLUE)
 source.fill_rect(Rect2i(0,0,36,36),Color.RED)
 source.fill_rect(Rect2i(36,0,36,36),Color.GREEN)
 var atlas=ImageTexture.create_from_image(source)
 var tiles=art.ground_tiles(atlas)
 check(art.ground_tiles(atlas)==tiles,"Ground tiles are prepared once per atlas")
 if DisplayServer.get_name()=="headless":
  art.tile_arrays.erase(atlas)
  return
 check(tiles.get_layers()==32 and tiles.get_width()==32,"Each ground tile has its own filtered layer")
 for i in 2:
  var image=tiles.get_layer_data(i)
  var base=image.duplicate();base.clear_mipmaps();base.convert(source.get_format())
  check(base.get_data()==source.get_region(Rect2i(i*36+2,2,32,32)).get_data(),"Ground recovery preserves the exact original tile pixels")
  var bytes=image.get_data()
  var offset=image.get_mipmap_offset(image.get_mipmap_count())
  var color=Color8(bytes[offset],bytes[offset+1],bytes[offset+2])
  check(color==(Color.RED if i==0 else Color.GREEN),"Even the farthest mip cannot pick up an adjacent tile's color")
 art.tile_arrays.erase(atlas)

func shot(name_:String,eye:Vector3,target:Vector3,fov:float,refresh_army:bool=false):
 game.ui.hide();game.set_process(false)
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=eye;camera.look_at(target);camera.fov=fov;camera.reset_physics_interpolation()
 for i in 10:await process_frame
 await RenderingServer.frame_post_draw
 var path="res://build/Other Files/Asset Toolkit/Falan Travel Stones 3D/"+name_.get_file()+".png"
 check(root.get_texture().get_image().save_png(path)==OK,"Captured "+name_)
 game.set_process(true);game.ui.show()
