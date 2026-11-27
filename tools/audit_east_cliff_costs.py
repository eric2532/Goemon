"""Source placement census and exact prepared cliff buffer payloads; no smoothness claim."""
import collections
import hashlib
import json
import struct
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
ASSET=ROOT/'assets/maps/falan/east_field_cliffs'
OUT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/cliff-cost-census.json'


def main():
 data=json.loads((ASSET/'data.json').read_text());relief=json.loads((ASSET/'relief/data.json').read_text())
 source=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Version Expansion Source Audit/map__00100_field1'
 raw=source.read_bytes();assert hashlib.sha256(raw).hexdigest()==data['field']['source_sha256']
 width,height=struct.unpack_from('>HH',raw,40);count=width*height
 objects=struct.unpack_from(f'>{count}H',raw,44+count*2);whole=collections.Counter();areas={key:collections.Counter()for key in ['east_gate','north_coast','alyut']}
 x0,y0,w,h=data['field']['owned_window']
 for i,serial in enumerate(objects):
  if serial not in range(12536,12548):continue
  whole[serial]+=1;x,y=i%width,i//width
  if not(x0<=x<x0+w and y0<=y<y0+h):continue
  area='north_coast'if y<100 and x>510 or x>670 and y<210 else'east_gate'
  areas[area][serial]+=1
 for row in data['alyut']['placements']:areas['alyut'][int(row['graphic'])]+=1
 records={}
 for serial in range(12536,12548):
  row={'graphic':serial,'all_source100_placements':whole[serial],'owned_source_placements':{area:counts[serial]for area,counts in areas.items()}}
  if str(serial)in relief['graphics']:
   meta=relief['graphics'][str(serial)];binary=(ASSET/f'relief/{serial}.bin').read_bytes();ns,np_,ni,npi,rawlen=struct.unpack_from('<IIIII',binary,4)
   payload=ns*40+np_*48+ni*4
   row.update(prepared_triangles=ni//3,source_painted_triangles=npi//3,compressed_binary_bytes=len(binary),decoded_preparation_bytes=rawlen,
    resident_cpu_attribute_index_payload_bytes=payload,gpu_upload_attribute_index_payload_bytes=payload,
    payload_contract='Exact prepared Float32 position/normal/color/UV and UInt32 rendered index bytes, with one material per face. Godot/driver alignment, packed internal formats and object overhead are not attributed by this estimate; actual global GPU memory is recorded separately by the visible fixture.',
    front_png_bytes=(ASSET/f'relief/{serial}.png').stat().st_size)
  else:row['mesh']='Existing sparse crest/native low-resolution family spur; exact runtime arrays are counted in the visible fixture.'
  records[str(serial)]=row
 report={'source_map100_sha256':data['field']['source_sha256'],'relief_data_sha256':hashlib.sha256((ASSET/'relief/data.json').read_bytes()).hexdigest(),
  'scope':'Currently published review candidate only, not visual acceptance or performance clearance. Static source counts do not establish visible instances, GPU cost or smooth gameplay.',
  'source100_all_twelve_family_total':sum(whole.values()),'owned_source_totals':{area:sum(counts.values())for area,counts in areas.items()},'graphics':records,
  'native_multimesh_transform_payload_per_instance_bytes':48,'next_measurement':'Actual mounted chunk/instance/frustum candidate counts, wall frame/engine/render CPU/GPU samples, global draw calls/primitives/video-buffer memory at the normal/second/source-facing gameplay cameras. Frustum candidates remain separate from actual GPU occlusion.'}
 OUT.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print('EAST_CLIFF_COST_CENSUS',report['source100_all_twelve_family_total'],report['owned_source_totals'])


if __name__=='__main__':main()
