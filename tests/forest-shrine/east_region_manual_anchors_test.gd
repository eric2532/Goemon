extends SceneTree
const Region=preload("res://scripts/forest/forest_east_region.gd")
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
var failures=[]
var checks=0
class Model extends RefCounted:
 var falan_area="interior"
 var falan_floor=0
 func surface_height(_x:float,_y:float)->float:return 0.

func _initialize():call_deferred("run")
func check(value:bool,label:String):
 checks+=1
 if not value:failures.append(label)
func run():
 var population=Region.residents();var sources={};var rows=[];var visible={}
 for npc in population.npcs:visible[str(npc.id)]=true
 var harbor=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/east_region/harbor.json"))
 for npc in harbor.npcs:visible[str(npc.id)]=true
 for actor in population.actors:
  if actor.get("generated_by")!=null:continue
  var source=int(actor.source);var kind=str(actor.type).to_lower()
  if source!=100 and source not in Region.data().fixed_maps:continue
  if kind not in ["event","housemaster"] and (not population.scripts.has(actor.script) or kind in ["watchevent","watchex","watch","warp","standenemy"]):continue
  if not actor.get("invisible",false):
   check(visible.has(str(actor.id)),"Manual visible actor has no existing NPC owner "+str(actor.id));continue
  var area=Region.source_area(100,Vector2i(actor.cell[0],actor.cell[1])) if source==100 else "interior"
  sources[Vector2i(source,0 if area=="east_gate" else 1 if area=="north_coast" else 2)]=area
 for key in sources:
  var model=Model.new();model.falan_area=sources[key];model.falan_floor=Maps.runtime_id(key.x) if key.x!=100 else 0
  var holder=Node3D.new();root.add_child(holder)
  var expected=Region.manual_anchors([key.x],model.falan_area)
  var registered=Region.build_manual_anchors(holder,model,[key.x])
  check(registered.size()==expected.size(),"Not every manual source event was registered inmap%d"%key.x)
  var sprites=holder.find_children("*","Sprite3D",true,false)
  check(sprites.size()==expected.size(),"Transparent anchor count mismatch inmap%d"%key.x)
  for sprite in sprites:
   var record:Dictionary=sprite.get_meta("npc_record",{})
   check(record.quest_action=="east_event:"+str(record.id),"Unattached manual event "+str(record.id))
   check(sprite.is_visible_in_tree(),"Invisible node cannot be enrolled forF "+str(record.id))
   var cell=Vector2i(record.cell[0],record.cell[1]);var wanted=Region.source_point(key.x,cell,model.falan_area if key.x==100 else "")
   check(Vector2(sprite.position.x,sprite.position.z).is_equal_approx(wanted),"Manual event moved from source cell "+str(record.id))
   check(sprite.texture is AtlasTexture and sprite.texture.atlas==null,"Manual event invented visible artwork "+str(record.id))
   rows.append({"actor":str(record.id),"source":key.x,"cell":record.cell,"quest_action":record.quest_action,"transparent":true,"source_program_present":population.scripts.has(record.script)})
  check(Region.build_manual_anchors(holder,model,[key.x]).is_empty(),"Manual event duplicated on repeatedsetup map%d"%key.x)
  holder.free()
 var report={"checks":checks,"failures":failures,"invisible_manual_anchors":rows,"visible_manual_owners":visible.size()}
 var file=FileAccess.open("res://build/Other Files/Asset Toolkit/East Gate Region/manual-anchor-matrix.json",FileAccess.WRITE);file.store_string(JSON.stringify(report," ")+"\n");file.close()
 print("EAST_MANUAL_ANCHORS_RESULT anchors=",rows.size()," maps=",sources.size()," checks=",checks," failures=",failures.size())
 for failure in failures:push_error(failure)
 quit(0 if failures.is_empty() else 1)
