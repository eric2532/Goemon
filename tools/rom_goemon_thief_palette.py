"""Master Thief's saved colors applied to copies of the ROM preview materials."""
import bpy
from rom_goemon_blender_materials import math_node


def linear_hex(value):
    rgb = [int(value[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in rgb) + (1,)


def apply_palette():
    for obj in [o for o in bpy.data.objects if o.get('rom_part')]:
        for index, slot in enumerate(obj.material_slots):
            if obj.name == 'ROM_Head' and index != 0:continue  # Preserve face channels and black temple shapes.
            mat = slot.material.copy();slot.material = mat;mat.name = 'MasterThief_' + mat.name
            nodes = mat.node_tree.nodes;links = mat.node_tree.links
            shader = next(n for n in nodes if n.type == 'BSDF_PRINCIPLED')
            color = shader.inputs['Base Color'].links[0].from_socket
            separate = nodes.new('ShaderNodeSeparateColor');links.new(color, separate.inputs[0])
            r, g, b = separate.outputs[:3]
            mul = lambda a, b_:math_node(nodes, links, 'MULTIPLY', a, b_)
            gt = lambda a, b_:math_node(nodes, links, 'GREATER_THAN', a, b_)
            lt = lambda a, b_:math_node(nodes, links, 'LESS_THAN', a, b_)
            blue = mul(gt(b, .2), mul(lt(r, .1), lt(g, .1)))
            masks = [(blue, 'e2dde0')] if obj.name == 'ROM_Head' else [
                (mul(gt(r, .15), mul(lt(g, .25), gt(r, math_node(nodes, links, 'ADD', b, .12)))), '722f3e'),
                (mul(gt(r, .5), mul(gt(g, .25), lt(b, .12))), 'd5ad58'),
                (mul(gt(r, .65), mul(gt(g, .65), gt(b, .65))), '253344'),
                (blue, 'd5ad58')]
            for mask, target in masks:
                mix = nodes.new('ShaderNodeMixRGB');links.new(mask, mix.inputs[0]);links.new(color, mix.inputs[1])
                mix.inputs[2].default_value = linear_hex(target);color = mix.outputs[0]
            links.new(color, shader.inputs['Base Color'])
            mat['pilot_palette'] = 'Master Thief maroon/navy/gold/silver; source images unchanged.'
