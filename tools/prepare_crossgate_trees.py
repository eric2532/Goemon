"""Initial preparation only; edit saved tree masters and use export_blender.py afterward."""
import hashlib
import json
import math
from pathlib import Path
import random
import runpy
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "assets/blender/environments/wind_meadow/broadleaf_tree.blend"
OUT = MASTER.parent / "crossgate_flora"
ART = ROOT / "assets/maps/falan/flora"
data = json.loads((ART / "source.json").read_text())
names = [name for name in data["graphics"] if name != "bark"]
assert all(not (OUT / (name+".blend")).exists() for name in names), "Preserve saved masters; export artist edits instead of regenerating"
protected = [MASTER, ROOT / "assets/models/environments/wind_meadow/broadleaf_tree.glb"]
before = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
OUT.mkdir(parents=True, exist_ok=True)
report = {"protected": before, "variants": {}}


def paint(name, texture):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    surface = nodes.get("Principled BSDF")
    surface.inputs["Roughness"].default_value = 1
    image = nodes.new("ShaderNodeTexImage")
    image.image = bpy.data.images.load(str(ART / (texture+".png")), check_existing=True)
    image.image.pack()
    colors = nodes.new("ShaderNodeVertexColor"); colors.layer_name = "Color"
    multiply = nodes.new("ShaderNodeMixRGB"); multiply.blend_type = "MULTIPLY"; multiply.inputs[0].default_value = 1
    material.node_tree.links.new(image.outputs["Color"], multiply.inputs[1])
    material.node_tree.links.new(colors.outputs["Color"], multiply.inputs[2])
    material.node_tree.links.new(multiply.outputs[0], surface.inputs["Base Color"])
    material.use_backface_culling = False
    return material


for name in names:
    bpy.ops.wm.open_mainfile(filepath=str(MASTER))
    body, canopy = bpy.data.objects["Body"], bpy.data.objects["Canopy"]
    counts = [(len(o.data.vertices), len(o.data.polygons)) for o in (body, canopy)]
    entry = data["graphics"][name]
    unit = data["metres_per_pixel"]
    rng = random.Random(161126)
    assert len(canopy.data.vertices) % 4 == 0, "Reuse intact existing leaf quads"
    shades = []
    for start in range(0, len(canopy.data.vertices), 4):
        leaves = list(canopy.data.vertices[start:start+4])
        center = sum((v.co for v in leaves), Vector()) / 4
        index = rng.randrange(len(entry["points"]))
        x, y = entry["points"][index]
        shades.extend([entry["shades"][index]]*4)
        left, right = entry["spans"][str(y)]
        axis = (left+right)*.5
        radius = max(1, (right-left)*.5)
        depth = math.sqrt(max(0, radius**2-(x-axis)**2))*rng.uniform(-.9, .9)
        target = Vector(((x-entry["origin"][0])*unit, depth*unit, (entry["origin"][1]-y)*unit))
        for vertex in leaves: vertex.co = target+(vertex.co-center)*1.30
    for obj, texture in ((body, "bark"), (canopy, name)):
        obj.data.materials.clear(); obj.data.materials.append(paint("Cross Gate "+texture, texture))
        obj["reused_source"] = str(MASTER.relative_to(ROOT))
        obj["source_graphic"] = entry["serial"]
        colors = obj.data.color_attributes.active_color
        for i, item in enumerate(colors.data):
            shade = shades[i] if obj == canopy else 1
            item.color = (shade, shade, shade, 1)
        if obj == canopy:
            for loop in obj.data.loops:
                obj.data.uv_layers.active.data[loop.index].uv = ((0, 0), (1, 0), (1, 1), (0, 1))[loop.vertex_index % 4]
        obj.data.update()
    assert counts == [(len(o.data.vertices), len(o.data.polygons)) for o in (body, canopy)]
    bpy.context.scene["source_recipe"] = "tools/recover_crossgate_foliage.py; source.json native crown samples"
    bpy.context.scene["export_active_vertex_colors"] = True
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / (name+".blend")))
    runpy.run_path(str(ROOT / "tools/export_blender.py"))
    report["variants"][name] = {"source_graphic": entry["serial"], "vertices_faces": counts}
assert before == {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
(OUT / "provenance.json").write_text(json.dumps(report, indent=2)+"\n")
(ROOT / "build/Other Files/Asset Toolkit/Falan Road Recovery/tree-preparation.json").write_text(json.dumps(report, indent=2)+"\n")
print("CROSSGATE_TREES_PREPARED: three solid trees; original meshes and leaf counts preserved")
