"""Fingerprint editable rigid geometry/paint, independently of animated poses."""
import hashlib
import json
import array


def fingerprint(ob):
    mesh=ob.data
    def values(value):
        if isinstance(value,(int,float,bool,str)):return value
        return [round(float(x),7) for x in value]
    materials=[]
    for material in mesh.materials:
        nodes=[]
        if material.node_tree:
            for node in material.node_tree.nodes:
                inputs=[(socket.name,values(socket.default_value)) for socket in node.inputs if hasattr(socket,'default_value')]
                image=getattr(node,'image',None)
                paint=hashlib.sha256(array.array('f',image.pixels[:]).tobytes()).hexdigest() if image else None
                nodes.append((node.type,inputs,paint))
        materials.append((material.name,values(material.diffuse_color),nodes))
    data=dict(vertices=[values(v.co) for v in mesh.vertices],
              faces=[(list(p.vertices),p.material_index) for p in mesh.polygons],
              normals=[values(n.vector) for n in mesh.corner_normals],
              uv=[[(values(v.uv)) for v in layer.data] for layer in mesh.uv_layers],
              colors=[(layer.name,layer.domain,layer.data_type,[values(v.color) for v in layer.data]) for layer in mesh.color_attributes],
              materials=materials)
    return hashlib.sha256(json.dumps(data,sort_keys=True).encode()).hexdigest()


def morph_fingerprint(ob):
    keys=ob.data.shape_keys
    values=[] if keys is None else [(key.name,[[round(float(c),7) for c in point.co] for point in key.data]) for key in keys.key_blocks]
    return hashlib.sha256(json.dumps(values).encode()).hexdigest()
