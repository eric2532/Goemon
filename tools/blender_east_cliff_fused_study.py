"""Build ONE new private editable study; never overwrite an existing Blender master."""
import bpy
import hashlib
import json
import sys
from pathlib import Path

folder=Path(sys.argv[sys.argv.index('--')+1]);master=folder/'study.blend'
assert not master.exists(),'Existing private editable master is protected; export edits instead of regenerating over them'
source_path=folder/'source-geometry.json';source=json.loads(source_path.read_text())
parent=source.get('parent_master','')
if parent:
    assert hashlib.sha256(Path(parent).read_bytes()).hexdigest()==source['parent_master_sha256'],'Private editable input changed; preserve/review its edits before refinement'
    bpy.ops.wm.open_mainfile(filepath=parent)
    objects=[bpy.data.objects['Source12538FusedAngularStudy']]
    bpy.ops.object.select_all(action='DESELECT')
else:
    bpy.ops.wm.read_factory_settings(use_empty=True);objects=[]
for part in source['parts']:
    vertices=[];faces=[];lookup={}
    for triangle in part['triangles']:
        ids=[]
        for p in triangle:
            point=(p[0],-p[2],p[1]);key=tuple(round(value,7)for value in point)
            if key not in lookup:lookup[key]=len(vertices);vertices.append(point)
            ids.append(lookup[key])
        faces.append((ids[0],ids[2],ids[1]))
    mesh=bpy.data.meshes.new(part['name']);mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new(part['name'],mesh);bpy.context.collection.objects.link(obj);objects.append(obj)
for obj in objects:obj.select_set(True)
bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();obj=bpy.context.object;obj.name='Source12538FusedAngularStudy'
modifier=obj.modifiers.new('FuseSourceIntersections','REMESH');modifier.mode='VOXEL';modifier.voxel_size=float(source['voxel_size_m']);modifier.use_smooth_shade=True
bpy.ops.object.modifier_apply(modifier=modifier.name)
modifier=obj.modifiers.new('RemoveVoxelStairSteps','SMOOTH');modifier.factor=.35;modifier.iterations=2;bpy.ops.object.modifier_apply(modifier=modifier.name)
for polygon in obj.data.polygons:polygon.use_smooth=True
if parent:
    # These tiny closed crumbs are below one source pixel and arise from voxel
    # pole cleanup; remove only sub-voxel generated islands, never a rock part.
    import bmesh
    bm=bmesh.new();bm.from_mesh(obj.data);remaining=set(bm.verts);tiny=[];removed=[]
    while remaining:
        queue=[remaining.pop()]
        for vertex in queue:
            for edge in vertex.link_edges:
                other=edge.other_vert(vertex)
                if other in remaining:remaining.remove(other);queue.append(other)
        span=max(max(v.co[axis]for v in queue)-min(v.co[axis]for v in queue)for axis in range(3))
        if len(queue)<=8 and span<float(source['voxel_size_m'])*.5:tiny.extend(queue);removed.append({'vertices':len(queue),'span_m':span})
    if tiny:bmesh.ops.delete(bm,geom=tiny,context='VERTS');bm.to_mesh(obj.data);obj.data.update()
    bm.free();obj['subvoxel_artifact_cleanup']=json.dumps(removed)
obj['source_geometry_sha256']=hashlib.sha256(source_path.read_bytes()).hexdigest();obj['source_master_paths']=json.dumps(source['source_master_sha256']);obj['inference']=source['inference'];obj['study_only_not_runtime']=True
bpy.ops.wm.save_as_mainfile(filepath=str(master))
mesh=obj.data;mesh.calc_loop_triangles();vertices=[(v.co.x,v.co.z,-v.co.y)for v in mesh.vertices];faces=[list(face.vertices)for face in mesh.loop_triangles]
adjacency=[set()for _ in vertices];edges={}
for face in faces:
    for a,b in zip(face,face[1:]+face[:1]):adjacency[a].add(b);adjacency[b].add(a);key=tuple(sorted((a,b)));edges[key]=edges.get(key,0)+1
remaining=set(range(len(vertices)));components=0
while remaining:
    components+=1;queue=[remaining.pop()]
    for vertex in queue:
        for neighbour in adjacency[vertex]:
            if neighbour in remaining:remaining.remove(neighbour);queue.append(neighbour)
report={'vertices':vertices,'faces':faces,'connected_components':components,'nonmanifold_edges':sum(count!=2 for count in edges.values()),'editable_master':str(master),'blender_version':bpy.app.version_string,'voxel_size_m':source['voxel_size_m'],'smooth_voxel_cleanup_iterations':2,'subvoxel_artifact_cleanup':json.loads(obj.get('subvoxel_artifact_cleanup','[]')),'scope':'Private new connected surface from source-fitted matrix and original whole angular crag/ledge input meshes. Original files are read-only; no decimation/LOD, runtime export, collision/nav or map changes.'}
(folder/'fused-geometry.json').write_text(json.dumps(report,separators=(',',':')));print('EAST_FUSED_BLENDER',len(vertices),len(faces),components,report['nonmanifold_edges'])
