extends "res://tests/forest-shrine/ruby_region_review.gd"
## Map coverage plus bounded source-aligned and gameplay cameras; no street walkthrough.
func _initialize():
 review_root="res://build/Other Files/Asset Toolkit/Kili Ghana Villages/"
 freeze_physics=true
 create_timer(1500).timeout.connect(func():printerr("KILI_GHANA_REVIEW_TIMEOUT");quit(1))
 run.call_deferred()
func local_point(cell:Vector2)->Vector2:
 if stage.area=="ghana":return Tour.Regions.Sites.VILLAGES.ghana[2]+cell*3.
 return super.local_point(cell)
func source_vector(vector:Vector2)->Vector2:
 return vector if stage.area=="ghana" else super.source_vector(vector)
func validate_visual_supports():pass
func isometric(name_:String,cell:Vector2,span:float):
 await super.isometric(name_,cell,span)
 for section in stage.sections:
  if section.key==name_:await gameplay(section);break
func gameplay(section:Dictionary):
 if records.any(func(p):return p.name==section.key+"-play"):return
 await super.gameplay(section)
func write_records():
 var unique={}
 for pose in records:unique[pose.name]=pose
 records=unique.values()
 super.write_records()
 var folder=review_root+phase+"/"
 var file=FileAccess.open(folder+"inventory-"+stage.key+".json",FileAccess.WRITE)
 var info=Tour.Indoor.floor_info(int(stage.floor)) if stage.area=="interior" else []
 var npcs=[]
 for node in game.world.map_features.find_children("*","Sprite3D",true,false):
  if node.has_meta("npc_name"):npcs.append({"name":node.get_meta("npc_name"),"position":var_to_str(node.position),"record":node.get_meta("npc_record",{})})
 file.store_string(JSON.stringify({"area":game.model.falan_area,"floor":game.model.falan_floor,"links":var_to_str(game.model.get_meta("falan_links",[])),"npcs":npcs,"mask":info[2] if not info.is_empty() else game.model.terrain.mask_texture().get_image().get_data().hex_encode().sha256_text()},"  "));file.close()
