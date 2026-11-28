extends RefCounted
## New Goemon endpoints only where a major dungeon lacks an original encounter.
const BRANCHES={"scientist":"牢房看守長","permafrost":"凍土守衛","east_8":"霞洞守衛","east_4096":"無名之森守衛","sokia_309":"迷龍守衛","sokia_303":"砂祠守衛"}
const FIXED={13016:"沙漠神殿守衛",15522:"雪山頂守衛",32106:"巴別塔中層守衛",32115:"巴別塔盡頭守衛"}
const FIXED_CELLS={32106:Vector2i(16,35),32115:Vector2i(70,96)}

static func prepare(game)->Dictionary:
 var maps=game.FalanTour.Winter.Recovered;var generated=maps.generated();var id:int=game.model.falan_floor
 if game.model.falan_area!="interior":return {}
 var branch:String=generated.branch(id);var title:String=FIXED.get(id,"");var at=Vector2.ZERO
 if BRANCHES.has(branch) and generated.number(id)==generated.count(branch,game.model.seed_value):
  title=BRANCHES[branch];at=generated.landing(id,game.model.seed_value,false)
 elif not title.is_empty():at=maps.source_point(id,FIXED_CELLS.get(id,Vector2i(39,15)))
 if title.is_empty():return {}
 var source=game.model.waves.patrol_source
 var state=maps.state(id,game.model.seed_value);var cell=Vector2i(((at-state.origin)/3.).round())+maps.crop(id).position
 var zone:Dictionary=source.zone_at(id,cell)
 if zone.is_empty():
  for candidate in source.data().get("zones",[]):
   if int(candidate.map)==maps.source_id(id):zone=candidate;break
 if zone.is_empty() or zone.groups.is_empty():return {}
 var group:Dictionary=source.data().groups[zone.groups[0][0]]
 # The new final-tower encounter uses its water-blue mouse; the other source member lacks a prepared attack sheet.
 var member_:Array=group.members[1 if id==32115 else 0];var species:Dictionary=source.data().species[int(member_[0])]
 var level=int(generated.SPECS[branch].levels[1]) if not branch.is_empty() else int(member_[2])
 return {"key":"goemon:"+str(id),"name":"Goemon 新遭遇 · "+title,"at":at,"species":int(member_[0]),"skin":int(species.get("skin",member_[0])),"level":level,"source":source}

static func spawn(game,spec:Dictionary)->bool:
 if game.model.enemies.values().any(func(e):return e.hp>0 and e.get("explore_endpoint","")==spec.key):return true
 var source:Script=spec.source
 var radius:float
 if source.has_method("radius"):radius=source.radius(spec.species)
 else:
  var body:AABB=preload("res://scripts/forest/crowd/pet_dimensions.gd").body(source,spec.skin)
  radius=minf(body.size.x,body.size.z)*.5*preload("res://scripts/forest/forest_enemy_roles.gd").MAP_ENEMY_SCALE
 var at:Vector2=spec.at;var selected=Vector3.INF
 var maps=game.FalanTour.Winter.Recovered;var state=maps.state(game.model.falan_floor,game.model.seed_value)
 var candidates=[]
 for y in range(-5,6):
  for x in range(-5,6):candidates.append(at+Vector2(x,y)*3.)
 candidates.sort_custom(func(a,b):return a.distance_squared_to(at)<b.distance_squared_to(at))
 for point:Vector2 in candidates:
  var cell=Vector2i(((point-state.origin)/3.).round())
  if not maps.open(state.bits,state.size,cell):continue
  var world=game.model.world_point(point)
  if not game.explore_access.body_clear(world+Vector3.UP*.15*game.model.falan_scale):continue
  if game.model.scenery_obstacles.values().any(func(box):return box.grow(2.5).has_point(world/game.model.falan_scale)):continue
  if not game.model.waves.navigation.move_clear(world/game.model.falan_scale,radius):continue
  if not game.army_runtime.native.can_reach(world,world,radius):continue
  if not game.army_runtime.native.can_reach(game.player.position,world,.55*game.model.falan_scale):continue
  if game.model.get_meta("falan_links",[]).any(func(link):return link.at.distance_squared_to(point)<6.*6.):continue
  selected=world;break
 if not selected.is_finite():return false
 var waves=game.model.waves;var roles=waves.Roles
 var companion:bool=source.has_method("companion")and source.companion(spec.species)
 var role:int=roles.GATEKEEPER_HOUND if companion else roles.SLIME
 var enemy=waves.spawn_enemy(role,selected,-1,spec.skin)
 enemy.skin=spec.skin;enemy.explore_endpoint=spec.key;enemy.patrol_radius=14.;enemy.footprint=.92
 waves.CaveProgression.apply(enemy,[spec.name,spec.level,660,true],roles.stats(role) if companion else source.STATS)
 waves.mark_dungeon_boss(enemy)
 spec.at=Vector2(selected.x,selected.z)/game.model.falan_scale
 return true
