extends Node

const Document=preload("res://scripts/forest/forest_map_document.gd")
const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const Practice=preload("res://scripts/forest/forest_training_dummy.gd")
const ROUND_HITS=20

var game
var socket:WebSocketPeer
var connected=false
var seed_value=0
var spawn_slot=0
var hits=0
var pose_clock=0.0
var last_area=""
var waiting_for_view=false
var peers:Dictionary={}
var avatars:Dictionary={}
var dummy

static func join_code()->String:
 return str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('room') || ''",true))

func begin():
 if socket!=null:return
 var url:String=JavaScriptBridge.eval("new URL('room', location.href).href.replace(/^http/, 'ws')",true)
 socket=WebSocketPeer.new()
 if socket.connect_to_url(url+"?code="+join_code().uri_encode())!=OK:
  socket=null
  OS.alert("Could not connect to the co-op room.","Cross Gate")

func _ready():
 process_mode=Node.PROCESS_MODE_ALWAYS

func _process(delta:float):
 if socket==null:return
 socket.poll()
 if socket.get_ready_state()==WebSocketPeer.STATE_CLOSED:
  var was_connected=connected
  connected=false;socket=null;waiting_for_view=false
  peers.clear()
  for avatar in avatars.values():avatar.queue_free()
  avatars.clear()
  update_practice("")
  if was_connected:game.toast("Co-op room disconnected")
  else:OS.alert("Could not join the room. It may be full, closed, or unavailable.","Cross Gate")
  return
 while socket.get_available_packet_count()>0:
  var data=JSON.parse_string(socket.get_packet().get_string_from_utf8())
  if data is Dictionary:receive(data)
 if not connected:return
 var area=playing_area()
 update_practice(area)
 pose_clock-=delta
 if pose_clock<=0.0 and not waiting_for_view and (not area.is_empty() or not last_area.is_empty()):
  waiting_for_view=socket.send_text('{"type":"view"}')==OK if area.is_empty() else send_pose(area)
  last_area=area
  pose_clock=.08
 for id in peers:
  var state:Dictionary=peers[id]
  if area.is_empty() or state.area!=area:
   if avatars.has(id):avatars[id].hide()
   continue
  present_peer(id,state,delta)

func receive(data:Dictionary):
 match data.get("type"):
  "ready":
   connected=true;seed_value=int(data.seed);hits=int(data.hits);spawn_slot=int(data.slot)
   var code=JSON.stringify(str(data.code))
   JavaScriptBridge.eval("(()=>{const url=new URL(location.href);url.searchParams.set('room',"+code+");history.replaceState(null,'',url)})()",true)
   game.begin_saved_falan(Document.WEB_FALAN_PATH)
  "view":
   waiting_for_view=false;hits=int(data.hits);peers=data.players
   for id in avatars.keys():
    if peers.has(id):continue
    avatars[id].queue_free();avatars.erase(id)

func playing_area()->String:
 if not game.playing or game.transitioning or game.model.phase!="wave":return ""
 return "%s:%d"%[Tour.area(game.model),game.model.falan_floor]

func send_pose(area:String)->bool:
 var body:Sprite3D=game.player.model.sprite
 if body.texture==null:return false
 var p:Vector3=game.player.global_position
 var rect=body.region_rect
 var look=[body.texture.resource_path,rect.position.x,rect.position.y,rect.size.x,rect.size.y,
  body.offset.x,body.offset.y,body.pixel_size*body.global_basis.y.length(),body.global_position.y-p.y,body.flip_h]
 return socket.send_text(JSON.stringify({"type":"pose","area":area,"position":[p.x,p.y,p.z],"look":look}))==OK

func present_peer(id:String,state:Dictionary,delta:float):
 var p=state.position
 var point=Vector3(p[0],p[1],p[2])
 var look=state.look
 if not avatars.has(id):
  var sprite=Sprite3D.new()
  sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
  sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
  sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
  sprite.region_enabled=true
  sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  add_child(sprite);avatars[id]=sprite
  var label=Label3D.new()
  label.text="Co-op partner";label.position.y=4.0
  label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.pixel_size=.011
  sprite.add_child(label)
  sprite.hide()
 var avatar:Sprite3D=avatars[id]
 if avatar.get_meta("atlas","")!=look[0]:
  if not ResourceLoader.exists(look[0],"Texture2D"):
   avatar.hide()
   return
  avatar.texture=load(look[0]);avatar.set_meta("atlas",look[0])
 avatar.region_rect=Rect2(look[1],look[2],look[3],look[4])
 avatar.offset=Vector2(look[5],look[6])
 avatar.pixel_size=look[7]
 avatar.flip_h=look[9]
 point.y+=look[8]
 avatar.global_position=avatar.global_position.lerp(point,minf(1.0,delta*14.0)) if avatar.visible and avatar.global_position.distance_squared_to(point)<100.0 else point
 avatar.show()

func update_practice(area:String):
 if area!="city:0":
  if is_instance_valid(dummy):
   game.enemies.erase(dummy);game.training_dummy=null;dummy.queue_free()
  return
 if not is_instance_valid(dummy):
  var practice=Practice.new();practice.game=game
  var spawn:Vector2i=Tour.STARTS.city+Vector2i(0,-1)
  practice.position=game.model.point(spawn)*game.model.falan_scale
  practice.landed.connect(send_hit)
  game.add_child(practice);dummy=practice;game.training_dummy=practice
  game.sync_training_dummy()
 var label="CO-OP TARGET\n%d / %d HITS"%[hits,ROUND_HITS] if hits<ROUND_HITS else "CO-OP TARGET\nCOMPLETE"
 if dummy.name_tag.text!=label:dummy.name_tag.text=label

func send_hit():
 if connected and hits<ROUND_HITS:socket.send_text('{"type":"hit"}')

func _exit_tree():
 if socket!=null:socket.close()
