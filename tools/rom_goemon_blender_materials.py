"""Portable Blender preview materials for preserved N64 textures and raw UVs."""
import bpy


def math_node(nodes, links, operation, a, b=None):
    node = nodes.new('ShaderNodeMath');node.operation = operation
    for i, value in enumerate([a, b]):
        if value is None:continue
        if isinstance(value, (int, float)):node.inputs[i].default_value = value
        else:links.new(value, node.inputs[i])
    return node.outputs[0]


def material(surface, root, rig, faces):
    mat = bpy.data.materials.new('ROM_' + surface.get('texture_file', 'color'))
    mat.use_nodes = True;mat.use_backface_culling = False
    nodes = mat.node_tree.nodes;links = mat.node_tree.links;nodes.clear()
    output = nodes.new('ShaderNodeOutputMaterial');shader = nodes.new('ShaderNodeBsdfPrincipled')
    shader.inputs['Roughness'].default_value = .82;shader.inputs['Specular IOR Level'].default_value = 0
    links.new(shader.outputs['BSDF'], output.inputs['Surface'])
    raw = nodes.new('ShaderNodeUVMap');raw.uv_map = 'ROM_Raw_ST'
    separate = nodes.new('ShaderNodeSeparateXYZ');links.new(raw.outputs['UV'], separate.inputs[0])
    combine = nodes.new('ShaderNodeCombineXYZ')
    tile = surface.get('tile', {});size = surface.get('texture_size', [32, 32])
    for axis, label in enumerate(['s', 't']):
        value = math_node(nodes, links, 'MULTIPLY', separate.outputs[axis], surface.get('uv_scale', [.5, .5])[axis] / 32)
        shift = tile.get(label + '_shift', 0)
        value = math_node(nodes, links, 'MULTIPLY', value, 2 ** (-shift if shift < 11 else 16 - shift))
        value = math_node(nodes, links, 'SUBTRACT', value, tile.get('origin', [0, 0])[axis])
        mode = tile.get(label + '_mode', 2);mask = tile.get(label + '_mask', 0)
        if mode & 2 or not mask:
            value = math_node(nodes, links, 'MAXIMUM', value, 0)
            value = math_node(nodes, links, 'MINIMUM', value, size[axis] - 1)
        if mask:
            period = 2 ** mask
            if mode & 1:
                value = math_node(nodes, links, 'ADD', value, .5)
                value = math_node(nodes, links, 'PINGPONG', value, period)
                value = math_node(nodes, links, 'SUBTRACT', value, .5)
                value = math_node(nodes, links, 'MAXIMUM', value, 0)
                value = math_node(nodes, links, 'MINIMUM', value, period - 1)
            else:value = math_node(nodes, links, 'FLOORED_MODULO', value, period)
        value = math_node(nodes, links, 'ADD', value, .5)
        value = math_node(nodes, links, 'DIVIDE', value, size[axis])
        if axis == 1:value = math_node(nodes, links, 'SUBTRACT', 1, value)
        links.new(value, combine.inputs[axis])

    def texture(filename):
        image = bpy.data.images.load(str(root / filename), check_existing=True);image.pack()
        node = nodes.new('ShaderNodeTexImage');node.image = image;node.interpolation = 'Closest';node.extension = 'EXTEND'
        links.new(combine.outputs[0], node.inputs['Vector'])
        return node.outputs['Color'], node.outputs['Alpha']

    pointer = surface.get('texture_pointer', '')
    if pointer in ['0xb000000', '0xc000000']:
        channel = 0 if pointer == '0xb000000' else 1
        value = nodes.new('ShaderNodeValue');value.name = 'ROM_Face_Channel_' + str(channel)
        driver = value.outputs[0].driver_add('default_value').driver
        variable = driver.variables.new();variable.name = 'face';variable.targets[0].id = rig
        variable.targets[0].data_path = '["rom_face_%d"]' % channel;driver.expression = 'face'
        color = None;alpha = 0
        for i, (_, record) in enumerate(sorted(faces.items())):
            rgb, a = texture(record['file'])
            selected = math_node(nodes, links, 'COMPARE', value.outputs[0], i)
            # The compare epsilon defaults to0.5, separating integer indices.
            if color is None:color = rgb
            else:
                mix = nodes.new('ShaderNodeMixRGB');links.new(selected, mix.inputs[0]);links.new(color, mix.inputs[1]);links.new(rgb, mix.inputs[2]);color = mix.outputs[0]
            alpha = math_node(nodes, links, 'ADD', alpha, math_node(nodes, links, 'MULTIPLY', a, selected))
    else:color, alpha = texture(surface['texture_file'])
    attribute = nodes.new('ShaderNodeVertexColor');attribute.layer_name = 'ROM_Color'
    multiply = nodes.new('ShaderNodeMixRGB');multiply.blend_type = 'MULTIPLY';multiply.inputs[0].default_value = 1
    links.new(color, multiply.inputs[1]);links.new(attribute.outputs['Color'], multiply.inputs[2]);links.new(multiply.outputs[0], shader.inputs['Base Color'])
    alpha = math_node(nodes, links, 'MULTIPLY', alpha, attribute.outputs['Alpha'])
    links.new(math_node(nodes, links, 'GREATER_THAN', alpha, .1), shader.inputs['Alpha'])
    mat['rom_surface'] = str(surface)
    return mat
