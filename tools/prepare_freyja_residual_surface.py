"""Recover the source-100 near-city alpha notch without changing owner envelopes."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import sys
import os
import shutil
import subprocess
from PIL import Image
from build_freyja_destinations import load_map
from build_freyja_outlying import is_road, is_water
from recover_sokia import rectangles

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/freyja_residual'
BASE={'freyja':'assets/maps/falan/west_approach_surface.png',
      'east_gate':'assets/maps/falan/east_region/east_gate-surface.png'}
ORIGINS={'freyja':(-480,-204),'east_gate':(-675,-204)}
SOURCE=ROOT.parent/'Magic Power'
IMPORT={'compress/mode':'0','mipmaps/generate':'false','process/fix_alpha_border':'true','process/premult_alpha':'false','process/hdr_as_srgb':'false'}


def configure_imports(names,check=False,directory=OUT,resource_root='res://assets/maps/falan/freyja_residual/',settings=IMPORT):
    for name in names:
        path=directory/(name+'.import')
        text=path.read_text()if path.exists()else'[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n[deps]\nsource_file="'+resource_root+name+'"\n[params]\n'
        for key,value in settings.items():
            pattern=r'(?m)^'+re.escape(key)+r'=.*$'
            if check:assert re.search(pattern,text).group(0)==key+'='+value,(name,key)
            elif re.search(pattern,text):text=re.sub(pattern,key+'='+value,text)
            else:text+=key+'='+value+'\n'
        if not check:path.write_text(text)


def local(area,x,y):
    return (3*y-582,1287-3*x)if area=='freyja'else(591-3*y,3*x-1251)


def pixel(area,x,y):
    a,b=local(area,x,y);ox,oz=ORIGINS[area]
    return (a-ox)//3,(b-oz)//3


def city_pixel(area,x,y):
    lx,lz=local(area,x,y)
    cx,cz=(lx-141,lz+240)if area=='freyja'else(-135-lx,-225-lz)
    return ((cx+402)//3,(cz+438)//3),lz<54


def apply_frame(frame,point):
    return tuple(frame['origin'][k]+frame['x'][k]*point[0]+frame['y'][k]*point[1]for k in (0,1))


def inside_rect(point,rect):
    return rect[0]<=point[0]<rect[0]+rect[2]and rect[1]<=point[1]<rect[1]+rect[3]


def row_spans(cells,width):
    rows={}
    for i in cells:rows.setdefault(i//width,[]).append(i%width)
    spans=[]
    for y,xs in sorted(rows.items()):
        xs=sorted(xs);start=last=xs[0]
        for x in xs[1:]+[xs[-1]+2]:
            if x>last+1:spans.append([y,start,last]);start=x
            last=x
    assert sum(right-left+1 for _,left,right in spans)==len(cells)
    return spans


def prepare_completion(source_map,contracts_path,bounds=None,scenery_catalog=None,ground_index=None,collect_exclusions=False):
    """Offline whole-source masks through the seven measured existing map100 owners."""
    sys.path.insert(0,str(SOURCE/'tools'))
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    raw=Path(source_map).read_bytes();w,h,ground,objects,flags=lib.parse_map(raw)
    client=(SOURCE/'data/crossgate/source/BlueCrossgate/map/0/100.dat').read_bytes()
    cw,ch,cg,co,cf=lib.parse_map(client)
    assert(w,h)==(cw,ch)and flags==cf
    assert all(not v or ground[i]==v for i,v in enumerate(cg))
    assert all(not v or objects[i]==v for i,v in enumerate(co))
    assert all((ground[i],objects[i])==(cg[i],co[i])for i,v in enumerate(cf)if v&0xc000)
    walk=navigation_grid(w,h,ground,objects,lib.serial_index())
    scenery_path=Path(scenery_catalog)if scenery_catalog else ROOT/'assets/maps/falan/venoa_field/scenery.json'
    scenery=json.loads(scenery_path.read_text())
    tree_stations={(int(r['cell'][0]),int(r['cell'][1])):int(r['serial'])for r in scenery['placements']if r['family']=='tree'}
    dry={i for i,tile in enumerate(ground)if tile not in (0,100)and not is_water(tile)}
    dry_open={i for i in dry if walk[i]}
    contracts=json.loads(Path(contracts_path).read_text());outputs={};areas={};supported=set();shown=set();envelopes=set()
    city=Image.open(ROOT/'assets/maps/falan/city_surface.png').convert('RGBA')
    for row in contracts['areas']:
        area=row['area'];base=Image.open(Path(contracts_path).parent/(area+'-surface.png')).convert('RGBA')
        assert hashlib.sha256(base.tobytes()).hexdigest()==row['mask_rgba_sha256']
        offset=8 if area=='south_lakes'else 0
        image=Image.new('RGBA',(base.width+offset,base.height),(255,0,0,255));image.paste(base,(offset,0))
        origin=[row['origin'][0]-offset*3,row['origin'][1]]
        exception=Image.new('RGBA',image.size);support=Image.new('RGBA',image.size)
        if area in ('freyja','east_gate'):
            previous=Image.open(OUT/(area+'-exception.png')).convert('RGBA');assert previous.size==base.size
            exception.paste(previous,(offset,0))
        changed=[];blocked=set();excluded=Counter();counts=Counter();owner_support=set();owner_shown=set()
        exclusion_cells={name:{'source':set(),'pixels':set()}for name in ('opaque_city','joined_village')}
        for py in range(image.height):
            for px in range(image.width):
                local=(origin[0]+px*3,origin[1]+py*3)
                at=apply_frame(row['frame'],local);xx,yy=at[0]/3,at[1]/3;x,y=round(xx),round(yy)
                assert abs(x-xx)<1e-6 and abs(y-yy)<1e-6
                if not(0<=x<w and 0<=y<h):continue
                i=y*w+x;tile=ground[i]
                if row['canonical_area']==area:envelopes.add(i)
                village=row.get('joined_village')
                if village and inside_rect(apply_frame(village['frame'],local),village['bounds']):
                    excluded['joined_village']+=1
                    exclusion_cells['joined_village']['pixels'].add((px,py))
                    if collect_exclusions:exclusion_cells['joined_village']['source'].add(i)
                    continue
                city_owned=False;city_layer=False
                if 'city'in row:
                    info=row['city'];cp=apply_frame(info['frame'],local)
                    city_layer=local[1]<info['end']and inside_rect(cp,info['bounds'])
                    cx,cy=[int((cp[k]-info['mask_origin'][k])/3)for k in (0,1)]
                    city_owned=city_layer and 0<=cx<city.width and 0<=cy<city.height and city.getpixel((cx,cy))[3]>=128
                if city_owned:
                    excluded['opaque_city']+=1
                    exclusion_cells['opaque_city']['pixels'].add((px,py))
                    if collect_exclusions:exclusion_cells['opaque_city']['source'].add(i)
                    continue
                if i in dry:
                    support.putpixel((px,py),(255,255 if walk[i]else 0,0,255));owner_shown.add(i)
                    if walk[i]:owner_support.add(i)
                if bounds and not inside_rect((x,y),bounds):continue
                if not tile:continue
                if tile==100:
                    if not cg[i]:blocked.add((x,y))
                    counts['blocked_control100_retained']+=1;continue
                old=image.getpixel((px,py))
                if not cg[i]or old[3]<128:
                    rgba=(255 if is_water(tile)else 0,224 if is_road(tile)else 0,220 if 1000<=tile<=1099 or 5954<=tile<=5988 else 0,255)
                    if rgba!=old:image.putpixel((px,py),rgba);changed.append([x,y]);counts['source_water'if is_water(tile)else'dry_ground']+=1
                    if tile not in range(5000,5009)and not walk[i]:blocked.add((x,y))
                    if city_layer:exception.putpixel((px,py),(255,255,255,255))
                if not cg[i]and is_water(tile):assert image.getpixel((px,py))[0]==255,'A newly recovered wet prop must not create native land'
        assert all(not walk[y*w+x]and ground[y*w+x]not in range(5000,5009)and not flags[y*w+x]&2 for x,y in blocked)
        delegated=[]
        if area=='south_lakes':
            for x,y in sorted(blocked&tree_stations.keys()):
                assert objects[y*w+x]==tree_stations[x,y],'Delegate only an exact source-ID tree station'
                delegated.append([x,y,tree_stations[x,y]])
            blocked.difference_update((x,y)for x,y,_ in delegated)
        for px,py in [(x,y)for y in range(base.height)for x in range(base.width)]:
            cell=apply_frame(row['frame'],(row['origin'][0]+px*3,row['origin'][1]+py*3));i=round(cell[1]/3)*w+round(cell[0]/3)
            if 0<=i<w*h and cg[i]and base.getpixel((px,py))[3]>=128:assert image.getpixel((px+offset,py))==base.getpixel((px,py))
        outputs[area+'-surface.png']=image;outputs[area+'-exception.png']=exception;outputs[area+'-source-support.png']=support
        areas[area]=dict(origin=origin,size=list(image.size),old_pixel_offset=[offset,0],changed_cells=changed,counts=dict(counts),exclusions=dict(excluded),
                         scenery_owned_blocked_cells=delegated,
                         blocked_rectangles=[list(r)for r in rectangles(blocked)],source_dry_spans=row_spans(owner_shown,w),source_dry_open_spans=row_spans(owner_support,w),
                         safe_rectangles=[list(r)for r in rectangles(set().union(*(cells['pixels']for cells in exclusion_cells.values())))],
                         protected_rgba_sha256=row['mask_rgba_sha256'],rgba_sha256=hashlib.sha256(image.tobytes()).hexdigest(),frame=row['frame'])
        if collect_exclusions:
            areas[area]['exact_owner_exclusions']={name:{'cells':len(cells['source']),'source_spans':row_spans(cells['source'],w),
                'local_pixel_rectangles':[list(r)for r in rectangles(cells['pixels'])],
                'source_water_cells':sum(is_water(ground[i])for i in cells['source']),
                'source_control100_cells':sum(ground[i]==100 for i in cells['source']),
                'source0_cells':sum(ground[i]==0 for i in cells['source'])}for name,cells in exclusion_cells.items()}
        if row['canonical_area']==area:shown.update(owner_shown);supported.update(owner_support)
    domain=Image.new('RGBA',(w,h))
    domain.putdata([(255 if i in dry else 0,255 if i in dry_open else 0,255 if cf[i]&0xc000 else 0,255 if ground[i]else 0)for i in range(w*h)])
    outputs['source-domain.png']=domain
    from prepare_venoa_field import source_water_surfaces
    assert ground_index,'Completed source water needs its matching prepared floor index'
    water,backdrop,ocean_index,_=source_water_surfaces(w,h,ground,Image.open(ground_index).convert('RGBA'))
    outputs.update({'water.png':water,'ocean-backdrop.png':backdrop,'ocean-index.png':ocean_index})
    data=dict(schema=1,active=False,source_map=100,source_sha256=hashlib.sha256(raw).hexdigest(),client_sha256=hashlib.sha256(client).hexdigest(),dimensions=[w,h],preview_bounds=bounds,
              import_contract={**IMPORT,'process/fix_alpha_border':'false'},
              scenery_catalog=str(scenery_path),scenery_catalog_sha256=hashlib.sha256(scenery_path.read_bytes()).hexdigest(),
              water_dimensions=[w,h],ocean_dimensions=[w,624],water_rgba_sha256=hashlib.sha256(water.tobytes()).hexdigest(),
              ocean_backdrop_rgba_sha256=hashlib.sha256(backdrop.tobytes()).hexdigest(),ocean_index_rgba_sha256=hashlib.sha256(ocean_index.tobytes()).hexdigest(),
              ocean_contract='Existing source100 water owner: every known source pixel retained; only source0 and inherited rows610–623 use inferred ocean background. No terrain, navigation or encounters supplied by these visual derivatives.',
              areas=areas,source_dry_cells=len(dry),source_dry_open_cells=len(dry_open),source_dry_spans=row_spans(dry,w),source_dry_open_spans=row_spans(dry_open,w),
              owner_dry_cells=len(shown),owner_dry_open_cells=len(supported),dry_open_outside_envelopes=[list(divmod(i,w)[::-1])for i in sorted(dry_open-envelopes)],
              dry_outside_envelopes=[list(divmod(i,w)[::-1])for i in sorted(dry-envelopes)],
              object_anchors_outside_envelopes=[[i%w,i//w,s]for i,s in enumerate(objects)if s>=1000 and i not in envelopes],
              source_domain_contract='Full source-plane dry ground excludes0/100/water; red=dry,green=decoder-open dry,blue=client-recorded flag,alpha=known source. Raw source support is distinct from owner support. Per-owner masks exclude exact existing opaque city and joined-village ownership; blocked dry scenery is separate from decoder-open support.',
              contract='Offline staged only. Every opaque known-client mask pixel is preserved at its measured frame/offset. Whole source surfaces, blocked dry cells and recorded water are considered without road or BFS filtering; southwest owner extends8columns only. Source100 remains blocked control data without invented visible floor. No runtime, navigation, encounter, source archive or saved-map activation.')
    assert not data['dry_open_outside_envelopes'],'Reconcile remaining dry ground outside measured owners'
    assert not data['dry_outside_envelopes'],'Blocked dry ground also requires a measured owner'
    return outputs,data


def completion_gd(outputs,data):
    root='res://assets/maps/falan/freyja_residual/full/'
    lines=['extends RefCounted','## Prepared full-source inputs for the existing map100 owners; originals stay intact.',
           'const SOURCE_SHA256='+json.dumps(data['source_sha256']),
           'const PREVIEW_BOUNDS='+str(data['preview_bounds'])if data['preview_bounds']else'const PREVIEW_BOUNDS=[]',
           'const SURFACES={']
    for area in data['areas']:lines.append(' '+json.dumps(area)+':preload('+json.dumps(root+area+'-surface.png')+'),')
    lines+=['}','const ORIGINS={']
    for area,row in data['areas'].items():lines.append(' '+json.dumps(area)+':Vector2(%s,%s),'%tuple(row['origin']))
    lines+=['}','const MASK_RGBA='+json.dumps({area:row['rgba_sha256']for area,row in data['areas'].items()},sort_keys=True),
            'const SUPPORT_RGBA='+json.dumps({area:hashlib.sha256(outputs[area+'-source-support.png'].tobytes()).hexdigest()for area in data['areas']},sort_keys=True),
            'const DOMAIN_RGBA='+json.dumps(hashlib.sha256(outputs['source-domain.png'].tobytes()).hexdigest()),'const BLOCKS={']
    for area,row in data['areas'].items():lines.append(' '+json.dumps(area)+':['+','.join('Rect2i(%d,%d,%d,%d)'%tuple(r)for r in row['blocked_rectangles'])+'],')
    lines+=['}','## Exact opaque-city/joined-village exclusions in local mask pixels, including source water/control cells.','const SAFE_RECTANGLES={']
    for area,row in data['areas'].items():lines.append(' '+json.dumps(area)+':['+','.join('Rect2i(%d,%d,%d,%d)'%tuple(r)for r in row['safe_rectangles'])+'],')
    lines+=['}','const CITY_REPAIRS='+json.dumps([area for area in data['areas']if outputs[area+'-exception.png'].getchannel('A').getbbox()]),
            'const WATER=preload('+json.dumps(root+'water.png')+')','const OCEAN_BACKDROP=preload('+json.dumps(root+'ocean-backdrop.png')+')',
            'const OCEAN_INDEX_PATH='+json.dumps(root+'ocean-index.png')]
    return '\n'.join(lines)+'\n'


def prepare():
    sys.path.insert(0,str(SOURCE/'tools'))
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    w,h,ground,objects,flags=load_map(lib,100);lookup=lib.serial_index()
    walk=navigation_grid(w,h,ground,objects,lookup)
    masks={area:Image.open(ROOT/path).convert('RGBA')for area,path in BASE.items()}
    south=Image.open(ROOT/'assets/maps/falan/south_approach_surface.png').convert('RGBA')
    city=Image.open(ROOT/'assets/maps/falan/city_surface.png').convert('RGBA')
    assert masks['freyja'].size==(321,229)and masks['east_gate'].size==(387,459)
    gaps=[]
    # The audited notch is wholly inside these existing owners, between their
    # legacy city-strip fade and the East field's source-x440 boundary.
    for y in range(36,135):
        for x in range(408,440):
            i=y*w+x
            if not walk[i]:continue
            alphas=[masks[a].getpixel(pixel(a,x,y))[3]for a in masks]
            sx,sy=x-263,y-134
            if 0<=sx<south.width and 0<=sy<south.height:alphas.append(south.getpixel((sx,sy))[3])
            if max(alphas)==0:gaps.append((x,y))
    assert len(gaps)==1252 and sum(not is_water(ground[y*w+x])for x,y in gaps)==942
    outputs={};areas={};shore_union=set();graphics={}
    for area,base in masks.items():
        repaired=base.copy();exception=Image.new('RGBA',base.size)
        fixed=[];city_kept=[];counts=Counter();blocked=set();shores=[];other_art=[];void_cells=[]
        band=[(x,y)for y in range(36,139)for x in range(408,440)]
        for x,y in band:
            i=y*w+x
            if not ground[i]or not flags[i]&0xc000 or base.getpixel(pixel(area,x,y))[3]>=128:continue
            cp,within=city_pixel(area,x,y)
            city_owned=within and 0<=cp[0]<city.width and 0<=cp[1]<city.height and city.getpixel(cp)[3]>=128
            if city_owned:
                city_kept.append([x,y]);continue
            serial=objects[i]
            if ground[i]==100:
                void_cells.append([x,y]);blocked.add((x,y))
                if serial>=1000:other_art.append([x,y,serial])
                continue
            if not walk[i]and not is_water(ground[i]):blocked.add((x,y))
            cap=12500<=serial<=12535
            rgba=(0 if cap or not is_water(ground[i])else 255,224 if is_road(ground[i])else 0,0,255)
            p=pixel(area,x,y);repaired.putpixel(p,rgba);exception.putpixel(p,(255,255,255,255))
            fixed.append([x,y]);counts['shore_cap'if cap else'source_water'if is_water(ground[i])else'dry_ground']+=1
            if cap:shores.append([x,y,serial]);shore_union.add((x,y,serial))
            elif serial>=1000:other_art.append([x,y,serial])
        fixed_set={pixel(area,x,y)for x,y in fixed}
        assert all(repaired.getpixel((x,y))==base.getpixel((x,y))for y in range(base.height)for x in range(base.width)if(x,y)not in fixed_set)
        outputs[area+'-surface.png']=repaired;outputs[area+'-exception.png']=exception
        areas[area]={'repaired_cells':fixed,'counts':dict(counts),'preserved_city_cells':city_kept,
                     'shores':shores,'blocked_cells':[list(p)for p in sorted(blocked)],'blocked_rectangles':[list(r)for r in rectangles(blocked)],
                     'recorded_cache_void':void_cells,'other_source_art':other_art,
                     'base':BASE[area],'base_sha256':hashlib.sha256((ROOT/BASE[area]).read_bytes()).hexdigest(),
                     'origin':list(ORIGINS[area]),'size':list(base.size)}
        assert {(x,y)for a,b,rw,rh in areas[area]['blocked_rectangles']for y in range(b,b+rh)for x in range(a,a+rw)}==blocked
        assert all(not walk[y*w+x]and ground[y*w+x]not in range(5000,5009)for x,y in blocked)
        assert all(not flags[y*w+x]&2 for x,y in blocked),'Never block a source-confirmed port'
    for x,y,serial in sorted(shore_union):
        g=lookup[serial];im=lib.image_from_record(g['pack'],g['row'])
        graphics[str(serial)]={'family':'shore','rgba_sha256':hashlib.sha256(im.tobytes()).hexdigest()}
    with lib.connection()as db:ident=db.execute("SELECT id FROM files WHERE path='BlueCrossgate/map/0/100.dat'").fetchone()[0]
    data={'schema':1,'source_map':100,'source_sha256':hashlib.sha256(lib.source_file(ident)[1].read_bytes()).hexdigest(),
          'source_dimensions':[w,h],'gap_cells':[list(p)for p in gaps],'gap_counts':{'dry_ground':942,'source_water':310},
          'source_band':[408,36,32,103],'areas':areas,'shores':[list(p)for p in sorted(shore_union)],'graphics':graphics,
          'city_mask':'assets/maps/falan/city_surface.png','city_mask_sha256':hashlib.sha256((ROOT/'assets/maps/falan/city_surface.png').read_bytes()).hexdigest(),
          'contract':'The full original recorded dry/water band surrounding the1252open-cell notch, including blocked dry ground. Opaque city pixels retained. Original maps/base masks/owner frames/field dimensions/ports/encounter rules unchanged. Source blocked dry/cache100 cells have exact merged static blocks; water/source0 is not relabelled as land. Existing cliff/cache100 presentation and unmatched tree art remain required visual reconciliation. Source shore caps reuse existing native visual forms. City-alpha0 cells use a scoped prepared clipping exception; other maps remain default-off.'}
    assert data['source_sha256']=='bc286a9dfcad277a4f1dbdad6e35277e5ed62d02165aa79862bec33db1df9905'
    data['import_contract']=IMPORT
    gd='''extends RefCounted
## Generated by tools/prepare_freyja_residual_surface.py; original masks remain intact.
const SURFACES={"freyja":preload("res://assets/maps/falan/freyja_residual/freyja-surface.png"),"east_gate":preload("res://assets/maps/falan/freyja_residual/east_gate-surface.png")}
const EXCEPTIONS={"freyja":preload("res://assets/maps/falan/freyja_residual/freyja-exception.png"),"east_gate":preload("res://assets/maps/falan/freyja_residual/east_gate-exception.png")}
const BASES={"freyja":preload("res://assets/maps/falan/west_approach_surface.png"),"east_gate":preload("res://assets/maps/falan/east_region/east_gate-surface.png")}
static var prepared={}
static func surface(area:String)->Texture2D:
 if prepared.has(area):return prepared[area]
 # Preserve imported transparent RGB too: legacy native coverage reads that channel.
 var image=BASES[area].get_image();var patch=EXCEPTIONS[area].get_image();var paint=SURFACES[area].get_image()
 var bounds:Rect2i=patch.get_used_rect()
 for y in range(bounds.position.y,bounds.end.y):
  for x in range(bounds.position.x,bounds.end.x):
   if patch.get_pixel(x,y).a>.5:image.set_pixel(x,y,paint.get_pixel(x,y))
 prepared[area]=ImageTexture.create_from_image(image)
 prepared[area].set_meta("source_cpu_image",image)
 return prepared[area]
'''
    return outputs,data,gd


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');parser.add_argument('--stage',type=Path)
    parser.add_argument('--completion-source',type=Path);parser.add_argument('--owner-contracts',type=Path);parser.add_argument('--source-bounds',nargs=4,type=int);parser.add_argument('--scenery-catalog',type=Path);parser.add_argument('--exclusion-out',type=Path);args=parser.parse_args()
    if args.completion_source:
        assert args.stage and args.owner_contracts,'Whole-source preparation requires an explicit offline stage and protected owner contracts'
        outputs,data=prepare_completion(args.completion_source,args.owner_contracts,args.source_bounds,args.scenery_catalog,args.stage/'freyja_ground_index.png',bool(args.exclusion_out))
        if args.exclusion_out:
            report={k:data[k]for k in ('source_sha256','dimensions','source_domain_contract')}
            report['areas']={area:{key:row[key]for key in ('origin','size','frame','exact_owner_exclusions')}for area,row in data['areas'].items()}
            checks=0
            for area,row in report['areas'].items():
                for cells in row['exact_owner_exclusions'].values():
                    source={(x,y)for y,left,right in cells['source_spans']for x in range(left,right+1)}
                    pixels={(x,y)for a,b,w,h in cells['local_pixel_rectangles']for y in range(b,b+h)for x in range(a,a+w)}
                    assert len(source)==len(pixels)==cells['cells'];checks+=1
                    mapped=set()
                    for px,py in pixels:
                        point=apply_frame(row['frame'],(row['origin'][0]+px*3,row['origin'][1]+py*3))
                        mapped.add((round(point[0]/3),round(point[1]/3)))
                    assert mapped==source;checks+=1
                    assert sum(w*h for _,_,w,h in cells['local_pixel_rectangles'])==len(pixels);checks+=1
            report.update(checks=checks,owner_contracts_sha256=hashlib.sha256(args.owner_contracts.read_bytes()).hexdigest(),city_mask_sha256=hashlib.sha256((ROOT/'assets/maps/falan/city_surface.png').read_bytes()).hexdigest())
            report['contract']='Exact existing opaque-city and joined-village predicates, sampled over every owner mask cell inside source100, independent of dry/water/control/bridge semantics. Source spans are[y,left,right]inclusive; local pixel rectangles are[x,y,width,height]. No runtime or prepared terrain files changed.'
            args.exclusion_out.parent.mkdir(parents=True,exist_ok=True);args.exclusion_out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
            print('FREYJA_EXACT_OWNER_EXCLUSIONS',{a:{k:d['cells']for k,d in r['exact_owner_exclusions'].items()}for a,r in report['areas'].items()})
            return
        gd=completion_gd(outputs,data)
        if args.check:
            assert json.loads((args.stage/'provenance.json').read_text())==data
            assert(args.stage/'data.gd').read_text()==gd
            for name,image in outputs.items():
                actual=Image.open(args.stage/name).convert('RGBA');assert actual.size==image.size and actual.tobytes()==image.tobytes(),name
        else:
            args.stage.mkdir(parents=True,exist_ok=True)
            for name,image in outputs.items():image.save(args.stage/name)
            (args.stage/'provenance.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
            (args.stage/'data.gd').write_text(gd)
        configure_imports(outputs,args.check,args.stage,'res://assets/maps/falan/freyja_residual/full/',data['import_contract'])
        engine=os.environ.get('GODOT_BIN')or shutil.which('godot')or'/Applications/Godot.app/Contents/MacOS/Godot'
        command=[engine,'--headless','--path',str(ROOT),'--script','res://tools/prepare_sokia_cpu_masks.gd',
                 '--log-file',str(args.stage.resolve()/'cpu-images-engine.log'),'--','--freyja-source','--source-only','--mask-root='+str(args.stage.resolve())]
        if args.check:command.append('--check')
        result=subprocess.run(command,text=True,capture_output=True)
        (args.stage/'cpu-images-check.log'if args.check else args.stage/'cpu-images-prepare.log').write_text(result.stdout+result.stderr)
        assert result.returncode==0 and 'SCRIPT ERROR'not in result.stdout+result.stderr,'Prepared CPU Image check failed'
        print('FREYJA_FULL_SOURCE_OFFLINE', {a:{'size':d['size'],'changed':len(d['changed_cells']),'counts':d['counts']}for a,d in data['areas'].items()},'dry_open_outside_envelopes='+str(len(data['dry_open_outside_envelopes'])))
        return
    outputs,data,gd=prepare();dest=args.stage or OUT
    if args.check:
        for name,image in outputs.items():
            actual=Image.open(dest/name).convert('RGBA');assert actual.size==image.size and actual.tobytes()==image.tobytes(),name
        assert json.loads((dest/'provenance.json').read_text())==data
        assert(dest/'data.gd').read_text()==gd
        if not args.stage:configure_imports(outputs,True)
    else:
        dest.mkdir(parents=True,exist_ok=True)
        for name,image in outputs.items():image.save(dest/name)
        (dest/'provenance.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n');(dest/'data.gd').write_text(gd)
        if not args.stage:configure_imports(outputs)
    print('FREYJA_RESIDUAL', {a:{'repaired':len(d['repaired_cells']),'city_preserved':len(d['preserved_city_cells']),'counts':d['counts'],'blocked':len(d['blocked_cells']),'shores':len(d['shores'])}for a,d in data['areas'].items()})


if __name__=='__main__':main()
