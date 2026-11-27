extends "res://tests/forest-shrine/east_village_props_review.gd"
## Read-only geometry ownership audit; no terrain, cliff, route or collider edits.
var cliff_nodes=[]
func run():
 root.size=Vector2i(1440,900);phase="VillageCliffs";review_area="alyut"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+phase))
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east-cliff-audit-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 game.model.team_progression.cards_enabled=false;game.tuning.invincible=true;game.player.set_auto_attack(false)
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 await open_area("north_coast");await site(2400,"alyut")
 await prop_views("alyut-cliff-context",Vector2i(63,35),Vector2i(37,58),Vector2i(45,60))
 var origin:Vector2=Tour.Regions.Sites.VILLAGES.alyut[2]
 var placement=Tour.Regions.village_transform("alyut")
 for node in game.world.find_children("*","GeometryInstance3D",true,false):
  if node is MeshInstance3D and node.mesh!=null:audit_node(node,node.mesh,node.global_transform,-1,origin,placement)
  elif node is MultiMeshInstance3D and node.multimesh!=null and node.multimesh.mesh!=null:
   for i in node.multimesh.instance_count:audit_node(node,node.multimesh.mesh,node.global_transform*node.multimesh.get_instance_transform(i),i,origin,placement)
 var out=FileAccess.open(PROP_OUT+"cliff-owners.json",FileAccess.WRITE)
 out.store_string(JSON.stringify({"checks":checks,"failures":errors,"captures":captures,"tall_geometry":cliff_nodes},"  "));out.close()
 print("EAST_CLIFF_AUDIT_RESULT checks=",checks," failures=",errors," tall_geometry=",cliff_nodes.size());await finish()

func source_meta(object:Object)->Dictionary:
 var result={}
 for key in object.get_meta_list():
  if "source" in key or "graphic" in key or "cliff" in key:result[str(key)]=var_to_str(object.get_meta(key))
 return result

func audit_node(node:GeometryInstance3D,mesh:Mesh,pose:Transform3D,index:int,origin:Vector2,placement:Transform2D):
 var box: AABB=pose*mesh.get_aabb();var scale_=game.model.falan_scale
 if box.size.y/scale_<7. or box.size.x/scale_>300. or box.size.z/scale_>300.:return
 var center=box.get_center()/scale_;var cell=(placement.inverse()*Vector2(center.x,center.z)-origin)/3.
 if not Rect2(-20,-20,140,140).has_point(cell):return
 cliff_nodes.append({"node":str(node.get_path()),"instance":index,"class":node.get_class(),"mesh_resource":mesh.resource_path,"world_aabb":var_to_str(box),"village_cell_center":[cell.x,cell.y],"local_height":box.size.y/scale_,"node_meta":source_meta(node),"mesh_meta":source_meta(mesh)})
