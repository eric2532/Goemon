#!/usr/bin/env python3
"""Stage the optional terrain-diagonal contract without editing shared sources."""
from __future__ import annotations

import difflib
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Low Source Candidate/Host/Original100 Candidate/Diagonal Contract'


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def replace(text: str, old: str, new: str, count: int = 1) -> str:
    assert text.count(old) == count, (old[:100], text.count(old), count)
    return text.replace(old, new)


def candidate(path: str, text: str) -> str:
    if path.endswith('terrain.h'):
        return replace(text, 'std::vector<uint8_t> covered;', 'std::vector<uint8_t> covered,diagonal_flips;')
    if path.endswith('crowd_binding.cpp'):
        old = '            data.heights=vector<float>(dict,"heights",F32);'
        text = replace(text, old, '''            auto flips=get(dict,"diagonal_flips");
            // A malformed optional mask must fail Terrain validation, not become the default split.
            data.diagonal_flips=flips&&variant_type(flips)!=NIL&&variant_type(flips)!=BYTES?std::vector<uint8_t>{2}:vector<uint8_t>(dict,"diagonal_flips",BYTES);
''' + old)
        return text
    if path.endswith('air.cpp'):
        return replace(text, 'tri(a,c,b);tri(b,c,d);', 'if(!data_.diagonal_flips.empty()&&data_.diagonal_flips[i]){tri(a,d,b);tri(a,c,d);}else{tri(a,c,b);tri(b,c,d);}')
    if path.endswith('forest_terrain_corridors.gd'):
        text = replace(text, 'terrain.covered.duplicate(),origin,bounds,rect_bounds', 'terrain.covered.duplicate(),terrain.diagonal_mask_valid,terrain.diagonal_flips.duplicate(),origin,bounds,rect_bounds')
        return replace(text, 'if native_field and terrain.pieces.is_empty() and ClassDB.class_exists("GoemonTerrainMath"):', 'if native_field and terrain.diagonal_mask_valid and terrain.diagonal_flips.is_empty() and terrain.pieces.is_empty() and ClassDB.class_exists("GoemonTerrainMath"):')
    if path.endswith('army_runtime.gd'):
        old = '  data.width=terrain.width;data.spacing=terrain.spacing;data.heights=terrain.heights;data.covered=terrain.covered'
        return replace(text, old, old + '''
  if terrain.has_method("native_diagonal_flips"):
   var flips:PackedByteArray=terrain.native_diagonal_flips()
   if not flips.is_empty():data.diagonal_flips=flips''')
    if path.endswith('terrain.cpp'):
        text = replace(text, 'same(data.covered,data_.covered)&&', 'same(data.covered,data_.covered)&&same(data.diagonal_flips,data_.diagonal_flips)&&')
        text = replace(text, 'same(data_.covered,shared_air->data_.covered)&&', 'same(data_.covered,shared_air->data_.covered)&&same(data_.diagonal_flips,shared_air->data_.diagonal_flips)&&')
        old = '    minimum_=data_.origin;'
        text = replace(text, old, '''    if(!data_.diagonal_flips.empty()){
        if(data_.width<2||data_.diagonal_flips.size()!=size_t(data_.width)*data_.width)ready_=false;
        else for(size_t i=0;i<data_.diagonal_flips.size();++i)
            if(data_.diagonal_flips[i]>1||(data_.diagonal_flips[i]&&(i%data_.width==size_t(data_.width-1)||i/data_.width==size_t(data_.width-1)))){ready_=false;break;}
    }
''' + old)
        old = '            result=u+v<=1?h00+(h10-h00)*u+(h01-h00)*v:h11+(h01-h11)*(1-u)+(h10-h11)*(1-v);'
        text = replace(text, old, '''            if(!data_.diagonal_flips.empty()&&data_.diagonal_flips[at])
                result=u>=v?h00+(h10-h00)*u+(h11-h10)*v:h00+(h11-h01)*u+(h01-h00)*v;
            else result=u+v<=1?h00+(h10-h00)*u+(h01-h00)*v:h11+(h01-h11)*(1-u)+(h10-h11)*(1-v);''')
        text = replace(text, 'for(int sample=0;sample<9;++sample)for(int axis=0;axis<3;++axis){', 'for(int sample=0;sample<9;++sample)for(int axis=0;axis<(data_.diagonal_flips.empty()?3:4);++axis){')
        text = replace(text, 'return axis==0?x:axis==1?z:x+z;', 'return axis==0?x:axis==1?z:axis==2?x+z:x-z;')
        old = '                if(sample==0){if(!clear(p,radius,layer,check_objects))return false;}'
        text = replace(text, old, '''                if(axis>=2&&!data_.diagonal_flips.empty()){
                    float px=(p.x+offset.x-data_.origin.x)/data_.spacing,pz=(p.z+offset.z-data_.origin.z)/data_.spacing;
                    int ix=int(std::floor(px)),iz=int(std::floor(pz));
                    if(ix<0||iz<0||ix>=data_.width-1||iz>=data_.width-1)continue;
                    bool flipped=data_.diagonal_flips[size_t(iz)*data_.width+ix]!=0;
                    if(flipped!=(axis==3))continue;
                }
''' + old)
        return text
    assert path.endswith('forest_kai_terrain.gd'), path
    text = replace(text, 'var covered=PackedByteArray()', 'var covered=PackedByteArray()\nvar diagonal_flips=PackedByteArray()\nvar diagonal_mask_valid=true')
    text = replace(text, ' super.configure(source)\n var surface=terrain_field()', ' super.configure(source)\n diagonal_flips=PackedByteArray();diagonal_mask_valid=true\n var surface=terrain_field()')
    old = ' width=surface.get_meta("width");spacing=surface.get_meta("spacing");heights=surface.get_meta("heights");covered=surface.get_meta("covered");bridges=surface.get_meta("bridges")'
    text = replace(text, old, old + '''
 var flips=surface.get_meta("diagonal_flips",PackedByteArray())
 if flips==null:flips=PackedByteArray()
 if not flips is PackedByteArray:
  diagonal_mask_valid=false;width=0;push_error("Invalid terrain diagonal mask type");return
 diagonal_flips=flips
 if not diagonal_flips.is_empty():
  if width<2 or diagonal_flips.size()!=width*width:
   diagonal_mask_valid=false;width=0;push_error("Incomplete terrain diagonal mask");return
  for i in diagonal_flips.size():
   if diagonal_flips[i]>1 or (diagonal_flips[i]!=0 and (i%width==width-1 or i/width==width-1)):
    diagonal_mask_valid=false;width=0;push_error("Invalid terrain diagonal mask");return''')
    text = replace(text, 'func contains(x:float,z:float)->bool:\n', 'func contains(x:float,z:float)->bool:\n if not diagonal_mask_valid:return false\n')
    text = replace(text, 'func height(x:float,z:float)->float:\n', 'func height(x:float,z:float)->float:\n if not diagonal_mask_valid:return NAN\n')
    text = replace(text, 'func _covered_height(x:float,z:float)->float:\n', 'func _covered_height(x:float,z:float)->float:\n if not diagonal_mask_valid:return NAN\n')
    text = replace(text, 'func _building_ground_result(first:Vector2i,last:Vector2i)->Dictionary:\n', 'func _building_ground_result(first:Vector2i,last:Vector2i)->Dictionary:\n if not diagonal_mask_valid:return {"error":"Needs solid ground under the whole building"}\n')
    text = replace(text, 'func bridge_at(x:float,z:float)->bool:', '''func native_diagonal_flips()->PackedByteArray:
 return diagonal_flips if diagonal_mask_valid else PackedByteArray([2])
func bridge_at(x:float,z:float)->bool:''')
    old = ' var result=h00+(h10-h00)*u+(h01-h00)*v if u+v<=1 else h11+(h01-h11)*(1-u)+(h10-h11)*(1-v)'
    text = replace(text, old, ''' var result:float
 if not diagonal_flips.is_empty() and diagonal_flips[at]!=0:result=h00+(h10-h00)*u+(h11-h10)*v if u>=v else h00+(h11-h01)*u+(h01-h00)*v
 else:result=h00+(h10-h00)*u+(h01-h00)*v if u+v<=1 else h11+(h01-h11)*(1-u)+(h10-h11)*(1-v)''', 2)
    old = '''   if check_steepness and u0+v0<1. and Vector2(h10-h00,h01-h00).length_squared()>rise_limit_squared:return {"error":"Keep the building clear of steep cliff faces"}
   if check_steepness and u1+v1>1. and Vector2(h11-h01,h11-h10).length_squared()>rise_limit_squared:return {"error":"Keep the building clear of steep cliff faces"}'''
    text = replace(text, old, '''   var flipped=not diagonal_flips.is_empty() and diagonal_flips[index]!=0
   if flipped:
    if check_steepness and u1>v0 and Vector2(h10-h00,h11-h10).length_squared()>rise_limit_squared:return {"error":"Keep the building clear of steep cliff faces"}
    if check_steepness and u0<v1 and Vector2(h11-h01,h01-h00).length_squared()>rise_limit_squared:return {"error":"Keep the building clear of steep cliff faces"}
   else:
    if check_steepness and u0+v0<1. and Vector2(h10-h00,h01-h00).length_squared()>rise_limit_squared:return {"error":"Keep the building clear of steep cliff faces"}
    if check_steepness and u1+v1>1. and Vector2(h11-h01,h11-h10).length_squared()>rise_limit_squared:return {"error":"Keep the building clear of steep cliff faces"}''')
    old = '''   for u in [u0,u1]:
    if 1.-u>=v0 and 1.-u<=v1:samples.append(Vector2(u,1.-u))
   for v in [v0,v1]:
    if 1.-v>=u0 and 1.-v<=u1:samples.append(Vector2(1.-v,v))
   for p in samples:
    var h=h00+(h10-h00)*p.x+(h01-h00)*p.y if p.x+p.y<=1. else h11+(h01-h11)*(1.-p.x)+(h10-h11)*(1.-p.y)'''
    text = replace(text, old, '''   if flipped:
    for u in [u0,u1]:
     if u>=v0 and u<=v1:samples.append(Vector2(u,u))
    for v in [v0,v1]:
     if v>=u0 and v<=u1:samples.append(Vector2(v,v))
   else:
    for u in [u0,u1]:
     if 1.-u>=v0 and 1.-u<=v1:samples.append(Vector2(u,1.-u))
    for v in [v0,v1]:
     if 1.-v>=u0 and 1.-v<=u1:samples.append(Vector2(1.-v,v))
   for p in samples:
    var h:float
    if flipped:h=h00+(h10-h00)*p.x+(h11-h10)*p.y if p.x>=p.y else h00+(h11-h01)*p.x+(h01-h00)*p.y
    else:h=h00+(h10-h00)*p.x+(h01-h00)*p.y if p.x+p.y<=1. else h11+(h01-h11)*(1.-p.x)+(h10-h11)*(1.-p.y)''')
    return text


