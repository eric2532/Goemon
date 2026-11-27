"""East-only visible-contour fitting; the shared Native cliff fitter stays unchanged."""
import copy
import math
from collections import deque
from PIL import Image, ImageDraw


def clean_native_front(image):
    """Preserve RGB; remove border void and large uniform neutral occlusion masks."""
    width, height = image.size
    pixels = list(image.convert('RGBA').getdata())
    void = Image.new('L', image.size)
    neutral = set()
    for i, (r, g, b, alpha) in enumerate(pixels):
        hidden = max(r, g, b) <= 45 and max(r, g, b) - min(r, g, b) < 3
        if alpha < 128 or hidden:
            void.putpixel((i % width, i // width), 255)
        if alpha >= 128 and hidden:
            neutral.add(i)
    for x, y in [(x, y) for x in range(width) for y in (0, height - 1)] + [(x, y) for y in range(height) for x in (0, width - 1)]:
        if void.getpixel((x, y)) == 255:
            ImageDraw.floodfill(void, (x, y), 128)
    removed = set()
    while neutral:
        start = neutral.pop()
        pending = deque([start])
        component = [start]
        while pending:
            i = pending.popleft()
            x, y = i % width, i // width
            for nx, ny in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]:
                ni = ny * width + nx
                if 0 <= nx < width and 0 <= ny < height and ni in neutral:
                    neutral.remove(ni)
                    component.append(ni)
                    pending.append(ni)
        if len(component) >= 512:
            removed.update(component)
    result = image.convert('RGBA').copy()
    for i, pixel in enumerate(pixels):
        if pixel[3] < 128 or i in removed or void.getpixel((i % width, i // width)) == 128:
            result.putpixel((i % width, i // width), (*pixel[:3], 0))
    return result


def source_contour_profile(image, graphic, native, measured_height=None):
    """Replace the Native92%roof floor with measured source-facing side heights.

    Input art may already have unrecorded black occlusion alpha removed. Original
    source origin and footprint cells remain authoritative. Old mesh bounds are
    only a reference. Hidden closure and crown placement are explicit inference.
    """
    profile = copy.deepcopy(native)
    width, height = image.size
    pixels = image.load()
    top = []
    for x in range(width):
        marks = [y for y in range(height) if pixels[x, y][3] >= 128 and max(pixels[x, y][:3]) > 45]
        top.append(marks[0] if marks else None)
    columns = [x for x, y in enumerate(top) if y is not None]
    assert columns, 'A visible stone contour is required; void masks need a separate owner'
    for x, y in enumerate(top):
        if y is None:
            top[x] = top[min(columns, key=lambda column: abs(column - x))]

    original = native['vertices'] + [native['crown']]
    low = [min(p[i] for p in original) for i in range(3)]
    high = [max(p[i] for p in original) for i in range(3)]
    center = [(low[i] + high[i]) / 2 for i in range(3)]
    extent = [(high[i] - low[i]) / 2 for i in range(3)]
    sides, levels = int(profile['sides']), int(profile['levels'])
    pixel_height, native_height = float(profile['pixel_height']), float(profile['height'])
    origin = graphic['origin']
    ceilings = []
    for side in range(sides):
        angle = side * math.tau / sides
        # A source footprint is a cell rectangle, not an inscribed ellipse.
        cosine, sine = math.cos(angle), math.sin(angle)
        scale = max(abs(cosine), abs(sine))
        x, z = center[0] + cosine / scale * extent[0], center[2] + sine / scale * extent[2]
        column = max(0, min(width - 1, round((x + z) * 32 / 3 - origin[0])))
        ceilings.append(max(min(.2, native_height), ((z - x) * 8 - origin[1] - top[column]) * pixel_height))
    calibration = 1.0 if measured_height is None else float(measured_height) / max(ceilings)
    if measured_height is not None:
        ceilings = [y * calibration for y in ceilings]
        pixel_height *= calibration
        profile['pixel_height'] = pixel_height
    fitted_height = max(ceilings)

    vertices = []
    overhang_samples = []
    for layer in range(levels):
        for side in range(sides):
            angle = side * math.tau / sides
            cosine, sine = math.cos(angle), math.sin(angle)
            direction_scale = max(abs(cosine), abs(sine))
            dx, dz = cosine / direction_scale * extent[0], sine / direction_scale * extent[2]
            y = ceilings[side] * (layer / (levels - 1) if layer < levels - 1 else .94)
            radius = .3
            for step in range(44, 11, -1):
                candidate = step / 40
                x, z = center[0] + dx * candidate, center[2] + dz * candidate
                u = round((x + z) * 32 / 3 - origin[0])
                v = round((z - x) * 8 - y / pixel_height - origin[1])
                if 0 <= u < width and 0 <= v < height and pixels[u, v][3] >= 128 and max(pixels[u, v][:3]) > 45:
                    radius = candidate
                    break
            point = [center[0] + dx * radius, y, center[2] + dz * radius]
            vertices.append(point)
            if radius > 1.0001:
                sample_u = round((point[0] + point[2]) * 32 / 3 - origin[0])
                sample_v = round((point[2] - point[0]) * 8 - point[1] / pixel_height - origin[1])
                overhang_samples.append({'point': point, 'native_pixel': [sample_u, sample_v], 'rgba': list(pixels[sample_u, sample_v])})
    highest = sorted(range(sides), key=lambda side: ceilings[side])[-3:]
    crown = [sum(vertices[(levels - 1) * sides + side][axis] for side in highest) / len(highest) for axis in range(3)]
    crown[1] = fitted_height

    # Visible alpha may extend beyond collision cells. Only sampled native paint
    # admits that bounded overhang; no collision or walk data is enlarged.
    profile.update(vertices=vertices, crown=crown, contour_top=top, height=fitted_height)
    updated = vertices + [crown]
    fitted_low = [min(point[axis] for point in updated) for axis in range(3)]
    fitted_high = [max(point[axis] for point in updated) for axis in range(3)]
    proof = {
        'method': 'Visible original top contour replaces the shared92%roof floor; source-high side controls the crown. Source anchors, footprint cells, navigation and portals remain unchanged; original painted alpha controls the visible envelope.',
        'side_heights': ceilings,
        'height_calibration': calibration,
        'reference_native_bounds': [low, high],
        'fitted_source_bounds': [fitted_low, fitted_high],
        'source_confirmed_overhang_rule': 'Up to10%radial continuation beyond the source footprint only where unchanged native alpha supplies visible stone; hidden depth is inferred separately. No new collision or walk cells.',
        'crown': crown,
        'inferred': 'Hidden side heights, closed crown and interpolation continue the measured visible pile within the source-fitted visible envelope.',
        'shared_native_modified': False,
        'confirmed_overhang_samples': overhang_samples,
    }
    if measured_height is not None:
        proof['explicit_measured_height'] = float(measured_height)
    return profile, proof
