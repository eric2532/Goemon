"""Private below-ground native-bank study; never enroll maps or change ground planes."""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps

from prepare_abanis_cliffs import measured_profile
from east_cliff_geometry import lobes, native_triangles, project, raster, rounded_native
from prepare_east_stone_profiles import clean_native_front, source_contour_profile

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Remaining Fallback Audit'
OUT = REPORT / 'Typed Bank Study'
STUDY = [12500, 12926, 1238125, 1238195]


def native(serial):
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
    import cg_library as lib
    plan = json.loads((REPORT / 'TYPED_BANK_SOURCE_PLAN.json').read_text())['graphics'][str(serial)]
    if serial >= 1_000_000:
        row = json.loads((ROOT / 'assets/maps/original_crossgate/east/catalog.json').read_text())['graphics'][str(serial)]
    else:
        row = lib.serial_index()[serial]
    original = lib.image_from_record(row['pack'], row['row']).convert('RGBA')
    assert hashlib.sha256(original.tobytes()).hexdigest() == plan['native_rgba_sha256']
    graphic = dict(origin=plan['origin'], footprint=plan['footprint'], rect=[0, 0, *original.size], rgba_sha256=plan['native_rgba_sha256'])
    return original, graphic, plan


def split_water(image, serial):
    """Only confirmed blue-water hybrid families use this separate original-RGB plane."""
    rgba = np.asarray(image).copy()
    water = np.zeros(rgba.shape[:2], dtype=bool)
    if 12500 <= serial <= 12535 or serial in [1238182, 1238183, 1238187, 1238188, 1238192]:
        r, g, b = rgba[:, :, :3].astype(float).transpose(2, 0, 1)
        water = (rgba[:, :, 3] >= 128) & (b > r * 1.12) & (g > r * 1.12) & (b > g * .90)
    solid = rgba.copy()
    solid[water, 3] = 0
    fluid = rgba.copy()
    fluid[~water, 3] = 0
    return Image.fromarray(solid), Image.fromarray(fluid), int(water.sum())


def fit_bank(image, graphic):
    """Invert a native contour study around its actual anchor, then restore source axes.

    This is a visual frame, not a new collision footprint. Wider original paint
    supplies the measured horizontal envelope; all resulting geometry is below
    the source cap at Y=0. Visible alpha and the original source projection are
    checked independently of the old hardcoded three-metre bank box.
    """
    source = ImageOps.flip(ImageOps.mirror(image))
    fx, fz = graphic['footprint']
    center = np.array([fx * 1.5 - 1.5, 0., 1.5 - fz * 1.5])
    auxiliary = dict(graphic)
    auxiliary['origin'] = [
        (center[0] + center[2]) * 64 / 3 - (image.width - 1 + graphic['origin'][0]),
        (center[2] - center[0]) * 16 - (image.height - 1 + graphic['origin'][1]),
    ]
    profile, _ = measured_profile(source, auxiliary)
    # Metadata footprints describe placement ownership, not opaque bitmap width.
    # The source-facing overhang is therefore measured separately from nav cells.
    visible = image.getbbox()
    ratio = max(1., (visible[2] - visible[0]) / ((fx + fz) * 32))
    for point in profile['vertices'] + [profile['crown']]:
        point[0] = center[0] + (point[0] - center[0]) * ratio
        point[2] = center[2] + (point[2] - center[2]) * ratio
    profile['pixel_height'] = .045
    profile['height'] = max(.15, (image.height + graphic['origin'][1] - 24) * .045)
    profile, proof = source_contour_profile(source, auxiliary, profile)
    triangles = rounded_native(native_triangles(profile), 2)
    # A reflection in all three axes reverses winding. Retain outward normals.
    triangles = 2 * center - triangles
    triangles = triangles[:, [0, 2, 1]]
    # The source cap is a ground datum, never an elevated box roof.
    assert triangles[:, :, 1].max() < 1e-8
    proof.update(source_cap_y=0., placement_footprint=graphic['footprint'],
                 visual_width_ratio=ratio,
                 frame='Native lower-bank frame: original anchor/cap stays at Y=0; rock descends. No new collision, navigation, water or portal ownership.')
    return triangles, proof


