"""Read-only East/north-coast source100 data-owner completeness census."""
import hashlib,json,struct,sys
from collections import Counter
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];sys.path[:0]=[str(ROOT.parent/'Magic Power/tools'),str(ROOT/'tools')]
import cg_library as lib
from prepare_field_assets import navigation_grid
from prepare_east_region_field import source_pixel,source_area
from build_freyja_outlying import is_road,is_water
from build_freyja_destinations import load_map
B=ROOT/'build/Other Files/Asset Toolkit/East Gate Region';OUT=B/'Runtime Audit/Source100 Completeness'
def sha(raw):return hashlib.sha256(raw).hexdigest()
def in_rect(p,r):return r[0]<=p[0]<r[0]+r[2]and r[1]<=p[1]<r[1]+r[3]
def run():
 OUT.mkdir(parents=True,exist_ok=True);active_path=ROOT/'assets/maps/falan/freyja_source/100.dat';full_path=ROOT/'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Server completion/100-client-plus-server.dat';archive_path=ROOT.parent/'Magic Power/data/crossgate/source/BlueCrossgate/map/0/100.dat';active_raw=active_path.read_bytes();full_raw=full_path.read_bytes();client_raw=archive_path.read_bytes();w,h,ag,ao,flags=load_map(lib,100);fw,fh,g,o,ff=lib.parse_map(full_raw);cw,ch,cg,co,cf=lib.parse_map(client_raw);assert(w,h)==(fw,fh)==(cw,ch)and flags==ff==cf
 assert all((ag[i],ao[i])==(cg[i],co[i])==(g[i],o[i])for i,f in enumerate(flags)if f&0xc000)
 source_nav=navigation_grid(w,h,g,o,lib.serial_index());active_nav=navigation_grid(w,h,ag,ao,lib.serial_index());metadata=json.loads((ROOT/'assets/maps/falan/freyja_residual/full/provenance.json').read_text());assert metadata['source_sha256']==sha(active_raw)
 masks={};prepared={};areas={};index=Image.open(ROOT/'assets/maps/falan/freyja_ground_index.png').convert('RGBA');scenery=json.loads((ROOT/'assets/maps/falan/east_region/field-scenery.json').read_text());coverage={}
 for area in ['east_gate','north_coast']:
  m=Image.open(ROOT/f'assets/maps/falan/freyja_residual/full/{area}-surface.png').convert('RGBA');assert sha(m.tobytes())==metadata['areas'][area]['rgba_sha256'];masks[area]=m;prepared[area]=Image.open(ROOT/f'assets/maps/falan/east_region/{area}-surface.png').convert('RGBA');coverage[area]={}
  for category,rows in scenery[area].items():
   for row in rows:
    if category=='ridges':x=row[0]-(row[3]/3-1)/2;y=row[1]+(row[4]/3-1)/2
    else:x,y=row[:2]
    coverage[area][(round(x),round(y),int(row[2]))]=category
  areas[area]=dict(counts=Counter(),missing_raw_cells=[],missing_raw_pg1=[],native_dry_open_mask_gaps=[],road_index_gaps=[],source_ground_index_gaps=[],exclusions=Counter(),missing_pg1_serial_counts=Counter(),field_scenery_categories=Counter())
 def locate(x,y):
  if not(440<=x<w and 0<=y<360):return None,None,'outside-current-East-preparer-domain'
  area=source_area(x,y);px,py=source_pixel(area,x,y);im=masks[area]
  if not(0<=px<im.width and 0<=py<im.height):return area,None,'outside-runtime-envelope'
  if any(in_rect((px,py),r)for r in metadata['areas'][area]['safe_rectangles']):
   kind='joined-Il-context'if area=='east_gate'and in_rect((px,py),[0,287,111,90])else'joined-Alyut-context'if area=='north_coast'else'opaque-Falan-city'
   return area,(px,py),kind
  return area,(px,py),'field'
 def state(x,y):
  area,pixel,context=locate(x,y);i=y*w+x;return dict(cell=[x,y],area=area,context=context,recorded=bool(flags[i]&0xc000),active=[ag[i],ao[i]],full=[g[i],o[i]],active_open=bool(active_nav[i]),full_open=bool(source_nav[i]),mask_rgba=list(masks[area].getpixel(pixel))if pixel else None,ground_index_rgba=list(index.getpixel((x,y))))
 outside=[];seen=set();overview=Image.new('RGB',(w-440,360),'#19272c');allcounts=Counter()
 for y in range(360):
  for x in range(440,w):
   i=y*w+x;area,pixel,context=locate(x,y);allcounts[context]+=1;diff=(ag[i],ao[i])!=(g[i],o[i]);known=bool(flags[i]&0xc000)
   if context=='outside-runtime-envelope':
    if g[i]not in(0,100)or o[i]>=1000:outside.append(state(x,y))
    continue
   r=areas[area];r['counts']['all_cells']+=1;r['counts']['all_recorded'if known else'all_unknown']+=1;r['counts']['all_missing_raw_tuples']+=diff
   if context!='field':r['exclusions'][context]+=1;overview.putpixel((x-440,y),(150,135,60));continue
   seen.add((x,y));c=r['counts'];c['field_cells']+=1;c['recorded'if known else'unknown']+=1;c['full_native_open']+=bool(source_nav[i]);c['active_native_open']+=bool(active_nav[i]);c['full_roads']+=is_road(g[i]);c['full_pg1_graphic_anchors']+=o[i]>=1000;c['missing_raw_tuples']+=diff
   if diff:r['missing_raw_cells'].append([x,y,ag[i],ao[i],g[i],o[i],int(flags[i])]);c['missing_raw_dry']+=g[i]not in(0,100)and not is_water(g[i]);c['missing_raw_road']+=is_road(g[i])
   mask=masks[area].getpixel(pixel);ready=prepared[area].getpixel(pixel);draw=index.getpixel((x,y));dry=g[i]not in(0,100)and not is_water(g[i]);maskgap=bool(dry and source_nav[i]and(mask[3]<128 or mask[0]>=128));c['native_dry_open_mask_gaps']+=maskgap;c['current_mask_vs_pinned_east_mask_different_rgba']+=mask!=ready
   if maskgap:r['native_dry_open_mask_gaps'].append([x,y,g[i],o[i],list(mask),list(ready)])
   if g[i]>=1000 and draw[3]<128:r['source_ground_index_gaps'].append([x,y,g[i],o[i]]);c['source_ground_index_alpha_gaps']+=1
   if is_road(g[i])and draw[3]<128:r['road_index_gaps'].append([x,y,g[i],o[i]]);c['road_index_alpha_gaps']+=1
   if o[i]>=1000 and ao[i]!=o[i]:
    category=coverage[area].get((x,y,o[i]));r['missing_raw_pg1'].append(dict(cell=[x,y],native_graphic=o[i],current_active_graphic=ao[i],prepared_pinned_field_owner=category));r['missing_pg1_serial_counts'][str(o[i])]+=1;r['field_scenery_categories'][category or 'not-in-field-scenery-catalog']+=1
   color=(36,74,112)if is_water(g[i])else(80,145,78)if dry else(35,42,40)
   if diff and dry:color=(200,62,166)
   if diff and is_road(g[i]):color=(245,151,39)
   if maskgap:color=(225,49,44)
   overview.putpixel((x-440,y),color)
 graph=json.loads((B/'Version Expansion Source Audit/graph.json').read_text());population=json.loads((ROOT/'assets/maps/falan/east_region/population.json').read_text());actors=[];links=[];generated=[]
 for row in graph['actors']:
  if row['map']!=100:continue
  x,y=row['cell'];r=dict(source_actor=row,state=state(x,y));r['population_prepared']=any(a.get('source')==100 and str(a.get('id'))==str(row['id'])and a.get('cell')==row['cell']for a in population['actors']);actors.append(r)
 for row in graph['links']:
  if row['source']!=100 and row['target']!=100:continue
  p=row.get('cell')if row['source']==100 else row.get('landing')
  if p and 0<=p[0]<w and 0<=p[1]<h:links.append(dict(link=row,role='entrance'if row['source']==100 else'return',state=state(*p)))
 for row in graph['dungeons']:
  if row['source']==100:
   a,b,c,d=row['rectangle'];samples=[state(x,y)for y in range(b,d+1)for x in range(a,c+1)];generated.append(dict(config=row['id'],rectangle=row['rectangle'],cells=len(samples),missing_raw_tuples=sum(s['active']!=s['full']for s in samples),missing_index=sum(s['ground_index_rgba'][3]<128 for s in samples),contexts=dict(Counter(s['context']for s in samples))))
 # The exact owner-envelope union extends beyond the earlier source preparer
 # guard. Inventory it separately without claiming neighboring goal ownership.
 envelope={};extra=[]
 for area,im in masks.items():
  c=Counter()
  for py in range(im.height):
   for px in range(im.width):
    x,y=(py+349,422-px)if area=='east_gate'else(px+474,py-49)
    if not(0<=x<w and 0<=y<h):continue
    desired=source_area(x,y)
    if desired!=area:
     other=source_pixel(desired,x,y)
     if 0<=other[0]<masks[desired].width and 0<=other[1]<masks[desired].height:continue
    excluded=any(in_rect((px,py),rect)for rect in metadata['areas'][area]['safe_rectangles']);i=y*w+x
    c['cells']+=1;c['excluded_city_or_joined_village']+=excluded
    if excluded:continue
    c['field']+=1;c['recorded'if flags[i]&0xc000 else'unknown']+=1;diff=(ag[i],ao[i])!=(g[i],o[i]);dry=g[i]not in(0,100)and not is_water(g[i]);c['missing_raw_tuple']+=diff;c['missing_dry']+=diff and dry;c['missing_pg1']+=ao[i]!=o[i]and o[i]>=1000;c['missing_roads']+=diff and is_road(g[i])
    if not(440<=x and y<360):
     c['outside_source_preparer_guard']+=1
     if diff and(dry or o[i]>=1000):extra.append(dict(cell=[x,y],area=area,active=[ag[i],ao[i]],full=[g[i],o[i]],recorded=bool(flags[i]&0xc000),scope='Existing owner-envelope outlier; sourcex<440 may belong to adjacent Falan/other-goal context, not automatically East-owned.'))
  envelope[area]=dict(c)
 # Existing neighboring goal envelope candidates remain separate from East.
 other_masks={a:Image.open(ROOT/f'assets/maps/falan/freyja_residual/full/{a}-surface.png').convert('RGBA')for a in metadata['areas']if a not in['east_gate','east_coast','north_coast']};other_summary=Counter()
 for row in extra:
  x,y=row['cell'];candidates=[]
  for area,im in other_masks.items():
   v=metadata['areas'][area];f=v['frame'];dx=x*3-f['origin'][0];dy=y*3-f['origin'][1];det=f['x'][0]*f['y'][1]-f['x'][1]*f['y'][0];u=(dx*f['y'][1]-dy*f['y'][0])/det;z=(f['x'][0]*dy-f['x'][1]*dx)/det;px=round((u-v['origin'][0])/3);py=round((z-v['origin'][1])/3)
   if 0<=px<im.width and 0<=py<im.height:candidates.append(dict(area=area,pixel=[px,py],mask_rgba=list(im.getpixel((px,py))),role='Other existing owner envelope; overlap does not prove source/visual completion.'))
  row['other_owner_envelopes']=candidates;other_summary['+'.join(sorted(c['area']for c in candidates))or'East-envelope-only']+=1
  row['scope']='Boundary comparison only; preserve Source100 and other-goal owners until ownership is resolved.'
 entry_catalog=json.loads((ROOT/'assets/maps/falan/east_region/field-entries.json').read_text())
 for row in generated:
  eligible=entry_catalog[str(row['config'])];row['prepared_eligible_entries']=len(eligible);row['eligible_entries_missing_raw_tuple']=sum((ag[y*w+x],ao[y*w+x])!=(g[y*w+x],o[y*w+x])for x,y in eligible)
 for r in areas.values():
  c=r['counts'];c['missing_raw_pg1_anchors']=len(r['missing_raw_pg1']);c['missing_raw_pg1_unique_ids']=len(r['missing_pg1_serial_counts']);c['missing_dry_native_ground_index_bindings']=sum(not is_water(row[2])for row in r['source_ground_index_gaps']);c['ground_index_missing_water_bindings']=sum(is_water(row[2])for row in r['source_ground_index_gaps'])
  for key in ['counts','exclusions','missing_pg1_serial_counts','field_scenery_categories']:r[key]=dict(r[key])
 summary=dict(scope='READ ONLY current source100 East/north-coast crop completeness. Canonical717fixed maps exclude separately owned map100 field planes. x>=440,y<360 and source_area ownership reproduce current East field preparer; outside runtime envelopes are listed, not silently reclassified.',source100_size=[w,h],active_sha256=sha(active_raw),full_compatible_candidate_sha256=sha(full_raw),archived_client_sha256=sha(client_raw),active_provenance=json.loads((ROOT/'assets/maps/falan/freyja_source/provenance.json').read_text()),known_source_cells_preserved=True,all_client_flags_preserved=True,area_context_totals=dict(allcounts),areas=areas,existing_owner_envelope_stats=envelope,owner_envelope_outliers_needing_boundary_classification=extra,owner_envelope_outlier_other_owner_summary=dict(other_summary),outside_runtime_envelopes=outside,source100_actors=actors,source100_entrances_and_returns=links,generated_rectangles=generated,limits=['This is an offline source/PNG/compiled-metadata audit, not a world render or Native route test.','PG1 missing from active raw may already have a partial pinned field-scenery owner; that evidence is recorded independently, and not-in-field-scenery is a follow-up candidate rather than proof every older context owner is absent.','Opaque Falan city, joined Il and joined Alyut contexts are excluded from field completion counts. Their source100 host remnants are not automatically the same maps as2000/2400.','Index alpha confirms a missing native tile binding; visual fallback may draw generic grass/water, which is not original road/terrain recovery.'])
 summary['outside_runtime_envelope_summary']={'cells':len(outside),'dry':sum(r['full'][0]not in(0,100)and not is_water(r['full'][0])for r in outside),'pg1_graphics':sum(r['full'][1]>=1000 for r in outside)}
 summary['current_mask_finding']='CurrentPNG masks exactly match earlier pinned East masks over the audited field scope;0native-dry-open support gaps. Active raw100incompleteness alone does not establish a terrain hole: masks retain the earlier source-complete East baseline.'
 files=['assets/maps/falan/freyja_source/100.dat','build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Server completion/100-client-plus-server.dat','assets/maps/falan/freyja_residual/full/provenance.json','assets/maps/falan/freyja_ground_index.png','assets/maps/falan/east_region/field-scenery.json','assets/maps/falan/east_region/population.json','assets/maps/falan/east_region/routes.json','scripts/forest/forest_freyja_terrain.gd','scripts/forest/forest_freyja_regions.gd','scripts/forest/forest_freyja_art.gd','scripts/forest/forest_east_road.gd','scripts/forest/forest_falan_frontier.gd']
 for area in masks:files +=[f'assets/maps/falan/freyja_residual/full/{area}-surface.png',f'assets/maps/falan/east_region/{area}-surface.png']
 summary['input_file_sha256']={p:sha((ROOT/p).read_bytes())for p in files};summary['source100_actor_summary']={'in_graph':len(actors),'prepared':sum(r['population_prepared']for r in actors)}
 (OUT/'report.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n');overview.resize((800,720),Image.Resampling.NEAREST).save(OUT/'source100-east-completeness.png');print(json.dumps({a:r['counts']for a,r in areas.items()},indent=2));print('contexts',dict(allcounts),'actors',len(actors),'links',len(links),'generated',len(generated),'outside',len(outside))
if __name__=='__main__':run()
