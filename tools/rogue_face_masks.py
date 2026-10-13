"""Closed native armor masks for the user-approved v2.37 equipment correction.

Call after the existing dragon_helmet / arcane_helmet generators. All points use
Blender world space, with the character looking along -Y. The accepted painted
skulls and facial UVs are preserved beneath these separate armor components.
"""
from collections import Counter

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import tessellate_polygon

from sculpt_rogue_pilot import make_mesh, finish_mesh, world_points


def _material(hero):
    return bpy.data.materials[hero + ' | Goemon matte painted palette']


def _remove(coll, prefixes):
    removed = []
    for obj in list(coll.objects):
        if obj.type == 'MESH' and any(obj.name.startswith(p) for p in prefixes):
            removed.append(obj.name)
            bpy.data.objects.remove(obj, do_unlink=True)
    return removed


def _armor(name, verts, faces, mat, uv, head, coll):
    obj = make_mesh('Equipment ' + name, verts, faces, mat, head, coll, uv)
    # Broad, deliberate armor planes match the native painted costume shapes.
    for face in obj.data.polygons:
        face.use_smooth = False
    obj['equipment_design'] = 'Closed face-covering native armor; painted skull preserved'
    return obj


def _smooth_skin(obj, count, boundary):
    """Continuous armor shading, with a crisp manufactured perimeter."""
    for face in obj.data.polygons:
        face.use_smooth = True
    boundaries = {tuple(sorted(edge)) for edge in boundary}
    for edge in obj.data.edges:
        a, b = edge.vertices
        if (a < count and b < count and tuple(sorted((a, b))) in boundaries or
                a >= count and b >= count and
                tuple(sorted((a-count, b-count))) in boundaries):
            edge.use_edge_sharp = True


def _shell(name, rows, mat, uv, head, coll, thickness=.026, exponent=2.45):
    """A real curved shell, with front/back skins and a closed perimeter.

    Each row is (height, half_width, central_front_y, side_y). Curved cheek
    returns reach the temple guards so the face stays covered in profile too.
    """
    across = (-1, -.90, -.72, -.48, -.24, 0, .24, .48, .72, .90, 1)
    verts = []
    for z, width, front, side in rows:
        for t in across:
            verts.append((width*t, front+(side-front)*abs(t)**exponent, z))
    count = len(verts)
    verts += [(x, y+thickness, z) for x, y, z in verts]
    stride = len(across)
    faces = []
    for k in range(len(rows)-1):
        for j in range(stride-1):
            a = k*stride+j
            # Triangulate deliberately: non-planar cheek quads export unchanged.
            for tri in ((a, a+1, a+stride+1), (a, a+stride+1, a+stride)):
                faces.extend((tri, tuple(v+count for v in reversed(tri))))
    perimeter = list(range(stride))
    perimeter += [k*stride+stride-1 for k in range(1, len(rows))]
    perimeter += list(reversed(range((len(rows)-1)*stride, len(rows)*stride-1)))
    perimeter += [k*stride for k in reversed(range(1, len(rows)-1))]
    for a, b in zip(perimeter, perimeter[1:]+perimeter[:1]):
        faces.append((a, a+count, b+count, b))
    obj = _armor(name, verts, faces, mat, uv, head, coll)
    _smooth_skin(obj, count, zip(perimeter, perimeter[1:]+perimeter[:1]))
    bpy.context.view_layer.update()
    surface = BVHTree.FromPolygons(world_points(obj), [list(f.vertices) for f in obj.data.polygons])
    return obj, surface


