extends SceneTree
const East=preload("res://scripts/forest/crowd/east_region_sprites.gd")
const Events=preload("res://scripts/forest/forest_east_events.gd")
var failures=[]
var checks=0
func _initialize():call_deferred("run")
func check(value:bool,label:String):
 checks+=1
 if not value:failures.append(label)
func run():
 var model={"falan_area":"interior","falan_floor":41029,"seed_value":1701,"army_runtime":null}
 var saved=get_meta(Events.ITEMS,{});var existed=has_meta(Events.ITEMS)
 set_meta(Events.ITEMS,{})
 var baseline=East.possible_members(model)
 check(East.held_item_encounters(model).is_empty(),"An empty quest bag adds no item battle pools")
 var records=[]
 for id in [18877,18878,18879,18880]:
  var held={};Events.set_item(held,id,1,1000.);set_meta(Events.ITEMS,held)
  var encounters=East.held_item_encounters(model)
  check(encounters==[str(20010+id-18877)],"Only the held source item's encounter is eligible for setup "+str(id))
  var members=East.possible_members(model);var added=members.filter(func(member):return member not in baseline)
  var expected=[]
  for group in East.data().bosses[encounters[0]].groups:
   for member in East.data().groups[str(group[0])].members:expected.append(int(member[0]))
  check(expected.all(func(member):return member in members and East.available(member)),"Every held item encounter appearance is included and available "+str(id))
  check(added.all(func(member):return member in expected),"Unheld item pools do not expand setup pages "+str(id))
  records.append({"item":id,"encounters":encounters,"possible_members":expected})
 if existed:set_meta(Events.ITEMS,saved)
 else:remove_meta(Events.ITEMS)
 var file=FileAccess.open("res://build/Other Files/Asset Toolkit/East Gate Region/Verification/held-item-pages.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"items":records,"scope":"Source held-item pool membership at setup. No command/Floor/time predicate is executed or bypassed."}," ")+"\n");file.close()
 print("EAST_HELD_ITEM_PAGES_RESULT checks=",checks," failures=",failures.size())
 for failure in failures:push_error(failure)
 quit(0 if failures.is_empty() else 1)
