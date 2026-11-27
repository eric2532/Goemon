extends "res://tests/forest-shrine/east_village_props_review.gd"
## Scoped native-crag geometry contracts and actual reachable camera review.
const FieldCliffs=preload("res://scripts/forest/forest_east_field_cliffs.gd")
var cliff_meshes=[]
var source_placements=[]
var source_cliff_cells={}
func run():
 root.size=Vector2i(1440,900);phase="FieldCliffs"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+phase))
 for serial in range(12536,12548):
  var mesh:Mesh=FieldCliffs.mesh(serial);var profile:Dictionary=FieldCliffs.Native.data()[str(serial)]
  var bound=mesh.get_aabb();var size_:Array=FieldCliffs.Native.graphic(serial).footprint
  var border=int(size_[0])==1
  var proof:Dictionary=mesh.get_meta("east_source_correlated_relief",{})
  check(mesh.get_surface_count()>0 and (border or proof.source_footprint==size_ and proof.source_contour.shared_native_modified==false),"Source footprint cells remain authoritative; separately verified native alpha permits visual overhang: "+str(serial))
  var expected:Array=proof.get("geometry_bounds",[[0,0,0],[0,0,0]])
  check(mesh.has_meta("native_border_crest") if border else bound.position.y>=-.001 and absf(bound.end.y-float(expected[1][1]))<.001,"Source-contour height replaces the old proxy box; sparse black borders retain actual native crest art: "+str(serial))
  check((border or closed_top(mesh)) and mesh.get_meta("east_inferred_reverse",false),"Native crag is closed; fine border crest reuses source alpha with shallow relief: "+str(serial))
  cliff_meshes.append({"graphic":serial,"aabb":var_to_str(bound),"source_height":profile.height,"presentation":"native_border_crest" if border else "solid_measured_crag"})
 check(not FieldCliffs.owns("laruka",12536,true) and not FieldCliffs.owns("west_lakes",12536,true) and not FieldCliffs.owns("south_lakes",12536,true),"Shared western/southern ridge ownership remains unchanged")
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east-field-cliffs-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 game.model.team_progression.cards_enabled=false;game.tuning.invincible=true;game.player.set_auto_attack(false)
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 review_area="alyut";await open_area("north_coast");await site(2400,"alyut")
 await prop_views("alyut-stable",Vector2i(51,44),Vector2i(63,35),Vector2i(60,41))
 await prop_views("alyut-cliff-context",Vector2i(51,44),Vector2i(63,35),Vector2i(60,60))
 check(not game.world.find_children("EastNativeCliff_*","MultiMeshInstance3D",true,false).is_empty(),"Joined North Coast uses the measured native crag owner")
 for node in game.world.find_children("*","Node3D",true,false):
  if node.get_meta("east_native_cliff_source_map",0)!=2400:continue
  source_placements=node.get_meta("east_native_cliff_source_placements",[])
  check(source_placements.size()==125 and node.get_meta("east_native_cliff_cells",0)==579,"All125native Alyut cliff placements and579distinct footprint cells are recovered, with the old12seam rows deduplicated")
 check(source_placements.size()==125,"Full native Alyut cliff owner is mounted once inside the joined village")
 await open_area("east_gate")
 await field_view("habaru-mouth-normal",Vector2(669,225),Vector2(672,223))
 await field_view("habaru-mouth-second",Vector2(676,222),Vector2(672,223))
 await field_view("east-field-normal",Vector2(572,236),Vector2(579,241))
 await field_view("east-field-second",Vector2(582,237),Vector2(579,241))
 check(not game.world.find_children("EastNativeCliff_*","MultiMeshInstance3D",true,false).is_empty(),"East Gate field uses the measured native crag owner")
 var file=FileAccess.open(PROP_OUT+"Cliff Audit/review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"observations":observations,"captures":captures,"meshes":cliff_meshes,"source_placements":source_placements,"source_map":FieldCliffs.VillageProps.data().source_maps.alyut,"scope":"East Gate/North Coast tall ArchivedGateRidges plus all125native Alyut cliffs; original anchors, collisions, terrain, route events and Habaru mouth cutout retained.","inferred_visuals":["Existing measured solid crag profiles and closed native coastal rock/moss backs", "Sparse native border/crest paint retains alpha relief with inferred0.12m depth"]},"  "));file.close()
 print("EAST_FIELD_CLIFFS_RESULT checks=",checks," failures=",errors," captures=",captures.size());await finish()

func field_view(label:String,preferred:Vector2,target:Vector2):
 var frame=Tour.Regions.frame("east_gate").inverse();var at=frame*(preferred*3.);var found=false
 for radius in 10:
  for y in range(-radius,radius+1):
   for x in range(-radius,radius+1):
    var sample=frame*((preferred+Vector2(x,y))*3.)
    if game.model.terrain.disk_clear(Vector3(sample.x,0,sample.y),.55):at=sample;found=true;break
   if found:break
  if found:break
 check(found,"Field camera anchor is on the original reachable walk-grid: "+label)
 if not found:return
 await position_at(at);var facing=(frame*(target*3.)-at).normalized()
 var source=Tour.Regions.frame("east_gate")*at/3.
 await gameplay_capture(label,"Normal gameplay camera at original map100 walk-grid cell "+str(source),atan2(-facing.x,-facing.y))

func closed_top(mesh:Mesh)->bool:
 var box=mesh.get_aabb();var at=Vector3(box.get_center().x,box.end.y+1.,box.get_center().z)
 for slot in mesh.get_surface_count():
  var arrays=mesh.surface_get_arrays(slot);var vertices=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX]
  var count_=indices.size() if indices is PackedInt32Array and not indices.is_empty() else vertices.size()
  for offset in range(0,count_,3):
   var points=[]
   for i in 3:points.append(vertices[indices[offset+i] if indices is PackedInt32Array and not indices.is_empty() else offset+i])
   if Geometry3D.ray_intersects_triangle(at,Vector3.DOWN,points[0],points[1],points[2])!=null:return true
 return false

func open_cell(cell:Vector2i)->bool:
 if not super.open_cell(cell):return false
 if review_area!="alyut":return true
 if source_cliff_cells.is_empty():
  for row in FieldCliffs.VillageProps.data().audit:
   if int(row.map)!=2400 or int(row.graphic) not in range(12536,12548):continue
   var g:Dictionary=FieldCliffs.Native.graphic(int(row.graphic))
   for z in int(g.footprint[1]):
    for x in int(g.footprint[0]):source_cliff_cells[Vector2i(row.cell[0]+x,row.cell[1]-z)]=true
 return not source_cliff_cells.has(cell)
