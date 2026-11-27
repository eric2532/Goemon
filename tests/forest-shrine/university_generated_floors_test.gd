extends "res://tests/forest-shrine/original_maps_test.gd"
const REVIEW="res://build/Other Files/Asset Toolkit/University Region/"

func run():
 var generated=Original.generated();var report=[];var seeds=[0,1,77,341]
 # Include every allowed variable floor count, especially the optional final floors.
 for branch_ in generated.SPECS:
  var spec:Dictionary=generated.SPECS[branch_];var observed={}
  for seed_ in seeds:observed[generated.count(branch_,seed_)]=true
  for candidate in 512:
   var count_:int=generated.count(branch_,candidate)
   if not observed.has(count_):seeds.append(candidate);observed[count_]=true
   if observed.size()==int(spec.maximum)-int(spec.minimum)+1:break
  check(observed.size()==int(spec.maximum)-int(spec.minimum)+1,"All permitted floor counts have a reproducible seed "+branch_)
 for seed_ in seeds:
  for branch_ in generated.SPECS:
   var spec:Dictionary=generated.SPECS[branch_];var count_:int=generated.count(branch_,seed_)
   check(count_>=spec.minimum and count_<=spec.maximum,"Source floor-count bounds "+branch_)
   var entry:int=Original.runtime_id(spec.entry[0]);var terminal:int=Original.runtime_id(spec.end[0])
   var first:int=generated.floor_id(branch_,1);var last:int=generated.floor_id(branch_,count_)
   check(Original.links(entry,seed_).any(func(link):return link.get("floor")==first),"Normal approach exposes the first floor: "+branch_)
   if branch_=="scientist":
    check(Original.links(terminal,seed_).any(func(link):return link.get("floor")==4402),"Scientist return laboratory retains its original reset stairs")
    check(not Original.links(terminal,seed_).any(func(link):return link.get("floor")==last),"No overlapping invented return to scientist5F")
   else:check(Original.links(terminal,seed_).any(func(link):return link.get("floor")==last),"Terminal exposes the return to the last floor: "+branch_)
   for n in range(1,count_+1):
    var id:int=generated.floor_id(branch_,n);var state=Original.state(id,seed_);var doors_:Array=generated.doors(id,seed_)
    check(Original.owns(id),"Existing map owner accepts %s %dF"%[branch_,n])
    check(state.raw==Original.state(id,seed_).raw,"Saved seed replays every source plane")
    if branch_=="mountain":
     check(state.get("native_template",false) and state.raw==Original.Art.raw_map(state.native_path),"Every snow floor retains all three planes of its native snapshot")
     check(state.size.x==40 and state.size.y>=40 and state.size.y<=80,"Every snow floor obeys original dungeon dimensions")
    check(connected(id,Original.point(id,doors_[0],seed_),Original.point(id,doors_[1],seed_),seed_),"The actual floor mask connects both stairs: %s %dF"%[branch_,n])
    var links=Original.links(id,seed_)
    check(links.size()==2,"Exactly the existing approach and onward stair remain")
    var previous=entry if n==1 else generated.floor_id(branch_,n-1)
    var next=terminal if n==count_ else generated.floor_id(branch_,n+1)
    check(links.any(func(link):return link.get("floor")==previous),"Source floor has its backward connection")
    check(links.any(func(link):return link.get("floor")==next),"Source floor has its forward connection")
    for link in links:
     var target:Dictionary=Original.state(link.floor,seed_)
     var cell=Vector2i(((link.arrival-target.origin)/3).round())
     check(Original.open(target.bits,target.size,cell),"Every arrival is on real open ground")
    var cells:int=state.size.x*state.size.y;var art=Original.Art.data().graphics;var missing={}
    for i in cells*2:
     var serial=state.raw.decode_u16(20+i*2)
     if serial>=1000 and not art.has(str(serial)):missing[serial]=true
    check(missing.is_empty(),"Every generated graphic exists: "+str(missing.keys()))
   report.append({"branch":branch_,"seed":seed_,"floors":count_})
 for seed_ in [0,1,77,341]:
  for n in range(1,Original.Beast.COUNT+1):
   var id:int=Original.Beast.FIRST+n-1;var state=Original.state(id,seed_)
   check(state.raw==Original.state(id,seed_).raw,"Beast seed replays the native layout")
   check(connected(id,Original.point(id,Original.Beast.stair(id,seed_,true),seed_),Original.point(id,Original.Beast.stair(id,seed_,false),seed_),seed_),"Every Beast floor joins its actual stairs")
   var links=Original.links(id,seed_)
   check(links.size()==2,"Every Beast floor keeps both source stair directions")
   for link:Dictionary in links:
    var destination=Original.state(link.floor,seed_);var cell=Vector2i(((link.arrival-destination.origin)/3.).round())
    check(Original.open(destination.bits,destination.size,cell),"Every Beast stair lands on original open ground")
  report.append({"branch":"beast","seed":seed_,"floors":Original.Beast.COUNT})
 var file=FileAccess.open(REVIEW+"generated-floors.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("UNIVERSITY_GENERATED_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
