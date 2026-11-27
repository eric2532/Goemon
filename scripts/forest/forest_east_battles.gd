extends RefCounted
## Source formations extend the existing regional battle state and native spawn loop.
static var specifications:Dictionary={}
static var run:Variant=null
static var item_serial=0
const LEGACY=[11004,15505,16503,47017]

static func owns(key:String)->bool:return key.begins_with("east:")
static func bank()->Script:return load("res://scripts/forest/crowd/east_region_sprites.gd")

static func specification(key:String)->Dictionary:return specifications.get(key,{})

static func begin(game,actor:Dictionary,raw_args:String)->bool:
 if actor.get("item_use",false) and not bank().owns_model(game.model):
  var blocked:Dictionary=game.get_tree().get_meta("east_battle_blockers",{})
  blocked[str(actor.id)]={"reason":"The current map uses a different prepared native appearance/timeline bank; this held-item formation cannot safely share its skin slots.","area":game.model.falan_area,"floor":game.model.falan_floor}
  game.get_tree().set_meta("east_battle_blockers",blocked);game.toast("此地的道具戰鬥尚未開放");return false
 var token=[game.get_instance_id(),game.model.seed_value]
 if run!=token:run=token;specifications.clear();item_serial=0
 var args=raw_args.split("|",true)
 if args.size()<10 or not args[9].is_valid_int():game.toast("原始戰鬥定義缺少遭遇編號");return false
 var encounter=int(args[9]);var source=bank();var payload:Dictionary=source.data()
 if actor.get("item_use",false) and not load("res://scripts/forest/forest_university_region.gd").active(game.get_tree(),game.model.falan_floor,game.model.falan_area).is_empty():
  game.toast("請先完成目前的戰鬥");return false
 if not payload.bosses.has(str(encounter)):game.toast("原始戰鬥資料尚待恢復");return false
 var seen={};var pending=[encounter]
 while not pending.is_empty():
  var next:int=pending.pop_back()
  if next<=0 or seen.has(next):continue
  seen[next]=true
  var zone:Dictionary=payload.bosses.get(str(next),{})
  if zone.is_empty():return false
  for group in zone.groups:
   for member in payload.groups[group[0]].details:
    if not source.available(int(member.species)):
     var blocked:Dictionary=game.get_tree().get_meta("east_battle_blockers",{})
     blocked[str(actor.id)]={"encounter":next,"appearance":int(payload.species[member.species].id),"reason":"Original source attack contact marker is unavailable; encounter membership is preserved."}
     game.get_tree().set_meta("east_battle_blockers",blocked);game.toast("原始攻擊命中時序尚未確認");return false
    if actor.get("item_use",false) and not source.companion(int(member.species)):
     var skin:int=payload.species[int(member.species)].skin
     var meshes:Dictionary=preload("res://scripts/forest/crowd/hound_sprites.gd").meshes
     var prepared:Array=meshes[source.ROOT].get_meta("prepared_pages",[]) if meshes.has(source.ROOT) else []
     if not source.motions().skin_pages[skin].all(func(page):return prepared.any(func(value):return int(value)==int(page))):
      var blockers:Dictionary=game.get_tree().get_meta("east_battle_blockers",{})
      blockers[str(actor.id)]={"encounter":encounter,"appearance":int(payload.species[int(member.species)].id),"reason":"Held-item source texture pages were not prepared during setup; keep the item and reopen its Equipment use flow."}
      game.get_tree().set_meta("east_battle_blockers",blockers)
      game.toast("請先在裝備頁準備這件道具");return false
  if int(zone.next_encounter)>0:pending.append(int(zone.next_encounter))
 var win=[]
 var target=args[1].split(",",false)
 if target.size()==4 and target[0]=="0" and target[1].is_valid_int() and int(target[1])>0:win=[int(target[1]),int(target[2]),int(target[3])]
 var at=Vector2i(actor.cell[0],actor.cell[1])
 if int(actor.source)==777:
  var state:Dictionary=source.state(game.model)
  var p=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
  at=Vector2i(((p-state.origin)/3.).round())
 var key="east:%s:%s:%d:%d"%[actor.id,game.model.falan_area,game.model.falan_floor,encounter]
 if actor.get("item_use",false):item_serial+=1;key+=":use:%d"%item_serial
 var spec={"map":game.model.falan_floor,"area":game.model.falan_area,"cell":at,"encounter":encounter,"win":win,"actors":[str(actor.id)],"actor":actor,"raw_args":raw_args}
 if actor.get("item_use",false):
  var p=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
  spec.runtime_at=p
 specifications[key]=spec
 if game.model.falan_floor in LEGACY and not actor.get("item_use",false):
  game.get_tree().set_meta("east_legacy_battle",spec)
  return true
 return load("res://scripts/forest/forest_university_region.gd").begin(game,key,-1,true)

static func victory(game,key:String,spec:Dictionary)->bool:
 var args:Array=spec.raw_args.split("|",true)
 # Keep undocumented result operands visible for source review instead of inventing item/quest-flag mutations.
 var unresolved=[]
 if args.size()>3 and not args[2].is_empty():unresolved.append("item result operands "+args[2]+"|"+args[3])
 for i in range(10,args.size()):
  if not args[i].is_empty() and args[i]!="0":unresolved.append("result field %d=%s"%[i,args[i]])
 if not unresolved.is_empty():
  var rows:Dictionary=game.get_tree().get_meta("east_battle_blockers",{})
  rows[str(spec.actor.id)]={"encounter":spec.encounter,"reason":"Original encounter-handler result contract is unavailable.","operands":unresolved}
  game.get_tree().set_meta("east_battle_blockers",rows)
  game.toast("戰鬥結束 · 原始任務結果尚待確認")
  return false
 if spec.win.is_empty():game.toast("戰鬥結束");return false
 load("res://scripts/forest/forest_east_region.gd").travel_source(game,int(spec.win[0]),Vector2i(spec.win[1],spec.win[2]))
 return true

static func tick_legacy(game):
 var tree:SceneTree=game.get_tree()
 if not tree.has_meta("east_legacy_battle") or game.transitioning:return
 var spec:Dictionary=tree.get_meta("east_legacy_battle")
 if int(spec.map)!=game.model.falan_floor or spec.area!=game.model.falan_area:return
 var cleared=false
 match int(spec.map):
  11004:cleared=tree.get_meta("habaru_slain",{}).size()>=game.FalanTour.Regions.Sites.HABARU_FORMATION.size()
  15505:cleared=tree.get_meta("zombie_slain",{}).has(0)
  16503:cleared=tree.get_meta("captain_slain",{}).size()>=game.FalanTour.Regions.Sites.CAPTAIN_FORMATION.size()
  47017:cleared=tree.get_meta("grave_slain",{}).has(3)
 if not cleared:return
 tree.remove_meta("east_legacy_battle")
 if is_instance_valid(game.get("explore_access"))and game.explore_access.enabled():
  var identity:String={11004:"habaru_slot",15505:"zombie_slot",16503:"captain_slot",47017:"grave_slot"}[int(spec.map)]
  game.explore_access.scripted_victory(identity,Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale,str(spec.actor.name),spec.win)
  return
 victory(game,"",spec)
