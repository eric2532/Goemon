"""Private11077/11078arched leaves/posts; source pixels stay immutable."""
import hashlib,json,math
from pathlib import Path
from PIL import Image,ImageDraw
from prepare_east_nature import ROOT,sources
OUT=ROOT/'assets/maps/falan/east_region/il_gate_parts'
FORMS={11077:dict(shift=0,leaf_bottom=[[4,146],[54,120]],post_feet=[[4,157],[22,168],[40,158]],post_polygon=[[4,54],[22,44],[40,54],[40,161],[22,173],[4,162]],stone_sample=[11,74,19,89],wood_sample=[39,65,47,79]),11078:dict(shift=28,leaf_bottom=[[32,146],[82,120]],post_feet=[[1,132],[18,143],[34,133]],post_polygon=[[1,30],[18,20],[34,30],[34,135],[18,146],[0,136]],stone_sample=[8,50,16,65],wood_sample=[65,60,73,74])}
def sha(raw):return hashlib.sha256(raw).hexdigest()
def prepare():
 table,_,pins=sources();OUT.mkdir(parents=True,exist_ok=True);rows={};master_path=ROOT/'assets/textures/edo/wood.png';master=Image.open(master_path).convert('RGB');plaster_path=ROOT/'assets/textures/edo/plaster.png';plaster=Image.open(plaster_path).convert('RGB')
 for serial,spec in FORMS.items():
  g,page=table[serial];atlas=Image.open(page).convert('RGBA');x,y,w,h=g['rect'];original=atlas.crop((x,y,x+w,y+h));assert sha(original.tobytes())==g['rgba_sha256'];original.save(OUT/f'{serial}-native.png')
  # Reuse the exact same native arched top:11078is shifted28pixels. The full
  # leaf behind the post is hidden reconstruction, never a new route/door.
  ref=table[11077];rg,rp=ref;rx,ry,rw,rh=rg['rect'];reference=Image.open(rp).convert('RGBA').crop((rx,ry,rx+rw,ry+rh));arch=[]
  for xx in range(0,55,2):
   ys=[yy for yy in range(45)if reference.getpixel((xx,yy))[3]>=128]
   if ys:arch.append([xx+spec['shift'],min(ys)])
  leaf_polygon=[spec['leaf_bottom'][0],*arch,spec['leaf_bottom'][1]];leaf_mask=Image.new('1',original.size);ImageDraw.Draw(leaf_mask).polygon([tuple(p)for p in leaf_polygon],fill=1);post_mask=Image.new('1',original.size);ImageDraw.Draw(post_mask).polygon([tuple(p)for p in spec['post_polygon']],fill=1)
  leaf=original.copy();post=original.copy();ground=original.copy();back=original.copy()
  colors=[p[:3]for p in original.crop(tuple(spec['wood_sample'])).getdata()if p[3]>=128];target=[sum(p[c]for p in colors)/len(colors)for c in range(3)];means=[sum(p[c]for p in master.getdata())/(master.width*master.height)for c in range(3)];wood=Image.new('RGBA',master.size);wood.putdata([(*(max(0,min(255,round(p[c]*target[c]/means[c])))for c in range(3)),255)for p in master.getdata()]);wood.save(OUT/f'{serial}-wood.png')
  stone=original.crop(tuple(spec['stone_sample']));solid=sorted([p[:3]for p in stone.getdata()if p[3]>=128],key=lambda p:sum(p));pale=solid[len(solid)*2//3:];tone=tuple(sum(p[c]for p in pale)/len(pale)for c in range(3));tile=Image.new('RGBA',plaster.size)
  # Hidden masonry uses the existing fine plaster grain, colored from native
  # pale mortar. Repeating the tiny front photograph made scalloped wallpaper.
  levels=[sum(p)/3 for p in plaster.getdata()];mean=sum(levels)/len(levels);tile.putdata([(*(min(255,round(tone[c]*(.88+.12*v/mean)))for c in range(3)),255)for v in levels]);tile.save(OUT/f'{serial}-stone.png')
  for yy in range(h):
   for xx in range(w):
    p=original.getpixel((xx,yy));owner='post'if post_mask.getpixel((xx,yy))else'leaf'if leaf_mask.getpixel((xx,yy))else'ground';leaf.putpixel((xx,yy),(*p[:3],p[3]if owner=='leaf'else 0));post.putpixel((xx,yy),(*p[:3],p[3]if owner=='post'else 0));ground.putpixel((xx,yy),(*p[:3],p[3]if owner=='ground'else 0));rgb=wood.getpixel((xx%128,yy%128));back.putpixel((xx,yy),(*rgb[:3],255 if leaf_mask.getpixel((xx,yy))else 0))
  for name,image in[('leaf-front',leaf),('post-front',post),('ground',ground),('leaf-back',back)]:image.save(OUT/f'{serial}-{name}.png')
  a,b=spec['leaf_bottom'];slope=(b[1]-a[1])/(b[0]-a[0]);offset=a[1]+g['origin'][1]-slope*(a[0]+g['origin'][0]);rows[str(serial)]=dict(graphic_id=serial,native_rgba_sha256=g['rgba_sha256'],origin=g['origin'],footprint=g['footprint'],size=[w,h],leaf_polygon=leaf_polygon,arch=arch,leaf_plane_slope=slope,leaf_plane_offset=offset,leaf_thickness=.22,post_height_pixels=104,post_body_top_pixels=97,post_base_pixels=8,**spec,derived_rgba_sha256={p.name:sha(Image.open(p).convert('RGBA').tobytes())for p in OUT.glob(f'{serial}-*.png')})
 data=dict(schema=1,scope='PRIVATE two original gate leaves/posts; pure scenery meshes only. No collider, door, route, map or NPC behavior.',source_catalogs=pins,reused_grain=dict(path=str(master_path.relative_to(ROOT)),file_sha256=sha(master_path.read_bytes())),reused_plaster=dict(path=str(plaster_path.relative_to(ROOT)),file_sha256=sha(plaster_path.read_bytes())),graphics=rows,inferences=['Native front RGB/alpha is partitioned exactly across leaf/post/ground; original file remains intact.','Observed arched outline, opening orientation and post footprints determine solid parts. Unseen leaf thickness, post rear uses existing fine plaster grain with the native pale-mortar palette, repeated brick rhythm and back hinges inferred from the observed design.','The original signed image origins and2x1footprints stay unchanged; no new door or collider is authored.'])
 (OUT/'data.json').write_text(json.dumps(data,indent=2)+'\n');print('IL_GATE_PARTS',len(rows))
if __name__=='__main__':prepare()
