extends "res://tests/forest-shrine/falan_pet_size_test.gd"

var reviewed=0

func check_frontier_patrols():
 if DisplayServer.get_name()=="headless":
  check(false,"The size catalog needs rendered Godot output")
  return
 game.paused=true
 DirAccess.make_dir_recursive_absolute(OUT+"Pet Size")
 var groups=[
  ["Habaru and Venoa",Habaru,["Ozunack / Habaru boss","Habaru bear","Green slime","Venoa great bear","Cave bear / summon"]],
  ["Zombie Cave",Zombie,["Modified zombie","Zombie","Rotting corpse","Hellhound"]],
  ["Pirate Cave",Captain,["Skeleton captain","Sea bat","Pirate"]],
  ["Forest Grave",Grave,["Shadow","Skeleton pirate","Grave guardian","Cupid"]],
  ["Black Prayer",Ruby,["Ruby","Bloody blade","Ghost"]],
  ["Undersea",Undersea,["Oznik / Undersea boss","Water dragon lizard","Lizard warrior"]],
 ]
 for page in 3:
  var rows=[]
  for group in groups.slice(page*2,page*2+2):
   for start in range(0,group[2].size(),4):
    var entries=[]
    for skin in range(start,mini(start+4,group[2].size())):entries.append({"source":group[1],"skin":skin,"name":group[2][skin]})
    rows.append({"title":group[0],"entries":entries})
  await capture_sheet("other-pets-%d"%(page+1),rows)
 for page in [["hound-pets-1",0,12],["hound-pets-2",12,21],["mantis-pets-1",21,33],["mantis-pets-2",33,41],["dragon-lizard-pets-1",41,53],["dragon-lizard-pets-2",53,61],["bee-pets-1",61,73],["bee-pets-2",73,82]]:
  var rows=[]
  for start in range(page[1],page[2],4):
   var entries=[]
   for skin in range(start,mini(start+4,page[2])):entries.append({"source":Pets,"skin":skin,"name":Pets.title(skin)})
   rows.append({"title":"Companion "+Pets.category(start),"entries":entries})
  await capture_sheet(page[0],rows)
 check(reviewed==104,"Every other dungeon appearance and all 82 companion appearances are pictured once")
 print("PET_CATALOG_REVIEW_RESULT appearances=",reviewed," failures=",errors)

func capture_sheet(filename:String,rows:Array):
 var pet_keys=[]
 for row in rows:
  for entry in row.entries:
   if entry.source==Pets:pet_keys.append(Pets.key(entry.skin))
 var pet_mesh:QuadMesh=Pets.make_mesh(pet_keys) if not pet_keys.is_empty() else null
 var viewport=SubViewport.new();viewport.size=Vector2i(2200,600*rows.size());viewport.own_world_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var env=WorldEnvironment.new();env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("202b36")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE
 viewport.add_child(env)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.size=44;camera.position=Vector3(0,rows.size()*6-2.5,25)
 viewport.add_child(camera)
 for row_index in rows.size():
  var row:Dictionary=rows[row_index];var base=float((rows.size()-row_index-1)*12)
  label(viewport,row.title+"  /  current game sizes",Vector3(0,base+8.7,1),48)
  var kaz:Sprite3D=game.player.model.sprite.duplicate();kaz.position+=Vector3(-17,base,0);viewport.add_child(kaz)
  label(viewport,"Kaz · 100%",Vector3(-17,base-1.8,1))
  for column in row.entries.size():
   var entry:Dictionary=row.entries[column];var source:Script=entry.source;var skin:int=entry.skin
   var x=-8.5+column*8.5
   check(skin>=0 and skin<source.motions().variants.size(),"Catalog skin exists: "+entry.name)
   var node=MultiMeshInstance3D.new();node.multimesh=MultiMesh.new()
   node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.use_custom_data=true
   node.multimesh.mesh=pet_mesh if source==Pets else source.make_mesh();node.multimesh.instance_count=1
   node.multimesh.set_instance_transform(0,Transform3D(Basis.IDENTITY,Vector3(x,base,0)))
   node.multimesh.set_instance_custom_data(0,Color(skin,entry.get("state",80),entry.get("clock",0.0),0));node.custom_aabb=AABB(Vector3(-25,-3,-3),Vector3(50,rows.size()*12+5,6))
   viewport.add_child(node);Sprites.apply_world_scale(node,game.model)
   var box:AABB
   var title:String=entry.name
   if source==Pets:
    box=Dimensions.companion_body(skin)
    title+="\n#%d"%int(source.motions().variants[skin].id)
   else:
    box=Dimensions.body(source,skin)
    title+=" · %d%%"%roundi(box.size.y/Dimensions.KAZ_HEIGHT*100)
   label(viewport,title,Vector3(x,base-1.8,1))
   outline(viewport,box,Vector3(x,base,0))
   reviewed+=1
 for i in 5:await process_frame
 await RenderingServer.frame_post_draw
 var path=filename if filename.begins_with("res://") else OUT+"Pet Size/"+filename+".png"
 check(viewport.get_texture().get_image().save_png(path)==OK,"Rendered "+path)
 print("PET_CATALOG_SHEET ",path)
 viewport.queue_free()
 await process_frame

func label(parent:Node,text:String,at:Vector3,size_:int=38):
 var node=Label3D.new();node.text=text;node.font_size=size_;node.pixel_size=.012
 node.position=at;parent.add_child(node)

func outline(parent:Node,box:AABB,at:Vector3):
 var lines=ImmediateMesh.new();lines.surface_begin(Mesh.PRIMITIVE_LINES)
 var corners=[]
 for y in [box.position.y,box.end.y]:
  for z in [box.position.z,box.end.z]:
   for x in [box.position.x,box.end.x]:corners.append(Vector3(x,y,z)+at)
 for pair in [[0,1],[0,2],[1,3],[2,3],[4,5],[4,6],[5,7],[6,7],[0,4],[1,5],[2,6],[3,7]]:
  lines.surface_add_vertex(corners[pair[0]]);lines.surface_add_vertex(corners[pair[1]])
 lines.surface_end()
 var wire=MeshInstance3D.new();wire.mesh=lines;var material=StandardMaterial3D.new()
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color("63d4ed");material.no_depth_test=true
 wire.material_override=material;parent.add_child(wire)
