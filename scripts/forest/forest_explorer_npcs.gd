extends Node
## Casual conversations for the existing Falan citizen placements.
const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const FalanDialogue=preload("res://assets/maps/falan/npc_dialogue.gd")
var game
var map_signature:Array=[]
var actors:Array=[]
var hint:Label3D
var nearest:Dictionary={}
var selected:Dictionary={}
var talk_bags:Dictionary={}
var update_left=0.0
func _ready():name="ExplorerNPCs"
func _process(delta):
 if game.model==null or not game.playing:return
 var signature=[game.model.get_instance_id(),game.model.falan_area,game.model.falan_floor,game.world.map_features.get_instance_id()]
 if map_signature!=signature:map_signature=signature;prepare()
 if not available():return
 update_left-=delta
 if update_left>0:return
 update_left=.15;nearest={}
 var distance=pow(5.0*game.model.falan_scale,2)
 for entry in actors:
  if not is_instance_valid(entry.node) or not entry.node.is_visible_in_tree():continue
  var at:Vector3=entry.node.global_position;var d=game.player.position.distance_squared_to(at)
  if d>=distance or not game._ryo_clear_path(game.player.position+Vector3.UP*2.5,at+Vector3.UP*2.5):continue
  nearest=entry;distance=d
 if is_instance_valid(hint):
  hint.visible=not nearest.is_empty()
  if hint.visible:hint.global_position=nearest.node.global_position+Vector3.UP*(4.0*game.model.falan_scale);hint.text="F · "+nearest.record.name
func prepare():
 actors.clear();nearest={}
 if is_instance_valid(hint):hint.get_parent().remove_child(hint);hint.queue_free()
 hint=null
 var area=str(game.model.falan_floor) if game.model.falan_area=="interior" else game.model.falan_area
 var citizens=game.world.map_features.find_child("OriginalFalanNPCs",true,false)
 if not Tour.NPCS.AREAS.has(area) or citizens==null:return
 var rows:Array=Tour.NPCS.AREAS[area]
 for i in rows.size():
  var sprite:Sprite3D=citizens.get_child(i)
  actors.append({"node":sprite,"record":{"id":"falan:%s:%d"%[area,i],"name":rows[i][2],"type":"FalanCitizen","portrait":sprite.texture,"messages":FalanDialogue.lines_for(rows[i])}})
 hint=Label3D.new();hint.font=preload("res://scripts/forest/preparation_skin.gd").FONT;hint.font_size=36;hint.pixel_size=.014
 hint.billboard=BaseMaterial3D.BILLBOARD_ENABLED;hint.hide();game.world.map_features.add_child(hint)
func available()->bool:
 return game.playing and not game.paused and not game.transitioning and not game.ordinary_pause and game.model.phase=="wave" and game.player.hp>0 and not Tour.area(game.model).is_empty()
func interact()->bool:
 if not available() or nearest.is_empty():return false
 selected=nearest.record
 var key=selected.id
 if talk_bags.get(key,[]).is_empty():talk_bags[key]=selected.messages.duplicate();talk_bags[key].shuffle()
 var pages=[{"text":talk_bags[key].pop_back(),"portrait":selected.portrait,"options":[]}]
 game.show_boss_dialogue(selected.name,pages,hint,finish)
 return true
func finish():
 if is_instance_valid(game.dialogue):game.close_boss_dialogue()
