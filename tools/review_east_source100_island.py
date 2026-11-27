"""Read-only original-entry audit for the source100 island beside10069@442,325."""
import hashlib,json,re,sys
from collections import deque,Counter
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT.parent/'Magic Power/tools'),str(ROOT/'tools')]
import cg_library as lib
from prepare_field_assets import navigation_grid
B=ROOT/'build/Other Files/Asset Toolkit'
OUT=B/'East Gate Region/Runtime Audit/Source100 Missing13/Remote Views'
def sha(raw):return hashlib.sha256(raw).hexdigest()
def connected(bits,w,h,seed):
    assert bits[seed[1]*w+seed[0]]
    seen={seed};pending=deque(seen)
    while pending:
        x,y=pending.popleft()
        for a,b in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
            if 0<=a<w and 0<=b<h and bits[b*w+a]and(a,b)not in seen:
                seen.add((a,b));pending.append((a,b))
    return seen
def run():
    raw_path=B/'Sokia Venoa Coverage/Server completion/100-client-plus-server.dat'
    raw=raw_path.read_bytes();w,h,ground,objects,flags=lib.parse_map(raw)
    bits=navigation_grid(w,h,ground,objects,lib.serial_index())
    island=connected(bits,w,h,(445,322));gate=connected(bits,w,h,(475,196))
    assert len(island)==466 and not island.intersection(gate)
    graph_path=B/'East Gate Region/Version Expansion Source Audit/graph.json'
    graph=json.loads(graph_path.read_text());incoming=[r for r in graph['links']if r['target']==100 and tuple(r.get('landing')or[])in island]
    source_links=[r for r in graph['links']if r['source']==100 and tuple(r.get('cell')or[])in island]
    graph_actors=[r for r in graph['actors']if r['map']==100 and tuple(r['cell'])in island]
    # Read complete global tables, including rows outside the eastern graph.
    warp_path=B/'Original Isometric Maps/reference-warp.txt';fixed=[];all100=[]
    for line,text in enumerate(warp_path.read_bytes().decode('gb18030').splitlines(),1):
        try:f=list(map(int,text.split()[:7]))
        except ValueError:continue
        if len(f)==7 and f[4]==100:
            row=dict(line=line,source=f[1],cell=f[2:4],landing=f[5:7]);all100.append(row)
            if tuple(f[5:7])in island:fixed.append(row)
    npc_path=B/'Cursed Maze/Source/npc-index.txt';inline=[];no_landing=[];island_actors=[];active_npcs=0
    for line,text in enumerate(npc_path.read_bytes().decode('gb18030').splitlines(),1):
        f=text.split('\t')
        if len(f)!=25 or f[0].startswith('#')or f[6]!='1'or not f[8].isdigit():continue
        active_npcs+=1;program=f[24]
        if int(f[8])==100 and tuple(map(int,f[9:11]))in island:island_actors.append(dict(line=line,kind=f[0],id=f[3],cell=list(map(int,f[9:11]))))
        targets=[]
        if f[0]=='Warp':
            parts=program.split('|')
            if len(parts)>3 and all(v.isdigit()for v in parts[1:4]):targets.append(tuple(map(int,parts[1:4])))
        for hit in re.findall(r'(?:^|\|)0\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)',program):targets.append(tuple(map(int,hit)))
        for target,x,y in set(targets):
            if target==100 and(x,y)in island:inline.append(dict(line=line,kind=f[0],actor=f[3],source=int(f[8]),landing=[x,y],program=program))
        if f[0]=='HouseWarp2'and program.split('|')[:2]==['1','100']:no_landing.append(dict(line=line,actor=f[3],source=int(f[8]),program=program))
    dungeon_path=B/'University Region/Source/dungeonconf.txt';generated=[];rectangles=[]
    for line,text in enumerate(dungeon_path.read_bytes().decode('gb18030').splitlines(),1):
        f=text.split('\t')
        if len(f)<117 or f[0].startswith('#')or not f[3].isdigit():continue
        if f[15]=='100'and f[16].isdigit()and f[17].isdigit()and tuple(map(int,f[16:18]))in island:generated.append(dict(line=line,config=f[3],landing=list(map(int,f[16:18]))))
        if f[9]=='100':
            x0,y0,x1,y1=map(int,f[10:14]);cells=[list(c)for c in island if x0<=c[0]<=x1 and y0<=c[1]<=y1]
            if cells:rectangles.append(dict(line=line,config=f[3],rectangle=[x0,y0,x1,y1],island_cells=len(cells)))
    # Every available SHA-pinned NPC program is scanned independently of graph
    # parser command case, active actor/day phase and current ownership.
    tree_path=B/'Original Isometric Maps/reference-tree.json';tree=json.loads(tree_path.read_text());expected={r['path']:r for r in tree['tree']if r['path'].startswith('gmsv/data/npc/')and r['path'].endswith('.txt')}
    cache={}
    for manifest in B.rglob('references.json'):
        try:rows=json.loads(manifest.read_text())
        except (ValueError,UnicodeDecodeError):continue
        if not isinstance(rows,list):continue
        for row in rows:
            key=row.get('path','');file=manifest.parent/str(row.get('file',''))
            if key not in expected or not file.is_file():continue
            content=file.read_bytes();blob=hashlib.sha1(b'blob '+str(len(content)).encode()+b'\0'+content).hexdigest()
            if blob==expected[key]['sha']:cache[key]=(file,content)
    scripted=[];script_hashes={}
    for path,(file,content)in cache.items():
        script_hashes[path]=sha(content)
        for line,text in enumerate(content.decode('gb18030').splitlines(),1):
            if not re.match(r'^\s*(?:Warp|Encount)\b',text,re.I):continue
            for a,x,y in re.findall(r'(?:\b|\|)0\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)',text):
                if int(a)==100 and(int(x),int(y))in island:scripted.append(dict(script=path,line=line,command=text.strip(),landing=[int(x),int(y)]))
    item_path=B/'East Gate Region/Version Expansion Source Audit/item-use-graph.json';items=json.loads(item_path.read_text());item_links=[r for r in items['links']if r['target']==100 and tuple(r.get('landing')or[])in island]
    owner_path=ROOT/'assets/maps/falan/freyja_residual/full/provenance.json';owners=json.loads(owner_path.read_text());external={}
    for area,row in owners['areas'].items():
        if area in ['east_gate','north_coast','east_coast']:continue
        f=row['frame'];origin=row['origin'];size=row['size'];hits=[]
        for x,y in island:
            dx=x*3.-f['origin'][0];dy=y*3.-f['origin'][1];det=f['x'][0]*f['y'][1]-f['x'][1]*f['y'][0]
            u=(dx*f['y'][1]-dy*f['y'][0])/det;v=(f['x'][0]*dy-f['x'][1]*dx)/det;px=round((u-origin[0])/3);py=round((v-origin[1])/3)
            if 0<=px<size[0]and 0<=py<size[1]:hits.append([x,y])
        if hits:external[area]=dict(envelope_cells=len(hits),example=hits[:5],meaning='Existing owner envelope overlap only; not a proven original arrival or visual ownership.')
    result=dict(status='HOLD10069from East-reachable production; isolated-source reference only',source_path=str(raw_path.relative_to(ROOT)),source_sha256=sha(raw),source_size=[w,h],source_walk_sha256=sha(bytes(bits)),gate_seed=[475,196],gate_component_cells=len(gate),island_seed=[445,322],island_cells=len(island),island_bbox=[min(x for x,y in island),min(y for x,y in island),max(x for x,y in island),max(y for x,y in island)],component_intersection=0,source_object=dict(graphic=10069,anchor=[442,325],anchor_open=bool(bits[325*w+442]),neighbor_component_seed=[445,322]),global_fixed_arrivals=fixed,global_fixed_arrivals_into100=len(all100),global_active_inline_arrivals=inline,global_active_npcs_scanned=active_npcs,global_HouseWarp2_to100_without_landing=no_landing,global_active_actors_on_island=island_actors,global_generated_arrivals=generated,global_generated_entry_rectangles=rectangles,owned_graph_incoming=incoming,owned_graph_outgoing=source_links,owned_graph_actors=graph_actors,owned_graph_link_types=sorted(set(r['kind']for r in graph['links'])),pinned_cached_script_count=len(cache),pinned_all_script_count=len(expected),pinned_cached_script_island_arrivals=scripted,item_use_island_arrivals=item_links,item_use_unknown_builtin_handlers=items['unknown_builtin_handlers'],external_owner_envelopes=external,limits=['No source bridge or route is invented. Directspawn on the island does not prove EastGate reachability.','The global fixed/inline/dayphase/battle-row and generated tables are complete pinned tables. Script/body coverage additionally includes all available SHA-verified programs and the complete717owned graph; uncached unrelated programs are not claimed absent.','The item-use graph covers reached reward/shop/drop items and their source programs; hidden built-in handlers remain the explicitly recorded source limitation.','An external owner envelope is a presentation boundary comparison, not route evidence.'],input_sha256={str(p.relative_to(ROOT)):sha(p.read_bytes())for p in[raw_path,graph_path,warp_path,npc_path,dungeon_path,tree_path,item_path,owner_path]},pinned_script_sha256=script_hashes)
    OUT.mkdir(parents=True,exist_ok=True);(OUT/'island-442325.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:result[k]for k in['island_cells','global_fixed_arrivals','global_active_inline_arrivals','global_generated_arrivals','global_generated_entry_rectangles','pinned_cached_script_count','pinned_all_script_count','pinned_cached_script_island_arrivals','item_use_island_arrivals','external_owner_envelopes']},ensure_ascii=False))
if __name__=='__main__':run()
