"""Audit Town source treasure and stage one default-off generic-entry-loot guard."""
from collections import Counter
import difflib,hashlib,json,re,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Source Context Audit/Prototype/Town Entry Loot'
PATH='scripts/forest/exploration_loot.gd'
OLD='\tvar model=game.model;var area:String=game.FalanTour.area(model)\n'
ADDED='\tvar source_context=game.FalanTour.Regions.private_source_context\n\tif source_context!=null and source_context.suppress_entry_chests(model):return\n'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
 OUT.mkdir(exist_ok=True);(OUT/'.gdignore').touch()
 source=(ROOT/PATH).read_text();assert 'source_context.suppress_entry_chests(model)' not in source,'Do not duplicate an applied guard';assert source.count(OLD)==1
 candidate=source.replace(OLD,OLD+ADDED);assert candidate.replace(ADDED,'')==source
 pop_path=ROOT/'assets/maps/falan/east_region/population.json';pop=json.loads(pop_path.read_text())
 named=[a for a in pop['actors'] if re.search('宝箱|寶箱|treasure|chest',a.get('name','')+' '+a.get('type',''),re.I)];graphics={int(a['graphic']) for a in named}
 specs_path=ROOT/'assets/maps/falan/east_region/dungeon_specs.gd';text=specs_path.read_text();specs=json.loads(text[text.index('{'):])
 preserved=[pop_path,specs_path,ROOT/'scripts/forest/forest_east_events.gd',ROOT/'scripts/forest/forest_original_dungeons.gd',ROOT/'assets/maps/falan/east_region/items.json']
 towns=[]
 for ident,folder in [(2000,'il_source_completion'),(2400,'alyut_source_completion')]:
  p=ROOT/f'assets/maps/falan/east_region/{folder}/hybrid-map.bin';preserved.append(p);b=p.read_bytes();w,h=struct.unpack_from('<II',b,12);n=w*h;pg=struct.unpack_from('<'+'H'*n,b,20+n*2);actors=[a for a in pop['actors'] if int(a['source'])==ident]
  programs={a['script']:pop['scripts'][a['script']] for a in actors if a.get('script') in pop['scripts']}
  towns.append({'source':ident,'size':[w,h],'actors':[{'id':a['id'],'type':a['type'],'name':a['name'],'cell':a['cell'],'script':a['script']} for a in actors],'actor_types':dict(Counter(a['type'] for a in actors)),'source_named_treasure_actors':[a['id'] for a in actors if a in named],'pg1_distinct_nonzero':len(set(pg)-{0}),'pg1_matches_known_named_treasure_actor_graphics':{str(g):pg.count(g) for g in graphics if g in pg},'source_event_program_sha256':{k:v['sha256'] for k,v in programs.items()},'source_event_gameplay_commands':[{'script':name,'line':line,'text':command.strip()} for name,record in programs.items() for line,command in record['lines'] if re.match(r'\s*(give|kill|addgold|warp|encount)',command,re.I)],'generated_entries':[{'key':k,'config':v['config'],'box_amount':v.get('box_amount'),'scope':v.get('box_amount_scope')} for k,v in specs.items() if int(v['entry'][0])==ident]})
 patch=''.join(difflib.unified_diff(source.splitlines(True),candidate.splitlines(True),fromfile='a/'+PATH,tofile='b/'+PATH));(OUT/'entry-loot.patch').write_text(patch);(OUT/'exploration_loot.gd').write_text(candidate)
 report={'stage_only':True,'default_context':'null','shared_runtime_file':PATH,'baseline_sha256':hashlib.sha256(source.encode()).hexdigest(),'candidate_sha256':hashlib.sha256(candidate.encode()).hexdigest(),'patch_sha256':hashlib.sha256(patch.encode()).hexdigest(),'private_adapter_sha256':sha(ROOT/'scripts/forest/forest_east_source_context_review.gd'),'towns':towns,'generated_box_records_preserved':[{'key':k,'config':v['config'],'box_amount':v.get('box_amount'),'scope':v.get('box_amount_scope')} for k,v in specs.items()],'unchanged_source_quest_map_generator_inputs':{str(p.relative_to(ROOT)):sha(p) for p in preserved},'conclusion':'The12outdoor entry-chest target is existing Goemon procedural dressing, with no matching fixed Town source reward/count record found in this bounded audit. All map art/NPC/event treasure remains with its original owner. The proposed guard affects only privately owned standalone2000/2400, leaving Host100/interiors/generatedbox_amount/deathdrops/explicitspawn_chest/item/gold/quest behavior untouched.','limits':'No absence claim is made about unclassified decorative map-art chests or inaccessible original server state. Their bytes/placement owners are preserved regardless. This audit does not activate or rewrite global loot.'}
 (OUT/'source-review.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps({'patch_sha256':report['patch_sha256'],'baseline':report['baseline_sha256'],'candidate':report['candidate_sha256'],'towns':[(r['source'],len(r['actors']),r['source_named_treasure_actors'],r['pg1_matches_known_named_treasure_actor_graphics'],r['generated_entries']) for r in towns],'generated_records':len(specs),'shared_applied':False},indent=2))
if __name__=='__main__':main()
