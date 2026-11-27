extends SceneTree
## Source selection and stable logical floors; this does not instantiate playable worlds.
const Prayer=preload("res://scripts/forest/forest_black_prayer.gd")
const South=preload("res://scripts/forest/forest_south_kili_population.gd")
const Ruby=preload("res://scripts/forest/crowd/ruby_boss_sprites.gd")
const OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Black Prayer encounters/"
class Scope extends RefCounted:
 var falan_area="interior"
 var falan_floor=0
 var seed_value=41829558
var checks=0
var failures=0
var records=[]
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("BLACK_PRAYER_SOURCE_FAIL "+label_)
func _initialize():run.call_deferred()
func run():
 var data:Dictionary=Prayer.source()
 check(data.config==301 and Prayer.FLOORS==[30101,30102,30103,30104,30105,30106],"Config301 keeps all six stable runtime identities")
 check(data.source_config.entry.map(func(value):return int(value))==[16507,14,14] and data.source_config.end.map(func(value):return int(value))==[16508,39,5],"Exact source entrance and palace endpoints")
 var prefix=[]
 for path in ["res://assets/maps/falan/south_kili_route/population.json","res://assets/maps/falan/sokia/population.json","res://assets/maps/original_crossgate/sokia_server/encounters.json"]:
  var table:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
  prefix.append_array(table.get("extra_species",table.get("species",[])))
 check(South.data().species.slice(0,int(data.species_offset))==prefix,"Every existing source member index remains unchanged")
 check(Ruby.motions().variants.map(func(row):return int(row.id))==[100654,101600,101121],"Existing Ruby/blade/ghost bank slots remain exact")
 for i in Prayer.FLOORS.size():
  var id:int=Prayer.FLOORS[i];var scope=Scope.new();scope.falan_floor=id
  var row:Dictionary=Prayer.source_floor(id);var zone:Dictionary=South.zone_at(id,Vector2i(9,9))
  var level=20+(i+1)*3/6
  check(row.config==301 and row.number==i+1 and row.runtime_id==id,"Known source configuration and floor index "+str(id))
  check(South.encounters_own(scope) and South.bank(scope)==Ruby,"Existing source movement/native Ruby bank owns floor "+str(id))
  check(zone.id==id and zone.config==301 and zone.levels==[level,level],"Qualified reference-generator floor level "+str(id))
  check(zone.groups.map(func(value):return [str(value[0]),int(value[1])])==[["prayer:15006",1],["prayer:15004",1],["prayer:15005",1]],"Exact three source group weights "+str(id))
  var state=South.state(scope)
  check(state.size==Prayer.SIZE and state.origin==Prayer.ORIGIN and state.bits==Prayer.walk_mask(id,scope.seed_value),"Existing seeded native layout preserved "+str(id))
  check(South.source_cell(scope,Prayer.point(Vector2i(9,9)))==Vector2i(9,9),"Source cell coordinates retain their old origin "+str(id))
  var rng=RandomNumberGenerator.new();rng.seed=341
  var bags={};var group_cycle=[]
  for draw in 3:
   var party:Array=South.group(zone,bags,rng)
   check(not party.is_empty(),"Optional source members still form a nonempty native party "+str(id))
   if not party.is_empty():group_cycle.append(party[0][3])
  group_cycle.sort()
  check(group_cycle==["prayer:15004","prayer:15005","prayer:15006"],"Equal source group bag draws each group before refill "+str(id))
  var roster=[]
  for choice in zone.groups:
   var one:Dictionary=zone.duplicate(true);one.groups=[choice];bags={};var sizes=[];var seen={}
   for draw in 6:
    var party:Array=South.group(one,bags,rng);sizes.append(party.size())
    check(party.all(func(member):return member.size()==4 and member[1]==level and member[2] in ["15003","15004"] and member[3]==choice[0]),"Source enemy/group tags and levels survive native selection "+str(id))
    for member in party:
     var species:Dictionary=South.data().species[member[0]];seen[int(species.id)]=true
     check(species.family=="black_prayer" and int(species.skin) in [1,2] and int(species.native_hp_per_level)==(400 if int(species.id)==101600 else 300),"Retained native skin and HP-per-level fit "+str(id))
   sizes.sort()
   check(sizes==[1,2,3,4,5,6],"Native party-size bag draws without replacement "+str(id)+" "+choice[0])
   var expected=[101121,101600] if choice[0]=="prayer:15006" else [101121] if choice[0]=="prayer:15004" else [101600]
   var actual=seen.keys();actual.sort();expected.sort()
   check(actual==expected,"Complete distinct source group roster "+str(id)+" "+choice[0])
   roster.append({"source_group":choice[0],"appearances":actual,"native_party_sizes":sizes})
  var links=Prayer.links(id,scope.seed_value)
  check(links.size()==2 and links[0].floor==(Prayer.ENTRY if i==0 else id-1) and links[1].floor==(Prayer.BOSS if i==5 else id+1),"Sequential original access/return chain preserved "+str(id))
  check(Prayer.patrols(id,scope.seed_value).size()==96,"Legacy station/death-slot compatibility data retained "+str(id))
  records.append({"runtime_id":id,"source_config":301,"floor":i+1,"levels":zone.levels,"groups":roster,"layout":"unchanged64x64 sixteen-room native adaptation"})
 for id in [Prayer.ENTRY,Prayer.BOSS]:
  var scope=Scope.new();scope.falan_floor=id
  check(not South.encounters_own(scope),"Ordinary source pool does not spill into fixed safe entrance or palace "+str(id))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var file=FileAccess.open(OUT+"floor-inventory.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"floors":records,"limits":data.limits,"goal_complete":false},"  "));file.close()
 print("BLACK_PRAYER_SOURCE_RESULT checks=",checks," failures=",failures," floors=",records.size())
 quit(1 if failures else 0)
