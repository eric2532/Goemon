"""Bake six source-derived cliff volume candidates; default output is private review only."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import struct
import sys
import tempfile
import zlib

import numpy as np
from PIL import Image, ImageDraw

from east_cliff_geometry import raster
from prepare_east_cliff_boulder_study import ROOT, study
from prepare_east_cliff_fringe_study import fringe_geometry

FULL=[12536,12537,12538,12542,12543,12546]
REVIEW=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Volume Candidates'
RUNTIME=ROOT/'assets/maps/falan/east_field_cliffs/relief'
INPUTS=['tools/east_cliff_geometry.py','tools/prepare_east_stone_profiles.py','tools/prepare_east_cliff_boulder_study.py','tools/prepare_east_cliff_fringe_study.py','tools/prepare_east_cliff_volumes.py','tools/asset_pipeline/glb.py','scripts/forest/forest_east_cliff_volume.gdshader','assets/maps/original_crossgate/cliff-profiles.json']


def encode(points,normals,palette,uv,foot,size):
 center=np.array([(foot[0]-1)*1.5,0.,-(foot[1]-1)*1.5]);rgb=np.clip(palette/255.,0,1)
 rgb=np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4)
 colors=np.concatenate([rgb,np.ones((*rgb.shape[:2],1))],axis=2)
 values=np.concatenate([points-center,normals,colors,uv/np.asarray(size)],axis=2).reshape(-1,12)
 rows=[];indices=[];lookup={}
 for row in values:
  key=tuple(row.round(6))
  if key not in lookup:lookup[key]=len(rows);rows.append(row)
  indices.append(lookup[key])
 vertices=np.asarray(rows,dtype='<f4');ids=np.asarray(indices,dtype='<u4');raw=vertices.tobytes()+ids.tobytes()
 blob=b'ECR4'+struct.pack('<III',len(vertices),len(ids),len(raw))+zlib.compress(raw,9)
 return blob,{'vertices':len(vertices),'indices':len(ids),'triangles':len(points),'attribute_stride_bytes':48,'resident_cpu_attribute_index_bytes':len(raw),'gpu_upload_attribute_index_bytes':len(raw),'compressed_geometry_bytes':len(blob),'geometry_sha256':hashlib.sha256(blob).hexdigest(),'memory_limit':'Exact source Float32/UInt32 payload, separate from driver packing/alignment/object overhead. Actual world renderer memory/frame samples remain required.'}


def build_family(serial,out,previews):
 face,g,ph,points,normals,palette,uv,description=study(serial);eye=np.array([-1.,16*ph,1.]);eye/=np.linalg.norm(eye)
 before=raster(points,normals,uv,face,eye,g,ph,palette=palette,source=True,unlit=True)
 combined,ns,colors,texture_uv,fringes,missing,valid=fringe_geometry(face,g,ph,points,normals,palette,uv,np.asarray(before)[::2,::2])
 registered=raster(combined,ns,texture_uv,face,eye,g,ph,palette=colors,source=True,unlit=True)
 actual=np.asarray(registered)[::2,::2];original=np.asarray(face);matched=valid&(abs(actual.astype(float)-original[:,:,:3]).max(2)<=1)
 assert int(matched.sum())==int(valid.sum()),f'Unregistered native art: {serial}: {int(valid.sum()-matched.sum())}'
 blob,cost=encode(combined,ns,colors,texture_uv,g['footprint'],face.size)
 image=io.BytesIO();face.save(image,format='PNG',optimize=True);paint=image.getvalue()
 out.mkdir(parents=True,exist_ok=True);(out/f'{serial}.bin').write_bytes(blob);(out/f'{serial}.png').write_bytes(paint)
 base_count=description['core_triangles'];stone_count=description['closed_reused_boulders'];per=description['reused_master']['triangles']
 components=[{'kind':'retained_closed_core','first_triangle':0,'triangles':base_count}]
 for i,placement in enumerate(description['placements']):components.append({'kind':'closed_source_stone'if placement['source_front']else'closed_inferred_stone','first_triangle':base_count+i*per,'triangles':per,'source_patch':placement['source_patch']})
 low,high=combined.reshape(-1,3).min(0),combined.reshape(-1,3).max(0)
 profile=description['source_contour']
 record={'graphic':serial,'format':'ECR4','status':'private_candidate_not_published_or_visually_accepted','native_rgba_sha256':description.get('source_native_rgba_sha256'),'source_origin':g['origin'],'source_footprint':g['footprint'],'pixel_height':ph,'native_height':profile['fitted_source_bounds'][1][1],'source_contour':profile,'source_profile_sha256':hashlib.sha256((ROOT/'assets/maps/original_crossgate/cliff-profiles.json').read_bytes()).hexdigest(),'source_rgb_preserved':True,'paint_png_sha256':hashlib.sha256(paint).hexdigest(),'geometry_bounds':[low.tolist(),high.tolist()],'closed_components':components,'closed_boulders':stone_count,'reused_master':description['reused_master'],'measured_native_patches':description['measured_native_patches'],'boulder_placements':description['placements'],'hidden_patch_continuation':description['source_patch_tile'],'fringe':{'first_triangle':len(points),'triangles':len(combined)-len(points),'observed_pixels_restored':int(missing.sum()),'components':fringes,'depth_rule':'Original ground-adjacent alpha at existing source datum; other alpha at adjacent measured surface depth. Thin-art backside/separation is inferred; no terrain, collision or nav mutation.'},'native_registration':{'observed_pixels':int(valid.sum()),'exact_pixels':int(matched.sum()),'fraction':1.,'lighting':'Unlit UV/RGB registration proof, separate from shaded material review and actual gameplay.'},'cost':cost,'inference':description['inferred'],'material_contract':'Continuous projected original-alpha color around native camera direction; independent whole-stone/moss palette and fixed-scale reused grain at other angles. No per-lobe paint gaps, UV edge clamping, whole-front sprite wrapping, geometry clipping or blank backs.'}
 record['core_reconstruction']=description['core_reconstruction'];record['moss_gap_continuation']=description.get('moss_gap_continuation')
 # Preserve the untouched original separately from the cleaned runtime alpha.
 sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'));import cg_library as lib
 row=lib.serial_index()[serial];native=lib.image_from_record(row['pack'],row['row']).convert('RGBA');record['native_rgba_sha256']=hashlib.sha256(native.tobytes()).hexdigest();assert native.convert('RGB').tobytes()==face.convert('RGB').tobytes()
 if previews:
  folder=out/'Images';folder.mkdir(exist_ok=True);native.save(folder/f'{serial}-native-untouched.png');registered.save(folder/f'{serial}-source-registration.png')
  raster(combined,ns,texture_uv,face,eye,g,ph,palette=colors).save(folder/f'{serial}-source-shaded.png')
  raster(combined,ns,np.full_like(texture_uv,-1.),face,[.5,.3705,1.],g,ph,palette=colors).save(folder/f'{serial}-rear-shaded.png')
  (folder/f'{serial}-study.json').write_text(json.dumps(description,ensure_ascii=False,indent=2)+'\n')
  np.savez_compressed(folder/f'{serial}-geometry.npz',triangles=combined,normals=ns,palette=colors,uv=texture_uv)
 print('EAST_CLIFF_VOLUME_CANDIDATE',serial,'stones',stone_count,'triangles',len(combined),'native pixels',int(matched.sum()),flush=True)
 return record


def contact_sheets(out,records):
 for kind in ['source','rear']:
  sheet=Image.new('RGB',(1800,1400),'#262f37');draw=ImageDraw.Draw(sheet)
  for i,serial in enumerate(FULL):
   x=(i%3)*600;y=(i//3)*700;row=records[str(serial)];draw.text((x+16,y+12),f"{serial} / {row['closed_boulders']} complete stones / {row['cost']['triangles']} triangles",fill='white')
   if kind=='source':
    for offset,label,name in [(0,'Untouched native','native-untouched'),(300,'Native-view registration','source-registration')]:
     image=Image.open(out/f'Images/{serial}-{name}.png').convert('RGBA')
     if name=='native-untouched':image=image.resize((image.width*2,image.height*2),Image.Resampling.NEAREST)
     image.thumbnail((285,620),Image.Resampling.LANCZOS);draw.text((x+offset+8,y+35),label,fill='white');sheet.paste(image,(x+offset+(300-image.width)//2,y+62),image)
   else:
    image=Image.open(out/f'Images/{serial}-rear-shaded.png');image.thumbnail((590,630),Image.Resampling.LANCZOS);sheet.paste(image,(x+(600-image.width)//2,y+45))
  sheet.save(out/f'{kind}-contact-sheet.png')


def prepare(out,previews=True):
 records={str(serial):build_family(serial,out,previews)for serial in FULL}
 data={'schema':4,'scope':'Private source-derived East/North Coast/Alyut cliff volume candidates. Source map/layout/foot cells, terrain, nav, quest gates, doors and portals are unchanged. Original3D is not claimed; hidden depths/upper occlusion/fringe placement are labeled reconstruction.','source_profile':'assets/maps/original_crossgate/cliff-profiles.json','source_inputs':{path:hashlib.sha256((ROOT/path).read_bytes()).hexdigest()for path in INPUTS},'graphics':records}
 (out/'data.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 if previews:contact_sheets(out,records)
 return data


def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');parser.add_argument('--publish',action='store_true');parser.add_argument('--no-previews',action='store_true');args=parser.parse_args();target=RUNTIME if args.publish else REVIEW
 if args.check:
  with tempfile.TemporaryDirectory(prefix='east-cliff-volume-check-',dir='/private/tmp')as temporary:
   folder=Path(temporary);prepare(folder,False);names=['data.json']+[f'{s}.{ext}'for s in FULL for ext in ['bin','png']];stale=[name for name in names if not(target/name).exists()or(target/name).read_bytes()!=(folder/name).read_bytes()];assert not stale,'Stale cliff volume candidate: '+','.join(stale)
  print('EAST_CLIFF_VOLUME_CHECK PASS')
 elif args.publish:
  with tempfile.TemporaryDirectory(prefix='east-cliff-volume-publish-',dir='/private/tmp')as temporary:
   folder=Path(temporary);prepare(folder,False);target.mkdir(parents=True,exist_ok=True)
   for path in folder.iterdir():pending=target/(path.name+'.tmp');pending.write_bytes(path.read_bytes());os.replace(pending,target/path.name)
  print('EAST_CLIFF_VOLUMES published six source-derived families')
 else:prepare(target,not args.no_previews);print('EAST_CLIFF_VOLUMES private candidates only; inspect both contact sheets before runtime publication')


if __name__=='__main__':main()
