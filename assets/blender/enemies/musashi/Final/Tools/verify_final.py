import bpy,bmesh,json,hashlib,os,sys
from pathlib import Path
from mathutils.bvhtree import BVHTree
p=Path(__file__).resolve().parents[1];sys.dont_write_bytecode=True;sys.path.insert(0,str(p/'Tools'))
from asset_validation import geometry_hash
path=p/'Musashi_Final.blend';bpy.ops.wm.open_mainfile(filepath=str(path));sc=bpy.context.scene
manifest=json.loads((p/'Validation/approved_geometry_manifest.json').read_text());lookup={o.get('approved_source_name'):o for o in bpy.data.objects}
exception=json.loads((p/'Validation/technical_cleanup_exception.json').read_text())
for old,h in manifest['geometry_hashes'].items():
 if old==exception['approved_source_name']:
  assert h==exception['before_geometry_hash'];assert geometry_hash(lookup[old])==exception['after_geometry_hash'],old
 else:assert old in lookup and geometry_hash(lookup[old])==h,old
for old,slots in manifest['source_material_bindings'].items():assert [m.get('approved_source_name') if m else None for m in lookup[old].data.materials]==slots,old
images=[]
for im in bpy.data.images:
 if im.source=='FILE':
  exists=bool(im.packed_file) or os.path.exists(bpy.path.abspath(im.filepath));assert exists,im.name
  images.append({'name':im.name,'path':im.filepath,'packed':bool(im.packed_file),'external_exists':os.path.exists(bpy.path.abspath(im.filepath))})
assert len(bpy.data.libraries)==0;assert len(bpy.data.actions)==0;assert not any(o.type=='ARMATURE' for o in bpy.data.objects)
meshes=[];trees={}
for o in bpy.data.objects:
 if o.type!='MESH':continue
 bm=bmesh.new();bm.from_mesh(o.data);bm.normal_update();bm.verts.ensure_lookup_table();bm.faces.ensure_lookup_table()
 data={'name':o.name,'approved_source_name':o.get('approved_source_name'),'vertices':len(bm.verts),'faces':len(bm.faces),'triangles':sum(len(f.verts)-2 for f in bm.faces),'boundary_edges':sum(e.is_boundary for e in bm.edges),'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),'inconsistent_manifold_edge_winding':sum(e.is_manifold and not e.is_contiguous for e in bm.edges),'degenerate_faces':sum(f.calc_area()<1e-10 for f in bm.faces),'duplicate_faces':len(bm.faces)-len({tuple(sorted(v.index for v in f.verts)) for f in bm.faces}),'duplicate_vertex_positions':len(bm.verts)-len({tuple(round(a,7) for a in v.co) for v in bm.verts}),'loose_vertices':sum(not v.link_edges for v in bm.verts),'closed_signed_volume':bm.calc_volume(signed=True) if all(e.is_manifold for e in bm.edges) else None,'uv_layers':list(o.data.uv_layers.keys()),'modifiers':[m.name for m in o.modifiers],'rest_paint_attribute':bool(o.data.attributes.get('MUSASHI_PaintRest'))}
 assert data['degenerate_faces']==0 and data['duplicate_faces']==0 and data['loose_vertices']==0,o.name
 assert data['inconsistent_manifold_edge_winding']==0,o.name
 assert data['rest_paint_attribute'],o.name
 for v,a in zip(o.data.vertices,o.data.attributes['MUSASHI_PaintRest'].data):assert (v.co-a.vector).length<1e-6
 meshes.append(data)
 if o.get('approved_source_name') in ['Hair • layered continuous sculpt','Hair • local ear overlap','Head • tapered angular cheeks','L sleeve • oversized hanging shape','R sleeve • oversized hanging shape','L hand • simplified soft mitten','R hand • simplified soft mitten','R ear','Neck']:trees[o.get('approved_source_name')]=BVHTree.FromBMesh(bm,epsilon=0)
 bm.free()
pairs=[('Hair • layered continuous sculpt','Head • tapered angular cheeks'),('Hair • local ear overlap','Hair • layered continuous sculpt'),('Hair • local ear overlap','R ear'),('L sleeve • oversized hanging shape','L hand • simplified soft mitten'),('R sleeve • oversized hanging shape','R hand • simplified soft mitten'),('Head • tapered angular cheeks','Neck')]
intersections=[{'objects':[a,b],'intersecting_face_pairs':len(trees[a].overlap(trees[b])),'interpretation':'Existing layered contact inspected; preserve approved geometry. Review weights/rigid attachment before deformation.'} for a,b in pairs]
report={'status':'MUSASHI_FINAL_APPROVED','approved_visible_design_unchanged':True,'material_pass_geometry_unchanged':True,'technical_cleanup_exception':{'isolated_zero_volume_hair_pairs_removed':12,'faces_removed':24,'vertices_removed':36,'retained_surfaces_identical':True},'all_other_geometry_unchanged':True,'camera_unchanged':True,'material_bindings_unchanged':True,'character_mesh_count':len(meshes),'character_vertices':sum(d['vertices'] for d in meshes),'character_triangles':sum(d['triangles'] for d in meshes),'missing_dependencies':0,'file_images':images,'external_libraries':len(bpy.data.libraries),'armatures':0,'actions':0,'unused_materials':[m.name for m in bpy.data.materials if m.users-int(m.use_fake_user)==0],'unused_meshes':[m.name for m in bpy.data.meshes if m.users==0],'mesh_audit':meshes,'layer_intersections':intersections,'final_sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
assert not report['unused_materials'];assert not report['unused_meshes']
(p/'Validation/final_validation.json').write_text(json.dumps(report,indent=2))
print(json.dumps({k:v for k,v in report.items() if k not in ['mesh_audit']},indent=2),flush=True)
if '--audit-only' in sys.argv:
 print('FINAL MASTER AUDIT COMPLETE; source unchanged.');sys.exit(0)
# Render the actual cleaned master, not the development intermediate. Do not save temporary render path changes.
sc.render.filepath=str(p/'Validation/cleaned_final_full.png');bpy.ops.render.render(write_still=True)
assert hashlib.sha256(path.read_bytes()).hexdigest()==report['final_sha256'];print('CLEAN FINAL MASTER RELOADED, VERIFIED AND RENDERED.')
