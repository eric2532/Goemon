"""Preserve native Freyja border/crest paint as alpha relief beside measured solid crags."""
import argparse,base64,hashlib,io,json,struct,sys,zlib
from pathlib import Path
from PIL import Image,ImageDraw
from prepare_elsa_scenery import outline
from build_freyja_destinations import load_map
from build_freyja_outlying import is_water
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/east_field_cliffs'
IDS=[12539,12540,12541,12544,12545,12547]
def products(map_loader=load_map, source_overrides=None):
 sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'));import cg_library as lib
 lookup=lib.serial_index();profiles=json.loads((ROOT/'assets/maps/original_crossgate/cliff-profiles.json').read_text())['profiles']
 images={};graphics={}
 for serial in IDS:
  row=lookup[serial];original=lib.image_from_record(row['pack'],row['row']).convert('RGBA');image=original.copy()
  assert hashlib.sha256(original.tobytes()).hexdigest()==profiles[str(serial)]['rgba_sha256'],('Native cliff revision mismatch',serial)
  mask=Image.new('L',image.size)
  for y in range(image.height):
   for x in range(image.width):
    r,g,b,a=image.getpixel((x,y))
    if a<128 or max(r,g,b)<=45 and max(r,g,b)-min(r,g,b)<3:mask.putpixel((x,y),255)
  for x,y in [(x,y)for x in range(image.width)for y in (0,image.height-1)]+[(x,y)for y in range(image.height)for x in (0,image.width-1)]:
   if mask.getpixel((x,y))==255:ImageDraw.floodfill(mask,(x,y),128)
  removed=0
  for y in range(image.height):
   for x in range(image.width):
    if mask.getpixel((x,y))==128:
     r,g,b,a=image.getpixel((x,y));image.putpixel((x,y),(r,g,b,0));removed+=bool(a)
  assert image.getbbox() and all(original.getpixel((x,y))[:3]==image.getpixel((x,y))[:3]for y in range(image.height)for x in range(image.width))
  images[serial]=image;graphics[str(serial)]={'origin':[row['x'],row['y']],'footprint':[max(1,row['east']),max(1,row['south'])],'pixel_height':profiles[str(serial)]['pixel_height'],'pack':row['pack'],'row':row['row'],'rgba_sha256':hashlib.sha256(original.tobytes()).hexdigest(),'alpha_border_pixels_removed':removed,'outline':outline(image)}
 width=2048;height=max(im.height for im in images.values())+4;atlas=Image.new('RGBA',(width,height));x=2
 for serial,image in images.items():
  atlas.paste(image,(x,2));graphics[str(serial)]['rect']=[x,2,image.width,image.height];x+=image.width+4
 assert x<width
 data={'schema':1,'graphics':graphics,'preservation':'Only alpha of border-connected native transparent/black occlusion pixels changes. All RGB values and original source files remain unchanged. Internal dark crevices remain.','inferred':'Native crest relief has0.12m edge depth and the same-family painted-crag vertical frame. A low closed hidden spur reuses that family profile at1/3horizontal and0.70vertical scale; no15mpeak is inferred from black occlusion masks.'}
 from prepare_field_assets import navigation_grid
 width,height,ground,objects,_=map_loader(lib,2400)
 walk=navigation_grid(width,height,ground,objects,lookup);bits=bytearray((width*height+7)//8)
 for i,value in enumerate(walk):
  if value:bits[i>>3]|=1<<(i&7)
 union=set();placements=[]
 for i,serial in enumerate(objects):
  if not 12536<=serial<=12547:continue
  row=lookup[serial];x,y=i%width,i//width;foot=[max(1,row['east']),max(1,row['south'])]
  placements.append({'map':2400,'cell':[x,y],'graphic':serial,'footprint':foot})
  union.update((x+a,y-b) for a in range(foot[0]) for b in range(foot[1]))
 with lib.connection() as db:map_row=dict(db.execute('SELECT * FROM files WHERE path=?',('BlueCrossgate/map/0/2400.dat',)).fetchone())
 data['alyut']={'source_path':map_row['path'],'source_sha256':hashlib.sha256((lib.SOURCE/map_row['path']).read_bytes()).hexdigest(),'size':[width,height],
  'walk':base64.b64encode(zlib.compress(bits)).decode(),'walk_sha256':hashlib.sha256(bits).hexdigest(),'placements':placements,
  'blocked_cliff_cells':[[x,y]for x,y in sorted(union)if not walk[y*width+x]],'walkable_cliff_cells':[[x,y]for x,y in sorted(union)if walk[y*width+x]],
  'native_graphic_attributes':{str(s):list(lib.cg.RECORD.unpack_from(lib.cg.graphic_index(lookup[s]['pack'])[0],lookup[s]['row']*40)[7])for s in range(12536,12548)}}
 if source_overrides and 2400 in source_overrides:
  data['alyut']['source_path']=source_overrides[2400]['path'];data['alyut']['source_sha256']=source_overrides[2400]['sha256']
 doors=json.loads((ROOT/'assets/maps/falan/east_region/village_buildings/data.json').read_text())['maps']['2400']['doors']
 protected={(58,31),(59,31),(66,64),(67,64)}|{tuple(row['source_cell'])for row in doors}
 data['alyut']['protected_cells']=[list(p)for p in sorted(protected)]
 data['alyut']['opening_exceptions']=[{'cell':list(p),'reason':'Exact existing native gate/house portal'}for p in sorted(union&protected)]
 field_folder=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Version Expansion Source Audit'
 ref=next(r for r in json.loads((field_folder/'references.json').read_text())if r['file']=='map__00100_field1')
 raw=(field_folder/ref['file']).read_bytes();assert hashlib.sha256(raw).hexdigest()==ref['sha256']
 assert hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==ref['git_blob']
 fw,fh=struct.unpack_from('>HH',raw,40);fc=fw*fh
 fg=struct.unpack_from('>'+str(fc)+'H',raw,44);fo=struct.unpack_from('>'+str(fc)+'H',raw,44+fc*2)
 fwlk=navigation_grid(fw,fh,fg,fo,lookup)
 field_bits={name:bytearray((fw*fh+7)//8)for name in ['walk','land','blocked_land','hidden_land']}
 for i,tile in enumerate(fg):
  land=bool(tile)and not is_water(tile)
  for name,value in [('walk',bool(fwlk[i])),('land',land),('blocked_land',land and not fwlk[i]),('hidden_land',tile==100 and not fwlk[i])]:
   if value:field_bits[name][i>>3]|=1<<(i&7)
 portals=set();routes=json.loads((ROOT/'assets/maps/falan/east_region/routes.json').read_text())
 for row in routes['fixed']:
  if row[0]==100:portals.add((row[1],row[2]))
  if row[3]==100:portals.add((row[4],row[5]))
 for key in ['inline_warps','event_links']:
  for row in routes[key]:
   if row['source']==100 and row.get('cell'):portals.add(tuple(row['cell']))
   if row['target']==100 and row.get('landing'):portals.add(tuple(row['landing']))
 for row in routes['automatic']:
  if row['source']==100:
   a,b,c,d=row['bounds'];portals.update((x,y)for x in range(a,c+1)for y in range(b,d+1))
 data['field']={'map':100,'size':[fw,fh],'source_path':ref['path'],'source_sha256':ref['sha256'],'git_blob':ref['git_blob'],'source_url':ref['url'],
  **{name:base64.b64encode(zlib.compress(value)).decode()for name,value in field_bits.items()},
  'sha256':{name:hashlib.sha256(value).hexdigest()for name,value in field_bits.items()},
  'portal_cells':[list(p)for p in sorted(portals)],'owned_window':[440,0,fw-440,360],
  'method':'Same SHA/Git-blob-verified pinned100map as the field owner; original graphic walk attributes and nonzero/non-water ground. Inferred hidden substrate may extend one tile beyond cliff footprints only onto blocked ground100inside the same owned window, excluding original portals. No terrain or navigation mutation.'}
 blob=io.BytesIO();atlas.save(blob,format='PNG',optimize=True)
 shader_source=(ROOT/'assets/materials/forest_stone.gdshader').read_text()
 assert '.58+stone_normal.y*.24' in shader_source
 shader=shader_source.replace('.58+stone_normal.y*.24','.40+stone_normal.y*.24').replace('stone_point*.36','stone_point*(east_vertex_palette?1.08:.36)').replace('uniform bool use_castle_stone = false;', 'uniform bool use_castle_stone = false;\nuniform bool east_vertex_palette = false;').replace('ALBEDO=attack_range_ink(color,stone_point,stone_normal);','if(east_vertex_palette)color=COLOR.rgb*(.83+grain*.34);\n\tALBEDO=attack_range_ink(color,stone_point,stone_normal);')
 data['reverse_shader']={'source':'assets/materials/forest_stone.gdshader','sha256':hashlib.sha256(shader_source.encode()).hexdigest(),'inferred_change':'Lower hidden-wall moss coverage from.58to.40; retain original substrate texture/material pitches. Optional measured-relief body mode uses coarse native vertex palette with3xshared grain pitch; shared source shader unchanged. Shared shader unchanged.'}
 return {'native-edges.png':blob.getvalue(),'data.json':(json.dumps(data,ensure_ascii=False,indent=2)+'\n').encode(),'reverse.gdshader':shader.encode()}
def main():
 p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args();result=products()
 if a.check:assert all((OUT/name).read_bytes()==value for name,value in result.items()),'Stale East cliff edge art'
 else:
  OUT.mkdir(parents=True,exist_ok=True)
  for name,value in result.items():(OUT/name).write_bytes(value)
 print('EAST_FIELD_CLIFFS:6original border/crest graphics; source RGB preserved')
if __name__=='__main__':main()
