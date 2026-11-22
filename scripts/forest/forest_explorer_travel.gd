extends RefCounted
## Direct area access without NPC services or quest prerequisites.
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const FLOORS=[4200,32181,32193,32183,32194,4206,4208,4210,4212,4213,4214,4215,4216,4221,4222,4223,4230,4232,4299,1850,14017,14018,14019,14020,14021,14022,14023,14024,14025,14036,14037,14038,14039]
const ARRIVALS={4200:Vector2i(38,46),32181:Vector2i(94,66),32193:Vector2i(33,39),32183:Vector2i(26,33),1850:Vector2i(5,4)}
static func open(game,page:int=0)->bool:
 if not game.playing or game.paused or game.transitioning or game.ordinary_pause or game.model.phase!="wave" or game.player.hp<=0 or Tour.area(game.model).is_empty():return false
 var choices=options(page)
 var trigger=Label3D.new()
 game.show_boss_dialogue("區域旅行",[{"text":"選擇想進入的區域。","portrait":null,"options":choices}],trigger,game.close_boss_dialogue)
 trigger.free()
 game.dialogue.chosen.connect(choose.bind(game))
 return true
static func options(page:int)->Array:
 var floors=FLOORS.filter(func(id):return Maps.owns(id))
 page=clampi(page,0,maxi(0,(floors.size()-1)/4))
 var choices=[]
 for id in floors.slice(page*4,page*4+4):choices.append(["area:%d"%id,Maps.title(id)])
 if page>0:choices.append(["page:%d"%(page-1),"上一頁"])
 if (page+1)*4<floors.size():choices.append(["page:%d"%(page+1),"下一頁"])
 choices.append(["cancel","返回"])
 return choices
static func choose(answer:String,game):
 if not is_instance_valid(game.dialogue) or game.dialogue.speaker!="區域旅行":return
 if answer.begins_with("page:"):
  var page=answer.trim_prefix("page:")
  if page.is_valid_int():game.dialogue.pages[0].options=options(int(page));game.dialogue.show_page()
  return
 if answer=="cancel":game.close_boss_dialogue();return
 var value=answer.trim_prefix("area:")
 if not answer.begins_with("area:") or not value.is_valid_int() or int(value) not in FLOORS or not Maps.owns(int(value)):return
 var id=game.explorer_clock.phase_floor(Maps.runtime_id(int(value)))
 var row=Maps.state(id);var cell:Vector2i=ARRIVALS.get(int(value),Maps.crop(id).position+row.size/2)
 var arrival=Tour.Indoor.safe_point(id,Maps.source_point(id,cell))
 game.close_boss_dialogue();game.transitioning=true
 Tour.travel.call_deferred(game,Maps.layout(id),{"arrival":arrival,"yaw":game.camera_rig.yaw,"velocity":Vector3.ZERO})
