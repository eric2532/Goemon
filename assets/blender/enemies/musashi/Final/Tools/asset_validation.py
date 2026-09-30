import bpy,json,hashlib

def value(v):
 if isinstance(v,(bool,int,float,str)) or v is None:return v
 try:return [value(a) for a in v]
 except:return str(v)

def geometry_hash(o):
 d={'type':o.type,'world':value(o.matrix_world),'hide_render':o.hide_render}
 if o.type=='MESH':
  d.update(vertices=[value(v.co) for v in o.data.vertices],edges=[list(e.vertices) for e in o.data.edges],polygons=[list(f.vertices) for f in o.data.polygons],smooth=[f.use_smooth for f in o.data.polygons],matidx=[f.material_index for f in o.data.polygons],slot_count=len(o.data.materials),vertex_normals=[value(v.normal) for v in o.data.vertices],color_attributes={a.name:[value(c.color) for c in a.data] for a in o.data.color_attributes},modifiers=[(m.name,m.type,m.show_viewport,m.show_render) for m in o.modifiers])
 elif o.type=='CAMERA':d.update(ortho_scale=o.data.ortho_scale,lens=o.data.lens,type=o.data.type)
 return hashlib.sha256(json.dumps(d,sort_keys=True).encode()).hexdigest()

def snapshot():return {o.name:geometry_hash(o) for o in bpy.data.objects if o.type in {'MESH','CAMERA'} and o.name!='Studio ground'}