def main():
    paths = ['native/terrain_math/crowd/terrain.h', 'native/terrain_math/crowd/terrain.cpp', 'native/terrain_math/crowd/air.cpp', 'native/terrain_math/crowd_binding.cpp', 'scripts/forest/forest_kai_terrain.gd', 'scripts/forest/forest_terrain_corridors.gd', 'scripts/forest/crowd/army_runtime.gd']
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / '.gdignore').write_text('')
    changes, pins = [], {}
    for path in paths:
        before = (ROOT / path).read_text()
        after = candidate(path, before)
        for name, text in [('before', before), ('candidate', after)]:
            target = OUT / name / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text)
        pins[path] = {'before_sha256': sha(before.encode()), 'candidate_sha256': sha(after.encode())}
        changes.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile='a/' + path, tofile='b/' + path))
    for path in ['native/terrain_math/crowd/math_types.h']:
        for name in ['before', 'candidate']:
            target = OUT / name / path
            target.write_bytes((ROOT / path).read_bytes())
        pins[path] = {'unchanged_dependency_sha256': sha((ROOT / path).read_bytes())}
    patch = ''.join(changes)
    (OUT / 'diagonal-flips.patch').write_text(patch)
    corridors = (OUT / 'candidate/scripts/forest/forest_terrain_corridors.gd').read_text()
    corridors = corridors.replace('res://scripts/forest/forest_kai_terrain.gd', 'res://' + str((OUT / 'candidate/scripts/forest/forest_kai_terrain.gd').relative_to(ROOT)))
    (OUT / 'corridor-probe.gd').write_text(corridors)
    record = {'status': 'isolated candidate only; no shared source publication', 'api_key': 'diagonal_flips', 'mask': 'empty or width*width bytes,0/1,unused lastrow/col0', 'sources': pins, 'patch_sha256': sha(patch.encode()), 'preparer_sha256': sha(Path(__file__).read_bytes())}
    (OUT / 'source-contract.json').write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps({'patch_sha256': record['patch_sha256'], 'changed_files': len(paths), 'output': str(OUT)}))


if __name__ == '__main__':
    main()