def _panel(name, outline, surface, mat, uv, head, coll, lift=.008, thickness=.012):
    """Seat a closed decorative armor panel on the actual faceted mask.

    Shared triangulation vertices are subdivided before projection, avoiding a
    flat sticker crossing through the curved snout. The back skin extends into
    the supporting armor, so no dark slit or metal border can hover in profile.
    """
    points = [Vector((x, 0, z)) for x, z in outline]
    lookup = {(round(p.x, 8), round(p.z, 8)): i for i, p in enumerate(points)}
    triangles = [tuple(p if isinstance(p, int) else
                       lookup[(round(p.x, 8), round(p.z, 8))] for p in tri)
                 for tri in tessellate_polygon([points])]
    for _ in range(2):
        edges = {}
        divided = []
        def midpoint(a, b):
            key = tuple(sorted((a, b)))
            if key not in edges:
                edges[key] = len(points)
                points.append((points[a]+points[b])*.5)
            return edges[key]
        for a, b, c in triangles:
            ab, bc, ca = midpoint(a, b), midpoint(b, c), midpoint(c, a)
            divided.extend(((a, ab, ca), (ab, b, bc), (ca, bc, c), (ab, bc, ca)))
        triangles = divided
    verts = []
    for p in points:
        hit, normal, index, distance = surface.ray_cast(Vector((p.x, -10, p.z)), Vector((0, 1, 0)))
        assert hit is not None, name + ' is outside its supporting mask'
        verts.append((p.x, hit.y-lift, p.z))
    # A triangle chord can cut through a sharply changing supporting facet even
    # when all three corners clear it. Lift only the affected shared vertices.
    for _ in range(4):
        clearance = [0.0]*len(verts)
        for tri in triangles:
            samples = ((1/3, 1/3, 1/3), (.5, .5, 0), (.5, 0, .5), (0, .5, .5))
            for weights in samples:
                p = sum((Vector(verts[i])*weight for i, weight in zip(tri, weights)), Vector())
                hit, *_ = surface.ray_cast(Vector((p.x, -10, p.z)), Vector((0, 1, 0)))
                if hit is not None:
                    shift = max(0, p.y-hit.y+min(.006, lift*.5))
                    for i in tri:
                        clearance[i] = max(clearance[i], shift)
        if max(clearance) < .00001:
            break
        verts = [(x, y-clearance[i], z) for i, (x, y, z) in enumerate(verts)]
    count = len(verts)
    verts += [(x, y+thickness, z) for x, y, z in verts]
    faces = list(triangles) + [tuple(i+count for i in reversed(t)) for t in triangles]
    edge_counts = Counter(tuple(sorted((a, b))) for t in triangles
                          for a, b in zip(t, t[1:]+t[:1]))
    for (a, b), uses in edge_counts.items():
        if uses == 1:
            faces.append((a, b, b+count, a+count))
    obj = _armor(name, verts, faces, mat, uv, head, coll)
    _smooth_skin(obj, count, [edge for edge, uses in edge_counts.items() if uses == 1])
    return obj


def _sides(outline, side):
    return [(side*x, z) for x, z in outline]


def _surface(*objects):
    bpy.context.view_layer.update()
    points, faces = [], []
    for obj in objects:
        offset = len(points)
        points += world_points(obj)
        faces += [tuple(i+offset for i in f.vertices) for f in obj.data.polygons]
    return BVHTree.FromPolygons(points, faces)


def dragon_face_mask(hero, head, coll):
    """Replace the small ornamental dragon face with one full armored face."""
    mat = _material(hero)
    navy, teal, silver = (.5625, .0625), (.1875, .0625), (.6875, .0625)
    dark, turquoise = (.3125, .0625), (.4375, .0625)
    removed = _remove(coll, (
        'Equipment dragon swept snout', 'Equipment dragon silver muzzle rim',
        'Equipment dragon teal eye inlay', 'Equipment dragon jaw guard',
        'Equipment dragon closed ', 'Equipment dragon visor ',
        'Equipment dragon face ', 'Equipment dragon muzzle ',
    ))
    mask, surface = _shell('dragon closed face shell', [
        (1.385, .075, -.245, .020),
        (1.435, .145, -.335, .055),
        (1.515, .235, -.390, .075),
        (1.620, .297, -.492, .080),
        (1.720, .340, -.532, .080),
        (1.790, .354, -.490, .075),
        (1.855, .354, -.459, .070),
        (1.925, .348, -.461, .065),
        (2.025, .337, -.445, .060),
        (2.130, .260, -.348, .035),
    ], mat, navy, head, coll, exponent=4.3)
    # Narrow dark recessed-looking visor slots hide the intact painted eyes.
    for side in (-1, 1):
        visor = _panel('dragon visor shadow '+str(side), _sides([
            (.052, 1.875), (.277, 1.944), (.253, 1.884), (.071, 1.846),
        ], side), surface, mat, dark, head, coll, lift=.010)
        _panel('dragon visor teal slit '+str(side), _sides([
            (.077, 1.870), (.255, 1.922), (.235, 1.891), (.083, 1.857),
        ], side), _surface(visor), mat, turquoise, head, coll, lift=.005, thickness=.008)
        _panel('dragon visor armored brow '+str(side), _sides([
            (.035, 1.901), (.278, 1.977), (.307, 1.949), (.064, 1.868),
        ], side), _surface(mask, visor), mat, silver, head, coll, lift=.029, thickness=.036)
        _panel('dragon face swept cheek '+str(side), _sides([
            (.102, 1.816), (.292, 1.877), (.327, 1.758),
            (.259, 1.623), (.195, 1.658), (.235, 1.749),
        ], side), surface, mat, teal, head, coll, lift=.020, thickness=.027)
        _panel('dragon muzzle nostril '+str(side), _sides([
            (.083, 1.742), (.179, 1.759), (.150, 1.726), (.092, 1.721),
        ], side), surface, mat, dark, head, coll, lift=.010)
    _panel('dragon muzzle silver bridge', [
        (0, 1.903), (-.069, 1.806), (-.041, 1.732),
        (0, 1.700), (.041, 1.732), (.069, 1.806),
    ], surface, mat, silver, head, coll, lift=.023, thickness=.030)
    _panel('dragon muzzle dark jaw seam', [
        (-.218, 1.654), (-.141, 1.614), (0, 1.596), (.141, 1.614),
        (.218, 1.654), (.186, 1.600), (0, 1.564), (-.186, 1.600),
    ], surface, mat, dark, head, coll, lift=.009)
    _panel('dragon muzzle silver jaw', [
        (-.191, 1.583), (0, 1.548), (.191, 1.583),
        (.111, 1.466), (0, 1.431), (-.111, 1.466),
    ], surface, mat, silver, head, coll, lift=.021, thickness=.028)
    mask['coverage'] = 'Full painted face including forehead, nose, mouth, cheeks and chin'
    return removed, [], ('Closed navy dragon faceplate with narrow turquoise visor, '
                         'projecting armored snout, silver bridge and complete jaw; '
                         'existing swept horns, crown shell and temple fins retained')