def build(serial):
    original, graphic, plan = native(serial)
    cleaned = clean_native_front(original)
    face, water, water_pixels = split_water(cleaned, serial)
    triangles, proof = fit_bank(face, graphic)
    # Preserve the source projection; rounded patches add depth along its null ray.
    ph = .045
    eye = np.array([-1., 16 * ph, 1.]); eye /= np.linalg.norm(eye)
    light = ImageOps.grayscale(face).convert('RGBA')
    light.putalpha(face.getchannel('A'))
    valid = np.asarray(face)[:, :, 3] >= 128
    patches = lobes(light, valid)
    yy, xx = np.mgrid[:face.height, :face.width]
    depth = np.zeros(valid.shape)
    for patch in patches:
        x, y = patch['center']; rx, ry = patch['radius']
        height = min(.42, max(.08, min(rx / (32 / 3 * math.sqrt(2)), ry * ph) * .8))
        patch['inferred_depth_m'] = height
        depth = np.maximum(depth, height * np.maximum(0, 1 - ((xx-x)/rx)**2 - ((yy-y)/ry)**2)**.55)
    normals = {}
    key = lambda p: tuple(np.round(p, 7))
    for triangle in triangles:
        normal = np.cross(triangle[2]-triangle[0], triangle[1]-triangle[0])
        for p in triangle: normals[key(p)] = normals.get(key(p), np.zeros(3)) + normal
    for p, normal in normals.items(): normals[p] = normal / max(1e-12, np.linalg.norm(normal))
    deformed = []
    for triangle in triangles:
        row = []
        for p in triangle:
            normal = normals[key(p)]
            uv = project(p, graphic, ph)
            x, y = np.rint(uv).astype(int)
            amount = depth[y, x] if 0 <= x < face.width and 0 <= y < face.height and valid[y, x] else 0.
            # Preserve source UV along the calibrated ray; never move the ground cap.
            amount *= min(1., max(0., -p[1]) / .35)
            delta = eye * amount if normal @ eye > .35 else normal * amount * .7
            if p[1] + delta[1] > 0: delta *= -p[1] / delta[1]
            row.append(p + delta)
        deformed.append(row)
    deformed = np.asarray(deformed)
    sums = {}
    for triangle in deformed:
        normal = np.cross(triangle[2]-triangle[0], triangle[1]-triangle[0])
        for p in triangle: sums[key(p)] = sums.get(key(p), np.zeros(3)) + normal
    for p, normal in sums.items(): sums[p] = normal / max(1e-12, np.linalg.norm(normal))
    normals = np.asarray([[sums[key(p)] for p in tri] for tri in deformed])
    uv = project(deformed, graphic, ph)
    observed = []
    for before, values in zip(triangles, uv):
        normal = np.cross(before[2]-before[0], before[1]-before[0]); normal /= max(1e-12, np.linalg.norm(normal))
        observed.append(normal @ eye > .15 and all(0 <= u < face.width-1 and 0 <= v < face.height-1 for u, v in values))
    uv[~np.asarray(observed)] = -1
    metadata = dict(graphic=serial, source_native_rgba_sha256=plan['native_rgba_sha256'], source_origin=graphic['origin'],
                    source_footprint=graphic['footprint'], proof=proof, water_pixels=water_pixels,
                    inferred='Hidden lower rock closure and 0.08–0.42 m native light-patch relief. Water RGB is retained separately at the existing water datum. Source cap, ground/object planes, anchors, collision, navigation and portals are untouched.',
                    status='private_native_geometry_study_not_enrolled_or_visually_accepted')
    return original, face, water, deformed, normals, uv, graphic, eye, metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--serial', type=int, action='append')
    args = parser.parse_args(); OUT.mkdir(parents=True, exist_ok=True)
    for serial in args.serial or STUDY:
        original, face, water, solid, normals, uv, graphic, eye, metadata = build(serial)
        original.save(OUT/f'{serial}-native.png'); face.save(OUT/f'{serial}-rock-front.png'); water.save(OUT/f'{serial}-water.png')
        # A fixed-scale hidden palette is kept separate from original front RGB.
        rgba = np.asarray(face); colors = rgba[(rgba[:,:,3]>=128)&(rgba[:,:,:3].max(2)>45),:3]
        palette = np.tile(np.median(colors, axis=0), (*solid.shape[:2], 1))
        for label, view in [('source', eye), ('normal', [-1,.72,1]), ('second', [1,.72,-1])]:
            raster(solid, normals, uv, face, view, graphic, .045, source=label=='source', palette=palette).save(OUT/f'{serial}-{label}.png')
        (OUT/f'{serial}-study.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2)+'\n')
        np.savez_compressed(OUT/f'{serial}-geometry.npz', solid=solid, normals=normals, uv=uv)
        print('EAST_BANK_STUDY', serial, len(solid), 'triangles; water pixels', metadata['water_pixels'], flush=True)


if __name__ == '__main__': main()
