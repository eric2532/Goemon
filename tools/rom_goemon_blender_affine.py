"""Preserve the small source shear which Blender bone channels cannot encode."""
import bpy


def add_correction(obj, rig, name):
    group = bpy.data.node_groups.new('ROM_Affine_' + name, 'GeometryNodeTree')
    group.interface.new_socket(name='Geometry', in_out='INPUT', socket_type='NodeSocketGeometry')
    group.interface.new_socket(name='Geometry', in_out='OUTPUT', socket_type='NodeSocketGeometry')
    input_ = group.nodes.new('NodeGroupInput');output = group.nodes.new('NodeGroupOutput')
    position = group.nodes.new('GeometryNodeInputPosition')
    separate = group.nodes.new('ShaderNodeSeparateXYZ');group.links.new(position.outputs['Position'], separate.inputs[0])
    combined = group.nodes.new('ShaderNodeCombineXYZ')
    for row in range(3):
        total = None
        for column in range(4):
            node = group.nodes.new('ShaderNodeMath');node.operation = 'MULTIPLY' if column < 3 else 'ADD'
            prop = 'affine_%s_%d%d' % (name, row, column);rig[prop] = float(row == column)
            driver = node.inputs[1].driver_add('default_value').driver
            v = driver.variables.new();v.name = 'coefficient';v.targets[0].id = rig;v.targets[0].data_path = '["%s"]' % prop
            driver.expression = 'coefficient'
            if column < 3:group.links.new(separate.outputs[column], node.inputs[0])
            else:node.inputs[0].default_value = 0
            if total is None:total = node.outputs[0]
            else:
                add = group.nodes.new('ShaderNodeMath');add.operation = 'ADD'
                group.links.new(total, add.inputs[0]);group.links.new(node.outputs[0], add.inputs[1]);total = add.outputs[0]
        group.links.new(total, combined.inputs[row])
    set_position = group.nodes.new('GeometryNodeSetPosition')
    group.links.new(input_.outputs['Geometry'], set_position.inputs['Geometry'])
    group.links.new(combined.outputs[0], set_position.inputs['Position'])
    group.links.new(set_position.outputs['Geometry'], output.inputs['Geometry'])
    modifier = obj.modifiers.new('Native affine correction', 'NODES');modifier.node_group = group
    return modifier