def demon_face_mask(hero, head, coll):
    """Purple cartoon demon armor mask, beneath the existing crystal crown."""
    mat = _material(hero)
    purple, lavender = (.3125, .1875), (.0625, .1875)
    dark, light = (.9375, .0625), (.8125, .0625)
    # This former exposed fringe is now behind the full mask. Its upper tip
    # pierced the violet crown; rear and side silver locks remain unchanged.
    removed = _remove(coll, ('Equipment demon ', 'Pilot silver sweeping fringe'))
    mask, surface = _shell('demon closed violet face shell', [
        (1.388, .063, -.230, .030),
        (1.445, .139, -.325, .065),
        (1.525, .225, -.389, .090),
        (1.620, .295, -.428, .085),
        (1.705, .335, -.469, .080),
        (1.780, .354, -.441, .075),
        (1.855, .361, -.409, .075),
        (1.945, .357, -.404, .075),
        (2.035, .334, -.390, .060),
        (2.085, .278, -.350, .045),
    ], mat, purple, head, coll, exponent=4.8)
    for side in (-1, 1):
        visor = _panel('demon narrow shadow eye '+str(side), _sides([
            (.058, 1.845), (.280, 1.908), (.255, 1.839), (.101, 1.811),
        ], side), surface, mat, dark, head, coll, lift=.012, thickness=.015)
        _panel('demon slanted violet eye slit '+str(side), _sides([
            (.098, 1.840), (.247, 1.879), (.229, 1.853), (.107, 1.828),
        ], side), _surface(visor), mat, light, head, coll, lift=.005, thickness=.008)
        _panel('demon bold raised brow '+str(side), _sides([
            (.034, 1.891), (.288, 1.972), (.307, 1.938),
            (.107, 1.864), (.065, 1.847),
        ], side), _surface(mask, visor), mat, lavender, head, coll, lift=.032, thickness=.040)
        _panel('demon angular cheek blade '+str(side), _sides([
            (.119, 1.780), (.316, 1.856), (.332, 1.728),
            (.234, 1.598), (.185, 1.632), (.251, 1.742),
        ], side), surface, mat, lavender, head, coll, lift=.019, thickness=.027)
    _panel('demon angular nose ridge', [
        (0, 1.916), (-.076, 1.781), (-.051, 1.703),
        (0, 1.668), (.051, 1.703), (.076, 1.781),
    ], surface, mat, purple, head, coll, lift=.053, thickness=.060)
    _panel('demon nose center facet', [
        (0, 1.888), (-.025, 1.753), (0, 1.686), (.025, 1.753),
    ], surface, mat, lavender, head, coll, lift=.057, thickness=.012)
    _panel('demon sharp mouth shadow', [
        (-.175, 1.636), (-.077, 1.609), (0, 1.625), (.077, 1.609),
        (.175, 1.636), (.132, 1.567), (0, 1.544), (-.132, 1.567),
    ], surface, mat, dark, head, coll, lift=.013, thickness=.020)
    for side in (-1, 1):
        _panel('demon small silver fang '+str(side), _sides([
            (.079, 1.615), (.131, 1.633), (.115, 1.554),
        ], side), surface, mat, lavender, head, coll, lift=.025, thickness=.032)
    _panel('demon pointed chin armor', [
        (-.132, 1.529), (0, 1.508), (.132, 1.529),
        (.086, 1.455), (0, 1.418), (-.086, 1.455),
    ], surface, mat, lavender, head, coll, lift=.021, thickness=.028)
    mask['coverage'] = 'Full painted face beneath a purple demon armor mask'
    return removed, [], ('Full violet demon mask with bold slanted brows, narrow dark '
                         'enchanted eyes, angular cheeks/nose/chin and two small silver '
                         'fangs; existing amethyst crystal crown and temples retained')
