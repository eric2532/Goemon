"""Prepare an isolated FortParts CPU-array candidate; never publish shared code."""
import difflib
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Bank Caps/Fort CPU Candidate'
SOURCE = ROOT/'scripts/forest/forest_falan_fort_parts.gd'


def once(text, old, new):
    assert text.count(old) == 1, ('Shared FortParts changed; review before adapting', old[:90])
    return text.replace(old, new, 1)


def main():
    contract = OUT/'source-contract.json'
    frozen = OUT/'fort_parts_before.gd'
    if contract.exists() and frozen.exists():
        recorded = json.loads(contract.read_text())
        assert hashlib.sha256(frozen.read_bytes()).hexdigest() == recorded['shared_sha256'], 'Frozen original differs from the proved master'
        assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() in [recorded['shared_sha256'], recorded['candidate_sha256']], 'Live FortParts changed; review the new source before regenerating'
        old = frozen.read_text()
    else:
        old = SOURCE.read_text()
    new = old
    helpers = '''
# Setup-only resource-owned arrays; no geometry/material or per-frame change.
static var cpu_stats={"retained":0,"readback_fallback":0}

static func cpu_committed(arrays:Array)->Array:
 var result=Paint.committed_arrays(arrays)
 var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var input_tangents=arrays[Mesh.ARRAY_TANGENT];var tangents=PackedFloat32Array()
 for index in normals.size():
  var n:Vector3=normals[index];var sign_=1.
  var tangent:Vector3
  if input_tangents is PackedFloat32Array and not input_tangents.is_empty():
   tangent=Vector3(input_tangents[index*4],input_tangents[index*4+1],input_tangents[index*4+2]);sign_=input_tangents[index*4+3]
  else:tangent=Vector3(n.z,-n.x,n.y).cross(n.normalized()).normalized()
  var encoded=tangent.octahedron_encode();encoded.y=maxf(encoded.y,1./32767.);encoded.y=encoded.y*.5+.5
  if sign_<0:encoded.y=1.-encoded.y
  var packed=encoded*65535.;var x=clampi(int(packed.x),0,65535);var y=clampi(int(packed.y),0,65535)
  if x==0 and y==65535:x=65535
  var decoded=Vector2(x/65535.,y/65535.);decoded.y=decoded.y*2.-1.;sign_=1. if decoded.y>=0 else -1.;decoded.y=absf(decoded.y)
  var restored=Vector3.octahedron_decode(decoded);tangents.append_array(PackedFloat32Array([restored.x,restored.y,restored.z,sign_]))
 result[Mesh.ARRAY_TANGENT]=tangents
 if result[Mesh.ARRAY_COLOR] is PackedColorArray:
  var colors:PackedColorArray=result[Mesh.ARRAY_COLOR]
  for index in colors.size():
   var color=colors[index]
   for channel in 4:color[channel]=clampi(int(color[channel]*255.),0,255)/255.
   colors[index]=color
  result[Mesh.ARRAY_COLOR]=colors
 return result

static func cpu_commit(tool:SurfaceTool)->Mesh:
 var arrays=cpu_committed(tool.commit_to_arrays());var result=tool.commit()
 result.set_meta("source_surface_arrays",arrays)
 return result

static func cpu_arrays(mesh:Mesh,part:int)->Array:
 if mesh.has_meta("source_surface_arrays_all"):
  cpu_stats.retained+=1;return mesh.get_meta("source_surface_arrays_all")[part]
 if part==0 and mesh.has_meta("source_surface_arrays"):
  cpu_stats.retained+=1;return mesh.get_meta("source_surface_arrays")
 cpu_stats.readback_fallback+=1;var arrays=mesh.surface_get_arrays(part)
 var cached:Array=mesh.get_meta("source_surface_arrays_all",[])
 if cached.is_empty():cached.resize(mesh.get_surface_count())
 cached[part]=arrays
 # A partially cached multi-surface resource must retain its remaining surfaces.
 for slot in mesh.get_surface_count():
  if cached[slot]==null:cached[slot]=mesh.surface_get_arrays(slot);cpu_stats.readback_fallback+=1
 mesh.set_meta("source_surface_arrays_all",cached);mesh.set_meta("source_surface_arrays",cached[0])
 return arrays

static func cpu_append(tool:SurfaceTool,mesh:Mesh,part:int,pose:Transform3D):
 var arrays=cpu_arrays(mesh,part);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
 var tangents:PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT];var uv=arrays[Mesh.ARRAY_TEX_UV];var uv2=arrays[Mesh.ARRAY_TEX_UV2]
 var indices=arrays[Mesh.ARRAY_INDEX]
 assert(indices==null or indices.is_empty(),"Fort CPU append preserves the original unindexed raw input contract")
 for index in indices if indices is PackedInt32Array and not indices.is_empty() else range(vertices.size()):
  # Match SurfaceTool.append_from's existing basis transform exactly.
  tool.set_normal(pose.basis*normals[index]);tool.set_color(colors[index])
  if not tangents.is_empty():tool.set_tangent(Plane(pose.basis*Vector3(tangents[index*4],tangents[index*4+1],tangents[index*4+2]),tangents[index*4+3]))
  if uv is PackedVector2Array and not uv.is_empty():tool.set_uv(uv[index])
  if uv2 is PackedVector2Array and not uv2.is_empty():tool.set_uv2(uv2[index])
  tool.add_vertex(pose*vertices[index])
 # append_from leaves the fresh tool's tangent state unchanged for later manual vertices.
 tool.set_tangent(Plane())

static func cpu_points(mesh:Mesh)->Array[Vector3]:
 var result:Array[Vector3]=[]
 for part in mesh.get_surface_count():
  for point:Vector3 in cpu_arrays(mesh,part)[Mesh.ARRAY_VERTEX]:result.append(point)
 return result
'''
    new = once(new, 'static func merlon(narrow_stem:bool=false)->Mesh:', helpers+'\nstatic func merlon(narrow_stem:bool=false)->Mesh:')
    new = once(new, ' var result=tool.commit()\n if narrow_stem:wall_tooth=result', ' var result=cpu_commit(tool)\n if narrow_stem:wall_tooth=result')
    new = once(new, '   cap.append_from(merlon(),0,Transform3D(Basis.IDENTITY.scaled(Vector3(1.20/1.18,.85/.76,.84/1.18)),Vector3(0,.425,2.53)))\n   round_tooth=cap.commit()',
               '   cpu_append(cap,merlon(),0,Transform3D(Basis.IDENTITY.scaled(Vector3(1.20/1.18,.85/.76,.84/1.18)),Vector3(0,.425,2.53)))\n   round_tooth=cpu_commit(cap)')
    new = once(new, ' for node in root.find_children("*","MeshInstance3D",true,false):\n  var pose=node.transform;',
               ' for node in root.find_children("*","MeshInstance3D",true,false):\n  for surface_index in node.mesh.get_surface_count():cpu_arrays(node.mesh,surface_index)\n  var pose=node.transform;')
    new = once(new, '   var arrays=node.mesh.surface_get_arrays(part);var vertices:', '   var arrays=cpu_arrays(node.mesh,part);var vertices:')
    new = once(new, ' var result=tool.commit();root.free()', ' var result=cpu_commit(tool);var retained=[result.get_meta("source_surface_arrays")];root.free()')
    new = once(new, '  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,features[feature].commit().surface_get_arrays(0))',
               '  var feature_arrays=cpu_committed(features[feature].commit_to_arrays())\n  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,feature_arrays);retained.append(cpu_committed(feature_arrays))')
    new = once(new, ' result.set_meta("falan_gate_detail_planes",gate_planes)\n return result',
               ' result.set_meta("falan_gate_detail_planes",gate_planes)\n result.set_meta("source_surface_arrays_all",retained)\n return result')
    new = once(new, 'else Fit.measure(Fit.mesh_points(source),"",Basis.IDENTITY,reference)', 'else Fit.measure(cpu_points(source),"",Basis.IDENTITY,reference)')
    new = once(new, 'tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.append_from(source,part,pose)', 'tool.begin(Mesh.PRIMITIVE_TRIANGLES);cpu_append(tool,source,part,pose)')
    new = once(new, '  var arrays=tool.commit().surface_get_arrays(0)', '  var arrays=cpu_committed(tool.commit_to_arrays())')
    new = once(new, 'range(source.surface_get_arrays(part)[Mesh.ARRAY_VERTEX].size(),colors.size())', 'range(cpu_arrays(source,part)[Mesh.ARRAY_VERTEX].size(),colors.size())')
    OUT.mkdir(parents=True, exist_ok=True); (OUT/'.gdignore').touch()
    target = OUT/'fort_parts_candidate.gd'; target.write_text(new)
    (OUT/'fort-parts-cpu.patch').write_text(''.join(difflib.unified_diff(old.splitlines(True), new.splitlines(True), fromfile='a/scripts/forest/forest_falan_fort_parts.gd', tofile='b/scripts/forest/forest_falan_fort_parts.gd')))
    (OUT/'source-contract.json').write_text(json.dumps({'shared_path': str(SOURCE.relative_to(ROOT)), 'shared_sha256': hashlib.sha256(old.encode()).hexdigest(),
        'candidate_path': str(target.relative_to(ROOT)), 'candidate_sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
        'scope': 'Isolated merlon/round-tooth, raw arrays and their direct prepare consumers. Shared FortParts untouched. Primitive/imported and independent detail builders retain honestly counted fallback reads. Exact geometry, all packed channels and materials are the publication gate; rendered startup performance remains unmeasured.'}, indent=2)+'\n')
    print('Prepared isolated merlon/raw CPU-array candidate; shared FortParts unchanged.')


if __name__ == '__main__': main()
